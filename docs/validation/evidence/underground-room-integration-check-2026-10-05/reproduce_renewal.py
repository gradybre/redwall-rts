#!/usr/bin/env python3
"""Evidence-only invocation of the unchanged root integration runner and strict analyzer."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[4]
CHECKPOINT = "9dad696ddb6485e9a8c4b8efd8c8dcee52c9c4c0"
BASE = "38515845^"
RUNNER = "docs/validation/evidence/underground-host-checkpoint-2026-10-04/verify_profile_integration.py"
SUITES = ["test_underground_room_composition.gd", "test_underground_session.gd",
          "test_underground_host.gd", "test_underground_world_retirement.gd",
          "test_room_catalog.gd", "test_underground_connector_catalog.gd",
          "test_mole_qualified_profiles.gd", "test_underground_support_clearance.gd",
          "test_underground_room_world_phases.gd", "test_underground_motion_catalog.gd"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def snapshot():
    paths = {p for p in (ROOT / "godot").rglob("*") if p.is_file()
             and ".godot" not in p.parts and p.suffix in
             (".gd", ".ugprof", ".ugmotion", ".uganim", ".ugactor", ".ugconn", ".uglvl")}
    paths.update(ROOT / p for p in [RUNNER, "tools/run_tests.sh", "tools/ci_test_shards.py",
                 "tools/gdscript_warnings.py", "docs/persistence_state_registry.md"])
    paths.add(Path(__file__).resolve())
    return {str(p.relative_to(ROOT)): sha(p) for p in sorted(paths)}


def raw_findings(text):
    return re.findall(r"^\s*(?:USER )?(?:SCRIPT ERROR|ERROR|WARNING):|(?:Parse|Parser) Error:|"
                      r"resources still in use at exit|ObjectDB instances? (?:were |was )?leaked", text, re.M)


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--port", type=int, default=6465)
    args = parser.parse_args()
    out = args.out.resolve()
    assert not out.exists() and not args.out.is_symlink()
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    assert head == CHECKPOINT
    changed = subprocess.check_output(["git", "diff", "--name-only", BASE + ".." + CHECKPOINT,
                                      "--", "godot"], cwd=ROOT, text=True).splitlines()
    files = sorted({p for p in changed if p.endswith(".gd")} | {"godot/test/" + s for s in SUITES})
    out.mkdir(parents=True)
    pins = snapshot()
    write(out / "source-sha256.json", pins)
    write(out / "analyzer-files.json", files)
    (out / "executed-runner.py.txt").write_bytes((ROOT / RUNNER).read_bytes())
    project = ROOT / "godot/project.godot"
    original_project = project.read_bytes()
    assert b"config/use_custom_user_dir" not in original_project
    registry = ROOT / "docs/persistence_state_registry.md"
    registry_hash = sha(registry)
    sidecars = {p: p.read_bytes() for ext in ("*.uid", "*.import") for p in (ROOT / "godot").rglob(ext)}
    assets = ROOT / "godot/demo/assets"
    assert not assets.is_symlink()
    record = {"head": head, "base": BASE, "scope": "Focused integrated validation, not a full milestone or playable acceptance",
              "commands": [], "assets_present_before": assets.exists(), "registry_sha256_before": registry_hash,
              "project_sha256_before": sha(project), "strict_custom_user_dir": "Redwall-ug-profile-integration-20261004",
              "analyzer_custom_user_dir": "Redwall-ug-room-integration-renewal-20261005", "analyzer_port": args.port}

    def run(command, name):
        print("starting " + name, flush=True)
        start = time.monotonic()
        env = os.environ.copy()
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        with (out / name).open("w") as log:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        record["commands"].append({"command": command, "exit_code": result.returncode,
                                   "seconds": round(time.monotonic() - start, 3), "log": name})
        print(name + " exit=" + str(result.returncode), flush=True)
        if result.returncode:
            raise RuntimeError(name)

    status = 1
    parked = None
    with tempfile.TemporaryDirectory(prefix="ug-room-integration-assets-", dir=ROOT.parent) as temporary:
        try:
            command = [sys.executable, "-B", RUNNER, "--out", str(out / "strict")]
            for suite in SUITES:
                command += ["--suite", suite]
            run(command, "strict-runner.log")
            import sys as _sys
            _sys.path.insert(0, str(ROOT / "tools"))
            import ci_test_shards as shards
            record["strict_suites"] = {}
            record["raw_suite_findings"] = {}
            for suite in SUITES:
                text = (out / "strict" / (suite + ".log")).read_text()
                counts, actual, _ = shards.parse_log(text)
                assert actual == [suite]
                record["strict_suites"][suite] = counts
                record["raw_suite_findings"][suite] = raw_findings(text)
                assert not record["raw_suite_findings"][suite]
            record["import_raw_findings"] = raw_findings((out / "strict/clean-import.log").read_text())
            assert not record["import_raw_findings"]
            if assets.exists():
                parked = Path(temporary) / "assets"
                assets.rename(parked)
            project.write_bytes(original_project.replace(b"[application]\n", b'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Redwall-ug-room-integration-renewal-20261005"\n', 1))
            run([sys.executable, "-B", "tools/gdscript_warnings.py", "--max", "0", "--port", str(args.port),
                 "--json", str(out / "analyzer.json"), *files], "analyzer.log")
            editor_log = Path(os.environ.get("TMPDIR", "/tmp")) / ("gdscript_warnings_editor_" + str(args.port) + ".log")
            if editor_log.exists():
                shutil.copyfile(editor_log, out / "analyzer-editor.log")
                record["analyzer_editor_raw_findings"] = raw_findings(editor_log.read_text())
                assert not record["analyzer_editor_raw_findings"]
            status = 0
        except (Exception, KeyboardInterrupt) as error:
            record["error"] = repr(error)
        finally:
            record["source_unchanged_before_restoration"] = snapshot() == pins
            project.write_bytes(original_project)
            if parked is not None and parked.exists():
                assert not assets.exists()
                parked.rename(assets)
            for ext in ("*.uid", "*.import"):
                for path in set((ROOT / "godot").rglob(ext)) - set(sidecars):
                    path.unlink()
            for path, data in sidecars.items():
                if not path.is_file() or path.read_bytes() != data:
                    path.write_bytes(data)
            record.update(project_restored=project.read_bytes() == original_project,
                          registry_unchanged=sha(registry) == registry_hash,
                          assets_restored=assets.exists() == record["assets_present_before"],
                          sidecars_restored=all(p.read_bytes() == b for p, b in sidecars.items()),
                          source_restored=snapshot() == pins,
                          head_unchanged=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == head)
            if not all(record[k] for k in ("source_unchanged_before_restoration", "project_restored", "registry_unchanged",
                       "assets_restored", "sidecars_restored", "source_restored", "head_unchanged")):
                status = 1
            record["exit_code"] = status
            write(out / "invocation.json", record)
            print("completed exit=" + str(status), flush=True)
    return status


if __name__ == "__main__":
    raise SystemExit(main())
