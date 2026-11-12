#import "SMSApplePayAPI.h"
#import <CoreFoundation/CoreFoundation.h>

NSString * const SMSApplePayErrorDomain = @"SMSApplePayErrorDomain";
NSError *SMSApplePayError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:SMSApplePayErrorDomain code:code
                          userInfo:@{NSLocalizedDescriptionKey: message}];
}
NSString *SMSApplePayString(id value) {
    return [value isKindOfClass:NSString.class]
        ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
}

NSURL *SMSApplePayCanonicalBaseURL(NSURL *url) {
    if (!url) return nil;
    NSURLComponents *parts = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    if (![parts.scheme.lowercaseString isEqual:@"https"] || !parts.host.length ||
        parts.user || parts.password || parts.query || parts.fragment ||
        (parts.path.length && ![parts.path isEqual:@"/"])) return nil;
    parts.scheme = @"https"; parts.host = parts.host.lowercaseString; parts.path = @"/";
    if ([parts.port isEqual:@443]) parts.port = nil;
    return parts.URL;
}

@interface SMSApplePayAPI ()
@property (nonatomic, copy) NSURL *baseURL;
@property (nonatomic, copy) NSString *userID;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NSString *deviceTrack;
@property (nonatomic, copy) NSString *gameVersion;
@end

@implementation SMSApplePayAPI
- (instancetype)initWithBaseURL:(NSURL *)baseURL userID:(NSString *)userID token:(NSString *)token
                   deviceTrack:(NSString *)deviceTrack gameVersion:(NSString *)gameVersion {
    baseURL = SMSApplePayCanonicalBaseURL(baseURL);
    if (!baseURL || !SMSApplePayString(userID).length || !SMSApplePayString(token).length) return nil;
    for (NSString *header in @[userID, token, deviceTrack, gameVersion]) {
        if ([header rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location != NSNotFound) return nil;
    }
    self = [super init];
    if (self) {
        _baseURL = [baseURL copy]; _userID = [userID copy]; _token = [token copy];
        _deviceTrack = [deviceTrack copy]; _gameVersion = [gameVersion copy];
    }
    return self;
}

+ (BOOL)isVerificationSuccessData:(NSData *)data statusCode:(NSInteger)statusCode {
    if (statusCode < 200 || statusCode >= 300) return NO;
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([SMSApplePayString(text).lowercaseString isEqualToString:@"ok"]) return YES;
    id value = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil];
    if (![value isKindOfClass:NSDictionary.class]) return NO;
    id status = value[@"status"];
    // Match JS status == 0, including the string "0"; missing/null/false is not an acknowledgement.
    BOOL zero = ([status isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)status) != CFBooleanGetTypeID() &&
                 [status doubleValue] == 0) || ([status isKindOfClass:NSString.class] && [status isEqual:@"0"]);
    return zero && [SMSApplePayString(value[@"data"]).lowercaseString isEqualToString:@"ok"];
}

- (void)verifyOrder:(NSString *)orderNo amount:(NSString *)amount receipt:(NSString *)receipt
        completion:(void (^)(NSError *))completion {
    NSURLComponents *parts = [NSURLComponents componentsWithURL:self.baseURL resolvingAgainstBaseURL:NO];
    parts.path = @"/api/third/apple_iap/payin/callback";
    parts.queryItems = @[[NSURLQueryItem queryItemWithName:@"gv" value:self.gameVersion],
                         [NSURLQueryItem queryItemWithName:@"qt_utc" value:
                          [NSString stringWithFormat:@"%.0f", NSDate.date.timeIntervalSince1970 * 1000]]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:parts.URL];
    request.HTTPMethod = @"POST"; request.timeoutInterval = 30;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:self.userID forHTTPHeaderField:@"X-AUTH-USER"];
    [request setValue:self.token forHTTPHeaderField:@"X-AUTH-TOKEN"];
    if (self.deviceTrack.length) [request setValue:self.deviceTrack forHTTPHeaderField:@"X-Auth-Track"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:
                       @{@"order_no": orderNo, @"receipt_data": receipt, @"amount": amount} options:0 error:nil];
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.HTTPCookieStorage = nil;
    configuration.URLCache = nil;
    // One short-lived session per verification; credentials never follow a redirect.
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger code = [response isKindOfClass:NSHTTPURLResponse.class] ? [(NSHTTPURLResponse *)response statusCode] : 0;
        NSError *result = error;
        if (!result && ![SMSApplePayAPI isVerificationSuccessData:data ?: [NSData data] statusCode:code]) {
            result = SMSApplePayError(20, @"服务端尚未确认订单，交易已保留，稍后重试验单。");
        }
        [session finishTasksAndInvalidate];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(result); });
    }] resume];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
 willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    completionHandler(nil);
}
@end
