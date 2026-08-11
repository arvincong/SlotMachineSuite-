#import "SlotGame.h"

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
    switch (self.type) {
        case SlotSymbolTypeNova: return 2;
        case SlotSymbolTypeCrown: return 3;
        case SlotSymbolTypeGem: return 4;
        case SlotSymbolTypeBell: return 5;
        case SlotSymbolTypeCoin: return 6;
        case SlotSymbolTypeSeven: return 8;
        case SlotSymbolTypeWild: return 10;
        case SlotSymbolTypeBonus: return 12;
    }
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

@implementation SlotGame

- (instancetype)init {
    self = [super init];
    if (self) {
        _betOptions = @[@100, @250, @500, @1000, @2500, @5000];
        [self resetSession];
    }
    return self;
}

- (NSArray<NSDictionary<NSString *,id> *> *)paylines {
    return @[
        @{@"name": @"Top", @"rows": @[@0, @0, @0, @0, @0]},
        @{@"name": @"Middle", @"rows": @[@1, @1, @1, @1, @1]},
        @{@"name": @"Bottom", @"rows": @[@2, @2, @2, @2, @2]},
        @{@"name": @"Rise", @"rows": @[@2, @1, @0, @1, @2]},
        @{@"name": @"Dip", @"rows": @[@0, @1, @2, @1, @0]}
    ];
}

- (void)increaseBet {
    NSUInteger index = [self.betOptions indexOfObject:@(self.bet)];
    if (index != NSNotFound && index + 1 < self.betOptions.count) {
        _bet = self.betOptions[index + 1].integerValue;
    }
}

- (void)decreaseBet {
    NSUInteger index = [self.betOptions indexOfObject:@(self.bet)];
    if (index != NSNotFound && index > 0) {
        _bet = self.betOptions[index - 1].integerValue;
    }
}

- (void)maxBet {
    _bet = self.betOptions.lastObject.integerValue;
}

- (void)resetSession {
    _balance = 50000;
    _bet = 500;
    _lastWin = 0;
    _jackpot = 1250000;
    _spinCount = 0;
    _message = @"Ready";
    _spinning = NO;
    _reels = [self randomReels];
}

- (void)beginSpinWithStep:(void (^)(void))step completion:(void (^)(void))completion {
    if (self.spinning) {
        return;
    }

    if (self.balance < self.bet) {
        _message = @"Add demo credits";
        if (completion) {
            completion();
        }
        return;
    }

    _balance -= self.bet;
    _jackpot += MAX(25, self.bet / 20);
    _lastWin = 0;
    _message = @"Spinning";
    _spinning = YES;

    __block NSInteger tick = 0;
    __block void (^advance)(void);
    advance = ^{
        if (tick < 18) {
            self->_reels = [self randomReels];
            if (step) {
                step();
            }
            tick += 1;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((0.045 + tick * 0.005) * NSEC_PER_SEC)), dispatch_get_main_queue(), advance);
            return;
        }

        self->_reels = [self randomReels];
        NSDictionary *result = [self evaluateReels:self.reels];
        NSInteger total = [result[@"total"] integerValue];
        NSInteger jackpotWin = [result[@"jackpotWin"] integerValue];
        self->_lastWin = total;
        self->_balance += total;
        self->_spinCount += 1;

        if (jackpotWin > 0) {
            self->_message = @"Grand jackpot";
            self->_jackpot = 1250000;
        } else if (total > self.bet * 20) {
            self->_message = @"Mega win";
        } else if (total > 0) {
            self->_message = @"Nice win";
        } else {
            self->_message = @"Try again";
        }

        self->_spinning = NO;
        if (completion) {
            completion();
        }
    };

    advance();
}

- (NSDictionary<NSString *, NSNumber *> *)evaluateReels:(NSArray<NSArray<SlotSymbol *> *> *)reels {
    NSInteger lineWin = 0;

    for (NSDictionary *payline in self.paylines) {
        NSArray<NSNumber *> *rows = payline[@"rows"];
        NSMutableArray<SlotSymbol *> *symbols = [NSMutableArray array];
        for (NSInteger column = 0; column < rows.count; column++) {
            [symbols addObject:reels[column][rows[column].integerValue]];
        }

        SlotSymbol *anchor = nil;
        for (SlotSymbol *symbol in symbols) {
            if (symbol.type != SlotSymbolTypeWild) {
                anchor = symbol;
                break;
            }
        }
        if (!anchor) {
            anchor = [SlotSymbol symbolWithType:SlotSymbolTypeWild];
        }

        NSInteger matchCount = 0;
        for (SlotSymbol *symbol in symbols) {
            if (symbol.type == anchor.type || symbol.type == SlotSymbolTypeWild || anchor.type == SlotSymbolTypeWild) {
                matchCount += 1;
            } else {
                break;
            }
        }

        if (matchCount >= 3) {
            lineWin += self.bet * anchor.payoutMultiplier * matchCount / 5;
        }
    }

    NSInteger bonusCount = 0;
    for (NSArray<SlotSymbol *> *column in reels) {
        for (SlotSymbol *symbol in column) {
            if (symbol.type == SlotSymbolTypeBonus) {
                bonusCount += 1;
            }
        }
    }

    NSInteger bonusWin = bonusCount >= 4 ? self.bet * bonusCount * 4 : 0;
    BOOL jackpotHit = bonusCount >= 7 || arc4random_uniform(2500) == 0;
    NSInteger jackpotWin = jackpotHit ? self.jackpot : 0;
    return @{@"lineWin": @(lineWin), @"bonusWin": @(bonusWin), @"jackpotWin": @(jackpotWin), @"total": @(lineWin + bonusWin + jackpotWin)};
}

- (NSArray<NSArray<SlotSymbol *> *> *)randomReels {
    NSMutableArray *columns = [NSMutableArray array];
    for (NSInteger column = 0; column < 5; column++) {
        NSMutableArray *rows = [NSMutableArray array];
        for (NSInteger row = 0; row < 3; row++) {
            [rows addObject:[self weightedSymbol]];
        }
        [columns addObject:[rows copy]];
    }
    return [columns copy];
}

- (SlotSymbol *)weightedSymbol {
    NSInteger totalWeight = 0;
    for (SlotSymbol *symbol in SlotSymbol.allSymbols) {
        totalWeight += symbol.weight;
    }

    NSInteger ticket = arc4random_uniform((uint32_t)totalWeight) + 1;
    for (SlotSymbol *symbol in SlotSymbol.allSymbols) {
        ticket -= symbol.weight;
        if (ticket <= 0) {
            return symbol;
        }
    }

    return [SlotSymbol symbolWithType:SlotSymbolTypeNova];
}

@end
