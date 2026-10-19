import XCTest

/// Walks the app through the screens the README and website show, in light and dark, saving each
/// as `<name>.png` / `<name>-dark.png` in `$SHOTS_DIR` (run by `scripts/screenshots.sh`). UI tests
/// need XCTest — Swift Testing can't drive an app. Each launch plants the demo deck (`DemoDeck`).
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLight() throws { try captureAll(dark: false) }
    func testDark() throws { try captureAll(dark: true) }

    private func captureAll(dark: Bool) throws {
        let suffix = dark ? "-dark" : ""

        var app = launch(dark: dark, ["-hasOnboarded", "NO"])
        sleep(3)   // the launch sunrise
        try save(app, "onboarding\(suffix)")

        app = launch(dark: dark)
        try save(app, "review\(suffix)")
        app.buttons["Show answer"].tap()
        sleep(1)
        try save(app, "revealed\(suffix)")
        app.buttons["Daily story"].tap()
        sleep(1)
        try save(app, "story\(suffix)")

        app = launch(dark: dark, ["-studyLanguage", "japanese"])
        app.buttons["Show answer"].tap()
        sleep(1)
        try save(app, "revealed-ja\(suffix)")

        app = launch(dark: dark, ["-startTab", "Words"])
        try save(app, "words\(suffix)")
        app.staticTexts["eccentric"].firstMatch.tap()
        sleep(1)
        try save(app, "detail\(suffix)")

        app = launch(dark: dark, ["-startTab", "Stats"])
        try save(app, "stats\(suffix)")

        app = launch(dark: dark, ["-startTab", "Settings"])
        try save(app, "settings\(suffix)")
    }

    /// Launches afresh with the demo deck and the given defaults (`-key value` pairs over the base ones).
    private func launch(dark: Bool, _ overrides: [String] = []) -> XCUIApplication {
        var settings = [
            "demoDeck": "YES", "hasOnboarded": "YES", "autoPlayPronunciation": "NO", "studyLanguage": "english",
            "appearance": dark ? "dark" : "light", "AppleLanguages": "(en)", "AppleLocale": "en_US",
        ]
        for pair in stride(from: 0, to: overrides.count - 1, by: 2) {
            settings[String(overrides[pair].dropFirst())] = overrides[pair + 1]
        }
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = settings.sorted { $0.key < $1.key }.flatMap { ["-\($0.key)", $0.value] }
        app.launch()
        sleep(3)   // the launch sunrise, then the first screen settles
        return app
    }

    private func save(_ app: XCUIApplication, _ name: String) throws {
        let directory = ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? NSTemporaryDirectory()
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
