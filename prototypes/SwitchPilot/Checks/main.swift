import Foundation
import IOKit.pwr_mgt
import PilotCore

struct CheckFailure: Error { let message: String }
func check(_ condition: Bool, _ message: String) throws {
    if !condition { throw CheckFailure(message: message) }
}
func expectError(_ expected: PilotError, _ operation: () throws -> Void) throws {
    do { try operation() }
    catch let error as PilotError {
        try check(error == expected, "wrong error: \(error)")
        return
    }
    throw CheckFailure(message: "operation unexpectedly succeeded")
}

let checks: [(String, () throws -> Void)] = [
    ("bounded finite duration", {
        for value in ["0", "-1", "61", "nan", "inf", "hello"] {
            try expectError(.invalidDuration) { _ = try holdDuration(value) }
        }
        try check(holdDuration("0.1") == 0.1, "fractional duration changed")
        try check(holdDuration("60") == 60, "valid upper bound rejected")
    }),
    ("Automation failures are errors", {
        try requireAutomationPermission(0)
        for status: Int32 in [-1743, -1744, -600] {
            try expectError(.automation(status)) { try requireAutomationPermission(status) }
        }
    }),
    ("three real assertion cycles and idempotent ownership", {
        let assertion = PowerAssertion()
        defer { try? assertion.stop() }
        for _ in 0..<3 {
            try assertion.start()
            guard let id = assertion.id else { throw CheckFailure(message: "missing live assertion ID") }
            guard let raw = IOPMAssertionCopyProperties(id)?.takeRetainedValue() else {
                throw CheckFailure(message: "assertion missing in OS")
            }
            let properties = raw as NSDictionary
            try check(properties[kIOPMAssertionTypeKey] as? String == "PreventUserIdleDisplaySleep", "wrong assertion kind")
            try check((properties[kIOPMAssertionLevelKey] as? NSNumber)?.intValue == 255, "OS assertion is not active")
            try check(assertion.isActive, "owner state disagrees with OS")
            try assertion.start()
            try check(assertion.id == id, "duplicate start changed ownership")
            try assertion.stop()
            try check(IOPMAssertionCopyProperties(id)?.takeRetainedValue() == nil, "assertion leaked after stop")
            try check(assertion.id == nil, "owner retained released ID")
            try assertion.stop()
        }
    }),
    ("owner deinit releases real assertion", {
        var owner: PowerAssertion? = PowerAssertion()
        try owner?.start()
        guard let id = owner?.id else { throw CheckFailure(message: "missing live assertion ID") }
        owner = nil
        try check(IOPMAssertionCopyProperties(id)?.takeRetainedValue() == nil, "deinit leaked assertion")
    })
]
var failures = 0
for (name, body) in checks {
    do { try body(); print("PASS: \(name)") }
    catch { failures += 1; print("FAIL: \(name): \(error)") }
}
print("\(checks.count - failures)/\(checks.count) checks passed")
exit(failures == 0 ? 0 : 1)
