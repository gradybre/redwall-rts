#!/usr/bin/env python3
"""Create-only strict component checks with assets restored even when import or validation refuses."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[6]


def main():
    if len(sys.argv) != 2:
        raise ValueError("usage: run_checks.py new-output-directory")
    out = Path(sys.argv[1]).resolve()
    saved = ROOT / ".mole-grip-clean-assets-aside"
    if out.exists() or out.is_symlink() or saved.exists() or saved.is_symlink():
        raise ValueError("existing output/saved assets; refuse before any mutation")
    out.mkdir(parents=True)
    assets = ROOT / "godot/demo/assets"
    commands = [
        ["/opt/homebrew/bin/godot", "--headless", "--path", "godot", "--editor", "--quit"],
        ["./tools/run_tests.sh"],
        ["python3", "tools/gdscript_warnings.py", "--port", "6149", "--max", "0",
         "godot/data/underground/mole-worker/mole_grip_source.gd", "godot/test/test_mole_grip_source.gd"],
    ]
    codes = []
    selector = ["test_mole_grip_source.gd", "test_underground_actor_content.gd", "test_underground_actor.gd"]
    with tempfile.TemporaryDirectory(prefix="ug1080-grip-") as temporary:
        shim = Path(temporary) / "godot"
        shim.write_text(
            "#!/usr/bin/env python3\nimport os,sys\na=sys.argv[1:]\n"
            "for i in range(len(a)-1):\n"
            " if a[i]=='--script' and a[i+1]=='test/run_tests.gd': a[i+1]="
            + repr(str(ROOT / "tools/ci_test_shard_runner.gd"))
            + "\nos.execv('/opt/homebrew/bin/godot',['/opt/homebrew/bin/godot']+a)\n")
        shim.chmod(0o755)
        env = os.environ.copy()
        env["PATH"] = str(shim.parent) + os.pathsep + env["PATH"]
        env["REDWALL_TEST_SHARD_SUITES"] = json.dumps(selector)
        try:
            if assets.exists():
                assets.rename(saved)
            shutil.rmtree(ROOT / "godot/.godot", ignore_errors=True)
            for name, command in zip(("import", "strict", "analyzer"), commands):
                with (out / (name + ".log")).open("x") as log:
                    code = subprocess.call(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
                codes.append(code)
                print(name, code, flush=True)
                if code:
                    break
        finally:
            if saved.exists():
                if assets.exists():
                    raise ValueError("unexpected recreated assets; preserve both directories")
                saved.rename(assets)
            (out / "invocation.json").write_text(json.dumps({
                "commands": commands, "returncodes": codes, "selector": selector,
                "assets_aside_outside_godot_scan": True,
            }, indent=2) + "\n")
    return max(codes) if codes else 1


if __name__ == "__main__":
    sys.exit(main())
