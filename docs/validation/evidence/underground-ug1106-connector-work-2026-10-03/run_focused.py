#!/usr/bin/env python3
"""Clean-import selected singleton shards through the unchanged CI test wrapper."""
from pathlib import Path
import argparse, importlib.util, json, shutil, subprocess

REPO = Path(__file__).resolve().parents[4]
parser = argparse.ArgumentParser()
parser.add_argument("iteration")
parser.add_argument("suites", nargs="+")
args = parser.parse_args()
out = Path(__file__).resolve().parent / args.iteration
out.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location("shards", REPO / "tools/ci_test_shards.py")
shards = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shards)
plan = shards.make_plan(len(shards.discover(REPO)), REPO)
(out / "full-plan.json").write_text(json.dumps(plan, indent=2) + "\n")
assets = REPO / "godot/demo/assets"
backup = REPO / ".ug1106-demo-assets"
assert not backup.exists(), "refuse to replace an existing assets backup"
moved = assets.exists()
if moved:
    assets.rename(backup)
reports = []
try:
    cache = REPO / "godot/.godot"
    if cache.exists():
        shutil.rmtree(cache)
    with (out / "import.log").open("w") as log:
        imported = subprocess.run(["godot", "--headless", "--path", "godot", "--editor", "--quit"], cwd=REPO, stdout=log, stderr=subprocess.STDOUT)
    assert imported.returncode == 0, "import failed"
    text = (out / "import.log").read_text()
    assert not any(line.startswith(("ERROR:", "WARNING:", "SCRIPT ERROR:")) for line in text.splitlines()), "import emitted diagnostics"
    for suite in args.suites:
        index = next(i for i, names in enumerate(plan["shards"]) if suite in names)
        assert plan["shards"][index] == [suite]
        command = ["./tools/run_tests.sh", "--shard", f"{index}/{plan['shard_count']}", "--output-dir", str(out / "shards")]
        with (out / (suite + ".log")).open("w") as log:
            result = subprocess.run(command, cwd=REPO, stdout=log, stderr=subprocess.STDOUT)
        report_path = out / "shards" / f"shard-{index}.json"
        if report_path.exists():
            reports.append(json.loads(report_path.read_text()))
        log_lines = (out / (suite + ".log")).read_text().splitlines()
        print(suite, "exit", result.returncode, flush=True)
        print("\n".join(line for line in log_lines if "test(s)," in line or line.startswith(("diagnostics:", "log:", "error:"))), flush=True)
        if result.returncode:
            raise SystemExit(result.returncode)
finally:
    (out / "summary.json").write_text(json.dumps(reports, indent=2) + "\n")
    if moved:
        backup.rename(assets)
