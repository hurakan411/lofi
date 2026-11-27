import SwiftUI

@main
struct LofiApp: App {
    #if DEBUG
    @StateObject private var store = FocusStore(debugUnlockAllRanks: true)
    #else
    @StateObject private var store = FocusStore()
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .tint(Palette.accent)
        }
    }
}
