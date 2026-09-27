import Core
import Foundation
@testable import Networking
import Testing

private struct Ping: Decodable, Sendable, Equatable {
    let okValue: Bool
}

@Suite(.serialized)
struct APIClientTests {
    private let base = URL(string: "https://api.test")

    private func client(token: String? = "t0k") throws -> APIClient {
        let secrets = InMemorySecretStore(token.map { ["access_token": $0] } ?? [:])
        return try APIClient(baseURL: #require(base), session: StubURLProtocol.session(), secrets: secrets)
    }

    @Test func decodesSnakeCaseAndSendsTheToken() async throws {
        StubURLProtocol.handler = { _ in (200, Data(#"{"ok_value": true}"#.utf8)) }
        let ping: Ping = try await client().send(Endpoint(path: "/v1/ping"))
        #expect(ping == Ping(okValue: true))
        #expect(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer t0k")
        #expect(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "X-Request-Id") != nil)
    }

    @Test func mapsStatusCodes() async throws {
        for (status, expected) in [(401, AppError.unauthorized), (422, .invalidRequest), (503, .server(status: 503))] {
            StubURLProtocol.handler = { _ in (status, Data()) }
            await #expect(throws: expected) {
                let _: Ping = try await client().send(Endpoint(path: "/v1/ping"))
            }
        }
    }

    @Test func badBodyIsADecodingError() async throws {
        StubURLProtocol.handler = { _ in (200, Data("nope".utf8)) }
        await #expect(throws: AppError.decoding) {
            let _: Ping = try await client().send(Endpoint(path: "/v1/ping"))
        }
    }
}
