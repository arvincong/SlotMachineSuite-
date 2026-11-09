#import "SlotGame.h"
#import "SMSGameRules.h"
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>

@implementation SlotSymbol

+ (NSArray<SlotSymbol *> *)allSymbols {
    static NSArray<SlotSymbol *> *symbols;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *items = [NSMutableArray array];
        for (NSInteger index = SlotSymbolTypeNova; index <= SlotSymbolTypeBonus; index++) {
            [items addObject:[SlotSymbol symbolWithType:index]];
        }
        symbols = [items copy];
    });
    return symbols;
}

+ (instancetype)symbolWithType:(SlotSymbolType)type {
    SlotSymbol *symbol = [[SlotSymbol alloc] init];
    [symbol setValue:@(type) forKey:@"type"];
    return symbol;
}

- (NSString *)title {
    switch (self.type) {
        case SlotSymbolTypeNova: return @"NOVA";
        case SlotSymbolTypeCrown: return @"CROWN";
        case SlotSymbolTypeGem: return @"GEM";
        case SlotSymbolTypeBell: return @"BELL";
        case SlotSymbolTypeSeven: return @"SEVEN";
        case SlotSymbolTypeCoin: return @"COIN";
        case SlotSymbolTypeWild: return @"WILD";
        case SlotSymbolTypeBonus: return @"BONUS";
    }
}

- (NSString *)systemImageName {
    switch (self.type) {
        case SlotSymbolTypeNova: return @"sparkles";
        case SlotSymbolTypeCrown: return @"crown.fill";
        case SlotSymbolTypeGem: return @"diamond.fill";
        case SlotSymbolTypeBell: return @"bell.fill";
        case SlotSymbolTypeSeven: return @"7.circle.fill";
        case SlotSymbolTypeCoin: return @"dollarsign.circle.fill";
        case SlotSymbolTypeWild: return @"wand.and.stars";
        case SlotSymbolTypeBonus: return @"gift.fill";
    }
}

- (NSInteger)weight {
    switch (self.type) {
        case SlotSymbolTypeNova: return 18;
        case SlotSymbolTypeCrown: return 16;
        case SlotSymbolTypeGem:
        case SlotSymbolTypeBell: return 14;
        case SlotSymbolTypeCoin: return 12;
        case SlotSymbolTypeSeven: return 10;
        case SlotSymbolTypeWild:
        case SlotSymbolTypeBonus: return 8;
    }
}

- (NSInteger)payoutMultiplier {
    return self.type >= 0 && self.type < SMSSymbols ? SMSMultipliers[self.type] : 0;
}

- (NSArray<UIColor *> *)palette {
    switch (self.type) {
        case SlotSymbolTypeNova: return @[[UIColor colorWithRed:0.14 green:0.78 blue:0.95 alpha:1], [UIColor colorWithRed:0.03 green:0.25 blue:0.77 alpha:1]];
        case SlotSymbolTypeCrown: return @[[UIColor colorWithRed:1.00 green:0.87 blue:0.24 alpha:1], [UIColor colorWithRed:0.93 green:0.35 blue:0.12 alpha:1]];
        case SlotSymbolTypeGem: return @[[UIColor colorWithRed:0.95 green:0.19 blue:0.72 alpha:1], [UIColor colorWithRed:0.32 green:0.08 blue:0.72 alpha:1]];
        case SlotSymbolTypeBell: return @[[UIColor colorWithRed:0.99 green:0.70 blue:0.18 alpha:1], [UIColor colorWithRed:0.98 green:0.20 blue:0.20 alpha:1]];
        case SlotSymbolTypeSeven: return @[[UIColor colorWithRed:0.98 green:0.14 blue:0.24 alpha:1], [UIColor colorWithRed:0.42 green:0.02 blue:0.12 alpha:1]];
        case SlotSymbolTypeCoin: return @[[UIColor colorWithRed:0.96 green:0.93 blue:0.39 alpha:1], [UIColor colorWithRed:0.08 green:0.65 blue:0.28 alpha:1]];
        case SlotSymbolTypeWild: return @[[UIColor colorWithRed:1.00 green:0.95 blue:0.36 alpha:1], [UIColor colorWithRed:0.13 green:0.74 blue:0.44 alpha:1]];
        case SlotSymbolTypeBonus: return @[[UIColor colorWithRed:0.36 green:0.93 blue:1.00 alpha:1], [UIColor colorWithRed:0.04 green:0.39 blue:0.94 alpha:1]];
    }
}

