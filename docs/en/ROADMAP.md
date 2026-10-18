# Roadmap and status

## Current baseline

- Version: 0.7.0
- Status: personal-use early release; not notarized, no distributed binaries.
- Implemented: keep awake, dark mode, screen saver, lock screen, display sleep,
  microphone mute, screen cleaning, optional login item, fixed hotkeys, and
  system-language English, Simplified Chinese, Traditional Chinese and
  Japanese UI, with an optional in-app language override.
- Deliberately removed: output volume (system menu bar/Control Center already
  covers it).

## Candidates

- Improve device-change refresh for microphone mute.
- Optional stable signing guidance and release packaging.
- More manual-test coverage for login/reboot, menu-bar icons and VoiceOver.

## Not planned

- Output volume, low-power mode, True Tone, desktop-icon hiding, Night Shift,
  Wi-Fi/Bluetooth toggles, audio-device switching, scenes or custom hotkey
  recording.
- Private APIs, privileged helpers, telemetry, background automation, automatic
  TCC resets, distribution/notarization.

Scope changes must pass the checklist in [CORE.md](CORE.md).

## Known limitations

- Screen cleaning has no keyboard exit by design; a hidden five-minute
  last-resort timer is the only automatic recovery.
- Microphone mute depends on the input device exposing a CoreAudio mute
  property.
- Rebuilding with ad-hoc signing can change code identity and cause macOS to ask
  for permissions again.
- The project is primarily developed on macOS 27; CI only builds on a GitHub
  macOS runner and does not exercise TCC or physical hardware.
