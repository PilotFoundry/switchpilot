# Technical design

Status: current baseline **v0.7.4**. This is the implementation-level summary;
the module map and runtime details live in
[en/ARCHITECTURE.md](en/ARCHITECTURE.md).

## 1. Stack and constraints

- macOS 14+; primarily developed on macOS 27, Apple Silicon.
- Swift 6.x with Apple Command Line Tools; SwiftPM package at
  `app/SwitchPilot`.
- AppKit + SwiftUI; no third-party Swift dependencies.
- No XCTest in the local CLT setup; core behavior is checked by the
  `SwitchPilotChecks` executable and static scripts.
- No private frameworks, privileged helper, network access, telemetry or
  automatic TCC changes.

## 2. Package layout

```text
app/SwitchPilot/
  Sources/SwitchPilot/        AppKit menu bar app + SwiftUI UI
  Sources/SwitchPilotCore/    Non-UI system integrations
  Sources/SwitchPilotChecks/  Core assertion harness
  Resources/                  Icons and localized .lproj resources
  Info.plist                  Bundle metadata and version
  Entitlements.plist          Hardened-runtime entitlements
```

## 3. Runtime components

| Component | Responsibility |
|---|---|
| `main.swift` | Launch, maintenance modes, language application before AppKit |
| `AppDelegate` | Status item, custom panel controller, settings window, single instance, login item |
| `PanelModel` | Observable panel state and action coordination |
| `SettingsModel` | Preferences, language, permissions, hotkeys, login item |
| `KeepAwakeSession` / `PowerAssertion` | IOKit display-sleep assertions and timing |
| `DarkMode` / `Permissions` | System Events checks and appearance read/write |
| `LockScreen` / `ScreenSaver` | Lock and screen-saver actions |
| `DisplaySleep` | Public `pmset displaysleepnow` wrapper |
| `Microphone` | CoreAudio capability, mute read/write and unsupported state |
| `ScreenCleaningManager` | Overlays, keyboard tap, mouse exit, hidden failsafe |
| `LoginItem` | `SMAppService` registration/state |
| `HotKeyManager` | Fixed Carbon hotkeys, disabled by default |

## 4. Localization architecture

- The Chinese source strings are the keys in `Localizable.strings`.
- `en.lproj`, `zh-Hans.lproj`, `zh-Hant.lproj` and `ja.lproj` contain the four
  UI tables. `InfoPlist.strings` exists for permission/display metadata.
- `L()` and `LF()` resolve the active language through the selected `.lproj`
  bundle; static SwiftUI strings use the app's `AppleLanguages` defaults.
- `AppLanguage` (`system`, `en`, `zh-Hans`, `zh-Hant`, `ja`) is persisted under
  `switchpilot.language`.
- At launch, `LanguagePreference.applyAtLaunch()` writes the app-scoped
  `AppleLanguages` value before AppKit/SwiftUI resolve resources.
- A language change requires a relaunch; Settings offers a restart action.
- `SWITCHPILOT_LANGUAGE` is a development/screenshot override, not a user
  preference.
- The language design contract is [en/LOCALIZATION.md](en/LOCALIZATION.md).

## 5. Build, packaging and signing

- `scripts/build-app` builds the package (debug by default), assembles the
  `.app`, copies `Info.plist`, icon and every `.lproj`, then signs it.
- `scripts/install-app` copies the bundle to `~/Applications`.
- The menu-bar panel uses a behind-window `NSVisualEffectView` menu material,
  magnet edge alignment to the status item, and an 80/60 ms scale/fade. The
  offscreen `--dump-panel` path requests an opaque fallback background.
- `scripts/build-release` builds release binaries for `arm64` and `x86_64`,
  combines them with `lipo`, assembles the app, copies all localizations,
  ad-hoc signs it, and writes a universal zip plus portable SHA-256 file.
- Release binary is intentionally ad-hoc; no personal signing identity is
  embedded.
- Local development may use `SWITCHPILOT_SIGN_IDENTITY`; rebuilding with a
  different identity can reset TCC trust.
- No notarization is available without a Developer ID certificate. See
  [en/RELEASE.md](en/RELEASE.md).

## 6. Preferences and state

- `UserDefaults` stores settings only (keep-awake preference, hotkeys, language,
  guide dismissal, etc.).
- Keep-awake state is backed by a real IOKit assertion; UI must read it back.
- Microphone mute reads the current CoreAudio capability; unsupported devices
  show an explicit explanation.
- Permission failures are surfaced as unavailable/denied states, not success.
- No settings or diagnostics are uploaded anywhere.

## 7. Testing and verification

```sh
make smoke
./scripts/verify-app.py
./scripts/qa-regression.py
```

- `verify-app.py` covers build, plist, signature, core checks, launch smoke,
  original-app integrity, contrast, panel size, semantic colors, policy
  regression and static scripts.
- Smoke checks all four locales and localized `InfoPlist` files.
- CI is deliberately TCC-free; manual TCC, login, audio, screen and Gatekeeper
  checks are documented in [en/TESTING.md](en/TESTING.md) and
  [TESTPLAN.md](TESTPLAN.md).
- Release packaging is reproducible through `scripts/build-release` and the
  GitHub release workflow.

## 8. Known limitations and future work

- Ad-hoc binaries trigger Gatekeeper on first launch; notarization requires a
  Developer ID certificate and credentials.
- TCC behavior is sensitive to signing identity changes.
- The app is universal for arm64/x86_64, but manual testing is primarily on
  Apple Silicon.
- Screen cleaning has no keyboard exit by design.
- Login-item and screen-cleaning behavior require manual acceptance on a real
  Mac.
