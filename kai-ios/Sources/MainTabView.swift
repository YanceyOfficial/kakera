import SwiftUI
import SwiftData
import KaiUI

/// The app's tab shell: review, word list, stats, and settings. Each tab builds its
/// own repository from the shared SwiftData context.
struct MainTabView: View {
    /// The selected tab. Seeded from a `-startTab` launch argument so a specific tab
    /// can be opened directly (used for UI screenshots); defaults to Review.
    @State private var selection = Self.initialSelection()
    /// The deck being studied. Every tab loads its words for it, so switching languages
    /// rebuilds them all (the `.id` below), keeping the selected tab.
    @AppStorage(AppSettings.studyLanguageKey) private var studyLanguageRaw = "english"
    @AppStorage("showFurigana") private var showFurigana = true

    var body: some View {
        TabView(selection: $selection) {
            ReviewTab()
                .clearOfTopEdge()
                .tabBarGivesWayToDial()
                .tag(0)
                .tabItem { Label("Review", systemImage: "rectangle.on.rectangle.angled") }

            WordsListView()
                .clearOfTopEdge()
                .tabBarGivesWayToDial()
                .tag(1)
                .tabItem { Label("Words", systemImage: "text.book.closed") }

            StatsView()
                .clearOfTopEdge()
                .tabBarGivesWayToDial()
                .tag(2)
                .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }

            SettingsView()
                .clearOfTopEdge()
                .tabBarGivesWayToDial()
                .tag(3)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .id(studyLanguageRaw)
        .environment(\.showsFurigana, showFurigana)
        .tint(KaiColor.accent)
        .minimizingTabBarOnScroll()
        .speedDialInVerticalBar(selection: $selection, items: Self.dialItems)
    }

    /// The tabs as the speed dial offers them (`SpeedDialInVerticalBar`).
    private static let dialItems = [
        SpeedDialItem(id: 0, title: "Review", systemImage: "rectangle.on.rectangle.angled"),
        SpeedDialItem(id: 1, title: "Words", systemImage: "text.book.closed"),
        SpeedDialItem(id: 2, title: "Stats", systemImage: "chart.bar.xaxis"),
        SpeedDialItem(id: 3, title: "Settings", systemImage: "gearshape"),
    ]

    private static func initialSelection() -> Int {
        switch UserDefaults.standard.string(forKey: "startTab") {
        case "Words": return 1
        case "Stats": return 2
        case "Settings": return 3
        default: return 0
        }
    }
}

/// Hosts the review session, rebuilding its store from the context and reloading the
/// due deck each time the tab appears (so newly added words show up).
private struct ReviewTab: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("newWordsPerDay") private var newWordsPerDay = 10
    @State private var store: ReviewStore?

    var body: some View {
        ZStack {
            KaiColor.washi.ignoresSafeArea()
            if let store {
                ReviewSessionView(store: store)
            } else {
                ProgressView().tint(KaiColor.accent)
            }
        }
        .task {
            let store = store ?? ReviewStore(context: modelContext)
            store.load(newLimit: newWordsPerDay)
            self.store = store
        }
    }
}

private extension View {
    /// On iOS 26+, the Liquid Glass tab bar shrinks while a list scrolls down and comes
    /// back on the way up, giving the content the room. Earlier systems keep it fixed.
    @ViewBuilder
    func minimizingTabBarOnScroll() -> some View {
        if #available(iOS 26, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}

// MARK: - The speed dial (iPhone Duo)

extension EnvironmentValues {
    /// The tabs are reached through the speed dial instead of the tab bar (`speedDialInVerticalBar`).
    @Entry fileprivate var usesSpeedDial = false
}

private extension View {
    /// Where iOS 27.1 shows a vertical bar on the trailing edge (an iPhone Duo: the strip beside the camera), the
    /// tab bar — narrow there — gives way to one Liquid Glass button at the foot of that strip that fans the other
    /// tabs out on a press (`SpeedDial`). Elsewhere the tab bar stays.
    @ViewBuilder
    func speedDialInVerticalBar(selection: Binding<Int>, items: [SpeedDialItem<Int>]) -> some View {
        if #available(iOS 27.1, *) {
            modifier(SpeedDialInVerticalBar(selection: selection, items: items))
        } else {
            self
        }
    }

    /// Inside each tab: the tab bar hides while the speed dial stands in for it.
    func tabBarGivesWayToDial() -> some View {
        modifier(TabBarGivesWayToDial())
    }
}

private struct TabBarGivesWayToDial: ViewModifier {
    @Environment(\.usesSpeedDial) private var usesSpeedDial

    func body(content: Content) -> some View {
        content.toolbar(usesSpeedDial ? .hidden : .automatic, for: .tabBar)
    }
}

@available(iOS 27.1, *)
private struct SpeedDialInVerticalBar: ViewModifier {
    @Binding var selection: Int
    let items: [SpeedDialItem<Int>]
    @Environment(\.toolbarVerticalEdge) private var edge
    /// Open from the start with a `-speedDialOpen YES` launch argument (UI screenshots, like `-startTab`).
    @State private var isOpen = UserDefaults.standard.bool(forKey: "speedDialOpen")

    func body(content: Content) -> some View {
        let dial = edge == .trailing
        content
            .environment(\.usesSpeedDial, dial)
            .overlay {
                // An open dial dims the screen behind it (Material's backdrop); a press there closes it.
                if dial && isOpen {
                    KaiColor.sumi.opacity(0.16)
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(KaiMotion.snappy) { isOpen = false } }
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if dial {
                    GeometryReader { proxy in
                        // Centred in the strip beside the camera: the safe area's trailing inset.
                        let strip = proxy.safeAreaInsets.trailing
                        SpeedDial(items: items, selection: $selection, isOpen: $isOpen)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .offset(x: strip / 2 + SpeedDialMetrics.half, y: -KaiSpacing.m)
                    }
                }
            }
    }
}

/// Half the speed dial's main button (its centre sits mid-strip).
private enum SpeedDialMetrics {
    static let half: CGFloat = 28
}
