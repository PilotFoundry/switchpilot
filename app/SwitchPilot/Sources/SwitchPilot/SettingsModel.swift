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

    init() {
        refreshAsync()
    }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.0"
    }

    var diagnostic: String {
        "应用位置：\(Bundle.main.bundlePath) · Automation：\(automation.description) · 辅助功能：\(accessibilityTrusted ? "已授权" : "未授权")"
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
                completion?()
            }
        }
    }

    /// Same explicit flow as the panel: request Automation, then open the
    /// Accessibility pane because macOS has no programmatic grant for it.
    func requestAllPermissions() {
        guard !busy else { return }
        busy = true
        message = "正在请求 Automation 授权…"
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
                    self.message = "所需权限已就绪。"
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
        message = accessibilityTrusted ? "辅助功能已授权。" : "辅助功能仍未授权，请在系统设置中勾选 SwitchPilot。"
        refreshAsync()
    }

    func recheck() {
        busy = true
        refreshAsync { [weak self] in
            guard let self else { return }
            self.busy = false
            self.message = self.permissionsReady ? "所需权限已就绪。" : "权限仍未就绪。可再次使用“申请全部权限”。"
        }
    }

    func openAutomationSettings() {
        Permissions.openAutomationSettings()
    }

    func openAccessibilitySettings() {
        Permissions.openAccessibilitySettings()
    }

    func setLoginItem(_ enabled: Bool) {
        busy = true
        defer { busy = false }
        do {
            if enabled {
                try LoginItem.enable()
                message = "已开启登录时启动。"
            } else {
                try LoginItem.disable()
                message = "已关闭登录时启动。"
            }
        } catch {
            message = "\(error)"
        }
        refreshAsync()
        if loginState == .requiresApproval {
            message = "已注册，但还需要在系统设置中批准。"
        }
    }

    func openLoginItemsSettings() {
        LoginItem.openSystemSettings()
    }
}
