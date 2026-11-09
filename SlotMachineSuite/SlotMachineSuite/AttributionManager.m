#import "AttributionManager.h"
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <AdSupport/AdSupport.h>

#if __has_include(<AppsFlyerLib/AppsFlyerLib.h>)
#import <AppsFlyerLib/AppsFlyerLib.h>
#define SMS_HAS_APPSFLYER 1
#else
#define SMS_HAS_APPSFLYER 0
#endif

#if __has_include(<AdjustSdk/Adjust.h>)
#import <AdjustSdk/Adjust.h>
#import <AdjustSdk/ADJConfig.h>
#import <AdjustSdk/ADJEvent.h>
#import <AdjustSdk/ADJLogger.h>
#define SMS_HAS_ADJUST 1
#else
#define SMS_HAS_ADJUST 0
#endif

@implementation AttributionManager {
    BOOL _didConfigure;
    NSDictionary *_launchOptions;
    NSDictionary<NSString *, NSString *> *_remoteConfiguration;
#if SMS_HAS_APPSFLYER
    AppsFlyerLib *_appsFlyer;
    NSMutableArray<NSDictionary *> *_pendingLinks;
#endif
#if SMS_HAS_ADJUST
    BOOL _adjustConfigured;
#endif
}

+ (instancetype)sharedManager {
    static AttributionManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[AttributionManager alloc] init];
    });
    return manager;
}

- (void)configureWithLaunchOptions:(NSDictionary * _Nullable)launchOptions {
    if (_didConfigure) {
        return;
    }

    _didConfigure = YES;
    _launchOptions = [launchOptions copy];
    [self configureAppsFlyerWithLaunchOptions:_launchOptions];
    [self configureAdjust];
}

- (void)applyRemoteConfiguration:(NSDictionary<NSString *, NSString *> *)configuration {
    NSAssert(NSThread.isMainThread, @"SDK configuration must run on the main thread");
    if (![configuration isKindOfClass:NSDictionary.class]) return;
    _remoteConfiguration = [configuration copy];
    [self configureAppsFlyerWithLaunchOptions:_launchOptions];
    [self configureAdjust];
}

- (NSDictionary<NSString *, NSString *> *)webQueryParameters {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSMutableDictionary<NSString *, NSString *> *parameters = [@{
        @"pkg": bundleID, @"channel": bundleID,
        @"jsb": @"HAminiBridgeIOS", @"supportVersion": @"2", @"supportShowAtt": @"1"
    } mutableCopy];
    if (ATTrackingManager.trackingAuthorizationStatus == ATTrackingManagerAuthorizationStatusAuthorized) {
        NSString *idfa = ASIdentifierManager.sharedManager.advertisingIdentifier.UUIDString;
        NSString *idfv = UIDevice.currentDevice.identifierForVendor.UUIDString;
        if (idfa.length) parameters[@"idfa"] = idfa;
        if (idfv.length) parameters[@"idfv"] = idfv;
#if SMS_HAS_APPSFLYER
        NSString *uid = [_appsFlyer getAppsFlyerUID];
        if (uid.length) parameters[@"apf"] = uid;
#endif
    }
    return [parameters copy];
}

- (void)logEvent:(NSString *)name values:(NSDictionary<NSString *, id> *)values {
    if (name.length == 0) {
        return;
    }

#if SMS_HAS_APPSFLYER
    // Messaging nil is intentional: events must not create an unconfigured SDK.
    [_appsFlyer logEvent:name withValues:values ?: @{}];
#endif

#if SMS_HAS_ADJUST
    id tokenValue = values[@"adjust_event_token"];
    if (_adjustConfigured && [tokenValue isKindOfClass:NSString.class] && [tokenValue length] > 0) {
        ADJEvent *event = [[ADJEvent alloc] initWithEventToken:tokenValue];
        if (event) {
            [Adjust trackEvent:event];
        }
    }
#endif
}

- (void)handleOpenURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
#if SMS_HAS_APPSFLYER
    if (_appsFlyer) {
        [_appsFlyer handleOpenUrl:url options:options ?: @{}];
    } else if (url) {
        [self enqueuePendingLink:@{@"url": url, @"options": [options copy] ?: @{}}];
    }
