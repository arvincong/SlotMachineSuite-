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
            NSDictionary *csc = @{@"open": @YES, @"url": @"https://csc.example/game?x=1#start",
                                  @"preShowAtt": @YES, @"source": @NO,
                                  @"allowed_hosts": @[@"LOGIN.EXAMPLE"],
                                  @"query_params": @{@"a": @"b"},
                                  @"adjustToken": @" abcdef123456 ", @"adjEnvironment": @" SANDBOX ",
                                  @"adjustStartEvent": @"abc123", @"adjustEvent_a": @"def456"};
            NSDictionary *us = @{@"open": @YES, @"url": @"https://us.example/",
                                 @"source": @YES, @"adjustToken": @"123456abcdef"};
            SMSRemoteConfiguration *config = resolve(@{});
            Check(!config.webEnabled, @"empty first launch is native");
            [defaults setObject:@"csc" forKey:@"SMSLaunchProject.v1"];
            [defaults setObject:@{@"csc": @{@"url": @"https://legacy.example/"}}
                         forKey:@"SMSLaunchWebConfigurations.v1"];
            [defaults setObject:@{@"AdjustAppToken": @"legacy123456"} forKey:@"SMSLaunchAttribution.v1"];
            config = resolve(@{@"project": @"csc", @"csc_url": @"https://legacy.example/", @"open": @YES});
            Check(!config.webEnabled, @"old project, URL cache and flat fields cannot authorize web");
            config = resolve(@{@"csc_info": csc, @"us_info": us});
            Check(config.webEnabled && [config.project isEqual:@"csc"], @"both open prefers CSC");
            Check([config.urlKey isEqual:@"url"], @"Parameter Store uses direct url field");
            Check([config.routeSource isEqual:@"remote_url"], @"fresh URL preferred");
            Check([config.webConfiguration[@"web_type"] isEqual:@"csc"], @"CSC bridge mode");
            Check([config.webConfiguration[@"url"] hasSuffix:@"?x=1#start"], @"query and fragment preserved");
            Check([config.webConfiguration[@"preShowAtt"] boolValue], @"ATT flag parsed");
            Check(![config.webConfiguration[@"source"] boolValue], @"source flag preserved separately");
            Check([config.webConfiguration[@"allowed_hosts"] containsObject:@"login.example"], @"host normalized");
            Check([config.webConfiguration[@"allowed_hosts"] containsObject:@"csc.example"], @"entry host included");
            Check([config.attributionConfiguration[@"AdjustAppToken"] isEqual:@"abcdef123456"], @"selected store credentials trimmed");
            Check([config.attributionConfiguration[@"AdjustEnvironment"] isEqual:@"sandbox"], @"environment normalized");
            Check([config.attributionConfiguration[@"AdjustStartEvent"] isEqual:@"abc123"], @"startup event parsed");
            Check([config.attributionConfiguration[@"adjustEvent_a"] isEqual:@"def456"], @"named event parsed");
            config = resolve(@{});
            Check(!config.webEnabled && !config.attributionConfiguration.count, @"failed fetch cannot use cached open or credentials");
            config = resolve(@{@"csc_info": @{@"open": @YES}});
            Check(config.webEnabled && [config.routeSource isEqual:@"cached_url"], @"fresh open authorizes retained URL after failed fetch");
            Check(![config.webConfiguration[@"preShowAtt"] boolValue], @"ATT flag never falls back to stale cache");
            Check(!config.attributionConfiguration[@"AdjustAppToken"], @"credentials do not fall back to cache");
            config = resolve(@{@"csc_info": @{@"open": @YES, @"url": @"https://new.example/"}});
            Check([config.webConfiguration[@"url"] isEqual:@"https://new.example/"], @"new URL replaces cached URL");
            Check(![config.webConfiguration[@"allowed_hosts"] containsObject:@"login.example"], @"old hosts do not leak");
            for (id invalid in @[@"", @"http://bad.example/", @"https://user:pass@bad.example/",
                                 @"javascript:alert(1)", @"https://", @42, NSNull.null]) {
                config = resolve(@{@"csc_info": @{@"open": @YES, @"url": invalid, @"source": @YES}});
                Check([config.routeSource isEqual:@"cached_url"], @"fresh open with invalid URL uses valid same-store cache");
                Check([config.webConfiguration[@"url"] isEqual:@"https://new.example/"], @"invalid URL never overwrites cache");
                Check([config.webConfiguration[@"source"] boolValue], @"cached URL uses fresh source flag");
            }
            config = resolve(@{@"csc_info": @{@"open": @NO}, @"us_info": us});
            Check(config.webEnabled && [config.project isEqual:@"us"], @"CSC closed selects open US despite old project");
            Check([config.webConfiguration[@"web_type"] isEqual:@"us"], @"US bridge mode");
            Check(![config.webConfiguration[@"allowed_hosts"] containsObject:@"new.example"], @"store hosts isolated");
            Check([config.attributionConfiguration[@"AdjustAppToken"] isEqual:@"123456abcdef"], @"store credentials isolated");
            config = resolve(@{@"csc_info": @{@"open": @YES}, @"us_info": @{@"open": @NO}});
            Check(!config.webEnabled, @"close revokes prior CSC URL cache");
            config = resolve(@{@"csc_info": csc, @"us_info": @{@"open": @YES, @"url": @"invalid"}});
            Check([config.routeSource isEqual:@"remote_url"], @"invalid lower-priority URL does not corrupt selected outcome");
            for (id invalidOpen in @[@NO, @1, @0, @"true", @"false", NSNull.null]) {
                (void)resolve(@{@"csc_info": csc});
                config = resolve(@{@"csc_info": @{@"open": invalidOpen, @"url": @"https://csc.example/"}});
                Check(!config.webEnabled, @"only an actual Boolean true authorizes web");
                config = resolve(@{@"csc_info": @{@"open": @YES}});
                Check(!config.webEnabled, @"invalid or false open revokes snapshot");
            }
            (void)resolve(@{@"csc_info": csc});
            config = resolve(@{@"csc_info": @{@"url": @"https://csc.example/"}});
            Check(!config.webEnabled, @"missing open in a received store stays native");
            config = resolve(@{@"csc_info": @{@"open": @YES}, @"us_info": us});
            Check([config.project isEqual:@"us"], @"open CSC without usable URL falls through to US");
            config = resolve(@{@"csc_info": @{@"open": @YES, @"url": @"https://clean.example/",
                                              @"preShowAtt": @"true", @"source": @1,
                                              @"allowed_hosts": @[@"other.example/path", @"*.example", @"login.example:443"],
                                              @"query_params": @{@"bad": @42, @"good": @"value"},
                                              @"adjustToken": @"invalid", @"adjustStartEvent": @"bad",
                                              @"adjustEvent_a": @"!@#$%^", @"adjEnvironment": @"unknown"}});
            Check([config.webConfiguration[@"allowed_hosts"] isEqual:@[@"clean.example"]], @"invalid hosts grant no access");
            Check([config.webConfiguration[@"query_params"] isEqual:@{@"good": @"value"}], @"non-string query parameters filtered");
            Check(![config.webConfiguration[@"preShowAtt"] boolValue] && ![config.webConfiguration[@"source"] boolValue], @"malformed optional Boolean flags default false");
            Check(!config.attributionConfiguration[@"AdjustAppToken"] &&
                  !config.attributionConfiguration[@"AdjustStartEvent"] &&
                  !config.attributionConfiguration[@"adjustEvent_a"], @"invalid Adjust tokens filtered");
            Check([config.attributionConfiguration[@"AdjustEnvironment"] isEqual:@"production"], @"unknown environment defaults production");
            [defaults setObject:@"corrupt" forKey:@"SMSParameterStoreWebConfigurations.v2"];
            config = resolve(@{@"csc_info": csc});
            Check(config.webEnabled, @"corrupt defaults recover with fresh remote values");
            [defaults setObject:@{@"csc_info": @{@"url": @"http://invalid.example/"}}
                         forKey:@"SMSParameterStoreWebConfigurations.v2"];
            config = resolve(@{@"csc_info": @{@"open": @YES}});
            Check(!config.webEnabled, @"cached URL is revalidated");
            for (id invalidStore in @[@42, NSNull.null, @[@"bad"], @"bad"]) {
                config = resolve(@{@"csc_info": invalidStore});
                Check(!config.webEnabled, @"malformed store stays native");
            }
            config = resolve(@{@"csc_info": @{@"open": @NO}, @"us_info": @{@"open": @NO}});
            Check(!config.webEnabled && !config.webConfiguration.count, @"both closed stays native");
            printf("PASS: %lu launch routing checks\n", (unsigned long)checks);
        } @finally {
            [defaults removePersistentDomainForName:suite];
        }
    }
    return 0;
}
