# Testing

SwitchPilot does not use XCTest because the local Command Line Tools setup does
not include the XCTest runtime. Core assertions live in the `SwitchPilotChecks`
executable; UI and system-integration checks are documented here. The
product-level plan is [../TESTPLAN.md](../TESTPLAN.md).

## Automated checks

```sh
make smoke
./scripts/verify-app.py
./scripts/qa-regression.py
```

`scripts/smoke.sh`:

1. builds the Swift package with the native build system;
2. assembles and ad-hoc signs the `.app`;
3. checks `en`, `zh-Hans`, `zh-Hant` and `ja` Localizable/InfoPlist resources;
4. runs the contrast-token checker.

The GitHub Actions workflow runs the same smoke test on a macOS runner. It does
not launch the menu-bar app, request TCC permissions, or test screen/audio
hardware. The release workflow separately builds the universal ad-hoc zip when a
release is published; it also does not notarize or exercise TCC.

`SwitchPilotChecks` contains checks for keep-awake assertions, presets,
permission-state mapping, screen-saver availability, microphone readback,
display-sleep command availability and other core behavior. Running it outside
the assembled app may not provide a bundle identifier; it is primarily a local
maintainer check.

## Manual test matrix

Run these on a Mac where you can grant/revoke permissions and observe screen
state. Do not record a check as passed if it was not executed.

| Area | Check |
|---|---|
| Keep awake | Timed/indefinite toggle, real assertion, auto-release, progress |
| Dark mode | Allow/deny Automation, toggle, readback |
| Screen saver | Real activation and exit |
| Lock screen | Automation + Accessibility, lock, password unlock |
| Display sleep | Screen sleeps; wake behavior follows system settings |
| Microphone | Mute/unmute on supported input; unsupported explanation |
| Screen cleaning | Overlay, keyboard suspended, visible mouse-exit hint, mouse exit, no countdown in normal mode, hidden timeout behavior |
| Login item | Register/unregister, logout/reboot launch |
| Hotkeys | Default off, enable, conflict error, disable, real key trigger |
| Settings | Revoke disclosure, advanced reset confirmation, no automatic tccutil; Command-W and Escape close the window |
| UI | Light/dark, small display, larger text, VoiceOver labels |
| Languages | Follow System + English, 简体中文, 繁體中文, 日本語; restart persistence |
| Icons | Menu-bar template icon, app icon in Finder/System Settings |
| Release | Download zip, verify SHA-256, universal architecture, ad-hoc codesign, all `.lproj`, right-click Open on first launch |

## Release artifact checks

```sh
VERSION=0.7.6
ZIP=dist/SwitchPilot-${VERSION}-macos-universal-adhoc.zip
shasum -a 256 -c "$ZIP.sha256"
unzip -q "$ZIP"
lipo -info SwitchPilot.app/Contents/MacOS/SwitchPilot
codesign --verify --strict SwitchPilot.app
codesign -dv --verbose=4 SwitchPilot.app   # expect Signature=adhoc
find SwitchPilot.app/Contents/Resources -maxdepth 1 -name '*.lproj'
spctl --assess --type execute --verbose=2 SwitchPilot.app  # expected: rejected
```

`spctl` rejection is expected for an ad-hoc, non-notarized build. Do not treat it
as a reason to disable Gatekeeper globally. See [RELEASE.md](RELEASE.md).

## Localization smoke

`scripts/smoke.sh` verifies the four resource directories exist. It does not
check key parity or layout. The manual language matrix above is still required;
see [LOCALIZATION.md](LOCALIZATION.md) for the full contract.

## Safety when testing screen cleaning

The cleaning mode intentionally suspends the keyboard. Keep the mouse available,
verify the exit button is on screen before starting, and use the hidden
five-minute failsafe only as a last resort. Record any failure and avoid
continuing the test on a machine you cannot recover.

## CI limitations

- No TCC grants, login/reboot, audio hardware, display hardware or screen-cleaning
  keyboard suppression.
- No notarization or Gatekeeper acceptance.
- No release publication on ordinary CI; the dedicated release workflow handles
  artifact upload.
