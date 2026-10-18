# Core principles

SwitchPilot is a personal-use, low-permission macOS menu bar app. Its goal is
not to reproduce every One Switch feature; it is to make a few high-value system
actions reliable and quick.

## Product rules

1. **Small and reliable.** Prefer a small set of understandable controls over a
   crowded dashboard.
2. **System gap or long chain.** A new control should either fill a real system
   gap or shorten a frequent, multi-step workflow. Merely mirroring an existing
   menu-bar/Control Center control is not enough.
3. **One clear action.** Clearly labelled, common and reversible actions run on
   click. Only irreversible/high-risk operations require confirmation.
4. **Minimum permission surface.** Use public APIs. Prefer an existing
   permission over adding a new TCC service. Explain missing permissions and
   unsupported devices instead of pretending success.
5. **Readback, not optimism.** Reflect system state from a real readback
   (assertions, appearance, lock state, mute capability) rather than from a
   click having happened.
6. **Visible state.** Privacy- and input-related state, especially microphone
   mute and screen cleaning, must be visible and understandable.
7. **Recoverable.** A mode that changes input state needs an explicit exit and
   a failure-safe path. Screen cleaning keeps the mouse as its exit and has a
   hidden last-resort timeout.
8. **No private APIs or automatic TCC changes.** No privileged helper, no
   private frameworks, no automatic `tccutil reset`, no modifying another
   app's data.
9. **Quiet native UI.** Follow macOS conventions: readable contrast, standard
   controls, minimal decoration, and a compact menu-bar panel.
10. **Evidence over claims.** Automated checks are separate from manual TCC /
    login / hardware acceptance. Unexecuted manual checks stay pending.

## Admission checklist for a new feature

- Does it fill a **system gap** or a **frequent long chain**, rather than
  duplicating an existing menu-bar/Control Center control?
- Is it implementable with **public APIs**, without a new permission surface,
  private framework or background daemon?
- Is it understandable, reversible/recoverable and capable of honest failure?
- Is its state visible, especially if it affects privacy or input?
- Does it preserve the compact, reliable menu-bar experience?

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

### Explicitly not planned

- Output volume: the system menu bar/Control Center already provides it.
- Low-power mode / battery controls: macOS already manages these.
- True Tone: no public API; device/capability specific.
- Hiding desktop icons: needs a preference hack and a Finder restart; not a
  stable public API and too disruptive for this project.
- Night Shift, Wi-Fi/Bluetooth toggles, desktop icon toggles, audio-device
  switching, scene automation, custom hotkey recorder.
- Distribution signing/notarization, sandboxing, telemetry, background
  automation.

## Manual acceptance

TCC permission transitions, real login/reboot launch, menu-bar/system icon
visibility, real lock/screen-saver/display-sleep behavior, microphone writeback
and real keyboard suppression in screen cleaning require a person at the
machine. See `docs/en/TESTING.md`; the CI smoke check does not replace these.
