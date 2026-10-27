import Foundation
import WidgetKit
import KakeraCore
import KakeraServices

/// Publishes the review snapshot the home-screen widget reads, and asks WidgetKit to
/// refresh. Call whenever the due count may have changed (launch, backgrounding).
enum WidgetSync {
    static func update(repository: VocabularyRepository, now: Date = .now) {
        let language = AppSettings.studyLanguage
        let entries = (try? repository.entries(for: language)) ?? []
        let reviews = ((try? repository.allReviewLogs()) ?? []).map(\.timestamp)
        WidgetSnapshotStore().write(snapshot(entries: entries, reviewTimestamps: reviews, language: language, now: now))
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// What the widget shows for a deck: the due count, the three most overdue words with
    /// their reading and gloss, today's review count, and when the next word comes.
    static func snapshot(
        entries: [VocabularyEntry], reviewTimestamps: [Date], language: LanguageDomain,
        now: Date, calendar: Calendar = .current
    ) -> ReviewWidgetSnapshot {
        let due = entries.filter { $0.dueAt <= now }.sorted { $0.dueAt < $1.dueAt }
        let startOfDay = calendar.startOfDay(for: now)
        return ReviewWidgetSnapshot(
            dueCount: due.count,
            totalWords: entries.count,
            updatedAt: now,
            language: language.rawValue,
            reviewedToday: reviewTimestamps.filter { $0 >= startOfDay && $0 <= now }.count,
            nextDueAt: entries.filter { $0.dueAt > now }.map(\.dueAt).min(),
            dueWords: due.prefix(3).map { ReviewWidgetWord(lemma: $0.lemma, reading: $0.phonetic, gloss: $0.explanation) })
    }
}
