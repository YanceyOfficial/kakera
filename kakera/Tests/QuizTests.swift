import Testing
import Foundation
import SwiftData
@testable import Kakera
import KakeraCore

/// A small deterministic RNG so shuffles are reproducible in tests.
private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private func word(
    _ lemma: String, _ meaning: String, kind: EntryKind = .word, language: LanguageDomain = .english,
    phonetic: String = "", syllables: [String] = [], examples: [Example] = [], quizzes: [Quiz] = []
) -> VocabularyEntry {
    VocabularyEntry(
        lemma: lemma, kind: kind, language: language, phonetic: phonetic, syllables: syllables,
        explanation: meaning, examples: examples, quizzes: quizzes)
}

/// The response that answers `question` right, whatever its mode.
private func rightResponse(_ question: QuizQuestion) -> QuizResponse {
    switch question.mode {
    case .choice: .choice(question.choices.firstIndex { question.answers.contains($0) }!)
    case .text, .tiles: .text(question.answers[0])
    }
}

/// A response that answers `question` wrong, whatever its mode.
private func wrongResponse(_ question: QuizQuestion) -> QuizResponse {
    switch question.mode {
    case .choice: .choice(question.choices.firstIndex { !question.answers.contains($0) }!)
    case .text, .tiles: .text("not it")
    }
}

@Suite("QuizGenerator")
struct QuizGeneratorTests {
    private let gen = QuizGenerator()

    private let pool = [
        word("eccentric", "古怪的", syllables: ["ec", "cen", "tric"],
             examples: [Example(sentence: "She is an eccentric old lady.", translation: "她是个古怪的老太太。")]),
        word("obsession", "痴迷", syllables: ["ob", "ses", "sion"]),
        word("meticulous", "细致的", syllables: ["me", "tic", "u", "lous"]),
        word("brisk", "轻快的", syllables: ["brisk"]),
    ]

    private func candidate(_ type: QuizType, for target: VocabularyEntry, pool: [VocabularyEntry], seed: UInt64 = 42) -> QuizQuestion? {
        var rng = SeededRNG(seed: seed)
        return gen.candidates(for: target, pool: pool, using: &rng).first { $0.type == type }
    }

    @Test("Single-choice meaning: the word is the prompt, its meaning is picked among the deck's")
    func meaningQuestion() throws {
        let question = try #require(candidate(.singleChoice, for: pool[0], pool: pool))
        #expect(question.mode == .choice)
        #expect(question.choices.count == 4)
        #expect(question.answers == ["古怪的"])
        #expect(question.word == "eccentric")
        #expect(!question.hidesWord)
        let correct = try #require(question.choices.firstIndex { question.answers.contains($0) })
        #expect(question.isCorrect(choiceIndex: correct))
    }

    @Test("Option count shrinks when there are few distractors")
    func fewDistractors() throws {
        let question = try #require(candidate(.singleChoice, for: pool[0], pool: Array(pool.prefix(2))))
        #expect(question.choices.count == 2)
        #expect(question.choices.contains("古怪的"))
        #expect(question.choices.contains("痴迷"))
    }

    @Test("Word choice: the meaning is the prompt and the word is picked among the deck's words")
    func wordChoice() throws {
        let question = try #require(candidate(.wordChoice, for: pool[0], pool: pool))
        #expect(question.mode == .choice)
        #expect(question.promptsWithMeaning)
        #expect(question.hidesWord)
        #expect(question.question == "古怪的")
        #expect(Set(question.choices) == ["eccentric", "obsession", "meticulous", "brisk"])
        #expect(question.answers == ["eccentric"])
    }

    @Test("Spelling: the meaning is the prompt and the word is typed")
    func spelling() throws {
        let question = try #require(candidate(.spelling, for: pool[0], pool: pool))
        #expect(question.mode == .text)
        #expect(question.isTextEntry)
        #expect(question.promptsWithMeaning)
        #expect(question.question == "古怪的")
        #expect(question.isCorrect(text: " Eccentric"))
        #expect(!question.isCorrect(text: "eccentricity"))
    }

    @Test("A Japanese word is spelled in kana or as written")
    func japaneseSpelling() throws {
        let natsukashii = word("懐かしい", "[形] 令人怀念的", language: .japanese, phonetic: "なつかしい ④")
        let question = try #require(candidate(.spelling, for: natsukashii, pool: [natsukashii]))
        #expect(question.isCorrect(text: "ナツカシイ"))
        #expect(question.isCorrect(text: "懐かしい"))
        #expect(!question.isCorrect(text: "なつかし"))
    }

