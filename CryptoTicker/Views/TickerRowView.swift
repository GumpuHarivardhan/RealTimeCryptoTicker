import SwiftUI

struct TickerRowView: View {
    let coin: Coin

    /// Is the green/red highlight showing right now?
    /// It belongs to this row only, so flashing BTC doesn't touch ETH or SOL.
    @State private var isFlashing = false

    var body: some View {
        HStack(spacing: 14) {
            CoinIcon(symbol: coin.symbol)

            VStack(alignment: .leading, spacing: 3) {
                Text(coin.name)
                    .font(.headline)
                Text("\(baseSymbol) / USDT")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                priceLabel
                ChangePill(change: coin.change, percent: coin.changePercent)
                    .opacity(coin.price == nil ? 0 : 1)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                // Only this overlay animates on a flash. Layout never changes.
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(flashColor.opacity(isFlashing ? 0.16 : 0))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(flashColor.opacity(isFlashing ? 0.6 : 0), lineWidth: 1.5)
                }
        }
        .accessibilityElement(children: .combine)
        // Runs every time `flashCount` changes. If a new update arrives
        // before the last flash ends, SwiftUI cancels the old one first.
        .task(id: coin.flashCount) {
            await flash()
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var priceLabel: some View {
        if let price = coin.price {
            Text(price, format: .currency(code: "USD"))
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(isFlashing ? flashColor : .primary)
                .contentTransition(.numericText(value: price))
                .animation(.snappy(duration: 0.25), value: price)
        } else {
            // Waiting for the first price: show a shimmer-style placeholder.
            Text("$00,000.00")
                .font(.title3.weight(.semibold).monospacedDigit())
                .redacted(reason: .placeholder)
                .accessibilityLabel("Loading price")
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

    /// "BTCUSDT" → "BTC"
    private var baseSymbol: String {
        coin.symbol.hasSuffix("USDT") ? String(coin.symbol.dropLast(4)) : coin.symbol
    }
}

// MARK: - Change pill

/// Capsule showing the 24h % change, with the absolute change underneath.
private struct ChangePill: View {
    let change: Double
    let percent: Double

    var body: some View {
        let isUp = change >= 0
        let tint: Color = isUp ? .green : .red

        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2.weight(.bold))
                Text(String(format: "%.2f%%", abs(percent)))
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())

            Text(String(format: "%+.2f", change))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "%@ %.2f percent in 24 hours", isUp ? "Up" : "Down", abs(percent)))
    }
}

// MARK: - Coin icon

/// Round brand-coloured badge for each coin.
private struct CoinIcon: View {
    let symbol: String

    var body: some View {
        let style = Self.style(for: symbol)

        ZStack {
            Circle()
                .fill(LinearGradient(colors: style.colors,
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
            if let glyph = style.systemImage {
                Image(systemName: glyph)
                    .font(.system(size: 20, weight: .bold))
            } else {
                Text(style.letters)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
            }
        }
        .foregroundStyle(.white)
        .frame(width: 44, height: 44)
        .shadow(color: style.colors.first!.opacity(0.35), radius: 6, y: 3)
        .accessibilityHidden(true)
    }

    private struct Style {
        var colors: [Color]
        var systemImage: String?
        var letters: String
    }

    private static func style(for symbol: String) -> Style {
        switch symbol {
        case "BTCUSDT":
            return Style(colors: [Color(red: 0.97, green: 0.62, blue: 0.10),
                                  Color(red: 0.93, green: 0.45, blue: 0.05)],
                         systemImage: "bitcoinsign", letters: "B")
        case "ETHUSDT":
            return Style(colors: [Color(red: 0.45, green: 0.50, blue: 0.95),
                                  Color(red: 0.30, green: 0.32, blue: 0.75)],
                         systemImage: "diamond.fill", letters: "E")
        case "SOLUSDT":
            return Style(colors: [Color(red: 0.60, green: 0.27, blue: 1.00),
                                  Color(red: 0.08, green: 0.85, blue: 0.65)],
                         systemImage: nil, letters: "SOL")
        default:
            return Style(colors: [.gray, .secondary], systemImage: nil,
                         letters: String(symbol.prefix(1)))
        }
    }
}
