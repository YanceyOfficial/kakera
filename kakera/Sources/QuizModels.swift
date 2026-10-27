import Foundation
import KakeraCore
import KakeraServices
import KakeraUI

/// A learner's response to a quiz question.
enum QuizResponse {
    case choice(Int)
    case text(String)
}

/// A quiz question shown in a session.
struct QuizQuestion: Identifiable {
    /// How the learner answers: tap one of the choices, type the answer, or tap tiles in
    /// order to assemble it.
    enum Mode {
        case choice, text, tiles
    }

    /// The backing entry's id (one question per reviewed word; also resets the view).
    let id: UUID
    let type: QuizType
    let word: String
    let phonetic: String
    /// The prompt under the word: a sentence (with the word blanked, for a cloze), or the
    /// meaning when that is what the learner answers from (see `promptsWithMeaning`).
    let question: String
    /// The options to pick from; for tiles, the bank of fragments; empty when the answer is typed.
    let choices: [String]
    let answers: [String]
    let translation: String

    var mode: Mode {
        if type == .splitCombine { return .tiles }
        return choices.isEmpty ? .text : .choice
    }
    /// The learner types the answer (fill-in-blank, listening, spelling).
    var isTextEntry: Bool { mode == .text }
    /// The meaning is the prompt and the word is the answer: picked among other words,
    /// typed, or assembled from tiles.
    var promptsWithMeaning: Bool {
        switch type {
        case .wordChoice, .spelling, .splitCombine: true
        case .singleChoice, .fillInBlank, .listeningSpelling, .meaningMatch, .contextCloze: false
        }
    }
    /// True when the word itself is the answer, so the prompt hides it until answered;
    /// false when the meaning is the answer (single choice, meaning match).
    var hidesWord: Bool {
        switch type {
        case .singleChoice, .meaningMatch: false
        case .splitCombine, .fillInBlank, .listeningSpelling, .contextCloze, .wordChoice, .spelling: true
        }
    }
    /// Listening-spelling plays the pronunciation as the prompt.
    var playsAudio: Bool { type == .listeningSpelling }

    func isCorrect(choiceIndex: Int) -> Bool {
        choices.indices.contains(choiceIndex) && answers.contains(choices[choiceIndex])
    }

    func isCorrect(text: String) -> Bool {
        let norm = Self.normalize(text)
        return answers.contains { Self.normalize($0) == norm }
    }

    /// Case-insensitive, and for Japanese kana-insensitive: a reading typed in katakana
    /// matches one given in hiragana. Ruby markup in an answer is read as its plain text.
    static func normalize(_ s: String) -> String {
        let plain = Ruby.plain(s).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return plain.applyingTransform(.hiraganaToKatakana, reverse: true) ?? plain
    }
}

/// Blanks a word out of an example sentence for a cloze question.
enum QuizCloze {
    static let blank = "____"

    /// The sentence with `term` replaced by a blank, or nil when the sentence doesn't
    /// contain it — as a whole word in English (so "eccentricity" doesn't hide
    /// "eccentric"), anywhere in Japanese — or the match would cut a furigana base in two
    /// (気 inside `{天気|てんき}`). The rest of the sentence keeps its ruby markup.
    static func blank(_ term: String, in markup: String, language: LanguageDomain) -> String? {
        let segments = Ruby.parse(markup)
        // The plain text, with the segment each character came from, and where each segment spans.
        var plain: [Character] = []
        var spans: [Range<Int>] = []
        for segment in segments {
            let base = switch segment {
            case .text(let text): text
            case .ruby(let base, _): base
            }
            spans.append(plain.count ..< plain.count + base.count)
            plain += base
        }
        guard let match = match(Array(term), in: plain, language: language, spans: spans, segments: segments)
        else { return nil }

        var out = ""
        var blanked = false
        for (segment, span) in zip(segments, spans) {
            guard span.overlaps(match) else {
                out += serialize(segment)
                continue
            }
            switch segment {
            case .ruby:   // wholly inside the match (see `match`)
                break
            case .text(let text):
                let characters = Array(text)
                out += String(characters[0 ..< max(0, match.lowerBound - span.lowerBound)])
            }
            if !blanked { out += blank; blanked = true }
            if case .text(let text) = segment {
                let characters = Array(text)
                out += String(characters[min(characters.count, match.upperBound - span.lowerBound)...])
            }
        }
        return out
    }

