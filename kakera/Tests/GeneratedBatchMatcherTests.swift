import Testing
import Foundation
@testable import Kakera
import KakeraAI

@Suite("GeneratedBatchMatcher")
struct GeneratedBatchMatcherTests {
    private func card(_ lemma: String) throws -> GeneratedCard {
        let json = """
        {"lemma":"\(lemma)","kind":"word","phonetic":"","syllables":[],"explanation":"","explanationEn":"",
        "partsOfSpeech":[],"examples":[],"mnemonic":"","etymology":"","synonyms":[],"collocations":[],
        "confusables":[],"quizzes":[]}
        """
        return try JSONDecoder().decode(GeneratedCard.self, from: Data(json.utf8))
    }

    @Test("A card pairs with its word whatever the case, width or a leading tilde")
    func pairsLooseSpellings() throws {
        let batch = GeneratedCardBatch(cards: [try card("によると"), try card("Police Car")])
        let matches = GeneratedBatchMatcher.match(lemmas: ["〜によると", "police car"], batch: batch)
        #expect(matches["〜によると"] == .card(batch.cards[0]))
        #expect(matches["police car"] == .card(batch.cards[1]))
    }

    @Test("A card the model annotated with ruby still pairs with the plain word")
    func pairsThroughRuby() throws {
        let batch = GeneratedCardBatch(cards: [try card("{化粧|けしょう}")])
        #expect(GeneratedBatchMatcher.match(lemmas: ["化粧"], batch: batch)["化粧"] == .card(batch.cards[0]))
    }

    @Test("An unrecognized item pairs by its input, and a word with neither card nor verdict is missing")
    func unrecognizedAndMissing() throws {
        let verdict = UnrecognizedWord(input: "Serendipty", reason: "拼写有误", suggestions: ["serendipity"])
        let batch = GeneratedCardBatch(cards: [try card("alpha")], unrecognized: [verdict])
        let matches = GeneratedBatchMatcher.match(lemmas: ["alpha", "serendipty", "beta"], batch: batch)
        #expect(matches["alpha"] == .card(batch.cards[0]))
        #expect(matches["serendipty"] == .unrecognized(verdict))
        #expect(matches["beta"] == .missing)
    }

    @Test("A lone leftover card goes to the lone leftover word, even spelled differently")
    func lonePairing() throws {
        let batch = GeneratedCardBatch(cards: [try card("alpha"), try card("color")])
        let matches = GeneratedBatchMatcher.match(lemmas: ["alpha", "colour"], batch: batch)
        #expect(matches["colour"] == .card(batch.cards[1]))
    }

    @Test("Two leftover words and one leftover card: neither is guessed")
    func noGuessingAmongSeveral() throws {
        let batch = GeneratedCardBatch(cards: [try card("color")])
        let matches = GeneratedBatchMatcher.match(lemmas: ["colour", "grey"], batch: batch)
        #expect(matches["colour"] == .missing)
        #expect(matches["grey"] == .missing)
    }
}
