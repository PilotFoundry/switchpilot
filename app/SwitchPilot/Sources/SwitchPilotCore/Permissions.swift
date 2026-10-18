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
