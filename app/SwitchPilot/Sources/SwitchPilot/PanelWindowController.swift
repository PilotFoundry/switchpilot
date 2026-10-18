import AppKit
import SwiftUI

/// A lightweight, non-activating panel used instead of NSPopover so the
/// menu-bar panel can have a deliberate scale/fade transition and a stable
/// anchor. NSPopover only exposes an on/off animation switch and produces a
/// full-size, pure cross-fade on macOS.
@MainActor
final class PanelWindowController {
    private let model: PanelModel
    private let hosting: NSHostingController<PanelView>
    private let panel: PanelWindow
    private let materialView = NSVisualEffectView()
    private var anchorButton: NSStatusBarButton?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?
    private var isClosing = false

    private(set) var isShown = false

    init(model: PanelModel) {
        self.model = model
        let hosting = NSHostingController(rootView: PanelView(model: model))
        hosting.sizingOptions = [.preferredContentSize]
        self.hosting = hosting

        let panel = PanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 620),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.panel = panel
        panel.isFloatingPanel = true
        panel.title = "SwitchPilot"
        panel.animationBehavior = .none
        panel.becomesKeyOnlyIfNeeded = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = hosting
        panel.onEscape = { [weak self] in self?.close() }
        panel.contentView?.wantsLayer = true

