public struct SuspensionState {
    public enum Reason: Hashable, Sendable { case sleep, screenLock, inactiveSession }
    private var reasons: Set<Reason> = []
    public init() {}
    public var isSuspended: Bool { !reasons.isEmpty }
    public mutating func suspend(for reason: Reason) { reasons.insert(reason) }
    public mutating func resume(from reason: Reason) { reasons.remove(reason) }
}
