import Core
import Foundation
import Networking
import Testing
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Intercepts every request of the session built in `makeClient()`.
/// No network, no sleeps: the handler answers synchronously.
final class StubURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (status: Int, body: Data)

    /// The suite is `.serialized`, so one test at a time sets the handler.
    nonisolated(unsafe) static var handler: Handler?

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (status, body) = try handler(request)
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// What the stub saw. The handler runs on a URLSession thread, outside the
/// test's task, so it only records; the test body asserts afterwards.
final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []

    func append(_ request: URLRequest) {
        lock.lock(); defer { lock.unlock() }
        requests.append(request)
    }

    var all: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return requests
    }
}

struct FixedTokenProvider: TokenProvider {
    let token: String?
    func accessToken() async throws -> String? { token }
}

struct Ping: Codable, Equatable, Sendable {
    let status: String
}

/// Serialized because `StubURLProtocol.handler` is shared by every session.
@Suite(.serialized)
struct APIClientTests {
    private func makeClient(token: String? = nil) throws -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return try APIClient(
            baseURL: #require(URL(string: "https://api.example.test/v1/")),
            session: session,
            tokenProvider: FixedTokenProvider(token: token)
        )
    }

    /// Installs a handler that logs each request and answers with `status`
    /// and `body`.
    private func stub(_ status: Int, _ body: Data = Data()) -> RequestLog {
        let log = RequestLog()
        StubURLProtocol.handler = { request in
            log.append(request)
            return (status, body)
        }
        return log
    }

    @Test func decodesASuccessfulResponseAndSendsARequestID() async throws {
        let log = stub(200, Data(#"{"status":"ok"}"#.utf8))
        let client = try makeClient()

        let ping: Ping = try await client.send(
            Endpoint(path: "ping", query: [QueryItem("verbose", "1")], requiresAuth: false)
        )

        #expect(ping == Ping(status: "ok"))
        let request = try #require(log.all.first)
        #expect(request.url?.absoluteString == "https://api.example.test/v1/ping?verbose=1")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil, "public endpoint sends no token")
        let id = request.value(forHTTPHeaderField: APIClient.requestIDHeader) ?? ""
        #expect(id.count == 36, "request id is a uuid")
    }

    @Test func sendsBearerTokenForAuthenticatedEndpoints() async throws {
        let log = stub(200, Data(#"{"status":"ok"}"#.utf8))
        let client = try makeClient(token: "t-123")

        let ping: Ping = try await client.send(Endpoint(path: "/ping"))

        #expect(ping.status == "ok")
        #expect(log.all.first?.value(forHTTPHeaderField: "Authorization") == "Bearer t-123")
    }

    @Test func missingTokenFailsBeforeTheNetwork() async throws {
        let log = stub(200)
        let client = try makeClient(token: nil)

        await #expect(throws: AppError.unauthorized) {
            let _: Ping = try await client.send(Endpoint(path: "/ping"))
        }
        #expect(log.all.isEmpty, "must not reach the network without a token")
    }

    @Test func serverErrorCarriesStatusAndRequestID() async throws {
        _ = stub(503, Data("down".utf8))
        let client = try makeClient()

        do {
            let _: Ping = try await client.send(Endpoint(path: "/ping", requiresAuth: false))
            Issue.record("expected a server error")
        } catch let error as AppError {
            guard case let .server(status, requestID) = error else {
                Issue.record("got \(error)")
                return
            }
            #expect(status == 503)
            #expect(requestID?.count == 36)
        }
    }

    @Test func unauthorizedStatusIsTyped() async throws {
        _ = stub(401)
        let client = try makeClient(token: "expired")

        await #expect(throws: AppError.unauthorized) {
            let _: Ping = try await client.send(Endpoint(path: "/ping"))
        }
    }

    @Test func decodingFailureNamesTheKey() async throws {
        _ = stub(200, Data(#"{"nope":1}"#.utf8))
        let client = try makeClient()

        do {
            let _: Ping = try await client.send(Endpoint(path: "/ping", requiresAuth: false))
            Issue.record("expected a decoding error")
        } catch let error as AppError {
            guard case let .decoding(message) = error else {
                Issue.record("got \(error)")
                return
            }
            #expect(message.contains("status"), "\(message)")
        }
    }

    @Test func emptyResponseTypeSkipsDecoding() async throws {
        _ = stub(204)
        let client = try makeClient()

        let empty: Empty = try await client.send(Endpoint(path: "/ping", method: .delete, requiresAuth: false))

        #expect(empty == Empty())
    }
}
