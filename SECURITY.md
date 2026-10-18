# Security

## Supported versions

Security fixes are applied to the current `main` branch and the latest release
line (currently 0.5.x). Older snapshots may not receive fixes.

## Reporting a vulnerability

Please use GitHub's private **Security advisories** flow:

https://github.com/PilotFoundry/switchpilot/security/advisories/new

Do not open a public issue for a vulnerability involving permissions, TCC,
screen cleaning, credential exposure or unsafe automation. Include:

- a description of the issue and impact;
- reproduction steps and macOS/app version;
- whether the app was built ad-hoc or with a development identity;
- relevant logs with personal paths and credentials removed.

This is a personal project maintained on a best-effort basis. There is no
bug-bounty program.

## Security boundaries

- SwitchPilot does not run a privileged helper, load private frameworks, or
  modify the TCC database.
- It does not automatically execute `tccutil reset`.
- Screen cleaning suspends keyboard events; the mouse exit and hidden
  last-resort timeout are part of the safety model. Do not bypass them.
- The app has no network access and no telemetry.
- The project does not ship notarized binaries. Build locally and verify the
  source you run. Never commit signing identities, certificates or Keychain
  material.
