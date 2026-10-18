# Localization

Status: current contract for **v0.7.3**. English is canonical for docs; the app
and its READMEs are localized into four languages.

## 1. Supported locales

| Locale | Resource | Role |
|---|---|---|
| English | `en.lproj` | Canonical docs, release notes, fallback for technical keys |
| Simplified Chinese | `zh-Hans.lproj` | Source-string language; fallback is readable |
| Traditional Chinese | `zh-Hant.lproj` | Taiwan macOS vocabulary |
| Japanese | `ja.lproj` | macOS Japanese vocabulary |

Default behavior is **Follow System**. Settings → Language can force a locale.
A change requires a relaunch.

## 2. Source-string contract

- The Chinese source string is the localization key.
- Every user-facing key must exist in `en`, `zh-Hans`, `zh-Hant` and `ja`.
  `zh-Hans` is an identity table for the source language.
- Format placeholders (`%@`, `%d`, `%02d`, `%%`) must be preserved exactly.
- Do not translate product names (`SwitchPilot`, `SwitchPilot Local Signing`,
  `System Events`), API names, command names or bundle identifiers.
- Do not change a source key without updating all four tables.
- Keep technical/error keys in English where a faithful local translation would
  be misleading, but localize the user-facing explanation around them.

## 3. Resource layout

```text
app/SwitchPilot/Resources/
  en.lproj/Localizable.strings
  en.lproj/InfoPlist.strings
  zh-Hans.lproj/Localizable.strings
  zh-Hans.lproj/InfoPlist.strings
  zh-Hant.lproj/Localizable.strings
  zh-Hant.lproj/InfoPlist.strings
  ja.lproj/Localizable.strings
  ja.lproj/InfoPlist.strings
```

`scripts/build-app` and `scripts/build-release` copy every `.lproj` into the app.
`InfoPlist.strings` supplies the localized Automation usage description and
display name. Permission prompts are resolved at launch, so a language change
must restart the app.

## 4. Runtime selection

1. `AppLanguage` represents `system`, `en`, `zh-Hans`, `zh-Hant`, `ja`.
2. `LanguagePreference` persists the selection under `switchpilot.language`.
3. `LanguagePreference.applyAtLaunch()` runs before AppKit/SwiftUI resolve
   resources. It sets the app-scoped `AppleLanguages` default for a forced
   locale, or removes it for Follow System.
4. Static SwiftUI `Text("中文 key")` uses the bundle selected by
   `AppleLanguages`.
5. Dynamic/AppKit strings use `L()` / `LF()`; these resolve the selected `.lproj`
   explicitly so status and error messages match the static UI.
6. `SWITCHPILOT_LANGUAGE=en|zh-Hans|zh-Hant|ja` is a development/screenshot-only
   override; it is not shown as a user preference.

## 5. UI and language switch

- Picker labels are native: English, 简体中文, 繁體中文, 日本語.
- The current selection is persisted immediately.
- The app cannot swap a running bundle's localization reliably, so Settings
  shows **Quit and Reopen**. The restart action relaunches the same app bundle.
- Follow System removes the app-scoped `AppleLanguages` value on the next launch.
- Do not promise a language change without a restart.

## 6. Copy and layout rules

- Prefer native, concise UI language over literal translation.
- Japanese/Traditional Chinese titles may be longer; verify panel tile wrapping
  and settings layout.
- Do not hide a control because a translation is long; shorten or wrap it.
- Do not put critical permission/safety information only in a tooltip.
- Keep localized README download/build facts equivalent to the English README.
- The in-app About copy must not claim One Switch affiliation or endorsement.

## 7. Adding or changing a locale

1. Add `.lproj` resources and all keys.
2. Preserve placeholders and key parity with English.
3. Add the locale to `AppLanguage` only if it is a supported app UI locale.
4. Update `InfoPlist.strings`.
5. Update `scripts/smoke.sh` resource checks if the supported set changes.
6. Add screenshots for panel/settings and verify long strings.
7. Update the four READMEs where user-facing facts or download instructions
   changed.
8. Run `make smoke`, `./scripts/verify-app.py` and the manual language matrix.

## 8. Verification

Minimum checks:

- Key parity and placeholder preservation across four tables.
- `en`, `zh-Hans`, `zh-Hant`, `ja` `.lproj` directories in the built app.
- Follow System and forced locale selection.
- Restart persistence.
- Panel, settings, About and permission prompt in each language.
- No clipping/ellipsis on the normal panel.
- Localized `InfoPlist.strings` for Automation usage text.

The manual matrix lives in [TESTING.md](TESTING.md) and
[../TESTPLAN.md](../TESTPLAN.md).
