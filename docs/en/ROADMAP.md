# Roadmap and status

## Current baseline

- Version: **0.7.1**
- Status: open-source early release maintained by PilotFoundry; ad-hoc universal
  binary published, not notarized.
- Implemented: keep awake, dark mode, screen saver, lock screen, display sleep,
  microphone mute, screen cleaning, optional login item, fixed hotkeys, and
  system-language English / Simplified Chinese / Traditional Chinese / Japanese
  UI with an in-app language override.
- Distribution: source is MIT licensed; release assets include an ad-hoc
  universal zip and SHA-256. No Developer ID signing or notarization exists yet.
- Deliberately removed: output volume (system menu bar/Control Center already
  covers it).

## Candidates

- Improve device-change refresh for microphone mute.
- Add more manual-test evidence for login/reboot, menu-bar icons and VoiceOver.
- Keep documentation, screenshots and four READMEs synchronized with each
  release.
- Optional Developer ID signing and notarization if an Apple Developer account
  and certificate become available.
- Improve release automation and artifact reproducibility.

## Distribution implementation

- Automated release workflow for the ad-hoc universal artifact is in
  `.github/workflows/release.yml`; it rebuilds and replaces the release zip and
  checksum when a release is published or manually dispatched.
- Documentation is split into current product docs in `docs/`, engineering specs
  in `docs/en/`, and historical research/evidence under `RESEARCH.md` and the
  archive paths.

## Not planned

- Output volume, low-power mode, True Tone, desktop-icon hiding, Night Shift,
  Wi-Fi/Bluetooth toggles, audio-device switching, scenes or custom hotkey
  recording.
- Private APIs, privileged helpers, telemetry, background automation, automatic
  TCC resets.
- Sandboxing, App Store distribution, paid support, or notarization without a
  Developer ID certificate.

Scope changes must pass the checklist in [CORE.md](CORE.md) and
[../CORE.md](../CORE.md).

## Known limitations

- Screen cleaning has no keyboard exit by design; a hidden five-minute
  last-resort timer is the only automatic recovery.
- Microphone mute depends on the input device exposing a CoreAudio mute
  property.
- Rebuilding with ad-hoc signing can change code identity and cause macOS to ask
  for permissions again.
- The ad-hoc release is blocked by Gatekeeper on first launch; users must
  right-click **Open** or scope a quarantine removal to the app.
- The project is primarily developed on macOS 27; CI only builds on a GitHub
  macOS runner and does not exercise TCC or physical hardware.
- Notarization, Gatekeeper acceptance on a clean Mac, login/reboot and audio
  hardware remain manual/unverified until executed.
