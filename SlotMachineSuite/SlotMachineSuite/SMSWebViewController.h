#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// ARC container for a validated configuration supplied on the main thread.
/// Keys: url (HTTPS), allowed_hosts (exact hosts), query_params (string pairs), title (optional).
/// The router must install this controller in a UINavigationController.
@interface SMSWebViewController : UIViewController

- (instancetype)initWithConfiguration:(NSDictionary<NSString *, id> *)configuration NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                       bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
