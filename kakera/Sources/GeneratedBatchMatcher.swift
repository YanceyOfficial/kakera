import Foundation
import KakeraAI
import KakeraUI

/// Pairs the words a request asked for with what the model wrote back: its card, its
/// verdict that the word wasn't recognized, or nothing at all. The model may respell a
/// word (case, full-width letters, a dropped "〜", ruby it was told not to write), so
/// words are compared by a normalized key, and a lone leftover card still goes to the
/// lone leftover word.
enum GeneratedBatchMatcher {
    enum Match: Equatable {
        case card(GeneratedCard)
        case unrecognized(UnrecognizedWord)
        /// Neither a card nor a verdict came back for the word.
        case missing
    }

    static func match(lemmas: [String], batch: GeneratedCardBatch) -> [String: Match] {
        var matches: [String: Match] = [:]
        var cards = batch.cards
        var unrecognized = batch.unrecognized
        var unmatched: [String] = []
        for lemma in lemmas {
            let k = key(lemma)
            if let i = cards.firstIndex(where: { key($0.lemma) == k }) {
                matches[lemma] = .card(cards.remove(at: i))
            } else if let i = unrecognized.firstIndex(where: { key($0.input) == k }) {
                matches[lemma] = .unrecognized(unrecognized.remove(at: i))
            } else {
                unmatched.append(lemma)
            }
        }
        // One word and one card left over: the card is the word's, respelled.
        if unmatched.count == 1, cards.count == 1, unrecognized.isEmpty {
            matches[unmatched[0]] = .card(cards[0])
        } else {
            for lemma in unmatched { matches[lemma] = .missing }
        }
        return matches
    }

    /// The word as compared: ruby stripped, case and width folded, tildes, dashes and
    /// punctuation trimmed from the ends, inner whitespace collapsed.
    static func key(_ text: String) -> String {
        let edges = CharacterSet(charactersIn: "〜～~-–—…・*").union(.whitespacesAndNewlines).union(.punctuationCharacters)
        return Ruby.plain(text)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: edges)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
