#!/usr/bin/env python3
"""Bounded real-process checks; only terminates processes started by this script."""
import json
import re
import selectors
import signal
import subprocess
import time
from pathlib import Path

root = Path(__file__).resolve().parent.parent
binary = root / "prototypes/SwitchPilot/.build/SwitchPilot.app/Contents/MacOS/SwitchPilot"
out = root / "evidence/raw/runtime"
out.mkdir(parents=True, exist_ok=True)
name = "SwitchPilot bounded research"

def assertions():
    return subprocess.check_output(["pmset", "-g", "assertions"], text=True)

def await_cleanup():
    for _ in range(30):
        if name not in assertions():
            return
        time.sleep(0.1)
    raise AssertionError("Pilot assertion still present after process exit")

assert name not in assertions(), "Another pilot assertion is active; refusing to interfere"
results = []
for label, seconds, stop_signal in [
    ("timer-1", "2", None), ("timer-2", "2", None), ("timer-3", "2", None),
    ("terminate", "60", signal.SIGTERM), ("kill", "60", signal.SIGKILL)
]:
    process = subprocess.Popen([str(binary), "awake", seconds],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            assert selector.select(timeout=5), "No startup state within 5 seconds"
        first = process.stdout.readline().strip()
        assert f"pid={process.pid}" in first and "readback=true" in first, first
        active = assertions()
        (out / f"{label}-active.txt").write_text(active)
        lines = [line for line in active.splitlines()
                 if name in line and re.search(rf"pid\s+{process.pid}\(", line)]
        assert len(lines) == 1, "OS did not report exactly one assertion for this child"
        if stop_signal:
            process.send_signal(stop_signal)
        remaining, error = process.communicate(timeout=8)
        expected = -int(stop_signal) if stop_signal else 0
        assert process.returncode == expected, (process.returncode, error)
        if stop_signal is None:
            assert "RELEASED readback=false" in remaining, remaining
        await_cleanup()
        results.append(dict(case=label, pid=process.pid, returncode=process.returncode,
                            active_line=lines[0].strip(), cleanup=True))
        print(f"PASS: {label}; active readback and cleanup confirmed", flush=True)
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)
await_cleanup()
(out / "process-checks.json").write_text(json.dumps(results, indent=2) + "\n")
print(f"{len(results)}/{len(results)} process checks passed")
