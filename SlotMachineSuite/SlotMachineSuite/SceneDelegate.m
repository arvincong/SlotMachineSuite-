#import "SceneDelegate.h"
#import "AttributionManager.h"
#import "SMSLaunchViewController.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene
willConnectToSession:(UISceneSession *)session
         options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:UIWindowScene.class]) {
        return;
    }

    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    SMSLaunchViewController *launch = [SMSLaunchViewController new];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:launch];
    navigation.navigationBarHidden = YES;
    self.window.rootViewController = navigation;
    [self.window makeKeyAndVisible];

    // Cold-launch links arrive in connectionOptions, not the warm-link callbacks.
    [self scene:scene openURLContexts:connectionOptions.URLContexts];
    for (NSUserActivity *userActivity in connectionOptions.userActivities) {
        [self scene:scene continueUserActivity:userActivity];
    }
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
