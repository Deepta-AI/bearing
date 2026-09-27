import Foundation

/// One API call; `Response` fixes the decoded type at the call site.
public struct Endpoint<Response: Decodable & Sendable>: Sendable {
    public var method: String
    public var path: String
    public var query: [URLQueryItem]

    public init(method: String = "GET", path: String, query: [URLQueryItem] = []) {
        self.method = method
        self.path = path
        self.query = query
    }
}
