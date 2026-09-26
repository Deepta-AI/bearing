import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// The one error type that crosses layer boundaries. Networking, storage and
/// features throw `AppError`; views switch on it to pick a message and decide
/// whether a retry button makes sense. Never show `localizedDescription` of a
/// foreign error to a user; map it here once.
public enum AppError: Error, Equatable, Sendable {
    /// No route to the host, or the device is offline.
    case offline
    /// The request took longer than the client timeout.
    case timeout
    /// The surrounding task was cancelled. Views ignore this one.
    case cancelled
    /// The server answered with a non-2xx status. `requestID` is the
    /// `X-Request-Id` we sent, for the support ticket.
    case server(status: Int, requestID: String?)
    /// The token was missing or rejected. The caller signs out.
    case unauthorized
    /// The body did not match the `Codable` type. The message names the key.
    case decoding(String)
    /// The response was not HTTP at all, or the URL could not be built.
    case invalidResponse
    /// The Keychain refused. `status` is the raw `OSStatus`.
    case keychain(status: Int32)
    /// Anything else, with a short description for the log.
    case unknown(String)

    /// Wraps a foreign error, mapping the well-known ones to typed cases.
    public init(_ error: any Error) {
        if let app = error as? AppError {
            self = app
        } else if error is CancellationError {
            self = .cancelled
        } else if let decoding = error as? DecodingError {
            self = .decoding(AppError.describe(decoding))
        } else if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost:
                self = .offline
            case .timedOut:
                self = .timeout
            case .cancelled:
                self = .cancelled
            default:
                self = .unknown(String(describing: url.code))
            }
        } else {
            self = .unknown(String(describing: error))
        }
    }

    /// True when a retry could plausibly succeed without the user changing
    /// anything. Views show a retry button only for these.
    public var isRetryable: Bool {
        switch self {
        case .offline, .timeout:
            true
        case let .server(status, _):
            status >= 500 || status == 429
        case .cancelled, .unauthorized, .decoding, .invalidResponse, .keychain, .unknown:
            false
        }
    }

    /// The String Catalog key for the user-facing message. The App target
    /// resolves it with `String(localized:)`; the package stays UI-free.
    public var messageKey: String {
        switch self {
        case .offline: "error.offline"
        case .timeout: "error.timeout"
        case .cancelled: "error.cancelled"
        case .server: "error.server"
        case .unauthorized: "error.unauthorized"
        case .decoding: "error.decoding"
        case .invalidResponse: "error.invalidResponse"
        case .keychain: "error.keychain"
        case .unknown: "error.unknown"
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            context.codingPath.map(\.stringValue).joined(separator: ".")
        }
        switch error {
        case let .keyNotFound(key, context):
            return "missing key \(key.stringValue) at \(path(context))"
        case let .typeMismatch(type, context):
            return "type mismatch for \(type) at \(path(context))"
        case let .valueNotFound(type, context):
            return "null \(type) at \(path(context))"
        case let .dataCorrupted(context):
            return "corrupted at \(path(context))"
        @unknown default:
            return "decoding failed"
        }
    }
}
