# Repository guidance

Read `docs/en/CORE.md` before changing the product scope. SwitchPilot is a
personal-use, low-permission macOS menu bar app with a deliberately small set
of reliable controls.

## Product rules

- Prefer public macOS/CoreAudio/IOKit/Carbon APIs.
- Do not add private frameworks, privileged helpers, background automation,
  telemetry, or automatic `tccutil reset`.
- Do not duplicate a control that is already available in the menu bar/Control
  Center unless it removes a genuinely long, high-frequency chain.
- Permissions must be requested only from an explicit user action and must
  degrade honestly when unavailable.
- Screen cleaning is a real keyboard lock. Keep the mouse exit, hidden
  last-resort timeout, and visible/recoverable state; do not add a keyboard exit
  without an explicit product decision.

## Build and test

- `make build` / `./scripts/build-app`
- `make smoke` for the CI-safe smoke test
- Manual TCC/login/screen tests are documented in `docs/en/TESTING.md`.

## Change hygiene

- Keep changes small and reviewable.
- Do not commit signing identities, certificates, Keychain material, TCC
  databases, personal diagnostics, or generated `.app` bundles.
- Update docs and tests together with behavior changes.
