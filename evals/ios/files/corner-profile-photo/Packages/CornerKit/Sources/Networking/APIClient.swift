import Core
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Sends endpoints and maps every failure to `AppError`.
public protocol APIClientProtocol: Sendable {
    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response
}

public final class APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let secrets: SecretStore

    public init(baseURL: URL, session: URLSession = .shared, secrets: SecretStore) {
        self.baseURL = baseURL
        self.session = session
        self.secrets = secrets
    }

    public func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path),
                                       resolvingAgainstBaseURL: false)
        if !endpoint.query.isEmpty { components?.queryItems = endpoint.query }
        guard let url = components?.url else { throw AppError.invalidRequest }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = endpoint.method
        let requestID = UUID().uuidString
        request.setValue(requestID, forHTTPHeaderField: "X-Request-Id")
        if let token = try? secrets.read("access_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let status: Int
        do {
            let (body, response) = try await session.data(for: request)
            data = body
            status = (response as? HTTPURLResponse)?.statusCode ?? 0
        } catch let error as URLError {
            throw Self.map(error)
        } catch is CancellationError {
            throw AppError.cancelled
        } catch {
            throw AppError.unknown
        }
        Log.request("\(requestID) \(endpoint.method) \(url.absoluteString) -> \(status)")

        switch status {
        case 200 ..< 300: break
        case 401: throw AppError.unauthorized
        case 422: throw AppError.invalidRequest
        default: throw AppError.server(status: status)
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw AppError.decoding
        }
    }

    static func map(_ error: URLError) -> AppError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost: .offline
        case .timedOut: .timeout
        case .cancelled: .cancelled
        default: .unknown
        }
    }
}
