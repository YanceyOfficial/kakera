#if DEBUG
import Foundation
import KakeraCore

/// A lived-in deck for screenshots: the starter words plus a few dozen more, a month of reviews
/// behind them (so Stats has a curve, maturity and a streak) and today's story. Planted on launch
/// with the `-demoDeck YES` argument (`KakeraUITests`), into an empty store only. Debug builds only.
enum DemoDeck {
    static var isRequested: Bool { UserDefaults.standard.bool(forKey: "demoDeck") }

    static func seedIfEmpty(_ repository: VocabularyRepository, now: Date = .now) throws {
        guard try repository.entries(for: .english).isEmpty else { return }
        let day: TimeInterval = 86_400
        var generator = SeededGenerator(seed: 7)

        let starters = StarterSeed.entries(for: .english, now: now.addingTimeInterval(-40 * day))
        let extras = words.enumerated().map { offset, word in
            VocabularyEntry(lemma: word.lemma, kind: .word, language: .english, phonetic: word.phonetic,
                            explanation: word.meaning, tags: word.tags,
                            now: now.addingTimeInterval(-Double(38 - offset) * day))
        }
        // The starter words stay new and due, so the review screen opens on "eccentric".
        for entry in starters { try repository.insertIfAbsent(entry) }

        for (offset, entry) in extras.enumerated() {
            try repository.insertIfAbsent(entry)
            // The last few are still new (and not yet in a session); the rest have been reviewed for
            // weeks and come due later, so today's session is the starter words.
            guard offset < extras.count - 5 else {
                var later = entry.scheduling
                later.due = now.addingTimeInterval(day)
                entry.reschedule(later)
                continue
            }
            let reps = Int.random(in: 2...9, using: &generator)
            let stability = Double.random(in: 0.5...18, using: &generator)
            let lastReview = now.addingTimeInterval(-Double.random(in: 0...6, using: &generator) * day)
            entry.reschedule(SchedulingState(
                stability: stability, difficulty: Double.random(in: 3...8, using: &generator),
                due: max(lastReview.addingTimeInterval(stability * day), now.addingTimeInterval(day)), lastReview: lastReview,
                reps: reps, lapses: reps > 6 ? 1 : 0, state: stability < 2 ? .learning : .review))
            for review in 0..<reps {
                let rating: ReviewRating = Int.random(in: 0..<10, using: &generator) < 2 ? .again : .good
                try repository.logReview(ReviewLog(
                    entryID: entry.id, rating: rating, quizType: .singleChoice,
                    elapsedMs: Int.random(in: 1_500...6_000, using: &generator), isCorrect: rating != .again,
                    timestamp: lastReview.addingTimeInterval(-Double(review * 3) * day)))
            }
        }
        // Every one of the last fortnight's days has some reviews: the streak.
        for daysAgo in 0..<14 {
            for _ in 0..<Int.random(in: 3...12, using: &generator) {
                let entry = extras[Int.random(in: 0..<extras.count - 5, using: &generator)]
                let rating: ReviewRating = Int.random(in: 0..<10, using: &generator) < 2 ? .hard : .good
                try repository.logReview(ReviewLog(
                    entryID: entry.id, rating: rating, quizType: .singleChoice, elapsedMs: 3_000, isCorrect: true,
                    timestamp: now.addingTimeInterval(-Double(daysAgo) * day - 3_600)))
            }
        }

        try repository.upsertDailyStory(DailyStory(
            day: now, language: .english,
            text: "My uncle was an eccentric man with one obsession: the lighthouse at the end of the pier. He kept meticulous notes on every ship that passed, convinced the light was more than ephemeral beauty. The neighbours found his diligence baffling, yet when the storm came, it was his careful logbook that guided the lost boat home.",
            translation: "我叔叔是个古怪的人，只有一个执念：码头尽头的灯塔。他把经过的每一艘船都记得一丝不苟，坚信那束光不只是转瞬即逝的美。邻居们对他的勤勉百思不解，可风暴来临时，正是他那本细致的航海日志把迷途的船引回了家。",
            wordLemmas: ["eccentric", "obsession", "meticulous", "ephemeral", "diligence", "baffling"],
            now: now))
    }

