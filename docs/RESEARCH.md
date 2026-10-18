# Research and history

Status: current overview. This document explains where SwitchPilot came from and
how early findings shaped the current product. It is not a current specification;
use the documents in [README.md](README.md) for implementation and acceptance.

## 1. Origin

SwitchPilot began as a personal investigation into a few macOS menu-bar controls
that were either missing or required a long chain of system settings. One Switch
was an inspiration for the menu-bar-first idea. SwitchPilot is independent: it
does not contain One Switch code, assets or distribution binaries and is not
affiliated with or endorsed by One Switch.

The repository keeps the complete development record, including failed
experiments and local acceptance notes. Historical material lives under
`artifacts/`, `evidence/` and `tooling/`; it is evidence of the journey, not
current product guidance.

## 2. Feasibility findings

- **Keep awake** can be implemented with public IOKit power assertions; it does
  not require a private helper.
- **Dark mode** depends on Automation/System Events because the public
  appearance API does not provide the required cross-process switch.
- **Lock screen and screen saver** need the right permission/shortcut path; they
  must report denied/unavailable states honestly.
- **Display sleep** has a public command: `pmset displaysleepnow`.
- **Microphone mute** depends on the input device exposing a CoreAudio mute
  property; unsupported devices must be described honestly.
- **Screen cleaning** requires a real keyboard event tap and mouse exit; a simple
  overlay is not a true keyboard lock.
- **Night Shift, True Tone, desktop-icon hiding, Wi-Fi/Bluetooth and output
  volume** were rejected for scope, private-API or product-fit reasons.

## 3. Product evolution

- Early builds were local-only experiments with a personal bundle identifier.
- The project later moved to an open-source repository under PilotFoundry with a
  public bundle identifier and MIT license.
- v0.6.0 established the English-first repository and complete history.
- v0.7.0 added Traditional Chinese, Japanese and in-app language selection.
- v0.7.1 aligned the About copy with the open-source release, removed One Switch
  from the in-app About text, and published an ad-hoc universal binary.
- The current documentation now separates product requirements, design,
  technical design, test plan, localization and release engineering.

## 4. What survived

The current implementation retains only the controls that passed the admission
rules in [CORE.md](CORE.md):

- keep awake
- dark mode
- screen saver
- lock screen
- display sleep
- microphone mute
- screen cleaning
- optional login item
- fixed hotkeys
- four-language UI

The small surface is intentional; feature breadth is not a success metric.

## 5. Evidence and limits

Historical acceptance notes were captured on specific local machines and macOS
versions. They are not portable guarantees. Permission, login, screen, audio and
Gatekeeper behavior must be re-verified manually on each target environment.
See [TESTPLAN.md](TESTPLAN.md) and [en/TESTING.md](en/TESTING.md).

## 6. Further reading

- Product boundary: [CORE.md](CORE.md)
- Product requirements: [PRD.md](PRD.md)
- Design: [DESIGN.md](DESIGN.md)
- Technical design: [TECH.md](TECH.md)
- Expansion decisions: [EXPANSION.md](EXPANSION.md)
- Current engineering docs: [README.md](README.md)
