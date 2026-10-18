# Architecture

SwitchPilot is a Swift package with two executables and a shared core module.

```text
app/SwitchPilot/
  Sources/SwitchPilot/        AppKit menu bar app + SwiftUI panel/settings
  Sources/SwitchPilotCore/    System integrations (no UI)
  Sources/SwitchPilotChecks/  Small executable test harness (non-XCTest)
```

## Runtime shape

- `main.swift` creates the application and dispatches maintenance modes such as
  `--panel-size`, `--dump-panel`, `--dump-settings` and the diagnostics URL
  handler.
- `AppDelegate.swift` owns the `NSStatusItem`, the SwiftUI `NSPopover`, the
  Settings window, single-instance guard and the optional `SMAppService` login
  item.
- `PanelModel` is the observable UI state and coordinates the core services.
- `SettingsModel` / `SettingsWindowController` own preferences, permissions,
  hotkeys and login-item controls.

The app is an `LSUIElement` agent: it has no Dock icon by default and is driven
from the menu bar. It is a single-instance app and supports the
`switchpilot://diagnose` URL for local diagnostics.

## Core modules

| Module | Responsibility |
|---|---|
| `KeepAwakeSession` / `PowerAssertion` | IOKit display-sleep assertions, timed/indefinite sessions, real assertion IDs |
| `DarkMode` / `Permissions` | System Events automation checks and dark-mode read/write |
| `LockScreen` / `ScreenSaver` | Lock-screen and screen-saver actions |
| `DisplaySleep` | Public `/usr/bin/pmset displaysleepnow` wrapper |
| `Microphone` | CoreAudio input-device capability, mute read/write and unsupported-device reporting |
| `ScreenCleaningManager` | Full-screen overlays, keyboard event tap, mouse exit, last-resort timer and cleanup |
| `StatusIcon` | Stable template S menu-bar icon |
| `LoginItem` | `SMAppService` state and registration |

## Permissions and signing

- Automation is used for dark mode and lock through System Events.
- Accessibility is used for the lock shortcut and for keyboard suppression in
  screen cleaning.
- No Screen Recording, Full Disk Access, network access or privileged helper is
  required.
- Local builds are ad-hoc signed by default. A stable development identity can
  be supplied through `SWITCHPILOT_SIGN_IDENTITY`; rebuilds with a different
  identity may cause macOS to re-prompt for TCC permissions.
- The app never automatically resets TCC. The Settings panel exposes copyable
  reset commands only after an explicit confirmation.

## Screen cleaning recovery

The cleaning mode uses a session-level CGEvent tap to swallow keyboard events,
while mouse events remain usable. The overlay has a custom-drawn exit button
that accepts the first mouse click. A hidden five-minute timer calls the same
idempotent cleanup path if the mouse/app state fails. The event tap is torn down
when the app exits, so a crash cannot leave a permanent keyboard lock.

## Build and distribution

`scripts/build-app` builds the Swift package, copies the executable, `Info.plist`
and app icon into a `.app`, and signs it. `scripts/install-app` copies the bundle
to `~/Applications`. The project intentionally does not ship notarized binaries
or a privileged installer.
