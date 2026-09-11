import AppKit
import XCTest
@testable import ClipboardCore

final class ClipboardCoreTests: XCTestCase {
    func testSpanishMessageWithEmojiTriggersWithoutChangingTheOriginal() {
        let text = "Feliz comienzo de clases!!! Empezamos con la rutina!!! 💪🏼😊❤️🏑\nLos esperamos a todos esta tarde 🏑🏑🏑"
        XCTAssertEqual(SpanishDetector().candidate(text), text)
    }

    func testEmojiFilteringDoesNotMakeEnglishOrEmojiOnlyMessagesSpanish() {
        let detector = SpanishDetector()
        XCTAssertNil(detector.candidate("Happy first day of school!!! Back to our routine!!! 💪🏼😊❤️🏑\nWe will see everyone this afternoon 🏑🏑🏑"))
        XCTAssertNil(detector.candidate("💪🏼😊❤️🏑🏑🏑"))
    }

    func testDetectionNormalizationPreservesOriginalAccentsAndEmojiInOutput() {
        let text = "Mañana empezamos las clases. ¿Puedes confirmar tu asistencia? 😊❤️"
            .decomposedStringWithCanonicalMapping
        let result = SpanishDetector().candidate(text)
        XCTAssertNotNil(result)
        XCTAssertEqual(result.map { Array($0.utf8) }, Array(text.utf8))
    }

    func testRecognizesSpanishWithoutTreatingOtherLanguagesAsSpanish() {
        let detector = SpanishDetector()
        XCTAssertNotNil(detector.candidate("La reunión se ha cambiado al jueves a las diez."))
        XCTAssertNotNil(detector.candidate("¿Puedes enviarme la factura cuando tengas un momento?"))
        XCTAssertNotNil(detector.candidate("gracias"))
        for text in ["The meeting has moved to Thursday morning.",
                     "La reunió s'ha canviat a dijous a les deu.",
                     "Você pode me enviar a fatura quando tiver um momento?",
                     "no", "a", "12345", "https://ejemplo.es/hola", "hola@ejemplo.es"] {
            XCTAssertNil(detector.candidate(text), "Unexpected Spanish candidate: \(text)")
        }
    }

    func testManualTranslationBypassesDetectionButNotContentLimits() {
        let detector = SpanishDetector()
        XCTAssertEqual(detector.candidate("  no  ", manual: true), "no")
        XCTAssertNil(detector.candidate("   ", manual: true))
        XCTAssertNil(detector.candidate(String(repeating: "hola ", count: 2100), manual: true))
        XCTAssertNil(detector.candidate("https://ejemplo.es", manual: true))
    }

    @MainActor func testOnlyNewClipboardWritesAreDeliveredAndReadingPreservesContents() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Before launch", forType: .string)
        var events: [String?] = []
        let monitor = ClipboardMonitor(pasteboard: board) { events.append($0) }
        monitor.start()
        defer { monitor.stop() }
        monitor.poll()
        XCTAssertTrue(events.isEmpty)
        board.clearContents()
        board.setString("Buenos días, ¿cómo estás?", forType: .string)
        monitor.poll()
        monitor.poll()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual((events.first ?? nil), "Buenos días, ¿cómo estás?")
        XCTAssertEqual(board.string(forType: .string), "Buenos días, ¿cómo estás?")
        board.clearContents()
        monitor.poll()
        XCTAssertEqual(events.count, 2)
        XCTAssertNil((events.last ?? nil))
    }

    @MainActor func testCopyEnglishWritesClipboardWithoutRetriggeringMonitor() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        var events: [String?] = []
        let monitor = ClipboardMonitor(pasteboard: board) { events.append($0) }
        monitor.start()
        defer { monitor.stop() }
        XCTAssertTrue(monitor.copyTranslation("The meeting is on Thursday."))
        monitor.poll()
        XCTAssertEqual(board.string(forType: .string), "The meeting is on Thursday.")
        XCTAssertTrue(events.isEmpty)
        board.clearContents()
        board.setString("Otra frase en español", forType: .string)
        monitor.poll()
        XCTAssertEqual(events.count, 1)
    }

    @MainActor func testConfidentialClipboardIsNotExposedEvenForManualTranslation() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        var events: [String?] = []
        let monitor = ClipboardMonitor(pasteboard: board) { events.append($0) }
        monitor.start()
        defer { monitor.stop() }
        board.clearContents()
        board.setString("Texto privado", forType: .string)
        board.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        monitor.poll()
        XCTAssertEqual(events.count, 1)
        XCTAssertNil((events.first ?? nil))
        XCTAssertNil(monitor.currentText())
    }

    @MainActor func testResumeSkipsCopiesMadeWhilePaused() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        var events: [String?] = []
        let monitor = ClipboardMonitor(pasteboard: board) { events.append($0) }
        monitor.start()
        monitor.stop()
        board.clearContents()
        board.setString("Durante la pausa", forType: .string)
        monitor.poll()
        monitor.start()
        defer { monitor.stop() }
        monitor.poll()
        XCTAssertTrue(events.isEmpty)
        board.clearContents()
        board.setString("Después de la pausa", forType: .string)
        monitor.poll()
        XCTAssertEqual(events.count, 1)
    }
}
