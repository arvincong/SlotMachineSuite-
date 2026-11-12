#import <Foundation/Foundation.h>
#import "SMSApplePayAPI.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const SMSApplePayStatusNotification;

/// StoreKit 1 (Objective-C) + TS receipt 验单协议。所有方法与回调均使用主线程。
/// 商品、金额和订单归属最终必须由服务端核对；客户端状态不直接发放金币。
@interface SMSApplePayManager : NSObject
+ (instancetype)sharedManager;
/// App 启动即注册，不能只在充值页面注册交易观察者。
- (void)start;
/// 登录/刷新 token 后更新。凭证只在内存，重启后重新配置才会补单。
- (BOOL)configureWithBaseURL:(NSURL *)baseURL userID:(NSString *)userID token:(NSString *)token
               deviceTrack:(NSString *)deviceTrack gameVersion:(NSString *)gameVersion
                     error:(NSError * _Nullable * _Nullable)error;
- (void)clearSession;
/// 对应 openApplePay，但增加必须的 productID、orderNo 和账号绑定。
/// 先通过业务 /api/pay/recharge 创建订单，再调用此方法。禁止用金额猜测 productID。
- (void)purchaseProduct:(NSString *)productID orderNo:(NSString *)orderNo amount:(NSString *)amount;
- (void)fetchProducts:(NSArray<NSString *> *)productIDs
          completion:(void (^)(NSArray<NSDictionary *> *products, NSError * _Nullable error))completion;
/// 对应 TS ApplePayManager.processLocalQueue。仅处理当前账号、当前 API 地址的交易。
- (void)retryPendingPurchases;
/// StoreKit 恢复只覆盖可恢复商品；消耗型充值补单使用 retryPendingPurchases。
- (void)restorePurchases;
- (NSArray<NSDictionary *> *)pendingOrders;
/// 原生业务对账扩展（不暴露给网页）。返回未关联苹果交易的 ID / 商品信息，不含凭证。
- (NSArray<NSDictionary *> *)unassociatedTransactions;
/// 只有业务服务端核实交易归属、订单及商品后才可调用；不会根据金额/商品猜订单。
- (BOOL)associateTransaction:(NSString *)transactionIdentifier withOrder:(NSString *)orderNo
                     amount:(NSString *)amount error:(NSError * _Nullable * _Nullable)error;
/// 仅在后台和苹果交易对账确认未扣款且业务订单已作废后调用。
/// 不能仅凭本地队列为空调用；Deferred/Purchased 订单不能通过此方法取消。
- (BOOL)resolveUnsubmittedOrderAfterServerCancellation:(NSString *)orderNo
                                               error:(NSError * _Nullable * _Nullable)error;
/// 用于调用方在投递事件前确认账号作用域。
- (BOOL)hasSessionForUser:(NSString *)userID baseURL:(NSString *)baseURL;
@end

NS_ASSUME_NONNULL_END
