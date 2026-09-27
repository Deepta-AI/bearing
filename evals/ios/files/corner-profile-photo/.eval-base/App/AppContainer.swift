import Core
import Features
import Networking
import SwiftUI

/// Composition root: the only place dependencies are built.
final class AppContainer: Sendable {
    let secrets: SecretStore
    let client: APIClientProtocol

    init(secrets: SecretStore, client: APIClientProtocol) {
        self.secrets = secrets
        self.client = client
    }

    static func live() -> AppContainer {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let baseURL = URL(string: raw)
        else { fatalError("API_BASE_URL missing from Info.plist; check Config/*.xcconfig") }
        let secrets = KeychainSecretStore(service: Bundle.main.bundleIdentifier ?? "com.example.corner")
        return AppContainer(secrets: secrets, client: APIClient(baseURL: baseURL, secrets: secrets))
    }

    @MainActor
    func ordersViewModel() -> OrdersViewModel {
        OrdersViewModel(service: RemoteOrdersService(client: client))
    }
}

private struct ContainerKey: EnvironmentKey {
    static let defaultValue: AppContainer = .live()
}

extension EnvironmentValues {
    var container: AppContainer {
        get { self[ContainerKey.self] }
        set { self[ContainerKey.self] = newValue }
    }
}
