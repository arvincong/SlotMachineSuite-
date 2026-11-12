#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const SMSApplePayErrorDomain;
FOUNDATION_EXPORT NSError *SMSApplePayError(NSInteger code, NSString *message);
FOUNDATION_EXPORT NSString *SMSApplePayString(id _Nullable value);
/// 规范化 HTTPS 根地址：host 小写、移除默认端口、固定根路径。
FOUNDATION_EXPORT NSURL * _Nullable SMSApplePayCanonicalBaseURL(NSURL * _Nullable url);

/// TS ApiMgr.applePayVerifyReceipt / ApplePayManager 的 OC 对应实现。
/// 不包含 /api/pay/recharge：该接口使用业务 Protobuf，调用方先创建订单。
@interface SMSApplePayAPI : NSObject <NSURLSessionTaskDelegate>
@property (nonatomic, copy, readonly) NSURL *baseURL;
@property (nonatomic, copy, readonly) NSString *userID;
- (nullable instancetype)initWithBaseURL:(NSURL *)baseURL
                                userID:(NSString *)userID
                                 token:(NSString *)token
                           deviceTrack:(NSString *)deviceTrack
                           gameVersion:(NSString *)gameVersion;
/// 仅接受 HTTP 2xx + 裸文本 ok，或 {status:0,data:"ok"}。
+ (BOOL)isVerificationSuccessData:(NSData *)data statusCode:(NSInteger)statusCode;
- (void)verifyOrder:(NSString *)orderNo amount:(NSString *)amount receipt:(NSString *)receipt
        completion:(void (^)(NSError * _Nullable error))completion;
@end

NS_ASSUME_NONNULL_END
