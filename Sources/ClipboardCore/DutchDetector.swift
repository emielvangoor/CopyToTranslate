import Foundation
import NaturalLanguage

/// Conservative proofreading eligibility. A missed fragment is preferable
/// to sending a name, identifier, or source code to the correction model.
public struct DutchDetector {
    public init() {}

    public func candidate(_ text: String?) -> String? {
        guard let text, text.count <= 10_000 else { return nil }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !looksLikeCode(value) else { return nil }
        let words = value.split { !$0.isLetter && $0 != "'" && $0 != "’" && $0 != "-" }
        guard words.count >= 4 || (words.count >= 3 && value.last.map { ".!?".contains($0) } == true),
              words.reduce(0, { $0 + $1.count }) >= 12 else { return nil }

        let nameParticles: Set<String> = ["van", "de", "der", "den", "ten", "ter", "te", "von", "en", "'t", "’t"]
        if words.count <= 8 && words.allSatisfy({ $0.first?.isUppercase == true || nameParticles.contains($0.lowercased()) }) {
            return nil
        }
        let sentenceWords: Set<String> = ["ik", "jij", "je", "u", "wij", "we", "jullie", "hij", "zij", "ze",
            "het", "de", "een", "dit", "dat", "die", "er", "wat", "wie", "hoe", "waar", "waarom", "wanneer",
            "welke", "als", "maar", "omdat", "zodat", "ook", "niet", "wel", "graag", "kan", "kun", "kunnen",
            "moet", "moeten", "zal", "zullen", "heb", "hebt", "heeft", "hebben", "ben", "bent", "is", "zijn",
            "was", "waren", "word", "wordt", "worden", "werd", "werden", "zou", "zouden", "en", "of", "met", "voor", "naar", "bij"]
        guard words.contains(where: { sentenceWords.contains($0.lowercased()) }) else { return nil }
        // Dutch lexical-class tagging is unavailable in NaturalLanguage. Use
        // strong prose cues instead of treating an article/preposition as a sentence.
        let subjectWords: Set<String> = ["ik", "jij", "wij", "we", "hij", "zij", "ze"]
        let initialSubjects: Set<String> = ["je", "u", "jullie", "dit", "dat"]
        let verbWords: Set<String> = ["ben", "bent", "is", "zijn", "was", "waren", "heb", "hebt", "heeft", "hebben",
            "had", "hadden", "word", "wordt", "worden", "werd", "werden", "kan", "kun", "kunt", "kunnen",
            "zal", "zullen", "zou", "zouden", "moet", "moeten", "mag", "mogen", "wil", "wilt", "willen"]
        let hasSentenceCue = words.contains { subjectWords.contains($0.lowercased()) || verbWords.contains($0.lowercased()) }
            || words.first.map { initialSubjects.contains($0.lowercased()) } == true
            || value.contains(where: { ".!?".contains($0) })
        guard hasSentenceCue else { return nil }

        let proseCharacters = CharacterSet.letters.union(.decimalDigits)
            .union(.whitespacesAndNewlines).union(.punctuationCharacters)
        let sample = String(value.precomposedStringWithCanonicalMapping.unicodeScalars.map {
            proseCharacters.contains($0) ? Character(String($0)) : " "
        })
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        guard recognizer.dominantLanguage == .dutch,
              (recognizer.languageHypotheses(withMaximum: 3)[.dutch] ?? 0) >= 0.85 else { return nil }
        return value
    }

    func looksLikeCode(_ text: String) -> Bool {
        if text.contains("```") || text.contains("<?") || text.contains("=>") || text.contains("==") { return true }
        let patterns = [
            #"(?m)^\s*(?://|/\*|\*/|# |-- )"#,
            #"(?m)^\s*(?:let|var|const|def|func|function|class|struct|enum|import|package|using)\s+\S"#,
            #"(?m)^\s*(?:echo|printf)\s+[\"'$]"#,
            #"(?m)^\s*\$?[\p{L}_][\p{L}\p{N}_.$\[\]]*\s*(?:=|:=)\s*\S"#,
            #"(?m)^\s*[\p{L}_$][\p{L}\p{N}_.$]*\s*\([^\n]*\)\s*;?\s*$"#,
            #"(?is)^\s*(?:SELECT\b.+\bFROM|INSERT\s+INTO|UPDATE\b.+\bSET|DELETE\s+FROM)\b"#,
            #"<\/?[A-Za-z][A-Za-z0-9]*(?:\s[^>]*|\s*\/?)>"#,
            #"(?s)^\s*[\{\[].*[\}\]]\s*$"#,
            #"(?m)^\s*(?:if|for|while|switch)\s*\(.+\)\s*\{"#
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }
}
