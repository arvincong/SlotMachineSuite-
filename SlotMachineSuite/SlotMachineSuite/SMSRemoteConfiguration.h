#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Resolves sticky project + fresh project_url, with a per-project persistent fallback.
@interface SMSRemoteConfiguration : NSObject
@property (nonatomic, readonly) BOOL webEnabled;
@property (nonatomic, copy, readonly) NSString *project;
@property (nonatomic, copy, readonly) NSString *urlKey;
@property (nonatomic, copy, readonly) NSString *routeSource;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *webConfiguration;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *attributionConfiguration;
+ (instancetype)configurationWithValues:(NSDictionary<NSString *, id> *)values;
/// An isolated defaults suite can be supplied by the macOS routing verification harness.
+ (instancetype)configurationWithValues:(NSDictionary<NSString *, id> *)values defaults:(NSUserDefaults *)defaults;
@end

NS_ASSUME_NONNULL_END
