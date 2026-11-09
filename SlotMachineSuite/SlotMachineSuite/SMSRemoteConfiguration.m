#import "SMSRemoteConfiguration.h"

static NSString * const SMSProjectKey = @"SMSLaunchProject.v1";
static NSString * const SMSWebCacheKey = @"SMSLaunchWebConfigurations.v1";
static NSString * const SMSAttributionCacheKey = @"SMSLaunchAttribution.v1";

static NSString *SMSConfigString(id value) {
    return [value isKindOfClass:NSString.class]
        ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
}

static NSString *SMSNormalizedProject(id value) {
    NSString *project = SMSConfigString(value);
    return [[project componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
            componentsJoinedByString:@""].lowercaseString;
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
    configuration.routeSource = @"no_project";
    configuration.webConfiguration = @{};
    values = [values isKindOfClass:NSDictionary.class] ? values : @{};

    // Retain validated credentials for offline launches; do not restart configured SDKs.
    NSDictionary *aliases = @{
        @"AppsFlyerDevKey": @[@"AppsFlyerDevKey", @"apfDevKey"],
        @"AppsFlyerAppID": @[@"AppsFlyerAppID", @"apfAppId"],
        @"AdjustAppToken": @[@"AdjustAppToken", @"adjustToken", @"adjAppToken"],
        @"AdjustEnvironment": @[@"AdjustEnvironment", @"adjEnvironment"]
    };
    id savedAttribution = [defaults objectForKey:SMSAttributionCacheKey];
    NSMutableDictionary *attribution = [NSMutableDictionary dictionary];
    for (NSString *target in aliases) {
        NSString *credential = [savedAttribution isKindOfClass:NSDictionary.class]
            ? SMSConfigString(savedAttribution[target]) : @"";
        for (NSString *key in aliases[target]) {
            NSString *remote = SMSConfigString(values[key]);
            if (remote.length) { credential = remote; break; }
        }
        if (credential.length) attribution[target] = credential;
    }
    configuration.attributionConfiguration = [attribution copy];
    if (attribution.count) [defaults setObject:attribution forKey:SMSAttributionCacheKey];

    // A saved project is sticky. Remote values are considered only on first assignment.
    NSString *project = SMSNormalizedProject([defaults objectForKey:SMSProjectKey]);
    if (!project.length) project = SMSNormalizedProject(values[@"project"]);
    if (!project.length) return configuration;
    [defaults setObject:project forKey:SMSProjectKey];
    configuration.project = project;
    configuration.urlKey = [project stringByAppendingString:@"_url"];

    id savedCache = [defaults objectForKey:SMSWebCacheKey];
    NSMutableDictionary *cache = [savedCache isKindOfClass:NSDictionary.class]
        ? [savedCache mutableCopy] : [NSMutableDictionary dictionary];
    NSDictionary *web = [self validatedWebValues:values url:values[configuration.urlKey] project:project];
    if (web) {
        cache[project] = web;
        [defaults setObject:cache forKey:SMSWebCacheKey];
        configuration.routeSource = @"remote_url";
    } else {
        // Validate a complete cached snapshot, keeping its hosts/parameters with its URL.
        id entry = cache[project];
        if ([entry isKindOfClass:NSDictionary.class]) {
            web = [self validatedWebValues:entry url:entry[@"url"] project:project];
        }
        configuration.routeSource = web ? @"cached_url" : @"no_valid_url";
    }
    if (web) {
        configuration.webConfiguration = web;
        configuration.webEnabled = YES;
    }
    return configuration;
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
    return @{@"url": url.absoluteString, @"project": project,
             @"web_type": [project isEqualToString:@"csc"] ? @"csc" : @"us",
             @"allowed_hosts": [hosts.allObjects sortedArrayUsingSelector:@selector(compare:)],
             @"query_params": parameters, @"title": title.length ? title : @"Starlight"};
}

@end
