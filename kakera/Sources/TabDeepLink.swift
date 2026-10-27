import Foundation

/// The app's own links — `kakera://review`, `kakera://words`, `kakera://stats`,
/// `kakera://settings` — as the tab each opens. The widget's tap is `kakera://review`.
enum TabDeepLink {
    static func tab(for url: URL) -> Int? {
        guard url.scheme?.lowercased() == "kakera" else { return nil }
        let name = url.host?.lowercased() ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        switch name {
        case "review": return 0
        case "words": return 1
        case "stats": return 2
        case "settings": return 3
        default: return nil
        }
    }
}
