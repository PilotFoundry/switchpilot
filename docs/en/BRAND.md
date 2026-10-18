# Brand and identity

Status: current identity rules for SwitchPilot and PilotFoundry.

## 1. Names

- Organization: **PilotFoundry**
- Repository: `PilotFoundry/switchpilot`
- App / product: **SwitchPilot**
- Bundle identifier: `io.github.pengxianghao21.SwitchPilot`
- License: MIT

`SwitchPilot` is the only product name used in the app and docs. Do not rename
the bundle identifier casually: it changes TCC identity.

## 2. Marks and assets

- App icon: the helm mark used by `assets/logo-1024.png`,
  `assets/logo-512.png`, `assets/logo-256.png`.
- Menu-bar icon: monochrome/template asset used by the app.
- Organization mark: `assets/org/pilotfoundry-icon-*.png`.
- Organization banner: `assets/org/pilotfoundry-brand-1600x900.png`.
- Social preview: `assets/social-preview.png`; the repository owner uploads it
  manually in GitHub settings.
- Organization avatar must be uploaded manually in GitHub organization
  settings; GitHub has no API for it.

Identity rules:

- No green in the PilotFoundry organization palette.
- The helm mark is a simplified ship's wheel; the final version has eight ivory
  grips and no colored protruding handles.
- Color belongs in the dark aurora field, not in the grips.
- The app icon and README mark must stay in the same family; do not introduce a
  second logo.

## 3. One Switch attribution

SwitchPilot was inspired by One Switch's menu-bar approach. It is independent.

Allowed:

- Naming One Switch in README inspiration/attribution.
- Naming One Switch in the legal/trademark disclaimer.
- Explaining that SwitchPilot is not affiliated with, endorsed by or distributed
  by One Switch.

Not allowed:

- Using One Switch logos, screenshots, icon styles or assets.
- Calling SwitchPilot an official One Switch product, clone, successor or
  replacement in a way that implies endorsement.
- Putting "One Switch" in the in-app About copy. The app About describes the
  open-source PilotFoundry project instead.
- Claiming code or asset derivation from One Switch.

Canonical About copy:

- English: **An open-source macOS menu-bar utility by PilotFoundry. MIT
  licensed.**
- 简体中文：**由 PilotFoundry 维护的开源 macOS 菜单栏小工具，遵循 MIT
  许可证。**
- 繁體中文：**由 PilotFoundry 維護的開源 macOS 選單列小工具，採用 MIT
  授權條款。**
- 日本語：**PilotFoundry によるオープンソースの macOS メニューバーユーティリティ。MIT ライセンス。**

Canonical attribution:

> SwitchPilot was inspired by One Switch's menu-bar approach to everyday system
> controls. It is an independent project and is not affiliated with or endorsed
> by One Switch; no One Switch code, assets or distribution binaries are
> included.

## 4. README and release copy

- Four READMEs must agree on product name, version, supported languages,
  download caveat and license.
- English is the canonical docs language; localized READMEs may translate the
  same facts but must not add contradictory claims.
- Release notes must not imply notarization or Developer ID signing when the
  build is ad-hoc.
- Do not use "personal use only" or "not for distribution" as current product
  positioning.
