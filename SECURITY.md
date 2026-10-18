# Security

## Supported versions

Security fixes are applied to the current `main` branch and the latest release
line (currently **0.7.x**). Older snapshots may not receive fixes.

## Reporting a vulnerability

Please use GitHub's private **Security advisories** flow:

https://github.com/PilotFoundry/switchpilot/security/advisories/new

Do not open a public issue for a vulnerability involving permissions, TCC,
screen cleaning, credential exposure or unsafe automation. Include:

- a description of the issue and impact;
- reproduction steps and macOS/app version;
- whether the app came from the ad-hoc release zip, a local build, or a local
  development-signed build;
- relevant logs with personal paths and credentials removed.

This is an open-source project maintained on a best-effort basis. There is no
bug-bounty program.

## Official binaries

The GitHub release may include an ad-hoc signed, universal macOS zip. It is a
convenience build, **not** a Developer ID/notarized distribution.

- Verify the published SHA-256 before opening it.
- The artifact is ad-hoc signed (`Signature=adhoc`); `spctl --assess` is expected
  to reject it because it is not notarized.
- On first launch, right-click the app and choose **Open**, or scope quarantine
  removal to this app:
  `xattr -dr com.apple.quarantine /Applications/SwitchPilot.app`
- Do not disable Gatekeeper system-wide, and do not disable SIP.
- For a higher trust level, build from the tagged source and sign it yourself.

The exact artifact, checksum and verification procedure are in
[docs/en/RELEASE.md](docs/en/RELEASE.md).

## Security boundaries

- SwitchPilot does not run a privileged helper, load private frameworks, or
  modify the TCC database.
- It does not automatically execute `tccutil reset`.
- Screen cleaning suspends keyboard events; the mouse exit and hidden
  last-resort timeout are part of the safety model. Do not bypass them.
- The app has no network access, telemetry, analytics or remote configuration.
- Permissions are requested only from explicit user actions.
- The app does not record microphone audio; it only reads/writes the mute
  property.
- No settings, diagnostics or user data are uploaded anywhere.
- The project does not ship notarized binaries. Release binaries are ad-hoc and
  must never contain signing identities, certificates, Keychain material or
  Developer ID credentials.
- TCC behavior is sensitive to signing identity changes; rebuilding with a
  different identity can require re-approval.

## Release integrity

For releases:

1. Check the artifact name and version.
2. Verify the SHA-256 file next to the zip.
3. Confirm the app is universal (`arm64 + x86_64`) and ad-hoc signed.
4. Confirm all four localized resources are present if localization matters to
   your deployment.
5. Treat the first-launch Gatekeeper warning as expected for this distribution
   path; do not bypass it globally.

## Dependency and build posture

- No third-party Swift packages.
- GitHub Actions workflows use pinned action major versions and the repository
  token; the release workflow does not receive Apple signing credentials.
- CodeQL and the CI-safe smoke test run on the public repository.
- Manual TCC, login-item, screen-cleaning, audio-hardware and Gatekeeper checks
  are not covered by CI. See `docs/en/TESTING.md`.
