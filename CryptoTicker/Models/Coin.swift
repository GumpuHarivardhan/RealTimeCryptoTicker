import Foundation
import Observation

/// The live state of ONE row in the list.
///
/// Every coin has its own @Observable object. SwiftUI remembers which
/// properties each view reads, so when BTC changes, only the BTC row
/// redraws. The other rows and the list are not touched.
@MainActor
@Observable
final class Coin: Identifiable {
    enum Direction {
        case up
        case down
    }

    let symbol: String  // "BTCUSDT"
    let name: String    // "Bitcoin"
    nonisolated var id: String { symbol }

    private(set) var price: Double?
    private(set) var change: Double = 0
    private(set) var changePercent: Double = 0

    /// Did the last update go up or down? Picks green or red.
    private(set) var direction: Direction?
    /// Goes up by 1 each time the row should flash.
    private(set) var flashCount = 0

    init(symbol: String, name: String) {
        self.symbol = symbol
        self.name = name
    }

    func update(with update: PriceUpdate) {
        // Nothing changed? Do nothing, so the row doesn't redraw for no reason.
        guard update.price != price || update.change != change else { return }

        // Compare with the last price. The very first update has nothing
        // to compare with, so it doesn't flash.
        if let oldPrice = price, update.price != oldPrice {
            direction = update.price > oldPrice ? .up : .down
            flashCount += 1
        }

        price = update.price
        change = update.change
        changePercent = update.changePercent
    }
}
