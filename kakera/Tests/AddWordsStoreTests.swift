import Testing
import Foundation
import SwiftData
@testable import Kakera
import KakeraAI
import KakeraCore

/// The add-words flow's data path: words go in, cards land one by one, and what the model
/// couldn't do waits for the learner. On an in-memory container (SwiftData: simulator only).
@MainActor
@Suite(.serialized)
struct AddWordsStoreTests {
    /// Answers each word by a script, counting attempts per word.
    final class ScriptedProvider: LLMProvider, @unchecked Sendable {
        enum Answer {
            case card(gloss: String)
            case unrecognized(reason: String, suggestions: [String])
            case failure(AIError)
            /// Fails the first time, then answers with a card.
            case failOnce(thenGloss: String)
        }
        private let lock = NSLock()
        private var script: [String: Answer]
        private var attempts: [String: Int] = [:]
        init(_ script: [String: Answer]) { self.script = script }

        func attempts(for word: String) -> Int { lock.withLock { attempts[word] ?? 0 } }

        func generateCards(lemmas: [String], language: LanguageDomain, literaryExamples: Bool) async throws -> GeneratedCardBatch {
            var cards: [GeneratedCard] = []
            var unrecognized: [UnrecognizedWord] = []
            for lemma in lemmas {
                let (answer, attempt): (Answer?, Int) = lock.withLock {
                    attempts[lemma, default: 0] += 1
                    return (script[lemma] ?? script[lemma.lowercased()], attempts[lemma]!)
                }
                switch answer {
                case .card(let gloss): cards.append(Self.card(lemma, gloss: gloss))
                case .unrecognized(let reason, let suggestions):
                    unrecognized.append(UnrecognizedWord(input: lemma, reason: reason, suggestions: suggestions))
                case .failure(let error): throw error
                case .failOnce(let gloss):
                    if attempt == 1 { throw AIError.http(status: 529, body: "overloaded") }
                    cards.append(Self.card(lemma, gloss: gloss))
                case nil: break
                }
            }
            return GeneratedCardBatch(cards: cards, unrecognized: unrecognized)
        }

        func generateStory(words: [String], language: LanguageDomain) async throws -> GeneratedStory {
            throw AIError.emptyResponse   // not exercised here
        }

        static func card(_ lemma: String, gloss: String) -> GeneratedCard {
            let json = """
            {"lemma":"\(lemma)","kind":"word","phonetic":"","syllables":[],"explanation":"\(gloss)","explanationEn":"",
            "partsOfSpeech":[],"examples":[],"mnemonic":"","etymology":"","synonyms":[],"collocations":[],
            "confusables":[],"quizzes":[]}
            """
            return try! JSONDecoder().decode(GeneratedCard.self, from: Data(json.utf8))
        }
    }

    /// Its own store, held for the test's whole life: these tests suspend while the store
    /// works, and in-memory containers all share one SQLite store — another suite dropping
    /// its container mid-await took the connection from under a fetch here (`scratch()`).
    private let container: ModelContainer
    private let repository: VocabularyRepository

    init() throws {
        container = try KakeraModelContainer.scratch()
        repository = VocabularyRepository(context: ModelContext(container))
    }

    private func makeStore(_ provider: ScriptedProvider) -> AddWordsStore {
        AddWordsStore(repository: repository, language: .english) { provider }
    }

    @Test("Each word lands in the deck as its card arrives, with its gloss")
    func wordsLandWithGlosses() async throws {
        let store = makeStore(ScriptedProvider(["alpha": .card(gloss: "n. 开端"), "beta": .card(gloss: "n. 其次")]))
        store.start(words: ["alpha", "beta"])
        await store.settle()
        #expect(store.items.map(\.word) == ["alpha", "beta"])
        #expect(store.items.map(\.status) == [.added(gloss: "n. 开端"), .added(gloss: "n. 其次")])
        #expect(try repository.entries(for: .english).map(\.lemma).sorted() == ["alpha", "beta"])
        #expect(store.addedCount == 2)
        #expect(store.isSettled)
        #expect(!store.needsAttention)
    }

    @Test("A word the model doesn't recognize waits for the learner, with the suggestions, and is not added")
    func unrecognizedWaits() async throws {
        let store = makeStore(ScriptedProvider(["serendipty": .unrecognized(reason: "拼写有误", suggestions: ["serendipity"])]))
        store.start(words: ["serendipty"])
        await store.settle()
        #expect(store.items.first?.status == .unrecognized(reason: "拼写有误", suggestions: ["serendipity"]))
        #expect(try repository.entries(for: .english).isEmpty)
        #expect(store.needsAttention)
    }

    @Test("A failed word names what went wrong and can be retried")
    func failedWordRetries() async throws {
        let provider = ScriptedProvider(["flaky": .failOnce(thenGloss: "adj. 不稳定的")])
        let store = makeStore(provider)
        store.start(words: ["flaky"])
        await store.settle()
        #expect(store.items.first?.status == .failed(message: AIError.http(status: 529, body: "overloaded").localizedDescription))

        store.retry(store.items[0].id)
        await store.settle()
        #expect(store.items.first?.status == .added(gloss: "adj. 不稳定的"))
        #expect(provider.attempts(for: "flaky") == 2)
        #expect(try repository.entries(for: .english).count == 1)
    }

    @Test("Picking a suggestion generates that word in place of the typo")
    func suggestionReplacesTypo() async throws {
        let store = makeStore(ScriptedProvider([
            "serendipty": .unrecognized(reason: "拼写有误", suggestions: ["serendipity"]),
            "serendipity": .card(gloss: "n. 机缘巧合"),
        ]))
        store.start(words: ["serendipty"])
        await store.settle()
        store.replace(store.items[0].id, with: "serendipity")
        await store.settle()
        #expect(store.items.map(\.word) == ["serendipity"])
        #expect(store.items.first?.status == .added(gloss: "n. 机缘巧合"))
        #expect(try repository.entries(for: .english).map(\.lemma) == ["serendipity"])
    }

    @Test("Without a usable AI setup every word fails with the reason")
    func setupFailureNamesReason() async throws {
        let store = AddWordsStore(repository: repository, language: .english) {
            throw AIError.missingAPIKey
        }
        store.start(words: ["alpha"])
        await store.settle()
        #expect(store.items.first?.status == .failed(message: AIError.missingAPIKey.localizedDescription))
        #expect(store.setupError == AIError.missingAPIKey.localizedDescription)
    }

    @Test("A word already in the deck is reported as such, not added twice")
    func duplicateIsReported() async throws {
        let store = makeStore(ScriptedProvider(["alpha": .card(gloss: "n. 开端")]))
        try StarterSeed.seedIfEmpty(repository)
        let before = try repository.entries(for: .english).count
        _ = try repository.insertIfAbsent(AICardMapper.entry(from: ScriptedProvider.card("alpha", gloss: "old")))
        store.start(words: ["Alpha"])
        await store.settle()
        #expect(store.items.first?.status == .alreadyInDeck)
        #expect(try repository.entries(for: .english).count == before + 1)
    }
}
