import XCTest
@testable import ClipboardCore

final class SuspensionStateTests: XCTestCase {
    func testWakeDoesNotResumeMonitoringUntilScreenIsUnlocked() {
        var state = SuspensionState()
        state.suspend(for: .screenLock)
        state.suspend(for: .sleep)
        state.resume(from: .sleep)
        XCTAssertTrue(state.isSuspended)
        state.resume(from: .screenLock)
        XCTAssertFalse(state.isSuspended)
    }

    func testSessionActivationDoesNotClearScreenLockAndRepeatedEventsAreSafe() {
        var state = SuspensionState()
        state.suspend(for: .screenLock)
        state.suspend(for: .screenLock)
        state.suspend(for: .inactiveSession)
        state.resume(from: .inactiveSession)
        state.resume(from: .sleep)
        XCTAssertTrue(state.isSuspended)
        state.resume(from: .screenLock)
        XCTAssertFalse(state.isSuspended)
    }
}
