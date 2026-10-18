#!/usr/bin/env python3
"""Validate the current documentation set.

This is deliberately a consistency check, not a "every feature PR must modify
docs" gate. It catches objective drift that review often misses:

* broken local Markdown links;
* version drift between Info.plist, four READMEs, ROADMAP, CHANGELOG and
  verify-app.py;
* release artifact names not matching the app version;
* docs/README.md not listing every current product/engineering document;
* release docs drifting away from the release workflow/build script.

Historical material under artifacts/, evidence/ and tooling/ is intentionally
excluded. English docs are canonical; localized READMEs are checked for the
version/artifact facts that must agree.
"""

from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent

# Canonical docs and the four localized entry points. Do not include historical
# archives here; they are allowed to contain dead links to old experiments.
FILES = [
    *sorted(ROOT.glob("README*.md")),
    *sorted((ROOT / "docs").rglob("*.md")),
    ROOT / "CONTRIBUTING.md",
    ROOT / "SUPPORT.md",
    ROOT / "SECURITY.md",
    ROOT / "AGENTS.md",
    ROOT / ".github/pull_request_template.md",
]

VERSION_RE = re.compile(r"\d+\.\d+\.\d+")
ARTIFACT_RE = re.compile(r"SwitchPilot-(\d+\.\d+\.\d+)-macos-universal-adhoc\.zip")
LINK_RE = re.compile(r"!?\[[^\]]*]\(([^)]+)\)")

errors: list[str] = []
passes: list[str] = []


def fail(message: str) -> None:
    errors.append(message)


def ok(message: str) -> None:
    passes.append(message)


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def read(path: Path) -> str:
    if not path.exists():
        fail(f"missing file: {rel(path)}")
        return ""
    return path.read_text(encoding="utf-8")


def local_link_targets(text: str) -> list[str]:
    targets: list[str] = []
    for raw in LINK_RE.findall(text):
        target = raw.strip()
        if target.startswith("<") and target.endswith(">"):
            target = target[1:-1]
        if not target or target.startswith(("#", "http://", "https://", "mailto:")):
            continue
        target = unquote(target.split("#", 1)[0].split("?", 1)[0])
        if not target:
            continue
        targets.append(target)
    return targets


def check_links() -> None:
    checked = 0
    for path in FILES:
        text = read(path)
        if not text:
            continue
        for target in local_link_targets(text):
            if target.startswith("/"):
                resolved = ROOT / target.lstrip("/")
            else:
                resolved = (path.parent / target).resolve()
            if not resolved.exists():
                fail(f"broken link: {rel(path)} -> {target}")
            checked += 1
    ok(f"local Markdown links resolve ({checked} links)")


def version_from_info_plist() -> str | None:
    path = ROOT / "app/SwitchPilot/Info.plist"
    if not path.exists():
        fail("missing app/SwitchPilot/Info.plist")
        return None
    try:
        with path.open("rb") as fh:
            version = plistlib.load(fh).get("CFBundleShortVersionString")
    except Exception as exc:  # noqa: BLE001 - report a useful diagnostic
        fail(f"cannot read Info.plist version: {exc}")
        return None
    if not isinstance(version, str) or not VERSION_RE.fullmatch(version):
        fail(f"invalid CFBundleShortVersionString: {version!r}")
        return None
    return version


