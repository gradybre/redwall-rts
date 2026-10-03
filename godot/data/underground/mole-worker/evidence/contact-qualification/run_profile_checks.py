#!/usr/bin/env python3
"""Run the unchanged strict guard with its bounded CI suite selector and preserve source pins."""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[6]
SOURCES = ["godot/scripts/core/underground_profiles.gd", "godot/test/test_underground_profiles.gd"]


def source_hashes():
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in SOURCES}


def main():
    if len(sys.argv) != 2:
        raise ValueError("usage: run_profile_checks.py new-output-directory")
    requested = Path(sys.argv[1])
    if requested.exists() or requested.is_symlink():
        raise ValueError("output already exists")
    out = requested.resolve()
    saved = ROOT / ".profile-selection-clean-assets-aside"
    if saved.exists() or saved.is_symlink():
        raise ValueError("saved assets already exist")
    out.mkdir(parents=True)
    (out / ".gdignore").touch()
    before = source_hashes()
    (out / "source-sha256.json").write_text(json.dumps(before, indent=2) + "\n")
    assets = ROOT / "godot/demo/assets"
    commands = [
        ["/opt/homebrew/bin/godot", "--headless", "--path", "godot", "--editor", "--quit"],
        ["./tools/run_tests.sh"],
        ["python3", "tools/gdscript_warnings.py", "--port", "6149", "--max", "0", *SOURCES],
    ]
    selector = ["test_underground_profiles.gd"]
    codes, diagnostic_failure = [], False
    with tempfile.TemporaryDirectory(prefix="ug1080-profile-selection-") as temporary:
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
                path = out / (name + ".log")
                with path.open("x") as log:
                    code = subprocess.call(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
                codes.append(code)
                text = path.read_text()
                diagnostic_failure |= bool(re.search(r"(?m)^(?:ERROR:|WARNING:|SCRIPT ERROR:)", text))
                if name == "analyzer":
                    diagnostic_failure |= "0 GDScript warning(s) in 0 of 2 file(s)" not in text
                print(name, code, "diagnostic_failure", diagnostic_failure, flush=True)
                if code or diagnostic_failure:
                    break
        finally:
            if saved.exists():
                if assets.exists():
                    raise ValueError("unexpected recreated assets; preserve both directories")
                saved.rename(assets)
            after = source_hashes()
            (out / "invocation.json").write_text(json.dumps({
                "commands": commands, "selector": selector, "returncodes": codes,
                "assets_aside_outside_godot_scan": True, "diagnostic_failure": diagnostic_failure,
                "source_unchanged": before == after, "source_after": after,
            }, indent=2) + "\n")
    return int(codes != [0, 0, 0] or diagnostic_failure or before != after)


if __name__ == "__main__":
    sys.exit(main())
