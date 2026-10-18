import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var model: PanelModel?

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        let model = PanelModel()
        self.model = model

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "switch.2", accessibilityDescription: "SwitchPilot")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "SwitchPilot"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let hosting = NSHostingController(rootView: PanelView(model: model))
        hosting.sizingOptions = [.preferredContentSize]
        let popover = NSPopover()
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 640)

        self.statusItem = statusItem
        self.popover = popover
    }

    @MainActor @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        model?.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @MainActor func applicationWillTerminate(_ notification: Notification) {
        model?.shutdown()
    }
}