@end

static NSString * const SMSGameSaveKey = @"SMSNativeGame.v1";

static BOOL SMSStoredInteger(id value, int64_t minimum, int64_t maximum, int64_t *output) {
    if (![value isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return NO;
    double number = [value doubleValue];
    if (!isfinite(number) || number < minimum || number > maximum) return NO;
    int64_t integer = [value longLongValue];
    if ((double)integer != number) return NO;
    *output = integer;
    return YES;
}

@interface SlotGame ()
- (void)advanceSpinAtTick:(NSInteger)tick;
- (void)finishPendingSpin;
- (NSArray<NSArray<SlotSymbol *> *> *)randomReels;
- (SlotSymbol *)weightedSymbol;
- (NSDictionary<NSString *, NSNumber *> *)evaluateReels:(NSArray<NSArray<SlotSymbol *> *> *)reels jackpot:(NSInteger)jackpot;
- (BOOL)restoreState:(id)state;
- (NSDictionary *)snapshotWithReels:(NSArray<NSArray<SlotSymbol *> *> *)reels
                           balance:(NSInteger)balance win:(NSInteger)win
                           jackpot:(NSInteger)jackpot spins:(NSInteger)spins;
@end

@implementation SlotGame {
    NSUserDefaults *_defaults;
    NSDictionary *_pendingState;
    NSUInteger _spinGeneration;
    void (^_spinStep)(void);
    void (^_spinCompletion)(void);
}

- (instancetype)init {
    return [self initWithDefaults:NSUserDefaults.standardUserDefaults];
}

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
    self = [super init];
    if (self) {
        _defaults = defaults;
        _betOptions = @[@100, @250, @500, @1000, @2500, @5000];
        if ([self restoreState:[defaults objectForKey:SMSGameSaveKey]]) {
            _message = @"Welcome back";
        } else {
            [self resetSession];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:)
            name:UIApplicationWillResignActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray<NSDictionary<NSString *,id> *> *)paylines {
    NSArray *names = @[@"Top", @"Middle", @"Bottom", @"Rise", @"Dip"];
    NSMutableArray *lines = [NSMutableArray array];
    for (int line = 0; line < SMSLines; line++) {
        NSMutableArray *rows = [NSMutableArray array];
        for (int col = 0; col < SMSColumns; col++) [rows addObject:@(SMSPaylines[line][col])];
        [lines addObject:@{@"name": names[line], @"rows": rows}];
    }
    return lines;
}

- (void)increaseBet {
    if (self.spinning) return;
    NSUInteger index = [self.betOptions indexOfObject:@(self.bet)];
    if (index != NSNotFound && index + 1 < self.betOptions.count) {
        _bet = self.betOptions[index + 1].integerValue;
        [self saveProgress];
    }
}

- (void)decreaseBet {
    if (self.spinning) return;
    NSUInteger index = [self.betOptions indexOfObject:@(self.bet)];
    if (index != NSNotFound && index > 0) {
        _bet = self.betOptions[index - 1].integerValue;
        [self saveProgress];
    }
}

- (void)maxBet {
    if (self.spinning) return;
    _bet = self.betOptions.lastObject.integerValue;
    [self saveProgress];
}

- (void)resetSession {
    if (self.spinning) return;
    _balance = SMSStartingCredits;
    _bet = 500;
    _lastWin = 0;
    _jackpot = SMSStartingJackpot;
    _spinCount = 0;
    _message = @"Ready";
    _reels = [self randomReels];
    [self saveProgress];
}

- (void)addDemoCredits {
    if (self.spinning) return;
    _balance = SMSClampCredits(self.balance + SMSStartingCredits);
    _message = @"Free virtual coins added";
    [self saveProgress];
}

- (NSDictionary *)snapshotWithReels:(NSArray<NSArray<SlotSymbol *> *> *)reels
                           balance:(NSInteger)balance win:(NSInteger)win
                           jackpot:(NSInteger)jackpot spins:(NSInteger)spins {
    NSMutableArray *board = [NSMutableArray arrayWithCapacity:SMSColumns * SMSRows];
    for (NSArray<SlotSymbol *> *column in reels)
        for (SlotSymbol *symbol in column) [board addObject:@(symbol.type)];
    return @{@"version": @1, @"balance": @(balance), @"bet": @(self.bet), @"lastWin": @(win),
             @"jackpot": @(jackpot), @"spinCount": @(spins), @"board": board};
}

- (BOOL)restoreState:(id)state {
    if (![state isKindOfClass:NSDictionary.class]) return NO;
    int64_t version, balance, bet, win, jackpot, spins;
    if (!SMSStoredInteger(state[@"version"], 1, 1, &version) ||
        !SMSStoredInteger(state[@"balance"], 0, SMSMaxCredits, &balance) ||
        !SMSStoredInteger(state[@"bet"], 100, 5000, &bet) ||
        !SMSStoredInteger(state[@"lastWin"], 0, SMSMaxCredits, &win) ||
        !SMSStoredInteger(state[@"jackpot"], SMSStartingJackpot, SMSMaxCredits, &jackpot) ||
        !SMSStoredInteger(state[@"spinCount"], 0, SMSMaxSpins, &spins) ||
        !SMSValidState(balance, bet, win, jackpot, spins)) return NO;
    id board = state[@"board"];
    if (![board isKindOfClass:NSArray.class] || [board count] != SMSColumns * SMSRows) return NO;
    NSMutableArray *reels = [NSMutableArray array];
    for (int col = 0; col < SMSColumns; col++) {
        NSMutableArray *column = [NSMutableArray array];
        for (int row = 0; row < SMSRows; row++) {
            int64_t symbol;
            if (!SMSStoredInteger(board[col * SMSRows + row], 0, SMSSymbols - 1, &symbol)) return NO;
            [column addObject:[SlotSymbol symbolWithType:(SlotSymbolType)symbol]];
        }
        [reels addObject:[column copy]];
    }
    _balance = (NSInteger)balance;
    _bet = (NSInteger)bet;
    _lastWin = (NSInteger)win;
    _jackpot = (NSInteger)jackpot;
    _spinCount = (NSInteger)spins;
    _reels = [reels copy];
    return YES;
}

- (void)saveProgress {
    // During animation the final transaction is already the authoritative save.
    NSDictionary *state = _pendingState ?: [self snapshotWithReels:self.reels balance:self.balance
        win:self.lastWin jackpot:self.jackpot spins:self.spinCount];
    [_defaults setObject:state forKey:SMSGameSaveKey];
}

- (void)beginSpinWithStep:(void (^ _Nullable)(void))step
               completion:(void (^ _Nullable)(void))completion {
    if (self.spinning) return;
    if (self.balance < self.bet || self.spinCount >= SMSMaxSpins) {
        _message = self.balance < self.bet ? @"Lower your bet or add free coins in Settings" : @"Reset progress to start a new session";
        if (completion) completion();
        return;
    }
    // Resolve and persist one complete turn before showing animation. Restoring
    // never replays a wager or rerolls an interrupted spin.
    NSInteger nextJackpot = SMSClampCredits(self.jackpot + MAX(25, self.bet / 20));
    NSArray *finalReels = [self randomReels];
    NSDictionary *result = [self evaluateReels:finalReels jackpot:nextJackpot];
    NSInteger win = [result[@"total"] integerValue];
    _pendingState = [self snapshotWithReels:finalReels
        balance:SMSClampCredits(self.balance - self.bet + win) win:win
        jackpot:[result[@"jackpotWin"] integerValue] > 0 ? SMSStartingJackpot : nextJackpot
        spins:self.spinCount + 1];
    [self saveProgress];
    _balance -= self.bet;
    _jackpot = nextJackpot;
    _lastWin = 0;
    _message = @"Spinning";
    _spinning = YES;
    _spinGeneration++;
    _spinStep = [step copy];
    _spinCompletion = [completion copy];
    if (UIAccessibilityIsReduceMotionEnabled()) [self finishPendingSpin];
    else [self advanceSpinAtTick:0];
}

- (void)advanceSpinAtTick:(NSInteger)tick {
    if (!self.spinning) return;
    if (tick >= 18) {
        [self finishPendingSpin];
        return;
    }
    NSUInteger generation = _spinGeneration;
    _reels = [self randomReels];
    if (_spinStep) _spinStep();
    // A callback may synchronously settle this spin and start another one.
    if (!self.spinning || _spinGeneration != generation) return;
    NSTimeInterval delay = 0.045 + ((tick + 1) * 0.005);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SlotGame *self = weakSelf;
        if (self && self.spinning && self->_spinGeneration == generation) [self advanceSpinAtTick:tick + 1];
    });
}

