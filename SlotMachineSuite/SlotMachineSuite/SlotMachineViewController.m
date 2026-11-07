#import "SlotMachineViewController.h"
#import "SlotGame.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static UIImage *CelebrationParticleImage(void) {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 2.0;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(18, 18) format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        UIBezierPath *star = [UIBezierPath bezierPath];
        CGPoint center = CGPointMake(9, 9);
        for (NSInteger index = 0; index < 8; index++) {
            CGFloat angle = -M_PI_2 + (M_PI / 4.0 * index);
            CGFloat radius = index % 2 == 0 ? 8.0 : 2.8;
            CGPoint point = CGPointMake(center.x + cos(angle) * radius,
                                        center.y + sin(angle) * radius);
            if (index == 0) {
                [star moveToPoint:point];
            } else {
                [star addLineToPoint:point];
            }
        }
        [star closePath];
        [[UIColor whiteColor] setFill];
        [star fill];
    }];
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
                tile.transform = CGAffineTransformMakeScale(reduceMotion ? 1.02 : 1.08,
                                                             reduceMotion ? 1.02 : 1.08);
                tile.layer.borderWidth = 2.0;
                tile.layer.borderColor = highlight.CGColor;
            } completion:^(BOOL finished) {
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
@property (nonatomic, strong) UILabel *miniLabel;
@property (nonatomic, strong) UILabel *majorLabel;
@property (nonatomic, strong) UILabel *grandLabel;
@property (nonatomic, strong) UIButton *minusButton;
@property (nonatomic, strong) UIButton *plusButton;
@property (nonatomic, strong) UIButton *maxButton;
@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) UIButton *spinButton;
@property (nonatomic, strong) UIView *celebrationOverlay;

@end

@implementation SlotMachineViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.game = [[SlotGame alloc] init];
    [self buildInterface];
    [self refreshUI];
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
    [top addArrangedSubview:[self iconButtonWithSystemName:@"list.bullet.rectangle.portrait.fill" action:@selector(showPaytable)]];
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
    [strip addArrangedSubview:[self jackpotBadge:@"MINI" tint:[UIColor colorWithRed:0.20 green:0.84 blue:0.38 alpha:1] valueLabel:&miniLabel]];
    [strip addArrangedSubview:[self jackpotBadge:@"MAJOR" tint:[UIColor colorWithRed:0.13 green:0.64 blue:0.95 alpha:1] valueLabel:&majorLabel]];
    [strip addArrangedSubview:[self jackpotBadge:@"GRAND" tint:[UIColor colorWithRed:0.98 green:0.24 blue:0.30 alpha:1] valueLabel:&grandLabel]];
    self.miniLabel = miniLabel;
    self.majorLabel = majorLabel;
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
    self.spinButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.spinButton.titleLabel.font = [UIFont systemFontOfSize:25 weight:UIFontWeightBlack];
    self.spinButton.tintColor = UIColor.whiteColor;
    self.spinButton.layer.cornerRadius = 8;
    self.spinButton.backgroundColor = [UIColor colorWithRed:0.08 green:0.72 blue:0.18 alpha:1];
    [self.spinButton addTarget:self action:@selector(spin) forControlEvents:UIControlEventTouchUpInside];
    [spinRow addArrangedSubview:self.resetButton];
    [spinRow addArrangedSubview:self.spinButton];
    [stack addArrangedSubview:spinRow];

    UILabel *footer = [self label:@"Virtual coins only" size:11 weight:UIFontWeightSemibold color:[UIColor colorWithWhite:1 alpha:0.58]];
    footer.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:footer];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-12],
        [stack.topAnchor constraintEqualToAnchor:panel.topAnchor constant:12],
        [stack.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-12],
        [self.minusButton.widthAnchor constraintEqualToConstant:42],
        [self.plusButton.widthAnchor constraintEqualToConstant:42],
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
    self.miniLabel.text = [self shortCredits:self.game.bet * 20];
    self.majorLabel.text = [self shortCredits:self.game.bet * 120];
    self.grandLabel.text = [self shortCredits:self.game.jackpot];
    [self.spinButton setTitle:(self.game.spinning ? @"SPINNING" : @"SPIN") forState:UIControlStateNormal];

    BOOL enabled = !self.game.spinning;
    self.minusButton.enabled = enabled;
    self.plusButton.enabled = enabled;
    self.maxButton.enabled = enabled;
    self.resetButton.enabled = enabled;
    self.spinButton.enabled = enabled;

    [UIView animateWithDuration:0.16 animations:^{
        [self.slotView applyReels:self.game.reels spinning:self.game.spinning];
    }];
}

