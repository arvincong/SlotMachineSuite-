#import <Foundation/Foundation.h>
#import "SMSRemoteConfiguration.h"

static NSUInteger checks;
static void Check(BOOL condition, NSString *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); exit(1); }
    checks++;
}

int main(void) {
    @autoreleasepool {
        NSString *suite = [@"SMSRoutingChecks." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        @try {
            SMSRemoteConfiguration *(^resolve)(NSDictionary *) = ^(NSDictionary *values) {
                return [SMSRemoteConfiguration configurationWithValues:values defaults:defaults];
            };
            SMSRemoteConfiguration *config = resolve(@{});
            Check(!config.webEnabled && [config.routeSource isEqual:@"no_project"], @"empty first launch is native");
            config = resolve(@{@"web_enabled": @YES, @"url": @"https://legacy.example/"});
            Check(!config.webEnabled, @"legacy fields do not bypass project selection");
            config = resolve(@{@"project": @" \n H Appt \t", @"happt_url": @"https://one.example/game?x=1#start",
                               @"allowed_hosts": @[@"LOGIN.EXAMPLE"], @"query_params": @{@"a": @"b"},
                               @"apfDevKey": @" test-key "});
            Check([config.project isEqual:@"happt"], @"project strips all whitespace and lowercases");
            Check([config.urlKey isEqual:@"happt_url"], @"dynamic key");
            Check(config.webEnabled && [config.webConfiguration[@"web_type"] isEqual:@"us"], @"arbitrary project uses US");
            Check([config.routeSource isEqual:@"remote_url"], @"remote URL preferred");
            Check([config.webConfiguration[@"allowed_hosts"] containsObject:@"login.example"], @"host normalized");
            Check([config.webConfiguration[@"allowed_hosts"] containsObject:@"one.example"], @"entry host included");
            config = resolve(@{@"project": @"csc", @"csc_url": @"https://wrong.example/"});
            Check([config.project isEqual:@"happt"], @"saved project cannot be reassigned");
            Check([config.routeSource isEqual:@"cached_url"], @"missing selected URL uses cache");
            Check([config.attributionConfiguration[@"AppsFlyerDevKey"] isEqual:@"test-key"], @"credential cache fallback");
            config = resolve(@{@"happt_url": @"https://two.example/new"});
            Check([config.webConfiguration[@"url"] isEqual:@"https://two.example/new"], @"fresh URL replaces saved URL");
            Check(![config.webConfiguration[@"allowed_hosts"] containsObject:@"login.example"], @"old hosts do not leak");
            for (id invalid in @[@"", @"http://bad.example/", @"https://user:pass@bad.example/", @"javascript:alert(1)",
                                 @"https://", @42, NSNull.null]) {
                config = resolve(@{@"happt_url": invalid});
                Check([config.routeSource isEqual:@"cached_url"], @"invalid remote URL uses valid cache");
                Check([config.webConfiguration[@"url"] isEqual:@"https://two.example/new"], @"invalid URL never overwrites cache");
            }
            config = resolve(@{@"happt_url": @"https://three.example/", @"allowed_hosts": @[@"other.example/path"],
                               @"query_params": @{@"bad": @42, @"good": @"value"}});
            Check([config.routeSource isEqual:@"remote_url"], @"valid URL wins even with malformed optional metadata");
            Check([config.webConfiguration[@"allowed_hosts"] isEqual:@[@"three.example"]], @"invalid hosts grant no access");
            Check([config.webConfiguration[@"query_params"] isEqual:@{@"good": @"value"}], @"non-string parameters filtered");
            config = resolve(@{});
            Check(config.webEnabled && [config.routeSource isEqual:@"cached_url"], @"offline launch reuses cache");
            [defaults removePersistentDomainForName:suite];
            config = resolve(@{@"project": @" CSC ", @"csc_url": @"https://csc.example/"});
            Check([config.webConfiguration[@"web_type"] isEqual:@"csc"], @"CSC selects separate bridge mode");
            [defaults removeObjectForKey:@"SMSLaunchProject.v1"];
            config = resolve(@{@"project": @"us", @"us_url": @"http://invalid.example/"});
            Check(!config.webEnabled && [config.routeSource isEqual:@"no_valid_url"], @"CSC cache cannot serve US");
            config = resolve(@{@"project": @"csc", @"csc_url": @"https://csc.example/"});
            Check([config.project isEqual:@"us"] && !config.webEnabled, @"project remains sticky even before URL arrives");
            [defaults setObject:@42 forKey:@"SMSLaunchProject.v1"];
            [defaults setObject:@"corrupt" forKey:@"SMSLaunchWebConfigurations.v1"];
            config = resolve(@{@"project": @"us", @"us_url": @"https://us.example/"});
            Check(config.webEnabled, @"corrupt defaults recover with valid remote values");
            [defaults setObject:@{@"us": @{@"url": @"http://invalid.example/"}} forKey:@"SMSLaunchWebConfigurations.v1"];
            config = resolve(@{});
            Check(!config.webEnabled, @"cached URL is revalidated");
            [defaults removePersistentDomainForName:suite];
            config = resolve(@{@"project": NSNull.null, @"us_url": @"https://us.example/"});
            Check(!config.webEnabled, @"non-string project stays native");
            printf("PASS: %lu launch routing checks\n", (unsigned long)checks);
        } @finally {
            [defaults removePersistentDomainForName:suite];
        }
    }
    return 0;
}
