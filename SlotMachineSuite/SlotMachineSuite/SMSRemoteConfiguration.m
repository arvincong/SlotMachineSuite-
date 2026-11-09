#import "SMSRemoteConfiguration.h"

static NSString *SMSConfigString(id value) {
    return [value isKindOfClass:NSString.class]
        ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
}

static BOOL SMSConfigBoolean(id value) {
    // JSON booleans only: strings such as "false" must not enable the web route.
    return [value isKindOfClass:NSNumber.class] &&
           CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID() && [value boolValue];
}

@interface SMSRemoteConfiguration ()
@property (nonatomic) BOOL webEnabled;
@property (nonatomic, copy) NSDictionary<NSString *, id> *webConfiguration;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *attributionConfiguration;
@end

@implementation SMSRemoteConfiguration

+ (instancetype)configurationWithValues:(NSDictionary<NSString *, id> *)values {
    SMSRemoteConfiguration *configuration = [self new];
    configuration.webConfiguration = @{};
    configuration.attributionConfiguration = @{};
    if (![values isKindOfClass:NSDictionary.class]) return configuration;

    // Keep compatibility with the reference project's SDK credential names.
    NSMutableDictionary *attribution = [NSMutableDictionary dictionary];
    NSDictionary *aliases = @{
        @"AppsFlyerDevKey": @[@"AppsFlyerDevKey", @"apfDevKey"],
        @"AppsFlyerAppID": @[@"AppsFlyerAppID", @"apfAppId"],
        @"AdjustAppToken": @[@"AdjustAppToken", @"adjustToken", @"adjAppToken"],
        @"AdjustEnvironment": @[@"AdjustEnvironment", @"adjEnvironment"]
    };
    [aliases enumerateKeysAndObjectsUsingBlock:^(NSString *target, NSArray *keys, BOOL *stop) {
        for (NSString *key in keys) {
            NSString *value = SMSConfigString(values[key]);
            if (value.length > 0) {
                attribution[target] = value;
                break;
            }
        }
    }];
    configuration.attributionConfiguration = attribution;

    if (!SMSConfigBoolean(values[@"web_enabled"])) return configuration;
    NSString *urlString = SMSConfigString(values[@"url"]);
    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    NSURL *url = components.URL;
    if (![url.scheme.lowercaseString isEqualToString:@"https"] || url.host.length == 0 ||
        url.user != nil || url.password != nil) return configuration;

    NSMutableSet<NSString *> *hosts = [NSMutableSet setWithObject:url.host.lowercaseString];
    id rawHosts = values[@"allowed_hosts"];
    if (rawHosts && ![rawHosts isKindOfClass:NSArray.class]) return configuration;
    for (id value in ([rawHosts isKindOfClass:NSArray.class] ? rawHosts : @[])) {
        NSString *host = SMSConfigString(value).lowercaseString;
        NSURLComponents *candidate = [NSURLComponents componentsWithString:[@"https://" stringByAppendingString:host]];
        if (host.length == 0 || ![candidate.host.lowercaseString isEqualToString:host] ||
            candidate.user != nil || candidate.password != nil || candidate.port != nil ||
            candidate.query != nil || candidate.fragment != nil || candidate.path.length > 0) return configuration;
        [hosts addObject:host];
    }

    NSMutableDictionary<NSString *, NSString *> *parameters = [NSMutableDictionary dictionary];
    id rawParameters = values[@"query_params"];
    if (rawParameters && ![rawParameters isKindOfClass:NSDictionary.class]) return configuration;
    for (id key in ([rawParameters isKindOfClass:NSDictionary.class] ? rawParameters : @{})) {
        id value = rawParameters[key];
        if (![key isKindOfClass:NSString.class] || [key length] == 0 ||
            ![value isKindOfClass:NSString.class]) return configuration;
        parameters[key] = value;
    }
    NSString *title = SMSConfigString(values[@"title"]);
    configuration.webConfiguration = @{
        @"url": url.absoluteString,
        @"allowed_hosts": hosts.allObjects,
        @"query_params": parameters,
        @"title": title.length ? title : @"Starlight"
    };
    configuration.webEnabled = YES;
    return configuration;
}

@end