    /// The first occurrence of `term` that stands as a word (English) and covers every
    /// ruby base it touches whole.
    private static func match(
        _ term: [Character], in plain: [Character], language: LanguageDomain,
        spans: [Range<Int>], segments: [Ruby.Segment]
    ) -> Range<Int>? {
        guard !term.isEmpty, term.count <= plain.count else { return nil }
        let needle = String(term).lowercased()
        for start in 0 ... (plain.count - term.count) {
            let range = start ..< start + term.count
            guard String(plain[range]).lowercased() == needle else { continue }
            if language == .english {
                let before = start > 0 ? plain[start - 1] : nil
                let after = range.upperBound < plain.count ? plain[range.upperBound] : nil
                guard !(before.map(isWordCharacter) ?? false), !(after.map(isWordCharacter) ?? false) else { continue }
            }
            let cutsRuby = zip(segments, spans).contains { segment, span in
                guard case .ruby = segment, span.overlaps(range) else { return false }
                return span.lowerBound < range.lowerBound || span.upperBound > range.upperBound
            }
            if !cutsRuby { return range }
        }
        return nil
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }

    private static func serialize(_ segment: Ruby.Segment) -> String {
        switch segment {
        case .text(let text): text
        case .ruby(let base, let reading): "{\(base)|\(reading)}"
        }
    }
}

/// Builds the questions a word can be asked as: its AI-written quizzes, and the ones built
/// here from the card itself — the meaning picked among the deck's (single choice), the
/// word picked by its meaning (word choice), the word spelled from its meaning, assembled
/// from its syllables (tiles), blanked out of an example sentence (cloze), or heard and
/// spelled (listening). Pure/deterministic given an RNG.
struct QuizGenerator {
    var optionCount = 4
    /// How many fragments from other words join a word's own in the tile bank.
    var extraTiles = 2

    /// Types not rendered yet.
    private static let unsupported: Set<QuizType> = [.splitCombine]
    /// Types answered by typing rather than tapping.
    private static let textTypes: Set<QuizType> = [.fillInBlank, .listeningSpelling, .spelling]

    /// One question for the word, picked among `candidates(for:pool:using:)`.
    func makeQuestion<G: RandomNumberGenerator>(
        for target: VocabularyEntry, pool: [VocabularyEntry], using rng: inout G
    ) -> QuizQuestion? {
        candidates(for: target, pool: pool, using: &rng).randomElement(using: &rng)
    }

    /// Every question that can be asked about the word. Nothing about a word without a meaning.
    func candidates<G: RandomNumberGenerator>(
        for target: VocabularyEntry, pool: [VocabularyEntry], using rng: inout G
    ) -> [QuizQuestion] {
        guard !meaning(of: target).isEmpty else { return [] }
        let others = pool.filter { $0.id != target.id }
        var questions = aiQuestions(for: target)
        questions += [
            meaningQuestion(for: target, others: others, using: &rng),
            wordChoiceQuestion(for: target, others: others, using: &rng),
            spellingQuestion(for: target),
            tilesQuestion(for: target, others: others, using: &rng),
            clozeQuestion(for: target, others: others, using: &rng),
            listeningQuestion(for: target),
        ].compactMap { $0 }
        return questions
    }

    func makeQuiz<G: RandomNumberGenerator>(
        due: [VocabularyEntry], pool: [VocabularyEntry], using rng: inout G
    ) -> [QuizQuestion] {
        due.compactMap { makeQuestion(for: $0, pool: pool, using: &rng) }
    }

    // MARK: AI-written

    /// The entry's usable AI-generated quizzes.
    private func aiQuestions(for target: VocabularyEntry) -> [QuizQuestion] {
        target.quizzes.compactMap { quiz in
            guard !Self.unsupported.contains(quiz.type), !quiz.answers.isEmpty else { return nil }
            let typed = Self.textTypes.contains(quiz.type)
            // Choice types need options that include a correct answer.
            guard typed || quiz.choices.contains(where: { quiz.answers.contains($0) }) else { return nil }
            return QuizQuestion(
                id: target.id, type: quiz.type, word: target.lemma, phonetic: target.phonetic,
                question: quiz.question, choices: typed ? [] : quiz.choices, answers: quiz.answers,
                translation: quiz.translation)
        }
    }

    // MARK: Built from the card

    /// The classic: pick the correct meaning among the other words' meanings.
    private func meaningQuestion<G: RandomNumberGenerator>(
        for target: VocabularyEntry, others: [VocabularyEntry], using rng: inout G
    ) -> QuizQuestion? {
        guard let options = options(correct: meaning(of: target), among: others.map(\.explanation), using: &rng)
        else { return nil }
        return QuizQuestion(
            id: target.id, type: .singleChoice, word: target.lemma, phonetic: target.phonetic,
            question: "", choices: options, answers: [meaning(of: target)], translation: "")
    }

