## Summary

<!-- What changes and why? -->

## Scope check

- [ ] Fits `docs/CORE.md` / `docs/en/CORE.md` (system gap or high-frequency long chain)
- [ ] Uses public APIs; no private framework/helper
- [ ] Handles missing permission / unsupported hardware honestly
- [ ] Does not alter TCC automatically
- [ ] Includes docs/CHANGELOG updates if behavior changed

## Verification

- [ ] `make smoke` passes
- [ ] `./scripts/verify-app.py` passes
- [ ] Manual tests performed (list):
- [ ] Known unverified items (list):

## Localization / release

- [ ] Four `.lproj` tables and `InfoPlist.strings` stay in sync (if user-facing copy changed)
- [ ] Four READMEs stay aligned on version/download facts (if applicable)
- [ ] No `dist/`, `.app`, certificates, signing identity or Keychain material committed
- [ ] Release artifact checks updated (if packaging changed)

## Screenshots / notes

<!-- If UI changed, include light/dark screenshots and relevant languages. Do not include secrets. -->
