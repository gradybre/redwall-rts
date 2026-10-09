#!/usr/bin/env python3
"""Run the exact CI singleton shard in this checkout with isolated user data."""
from pathlib import Path
import hashlib
import importlib.util
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[7]
OUT = Path(__file__).resolve().parent
FILES = ("godot/data/underground/mole-worker/mole_profile_driver.gd", "godot/test/test_mole_profile_driver.gd")
USER_NAME = "Redwall-Codex-Cardinal-Driver-v1"
OVERRIDE = ('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + USER_NAME + '"\n').encode()
spec = importlib.util.spec_from_file_location("shards", ROOT / "tools/ci_test_shards.py")
shards = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shards)


def pins():
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in FILES}


def main():
    outputs = [OUT / name for name in ("commands.json", "source-sha256.json", "import.log", "strict.log", "analyzer.log", "verification.json", "shard")]
    override, assets, saved = ROOT / "godot/override.cfg", ROOT / "godot/demo/assets", ROOT / ".profile-clean-assets-aside"
    if any(path.exists() or path.is_symlink() for path in [*outputs, override, saved]):
        raise ValueError("CARDINAL_DRIVER_EXISTING_OUTPUT_OR_OVERRIDE")
    before = pins()
    plan = shards.make_plan(len(shards.discover(ROOT)), ROOT)
    index = next(i for i, names in enumerate(plan["shards"]) if names == ["test_mole_profile_driver.gd"])
    commands = [["godot", "--headless", "--path", "godot", "--editor", "--quit"],
                ["./tools/run_tests.sh", "--shard", str(index) + "/" + str(plan["shard_count"]), "--output-dir", str(OUT / "shard")],
                ["python3", "tools/gdscript_warnings.py", *FILES, "--port", "6149", "--max", "0"]]
    (OUT / "commands.json").write_text(json.dumps(commands, indent=2) + "\n")
    (OUT / "source-sha256.json").write_text(json.dumps(before, indent=2) + "\n")
    with override.open("xb") as stream:
        stream.write(OVERRIDE)
    moved, bad, codes, error = False, False, [], ""
    try:
        if assets.exists():
            assets.rename(saved)
            moved = True
        cache = ROOT / "godot/.godot"
        if cache.exists():
            shutil.rmtree(cache)
        for command, name in zip(commands, ("import.log", "strict.log", "analyzer.log")):
            with (OUT / name).open("x") as log:
                code = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600).returncode
            codes.append(code)
            output = (OUT / name).read_text()
            bad = bad or bool(re.search(r"^(?:SCRIPT ERROR|ERROR|WARNING):|ObjectDB instances? (?:were|was) leaked|resources still in use at exit", output, re.M))
            if code or bad:
                break
            if name == "strict.log":
                shards.parse_log(output)
    except Exception as failure:
        error = repr(failure)
    finally:
        if moved:
            saved.rename(assets)
        if override.read_bytes() != OVERRIDE:
            raise ValueError("CARDINAL_DRIVER_OVERRIDE_DRIFT")
        override.unlink()
    after = pins()
    result = {"returncodes": codes, "diagnostic_failure": bad, "exception": error, "source_unchanged": before == after,
              "source_after": after, "assets_restored": not saved.exists(), "user_directory_name": USER_NAME,
              "override_sha256": hashlib.sha256(OVERRIDE).hexdigest(), "override_removed": not override.exists()}
    (OUT / "verification.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2), flush=True)
    return 0 if codes == [0, 0, 0] and not bad and not error and before == after else 2


if __name__ == "__main__":
    raise SystemExit(main())
