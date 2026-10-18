import AppKit
import SwiftUI
import SwitchPilotCore

@MainActor
final class PanelModel: ObservableObject {
    @Published private(set) var keepAwakeActive = false
    @Published private(set) var keepAwakeRemaining: String = L("未开启")
    @Published private(set) var keepAwakeProgress: Double?
    @Published private(set) var keepAwakeError: String?
    @Published var preset: KeepAwakePreset = .unlimited

    @Published private(set) var systemIsDark = false
    @Published private(set) var darkModePermission: AutomationState = .notDetermined
    @Published private(set) var darkModeStatus = ""
    @Published private(set) var darkModeError: String?
    @Published private(set) var darkModeBusy = false

    @Published private(set) var screenSaverStatus = L("未执行")
    @Published private(set) var lockStatus = L("未执行")
    @Published private(set) var displaySleepStatus = L("未执行")
    @Published private(set) var microphoneState = MicrophoneDevice(
        deviceID: 0, name: L("正在读取…"), supportsMute: false, muted: nil, message: nil)
    @Published private(set) var microphoneError = ""
    @Published private(set) var screenCleaningStatus = L("未执行")
    @Published private(set) var screenCleaningError = ""
    @Published private(set) var screenCleaningNeedsAccessibility = false
    @Published private(set) var screenCleaningActive = false
    @Published private(set) var lockPermissions = LockPermissions(automation: .notDetermined, accessibilityTrusted: false)
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var permissionSetupMessage = ""
    @Published private(set) var permissionBusy = false

    @Published private(set) var hasSeenWelcome: Bool
    @Published var showGuide: Bool

    var onOpenSettings: (() -> Void)?
    var onContentSizeChanged: (() -> Void)?

    private let session = KeepAwakeSession()
    private let screenCleaning = ScreenCleaningManager()
    private var didShutdown = false

