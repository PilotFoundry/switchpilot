import AppKit
import Foundation

public enum ScreenSaverError: Error, CustomStringConvertible {
    case engineMissing
    case launchFailed(String)

    public var description: String {
        switch self {
        case .engineMissing: return "未找到系统屏幕保护引擎 (com.apple.ScreenSaver.Engine)"
        case .launchFailed(let message): return "启动屏幕保护失败：\(message)"
        }
    }
}

/// Starts the system screen saver by launching the shipped ScreenSaverEngine app.
///
/// This is the same system-facing mechanism the original application exposes; it
/// is a system-application launch, not a documented SDK API. No TCC permission is
/// required. A launch is not a proof that the screen saver is actually visible.
public enum ScreenSaver {
    public static let bundleIdentifier = "com.apple.ScreenSaver.Engine"

    public static var engineURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    public static var isAvailable: Bool { engineURL != nil }

    public static func isRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    /// Starts the screen saver; completion is delivered on the main queue.
    public static func start(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = engineURL else {
            completion(.failure(ScreenSaverError.engineMissing))
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(ScreenSaverError.launchFailed(error.localizedDescription)))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
}
