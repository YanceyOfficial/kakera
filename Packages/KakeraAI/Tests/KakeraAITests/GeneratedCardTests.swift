import Foundation
import Testing
@testable import KakeraAI

@Test("A generated card batch decodes from the provider JSON contract")
func decodeCardBatch() throws {
    let json = """
    {"cards":[{"lemma":"eccentric","kind":"word","phonetic":"/ɪkˈsɛntrɪk/",
    "syllables":["ec","cen","tric"],"explanation":"adj. 古怪的，异乎寻常的",
    "explanationEn":"odd or unconventional in behaviour",
    "partsOfSpeech":["adjective","noun"],
    "examples":[{"sentence":"He is eccentric.","translation":"他很古怪。"}],
    "mnemonic":"ex-center：偏离中心","etymology":"源自希腊语 ekkentros",
    "roots":"ec-（出）+ centr（中心）+ -ic",
    "synonyms":[{"sense":"古怪的","words":["quirky","odd"]}],
    "collocations":[{"phrase":"an eccentric habit","meaning":"古怪的习惯",
    "example":"He has an eccentric habit.","exampleTranslation":"他有个古怪的习惯。"}],
    "confusables":["erratic"],
    "quizzes":[{"type":"singleChoice","question":"They are the ____ of this world.",
    "choices":["eccentrics","workers"],"answers":["eccentrics"],"translation":"..."}]}]}
    """.data(using: .utf8)!
    let batch = try JSONDecoder().decode(GeneratedCardBatch.self, from: json)
    #expect(batch.cards.count == 1)
    let card = batch.cards[0]
    #expect(card.lemma == "eccentric")
    #expect(card.kind == "word")
    #expect(card.explanation == "adj. 古怪的，异乎寻常的")
    #expect(card.explanationEn == "odd or unconventional in behaviour")
    #expect(card.examples.first?.translation == "他很古怪。")
    #expect(card.roots == "ec-（出）+ centr（中心）+ -ic")
    #expect(card.synonyms.first?.sense == "古怪的")
    #expect(card.synonyms.first?.words == ["quirky", "odd"])
    #expect(card.collocations.first?.phrase == "an eccentric habit")
    #expect(card.collocations.first?.exampleTranslation == "他有个古怪的习惯。")
    #expect(card.quizzes.first?.answers == ["eccentrics"])
}

@Test("Roots is optional — a card without it decodes with roots == nil")
func rootsOptional() throws {
    let json = """
    {"cards":[{"lemma":"x","kind":"word","phonetic":"","syllables":[],"explanation":"",
    "explanationEn":"","partsOfSpeech":[],"examples":[],"mnemonic":"","etymology":"",
    "synonyms":[],"collocations":[],"confusables":[],"quizzes":[]}]}
    """.data(using: .utf8)!
    let batch = try JSONDecoder().decode(GeneratedCardBatch.self, from: json)
    #expect(batch.cards[0].roots == nil)
}

@Test("A batch carries the items the model did not recognize, and none when the key is absent")
func unrecognizedDecodes() throws {
    let json = """
    {"cards":[],"unrecognized":[{"input":"serendipty","reason":"拼写有误","suggestions":["serendipity"]}]}
    """.data(using: .utf8)!
    let batch = try JSONDecoder().decode(GeneratedCardBatch.self, from: json)
    #expect(batch.unrecognized.count == 1)
    #expect(batch.unrecognized[0].input == "serendipty")
    #expect(batch.unrecognized[0].reason == "拼写有误")
    #expect(batch.unrecognized[0].suggestions == ["serendipity"])

    let bare = try JSONDecoder().decode(GeneratedCardBatch.self, from: Data(#"{"cards":[]}"#.utf8))
    #expect(bare.unrecognized.isEmpty)
}

@Test("A card with no meaning and no examples is blank — nothing a learner could study")
func blankCard() throws {
    func card(explanation: String, explanationEn: String = "", examples: String = "[]") throws -> GeneratedCard {
        let json = """
        {"cards":[{"lemma":"装飾","kind":"word","phonetic":"","syllables":[],"explanation":"\(explanation)",
        "explanationEn":"\(explanationEn)","partsOfSpeech":[],"examples":\(examples),"mnemonic":"","etymology":"",
        "roots":"","synonyms":[],"collocations":[],"confusables":[],"quizzes":[]}]}
        """
        return try JSONDecoder().decode(GeneratedCardBatch.self, from: Data(json.utf8)).cards[0]
    }
    #expect(try card(explanation: "").isBlank)
    #expect(try card(explanation: "  ").isBlank)
    #expect(!(try card(explanation: "[名] 装饰").isBlank))
    #expect(!(try card(explanation: "", explanationEn: "decoration").isBlank))
    #expect(!(try card(explanation: "", examples: #"[{"sentence":"部屋を装飾する。","translation":"装饰房间。"}]"#).isBlank))
}
