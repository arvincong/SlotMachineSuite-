import SwiftUI

struct PaytableView: View {
    @EnvironmentObject private var game: SlotGameViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.07, green: 0.07, blue: 0.15), Color(red: 0.17, green: 0.03, blue: 0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(SlotSymbol.allCases) { symbol in
                            HStack(spacing: 12) {
                                SymbolPreview(symbol: symbol)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(symbol.title)
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("3+ from left pays x\(symbol.payoutMultiplier)")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.68))
                                }

                                Spacer()

                                Text((game.bet * symbol.payoutMultiplier * 3 / 5).formatted())
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                    .foregroundStyle(Color(red: 1.0, green: 0.91, blue: 0.22))
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.16), lineWidth: 1))
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("PAYLINES")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            ForEach(game.paylines) { line in
                                HStack {
                                    Text(line.name)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                    Spacer()
                                    Text(line.rows.map { "\($0 + 1)" }.joined(separator: "-"))
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                }
                                .foregroundStyle(.white.opacity(0.78))
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.26)))
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Paytable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .black))
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}

private struct SymbolPreview: View {
    let symbol: SlotSymbol

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(LinearGradient(colors: symbol.palette, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 54, height: 54)
            .overlay(
                Image(systemName: symbol.systemImage)
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(.white)
            )
    }
}

struct PaytableView_Previews: PreviewProvider {
    static var previews: some View {
        PaytableView()
            .environmentObject(SlotGameViewModel())
    }
}