        materialView.material = .menu
        materialView.blendingMode = .behindWindow
        materialView.state = .active
        materialView.autoresizingMask = [.width, .height]
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = 12
        materialView.layer?.masksToBounds = true
        if let contentView = panel.contentView {
            materialView.frame = contentView.bounds
            contentView.addSubview(materialView, positioned: .below, relativeTo: nil)
        }
    }

    func show(relativeTo button: NSStatusBarButton) {
        if isShown || isClosing {
            return
        }
        anchorButton = button
        model.refreshAsync()
        hosting.view.layoutSubtreeIfNeeded()
        let size = preferredSize()
        panel.setContentSize(size)
        panel.setFrame(frame(for: size), display: false)
        panel.alphaValue = 0
        configureContentLayer(for: size)
        panel.orderFrontRegardless()
        panel.makeKey()
        isShown = true
        installClickMonitors()
        animateOpen()
    }

    func close(animated: Bool = true) {
        guard isShown, !isClosing else { return }
        isClosing = true
        removeClickMonitors()
        panel.ignoresMouseEvents = true

        guard animated, !reduceMotion else {
            finishClose()
            return
        }

        let layer = panel.contentView?.layer
        let scale = CABasicAnimation(keyPath: "transform")
        scale.fromValue = CATransform3DIdentity
        scale.toValue = CATransform3DMakeScale(0.995, 0.995, 1)
        scale.duration = 0.06
        scale.timingFunction = CAMediaTimingFunction(name: .easeIn)
        layer?.add(scale, forKey: "switchpilot.closeScale")
        layer?.transform = CATransform3DMakeScale(0.995, 0.995, 1)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.06
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in self?.finishClose() }
        })
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if isShown || isClosing {
            close()
        } else {
            show(relativeTo: button)
        }
    }

    /// Called when the panel content changes height (guide, permission card,
    /// etc.). Keep the top edge anchored so the panel grows downward.
    func resizeToFit() {
        guard isShown, !isClosing else { return }
        hosting.view.layoutSubtreeIfNeeded()
        let size = preferredSize()
        guard size.height > 100 else { return }
        var target = panel.frame
        target.size = size
        target.origin.y = panel.frame.maxY - size.height
        panel.setFrame(target, display: true)
        configureContentLayer(for: size)
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func preferredSize() -> NSSize {
        hosting.view.layoutSubtreeIfNeeded()
        let preferred = hosting.preferredContentSize
        let screenHeight = anchorButton?.window?.screen?.visibleFrame.height
            ?? NSScreen.main?.visibleFrame.height
            ?? 900
        let limit = screenHeight - 120
        let height = min(max(preferred.height, 480), max(480, limit))
        return NSSize(width: 380, height: height)
    }

    private func frame(for size: NSSize) -> NSRect {
        guard let button = anchorButton,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else {
            return NSRect(x: 0, y: 0, width: size.width, height: size.height)
        }

        let buttonInWindow = button.convert(button.bounds, to: nil)
        let anchor = buttonWindow.convertToScreen(buttonInWindow)
        let visible = screen.visibleFrame
        let gap: CGFloat = 4
        let edgeGap: CGFloat = 4
        // Magnet alignment: on the left half of the screen the panel's leading
        // edge snaps near the status item's leading edge; on the right half its
        // trailing edge snaps near the item's trailing edge. The result is then
        // clamped to the visible screen so the panel never leaves the display.
        var x: CGFloat
        if anchor.midX < visible.midX {
            x = anchor.minX - edgeGap
        } else {
            x = anchor.maxX - size.width + edgeGap
        }
        x = min(max(x, visible.minX + edgeGap), visible.maxX - size.width - edgeGap)
        let y = anchor.minY - gap - size.height
        return NSRect(
            x: x,
            y: max(y, visible.minY + 8),
            width: size.width,
            height: size.height
        )
    }

    private func configureContentLayer(for size: NSSize) {
        guard let content = panel.contentView, let layer = content.layer else { return }
        content.frame = NSRect(origin: .zero, size: size)
        materialView.frame = content.bounds
        content.layoutSubtreeIfNeeded()
        layer.anchorPoint = CGPoint(x: 1, y: 1)
        layer.position = CGPoint(x: content.bounds.maxX, y: content.bounds.maxY)
        layer.masksToBounds = true
    }

    private func animateOpen() {
        guard let layer = panel.contentView?.layer else {
            panel.alphaValue = 1
            return
        }
        if reduceMotion {
            layer.transform = CATransform3DIdentity
            panel.alphaValue = 1
            return
        }

        layer.transform = CATransform3DMakeScale(0.985, 0.985, 1)
        let scale = CABasicAnimation(keyPath: "transform")
        scale.fromValue = CATransform3DMakeScale(0.985, 0.985, 1)
        scale.toValue = CATransform3DIdentity
        scale.duration = 0.08
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(scale, forKey: "switchpilot.openScale")
        layer.transform = CATransform3DIdentity

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.panel.animator().alphaValue = 1
        })
    }

    private func finishClose() {
        panel.orderOut(nil)
        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
        panel.contentView?.layer?.transform = CATransform3DIdentity
        isShown = false
        isClosing = false
        anchorButton = nil
    }

    private func installClickMonitors() {
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            self?.handleLocalClick(event)
            return event
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.handleGlobalClick() }
        }
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    private func removeClickMonitors() {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
            self.resignActiveObserver = nil
        }
    }

    private func handleLocalClick(_ event: NSEvent) {
        guard isShown, !isClosing else { return }
        guard let window = event.window else { return }
        if window === panel {
            return
        }
        // Do not dismiss while a SwiftUI menu (preset picker) is open.
        if window.className.contains("Menu") {
            return
        }
        if isStatusButtonClick(event) {
            return
        }
        close()
    }

    private func handleGlobalClick() {
        guard isShown, !isClosing else { return }
        let point = NSEvent.mouseLocation
        if panel.frame.contains(point) {
            return
        }
        if let frame = statusButtonScreenFrame(), frame.contains(point) {
            return
        }
        close()
    }

    private func isStatusButtonClick(_ event: NSEvent) -> Bool {
        guard let button = anchorButton,
              let window = button.window,
              event.window === window else { return false }
        let point = window.convertToScreen(NSRect(
            origin: event.locationInWindow,
            size: .zero
        )).origin
        return buttonScreenFrame(button: button, window: window).contains(point)
    }

    private func statusButtonScreenFrame() -> NSRect? {
        guard let button = anchorButton, let window = button.window else { return nil }
        return buttonScreenFrame(button: button, window: window)
    }

    private func buttonScreenFrame(button: NSStatusBarButton, window: NSWindow) -> NSRect {
        let rect = button.convert(button.bounds, to: nil)
        return window.convertToScreen(rect)
    }
}

/// Borderless panel that can become key without activating the app and can
/// close on Escape while the panel is the key window.
private final class PanelWindow: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
