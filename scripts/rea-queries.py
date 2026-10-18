#!/usr/bin/env python3
"""Run a reviewed JSON query list through one local REA MCP process."""
import json
import selectors
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
jobs = json.loads(Path(sys.argv[1]).read_text())
out = root / "evidence/raw/rea" / Path(sys.argv[1]).stem
out.mkdir(parents=True, exist_ok=True)
with (out / "server.log").open("w") as log:
    server = subprocess.Popen([str(root / "scripts/rea"), "--mcp"], cwd=root,
                              stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                              stderr=log)
    selector = selectors.DefaultSelector()
    selector.register(server.stdout, selectors.EVENT_READ)
    pending = bytearray()

    def request(number, method, params):
        server.stdin.write((json.dumps(dict(jsonrpc="2.0", id=number,
                                           method=method, params=params)) + "\n").encode())
        server.stdin.flush()
        while True:
            while b"\n" not in pending:
                if not selector.select(timeout=360):
                    raise TimeoutError("REA did not answer within 360 seconds")
                chunk = server.stdout.read1(65536)
                if not chunk:
                    raise RuntimeError("REA exited before responding")
                pending.extend(chunk)
            line, _, rest = pending.partition(b"\n")
            pending[:] = rest
            response = json.loads(line)
            if response.get("id") == number:
                if "error" in response:
                    raise RuntimeError(response["error"])
                result = response["result"]
                if result.get("isError"):
                    raise RuntimeError(result)
                return result

    try:
        request(1, "initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                                  "clientInfo": {"name": "oneswitch-pilot", "version": "1"}})
        server.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
        server.stdin.flush()
        for number, job in enumerate(jobs, 2):
            args = job["arguments"].copy()
            if job["name"] == "open_binary":
                args["path"] = str((root / args["path"]).resolve())
            result = request(number, "tools/call", {"name": job["name"], "arguments": args})
            (out / f"{number:02d}-{job['name']}.json").write_text(json.dumps(result, indent=2) + "\n")
            print(f"{number:02d} {job['name']}: response saved", flush=True)
    finally:
        selector.close()
        server.stdin.close()
        try:
            server.wait(timeout=20)
        except subprocess.TimeoutExpired:
            server.terminate()
            try:
                server.wait(timeout=10)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