    @Test("Tiles: the word's syllables, with a couple from other words, spell it when tapped in order")
    func tiles() throws {
        let question = try #require(candidate(.splitCombine, for: pool[0], pool: pool))
        #expect(question.mode == .tiles)
        #expect(question.promptsWithMeaning)
        #expect(question.hidesWord)
        for syllable in ["ec", "cen", "tric"] { #expect(question.choices.contains(syllable)) }
        let extras = question.choices.filter { !["ec", "cen", "tric"].contains($0) }
        #expect(extras.count == 2)
        let others = Set(pool.dropFirst().flatMap(\.syllables))
        #expect(extras.allSatisfy { others.contains($0) })
        #expect(question.choices.count == 5)
        #expect(question.isCorrect(text: "eccentric"))
        #expect(!question.isCorrect(text: "ecceneric"))
    }

    @Test("Tiles need at least two syllables that spell the word")
    func tilesNeedSyllables() {
        let dashed = word("eccentric", "古怪的", syllables: ["ec-", "cen-", "tric"])
        #expect(candidate(.splitCombine, for: dashed, pool: pool) == nil)
        #expect(candidate(.splitCombine, for: pool[3], pool: pool) == nil)   // "brisk": one tile
    }

    @Test("Japanese tiles are the morae, spelling the reading")
    func japaneseTiles() throws {
        let natsukashii = word("懐かしい", "[形] 令人怀念的", language: .japanese, phonetic: "なつかしい ④",
                               syllables: ["な", "つ", "か", "し", "い"])
        let komorebi = word("木漏れ日", "[名] 树隙阳光", language: .japanese, phonetic: "こもれび",
                            syllables: ["こ", "も", "れ", "び"])
        let question = try #require(candidate(.splitCombine, for: natsukashii, pool: [natsukashii, komorebi]))
        #expect(question.isCorrect(text: "なつかしい"))
        #expect(question.choices.count == 7)
    }

    @Test("Cloze: an example sentence with the word blanked, the word picked among the deck's")
    func cloze() throws {
        let question = try #require(candidate(.contextCloze, for: pool[0], pool: pool))
        #expect(question.mode == .choice)
        #expect(question.hidesWord)
        #expect(!question.promptsWithMeaning)
        #expect(question.question == "She is an ____ old lady.")
        #expect(question.translation == "她是个古怪的老太太。")
        #expect(question.choices.contains("eccentric"))
        #expect(question.choices.count == 4)
        #expect(question.answers == ["eccentric"])
    }

    @Test("Cloze skips an example that doesn't contain the word as a word")
    func clozeNeedsTheWord() {
        let derived = word("eccentric", "古怪的",
                           examples: [Example(sentence: "Her eccentricity is charming.", translation: "")])
        #expect(candidate(.contextCloze, for: derived, pool: pool) == nil)
    }

    @Test("Listening: a word is heard and spelled; a phrase is not")
    func listening() throws {
        let question = try #require(candidate(.listeningSpelling, for: pool[0], pool: pool))
        #expect(question.mode == .text)
        #expect(question.playsAudio)
        #expect(question.hidesWord)
        #expect(question.isCorrect(text: "eccentric"))
        let phrase = word("give up", "放弃", kind: .phrase)
        #expect(candidate(.listeningSpelling, for: phrase, pool: [phrase]) == nil)
    }

    @Test("Nothing is asked about a word without a meaning")
    func returnsNil() {
        var rng = SeededRNG(seed: 1)
        let blank = word("blank", "", syllables: ["bl", "ank"],
                         examples: [Example(sentence: "A blank page.", translation: "")])
        #expect(gen.makeQuestion(for: blank, pool: pool, using: &rng) == nil)
    }

    @Test("A word alone in the deck is still spelled or heard, never chosen among others")
    func lonelyWord() {
        var rng = SeededRNG(seed: 1)
        let lonely = word("alone", "孤单")
        let types = Set(gen.candidates(for: lonely, pool: [lonely], using: &rng).map(\.type))
        #expect(types == [.spelling, .listeningSpelling])
    }

    @Test("An AI quiz is among the candidates, as a text-entry question hiding the word")
    func aiQuiz() throws {
        let e = word("use", "v. 使用", quizzes: [
            Quiz(type: .fillInBlank, question: "Make ____ of it.", choices: [], answers: ["use"]),
        ])
        let q = try #require(candidate(.fillInBlank, for: e, pool: [e]))
        #expect(q.isTextEntry)
        #expect(q.hidesWord)
        #expect(q.isCorrect(text: "  USE ") == true)    // case/whitespace-insensitive
        #expect(q.isCorrect(text: "used") == false)
    }

    @Test("An unusable AI quiz is left out")
    func skipsBadAIQuiz() {
        // A choice quiz whose choices don't contain the answer is unusable.
        let e = word("eccentric", "古怪的", quizzes: [
            Quiz(type: .meaningMatch, question: "?", choices: ["a", "b"], answers: ["c"]),
        ])
        #expect(candidate(.meaningMatch, for: e, pool: pool) == nil)
    }

    @Test("A question is one of the candidates")
    func picksACandidate() {
        var rng = SeededRNG(seed: 9)
        let question = gen.makeQuestion(for: pool[0], pool: pool, using: &rng)
        var again = SeededRNG(seed: 9)
        let candidates = gen.candidates(for: pool[0], pool: pool, using: &again)
        #expect(candidates.contains { $0.type == question?.type && $0.question == question?.question })
    }
}

@Suite("Cloze")
struct ClozeTests {
    @Test("Blanks the word as a whole word, whatever its case")
    func english() {
        #expect(QuizCloze.blank("eccentric", in: "Eccentric people amuse me.", language: .english) == "____ people amuse me.")
        #expect(QuizCloze.blank("eccentric", in: "Her eccentricity is charming.", language: .english) == nil)
        #expect(QuizCloze.blank("give up", in: "Never give up!", language: .english) == "Never ____!")
    }

