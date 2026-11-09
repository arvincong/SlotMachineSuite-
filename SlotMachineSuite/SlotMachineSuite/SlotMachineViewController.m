#import "SlotMachineViewController.h"
#import "SlotGame.h"
#import "SMSInformationViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

// One finite launch and burst, rendered entirely by Core Animation. No timers
// or repeating emitters survive removal of the celebration overlay.
static void AddWinFirework(CALayer *container, CGPoint origin, UIColor *color,
                          NSTimeInterval delay, CGFloat radius, NSInteger rayCount) {
    CFTimeInterval start = [container convertTime:CACurrentMediaTime() fromLayer:nil] + delay;
    NSTimeInterval ascent = 0.32;

    CAShapeLayer *rocket = [CAShapeLayer layer];
    UIBezierPath *launchPath = [UIBezierPath bezierPath];
    [launchPath moveToPoint:CGPointMake(origin.x - 20, origin.y + radius * 1.4)];
    [launchPath addQuadCurveToPoint:origin
                     controlPoint:CGPointMake(origin.x + 12, origin.y + radius * 0.6)];
    rocket.path = launchPath.CGPath;
    rocket.fillColor = UIColor.clearColor.CGColor;
    rocket.strokeColor = color.CGColor;
    rocket.lineWidth = 2.5;
    rocket.lineCap = kCALineCapRound;
    rocket.opacity = 0;
    [container addSublayer:rocket];

    CABasicAnimation *launchEnd = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    launchEnd.fromValue = @0;
    launchEnd.toValue = @1;
    launchEnd.duration = ascent;
    CABasicAnimation *launchStart = [CABasicAnimation animationWithKeyPath:@"strokeStart"];
    launchStart.fromValue = @0;
    launchStart.toValue = @1;
    launchStart.beginTime = 0.08;
    launchStart.duration = ascent - 0.08;
    CABasicAnimation *launchOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    launchOpacity.fromValue = @1;
    launchOpacity.toValue = @0.5;
    launchOpacity.duration = ascent;
    CAAnimationGroup *launch = [CAAnimationGroup animation];
    launch.animations = @[launchEnd, launchStart, launchOpacity];
    launch.beginTime = start;
    launch.duration = ascent;
    [rocket addAnimation:launch forKey:@"launch"];

    for (NSInteger index = 0; index < rayCount; index++) {
        CGFloat angle = (2.0 * M_PI * index / rayCount) + (arc4random_uniform(100) / 500.0);
        CGFloat distance = radius * (0.65 + arc4random_uniform(36) / 100.0);
        CGFloat dx = cos(angle) * distance;
        CGFloat dy = sin(angle) * distance;
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:origin];
        [path addQuadCurveToPoint:CGPointMake(origin.x + dx, origin.y + dy + radius * 0.48)
                    controlPoint:CGPointMake(origin.x + dx * 0.65, origin.y + dy * 0.65)];

        CAShapeLayer *ray = [CAShapeLayer layer];
        ray.path = path.CGPath;
        ray.fillColor = UIColor.clearColor.CGColor;
        ray.strokeColor = (index % 4 == 0 ? UIColor.whiteColor : color).CGColor;
        ray.lineWidth = index % 3 == 0 ? 2.4 : 1.5;
        ray.lineCap = kCALineCapRound;
        ray.opacity = 0;
        [container addSublayer:ray];

        CABasicAnimation *head = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        head.fromValue = @0;
        head.toValue = @1;
        head.duration = 0.85;
        head.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        head.fillMode = kCAFillModeForwards;
        head.removedOnCompletion = NO;
        CABasicAnimation *tail = [CABasicAnimation animationWithKeyPath:@"strokeStart"];
        tail.fromValue = @0;
        tail.toValue = @1;
        tail.beginTime = 0.12;
        tail.duration = 1.03;
        CAKeyframeAnimation *fade = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        fade.values = @[@1, @0.9, @0];
        fade.keyTimes = @[@0, @0.4, @1];
        fade.duration = 1.15;
        CAAnimationGroup *burst = [CAAnimationGroup animation];
        burst.animations = @[head, tail, fade];
        burst.beginTime = start + ascent;
        burst.duration = 1.15;
        [ray addAnimation:burst forKey:@"sparkTrail"];
    }

    CAShapeLayer *ring = [CAShapeLayer layer];
    ring.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(-18, -18, 36, 36)].CGPath;
    ring.position = origin;
    ring.fillColor = UIColor.clearColor.CGColor;
    ring.strokeColor = color.CGColor;
    ring.lineWidth = 1.5;
    ring.opacity = 0;
    [container addSublayer:ring];
    CABasicAnimation *expand = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    expand.fromValue = @0.3;
    expand.toValue = @3;
    expand.duration = 0.55;
    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = @0.8;
    fade.toValue = @0;
    fade.duration = 0.55;
    CAAnimationGroup *wave = [CAAnimationGroup animation];
    wave.animations = @[expand, fade];
    wave.beginTime = start + ascent;
    wave.duration = 0.55;
    [ring addAnimation:wave forKey:@"burstRing"];
}

