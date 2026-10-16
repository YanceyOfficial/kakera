import SwiftUI
import SwiftData
import KaiCore
import KaiUI

/// The application entry point. Wires the shared SwiftData container into the
/// environment so views and repositories can read/write vocabulary data.
@main
struct KaiIosApp: App {
    /// Which way the window may turn, per screen (`KaiOrientation`).
    @UIApplicationDelegateAdaptor(OrientationDelegate.self) private var orientation
    /// The on-disk SwiftData container backing the app (CloudKit sync off for now).
    private let container: ModelContainer

    /// User appearance preference (system / light / dark).
    @AppStorage("appearance") private var appearanceRaw = AppAppearance.system.rawValue
    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .system }

    init() {
        do {
            container = try KaiModelContainer.onDisk()
        } catch {
            // A container that cannot be created is an unrecoverable launch failure.
            fatalError("Failed to create the SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(container)
    }
}

/// Upright on a phone-sized screen — every iPhone, an iPhone Duo folded — and free to turn on a larger one (the Duo
/// unfolded), asked again whenever the window moves to the other screen (`RootView`). iPads aren't narrowed.
final class OrientationDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        guard UIDevice.current.userInterfaceIdiom == .phone, let screen = window?.windowScene?.screen else {
            return .all
        }
        return KaiOrientation.allowsLandscape(screen: screen.bounds.size) ? .allButUpsideDown : .portrait
    }
}
