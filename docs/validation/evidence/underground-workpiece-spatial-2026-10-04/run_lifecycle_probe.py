#!/usr/bin/env python3
"""Run an owned probe against immutable, explicitly diagnostic1134 snapshots; restore every overlay."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
CONSTRUCTION = ROOT.parent / "redwall-rts-codex-ug-connector-work"
DEPENDENCIES = CONSTRUCTION / "docs/validation/evidence/underground-connector-workpieces-2026-10-04"
TEST = "godot/test/test_underground_workpiece_spatial_lifecycle.gd"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--pins", type=Path, default=HERE / "source-review-1/source-sha256.json")
    parser.add_argument("--suite", action="append", default=[])
    parser.add_argument("--extra-script", action="append", default=[])
    parser.add_argument("--skip-lifecycle", action="store_true")
    parser.add_argument("--adapters", default="diagnostic-adapters-1")
    args = parser.parse_args()
    overlays = {}
    for folder in ("diagnostic-source-2", args.adapters):
        source = DEPENDENCIES / folder
        for path, digest in json.loads((source / "source-sha256.json").read_text()).items():
            data = (source / path).read_bytes()
            assert hashlib.sha256(data).hexdigest() == digest, path
            overlays[path] = data
    before = {path: (ROOT / path).read_bytes() if (ROOT / path).exists() else None for path in overlays}
    uid = ROOT / "godot/test/test_underground_connector_workpieces.gd.uid"
    old_uid = uid.read_bytes() if uid.exists() else None
    frozen = json.loads(args.pins.read_text())
    for path, digest in frozen.items():
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, path
    metadata = {"scope": "Unreviewed diagnostic1134 only; no accepted combined lifecycle or production source qualification.",
        "diagnostic_sources": {path: hashlib.sha256(data).hexdigest() for path, data in overlays.items()}}
    result = None
    try:
        for path, data in overlays.items():
            (ROOT / path).write_bytes(data)
        command = [sys.executable, str(HERE / "reproduce.py"), "--out", str(args.out), "--extra-script", TEST]
        if not args.skip_lifecycle:
            command += ["--suite", Path(TEST).name]
        for suite in args.suite:
            command += ["--suite", suite]
        for path in args.extra_script:
            command += ["--extra-script", path]
        for path in overlays:
            command += ["--dependency", path]
        result = subprocess.run(command, cwd=ROOT)
    finally:
        metadata["overlay_unchanged"] = all((ROOT / path).read_bytes() == data for path, data in overlays.items())
        for path, data in before.items():
            if data is None:
                (ROOT / path).unlink(missing_ok=True)
            else:
                (ROOT / path).write_bytes(data)
        if old_uid is None:
            uid.unlink(missing_ok=True)
        else:
            uid.write_bytes(old_uid)
        metadata["overlays_restored"] = all(
            not (ROOT / path).exists() if data is None else (ROOT / path).read_bytes() == data for path, data in before.items())
        metadata["frozen_sources_unchanged"] = all(
            hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest for path, digest in frozen.items())
        if args.out.is_dir():
            (args.out / "diagnostic-overlay.json").write_text(json.dumps(metadata, indent=2) + "\n")
    return result.returncode if result is not None else 1


if __name__ == "__main__":
    raise SystemExit(main())