    init() {
        let seen = UserDefaults.standard.bool(forKey: "switchpilot.hasSeenWelcome")
        hasSeenWelcome = seen
        showGuide = !seen
        session.onChange = { [weak self] in
            Task { @MainActor in self?.refreshKeepAwake() }
        }
        screenCleaning.onStateChange = { [weak self] active, message in
            Task { @MainActor in
                self?.screenCleaningActive = active
                self?.screenCleaningStatus = message
                if active {
                    self?.screenCleaningError = ""
                    self?.screenCleaningNeedsAccessibility = false
                }
            }
        }
        refreshAsync()
    }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.7.8"
    }

    var statusTitle: String {
        keepAwakeActive ? L("保护中") : L("保活关闭")
    }

    var guideVisible: Bool { !hasSeenWelcome || showGuide }

    var darkModeNeedsPermission: Bool {
        darkModePermission != .allowed
    }

    var lockNeedsPermission: Bool {
        !lockPermissions.canAttempt
    }

    var permissionsSummary: String {
        LF("权限：Automation %@ · 辅助功能 %@", darkModePermission.userFacingDescription, accessibilityTrusted ? L("已授权") : L("未授权"))
    }

    var allPermissionsReady: Bool {
        darkModePermission == .allowed && accessibilityTrusted
    }

    // MARK: - Refresh

    /// Synchronous preflight for immediate display; prefer refreshAsync for user-visible refreshes.
    func refresh() {
        systemIsDark = DarkMode.currentAppearanceIsDark()
        darkModePermission = Permissions.automationStatusResolvingTarget()
        lockPermissions = LockScreen.permissions()
        accessibilityTrusted = Permissions.accessibilityTrusted()
        refreshKeepAwake()
        refreshMicrophone()
    }

    /// AEDeterminePermissionToAutomateTarget may block; probe off the main thread
    /// and publish results on the main actor.
    func refreshAsync(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let automation = Permissions.automationStatusResolvingTarget()
            let lock = LockScreen.permissions()
            let accessibility = Permissions.accessibilityTrusted()
            let dark = DarkMode.currentAppearanceIsDark()
            let microphone = Microphone.read()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.darkModePermission = automation
                self.lockPermissions = lock
                self.accessibilityTrusted = accessibility
                self.systemIsDark = dark
                self.microphoneState = microphone
                self.microphoneError = ""
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
            keepAwakeRemaining = LF("剩余 %02d:%02d", minutes, seconds)
        } else if session.isActive {
            keepAwakeRemaining = L("无限期 · 直到关闭或退出")
        } else {
            keepAwakeRemaining = L("未开启")
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

    func toggleKeepAwake() {
        setKeepAwake(!keepAwakeActive)
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
            darkModeStatus = L("需要授权后才能切换")
            return
        }
        do {
            try DarkMode.set(enabled)
            systemIsDark = enabled
            darkModeStatus = enabled ? L("已切换为深色模式") : L("已切换为浅色模式")
        } catch {
            darkModeError = "\(error)"
            darkModeStatus = L("切换失败，系统外观未被确认修改")
            systemIsDark = DarkMode.currentAppearanceIsDark()
        }
    }

    /// Explicit Automation-only request (used by the appearance row).
    func requestDarkModeAuthorization() {
        guard !permissionBusy else { return }
        permissionBusy = true
        permissionSetupMessage = L("正在请求 Automation 授权…")
        DispatchQueue.global(qos: .userInitiated).async {
            var state = Permissions.requestAutomation()
            if state == .targetNotRunning {
                state = Permissions.automationStatusResolvingTarget()
            }
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
        permissionSetupMessage = L("正在请求 Automation 授权…")
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
                    ? L("辅助功能已授权。")
                    : L("辅助功能仍未授权：请在系统设置 › 隐私与安全性 › 辅助功能中勾选 SwitchPilot。")
                self.refreshAsync()
            }
        }
    }

    func requestLockAutomation() {
        guard !permissionBusy else { return }
        permissionBusy = true
        permissionSetupMessage = L("正在请求 Automation 授权…")
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
                        ? L("锁定屏幕所需权限已就绪。")
                        : "Automation 已授权；锁屏仍需要辅助功能授权。"
                } else {
                    self.permissionSetupMessage = "Automation 未授权：\(state.userFacingDescription)。"
                }
            }
        }
    }

    private func updatePermissionMessage(automation: AutomationState) {
        if allPermissionsReady {
            permissionSetupMessage = L("所需权限已就绪。")
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
        permissionSetupMessage = L("正在检查权限…")
        refreshAsync { [weak self] in
            guard let self else { return }
            self.permissionBusy = false
            self.permissionSetupMessage = self.allPermissionsReady ? L("所需权限已就绪。") : LF("权限仍未就绪：%@", self.permissionsSummary)
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


    /// Preview-only helper for `--dump-panel`: does not touch microphone hardware.
    func previewMicrophone(muted: Bool) {
        microphoneState = MicrophoneDevice(
            deviceID: 1, name: L("MacBook Pro 麦克风"), supportsMute: true,
            muted: muted, message: nil)
    }

    // MARK: - Guide

    /// Preview-only helper for screenshots: makes permission cards disappear
    /// without touching TCC or persisted state.
    func previewAuthorized() {
        hasSeenWelcome = true
        showGuide = false
        darkModePermission = .allowed
        lockPermissions = LockPermissions(automation: .allowed, accessibilityTrusted: true)
        accessibilityTrusted = true
        systemIsDark = false
    }

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
        // Interaction policy (v0.3.8): a clearly labelled, common, reversible
        // action runs immediately; only irreversible/high-risk actions confirm.
        ScreenSaver.start { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success:
                    self.screenSaverStatus = L("未执行")
                case .failure(let error):
                    self.screenSaverStatus = LF("失败：%@", String(describing: error))
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
            lockStatus = L("未执行")
            if permissions.automation != .allowed {
                requestLockAutomation()
            } else {
                requestAccessibilityPrompt()
            }
            return
        }
        // The tile is already an explicit action with a clear label; the user
        // asked to drop the extra confirmation so locking matches the system
        // shortcut's immediacy. Permission gating still happens above.
        do {
            try LockScreen.lock()
            lockStatus = L("未执行")
        } catch {
            lockStatus = LF("失败：%@", String(describing: error))
            lockPermissions = LockScreen.permissions()
        }
    }

    // MARK: - Microphone mute

    func refreshMicrophone() {
        DispatchQueue.global(qos: .userInitiated).async {
            let state = Microphone.read()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.microphoneState = state
                self.microphoneError = ""
            }
        }
    }

    func toggleMicrophoneMute() {
        guard microphoneState.supportsMute else { return }
        let target = !(microphoneState.muted ?? false)
        if Microphone.setMuted(target) {
            refreshMicrophone()
        } else {
            microphoneError = L("切换麦克风静音失败；输入设备可能已变化")
            refreshMicrophone()
        }
    }

    // MARK: - Screen cleaning

    func startScreenCleaning() {
        guard !screenCleaningActive else { return }
        screenCleaningError = ""
        screenCleaningNeedsAccessibility = false
        guard Permissions.accessibilityTrusted() else {
            screenCleaningStatus = L("需要辅助功能授权才能锁定键盘输入")
            screenCleaningError = L("需要辅助功能授权；不会进入清洁模式")
            screenCleaningNeedsAccessibility = true
            _ = Permissions.accessibilityPrompt()
            return
        }
        do {
            // Normal mode has no timer/countdown; an env var is available only
            // for controlled tests that need an automatic exit.
            let testSeconds = ProcessInfo.processInfo.environment["SWITCHPILOT_CLEAN_SCREEN_TEST_SECONDS"]
                .flatMap(Int.init)
            try screenCleaning.start(duration: testSeconds)
        } catch {
            screenCleaningStatus = "\(error)"
            screenCleaningError = "\(error)"
            screenCleaningNeedsAccessibility = !Permissions.accessibilityTrusted()
        }
    }

    // MARK: - Display sleep

    func sleepDisplay() {
        displaySleepStatus = L("正在请求…")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try DisplaySleep.request()
                DispatchQueue.main.async { [weak self] in
                    self?.displaySleepStatus = L("未执行")
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.displaySleepStatus = LF("失败：%@", String(describing: error))
                }
            }
        }
    }

    // MARK: - Lifecycle

    func shutdown() {
        guard !didShutdown else { return }
        didShutdown = true
        screenCleaning.stop()
        session.stop()
    }

    func quit() {
        shutdown()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Helpers

}
