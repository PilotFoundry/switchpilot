import AppKit
import ApplicationServices
import Carbon
import Foundation

/// Apple Event automation state for a target application.
///
/// The numbers are the documented Apple Event OSStatus values; they are spelled
/// out so the mapping is visible and testable without importing MacErrors.
public enum AutomationState: Equatable, CustomStringConvertible {
    case allowed
    case denied
    case notDetermined
    case targetNotRunning
    case failed(Int32)

    public init(osStatus: Int32) {
        switch osStatus {
        case 0: self = .allowed
        case -1743: self = .denied
        case -1744: self = .notDetermined
        case -600: self = .targetNotRunning
        default: self = .failed(osStatus)
        }
    }

    public var canWrite: Bool { self == .allowed }

    /// Short user-facing label; keeps OSStatus out of normal UI text.
    public var userFacingDescription: String {
        switch self {
        case .allowed: return "已授权"
        case .denied: return "已被拒绝"
        case .notDetermined: return "待授权"
        case .targetNotRunning: return "待授权（首次操作时提示）"
        case .failed(let code): return "未知状态 (\(code))"
        }
    }

    public var description: String {
        switch self {
        case .allowed: return "已授权"
        case .denied: return "已被拒绝 (-1743)"
        case .notDetermined: return "需要用户授权 (-1744)"
        case .targetNotRunning: return "目标进程未运行 (-600)"
        case .failed(let code): return "未知状态 (\(code))"
        }
    }
}

public enum Permissions {
    public static let systemEventsBundleID = "com.apple.systemevents"

    /// Read-only preflight: does not prompt the user.
    public static func automationStatus() -> AutomationState {
        let target = NSAppleEventDescriptor(bundleIdentifier: systemEventsBundleID)
        let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, false)
        return AutomationState(osStatus: status)
    }

    /// Explicit user-triggered request; macOS may show the Automation consent dialog.
    public static func requestAutomation() -> AutomationState {
        let target = NSAppleEventDescriptor(bundleIdentifier: systemEventsBundleID)
        let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true)
        return AutomationState(osStatus: status)
    }

    /// Read-only check; never prompts.
    public static func accessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    public static func systemEventsRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: systemEventsBundleID).isEmpty
    }
}

extension Permissions {
    public static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "local.personal.SwitchPilot"
    }

    public static func openAccessibilitySettings() {
        openSecurityPane("Privacy_Accessibility")
    }

    public static func openAutomationSettings() {
        openSecurityPane("Privacy_Automation")
    }

    private static func openSecurityPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}

extension Permissions {
    /// Shows the system Accessibility consent prompt (the app cannot grant it).
    /// Returns the trust state immediately after the prompt; the user may need
    /// to toggle the app in System Settings afterwards.
    @discardableResult
    public static func accessibilityPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
