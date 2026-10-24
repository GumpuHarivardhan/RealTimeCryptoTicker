import SwiftUI

struct TickerRowView: View {
    let coin: Coin

    /// Is the green/red highlight showing right now?
    /// It belongs to this row only, so flashing BTC doesn't touch ETH or SOL.
    @State private var isFlashing = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(coin.name)
                    .font(.headline)
                Text(coin.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(priceText)
                    .font(.headline.monospacedDigit())
                Text(changeText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(coin.change >= 0 ? Color.green : Color.red)
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(flashColor.opacity(isFlashing ? 0.3 : 0))
        // Runs every time `flashCount` changes. If a new update arrives
        // before the last flash ends, SwiftUI cancels the old one first.
        .task(id: coin.flashCount) {
            await flash()
        }
    }

    private func flash() async {
        guard coin.flashCount > 0 else { return } // don't flash when the row first appears

        isFlashing = true
        do {
            try await Task.sleep(for: .milliseconds(300))
        } catch {
            return // a newer update took over
        }
        withAnimation(.easeOut(duration: 0.5)) {
            isFlashing = false
        }
    }

    private var flashColor: Color {
        coin.direction == .down ? .red : .green
    }

    private var priceText: String {
        guard let price = coin.price else { return "—" }
        return price.formatted(.currency(code: "USD"))
    }

    private var changeText: String {
        String(format: "%+.2f (%+.2f%%)", coin.change, coin.changePercent)
    }
}
