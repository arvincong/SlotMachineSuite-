#import "SMSApplePayManager.h"
#import "SMSApplePayStore.h"
#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

NSNotificationName const SMSApplePayStatusNotification = @"SMSApplePayStatusNotification";

@interface SMSApplePayManager () <SKPaymentTransactionObserver, SKProductsRequestDelegate, SKRequestDelegate>
@property (nonatomic, strong) SMSApplePayStore *store;
@property (nonatomic, strong, nullable) SMSApplePayAPI *api;
@property (nonatomic, strong, nullable) SKProductsRequest *productRequest;
@property (nonatomic, copy, nullable) void (^productCompletion)(NSArray<SKProduct *> *, NSError * _Nullable);
@property (nonatomic, strong, nullable) SKReceiptRefreshRequest *receiptRequest;
@property (nonatomic, strong) NSMutableSet<NSString *> *verifying;
@property (nonatomic, copy, nullable) NSString *purchaseRequestKey;
@property (nonatomic) BOOL started;
@property (nonatomic) BOOL restoring;
@property (nonatomic) BOOL receiptRefreshAttempted;
@property (nonatomic, copy, nullable) NSDictionary *restoreScope;
@end

@implementation SMSApplePayManager
+ (instancetype)sharedManager {
    static SMSApplePayManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [SMSApplePayManager new]; });
    return manager;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        NSURL *root = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                                          inDomains:NSUserDomainMask].firstObject;
        NSURL *file = [root URLByAppendingPathComponent:@"SMSApplePay/orders-v1.json"];
        _store = [[SMSApplePayStore alloc] initWithFileURL:file];
        _verifying = [NSMutableSet set];
    }
    return self;
}
- (void)start {
    NSAssert(NSThread.isMainThread, @"Apple Pay must run on main thread");
    if (self.started) return;
    self.started = YES;
    // A created order has never reached addPayment; an interrupted product lookup is safe to retry.
    for (NSDictionary *record in self.store.allRecords) {
        if ([record[@"state"] isEqual:@"created"]) {
            NSMutableDictionary *interrupted = [record mutableCopy];
            interrupted[@"state"] = @"failed";
            [self save:interrupted];
        }
    }
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationActive:)
                                               name:UIApplicationDidBecomeActiveNotification object:nil];
    [SKPaymentQueue.defaultQueue addTransactionObserver:self];
}
- (void)applicationActive:(NSNotification *)notification { [self retryPendingPurchases]; }

- (BOOL)configureWithBaseURL:(NSURL *)baseURL userID:(NSString *)userID token:(NSString *)token
               deviceTrack:(NSString *)deviceTrack gameVersion:(NSString *)gameVersion error:(NSError **)error {
    NSAssert(NSThread.isMainThread, @"Apple Pay must run on main thread");
    SMSApplePayAPI *api = [[SMSApplePayAPI alloc] initWithBaseURL:baseURL userID:userID token:token
                                                 deviceTrack:deviceTrack gameVersion:gameVersion];
    if (!api) {
        if (error) *error = SMSApplePayError(1, @"需要有效的 HTTPS API 根地址、用户 ID 和 token。");
        return NO;
    }
    self.api = api;
    [self start];
    [self retryPendingPurchases];
    return YES;
}
- (void)clearSession {
    NSAssert(NSThread.isMainThread, @"Apple Pay must run on main thread");
    self.api = nil;
}
- (BOOL)hasSessionForUser:(NSString *)userID baseURL:(NSString *)baseURL {
    NSURL *canonical = SMSApplePayCanonicalBaseURL([NSURL URLWithString:baseURL ?: @""]);
    return self.api && [self.api.userID isEqual:userID] && [self.api.baseURL isEqual:canonical];
}
- (BOOL)isCurrentRecord:(NSDictionary *)record {
    return [self hasSessionForUser:record[@"userID"] baseURL:record[@"baseURL"]];
}
- (void)emit:(NSString *)status record:(nullable NSDictionary *)record message:(NSString *)message {
    NSMutableDictionary *event = [@{@"status": status, @"msg": message ?: @""} mutableCopy];
    for (NSString *key in @[@"orderNo", @"productID", @"amount", @"transactionIdentifier", @"userID", @"baseURL"]) {
        if (record[key]) event[key] = record[key];
    }
    if (!record && self.api) { event[@"userID"] = self.api.userID; event[@"baseURL"] = self.api.baseURL.absoluteString; }
    event[@"verified"] = @([status isEqual:@"verified"]);
    [NSNotificationCenter.defaultCenter postNotificationName:SMSApplePayStatusNotification object:self userInfo:event];
}
- (BOOL)save:(NSDictionary *)record {
    NSError *error = nil;
    if ([self.store saveRecord:record error:&error]) return YES;
    [self emit:@"storage_error" record:record message:error.localizedDescription];
    return NO;
}
- (BOOL)isUnresolved:(NSDictionary *)record {
    return ![@[@"finished", @"failed", @"cancelled"] containsObject:record[@"state"]];
}
- (NSArray<NSDictionary *> *)pendingOrders {
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *record in self.store.allRecords) {
        if ([self isCurrentRecord:record] && [self isUnresolved:record]) {
            NSMutableDictionary *item = [record mutableCopy];
            [item removeObjectForKey:@"key"];
            [result addObject:item];
        }
    }
    return result;
}

