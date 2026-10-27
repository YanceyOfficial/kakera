import Foundation
import KakeraCore

/// One chunk of a batch, as it finishes: what the model wrote for its words, or why it failed.
public enum CardChunkResult: Sendable {
    case generated(lemmas: [String], batch: GeneratedCardBatch)
    /// `message` is the error's localized description.
    case failed(lemmas: [String], message: String)

    /// The words the chunk was asked for.
    public var lemmas: [String] {
        switch self {
        case .generated(let lemmas, _), .failed(let lemmas, _): lemmas
        }
    }
}

/// A chunk that failed: which words it carried, and what went wrong (so the log and the
/// screen can say which words to try again, not just how many).
public struct ChunkFailure: Sendable, Equatable {
    public let lemmas: [String]
    public let message: String
}

/// The result of a chunked batch generation: the cards that were produced, the items the
/// model did not recognize, and a record of each chunk that failed (so callers can report
/// partial success).
public struct BatchGenerationOutcome: Sendable {
    public let cards: [GeneratedCard]
    public let unrecognized: [UnrecognizedWord]
    public let failures: [ChunkFailure]

    public var hasFailures: Bool { !failures.isEmpty }
}

public extension LLMProvider {
    /// Generates cards for many lemmas by splitting them into chunks of at most
    /// `chunkSize`, so a single request can't exceed the model's output budget — or, at a
    /// chunk size of 1, so each word is its own request: the shortest request there is,
    /// and one that fails or succeeds on its own.
    ///
    /// Up to `concurrency` chunks are in flight at once — a card takes the model tens of
    /// seconds to write, so a batch done one chunk after another took minutes — and
    /// best-effort: a chunk that fails is recorded in `failures` and does not abort the
    /// others, so the user keeps the words that did generate. Card order follows the
    /// input order, whatever order the chunks finish in. `onChunk` hears each chunk as it
    /// finishes, in finishing order, so a screen can show words landing one by one.
    func generateCards(
        lemmas: [String],
        language: LanguageDomain,
        literaryExamples: Bool,
        chunkSize: Int,
        concurrency: Int = 4,
        onChunk: (@Sendable (CardChunkResult) async -> Void)? = nil
    ) async -> BatchGenerationOutcome {
        let size = max(1, chunkSize)
        let chunks = stride(from: 0, to: lemmas.count, by: size).map {
            Array(lemmas[$0 ..< min($0 + size, lemmas.count)])
        }
        var results = [CardChunkResult?](repeating: nil, count: chunks.count)

        await withTaskGroup(of: (Int, CardChunkResult).self) { group in
            var next = 0
            func startNext() {
                guard next < chunks.count else { return }
                let index = next
                next += 1
                group.addTask {
                    do {
                        let batch = try await generateCards(
                            lemmas: chunks[index], language: language, literaryExamples: literaryExamples)
                        return (index, .generated(lemmas: chunks[index], batch: batch))
                    } catch {
                        return (index, .failed(lemmas: chunks[index], message: error.localizedDescription))
                    }
                }
            }
            for _ in 0 ..< max(1, concurrency) { startNext() }
            for await (index, result) in group {
                results[index] = result
                await onChunk?(result)
                startNext()
            }
        }

        var cards: [GeneratedCard] = []
        var unrecognized: [UnrecognizedWord] = []
        var failures: [ChunkFailure] = []
        for result in results {
            switch result {
            case .generated(_, let batch):
                cards.append(contentsOf: batch.cards)
                unrecognized.append(contentsOf: batch.unrecognized)
            case .failed(let lemmas, let message):
                failures.append(ChunkFailure(lemmas: lemmas, message: message))
            case nil:
                break
            }
        }
        return BatchGenerationOutcome(cards: cards, unrecognized: unrecognized, failures: failures)
    }
}
