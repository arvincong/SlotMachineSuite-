#import "AttributionManager.h"
#import <objc/message.h>

static id AFSharedInstance(void) {
    Class appsFlyerClass = NSClassFromString(@"AppsFlyerLib");
    SEL sharedSelector = NSSelectorFromString(@"shared");
    if (![appsFlyerClass respondsToSelector:sharedSelector]) {
        return nil;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [appsFlyerClass performSelector:sharedSelector];
#pragma clang diagnostic pop
}

@implementation AttributionManager {
    BOOL _didConfigure;
}

+ (instancetype)sharedManager {
    static AttributionManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[AttributionManager alloc] init];
    });
    return manager;
}

- (void)configure {
    if (_didConfigure) {
        return;
    }

    _didConfigure = YES;
    [self configureAppsFlyer];
    [self configureAdjust];
}

- (void)logEvent:(NSString *)name values:(NSDictionary<NSString *,id> *)values {
    if (name.length == 0) {
        return;
    }

    id appsFlyer = AFSharedInstance();
    SEL logSelector = NSSelectorFromString(@"logEvent:withValues:");
    if ([appsFlyer respondsToSelector:logSelector]) {
        ((void (*)(id, SEL, NSString *, NSDictionary *))objc_msgSend)(appsFlyer, logSelector, name, values ?: @{});
    }

    NSString *adjustToken = values[@"adjust_event_token"];
    if (adjustToken.length > 0) {
        Class eventClass = NSClassFromString(@"ADJEvent");
        Class adjustClass = NSClassFromString(@"Adjust");
        SEL initSelector = NSSelectorFromString(@"initWithEventToken:");
        SEL trackSelector = NSSelectorFromString(@"trackEvent:");
        if (eventClass && [adjustClass respondsToSelector:trackSelector]) {
            id event = [[eventClass alloc] init];
            if ([event respondsToSelector:initSelector]) {
                event = ((id (*)(id, SEL, NSString *))objc_msgSend)(event, initSelector, adjustToken);
                ((void (*)(id, SEL, id))objc_msgSend)(adjustClass, trackSelector, event);
            }
        }
    }
}

- (void)handleOpenURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    id appsFlyer = AFSharedInstance();
    SEL selector = NSSelectorFromString(@"handleOpenUrl:options:");
    if ([appsFlyer respondsToSelector:selector]) {
        ((void (*)(id, SEL, NSURL *, NSDictionary *))objc_msgSend)(appsFlyer, selector, url, options ?: @{});
    }
}

- (BOOL)continueUserActivity:(NSUserActivity *)userActivity
          restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    id appsFlyer = AFSharedInstance();
    SEL selector = NSSelectorFromString(@"continueUserActivity:restorationHandler:");
    if ([appsFlyer respondsToSelector:selector]) {
        return ((BOOL (*)(id, SEL, NSUserActivity *, id))objc_msgSend)(appsFlyer, selector, userActivity, restorationHandler);
    }
    return NO;
}

- (void)configureAppsFlyer {
    NSString *devKey = [self infoString:@"AppsFlyerDevKey"];
    NSString *appID = [self infoString:@"AppsFlyerAppID"];
    id appsFlyer = AFSharedInstance();

    if (devKey.length == 0 || appID.length == 0 || !appsFlyer) {
        NSLog(@"[AppsFlyer] configure skipped: missing keys or framework.");
        return;
    }

    SEL initSelector = NSSelectorFromString(@"initializeWithDevKey:appId:");
    if ([appsFlyer respondsToSelector:initSelector]) {
        ((void (*)(id, SEL, NSString *, NSString *))objc_msgSend)(appsFlyer, initSelector, devKey, appID);
    }

#if DEBUG
    if ([appsFlyer respondsToSelector:NSSelectorFromString(@"setIsDebug:")]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(appsFlyer, NSSelectorFromString(@"setIsDebug:"), YES);
    }
#endif

    if ([appsFlyer respondsToSelector:NSSelectorFromString(@"start")]) {
        ((void (*)(id, SEL))objc_msgSend)(appsFlyer, NSSelectorFromString(@"start"));
    }
}

- (void)configureAdjust {
    NSString *appToken = [self infoString:@"AdjustAppToken"];
    if (appToken.length == 0) {
        NSLog(@"[Adjust] configure skipped: missing AdjustAppToken.");
        return;
    }

    Class configClass = NSClassFromString(@"ADJConfig");
    Class adjustClass = NSClassFromString(@"Adjust");
    SEL initSelector = NSSelectorFromString(@"initWithAppToken:environment:");
    SEL initSdkSelector = NSSelectorFromString(@"initSdk:");

    if (!configClass || ![adjustClass respondsToSelector:initSdkSelector]) {
        NSLog(@"[Adjust] configure skipped: framework unavailable.");
        return;
    }

    NSString *environment = [[[self infoString:@"AdjustEnvironment"] lowercaseString] isEqualToString:@"sandbox"] ? @"sandbox" : @"production";
    id config = [[configClass alloc] init];
    if ([config respondsToSelector:initSelector]) {
        config = ((id (*)(id, SEL, NSString *, NSString *))objc_msgSend)(config, initSelector, appToken, environment);
    }

    if (config) {
        ((void (*)(id, SEL, id))objc_msgSend)(adjustClass, initSdkSelector, config);
    }
}

- (NSString *)infoString:(NSString *)key {
    id value = [NSBundle.mainBundle objectForInfoDictionaryKey:key];
    return [value isKindOfClass:NSString.class] ? value : @"";
}

@end
