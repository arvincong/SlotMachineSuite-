#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SlotSymbolType) {
    SlotSymbolTypeNova,
    SlotSymbolTypeCrown,
    SlotSymbolTypeGem,
    SlotSymbolTypeBell,
    SlotSymbolTypeSeven,
    SlotSymbolTypeCoin,
    SlotSymbolTypeWild,
    SlotSymbolTypeBonus
};

@interface SlotSymbol : NSObject

@property (nonatomic, readonly) SlotSymbolType type;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *systemImageName;
@property (nonatomic, readonly) NSInteger weight;
@property (nonatomic, readonly) NSInteger payoutMultiplier;
@property (nonatomic, readonly) NSArray<UIColor *> *palette;

+ (NSArray<SlotSymbol *> *)allSymbols;
+ (instancetype)symbolWithType:(SlotSymbolType)type;

@end

@interface SlotGame : NSObject

@property (nonatomic, copy, readonly) NSArray<NSArray<SlotSymbol *> *> *reels;
@property (nonatomic, readonly) NSInteger balance;
@property (nonatomic, readonly) NSInteger bet;
@property (nonatomic, readonly) NSInteger lastWin;
@property (nonatomic, readonly) NSInteger jackpot;
@property (nonatomic, copy, readonly) NSString *message;
@property (nonatomic, readonly) BOOL spinning;
@property (nonatomic, readonly) NSInteger spinCount;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *betOptions;

/// Supply an isolated defaults suite for state restoration checks.
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults;
- (void)saveProgress;
- (void)addDemoCredits;
- (void)increaseBet;
- (void)decreaseBet;
- (void)maxBet;
- (void)resetSession;
- (void)beginSpinWithStep:(void (^ _Nullable)(void))step
               completion:(void (^ _Nullable)(void))completion;
- (NSArray<NSDictionary<NSString *, id> *> *)paylines;

@end

NS_ASSUME_NONNULL_END
