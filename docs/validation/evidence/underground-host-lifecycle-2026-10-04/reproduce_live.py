#!/usr/bin/env python3
"""Run the real scene restart probe with isolated user settings and a bounded own child."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[4]
BASE = Path(__file__).resolve().parent
ASSET_CUES = {"amb_rain", "amb_stream", "amb_wind", "chop", "complete", "dig", "drop", "gnaw", "pickup", "saw", "splash", "step_dirt", "step_grass", "step_tunnel", "step_wade", "step_wood", "tree_fall", "ui_click", "warning", "water_in", "water_out"}


def known_unstaged_asset_warning(line):
    if line == "WARNING: demo assets are not staged (tools/stage_demo_assets.py); running on placeholders":
        return True
    match = re.fullmatch(r"WARNING: sound cue (\w+): [1-9][0-9]* of [1-9][0-9]* files missing \(res://demo/assets/sound/.*\); it plays silent until they are staged", line)
    return match is not None and match.group(1) in ASSET_CUES


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    project = ROOT / "godot/project.godot"
    original = project.read_bytes()
    if b"config/use_custom_user_dir" in original:
        raise RuntimeError("Refuse to replace existing custom user directory")
    isolated = original.replace(b"[application]\n", b'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Redwall-ug-host-live-20261004"\n', 1)
    command = ["godot", "--headless", "--path", "godot", "--script", str(BASE / "host_live.gd"), "--", "--size", "1280x720"]
    record = {"command": command, "project_sha256": hashlib.sha256(original).hexdigest(),
              "probe_sha256": hashlib.sha256((BASE / "host_live.gd").read_bytes()).hexdigest()}
    started = time.monotonic()
    try:
        project.write_bytes(isolated)
        with (out / "live.log").open("w") as log:
            child = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=90)
        record["exit_code"] = child.returncode
    except subprocess.TimeoutExpired:
        record["exit_code"] = 1
        record["error"] = "own child exceeded 90 seconds and was stopped"
    finally:
        project.write_bytes(original)
        record["project_restored"] = project.read_bytes() == original
        record["seconds"] = round(time.monotonic() - started, 3)
        lines = (out / "live.log").read_text().splitlines()
        record["summaries"] = [line for line in lines if line.startswith("LIVE-SUMMARY ")]
        record["raw_diagnostics"] = [line for line in lines if re.match(r"^(SCRIPT ERROR:|ERROR:|WARNING:)", line)]
        record["unexpected_diagnostics"] = [line for line in record["raw_diagnostics"] if not known_unstaged_asset_warning(line)]
        record["leak_diagnostics"] = [line for line in lines if "leaked at exit" in line or "resources still in use" in line]
        (out / "invocation.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record, indent=2))
    valid = len(record["summaries"]) == 1 and re.fullmatch(r"LIVE-SUMMARY [1-9][0-9]* 0", record["summaries"][0])
    fatal = bool(record["unexpected_diagnostics"])
    return 0 if record["exit_code"] == 0 and valid and not fatal and not record["leak_diagnostics"] and record["project_restored"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