@interface GradientView : UIView

@property (nonatomic, copy) NSArray<UIColor *> *colors;
@property (nonatomic) CGPoint startPoint;
@property (nonatomic) CGPoint endPoint;

@end

@implementation GradientView

+ (Class)layerClass {
    return CAGradientLayer.class;
}

- (instancetype)initWithColors:(NSArray<UIColor *> *)colors {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _colors = colors;
        _startPoint = CGPointMake(0, 0);
        _endPoint = CGPointMake(1, 1);
        [self updateLayer];
    }
    return self;
}

- (void)setColors:(NSArray<UIColor *> *)colors {
    _colors = [colors copy];
    [self updateLayer];
}

- (void)setStartPoint:(CGPoint)startPoint {
    _startPoint = startPoint;
    [self updateLayer];
}

- (void)setEndPoint:(CGPoint)endPoint {
    _endPoint = endPoint;
    [self updateLayer];
}

- (void)updateLayer {
    CAGradientLayer *layer = (CAGradientLayer *)self.layer;
    NSMutableArray *cgColors = [NSMutableArray array];
    for (UIColor *color in self.colors) {
        [cgColors addObject:(id)color.CGColor];
    }
    layer.colors = cgColors;
    layer.startPoint = self.startPoint;
    layer.endPoint = self.endPoint;
}

@end

@interface SymbolTileView : GradientView

@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
- (void)applySymbol:(SlotSymbol *)symbol spinning:(BOOL)spinning;

@end

@implementation SymbolTileView

- (instancetype)init {
    self = [super initWithColors:@[[UIColor blackColor], [UIColor darkGrayColor]]];
    if (self) {
        self.layer.cornerRadius = 8;
        self.layer.masksToBounds = YES;

        _iconView = [[UIImageView alloc] init];
        _iconView.tintColor = UIColor.whiteColor;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.textColor = UIColor.whiteColor;
        _titleLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightBlack];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumScaleFactor = 0.55;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

        [self addSubview:_iconView];
        [self addSubview:_titleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-8],
            [_iconView.widthAnchor constraintEqualToAnchor:self.widthAnchor multiplier:0.42],
            [_iconView.heightAnchor constraintEqualToAnchor:_iconView.widthAnchor],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-4],
            [_titleLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:2]
        ]];
    }
    return self;
}

- (void)applySymbol:(SlotSymbol *)symbol spinning:(BOOL)spinning {
    self.colors = symbol.palette;
    self.iconView.image = [UIImage systemImageNamed:symbol.systemImageName];
    self.titleLabel.text = symbol.title;
    self.alpha = spinning ? 0.82 : 1;
    self.transform = spinning ? CGAffineTransformMakeScale(0.92, 0.92) : CGAffineTransformIdentity;
}

@end

@interface SlotMachineView : GradientView

@property (nonatomic, strong) NSArray<NSArray<SymbolTileView *> *> *tiles;
- (void)applyReels:(NSArray<NSArray<SlotSymbol *> *> *)reels spinning:(BOOL)spinning;
- (void)celebrate;
- (void)stopCelebrating;

@end

@implementation SlotMachineView

