#import "AppDelegate.h"
#import "AttributionManager.h"
#import "SceneDelegate.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Register the SDK's session-ready listener before scenes become active.
    // SDKs without credentials remain disabled and do no startup work.
    [[AttributionManager sharedManager] configureWithLaunchOptions:launchOptions];
    return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application
configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                             options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *configuration = [UISceneConfiguration configurationWithName:@"Default Configuration"
                                                                        sessionRole:connectingSceneSession.role];
    configuration.delegateClass = SceneDelegate.class;
    return configuration;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    [[AttributionManager sharedManager] handleOpenURL:url options:options];
    return YES;
}

- (BOOL)application:(UIApplication *)application
continueUserActivity:(NSUserActivity *)userActivity
 restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    return [[AttributionManager sharedManager] continueUserActivity:userActivity restorationHandler:restorationHandler];
}

@end
