import Core
import Foundation
import Testing
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

struct AppErrorTests {
    @Test func mapsURLErrorsToTypedCases() {
        let cases: [(URLError.Code, AppError)] = [
            (.notConnectedToInternet, .offline),
            (.cannotFindHost, .offline),
            (.timedOut, .timeout),
            (.cancelled, .cancelled),
        ]
        for (code, want) in cases {
            #expect(AppError(URLError(code)) == want, "URLError \(code)")
        }
    }

    @Test func mapsCancellationError() {
        #expect(AppError(CancellationError()) == .cancelled)
    }

    @Test func passesAppErrorThrough() {
        let original = AppError.server(status: 503, requestID: "abc")
        #expect(AppError(original) == original)
    }

    @Test func describesDecodingErrorWithThePath() {
        struct Payload: Decodable { let status: String }
        let data = Data(#"{"version":"1"}"#.utf8)
        do {
            _ = try JSONDecoder().decode(Payload.self, from: data)
            Issue.record("expected a decoding error")
        } catch {
            guard case let .decoding(message) = AppError(error) else {
                Issue.record("expected .decoding, got \(AppError(error))")
                return
            }
            #expect(message.contains("status"), "\(message)")
        }
    }

    @Test func retryableOnlyForTransientFailures() {
        #expect(AppError.offline.isRetryable)
        #expect(AppError.timeout.isRetryable)
        #expect(AppError.server(status: 503, requestID: nil).isRetryable)
        #expect(AppError.server(status: 429, requestID: nil).isRetryable)
        #expect(!AppError.server(status: 404, requestID: nil).isRetryable)
        #expect(!AppError.unauthorized.isRetryable)
        #expect(!AppError.decoding("x").isRetryable)
        #expect(!AppError.cancelled.isRetryable)
    }

    @Test func everyCaseHasAMessageKey() {
        let all: [AppError] = [
            .offline, .timeout, .cancelled, .server(status: 500, requestID: nil), .unauthorized,
            .decoding("k"), .invalidResponse, .keychain(status: -25300), .unknown("u"),
        ]
        let keys = Set(all.map(\.messageKey))
        #expect(keys.count == all.count, "message keys must be distinct")
        for key in keys {
            #expect(key.hasPrefix("error."), "\(key)")
        }
    }
}
