import Foundation

/// Words handed to the app from outside — the share extension — waiting in the App Group
/// until the app comes to the front and opens its add-words sheet on them.
public struct WordInbox {
    private let defaults: UserDefaults?
    private let key = "wordInbox"

    /// Production: the shared App Group suite.
    public init(suiteName: String = kakeraAppGroupID) {
        self.defaults = UserDefaults(suiteName: suiteName)
    }

    /// Test seam: an explicit defaults instance.
    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// What is waiting, in the order it arrived.
    public var pending: [String] {
        defaults?.stringArray(forKey: key) ?? []
    }

    /// Appends `words` to what is waiting: trimmed, blanks dropped, and a word already
    /// there (whatever its case) not added again.
    public func add(_ words: [String]) {
        var seen = Set(pending.map { $0.lowercased() })
        var merged = pending
        for word in words {
            let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { continue }
            merged.append(trimmed)
        }
        defaults?.set(merged, forKey: key)
    }

    /// Takes everything that is waiting, leaving the inbox empty.
    public func drain() -> [String] {
        let words = pending
        defaults?.removeObject(forKey: key)
        return words
    }
}
