# UI/UX design

Status: current baseline **v0.7.4**. English is canonical. Screenshots live in
`docs/images/`; all UI must be readable in light and dark appearances.

## 1. Design principles

- **Native first.** AppKit status item, SwiftUI panel, standard controls, SF
  Symbols. No custom chrome or multi-layer visual effects.
- **State is visible.** Every action has an honest idle, active, permission,
  denied, failure or unsupported state.
- **One panel, few decisions.** The panel is a compact control surface, not a
  dashboard. Settings holds configuration and permission explanations.
- **Quiet by default.** The app is an `LSUIElement` agent with no Dock icon. The
  panel uses a short, restrained scale/fade anchored under the menu-bar icon;
  Reduce Motion removes the scale.
- **Localizable by construction.** Copy must fit English, Simplified Chinese,
  Traditional Chinese and Japanese. Language names are shown natively.

## 2. Menu-bar presence

- Template icon in the system menu bar; no color-only state.
- Left click opens the panel; the status item follows standard macOS behavior.
- Panel presentation: custom borderless `NSPanel`, 80 ms ease-out, very light
  scale 0.985 → 1 plus opacity fade, anchored at the menu-bar icon; close is
  60 ms ease-in. No popover arrow.
- Surface: behind-window `NSVisualEffectView` menu material plus a 90% adaptive
  window-background tint, rounded 12pt mask, hairline border and standard window
  shadow. The content sits transparently on the material.
- Magnet alignment: the panel's leading/trailing edge snaps 4pt outside the
  status item edge on the corresponding screen half, then clamps to the visible
  screen.
- Transient dismissal uses outside-click monitors, Escape and app activation;
  menus inside the panel must not dismiss it prematurely.
- Single instance. A second launch explains that SwitchPilot is already running.
- The menu-bar app remains useful when permissions are missing, but gated
  actions must explain what is unavailable.

## 3. Panel structure

Width: 380 pt. Normal height: about 709 pt; with the permission guide: about
782 pt. The panel is scroll-safe on smaller displays.

1. **Header** — app mark/name, version, current keep-awake summary.
2. **Keep awake** — toggle, 15/30/60/unlimited picker, readback state.
3. **Dark mode / microphone** — system appearance status and microphone
   capability/state.
4. **Quick actions** — screen saver, lock screen, display sleep, screen
   cleaning. Each tile has an icon, title, short subtitle and optional badge.
5. **Permissions** — only when needed; readiness summary, grant/recheck
   actions, diagnostics disclosure.
6. **Footer** — How to use, Settings, Quit. Permission state stays in the
   permission card and Settings rather than duplicating a footer summary.

Long localized labels wrap to at most two lines; the panel height may grow and
is measured by `--panel-size`.

## 4. Settings window

Width: about 460 pt; content is grouped into cards:

- Permissions: Automation, Accessibility, recheck, revoke guidance.
- Hotkeys: fixed shortcuts, enable toggle, conflict/error explanation.
- Login: optional `SMAppService` login item; honest registration state.
- **Language**: Follow System / English / 简体中文 / 繁體中文 / 日本語, plus
  **Quit and Reopen** because a language change requires a relaunch.
- About: SwitchPilot, version, open-source/MIT positioning, and an
  **Open source** badge. The About copy does not mention One Switch.

Settings refreshes permission state when it opens or the app becomes active.
Advanced TCC reset commands remain copy-only after explicit disclosure; the app
never runs `tccutil reset` automatically.

## 5. Screen cleaning

- Full-screen overlays on all displays.
- Session event tap suppresses keyboard input; mouse remains available.
- Visible **Exit cleaning mode** button accepts the first mouse click.
- No keyboard exit by design.
- Hidden five-minute failsafe; no countdown in normal mode.
- State must be visibly recoverable and cleaned up on app exit.

This is a safety-critical surface. Do not change the exit model without an
explicit product decision and a manual test.

## 6. Localization design

Supported locales:

| Locale | Notes |
|---|---|
| English | Canonical README; default fallback for untranslated keys |
| Simplified Chinese | Source strings are Chinese, so fallback is readable |
| Traditional Chinese | Use Taiwan macOS vocabulary (設定、螢幕、選單列、權限) |
| Japanese | Use macOS Japanese terms (メニューバー、スリープ防止、画面をロック) |

Rules:

- Do not hide controls solely because a translation is longer; wrap or shorten
  the copy instead.
- Keep format placeholders unchanged.
- Do not embed English-only abbreviations in user-facing text unless they are
  product names or platform terminology.
- Avoid putting critical warnings only in a tooltip; they must be visible.
- After a language change, show the restart instruction and the restart action.
- Localized permission prompts come from `InfoPlist.strings` and are loaded at
  launch.

## 7. Accessibility and contrast

- Use standard controls and labels; provide accessibility labels/hints where a
  custom control or icon-only action is used.
- Maintain at least 4.5:1 contrast for ink tokens on panel, card and tile
  backgrounds in light and dark modes.
- Do not use color as the sole indicator of state.
- Respect larger text and VoiceOver; manual verification remains required.

## 8. Visual identity

- Mark: the PilotFoundry helm; app icon and organization logo share the same
  family. No green palette in the organization identity.
- The menu-bar icon is monochrome/template.
- Social-preview and organization assets live under `assets/org/` and
  `assets/`.
- One Switch may be named in README attribution and legal notice, but not in the
  in-app About copy; the app is independent and does not use One Switch assets.

See [en/BRAND.md](en/BRAND.md) for naming and trademark boundaries.

## 9. Copy rules

- Prefer short, direct, native sentences over literal translation.
- Explain what is missing and what the user can do next.
- Never claim success when state could not be verified.
- Use "Follow System" for the language default, not "Auto".
- Release/download copy must state that the binary is ad-hoc and not notarized.
- Keep the four READMEs aligned on user-visible facts.

## 10. Current screenshots

- English: `docs/images/panel-light.png`, `panel-dark.png`
- Simplified Chinese: `docs/images/zh/panel-light.png`, `zh/panel-dark.png`
- Traditional Chinese: `docs/images/panel-zh-Hant.png`,
  `panel-dark-zh-Hant.png`
- Japanese: `docs/images/panel-ja.png`, `panel-dark-ja.png`
- Settings/language examples: `docs/images/settings-en.png`,
  `settings-ja.png`, `settings-zh-Hant.png`
