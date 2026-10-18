import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?

    convenience init(model: SettingsModel) {
        let hosting = NSHostingController(rootView: SettingsView(model: model))
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: hosting)
        window.title = "SwitchPilot 设置"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.center()
        self.init(window: window)
        window.delegate = self
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    func present() {
        if let controller = window?.contentViewController {
            controller.view.layoutSubtreeIfNeeded()
            let size = controller.preferredContentSize
            if size.height > 100 {
                window?.setContentSize(NSSize(width: max(size.width, 460), height: size.height))
            }
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
}
