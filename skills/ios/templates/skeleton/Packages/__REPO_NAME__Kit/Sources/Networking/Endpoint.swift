import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// One API call: where it goes, what it sends, and the type it decodes into.
/// The `Response` type parameter is what makes `client.send(.health)` return a
/// `Health` and nothing else. Endpoints are values; features define theirs as
/// static members in an extension (see `Endpoint.health` in Features).
public struct Endpoint<Response: Decodable & Sendable>: Sendable {
    public var path: String
    public var method: HTTPMethod
    public var query: [QueryItem]
    public var headers: [String: String]
    public var body: Data?
    /// False for sign-in and health: the client then sends no bearer token.
    public var requiresAuth: Bool

    public init(
        path: String,
        method: HTTPMethod = .get,
        query: [QueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        requiresAuth: Bool = true
    ) {
        self.path = path
        self.method = method
        self.query = query
        self.headers = headers
        self.body = body
        self.requiresAuth = requiresAuth
    }

    /// Builds an endpoint whose body is `value` encoded as JSON.
    public static func json(
        path: String,
        method: HTTPMethod = .post,
        body value: some Encodable,
        requiresAuth: Bool = true,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> Endpoint {
        try Endpoint(
            path: path,
            method: method,
            headers: ["Content-Type": "application/json"],
            body: encoder.encode(value),
            requiresAuth: requiresAuth
        )
    }
}

/// One query parameter, in order. Endpoints carry this plain `Sendable` value
/// and the client converts it to `URLQueryItem`, so an endpoint means the same
/// thing on every platform and Foundation version.
public struct QueryItem: Hashable, Sendable {
    public var name: String
    public var value: String?

    public init(_ name: String, _ value: String?) {
        self.name = name
        self.value = value
    }
}

/// For endpoints with an empty or ignored body.
public struct Empty: Decodable, Sendable, Equatable {
    public init() {}
    public init(from decoder: any Decoder) throws {}
}