#endif
}

- (BOOL)continueUserActivity:(NSUserActivity *)userActivity
          restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
#if SMS_HAS_APPSFLYER
    if (_appsFlyer) return [_appsFlyer continueUserActivity:userActivity restorationHandler:restorationHandler];
    if (![userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) return NO;
    NSMutableDictionary *pending = [@{@"activity": userActivity} mutableCopy];
    if (restorationHandler) pending[@"restoration"] = [restorationHandler copy];
    [self enqueuePendingLink:pending];
    return YES;
#else
    return NO;
#endif
}

#if SMS_HAS_APPSFLYER
- (void)enqueuePendingLink:(NSDictionary *)link {
    if (!_pendingLinks) _pendingLinks = [NSMutableArray array];
    if (_pendingLinks.count >= 8) [_pendingLinks removeObjectAtIndex:0];
    [_pendingLinks addObject:link];
}

- (void)deliverPendingLinks {
    NSArray<NSDictionary *> *links = [_pendingLinks copy];
    [_pendingLinks removeAllObjects];
    for (NSDictionary *link in links) {
        if (link[@"url"]) {
            [_appsFlyer handleOpenUrl:link[@"url"] options:link[@"options"]];
        } else {
            [_appsFlyer continueUserActivity:link[@"activity"] restorationHandler:link[@"restoration"]];
        }
    }
}
#endif

- (void)configureAppsFlyerWithLaunchOptions:(NSDictionary * _Nullable)launchOptions {
#if SMS_HAS_APPSFLYER
    if (_appsFlyer) return;
#endif
    NSString *devKey = [self infoString:@"AppsFlyerDevKey"];
    NSString *appID = [self infoString:@"AppsFlyerAppID"];
    if (devKey.length == 0 || appID.length == 0) {
        return;
    }

#if SMS_HAS_APPSFLYER
    // Accessing shared creates the SDK, so validate credentials first.
    _appsFlyer = [AppsFlyerLib shared];
    _appsFlyer.isDebug = NO;
    [_appsFlyer initWithDevKey:devKey appleAppId:appID];
    [_appsFlyer handleLaunchOptions:launchOptions];

    // AppsFlyer 7 invokes this on the main queue once per foreground cycle,
    // after configuration and deep-link readiness conditions are satisfied.
    __weak AppsFlyerLib *weakAppsFlyer = _appsFlyer;
    [_appsFlyer registerSessionReadyListener:^{
        [weakAppsFlyer start];
    }];
    [self deliverPendingLinks];
#else
    NSLog(@"[AppsFlyer] Credentials provided, but AppsFlyerLib is not linked.");
#endif
}

- (void)configureAdjust {
#if SMS_HAS_ADJUST
    if (_adjustConfigured) return;
#endif
    NSString *appToken = [self infoString:@"AdjustAppToken"];
    if (appToken.length == 0) {
        return;
    }

#if SMS_HAS_ADJUST
    NSString *environment = [[[self infoString:@"AdjustEnvironment"] lowercaseString] isEqualToString:@"sandbox"]
        ? ADJEnvironmentSandbox : ADJEnvironmentProduction;
    ADJConfig *config = [[ADJConfig alloc] initWithAppToken:appToken environment:environment];
    if (![config isValid]) {
        return;
    }

    // Keep warnings and errors visible without routine SDK startup messages.
    config.logLevel = ADJLogLevelWarn;
    [Adjust initSdk:config];
    _adjustConfigured = YES;
#else
    NSLog(@"[Adjust] App token provided, but Adjust is not linked.");
#endif
}

- (NSString *)infoString:(NSString *)key {
    id value = _remoteConfiguration[key];
    NSString *remote = [value isKindOfClass:NSString.class]
        ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
    if (remote.length) return remote;
    value = [NSBundle.mainBundle objectForInfoDictionaryKey:key];
    return [value isKindOfClass:NSString.class]
        ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
}

@end
