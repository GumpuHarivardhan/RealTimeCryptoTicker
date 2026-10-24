import Foundation

/// One price update for one coin.
/// It's a simple struct (`Sendable`), so it can safely move from the
/// background socket to the main thread.
struct PriceUpdate: Sendable, Equatable {
    let symbol: String         // "BTCUSDT"
    let price: Double          // current price
    let change: Double         // 24h price change
    let changePercent: Double  // 24h % change
}

/// The JSON Binance sends. Field names match the JSON keys.
/// Binance sends numbers as strings, so we convert them below.
///
/// Example: {"e":"24hrTicker","s":"BTCUSDT","c":"67250.10","p":"-120.50","P":"-0.18", ...}
struct BinanceTicker: Decodable {
    let s: String  // symbol
    let c: String  // current price
    let p: String  // 24h price change
    let P: String  // 24h % change

    /// Returns nil if a number can't be read.
    func toPriceUpdate() -> PriceUpdate? {
        guard let price = Double(c),
              let change = Double(p),
              let percent = Double(P) else { return nil }

        return PriceUpdate(symbol: s, price: price, change: change, changePercent: percent)
    }
}
