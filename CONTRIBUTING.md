# Contributing

Thanks for considering a contribution. SwitchPilot is a personal-use project
with a deliberately narrow scope, so please read [docs/en/CORE.md](docs/en/CORE.md)
before proposing a feature.

## Good contributions

- Bug fixes with a minimal reproduction.
- Permission/error-state improvements that keep the user informed.
- Test or documentation improvements.
- Accessibility fixes.
- Small reliability improvements to existing controls.

## Product-scope changes

A new feature must answer the CORE admission checklist. In particular:

- Is it a system gap or a high-frequency long chain, rather than a duplicate of
  an existing menu-bar/Control Center control?
- Can it be implemented with public APIs and no new permission surface?
- Is it recoverable and does it expose honest state?
- Does it fit the small panel and the existing product boundaries?

Open an issue before implementing a new feature. Features that require private
APIs, privileged helpers, background automation, telemetry or automatic TCC
changes are out of scope.

## Development

```sh
git clone https://github.com/pengxianghao21/switchpilot.git
cd switchpilot
make build
make smoke
```

Optional local install:

```sh
make app
make install
```

The app is a macOS menu-bar agent (`LSUIElement`) and uses only Apple system
frameworks. Keep the Swift package free of external dependencies unless there is
a compelling reason.

## Pull requests

- Keep commits focused and explain the user-visible behavior change.
- Update docs/CHANGELOG for behavior changes.
- Add or update automated checks where practical.
- List manual tests performed and what remains unverified.
- Do not include generated `.app` bundles, build products, signing material,
  TCC databases, personal diagnostics, or unrelated files.
- Be respectful in reviews; follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Testing

`make smoke` is the CI-safe baseline. TCC and hardware tests require a person at
the Mac; see [docs/en/TESTING.md](docs/en/TESTING.md). Do not claim a manual test
passed if it was not run.

## License

By contributing, you agree that your contribution is licensed under the MIT
License in [LICENSE](LICENSE).
