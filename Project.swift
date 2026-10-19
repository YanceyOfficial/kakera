import ProjectDescription

let project = Project(
    name: "kakera",
    packages: [
        .local(path: "Packages/KakeraCore"),
        .local(path: "Packages/KakeraFSRS"),
        .local(path: "Packages/KakeraAI"),
        .local(path: "Packages/KakeraServices"),
        .local(path: "Packages/KakeraUI"),
    ],
    settings: .settings(base: [
        "SWIFT_VERSION": "6.0",
        // The Apple Developer Program team.
        "DEVELOPMENT_TEAM": "A542S7SY83",
    ]),
    targets: [
        .target(
            name: "Kakera",
            destinations: .iOS,
            product: .app,
            bundleId: "app.yancey.kakera",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(
                with: [
                    // The mark on the app's background, from scripts/generate_app_icon.swift;
                    // LaunchSplash picks up from this exact frame.
                    "UILaunchScreen": [
                        "UIColorName": "LaunchBackground",
                        "UIImageName": "LaunchMark",
                    ],
                    "CFBundleDisplayName": "Kakera",
                    // Only HTTPS (exempt): App Store Connect needn't ask about export compliance.
                    "ITSAppUsesNonExemptEncryption": false,
                    // CloudKit pushes silently when another device changed the store.
                    "UIBackgroundModes": ["remote-notification"],
                    // Upright on a phone-sized screen and turning on a larger one (an iPhone Duo unfolded): the app
                    // delegate narrows this per screen at run time (`KakeraOrientation`); iPads turn freely.
                    "UISupportedInterfaceOrientations~iphone": [
                        "UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft",
                        "UIInterfaceOrientationLandscapeRight",
                    ],
                    "UISupportedInterfaceOrientations~ipad": [
                        "UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
                        "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight",
                    ],
                ]
            ),
            buildableFolders: [
                "kakera/Sources",
                "kakera/Resources",
            ],
            entitlements: .dictionary([
                "com.apple.security.application-groups": ["group.app.yancey.kakera"],
                // SwiftData mirrors the store to this container's private database (KakeraModelContainer).
                "com.apple.developer.icloud-container-identifiers": ["iCloud.app.yancey.kakera"],
                "com.apple.developer.icloud-services": ["CloudKit"],
                // The "starter deck planted" flags (RootView), shared by a person's devices.
                "com.apple.developer.ubiquity-kvstore-identifier": "$(TeamIdentifierPrefix)$(CFBundleIdentifier)",
                // Archiving for the App Store switches this to production.
                "aps-environment": "development",
            ]),
            dependencies: [
                .package(product: "KakeraCore"),
                .package(product: "KakeraFSRS"),
                .package(product: "KakeraAI"),
                .package(product: "KakeraServices"),
                .package(product: "KakeraUI"),
                .target(name: "KakeraWidget"),
            ]
        ),
        .target(
            name: "KakeraWidget",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "app.yancey.kakera.widget",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDisplayName": "Kakera",
                    "NSExtension": [
                        "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
                    ],
                ]
            ),
            buildableFolders: [
                "kakera-widget/Sources",
                "kakera-widget/Resources",
            ],
            entitlements: .dictionary([
                "com.apple.security.application-groups": ["group.app.yancey.kakera"],
            ]),
            dependencies: [
                .package(product: "KakeraServices"),
                .package(product: "KakeraUI"),
            ]
        ),
        .target(
            name: "KakeraTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "app.yancey.kakeraTests",
            infoPlist: .default,
            buildableFolders: [
                "kakera/Tests"
            ],
            dependencies: [.target(name: "Kakera")]
        ),
        // Drives the app through its screens for the README and website screenshots (`scripts/screenshots.sh`).
        .target(
            name: "KakeraUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "app.yancey.kakeraUITests",
            infoPlist: .default,
            buildableFolders: [
                "kakera/UITests"
            ],
            dependencies: [.target(name: "Kakera")]
        ),
    ]
)
