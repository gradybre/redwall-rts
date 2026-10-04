#!/usr/bin/env python3
"""Repeat the pure final Transform proof with isolated user data, strict tests and LSP checks."""
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
FILES = ['godot/scripts/core/underground_final_facts.gd', 'godot/test/test_underground_final_facts.gd']
SUITES = ['test_underground_final_facts.gd', 'test_transforms.gd', 'test_underground_routes.gd']


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--port", type=int, default=6268)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    pins = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in FILES}
    (out / "source-sha256.json").write_text(json.dumps(pins, indent=2) + "\n")
    record = {"commands": [], "source_unchanged": False}
    project = ROOT / "godot/project.godot"
    original_project = project.read_bytes()
    isolated_name = "Redwall-ug-final-transform-tests"
    if b"config/use_custom_user_dir" in original_project:
        raise RuntimeError("Refuse to overwrite a preexisting custom user directory")
    test_project = original_project.replace(b"[application]\n", (
        '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + isolated_name + '"\n').encode(), 1)
    record["project_sha256_before"] = hashlib.sha256(original_project).hexdigest()
    record["custom_user_dir_name"] = isolated_name
    record["project_test_sha256"] = hashlib.sha256(test_project).hexdigest()
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
                    or " test(s)," in line or "GDScript warning(s)" in line or line.startswith("HOT-REACH"):
                print(line, flush=True)
        if result.returncode:
            raise RuntimeError(log_name)

    with tempfile.TemporaryDirectory(prefix="ug1100-transform-assets-", dir=ROOT.parent) as temporary:
        parked = Path(temporary) / "assets"
        try:
            project.write_bytes(test_project)
            if assets.exists():
                assets.rename(parked)
            shutil.rmtree(ROOT / "godot/.godot", ignore_errors=True)
            run(["godot", "--headless", "--path", "godot", "--editor", "--quit"], "clean-import.log")
            sys.path.insert(0, str(ROOT / "tools"))
            import ci_test_shards as shards
            plan = shards.make_plan(len(shards.discover(ROOT)), repo=ROOT,
                                    weights_path=ROOT / "tools/ci_test_shard_weights.json")
            for suite in SUITES:
                index = next(i for i, group in enumerate(plan["shards"]) if group == [suite])
                run(["./tools/run_tests.sh", "--shard", f"{index}/{plan['shard_count']}",
                     "--output-dir", str(out)], suite + ".log")
            run(["python3", "tools/gdscript_warnings.py", "--max", "0", "--port", str(args.port),
                 "--json", str(out / "analyzer.json"), *FILES], "analyzer.log")
        except Exception as error:
            status = 1
            record["error"] = str(error)
        finally:
            project.write_bytes(original_project)
            record["project_restored"] = project.read_bytes() == original_project
            if parked.exists():
                parked.rename(assets)
            record["assets_restored"] = assets.exists() == record["assets_present_before"]
            record["source_unchanged"] = pins == {
                name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in FILES}
            if not record["assets_restored"] or not record["source_unchanged"] or not record["project_restored"]:
                status = 1
            record["exit_code"] = status
            (out / "invocation.json").write_text(json.dumps(record, indent=2) + "\n")
    return status


if __name__ == "__main__":
    raise SystemExit(main())
