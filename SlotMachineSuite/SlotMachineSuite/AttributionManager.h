#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface AttributionManager : NSObject

+ (instancetype)sharedManager;
- (void)configure;
- (void)logEvent:(NSString *)name values:(NSDictionary<NSString *, id> *)values;
- (void)handleOpenURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options;
- (BOOL)continueUserActivity:(NSUserActivity *)userActivity
          restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler;

@end
