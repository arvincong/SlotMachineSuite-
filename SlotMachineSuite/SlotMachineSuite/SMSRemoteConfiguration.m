#import "SMSRemoteConfiguration.h"
#import <CoreFoundation/CoreFoundation.h>

// Version 2 never uses the old sticky project or an old cached enable decision.
static NSString * const SMSWebCacheKey = @"SMSParameterStoreWebConfigurations.v2";

static NSString *SMSConfigString(id value) {
    return [value isKindOfClass:NSString.class]
        ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
}

static BOOL SMSConfigBoolean(id value) {
    return [value isKindOfClass:NSNumber.class] &&
        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID() && [value boolValue];
}

static BOOL SMSIsToken(NSString *value, NSUInteger length) {
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"] invertedSet];
    return value.length == length && [value rangeOfCharacterFromSet:invalid].location == NSNotFound;
}

@interface SMSRemoteConfiguration ()
@property (nonatomic) BOOL webEnabled;
@property (nonatomic, copy) NSString *project;
@property (nonatomic, copy) NSString *urlKey;
@property (nonatomic, copy) NSString *routeSource;
@property (nonatomic, copy) NSDictionary<NSString *, id> *webConfiguration;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *attributionConfiguration;
+ (nullable NSDictionary<NSString *, id> *)validatedWebValues:(NSDictionary *)values
                                                       url:(id)rawURL project:(NSString *)project;
+ (NSDictionary<NSString *, NSString *> *)attributionValues:(NSDictionary *)values;
@end

@implementation SMSRemoteConfiguration

+ (instancetype)configurationWithValues:(NSDictionary<NSString *, id> *)values {
    return [self configurationWithValues:values defaults:NSUserDefaults.standardUserDefaults];
}

+ (instancetype)configurationWithValues:(NSDictionary<NSString *, id> *)values defaults:(NSUserDefaults *)defaults {
    NSAssert(NSThread.isMainThread, @"Launch configuration must be resolved on the main thread");
    SMSRemoteConfiguration *configuration = [self new];
    configuration.project = @"";
    configuration.urlKey = @"";
    configuration.routeSource = @"closed_or_unavailable";
    configuration.webConfiguration = @{};
    configuration.attributionConfiguration = @{};
    values = [values isKindOfClass:NSDictionary.class] ? values : @{};
    id savedCache = [defaults objectForKey:SMSWebCacheKey];
    NSMutableDictionary *cache = [savedCache isKindOfClass:NSDictionary.class]
        ? [savedCache mutableCopy] : [NSMutableDictionary dictionary];

    // Deterministic priority when both stores are open. Never combine their metadata.
    for (NSString *project in @[@"csc", @"us"]) {
        NSString *storeName = [project stringByAppendingString:@"_info"];
        id entry = values[storeName];
        // A failed fetch supplies no store. Stay native without destroying URL data
        // that a later successful open=true response may authorize again.
        if (!entry) continue;
        NSDictionary *store = [entry isKindOfClass:NSDictionary.class] ? entry : @{};
        if (!SMSConfigBoolean(store[@"open"])) {
            // Missing/malformed open also revokes a previous snapshot.
            [cache removeObjectForKey:storeName];
            continue;
        }
        NSDictionary *web = [self validatedWebValues:store url:store[@"url"] project:project];
        NSString *routeSource = @"remote_url";
        if (web) {
            cache[storeName] = web;
        } else {
            // Only a fresh open=true can authorize URL fallback. Runtime flags and
            // credentials always come from the current store, never from this cache.
            id saved = cache[storeName];
            if ([saved isKindOfClass:NSDictionary.class]) {
                web = [self validatedWebValues:saved url:saved[@"url"] project:project];
                if (web) {
                    NSMutableDictionary *snapshot = [web mutableCopy];
                    snapshot[@"preShowAtt"] = @(SMSConfigBoolean(store[@"preShowAtt"]));
                    snapshot[@"source"] = @(SMSConfigBoolean(store[@"source"]));
                    web = snapshot;
                }
            }
            routeSource = @"cached_url";
        }
        if (!web) {
            if (!configuration.webEnabled) configuration.routeSource = @"no_valid_url";
            continue;
        }
        if (!configuration.webEnabled) {
            configuration.project = project;
            configuration.urlKey = @"url";
            configuration.routeSource = routeSource;
            configuration.webConfiguration = web;
            configuration.attributionConfiguration = [self attributionValues:store];
            configuration.webEnabled = YES;
        }
    }
    [defaults setObject:cache forKey:SMSWebCacheKey];
    return configuration;
}

