import Testing
import Foundation
@testable import Kakera

@Suite("TabDeepLink")
struct TabDeepLinkTests {
    @Test("The widget's link opens the Review tab; other tabs by name; anything else is ignored")
    func resolvesTabs() {
        #expect(TabDeepLink.tab(for: URL(string: "kakera://review")!) == 0)
        #expect(TabDeepLink.tab(for: URL(string: "kakera://words")!) == 1)
        #expect(TabDeepLink.tab(for: URL(string: "kakera://stats")!) == 2)
        #expect(TabDeepLink.tab(for: URL(string: "kakera://settings")!) == 3)
        #expect(TabDeepLink.tab(for: URL(string: "kakera://nonsense")!) == nil)
        #expect(TabDeepLink.tab(for: URL(string: "https://kakera.yancey.app/review")!) == nil)
    }
}
