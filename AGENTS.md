# Repository guidance

Read `docs/en/CORE.md` and `docs/CORE.md` before changing the product scope.
SwitchPilot is an open-source, low-permission macOS menu bar app maintained by
PilotFoundry, with a deliberately small set of reliable controls. English is the
canonical documentation language.

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
- Do not add one-click distribution claims: the public binary is ad-hoc and not
  notarized until a Developer ID certificate exists.

## Documentation map

- Product docs: `docs/CORE.md`, `PRD.md`, `DESIGN.md`, `TECH.md`, `TESTPLAN.md`,
  `EXPANSION.md`, `RESEARCH.md`.
- Engineering specs: `docs/en/ARCHITECTURE.md`, `CORE.md`, `ROADMAP.md`,
  `TESTING.md`, `LOCALIZATION.md`, `RELEASE.md`, `BRAND.md`.
- `docs/README.md` is the map; keep it current.
- Localized READMEs are entry points; English docs remain canonical.

## Build and test

- `make build` / `./scripts/build-app`
- `make smoke` for the CI-safe smoke test
- `make docs-check` for Markdown links, version consistency, docs map and release-doc checks
- `./scripts/verify-app.py` for bundle, signature, policy and sizing checks
- Manual TCC/login/screen/release checks are documented in
  `docs/en/TESTING.md` and `docs/TESTPLAN.md`.

## Version and release hygiene

- Sync versions in `Info.plist`, `scripts/verify-app.py`, model fallbacks,
  `CHANGELOG.md`, `docs/en/ROADMAP.md`, four READMEs and the release tag.
- Use `make release` / `./scripts/build-release` for the universal ad-hoc zip.
- Never commit `dist/`, `.app` bundles, signing identities, certificates,
  Keychain material, TCC databases, or personal diagnostics.
- Do not use a personal signing identity for a public release.
- Release workflow: `.github/workflows/release.yml`; process:
  `docs/en/RELEASE.md`.
- Any localization change must update all four tables and, when user-facing,
  all four READMEs.

## Change hygiene

- Keep changes small and reviewable.
- Update docs and tests together with behavior changes.
- Do not rewrite historical evidence under `artifacts/`, `evidence/` or
  `tooling/`; current specs live in `docs/`.
