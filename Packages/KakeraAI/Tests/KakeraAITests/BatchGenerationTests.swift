import Foundation
import Testing
import KakeraCore
@testable import KakeraAI

/// A mock provider that returns one card per lemma, but throws for any chunk that
/// contains a lemma starting with "!" — lets us assert chunking and partial-failure.
private struct MockProvider: LLMProvider {
    let chunkSizesSeen: Recorder

    final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var sizes: [Int] = []
        func record(_ n: Int) { lock.lock(); sizes.append(n); lock.unlock() }
    }

    /// A lemma starting with "?" is reported as unrecognized instead of getting a card.
    func generateCards(lemmas: [String], language: LanguageDomain, literaryExamples: Bool) async throws -> GeneratedCardBatch {
        chunkSizesSeen.record(lemmas.count)
        if lemmas.contains(where: { $0.hasPrefix("!") }) {
            throw AIError.emptyResponse
        }
        return GeneratedCardBatch(
            cards: lemmas.filter { !$0.hasPrefix("?") }.map { card(lemma: $0) },
            unrecognized: lemmas.filter { $0.hasPrefix("?") }.map {
                UnrecognizedWord(input: $0, reason: "拼写有误", suggestions: [String($0.dropFirst())])
            })
    }

    func generateStory(words: [String], language: LanguageDomain) async throws -> GeneratedStory {
        GeneratedStory(story: words.joined(separator: " "), translation: "")
    }

    private func card(lemma: String) -> GeneratedCard {
        let json = """
        {"lemma":"\(lemma)","kind":"word","phonetic":"","syllables":[],"explanation":"",
        "explanationEn":"","partsOfSpeech":[],"examples":[],"mnemonic":"","etymology":"",
        "synonyms":[],"collocations":[],"confusables":[],"quizzes":[]}
        """
        return try! JSONDecoder().decode(GeneratedCard.self, from: Data(json.utf8))
    }
}

@Test("Batch generation splits lemmas into chunks of at most chunkSize")
func batchesIntoChunks() async {
    let recorder = MockProvider.Recorder()
    let provider = MockProvider(chunkSizesSeen: recorder)
    let lemmas = (1...25).map { "w\($0)" }

    let outcome = await provider.generateCards(lemmas: lemmas, language: .english, literaryExamples: false, chunkSize: 10)

    #expect(outcome.cards.count == 25)
    #expect(recorder.sizes.sorted() == [5, 10, 10])   // 25 split into 10/10/5 (chunks run concurrently)
    #expect(outcome.failures.isEmpty)
    #expect(outcome.cards.map(\.lemma) == lemmas)   // input order preserved
}

@Test("A failing chunk is recorded but does not abort the rest")
func partialFailureIsBestEffort() async {
    let provider = MockProvider(chunkSizesSeen: .init())
    // Second chunk (w4,w5,w6) contains a poison lemma and will throw.
    let lemmas = ["w1", "w2", "w3", "!bad", "w5", "w6", "w7"]

    let outcome = await provider.generateCards(lemmas: lemmas, language: .english, literaryExamples: false, chunkSize: 3)

    #expect(outcome.failures.count == 1)
    #expect(outcome.cards.map(\.lemma) == ["w1", "w2", "w3", "w7"])   // chunks 1 and 3 survived
}

@Test("A failed chunk's record names its words and says what went wrong")
func failureNamesItsWords() async {
    let provider = MockProvider(chunkSizesSeen: .init())
    let outcome = await provider.generateCards(lemmas: ["w1", "!bad", "w3"], language: .english, literaryExamples: false, chunkSize: 1)
    #expect(outcome.failures.map(\.lemmas) == [["!bad"]])
    #expect(outcome.failures.first?.message == AIError.emptyResponse.localizedDescription)
}

@Test("Unrecognized items from every chunk are collected beside the cards")
func unrecognizedCollected() async {
    let provider = MockProvider(chunkSizesSeen: .init())
    let outcome = await provider.generateCards(lemmas: ["w1", "?typo", "w3", "?tpyo"], language: .english, literaryExamples: false, chunkSize: 2)
    #expect(outcome.cards.map(\.lemma) == ["w1", "w3"])
    #expect(outcome.unrecognized.map(\.input) == ["?typo", "?tpyo"])
    #expect(outcome.unrecognized.first?.suggestions == ["typo"])
}

