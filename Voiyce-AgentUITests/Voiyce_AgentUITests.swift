//
//  Voiyce_AgentUITests.swift
//  Voiyce-AgentUITests
//

import XCTest
import AppKit

@MainActor
final class Voiyce_AgentUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        NSWorkspace.shared.hideOtherApplications()
        app = XCUIApplication()
        app.terminate()
        app.launchArguments = [
            "--ui-testing",
            "-ApplePersistenceIgnoreState", "YES"
        ]
        app.launchEnvironment = [
            "VOIYCE_UI_TESTING": "1"
        ]
        addSystemAlertHandler()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testDashboardSettingsAndPermissionsNavigation() throws {
        launchAndWaitForDashboard()
        assertNoInternalImplementationTerms(on: "Dashboard")

        click(ui("sidebar-settings"))
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(ui("settings-billing-limits").exists)
        let billingLimitLabel = ui("settings-billing-limits").label
        XCTAssertTrue(billingLimitLabel.contains("Usage Limits"))
        assertNoInternalImplementationTerms(on: "Settings")

        click(settingsTab("Permissions"))
        XCTAssertTrue(app.staticTexts["System Permissions"].waitForExistence(timeout: 5))
        XCTAssertTrue(ui("permission-row-microphone").exists)
        XCTAssertTrue(ui("permission-row-screen-recording").exists)
        XCTAssertTrue(ui("permissions-refresh").exists)
        XCTAssertTrue(ui("permissions-open-system-settings").exists)
        click(ui("permissions-refresh"))
        XCTAssertTrue(app.staticTexts["Permission status refreshed."].waitForExistence(timeout: 5))

        click(settingsTab("Hotkeys"))
        XCTAssertTrue(app.staticTexts["Keyboard Shortcuts"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Dictation Mode"].exists)
    }

    func testPermissionsScreenCanReturnToDashboard() throws {
        launchAppWindowIfNeeded()
        XCTAssertTrue(ui("sidebar-settings").waitForExistence(timeout: 10))

        click(ui("sidebar-settings"))
        click(settingsTab("Permissions"))
        XCTAssertTrue(app.staticTexts["System Permissions"].waitForExistence(timeout: 5))

        click(ui("sidebar-dashboard"))
        XCTAssertTrue(app.staticTexts["Pro Trial"].waitForExistence(timeout: 5))
    }

    private func launchAndWaitForDashboard() {
        launchAppWindowIfNeeded()
        XCTAssertTrue(ui("sidebar-dashboard").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Pro Trial"].waitForExistence(timeout: 10))
    }

    private func launchAppWindowIfNeeded() {
        app.launch()
        focusApp()
        if !ui("sidebar-dashboard").waitForExistence(timeout: 3) {
            focusApp()
            app.typeKey("n", modifierFlags: .command)
            focusApp()
        }
    }

    private func ui(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func staticText(containing label: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
    }

    private func assertNoInternalImplementationTerms(on surface: String) {
        for internalTerm in ["OpenAI", "VideoDB", "Computer Use", "SDP", "tool call", "Realtime", "backend"] {
            XCTAssertFalse(
                staticText(containing: internalTerm).exists,
                "\(surface) should not expose internal term: \(internalTerm)"
            )
        }
    }

    private func settingsTab(_ label: String) -> XCUIElement {
        let byIdentifier = ui("settings-tab-\(label.lowercased())")
        if byIdentifier.exists { return byIdentifier }
        return app.descendants(matching: .any)[label].firstMatch
    }

    private func click(_ element: XCUIElement) {
        focusApp()
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        element.click()
    }

    private func waitForLabel(_ identifier: String, containing text: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let element = ui(identifier)
            if !element.exists {
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
                continue
            }

            if element.label.localizedCaseInsensitiveContains(text) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        let element = ui(identifier)
        guard element.exists else { return false }
        return element.label.localizedCaseInsensitiveContains(text)
    }

    private func focusApp() {
        app.activate()
        NSWorkspace.shared.hideOtherApplications()
        app.activate()
    }

    private func addSystemAlertHandler() {
        addUIInterruptionMonitor(withDescription: "System permission and notification alerts") { alert in
            guard [.alert, .dialog, .sheet].contains(alert.elementType) else {
                return false
            }

            let buttonTitles = [
                "Don’t Allow",
                "Don't Allow",
                "Not Now",
                "OK",
                "Allow",
                "Continue",
                "Cancel"
            ]

            for title in buttonTitles {
                let button = alert.buttons[title]
                if button.exists {
                    button.click()
                    return true
                }
            }

            if alert.buttons.count > 0 {
                alert.buttons.element(boundBy: 0).click()
                return true
            }

            return false
        }
    }
}
