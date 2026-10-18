# Release engineering

Status: current release process for **v0.7.4**. The project publishes an
ad-hoc universal binary for convenience. It does **not** have a Developer ID
certificate or notarization.

## 1. Release artifacts

Current naming:

```text
SwitchPilot-<version>-macos-universal-adhoc.zip
SwitchPilot-<version>-macos-universal-adhoc.zip.sha256
```

Properties:

- universal `arm64` + `x86_64`;
- macOS 14+;
- ad-hoc signed with hardened runtime;
- includes all four `.lproj` resources and localized `InfoPlist.strings`;
- no personal signing identity, certificate or Keychain material;
- no AppleDouble `._*` files;
- portable checksum file containing the bare artifact name.

## 2. Version bump checklist

Update together:

1. `app/SwitchPilot/Info.plist` (`CFBundleShortVersionString`).
2. `scripts/verify-app.py` expected version.
3. Fallbacks in `PanelModel` / `SettingsModel`.
4. `CHANGELOG.md`.
5. `docs/en/ROADMAP.md` baseline version.
6. All four README version/download references.
7. Release notes and tag.
8. Run `make docs-check` after the version/README/release-doc updates.

Use one version for the app, source tag and artifact. Do not bump only one
surface.

## 3. Build

```sh
./scripts/build-release
```

The script:

1. reads the version from `Info.plist`;
2. cross-builds release binaries for `arm64-apple-macosx14.0` and
   `x86_64-apple-macosx14.0`;
3. combines them with `lipo`;
4. assembles `dist/SwitchPilot.app`;
5. copies `Info.plist`, the app icon and every `.lproj`;
6. ad-hoc signs with hardened runtime and `Entitlements.plist`;
7. strips resource forks, produces the zip and a portable SHA-256 file.

Do not set `SWITCHPILOT_SIGN_IDENTITY` for a public release. That variable is for
local development identities only.

## 4. Verify before upload

```sh
VERSION=0.7.4
ZIP=dist/SwitchPilot-${VERSION}-macos-universal-adhoc.zip
shasum -a 256 -c "$ZIP.sha256"
unzip -l "$ZIP"
lipo -info dist/SwitchPilot.app/Contents/MacOS/SwitchPilot
codesign --verify --strict dist/SwitchPilot.app
codesign -dv --verbose=4 dist/SwitchPilot.app
find dist/SwitchPilot.app/Contents/Resources -maxdepth 1 -name '*.lproj'
```

Expected signature result: `Signature=adhoc`, `TeamIdentifier=not set`.
`spctl --assess --type execute` should reject the app because it is not
notarized. That is expected and must be documented, not "fixed" by disabling
Gatekeeper.

## 5. Upload

Manual path:

```sh
gh release upload "$TAG" "$ZIP" "$ZIP.sha256" --clobber
```

Release notes must include:

- artifact name and architecture;
- macOS requirement;
- a pointer to the attached `.sha256` file (or a hash updated after every
  workflow rebuild);
- ad-hoc/not-notarized warning;
- right-click **Open** or scoped `xattr` command;
- a statement that no Developer ID build exists.

The automated path is `.github/workflows/release.yml`, triggered when a release
is published or manually dispatched for an existing tag. It rebuilds and
replaces the zip/checksum using the repository token. It does not notarize.
Because a rerun can change the zip's hash, prefer linking the `.sha256` asset
over hard-coding a hash in the release notes.

## 6. Gatekeeper wording

Use:

> This build is ad-hoc signed and not notarized. On first launch, macOS may
> block it. Right-click the app and choose **Open**, or scope the quarantine
> removal to this app:
> `xattr -dr com.apple.quarantine /Applications/SwitchPilot.app`
> Do not disable Gatekeeper system-wide.

Do not say "download and run with no prompt". Do not tell users to disable SIP or
Gatekeeper globally.

## 7. Future Developer ID path

When a Developer ID certificate and notary credentials exist:

1. build the same universal app;
2. sign with Developer ID Application + hardened runtime;
3. submit with `xcrun notarytool submit --wait`;
4. `xcrun stapler staple`;
5. verify with `spctl --assess` and `stapler validate`;
6. update README/release notes to remove the ad-hoc caveat;
7. keep the checksum and test the downloaded artifact on a clean Mac.

Until then, do not claim notarization, signing trust or one-click Gatekeeper
acceptance.

## 8. Rollback

Keep the previous release and `/tmp/switchpilot-backup` local backup during a
local update. A release tag must not be moved to a different app binary after
users have downloaded it; documentation-only tag moves should be called out in
the release notes or avoided.
