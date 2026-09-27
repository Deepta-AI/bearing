import Core
import Features
import Networking
import SwiftUI

/// Composition root: the only place dependencies are built.
final class AppContainer: Sendable {
    let baseURL: URL
    let secrets: SecretStore
    let client: APIClientProtocol

    init(baseURL: URL, secrets: SecretStore, client: APIClientProtocol) {
        self.baseURL = baseURL
        self.secrets = secrets
        self.client = client
    }

    static func live() -> AppContainer {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let baseURL = URL(string: raw)
        else { fatalError("API_BASE_URL missing from Info.plist; check Config/*.xcconfig") }
        let secrets = KeychainSecretStore(service: Bundle.main.bundleIdentifier ?? "com.example.corner")
        return AppContainer(baseURL: baseURL, secrets: secrets,
                            client: APIClient(baseURL: baseURL, secrets: secrets))
    }

    @MainActor
    func ordersViewModel() -> OrdersViewModel {
        OrdersViewModel(service: RemoteOrdersService(client: client))
    }

    @MainActor
    func profilePhotoModel() -> ProfilePhotoModel {
        ProfilePhotoModel(service: ProfilePhotoService(baseURL: baseURL))
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