- (void)showWinCelebrationIfNeeded {
    if (self.game.lastWin <= 0 || self.view.window == nil) {
        return;
    }

    [self.celebrationOverlay removeFromSuperview];
    self.celebrationOverlay = nil;

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

    UIImage *particleImage = CelebrationParticleImage();
    CAEmitterLayer *emitter = [CAEmitterLayer layer];
    emitter.emitterPosition = CGPointMake(CGRectGetMidX(overlay.bounds), CGRectGetMidY(overlay.bounds) - 44);
    emitter.emitterShape = kCAEmitterLayerPoint;
    emitter.renderMode = kCAEmitterLayerAdditive;

    CAEmitterCell *particle = [CAEmitterCell emitterCell];
    particle.contents = (id)particleImage.CGImage;
    particle.birthRate = isGrand ? 52 : (isMega ? 36 : 24);
    particle.lifetime = isGrand ? 1.55 : 1.15;
    particle.velocity = isGrand ? 190 : 150;
    particle.velocityRange = isGrand ? 110 : 85;
    particle.emissionRange = (CGFloat)(M_PI * 2.0);
    particle.spinRange = (CGFloat)M_PI;
    particle.scale = isGrand ? 0.14 : 0.10;
    particle.scaleRange = 0.06;
    particle.alphaSpeed = -0.72;
    particle.color = accent.CGColor;
    emitter.emitterCells = @[particle];
    [overlay.layer addSublayer:emitter];

    [self.slotView celebrate];

    if (reduceMotion) {
        overlay.alpha = 1;
        halo.alpha = 1;
        halo.transform = CGAffineTransformIdentity;
        title.transform = CGAffineTransformIdentity;
        amount.transform = CGAffineTransformIdentity;
    } else {
        halo.transform = CGAffineTransformMakeScale(0.36, 0.36);
        [UIView animateKeyframesWithDuration:isGrand ? 0.72 : 0.52
                                       delay:0
                                     options:UIViewKeyframeAnimationOptionCalculationModeCubic | UIViewAnimationOptionBeginFromCurrentState
                                  animations:^{
            overlay.alpha = 1;
            halo.alpha = 1;
            halo.transform = CGAffineTransformIdentity;
            title.transform = CGAffineTransformIdentity;
            amount.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    [UIView animateWithDuration:0.18 animations:^{
        self.messageLabel.transform = CGAffineTransformMakeScale(1.12, 1.12);
        self.winValueLabel.transform = CGAffineTransformMakeScale(1.10, 1.10);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.28 animations:^{
            self.messageLabel.transform = CGAffineTransformIdentity;
            self.winValueLabel.transform = CGAffineTransformIdentity;
        }];
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        emitter.birthRate = 0;
    });

    NSTimeInterval duration = isGrand ? 1.75 : 1.20;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.24 animations:^{
            overlay.alpha = 0;
        } completion:^(BOOL finished) {
            [overlay removeFromSuperview];
            if (self.celebrationOverlay == overlay) {
                self.celebrationOverlay = nil;
            }
        }];
    });
}

- (void)clearWinCelebration {
    [self.celebrationOverlay removeFromSuperview];
    self.celebrationOverlay = nil;
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
    [self clearWinCelebration];
    [self.game resetSession];
    [self refreshUI];
}

- (void)spin {
    [self.game beginSpinWithStep:^{
        [self refreshUI];
    } completion:^{
        [self refreshUI];
        [self showWinCelebrationIfNeeded];
    }];
    [self refreshUI];
}

- (void)showPaytable {
    UIViewController *controller = [[UIViewController alloc] init];
    controller.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.15 alpha:1];
    controller.title = @"Paytable";

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [controller.view addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:controller.view.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-16],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]
    ]];

    for (SlotSymbol *symbol in SlotSymbol.allSymbols) {
        UILabel *row = [self label:[NSString stringWithFormat:@"%@   3+ pays x%ld   %@", symbol.title, (long)symbol.payoutMultiplier, [self formatNumber:self.game.bet * symbol.payoutMultiplier * 3 / 5]] size:16 weight:UIFontWeightBlack color:UIColor.whiteColor];
        row.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        row.layer.cornerRadius = 8;
        row.layer.masksToBounds = YES;
        row.numberOfLines = 2;
        [stack addArrangedSubview:row];
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:54].active = YES;
    }

    for (NSDictionary *line in self.game.paylines) {
        NSArray *rows = line[@"rows"];
        NSMutableArray *displayRows = [NSMutableArray array];
        for (NSNumber *row in rows) {
            [displayRows addObject:@(row.integerValue + 1).stringValue];
        }
        UILabel *label = [self label:[NSString stringWithFormat:@"%@  %@", line[@"name"], [displayRows componentsJoinedByString:@"-"]] size:14 weight:UIFontWeightBold color:[UIColor colorWithWhite:1 alpha:0.78]];
        [stack addArrangedSubview:label];
    }

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:controller];
    controller.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark"] style:UIBarButtonItemStylePlain target:self action:@selector(dismissPaytable)];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)dismissPaytable {
    [self dismissViewControllerAnimated:YES completion:nil];
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
