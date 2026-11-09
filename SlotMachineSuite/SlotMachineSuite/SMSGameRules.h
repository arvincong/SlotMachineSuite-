#ifndef SMSGameRules_h
#define SMSGameRules_h

#include <stdbool.h>
#include <stdint.h>

// Symbol indices match SlotSymbolType; kept portable for deterministic checks.
enum { SMSColumns = 5, SMSRows = 3, SMSLines = 5, SMSSymbols = 8, SMSWild = 6, SMSBonus = 7 };
static const int SMSPaylines[SMSLines][SMSColumns] = {
    {0, 0, 0, 0, 0}, {1, 1, 1, 1, 1}, {2, 2, 2, 2, 2},
    {2, 1, 0, 1, 2}, {0, 1, 2, 1, 0}
};
static const int SMSMultipliers[SMSSymbols] = {2, 3, 4, 5, 8, 6, 10, 0};
static const int64_t SMSStartingCredits = 50000;
static const int64_t SMSStartingJackpot = 1250000;
static const int64_t SMSMaxCredits = INT64_C(1000000000000);
static const int64_t SMSMaxSpins = INT64_C(1000000000);

static inline int64_t SMSClampCredits(int64_t amount) {
    return amount > SMSMaxCredits ? SMSMaxCredits : amount;
}

static inline bool SMSValidBet(int64_t bet) {
    return bet == 100 || bet == 250 || bet == 500 || bet == 1000 || bet == 2500 || bet == 5000;
}

static inline bool SMSValidBoard(const int board[SMSColumns][SMSRows]) {
    for (int c = 0; c < SMSColumns; c++)
        for (int r = 0; r < SMSRows; r++)
            if (board[c][r] < 0 || board[c][r] >= SMSSymbols) return false;
    return true;
}

static inline bool SMSValidState(int64_t balance, int64_t bet, int64_t lastWin,
                                 int64_t jackpot, int64_t spins) {
    return balance >= 0 && balance <= SMSMaxCredits && SMSValidBet(bet) &&
        lastWin >= 0 && lastWin <= SMSMaxCredits && jackpot >= SMSStartingJackpot &&
        jackpot <= SMSMaxCredits && spins >= 0 && spins <= SMSMaxSpins;
}

static inline int64_t SMSLinePayout(int symbol, int matches, int64_t bet) {
    if (symbol < 0 || symbol >= SMSBonus || matches < 3 || matches > SMSColumns || !SMSValidBet(bet)) return 0;
    return bet * SMSMultipliers[symbol] * matches / SMSLines;
}

typedef struct {
    int64_t lineWin;
    int64_t bonusWin;
    int64_t jackpotWin;
    int64_t total;
    int bonusCount;
} SMSGameResult;

static inline SMSGameResult SMSEvaluateBoard(const int board[SMSColumns][SMSRows], int64_t bet, int64_t jackpot) {
    SMSGameResult result = {0};
    if (!SMSValidBoard(board) || !SMSValidBet(bet) || jackpot < SMSStartingJackpot || jackpot > SMSMaxCredits) return result;
    for (int line = 0; line < SMSLines; line++) {
        int64_t best = 0;
        // Pick the highest valid left-to-right match. A BONUS is a scatter only;
        // WILD never substitutes for BONUS and cannot bridge a broken match.
        for (int candidate = 0; candidate <= SMSWild; candidate++) {
            int matches = 0;
            for (int col = 0; col < SMSColumns; col++) {
                int symbol = board[col][SMSPaylines[line][col]];
                if (symbol != candidate && symbol != SMSWild) break;
                matches++;
            }
            int64_t payout = SMSLinePayout(candidate, matches, bet);
            if (payout > best) best = payout;
        }
        result.lineWin += best;
    }
    for (int c = 0; c < SMSColumns; c++)
        for (int r = 0; r < SMSRows; r++)
            if (board[c][r] == SMSBonus) result.bonusCount++;
    result.bonusWin = result.bonusCount >= 4 ? bet * result.bonusCount * 4 : 0;
    result.jackpotWin = result.bonusCount >= 7 ? jackpot : 0;
    result.total = SMSClampCredits(result.lineWin + result.bonusWin + result.jackpotWin);
    return result;
}

#endif
