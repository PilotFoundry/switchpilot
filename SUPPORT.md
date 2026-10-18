# Support

SwitchPilot is an open-source, best-effort project maintained by PilotFoundry.
There is no guaranteed response time or commercial support.

## First steps

- Read the [README](README.md) and the [documentation map](docs/README.md).
- Read [docs/en/CORE.md](docs/en/CORE.md) for the product boundary.
- Check [docs/en/ROADMAP.md](docs/en/ROADMAP.md) and
  [docs/en/TESTING.md](docs/en/TESTING.md) for known limitations and manual test
  coverage.

## Usage and release questions

For usage questions and general discussion, open a GitHub issue with the
appropriate template. Include:

- macOS version;
- SwitchPilot version;
- whether you used the ad-hoc release zip or a local build;
- CPU architecture (Apple Silicon or Intel);
- selected language (Follow System / English / 简体中文 / 繁體中文 / 日本語);
- steps, expected/actual behavior;
- whether the relevant permissions were granted.

For release binaries, state clearly that the app is ad-hoc signed and not
notarized; first launch may require right-click **Open**. See
[docs/en/RELEASE.md](docs/en/RELEASE.md).

## Bugs

Include a minimal reproduction, macOS/app version, build method, locale and
permission state. Do not paste TCC databases, Keychain data, certificates,
personal paths or unrelated logs.

## Security

Use [SECURITY.md](SECURITY.md), not a public issue. Do not post exploit details
or signing material publicly.

## Feature requests

SwitchPilot deliberately keeps a small scope. Read
[docs/en/CORE.md](docs/en/CORE.md) and [docs/CORE.md](docs/CORE.md) before
proposing a feature. A new control must fill a system gap or high-frequency long
chain, use public APIs, expose honest state and remain recoverable.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development, localization and release
expectations.
