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
/// Japanese reads the way a textbook page is laid out before it segments anything:
/// - a reading line over kanji (furigana Vision reads as its own line: めざ over 目指します)
///   and part-of-speech labels (〈名〉, 〈動Ⅰ〉) are dropped;
/// - `かな（漢字）` keeps the kanji form (いがくぶ（医学部） → 医学部), and `形（←辞書形）` the
///   dictionary form (目指します（←目指す） → 目指す);
/// - what is left splits at anything that isn't kana, kanji or Latin letters joined to them
///   (iPS細胞), and a piece that is one word — no hiragana (講演会), kanji with trailing
///   okurigana (懐かしい), or a short kana word — is kept whole;
/// - running text goes to the system word segmentation (`NLTokenizer`), whose kanji and
///   katakana pieces in a row are joined back (医学 + 部 → 医学部), keeping tokens with a kanji or
///   katakana, or three or more hiragana — which drops particles (を, が, は) and auxiliaries
///   (た, ます, いる) but keeps きれい. A conjugated verb comes as its stem (聴い); the card
///   generator still identifies it.
public struct WordCandidateExtractor: Sendable {
    private let minLength: Int
    public init(minLength: Int = 2) { self.minLength = minLength }

    public func candidates(from lines: [String], language: CandidateLanguage = .english) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        let tokens = language == .japanese
            ? Self.withoutReadingLines(lines).flatMap(Self.japaneseTokens)
            : lines.flatMap { tokens(in: $0, language: language) }
        for token in tokens {
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
            return Self.japaneseTokens(in: line)
        }
    }

    // MARK: Japanese

    private enum Script { case hiragana, katakana, kanji, latin, other }

    private static func script(of scalar: Unicode.Scalar) -> Script {
        switch scalar.value {
        case 0x3041...0x309F: .hiragana
        case 0x30A1...0x30FA, 0x30FC: .katakana   // ー, the long-vowel mark, rides with katakana
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x3005: .kanji   // 々 too
        case 0x41...0x5A, 0x61...0x7A: .latin
        default: .other
        }
    }

    private static func scripts(_ text: String) -> [Script] { text.unicodeScalars.map(script(of:)) }

    /// The lines without the furigana Vision reads as lines of their own: short, all
    /// hiragana, and over a line with kanji in it.
    private static func withoutReadingLines(_ lines: [String]) -> [String] {
        lines.indices.compactMap { index in
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            let isReading = !line.isEmpty && line.count <= 8 && scripts(line).allSatisfy { $0 == .hiragana }
            let overKanji = index + 1 < lines.count && scripts(lines[index + 1]).contains(.kanji)
            return isReading && overKanji ? nil : line
        }
    }

    private static func japaneseTokens(in line: String) -> [String] {
        // Part-of-speech labels, also when Vision misreads the closing bracket or misses it.
        let line = line.replacingOccurrences(of: "[〈《][^〉》（(]*[〉》]?", with: " ", options: .regularExpression)
        var pieces: [String] = []
        var rest = line[...]
        // かな（漢字） and 形（←辞書形）: one form per pair, the one to learn.
        let pair = /([^\s（()）]+)\s*[（(]([^（()）]*)[)）]/
        while let match = rest.firstMatch(of: pair) {
            pieces.append(String(rest[..<match.range.lowerBound]))
            pieces.append(chosen(String(match.output.1), String(match.output.2)))
            rest = rest[match.range.upperBound...]
        }
        pieces.append(String(rest))
        return pieces.flatMap(segments).flatMap(words)
    }

    /// Of `outside（inside）`, the form a learner adds: the dictionary form after an arrow, the
    /// kanji spelled out for a word written in kana, otherwise the word outside.
    private static func chosen(_ outside: String, _ inside: String) -> String {
        let arrows: Set<Character> = ["←", "⇐", "<"]
        let inner = String(inside.drop { arrows.contains($0) || $0.isWhitespace })
        if inner.count < inside.count, inner.unicodeScalars.contains(where: { script(of: $0) != .other }) {
            return inner
        }
        let outer = Set(scripts(outside)), within = Set(scripts(inner))
        if outer.contains(.hiragana), !outer.contains(.kanji), within.contains(.kanji) { return inner }
        return outside
    }

    /// The runs of kana, kanji, and Latin letters joined to them.
    private static func segments(_ text: String) -> [String] {
        var segments: [String] = []
        var current = ""
        for character in text {
            if character.unicodeScalars.allSatisfy({ script(of: $0) != .other }) {
                current.append(character)
            } else if !current.isEmpty {
                segments.append(current)
                current = ""
            }
        }
        if !current.isEmpty { segments.append(current) }
        return segments
    }

    /// One run as words: whole when it is one word, otherwise as the system segments it.
    private static func words(in segment: String) -> [String] {
        let kinds = scripts(segment)
        guard kinds.contains(where: { $0 != .latin }) else { return [] }   // English inside Japanese
        let hiragana = kinds.filter { $0 == .hiragana }.count
        let okurigana = kinds.drop { $0 != .hiragana }.allSatisfy { $0 == .hiragana }   // 懐かしい, 目指す
        let isOneWord = hiragana == 0
            || (okurigana && kinds.first != .hiragana && segment.count <= 8)
            || (hiragana == kinds.count && segment.count <= 7)
        if isOneWord { return isJapaneseWord(segment) ? [segment] : [] }

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = segment
        tokenizer.setLanguage(.japanese)
        var tokens: [String] = []
        for range in tokenizer.tokens(for: segment.startIndex ..< segment.endIndex) {
            let token = String(segment[range])
            // Kanji and katakana pieces in a row are one compound the segmenter split: 医学 + 部.
            if let last = tokens.last, isCompoundPiece(last), isCompoundPiece(token), segment.range(of: last + token) != nil {
                tokens[tokens.count - 1] = last + token
            } else {
                tokens.append(token)
            }
        }
        return tokens.filter(isJapaneseWord)
    }

    private static func isCompoundPiece(_ token: String) -> Bool {
        scripts(token).allSatisfy { $0 == .kanji || $0 == .katakana }
    }

    /// Japanese, and a word: a kanji or more than one katakana anywhere, or hiragana alone and
    /// at least three long. Latin counts only joined to Japanese (iPS細胞).
    private static func isJapaneseWord(_ token: String) -> Bool {
        let kinds = scripts(token)
        guard !kinds.contains(.other) else { return false }
        let katakana = kinds.filter { $0 == .katakana }.count
        let hiragana = kinds.filter { $0 == .hiragana }.count
        return kinds.contains(.kanji) || katakana >= 2 || (hiragana >= 3 && hiragana == kinds.count)
            || (katakana == 1 && hiragana > 0)
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
