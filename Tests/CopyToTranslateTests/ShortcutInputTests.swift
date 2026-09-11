import XCTest
import ClipboardCore
@testable import CopyToTranslate

final class ShortcutInputTests: XCTestCase {
    func testSelectionWinsWithoutReadingClipboard() throws {
        var clipboardRead = false
        let source = try ShortcutInput.read(selection: { "did is een  test" }, clipboard: {
            clipboardRead = true
            return "Other clipboard content"
        })
        XCTAssertEqual(source, "did is een  test")
        XCTAssertFalse(clipboardRead)
    }

    func testNoSelectionUsesExistingClipboardWorkflow() throws {
        XCTAssertEqual(try ShortcutInput.read(selection: { nil }, clipboard: { "Ik vindt dit leuk." }),
                       "Ik vindt dit leuk.")
    }

    func testAccessErrorsNeverSendUnrelatedClipboardContent() {
        for error in [SelectedTextError.permissionRequired, .unavailable, .secureField] {
            var clipboardRead = false
            XCTAssertThrowsError(try ShortcutInput.read(selection: { throw error }, clipboard: {
                clipboardRead = true
                return "Private clipboard content"
            }))
            XCTAssertFalse(clipboardRead)
        }
    }

    func testShortcutClassifiesSpanishBeforeDutchWithoutCloudDetection() {
        let spanish = "Feliz comienzo de clases!!! Empezamos con la rutina!!! 💪🏼😊❤️🏑\nLos esperamos a todos esta tarde 🏑🏑🏑"
        XCTAssertEqual(ShortcutClassifier().classify(spanish), .spanish(spanish))
        XCTAssertEqual(ShortcutClassifier().classify("did is een  test"), .dutch("did is een  test"))
    }

    func testShortcutSkipsCodeNamesAndOtherLanguages() {
        for text in ["Emiel van Goor", "let greeting = \"Hola mundo\"", "This is an English sentence.", "💪🏼😊❤️🏑"] {
            XCTAssertNil(ShortcutClassifier().classify(text), text)
        }
    }
}
