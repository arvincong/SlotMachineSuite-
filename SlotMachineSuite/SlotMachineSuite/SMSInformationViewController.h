#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SMSInformationViewController : UIViewController
+ (instancetype)rulesControllerWithBet:(NSInteger)bet jackpot:(NSInteger)jackpot;
+ (instancetype)privacyController;
+ (instancetype)aboutController;
@end

NS_ASSUME_NONNULL_END
