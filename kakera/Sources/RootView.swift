import SwiftUI
import SwiftData
import CoreData
import Combine
import KakeraCore
import KakeraUI

/// App root: seeds the starter deck once, then hosts the tab shell. Real navigation
/// (decks, entry authoring, stats) lives inside the tabs.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var seeded = false
    /// App-wide toast presenter, injected into the environment for every screen.
    @State private var toast = ToastCenter()

    var body: some View {
        ZStack(alignment: .top) {
            KakeraColor.washi.ignoresSafeArea()
            if !hasOnboarded {
                // In place of the tabs, not over them: a cover would leave the review screen live
                // underneath, auto-playing its first card behind the welcome.
                OnboardingView(hasOnboarded: $hasOnboarded)
                    .transition(.opacity)
            } else if seeded {
                MainTabView()
                    .transition(.opacity)
            } else {
                ProgressView().tint(KakeraColor.accent)
            }
            if let item = toast.current {
                KakeraToast(item.message, style: item.style)
                    .padding(.top, KakeraSpacing.xl)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .environment(toast)
        // Folding or unfolding an iPhone Duo moves the window to the other screen: which way it may turn changes too.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { _ in
            for scene in UIApplication.shared.connectedScenes {
                (scene as? UIWindowScene)?.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toast.current?.id)
        .animation(.easeInOut(duration: 0.3), value: hasOnboarded)
        .launchSplash()
        .task {
            guard !seeded else { return }
            let repository = VocabularyRepository(context: modelContext)
            #if DEBUG
            if DemoDeck.isRequested { try? DemoDeck.seedIfEmpty(repository) }
            #endif
            // With iCloud the starter deck is planted once per person, not per device: the flag lives in
            // iCloud's key-value store, so a second device doesn't bring back starter words deleted on the
            // first. Without an iCloud account the flag would only outlive a reinstall, so it isn't read.
            let iCloud = NSUbiquitousKeyValueStore.default
            let signedIn = FileManager.default.ubiquityIdentityToken != nil
            for language in LanguageDomain.allCases where !(signedIn && iCloud.bool(forKey: "starterSeeded.\(language.rawValue)")) {
                try? StarterSeed.seedIfEmpty(repository, language: language)
                iCloud.set(true, forKey: "starterSeeded.\(language.rawValue)")
            }
            try? repository.mergeDuplicates()
            seeded = true
            // Keep the daily reminder in sync with settings + deck state on launch.
            let enabled = UserDefaults.standard.bool(forKey: "reminderEnabled")
            let minutes = UserDefaults.standard.object(forKey: "reminderMinutes") as? Int ?? 540
            let hasWords = !(((try? repository.entries(for: AppSettings.studyLanguage)) ?? []).isEmpty)
            await ReviewReminder.apply(enabled: enabled, minutes: minutes, hasWords: hasWords)
            WidgetSync.update(repository: repository)
        }
        // iCloud brought in changes: fold any twins they made (a word added on two devices) into one.
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)) { _ in
            try? VocabularyRepository(context: modelContext).mergeDuplicates()
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
        .modelContainer(try! KakeraModelContainer.inMemory())
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

