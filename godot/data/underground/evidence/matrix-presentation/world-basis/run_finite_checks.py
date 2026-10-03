#!/usr/bin/env python3
"""Create-only clean focused finite-source checks with exact byte-identical tool analysis mirrors."""
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
    raise ValueError("usage: run_finite_checks.py new-output-directory")
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=False)
assets = ROOT / "godot/demo/assets"
saved = ROOT / ".finite-world-clean-assets-aside"
if saved.exists() or saved.is_symlink():
    raise ValueError("existing saved assets; do not overwrite")
shimdir = Path(tempfile.mkdtemp(prefix="ug1080-finite-world-"))
shim = shimdir / "godot"
shim.write_text(
    "#!/usr/bin/env python3\nimport os,sys\na=sys.argv[1:]\n"
    "for i in range(len(a)-1):\n"
    " if a[i]=='--script' and a[i+1]=='test/run_tests.gd': a[i+1]="
    + repr(str(ROOT / "tools/ci_test_shard_runner.gd"))
    + "\nos.execv('/opt/homebrew/bin/godot',['/opt/homebrew/bin/godot']+a)\n")
shim.chmod(0o755)
env = os.environ.copy()
env["PATH"] = str(shimdir) + os.pathsep + env["PATH"]
env["REDWALL_TEST_SHARD_SUITES"] = json.dumps(["test_underground_actor.gd"])
mirror = assets / "underground-analysis"
sources = [ROOT / "tools" / name for name in ("bake_underground_matrices.gd", "capture_underground_profiles.gd")]
commands = [
    ["/opt/homebrew/bin/godot", "--headless", "--path", "godot", "--editor", "--quit"],
    ["./tools/run_tests.sh"],
    ["python3", "tools/gdscript_warnings.py", "--port", "6149", "--max", "0",
     "godot/demo/cast/underground_actor.gd", "godot/test/test_underground_actor.gd",
     "godot/data/underground/evidence/matrix-presentation/world-basis/native_actor.gd",
     *[str((mirror/source.name).relative_to(ROOT)) for source in sources]],
]
codes = []
made = False
try:
    if assets.exists():
        assets.rename(saved)
    shutil.rmtree(ROOT / "godot/.godot", ignore_errors=True)
    mirror.mkdir(parents=True, exist_ok=False)
    made = True
    for source in sources:
        shutil.copyfile(source, mirror/source.name)
    for name, command in zip(("import", "strict", "analyzer"), commands):
        with (out/(name+".log")).open("x") as log:
            code = subprocess.call(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        codes.append(code)
        print(name, code, flush=True)
        if code:
            break
finally:
    if made:
        shutil.rmtree(assets)
    if saved.exists():
        saved.rename(assets)
    shutil.rmtree(shimdir)
    (out/"invocation.json").write_text(json.dumps({
        "commands": commands, "returncodes": codes, "selector": env["REDWALL_TEST_SHARD_SUITES"],
        "analysis_mirrors": [{"source": str(source.relative_to(ROOT)),
            "mirror": str((mirror/source.name).relative_to(ROOT)),
            "sha256": hashlib.sha256(source.read_bytes()).hexdigest()} for source in sources],
    }, indent=2)+"\n")
sys.exit(max(codes) if codes else 1)
