import Foundation
import NaturalLanguage

public struct SpanishDetector {
    public init() {}
    public func candidate(_ text: String?, manual: Bool = false) -> String? {
        guard let text, text.count <= 10_000 else { return nil }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let letters = value.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        guard letters > 0 else { return nil }
        if !value.contains(where: { $0.isWhitespace }) {
            if value.contains("@") || value.hasPrefix("www.") || URLComponents(string: value)?.scheme != nil {
                return nil
            }
        }
        if manual { return value }
        guard letters >= 4 else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(value)
        guard recognizer.dominantLanguage == .spanish,
              (recognizer.languageHypotheses(withMaximum: 3)[.spanish] ?? 0) >= 0.80 else { return nil }
        return value
    }
}
