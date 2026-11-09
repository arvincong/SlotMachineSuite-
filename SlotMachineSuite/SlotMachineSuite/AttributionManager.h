#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AttributionManager : NSObject

+ (instancetype)sharedManager;
- (void)configureWithLaunchOptions:(NSDictionary * _Nullable)launchOptions;
/// Applies credentials to SDKs that have not been initialized yet; existing SDKs are never restarted.
- (void)applyRemoteConfiguration:(NSDictionary<NSString *, NSString *> *)configuration;
/// Reference WebView query fields; advertising identifiers require ATT authorization.
- (NSDictionary<NSString *, NSString *> *)webQueryParameters;
- (void)logEvent:(NSString *)name values:(NSDictionary<NSString *, id> * _Nullable)values;
- (void)handleOpenURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> * _Nullable)options;
- (BOOL)continueUserActivity:(NSUserActivity *)userActivity
          restorationHandler:(void (^ _Nullable)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler;

@end

NS_ASSUME_NONNULL_END
