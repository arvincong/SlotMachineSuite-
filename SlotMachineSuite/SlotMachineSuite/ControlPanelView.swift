import SwiftUI

struct ControlPanelView: View {
    @EnvironmentObject private var game: SlotGameViewModel

    var body: some View {
        VStack(spacing: 10) {
            Text(game.message.uppercased())
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(game.lastWin > 0 ? Color(red: 1.0, green: 0.92, blue: 0.24) : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: 26)

            HStack(spacing: 10) {
                Button {
                    game.decreaseBet()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .black))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(GlassIconButtonStyle(tint: Color(red: 0.10, green: 0.54, blue: 0.96)))
                .disabled(game.isSpinning)
                .accessibilityLabel("Decrease bet")

                VStack(spacing: 2) {
                    Text("BET")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(game.bet.formatted())
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))

                Button {
                    game.increaseBet()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .black))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(GlassIconButtonStyle(tint: Color(red: 0.10, green: 0.54, blue: 0.96)))
                .disabled(game.isSpinning)
                .accessibilityLabel("Increase bet")

                Button("MAX") {
                    game.maxBet()
                }
                .font(.system(size: 14, weight: .black, design: .rounded))
                .buttonStyle(PillCommandButtonStyle(tint: Color(red: 0.97, green: 0.36, blue: 0.16)))
                .disabled(game.isSpinning)
            }

            HStack(spacing: 12) {
                Button {
                    game.resetSession()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .black))
                        .frame(width: 50, height: 52)
                }
                .buttonStyle(GlassIconButtonStyle(tint: Color(red: 0.68, green: 0.16, blue: 0.78)))
                .disabled(game.isSpinning)
                .accessibilityLabel("Reset demo credits")

                Button {
                    game.spin()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: game.isSpinning ? "sparkle.magnifyingglass" : "play.fill")
                            .font(.system(size: 22, weight: .black))
                        Text(game.isSpinning ? "SPINNING" : "SPIN")
                            .font(.system(size: 25, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                }
                .buttonStyle(SpinButtonStyle())
                .disabled(game.isSpinning)
            }

            Text("Virtual coins only")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.55, green: 0.02, blue: 0.42), Color(red: 0.10, green: 0.04, blue: 0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.24), lineWidth: 1))
        )
    }
}

struct PillCommandButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(minWidth: 54, minHeight: 42)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.5), Color.black.opacity(0.38)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.28), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

private struct SpinButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.68, green: 1.0, blue: 0.22),
                                Color(red: 0.08, green: 0.72, blue: 0.18),
                                Color(red: 0.02, green: 0.32, blue: 0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.72), lineWidth: 2))
            )
            .shadow(color: Color.green.opacity(0.48), radius: 14, y: 5)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}
