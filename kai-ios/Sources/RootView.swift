import SwiftUI
import SwiftData
import KaiCore
import KaiUI

/// App root: seeds the starter deck once, then hosts the tab shell. Real navigation
/// (decks, entry authoring, stats) lives inside the tabs.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var seeded = false
    /// Onboarding waits for the launch splash, which would otherwise play under its cover.
    @State private var splashDone = false
    /// App-wide toast presenter, injected into the environment for every screen.
    @State private var toast = ToastCenter()

    var body: some View {
        ZStack(alignment: .top) {
            KaiColor.washi.ignoresSafeArea()
            if seeded {
                MainTabView()
            } else {
                ProgressView().tint(KaiColor.accent)
            }
            if let item = toast.current {
                KaiToast(item.message, style: item.style)
                    .padding(.top, KaiSpacing.xl)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .environment(toast)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toast.current?.id)
        .launchSplash { splashDone = true }
        .fullScreenCover(isPresented: Binding(get: { seeded && splashDone && !hasOnboarded }, set: { _ in })) {
            OnboardingView(hasOnboarded: $hasOnboarded)
        }
        .task {
            guard !seeded else { return }
            let repository = VocabularyRepository(context: modelContext)
            for language in LanguageDomain.allCases {
                try? StarterSeed.seedIfEmpty(repository, language: language)
            }
            seeded = true
            // Keep the daily reminder in sync with settings + deck state on launch.
            let enabled = UserDefaults.standard.bool(forKey: "reminderEnabled")
            let minutes = UserDefaults.standard.object(forKey: "reminderMinutes") as? Int ?? 540
            let hasWords = !(((try? repository.entries(for: AppSettings.studyLanguage)) ?? []).isEmpty)
            await ReviewReminder.apply(enabled: enabled, minutes: minutes, hasWords: hasWords)
            WidgetSync.update(repository: repository)
        }
        .onChange(of: scenePhase) { _, phase in
            // Refresh the widget's due count as the app leaves the foreground.
            if phase != .active {
                WidgetSync.update(repository: VocabularyRepository(context: modelContext))
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(try! KaiModelContainer.inMemory())
}

extension View {
    /// Keeps every screen's header clear of the display's top edge where the safe area doesn't: an iPhone Duo shows
    /// its status bar in the vertical bar beside the camera, so its top inset is a few points and a header there runs
    /// under the screen's rounded edge. The safe area grows to `minimum` there; with a status bar on top (every other
    /// iPhone) it is already deeper and nothing changes.
    func clearOfTopEdge(minimum: CGFloat = 24) -> some View {
        modifier(TopEdgeClearance(minimum: minimum))
    }
}

private struct TopEdgeClearance: ViewModifier {
    let minimum: CGFloat

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content.safeAreaPadding(.top, max(0, minimum - proxy.safeAreaInsets.top))
        }
    }
}

