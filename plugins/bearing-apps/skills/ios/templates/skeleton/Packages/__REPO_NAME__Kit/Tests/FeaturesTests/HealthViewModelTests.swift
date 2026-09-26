import Core
import Features
import Foundation
import Testing

struct StubHealthService: HealthService {
    let result: Result<Health, any Error>

    func check() async throws -> Health {
        try result.get()
    }
}

/// The view model is `@MainActor`, so the suite is too; Swift Testing runs
/// each test on the main actor on Linux and Apple platforms alike.
@MainActor
struct HealthViewModelTests {
    @Test func startsIdle() {
        let model = HealthViewModel(service: StubHealthService(result: .success(Health(status: "ok", version: "1"))))
        #expect(model.state == .idle)
        #expect(model.lastCheckedAt == nil)
        #expect(!model.canRetry)
    }

    @Test func refreshLoadsAndStampsTheClock() async {
        let clock = FixedClock()
        let health = Health(status: "ok", version: "1.2.3")
        let model = HealthViewModel(service: StubHealthService(result: .success(health)), clock: clock)

        await model.refresh()

        #expect(model.state == .loaded(health))
        #expect(model.lastCheckedAt == clock.now)
        #expect(!model.canRetry)
    }

    @Test func transientFailureOffersRetry() async {
        let model = HealthViewModel(service: StubHealthService(result: .failure(AppError.offline)))

        await model.refresh()

        #expect(model.state == .failed(.offline))
        #expect(model.canRetry)
        #expect(model.lastCheckedAt == nil)
    }

    @Test func permanentFailureDoesNotOfferRetry() async {
        let model = HealthViewModel(service: StubHealthService(result: .failure(AppError.decoding("status"))))

        await model.refresh()

        #expect(model.state == .failed(.decoding("status")))
        #expect(!model.canRetry)
    }

    @Test func cancellationIsNotShownAsAFailure() async {
        let model = HealthViewModel(service: StubHealthService(result: .failure(CancellationError())))

        await model.refresh()

        #expect(model.state == .loading, "the screen is gone; no error state is rendered")
    }
}
