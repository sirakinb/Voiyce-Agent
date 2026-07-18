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
            "--reset-agent-safety-choice",
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

    func testDashboardSettingsAndAgentNavigation() throws {
        launchAndWaitForDashboard()
        assertNoInternalImplementationTerms(on: "Dashboard")

        click(ui("sidebar-settings"))
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(ui("settings-billing-limits").exists)
        let billingLimitLabel = ui("settings-billing-limits").label
        XCTAssertTrue(billingLimitLabel.contains("Usage Limits"))
        XCTAssertTrue(billingLimitLabel.contains("Context, Talk, and Act use beta budgets"))
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
        XCTAssertTrue(app.staticTexts["Agent Mode"].exists)
        XCTAssertTrue(app.staticTexts["Tap Option once to start or stop the selected Agent mode"].exists)

        click(ui("sidebar-agent"))
        XCTAssertTrue(app.staticTexts["Agent"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Choose how Voiyce works with you."].exists)

        click(ui("sidebar-agentLog"))
        XCTAssertTrue(app.staticTexts["Agent Log"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["See what Voiyce did, what it touched, and what to try next."].exists)
        XCTAssertTrue(app.staticTexts["Session timeline"].exists)
        XCTAssertTrue(app.staticTexts["Action details"].exists)
        XCTAssertTrue(app.staticTexts["Redacted support export"].exists)
        assertNoInternalImplementationTerms(on: "Agent Log")
    }

    func testAgentModeSelectorShowsExpectedModes() throws {
        launchAndWaitForDashboard()

        click(ui("sidebar-agent"))
        XCTAssertTrue(app.staticTexts["Agent"].waitForExistence(timeout: 5))

        for identifier in ["agent-mode-off", "agent-mode-context", "agent-mode-talk", "agent-mode-act"] {
            let control = ui(identifier)
            XCTAssertTrue(control.waitForExistence(timeout: 5), "Missing Agent mode: \(identifier)")
            click(control)
        }

        XCTAssertTrue(app.staticTexts["Choose Act safety first."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Act command"].exists)
    }

    func testAgentScreenPolishAndStartStopControls() throws {
        launchAndWaitForDashboard()

        click(ui("sidebar-agent"))
        XCTAssertTrue(app.staticTexts["Agent"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Choose how Voiyce works with you."].exists)
        XCTAssertTrue(ui("agent-mode-off").exists)
        XCTAssertTrue(ui("agent-mode-context").exists)
        XCTAssertTrue(ui("agent-mode-talk").exists)
        XCTAssertTrue(ui("agent-mode-act").exists)
        XCTAssertTrue(app.staticTexts["STATUS"].exists)
        XCTAssertTrue(app.staticTexts["Context stays off until you start."].exists)
        XCTAssertTrue(app.staticTexts["Start begins capture"].exists)
        XCTAssertTrue(app.staticTexts["Stop pauses capture"].exists)
        XCTAssertTrue(app.staticTexts["Private Mode pauses context"].exists)

        click(ui("agent-mode-off"))
        let offAction = ui("agent-primary-action")
        XCTAssertTrue(offAction.waitForExistence(timeout: 5))
        XCTAssertFalse(offAction.isEnabled)
        XCTAssertTrue(app.staticTexts["Off"].exists)
        XCTAssertTrue(app.staticTexts["OFF · WHAT IT CAN DO"].exists)

        click(ui("agent-mode-context"))
        XCTAssertTrue(app.staticTexts["CONTEXT · WHAT IT CAN DO"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Quietly keeping context."].exists)
        let startAction = ui("agent-primary-action")
        XCTAssertTrue(startAction.waitForExistence(timeout: 5))
        XCTAssertTrue(startAction.isEnabled)
        click(startAction)
        XCTAssertTrue(app.staticTexts["Keeping context"].waitForExistence(timeout: 5))
        XCTAssertTrue(ui("sidebar-agent-activity").waitForExistence(timeout: 5))
        XCTAssertEqual(ui("sidebar-agent-activity").label, "Context active")
        let stopAction = ui("agent-primary-action")
        XCTAssertTrue(stopAction.waitForExistence(timeout: 5))
        XCTAssertTrue(stopAction.isEnabled)
        click(stopAction)
        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        XCTAssertFalse(ui("sidebar-agent-activity").exists)

        click(ui("agent-mode-act"))
        XCTAssertTrue(app.staticTexts["Choose Act safety first."].waitForExistence(timeout: 5))
        XCTAssertFalse(ui("agent-primary-action").isEnabled)
        XCTAssertTrue(ui("agent-safety-normal").exists)
        click(ui("agent-safety-normal"))
        XCTAssertTrue(app.staticTexts["You stay in control."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Run a bounded action pass on the current screen."].exists)
        click(ui("agent-primary-action"))
        XCTAssertTrue(ui("sidebar-agent-activity").waitForExistence(timeout: 5))
        XCTAssertEqual(ui("sidebar-agent-activity").label, "Act active")
        click(ui("agent-primary-action"))

        for internalTerm in ["OpenAI", "VideoDB", "Computer Use", "SDP", "tool call", "Realtime"] {
            XCTAssertFalse(
                staticText(containing: internalTerm).exists,
                "Agent screen should not expose internal term: \(internalTerm)"
            )
        }
    }

    func testStopVisibleForTalkAndActSessions() throws {
        launchAndWaitForDashboard()

        click(ui("sidebar-agent"))
        XCTAssertTrue(app.staticTexts["Agent"].waitForExistence(timeout: 5))

        for identifier in ["agent-mode-talk", "agent-mode-act"] {
            click(ui(identifier))

            let startAction = ui("agent-primary-action")
            XCTAssertTrue(startAction.waitForExistence(timeout: 5))
            XCTAssertTrue(startAction.label.contains("Start"), "\(identifier) should start from an inactive state")
            if identifier == "agent-mode-act" {
                XCTAssertFalse(startAction.isEnabled, "Act should require an explicit safety mode before first start")
                click(ui("agent-safety-normal"))
            }
            XCTAssertTrue(startAction.isEnabled)
            click(startAction)

            let stopAction = ui("agent-primary-action")
            XCTAssertTrue(stopAction.waitForExistence(timeout: 5))
            XCTAssertTrue(stopAction.label.contains("Stop"), "\(identifier) should show a visible Stop action while active")
            XCTAssertTrue(stopAction.isEnabled)
            click(stopAction)
        }
    }

    func testActCommandCanUseNativeVoiyceNavigation() throws {
        launchAndWaitForDashboard()

        click(ui("sidebar-agent"))
        XCTAssertTrue(app.staticTexts["Agent"].waitForExistence(timeout: 5))
        click(ui("agent-mode-act"))
        XCTAssertTrue(app.staticTexts["Act command"].waitForExistence(timeout: 5))
        click(ui("agent-safety-normal"))

        let commandField = ui("act-command-field")
        XCTAssertTrue(commandField.waitForExistence(timeout: 5))
        click(commandField)
        app.typeText("click the settings tab")

        let runButton = ui("act-command-run")
        XCTAssertTrue(runButton.waitForExistence(timeout: 5))
        click(runButton)

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 8))
        XCTAssertTrue(ui("settings-tab-permissions").exists)
    }

    func testActCommandShowsMainStopWhileRunning() throws {
        launchAndWaitForDashboard()

        click(ui("sidebar-agent"))
        XCTAssertTrue(app.staticTexts["Agent"].waitForExistence(timeout: 5))
        click(ui("agent-mode-act"))
        XCTAssertTrue(app.staticTexts["Act command"].waitForExistence(timeout: 5))
        click(ui("agent-safety-normal"))

        let commandField = ui("act-command-field")
        XCTAssertTrue(commandField.waitForExistence(timeout: 5))
        click(commandField)
        app.typeText("hold active act command")

        let runButton = ui("act-command-run")
        XCTAssertTrue(runButton.waitForExistence(timeout: 5))
        click(runButton)

        let stopAction = ui("agent-primary-action")
        XCTAssertTrue(stopAction.waitForExistence(timeout: 5))
        XCTAssertTrue(stopAction.label.contains("Stop"), "Act command should expose the main Stop action while work is active")
        click(stopAction)
        XCTAssertTrue(
            waitForLabel("agent-primary-action", containing: "Start"),
            "Act command Stop should return the main action to Start"
        )
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
