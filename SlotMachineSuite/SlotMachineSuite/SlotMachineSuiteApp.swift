import SwiftUI

@main
struct SlotMachineSuiteApp: App {
    @StateObject private var game = SlotGameViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
        }
    }
}
