import XCTest
import ClipboardCore

final class ShortcutClassifierTests: XCTestCase {
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
