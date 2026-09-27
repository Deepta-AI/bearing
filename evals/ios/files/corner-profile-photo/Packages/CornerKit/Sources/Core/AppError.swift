import Foundation

/// Every error a screen can show or react to. The client maps foreign
/// errors to these at the boundary.
public enum AppError: Error, Equatable, Sendable {
    case offline
    case timeout
    case unauthorized
    case invalidRequest
    case server(status: Int)
    case decoding
    case cancelled
    case unknown

    /// Whether the screen should offer a retry.
    public var isRetryable: Bool {
        switch self {
        case .offline, .timeout, .server: true
        default: false
        }
    }

    /// String Catalog key for the message shown to the customer.
    public var messageKey: String {
        switch self {
        case .offline: "error.offline"
        case .timeout: "error.timeout"
        case .unauthorized: "error.unauthorized"
        case .server: "error.server"
        default: "error.generic"
        }
    }
}
