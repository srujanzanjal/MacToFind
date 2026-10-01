//
//  LaunchAtLoginManager.swift
//  MacToFind
//
//  Manages Launch at Login registration using Apple's modern SMAppService.mainApp.
//

import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()
    
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var statusMessage: String? = nil
    
    private init() {
        refreshStatus()
    }
    
    func refreshStatus() {
        let status = SMAppService.mainApp.status
        isEnabled = (status == .enabled)
        
        switch status {
        case .enabled:
            statusMessage = nil
        case .requiresApproval:
            statusMessage = "Requires approval in System Settings > General > Login Items"
        case .notFound:
            statusMessage = "Application bundle not found in Applications"
        case .notRegistered:
            statusMessage = nil
        @unknown default:
            statusMessage = nil
        }
    }
    
    func autoRegisterOnLaunch() {
        refreshStatus()
        let explicitlyDisabled = UserDefaults.standard.bool(forKey: "launch_at_login_explicitly_disabled")
        if !explicitlyDisabled && !isEnabled {
            print("[LaunchAtLogin] Auto-registering SMAppService.mainApp on startup...")
            setEnabled(true)
        }
    }
    
    func setEnabled(_ enable: Bool) {
        UserDefaults.standard.set(!enable, forKey: "launch_at_login_explicitly_disabled")
        do {
            if enable {
                if SMAppService.mainApp.status == .enabled {
                    isEnabled = true
                    return
                }
                try SMAppService.mainApp.register()
                print("[LaunchAtLogin] Successfully registered SMAppService.mainApp")
            } else {
                if SMAppService.mainApp.status == .notRegistered {
                    isEnabled = false
                    return
                }
                try SMAppService.mainApp.unregister()
                print("[LaunchAtLogin] Successfully unregistered SMAppService.mainApp")
            }
        } catch {
            print("[LaunchAtLogin] Error toggling login item: \(error.localizedDescription)")
            statusMessage = error.localizedDescription
        }
        refreshStatus()
    }
}
