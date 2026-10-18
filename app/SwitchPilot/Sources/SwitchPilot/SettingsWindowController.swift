import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?

    private let hosting: NSHostingController<SettingsView>
    private var sizeCancellable: AnyCancellable?

    init(model: SettingsModel) {
        let hosting = NSHostingController(rootView: SettingsView(model: model))
        hosting.sizingOptions = [.preferredContentSize]
        self.hosting = hosting

        let window = NSWindow(contentViewController: hosting)
        window.title = "SwitchPilot 设置"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.center()
        super.init(window: window)
        window.delegate = self

        // The revoke disclosure changes the content height after the window is
        // already on screen; keep the window sized to the hosting controller.
        sizeCancellable = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.resizeToFit() }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    func present() {
        resizeToFit()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func resizeToFit() {
        guard let window else { return }
        hosting.view.layoutSubtreeIfNeeded()
        var size = hosting.preferredContentSize
        guard size.height > 100 else { return }
        size.width = max(size.width, 460)
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1200, height: 900)
        size.height = min(size.height, visible.height - 80)
        guard abs(window.contentLayoutRect.height - size.height) > 0.5
            || abs(window.contentLayoutRect.width - size.width) > 0.5 else { return }
        let top = window.frame.maxY
        window.setContentSize(size)
        var frame = window.frame
        frame.origin.y = top - frame.height
        window.setFrameOrigin(frame.origin)
    }
}
