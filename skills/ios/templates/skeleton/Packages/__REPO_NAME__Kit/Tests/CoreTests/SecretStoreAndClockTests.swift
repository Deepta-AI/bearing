import Core
import Foundation
import Testing

struct SecretStoreAndClockTests {
    @Test func inMemoryStoreRoundTrips() throws {
        let store = InMemorySecretStore()
        #expect(try store.readString(.accessToken) == nil)

        try store.write("token-1", for: .accessToken)
        #expect(try store.readString(.accessToken) == "token-1")

        try store.write("token-2", for: .accessToken)
        #expect(try store.readString(.accessToken) == "token-2", "write replaces")

        try store.remove(.accessToken)
        #expect(try store.read(.accessToken) == nil)
        #expect(throws: Never.self, "removing an absent key is fine") {
            try store.remove(.accessToken)
        }
    }

    @Test func keysAreIndependent() throws {
        let store = InMemorySecretStore()
        try store.write("a", for: .accessToken)
        try store.write("r", for: .refreshToken)
        #expect(try store.readString(.accessToken) == "a")
        #expect(try store.readString(.refreshToken) == "r")
    }

    @Test func fixedClockStandsStillAndAdvances() {
        let clock = FixedClock()
        #expect(clock.now == clock.now)
        let later = clock.advanced(by: 90)
        #expect(abs(later.now.timeIntervalSince(clock.now) - 90) < 0.001)
    }
}
