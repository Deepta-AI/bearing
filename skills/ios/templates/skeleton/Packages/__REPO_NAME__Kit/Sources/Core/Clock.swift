import Foundation

/// The wall clock as a dependency, so nothing reads `Date()` directly and
/// tests never depend on the real time. (Swift's `Clock` protocol measures
/// durations; this one answers "what time is it".)
public protocol WallClock: Sendable {
    var now: Date { get }
}

/// The real clock. The App container owns the only instance.
public struct SystemClock: WallClock {
    public init() {}
    public var now: Date {
        Date()
    }
}

/// A clock that stands still. Build a new one to move time in a test.
public struct FixedClock: WallClock {
    public var now: Date

    public init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.now = now
    }

    /// Returns a clock `interval` seconds later.
    public func advanced(by interval: TimeInterval) -> FixedClock {
        FixedClock(now: now.addingTimeInterval(interval))
    }
}
