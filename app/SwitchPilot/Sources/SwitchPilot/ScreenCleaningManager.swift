import AppKit
import CoreGraphics
import Foundation
import SwitchPilotCore

enum ScreenCleaningError: Error, CustomStringConvertible {
    case accessibilityRequired
    case eventTapUnavailable

    var description: String {
        switch self {
        case .accessibilityRequired:
            return "需要辅助功能授权才能锁定键盘输入"
        case .eventTapUnavailable:
            return "无法创建键盘拦截；请确认辅助功能授权后重试"
        }
    }
}

/// Screen-cleaning mode. The keyboard is swallowed by a session event tap
/// (requires the existing Accessibility grant); the mouse remains usable so the
/// user exits via the on-screen button. There is intentionally no countdown or
/// automatic exit in normal use; an optional duration exists only for
/// controlled tests (SWITCHPILOT_CLEAN_SCREEN_TEST_SECONDS). All state is
/// released on stop and the tap dies with the process if the app crashes.
@MainActor
final class ScreenCleaningManager {
    var onStateChange: ((Bool, String) -> Void)?

    private(set) var isActive = false
    private var windows: [NSWindow] = []
    private var overlays: [CleaningOverlayView] = []
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private var failsafeTimer: Timer?
    private var assertion: PowerAssertion?
    private var remainingSeconds = 0
    private var showsCountdown = false

    func start(duration: Int? = nil) throws {
        guard !isActive else { return }
        guard Permissions.accessibilityTrusted() else {
            throw ScreenCleaningError.accessibilityRequired
        }

        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue))
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: screenCleaningTapCallback,
            userInfo: userInfo
        ) else {
            throw ScreenCleaningError.eventTapUnavailable
        }
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        let power = PowerAssertion()
        try? power.start()
        assertion = power

        showsCountdown = duration != nil
        remainingSeconds = max(1, duration ?? 0)
        buildOverlays()
        isActive = true
        updateCountdown()
        onStateChange?(true, "清洁模式进行中：键盘已暂停，鼠标点击退出")

        if showsCountdown {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        }
        // Hidden last-resort recovery if the mouse fails; never shown in normal UI.
        failsafeTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
    }

    func stop() {
        guard isActive || eventTap != nil || !windows.isEmpty else { return }
        timer?.invalidate()
        timer = nil
        failsafeTimer?.invalidate()
        failsafeTimer = nil
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        overlays.removeAll()
        try? assertion?.stop()
        assertion = nil
        showsCountdown = false
        let wasActive = isActive
        isActive = false
        if wasActive {
            onStateChange?(false, "已退出清洁模式")
            NSApp.activate(ignoringOtherApps: false)
        }
    }

    fileprivate func reenableTap() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        if !CGEvent.tapIsEnabled(tap: eventTap) {
            stop()
        }
    }

    private func tick() {
        guard isActive, showsCountdown else { return }
        remainingSeconds -= 1
        updateCountdown()
        if remainingSeconds <= 0 {
            stop()
        }
    }

    private func updateCountdown() {
        guard showsCountdown else { return }
        for overlay in overlays {
            overlay.update(secondsRemaining: remainingSeconds)
        }
    }

    private func buildOverlays() {
        for screen in NSScreen.screens {
            let window = CleaningWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false)
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            let overlay = CleaningOverlayView(
                frame: NSRect(origin: .zero, size: screen.frame.size),
                manager: self,
                showCountdown: showsCountdown)
            overlay.autoresizingMask = [.width, .height]
            window.contentView = overlay
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            windows.append(window)
            overlays.append(overlay)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc fileprivate func exitFromOverlay(_ sender: Any?) {
        stop()
    }

    /// Offscreen preview of the overlay (no event tap/windows) for UI checks.
    @MainActor
    static func previewOverlay(size: NSSize) -> NSView {
        let manager = ScreenCleaningManager()
        let view = CleaningOverlayView(
            frame: NSRect(origin: .zero, size: size),
            manager: manager,
            showCountdown: false)
        view.layoutSubtreeIfNeeded()
        return view
    }
}

/// Borderless overlay windows must opt into key/main status so the mouse can
/// interact with the exit button.
private final class CleaningWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class CleaningOverlayView: NSView {
    private weak var manager: ScreenCleaningManager?
    private let titleLabel = NSTextField(labelWithString: "屏幕清洁模式")
    private let instructionLabel = NSTextField(labelWithString: "")
    private let countdownLabel = NSTextField(labelWithString: "")
    private let exitControl: CleaningExitControl
    private let showsCountdown: Bool

    init(frame: NSRect, manager: ScreenCleaningManager, showCountdown: Bool) {
        self.manager = manager
        self.showsCountdown = showCountdown
        self.exitControl = CleaningExitControl(manager: manager)
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false

        instructionLabel.font = .systemFont(ofSize: 13)
        instructionLabel.textColor = NSColor(white: 0.78, alpha: 1)
        instructionLabel.alignment = .center
        instructionLabel.lineBreakMode = .byWordWrapping
        instructionLabel.maximumNumberOfLines = 2
        instructionLabel.isEditable = false
        instructionLabel.isBordered = false
        instructionLabel.drawsBackground = false
        instructionLabel.stringValue = showCountdown
            ? "键盘输入已暂停；点击下方按钮退出。测试模式会在倒计时结束时自动退出。"
            : "键盘输入已暂停；移动鼠标并点击下方按钮退出清洁模式。"

        countdownLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        countdownLabel.textColor = .white
        countdownLabel.alignment = .center
        countdownLabel.isEditable = false
        countdownLabel.isBordered = false
        countdownLabel.drawsBackground = false
        countdownLabel.isHidden = !showCountdown

        addSubview(titleLabel)
        addSubview(instructionLabel)
        addSubview(countdownLabel)
        addSubview(exitControl)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func layout() {
        super.layout()
        let width = bounds.width
        let height = bounds.height
        titleLabel.frame = NSRect(x: 40, y: height * 0.62, width: width - 80, height: 36)
        instructionLabel.frame = NSRect(x: 60, y: height * 0.52, width: width - 120, height: 48)
        countdownLabel.frame = NSRect(x: 60, y: height * 0.46, width: width - 120, height: 24)
        exitControl.frame = NSRect(x: (width - 240) / 2, y: height * 0.34, width: 240, height: 54)
    }

    func update(secondsRemaining: Int) {
        guard showsCountdown else { return }
        countdownLabel.stringValue = "\(secondsRemaining) 秒后自动退出（测试模式）"
    }
}

/// Custom-drawn exit control instead of NSButton: it renders reliably on the
/// pure-black overlay and accepts the first mouse click.
private final class CleaningExitControl: NSView {
    private weak var manager: ScreenCleaningManager?
    private let label = NSTextField(labelWithString: "退出清洁模式")

    init(manager: ScreenCleaningManager) {
        self.manager = manager
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.94, alpha: 1).cgColor
        layer?.cornerRadius = 10
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = NSColor(white: 0.08, alpha: 1)
        label.alignment = .center
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: 12, dy: 12)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        manager?.exitFromOverlay(nil)
    }
}

private func screenCleaningTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<ScreenCleaningManager>.fromOpaque(userInfo).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        Task { @MainActor in manager.reenableTap() }
        return Unmanaged.passUnretained(event)
    }
    switch type {
    case .keyDown, .keyUp, .flagsChanged:
        return nil
    default:
        return Unmanaged.passUnretained(event)
    }
}
