# Expansion evaluation

Status: current baseline **v0.7.2**. This document is a decision record for
proposed scope changes; it is not a promise that a candidate will ship.

## 1. Current boundary

SwitchPilot intentionally covers a small set of reliable controls:

- keep awake
- dark mode
- screen saver
- lock screen
- display sleep
- microphone mute
- screen cleaning
- optional login item
- fixed global hotkeys
- four-language UI with an in-app override

The product is open source and ships an ad-hoc universal binary. Distribution
improvements, not additional toggles, are the active engineering candidates.

## 2. Admission rubric

A candidate must satisfy all of the following:

1. It fills a real system gap or shortens a frequent multi-step workflow; it is
   not merely a duplicate of a menu-bar/Control Center control.
2. It can be implemented with public frameworks and no new private API.
3. It does not add an unnecessary TCC permission surface.
4. It has honest readback, visible state and a recovery path.
5. It fits the compact panel and can be localized without breaking layout.
6. It can be tested manually; CI-only evidence is insufficient for
   TCC/hardware behavior.
7. It does not weaken the safety model for screen cleaning, permissions or
   automation.

## 3. Candidates and decisions

| Candidate | Decision | Rationale |
|---|---|---|
| Improve microphone device-change refresh | Candidate | Real usability gap; public CoreAudio APIs; needs manual hardware testing |
| More login/reboot and menu-bar icon manual coverage | Candidate | Existing features need evidence, not new surface |
| VoiceOver and larger-text audit | Candidate | Accessibility hardening within existing scope |
| Automated release workflow | Implemented | Reproducible universal ad-hoc artifacts; no notarization |
| Developer ID signing + notarization | Blocked | Requires Apple Developer Program, Developer ID certificate and notary credentials |
| Developer ID distribution / sandbox / App Store | Not planned now | Larger operational and security commitment than current project scope |
| Output volume | Not planned | System menu bar/Control Center already covers it |
| Low-power mode / True Tone | Not planned | Public API or product-fit constraints; macOS already handles them |
| Night Shift, Wi-Fi/Bluetooth, desktop icons | Not planned | Private/preference hacks or duplication |
| Audio-device switching, scenes, custom hotkey recorder | Not planned | Scope expansion without a matching high-frequency gap |
| Background automation, privileged helper | Never | Violates product and security boundaries |
| Telemetry, network features, remote config | Never | Violates privacy positioning |

## 4. Distribution expansion

The current release is an ad-hoc universal zip. The next distribution milestone
would be:

- Developer ID Application signing
- hardened runtime verification
- notarization and stapling
- `spctl` acceptance on a clean Mac
- a signed `.dmg` or zip with the same four locales

This is blocked on credentials and should not be implied by the README until it
actually exists. The current caveat, checksum and manual verification steps are
defined in [en/RELEASE.md](en/RELEASE.md).

## 5. Decision log

- v0.7.0: four languages and in-app language selection shipped.
- v0.7.1: About/README positioning corrected for the open-source release; About
  no longer describes the app as personal-use-only or mentions One Switch.
- v0.7.1: ad-hoc universal binary published with checksum and Gatekeeper
  instructions.
- Next: documentation consistency, release workflow, manual test evidence; no
  new toggle is approved by this document.