def check_versions(version: str) -> None:
    expected_artifact = f"SwitchPilot-{version}-macos-universal-adhoc.zip"

    readme_patterns = {
        "README.md": re.compile(r"Version\s+(\d+\.\d+\.\d+)"),
        "README.zh-CN.md": re.compile(r"版本\s+(\d+\.\d+\.\d+)"),
        "README.zh-Hant.md": re.compile(r"版本\s+(\d+\.\d+\.\d+)"),
        "README.ja.md": re.compile(r"バージョン\s+(\d+\.\d+\.\d+)"),
    }
    for name, pattern in readme_patterns.items():
        text = read(ROOT / name)
        match = pattern.search(text)
        if not match:
            fail(f"{name}: version line not found")
            continue
        if match.group(1) != version:
            fail(f"{name}: version {match.group(1)} != {version}")
        if expected_artifact not in text:
            fail(f"{name}: expected release artifact {expected_artifact}")
        if "docs/README.md" not in text:
            fail(f"{name}: missing documentation map link")
    ok(f"README versions and artifacts agree ({version})")

    roadmap = read(ROOT / "docs/en/ROADMAP.md")
    match = re.search(r"Version:\s*\*{0,2}(\d+\.\d+\.\d+)", roadmap)
    if not match or match.group(1) != version:
        fail(f"docs/en/ROADMAP.md: version does not match {version}")
    ok(f"ROADMAP version agrees ({version})")

    verify = read(ROOT / "scripts/verify-app.py")
    if f'!= "{version}"' not in verify:
        fail(f"scripts/verify-app.py: expected version {version} not found")
    ok(f"verify-app expected version agrees ({version})")

    changelog = read(ROOT / "CHANGELOG.md")
    if f"## [{version}]" not in changelog:
        fail(f"CHANGELOG.md: missing ## [{version}] section")
    ok(f"CHANGELOG contains {version}")

    security_insights = read(ROOT / "SECURITY-INSIGHTS.yml")
    if f"v{version}" not in security_insights:
        fail(f"SECURITY-INSIGHTS.yml: missing v{version}")
    ok(f"SECURITY-INSIGHTS lists v{version}")

    # The zip/checksum naming contract in the release spec should not drift.
    release = read(ROOT / "docs/en/RELEASE.md")
    if "SwitchPilot-<version>-macos-universal-adhoc.zip" not in release:
        fail("docs/en/RELEASE.md: release artifact naming contract missing")
    if "SwitchPilot-<version>-macos-universal-adhoc.zip.sha256" not in release:
        fail("docs/en/RELEASE.md: checksum naming contract missing")


def check_docs_map() -> None:
    map_path = ROOT / "docs/README.md"
    map_text = read(map_path)
    targets = set(local_link_targets(map_text))

    expected: set[str] = set()
    for path in sorted((ROOT / "docs").glob("*.md")):
        if path.name != "README.md":
            expected.add(path.name)
    for path in sorted((ROOT / "docs/en").glob("*.md")):
        expected.add(f"en/{path.name}")

    missing = sorted(expected - targets)
    if missing:
        for item in missing:
            fail(f"docs/README.md does not list {item}")
    extra = sorted(target for target in targets if target.endswith(".md") and target not in expected)
    # Links to README files outside docs/ are allowed; only report stale local
    # docs links that do not exist.
    for target in extra:
        if not (map_path.parent / target).exists():
            fail(f"docs/README.md links to missing {target}")
    ok(f"documentation map covers {len(expected)} current docs")


def check_release_workflow() -> None:
    release_doc = read(ROOT / "docs/en/RELEASE.md")
    workflow_path = ROOT / ".github/workflows/release.yml"
    if ".github/workflows/release.yml" not in release_doc:
        fail("docs/en/RELEASE.md: release workflow not referenced")
    if "scripts/build-release" not in release_doc:
        fail("docs/en/RELEASE.md: build-release script not referenced")
    workflow = read(workflow_path)
    if "./scripts/build-release" not in workflow:
        fail("release workflow: scripts/build-release not invoked")
    if "gh release upload" not in workflow:
        fail("release workflow: release upload step missing")
    ok("release docs and workflow references agree")


def main() -> int:
    version = version_from_info_plist()
    if version:
        check_versions(version)
    check_links()
    check_docs_map()
    check_release_workflow()

    for message in passes:
        print(f"PASS: {message}")
    for message in errors:
        print(f"FAIL: {message}")

    if errors:
        print(f"\ndocs-check: {len(errors)} error(s), {len(passes)} check(s) passed")
        return 1
    print(f"\ndocs-check: {len(passes)} checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
