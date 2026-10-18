import Foundation
import IOKit.pwr_mgt

public enum PowerAssertionError: Error, Equatable, CustomStringConvertible {
    case createFailed(Int32)
    case releaseFailed(Int32)
    case readbackMismatch

    public var description: String {
        switch self {
        case .createFailed(let code): return "IOPMAssertionCreateWithName failed (\(code))"
        case .releaseFailed(let code): return "IOPMAssertionRelease failed (\(code))"
        case .readbackMismatch: return "power assertion readback did not match the requested state"
        }
    }
}

/// Owns exactly one PreventUserIdleDisplaySleep assertion and guarantees Create/Release pairing.
public final class PowerAssertion {
    public private(set) var id: IOPMAssertionID?
    private let name: String

    public init(name: String = "SwitchPilot personal") {
        self.name = name
    }

    public var isActive: Bool {
        guard let id, let value = IOPMAssertionCopyProperties(id)?.takeRetainedValue() else {
            return false
        }
        let properties = value as NSDictionary
        return (properties[kIOPMAssertionLevelKey] as? NSNumber)?.intValue == kIOPMAssertionLevelOn
    }

    public func start() throws {
        if id != nil { return }
        var created: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name as CFString,
            &created)
        guard status == kIOReturnSuccess else {
            throw PowerAssertionError.createFailed(Int32(truncatingIfNeeded: status))
        }
        id = created
        guard isActive else {
            try stop()
            throw PowerAssertionError.readbackMismatch
        }
    }

    public func stop() throws {
        guard let owned = id else { return }
        let status = IOPMAssertionRelease(owned)
        guard status == kIOReturnSuccess else {
            throw PowerAssertionError.releaseFailed(Int32(truncatingIfNeeded: status))
        }
        id = nil
    }

    deinit {
        do { try stop() }
        catch { FileHandle.standardError.write(Data("PowerAssertion cleanup failed: \(error)\n".utf8)) }
    }
}
