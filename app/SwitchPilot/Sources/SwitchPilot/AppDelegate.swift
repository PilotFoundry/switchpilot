import AppKit
import Combine
import SwiftUI
import SwitchPilotCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var model: PanelModel?
    private var settingsModel: SettingsModel?
    private var settingsWindow: SettingsWindowController?
    private var externalSettingsWatch: Timer?
    private var sawSystemSettingsFrontmost = false
    private var externalWatchStartedAt: Date?
    private var hosting: NSHostingController<PanelView>?
    private var hotKeys: HotKeyManager?
    private var microphoneMuted = false
    private var microphoneCancellable: AnyCancellable?

    @MainActor func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "switchpilot" && $0.host == "diagnose" }) else { return }
        writeRuntimeDiagnostics()
    }

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        let model = PanelModel()
        self.model = model
        model.onOpenSettings = { [weak self] in self?.openSettings() }
        model.onContentSizeChanged = { [weak self] in self?.resizePopover() }

        let hotKeys = HotKeyManager()
        hotKeys.onKeepAwakeToggle = { [weak model] in model?.toggleKeepAwake() }
        hotKeys.onScreenSaver = { [weak model] in model?.startScreenSaver() }
        hotKeys.startIfEnabled()
        self.hotKeys = hotKeys

        microphoneCancellable = model.$microphoneState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.microphoneMuted = state.muted == true
                self?.updateMicrophoneStatusItem()
            }

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = StatusIcon.make(size: 18)
            button.image = image
            button.toolTip = "SwitchPilot"
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }

        let hosting = NSHostingController(rootView: PanelView(model: model))
        hosting.sizingOptions = [.preferredContentSize]
        self.hosting = hosting
        let popover = NSPopover()
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 380, height: 620)

        self.statusItem = statusItem
        self.popover = popover

        if ProcessInfo.processInfo.environment["SWITCHPILOT_DEV"] == "1",
           ProcessInfo.processInfo.environment["SWITCHPILOT_OPEN_SETTINGS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.openSettings()
                if ProcessInfo.processInfo.environment["SWITCHPILOT_OPEN_SYSTEM_SETTINGS"] == "1" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                        self?.settingsModel?.openAutomationSettings()
                    }
                }
                if ProcessInfo.processInfo.environment["SWITCHPILOT_EXPAND_REVOKE"] == "1" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                        self?.settingsModel?.previewExpandRevoke()
                    }
                }
            }
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.workspaceAppActivated(note) }
        }
        workspaceCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.workspaceAppTerminated(note) }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.model?.refreshAsync()
                self?.settingsModel?.refreshAsync()
            }
        }
    }

    @MainActor private func updateMicrophoneStatusItem() {
        guard let button = statusItem?.button else { return }
        button.image = StatusIcon.make(size: 18, microphoneMuted: microphoneMuted)
        button.toolTip = microphoneMuted ? "SwitchPilot · 麦克风已静音" : "SwitchPilot"
    }

    @MainActor @objc private func statusItemClicked(_ sender: Any?) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showStatusMenu()
        } else {
            togglePopover(sender)
        }
    }

    @MainActor private func showStatusMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "设置…", action: #selector(menuOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        let microphoneItem = NSMenuItem(
            title: microphoneMuted ? "取消麦克风静音" : "静音麦克风",
            action: #selector(menuToggleMicrophone),
            keyEquivalent: "")
        microphoneItem.target = self
        microphoneItem.isEnabled = model?.microphoneState.supportsMute == true
        if model?.microphoneState.supportsMute != true {
            microphoneItem.title = "麦克风静音不可用"
        }
        let guideItem = NSMenuItem(title: "使用说明", action: #selector(menuShowGuide), keyEquivalent: "")
        guideItem.target = self
        let quitItem = NSMenuItem(title: "退出 SwitchPilot", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(microphoneItem)
        menu.addItem(guideItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @MainActor @objc private func menuOpenSettings() {
        openSettings()
    }

    @MainActor @objc private func menuToggleMicrophone() {
        model?.toggleMicrophoneMute()
    }

    @MainActor @objc private func menuShowGuide() {
        model?.showGuide = true
        showPopover()
    }

    @MainActor @objc private func menuQuit() {
        model?.quit()
    }

    @MainActor private func showPopover() {
        guard let button = statusItem?.button, let popover, !popover.isShown else { return }
        model?.refreshAsync()
        resizePopover()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @MainActor @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        showPopover()
    }

    @MainActor private func resizePopover() {
        guard let hosting, let popover else { return }
        hosting.view.layoutSubtreeIfNeeded()
        let size = hosting.preferredContentSize
        if size.height > 100 {
            let screenLimit = (NSScreen.main?.visibleFrame.height ?? 900) - 120
            popover.contentSize = NSSize(width: 380, height: min(size.height, max(480, screenLimit)))
        }
    }

    @MainActor private func workspaceAppActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        if app.bundleIdentifier == "com.apple.systempreferences" {
            sawSystemSettingsFrontmost = true
            return
        }
        guard sawSystemSettingsFrontmost, settingsWindow?.window != nil else { return }
        sawSystemSettingsFrontmost = false
        settingsWindow?.present()
        settingsModel?.refreshAsync()
    }

    @MainActor private func workspaceAppTerminated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "com.apple.systempreferences",
              settingsWindow?.window != nil else { return }
        sawSystemSettingsFrontmost = false
        settingsWindow?.present()
        settingsModel?.refreshAsync()
    }

    @MainActor private func startExternalSettingsWatch() {
        guard externalSettingsWatch == nil else { return }
        sawSystemSettingsFrontmost = false
        externalSettingsWatch = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollExternalSettings() }
        }
    }

    @MainActor private func stopExternalSettingsWatch() {
        externalSettingsWatch?.invalidate()
        externalSettingsWatch = nil
        sawSystemSettingsFrontmost = false
    }

    /// While the SwitchPilot settings window is open, notice when the user has
    /// been in System Settings and then leaves it (close/quit/switch back).
    /// Bring the settings window forward and refresh the real permission state;
    /// the user keeps a place to press "re-check" instead of losing the window.
    @MainActor private func pollExternalSettings() {
        guard settingsWindow?.window != nil else {
            stopExternalSettingsWatch()
            return
        }
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if front == "com.apple.systempreferences" {
            sawSystemSettingsFrontmost = true
            return
        }
        guard sawSystemSettingsFrontmost else { return }
        sawSystemSettingsFrontmost = false
        settingsWindow?.present()
        settingsModel?.refreshAsync()
    }

    @MainActor func openSettings() {
        if settingsWindow == nil {
            let settingsModel = SettingsModel(hotKeys: hotKeys)
            self.settingsModel = settingsModel
            let controller = SettingsWindowController(model: settingsModel)
            controller.onClose = { [weak self] in self?.stopExternalSettingsWatch() }
            settingsWindow = controller
        }
        settingsModel?.refreshAsync()
        settingsWindow?.present()
        startExternalSettingsWatch()
    }

    @MainActor func applicationWillTerminate(_ notification: Notification) {
        externalSettingsWatch?.invalidate()
        hotKeys?.stop()
        model?.shutdown()
    }
}