- (instancetype)init {
    self = [super initWithColors:@[
        [UIColor colorWithRed:0.92 green:0.13 blue:0.50 alpha:1],
        [UIColor colorWithRed:0.18 green:0.05 blue:0.36 alpha:1],
        [UIColor colorWithRed:0.02 green:0.31 blue:0.23 alpha:1]
    ]];
    if (self) {
        self.layer.cornerRadius = 8;
        self.layer.borderColor = UIColor.whiteColor.CGColor;
        self.layer.borderWidth = 2;

        UIStackView *vertical = [[UIStackView alloc] init];
        vertical.axis = UILayoutConstraintAxisVertical;
        vertical.spacing = 6;
        vertical.distribution = UIStackViewDistributionFillEqually;
        vertical.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:vertical];

        NSMutableArray *rows = [NSMutableArray array];
        for (NSInteger row = 0; row < 3; row++) {
            UIStackView *horizontal = [[UIStackView alloc] init];
            horizontal.axis = UILayoutConstraintAxisHorizontal;
            horizontal.spacing = 6;
            horizontal.distribution = UIStackViewDistributionFillEqually;
            [vertical addArrangedSubview:horizontal];

            NSMutableArray *rowTiles = [NSMutableArray array];
            for (NSInteger column = 0; column < 5; column++) {
                SymbolTileView *tile = [[SymbolTileView alloc] init];
                [horizontal addArrangedSubview:tile];
                [rowTiles addObject:tile];
            }
            [rows addObject:[rowTiles copy]];
        }
        _tiles = [rows copy];

        [NSLayoutConstraint activateConstraints:@[
            [vertical.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
            [vertical.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
            [vertical.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
            [vertical.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10],
            [self.heightAnchor constraintEqualToAnchor:self.widthAnchor multiplier:0.76]
        ]];
    }
    return self;
}

- (void)applyReels:(NSArray<NSArray<SlotSymbol *> *> *)reels spinning:(BOOL)spinning {
    for (NSInteger row = 0; row < 3; row++) {
        for (NSInteger column = 0; column < 5; column++) {
            [self.tiles[row][column] applySymbol:reels[column][row] spinning:spinning];
        }
    }
}

- (void)celebrate {
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    UIColor *highlight = [UIColor colorWithRed:1.0 green:0.86 blue:0.30 alpha:1.0];
    NSInteger index = 0;

    for (NSArray<SymbolTileView *> *rowTiles in self.tiles) {
        for (SymbolTileView *tile in rowTiles) {
            NSTimeInterval delay = reduceMotion ? 0 : index * 0.018;
            [UIView animateWithDuration:reduceMotion ? 0.18 : 0.30
                                  delay:delay
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                             animations:^{
                tile.transform = reduceMotion ? CGAffineTransformIdentity : CGAffineTransformMakeScale(1.08, 1.08);
                tile.layer.borderWidth = 2.0;
                tile.layer.borderColor = highlight.CGColor;
            } completion:^(BOOL finished) {
                if (!finished) {
                    return;
                }
                [UIView animateWithDuration:reduceMotion ? 0.16 : 0.34
                                      delay:0
                                    options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn
                                 animations:^{
                    tile.transform = CGAffineTransformIdentity;
                    tile.layer.borderWidth = 0;
                } completion:nil];
            }];
            index += 1;
        }
    }
}

- (void)stopCelebrating {
    for (NSArray<SymbolTileView *> *row in self.tiles) {
        for (SymbolTileView *tile in row) {
            [tile.layer removeAllAnimations];
            tile.transform = CGAffineTransformIdentity;
            tile.layer.borderWidth = 0;
        }
    }
}

@end

@interface SlotMachineViewController ()

@property (nonatomic, strong) SlotGame *game;
@property (nonatomic, strong) SlotMachineView *slotView;
@property (nonatomic, strong) UILabel *balanceValueLabel;
@property (nonatomic, strong) UILabel *betValueLabel;
@property (nonatomic, strong) UILabel *controlBetValueLabel;
@property (nonatomic, strong) UILabel *winValueLabel;
@property (nonatomic, strong) UILabel *spinsValueLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UILabel *lineCountLabel;
@property (nonatomic, strong) UILabel *bonusCountLabel;
@property (nonatomic, strong) UILabel *grandLabel;
@property (nonatomic, strong) UIButton *minusButton;
@property (nonatomic, strong) UIButton *plusButton;
@property (nonatomic, strong) UIButton *maxButton;
@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) UIButton *spinButton;
@property (nonatomic, strong) UIButton *settingsButton;
@property (nonatomic, strong) UIButton *rulesButton;
@property (nonatomic, strong) UIView *celebrationOverlay;

@end

@implementation SlotMachineViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.game = [[SlotGame alloc] init];
    [self buildInterface];
    [self refreshUI];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self clearWinCelebration];
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [self clearWinCelebration];
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)buildInterface {
    GradientView *background = [[GradientView alloc] initWithColors:@[
        [UIColor colorWithRed:0.08 green:0.08 blue:0.18 alpha:1],
        [UIColor colorWithRed:0.20 green:0.04 blue:0.18 alpha:1],
        [UIColor colorWithRed:0.02 green:0.18 blue:0.16 alpha:1]
    ]];
    background.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:background];

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.alwaysBounceVertical = YES;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrollView];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [background.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [background.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [background.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [background.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor constant:14],
        [stack.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor constant:-14],
        [stack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:10],
        [stack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-12],
        [stack.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor constant:-28]
    ]];

    [stack addArrangedSubview:[self headerView]];
    [stack addArrangedSubview:[self jackpotStripView]];

    self.slotView = [[SlotMachineView alloc] init];
    [stack addArrangedSubview:self.slotView];
    [stack addArrangedSubview:[self statusPanelView]];
    [stack addArrangedSubview:[self controlPanelView]];
}

