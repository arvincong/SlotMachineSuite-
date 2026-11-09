#include "SMSGameRules.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned checks;
static void check(bool condition, const char *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", message); exit(1); }
    checks++;
}
static void fill(int board[SMSColumns][SMSRows], int symbol) {
    for (int c = 0; c < SMSColumns; c++)
        for (int r = 0; r < SMSRows; r++) board[c][r] = symbol;
}
static void scatterBoard(int board[SMSColumns][SMSRows], int count) {
    for (int c = 0; c < SMSColumns; c++)
        for (int r = 0; r < SMSRows; r++) board[c][r] = (c + r) % 6;
    for (int i = 0; i < count; i++) board[i / SMSRows][i % SMSRows] = SMSBonus;
}
int main(void) {
    int board[SMSColumns][SMSRows];
    fill(board, 0);
    SMSGameResult result = SMSEvaluateBoard(board, 500, SMSStartingJackpot);
    check(result.lineWin == 5000 && result.total == 5000, "five full NOVA paylines are each paid once");
    fill(board, SMSWild);
    result = SMSEvaluateBoard(board, 500, SMSStartingJackpot);
    check(result.lineWin == 25000 && result.bonusWin == 0, "all WILD board uses the WILD payout");
    fill(board, SMSBonus);
    result = SMSEvaluateBoard(board, 500, SMSStartingJackpot);
    check(result.lineWin == 0 && result.bonusCount == 15, "BONUS is scatter only");
    check(result.bonusWin == 30000 && result.jackpotWin == SMSStartingJackpot, "scatter and jackpot stack");
    check(result.total == 1280000, "jackpot total includes scatter reward");
    fill(board, SMSBonus);
    board[0][0] = board[1][0] = board[2][0] = 0;
    board[3][0] = 1;
    board[4][0] = 2;
    result = SMSEvaluateBoard(board, 500, SMSStartingJackpot);
    check(result.lineWin == 600, "a three-symbol run stops at the first mismatch");
    board[0][0] = board[1][0] = board[2][0] = SMSWild;
    board[3][0] = board[4][0] = 0;
    result = SMSEvaluateBoard(board, 500, SMSStartingJackpot);
    check(result.lineWin == 3000, "leading WILDs choose the highest valid payout");
    board[0][0] = 0; board[1][0] = 1; board[2][0] = board[3][0] = board[4][0] = 0;
    result = SMSEvaluateBoard(board, 500, SMSStartingJackpot);
    check(result.lineWin == 0, "later matching symbols cannot bridge a broken leftmost run");
    fill(board, SMSBonus);
    for (int col = 0; col < SMSColumns; col++) board[col][SMSPaylines[3][col]] = 2;
    result = SMSEvaluateBoard(board, 500, SMSStartingJackpot);
    check(result.lineWin == 2000, "Rise diagonal uses the documented row path");
    for (int count = 0; count <= SMSColumns * SMSRows; count++) {
        scatterBoard(board, count);
        result = SMSEvaluateBoard(board, 500, SMSStartingJackpot);
        check(result.bonusCount == count, "scatter count matches the entire board");
        check(result.bonusWin == (count >= 4 ? 500 * count * 4 : 0), "scatter threshold is exactly four");
        check(result.jackpotWin == (count >= 7 ? SMSStartingJackpot : 0), "jackpot threshold is exactly seven");
    }
    fill(board, 0);
    board[4][2] = SMSSymbols;
    check(!SMSValidBoard(board) && SMSEvaluateBoard(board, 500, SMSStartingJackpot).total == 0, "invalid symbol rejected");
    board[4][2] = -1;
    check(!SMSValidBoard(board), "negative symbol rejected");
    fill(board, 0);
    check(SMSEvaluateBoard(board, -500, SMSStartingJackpot).total == 0, "negative wager rejected");
    check(SMSEvaluateBoard(board, 101, SMSStartingJackpot).total == 0, "unsupported wager rejected");
    check(SMSEvaluateBoard(board, 500, -1).total == 0, "invalid pool rejected");
    check(SMSValidState(50000, 500, 0, SMSStartingJackpot, 0), "initial game state accepted");
    check(!SMSValidState(-1, 500, 0, SMSStartingJackpot, 0), "negative saved balance rejected");
    check(!SMSValidState(SMSMaxCredits + 1, 500, 0, SMSStartingJackpot, 0), "oversized saved balance rejected");
    check(!SMSValidState(50000, 101, 0, SMSStartingJackpot, 0), "unsupported saved bet rejected");
    check(!SMSValidState(50000, 500, -1, SMSStartingJackpot, 0), "negative saved win rejected");
    check(!SMSValidState(50000, 500, 0, SMSStartingJackpot - 1, 0), "invalid saved pool rejected");
    check(!SMSValidState(50000, 500, 0, SMSStartingJackpot, SMSMaxSpins + 1), "oversized spin count rejected");
    fill(board, SMSBonus);
    result = SMSEvaluateBoard(board, 5000, SMSMaxCredits);
    check(result.total == SMSMaxCredits, "maximum-pool payout saturates safely");
    check(SMSClampCredits(SMSMaxCredits + 50000) == SMSMaxCredits, "free coin refill saturates safely");
    unsigned randomState = 123456789;
    for (int sample = 0; sample < 20000; sample++) {
        for (int col = 0; col < SMSColumns; col++) {
            for (int row = 0; row < SMSRows; row++) {
                randomState = randomState * 1664525u + 1013904223u;
                board[col][row] = (int)((randomState >> 16) % SMSSymbols);
            }
        }
        result = SMSEvaluateBoard(board, 5000, SMSStartingJackpot);
        check(result.total == result.lineWin + result.bonusWin + result.jackpotWin, "awards sum across randomized boards");
        check(result.lineWin >= 0 && result.lineWin <= 250000, "line awards stay within the documented maximum");
        check((result.jackpotWin > 0) == (result.bonusCount >= 7), "there is no hidden jackpot draw");
        int64_t after = SMSClampCredits(50000 - 5000 + result.total);
        check(SMSValidState(after, 5000, result.total, SMSStartingJackpot, sample + 1), "settled state remains restorable");
    }
    printf("PASS: %u game rule checks (including 20,000 deterministic boards)\n", checks);
    return 0;
}