@Test("Each chunk is reported as it finishes, with its words, before the whole batch is done")
func chunksReportedAsTheyFinish() async {
    final class Seen: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var results: [CardChunkResult] = []
        func add(_ r: CardChunkResult) { lock.lock(); results.append(r); lock.unlock() }
    }
    let seen = Seen()
    let provider = SlowProvider()   // "slow…" lemmas take longer than the rest
    let outcome = await provider.generateCards(
        lemmas: ["slow1", "fast1", "!bad"], language: .english, literaryExamples: false, chunkSize: 1, concurrency: 3
    ) { result in
        seen.add(result)
    }
    #expect(outcome.cards.map(\.lemma) == ["slow1", "fast1"])
    // Reported in completion order, not input order: the slow word comes last.
    #expect(seen.results.map(\.lemmas) == [["fast1"], ["!bad"], ["slow1"]] || seen.results.map(\.lemmas) == [["!bad"], ["fast1"], ["slow1"]])
    if case .generated(let lemmas, let batch)? = seen.results.last {
        #expect(lemmas == ["slow1"])
        #expect(batch.cards.map(\.lemma) == ["slow1"])
    } else {
        Issue.record("the slow chunk should be reported last, as generated")
    }
    #expect(seen.results.contains { if case .failed(let lemmas, _) = $0 { lemmas == ["!bad"] } else { false } })
}

@Test("chunkSize below 1 is clamped to 1")
func clampsChunkSize() async {
    let provider = MockProvider(chunkSizesSeen: .init())
    let outcome = await provider.generateCards(lemmas: ["a", "b"], language: .english, literaryExamples: false, chunkSize: 0)
    #expect(outcome.cards.count == 2)
}

@Test("Chunks run concurrently, and order still follows the input")
func chunksRunConcurrently() async {
    let clock = ContinuousClock()
    let provider = SlowProvider()
    let lemmas = (1...8).map { "w\($0)" }
    let start = clock.now
    let outcome = await provider.generateCards(lemmas: lemmas, language: .english, literaryExamples: false, chunkSize: 2, concurrency: 4)
    let elapsed = clock.now - start
    #expect(outcome.cards.map(\.lemma) == lemmas)
    // Four chunks of 200 ms each: together about 200 ms, one after another 800 ms.
    #expect(elapsed < .milliseconds(600))
}

@Test("Truncation reads as advice, not an error code")
func truncationDescription() {
    #expect(AIError.truncated.localizedDescription.contains("fewer words"))
    #expect(!AIError.decoding("x").localizedDescription.contains("error 2"))
}

/// Answers each chunk after a delay — 200 ms, or 500 ms for a chunk with a "slow…" lemma —
/// to show ordering holds; a "!…" lemma makes the chunk fail.
private struct SlowProvider: LLMProvider {
    func generateCards(lemmas: [String], language: LanguageDomain, literaryExamples: Bool) async throws -> GeneratedCardBatch {
        try await Task.sleep(for: .milliseconds(lemmas.contains { $0.hasPrefix("slow") } ? 500 : 200))
        if lemmas.contains(where: { $0.hasPrefix("!") }) { throw AIError.emptyResponse }
        return GeneratedCardBatch(cards: lemmas.map { lemma in
            let json = """
            {"lemma":"\(lemma)","kind":"word","phonetic":"","syllables":[],"explanation":"",
            "explanationEn":"","partsOfSpeech":[],"examples":[],"mnemonic":"","etymology":"",
            "synonyms":[],"collocations":[],"confusables":[],"quizzes":[]}
            """
            return try! JSONDecoder().decode(GeneratedCard.self, from: Data(json.utf8))
        })
    }

    func generateStory(words: [String], language: LanguageDomain) async throws -> GeneratedStory {
        GeneratedStory(story: "", translation: "")
    }
}
