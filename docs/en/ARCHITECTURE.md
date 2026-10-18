# Architecture

SwitchPilot is a Swift package with two executables and a shared core module.
The product docs are in [../CORE.md](../CORE.md) and [../TECH.md](../TECH.md).

```text
app/SwitchPilot/
  Sources/SwitchPilot/        AppKit menu bar app + SwiftUI panel/settings
  Sources/SwitchPilotCore/    System integrations (no UI)
  Sources/SwitchPilotChecks/  Small executable test harness (non-XCTest)
  Resources/                  Icons + en/zh-Hans/zh-Hant/ja .lproj tables
```

## Runtime shape

- `main.swift` applies the saved language before AppKit resolves resources,
  creates the application and dispatches maintenance modes such as
  `--panel-size`, `--dump-panel`, `--dump-settings` and the diagnostics URL
  handler.
- `AppDelegate.swift` owns the `NSStatusItem`, the custom `PanelWindowController`,
  the Settings window, single-instance guard and the optional `SMAppService`
  login item. The panel is a borderless non-activating `NSPanel`, not an
  `NSPopover`, so its anchor, transient dismissal and scale/fade timing are
  controlled by the app.
- `PanelModel` is the observable UI state and coordinates the core services.
- `SettingsModel` / `SettingsWindowController` own preferences, permissions,
  hotkeys, language and login-item controls.

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

## Localization architecture

- Chinese source strings are the keys in `Localizable.strings`.
- `en.lproj`, `zh-Hans.lproj`, `zh-Hant.lproj` and `ja.lproj` contain the four
  UI tables; every supported locale also has an `InfoPlist.strings`.
- `AppLanguage` and `LanguagePreference` persist the selection under
  `switchpilot.language`.
- `LanguagePreference.applyAtLaunch()` sets the app-scoped `AppleLanguages`
  default for a forced locale, or removes it for Follow System, before
  AppKit/SwiftUI resolve resources.
- Static SwiftUI strings use the selected bundle; dynamic/AppKit strings use
  `L()` / `LF()`, which resolve the selected `.lproj` explicitly.
- A language change requires a relaunch so the bundle and `InfoPlist.strings`
  reload consistently. Settings provides **Quit and Reopen**.
- `SWITCHPILOT_LANGUAGE` is a development/screenshot-only override.

## Panel presentation

- The panel is a borderless, non-activating `NSPanel` hosted by
  `PanelWindowController`.
- The background is a behind-window `NSVisualEffectView` using the macOS menu
  material, a more opaque, Magnet-like adaptive `windowBackgroundColor` tint (90% opacity), a
  rounded mask and a subtle hairline border. The SwiftUI content is transparent
  over it.
- Opening: 80 ms ease-out, opacity 0 → 1 and a very subtle content scale
  0.985 → 1 anchored at the top-trailing edge.
- Closing: 60 ms ease-in, opacity 1 → 0 and a subtle scale 1 → 0.995.
- Magnet alignment: on the left half of the screen the panel's leading edge
  snaps 4pt outside the status item's leading edge; on the right half its
  trailing edge snaps 4pt outside the item's trailing edge, then it is clamped
  to the visible screen.
- The panel is positioned below the status item and has no NSPopover arrow.
- Transient behavior is preserved with local/global mouse monitors, Escape
  handling and workspace activation; SwiftUI menus (such as the keep-awake
  preset picker) do not dismiss the panel while open.
- Reduce Motion disables the scale and uses an immediate/near-instant
  transition.

The full contract is [LOCALIZATION.md](LOCALIZATION.md).

## Permissions and signing

- Automation is used for dark mode and lock through System Events.
- Accessibility is used for the lock shortcut and for keyboard suppression in
  screen cleaning.
- No Screen Recording, Full Disk Access, network access or privileged helper is
  required.
- Local builds are ad-hoc signed by default. A stable development identity can
  be supplied through `SWITCHPILOT_SIGN_IDENTITY`; rebuilds with a different
  identity may cause macOS to re-prompt for TCC permissions.
- The app never automatically resets TCC. Settings exposes copyable reset
  commands only after an explicit confirmation.

## Screen cleaning recovery

The cleaning mode uses a session-level CGEvent tap to swallow keyboard events,
while mouse events remain usable. The overlay has a custom-drawn exit button
that accepts the first mouse click. A hidden five-minute timer calls the same
idempotent cleanup path if the mouse/app state fails. The event tap is torn down
when the app exits, so a crash cannot leave a permanent keyboard lock.

## Build and distribution

- `scripts/build-app` builds the Swift package, copies the executable,
  `Info.plist`, app icon and all `.lproj` resources into a `.app`, and signs it.
- `scripts/install-app` copies the bundle to `~/Applications`.
- `scripts/build-release` cross-builds release binaries for arm64 and x86_64,
  combines them with `lipo`, assembles the app, copies all localized resources,
  ad-hoc signs it, and writes the universal zip and SHA-256 file.
- `.github/workflows/release.yml` rebuilds and attaches the artifact when a
  release is published (or manually dispatched), using the repository token.
- The project intentionally does not ship notarized binaries or a privileged
  installer. The published binary is an ad-hoc convenience build; see
  [RELEASE.md](RELEASE.md).

## Testing

Core behavior is checked by `SwitchPilotChecks`; CI runs `make smoke` and static
policy checks. TCC, hardware, screen-cleaning and Gatekeeper checks are manual.
See [TESTING.md](TESTING.md) and [../TESTPLAN.md](../TESTPLAN.md).
