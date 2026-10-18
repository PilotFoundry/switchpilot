import Foundation
import IOKit.pwr_mgt
import Carbon

public enum PilotError: Error, Equatable {
    case invalidDuration
    case automation(Int32)
    case power(Int32)
    case script(String)
    case readbackMismatch
}
public func holdDuration(_ value: String) throws -> Double {
    guard let seconds = Double(value), seconds.isFinite, seconds > 0, seconds <= 60 else {
        throw PilotError.invalidDuration
    }
    return seconds
}
public func requireAutomationPermission(_ status: Int32) throws {
    guard status == noErr else { throw PilotError.automation(status) }
}
public final class PowerAssertion {
    public private(set) var id: IOPMAssertionID?
    public init() {}
    public var isActive: Bool {
        guard let id, let value = IOPMAssertionCopyProperties(id)?.takeRetainedValue() else { return false }
        let properties = value as NSDictionary
        return (properties[kIOPMAssertionLevelKey] as? NSNumber)?.intValue == kIOPMAssertionLevelOn
    }
    public func start() throws {
        if id != nil { return }
        var created: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "SwitchPilot bounded research" as CFString, &created)
        guard status == kIOReturnSuccess else { throw PilotError.power(Int32(truncatingIfNeeded: status)) }
        id = created
        guard isActive else {
            try stop()
            throw PilotError.readbackMismatch
        }
    }
    public func stop() throws {
        guard let owned = id else { return }
        let status = IOPMAssertionRelease(owned)
        guard status == kIOReturnSuccess else { throw PilotError.power(Int32(truncatingIfNeeded: status)) }
        id = nil
    }
    deinit {
        do { try stop() }
        catch { FileHandle.standardError.write(Data("Assertion cleanup failed: \(error)\n".utf8)) }
    }
}
public enum DarkMode {
    public static func permissionStatus() -> Int32 {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.systemevents")
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, false)
    }
    private static func execute(_ source: String) throws -> NSAppleEventDescriptor {
        try requireAutomationPermission(permissionStatus())
        guard let script = NSAppleScript(source: source) else {
            throw PilotError.script("Could not create AppleScript")
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error { throw PilotError.script(error.description) }
        return result
    }
    public static func read() throws -> Bool {
        let result = try execute("tell application \"System Events\" to tell appearance preferences to get dark mode")
        guard [typeBoolean, typeTrue, typeFalse].contains(result.descriptorType) else {
            throw PilotError.script("Expected boolean, received descriptor \(result.descriptorType)")
        }
        return result.booleanValue
    }
    public static func set(_ enabled: Bool) throws {
        _ = try execute("tell application \"System Events\" to tell appearance preferences to set dark mode to \(enabled ? "true" : "false")")
        guard try read() == enabled else { throw PilotError.readbackMismatch }
    }
}
