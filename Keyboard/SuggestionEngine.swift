import UIKit

struct Suggestion {
    let title: String
    let insert: String
    let isEmoji: Bool
}

final class SuggestionEngine {
    private let checker = UITextChecker()
    private let store = Store.shared

    static func trailingWord(_ text: String) -> String {
        var chars: [Character] = []
        for ch in text.reversed() {
            if ch.isLetter || ch == "'" || ch == "\u{2019}" {
                chars.append(ch)
                if chars.count >= 40 { break }
            } else {
                break
            }
        }
        return String(chars.reversed())
    }

    /// The word before `head` (lowercased), or "" at the start of a sentence.
    func previousWord(in head: String) -> String {
        guard let last = head.last, last.isWhitespace else { return "" }
        let trimmed = head.trimmingCharacters(in: .whitespacesAndNewlines)
        return SuggestionEngine.trailingWord(trimmed).lowercased()
    }

    private func capitalized(_ word: String) -> String {
        guard let first = word.first else { return word }
        return String(first).uppercased() + word.dropFirst()
    }

    func suggestions(context: String?, shortcuts: [Shortcut]) -> [Suggestion] {
        let ctx = context ?? ""
        let partial = SuggestionEngine.trailingWord(ctx)
        var out: [Suggestion] = []

        if !partial.isEmpty {
            let lower = partial.lowercased()
            let head = String(ctx.dropLast(partial.count))
            let previous = previousWord(in: head)
            var candidates: [String] = []

            if let sc = shortcuts.first(where: { $0.trigger.lowercased() == lower }) {
                candidates.append(sc.expansion)
            }
            candidates += store.learnedWords(prefix: lower, previous: previous, limit: 3)

            let ns = partial as NSString
            let full = NSRange(location: 0, length: ns.length)
            let missed = checker.rangeOfMisspelledWord(in: partial, range: full, startingAt: 0, wrap: false, language: "en_US")
            if missed.location != NSNotFound {
                candidates += checker.guesses(forWordRange: missed, in: partial, language: "en_US") ?? []
            }
            candidates += checker.completions(forPartialWordRange: full, in: partial, language: "en_US") ?? []

            let startsUpper = partial.first?.isUppercase ?? false
            var seen = Set<String>([lower])
            var words: [String] = []
            for c in candidates {
                let key = c.lowercased()
                if seen.contains(key) { continue }
                seen.insert(key)
                words.append(startsUpper ? capitalized(c) : c)
                if words.count >= 2 { break }
            }

            out.append(Suggestion(title: "\"\(partial)\"", insert: partial, isEmoji: false))
            for w in words {
                out.append(Suggestion(title: w, insert: w, isEmoji: false))
            }
            if partial.count >= 2, let emoji = EmojiData.suggestion(for: partial) {
                let item = Suggestion(title: emoji, insert: emoji, isEmoji: true)
                if out.count >= 3 { out[2] = item } else { out.append(item) }
            }
            return out
        }

        // No word being typed: predict the next word.
        let trimmed = ctx.trimmingCharacters(in: .whitespacesAndNewlines)
        let endsWithSpace = ctx.last?.isWhitespace ?? true
        if !ctx.isEmpty && !endsWithSpace { return [] }

        var atStart = trimmed.isEmpty || ctx.hasSuffix("\n")
        if let tl = trimmed.last, ".!?".contains(tl) { atStart = true }

        var words: [String] = []
        if atStart {
            words = ["I", "The", "I'm"]
        } else {
            let prev = SuggestionEngine.trailingWord(trimmed).lowercased()
            words = store.nextWords(after: prev, limit: 3)
            for d in ["the", "and", "to", "a", "of"] where !words.contains(d) {
                words.append(d)
            }
        }
        out = words.prefix(3).map { Suggestion(title: $0, insert: $0, isEmoji: false) }

        if !atStart, endsWithSpace, !ctx.isEmpty {
            let prev = SuggestionEngine.trailingWord(trimmed)
            if let emoji = EmojiData.suggestion(for: prev) {
                let item = Suggestion(title: emoji, insert: emoji, isEmoji: true)
                if out.count >= 3 { out[2] = item } else { out.append(item) }
            }
        }
        return out
    }
}
