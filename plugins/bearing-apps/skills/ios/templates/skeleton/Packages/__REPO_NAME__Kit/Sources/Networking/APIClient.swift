import Core
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// What features depend on. Tests substitute a stub; the App wires `APIClient`.
public protocol APIClientProtocol: Sendable {
    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response
}

/// Supplies the bearer token for authenticated endpoints. Backed by the
/// `SecretStore` in production; a closure in tests.
public protocol TokenProvider: Sendable {
    func accessToken() async throws -> String?
}

/// A `TokenProvider` that reads the Keychain-backed `SecretStore`.
public struct SecretStoreTokenProvider: TokenProvider {
    private let store: any SecretStore

    public init(store: any SecretStore) { self.store = store }

    public func accessToken() async throws -> String? {
        try store.readString(.accessToken)
    }
}

/// The URLSession client. Every call is `async`, honours task cancellation
/// (cancelling the surrounding `Task` cancels the request; `swift test` on
/// Linux and Xcode both do this through `URLSession.data(for:)`), decodes
/// with `Codable`, and throws `AppError` and nothing else. Each request
/// carries an `X-Request-Id` so the server log and the client log meet.
///
/// An actor rather than a class: the session, decoder and base URL are
/// isolated state, so the type is Sendable without `@unchecked`.
public actor APIClient: APIClientProtocol {
    public static let requestIDHeader = "X-Request-Id"

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let tokenProvider: any TokenProvider
    private let userAgent: String

    /// - Parameters:
    ///   - baseURL: `API_BASE_URL` from the xcconfig, no trailing slash needed.
    ///   - session: the App passes `.shared` configured with timeouts; tests pass
    ///     a session whose `protocolClasses` contain a stub.
    ///   - tokenProvider: where bearer tokens come from.
    public init(
        baseURL: URL,
        session: URLSession,
        tokenProvider: any TokenProvider,
        userAgent: String = "__REPO_NAME__"
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.userAgent = userAgent
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        let request = try await makeRequest(endpoint)
        let requestID = request.value(forHTTPHeaderField: Self.requestIDHeader)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await perform(request)
        } catch {
            throw AppError(error)
        }
        try Task.checkCancellation()

        guard let http = response as? HTTPURLResponse else { throw AppError.invalidResponse }
        switch http.statusCode {
        case 200 ..< 300:
            break
        case 401:
            throw AppError.unauthorized
        default:
            throw AppError.server(status: http.statusCode, requestID: requestID)
        }

        if Response.self == Empty.self, let empty = Empty() as? Response {
            return empty
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw AppError(error)
        }
    }

    /// Runs the request and honours cancellation of the calling task.
    /// `URLSession.data(for:)` exists on Apple platforms and, since Swift 6,
    /// in FoundationNetworking on Linux, so one path serves both.
    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }

    private func makeRequest<Response>(_ endpoint: Endpoint<Response>) async throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw AppError.invalidResponse
        }
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        let path = endpoint.path.hasPrefix("/") ? endpoint.path : "/" + endpoint.path
        components.path = basePath + path
        components.queryItems = endpoint.query.isEmpty
            ? nil
            : endpoint.query.map { URLQueryItem(name: $0.name, value: $0.value) }
        guard let url = components.url else { throw AppError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: Self.requestIDHeader)
        for (name, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if endpoint.requiresAuth {
            guard let token = try await tokenProvider.accessToken() else { throw AppError.unauthorized }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

public extension URLSessionConfiguration {
    /// The configuration the App uses: bounded timeouts, no cookies, JSON only.
    static func api() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 60
        configuration.httpShouldSetCookies = false
        return configuration
    }
}
