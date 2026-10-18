import AppKit
import Carbon
import CoreGraphics
import Foundation

public struct LockPermissions: Equatable {
    public let automation: AutomationState
    public let accessibilityTrusted: Bool

    public init(automation: AutomationState, accessibilityTrusted: Bool) {
        self.automation = automation
        self.accessibilityTrusted = accessibilityTrusted
    }

    public var canAttempt: Bool {
        automation == .allowed && accessibilityTrusted
    }

    public var summary: String {
        LF("自动化：%@；辅助功能：%@", automation.description, accessibilityTrusted ? L("已授权") : L("未授权"))
    }
}

public enum LockScreenError: Error, CustomStringConvertible {
    case permissions(LockPermissions)
    case script(String)

    public var description: String {
        switch self {
        case .permissions(let permissions): return LF("缺少权限：%@", permissions.summary)
        case .script(let message): return LF("锁屏脚本失败：%@", message)
        }
    }
}

/// Locks the screen with the same System Events keystroke the original app used.
///
/// The keystroke is Ctrl+Cmd+Q, synthesized by System Events. That requires BOTH
/// Automation consent (to talk to System Events) and Accessibility trust (for UI
/// scripting), so this type never sends the keystroke unless both are granted.
public enum LockScreen {
    /// Same literal the original application ships.
    public static let lockScript = "tell application \"System Events\" to keystroke \"q\" using {command down, control down}"

    public static func permissions() -> LockPermissions {
        LockPermissions(
            automation: Permissions.automationStatus(),
            accessibilityTrusted: Permissions.accessibilityTrusted())
    }

    /// Explicit user-triggered request. Tries the consent API and, if needed, a
    /// harmless System Events probe so the system can present its prompt.
    public static func requestAutomationPermission() -> AutomationState {
        let direct = Permissions.requestAutomation()
        if direct == .allowed { return direct }
        _ = try? runScript("tell application \"System Events\" to get name")
        return Permissions.automationStatus()
    }

    /// Best-effort readback. `CGSessionCopyCurrentDictionary` is public API (10.3+),
    /// but the `CGSSessionScreenIsLocked` key is not declared in the current public
    /// SDK header, so nil/unknown is a valid result and must not be presented as proof.
    public static func isLocked() -> Bool? {
        guard let dictionary = CGSessionCopyCurrentDictionary() as NSDictionary? else {
            return nil
        }
        if let number = dictionary["CGSSessionScreenIsLocked"] as? NSNumber {
            return number.boolValue
        }
        if let value = dictionary["CGSSessionScreenIsLocked"] as? Bool {
            return value
        }
        return nil
    }

    public static func lock() throws {
        let currentPermissions = permissions()
        guard currentPermissions.canAttempt else {
            throw LockScreenError.permissions(currentPermissions)
        }
        _ = try runScript(lockScript)
    }

    private static func runScript(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw LockScreenError.script(L("无法创建 AppleScript"))
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int
            let message = error[NSAppleScript.errorMessage] as? String ?? "\(error)"
            throw LockScreenError.script("\(number ?? 0) \(message)")
        }
        return result
    }
}
