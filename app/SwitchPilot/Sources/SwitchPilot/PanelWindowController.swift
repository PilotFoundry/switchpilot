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
    private let materialView = PassthroughVisualEffectView()
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

    /// Regression probe for the click-through material fix. This is run by
    /// `SwitchPilot --panel-hit-test` in verify-app.py so a future background
    /// view cannot silently start swallowing all panel clicks again.
    static func hitTestRegressionProbe() -> Bool {
        let material = PassthroughVisualEffectView(
            frame: NSRect(x: 0, y: 0, width: 100, height: 100)
        )
        return material.hitTest(NSPoint(x: 50, y: 50)) == nil
            && statusButtonHitTestRegressionProbe()
    }

    /// A status item is a menu-bar target, not just its 22pt button frame.
    /// On macOS 27 a pointer pinned to the top of the screen reports a location
    /// above the button frame; macOS still routes the click to the button. The
    /// outside-click monitors must use the same inclusive, screen-top-aware
    /// region or they dismiss on mouse-down and the button action reopens on
    /// mouse-up.
    static func pointHitsStatusButton(
        _ point: NSPoint,
        buttonFrame: NSRect,
        screenTop: CGFloat
    ) -> Bool {
        guard buttonFrame.width > 0, buttonFrame.height > 0 else { return false }
        let top = max(buttonFrame.maxY, screenTop)
        return point.x >= buttonFrame.minX
            && point.x <= buttonFrame.maxX
            && point.y >= buttonFrame.minY
            && point.y <= top
    }

    private static func statusButtonHitTestRegressionProbe() -> Bool {
        let frame = NSRect(x: 500, y: 1515, width: 40, height: 36)
        let screenTop: CGFloat = 1555
        let cases: [(NSPoint, Bool)] = [
            (NSPoint(x: 520, y: 1533), true),   // center
            (NSPoint(x: 520, y: 1515), true),   // inclusive lower edge
            (NSPoint(x: 520, y: 1551), true),   // inclusive button top
            (NSPoint(x: 520, y: 1555), true),   // screen-top click
            (NSPoint(x: 500, y: 1555), true),   // inclusive leading edge
            (NSPoint(x: 540, y: 1555), true),   // inclusive trailing edge
            (NSPoint(x: 499, y: 1555), false),  // beside the button
            (NSPoint(x: 541, y: 1555), false),  // beside the button
            (NSPoint(x: 520, y: 1514), false),  // below the button
            (NSPoint(x: 520, y: 1556), false),  // above the screen
        ]
        guard cases.allSatisfy({ pointHitsStatusButton($0.0, buttonFrame: frame, screenTop: screenTop) == $0.1 }) else {
            return false
        }
        return !pointHitsStatusButton(.zero, buttonFrame: .zero, screenTop: screenTop)
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
        // A non-activating panel can become key, but activating the accessory app
        // first is what makes the first click on a SwiftUI button perform its
        // action instead of merely activating the window. It also gives the
        // Accessibility consent prompt a foreground app to attach to.
        activateSwitchPilotForUserAction()
        panel.makeKeyAndOrderFront(nil)
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
        return PanelGeometry.frame(
            anchor: anchor,
            visible: screen.visibleFrame,
            size: size
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
            // Capture the click location before hopping to the main actor: the
            // pointer may move while the asynchronous task is queued.
            let point = NSEvent.mouseLocation
            Task { @MainActor in self?.handleGlobalClick(at: point) }
        }
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let cursorOverStatus = self.isPointOverStatusButton(NSEvent.mouseLocation)
                let mouseButtonDown = NSEvent.pressedMouseButtons != 0
                guard PanelDismissalPolicy.shouldCloseAfterResign(
                    isShown: self.isShown,
                    isClosing: self.isClosing,
                    cursorOverStatusButton: cursorOverStatus,
                    mouseButtonDown: mouseButtonDown
                ) else { return }
                self.close()
            }
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

    private func handleGlobalClick(at point: NSPoint) {
        guard isShown, !isClosing else { return }
        if panel.frame.contains(point) {
            return
        }
        if isPointOverStatusButton(point) {
            return
        }
        close()
    }

    private func isPointOverStatusButton(_ point: NSPoint) -> Bool {
        guard let button = anchorButton,
              let window = button.window,
              let screen = window.screen else { return false }
        return Self.pointHitsStatusButton(
            point,
            buttonFrame: buttonScreenFrame(button: button, window: window),
            screenTop: screen.frame.maxY
        )
    }

    private func isStatusButtonClick(_ event: NSEvent) -> Bool {
        guard let button = anchorButton,
              let window = button.window,
              let screen = window.screen,
              event.window === window else { return false }
        let point = window.convertToScreen(NSRect(
            origin: event.locationInWindow,
            size: .zero
        )).origin
        return Self.pointHitsStatusButton(
            point,
            buttonFrame: buttonScreenFrame(button: button, window: window),
            screenTop: screen.frame.maxY
        )
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

/// The material must never participate in hit testing. It is installed as a
/// subview of the SwiftUI hosting view; a normal NSVisualEffectView would sit
/// above the SwiftUI hit-test tree and swallow every click.
private final class PassthroughVisualEffectView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
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
