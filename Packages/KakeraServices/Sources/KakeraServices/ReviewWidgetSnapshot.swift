import Foundation

/// The App Group shared between the app and its widget.
public let kakeraAppGroupID = "group.app.yancey.kakera"

/// One word the widget shows: the headword, its reading (phonetic for English, kana with
/// pitch accent for Japanese; may be empty) and the concise gloss.
public struct ReviewWidgetWord: Codable, Sendable, Equatable {
    public var lemma: String
    public var reading: String
    public var gloss: String

    public init(lemma: String, reading: String, gloss: String) {
        self.lemma = lemma
        self.reading = reading
        self.gloss = gloss
    }
}

/// A small snapshot the app publishes for the home-screen widget (which can't read the
/// app's SwiftData store directly): how many words are due, a few of them, and when the
/// next one comes once none are.
public struct ReviewWidgetSnapshot: Codable, Sendable, Equatable {
    public var dueCount: Int
    public var totalWords: Int
    public var updatedAt: Date
    /// The deck being studied, as `LanguageDomain`'s raw value ("english" / "japanese").
    public var language: String
    /// Reviews logged since the day began.
    public var reviewedToday: Int
    /// When the next word falls due, once nothing is (nil with an empty deck).
    public var nextDueAt: Date?
    /// Up to three due words, the most overdue first.
    public var dueWords: [ReviewWidgetWord]

    public init(dueCount: Int, totalWords: Int, updatedAt: Date = .now, language: String = "english",
                reviewedToday: Int = 0, nextDueAt: Date? = nil, dueWords: [ReviewWidgetWord] = []) {
        self.dueCount = dueCount
        self.totalWords = totalWords
        self.updatedAt = updatedAt
        self.language = language
        self.reviewedToday = reviewedToday
        self.nextDueAt = nextDueAt
        self.dueWords = dueWords
    }

    /// Reads what an older app wrote (count, total and time only) at the new fields' defaults.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dueCount = try c.decode(Int.self, forKey: .dueCount)
        totalWords = try c.decode(Int.self, forKey: .totalWords)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? "english"
        reviewedToday = try c.decodeIfPresent(Int.self, forKey: .reviewedToday) ?? 0
        nextDueAt = try c.decodeIfPresent(Date.self, forKey: .nextDueAt)
        dueWords = try c.decodeIfPresent([ReviewWidgetWord].self, forKey: .dueWords) ?? []
    }

    // MARK: Presentation

    /// The words under the count: "words due", "word due", or "all caught up".
    public var caption: String {
        switch dueCount {
        case 0: "all caught up"
        case 1: "word due"
        default: "words due"
        }
    }

    /// The deck's own name, as the language picker shows it.
    public var languageLabel: String {
        switch language {
        case "english": "English"
        case "japanese": "日本語"
        default: language.capitalized
        }
    }

    /// When the next word comes, for the caught-up state: a time today, "tomorrow", a
    /// weekday within the week, or a date — nil with nothing scheduled.
    public func nextDueText(now: Date = .now, calendar: Calendar = .current) -> String? {
        guard let nextDueAt else { return nil }
        guard nextDueAt > now else { return "Due now" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale
        formatter.timeZone = calendar.timeZone
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: nextDueAt)).day ?? 0
        switch days {
        case 0:
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Next at \(formatter.string(from: nextDueAt))"
        case 1:
            return "Next tomorrow"
        case 2...6:
            formatter.dateFormat = "EEEE"
            return "Next on \(formatter.string(from: nextDueAt))"
        default:
            formatter.setLocalizedDateFormatFromTemplate("MMMd")
            return "Next on \(formatter.string(from: nextDueAt))"
        }
    }
}

/// Reads/writes the widget snapshot in the shared App Group container.
public struct WidgetSnapshotStore {
    private let defaults: UserDefaults?
    private let key = "reviewWidgetSnapshot"

    /// Production: the shared App Group suite.
    public init(suiteName: String = kakeraAppGroupID) {
        self.defaults = UserDefaults(suiteName: suiteName)
    }

    /// Test seam: an explicit defaults instance.
    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func write(_ snapshot: ReviewWidgetSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    public func read() -> ReviewWidgetSnapshot? {
        guard let defaults, let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ReviewWidgetSnapshot.self, from: data)
    }
}
