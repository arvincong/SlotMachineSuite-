#import "SMSInformationViewController.h"
#import "SlotGame.h"
#import "SMSGameRules.h"

@interface SMSInformationViewController ()
@property (nonatomic, copy) NSString *informationText;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *links;
@end

@implementation SMSInformationViewController

+ (instancetype)controllerWithTitle:(NSString *)title text:(NSString *)text links:(NSArray *)links {
    SMSInformationViewController *controller = [self new];
    controller.title = title;
    controller.informationText = text;
    controller.links = links;
    return controller;
}

+ (NSString *)bundleString:(NSString *)key {
    id value = [NSBundle.mainBundle objectForInfoDictionaryKey:key];
    return [value isKindOfClass:NSString.class]
        ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
}

+ (NSURL *)validatedHTTPSURL:(NSString *)string {
    NSURL *url = [NSURL URLWithString:string];
    return [url.scheme.lowercaseString isEqual:@"https"] && url.host.length && !url.user && !url.password ? url : nil;
}

+ (NSArray *)supportLinksIncludingPolicy:(BOOL)includePolicy {
    NSMutableArray *links = [NSMutableArray array];
    NSString *policy = [self bundleString:@"SMSPrivacyPolicyURL"];
    if (includePolicy && [self validatedHTTPSURL:policy])
        [links addObject:@{@"title": @"Open full privacy policy", @"url": policy}];
    NSString *support = [self bundleString:@"SMSSupportURL"];
    if ([self validatedHTTPSURL:support])
        [links addObject:@{@"title": @"Contact support", @"url": support}];
    NSString *email = [self bundleString:@"SMSSupportEmail"];
    NSCharacterSet *forbidden = [NSCharacterSet characterSetWithCharactersInString:@"\r\n ?&#"];
    if ([email containsString:@"@"] && [email rangeOfCharacterFromSet:forbidden].location == NSNotFound) {
        NSURLComponents *components = [NSURLComponents new];
        components.scheme = @"mailto";
        components.path = email;
        components.queryItems = @[[NSURLQueryItem queryItemWithName:@"subject" value:@"Slot Machine Suite support"]];
        if (components.URL) [links addObject:@{@"title": @"Email support", @"url": components.URL.absoluteString}];
    }
    return links;
}

+ (instancetype)rulesControllerWithBet:(NSInteger)bet jackpot:(NSInteger)jackpot {
    NSMutableString *text = [NSMutableString stringWithString:
        @"Virtual coins only\nThis is a simulated slot game. Coins are free, have no monetary value and cannot be purchased, transferred or redeemed for cash or prizes. There are no real-money wagers.\n\n"
         "How to play\nChoose a total bet, then tap Spin. One bet covers all five paylines. A spin costs that bet once. You can change the bet only between spins. If your balance is too low, lower the bet or choose Add free coins in Settings.\n\n"
         "Line wins\nSymbols must match from the leftmost reel across at least three consecutive reels on a payline. Only the highest-paying match on each line is paid. Wins from different lines are added. WILD substitutes for ordinary symbols, but never for BONUS. A run of WILDs can also pay as WILD. BONUS does not pay as an ordinary line symbol.\n\n"
         "Payout formula\nLine win = total bet × symbol multiplier × matching reels ÷ 5, rounded down to whole coins. The amounts below are per winning line for the selected total bet.\n\n"];
    [text appendFormat:@"Selected total bet: %@ coins\n\n", [self number:bet]];
    for (SlotSymbol *symbol in SlotSymbol.allSymbols) {
        if (symbol.type == SlotSymbolTypeBonus) continue;
        [text appendFormat:@"%@ · multiplier %ld\n3 reels: %@   4 reels: %@   5 reels: %@\n\n",
            symbol.title, (long)symbol.payoutMultiplier,
            [self number:SMSLinePayout((int)symbol.type, 3, bet)],
            [self number:SMSLinePayout((int)symbol.type, 4, bet)],
            [self number:SMSLinePayout((int)symbol.type, 5, bet)]];
    }
    [text appendString:@"Five paylines\nRows are numbered 1 (top), 2 (middle) and 3 (bottom), read left to right.\nTop: 1–1–1–1–1\nMiddle: 2–2–2–2–2\nBottom: 3–3–3–3–3\nRise: 3–2–1–2–3\nDip: 1–2–3–2–1\n\n"
        "BONUS scatter\nFour or more BONUS symbols anywhere on the final 5 × 3 board award total bet × BONUS count × 4. Scatter wins are added to line wins.\n\n"
        "Jackpot\nSeven or more BONUS symbols on the final board also award the current jackpot pool. There is no separate hidden jackpot draw. Each accepted spin adds the greater of 25 coins or 5% of its bet (rounded down) to the pool before evaluation. After a jackpot win, the pool resets to 1,250,000 coins.\n\n"];
    [text appendFormat:@"Pool before the next spin: %@ coins.\n\n", [self number:jackpot]];
    [text appendString:@"Random outcomes\nReels use weighted random symbols. Displayed payouts describe rewards, not the chance of winning. Earlier wins or losses do not guarantee a future result. Balance, pool and individual awards are capped at 1 trillion virtual coins.\n\n"
        "Saved progress\nBalance, bet, spin count, jackpot and final board are saved on this device. A spin result is saved before its animation; leaving the app does not reroll it. Add free coins preserves your progress. Reset game progress starts a new local game and requires confirmation. Deleting the app may remove local progress. There is no cloud sync."];
    return [self controllerWithTitle:@"Rules & payouts" text:text links:@[]];
}

