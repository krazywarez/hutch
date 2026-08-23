//  Verifies what a build cannot: that controls reach VoiceOver with something to say.
//
//  `scripts/check_accessibility.py` proves no icon-only control is missing a label in
//  *source*. It cannot prove the label survives to the accessibility tree — a modifier
//  on the wrong side of a `.buttonStyle`, or a container that flattens its children,
//  compiles and lints clean and still announces nothing. That is what this asserts.
//
//  The sweep is deliberately generic rather than a list of expected labels. A hardcoded
//  list goes stale the moment a screen changes and tests only what someone remembered to
//  add; walking whatever is on screen catches controls nobody thought about.

import XCTest

// XCUIApplication is MainActor-isolated, and this project builds in Swift 6 language
// mode, so the whole case is annotated rather than each call hopping actors.
@MainActor
final class AccessibilityUITests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Reachable without credentials

    /// Every control on the auth screen announces itself.
    ///
    /// This is the one screen reachable with no token, so it is the only part of the
    /// sweep that runs unconditionally. It is a thin slice of the app, and the point of
    /// `authenticatedSessionHasNoSilentControls` is to cover the rest.
    func testAuthScreenHasNoSilentControls() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.buttons.firstMatch.waitForExistence(timeout: 10),
            "the auth screen never appeared, so nothing was verified"
        )
        assertNoSilentControls(in: app, screen: "auth")
    }

    // MARK: - Requires a token

    /// The same sweep across the signed-in tabs.
    ///
    /// Skipped unless `HUTCH_TEST_TOKEN` is set, because the app has no stub session:
    /// there is no launch argument that fakes an API, so reaching a signed-in screen
    /// means really signing in. Supply a SourceHut personal access token to run it:
    ///
    ///     HUTCH_TEST_TOKEN=… xcodebuild test -scheme Hutch -testPlan HutchUITests …
    ///
    /// The token is read from the environment and never written to the repository.
    func testAuthenticatedSessionHasNoSilentControls() throws {
        let token = ProcessInfo.processInfo.environment["HUTCH_TEST_TOKEN"]
        try XCTSkipIf(
            token?.isEmpty ?? true,
            "set HUTCH_TEST_TOKEN to sweep the signed-in screens"
        )

        let app = XCUIApplication()
        app.launch()

        let field = app.secureTextFields.firstMatch.exists
            ? app.secureTextFields.firstMatch
            : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "no token field on the auth screen")
        field.tap()
        field.typeText(token!)

        app.buttons["Connect"].tap()

        // Home is the landing tab; its tab bar is the signal that sign-in completed.
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 30),
            "sign-in did not reach the tab bar — check the token"
        )

        for tab in app.tabBars.buttons.allElementsBoundByIndex {
            guard tab.isHittable else { continue }
            let name = tab.label
            tab.tap()
            _ = app.staticTexts.firstMatch.waitForExistence(timeout: 10)
            assertNoSilentControls(in: app, screen: name)
        }
    }

    // MARK: - The sweep

    /// Fail for any hittable control VoiceOver would reach with no usable label.
    ///
    /// An unlabelled `Button { Image(systemName: "gearshape") }` does not surface as an
    /// empty label — SwiftUI leaks the symbol name into *both* the label and the
    /// identifier, so VoiceOver announces "gearshape". Comparing the two is what detects
    /// it, and it is exact rather than a guess at what a symbol name looks like: an
    /// earlier version tested for a dot and sailed straight past "gearshape".
    ///
    /// This works because the app sets no `accessibilityIdentifier` anywhere, so a
    /// non-empty identifier can only have come from a symbol. Should one ever be set
    /// deliberately, this needs to exclude it.
    private func assertNoSilentControls(in app: XCUIApplication, screen: String) {
        for button in app.buttons.allElementsBoundByIndex {
            guard button.isHittable else { continue }

            let label = button.label.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertFalse(
                label.isEmpty,
                "\(screen): a button announces nothing at \(button.frame)"
            )
            XCTAssertFalse(
                !button.identifier.isEmpty && button.identifier == label,
                "\(screen): a button announces the SF Symbol name \"\(label)\" — "
                    + "it needs an .accessibilityLabel"
            )
        }
    }
}
