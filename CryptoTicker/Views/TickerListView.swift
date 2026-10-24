import SwiftUI

struct TickerListView: View {
    let viewModel: TickerViewModel

    var body: some View {
        NavigationStack {
            // This only reads `viewModel.coins`, which never changes,
            // so price updates never redraw the list.
            List(viewModel.coins) { coin in
                TickerRowView(coin: coin)
            }
            .listStyle(.plain)
            .navigationTitle("Crypto Ticker")
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

/// "Live" / "Reconnecting…" label. It's its own view so a connection change
/// only redraws this label, not the list.
private struct ConnectionBadge: View {
    let viewModel: TickerViewModel

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(viewModel.isConnected ? "Live" : "Reconnecting…")
                .font(.caption)
        }
    }
}

#Preview {
    TickerListView(viewModel: TickerViewModel())
}
