#!/usr/bin/env python3
"""Create-only focused CI checks; source pins and all strict footers remain in the repository."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools"))
import ci_test_shards

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--iteration", required=True)
args = parser.parse_args()
if not args.iteration.isdecimal():
    raise SystemExit("iteration must be numeric")
out = Path(__file__).resolve().parent / ("iteration-" + args.iteration)
out.mkdir()
os.chdir(ROOT)
paths = ["godot/scripts/core/underground_terrain.gd", "godot/test/test_underground_terrain.gd"]
def hashes():
    return {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
original = hashes()
(out / "source-sha256.json").write_text(json.dumps(original, indent=2) + "\n")
record = {"head": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
          "focused_only": True, "commands": [], "source_unchanged": False}
assets = ROOT / "godot/demo/assets"
backup = ROOT / ".route-clearance-assets-aside"
if backup.exists():
    raise SystemExit("existing asset backup; refusing to overwrite")
present = assets.exists()
status = 0
def run(command, name):
    started = time.monotonic()
    print("Starting " + name, flush=True)
    with (out / name).open("x") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
    record["commands"].append({"command": command, "log": name, "exit_code": result.returncode,
                               "seconds": round(time.monotonic() - started, 3)})
    print("Finished " + name + " exit " + str(result.returncode), flush=True)
    for line in (out / name).read_text().splitlines():
        if line.startswith(("diagnostics:", "log:", "ok:")) or "test(s)," in line or "GDScript warning(s)" in line:
            print(line, flush=True)
    return result.returncode
try:
    if present:
        assets.rename(backup)
    shutil.rmtree(ROOT / "godot/.godot", ignore_errors=True)
    status = run(["godot", "--headless", "--path", "godot", "--editor", "--quit"], "clean-import.log")
    if any(line.startswith(("ERROR:", "SCRIPT ERROR:")) for line in (out / "clean-import.log").read_text().splitlines()):
        status = 1
    if status == 0:
        count = len(ci_test_shards.discover(ROOT))
        plan = ci_test_shards.make_plan(count, ROOT)
        for suite in ["test_underground_terrain.gd", "test_underground_world_bindings.gd"]:
            index = next(i for i, group in enumerate(plan["shards"]) if group == [suite])
            code = run(["./tools/run_tests.sh", "--shard", f"{index}/{count}", "--output-dir", str(out)], suite + ".log")
            status = status or code
            if code:
                break
        code = run(["python3", "tools/gdscript_warnings.py", "--port", "6197", "--max", "0",
                    "--json", str(out / "analyzer.json"), *paths], "analyzer.log")
        status = status or code
finally:
    if present:
        if assets.exists():
            raise RuntimeError("unexpected asset path; original backup preserved")
        backup.rename(assets)
    record["assets_restored"] = assets.exists() == present
    record["source_unchanged"] = original == hashes()
    if not record["assets_restored"] or not record["source_unchanged"]:
        status = 1
    record["exit_code"] = status
    (out / "invocation.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record), flush=True)
raise SystemExit(status)
