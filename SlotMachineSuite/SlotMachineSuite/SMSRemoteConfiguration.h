#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Converts untrusted remote values into a single launch decision.
@interface SMSRemoteConfiguration : NSObject
@property (nonatomic, readonly) BOOL webEnabled;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *webConfiguration;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *attributionConfiguration;
+ (instancetype)configurationWithValues:(NSDictionary<NSString *, id> *)values;
@end

NS_ASSUME_NONNULL_END