- (UIView *)headerView {
    UIStackView *container = [[UIStackView alloc] init];
    container.axis = UILayoutConstraintAxisVertical;
    container.spacing = 6;

    UIStackView *top = [[UIStackView alloc] init];
    top.axis = UILayoutConstraintAxisHorizontal;
    top.spacing = 10;
    top.alignment = UIStackViewAlignmentFill;
    UILabel *balanceLabel = nil;
    UIView *balanceView = [self metricViewWithTitle:@"BALANCE" valueLabel:&balanceLabel];
    self.balanceValueLabel = balanceLabel;
    [top addArrangedSubview:balanceView];
    self.rulesButton = [self iconButtonWithSystemName:@"list.bullet.rectangle.portrait.fill" action:@selector(showPaytable)];
    self.rulesButton.accessibilityLabel = @"Rules and payouts";
    self.settingsButton = [self iconButtonWithSystemName:@"gearshape.fill" action:@selector(showSettings)];
    self.settingsButton.accessibilityLabel = @"Settings, privacy and support";
    [top addArrangedSubview:self.rulesButton];
    [top addArrangedSubview:self.settingsButton];
    [container addArrangedSubview:top];

    UILabel *starlight = [self label:@"STARLIGHT" size:22 weight:UIFontWeightBlack color:UIColor.whiteColor];
    starlight.textAlignment = NSTextAlignmentCenter;
    UILabel *jackpot = [self label:@"JACKPOT" size:42 weight:UIFontWeightBlack color:[UIColor colorWithRed:1 green:0.91 blue:0.22 alpha:1]];
    jackpot.textAlignment = NSTextAlignmentCenter;
    jackpot.adjustsFontSizeToFitWidth = YES;
    [container addArrangedSubview:starlight];
    [container addArrangedSubview:jackpot];
    return container;
}

- (UIView *)jackpotStripView {
    UIStackView *strip = [[UIStackView alloc] init];
    strip.axis = UILayoutConstraintAxisHorizontal;
    strip.spacing = 8;
    strip.distribution = UIStackViewDistributionFillEqually;

    UILabel *miniLabel = nil;
    UILabel *majorLabel = nil;
    UILabel *grandLabel = nil;
    [strip addArrangedSubview:[self jackpotBadge:@"PAYLINES" tint:[UIColor colorWithRed:0.20 green:0.84 blue:0.38 alpha:1] valueLabel:&miniLabel]];
    [strip addArrangedSubview:[self jackpotBadge:@"BONUS" tint:[UIColor colorWithRed:0.13 green:0.64 blue:0.95 alpha:1] valueLabel:&majorLabel]];
    [strip addArrangedSubview:[self jackpotBadge:@"JACKPOT" tint:[UIColor colorWithRed:0.98 green:0.24 blue:0.30 alpha:1] valueLabel:&grandLabel]];
    self.lineCountLabel = miniLabel;
    self.bonusCountLabel = majorLabel;
    self.grandLabel = grandLabel;
    return strip;
}

- (UIView *)statusPanelView {
    UIStackView *panel = [[UIStackView alloc] init];
    panel.axis = UILayoutConstraintAxisHorizontal;
    panel.spacing = 10;
    panel.distribution = UIStackViewDistributionFillEqually;

    UILabel *betLabel = nil;
    UILabel *winLabel = nil;
    UILabel *spinsLabel = nil;
    [panel addArrangedSubview:[self metricViewWithTitle:@"BET" valueLabel:&betLabel]];
    [panel addArrangedSubview:[self metricViewWithTitle:@"WIN" valueLabel:&winLabel]];
    [panel addArrangedSubview:[self metricViewWithTitle:@"SPINS" valueLabel:&spinsLabel]];
    self.betValueLabel = betLabel;
    self.winValueLabel = winLabel;
    self.spinsValueLabel = spinsLabel;
    return panel;
}

