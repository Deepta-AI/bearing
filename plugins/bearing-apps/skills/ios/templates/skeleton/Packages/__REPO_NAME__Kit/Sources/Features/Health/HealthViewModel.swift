import Core
import Foundation
import Observation

/// Screen state for the health view. `@Observable` so SwiftUI tracks only the
/// properties a view body reads; `@MainActor` because the state is UI state.
/// The view drives it with `.task { await model.refresh() }`, which is
/// structured: leaving the screen cancels the request. No stored `Task`, no
/// `ObservableObject`, no `@Published`.
@MainActor
@Observable
public final class HealthViewModel {
    /// Every screen has these four states and the view renders all four.
    public enum State: Equatable, Sendable {
        case idle
        case loading
        case loaded(Health)
        case failed(AppError)
    }

    public private(set) var state: State = .idle
    public private(set) var lastCheckedAt: Date?

    private let service: any HealthService
    private let clock: any WallClock

    public init(service: any HealthService, clock: any WallClock = SystemClock()) {
        self.service = service
        self.clock = clock
    }

    /// Loads once. Safe to call again: the state goes back to `.loading`
    /// while the previous content stays available to callers that kept it.
    public func refresh() async {
        state = .loading
        do {
            let health = try await service.check()
            state = .loaded(health)
            lastCheckedAt = clock.now
        } catch {
            let app = AppError(error)
            // A cancelled load is not a failure to show: the screen is gone.
            guard app != .cancelled else { return }
            state = .failed(app)
        }
    }

    /// True when the view should offer a retry button.
    public var canRetry: Bool {
        if case let .failed(error) = state { return error.isRetryable }
        return false
    }
}
