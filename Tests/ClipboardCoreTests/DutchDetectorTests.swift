import XCTest
@testable import ClipboardCore

final class DutchDetectorTests: XCTestCase {
    func testDutchSentencesAndEmailsWithMistakesAreEligible() {
        let detector = DutchDetector()
        for text in [
            "Ik vindt dit een goed idee en ik wordt er blij van.",
            "Kun je mij morgen even bellen",
            "Dat klopt niet.",
            "Beste Jan,\n\nBedankt voor je bericht. Ik heb de documenten ontvangen en zal ze morgen bekijken.\n\nGroeten,\nEmiel",
            "Morgen beginnen de lessen weer!!! We hebben er zin in!!! 💪🏼😊❤️🏑"
        ] {
            XCTAssertEqual(detector.candidate(text), text, text)
        }
    }

    func testNamesFragmentsAndOtherLanguagesStayQuiet() {
        let detector = DutchDetector()
        for text in ["Emiel van Goor", "Jan Pieter de Vries", "Jan Willem van der Meer",
                     "Amsterdam", "Factuur", "Goed idee", "de nieuwe factuur",
                     "de nieuwe factuur van januari", "een overzicht van alle openstaande facturen",
                     "de vergadering van volgende week",
                     "de status van je aanvraag", "een overzicht van je openstaande facturen",
                     "The meeting has moved to Thursday morning.",
                     "La reunión se ha cambiado al jueves a las diez.",
                     "Wir haben die Unterlagen erhalten und werden sie morgen prüfen."] {
            XCTAssertNil(detector.candidate(text), text)
        }
    }

    func testCodeContainingDutchStringsIsNotProse() {
        let detector = DutchDetector()
        for text in [
            "let bericht = \"Ik heb de documenten ontvangen en zal ze morgen bekijken.\"",
            "const tekst = 'Kun je mij morgen even bellen';",
            "{\"bericht\": \"Ik heb de documenten ontvangen en zal ze morgen bekijken.\"}",
            "```swift\n// Dit is een opmerking in het Nederlands.\nprint(bericht)\n```",
            "<p>Ik heb de documenten ontvangen en zal ze morgen bekijken.</p>",
            "// Dit is een opmerking in het Nederlands.",
            "print(\"Ik heb de documenten ontvangen en zal ze morgen bekijken.\")",
            "console.log('Ik heb de documenten ontvangen en zal ze morgen bekijken.');",
            "$bericht = \"Ik heb de documenten ontvangen en zal ze morgen bekijken.\";",
            "echo \"Ik heb de documenten ontvangen en zal ze morgen bekijken.\";",
            "SELECT naam FROM klanten WHERE naam = 'Dit is een Nederlandse zin';"
        ] {
            XCTAssertNil(detector.candidate(text), text)
        }
    }

    func testTrimmingDoesNotChangeAccentsEmojiOrEmailFormatting() {
        let text = "Ik heb één vraag over je e-mail.\nKun je mij morgen even bellen? 😊"
            .decomposedStringWithCanonicalMapping
        let result = DutchDetector().candidate("  \(text)\n")
        XCTAssertEqual(result.map { Array($0.utf8) }, Array(text.utf8))
    }

    func testEmptyNonTextAndOversizedSelectionsAreSkipped() {
        let detector = DutchDetector()
        for text: String? in [nil, " ", "12345", "😊❤️", "https://voorbeeld.nl", "jan@voorbeeld.nl",
                             String(repeating: "Dit is een Nederlandse zin. ", count: 500)] {
            XCTAssertNil(detector.candidate(text))
        }
    }
}