#pragma mark - Product query and purchase
- (void)fetchStoreProducts:(NSArray<NSString *> *)identifiers
               completion:(void (^)(NSArray<SKProduct *> *, NSError * _Nullable))completion {
    if (self.productRequest) { completion(@[], SMSApplePayError(2, @"商品查询正在进行，请稍后重试。")); return; }
    if (!identifiers.count) { completion(@[], SMSApplePayError(3, @"商品 ID 不能为空。")); return; }
    for (id identifier in identifiers) {
        if (!SMSApplePayString(identifier).length) { completion(@[], SMSApplePayError(3, @"商品 ID 无效。")); return; }
    }
    self.productCompletion = completion;
    self.productRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:identifiers]];
    self.productRequest.delegate = self;
    SKProductsRequest *request = self.productRequest;
    [request start];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (self.productRequest != request) return;
        [request cancel];
        void (^callback)(NSArray<SKProduct *> *, NSError *) = self.productCompletion;
        self.productRequest = nil; self.productCompletion = nil;
        if (callback) callback(@[], SMSApplePayError(5, @"苹果商品查询超时，请稍后重试。"));
    });
}
- (void)fetchProducts:(NSArray<NSString *> *)productIDs
          completion:(void (^)(NSArray<NSDictionary *> *, NSError * _Nullable))completion {
    NSAssert(NSThread.isMainThread, @"Apple Pay must run on main thread");
    [self fetchStoreProducts:productIDs completion:^(NSArray<SKProduct *> *products, NSError *error) {
        NSMutableArray *items = [NSMutableArray array];
        for (SKProduct *product in products) {
            NSNumberFormatter *formatter = [NSNumberFormatter new];
            formatter.numberStyle = NSNumberFormatterCurrencyStyle; formatter.locale = product.priceLocale;
            [items addObject:@{@"productID": product.productIdentifier, @"title": product.localizedTitle,
                               @"price": product.price.stringValue, @"displayPrice": [formatter stringFromNumber:product.price] ?: @"",
                               @"currencyCode": [product.priceLocale objectForKey:NSLocaleCurrencyCode] ?: @""}];
        }
        completion(items, error);
    }];
}
- (void)purchaseProduct:(NSString *)productID orderNo:(NSString *)orderNo amount:(NSString *)amount {
    NSAssert(NSThread.isMainThread, @"Apple Pay must run on main thread");
    [self start];
    NSDictionary *attempt = @{@"productID": SMSApplePayString(productID), @"orderNo": SMSApplePayString(orderNo),
                              @"amount": SMSApplePayString(amount), @"userID": self.api.userID ?: @"",
                              @"baseURL": self.api.baseURL.absoluteString ?: @""};
    NSDecimalNumber *number = [NSDecimalNumber decimalNumberWithString:SMSApplePayString(amount)
                                                              locale:@{NSLocaleDecimalSeparator: @"."}];
    BOOL validAmount = SMSApplePayString(amount).length <= 32 &&
        [SMSApplePayString(amount) rangeOfString:@"^[0-9]+(\\.[0-9]+)?$" options:NSRegularExpressionSearch].location != NSNotFound;
    if (!self.api || !SMSApplePayString(productID).length || !SMSApplePayString(orderNo).length || !validAmount ||
        [number isEqual:NSDecimalNumber.notANumber] || [number compare:NSDecimalNumber.zero] != NSOrderedDescending) {
        [self emit:@"failed" record:attempt message:@"请先配置登录会话，并传入商品 ID、业务订单号和正数金额字符串。"]; return;
    }
    if (self.store.loadError) { [self emit:@"storage_error" record:attempt message:self.store.loadError.localizedDescription]; return; }
    if (![SKPaymentQueue canMakePayments]) { [self emit:@"failed" record:attempt message:@"此设备不允许内购。"]; return; }
    if (self.productRequest || self.restoring || self.purchaseRequestKey) {
        [self emit:@"busy" record:attempt message:@"支付或商品查询正在进行，请稍后重试。"]; return;
    }
    for (NSDictionary *record in self.store.allRecords) {
        BOOL sameOrder = [self isCurrentRecord:record] && [record[@"orderNo"] isEqual:orderNo];
        if (sameOrder && [record[@"state"] isEqual:@"cancelled"]) {
            [self emit:@"failed" record:attempt message:@"该业务订单已作废，请重新创建业务订单。"]; return;
        }
        if (sameOrder && [record[@"state"] isEqual:@"finished"]) {
            [self emit:@"verified" record:record message:@"该订单已验单，请刷新业务余额。"]; return;
        }
        if ([self isCurrentRecord:record] && [self isUnresolved:record]) {
            [self emit:@"busy" record:attempt message:@"当前账号存在未完成订单，请先补单；若没有苹果交易，需要服务端对账后通过原生接口解除订单。"];
            [self retryPendingPurchases]; return;
        }
    }
    NSMutableDictionary *record = [attempt mutableCopy];
    NSString *key = NSUUID.UUID.UUIDString;
    record[@"key"] = key; record[@"state"] = @"created";
    if (![self save:record]) return;
    self.purchaseRequestKey = key;
    [self emit:@"loading_product" record:record message:@""];
    [self fetchStoreProducts:@[productID] completion:^(NSArray<SKProduct *> *products, NSError *error) {
        self.purchaseRequestKey = nil;
        NSMutableDictionary *latest = [[self.store recordForKey:key] mutableCopy];
        SKProduct *product = products.firstObject;
        if (error || !product || ![product.productIdentifier isEqual:productID] || ![self isCurrentRecord:latest]) {
            latest[@"state"] = @"failed";
            if ([self save:latest]) [self emit:@"failed" record:latest message:error.localizedDescription ?: @"商品不存在或登录会话已改变。"]; return;
        }
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        // Opaque persisted order key; never embed a token or plaintext user ID here.
        payment.applicationUsername = key; payment.quantity = 1;
        latest[@"state"] = @"submitted";
        if (![self save:latest]) return;
        [SKPaymentQueue.defaultQueue addPayment:payment];
        [self emit:@"purchasing" record:latest message:@""];
    }];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (request != self.productRequest) return;
        void (^completion)(NSArray<SKProduct *> *, NSError *) = self.productCompletion;
        self.productRequest = nil; self.productCompletion = nil;
        NSError *error = response.invalidProductIdentifiers.count
            ? SMSApplePayError(4, @"存在无效商品 ID，请核对 App Store Connect 配置。") : nil;
        if (completion) completion(response.products, error);
    });
}

