import Foundation
import Testing
@testable import KakeraServices

@Test("Widget snapshot round-trips through the store")
func widgetSnapshotRoundTrips() throws {
    let suite = "test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = WidgetSnapshotStore(defaults: defaults)
    #expect(store.read() == nil)

    let snapshot = ReviewWidgetSnapshot(dueCount: 7, totalWords: 20,
                                        updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
    store.write(snapshot)
    #expect(store.read() == snapshot)
}

@Test("A snapshot written by an older app decodes with the new fields at their defaults")
func legacySnapshotDecodes() throws {
    let legacy = Data(#"{"dueCount":7,"totalWords":20,"updatedAt":1700000000}"#.utf8)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let snapshot = try decoder.decode(ReviewWidgetSnapshot.self, from: legacy)
    #expect(snapshot.dueCount == 7)
    #expect(snapshot.language == "english")
    #expect(snapshot.reviewedToday == 0)
    #expect(snapshot.nextDueAt == nil)
    #expect(snapshot.dueWords.isEmpty)
}

@Test("The widget's words, language and timing round-trip through the store")
func richSnapshotRoundTrips() throws {
    let suite = "test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = WidgetSnapshotStore(defaults: defaults)
    let snapshot = ReviewWidgetSnapshot(
        dueCount: 2, totalWords: 9, updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        language: "japanese", reviewedToday: 5, nextDueAt: Date(timeIntervalSince1970: 1_700_003_600),
        dueWords: [ReviewWidgetWord(lemma: "懐かしい", reading: "なつかしい ④", gloss: "[形] 令人怀念的")])
    store.write(snapshot)
    #expect(store.read() == snapshot)
}

@Test("The caption counts the due words, and once none are due says when the next one comes")
func captions() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US")
    let now = Date(timeIntervalSince1970: 1_700_000_000)   // 2023-11-14 22:13 UTC

    #expect(ReviewWidgetSnapshot(dueCount: 12, totalWords: 40).caption == "words due")
    #expect(ReviewWidgetSnapshot(dueCount: 1, totalWords: 40).caption == "word due")
    #expect(ReviewWidgetSnapshot(dueCount: 0, totalWords: 40).caption == "all caught up")

    // Foundation sets the meridiem off with a narrow no-break space; the words are what matter.
    #expect(ReviewWidgetSnapshot(dueCount: 0, totalWords: 1, nextDueAt: now.addingTimeInterval(1_800))
        .nextDueText(now: now, calendar: calendar)?.replacingOccurrences(of: "\u{202F}", with: " ") == "Next at 10:43 PM")
    #expect(ReviewWidgetSnapshot(dueCount: 0, totalWords: 1, nextDueAt: now.addingTimeInterval(8 * 3_600))
        .nextDueText(now: now, calendar: calendar) == "Next tomorrow")
    #expect(ReviewWidgetSnapshot(dueCount: 0, totalWords: 1, nextDueAt: now.addingTimeInterval(3 * 86_400))
        .nextDueText(now: now, calendar: calendar) == "Next on Friday")
    #expect(ReviewWidgetSnapshot(dueCount: 0, totalWords: 1, nextDueAt: now.addingTimeInterval(20 * 86_400))
        .nextDueText(now: now, calendar: calendar) == "Next on Dec 4")
    #expect(ReviewWidgetSnapshot(dueCount: 0, totalWords: 0).nextDueText(now: now, calendar: calendar) == nil)
    #expect(ReviewWidgetSnapshot(dueCount: 0, totalWords: 1, nextDueAt: now.addingTimeInterval(-60))
        .nextDueText(now: now, calendar: calendar) == "Due now")
}

@Test("The language label is the deck's own name")
func languageLabel() {
    #expect(ReviewWidgetSnapshot(dueCount: 0, totalWords: 0, language: "english").languageLabel == "English")
    #expect(ReviewWidgetSnapshot(dueCount: 0, totalWords: 0, language: "japanese").languageLabel == "日本語")
}