- (UIView *)controlPanelView {
    GradientView *panel = [[GradientView alloc] initWithColors:@[
        [UIColor colorWithRed:0.55 green:0.02 blue:0.42 alpha:1],
        [UIColor colorWithRed:0.10 green:0.04 blue:0.18 alpha:1]
    ]];
    panel.layer.cornerRadius = 8;
    panel.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:stack];

    self.messageLabel = [self label:@"" size:18 weight:UIFontWeightBlack color:UIColor.whiteColor];
    self.messageLabel.textAlignment = NSTextAlignmentCenter;
    self.messageLabel.numberOfLines = 0;
    [stack addArrangedSubview:self.messageLabel];

    UIStackView *betRow = [[UIStackView alloc] init];
    betRow.axis = UILayoutConstraintAxisHorizontal;
    betRow.spacing = 10;
    betRow.alignment = UIStackViewAlignmentFill;
    self.minusButton = [self commandButton:@"minus" title:nil action:@selector(decreaseBet)];
    self.plusButton = [self commandButton:@"plus" title:nil action:@selector(increaseBet)];
    self.maxButton = [self commandButton:nil title:@"MAX" action:@selector(maxBet)];
    [betRow addArrangedSubview:self.minusButton];
    [betRow addArrangedSubview:[self compactBetView]];
    [betRow addArrangedSubview:self.plusButton];
    [betRow addArrangedSubview:self.maxButton];
    [stack addArrangedSubview:betRow];

    UIStackView *spinRow = [[UIStackView alloc] init];
    spinRow.axis = UILayoutConstraintAxisHorizontal;
    spinRow.spacing = 12;
    self.resetButton = [self commandButton:@"arrow.counterclockwise" title:nil action:@selector(resetGame)];
    self.resetButton.accessibilityLabel = @"Reset local game progress";
    self.minusButton.accessibilityLabel = @"Decrease bet";
    self.plusButton.accessibilityLabel = @"Increase bet";
    self.maxButton.accessibilityLabel = @"Set maximum bet";
    self.spinButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.spinButton.titleLabel.font = [UIFont systemFontOfSize:25 weight:UIFontWeightBlack];
    self.spinButton.tintColor = UIColor.whiteColor;
    self.spinButton.layer.cornerRadius = 8;
    self.spinButton.backgroundColor = [UIColor colorWithRed:0.08 green:0.72 blue:0.18 alpha:1];
    [self.spinButton addTarget:self action:@selector(spin) forControlEvents:UIControlEventTouchUpInside];
    [spinRow addArrangedSubview:self.resetButton];
    [spinRow addArrangedSubview:self.spinButton];
    [stack addArrangedSubview:spinRow];

    UILabel *footer = [self label:@"Free virtual coins · No cash value or prizes" size:11 weight:UIFontWeightSemibold color:[UIColor colorWithWhite:1 alpha:0.58]];
    footer.textAlignment = NSTextAlignmentCenter;
    footer.numberOfLines = 0;
    [stack addArrangedSubview:footer];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-12],
        [stack.topAnchor constraintEqualToAnchor:panel.topAnchor constant:12],
        [stack.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-12],
        [self.minusButton.widthAnchor constraintEqualToConstant:44],
        [self.plusButton.widthAnchor constraintEqualToConstant:44],
        [self.maxButton.widthAnchor constraintEqualToConstant:58],
        [self.resetButton.widthAnchor constraintEqualToConstant:50],
        [self.spinButton.heightAnchor constraintEqualToConstant:58]
    ]];

    return panel;
}

- (UIView *)metricViewWithTitle:(NSString *)title valueLabel:(UILabel **)valueLabel {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.42];
    view.layer.cornerRadius = 8;

    UILabel *titleLabel = [self label:title size:10 weight:UIFontWeightBold color:[UIColor colorWithWhite:1 alpha:0.7]];
    UILabel *value = [self label:@"" size:16 weight:UIFontWeightBlack color:UIColor.whiteColor];
    value.tag = 44;
    value.textAlignment = NSTextAlignmentCenter;
    value.adjustsFontSizeToFitWidth = YES;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, value]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 2;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [view.heightAnchor constraintGreaterThanOrEqualToConstant:44],
        [stack.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:8],
        [stack.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-8],
        [stack.centerYAnchor constraintEqualToAnchor:view.centerYAnchor]
    ]];

    if (valueLabel) {
        *valueLabel = value;
    }
    return view;
}

