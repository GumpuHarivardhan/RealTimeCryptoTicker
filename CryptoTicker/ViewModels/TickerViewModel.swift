import Foundation
import Observation

/// Screen state: the list of coins and whether we're connected.
/// It's on the main actor because it updates the UI.
@MainActor
@Observable
final class TickerViewModel {
    /// Created once and never replaced. Prices change INSIDE each Coin,
    /// so the list itself never has to redraw.
    let coins: [Coin]

    var isConnected = false

    private let socket: BinanceSocket

    init() {
        let coins = [
            Coin(symbol: "BTCUSDT", name: "Bitcoin"),
            Coin(symbol: "ETHUSDT", name: "Ethereum"),
            Coin(symbol: "SOLUSDT", name: "Solana"),
        ]
        self.coins = coins
        self.socket = BinanceSocket(symbols: coins.map { $0.symbol })
    }

    /// Call this from the view's `.task { }`. SwiftUI cancels that task when
    /// the screen goes away, which ends this loop and closes the socket.
    /// We don't keep the Task ourselves, so there's no retain cycle.
    func start() async {
        for await event in socket.events() {
            switch event {
            case .connected:
                isConnected = true
            case .disconnected:
                isConnected = false
            case .price(let update):
                coins.first(where: { $0.symbol == update.symbol })?.update(with: update)
            }
        }
    }
}
