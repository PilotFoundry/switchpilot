## [Unreleased]

- Add a documentation consistency workflow and `make docs-check` (links,
  versions, docs map, release references) plus a PR-template Docs impact field.
- Rewrite the product docs (`CORE`, `PRD`, `DESIGN`, `TECH`, `TESTPLAN`,
  `EXPANSION`, `RESEARCH`) for the current open-source, four-language,
  ad-hoc-binary baseline.
- Add canonical engineering specs for localization, release engineering and
  brand/attribution.
- Correct stale personal-use/no-distribution wording in SECURITY, SUPPORT,
  CONTRIBUTING, AGENTS, SECURITY-INSIGHTS, README and the issue/PR templates.
- Add an automated release workflow for the universal ad-hoc artifact.

# Changelog

All notable user-visible changes are recorded here. This project follows
semantic versioning while it is pre-1.0.

## [0.7.8] - 2026-10-18

- Remove the final screen-cleaning completion line ("清洁：已退出清洁模式").
  Quick actions are now fire-and-forget: no success/completion/history line.
- Keep failure and permission feedback; screen-cleaning failures remain in the
  dedicated error row.
- Extend the self-evident UI principle with "quick actions are fire-and-forget".
- Refresh docs/screenshots for the cleaner quick-actions card.

## [0.7.7] - 2026-10-18

- Remove the persistent screen-cleaning exit hint. The action label and overlay
  already explain the interaction; good UI should not narrate everything.
- Suppress successful status lines for screen saver, lock screen and display
  sleep. Failures and permission gaps still surface; screen-cleaning recovery
  status remains visible.
- Add a "self-evident over annotated" principle to the product/design docs.
- Revert panel height docs to 709 pt (782 pt with the guide).
- Refresh screenshots for the cleaner quick-actions card.

## [0.7.6] - 2026-10-18

- Add a persistent in-panel hint explaining how to exit screen cleaning:
  move the mouse and click "Exit cleaning mode".
- Update the panel height docs to 731 pt (804 pt with the permission guide).
- Refresh the design/requirements/test docs and localized README feature tables.
- Keep the v0.7.5 Settings Command-W fix and regression checks.

## [0.7.5] - 2026-10-18

- Make the Settings window close with Command-W. The app is LSUIElement and
  has no main menu, so there was no File > Close key equivalent; add a
  SettingsWindow key-equivalent handler plus a local key monitor fallback.
- Add Escape-to-close on the Settings window.
- Add `--settings-close-key-test` and extend verify/QA regression checks.

## [0.7.4] - 2026-10-18

- Remove the duplicate permission status line from the panel footer. Missing
  permissions remain visible in the permission card; full status remains in
  Settings.
- Reduce the normal panel height to about 709 pt (782 pt with the permission
  guide).
- Keep the v0.7.3 click-path fixes and regression checks.

## [0.7.3] - 2026-10-18

- Fix panel buttons receiving no clicks:
  - make the material `NSVisualEffectView` click-through;
  - disable hit testing on the cosmetic border overlay;
  - activate the accessory app and make the panel key when showing it, so the
    first click performs the SwiftUI action.
- Add a runtime `--panel-hit-test` regression probe and a QA source guard for
  material click-through, border hit testing and panel activation.
- `verify-app.py` now has 13 checks; `qa-regression.py` now has 14.
- Keep the v0.7.2 panel animation, 90% menu material and magnet alignment.

## [0.7.2] - 2026-10-18

- Replace the AppKit `NSPopover` with a custom borderless, non-activating
  `NSPanel` (`PanelWindowController`).
- Add an 80 ms open / 60 ms close scale+fade animation, anchored to the
  menu-bar status item.
- Add a dark behind-window menu material with an adaptive 90% background tint,
  rounded mask, hairline border and window shadow.
- Add magnet edge alignment: the panel's leading/trailing edge snaps 4 pt
  outside the status item and is clamped to the visible screen.
- Preserve transient dismissal (outside click, Escape, app activation), keep
  SwiftUI menus open, and support Reduce Motion.
- Add docs for panel presentation, material and magnet alignment.

## [0.7.1] - 2026-10-18

- Reword the About section for the open-source release: it now describes
  SwitchPilot as an open-source macOS menu-bar utility maintained by
  PilotFoundry under the MIT license, instead of describing it as a personal,
  non-distributed One Switch replacement.
- Change the About badge from "personal use" to "open source" in every locale.
- Add an ad-hoc universal binary release asset and multilingual download
  instructions (not notarized; right-click Open required on first launch).

## [0.7.0] - 2026-10-18

- Add Traditional Chinese and Japanese UI localizations.
- Add a Settings → Language selector (Follow System, English, 简体中文,
  繁體中文, 日本語) with an explicit "Quit and Reopen" action so the bundle
  localization and permission prompts reload consistently.
- Add localized InfoPlist strings for Japanese and Traditional Chinese.
- Keep English and Simplified Chinese behavior unchanged.
- Add an optional ad-hoc universal release zip for download convenience; it is
  not notarized and still requires the macOS right-click Open step.

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
