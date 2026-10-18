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

    /// Launch System Events without bringing it to the foreground. The preflight
    /// API returns -600 (target not running) even when Automation is granted, so
    /// starting the target is required before a status can be determined.
    public static func launchSystemEvents() {
        guard !systemEventsRunning(),
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: systemEventsBundleID) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: nil)
    }

    /// Resolve -600 by starting System Events, then re-run the read-only preflight.
    /// Only prompts are suppressed; the caller still decides when to ask for consent.
    public static func automationStatusResolvingTarget(timeout: TimeInterval = 1.2) -> AutomationState {
        let initial = automationStatus()
        guard initial == .targetNotRunning else { return initial }
        launchSystemEvents()
        let deadline = Date().addingTimeInterval(timeout)
        var status = automationStatus()
        while status == .targetNotRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
            status = automationStatus()
        }
        return status
    }
}

public struct PermissionResetResult: Sendable {
    public let succeeded: Bool
    public let summary: String
    public let output: String

    public init(succeeded: Bool, summary: String, output: String) {
        self.succeeded = succeeded
        self.summary = summary
        self.output = output
    }
}

extension Permissions {
    /// Advanced, explicit user action only: reset this app's TCC decisions with
    /// the system tccutil. This is not an Apple-supported revoke API, has no
    /// undo, and is never called automatically. Scope is always this bundle and
    /// the two named services; never All, never sudo.
    public static func resetInAppPermissions() -> PermissionResetResult {
        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else {
            return PermissionResetResult(
                succeeded: false,
                summary: "无法确定应用标识，未执行重置。",
                output: "")
        }
        let services = ["AppleEvents", "Accessibility"]
        var lines: [String] = []
        var allOK = true
        for service in services {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", service, bundleID]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if process.terminationStatus != 0 {
                    allOK = false
                }
                lines.append("\(service) exit=\(process.terminationStatus) \(text)")
            } catch {
                allOK = false
                lines.append("\(service) error=\(error.localizedDescription)")
            }
        }
        let output = lines.joined(separator: "\n")
        let summary = allOK
            ? "已在应用内重置本应用的两项权限；请重新申请授权。若状态未变，请重启应用后再检查。"
            : "应用内重置未完全成功，请用系统设置或终端命令重试。"
        return PermissionResetResult(succeeded: allOK, summary: summary, output: output)
    }

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
