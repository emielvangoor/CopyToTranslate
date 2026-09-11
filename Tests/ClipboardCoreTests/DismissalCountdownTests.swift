import XCTest
@testable import ClipboardCore

final class DismissalCountdownTests: XCTestCase {
    func testExpiresAtFiveSecondsWithoutNegativeRemainingTime() {
        let countdown = DismissalCountdown(startedAt: 100)
        XCTAssertEqual(countdown.remaining(at: 100), 5)
        XCTAssertEqual(countdown.remaining(at: 104.75), 0.25)
        XCTAssertEqual(countdown.remaining(at: 105), 0)
        XCTAssertEqual(countdown.remaining(at: 200), 0)
    }

    func testHoverPausesThenResumesRemainingTimeWithoutRestarting() {
        var countdown = DismissalCountdown(startedAt: 100)
        countdown.pause(at: 103)
        XCTAssertTrue(countdown.isPaused)
        XCTAssertEqual(countdown.remaining(at: 1000), 2)
        countdown.resume(at: 1000)
        XCTAssertFalse(countdown.isPaused)
        XCTAssertEqual(countdown.remaining(at: 1001.5), 0.5)
        XCTAssertEqual(countdown.remaining(at: 1002), 0)
    }

    func testDuplicateHoverEventsCannotExtendTheDeadline() {
        var countdown = DismissalCountdown(startedAt: 100)
        countdown.resume(at: 102)
        countdown.pause(at: 103)
        countdown.pause(at: 105)
        countdown.resume(at: 110)
        countdown.resume(at: 111)
        XCTAssertEqual(countdown.remaining(at: 111), 1)
        XCTAssertEqual(countdown.remaining(at: 112), 0)
    }

    func testAlreadyHoveredCardGetsFullReadingTimeAfterPointerLeaves() {
        var countdown = DismissalCountdown(startedAt: 100, paused: true)
        XCTAssertTrue(countdown.isPaused)
        XCTAssertEqual(countdown.remaining(at: 500), 5)
        countdown.resume(at: 500)
        XCTAssertEqual(countdown.remaining(at: 504), 1)
        XCTAssertEqual(countdown.remaining(at: 505), 0)
    }
}
