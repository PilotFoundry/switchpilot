import AppKit
import Carbon

/// Two fixed global hotkeys that reuse existing panel actions. Carbon hotkeys do
/// not require Accessibility or Automation; registration failure (usually a
/// duplicate combo) is surfaced to Settings instead of silently disabling.
@MainActor
final class HotKeyManager {
    static let enabledDefaultsKey = "switchpilot.hotKeysEnabled"
    static let keepAwakeCombo = "⌃⌥⌘K"
    static let screenSaverCombo = "⌃⌥⌘S"

    static weak var current: HotKeyManager?

    var onKeepAwakeToggle: (() -> Void)?
    var onScreenSaver: (() -> Void)?
    private(set) var lastError = ""

    init() {
        Self.current = self
    }

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
    }

    var hasRegisteredHotKeys: Bool {
        !hotKeyRefs.isEmpty
    }

    func startIfEnabled() {
        guard isEnabled else { return }
        if let error = register() {
            lastError = error
            UserDefaults.standard.set(false, forKey: Self.enabledDefaultsKey)
        }
    }

    /// Returns nil on success, otherwise a user-readable error and leaves the
    /// preference disabled.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> String? {
        if enabled {
            if let error = register() {
                UserDefaults.standard.set(false, forKey: Self.enabledDefaultsKey)
                lastError = error
                return error
            }
            UserDefaults.standard.set(true, forKey: Self.enabledDefaultsKey)
            lastError = ""
            return nil
        }
        stop()
        UserDefaults.standard.set(false, forKey: Self.enabledDefaultsKey)
        lastError = ""
        return nil
    }

    func stop() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        eventHandlerRef = nil
    }

    private func register() -> String? {
        stop()
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            switchPilotHotKeyHandler,
            1,
            &eventType,
            userData,
            &eventHandlerRef)
        guard installStatus == noErr else {
            return "快捷键事件处理注册失败（\(installStatus)）"
        }

        let modifiers = UInt32(cmdKey | optionKey | controlKey)
        if let error = registerOne(
            id: 1,
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: modifiers,
            label: "保持亮屏"
        ) {
            stop()
            return error
        }
        if let error = registerOne(
            id: 2,
            keyCode: UInt32(kVK_ANSI_S),
            modifiers: modifiers,
            label: "启动屏保"
        ) {
            stop()
            return error
        }
        return nil
    }

    private func registerOne(
        id: UInt32,
        keyCode: UInt32,
        modifiers: UInt32,
        label: String
    ) -> String? {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x5350494C), id: id) // 'SPIL'
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref)
        guard status == noErr, let ref else {
            return "\(label)快捷键注册失败（\(status)），可能被其他应用占用"
        }
        hotKeyRefs.append(ref)
        return nil
    }

    fileprivate func handleHotKey(id: UInt32) {
        switch id {
        case 1:
            onKeepAwakeToggle?()
        case 2:
            onScreenSaver?()
        default:
            break
        }
    }
}

private func switchPilotHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData, let event else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID)
    guard status == noErr else { return OSStatus(eventNotHandledErr) }
    Task { @MainActor in
        manager.handleHotKey(id: hotKeyID.id)
    }
    return noErr
}