+ (NSString *)number:(int64_t)value {
    return [NSNumberFormatter localizedStringFromNumber:@(value) numberStyle:NSNumberFormatterDecimalStyle];
}

+ (instancetype)privacyController {
    NSString *developer = [self bundleString:@"SMSDeveloperName"];
    NSString *operator = developer.length ? developer : @"The developer identified on this app’s App Store listing";
    NSString *text = [NSString stringWithFormat:
        @"Privacy notice\n%@ operates this app.\n\n"
         "Local game data\nThe native game saves your virtual coin balance, bet, spin count, jackpot and board in app storage on this device. No account is required for the native game. This game save is not sent to a game server by the native game code. Reset game progress replaces that save; uninstalling the app may remove local app data.\n\n"
         "Remote configuration\nThe app uses Statsig to request configuration at launch. The SDK may process app and device information, an SDK-generated identifier, network information, diagnostics and configuration exposure events. Native game play does not require you to allow advertising tracking.\n\n"
         "Attribution services\nDepending on the active configuration, Adjust and AppsFlyer may be initialized to measure installs, sessions and app events. These services may process device, network and attribution information under their own policies. App Tracking Transparency controls permission for tracking and access to the advertising identifier. You can change this permission in iOS Settings.\n\n"
         "Web content\nSome configurations open a web experience. The website receives normal web requests and may use cookies or its own storage and services. The app can provide app, device and authorized attribution information to that experience. Review the website’s own privacy information before providing personal data.\n\n"
         "Retention and choices\nLocal game data remains until it is reset or removed. Configuration and SDK caches can remain until the app removes them or app data is deleted. Resetting the game does not delete records held by third-party services. Server retention and privacy requests are governed by the published privacy policy and the relevant service policies.\n\n"
         "Contact\nUse the support options below or the developer contact listed on the App Store for privacy questions. The published privacy policy provides the developer’s full collection, retention and request details.", operator];
    return [self controllerWithTitle:@"Privacy" text:text links:[self supportLinksIncludingPolicy:YES]];
}

+ (instancetype)aboutController {
    NSString *version = [self bundleString:@"CFBundleShortVersionString"];
    NSString *build = [self bundleString:@"CFBundleVersion"];
    NSString *text = [NSString stringWithFormat:
        @"Starlight\nSlot Machine Suite\nVersion %@ (%@)\n\n"
         "A virtual-coin slot game with five paylines, WILD symbols and BONUS scatter rewards.\n\n"
         "Coins are free and have no real-world value. There are no deposits, withdrawals, cash prizes or purchases in the native game.\n\n"
         "Your game progress stays on this device. Add free coins or reset your progress through Settings. Resetting does not change iOS tracking permission or erase records held by third-party services.\n\n"
         "For help, use the support options below or the developer’s contact on the App Store listing.", version, build];
    return [self controllerWithTitle:@"About & support" text:text links:[self supportLinksIncludingPolicy:NO]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIColor *background = [UIColor colorWithRed:0.07 green:0.07 blue:0.15 alpha:1];
    self.view.backgroundColor = background;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self action:@selector(close)];
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    UITextView *text = [UITextView new];
    text.editable = NO;
    text.selectable = YES;
    text.backgroundColor = background;
    text.textColor = UIColor.whiteColor;
    text.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    text.adjustsFontForContentSizeCategory = YES;
    text.textContainerInset = UIEdgeInsetsMake(16, 12, 20, 12);
    text.text = self.informationText;
    text.accessibilityIdentifier = @"informationText";
    [stack addArrangedSubview:text];
    for (NSUInteger index = 0; index < self.links.count; index++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:self.links[index][@"title"] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        button.titleLabel.adjustsFontForContentSizeCategory = YES;
        button.titleLabel.numberOfLines = 0;
        button.titleLabel.textAlignment = NSTextAlignmentCenter;
        button.tintColor = [UIColor colorWithRed:1 green:0.9 blue:0.3 alpha:1];
        button.tag = (NSInteger)index;
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
        [button addTarget:self action:@selector(openLink:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:button];
    }
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-12],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12]
    ]];
}

- (void)openLink:(UIButton *)sender {
    if (sender.tag < 0 || (NSUInteger)sender.tag >= self.links.count) return;
    NSURL *url = [NSURL URLWithString:self.links[(NSUInteger)sender.tag][@"url"]];
    if (!url) return;
    __weak typeof(self) weakSelf = self;
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
        if (success) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            SMSInformationViewController *self = weakSelf;
            if (!self || !self.view.window || self.presentedViewController) return;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Unable to open link"
                message:@"Check your connection or contact the developer using the App Store listing."
                preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
