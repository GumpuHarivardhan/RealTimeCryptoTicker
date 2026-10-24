import SwiftUI

struct TickerListView: View {
    let viewModel: TickerViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MarketHeader()

                    // This only reads `viewModel.coins`, which never changes,
                    // so price updates never redraw the list.
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.coins) { coin in
                            TickerRowView(coin: coin)
                        }
                    }

                    Text("Prices from Binance · USDT pairs · 24h change")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Markets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ConnectionBadge(viewModel: viewModel)
                }
            }
        }
        // Starts the live feed when the screen appears and stops it
        // (closing the socket) when the screen goes away.
        .task {
            await viewModel.start()
        }
    }
}

/// Static section title. Reads no live state, so it never redraws.
private struct MarketHeader: View {
    var body: some View {
        HStack {
            Text("Watchlist")
                .font(.title3.weight(.semibold))
            Spacer()
            Label("Real-time", systemImage: "bolt.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}

/// "Live" / "Reconnecting…" pill. It's its own view so a connection change
/// only redraws this pill, not the list.
private struct ConnectionBadge: View {
    let viewModel: TickerViewModel

    var body: some View {
        let isConnected = viewModel.isConnected
        let tint: Color = isConnected ? .green : .orange

        HStack(spacing: 6) {
            Image(systemName: isConnected ? "circle.fill" : "wifi.exclamationmark")
                .font(.system(size: isConnected ? 7 : 10, weight: .bold))
                .symbolEffect(.pulse, options: .repeating)
            Text(isConnected ? "Live" : "Reconnecting…")
                .font(.caption.weight(.semibold))
                .contentTransition(.opacity)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.15), in: Capsule())
        .animation(.snappy, value: isConnected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isConnected ? "Connected, live prices" : "Reconnecting")
    }
}

#Preview {
    TickerListView(viewModel: TickerViewModel())
}
