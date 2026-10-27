import Foundation
import NaturalLanguage

/// The language whose words are being looked for in recognized or shared text.
public enum CandidateLanguage: String, Sendable {
    case english, japanese
}

/// Turns recognized text lines into de-duplicated word candidates, in reading order.
///
/// English: whitespace-split tokens, letters only, lowercased, at least `minLength` long,
/// function words left out — a scanned page offers its vocabulary, not its grammar.
/// Japanese: the system word segmentation (`NLTokenizer`), keeping tokens with a kanji or
/// katakana, or three or more hiragana — which drops particles (を, が, は) and
/// auxiliaries (た, ます, いる) but keeps きれい. A conjugated verb comes as its stem (聴い);
/// the card generator still identifies it.
public struct WordCandidateExtractor: Sendable {
    private let minLength: Int
    public init(minLength: Int = 2) { self.minLength = minLength }

    public func candidates(from lines: [String], language: CandidateLanguage = .english) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for token in lines.flatMap({ tokens(in: $0, language: language) }) {
            let key = language == .english ? token.lowercased() : token
            if seen.insert(key).inserted { result.append(key) }
        }
        return result
    }

    private func tokens(in line: String, language: CandidateLanguage) -> [String] {
        switch language {
        case .english:
            return line.split(whereSeparator: \.isWhitespace).compactMap { raw in
                let token = raw.trimmingCharacters(in: .punctuationCharacters)
                guard token.count >= minLength, token.allSatisfy(\.isLetter),
                      !Self.englishStopWords.contains(token.lowercased()) else { return nil }
                return token
            }
        case .japanese:
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.string = line
            tokenizer.setLanguage(.japanese)
            return tokenizer.tokens(for: line.startIndex ..< line.endIndex)
                .map { String(line[$0]) }
                .filter(Self.isJapaneseWord)
        }
    }

    /// A kanji or katakana anywhere, or hiragana alone and at least three long; nothing
    /// else (Latin, digits, punctuation) counts.
    private static func isJapaneseWord(_ token: String) -> Bool {
        var hiragana = 0
        var substantive = false
        for scalar in token.unicodeScalars {
            switch scalar.value {
            case 0x3041...0x309F: hiragana += 1
            case 0x30A1...0x30FA, 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x3005: substantive = true   // katakana, kanji, 々
            case 0x30FC: break   // ー, the long-vowel mark, rides along
            default: return false
            }
        }
        return substantive || hiragana >= 3
    }

    /// Articles, pronouns, prepositions, conjunctions, auxiliaries and the like.
    private static let englishStopWords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "nor", "so", "yet", "if", "then", "than", "as", "because",
        "of", "to", "in", "on", "at", "by", "for", "from", "with", "without", "into", "onto", "over",
        "under", "about", "above", "below", "between", "through", "during", "before", "after", "up",
        "down", "out", "off", "i", "me", "my", "mine", "we", "us", "our", "ours", "you", "your", "yours",
        "he", "him", "his", "she", "her", "hers", "it", "its", "they", "them", "their", "theirs", "this",
        "that", "these", "those", "who", "whom", "whose", "which", "what", "where", "when", "why", "how",
        "am", "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "having", "do",
        "does", "did", "doing", "will", "would", "shall", "should", "can", "could", "may", "might",
        "must", "not", "no", "yes", "there", "here", "all", "any", "each", "some", "such", "only",
        "own", "same", "very", "too", "also", "just", "both", "either", "neither", "one", "ones",
    ]
}
