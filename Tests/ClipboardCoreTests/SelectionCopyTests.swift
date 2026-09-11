import AppKit
import XCTest
@testable import ClipboardCore

final class SelectionCopyTests: XCTestCase {
    @MainActor func testCopyUsesFreshValidatedTextAndLeavesItOnClipboard() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Old Dutch clipboard", forType: .string)
        var events: [String?] = []
        let monitor = ClipboardMonitor(pasteboard: board) { events.append($0) }
        monitor.start()
        defer { monitor.stop() }
        let text = try await monitor.captureSelectionCopy(copy: {
            board.clearContents()
            board.setString("Buenas noches a todos!", forType: .string)
            monitor.poll()
            return true
        }, isSourceActive: { true }, matchesSource: { $0 == "Buenas noches a todos!" })
        XCTAssertEqual(text, "Buenas noches a todos!")
        XCTAssertEqual(board.string(forType: .string), text)
        monitor.poll()
        XCTAssertTrue(events.isEmpty)
    }

    @MainActor func testUnrelatedWriteIsNeitherReturnedNorOverwritten() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Original", forType: .string)
        let monitor = ClipboardMonitor(pasteboard: board) { _ in }
        do {
            _ = try await monitor.captureSelectionCopy(copy: {
                board.clearContents()
                board.setString("Unrelated Dutch sentence", forType: .string)
                return true
            }, isSourceActive: { true }, matchesSource: { $0 == "Expected Spanish selection" })
            XCTFail("An unrelated clipboard write must never reach classification")
        } catch { }
        XCTAssertEqual(board.string(forType: .string), "Unrelated Dutch sentence")
    }

    @MainActor func testTimedOutCopyNeverReturnsOldTextOrRestoresOverLateCopy() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Original", forType: .string)
        let monitor = ClipboardMonitor(pasteboard: board) { _ in }
        do {
            _ = try await monitor.captureSelectionCopy(copy: { true }, isSourceActive: { true },
                matchesSource: { _ in true }, timeout: .milliseconds(20))
            XCTFail("A copy without a fresh write must fail")
        } catch { }
        XCTAssertEqual(board.string(forType: .string), "Original")
        board.clearContents()
        board.setString("Late selected text", forType: .string)
        await Task.yield()
        XCTAssertEqual(board.string(forType: .string), "Late selected text")
    }

    @MainActor func testCancellationDoesNotReturnCopiedText() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let monitor = ClipboardMonitor(pasteboard: board) { _ in }
        let task = Task {
            try await monitor.captureSelectionCopy(copy: { true }, isSourceActive: { true }, matchesSource: { _ in true })
        }
        await Task.yield()
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled capture returned text") }
        catch is CancellationError { }
    }

    @MainActor func testSourceChangeAndProtectedClipboardDoNotReturnText() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let monitor = ClipboardMonitor(pasteboard: board) { _ in }
        var active = true
        do {
            _ = try await monitor.captureSelectionCopy(copy: {
                board.clearContents()
                board.setString("New copy", forType: .string)
                active = false
                return true
            }, isSourceActive: { active }, matchesSource: { _ in true })
            XCTFail("Focus change must invalidate capture")
        } catch { }
        XCTAssertEqual(board.string(forType: .string), "New copy")
        board.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        var copied = false
        do {
            _ = try await monitor.captureSelectionCopy(copy: { copied = true; return true },
                isSourceActive: { true }, matchesSource: { _ in true })
            XCTFail("Protected clipboard should not start Copy")
        } catch { }
        XCTAssertFalse(copied)
    }
}