    /// The reverse: given the meaning, pick the word among the other words.
    private func wordChoiceQuestion<G: RandomNumberGenerator>(
        for target: VocabularyEntry, others: [VocabularyEntry], using rng: inout G
    ) -> QuizQuestion? {
        guard let options = options(correct: target.lemma, among: others.map(\.lemma), using: &rng)
        else { return nil }
        return QuizQuestion(
            id: target.id, type: .wordChoice, word: target.lemma, phonetic: target.phonetic,
            question: meaning(of: target), choices: options, answers: [target.lemma], translation: "")
    }

    /// Given the meaning, type the word.
    private func spellingQuestion(for target: VocabularyEntry) -> QuizQuestion {
        QuizQuestion(
            id: target.id, type: .spelling, word: target.lemma, phonetic: target.phonetic,
            question: meaning(of: target), choices: [], answers: spellings(of: target), translation: "")
    }

    /// Given the meaning, assemble the word from its syllables (its morae, in Japanese)
    /// shuffled in with a couple from other words. English tiles must spell the word.
    private func tilesQuestion<G: RandomNumberGenerator>(
        for target: VocabularyEntry, others: [VocabularyEntry], using rng: inout G
    ) -> QuizQuestion? {
        let tiles = target.syllables.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard target.kind == .word, tiles.count >= 2 else { return nil }
        let spelled = tiles.joined()
        let answer: String
        if target.language == .japanese {
            answer = spelled
        } else {
            guard spelled.lowercased() == target.lemma.lowercased() else { return nil }
            answer = target.lemma
        }

        let own = Set(tiles.map { $0.lowercased() })
        var seen: Set<String> = []
        var extras = others.flatMap(\.syllables)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !own.contains($0.lowercased()) && seen.insert($0.lowercased()).inserted }
        extras.shuffle(using: &rng)
        var bank = tiles + extras.prefix(extraTiles)
        bank.shuffle(using: &rng)
        return QuizQuestion(
            id: target.id, type: .splitCombine, word: target.lemma, phonetic: target.phonetic,
            question: meaning(of: target), choices: bank, answers: [answer], translation: "")
    }

    /// One of the word's example sentences with the word blanked; pick it among the other words.
    private func clozeQuestion<G: RandomNumberGenerator>(
        for target: VocabularyEntry, others: [VocabularyEntry], using rng: inout G
    ) -> QuizQuestion? {
        for example in target.examples.shuffled(using: &rng) {
            guard let blanked = QuizCloze.blank(target.lemma, in: example.sentence, language: target.language)
            else { continue }
            guard let options = options(correct: target.lemma, among: others.map(\.lemma), using: &rng)
            else { return nil }
            return QuizQuestion(
                id: target.id, type: .contextCloze, word: target.lemma, phonetic: target.phonetic,
                question: blanked, choices: options, answers: [target.lemma], translation: example.translation)
        }
        return nil
    }

    /// Hear the word, spell it. Words only: a phrase has no pronunciation of its own.
    private func listeningQuestion(for target: VocabularyEntry) -> QuizQuestion? {
        guard target.kind == .word else { return nil }
        return QuizQuestion(
            id: target.id, type: .listeningSpelling, word: target.lemma, phonetic: target.phonetic,
            question: "", choices: [], answers: spellings(of: target), translation: "")
    }

    // MARK: Helpers

    private func meaning(of entry: VocabularyEntry) -> String {
        entry.explanation.trimmingCharacters(in: .whitespaces)
    }

    /// The word as written and, for Japanese, its kana reading too (either spelling counts).
    private func spellings(of entry: VocabularyEntry) -> [String] {
        var answers = [entry.lemma]
        if entry.language == .japanese {
            let reading = JapaneseSpeech.text(word: entry.lemma, phonetic: entry.phonetic)
            if reading != entry.lemma { answers.append(reading) }
        }
        return answers
    }

    /// `correct` mixed in with up to `optionCount - 1` distinct, non-empty distractors from
    /// `others`, shuffled; nil when there is no distractor at all.
    private func options<G: RandomNumberGenerator>(
        correct: String, among others: [String], using rng: inout G
    ) -> [String]? {
        var seen: Set<String> = [correct.lowercased()]
        var distractors: [String] = []
        for other in others {
            let value = other.trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty, seen.insert(value.lowercased()).inserted else { continue }
            distractors.append(value)
        }
        guard !distractors.isEmpty else { return nil }

        distractors.shuffle(using: &rng)
        var options = Array(distractors.prefix(optionCount - 1))
        options.append(correct)
        options.shuffle(using: &rng)
        return options
    }
}
