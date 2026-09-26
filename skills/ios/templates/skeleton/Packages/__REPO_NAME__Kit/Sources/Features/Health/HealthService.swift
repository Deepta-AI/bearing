import Core
import Foundation
import Networking

/// What the health feature needs from the outside. One protocol per feature
/// boundary; the view model depends on this, never on `APIClient` directly.
public protocol HealthService: Sendable {
    func check() async throws -> Health
}

/// The production implementation: one endpoint, one decode, errors already
/// typed by the client.
public struct RemoteHealthService: HealthService {
    private let client: any APIClientProtocol

    public init(client: any APIClientProtocol) {
        self.client = client
    }

    public func check() async throws -> Health {
        try await client.send(.health)
    }
}
