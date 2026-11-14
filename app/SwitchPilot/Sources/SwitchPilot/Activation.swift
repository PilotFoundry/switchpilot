import AppKit

/// Menu-bar actions must activate the accessory app before a custom panel or
/// Settings window can become key. On macOS 27 `NSApp.activate()` alone can
/// leave the previously focused app frontmost; this explicit activation path
/// ensures the first click inside the panel reaches its control.
@MainActor
func activateSwitchPilotForUserAction() {
    NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
}
