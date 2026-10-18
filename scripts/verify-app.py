#!/usr/bin/env python3
"""Automated acceptance for the personal SwitchPilot app.

Only side effects: builds the app, briefly launches it as a menu bar app, then
terminates it. No permission prompts, no screen saver, no lock screen, no changes
to the original One Switch application.
"""
import hashlib
import os
import plistlib
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PKG = ROOT / "app/SwitchPilot"
BUILD = PKG / ".build"
APP = BUILD / "SwitchPilot.app"
APP_BIN = APP / "Contents/MacOS/SwitchPilot"
ORIGINAL = Path("/Applications/One Switch.app")
ORIGINAL_HASH = "ee4551f90014801f0252abea9787911a8ce04e9e6bae1207589eebf1584208fa"
ORIGINAL_VERSION = "1.35.4"

results = []


def app_pids():
    ps = run("/bin/ps", "-axo", "pid=,command=").stdout
    return {
        line.split()[0]
        for line in ps.splitlines()
        if "SwitchPilot.app/Contents/MacOS/SwitchPilot" in line
    }


def run(*args, **kwargs):
    return subprocess.run(args, capture_output=True, text=True, **kwargs)


BASELINE_APP_PIDS = app_pids()


def check(name, function):
    try:
        detail = function()
        results.append((name, True, detail or ""))
        print(f"PASS: {name}" + (f" — {detail}" if detail else ""), flush=True)
    except Exception as error:  # noqa: BLE001 - report every failure
        results.append((name, False, str(error)))
        print(f"FAIL: {name} — {error}", flush=True)


def assertions_text():
    return run("/usr/bin/pmset", "-g", "assertions").stdout


def check_build():
    result = run("/bin/sh", str(ROOT / "scripts/build-app"))
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    if not APP_BIN.exists():
        raise RuntimeError("build did not produce SwitchPilot.app executable")
    return str(APP)


def check_plists():
    info = plistlib.loads((PKG / "Info.plist").read_bytes())
    entitlements = plistlib.loads((PKG / "Entitlements.plist").read_bytes())
    if info.get("CFBundleIdentifier") != "local.personal.SwitchPilot":
        raise RuntimeError("unexpected bundle id")
    if info.get("CFBundleShortVersionString") != "0.3.4":
        raise RuntimeError(f"unexpected bundle version: {info.get('CFBundleShortVersionString')}")
    if info.get("LSUIElement") is not True:
        raise RuntimeError("LSUIElement must be true")
    if not info.get("NSAppleEventsUsageDescription"):
        raise RuntimeError("missing NSAppleEventsUsageDescription")
    if info.get("CFBundleIconFile") != "AppIcon":
        raise RuntimeError("missing CFBundleIconFile")
    icon = APP / "Contents/Resources/AppIcon.icns"
    if not icon.exists() or icon.stat().st_size < 10_000:
        raise RuntimeError("missing or tiny AppIcon.icns in bundle")
    if entitlements.get("com.apple.security.automation.apple-events") is not True:
        raise RuntimeError("missing automation entitlement")
    for plist in (PKG / "Info.plist", PKG / "Entitlements.plist"):
        lint = run("/usr/bin/plutil", "-lint", str(plist))
        if lint.returncode != 0:
            raise RuntimeError(lint.stderr.strip())
    return "LSUIElement + usage description + automation entitlement"


def check_signature():
    verify = run("/usr/bin/codesign", "--verify", "--strict", str(APP))
    if verify.returncode != 0:
        raise RuntimeError(verify.stderr.strip())
    details = run("/usr/bin/codesign", "-dv", str(APP)).stderr
    flag_lines = [line for line in details.splitlines() if "flags=" in line]
    if not flag_lines or "runtime" not in flag_lines[0]:
        raise RuntimeError(f"Hardened Runtime flag missing: {flag_lines}")
    return "hardened runtime signature (local identity or ad-hoc)"


def check_core_checks():
    show = run("swift", "build", "--package-path", str(PKG), "--build-system", "native", "--show-bin-path")
    if show.returncode != 0:
        raise RuntimeError(show.stderr.strip())
    binary = Path(show.stdout.strip()) / "SwitchPilotChecks"
    if not binary.exists():
        raise RuntimeError(f"checks binary missing at {binary}")
    result = run(str(binary), timeout=120)
    output = result.stdout + result.stderr
    if result.returncode != 0:
        raise RuntimeError(output.strip()[-1500:])
    expected = "checks passed"
    if expected not in output:
        raise RuntimeError("checks binary did not report a summary")
    summary = [line for line in output.splitlines() if expected in line]
    return summary[-1] if summary else "checks passed"


