import Foundation

public enum DisplaySleepError: Error, CustomStringConvertible {
    case unavailable
    case commandFailed(Int32, String)

    public var description: String {
        switch self {
        case .unavailable: return L("系统未找到 pmset")
        case .commandFailed(let code, let message):
            return message.isEmpty ? LF("关闭显示器失败（退出码 %@）", String(code)) : LF("关闭显示器失败（%@）：%@", String(code), message)
        }
    }
}

/// Immediate display sleep through the public pmset CLI. No TCC grant is needed.
/// The screen wakes on the next user input; this is a one-shot action, not a
/// persistent power setting.
public enum DisplaySleep {
    public static let executablePath = "/usr/bin/pmset"
    public static let arguments = ["displaysleepnow"]

    public static var isAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: executablePath)
    }

    public static func request() throws {
        guard isAvailable else { throw DisplaySleepError.unavailable }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw DisplaySleepError.commandFailed(process.terminationStatus, text)
        }
    }
}
