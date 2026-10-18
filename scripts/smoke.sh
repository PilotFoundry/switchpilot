#!/bin/sh
# Open-source CI smoke test: build the Swift package, assemble the .app, and
# run the contrast-token check. It intentionally does not launch the app or
# request TCC permissions.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
swift build --package-path "$ROOT/app/SwitchPilot" --build-system native
APP=$(/bin/sh "$ROOT/scripts/build-app" | tail -n 1)
test -d "$APP"
for lang in en zh-Hans; do
    test -f "$APP/Contents/Resources/$lang.lproj/Localizable.strings"
done
test -f "$APP/Contents/Resources/en.lproj/InfoPlist.strings"
python3 "$ROOT/scripts/check-contrast.py"
printf '%s\n' "smoke: build, app bundle, and contrast checks passed"
