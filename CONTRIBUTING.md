# Contributing

Thanks for considering a contribution. SwitchPilot is an open-source project
maintained by PilotFoundry, with a deliberately narrow scope. Read
[docs/en/CORE.md](docs/en/CORE.md) and [docs/CORE.md](docs/CORE.md) before
proposing a feature.

## Good contributions

- Bug fixes with a minimal reproduction.
- Permission/error-state improvements that keep the user informed.
- Accessibility and localization fixes across all four supported locales.
- Test, documentation and release-tooling improvements.
- Small reliability improvements to existing controls.

## Product-scope changes

A new feature must answer the CORE admission checklist. In particular:

- Is it a system gap or a high-frequency long chain, rather than a duplicate of
  an existing menu-bar/Control Center control?
- Can it be implemented with public APIs and no new permission surface?
- Is it recoverable and does it expose honest state?
- Does it fit the small panel and remain readable in all four languages?

Open an issue before implementing a new feature. Features that require private
APIs, privileged helpers, background automation, telemetry or automatic TCC
changes are out of scope.

## Development

```sh
git clone https://github.com/PilotFoundry/switchpilot.git
cd switchpilot
make build
make smoke
./scripts/verify-app.py
```

Optional local install:

```sh
make app
make install
```

The app is a macOS menu-bar agent (`LSUIElement`) and uses only Apple system
frameworks. Keep the Swift package free of external dependencies unless there is
a compelling reason.

## Localization changes

- The app supports `en`, `zh-Hans`, `zh-Hant` and `ja`.
- Chinese source strings are the keys; every supported key must exist in all four
  tables with placeholders preserved.
- Update `InfoPlist.strings` when permission/display copy changes.
- Verify panel/settings layout for long Japanese/Traditional Chinese strings.
- Update the four READMEs when user-facing facts, language support or download
  instructions change.
- The full contract is [docs/en/LOCALIZATION.md](docs/en/LOCALIZATION.md).

## Documentation

English is canonical. Run `make docs-check` when changing READMEs, docs, version references, release docs or the PR template. Product docs live in `docs/`; engineering specs live in
`docs/en/`. Keep the [documentation map](docs/README.md), READMEs, CHANGELOG and
version references aligned.

## Release and packaging

- Do not commit generated `.app` bundles, `dist/` artifacts, build products,
  signing material, certificates, TCC databases or personal diagnostics.
- `make release` / `scripts/build-release` creates the universal ad-hoc zip.
- Never set `SWITCHPILOT_SIGN_IDENTITY` for a public release; it is for local
  development only.
- Release workflow and verification steps are in
  [docs/en/RELEASE.md](docs/en/RELEASE.md).

## Pull requests

- Keep commits focused and explain the user-visible behavior change.
- Update docs/CHANGELOG for behavior changes.
- Add or update automated checks where practical.
- List manual tests performed and what remains unverified.
- Include screenshots for UI changes in light/dark and relevant languages.
- Be respectful in reviews; follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Testing

`make smoke` is the CI-safe baseline. TCC, hardware, login, screen-cleaning,
Gatekeeper and release-artifact checks require a person at the Mac; see
[docs/en/TESTING.md](docs/en/TESTING.md) and [docs/TESTPLAN.md](docs/TESTPLAN.md).
Do not claim a manual test passed if it was not run.

## License

By contributing, you agree that your contribution is licensed under the MIT
License in [LICENSE](LICENSE).
