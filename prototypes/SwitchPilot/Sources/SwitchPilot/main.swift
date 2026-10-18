import Foundation
import PilotCore

func emit(_ message: String) {
    FileHandle.standardOutput.write(Data((message + "\n").utf8))
}
do {
    let args = Array(CommandLine.arguments.dropFirst())
    switch args.first {
    case "awake":
        guard args.count == 2 else { throw PilotError.invalidDuration }
        let seconds = try holdDuration(args[1])
        let assertion = PowerAssertion()
        try assertion.start()
        emit("ACTIVE pid=\(ProcessInfo.processInfo.processIdentifier) id=\(assertion.id!) readback=\(assertion.isActive)")
        Thread.sleep(forTimeInterval: seconds)
        try assertion.stop()
        emit("RELEASED readback=\(assertion.isActive)")
    case "dark-probe":
        let status = DarkMode.permissionStatus()
        emit("AUTOMATION status=\(status) askUserIfNeeded=false")
        try requireAutomationPermission(status)
        emit("DARK \(try DarkMode.read())")
    case "dark-cycle":
        // shortcut: manual pilot only; production needs scheduling and external-change arbitration.
        let original = try DarkMode.read()
        emit("ORIGINAL \(original)")
        do {
            for cycle in 1...3 {
                try DarkMode.set(!original)
                try DarkMode.set(original)
                emit("CYCLE \(cycle) restored=\(try DarkMode.read())")
            }
        } catch {
            let failure = error
            do { try DarkMode.set(original); emit("RESTORED after failure") }
            catch {
                FileHandle.standardError.write(Data("RESTORE FAILED: \(error); original=\(original)\n".utf8))
            }
            throw failure
        }
    default:
        emit("Research only. Commands: awake <seconds: 0 < n <= 60>, dark-probe, dark-cycle")
    }
} catch {
    FileHandle.standardError.write(Data("FAILED: \(error)\n".utf8))
    exit(1)
}
