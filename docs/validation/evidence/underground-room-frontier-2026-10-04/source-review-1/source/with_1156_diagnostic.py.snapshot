#!/usr/bin/env python3
"""Use exactly one immutable1156 API checkpoint for an isolated diagnostic, then restore every file."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
EVIDENCE = Path(__file__).resolve().parent
FILES = {
    "godot/scripts/core/underground_profiles.gd",
    "godot/scripts/core/underground_routes.gd",
    "godot/scripts/core/underground_world_routes.gd",
    "godot/data/underground/mole-worker/mole_profile_driver.gd",
    "godot/data/underground/mole-worker/work-approach-v1/source_program.gd",
    "godot/data/underground/mole-worker/work-approach-v1/source_program.gd.uid",
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--port", type=int, default=6355)
    parser.add_argument("--suite", action="append", default=[])
    args = parser.parse_args()
    source = args.checkpoint.resolve()
    output = args.out.resolve()
    manifest = json.loads((source / "source-sha256.json").read_text())
    if set(manifest) != FILES:
        raise ValueError("Diagnostic dependency paths differ from the six-file approved API packet")
    snapshots = {name: (source / (name + ".txt")).read_bytes() for name in sorted(FILES)}
    for name, data in snapshots.items():
        if hashlib.sha256(data).hexdigest() != manifest[name]:
            raise ValueError("Immutable diagnostic dependency changed: " + name)
    output.mkdir(parents=True, exist_ok=False)
    originals = {name: (ROOT / name).read_bytes() if (ROOT / name).exists() else None for name in snapshots}
    record = {"checkpoint": str(source), "diagnostic_sha256": manifest,
              "production_acceptance": False,
              "original_sha256": {name: hashlib.sha256(data).hexdigest() if data is not None else None
                                  for name, data in originals.items()}}
    for name, data in originals.items():
        archive = output / "dependencies" / (name + ".original")
        archive.parent.mkdir(parents=True, exist_ok=True)
        if data is not None:
            archive.write_bytes(data)
        (output / "dependencies" / (name + ".diagnostic")).write_bytes(snapshots[name])
    (output / "dependency-manifest.json").write_text(json.dumps(record, indent=2) + "\n")
    result = 1
    try:
        for name, data in snapshots.items():
            target = ROOT / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        command = [sys.executable, "-B", str(EVIDENCE / "reproduce.py"), "--out", str(output / "checks"),
                   "--port", str(args.port)]
        for name in snapshots:
            command += ["--dependency", name]
        for suite in args.suite or ["test_underground_room_frontier.gd"]:
            command += ["--suite", suite]
        record["command"] = command
        result = subprocess.run(command, cwd=ROOT).returncode
        record["diagnostic_sources_unchanged"] = all((ROOT / name).read_bytes() == data
                                                   for name, data in snapshots.items())
    finally:
        for name, data in originals.items():
            if data is None:
                (ROOT / name).unlink(missing_ok=True)
            else:
                (ROOT / name).write_bytes(data)
        record["originals_restored"] = all((ROOT / name).read_bytes() == data if data is not None
                                           else not (ROOT / name).exists() for name, data in originals.items())
        record["exit_code"] = result
        (output / "dependency-restoration.json").write_text(json.dumps(record, indent=2) + "\n")
    if not record.get("diagnostic_sources_unchanged") or not record["originals_restored"]:
        raise RuntimeError("Diagnostic restoration or source equality failed")
    return result


if __name__ == "__main__":
    raise SystemExit(main())
