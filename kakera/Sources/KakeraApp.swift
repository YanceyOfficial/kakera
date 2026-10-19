import SwiftUI
import SwiftData
import KakeraCore
import KakeraServices
import KakeraUI

/// The application entry point. Wires the shared SwiftData container into the
/// environment so views and repositories can read/write vocabulary data.
@main
struct KakeraApp: App {
    /// Which way the window may turn, per screen (`KakeraOrientation`).
    @UIApplicationDelegateAdaptor(OrientationDelegate.self) private var orientation
    /// The on-disk SwiftData container backing the app, mirrored to the person's private iCloud database.
    private let container: ModelContainer

    /// User appearance preference (system / light / dark).
    @AppStorage("appearance") private var appearanceRaw = AppAppearance.system.rawValue
    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .system }

    init() {
        do {
            container = try KakeraModelContainer.onDisk(cloudKitContainer: KakeraModelContainer.cloudKitContainerIdentifier)
        } catch {
            // Without iCloud (a build that lacks the entitlement) the same store still works on this device.
            AppLog.shared.error("iCloud sync unavailable, staying on this device: \(error)", category: "sync")
            do {
                container = try KakeraModelContainer.onDisk()
            } catch {
                // A container that cannot be created is an unrecoverable launch failure.
                fatalError("Failed to create the SwiftData container: \(error)")
            }
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
        return KakeraOrientation.allowsLandscape(screen: screen.bounds.size) ? .allButUpsideDown : .portrait
    }
}
