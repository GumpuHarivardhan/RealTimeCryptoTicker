import SwiftUI

@main
struct CryptoTickerApp: App {
    // @State keeps ONE view model alive for the whole app.
    @State private var viewModel = TickerViewModel()

    var body: some Scene {
        WindowGroup {
            TickerListView(viewModel: viewModel)
        }
    }
}
