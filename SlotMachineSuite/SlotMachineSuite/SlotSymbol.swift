import SwiftUI

enum SlotSymbol: String, CaseIterable, Identifiable {
    case nova
    case crown
    case gem
    case bell
    case seven
    case coin
    case wild
    case bonus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nova: "NOVA"
        case .crown: "CROWN"
        case .gem: "GEM"
        case .bell: "BELL"
        case .seven: "SEVEN"
        case .coin: "COIN"
        case .wild: "WILD"
        case .bonus: "BONUS"
        }
    }

    var systemImage: String {
        switch self {
        case .nova: "sparkles"
        case .crown: "crown.fill"
        case .gem: "diamond.fill"
        case .bell: "bell.fill"
        case .seven: "7.circle.fill"
        case .coin: "dollarsign.circle.fill"
        case .wild: "wand.and.stars"
        case .bonus: "gift.fill"
        }
    }

    var palette: [Color] {
        switch self {
        case .nova: [Color(red: 0.14, green: 0.78, blue: 0.95), Color(red: 0.03, green: 0.25, blue: 0.77)]
        case .crown: [Color(red: 1.0, green: 0.87, blue: 0.24), Color(red: 0.93, green: 0.35, blue: 0.12)]
        case .gem: [Color(red: 0.95, green: 0.19, blue: 0.72), Color(red: 0.32, green: 0.08, blue: 0.72)]
        case .bell: [Color(red: 0.99, green: 0.70, blue: 0.18), Color(red: 0.98, green: 0.20, blue: 0.20)]
        case .seven: [Color(red: 0.98, green: 0.14, blue: 0.24), Color(red: 0.42, green: 0.02, blue: 0.12)]
        case .coin: [Color(red: 0.96, green: 0.93, blue: 0.39), Color(red: 0.08, green: 0.65, blue: 0.28)]
        case .wild: [Color(red: 1.0, green: 0.95, blue: 0.36), Color(red: 0.13, green: 0.74, blue: 0.44)]
        case .bonus: [Color(red: 0.36, green: 0.93, blue: 1.0), Color(red: 0.04, green: 0.39, blue: 0.94)]
        }
    }

    var weight: Int {
        switch self {
        case .nova: 18
        case .crown: 16
        case .gem: 14
        case .bell: 14
        case .seven: 10
        case .coin: 12
        case .wild: 8
        case .bonus: 8
        }
    }

    var payoutMultiplier: Int {
        switch self {
        case .nova: 2
        case .crown: 3
        case .gem: 4
        case .bell: 5
        case .seven: 8
        case .coin: 6
        case .wild: 10
        case .bonus: 12
        }
    }
}

struct Payline: Identifiable {
    let id = UUID()
    let name: String
    let rows: [Int]
}

struct SpinResult {
    let lineWin: Int
    let bonusWin: Int
    let jackpotWin: Int

    var total: Int { lineWin + bonusWin + jackpotWin }
}
