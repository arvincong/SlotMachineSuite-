#import <Foundation/Foundation.h>
#import "SMSApplePayAPI.h"
#import "SMSApplePayStore.h"

static void Check(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}
static NSData *Data(NSString *text) { return [text dataUsingEncoding:NSUTF8StringEncoding]; }
static NSDictionary *Record(NSString *key, NSString *state) {
    return @{@"key": key, @"state": state, @"orderNo": @"order-1", @"productID": @"test.coins",
             @"amount": @"4.99", @"userID": @"user-a", @"baseURL": @"https://api.example.com/"};
}
int main(void) {
    @autoreleasepool {
        Check([SMSApplePayAPI isVerificationSuccessData:Data(@"  OK\n") statusCode:200], @"bare ok");
        Check([SMSApplePayAPI isVerificationSuccessData:Data(@"{\"status\":0,\"data\":\"ok\"}") statusCode:201], @"wrapped ok");
        Check([SMSApplePayAPI isVerificationSuccessData:Data(@"{\"status\":\"0\",\"data\":\" OK \"}") statusCode:200], @"string zero TS compatibility");
        for (NSString *text in @[@"", @"<html>ok</html>", @"{\"success\":true}", @"{\"data\":\"ok\"}",
                                 @"{\"status\":1,\"data\":\"ok\"}", @"{\"status\":0,\"data\":{}}",
                                 @"{\"status\":false,\"data\":\"ok\"}", @"{\"status\":null,\"data\":\"ok\"}",
                                 @"[0,\"ok\"]", @"\"ok\""]) {
            Check(![SMSApplePayAPI isVerificationSuccessData:Data(text) statusCode:200], @"reject ambiguous acknowledgement");
        }
        Check(![SMSApplePayAPI isVerificationSuccessData:Data(@"ok") statusCode:500], @"reject HTTP failure");
        Check(![SMSApplePayAPI isVerificationSuccessData:Data(@"ok") statusCode:302], @"reject redirect");
        Check([SMSApplePayCanonicalBaseURL([NSURL URLWithString:@"https://API.example.com:443"]).absoluteString
               isEqual:@"https://api.example.com/"], @"canonical HTTPS origin");
        for (NSString *text in @[@"http://api.example.com", @"https://u:p@api.example.com", @"https://api.example.com/api",
                                 @"https://api.example.com/?x=1", @"https://api.example.com/#fragment"]) {
            Check(!SMSApplePayCanonicalBaseURL([NSURL URLWithString:text]), @"reject invalid API root");
        }
        Check(![[SMSApplePayAPI alloc] initWithBaseURL:[NSURL URLWithString:@"https://api.example.com"]
                                               userID:@"a" token:@"bad\ntoken" deviceTrack:@"" gameVersion:@"1"], @"reject header injection");
        NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        NSURL *file = [root URLByAppendingPathComponent:@"orders.json"];
        SMSApplePayStore *store = [[SMSApplePayStore alloc] initWithFileURL:file];
        Check(!store.loadError && store.allRecords.count == 0, @"first launch missing file");
        NSError *error = nil;
        Check([store saveRecord:Record(@"key-1", @"submitted") error:&error], @"persist before charge");
        SMSApplePayStore *restarted = [[SMSApplePayStore alloc] initWithFileURL:file];
        Check(!restarted.loadError && restarted.allRecords.count == 1, @"recover across process restart");
        Check([restarted saveRecord:Record(@"key-1", @"verified") error:&error] && restarted.allRecords.count == 1,
              @"update the same order without duplicate queue entries");
        Check(![restarted saveRecord:@{@"key": @"broken"} error:&error], @"reject incomplete record");
        Check([[restarted recordForKey:@"key-1"][@"state"] isEqual:@"verified"], @"failed save leaves original snapshot");
        // Leave deliberately corrupt data untouched; never reset a payment journal silently.
        Check([Data(@"broken json") writeToURL:file atomically:YES], @"prepare damaged log");
        SMSApplePayStore *corrupt = [[SMSApplePayStore alloc] initWithFileURL:file];
        Check(corrupt.loadError != nil && ![corrupt saveRecord:Record(@"key-2", @"submitted") error:&error], @"corruption blocks charge");
        Check([[NSData dataWithContentsOfURL:file] isEqual:Data(@"broken json")], @"preserve damaged log");
        // An unwritable destination must not mutate the in-memory queue.
        NSURL *parentFile = [root URLByAppendingPathComponent:@"not-a-directory"];
        Check([Data(@"x") writeToURL:parentFile atomically:YES], @"prepare failing destination");
        SMSApplePayStore *failing = [[SMSApplePayStore alloc] initWithFileURL:[root URLByAppendingPathComponent:@"other.json"]];
        [failing setValue:[parentFile URLByAppendingPathComponent:@"orders.json"] forKey:@"fileURL"];
        Check(![failing saveRecord:Record(@"key-3", @"submitted") error:&error] && failing.allRecords.count == 0,
              @"write failure never authorizes payment");
        [NSFileManager.defaultManager removeItemAtURL:root error:nil];
        NSLog(@"PASS: Apple Pay protocol and durable-order checks");
    }
    return 0;
}
