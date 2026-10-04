#!/usr/bin/env python3
"""Clean CI import and strict focused actual spoil-worker composition checks."""

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
SOURCES = ("godot/scripts/core/spoil_tips.gd", "godot/scripts/core/spoil_work.gd",
           "godot/test/test_spoil_tips.gd", "godot/test/test_spoil_work.gd")
SUITES = ("test_spoil_work.gd", "test_spoil_tips.gd", "test_modular_projects.gd",
          "test_modular_inventory.gd", "test_excavation_physical.gd")


def run(command, path):
    with path.open("w") as log:
        result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    output = path.read_text()
    print(path.name, "exit", result.returncode, flush=True)
    for line in output.splitlines():
        if (line.startswith(("diagnostics:", "log:", "ok:")) or "failure(s)" in line
                or "GDScript warning(s)" in line or "FAIL" in line or "SCRIPT ERROR" in line):
            print(line, flush=True)
    if result.returncode:
        raise SystemExit(result.returncode)
    return output


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: reproduce.py NEW_OUTPUT_DIRECTORY")
    out = Path(sys.argv[1]).resolve()
    if out.exists():
        raise SystemExit("refuse to overwrite existing evidence")
    held = ROOT / "godot/demo/assets.spoil-work-validation-held"
    assets = ROOT / "godot/demo/assets"
    if held.exists():
        raise SystemExit("refuse existing asset holding path")
    out.mkdir(parents=True)
    hashes = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in SOURCES}
    (out / "source-sha256.json").write_text(json.dumps(hashes, indent=2) + "\n")
    moved = assets.exists()
    if moved:
        assets.rename(held)
    try:
        cache = ROOT / "godot/.godot"
        if cache.exists():
            shutil.rmtree(cache)
        output = run(["godot", "--headless", "--path", "godot", "--editor", "--quit"],
                     out / "clean-import.log")
        if any("ERROR:" in line or "WARNING:" in line for line in output.splitlines()):
            raise SystemExit("clean import contained diagnostics")
        sys.path.insert(0, str(ROOT / "tools"))
        from ci_test_shards import discover, make_plan
        count = len(discover(ROOT))
        plan = make_plan(count, ROOT)
        for name in SUITES:
            matches = [i for i, group in enumerate(plan["shards"]) if name in group]
            if len(matches) != 1:
                raise SystemExit("missing exact singleton " + name)
            run(["./tools/run_tests.sh", "--shard", f"{matches[0]}/{count}",
                 "--output-dir", str(out / "shards")], out / (name + ".log"))
        run(["python3", "tools/gdscript_warnings.py", "--port", "6157", "--max", "0",
             "--json", str(out / "analyzer.json"), *SOURCES], out / "analyzer.log")
        current = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in SOURCES}
        if current != hashes:
            raise SystemExit("source changed during validation")
    finally:
        if moved:
            held.rename(assets)


if __name__ == "__main__":
    main()