- (UIView *)compactBetView {
    UILabel *betLabel = nil;
    UIView *view = [self metricViewWithTitle:@"BET" valueLabel:&betLabel];
    self.controlBetValueLabel = betLabel;
    return view;
}

- (UIView *)jackpotBadge:(NSString *)title tint:(UIColor *)tint valueLabel:(UILabel **)outValueLabel {
    GradientView *badge = [[GradientView alloc] initWithColors:@[tint, [UIColor colorWithWhite:0 alpha:0.58]]];
    badge.layer.cornerRadius = 8;

    UILabel *titleLabel = [self label:title size:10 weight:UIFontWeightBlack color:[UIColor colorWithWhite:1 alpha:0.88]];
    UILabel *value = [self label:@"" size:18 weight:UIFontWeightBlack color:UIColor.whiteColor];
    value.textAlignment = NSTextAlignmentCenter;
    value.adjustsFontSizeToFitWidth = YES;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, value]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [badge addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [badge.heightAnchor constraintGreaterThanOrEqualToConstant:54],
        [stack.leadingAnchor constraintEqualToAnchor:badge.leadingAnchor constant:6],
        [stack.trailingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:-6],
        [stack.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor]
    ]];
    if (outValueLabel) {
        *outValueLabel = value;
    }
    return badge;
}

- (UIButton *)iconButtonWithSystemName:(NSString *)systemName action:(SEL)action {
    UIButton *button = [self commandButton:systemName title:nil action:action];
    [button.widthAnchor constraintEqualToConstant:44].active = YES;
    [button.heightAnchor constraintEqualToConstant:44].active = YES;
    return button;
}

- (UIButton *)commandButton:(NSString *)systemName title:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    if (systemName) {
        [button setImage:[UIImage systemImageNamed:systemName] forState:UIControlStateNormal];
    }
    if (title) {
        [button setTitle:title forState:UIControlStateNormal];
    }
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBlack];
    button.tintColor = UIColor.whiteColor;
    button.backgroundColor = [UIColor colorWithRed:0.10 green:0.54 blue:0.96 alpha:1];
    button.layer.cornerRadius = 8;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.55;
    return label;
}

- (void)refreshUI {
    self.balanceValueLabel.text = [self formatNumber:self.game.balance];
    self.betValueLabel.text = [self formatNumber:self.game.bet];
    self.controlBetValueLabel.text = [self formatNumber:self.game.bet];
    self.winValueLabel.text = [self formatNumber:self.game.lastWin];
    self.winValueLabel.textColor = self.game.lastWin > 0 ? [UIColor colorWithRed:1 green:0.92 blue:0.22 alpha:1] : UIColor.whiteColor;
    self.spinsValueLabel.text = [self formatNumber:self.game.spinCount];
    self.messageLabel.text = self.game.message.uppercaseString;
    self.lineCountLabel.text = @"5 lines";
    self.bonusCountLabel.text = @"4+ symbols";
    self.grandLabel.text = [self shortCredits:self.game.jackpot];
    [self.spinButton setTitle:(self.game.spinning ? @"SPINNING" : @"SPIN") forState:UIControlStateNormal];

    BOOL enabled = !self.game.spinning;
    self.minusButton.enabled = enabled;
    self.plusButton.enabled = enabled;
    self.maxButton.enabled = enabled;
    self.resetButton.enabled = enabled;
    self.spinButton.enabled = enabled;
    self.settingsButton.enabled = enabled;
    self.rulesButton.enabled = enabled;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [self.slotView applyReels:self.game.reels spinning:NO];
    } else {
        [UIView animateWithDuration:0.16 animations:^{
            [self.slotView applyReels:self.game.reels spinning:self.game.spinning];
        }];
    }
}

