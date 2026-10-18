import AppKit
import SwiftUI
import SwitchPilotCore

@MainActor
final class PanelModel: ObservableObject {
    @Published private(set) var keepAwakeActive = false
    @Published private(set) var keepAwakeRemaining: String = "未开启"
    @Published private(set) var keepAwakeError: String?
    @Published var preset: KeepAwakePreset = .unlimited

    @Published private(set) var systemIsDark = false
    @Published private(set) var darkModePermission: AutomationState = .notDetermined
    @Published private(set) var darkModeStatus = ""
    @Published private(set) var darkModeError: String?
    @Published private(set) var darkModeBusy = false

    @Published private(set) var screenSaverStatus = "未执行"
    @Published private(set) var lockStatus = "未执行"
    @Published private(set) var lockPermissions = LockPermissions(automation: .notDetermined, accessibilityTrusted: false)

    private let session = KeepAwakeSession()
    private var didShutdown = false

    init() {
        session.onChange = { [weak self] in
            Task { @MainActor in self?.refreshKeepAwake() }
        }
        refresh()
    }

    var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        return short
    }

    // MARK: - Refresh

    func refresh() {
        systemIsDark = DarkMode.currentAppearanceIsDark()
        darkModePermission = Permissions.automationStatus()
        lockPermissions = LockScreen.permissions()
        refreshKeepAwake()
    }

    private func refreshKeepAwake() {
        keepAwakeActive = session.isActive
        if let remaining = session.remainingSeconds {
            let minutes = remaining / 60
            let seconds = remaining % 60
            keepAwakeRemaining = String(format: "剩余 %02d:%02d", minutes, seconds)
        } else if session.isActive {
            keepAwakeRemaining = "无限期（直到关闭或退出）"
        } else {
            keepAwakeRemaining = "未开启"
        }
    }

    // MARK: - Keep awake

    func setKeepAwake(_ enabled: Bool) {
        do {
            if enabled {
                try session.start(minutes: preset.minutes)
                keepAwakeError = nil
            } else {
                session.stop()
                keepAwakeError = nil
            }
        } catch {
            keepAwakeError = "\(error)"
        }
        refreshKeepAwake()
    }

    func setPreset(_ value: KeepAwakePreset) {
        preset = value
        if keepAwakeActive {
            setKeepAwake(true)
        }
    }

    // MARK: - Dark mode

    func setDarkMode(_ enabled: Bool) {
        guard !darkModeBusy else { return }
        darkModeBusy = true
        defer { darkModeBusy = false }
        darkModeError = nil
        let state = Permissions.automationStatus()
        darkModePermission = state
        guard state == .allowed else {
            darkModeStatus = "需要授权后才能切换（当前：\(state.description)）"
            return
        }
        do {
            try DarkMode.set(enabled)
            systemIsDark = enabled
            darkModeStatus = enabled ? "已切换为深色模式" : "已切换为浅色模式"
        } catch {
            darkModeError = "\(error)"
            darkModeStatus = "切换失败，系统外观未被确认修改"
            systemIsDark = DarkMode.currentAppearanceIsDark()
        }
    }

    func requestDarkModeAuthorization() {
        guard !darkModeBusy else { return }
        darkModeBusy = true
        darkModePermission = DarkMode.requestPermission()
        darkModeStatus = darkModePermission == .allowed ? "已授权，可以切换" : "授权未完成：\(darkModePermission.description)"
        darkModeBusy = false
    }

    // MARK: - Screen saver

    func startScreenSaver() {
        guard confirm(
            title: "启动屏幕保护？",
            message: "将立即启动系统屏幕保护。如果系统设置为唤醒需要密码，可能需要先解锁。",
            confirmTitle: "启动") else { return }
        ScreenSaver.start { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success:
                    self.screenSaverStatus = ScreenSaver.isRunning() ? "已启动（进程可见）" : "已请求启动（未确认）"
                case .failure(let error):
                    self.screenSaverStatus = "失败：\(error)"
                }
            }
        }
    }

    // MARK: - Lock screen

    func lockScreen() {
        lockPermissions = LockScreen.permissions()
        guard lockPermissions.canAttempt else {
            lockStatus = "未执行：缺少权限"
            presentLockPermissionsAlert()
            return
        }
        guard confirm(
            title: "锁定屏幕？",
            message: "屏幕将立即锁定；如果系统要求密码，需要输入密码解锁。",
            confirmTitle: "锁定") else { return }
        do {
            try LockScreen.lock()
            lockStatus = "已请求锁定，确认中…"
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if let locked = LockScreen.isLocked() {
                    lockStatus = locked ? "已锁定" : "已请求锁定（读回未锁定）"
                } else {
                    lockStatus = "已请求锁定（未确认）"
                }
            }
        } catch {
            lockStatus = "失败：\(error)"
        }
    }

    func requestLockAutomation() {
        let state = LockScreen.requestAutomationPermission()
        lockPermissions = LockScreen.permissions()
        lockStatus = state == .allowed ? "自动化已授权；辅助功能仍为 \(lockPermissions.accessibilityTrusted ? "已授权" : "未授权")" : "自动化状态：\(state.description)"
    }

    func openAccessibilitySettings() {
        openSystemSettings(path: "Privacy_Accessibility")
    }

    func openAutomationSettings() {
        openSystemSettings(path: "Privacy_Automation")
    }

    // MARK: - Lifecycle

    func shutdown() {
        guard !didShutdown else { return }
        didShutdown = true
        session.stop()
    }

    func quit() {
        shutdown()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Helpers

    private func openSystemSettings(path: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(path)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func confirm(title: String, message: String, confirmTitle: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func presentLockPermissionsAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "锁定屏幕需要额外权限"
        alert.informativeText = """
        \(lockPermissions.summary)

        锁定屏幕使用与系统快捷键 Ctrl+Cmd+Q 等价的 System Events 按键注入：
        · Automation 授权用于向 System Events 发送指令；
        · 辅助功能授权用于按键注入。
        缺少权限时不会发送按键。
        """
        alert.addButton(withTitle: "请求 Automation 授权")
        alert.addButton(withTitle: "打开辅助功能设置")
        alert.addButton(withTitle: "取消")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            requestLockAutomation()
        } else if response == .alertSecondButtonReturn {
            openAccessibilitySettings()
        }
    }
}
