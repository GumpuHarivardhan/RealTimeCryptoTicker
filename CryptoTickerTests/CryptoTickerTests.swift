import Foundation
import Testing
@testable import CryptoTicker

struct BinanceTickerTests {
    @Test func decodesTickerJSON() throws {
        let json = #"{"e":"24hrTicker","s":"BTCUSDT","c":"67250.10","p":"-120.50","P":"-0.18"}"#
        let ticker = try JSONDecoder().decode(BinanceTicker.self, from: Data(json.utf8))
        let update = try #require(ticker.toPriceUpdate())

        #expect(update.symbol == "BTCUSDT")
        #expect(update.price == 67250.10)
        #expect(update.change == -120.50)
        #expect(update.changePercent == -0.18)
    }

    @Test func buildsSubscribeMessage() async {
        let socket = BinanceSocket(symbols: ["BTCUSDT", "ETHUSDT", "SOLUSDT"])
        let message = await socket.subscribeMessage()
        #expect(message == #"{"method":"SUBSCRIBE","params":["btcusdt@ticker","ethusdt@ticker","solusdt@ticker"],"id":1}"#)
    }
}

@MainActor
struct CoinTests {
    private func update(_ price: Double) -> PriceUpdate {
        PriceUpdate(symbol: "BTCUSDT", price: price, change: 0, changePercent: 0)
    }

    @Test func firstUpdateDoesNotFlash() {
        let coin = Coin(symbol: "BTCUSDT", name: "Bitcoin")
        coin.update(with: update(100))
        #expect(coin.flashCount == 0)
    }

    @Test func priceUpFlashesGreen() {
        let coin = Coin(symbol: "BTCUSDT", name: "Bitcoin")
        coin.update(with: update(100))
        coin.update(with: update(101))
        #expect(coin.direction == .up)
        #expect(coin.flashCount == 1)
    }

    @Test func priceDownFlashesRed() {
        let coin = Coin(symbol: "BTCUSDT", name: "Bitcoin")
        coin.update(with: update(100))
        coin.update(with: update(99))
        #expect(coin.direction == .down)
        #expect(coin.flashCount == 1)
    }
}
