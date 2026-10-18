import Foundation
import IOKit.pwr_mgt
import SwitchPilotCore

struct CheckFailure: Error { let message: String }

func check(_ condition: Bool, _ message: String) throws {
    if !condition { throw CheckFailure(message: message) }
}

func expectError<T: Error & Equatable>(_ expected: T, _ operation: () throws -> Void) throws {
    do {
        try operation()
    } catch let error as T {
        try check(error == expected, "wrong error: \(error), expected \(expected)")
        return
    }
    throw CheckFailure(message: "operation unexpectedly succeeded")
}

let checks: [(String, () throws -> Void)] = [
    ("preset mapping", {
        try check(KeepAwakePreset.minutes15.minutes == 15, "15 minute preset changed")
        try check(KeepAwakePreset.minutes30.minutes == 30, "30 minute preset changed")
        try check(KeepAwakePreset.minutes60.minutes == 60, "60 minute preset changed")
        try check(KeepAwakePreset.unlimited.minutes == nil, "unlimited preset must not have a duration")
    }),
    ("invalid durations rejected", {
        for value in [0.0, -1.0, Double.infinity, Double.nan] {
            try expectError(KeepAwakeError.invalidDuration) {
                try KeepAwakeSession().start(seconds: value)
            }
        }
    }),
    ("automation status mapping", {
        try check(AutomationState(osStatus: 0) == .allowed, "noErr must map to allowed")
        try check(AutomationState(osStatus: -1743) == .denied, "-1743 must map to denied")
        try check(AutomationState(osStatus: -1744) == .notDetermined, "-1744 must map to notDetermined")
        try check(AutomationState(osStatus: -600) == .targetNotRunning, "-600 must map to targetNotRunning")
        try check(AutomationState(osStatus: -1) == .failed(-1), "unknown status must be preserved")
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
    }),
    ("timed session releases assertion", {
        let session = KeepAwakeSession()
        var changeCount = 0
        session.onChange = { changeCount += 1 }
        try session.start(seconds: 0.4)
        try check(session.isActive, "timed session did not start")
        guard let id = session.liveAssertionID else { throw CheckFailure(message: "no assertion ID for timed session") }
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        try check(!session.isActive, "timed session did not auto-release")
        try check(session.liveAssertionID == nil, "timed session leaked its assertion")
        try check(IOPMAssertionCopyProperties(id)?.takeRetainedValue() == nil, "timed assertion still present in OS")
        try check(changeCount > 0, "session never reported a state change")
    }),
    ("dark mode global appearance read", {
        let dark = DarkMode.currentAppearanceIsDark()
        print("  appearance dark=\(dark)")
        try check(Permissions.automationStatus() != .failed(0), "permission state must be a defined value")
    }),
    ("screen saver engine resolvable", {
        try check(ScreenSaver.isAvailable, "ScreenSaverEngine is not resolvable")
        if let url = ScreenSaver.engineURL {
            print("  engine=\(url.path)")
        }
    }),
    ("lock screen refuses to run without permissions", {
        let permissions = LockScreen.permissions()
        print("  permissions: \(permissions.summary)")
        if permissions.canAttempt {
            print("  SKIP: permissions already granted on this machine")
            return
        }
        do {
            try LockScreen.lock()
            throw CheckFailure(message: "lock screen executed without Automation+Accessibility")
        } catch let error as LockScreenError {
            if case .permissions = error {
                return
            }
            throw CheckFailure(message: "unexpected lock error: \(error)")
        }
    })
]

var failures = 0
for (name, body) in checks {
    do {
        try body()
        print("PASS: \(name)")
    } catch {
        failures += 1
        print("FAIL: \(name): \(error)")
    }
}
print("\(checks.count - failures)/\(checks.count) checks passed")
exit(failures == 0 ? 0 : 1)
