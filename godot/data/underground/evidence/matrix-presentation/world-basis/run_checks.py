#!/usr/bin/env python3
"""Create-only clean CI checks for the finite native heading source and exact reader tests."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[6]
if len(sys.argv) != 2:
    raise ValueError("usage: run_checks.py new-output-directory")
evidence = Path(sys.argv[1]).resolve()
evidence.mkdir(parents=True, exist_ok=False)
assets = ROOT / "godot/demo/assets"
saved = ROOT / ".world-basis-clean-assets-aside"
if saved.exists() or saved.is_symlink():
    raise ValueError("existing saved assets; do not overwrite")
shimdir = Path(tempfile.mkdtemp(prefix="ug1080-world-basis-shim-"))
shim = shimdir / "godot"
shim.write_text(
    "#!/usr/bin/env python3\nimport os,sys\na=sys.argv[1:]\n"
    "for i in range(len(a)-1):\n"
    " if a[i]=='--script' and a[i+1]=='test/run_tests.gd': a[i+1]="
    + repr(str(ROOT / "tools/ci_test_shard_runner.gd"))
    + "\nos.execv('/opt/homebrew/bin/godot',['/opt/homebrew/bin/godot']+a)\n"
)
shim.chmod(0o755)
env = os.environ.copy()
env["PATH"] = str(shimdir) + os.pathsep + env["PATH"]
env["REDWALL_TEST_SHARD_SUITES"] = json.dumps(["test_underground_world_basis.gd"])
source = ROOT / "tools/bake_underground_world_basis.gd"
mirror = assets / "underground-analysis/bake_underground_world_basis.gd"
commands = [
    ["/opt/homebrew/bin/godot", "--headless", "--path", "godot", "--editor", "--quit"],
    ["./tools/run_tests.sh"],
    ["python3", "tools/gdscript_warnings.py", "--port", "6149", "--max", "0",
     str(mirror.relative_to(ROOT)), "godot/test/test_underground_world_basis.gd"],
]
codes = []
made_mirror_tree = False
try:
    if assets.exists():
        assets.rename(saved)
    shutil.rmtree(ROOT / "godot/.godot", ignore_errors=True)
    mirror.parent.mkdir(parents=True, exist_ok=False)
    made_mirror_tree = True
    shutil.copyfile(source, mirror)
    for command, name in zip(commands, ["import", "strict", "analyzer"]):
        with (evidence / (name + ".log")).open("x") as out:
            code = subprocess.call(command, cwd=ROOT, env=env, stdout=out, stderr=subprocess.STDOUT)
        codes.append(code)
        print(name, code, flush=True)
        if code:
            break
finally:
    if made_mirror_tree:
        shutil.rmtree(assets)
    if saved.exists():
        saved.rename(assets)
    shutil.rmtree(shimdir)
    (evidence / "invocation.json").write_text(json.dumps({
        "commands": commands, "returncodes": codes,
        "selector": env["REDWALL_TEST_SHARD_SUITES"],
        "byte_identical_analysis_mirror": {
            "source": str(source.relative_to(ROOT)), "mirror": str(mirror.relative_to(ROOT)),
            "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        },
    }, indent=2) + "\n")
sys.exit(max(codes) if codes else 1)
