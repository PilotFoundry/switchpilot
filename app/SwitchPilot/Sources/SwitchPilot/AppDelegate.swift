import AppKit
import SwiftUI
import SwitchPilotCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var model: PanelModel?
    private var settingsModel: SettingsModel?
    private var settingsWindow: SettingsWindowController?
    private var hosting: NSHostingController<PanelView>?

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        let model = PanelModel()
        self.model = model
        model.onOpenSettings = { [weak self] in self?.openSettings() }
        model.onContentSizeChanged = { [weak self] in self?.resizePopover() }

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
        let guideItem = NSMenuItem(title: "使用说明", action: #selector(menuShowGuide), keyEquivalent: "")
        guideItem.target = self
        let quitItem = NSMenuItem(title: "退出 SwitchPilot", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(settingsItem)
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

    @MainActor func openSettings() {
        if settingsWindow == nil {
            let settingsModel = SettingsModel()
            self.settingsModel = settingsModel
            settingsWindow = SettingsWindowController(model: settingsModel)
        }
        settingsModel?.refreshAsync()
        settingsWindow?.present()
    }

    @MainActor func applicationWillTerminate(_ notification: Notification) {
        model?.shutdown()
    }
}
