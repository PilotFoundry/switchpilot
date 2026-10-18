# Changelog

All notable user-visible changes are recorded here. This project follows
semantic versioning while it is pre-1.0.

## [0.6.0] - 2026-10-18

- Add system-language English localization for the app, permission prompts,
  menus, settings, status messages and the screen-cleaning overlay; Chinese
  remains the source language and fallback.
- Add English open-source documentation and localized screenshots.
- Publish the complete development history for transparency.
- Align the README and social-preview identity with the app icon.
- Add English-first contribution, security, conduct and issue/PR guidance.

## [0.5.3] - 2026-10-18

- Keep the menu-bar icon fixed as the SwitchPilot S mark; microphone mute is
  exposed by the tooltip and right-click action instead of changing the icon.
- Record the hidden five-minute screen-cleaning failsafe as accepted.
- Document the remaining manual acceptance items.

## [0.5.2] - 2026-10-18

- Compress the panel: merge dark mode and microphone into one system card,
  2×2 action grid, conditional status lines, permission card at the top.
- Add a read-only policy-regression gate covering CORE boundaries, volume
  removal, private APIs, TCC behavior, microphone/cleaning guards, hotkeys and
  single-instance constraints.
- Add inline accessibility guidance for screen cleaning.

## [0.5.1] - 2026-10-18

- Refine the microphone action button styling.
- Repair the screen-cleaning exit control (custom-drawn, mouse-first) and remove
  the visible countdown from normal cleaning.
- Add a hidden last-resort timeout for screen cleaning.

## [0.5.0] - 2026-10-18

- Remove output-volume control; macOS already provides it.
- Add capability-aware microphone mute.
- Add screen cleaning with keyboard suspension and mouse exit.

## [0.4.1] - 2026-10-18

- Clarify muted-state presentation and record field feedback.

## [0.4.0] - 2026-10-18

- Add fixed global hotkeys (disabled by default) and display sleep.

## [0.3.9] - 2026-10-18

- Consolidate permission guidance, shorten success states, improve diagnostics
  and clarify the advanced in-app permission reset.

## [0.1.0] - 2026-10-18

- First personal-use menu bar MVP: keep awake, dark mode, screen saver and lock
  screen with permission gating.
