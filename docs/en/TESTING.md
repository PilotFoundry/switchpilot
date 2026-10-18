# Testing

SwitchPilot does not use XCTest because the local Command Line Tools setup does
not include the XCTest runtime. Core assertions live in the `SwitchPilotChecks`
executable; UI and system-integration checks are documented here.

## Automated checks

```sh
make smoke
```

`scripts/smoke.sh`:

1. builds the Swift package with the native build system;
2. assembles and ad-hoc signs the `.app`;
3. runs the contrast-token checker.

The GitHub Actions workflow runs the same smoke test on a macOS runner. It does
not launch the menu-bar app or request TCC permissions, and it does not test
screen or audio hardware.

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
| Microphone | Mute/unmute on supported input; unsupported device explanation |
| Screen cleaning | Overlay, keyboard suspended, mouse exit, no countdown in normal mode, hidden timeout behavior |
| Login item | Register/unregister, logout/reboot launch |
| Hotkeys | Default off, enable, conflict error, disable, real key trigger |
| Settings | Revoke disclosure, advanced reset confirmation, no automatic tccutil |
| UI | Light/dark, small display, larger text, VoiceOver labels |
| Icons | Menu-bar template icon, app icon in Finder/System Settings |

## Safety when testing screen cleaning

The cleaning mode intentionally suspends the keyboard. Keep the mouse available,
verify the exit button is on screen before starting, and use the hidden
five-minute failsafe only as a last resort. Record any failure and avoid
continuing the test on a machine you cannot recover.
