import AppKit
import Carbon
import Foundation

public enum DarkModeError: Error, CustomStringConvertible {
    case permission(AutomationState)
    case script(String)
    case readbackMismatch
    case unexpectedResult(Int)

    public var description: String {
        switch self {
        case .permission(let state): return "需要 System Events 自动化授权：\(state.description)"
        case .script(let message): return "AppleScript 失败：\(message)"
        case .readbackMismatch: return "写入后读回与请求值不一致"
        case .unexpectedResult(let type): return "AppleScript 返回了非布尔结果（descriptor type \(type)）"
        }
    }
}

/// System appearance switching through the public System Events script dictionary.
///
/// No public SDK API sets the global appearance; this is the same target the
/// original application used. Every write is followed by a readback.
public enum DarkMode {
    private static let readScript = "tell application \"System Events\" to tell appearance preferences to get dark mode"

    /// Read-only display of the global appearance flag (no automation permission required).
    /// This is a preferences key, not a documented SDK API; it is used only for display.
    public static func currentAppearanceIsDark() -> Bool {
        let value = CFPreferencesCopyAppValue("AppleInterfaceStyle" as CFString, kCFPreferencesAnyApplication)
        guard let style = value as? String else { return false }
        return style.caseInsensitiveCompare("Dark") == .orderedSame
    }

    public static func permissionStatus() -> AutomationState {
        Permissions.automationStatus()
    }

    /// Explicit user-triggered authorization attempt: asks the system, and if the
    /// target is not running yet, sends a harmless read to start it so the consent
    /// prompt can appear. Never called automatically.
    public static func requestPermission() -> AutomationState {
        let direct = Permissions.requestAutomation()
        if direct == .allowed { return direct }
        _ = try? read()
        return Permissions.automationStatus()
    }

    public static func read() throws -> Bool {
        let result = try execute(readScript)
        guard [typeBoolean, typeTrue, typeFalse].contains(result.descriptorType) else {
            throw DarkModeError.unexpectedResult(Int(result.descriptorType))
        }
        return result.booleanValue
    }

    public static func set(_ enabled: Bool) throws {
        _ = try execute("tell application \"System Events\" to tell appearance preferences to set dark mode to \(enabled ? "true" : "false")")
        guard try read() == enabled else { throw DarkModeError.readbackMismatch }
    }

    private static func execute(_ source: String) throws -> NSAppleEventDescriptor {
        let state = Permissions.automationStatus()
        if state == .denied {
            throw DarkModeError.permission(state)
        }
        guard let script = NSAppleScript(source: source) else {
            throw DarkModeError.script("无法创建 AppleScript")
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int
            let message = error[NSAppleScript.errorMessage] as? String ?? "\(error)"
            if let number, number == -1743 || number == -1744 {
                throw DarkModeError.permission(AutomationState(osStatus: Int32(number)))
            }
            throw DarkModeError.script("\(number ?? 0) \(message)")
        }
        return result
    }
}
