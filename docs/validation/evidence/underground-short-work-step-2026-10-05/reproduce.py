#!/usr/bin/env python3
"""Run only the additive finite-step Python proof; never launch Godot or modify a source input."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import resource
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SOURCE = ROOT / "godot/data/underground/mole-worker/work-step-v1"


def pins():
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(SOURCE.glob("*.py"))}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("label")
    args = parser.parse_args()
    if re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", args.label) is None:
        raise ValueError("invalid fresh evidence label")
    out = HERE / args.label
    if out.exists() or out.is_symlink():
        raise ValueError("existing evidence is immutable")
    out.mkdir()
    before = pins()
    rows = []
    commands = [
        [sys.executable, "-B", str(SOURCE / "test_short_step.py")],
        [sys.executable, "-B", str(SOURCE / "compile_short_step.py"), str(out / "result")],
    ]
    for index, command in enumerate(commands):
        start = time.monotonic()
        with (out / f"{index}-stdout.log").open("xb") as stdout, (out / f"{index}-stderr.log").open("xb") as stderr:
            result = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr)
        rows.append({"command": command, "exit_code": result.returncode, "elapsed_s": time.monotonic() - start})
        if result.returncode:
            break
    unchanged = before == pins()
    record = {"commands": rows, "source_pins": before, "source_unchanged": unchanged,
              "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "python": sys.version, "platform": sys.platform,
              "offline_child_maxrss": resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
              "maxrss_unit": "bytes" if sys.platform == "darwin" else "KiB",
              "engine_runs": 0, "runtime_qualification": False}
    (out / "invocation.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({"result": str(out), "codes": [row["exit_code"] for row in rows], "source_unchanged": unchanged}))
    if not unchanged or len(rows) != len(commands) or any(row["exit_code"] for row in rows):
        sys.exit(1)


if __name__ == "__main__":
    main()
