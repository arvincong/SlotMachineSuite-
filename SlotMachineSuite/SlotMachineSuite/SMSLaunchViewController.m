#import "SMSLaunchViewController.h"
#import "SMSRemoteConfiguration.h"
#import "SMSWebViewController.h"
#import "SlotMachineViewController.h"
#import "AttributionManager.h"
#import "SlotMachineSuite-Swift.h"

@interface SMSLaunchViewController ()
@property (nonatomic) BOOL requested;
@property (nonatomic) BOOL resolved;
@end

@implementation SMSLaunchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.035 green:0.055 blue:0.14 alpha:1];
    UIImageView *mark = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"LaunchMark"]];
    mark.contentMode = UIViewContentModeScaleAspectFit;
    UILabel *title = [UILabel new];
    title.text = @"STARLIGHT";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.color = UIColor.whiteColor;
    [spinner startAnimating];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[mark, title, spinner]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 20;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [mark.widthAnchor constraintEqualToConstant:164],
        [mark.heightAnchor constraintEqualToConstant:164],
        [stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-35],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16]
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.requested) return;
    self.requested = YES;
    __weak typeof(self) weakSelf = self;
    [[SMSStatsigClient sharedClient] fetchConfigurationWithCompletion:^(NSDictionary<NSString *, id> *values, NSString *source) {
        SMSLaunchViewController *self = weakSelf;
        if (!self || self.resolved) return;
        self.resolved = YES;
        SMSRemoteConfiguration *config = [SMSRemoteConfiguration configurationWithValues:values];
        [[AttributionManager sharedManager] applyRemoteConfiguration:config.attributionConfiguration];
        // Log outcome only; never dump URLs, SDK keys or query parameters.
        NSLog(@"[Launch] source=%@ urlSource=%@ route=%@", source, config.routeSource,
              config.webEnabled ? config.webConfiguration[@"web_type"] : @"native");
        UIViewController *destination = config.webEnabled
            ? [[SMSWebViewController alloc] initWithConfiguration:config.webConfiguration]
            : [SlotMachineViewController new];
        UINavigationController *navigation = self.navigationController;
        if (!navigation) return;
        [navigation setNavigationBarHidden:!config.webEnabled animated:NO];
        [navigation setViewControllers:@[destination] animated:NO];
    }];
}

@end