    private static let words: [(lemma: String, phonetic: String, meaning: String, tags: [String])] = [
        ("ephemeral", "/ɪˈfem.ər.əl/", "adj. 短暂的，转瞬即逝的", ["GRE"]),
        ("ubiquitous", "/juːˈbɪk.wɪ.təs/", "adj. 无处不在的", ["GRE"]),
        ("diligence", "/ˈdɪl.ɪ.dʒəns/", "n. 勤勉，用功", []),
        ("baffling", "/ˈbæf.lɪŋ/", "adj. 令人困惑的", []),
        ("candid", "/ˈkæn.dɪd/", "adj. 坦率的，直言不讳的", []),
        ("serendipity", "/ˌser.ənˈdɪp.ə.ti/", "n. 意外发现珍奇事物的运气", ["literary"]),
        ("ambivalent", "/æmˈbɪv.ə.lənt/", "adj. 矛盾的，摇摆不定的", ["GRE"]),
        ("lucid", "/ˈluː.sɪd/", "adj. 清晰易懂的；神志清醒的", []),
        ("pragmatic", "/præɡˈmæt.ɪk/", "adj. 务实的，讲求实际的", []),
        ("resilient", "/rɪˈzɪl.i.ənt/", "adj. 有韧性的，能迅速恢复的", []),
        ("scrutinize", "/ˈskruː.tɪ.naɪz/", "v. 仔细审查", ["GRE"]),
        ("tenacious", "/təˈneɪ.ʃəs/", "adj. 坚韧的，顽强的", []),
        ("vindicate", "/ˈvɪn.dɪ.keɪt/", "v. 证明……正确；为……辩护", ["GRE"]),
        ("whimsical", "/ˈwɪm.zɪ.kəl/", "adj. 异想天开的，古怪有趣的", ["literary"]),
        ("zealous", "/ˈzel.əs/", "adj. 热情的，狂热的", []),
        ("benevolent", "/bəˈnev.əl.ənt/", "adj. 仁慈的，乐善好施的", []),
        ("conundrum", "/kəˈnʌn.drəm/", "n. 难题，谜题", []),
        ("eloquent", "/ˈel.ə.kwənt/", "adj. 雄辩的，有说服力的", []),
        ("frugal", "/ˈfruː.ɡəl/", "adj. 节俭的", []),
        ("gregarious", "/ɡrɪˈɡeə.ri.əs/", "adj. 爱交际的，合群的", []),
        ("inevitable", "/ɪˈnev.ɪ.tə.bəl/", "adj. 不可避免的", []),
        ("juxtapose", "/ˌdʒʌk.stəˈpəʊz/", "v. 并置，并列", ["GRE"]),
        ("labyrinth", "/ˈlæb.ə.rɪnθ/", "n. 迷宫；错综复杂的事物", ["literary"]),
        ("mundane", "/mʌnˈdeɪn/", "adj. 平凡的，世俗的", []),
        ("nostalgia", "/nɒsˈtæl.dʒə/", "n. 怀旧，乡愁", []),
        ("oblivious", "/əˈblɪv.i.əs/", "adj. 未察觉的，浑然不觉的", []),
        ("paradox", "/ˈpær.ə.dɒks/", "n. 悖论；自相矛盾的事", []),
        ("quintessential", "/ˌkwɪn.tɪˈsen.ʃəl/", "adj. 典型的，精髓的", []),
        ("reverie", "/ˈrev.ər.i/", "n. 幻想，白日梦", ["literary"]),
        ("solitude", "/ˈsɒl.ɪ.tʃuːd/", "n. 独处，孤独", []),
    ]
}

/// A tiny deterministic generator, so every screenshot run plants the same deck.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
#endif