- (void)showWinCelebrationIfNeeded {
    if (self.game.lastWin <= 0 || self.view.window == nil ||
        self.presentedViewController != nil ||
        UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        return;
    }

    [self clearWinCelebration];

    BOOL isGrand = [self.game.message isEqualToString:@"Grand jackpot"];
    BOOL isMega = [self.game.message isEqualToString:@"Mega win"];
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    UIColor *accent = isGrand
        ? [UIColor colorWithRed:1.0 green:0.78 blue:0.20 alpha:1.0]
        : (isMega
           ? [UIColor colorWithRed:0.70 green:0.48 blue:1.0 alpha:1.0]
           : [UIColor colorWithRed:0.30 green:0.92 blue:1.0 alpha:1.0]);

    UIView *overlay = [[UIView alloc] initWithFrame:self.view.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.userInteractionEnabled = NO;
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:isGrand ? 0.22 : 0.12];
    overlay.alpha = 0;
    self.celebrationOverlay = overlay;
    [self.view addSubview:overlay];

    UIView *halo = [[UIView alloc] initWithFrame:CGRectMake(0, 0, isGrand ? 210 : 170, isGrand ? 210 : 170)];
    halo.center = CGPointMake(CGRectGetMidX(overlay.bounds), CGRectGetMidY(overlay.bounds) - 44);
    halo.backgroundColor = [accent colorWithAlphaComponent:0.12];
    halo.layer.cornerRadius = halo.bounds.size.width / 2.0;
    halo.layer.borderWidth = isGrand ? 3.0 : 2.0;
    halo.layer.borderColor = [accent colorWithAlphaComponent:0.72].CGColor;
    halo.alpha = 0;
    [overlay addSubview:halo];

    UILabel *title = [self label:self.game.message.uppercaseString
                             size:isGrand ? 36 : 30
                           weight:UIFontWeightBlack
                            color:accent];
    title.textAlignment = NSTextAlignmentCenter;
    title.frame = CGRectMake(20, CGRectGetMaxY(halo.frame) + 22, overlay.bounds.size.width - 40, 48);
    title.transform = CGAffineTransformMakeScale(0.72, 0.72);
    [overlay addSubview:title];

    UILabel *amount = [self label:[NSString stringWithFormat:@"+%@", [self shortCredits:self.game.lastWin]]
                             size:isGrand ? 28 : 23
                           weight:UIFontWeightBold
                            color:UIColor.whiteColor];
    amount.textAlignment = NSTextAlignmentCenter;
    amount.frame = CGRectMake(20, CGRectGetMaxY(title.frame) + 3, overlay.bounds.size.width - 40, 36);
    amount.transform = CGAffineTransformMakeScale(0.72, 0.72);
    [overlay addSubview:amount];

    if (!reduceMotion) {
        CALayer *fireworks = [CALayer layer];
        fireworks.frame = overlay.bounds;
        fireworks.masksToBounds = YES;
        // Behind the labels; at most three finite bursts (90 shape layers).
        [overlay.layer insertSublayer:fireworks atIndex:0];
        CGFloat width = CGRectGetWidth(overlay.bounds);
        CGFloat top = self.view.safeAreaInsets.top;
        CGFloat centerY = MAX(top + 90, CGRectGetMinY(halo.frame) + 25);
        CGFloat radius = MIN(118, width * 0.27);
        AddWinFirework(fireworks, CGPointMake(width * 0.5, centerY), accent, 0, radius, 28);
        if (isMega || isGrand) {
            UIColor *gold = [UIColor colorWithRed:1 green:0.83 blue:0.36 alpha:1];
            AddWinFirework(fireworks, CGPointMake(width * 0.25, centerY + 50),
                           gold, 0.30, radius * 0.85, 28);
            AddWinFirework(fireworks, CGPointMake(width * 0.75, centerY + 25),
                           isGrand ? gold : accent, 0.58, radius * 0.9, 28);
        }
    }

    if (!reduceMotion) [self.slotView celebrate];

    if (reduceMotion) {
        overlay.alpha = 1;
        halo.alpha = 1;
        halo.transform = CGAffineTransformIdentity;
        title.transform = CGAffineTransformIdentity;
        amount.transform = CGAffineTransformIdentity;
    } else {
        halo.transform = CGAffineTransformMakeScale(0.36, 0.36);
        [UIView animateWithDuration:isGrand ? 0.72 : 0.52
                              delay:0
             usingSpringWithDamping:0.72
              initialSpringVelocity:0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            overlay.alpha = 1;
            halo.alpha = 1;
            halo.transform = CGAffineTransformIdentity;
            title.transform = CGAffineTransformIdentity;
            amount.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    if (!reduceMotion) {
        [UIView animateWithDuration:0.18 animations:^{
            self.messageLabel.transform = CGAffineTransformMakeScale(1.12, 1.12);
            self.winValueLabel.transform = CGAffineTransformMakeScale(1.10, 1.10);
        } completion:^(BOOL finished) {
            if (!finished || self.celebrationOverlay != overlay) {
                return;
            }
            [UIView animateWithDuration:0.28 animations:^{
                self.messageLabel.transform = CGAffineTransformIdentity;
                self.winValueLabel.transform = CGAffineTransformIdentity;
            }];
        }];
    }

    NSTimeInterval duration = reduceMotion ? 1.2 : ((isGrand || isMega) ? 2.25 : 1.7);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf.celebrationOverlay != overlay) {
            return;
        }
        [UIView animateWithDuration:0.24 animations:^{
            overlay.alpha = 0;
        } completion:^(BOOL finished) {
            [overlay removeFromSuperview];
            if (strongSelf.celebrationOverlay == overlay) {
                strongSelf.celebrationOverlay = nil;
            }
        }];
    });
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    [self clearWinCelebration];
    [self.game saveProgress];
}

