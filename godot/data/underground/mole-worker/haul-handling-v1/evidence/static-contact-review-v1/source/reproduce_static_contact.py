#!/usr/bin/env python3
"""Reproduce the bounded static authoring packet in a new output folder, without touching gameplay owners."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    if args.out.exists():
        raise ValueError("HANDLING_OUTPUT_EXISTS")
    output = args.out.resolve()
    output.mkdir(parents=True)
    sources = sorted(HERE.glob("*.py")) + sorted((HERE / "native_capture").glob("*.gd")) + [HERE / "native_capture/project.godot"]
    pins = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    (output / "source-sha256.json").write_text(json.dumps(pins, indent=2) + "\n")
    for path in sources:
        target = output / "source" / path.relative_to(HERE)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
    actual = ["--palette", str(args.palette.resolve()), "--grip-palette", str(args.grip_palette.resolve())]
    native = output / "wood-topology.json"
    candidate = output / "candidate"
    commands = [
        ("native-stock", [args.godot, "--headless", "--path", str(HERE / "native_capture"), "--script", "capture_stock.gd", "--", str(native)]),
        ("author", [sys.executable, str(HERE / "author_handling.py"), *actual, "--out", str(candidate), "--lean", "95", "--ahead", "576",
                    "--drop", "96", "--grip-raise", "64", "--grip-back", "192", "--right-grip-back", "160", "--plant-soles"]),
        ("proof", [sys.executable, str(HERE / "prove_static_contact.py"), *actual, "--candidate", str(candidate),
                   "--wood-topology", str(native), "--out", str(output / "static-contact.json")]),
        ("preview", [sys.executable, str(HERE / "render_candidate.py"), *actual, "--candidate", str(candidate),
                     "--wood-topology", str(native), "--out", str(output / "preview.png")]),
        ("tests", [sys.executable, str(HERE / "test_handling_source.py"), *actual, "--candidate", str(candidate), "--wood-topology", str(native)])]
    record = {"schema": 1, "production_qualified": False, "source_sha256": pins, "commands": [],
              "scope": "Static source contact only; no gameplay project, runtime owner, source profile or cost/rate changed."}
    code = 0
    for name, command in commands:
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=60)
        (output / (name + ".log")).write_text(result.stdout + result.stderr)
        record["commands"].append({"name": name, "argv": command, "exit_code": result.returncode})
        if result.returncode:
            code = result.returncode
            break
    record["source_unchanged"] = all(hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest for name, digest in pins.items())
    record["outputs"] = {str(path.relative_to(output)): hashlib.sha256(path.read_bytes()).hexdigest()
                         for path in sorted(output.rglob("*")) if path.is_file()}
    (output / "invocation.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({"output": str(output), "completed_steps": len(record["commands"]), "exit_code": code,
                      "source_unchanged": record["source_unchanged"], "production_qualified": False}))
    raise SystemExit(code if record["source_unchanged"] else 2)


if __name__ == "__main__":
    main()
