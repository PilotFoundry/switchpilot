import AppKit
import SwiftUI
import SwitchPilotCore

@MainActor
final class PanelModel: ObservableObject {
    @Published private(set) var keepAwakeActive = false
    @Published private(set) var keepAwakeRemaining: String = "未开启"
    @Published private(set) var keepAwakeProgress: Double?
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

    @Published private(set) var hasSeenWelcome: Bool
    @Published var showGuide: Bool

    private let session = KeepAwakeSession()
    private var didShutdown = false

    init() {
        let seen = UserDefaults.standard.bool(forKey: "switchpilot.hasSeenWelcome")
        hasSeenWelcome = seen
        showGuide = !seen
        session.onChange = { [weak self] in
            Task { @MainActor in self?.refreshKeepAwake() }
        }
        refresh()
    }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    }

    var statusTitle: String {
        keepAwakeActive ? "保护中" : "空闲"
    }

    var darkModeNeedsPermission: Bool { !darkModePermission.canWrite }
    var lockNeedsPermission: Bool { !lockPermissions.canAttempt }

    var permissionsSummary: String {
        "Automation：\(darkModePermission.description) · 辅助功能：\(lockPermissions.accessibilityTrusted ? "已授权" : "未授权")"
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
        keepAwakeProgress = session.fractionRemaining
        if let remaining = session.remainingSeconds {
            let minutes = remaining / 60
            let seconds = remaining % 60
            keepAwakeRemaining = String(format: "剩余 %02d:%02d", minutes, seconds)
        } else if session.isActive {
            keepAwakeRemaining = "无限期 · 直到关闭或退出"
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
            darkModeStatus = "需要授权后才能切换"
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
        darkModeStatus = darkModePermission == .allowed ? "已授权，可以切换" : "授权未完成"
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
        lockStatus = state == .allowed ? "自动化已授权；辅助功能仍需检查" : "自动化状态：\(state.description)"
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

    func dismissGuide() {
        hasSeenWelcome = true
        showGuide = false
        UserDefaults.standard.set(true, forKey: "switchpilot.hasSeenWelcome")
    }

    func toggleGuide() {
        showGuide.toggle()
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
}
