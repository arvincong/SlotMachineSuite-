import SwiftUI

struct SlotMachineView: View {
    let reels: [[SlotSymbol]]
    let isSpinning: Bool

    var body: some View {
        GeometryReader { proxy in
            let tileGap: CGFloat = 6
            let tileWidth = (proxy.size.width - tileGap * 4) / 5
            let tileHeight = min((proxy.size.height - tileGap * 2) / 3, tileWidth * 1.16)

            VStack(spacing: tileGap) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: tileGap) {
                        ForEach(0..<5, id: \.self) { column in
                            SymbolTile(symbol: reels[column][row], isSpinning: isSpinning)
                                .frame(width: tileWidth, height: tileHeight)
                                .id("\(column)-\(row)-\(reels[column][row].id)-\(isSpinning)")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1.32, contentMode: .fit)
        .padding(10)
        .background(CabinetFrame())
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        colors: [Color.white, Color(red: 1.0, green: 0.78, blue: 0.18), Color(red: 0.34, green: 0.94, blue: 0.50)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
        )
        .shadow(color: Color.black.opacity(0.45), radius: 16, y: 10)
    }
}

private struct SymbolTile: View {
    let symbol: SlotSymbol
    let isSpinning: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.10, blue: 0.18), Color(red: 0.02, green: 0.03, blue: 0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))

            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: symbol.palette,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(7)
                .shadow(color: symbol.palette.first?.opacity(0.55) ?? .clear, radius: 8)

            VStack(spacing: 2) {
                Image(systemName: symbol.systemImage)
                    .font(.system(size: 30, weight: .black))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 2, y: 2)
                    .minimumScaleFactor(0.5)

                Text(symbol.title)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .padding(8)
            .opacity(isSpinning ? 0.82 : 1)
            .scaleEffect(isSpinning ? 0.92 : 1)
            .animation(.easeOut(duration: 0.16), value: symbol)
        }
        .clipped()
    }
}

private struct CabinetFrame: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.92, green: 0.13, blue: 0.50),
                        Color(red: 0.18, green: 0.05, blue: 0.36),
                        Color(red: 0.02, green: 0.31, blue: 0.23)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.45), lineWidth: 6)
            )
    }
}