+ (NSDictionary<NSString *, NSString *> *)attributionValues:(NSDictionary *)values {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"apfDevKey", @"apfAppId"]) {
        NSString *value = SMSConfigString(values[key]);
        if (value.length) result[[key isEqual:@"apfDevKey"] ? @"AppsFlyerDevKey" : @"AppsFlyerAppID"] = value;
    }
    NSString *token = SMSConfigString(values[@"adjustToken"]);
    if (SMSIsToken(token, 12)) result[@"AdjustAppToken"] = token;
    NSString *environment = SMSConfigString(values[@"adjEnvironment"]).lowercaseString;
    result[@"AdjustEnvironment"] = [environment isEqual:@"sandbox"] ? @"sandbox" : @"production";
    NSString *startEvent = SMSConfigString(values[@"adjustStartEvent"]);
    if (SMSIsToken(startEvent, 6)) result[@"AdjustStartEvent"] = startEvent;
    for (id key in values) {
        if (![key isKindOfClass:NSString.class] || ![key hasPrefix:@"adjustEvent_"] ||
            [key length] <= @"adjustEvent_".length) continue;
        NSString *event = SMSConfigString(values[key]);
        if (SMSIsToken(event, 6)) result[key] = event;
    }
    return result;
}

+ (nullable NSDictionary<NSString *, id> *)validatedWebValues:(NSDictionary *)values
                                                       url:(id)rawURL project:(NSString *)project {
    NSString *urlString = SMSConfigString(rawURL);
    if (!urlString.length) return nil;
    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    NSURL *url = components.URL;
    if (![url.scheme.lowercaseString isEqualToString:@"https"] || !url.host.length ||
        url.user != nil || url.password != nil) return nil;

    NSMutableSet<NSString *> *hosts = [NSMutableSet setWithObject:url.host.lowercaseString];
    id rawHosts = values[@"allowed_hosts"];
    // Invalid optional entries grant no extra access and do not veto a valid URL.
    for (id value in ([rawHosts isKindOfClass:NSArray.class] ? rawHosts : @[])) {
        NSString *host = SMSConfigString(value).lowercaseString;
        NSURLComponents *candidate = [NSURLComponents componentsWithString:[@"https://" stringByAppendingString:host]];
        if (!host.length || ![candidate.host.lowercaseString isEqualToString:host] ||
            candidate.user != nil || candidate.password != nil || candidate.port != nil ||
            candidate.query != nil || candidate.fragment != nil || candidate.path.length) continue;
        [hosts addObject:host];
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    id rawParameters = values[@"query_params"];
    for (id key in ([rawParameters isKindOfClass:NSDictionary.class] ? rawParameters : @{})) {
        id value = rawParameters[key];
        if (![key isKindOfClass:NSString.class] || ![key length] || ![value isKindOfClass:NSString.class]) continue;
        parameters[key] = value;
    }
    NSString *title = SMSConfigString(values[@"title"]);
    return @{@"url": url.absoluteString, @"project": project, @"web_type": project,
             @"preShowAtt": @(SMSConfigBoolean(values[@"preShowAtt"])),
             @"source": @(SMSConfigBoolean(values[@"source"])),
             @"allowed_hosts": [hosts.allObjects sortedArrayUsingSelector:@selector(compare:)],
             @"query_params": parameters, @"title": title.length ? title : @"Starlight"};
}

@end
