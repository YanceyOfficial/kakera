import Foundation
import Observation
import KakeraAI
import KakeraCore
import KakeraServices

/// Drives the add-words flow: each word is its own request to the model (the shortest
/// request there is, and one that fails or succeeds on its own), a few in flight at
/// once, and every card lands in the deck the moment it is written — the screen shows
/// the words landing one by one instead of a spinner for minutes. A word the model
/// doesn't recognize waits here with its suggestions, and a failed one with its reason
/// and a retry.
@MainActor
@Observable
final class AddWordsStore {
    enum Status: Equatable {
        case queued
        case generating
        case added(gloss: String)
        case alreadyInDeck
        case unrecognized(reason: String, suggestions: [String])
        case failed(message: String)
    }

    struct Item: Identifiable, Equatable {
        let id: UUID
        var word: String
        var status: Status
    }

    private(set) var items: [Item] = []
    private(set) var isGenerating = false
    /// Why nothing could be generated at all (no key, no model), when that was the case.
    private(set) var setupError: String?
    let language: LanguageDomain

    private let repository: VocabularyRepository
    private let makeProvider: @Sendable () async throws -> any LLMProvider
    private var run: Task<Void, Never>?

    /// Requests in flight at once.
    static let concurrency = 4

    init(
        repository: VocabularyRepository,
        language: LanguageDomain,
        makeProvider: @escaping @Sendable () async throws -> any LLMProvider = {
            ProviderFactory.make(try await AIConfigStore.readyConfiguration())
        }
    ) {
        self.repository = repository
        self.language = language
        self.makeProvider = makeProvider
    }

    // MARK: Reading

    /// Words now in the deck: added just now, or found there already.
    var addedCount: Int {
        items.filter { if case .added = $0.status { true } else { $0.status == .alreadyInDeck } }.count
    }

    /// Words the learner has to do something about: unrecognized or failed.
    var needsAttention: Bool {
        items.contains { if case .unrecognized = $0.status { true } else if case .failed = $0.status { true } else { false } }
    }

    /// Nothing is waiting or in flight.
    var isSettled: Bool {
        !isGenerating && !items.contains { $0.status == .queued || $0.status == .generating }
    }

    // MARK: Driving

    /// Queues the words (ones already listed are skipped) and starts generating.
    func start(words: [String]) {
        var seen = Set(items.map { GeneratedBatchMatcher.key($0.word) })
        for word in words where seen.insert(GeneratedBatchMatcher.key(word)).inserted {
            items.append(Item(id: UUID(), word: word, status: .queued))
        }
        generate()
    }

    /// Tries a failed (or unrecognized) word again.
    func retry(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].status = .queued
        generate()
    }

    /// Generates `word` in the item's place — a suggestion the learner picked, or a fix they typed.
    func replace(_ id: UUID, with word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].word = trimmed
        items[i].status = .queued
        generate()
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id && $0.status != .generating }
    }

    /// Stops what's in flight; what has landed stays, the rest reads as stopped and can be retried.
    func stop() {
        run?.cancel()
    }

    /// Waits for the current run to finish (tests).
    func settle() async {
        await run?.value
    }

    private func generate() {
        guard run == nil else { return }   // the running loop picks up what was just queued
        run = Task { [weak self] in await self?.runQueue() }
    }

    private func runQueue() async {
        isGenerating = true
        defer {
            isGenerating = false
            run = nil
        }
        while !Task.isCancelled {
            let pending = items.filter { $0.status == .queued }
            guard !pending.isEmpty else { return }
            var toGenerate: [Item] = []
            for item in pending {
                // A word already in the deck needs no request.
                if (try? repository.entry(lemma: item.word, language: language)) ?? nil != nil {
                    set(item.id, .alreadyInDeck)
                } else {
                    set(item.id, .generating)
                    toGenerate.append(item)
                }
            }
            guard !toGenerate.isEmpty else { continue }

            let provider: any LLMProvider
            do {
                provider = try await makeProvider()
            } catch {
                setupError = error.localizedDescription
                AppLog.shared.error("Generation failed: \(error.localizedDescription)", category: "ai")
                for item in toGenerate { set(item.id, .failed(message: error.localizedDescription)) }
                return
            }
            setupError = nil

            let apply: @Sendable (CardChunkResult) async -> Void = { [weak self] result in
                await self?.apply(result)
            }
            _ = await provider.generateCards(
                lemmas: toGenerate.map(\.word), language: language, literaryExamples: false,
                chunkSize: 1, concurrency: Self.concurrency, onChunk: apply)

            if Task.isCancelled {
                for item in items where item.status == .generating {
                    set(item.id, .failed(message: "Stopped before the card was written."))
                }
            }
        }
    }

    /// Records one request's result: the card goes into the deck, a verdict or a failure
    /// goes to the screen and the log.
    private func apply(_ result: CardChunkResult) {
        switch result {
        case .generated(let lemmas, let batch):
            let matches = GeneratedBatchMatcher.match(lemmas: lemmas, batch: batch)
            for lemma in lemmas {
                guard let i = items.firstIndex(where: { $0.word == lemma && $0.status == .generating }) else { continue }
                switch matches[lemma] {
                case .card(let card)?:
                    do {
                        let inserted = try repository.insertIfAbsent(AICardMapper.entry(from: card, language: language))
                        items[i].status = inserted ? .added(gloss: card.explanation) : .alreadyInDeck
                    } catch {
                        AppLog.shared.error("Couldn't save “\(lemma)”: \(error.localizedDescription)", category: "words")
                        items[i].status = .failed(message: "Couldn't save the card — \(error.localizedDescription)")
                    }
                case .unrecognized(let verdict)?:
                    AppLog.shared.warning("“\(lemma)” not recognized: \(verdict.reason)", category: "ai")
                    items[i].status = .unrecognized(reason: verdict.reason, suggestions: verdict.suggestions)
                case .missing?, nil:
                    AppLog.shared.error("No card came back for “\(lemma)”", category: "ai")
                    items[i].status = .failed(message: "The model wrote no card for this word.")
                }
            }
        case .failed(let lemmas, let message):
            AppLog.shared.error("Generation failed for \(lemmas.joined(separator: ", ")): \(message)", category: "ai")
            for lemma in lemmas {
                if let i = items.firstIndex(where: { $0.word == lemma && $0.status == .generating }) {
                    items[i].status = .failed(message: message)
                }
            }
        }
    }

    private func set(_ id: UUID, _ status: Status) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].status = status
    }
}
