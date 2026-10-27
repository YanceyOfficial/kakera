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

    @Test("Latin words and digits in Japanese text are not Japanese candidates")
    func japaneseSkipsLatin() {
        let extractor = WordCandidateExtractor()
        #expect(extractor.candidates(from: ["iPhone 17 を 2026年に買った"], language: .japanese) == ["年", "買っ"])
    }
}
