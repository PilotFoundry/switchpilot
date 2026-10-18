import AppKit
import SwitchPilotCore
import Combine
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?

    private let hosting: NSHostingController<SettingsView>
    private var sizeCancellable: AnyCancellable?
    private var keyMonitor: Any?

    init(model: SettingsModel) {
        let hosting = NSHostingController(rootView: SettingsView(model: model))
        hosting.sizingOptions = [.preferredContentSize]
        self.hosting = hosting

        let window = SettingsWindow(contentViewController: hosting)
        window.title = L("SwitchPilot 设置")
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

    /// Offscreen probe used by `--settings-close-key-test` to verify the
    /// standard Command-W path without presenting a visible Settings window.
    static func closeShortcutRegressionProbe() -> Bool {
        let window = SettingsWindow(
            contentRect: NSRect(x: -20_000, y: -20_000, width: 460, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.orderFront(nil)
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "w",
            charactersIgnoringModifiers: "w",
            isARepeat: false,
            keyCode: 13
        ) else { return false }
        let handled = window.performKeyEquivalent(with: event)
        let closed = !window.isVisible
        window.orderOut(nil)
        return handled && closed
    }

    func windowWillClose(_ notification: Notification) {
        removeKeyMonitor()
        onClose?()
    }

    func present() {
        resizeToFit()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        installKeyMonitor()
    }

    /// Belt-and-suspenders for Command-W: the current app has no main menu
    /// (LSUIElement), so there is no File > Close item to own the shortcut.
    /// The monitor catches the event before normal dispatch; SettingsWindow's
    /// performKeyEquivalent remains as the AppKit-level fallback.
    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command,
               event.charactersIgnoringModifiers?.lowercased() == "w" {
                self?.window?.performClose(nil)
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
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


/// The app is LSUIElement and has no main menu, so AppKit has no File > Close
/// menu item to resolve Command-W. NSWindow itself does not own that shortcut.
/// Handle it on the window so the standard Settings window can always close.
private final class SettingsWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command,
           event.charactersIgnoringModifiers?.lowercased() == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        performClose(nil)
    }
}
