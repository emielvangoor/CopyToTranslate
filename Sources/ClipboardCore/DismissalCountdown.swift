import Foundation

/// Monotonic timestamps keep the deadline independent of wall-clock changes.
public struct DismissalCountdown {
    public let duration: TimeInterval
    private var remainingWhenResumed: TimeInterval
    private var resumedAt: TimeInterval?

    public init(startedAt: TimeInterval, paused: Bool = false) {
        let lifetime: TimeInterval = 5
        duration = lifetime
        remainingWhenResumed = lifetime
        resumedAt = paused ? nil : startedAt
    }

    public var isPaused: Bool { resumedAt == nil }

    public func remaining(at now: TimeInterval) -> TimeInterval {
        let elapsed = resumedAt.map { max(0, now - $0) } ?? 0
        return max(0, remainingWhenResumed - elapsed)
    }

    public mutating func pause(at now: TimeInterval) {
        guard !isPaused else { return }
        remainingWhenResumed = remaining(at: now)
        resumedAt = nil
    }

    public mutating func resume(at now: TimeInterval) {
        guard isPaused else { return }
        resumedAt = now
    }
}
