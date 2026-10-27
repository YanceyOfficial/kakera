import Foundation
import Testing
@testable import KakeraServices

@Suite("WordInbox")
struct WordInboxTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test.inbox.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Words added from outside wait until the app drains them, then the inbox is empty")
    func addAndDrain() {
        let inbox = WordInbox(defaults: makeDefaults())
        inbox.add(["eccentric", "obsession"])
        #expect(inbox.pending == ["eccentric", "obsession"])
        #expect(inbox.drain() == ["eccentric", "obsession"])
        #expect(inbox.pending.isEmpty)
        #expect(inbox.drain().isEmpty)
    }

    @Test("Two shares before the app opens merge, in order, without repeats or blanks")
    func merges() {
        let inbox = WordInbox(defaults: makeDefaults())
        inbox.add(["eccentric", " ", "Obsession"])
        inbox.add(["obsession", "meticulous", "eccentric"])
        #expect(inbox.pending == ["eccentric", "Obsession", "meticulous"])
    }
}
