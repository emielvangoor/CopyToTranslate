import Foundation

public enum ShortcutAction: Equatable {
    case spanish(String), dutch(String)
}

/// Local classification happens before any translation or proofreading request.
public struct ShortcutClassifier {
    public init() {}

    public func classify(_ text: String?) -> ShortcutAction? {
        let dutch = DutchDetector()
        guard let text, text.count <= 10_000, !dutch.looksLikeCode(text) else { return nil }
        if let source = SpanishDetector().candidate(text) { return .spanish(source) }
        if let source = dutch.candidate(text) { return .dutch(source) }
        return nil
    }
}
