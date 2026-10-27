import Testing
import Foundation
import SwiftData
@testable import Kakera
import KakeraCore

@MainActor
@Suite(.serialized)
struct StarterSeedTests {
    @Test("Every English starter word is split into syllables that spell it")
    func starterSyllablesSpellTheWord() {
        for entry in StarterSeed.entries(for: .english) {
            #expect(entry.syllables.count >= 2, "\(entry.lemma) has no syllables")
            #expect(entry.syllables.joined() == entry.lemma, "\(entry.lemma)'s syllables spell \(entry.syllables.joined())")
        }
    }

    @Test("The demo deck can ask a starter word as tiles with distractor pieces")
    func demoDeckOffersTiles() throws {
        let context = ModelContext(try KakeraModelContainer.scratch())
        let repository = VocabularyRepository(context: context)
        try DemoDeck.seedIfEmpty(repository)
        let all = try repository.entries(for: .english)
        for entry in all where !entry.syllables.isEmpty {
            #expect(entry.syllables.joined() == entry.lemma, "\(entry.lemma)'s syllables spell \(entry.syllables.joined())")
        }

        let eccentric = try #require(all.first { $0.lemma == "eccentric" })
        var rng = SystemRandomNumberGenerator()
        let generator = QuizGenerator()
        let tiles = try #require(
            generator.candidates(for: eccentric, pool: all, using: &rng).first { $0.type == .splitCombine })
        #expect(tiles.mode == .tiles)
        #expect(tiles.choices.count == eccentric.syllables.count + generator.extraTiles)
    }
}
