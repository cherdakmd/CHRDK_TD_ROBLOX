#!/usr/bin/env python3
"""Run all headless Luau suites. Pass --luau /path/to/luau or set LUAU_BIN."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SUITES = ("game_logic", "server_integration", "client_smoke", "balance_simulation", "profiles_storage")


def lua_string(value: str) -> str:
    for level in range(4, 12):
        marker = "=" * level
        close = f"]{marker}]"
        if close not in value:
            return f"[{marker}[{value}{close}"
    raise ValueError("Cannot embed source as a Luau long string")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", default=os.environ.get("LUAU_BIN") or shutil.which("luau"))
    args = parser.parse_args()
    if not args.luau or not Path(args.luau).exists():
        print("Luau CLI not found. Pass --luau /path/to/luau or set LUAU_BIN.", file=sys.stderr)
        return 2
    luau = Path(args.luau)
    sources = sorted((ROOT / "src").rglob("*.luau"))
    entries = ",\n".join(f"  [ {lua_string(str(p.relative_to(ROOT)))} ] = {lua_string(p.read_text(encoding='utf-8'))}" for p in sources)
    bundle_dir = ROOT / ".cache/tests"
    bundle_dir.mkdir(parents=True, exist_ok=True)
    harness = (ROOT / "tests/luau_harness.luau").read_text(encoding="utf-8")
    failures = 0
    for name in SUITES:
        test = ROOT / f"tests/{name}.luau"
        if not test.exists():
            print(f"FAILED: required suite is missing: {test.relative_to(ROOT)}", file=sys.stderr)
            failures += 1
            continue
        bundle = bundle_dir / f"{name}.luau"
        bundle.write_text(f"local SOURCES = {{\n{entries}\n}}\n\n{harness}\n\n{test.read_text(encoding='utf-8')}\n", encoding="utf-8")
        result = subprocess.run([str(luau), str(bundle)], cwd=ROOT, text=True, capture_output=True, timeout=90)
        print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        if result.returncode != 0:
            failures += 1
            print(f"FAILED: {name} (exit {result.returncode})", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
