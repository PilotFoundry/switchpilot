import AppKit
import SwiftUI
import SwitchPilotCore

@MainActor
final class SettingsModel: ObservableObject {
    @Published private(set) var automation: AutomationState = .notDetermined
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var loginState: LoginItemState = .notRegistered
    @Published private(set) var busy = false
    @Published private(set) var message = ""
    @Published private(set) var showsRevokeHelp = false
    @Published private(set) var showsDiagnostic = false
    @Published private(set) var showsAdvancedTCCUtil = false
    @Published private(set) var tccutilCopied = false
    private var copyResetWorkItem: DispatchWorkItem?
    private let hotKeys: HotKeyManager?

    @Published private(set) var hotKeysEnabled = false
    @Published private(set) var hotKeyError = ""
    @Published private(set) var language: AppLanguage = LanguagePreference.selected

    init(hotKeys: HotKeyManager? = nil) {
        self.hotKeys = hotKeys
        refreshHotKeys()
        refreshAsync()
    }

    var hotKeysAvailable: Bool { hotKeys != nil }

    var hotKeyCombos: String {
        LF("%@ 保持亮屏 · %@ 启动屏保", HotKeyManager.keepAwakeCombo, HotKeyManager.screenSaverCombo)
    }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.7.3"
    }

    var hasAnyPermission: Bool {
        automation == .allowed || accessibilityTrusted
    }

    var tccutilResetCommands: String {
        "tccutil reset AppleEvents \(Permissions.bundleIdentifier)\ntccutil reset Accessibility \(Permissions.bundleIdentifier)"
    }

    var diagnostic: String {
        LF("应用位置：%@ · Automation：%@ · 辅助功能：%@", Bundle.main.bundlePath, automation.description, accessibilityTrusted ? L("已授权") : L("未授权"))
    }

    var permissionsReady: Bool {
        automation == .allowed && accessibilityTrusted
    }

    func refresh() {
        automation = Permissions.automationStatusResolvingTarget()
        accessibilityTrusted = Permissions.accessibilityTrusted()
        loginState = LoginItem.state
    }

    func refreshAsync(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let automation = Permissions.automationStatusResolvingTarget()
            let access = Permissions.accessibilityTrusted()
            let login = LoginItem.state
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.automation = automation
                self.accessibilityTrusted = access
                self.loginState = login
                if !self.hasAnyPermission {
                    self.showsRevokeHelp = false
                    self.showsAdvancedTCCUtil = false
                }
                if self.permissionsReady {
                    self.showsDiagnostic = false
                }
                completion?()
            }
        }
    }

    /// Same explicit flow as the panel: request Automation, then open the
    /// Accessibility pane because macOS has no programmatic grant for it.
    func requestAllPermissions() {
        guard !busy else { return }
        busy = true
        message = L("正在请求 Automation 授权…")
        DispatchQueue.global(qos: .userInitiated).async {
            var state = Permissions.requestAutomation()
            if state == .targetNotRunning {
                state = Permissions.automationStatusResolvingTarget()
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.automation = state
                self.accessibilityTrusted = Permissions.accessibilityTrusted()
                if !self.accessibilityTrusted {
                    self.accessibilityTrusted = Permissions.accessibilityPrompt() || Permissions.accessibilityTrusted()
                }
                self.busy = false
                self.refreshAsync()
                if self.permissionsReady {
                    self.message = L("所需权限已就绪。")
                } else if !self.accessibilityTrusted {
                    self.message = state == .allowed
                        ? "Automation 已授权。请在辅助功能设置中勾选 SwitchPilot，然后点“重新检查”。"
                        : "Automation：\(state.userFacingDescription)；辅助功能未授权。"
                } else {
                    self.message = "Automation 尚未授权：\(state.userFacingDescription)。"
                }
            }
        }
    }

    func requestAccessibilityPrompt() {
        accessibilityTrusted = Permissions.accessibilityPrompt() || Permissions.accessibilityTrusted()
        message = accessibilityTrusted ? L("辅助功能已授权。") : L("辅助功能仍未授权，请在系统设置中勾选 SwitchPilot。")
        refreshAsync()
    }

    func recheck() {
        busy = true
        refreshAsync { [weak self] in
            guard let self else { return }
            self.busy = false
            self.message = self.permissionsReady ? L("所需权限已就绪。") : L("权限仍未就绪。可再次使用“申请全部权限”。")
        }
    }

    func openAutomationSettings() {
        Permissions.openAutomationSettings()
    }

    func openAccessibilitySettings() {
        Permissions.openAccessibilitySettings()
    }

    func setLoginItem(_ enabled: Bool) {
        guard !busy else { return }
        busy = true
        var failed = false
        do {
            if enabled {
                try LoginItem.enable()
            } else {
                try LoginItem.disable()
            }
        } catch {
            message = "\(error)"
            failed = true
        }
        busy = false
        refreshAsync { [weak self] in
            guard let self, !failed else { return }
            switch self.loginState {
            case .enabled:
                self.message = L("登录时启动已开启。")
            case .requiresApproval:
                self.message = L("已注册，但还需要在系统设置 › 通用 › 登录项中批准。")
            case .notFound:
                self.message = L("未找到登录项；请从 ~/Applications 的安装副本重试。")
            case .unknown:
                self.message = L("登录时启动状态未知，请在系统设置中检查。")
            case .notRegistered:
                self.message = L("登录时启动已关闭。")
            }
        }
    }

    func openLoginItemsSettings() {
        LoginItem.openSystemSettings()
    }

    func toggleRevokeHelp() {
        showsRevokeHelp.toggle()
        if !showsRevokeHelp {
            showsAdvancedTCCUtil = false
        }
    }

    func toggleAdvancedTCCUtil() {
        showsAdvancedTCCUtil.toggle()
    }

    func toggleDiagnostic() {
        showsDiagnostic.toggle()
    }

    func refreshHotKeys() {
        if let hotKeys {
            hotKeysEnabled = hotKeys.isEnabled && hotKeys.hasRegisteredHotKeys
            hotKeyError = hotKeys.lastError
        } else {
            hotKeysEnabled = UserDefaults.standard.bool(forKey: HotKeyManager.enabledDefaultsKey)
            hotKeyError = ""
        }
    }

    func setHotKeysEnabled(_ enabled: Bool) {
        guard let hotKeys else {
            hotKeyError = L("设置窗口未连接快捷键服务")
            return
        }
        if let error = hotKeys.setEnabled(enabled) {
            hotKeysEnabled = false
            hotKeyError = error
            message = error
        } else {
            hotKeysEnabled = hotKeys.isEnabled
            hotKeyError = ""
            message = enabled ? L("全局快捷键已启用。") : L("全局快捷键已停用。")
        }
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        LanguagePreference.set(language)
        message = L("语言已保存，重启应用后生效。")
    }

    func restartApp() {
        let path = Bundle.main.bundlePath
        let quoted = "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 0.8; /usr/bin/open \(quoted)"]
        try? process.run()
        NSApp.terminate(nil)
    }

    func resetInAppPermissions() {
        guard !busy else { return }
        busy = true
        message = L("正在应用内重置权限…")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Permissions.resetInAppPermissions()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.busy = false
                self.showsRevokeHelp = false
                self.showsAdvancedTCCUtil = false
                self.message = result.summary
                self.refreshAsync()
            }
        }
    }

    func copyTCCUtilResetCommands() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(tccutilResetCommands, forType: .string)
        tccutilCopied = true
        copyResetWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.tccutilCopied = false
        }
        copyResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }

    /// Preview-only helper for `--dump-settings`: does not touch TCC/user data.
    func previewAuthorizedPermissions() {
        automation = .allowed
        accessibilityTrusted = true
    }

    /// Preview-only helper for `--dump-settings`: does not touch TCC/user data.
    func previewExpandRevoke() {
        showsRevokeHelp = true
        showsAdvancedTCCUtil = true
    }
}
