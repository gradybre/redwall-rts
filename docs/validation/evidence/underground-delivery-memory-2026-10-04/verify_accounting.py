#!/usr/bin/env python3
"""Create-only bounded rerun of the changed accounting guards, without any Godot writes."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[4]
FILES = ("tools/underground_memory_budget.py", "tools/test_underground_memory_budget.py",
         "docs/validation/ready07_arithmetic.py", "docs/systems_architecture.md",
         "docs/persistence_state_registry.md", "docs/planning/underground_memory_pack.json",
         "docs/planning/registry_capacity_audit.json")


def pins():
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in FILES}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("out", type=Path)
    out = parser.parse_args().out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    before = pins()
    commands = [
        ("memory-tests.log", ["tools/test_underground_memory_budget.py", "-v"]),
        ("memory-check.log", ["tools/underground_memory_budget.py", "--check"]),
        ("ready07.log", ["docs/validation/ready07_arithmetic.py", "--output", str(out / "ready07.json")]),
    ]
    results = []
    for name, arguments in commands:
        command = [sys.executable, "-B", *arguments]
        start = time.monotonic()
        with (out / name).open("x") as log:
            code = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT).returncode
        results.append(dict(command=command, log=name, exit_code=code, seconds=round(time.monotonic() - start, 3)))
        print(name, code, flush=True)
    result = dict(source_sha256=before, commands=results, source_unchanged=before == pins(),
                  exit_code=int(any(row["exit_code"] for row in results) or before != pins()))
    (out / "invocation.json").write_text(json.dumps(result, indent=2) + "\n")
    return result["exit_code"]


if __name__ == "__main__":
    sys.exit(main())
