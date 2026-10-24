import Foundation

/// Talks to the Binance WebSocket.
///
/// It's an `actor`, so all socket work and JSON decoding run in the
/// background, never on the main thread, and only one piece of code
/// touches its state at a time.
actor BinanceSocket {
    enum Event: Sendable {
        case connected
        case disconnected
        case price(PriceUpdate)
    }

    private let url = URL(string: "wss://stream.binance.com:9443/ws")!
    private let symbols: [String]
    private let decoder = JSONDecoder()

    init(symbols: [String]) {
        self.symbols = symbols
    }

    /// Returns a stream of events. The socket stays open while someone is
    /// listening. When the listener stops, the socket closes by itself.
    nonisolated func events() -> AsyncStream<Event> {
        AsyncStream { continuation in
            let task = Task {
                await self.connectAndReconnect(continuation)
            }
            // The listener went away (for example, the screen closed): stop everything.
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private

    /// Connect, read messages, and if the connection drops, wait and
    /// try again. The wait doubles each time: 1s, 2s, 4s ... up to 30s.
    private func connectAndReconnect(_ continuation: AsyncStream<Event>.Continuation) async {
        var retryDelay = 1

        while !Task.isCancelled {
            let socket = URLSession.shared.webSocketTask(with: url)
            socket.resume()

            do {
                try await socket.send(.string(subscribeMessage()))
                continuation.yield(.connected)
                retryDelay = 1  // connected, so the next drop starts again at 1s
                try await readMessages(from: socket, continuation)
            } catch {
                // The connection failed or dropped. We'll try again below.
            }

            socket.cancel(with: .goingAway, reason: nil)
            continuation.yield(.disconnected)

            // Wait before reconnecting. If we're cancelled while waiting, stop.
            do {
                try await Task.sleep(for: .seconds(retryDelay))
            } catch {
                break
            }
            retryDelay = min(retryDelay * 2, 30)
        }

        continuation.finish()
    }

    /// Reads messages until the socket closes (then it throws).
    private func readMessages(
        from socket: URLSessionWebSocketTask,
        _ continuation: AsyncStream<Event>.Continuation
    ) async throws {
        // `receive()` doesn't stop by itself when the task is cancelled,
        // so on cancel we close the socket. That makes `receive()` throw.
        try await withTaskCancellationHandler {
            while true {
                let message = try await socket.receive()
                if let update = decode(message) {
                    continuation.yield(.price(update))
                }
            }
        } onCancel: {
            socket.cancel(with: .goingAway, reason: nil)
        }
    }

    /// Turns a socket message into a PriceUpdate. Anything that isn't a
    /// ticker (like the `{"result":null,"id":1}` reply) returns nil.
    private func decode(_ message: URLSessionWebSocketTask.Message) -> PriceUpdate? {
        guard case .string(let text) = message,
              let ticker = try? decoder.decode(BinanceTicker.self, from: Data(text.utf8))
        else { return nil }

        return ticker.toPriceUpdate()
    }

    /// {"method":"SUBSCRIBE","params":["btcusdt@ticker","ethusdt@ticker","solusdt@ticker"],"id":1}
    func subscribeMessage() -> String {
        let params = symbols
            .map { "\"\($0.lowercased())@ticker\"" }
            .joined(separator: ",")
        return "{\"method\":\"SUBSCRIBE\",\"params\":[\(params)],\"id\":1}"
    }
}
