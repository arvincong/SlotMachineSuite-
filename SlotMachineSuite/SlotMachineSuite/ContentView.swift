import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var game: SlotGameViewModel

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height

            ZStack {
                CasinoBackground()

                if isWide {
                    HStack(spacing: 18) {
                        VStack(spacing: 12) {
                            GameHeaderView()
                            JackpotStripView()
                            StatusPanelView()
                        }
                        .frame(maxWidth: 330)

                        SlotMachineView(reels: game.reels, isSpinning: game.isSpinning)

                        ControlPanelView()
                            .frame(maxWidth: 320)
                    }
                    .padding(24)
                } else {
                    VStack(spacing: 10) {
                        GameHeaderView()
                        JackpotStripView()
                        SlotMachineView(reels: game.reels, isSpinning: game.isSpinning)
                            .padding(.top, 4)
                        StatusPanelView()
                        ControlPanelView()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                }
            }
            .sheet(isPresented: $game.showPaytable) {
                PaytableView()
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

private struct CasinoBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.18),
                    Color(red: 0.20, green: 0.04, blue: 0.18),
                    Color(red: 0.02, green: 0.18, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color(red: 1.0, green: 0.74, blue: 0.18).opacity(0.42), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 330
            )
            .ignoresSafeArea()

            VStack {
                CoinCurtain()
                    .frame(height: 140)
                Spacer()
            }
            .ignoresSafeArea()
        }
    }
}

private struct CoinCurtain: View {
    private let offsets: [(x: CGFloat, y: CGFloat, scale: CGFloat)] = [
        (0.08, 0.24, 0.8), (0.22, 0.10, 1.1), (0.42, 0.32, 0.7),
        (0.64, 0.14, 1.0), (0.82, 0.28, 0.86), (0.94, 0.08, 1.2)
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(offsets.indices, id: \.self) { index in
                CoinView()
                    .frame(width: 40 * offsets[index].scale, height: 40 * offsets[index].scale)
                    .position(
                        x: proxy.size.width * offsets[index].x,
                        y: proxy.size.height * offsets[index].y
                    )
                    .rotationEffect(.degrees(Double(index * 24)))
            }
        }
    }
}

private struct CoinView: View {
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.95, blue: 0.30), Color(red: 0.92, green: 0.45, blue: 0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(Circle().stroke(Color.white.opacity(0.75), lineWidth: 2))
            .overlay(
                Image(systemName: "dollarsign")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color(red: 0.55, green: 0.20, blue: 0.04))
            )
            .shadow(color: Color.yellow.opacity(0.55), radius: 12)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SlotGameViewModel())
    }
}
