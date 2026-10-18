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
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var permissionSetupMessage = ""
    @Published private(set) var permissionBusy = false

    @Published private(set) var hasSeenWelcome: Bool
    @Published var showGuide: Bool

    var onOpenSettings: (() -> Void)?
    var onContentSizeChanged: (() -> Void)?

    private let session = KeepAwakeSession()
    private var didShutdown = false

    init() {
        let seen = UserDefaults.standard.bool(forKey: "switchpilot.hasSeenWelcome")
        hasSeenWelcome = seen
        showGuide = !seen
        session.onChange = { [weak self] in
            Task { @MainActor in self?.refreshKeepAwake() }
        }
        refreshAsync()
    }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.0"
    }

    var statusTitle: String {
        keepAwakeActive ? "保护中" : "保活关闭"
    }

    var guideVisible: Bool { !hasSeenWelcome || showGuide }

    var darkModeNeedsPermission: Bool {
        darkModePermission != .allowed
    }

    var lockNeedsPermission: Bool {
        !lockPermissions.canAttempt
    }

    var permissionsSummary: String {
        "权限：Automation \(darkModePermission.userFacingDescription) · 辅助功能 \(accessibilityTrusted ? "已授权" : "未授权")"
    }

    var allPermissionsReady: Bool {
        darkModePermission == .allowed && accessibilityTrusted
    }

    // MARK: - Refresh

    /// Synchronous preflight for immediate display; prefer refreshAsync for user-visible refreshes.
    func refresh() {
        systemIsDark = DarkMode.currentAppearanceIsDark()
        darkModePermission = Permissions.automationStatus()
        lockPermissions = LockScreen.permissions()
        accessibilityTrusted = Permissions.accessibilityTrusted()
        refreshKeepAwake()
    }

    /// AEDeterminePermissionToAutomateTarget may block; probe off the main thread
    /// and publish results on the main actor.
    func refreshAsync(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let automation = Permissions.automationStatus()
            let lock = LockScreen.permissions()
            let accessibility = Permissions.accessibilityTrusted()
            let dark = DarkMode.currentAppearanceIsDark()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.darkModePermission = automation
                self.lockPermissions = lock
                self.accessibilityTrusted = accessibility
                self.systemIsDark = dark
                self.refreshKeepAwake()
                completion?()
            }
        }
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
        guard darkModePermission == .allowed else {
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

    /// Explicit Automation-only request (used by the appearance row).
    func requestDarkModeAuthorization() {
        guard !permissionBusy else { return }
        permissionBusy = true
        permissionSetupMessage = "正在请求 Automation 授权…"
        DispatchQueue.global(qos: .userInitiated).async {
            let state = Permissions.requestAutomation()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.darkModePermission = state
                self.permissionBusy = false
                self.refreshAsync()
                self.permissionSetupMessage = state == .allowed
                    ? "Automation 已授权，可以切换深色模式。"
                    : "Automation 未授权：\(state.userFacingDescription)。可在系统设置中开启。"
            }
        }
    }

    /// Request everything that can be requested: Automation through the system
    /// prompt, Accessibility through its consent prompt (macOS has no silent grant).
    func requestAllPermissions() {
        guard !permissionBusy else { return }
        permissionBusy = true
        permissionSetupMessage = "正在请求 Automation 授权…"
        DispatchQueue.global(qos: .userInitiated).async {
            let automation = Permissions.requestAutomation()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.darkModePermission = automation
                self.accessibilityTrusted = Permissions.accessibilityTrusted()
                if !self.accessibilityTrusted {
                    let trusted = Permissions.accessibilityPrompt()
                    self.accessibilityTrusted = trusted || Permissions.accessibilityTrusted()
                }
                self.permissionBusy = false
                self.refreshAsync()
                self.updatePermissionMessage(automation: automation)
            }
        }
    }

    /// Shows the Accessibility prompt again (for the lock-screen permission block).
    func requestAccessibilityPrompt() {
        DispatchQueue.global(qos: .userInitiated).async {
            let trusted = Permissions.accessibilityPrompt() || Permissions.accessibilityTrusted()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.permissionBusy = false
                self.permissionSetupMessage = trusted
                    ? "辅助功能已授权。"
                    : "辅助功能仍未授权：请在系统设置 › 隐私与安全性 › 辅助功能中勾选 SwitchPilot。"
                self.refreshAsync()
            }
        }
    }

    func requestLockAutomation() {
        guard !permissionBusy else { return }
        permissionBusy = true
        permissionSetupMessage = "正在请求 Automation 授权…"
        DispatchQueue.global(qos: .userInitiated).async {
            let state = LockScreen.requestAutomationPermission()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.lockPermissions = LockScreen.permissions()
                self.darkModePermission = state
                self.accessibilityTrusted = Permissions.accessibilityTrusted()
                self.permissionBusy = false
                self.refreshAsync()
                if state == .allowed {
                    self.permissionSetupMessage = self.accessibilityTrusted
                        ? "锁定屏幕所需权限已就绪。"
                        : "Automation 已授权；锁屏仍需要辅助功能授权。"
                } else {
                    self.permissionSetupMessage = "Automation 未授权：\(state.userFacingDescription)。"
                }
            }
        }
    }

    private func updatePermissionMessage(automation: AutomationState) {
        if allPermissionsReady {
            permissionSetupMessage = "所需权限已就绪。"
        } else if !accessibilityTrusted {
            permissionSetupMessage = automation == .allowed
                ? "Automation 已授权。请在系统提示或辅助功能设置中勾选 SwitchPilot，然后点“重新检查”。"
                : "Automation：\(automation.userFacingDescription)；辅助功能未授权。可先点“稍后再说”，保活与屏保仍可使用。"
        } else {
            permissionSetupMessage = "Automation：\(automation.userFacingDescription)。深色模式与锁屏暂不可用。"
        }
    }

    func recheckPermissions() {
        permissionBusy = true
        permissionSetupMessage = "正在检查权限…"
        refreshAsync { [weak self] in
            guard let self else { return }
            self.permissionBusy = false
            self.permissionSetupMessage = self.allPermissionsReady ? "所需权限已就绪。" : "权限仍未就绪：\(self.permissionsSummary)"
        }
    }

    func openSettings() {
        onOpenSettings?()
    }

    func openAutomationSettings() {
        Permissions.openAutomationSettings()
    }

    func openAccessibilitySettings() {
        Permissions.openAccessibilitySettings()
    }

    // MARK: - Guide

    func forceGuideForPreview() {
        hasSeenWelcome = false
        showGuide = true
    }

    /// Preview-only: hides the guide in memory without touching UserDefaults.
    func hideGuideForPreview() {
        hasSeenWelcome = true
        showGuide = false
    }

    func dismissGuide() {
        hasSeenWelcome = true
        showGuide = false
        UserDefaults.standard.set(true, forKey: "switchpilot.hasSeenWelcome")
        onContentSizeChanged?()
    }

    func toggleGuide() {
        showGuide.toggle()
        onContentSizeChanged?()
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
        permissionBusy = true
        DispatchQueue.global(qos: .userInitiated).async {
            let permissions = LockScreen.permissions()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.permissionBusy = false
                self.lockPermissions = permissions
                self.accessibilityTrusted = permissions.accessibilityTrusted
                self.presentLockFlow(permissions: permissions)
            }
        }
    }

    private func presentLockFlow(permissions: LockPermissions) {
        guard permissions.canAttempt else {
            lockStatus = "未执行：缺少权限"
            if permissions.automation != .allowed {
                requestLockAutomation()
            } else {
                requestAccessibilityPrompt()
            }
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
            lockPermissions = LockScreen.permissions()
        }
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
