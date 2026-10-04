#!/usr/bin/env python3
"""Repeat the exact1106 adapter clean import, real strict suite shards and selected LSP checks."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[4]
FILES = [
    "godot/scripts/core/construction.gd",
    "godot/scripts/core/modular_projects.gd",
    "godot/scripts/core/underground_connector_work.gd",
    "godot/test/test_underground_connector_work.gd",
]
SUITES = [
    "test_underground_connector_work.gd",
    "test_underground_connector_placements.gd",
    "test_modular_projects.gd",
    "test_modular_inventory.gd",
    "test_construction_modular.gd",
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--port", type=int, default=6156)
    parser.add_argument("--suite", action="append")
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    pins = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in FILES}
    (out / "source-sha256.json").write_text(json.dumps(pins, indent=2) + "\n")
    record = {"commands": [], "source_unchanged": False}
    assets = ROOT / "godot/demo/assets"
    record["assets_present_before"] = assets.exists()
    status = 0

    def run(command, log_name):
        started = time.monotonic()
        with (out / log_name).open("w") as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        record["commands"].append({"command": command, "exit_code": result.returncode,
                                   "seconds": round(time.monotonic() - started, 3), "log": log_name})
        print(log_name, result.returncode, flush=True)
        for line in (out / log_name).read_text().splitlines():
            if line.startswith(("diagnostics:", "log:", "ok:", "error:", "SCRIPT ERROR:")) \
                    or " test(s)," in line or "GDScript warning(s)" in line:
                print(line, flush=True)
        if result.returncode:
            raise RuntimeError(log_name)

    with tempfile.TemporaryDirectory(prefix="ug1106-adapter-assets-", dir=ROOT.parent) as temporary:
        parked = Path(temporary) / "assets"
        try:
            if assets.exists():
                assets.rename(parked)
            shutil.rmtree(ROOT / "godot/.godot", ignore_errors=True)
            run(["godot", "--headless", "--path", "godot", "--editor", "--quit"], "clean-import.log")
            sys.path.insert(0, str(ROOT / "tools"))
            import ci_test_shards as shards
            plan = shards.make_plan(len(shards.discover(ROOT)), repo=ROOT,
                                    weights_path=ROOT / "tools/ci_test_shard_weights.json")
            for suite in args.suite or SUITES:
                index = next(i for i, group in enumerate(plan["shards"]) if group == [suite])
                run(["./tools/run_tests.sh", "--shard", f"{index}/{plan['shard_count']}",
                     "--output-dir", str(out)], suite + ".log")
            run(["python3", "tools/gdscript_warnings.py", "--max", "0", "--port", str(args.port),
                 "--json", str(out / "analyzer.json"), *FILES], "analyzer.log")
        except Exception as error:
            status = 1
            record["error"] = str(error)
        finally:
            if parked.exists():
                parked.rename(assets)
            record["assets_restored"] = assets.exists() == record["assets_present_before"]
            record["source_unchanged"] = pins == {
                name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in FILES}
            if not record["assets_restored"] or not record["source_unchanged"]:
                status = 1
            record["exit_code"] = status
            (out / "invocation.json").write_text(json.dumps(record, indent=2) + "\n")
    return status


if __name__ == "__main__":
    raise SystemExit(main())
