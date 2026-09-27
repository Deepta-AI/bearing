import SwiftUI

@main
struct CornerApp: App {
    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.container, container)
        }
    }
}
