import Foundation
import SwiftUI

@MainActor
final class SlotGameViewModel: ObservableObject {
    @Published var reels: [[SlotSymbol]]
    @Published var balance: Int
    @Published var bet: Int
    @Published var lastWin: Int
    @Published var jackpot: Int
    @Published var message: String
    @Published var isSpinning: Bool
    @Published var showPaytable: Bool
    @Published var spinCount: Int

    let betOptions = [100, 250, 500, 1_000, 2_500, 5_000]
    let paylines: [Payline] = [
        Payline(name: "Top", rows: [0, 0, 0, 0, 0]),
        Payline(name: "Middle", rows: [1, 1, 1, 1, 1]),
        Payline(name: "Bottom", rows: [2, 2, 2, 2, 2]),
        Payline(name: "Rise", rows: [2, 1, 0, 1, 2]),
        Payline(name: "Dip", rows: [0, 1, 2, 1, 0])
    ]

    init() {
        reels = Self.randomReels()
        balance = 50_000
        bet = 500
        lastWin = 0
        jackpot = 1_250_000
        message = "Ready"
        isSpinning = false
        showPaytable = false
        spinCount = 0
    }

    func increaseBet() {
        guard let index = betOptions.firstIndex(of: bet), index < betOptions.count - 1 else { return }
        bet = betOptions[index + 1]
    }

    func decreaseBet() {
        guard let index = betOptions.firstIndex(of: bet), index > 0 else { return }
        bet = betOptions[index - 1]
    }

    func maxBet() {
        bet = betOptions.last ?? bet
    }

    func resetSession() {
        balance = 50_000
        bet = 500
        lastWin = 0
        jackpot = 1_250_000
        spinCount = 0
        message = "Ready"
        reels = Self.randomReels()
    }

    func spin() {
        guard !isSpinning else { return }
        guard balance >= bet else {
            message = "Add demo credits"
            return
        }

        balance -= bet
        jackpot += max(25, bet / 20)
        lastWin = 0
        message = "Spinning"
        isSpinning = true

        Task {
            for step in 0..<18 {
                reels = Self.randomReels()
                try? await Task.sleep(nanoseconds: UInt64(45_000_000 + step * 5_000_000))
            }

            let settledReels = Self.randomReels()
            reels = settledReels
            let result = evaluate(reels: settledReels)
            lastWin = result.total
            balance += result.total
            spinCount += 1

            if result.jackpotWin > 0 {
                message = "Grand jackpot"
                jackpot = 1_250_000
            } else if result.total > bet * 20 {
                message = "Mega win"
            } else if result.total > 0 {
                message = "Nice win"
            } else {
                message = "Try again"
            }

            isSpinning = false
        }
    }

    func evaluate(reels: [[SlotSymbol]]) -> SpinResult {
        var lineWin = 0

        for payline in paylines {
            let symbols = payline.rows.enumerated().map { column, row in reels[column][row] }
            let anchor = symbols.first { $0 != .wild } ?? .wild
            var matchCount = 0

            for symbol in symbols {
                if symbol == anchor || symbol == .wild || anchor == .wild {
                    matchCount += 1
                } else {
                    break
                }
            }

            if matchCount >= 3 {
                lineWin += bet * anchor.payoutMultiplier * matchCount / 5
            }
        }

        let bonusCount = reels.flatMap { $0 }.filter { $0 == .bonus }.count
        let bonusWin = bonusCount >= 4 ? bet * bonusCount * 4 : 0
        let jackpotHit = bonusCount >= 7 || Int.random(in: 1...2_500) == 1
        let jackpotWin = jackpotHit ? jackpot : 0

        return SpinResult(lineWin: lineWin, bonusWin: bonusWin, jackpotWin: jackpotWin)
    }

    static func randomReels() -> [[SlotSymbol]] {
        (0..<5).map { _ in
            (0..<3).map { _ in weightedSymbol() }
        }
    }

    private static func weightedSymbol() -> SlotSymbol {
        let totalWeight = SlotSymbol.allCases.reduce(0) { $0 + $1.weight }
        var ticket = Int.random(in: 1...totalWeight)

        for symbol in SlotSymbol.allCases {
            ticket -= symbol.weight
            if ticket <= 0 {
                return symbol
            }
        }

        return .nova
    }
}
