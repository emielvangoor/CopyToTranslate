import XCTest
import ClipboardCore
@testable import CopyToTranslate

final class WhatsAppSelectionTests: XCTestCase {
    func testOnlyWhatsAppsSelectionCopyMenuIsAccepted() {
        XCTAssertTrue(WhatsAppSelectionCapture.isCopyOnlyMenu(["\u{200e}copy"]))
        XCTAssertFalse(WhatsAppSelectionCapture.isCopyOnlyMenu(["reply", "copy", "forward", "delete"]))
        XCTAssertFalse(WhatsAppSelectionCapture.isCopyOnlyMenu(["send"]))
        XCTAssertFalse(WhatsAppSelectionCapture.isCopyOnlyMenu([]))
    }

    func testCapturedSelectionMustBelongToThePointedMessage() {
        let description = "Mensaje: Buenas noches a todos! Nos vemos mañana."
        XCTAssertTrue(WhatsAppSelectionCapture.matchesMessage("Buenas noches a todos!", descriptions: [description]))
        XCTAssertFalse(WhatsAppSelectionCapture.matchesMessage("Dit is een oude tekst.", descriptions: [description]))
        XCTAssertFalse(WhatsAppSelectionCapture.matchesMessage(" ", descriptions: [description]))
    }

    func testHighlightedWhatsAppMessageRoutesToSpanishTranslation() {
        let text = "Perfecto! era porque no sabía si igual os coincide carreras o algo por alli! por eso aviso con tiempo!\n\nSois uno/as máquinas!"
        XCTAssertEqual(ShortcutClassifier().classify(text), .spanish(text))
    }
}
