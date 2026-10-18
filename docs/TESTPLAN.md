# Test plan

Status: current baseline **v0.7.2**. English is canonical. Automated checks are
not a substitute for manual TCC, hardware, login, screen-cleaning or release
verification.

## 1. Scope

Verify:

- build and app bundle integrity;
- core non-UI behavior in `SwitchPilotChecks`;
- light/dark contrast and panel sizing;
- all four UI locales and language persistence;
- ad-hoc universal release artifact structure, signature and checksum;
- regression boundaries for permissions, private APIs and screen cleaning.

Not covered by CI:

- real TCC grants/revocations;
- real login/reboot launch;
- microphone hardware behavior;
- screen saver/lock/display sleep on physical displays;
- VoiceOver quality;
- Gatekeeper first launch on a clean Mac;
- notarization (not available).

## 2. Test levels

| Level | Tool | Scope |
|---|---|---|
| Core | `SwitchPilotChecks` | Assertions, presets, permission mapping, screen saver, microphone, display sleep |
| Build | `scripts/build-app` | Compile, bundle, plist, resources, ad-hoc/local signature |
| Smoke | `make smoke` | Build, bundle, contrast, four `.lproj` tables |
| Verification | `scripts/verify-app.py` | 12-step bundle/app/launch/policy check |
| Policy | `scripts/qa-regression.py` | 13 checks for scope, TCC, APIs and safety boundaries |
| Release | `scripts/build-release` | Universal build, ad-hoc signature, zip, checksum |
| Manual | this document | TCC, hardware, UI, localization, Gatekeeper |

## 3. Automated commands

```sh
make smoke
./scripts/verify-app.py
./scripts/qa-regression.py
```

`verify-app.py` also runs `SwitchPilotChecks` and checks plist/signature,
launch smoke, original app integrity, contrast, panel sizes, semantic colors and
static scripts. CI runs the CI-safe subset and does not request TCC.

## 4. Localization test matrix

For each locale:

- follow system / forced locale;
- panel header, features, quick actions, permissions, footer;
- Settings: permissions, hotkeys, login, language, About;
- language change persists after a restart;
- permission prompts use the localized `InfoPlist.strings`;
- no clipping/ellipsis on normal panel size;
- format placeholders in diagnostics/errors remain intact.

| Locale | Required checks |
|---|---|
| Follow System | System locale selects a supported table; fallback is readable |
| English | Full panel/settings/about; format strings intact |
| 简体中文 | Full panel/settings/about; language selector labels |
| 繁體中文 | Taiwan macOS vocabulary; panel action titles fit |
| 日本語 | macOS Japanese vocabulary; long subtitles wrap at most two lines |

## 5. Release artifact checks

For a tagged release:

```sh
gh release download <tag> -p '*universal-adhoc*'
shasum -a 256 -c *.sha256
unzip SwitchPilot-*-macos-universal-adhoc.zip
lipo -info SwitchPilot.app/Contents/MacOS/SwitchPilot
codesign --verify --strict SwitchPilot.app
ls SwitchPilot.app/Contents/Resources/*.lproj
```

Expected:

- `shasum` passes;
- architecture is `x86_64 arm64`;
- signature verifies as ad-hoc (`Signature=adhoc`);
- all four `.lproj` directories exist;
- no `._*` AppleDouble files in the zip;
- `spctl --assess` rejects the ad-hoc app (expected, not a regression);
- first launch on a clean Mac requires right-click **Open**.

## 6. Manual test matrix

| Area | Check |
|---|---|
| Keep awake | Timed/indefinite toggle, real assertion, auto-release, progress |
| Dark mode | Allow/deny Automation, toggle, readback |
| Screen saver | Real activation and exit |
| Lock screen | Automation + Accessibility, lock, password unlock |
| Display sleep | Screen sleeps; wake behavior follows system settings |
| Microphone | Mute/unmute on supported input; unsupported explanation |
| Screen cleaning | Overlay, keyboard suspended, mouse exit, hidden timeout, no normal countdown |
| Login item | Register/unregister, logout/reboot launch |
| Hotkeys | Default off, enable, conflict error, disable, real trigger |
| Settings | Revoke disclosure, advanced reset confirmation, no automatic tccutil |
| UI | Light/dark, small display, larger text, VoiceOver labels |
| Panel animation | Open/close from status item, 80/60 ms scale+fade, no clipped content, outside click/Escape, Reduce Motion |
| Material/magnet | Dark/light translucency, readability over bright/dark desktops, left/right status-item edge snapping, screen-edge clamp |
| Languages | Follow System + four locales; restart persistence |
| Icons | Menu-bar template icon; app icon in Finder/System Settings |
| Release | Download, checksum, right-click Open, permission prompts |

## 7. Safety

Screen cleaning intentionally suspends keyboard input. Keep the mouse available,
verify the exit control is visible before starting, and use the hidden
five-minute failsafe only as a last resort. Do not continue on a machine you
cannot recover.

## 8. Acceptance criteria

- Automated checks pass.
- Manual checks that were executed are recorded; unexecuted checks remain
  unverified.
- Release artifact checks pass.
- No new private API, permission surface, telemetry, network access or automatic
  TCC change is introduced.
- Documentation and changelog are updated together with behavior.

Detailed commands and the current manual matrix are in
[en/TESTING.md](en/TESTING.md).
