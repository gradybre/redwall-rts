#!/usr/bin/env python3
"""Create-only CI-style focused adapter checks, restoring the own-worktree assets on every exit."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[5]
evidence = Path(sys.argv[1]).resolve()
evidence.mkdir(parents=True, exist_ok=False)
assets = root / "godot/demo/assets"
saved = root / "godot/demo/assets.matrix-clean-aside"
if saved.exists():
    raise RuntimeError("existing saved assets; do not overwrite")
shimdir = Path(tempfile.mkdtemp(prefix="ug1080-matrix-shim-"))
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
env["REDWALL_TEST_SHARD_SUITES"] = json.dumps([
    "test_underground_actor.gd", "test_demo_actor_underground_heading.gd"
])
commands = [
    ["/opt/homebrew/bin/godot", "--headless", "--path", "godot", "--editor", "--quit"],
    ["./tools/run_tests.sh"],
    ["python3", "tools/gdscript_warnings.py", "--port", "6149", "--max", "0",
     "godot/demo/cast/underground_actor.gd", "godot/test/test_underground_actor.gd"],
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
        "commands": commands, "returncodes": codes, "selector": env["REDWALL_TEST_SHARD_SUITES"]
    }, indent=2) + "\n")
sys.exit(max(codes) if codes else 1)
