import Foundation
import Networking

/// The `/healthz` payload of a service on this standard: `{"status":"ok","version":"..."}`.
/// Decoded with `Codable`; the keys are the wire names, so a server rename is
/// a compile-visible change here, not a silent nil somewhere else.
public struct Health: Codable, Equatable, Sendable {
    public let status: String
    public let version: String

    public init(status: String, version: String) {
        self.status = status
        self.version = version
    }

    public var isHealthy: Bool {
        status == "ok"
    }
}

public extension Endpoint<Health> {
    /// Liveness of the API this app talks to. Unauthenticated.
    static var health: Endpoint<Health> {
        Endpoint(path: "/healthz", requiresAuth: false)
    }
}
