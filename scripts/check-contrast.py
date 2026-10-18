#!/usr/bin/env python3
"""Assert the SwitchPilot ink tokens keep WCAG AA contrast on every surface.

Parses the adaptive tokens from Theme.swift so the check follows the real code.
Surfaces are the measured light/dark panel/card/tile colors from the UI review.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
theme = (ROOT / "app/SwitchPilot/Sources/SwitchPilot/Theme.swift").read_text()
pattern = re.compile(r"static var (\w+): Color \{ adaptive\(light: \(([^)]+)\), dark: \(([^)]+)\)\) \}")
tokens = {}
for name, light, dark in pattern.findall(theme):
    tokens[name] = {
        "light": tuple(float(v) for v in light.split(",")),
        "dark": tuple(float(v) for v in dark.split(",")),
    }

surfaces = {
    "light": {"panel": (252, 252, 252), "card": (241, 241, 241), "tile": (229, 229, 229)},
    "dark": {"panel": (24, 24, 24), "card": (34, 34, 34), "tile": (42, 42, 42)},
}
primary = {"light": (0.0, 0.0, 0.0), "dark": (1.0, 1.0, 1.0)}


def channel(value):
    value /= 255.0
    return value / 12.92 if value <= 0.03928 else ((value + 0.055) / 1.055) ** 2.4


def luminance(rgb):
    r, g, b = (channel(v) for v in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


failures = 0
for mode, backgrounds in surfaces.items():
    for token_name in ("secondaryInk", "warningInk", "successInk", "errorInk"):
        rgb = [round(v * 255) for v in tokens[token_name][mode]]
        for surface_name, background in backgrounds.items():
            ratio = contrast(rgb, background)
            ok = ratio >= 4.5
            failures += 0 if ok else 1
            print(f"{'PASS' if ok else 'FAIL'}: {token_name:12s} {mode:5s} on {surface_name:5s} {ratio:.2f}:1")
    ratio = contrast([round(v * 255) for v in primary[mode]], backgrounds["panel"])
    failures += 0 if ratio >= 4.5 else 1
    print(f"{'PASS' if ratio >= 4.5 else 'FAIL'}: primary text {mode:5s} on panel {ratio:.2f}:1")

print(f"{'PASS' if failures == 0 else 'FAIL'}: contrast token check")
sys.exit(0 if failures == 0 else 1)
