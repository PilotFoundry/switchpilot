# Core principles

Status: current baseline **v0.7.2**. This document defines SwitchPilot's product
boundary. The implementation-level admission checklist lives in
[en/CORE.md](en/CORE.md).

## Positioning

SwitchPilot is an open-source, privacy-first macOS menu-bar utility maintained
by [PilotFoundry](https://github.com/PilotFoundry). It was inspired by One
Switch's approach of putting everyday system controls in the menu bar, but it is
an independent project with a deliberately smaller scope. It is not affiliated
with or endorsed by One Switch, and contains no One Switch code, assets or
distribution binaries.

The project is not a personal-use-only prototype any more: source, releases,
documentation and issue tracking are public. That changes the maintenance bar,
not the product scope.

## Product rules

1. **Small and reliable.** Prefer a small set of understandable controls over a
   crowded dashboard.
2. **System gap or long chain.** A new control must fill a real system gap or
   shorten a frequent, multi-step workflow. Mirroring an existing menu-bar or
   Control Center control is not enough.
3. **One clear action.** Clearly labelled, common and reversible actions run on
   click. Only irreversible or high-risk operations require confirmation.
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
    login, hardware and release acceptance. Unexecuted manual checks stay
    pending.

## Included scope

- Keep awake, timed or unlimited
- Dark mode through System Events
- System screen saver
- Lock screen, gated by Automation and Accessibility
- Display sleep through `pmset displaysleepnow`
- Capability-aware microphone mute
- Screen cleaning with a real keyboard event tap, mouse exit and hidden
  five-minute failsafe
- Optional login item through `SMAppService`
- Fixed global hotkeys, disabled by default
- English, Simplified Chinese, Traditional Chinese and Japanese UI, following
  the system language by default with an in-app override
- Ad-hoc universal macOS release binary, published with checksums

## Explicitly out of scope

- Output volume, low-power mode, True Tone, desktop-icon hiding, Night Shift,
  Wi-Fi/Bluetooth toggles, audio-device switching, scenes and custom hotkey
  recording
- Private APIs, privileged helpers, background automation, telemetry,
  automatic TCC resets, network access or remote configuration
- Developer ID signing, notarization, sandboxing and App Store distribution
  while the project has no Developer ID certificate
- Branding that could imply endorsement by, or affiliation with, One Switch

## Distribution boundary

Public source and an ad-hoc universal binary are intentional. The binary is a
convenience build, not a notarized distribution: macOS may require the user to
right-click **Open** on first launch. Users who need a higher trust level should
build from source and sign it themselves. The exact artifact names, checksum,
verification steps and future notarization path are defined in
[en/RELEASE.md](en/RELEASE.md).

## Decision rule

If a proposal makes the product larger without making a frequent system action
more reliable, faster or more understandable, it is probably out of scope. If it
weakens permission honesty, state readback or recovery, it is out of scope
regardless of demand.
