import Testing
import Foundation
@testable import Kakera
import KakeraCore
import KakeraServices

@Suite("WidgetSync")
struct WidgetSyncTests {
    private func entry(_ lemma: String, gloss: String, reading: String = "", due: Date) -> VocabularyEntry {
        let entry = VocabularyEntry(lemma: lemma, kind: .word, language: .english, phonetic: reading, explanation: gloss)
        var state = entry.scheduling
        state.due = due
        entry.reschedule(state)
        return entry
    }

    /// Fixed to UTC: "today" must not depend on the machine's zone.
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test("The snapshot counts the due words, lists the most overdue first with reading and gloss, and says when the next one comes")
    func snapshotFromDeck() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)   // 08:00 UTC
        let hour: TimeInterval = 3_600
        let entries = [
            entry("later", gloss: "adv. 稍后", due: now.addingTimeInterval(5 * hour)),
            entry("ephemeral", gloss: "adj. 短暂的", reading: "/ɪˈfem.ər.əl/", due: now.addingTimeInterval(-2 * hour)),
            entry("eccentric", gloss: "adj. 古怪的", due: now.addingTimeInterval(-30 * hour)),
            entry("obsession", gloss: "n. 执念", due: now.addingTimeInterval(-hour)),
            entry("meticulous", gloss: "adj. 一丝不苟的", due: now),
            entry("soonest", gloss: "adj. 最早的", due: now.addingTimeInterval(2 * hour)),
        ]
        let snapshot = WidgetSync.snapshot(
            entries: entries, reviewTimestamps: [now.addingTimeInterval(-hour), now.addingTimeInterval(-26 * hour)],
            language: .japanese, now: now, calendar: utc)
        #expect(snapshot.dueCount == 4)
        #expect(snapshot.totalWords == 6)
        #expect(snapshot.language == "japanese")
        #expect(snapshot.dueWords.map(\.lemma) == ["eccentric", "ephemeral", "obsession"])
        #expect(snapshot.dueWords[1] == ReviewWidgetWord(lemma: "ephemeral", reading: "/ɪˈfem.ər.əl/", gloss: "adj. 短暂的"))
        #expect(snapshot.nextDueAt == now.addingTimeInterval(2 * hour))
        #expect(snapshot.reviewedToday == 1)
        #expect(snapshot.updatedAt == now)
    }

    @Test("With nothing due the snapshot lists no words and points at the next due time")
    func caughtUp() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let entries = [entry("later", gloss: "adv. 稍后", due: now.addingTimeInterval(7_200))]
        let snapshot = WidgetSync.snapshot(entries: entries, reviewTimestamps: [], language: .english, now: now, calendar: utc)
        #expect(snapshot.dueCount == 0)
        #expect(snapshot.dueWords.isEmpty)
        #expect(snapshot.nextDueAt == now.addingTimeInterval(7_200))
    }
}
