#import "AppDelegate.h"
#import "AttributionManager.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Window creation belongs to SceneDelegate when scene-based lifecycle is enabled.
    // Keep app-level startup lightweight so scene connection is not delayed.
    return YES;
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
