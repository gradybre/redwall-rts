#!/usr/bin/env python3
"""Create-only CI-style component checks; own assets stay outside the Godot scan and restore on exit."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[4]
if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and sys.argv[2] != "--catalog-only"):
    raise ValueError("usage: run_connector_catalog_checks.py output-directory [--catalog-only]")
catalog_only = len(sys.argv) == 3
evidence = Path(sys.argv[1]).resolve()
evidence.mkdir(parents=True, exist_ok=False)
assets = root / "godot/demo/assets"
saved = root / ".connector-catalog-clean-assets-aside"
if saved.exists():
    raise RuntimeError("existing saved assets; do not overwrite")
shimdir = Path(tempfile.mkdtemp(prefix="ug1080-catalog-shim-"))
shim = shimdir / "godot"
shim.write_text(
    "#!/usr/bin/env python3\nimport os,sys\na=sys.argv[1:]\n"
    "for i in range(len(a)-1):\n"
    " if a[i]=='--script' and a[i+1]=='test/run_tests.gd': a[i+1]="
    + repr(str(root / "tools/ci_test_shard_runner.gd"))
    + "\nos.execv('/opt/homebrew/bin/godot',['/opt/homebrew/bin/godot']+a)\n"
)
shim.chmod(0o755)
env = os.environ.copy()
env["PATH"] = str(shimdir) + os.pathsep + env["PATH"]
selected = ["test_underground_connector_catalog.gd"] if catalog_only else [
    "test_underground_connector_catalog.gd", "test_movement.gd",
    "test_underground_profiles.gd", "test_underground_level_catalog.gd"
]
env["REDWALL_TEST_SHARD_SUITES"] = json.dumps(selected)
commands = [
    ["/opt/homebrew/bin/godot", "--headless", "--path", "godot", "--editor", "--quit"],
    ["./tools/run_tests.sh"],
    ["python3", "tools/gdscript_warnings.py", "--port", "6149", "--max", "0",
     "godot/scripts/core/underground_connector_catalog.gd",
     "godot/test/test_underground_connector_catalog.gd",
     *([] if catalog_only else ["godot/scripts/core/movement.gd", "godot/test/test_movement.gd"])],
]
codes = []
try:
    if assets.exists():
        assets.rename(saved)
    shutil.rmtree(root / "godot/.godot", ignore_errors=True)
    for command, name in zip(commands, ["import", "strict", "analyzer"]):
        with (evidence / (name + ".log")).open("x") as out:
            code = subprocess.call(command, cwd=root, env=env, stdout=out, stderr=subprocess.STDOUT)
        codes.append(code)
        print(name, code, flush=True)
        if code:
            break
finally:
    if saved.exists():
        saved.rename(assets)
    shutil.rmtree(shimdir)
    (evidence / "invocation.json").write_text(json.dumps({
        "commands": commands, "returncodes": codes,
        "selector": env["REDWALL_TEST_SHARD_SUITES"]
    }, indent=2) + "\n")
sys.exit(max(codes) if codes else 1)
