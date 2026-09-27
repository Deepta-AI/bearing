import SwiftUI

struct ContentView: View {
    @Environment(\.container) private var container

    var body: some View {
        TabView {
            OrdersView(model: container.ordersViewModel())
                .tabItem { Label("tab.orders", systemImage: "bag") }
            ProfileView(model: container.profilePhotoModel())
                .tabItem { Label("tab.profile", systemImage: "person") }
        }
    }
}
