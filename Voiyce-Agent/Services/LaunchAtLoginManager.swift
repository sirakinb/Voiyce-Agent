//
//  LaunchAtLoginManager.swift
//  Voiyce-Agent
//

import Foundation
import ServiceManagement

/// Pure mapping from an `SMAppService` status to the UI signals the toggle
/// needs. Kept free of side effects so the state handling can be unit-tested
/// without touching the login-item registration machinery.
enum LaunchAtLoginStatePolicy {
    /// The toggle reads "on" whenever the login item is registered. Apple
    /// treats `.requiresApproval` as *successfully registered* but awaiting the
    /// user's approval in System Settings, so it must read on too — otherwise
    /// the toggle snaps back off after a successful register and a second tap
    /// re-registers an already-registered service (`kSMErrorAlreadyRegistered`).
    static func isEnabled(for status: SMAppService.Status) -> Bool {
        status == .enabled || status == .requiresApproval
    }

    /// `.requiresApproval` means the login item is registered but the user has
    /// to approve it in System Settings › General › Login Items before it takes
    /// effect. The toggle stays on (see `isEnabled`) while this drives the
    /// actionable subtitle telling the user to finish approval.
    static func needsApproval(for status: SMAppService.Status) -> Bool {
        status == .requiresApproval
    }
}

/// The subset of `SMAppService` the manager depends on, factored into a
/// protocol so register/unregister/error transitions can be exercised in tests
/// without a real login-item registration.
protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// Wraps `SMAppService.mainApp` so the "Launch at Login" toggle actually
/// registers/unregisters the app as a login item and surfaces failures.
@Observable
final class LaunchAtLoginManager {
    private(set) var isEnabled = false
    private(set) var needsApproval = false
    var errorMessage: String?

    private let service: LoginItemService

    init(service: LoginItemService = SMAppService.mainApp) {
        self.service = service
        refresh()
    }

    /// Re-reads the current system status. Call on appear and when the app
    /// becomes active (e.g. returning from the Login Items settings pane).
    func refresh() {
        let status = service.status
        isEnabled = LaunchAtLoginStatePolicy.isEnabled(for: status)
        needsApproval = LaunchAtLoginStatePolicy.needsApproval(for: status)
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil

        do {
            // `isEnabled(for:)` is true for both `.enabled` and
            // `.requiresApproval` — the two states where the item is already
            // registered — so we never call `register()` on an already
            // registered service, nor `unregister()` on an unregistered one.
            let alreadyRegistered = LaunchAtLoginStatePolicy.isEnabled(for: service.status)
            if enabled {
                if !alreadyRegistered {
                    try service.register()
                }
            } else {
                if alreadyRegistered {
                    try service.unregister()
                }
            }
        } catch {
            errorMessage = "Could not update Launch at Login: \(error.localizedDescription)"
        }

        refresh()
    }
}
