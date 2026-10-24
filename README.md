# Crypto Ticker

A simple iOS app that shows live **Bitcoin, Ethereum and Solana** prices from the Binance WebSocket.

- When a price goes **up**, the row flashes **green**. When it goes **down**, it flashes **red**.
- If the internet drops, the app **reconnects by itself**.

**Built with:** SwiftUI, Swift Concurrency (`async/await`, `actor`, `Task`), and the Observation framework (`@Observable`). No third-party libraries.
**Needs:** Xcode 16+, iOS 17+.

## How to run

1. Open `CryptoTicker.xcodeproj` in Xcode.
2. Pick an iPhone simulator.
3. Press **⌘R** to run, or **⌘U** to run the tests.

## Files

```
CryptoTicker/
├── CryptoTickerApp.swift        Starts the app
├── Models/
│   ├── PriceUpdate.swift        One price update + the Binance JSON format
│   └── Coin.swift               The live state of one row (@Observable)
├── Network/
│   └── BinanceSocket.swift      WebSocket connection + reconnect (actor)
├── ViewModels/
│   └── TickerViewModel.swift    The list of coins + "connected?" flag
└── Views/
    ├── TickerListView.swift     The Markets screen + Live badge
    └── TickerRowView.swift      One coin card + the flash animation
```

## How the data moves

```
Binance WebSocket
     │  JSON text
     ▼
BinanceSocket        (actor, runs in the background)
     │  turns JSON into PriceUpdate
     ▼
TickerViewModel      (main thread)
     │  finds the right Coin, e.g. BTC
     ▼
Coin (BTC)  ──►  only the BTC row redraws
```

---

## 1. Concurrency: keeping the main thread free

**`BinanceSocket` is an `actor`.** An actor runs its code in the background, one piece at a time. So connecting, reading messages and decoding JSON **never run on the main thread**, and the UI stays smooth.

**`async/await` instead of callbacks.** Reading the socket is a plain loop:

```swift
while true {
    let message = try await socket.receive()
    // decode and send it to the UI
}
```

**`AsyncStream` sends data to the UI.** The socket puts events into a stream, and the view model reads them with `for await`:

```swift
for await event in socket.events() {
    switch event {
    case .connected:          isConnected = true
    case .disconnected:       isConnected = false
    case .price(let update):  coins.first(where: ...)?.update(with: update)
    }
}
```

Only small `Sendable` structs (`PriceUpdate`) travel from the background to the main thread. Swift checks that this is safe at compile time.

## 2. State management: only the changed row redraws

This is the most important part. **A BTC price update must not redraw the whole list.**

The app uses **`@Observable`** (iOS 17). With `@Observable`, SwiftUI tracks **exactly which properties each view reads**. When a property changes, only the views that read it redraw.

So the state is split into small pieces:

| What | Read by | Changes when |
|---|---|---|
| `viewModel.coins` (the array) | The list | **Never.** It's created once. |
| `viewModel.isConnected` | Only the "Live" badge | The connection changes |
| One `Coin` object per coin | Only its own row | That coin's price changes |

When a BTC update arrives:

1. The view model finds the BTC `Coin`.
2. It changes `price` on that one object.
3. SwiftUI redraws **only the BTC row**. The list, ETH, SOL and the badge stay as they are.

There's one more small saving: `Coin.update` returns early if nothing changed, so the row doesn't redraw for no reason.

## 3. The flash animation

`Coin` keeps two things:

- `direction`: `.up` or `.down`, which picks green or red
- `flashCount`: goes up by 1 every time the price changes

The row has its own `@State var isFlashing` and uses `.task(id:)`:

```swift
.overlay { card.fill(flashColor.opacity(isFlashing ? 0.16 : 0)) }
.task(id: coin.flashCount) {
    isFlashing = true                              // show the colour
    try await Task.sleep(for: .milliseconds(300))  // keep it briefly
    withAnimation(.easeOut(duration: 0.5)) {
        isFlashing = false                         // fade out
    }
}
```

Why this is efficient:

- **`.task(id:)` restarts each time `flashCount` changes, and SwiftUI cancels the old one first.** If prices arrive fast, old flashes never pile up, and there are no timers to clean up.
- `isFlashing` lives **inside one row**, so flashing BTC doesn't touch any other row.
- Only the background colour animates. The layout doesn't change.
- The first price doesn't flash, because there's nothing to compare it with.

## 4. Reconnecting when the connection drops

`BinanceSocket` runs a simple loop:

```
repeat until stopped:
    connect → send SUBSCRIBE → read messages
    (connection dropped)
    wait 1s, 2s, 4s, 8s ... up to 30s
    try again
```

- The wait **doubles** after each failure, so the app doesn't flood the server or drain the battery while offline.
- After a successful connection, the wait **resets to 1 second**.
- The pill in the top-right shows **Live** (pulsing green) or **Reconnecting…** (orange).

## 5. Memory management: no retain cycles

Long-running socket code can easily leak memory. This app avoids that:

- **The view controls how long the connection lives.** `TickerListView` calls `await viewModel.start()` inside `.task { }`, and SwiftUI cancels that task when the screen goes away.
- **The view model doesn't store any `Task`.** So there's no "view model → task → view model" loop.
- **Stopping happens in a chain:** the screen closes → the `.task` is cancelled → `for await` ends → the stream's `onTermination` cancels the socket task → the socket closes → everything is freed.

## Tests

`CryptoTickerTests.swift` checks:

- Binance JSON decodes correctly
- The SUBSCRIBE message is correct
- The flash direction: up = green, down = red, and no flash on the first price

## Ideas for later

- Reconnect at once when the network comes back (`NWPathMonitor`).
- Let the user add or remove coins.
