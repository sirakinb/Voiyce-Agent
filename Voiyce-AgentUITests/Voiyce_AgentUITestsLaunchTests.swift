//
//  Voiyce_AgentUITestsLaunchTests.swift
//  Voiyce-AgentUITests
//

import XCTest
import AppKit

@MainActor
final class Voiyce_AgentUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        NSWorkspace.shared.hideOtherApplications()
    }

    func testLaunchesIntoUsableShell() throws {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = [
            "--ui-testing",
            "-ApplePersistenceIgnoreState", "YES"
        ]
        app.launchEnvironment = [
            "VOIYCE_UI_TESTING": "1"
        ]
        app.launch()
        focus(app)

        if !app.descendants(matching: .any)["sidebar-dashboard"].firstMatch.waitForExistence(timeout: 3) {
            focus(app)
            app.typeKey("n", modifierFlags: .command)
            focus(app)
        }

        XCTAssertTrue(app.descendants(matching: .any)["sidebar-dashboard"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-agent"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-agentLog"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-settings"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Pro Trial"].waitForExistence(timeout: 10))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Dashboard"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate()
    }

    func testOfflineSignedOutLaunchShowsRecoveryCopy() throws {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = [
            "--ui-testing",
            "-ApplePersistenceIgnoreState", "YES"
        ]
        app.launchEnvironment = [
            "VOIYCE_UI_TESTING": "1",
            "VOIYCE_UI_TEST_SIGNED_OUT": "1",
            "VOIYCE_UI_TEST_OFFLINE": "1"
        ]
        app.launch()
        focus(app)

        if !app.descendants(matching: .any)["auth-view"].firstMatch.waitForExistence(timeout: 3) {
            focus(app)
            app.typeKey("n", modifierFlags: .command)
            focus(app)
        }

        XCTAssertTrue(app.descendants(matching: .any)["auth-view"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Reconnect to sign in"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No internet connection. Reconnect Wi-Fi or Ethernet, then sign in again."].exists)
        XCTAssertFalse(app.buttons["auth-google-button"].isEnabled)
        XCTAssertFalse(app.buttons["auth-submit-button"].isEnabled)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Offline Auth Recovery"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate()
    }

    private func focus(_ app: XCUIApplication) {
        app.activate()
        NSWorkspace.shared.hideOtherApplications()
        app.activate()
    }
}