- (void)clearWinCelebration {
    UIView *overlay = self.celebrationOverlay;
    self.celebrationOverlay = nil;
    [overlay.layer removeAllAnimations];
    for (CALayer *layer in overlay.layer.sublayers) {
        [layer removeAllAnimations];
        for (CALayer *spark in layer.sublayers) {
            [spark removeAllAnimations];
        }
    }
    [overlay removeFromSuperview];
    [self.slotView stopCelebrating];
    [self.messageLabel.layer removeAllAnimations];
    [self.winValueLabel.layer removeAllAnimations];
    self.messageLabel.transform = CGAffineTransformIdentity;
    self.winValueLabel.transform = CGAffineTransformIdentity;
}

- (void)increaseBet {
    [self.game increaseBet];
    [self refreshUI];
}

- (void)decreaseBet {
    [self.game decreaseBet];
    [self refreshUI];
}

- (void)maxBet {
    [self.game maxBet];
    [self refreshUI];
}

- (void)resetGame {
    if (self.game.spinning || self.presentedViewController) return;
    [self clearWinCelebration];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset game progress?"
        message:@"This replaces your saved balance, bet, spin count and jackpot with a new game and 50,000 free virtual coins. It cannot be undone."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Keep playing" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset progress" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [weakSelf.game resetSession];
        [weakSelf refreshUI];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)spin {
    if (self.game.spinning) {
        return;
    }
    [self clearWinCelebration];
    NSInteger previousSpinCount = self.game.spinCount;
    [self.game beginSpinWithStep:^{
        [self refreshUI];
    } completion:^{
        [self refreshUI];
        // An insufficient-balance completion must not replay the previous win.
        if (self.game.spinCount > previousSpinCount) {
            [self showWinCelebrationIfNeeded];
        }
    }];
    [self refreshUI];
}

- (void)showPaytable {
    if (self.game.spinning) return;
    [self presentInformation:[SMSInformationViewController rulesControllerWithBet:self.game.bet jackpot:self.game.jackpot]];
}

- (void)presentInformation:(UIViewController *)controller {
    [self clearWinCelebration];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:controller];
    navigation.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    void (^present)(void) = ^{ [self presentViewController:navigation animated:YES completion:nil]; };
    UIViewController *current = self.presentedViewController;
    if (current.isBeingDismissed && current.transitionCoordinator) {
        [current.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            if (!context.isCancelled) present();
        }];
    } else if (current) {
        [self dismissViewControllerAnimated:YES completion:present];
    } else {
        present();
    }
}

- (void)showSettings {
    if (self.game.spinning || self.presentedViewController) return;
    [self clearWinCelebration];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Game settings"
        message:@"Progress is saved on this device. All coins are free and have no cash value."
        preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"Rules & payouts" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf showPaytable];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Privacy" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf presentInformation:[SMSInformationViewController privacyController]];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"About & support" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf presentInformation:[SMSInformationViewController aboutController]];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Add 50,000 free coins" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf.game addDemoCredits];
        [weakSelf refreshUI];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.settingsButton;
    sheet.popoverPresentationController.sourceRect = self.settingsButton.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (NSString *)formatNumber:(NSInteger)value {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    return [formatter stringFromNumber:@(value)];
}

- (NSString *)shortCredits:(NSInteger)value {
    if (value >= 1000000) {
        return [NSString stringWithFormat:@"%.1fM", value / 1000000.0];
    }
    if (value >= 1000) {
        return [NSString stringWithFormat:@"%.1fK", value / 1000.0];
    }
    return [self formatNumber:value];
}

@end
