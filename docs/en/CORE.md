# Core principles (engineering acceptance)

This is the engineering-level admission and acceptance checklist. The
product-level boundary is [../CORE.md](../CORE.md); the requirements are
[../PRD.md](../PRD.md). English is canonical.

## Positioning

SwitchPilot is an open-source, low-permission macOS menu-bar app maintained by
PilotFoundry. It began as a personal tool and was inspired by One Switch's
menu-bar approach. It is independent, contains no One Switch code or assets, and
is not affiliated with or endorsed by One Switch.

The project publishes source and an ad-hoc universal binary. An ad-hoc binary is
a convenience build, not a notarized distribution. Developer ID signing and
notarization remain out of scope while no certificate is available.

## Product rules

1. **Small and reliable.** Prefer a small set of understandable controls over a
   crowded dashboard.
2. **System gap or long chain.** A new control must fill a real system gap or
   shorten a frequent, multi-step workflow. Mirroring an existing menu-bar or
   Control Center control is not enough.
3. **One clear action.** Clearly labelled, common, reversible actions run on
   click. Only irreversible/high-risk operations require confirmation.
4. **Minimum permission surface.** Use public APIs. Prefer an existing
   permission over adding a new TCC service. Explain missing permissions and
   unsupported devices instead of pretending success.
5. **Readback, not optimism.** Reflect system state from a real readback
   (assertions, appearance, lock state, mute capability) rather than from a
   click having happened.
6. **Visible state.** Privacy- and input-related state, especially microphone
   mute and screen cleaning, must be visible and understandable.
7. **Recoverable.** A mode that changes input state needs an explicit exit and a
   failure-safe path. Screen cleaning keeps the mouse as its exit and has a
   hidden last-resort timeout.
8. **No private APIs or automatic TCC changes.** No privileged helper, private
   frameworks, automatic `tccutil reset`, or modification of another app's data.
9. **Quiet native UI.** Follow macOS conventions: readable contrast, standard
   controls, minimal decoration and a compact menu-bar panel.
10. **Evidence over claims.** Automated checks are separate from manual TCC,
    login, hardware and Gatekeeper acceptance. Unexecuted manual checks stay
    pending.

11. **Self-evident over annotated.** Controls, state and system behavior should
    explain themselves. Do not add persistent copy for successful quick actions
    or for what a label already says; reserve text for permissions, failures,
    recovery and safety-critical exits.

## Scope

### Included

- Keep awake (timed or unlimited)
- Dark mode
- Screen saver
- Lock screen
- Display sleep
- Microphone mute (capability-aware)
- Screen cleaning (keyboard suspended, mouse exit, hidden five-minute failsafe)
- Permission onboarding, Settings, optional login item, fixed global hotkeys
  (disabled by default)
- English, Simplified Chinese, Traditional Chinese and Japanese UI, with
  Follow System default and an in-app override
- Ad-hoc universal binary with checksums and explicit Gatekeeper instructions

### Explicitly not planned

- Output volume: the system menu bar/Control Center already provides it.
- Low-power mode / battery controls: macOS already manages these.
- True Tone: no public API; device/capability specific.
- Hiding desktop icons: needs a preference hack and a Finder restart; not a
  stable public API and too disruptive for this project.
- Night Shift, Wi-Fi/Bluetooth toggles, audio-device switching, scenes or custom
  hotkey recording.
- Telemetry, network access, background automation, privileged helpers.
- Developer ID signing, notarization, sandboxing or App Store distribution
  while the project has no Developer ID certificate.

## Admission checklist for a new feature

- Does it fill a **system gap** or a **frequent long chain**, rather than
  duplicating an existing menu-bar/Control Center control?
- Is it implementable with **public APIs**, without a new permission surface,
  private framework or background daemon?
- Is it understandable, reversible/recoverable and capable of honest failure?
- Is its state visible, especially if it affects privacy or input?
- Does it preserve the compact, reliable menu-bar experience and all four
  localizations?

## Release acceptance

- App version, tag, artifact name and README versions agree.
- `make smoke`, `verify-app.py` and `qa-regression.py` pass.
- All four `.lproj` tables and localized `InfoPlist.strings` are present.
- Universal binary is `arm64 + x86_64`, ad-hoc signed, no personal identity.
- SHA-256 verifies; zip has no AppleDouble files.
- Release notes state that the build is not notarized and explain right-click
  **Open**.
- No private API, new TCC permission or automatic reset has been introduced.

## Manual acceptance

TCC transitions, real login/reboot, menu-bar/system icon visibility, real
lock/screen-saver/display-sleep behavior, microphone writeback, Gatekeeper
first-run and real keyboard suppression in screen cleaning require a person at
the machine. See [TESTING.md](TESTING.md), [../TESTPLAN.md](../TESTPLAN.md) and
[RELEASE.md](RELEASE.md).
