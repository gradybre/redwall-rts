#!/usr/bin/env python3
"""Repeat decision1100's clean import, unchanged strict gates and exact analyzer selection."""
import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[4]
SUITES = ["test_underground_final_facts.gd", "test_underground_space_owner.gd", "test_underground_routes.gd"]
FILES = ["godot/scripts/core/underground_space_owner.gd", "godot/scripts/core/underground_final_facts.gd", "godot/test/test_underground_final_facts.gd"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--port", type=int, default=6211)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    out = args.out.resolve()

    def run(command, name, env=None):
        with (out / name).open("w") as log:
            subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)

    with tempfile.TemporaryDirectory(prefix="ug1100-assets-", dir=ROOT.parent) as parked_dir:
        assets = ROOT / "godot/demo/assets"
        parked = Path(parked_dir) / "assets"
        try:
            if assets.exists():
                assets.rename(parked)
            shutil.rmtree(ROOT / "godot/.godot", ignore_errors=True)
            run(["godot", "--headless", "--path", "godot", "--editor", "--quit"], "import.log")
            shell = (ROOT / "tools/run_tests.sh").read_text()
            original_root = 'repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"'
            original_runner = 'godot_script="test/run_tests.gd"'
            assert shell.count(original_root) == shell.count(original_runner) == 1
            shell = shell.replace(original_root, "repo_root=" + shlex.quote(str(ROOT)))
            shell = shell.replace(original_runner, 'godot_script="' + str(ROOT / "tools/ci_test_shard_runner.gd") + '"')
            (out / "strict-focused.sh").write_text(shell)
            env = os.environ.copy()
            env["REDWALL_TEST_SHARD_SUITES"] = json.dumps(SUITES)
            run(["bash", str(out / "strict-focused.sh")], "strict.log", env)
            run(["python3", "tools/gdscript_warnings.py", "--max", "0", "--port", str(args.port), *FILES], "analyzer.log")
        finally:
            if parked.exists():
                parked.rename(assets)


if __name__ == "__main__":
    main()