- (void)finishPendingSpin {
    if (!self.spinning || !_pendingState) return;
    NSInteger awardedJackpot = _jackpot;
    NSInteger wager = _bet;
    [self restoreState:_pendingState];
    _pendingState = nil;
    _spinning = NO;
    _spinGeneration++;
    // A reset pool after this spin signals the visible 7+ BONUS jackpot.
    _message = self.jackpot == SMSStartingJackpot && awardedJackpot > SMSStartingJackpot ? @"Grand jackpot"
        : (self.lastWin > wager * 20 ? @"Mega win" : (self.lastWin > 0 ? @"Nice win" : @"Try again"));
    void (^completion)(void) = _spinCompletion;
    _spinCompletion = nil;
    _spinStep = nil;
    if (completion) completion();
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    [self finishPendingSpin];
    [self saveProgress];
}

- (NSDictionary<NSString *, NSNumber *> *)evaluateReels:(NSArray<NSArray<SlotSymbol *> *> *)reels jackpot:(NSInteger)jackpot {
    int board[SMSColumns][SMSRows];
    for (int col = 0; col < SMSColumns; col++)
        for (int row = 0; row < SMSRows; row++) board[col][row] = (int)reels[col][row].type;
    SMSGameResult result = SMSEvaluateBoard(board, self.bet, jackpot);
    return @{@"lineWin": @(result.lineWin), @"bonusWin": @(result.bonusWin),
             @"jackpotWin": @(result.jackpotWin), @"total": @(result.total)};
}

- (NSArray<NSArray<SlotSymbol *> *> *)randomReels {
    NSMutableArray *columns = [NSMutableArray array];
    for (NSInteger column = 0; column < SMSColumns; column++) {
        NSMutableArray *rows = [NSMutableArray array];
        for (NSInteger row = 0; row < SMSRows; row++) [rows addObject:[self weightedSymbol]];
        [columns addObject:[rows copy]];
    }
    return [columns copy];
}

- (SlotSymbol *)weightedSymbol {
    NSInteger totalWeight = 0;
    for (SlotSymbol *symbol in SlotSymbol.allSymbols) totalWeight += symbol.weight;
    NSInteger ticket = arc4random_uniform((uint32_t)totalWeight) + 1;
    for (SlotSymbol *symbol in SlotSymbol.allSymbols) {
        ticket -= symbol.weight;
        if (ticket <= 0) return symbol;
    }
    return [SlotSymbol symbolWithType:SlotSymbolTypeNova];
}

@end
