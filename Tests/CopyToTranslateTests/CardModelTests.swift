import XCTest
@testable import ClipboardCore
@testable import CopyToTranslate

final class CardModelTests: XCTestCase {
    @MainActor func testCopyFollowsVisibleDutchVersionAndClearsOldConfirmation() {
        let model = CardModel(source: "Ik vindt dit leuk.", kind: .dutchProofreading)
        model.proofreading = .init(corrected: "Ik vind dit leuk.", improved: "Dit vind ik leuk.")
        var clipboard = "Ik vindt dit leuk."
        XCTAssertEqual(model.selectedVariant, .corrected)
        model.copyResult { clipboard = $0; return true }
        XCTAssertEqual(clipboard, "Ik vind dit leuk.")
        XCTAssertTrue(model.copied)
        model.selectVariant(.improved)
        XCTAssertFalse(model.copied)
        model.copyResult { clipboard = $0; return true }
        XCTAssertEqual(clipboard, "Dit vind ik leuk.")
        model.selectVariant(.corrected)
        XCTAssertEqual(model.displayedText, "Ik vind dit leuk.")
        XCTAssertEqual(model.source, "Ik vindt dit leuk.")
    }

    @MainActor func testFailedCopyCanBeRetriedAndCancelledTextCannotBeCopied() {
        let model = CardModel(source: "Hola")
        model.translation = "Hello"
        model.copyResult { _ in false }
        XCTAssertTrue(model.copyFailed)
        XCTAssertFalse(model.copied)
        model.copyResult { _ in true }
        XCTAssertFalse(model.copyFailed)
        XCTAssertTrue(model.copied)
        model.cancel()
        var copiedAfterCancellation = false
        model.copyResult { _ in copiedAfterCancellation = true; return true }
        XCTAssertFalse(copiedAfterCancellation)
        XCTAssertNil(model.displayedText)
    }

    @MainActor func testLateDutchResultIsDiscardedAfterCardCancellation() async {
        let result = DutchProofreading(corrected: "Ik vind dit leuk.", improved: "Dit vind ik leuk.")
        let gate = ProofreadingGate()
        let model = CardModel(source: "Ik vindt dit leuk.", kind: .dutchProofreading)
        var finished = false
        model.onFinished = { finished = true }
        let task = Task { await model.proofread { _ in await gate.run() } }
        for await _ in gate.started { break }
        model.cancel()
        await gate.finish(result)
        await task.value
        XCTAssertNil(model.proofreading)
        XCTAssertNil(model.displayedText)
        XCTAssertFalse(finished)
    }
}

private actor ProofreadingGate {
    nonisolated let started: AsyncStream<Void>
    private let signal: AsyncStream<Void>.Continuation
    private var pending: CheckedContinuation<DutchProofreading, Never>?

    init() {
        (started, signal) = AsyncStream.makeStream(of: Void.self)
    }

    func run() async -> DutchProofreading {
        await withCheckedContinuation { continuation in
            pending = continuation
            signal.yield(())
            signal.finish()
        }
    }

    func finish(_ result: DutchProofreading) {
        pending?.resume(returning: result)
        pending = nil
    }
}
