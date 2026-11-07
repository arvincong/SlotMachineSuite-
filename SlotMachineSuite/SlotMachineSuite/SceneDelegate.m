#import "SceneDelegate.h"
#import "AttributionManager.h"
#import "SlotMachineViewController.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene
willConnectToSession:(UISceneSession *)session
         options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:UIWindowScene.class]) {
        return;
    }

    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    self.window.rootViewController = [[SlotMachineViewController alloc] init];
    [self.window makeKeyAndVisible];

    // Keep optional attribution setup out of the scene connection path so the
    // first frame can be presented without waiting for third-party SDKs.
    dispatch_async(dispatch_get_main_queue(), ^{
        [[AttributionManager sharedManager] configure];
    });
}

- (void)scene:(UIScene *)scene
openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    for (UIOpenURLContext *context in URLContexts) {
        NSMutableDictionary *options = [NSMutableDictionary dictionary];
        if (context.options.sourceApplication.length > 0) {
            options[UIApplicationOpenURLOptionsSourceApplicationKey] = context.options.sourceApplication;
        }
        if (context.options.annotation) {
            options[UIApplicationOpenURLOptionsAnnotationKey] = context.options.annotation;
        }
        options[UIApplicationOpenURLOptionsOpenInPlaceKey] = @(context.options.openInPlace);
        [[AttributionManager sharedManager] handleOpenURL:context.URL options:options];
    }
}

- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity {
    [[AttributionManager sharedManager] continueUserActivity:userActivity restorationHandler:nil];
}

@end
