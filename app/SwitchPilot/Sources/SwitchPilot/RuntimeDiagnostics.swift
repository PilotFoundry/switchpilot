import AppKit
import SwitchPilotCore

/// Read-only runtime snapshot used by --diagnose-runtime and by the
/// switchpilot://diagnose URL while the app is already running. It never grants,
/// revokes, locks or changes appearance; permission checks are read-only.
@MainActor
func writeRuntimeDiagnostics(to path: String = "/tmp/switchpilot-runtime-diagnose.txt") {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    let icon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    let iconSizes = icon.representations.map { "\($0.pixelsWide)x\($0.pixelsHigh)" }.joined(separator: ",")
    let menuIcon = StatusIcon.make()
    let seenWelcome = UserDefaults.standard.object(forKey: "switchpilot.hasSeenWelcome") as? Bool ?? false
    let audio = AudioOutput.read()
    let hotKeys = HotKeyManager.current
    let lines = [
        "version=\(version)",
        "bundleIdentifier=\(Bundle.main.bundleIdentifier ?? "nil")",
        "bundlePath=\(Bundle.main.bundlePath)",
        "macOS=\(ProcessInfo.processInfo.operatingSystemVersionString)",
        "automationRaw=\(Permissions.automationStatus())",
        "automationResolved=\(Permissions.automationStatusResolvingTarget())",
        "systemEventsRunning=\(Permissions.systemEventsRunning())",
        "accessibilityTrusted=\(Permissions.accessibilityTrusted())",
        "loginItemState=\(LoginItem.state.description)",
        "bundleIconRepresentations=\(icon.representations.count)",
        "bundleIconSizes=\(iconSizes)",
        "menuBarIconSize=\(Int(menuIcon.size.width))x\(Int(menuIcon.size.height))",
        "menuBarIconTemplate=\(menuIcon.isTemplate)",
        "hasSeenWelcome=\(seenWelcome)",
        "displaySleepAvailable=\(DisplaySleep.isAvailable)",
        "audioDevice=\(audio.name)",
        "audioSupportsVolume=\(audio.supportsVolume)",
        "audioSupportsMute=\(audio.supportsMute)",
        "hotKeysEnabled=\(hotKeys?.isEnabled ?? false)",
        "hotKeysRegistered=\(hotKeys?.hasRegisteredHotKeys ?? false)",
        "hotKeyError=\(hotKeys?.lastError ?? "")",
    ].joined(separator: "\n") + "\n"
    try? lines.write(toFile: path, atomically: true, encoding: .utf8)
}
