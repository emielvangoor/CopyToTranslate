import XCTest
@testable import ClipboardCore
@testable import CopyToTranslate

final class CardModelTests: XCTestCase {
    @MainActor func testInstructionCardNeverStartsProofreading() async {
        let model = CardModel(source: "", kind: .dutchProofreading)
        model.error = "Copy text first"
        await model.proofread { _ in
            XCTFail("An informational card must not send a request")
            return DutchProofreading(corrected: "Unexpected", improved: "Unexpected", rewritten: "Unexpected")
        }
        XCTAssertNil(model.displayedText)
        XCTAssertEqual(model.error, "Copy text first")
    }

    @MainActor func testCopyFollowsVisibleDutchVersionAndClearsOldConfirmation() {
        let model = CardModel(source: "Ik vindt dit leuk.", kind: .dutchProofreading)
        model.proofreading = .init(corrected: "Ik vind dit leuk.", improved: "Dit vind ik leuk.", rewritten: "Hier word ik blij van.")
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

    @MainActor func testRewriteCopiesTheVisibleVersionAndKeepsOtherChoices() throws {
        let model = CardModel(source: "Ik vindt dit leuk.", kind: .dutchProofreading)
        model.proofreading = try JSONDecoder().decode(DutchProofreading.self, from: Data(#"{"corrected":"Ik vind dit leuk.","improved":"Dit vind ik leuk.","rewritten":"Hier word ik blij van."}"#.utf8))
        model.copyResult { _ in true }
        let rewrite = try XCTUnwrap(DutchVariant(rawValue: "rewritten"))
        model.selectVariant(rewrite)
        XCTAssertFalse(model.copied)
        XCTAssertEqual(model.displayedText, "Hier word ik blij van.")
        XCTAssertEqual(model.copyTitle, "Copy rewrite")
        var copied = ""
        model.copyResult { copied = $0; return true }
        XCTAssertEqual(copied, "Hier word ik blij van.")
        model.selectVariant(.improved)
        XCTAssertEqual(model.displayedText, "Dit vind ik leuk.")
        model.selectVariant(.corrected)
        XCTAssertEqual(model.displayedText, "Ik vind dit leuk.")
        model.cancel()
        model.selectVariant(rewrite)
        XCTAssertNil(model.displayedText)
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
        let result = DutchProofreading(corrected: "Ik vind dit leuk.", improved: "Dit vind ik leuk.", rewritten: "Hier word ik blij van.")
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
