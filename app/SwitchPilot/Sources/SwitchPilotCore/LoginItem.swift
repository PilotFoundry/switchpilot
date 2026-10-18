import ServiceManagement

public enum LoginItemState: Equatable, CustomStringConvertible {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
    case unknown(Int)

    public init(status: SMAppService.Status) {
        switch status {
        case .notRegistered: self = .notRegistered
        case .enabled: self = .enabled
        case .requiresApproval: self = .requiresApproval
        case .notFound: self = .notFound
        @unknown default: self = .unknown(Int(status.rawValue))
        }
    }

    public var description: String {
        switch self {
        case .notRegistered: return "未开启"
        case .enabled: return "已开启"
        case .requiresApproval: return "已注册，等待系统批准"
        case .notFound: return "未开启（尚未注册）"
        case .unknown(let raw): return "未知状态 (\(raw))"
        }
    }
}

public enum LoginItemError: Error, CustomStringConvertible {
    case registration(String)
    case unregistration(String)

    public var description: String {
        switch self {
        case .registration(let message): return "开启登录时启动失败：\(message)"
        case .unregistration(let message): return "关闭登录时启动失败：\(message)"
        }
    }
}

/// Login-at-start support through the public ServiceManagement API (macOS 13+).
/// Requires a code-signed app bundle; ad-hoc signatures may be refused by the
/// system and the app should surface the real error instead of pretending success.
public enum LoginItem {
    public static var state: LoginItemState {
        LoginItemState(status: SMAppService.mainApp.status)
    }

    public static func enable() throws {
        do {
            try SMAppService.mainApp.register()
        } catch {
            throw LoginItemError.registration(error.localizedDescription)
        }
    }

    public static func disable() throws {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            throw LoginItemError.unregistration(error.localizedDescription)
        }
    }

    public static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
