import Foundation

/// One example sentence with its translation, as produced by the model.
public struct GeneratedExample: Codable, Equatable, Sendable {
    public let sentence: String
    public let translation: String
}

/// A cluster of similar words sharing one sense, grouped like a bilingual
/// dictionary: `sense` is the shared meaning (Chinese gloss), `words` are the
/// English words that carry it.
public struct GeneratedSynonymGroup: Codable, Equatable, Sendable {
    public let sense: String
    public let words: [String]
}

/// A fixed collocation the model produced: `phrase`/`example` are English, `meaning`
/// and `exampleTranslation` are Chinese glosses.
public struct GeneratedCollocation: Codable, Equatable, Sendable {
    public let phrase: String
    public let meaning: String
    public let example: String
    public let exampleTranslation: String
}

/// One quiz item. `type` is the raw value of a KakeraCore `QuizType`; validated at ingestion.
public struct GeneratedQuiz: Codable, Equatable, Sendable {
    public let type: String
    public let question: String
    public let choices: [String]
    public let answers: [String]
    public let translation: String
}

/// A full vocabulary card produced by the model, before it is mapped to a KakeraCore entry.
public struct GeneratedCard: Codable, Equatable, Sendable {
    public let lemma: String
    public let kind: String
    public let phonetic: String
    public let syllables: [String]
    /// Concise Chinese gloss (part of speech + short meaning).
    public let explanation: String
    /// Fuller English definition; empty string when the model has none.
    public let explanationEn: String
    public let partsOfSpeech: [String]
    public let examples: [GeneratedExample]
    public let mnemonic: String
    public let etymology: String
    /// Morpheme breakdown (prefix/root/suffix with meanings). Optional — the model
    /// omits it for words with no identifiable roots.
    public let roots: String?
    /// Similar words grouped by shared sense (see `GeneratedSynonymGroup`).
    public let synonyms: [GeneratedSynonymGroup]
    /// Fixed collocations / phrases the word commonly forms (see `GeneratedCollocation`).
    public let collocations: [GeneratedCollocation]
    public let confusables: [String]
    public let quizzes: [GeneratedQuiz]
}

/// An item the model could not identify as a word or expression of the language — a typo,
/// another language, stray characters — so it wrote no card for it. `suggestions` are the
/// words the learner most likely meant (plain text, dictionary form), for them to pick from.
public struct UnrecognizedWord: Codable, Equatable, Sendable {
    public let input: String
    /// A short reason in the learner's language (Chinese).
    public let reason: String
    public let suggestions: [String]

    public init(input: String, reason: String, suggestions: [String]) {
        self.input = input
        self.reason = reason
        self.suggestions = suggestions
    }
}

/// The top-level object returned by structured-output generation (a schema must be an object):
/// one card per recognized item, and the items the model did not recognize.
public struct GeneratedCardBatch: Codable, Equatable, Sendable {
    public let cards: [GeneratedCard]
    /// Empty when every item got a card. Decodes as empty when a reply (or a test fixture)
    /// predates the key.
    public let unrecognized: [UnrecognizedWord]

    public init(cards: [GeneratedCard], unrecognized: [UnrecognizedWord] = []) {
        self.cards = cards
        self.unrecognized = unrecognized
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cards = try container.decode([GeneratedCard].self, forKey: .cards)
        unrecognized = try container.decodeIfPresent([UnrecognizedWord].self, forKey: .unrecognized) ?? []
    }
}