#pragma mark - Transaction observation and recovery
- (nullable NSDictionary *)recordForTransaction:(SKPaymentTransaction *)transaction {
    NSString *username = transaction.payment.applicationUsername ?: transaction.originalTransaction.payment.applicationUsername;
    NSDictionary *record = username.length ? [self.store recordForKey:username] : nil;
    if (!record) {
        NSString *identifier = transaction.originalTransaction.transactionIdentifier ?: transaction.transactionIdentifier;
        for (NSDictionary *item in self.store.allRecords) {
            if (identifier.length && [item[@"transactionIdentifier"] isEqual:identifier]) { record = item; break; }
        }
    }
    if (![record[@"productID"] isEqual:transaction.payment.productIdentifier]) return nil;
    // Never rebind a second purchased transaction to an existing business order.
    NSString *knownID = record[@"transactionIdentifier"];
    if (transaction.transactionState != SKPaymentTransactionStateRestored && knownID.length &&
        transaction.transactionIdentifier.length && ![knownID isEqual:transaction.transactionIdentifier]) return nil;
    return record;
}
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SKPaymentTransaction *transaction in transactions) [self processTransaction:transaction];
    });
}
- (void)processTransaction:(SKPaymentTransaction *)transaction {
    NSDictionary *record = [self recordForTransaction:transaction];
    if (transaction.transactionState == SKPaymentTransactionStateFailed) {
        if (record) {
            NSMutableDictionary *failed = [record mutableCopy]; failed[@"state"] = @"failed";
            if (![self save:failed]) return;
            BOOL cancelled = [transaction.error.domain isEqual:SKErrorDomain] && transaction.error.code == SKErrorPaymentCancelled;
            [self emit:cancelled ? @"cancelled" : @"failed" record:failed message:transaction.error.localizedDescription ?: @"支付失败。"];
        }
        [SKPaymentQueue.defaultQueue finishTransaction:transaction];
        return;
    }
    if (transaction.transactionState == SKPaymentTransactionStatePurchasing) return;
    if (!record) {
        // StoreKit may omit applicationUsername after restoration/reinstall. Guessing by amount/product
        // can associate a receipt with the wrong order; retain it for explicit business reconciliation.
        [self emit:@"unassociated" record:nil message:@"苹果交易没有可核实的本地订单关联，已保留，请联系业务服务端对账。"];
        return;
    }
    if (transaction.transactionState == SKPaymentTransactionStateDeferred) {
        NSMutableDictionary *deferred = [record mutableCopy]; deferred[@"state"] = @"deferred";
        if ([self save:deferred]) [self emit:@"deferred" record:deferred message:@"等待家长或付款批准，请勿重复支付。"];
        return;
    }
    if (transaction.transactionState != SKPaymentTransactionStatePurchased &&
        transaction.transactionState != SKPaymentTransactionStateRestored) return;
    if ([record[@"state"] isEqual:@"finished"]) {
        [SKPaymentQueue.defaultQueue finishTransaction:transaction];
        return;
    }
    if ([record[@"state"] isEqual:@"verified"]) { [self finishVerifiedTransaction:transaction record:record]; return; }
    NSMutableDictionary *purchased = [record mutableCopy];
    NSString *identifier = transaction.originalTransaction.transactionIdentifier ?: transaction.transactionIdentifier;
    if (!identifier.length) { [self emit:@"pending_verification" record:record message:@"等待苹果交易 ID。"]; return; }
    purchased[@"transactionIdentifier"] = identifier; purchased[@"state"] = @"purchased";
    if (![self save:purchased] || ![self isCurrentRecord:purchased]) return;
    [self verifyTransaction:transaction record:purchased];
}
- (void)retryPendingPurchases {
    NSAssert(NSThread.isMainThread, @"Apple Pay must run on main thread");
    if (!self.api || self.store.loadError) return;
    for (SKPaymentTransaction *transaction in SKPaymentQueue.defaultQueue.transactions) {
        if (transaction.transactionState == SKPaymentTransactionStatePurchased ||
            transaction.transactionState == SKPaymentTransactionStateRestored ||
            transaction.transactionState == SKPaymentTransactionStateFailed ||
            transaction.transactionState == SKPaymentTransactionStateDeferred) [self processTransaction:transaction];
    }
    // A process can stop between finishTransaction and recording finished. Verified means the
    // server already acknowledged, so a missing StoreKit transaction can safely close the log.
    for (NSDictionary *record in self.store.allRecords) {
        if (![record[@"state"] isEqual:@"verified"]) continue;
        BOOL queued = NO;
        for (SKPaymentTransaction *transaction in SKPaymentQueue.defaultQueue.transactions) {
            if ([[self recordForTransaction:transaction][@"key"] isEqual:record[@"key"]]) { queued = YES; break; }
        }
        if (!queued) {
            NSMutableDictionary *finished = [record mutableCopy]; finished[@"state"] = @"finished";
            if ([self save:finished]) [self emit:@"verified" record:finished message:@"验单已确认，请刷新业务余额。"];
        }
    }
}
- (NSString *)receipt {
    NSURL *url = NSBundle.mainBundle.appStoreReceiptURL;
    NSData *data = url ? [NSData dataWithContentsOfURL:url] : nil;
    return data.length ? [data base64EncodedStringWithOptions:0] : @"";
}
- (void)verifyTransaction:(SKPaymentTransaction *)transaction record:(NSDictionary *)record {
    NSString *identifier = record[@"transactionIdentifier"];
    if ([self.verifying containsObject:identifier]) return;
    NSString *receipt = [self receipt];
    if (!receipt.length) {
        [self emit:@"pending_verification" record:record message:@"苹果凭证尚未就绪，交易已保留。"];
        // Receipt refresh can show an Apple login prompt; only attempt in the foreground, once per launch.
        if (!self.receiptRequest && !self.receiptRefreshAttempted &&
            UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
            self.receiptRefreshAttempted = YES;
            self.receiptRequest = [[SKReceiptRefreshRequest alloc] initWithReceiptProperties:nil];
            self.receiptRequest.delegate = self; [self.receiptRequest start];
        }
        return;
    }
    SMSApplePayAPI *api = self.api;
    [self.verifying addObject:identifier];
    [self emit:@"verifying" record:record message:@""];
    [api verifyOrder:record[@"orderNo"] amount:record[@"amount"] receipt:receipt completion:^(NSError *error) {
        [self.verifying removeObject:identifier];
        NSDictionary *latest = [self.store recordForKey:record[@"key"]];
        if (error) { [self emit:@"pending_verification" record:latest message:error.localizedDescription]; return; }
        NSMutableDictionary *verified = [latest mutableCopy]; verified[@"state"] = @"verified";
        // Persist acknowledgement before finishing StoreKit; a crash must never trigger a new charge.
        if ([self save:verified]) [self finishVerifiedTransaction:transaction record:verified];
    }];
}
- (void)finishVerifiedTransaction:(SKPaymentTransaction *)transaction record:(NSDictionary *)record {
    [SKPaymentQueue.defaultQueue finishTransaction:transaction];
    NSMutableDictionary *finished = [record mutableCopy]; finished[@"state"] = @"finished";
    if ([self save:finished]) [self emit:@"verified" record:finished message:@"服务端已确认订单，请刷新业务余额。"];
}

