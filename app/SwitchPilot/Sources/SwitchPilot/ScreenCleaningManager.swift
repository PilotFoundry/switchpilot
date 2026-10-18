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

/// Timed screen-cleaning mode. The keyboard is swallowed by a session event tap
/// (requires the existing Accessibility grant), while the mouse/trackpad stays
/// usable so the user can click the on-screen exit button. A timer is the
/// safety fallback; keyboard is never used to exit. All state is released on
/// stop and the event tap dies with the process if the app crashes.
@MainActor
final class ScreenCleaningManager {
    var onStateChange: ((Bool, String) -> Void)?

    private(set) var isActive = false
    private var windows: [NSWindow] = []
    private var overlays: [CleaningOverlayView] = []
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private var assertion: PowerAssertion?
    private var remainingSeconds = 0

    func start(duration: Int = 60) throws {
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

        remainingSeconds = max(5, duration)
        buildOverlays()
        isActive = true
        updateCountdown()
        onStateChange?(true, "清洁模式进行中：键盘已暂停，鼠标点击退出")

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        guard isActive || eventTap != nil || !windows.isEmpty else { return }
        timer?.invalidate()
        timer = nil
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
        guard isActive else { return }
        remainingSeconds -= 1
        updateCountdown()
        if remainingSeconds <= 0 {
            stop()
        }
    }

    private func updateCountdown() {
        for overlay in overlays {
            overlay.update(secondsRemaining: remainingSeconds)
        }
    }

    private func buildOverlays() {
        for screen in NSScreen.screens {
            let window = NSWindow(
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
                manager: self)
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
}

private final class CleaningOverlayView: NSView {
    private weak var manager: ScreenCleaningManager?
    private let countdownLabel = NSTextField(labelWithString: "")
    private let button: NSButton

    init(frame: NSRect, manager: ScreenCleaningManager) {
        self.manager = manager
        self.button = NSButton(title: "退出清洁模式", target: manager, action: #selector(ScreenCleaningManager.exitFromOverlay(_:)))
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        let title = NSTextField(labelWithString: "屏幕清洁模式")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.textColor = .white

        let instruction = NSTextField(labelWithString: "键盘输入已暂停；移动鼠标并点击按钮即可退出。若未点击，计时结束后自动退出。")
        instruction.font = .systemFont(ofSize: 13)
        instruction.textColor = NSColor(white: 0.78, alpha: 1)
        instruction.alignment = .center
        instruction.lineBreakMode = .byWordWrapping
        instruction.maximumNumberOfLines = 2

        countdownLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        countdownLabel.textColor = .white
        countdownLabel.alignment = .center

        button.bezelStyle = .rounded
        button.controlSize = .large
        button.keyEquivalent = ""
        button.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [title, instruction, countdownLabel, button])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    func update(secondsRemaining: Int) {
        countdownLabel.stringValue = "\(secondsRemaining) 秒后自动退出"
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