    @Test("Keeps the rest of a Japanese sentence's furigana, and won't cut a reading in two")
    func japanese() {
        #expect(QuizCloze.blank("懐かしい", in: "{懐|なつ}かしい{歌|うた}だ。", language: .japanese) == "____{歌|うた}だ。")
        #expect(QuizCloze.blank("気", in: "{天気|てんき}がいい。", language: .japanese) == nil)
        #expect(QuizCloze.blank("木漏れ日", in: "{木漏|こも}れ{日|び}が{綺麗|きれい}だ。", language: .japanese) == "____が{綺麗|きれい}だ。")
    }
}

@MainActor
@Suite(.serialized)
struct QuizStoreTests {
    private func makeSeededStore() throws -> (QuizStore, VocabularyRepository) {
        let context = ModelContext(try KakeraModelContainer.scratch())
        let repository = VocabularyRepository(context: context)
        try StarterSeed.seedIfEmpty(repository)
        return (QuizStore(context: context, language: .english), repository)
    }

    @Test("Builds a question per seeded word")
    func loadsQuestions() throws {
        let (store, _) = try makeSeededStore()
        store.load()
        #expect(store.questions.count == 3)
    }

    @Test("load(entryIDs:) builds questions only for the given words")
    func loadForSpecificIDs() throws {
        let (store, repo) = try makeSeededStore()
        let target = try #require(repo.entries(for: .english).first)
        store.load(entryIDs: [target.id])
        #expect(store.questions.count == 1)
        #expect(store.questions.first?.id == target.id)
    }

    @Test("A correct answer is a no-op — the review already graded it")
    func correctAnswerIsNoOp() throws {
        let (store, repo) = try makeSeededStore()
        store.load()
        let question = try #require(store.questions.first)

        #expect(store.submit(question, rightResponse(question)) == true)
        #expect(try repo.reviewLogs(entryID: question.id).isEmpty)
    }

    @Test("A wrong answer re-grades a graduated word as again (the double-check catch)")
    func wrongAnswerGradesAgain() throws {
        let (store, repo) = try makeSeededStore()
        store.load()
        let question = try #require(store.questions.first)
        let entry = try #require(repo.entries(for: .english).first { $0.id == question.id })
        entry.reschedule(SchedulingState(
            stability: 10, difficulty: 5, due: Date(), lastReview: Date(),
            reps: 3, lapses: 0, state: .review))

        #expect(store.submit(question, wrongResponse(question)) == false)

        #expect(entry.scheduling.lapses == 1)
        let log = try #require(try repo.reviewLogs(entryID: question.id).first)
        #expect(log.rating == .again)
        #expect(log.quizType == question.type)
    }
}

@Test("A typed reading matches in hiragana or katakana, and ruby answers read as plain")
func japaneseAnswerNormalization() {
    #expect(QuizQuestion.normalize("ナツカシイ") == QuizQuestion.normalize("なつかしい"))
    #expect(QuizQuestion.normalize(" なつかしい ") == "なつかしい")
    #expect(QuizQuestion.normalize("{懐|なつ}かしい") == "懐かしい")
    #expect(QuizQuestion.normalize("USE") == "use")
}