#pragma mark - Explicit business reconciliation (native only)
- (NSArray<NSDictionary *> *)unassociatedTransactions {
    NSAssert(NSThread.isMainThread, @"Apple Pay must run on main thread");
    NSMutableArray *items = [NSMutableArray array];
    for (SKPaymentTransaction *transaction in SKPaymentQueue.defaultQueue.transactions) {
        if ([self recordForTransaction:transaction] ||
            (transaction.transactionState != SKPaymentTransactionStatePurchased &&
             transaction.transactionState != SKPaymentTransactionStateRestored)) continue;
        [items addObject:@{@"transactionIdentifier": transaction.transactionIdentifier ?: @"",
                           @"originalTransactionIdentifier": transaction.originalTransaction.transactionIdentifier ?: @"",
                           @"productID": transaction.payment.productIdentifier ?: @""}];
    }
    return items;
}
- (BOOL)associateTransaction:(NSString *)identifier withOrder:(NSString *)orderNo amount:(NSString *)amount error:(NSError **)error {
    NSAssert(NSThread.isMainThread, @"Apple Pay must run on main thread");
    if (!self.api || !SMSApplePayString(identifier).length || !SMSApplePayString(orderNo).length || !SMSApplePayString(amount).length) {
        if (error) *error = SMSApplePayError(40, @"对账关联需要已登录会话、交易 ID、订单号和金额。"); return NO;
    }
    for (SKPaymentTransaction *transaction in SKPaymentQueue.defaultQueue.transactions) {
        if (![transaction.transactionIdentifier isEqual:identifier] &&
            ![transaction.originalTransaction.transactionIdentifier isEqual:identifier]) continue;
        if ([self recordForTransaction:transaction] ||
            (transaction.transactionState != SKPaymentTransactionStatePurchased && transaction.transactionState != SKPaymentTransactionStateRestored)) break;
        NSDictionary *existing = nil;
        for (NSDictionary *record in self.store.allRecords) {
            if ([self isCurrentRecord:record] && [record[@"orderNo"] isEqual:orderNo]) {
                if ([record[@"state"] isEqual:@"failed"]) continue;
                if (existing || ![@[@"created", @"submitted", @"deferred"] containsObject:record[@"state"]] ||
                    [record[@"transactionIdentifier"] length] || ![record[@"productID"] isEqual:transaction.payment.productIdentifier] ||
                    ![record[@"amount"] isEqual:amount]) {
                    if (error) *error = SMSApplePayError(41, @"该业务订单已有支付记录或信息冲突，不能覆盖关联。"); return NO;
                }
                existing = record;
            }
        }
        NSDictionary *record = @{@"key": existing[@"key"] ?: NSUUID.UUID.UUIDString, @"orderNo": orderNo,
                                  @"productID": transaction.payment.productIdentifier, @"amount": amount,
                                  @"userID": self.api.userID, @"baseURL": self.api.baseURL.absoluteString,
                                  @"transactionIdentifier": transaction.originalTransaction.transactionIdentifier ?: identifier,
                                  @"state": @"purchased"};
        if (![self.store saveRecord:record error:error]) return NO;
        [self processTransaction:transaction];
        return YES;
    }
    if (error) *error = SMSApplePayError(42, @"未找到可关联的未完成苹果交易。");
    return NO;
}
- (BOOL)resolveUnsubmittedOrderAfterServerCancellation:(NSString *)orderNo error:(NSError **)error {
    NSAssert(NSThread.isMainThread, @"Apple Pay must run on main thread");
    for (NSDictionary *record in self.store.allRecords) {
        if (![self isCurrentRecord:record] || ![record[@"orderNo"] isEqual:orderNo] ||
            ![@[@"submitted", @"created"] containsObject:record[@"state"]]) continue;
        if ([self.purchaseRequestKey isEqual:record[@"key"]]) break;
        BOOL queued = NO;
        for (SKPaymentTransaction *transaction in SKPaymentQueue.defaultQueue.transactions) {
            if ([[self recordForTransaction:transaction][@"key"] isEqual:record[@"key"]]) { queued = YES; break; }
        }
        if (queued) break;
        NSMutableDictionary *closed = [record mutableCopy]; closed[@"state"] = @"cancelled";
        return [self.store saveRecord:closed error:error];
    }
    if (error) *error = SMSApplePayError(43, @"订单不允许解除：未登录、不匹配或仍存在苹果交易。");
    return NO;
}

