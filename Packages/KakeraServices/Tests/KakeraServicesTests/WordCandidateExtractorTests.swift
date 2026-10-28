import Testing
@testable import KakeraServices

@Suite("WordCandidateExtractor")
struct WordCandidateExtractorTests {
    @Test("Strips punctuation, drops non-alpha and short tokens, dedupes case-insensitively")
    func candidateFiltering() {
        let extractor = WordCandidateExtractor(minLength: 2)
        let lines = ["Pure eccentric, obsessive genius.", "genius 42 a", "Eccentric!"]
        #expect(extractor.candidates(from: lines) == ["pure", "eccentric", "obsessive", "genius"])
    }

    @Test("Function words are left out: a scanned page is its vocabulary, not its grammar")
    func stopWords() {
        let extractor = WordCandidateExtractor()
        let lines = ["The lighthouse at the end of the pier was an obsession, and it is not ephemeral."]
        #expect(extractor.candidates(from: lines) == ["lighthouse", "end", "pier", "obsession", "ephemeral"])
    }

    @Test("Empty and whitespace-only input yields no candidates")
    func emptyInput() {
        let extractor = WordCandidateExtractor()
        #expect(extractor.candidates(from: ["", "   ", "!!!"]).isEmpty)
    }

    @Test("Japanese text is split into words; particles, auxiliaries and punctuation are left out")
    func japanese() {
        let extractor = WordCandidateExtractor()
        let lines = ["懐かしい歌を聴いた。", "木漏れ日がきれいだ。コーヒーを飲みます", "懐かしい"]
        #expect(extractor.candidates(from: lines, language: .japanese)
                == ["懐かしい", "歌", "聴い", "木漏れ日", "きれい", "コーヒー", "飲み"])
    }

    @Test("A textbook word list keeps whole words: the kanji form, the dictionary form, no ruby lines or labels")
    func japaneseWordList() {
        // Vision's lines for a page of a Japanese textbook's vocabulary (a phone photo, ISSUE-5).
        let lines = [
            "いがくぶ（医学部）③", "めざ", "目指します（←目指す②）", "進みます（←進む•）",
            "iPSさいぼう（iPS細胞）⑦", "かいはつ", "開発します（←開発する•）", "マウス（mouse）", "①",
            "ヒト（人）0", "〈名〉", "〈動 I>", "〈動I〉", "〈名〉", "〈動亚", "〈名〉", "〈名〉",
            "ノーベルしょう（Nobel賞）④〈名〉", "しゅしょう", "受賞します（←受賞する◎）", "〈動］",
            "こうえんかい（講演会）③", "〈名",
        ]
        #expect(WordCandidateExtractor().candidates(from: lines, language: .japanese)
                == ["医学部", "目指す", "進む", "iPS細胞", "開発する", "マウス", "ヒト", "Nobel賞", "受賞する", "講演会"])
    }

    @Test("A compound in running Japanese text stays whole")
    func japaneseCompoundInSentence() {
        #expect(WordCandidateExtractor().candidates(from: ["医学部の講演会に行った"], language: .japanese)
                .prefix(2) == ["医学部", "講演会"])
    }

    @Test("Latin words and digits in Japanese text are not Japanese candidates")
    func japaneseSkipsLatin() {
        let extractor = WordCandidateExtractor()
        #expect(extractor.candidates(from: ["iPhone 17 を 2026年に買った"], language: .japanese) == ["年", "買っ"])
    }
}
