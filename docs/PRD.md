# Product requirements

Status: current baseline **v0.7.7** (2026-10-18). English is the canonical
source for this document.

## 1. Problem

macOS exposes many useful system controls, but several everyday actions still
require a chain of menu-bar, System Settings or terminal steps. Existing
all-in-one switch utilities can be large, closed or heavier than necessary.
SwitchPilot focuses on a few high-value controls and keeps their real state
visible.

The project began as a personal investigation and is now open source under
PilotFoundry. It is inspired by One Switch's menu-bar idea but is an independent
project; it does not include One Switch code, assets or binaries and is not
affiliated with or endorsed by One Switch.

## 2. Audience

- People who want a small, native menu-bar utility for a few recurring macOS
  actions.
- Users who care about permission transparency, no telemetry and no background
  automation.
- Developers who want a readable MIT-licensed Swift/AppKit/SwiftUI example and
  are comfortable building or inspecting the source.
- Users on macOS 14 or later, on Apple Silicon or Intel. The release binary is
  universal; the project is primarily developed on Apple Silicon.

## 3. Goals

1. Make keep-awake, screen saver, display sleep, lock, dark mode, microphone
   mute and screen cleaning reachable in one or two clicks.
2. Never report success without a real readback when a readback is possible.
3. Keep the permission surface small and explain missing permissions honestly.
4. Remain a compact, quiet native menu-bar app.
5. Ship an open-source release that users can download, verify and build.
6. Provide equivalent English, Simplified Chinese, Traditional Chinese and
   Japanese UI, with a clear language override and restart behavior.

## 4. Non-goals

- A full One Switch clone or a 30-toggle dashboard.
- Output volume, low-power mode, True Tone, Night Shift, Wi-Fi/Bluetooth,
  desktop-icon hiding, audio-device switching, scenes or custom hotkey
  recording.
- Telemetry, analytics, network access, remote configuration or automatic
  updates.
- Private frameworks, privileged helpers, background automation or automatic
  TCC resets.
- Developer ID signing, notarization, sandboxing, App Store distribution or
  paid support while the project has no Developer ID certificate.

See [CORE.md](CORE.md) for the admission rules.

## 5. Functional requirements

| ID | Requirement | Acceptance |
|---|---|---|
| FR-1 | Keep awake, 15/30/60 minutes or unlimited | Real IOKit assertion; remaining time visible; auto-release at timeout |
| FR-2 | Dark mode | Read and toggle system appearance through System Events; honest denied state |
| FR-3 | Screen saver | Start the system screen saver; report failure |
| FR-4 | Lock screen | Send the system lock shortcut; require Automation + Accessibility |
| FR-5 | Display sleep | Run public `pmset displaysleepnow`; no private API |
| FR-6 | Microphone mute | Capability-aware default input mute; unsupported state is honest |
| FR-7 | Screen cleaning | Full-screen overlay, keyboard event tap, mouse exit, hidden five-minute failsafe |
| FR-8 | Login at start | Optional `SMAppService` login item controlled in Settings |
| FR-9 | Global hotkeys | Fixed `⌃⌥⌘K` / `⌃⌥⌘S`; disabled by default |
| FR-10 | Languages | Four locales; Follow System default; Settings override; restart required |
| FR-11 | About | Open-source positioning, version and MIT license; no One Switch claim inside the app |
| FR-12 | Distribution | Universal ad-hoc zip, SHA-256, clear Gatekeeper instructions; no notarization claim |

## 6. UX requirements

- Panel width 380 pt; normal height about 709 pt, guided/permission state up to
  about 782 pt.
- Settings is a separate window about 460 pt wide.
- Controls use standard AppKit/SwiftUI buttons, toggles, pickers and menus.
- Light and dark mode meet the contrast tokens checked by `make smoke`.
- The menu-bar icon is a template image and does not use color as the only
  state indicator.
- Permission-required actions are disabled or explained, never fake success.
- Screen cleaning must show a visible mouse exit and must not offer a keyboard
  exit by design.
- Do not add persistent copy for successful quick actions. Surface failures,
  permission gaps and screen-cleaning recovery only.
- Language names are shown in their own language; the current selection is
  visible; a **Quit and Reopen** action is available.

Detailed UI rules are in [DESIGN.md](DESIGN.md).

## 7. Localization requirements

- Supported locales: `en`, `zh-Hans`, `zh-Hant`, `ja`.
- Default follows the system; Settings can force one locale.
- The app must restart after a language change so AppKit, SwiftUI and
  `InfoPlist.strings` reload consistently.
- All user-facing keys must exist in all four tables; format placeholders must
  be preserved.
- Japanese and Traditional Chinese copy must fit the existing panel; if it does
  not, layout and copy are reviewed together.
- The four README files must document the same download, build, permission and
  release facts.

The implementation contract is [en/LOCALIZATION.md](en/LOCALIZATION.md).

## 8. Permissions and privacy

Required permissions:

- Automation → System Events for dark mode and lock.
- Accessibility for lock and screen-cleaning keyboard suppression.
- Login-item approval through macOS service management.

The app must not request permissions on launch without a user action, must not
modify TCC automatically, must not read unrelated files, must not record audio,
and must not perform network requests. See [SECURITY.md](../SECURITY.md).

## 9. Distribution requirements

- Provide universal (Apple Silicon + Intel) release binaries for convenience.
- Ad-hoc sign the released app; never embed a personal signing identity.
- Publish the zip and SHA-256 together.
- State clearly that the binary is not notarized and that first launch may need
  right-click **Open**.
- Keep source builds and local signing possible.
- Add a reproducible release workflow; Developer ID signing/notarization is a
  future enhancement blocked on credentials.

See [en/RELEASE.md](en/RELEASE.md).

## 10. Success criteria

- A new user can understand the permission boundary and the download caveat
  from the README without opening an issue.
- All four locales can be selected, persisted and restored after relaunch.
- A release artifact passes architecture, signature, checksum and locale
  resource checks.
- CI is green for builds, smoke checks and static policy checks.
- Manual TCC, login-item, hardware and Gatekeeper checks remain explicitly
  marked as manual or unverified.

## 11. Current limitations

- The release is ad-hoc, not notarized.
- TCC behavior, login/reboot, audio hardware, VoiceOver and Gatekeeper first-run
  behavior require a human at a Mac.
- The project is primarily tested on macOS 27 / Apple Silicon; macOS 14+
  remains the stated minimum.
