import SwiftUI

/// The app entry point. Wiring only: build the container, hand it to the
/// root view, put it in the environment. Nothing else lives here.
@main
struct __REPO_NAME__App: App {
    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
                .environment(\.container, container)
        }
    }
}
