import Core
import Features
import Networking
import SwiftUI

/// The one composition root, and the only object that may be reached for
/// globally. Every dependency is built here from configuration and passed
/// down through initialisers or the `\.container` environment key. Nothing
/// else in the app is a singleton.
///
/// Immutable, and every dependency is itself `Sendable`, so the container is
/// `Sendable` and needs no actor: Swift 6 mode lets it be an environment
/// default and cross into any task.
final class AppContainer: Sendable {
    let secrets: any SecretStore
    let clock: any WallClock
    let apiClient: any APIClientProtocol
    let healthService: any HealthService

    init(secrets: any SecretStore, clock: any WallClock, apiClient: any APIClientProtocol) {
        self.secrets = secrets
        self.clock = clock
        self.apiClient = apiClient
        healthService = RemoteHealthService(client: apiClient)
    }

    /// Production wiring. `API_BASE_URL` comes from `Config/*.xcconfig` through
    /// Info.plist; a missing value is a build misconfiguration, so failing
    /// here at launch is the right place (the only `fatalError` in the app).
    static func live() -> AppContainer {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let baseURL = URL(string: raw), baseURL.scheme != nil
        else {
            fatalError("API_BASE_URL missing or invalid: set it in Config/Debug.xcconfig or Config/Local.xcconfig")
        }
        let secrets = KeychainSecretStore(service: Bundle.main.bundleIdentifier ?? "__ORG_ID__.__REPO_SLUG__")
        let client = APIClient(
            baseURL: baseURL,
            session: URLSession(configuration: .api()),
            tokenProvider: SecretStoreTokenProvider(store: secrets)
        )
        return AppContainer(secrets: secrets, clock: SystemClock(), apiClient: client)
    }

    /// Previews and UI tests: no network, no Keychain.
    static func preview(health: Result<Health, any Error> = .success(Health(status: "ok", version: "preview")))
        -> AppContainer {
        AppContainer(secrets: InMemorySecretStore(), clock: FixedClock(), apiClient: PreviewAPIClient(health: health))
    }
}

/// Answers the health endpoint and nothing else. Extend per preview need.
private struct PreviewAPIClient: APIClientProtocol {
    let health: Result<Health, any Error>

    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        if let value = try health.get() as? Response { return value }
        throw AppError.invalidResponse
    }
}

extension EnvironmentValues {
    /// Deep views read dependencies from here; screens take them in `init`.
    @Entry var container: AppContainer = .preview()
}
