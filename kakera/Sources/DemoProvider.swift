#if DEBUG
import Foundation
import KakeraAI
import KakeraCore

/// The simulator's stand-in for the model: with `-demoAI YES` the add-words flow runs without
/// a key, every word answered after a beat — a card for most, the model's "did you mean" for
/// a few planted typos, an overloaded provider for `fail`, and a wait that outlasts any
/// screenshot for `ineffable` (still being written when the picture is taken). Screenshots
/// and probes (`KakeraUITests`); debug builds only.
enum DemoAI {
    static var isRequested: Bool { UserDefaults.standard.bool(forKey: "demoAI") }
}

/// Answers from a small table instead of a model; see `DemoAI`.
struct DemoProvider: LLMProvider {
    func generateCards(lemmas: [String], language: LanguageDomain, literaryExamples: Bool) async throws -> GeneratedCardBatch {
        var cards: [GeneratedCard] = []
        var unrecognized: [UnrecognizedWord] = []
        for lemma in lemmas {
            let word = lemma.trimmingCharacters(in: .whitespacesAndNewlines)
            try await Task.sleep(for: .seconds(Self.wait(for: word)))
            if let typo = Self.typos[word.lowercased()] {
                unrecognized.append(UnrecognizedWord(input: lemma, reason: typo.reason, suggestions: typo.suggestions))
            } else if word.lowercased() == "fail" {
                throw AIError.http(status: 529, body: #"{"type":"error","error":{"type":"overloaded_error"}}"#)
            } else {
                cards.append(try Self.card(word))
            }
        }
        return GeneratedCardBatch(cards: cards, unrecognized: unrecognized)
    }

    func generateStory(words: [String], language: LanguageDomain) async throws -> GeneratedStory {
        try await Task.sleep(for: .seconds(2))
        let json = """
        {"story":"A short passage that uses \(words.joined(separator: ", ")).",
        "translation":"一段用到这些词的短文。"}
        """
        return try JSONDecoder().decode(GeneratedStory.self, from: Data(json.utf8))
    }

    private static func wait(for word: String) -> Double {
        switch word.lowercased() {
        case "ineffable": 600
        case let typo where typos[typo] != nil: 2
        default: 3
        }
    }

    private static let typos: [String: (reason: String, suggestions: [String])] = [
        "serendipty": ("拼写有误，英语里没有这个词。", ["serendipity"]),
        "recieve": ("拼写有误（i 和 e 的顺序反了）。", ["receive"]),
        "によようと": ("不是日语中既有的词或句型，很可能是「によると」的误写。", ["によると", "によって"]),
    ]

    private static let known: [String: (phonetic: String, gloss: String, sentence: String, translation: String)] = [
        "halcyon": ("/ˈhæl.si.ən/", "adj. 宁静的；太平的", "He looked back on the halcyon days of his youth.", "他回望年轻时的太平岁月。"),
        "petrichor": ("/ˈpet.rɪ.kɔːr/", "n. 雨后泥土的气息", "The petrichor after the storm filled the garden.", "暴雨过后，花园里弥漫着泥土的气息。"),
        "sonorous": ("/ˈsɒn.ər.əs/", "adj. 洪亮的；响亮的", "His sonorous voice carried across the hall.", "他洪亮的嗓音响彻大厅。"),
    ]

    /// The word's own card when the table has one, else a generic one.
    private static func card(_ word: String) throws -> GeneratedCard {
        let entry = known[word.lowercased()]
        let json = """
        {"lemma":"\(word)","kind":"word","phonetic":"\(entry?.phonetic ?? "")","syllables":[],
        "explanation":"\(entry?.gloss ?? "n. 示例释义")","explanationEn":"","partsOfSpeech":[],
        "examples":[{"sentence":"\(entry?.sentence ?? "An example sentence with \(word).")","translation":"\(entry?.translation ?? "一个例句。")"}],
        "mnemonic":"","etymology":"","synonyms":[],"collocations":[],"confusables":[],"quizzes":[]}
        """
        return try JSONDecoder().decode(GeneratedCard.self, from: Data(json.utf8))
    }
}
#endif
