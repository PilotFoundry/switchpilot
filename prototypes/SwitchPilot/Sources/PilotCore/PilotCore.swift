import Foundation
public enum PilotError: Error, Equatable {
    case invalidDuration
    case automation(Int32)
    case power(Int32)
    case script(String)
    case readbackMismatch
}
public func holdDuration(_ value: String) throws -> Double { 0 }
public func requireAutomationPermission(_ status: Int32) throws {}
public final class PowerAssertion {
    public private(set) var id: UInt32?
    public init() {}
    public func start() throws {}
    public func stop() throws {}
}