#pragma mark - Request failure and restore
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (request == self.productRequest) {
            void (^completion)(NSArray<SKProduct *> *, NSError *) = self.productCompletion;
            self.productRequest = nil; self.productCompletion = nil;
            if (completion) completion(@[], error);
        } else if (request == self.receiptRequest) {
            self.receiptRequest = nil;
            [self emit:@"pending_verification" record:nil message:@"刷新苹果凭证失败，请稍后重试或重启应用。"];
        }
    });
}
- (void)requestDidFinish:(SKRequest *)request {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (request == self.receiptRequest) { self.receiptRequest = nil; [self retryPendingPurchases]; }
    });
}
- (void)restorePurchases {
    NSAssert(NSThread.isMainThread, @"Apple Pay must run on main thread");
    if (!self.api) { [self emit:@"failed" record:nil message:@"恢复购买前请先登录并配置支付会话。"]; return; }
    if (self.restoring || self.productRequest || self.purchaseRequestKey) {
        [self emit:@"busy" record:nil message:@"已有支付请求正在进行。"]; return;
    }
    self.restoring = YES;
    self.restoreScope = @{@"userID": self.api.userID, @"baseURL": self.api.baseURL.absoluteString};
    [SKPaymentQueue.defaultQueue restoreCompletedTransactions];
}
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.restoring = NO;
        [self emit:@"restore_finished" record:self.restoreScope message:@"苹果恢复请求已结束；消耗型充值不在恢复列表中，订单以验单结果为准。"];
        self.restoreScope = nil;
    });
}
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.restoring = NO; [self emit:@"restore_failed" record:self.restoreScope message:error.localizedDescription];
        self.restoreScope = nil;
    });
}
@end
