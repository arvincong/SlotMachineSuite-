import SwiftUI

struct GameHeaderView: View {
    @EnvironmentObject private var game: SlotGameViewModel

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                TopMetricView(title: "BALANCE", value: game.balance.formatted())
                Button {
                    game.showPaytable = true
                } label: {
                    Image(systemName: "list.bullet.rectangle.portrait.fill")
                        .font(.system(size: 20, weight: .heavy))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(GlassIconButtonStyle(tint: Color(red: 0.11, green: 0.72, blue: 0.96)))
                .accessibilityLabel("Paytable")
            }

            VStack(spacing: -2) {
                Text("STARLIGHT")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 3, y: 2)
                Text("JACKPOT")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color(red: 1.0, green: 0.93, blue: 0.28), Color(red: 1.0, green: 0.33, blue: 0.18)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(red: 0.77, green: 0.04, blue: 0.12), radius: 2, y: 3)
            }
            .minimumScaleFactor(0.72)
            .lineLimit(1)
        }
    }
}

struct JackpotStripView: View {
    @EnvironmentObject private var game: SlotGameViewModel

    var body: some View {
        HStack(spacing: 8) {
            JackpotBadge(title: "MINI", value: game.bet * 20, tint: Color(red: 0.20, green: 0.84, blue: 0.38))
            JackpotBadge(title: "MAJOR", value: game.bet * 120, tint: Color(red: 0.13, green: 0.64, blue: 0.95))
            JackpotBadge(title: "GRAND", value: game.jackpot, tint: Color(red: 0.98, green: 0.24, blue: 0.30))
        }
    }
}

struct StatusPanelView: View {
    @EnvironmentObject private var game: SlotGameViewModel

    var body: some View {
        HStack(spacing: 10) {
            TopMetricView(title: "BET", value: game.bet.formatted())
            TopMetricView(title: "WIN", value: game.lastWin.formatted(), highlight: game.lastWin > 0)
            TopMetricView(title: "SPINS", value: game.spinCount.formatted())
        }
    }
}

private struct TopMetricView: View {
    let title: String
    let value: String
    var highlight = false

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(highlight ? Color(red: 1.0, green: 0.92, blue: 0.22) : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

private struct JackpotBadge: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
            Text(value.shortCredits)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.95), Color.black.opacity(0.58)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.45), lineWidth: 1.5))
        )
        .shadow(color: tint.opacity(0.35), radius: 10, y: 4)
    }
}

struct GlassIconButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.55), Color.black.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.38), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

extension Int {
    var shortCredits: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        }

        if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        }

        return formatted()
    }
}
