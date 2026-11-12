#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// 订单日志；只持久化业务订单和交易关联，不保存 token 或 receipt。
/// 所有调用在主线程。文件损坏时停止支付，保留原文件供排查。
@interface SMSApplePayStore : NSObject
@property (nonatomic, strong, readonly, nullable) NSError *loadError;
- (instancetype)initWithFileURL:(NSURL *)fileURL;
- (NSArray<NSDictionary<NSString *, id> *> *)allRecords;
- (nullable NSDictionary<NSString *, id> *)recordForKey:(NSString *)key;
/// 先原子写盘，成功后才替换内存快照。
- (BOOL)saveRecord:(NSDictionary<NSString *, id> *)record error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
