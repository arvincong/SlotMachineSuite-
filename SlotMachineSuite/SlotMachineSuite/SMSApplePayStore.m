#import "SMSApplePayStore.h"
#import "SMSApplePayAPI.h"

@interface SMSApplePayStore ()
@property (nonatomic, copy) NSURL *fileURL;
@property (nonatomic, copy) NSDictionary<NSString *, NSDictionary *> *records;
@property (nonatomic, strong, nullable) NSError *loadError;
@end

@implementation SMSApplePayStore
- (instancetype)initWithFileURL:(NSURL *)fileURL {
    self = [super init];
    if (!self) return nil;
    _fileURL = [fileURL copy]; _records = @{};
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:&error];
    if (!data) {
        if (!([error.domain isEqual:NSCocoaErrorDomain] && error.code == NSFileReadNoSuchFileError)) _loadError = error;
        return self;
    }
    id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    NSDictionary *records = [root isKindOfClass:NSDictionary.class] ? root[@"records"] : nil;
    BOOL valid = [root isKindOfClass:NSDictionary.class] && [root[@"version"] isEqual:@1] &&
                 [records isKindOfClass:NSDictionary.class];
    if (valid) {
        for (NSString *key in records) {
            if (![self isValidRecord:records[key]] || ![records[key][@"key"] isEqual:key]) { valid = NO; break; }
        }
    }
    if (valid) _records = [records copy];
    else _loadError = error ?: SMSApplePayError(30, @"支付订单日志损坏，请保留文件并排查，暂不允许新支付。");
    return self;
}

- (BOOL)isValidRecord:(id)record {
    if (![record isKindOfClass:NSDictionary.class]) return NO;
    for (NSString *key in @[@"key", @"orderNo", @"productID", @"amount", @"userID", @"baseURL", @"state"]) {
        if (!SMSApplePayString(record[key]).length) return NO;
    }
    return [@[@"created", @"submitted", @"deferred", @"purchased", @"verified", @"finished", @"failed", @"cancelled"]
            containsObject:record[@"state"]];
}
- (NSArray<NSDictionary<NSString *, id> *> *)allRecords { return self.records.allValues; }
- (NSDictionary<NSString *, id> *)recordForKey:(NSString *)key { return self.records[key]; }

- (BOOL)saveRecord:(NSDictionary<NSString *, id> *)record error:(NSError **)error {
    if (self.loadError || ![self isValidRecord:record]) {
        if (error) *error = self.loadError ?: SMSApplePayError(31, @"支付订单字段不完整。");
        return NO;
    }
    NSMutableDictionary *next = [self.records mutableCopy];
    next[record[@"key"]] = [record copy];
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"version": @1, @"records": next} options:0 error:error];
    if (!data) return NO;
    NSURL *directory = [self.fileURL URLByDeletingLastPathComponent];
    if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES
                                               attributes:nil error:error]) return NO;
    if (![data writeToURL:self.fileURL options:NSDataWritingAtomic error:error]) return NO;
    self.records = [next copy];
    return YES;
}
@end