def check_launch_smoke():
    env = dict(os.environ)
    env["SWITCHPILOT_SMOKE_TEST"] = "1"
    process = subprocess.Popen(
        [str(APP_BIN)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)
    try:
        time.sleep(2.5)
        if process.poll() is not None:
            _, err = process.communicate()
            raise RuntimeError(f"app exited early (code {process.returncode}): {err.strip()[-800:]}")
        if "SwitchPilot" in assertions_text() and "SwitchPilot personal" in assertions_text():
            raise RuntimeError("idle app created a power assertion before any toggle")
    finally:
        if process.poll() is None:
            process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
    time.sleep(0.3)
    if "SwitchPilot" in assertions_text():
        raise RuntimeError("power assertion still present after app termination")
    return "process stayed alive >2s and exited without leaving assertions"


def check_no_leftover_process():
    leftovers = app_pids() - BASELINE_APP_PIDS
    if leftovers:
        raise RuntimeError("leftover app process: " + ", ".join(sorted(leftovers)))
    ignored = len(BASELINE_APP_PIDS)
    return f"no new leftover SwitchPilot process" + (f" (ignoring {ignored} pre-existing instance)" if ignored else "")


def check_original_app():
    version = run("/usr/bin/defaults", "read", str(ORIGINAL / "Contents/Info.plist"), "CFBundleShortVersionString")
    if version.stdout.strip() != ORIGINAL_VERSION:
        raise RuntimeError(f"original version changed: {version.stdout.strip()!r}")
    digest = hashlib.sha256((ORIGINAL / "Contents/MacOS/One Switch").read_bytes()).hexdigest()
    if digest != ORIGINAL_HASH:
        raise RuntimeError("original main binary hash changed")
    verify = run("/usr/bin/codesign", "--verify", "--strict", str(ORIGINAL))
    if verify.returncode != 0:
        raise RuntimeError(verify.stderr.strip())
    return f"{ORIGINAL_VERSION} hash/signature unchanged"


def check_contrast_tokens():
    result = run("/usr/bin/python3", str(ROOT / "scripts/check-contrast.py"))
    if result.returncode != 0:
        raise RuntimeError(result.stdout.strip()[-1200:])
    return "all ink tokens >= 4.5:1 on panel/card/tile"


def check_panel_sizes():
    env = dict(os.environ)
    app = str(APP_BIN)
    no_guide = dict(env, SWITCHPILOT_HIDE_GUIDE="1")
    guide = dict(env, SWITCHPILOT_FORCE_GUIDE="1")
    result = run(app, "--panel-size", env=no_guide)
    if result.returncode != 0 or "x" not in result.stdout:
        raise RuntimeError(f"panel-size (no guide) failed: {result.stderr.strip()}")
    width, height = (int(v) for v in result.stdout.strip().split("x"))
    if width != 380 or height > 680:
        raise RuntimeError(f"panel without guide is {width}x{height}, expected 380x<=680")
    result = run(app, "--panel-size", env=guide)
    if result.returncode != 0 or "x" not in result.stdout:
        raise RuntimeError(f"panel-size (guide) failed: {result.stderr.strip()}")
    width, height = (int(v) for v in result.stdout.strip().split("x"))
    if width != 380 or height > 760:
        raise RuntimeError(f"panel with guide is {width}x{height}, expected 380x<=760")
    return "panel sizes within 380x680 / 380x760"


def check_no_raw_foreground_colors():
    files = [
        ROOT / "app/SwitchPilot/Sources/SwitchPilot/PanelView.swift",
        ROOT / "app/SwitchPilot/Sources/SwitchPilot/SettingsView.swift",
    ]
    bad = []
    for path in files:
        text = path.read_text()
        for needle in (".foregroundStyle(.green)", ".foregroundStyle(.orange)", ".foregroundStyle(.red)"):
            if needle in text:
                bad.append(f"{path.name}: {needle}")
    if bad:
        raise RuntimeError("raw semantic foreground colors found: " + "; ".join(bad))
    return "no raw green/orange/red foreground text"


def check_static_scripts():
    for script in (ROOT / "scripts/rea-queries.py", ROOT / "scripts/verify-app.py"):
        result = run("/usr/bin/python3", "-m", "py_compile", str(script))
        if result.returncode != 0:
            raise RuntimeError(f"{script.name}: {result.stderr.strip()}")
    for script in (ROOT / "scripts/build-app", ROOT / "scripts/install-app", ROOT / "scripts/uninstall-app", ROOT / "scripts/rea"):
        result = run("/bin/sh", "-n", str(script))
        if result.returncode != 0:
            raise RuntimeError(f"{script.name}: {result.stderr.strip()}")
    return "python/shell syntax checks"


check("build", check_build)
check("plists", check_plists)
check("signature", check_signature)
check("core checks", check_core_checks)
check("launch smoke", check_launch_smoke)
check("leftover process", check_no_leftover_process)
check("original app unchanged", check_original_app)
check("contrast tokens", check_contrast_tokens)
check("panel sizes", check_panel_sizes)
check("semantic text colors", check_no_raw_foreground_colors)
check("static scripts", check_static_scripts)

failures = sum(1 for _, ok, _ in results if not ok)
print(f"{len(results) - failures}/{len(results)} verification steps passed")
sys.exit(0 if failures == 0 else 1)
