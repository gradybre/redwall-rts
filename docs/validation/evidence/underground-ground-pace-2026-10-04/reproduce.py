#!/usr/bin/env python3
"""Repeat isolated ground-only Catalog checks with exact source restoration."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[4]
FILES = ['godot/scripts/core/underground_connector_catalog.gd', 'godot/test/test_underground_connector_catalog.gd']
SUITES = ['test_underground_connector_catalog.gd']
ARTIFACTS = ['godot/data/underground/ground-pace-v1/ground-pace.ugconn',
             'godot/data/underground/ground-pace-v1/manifest.json',
             'godot/data/underground/ground-pace-v1/compile_ground_pace.py',
             'godot/data/underground/ground-pace-v1/test_compile_ground_pace.py']


def validate_import_log(text):
    """An exit-zero import may still report errors, warnings or leaked engine owners."""
    diagnostic = re.compile(r'^\s*(?:USER )?(?:SCRIPT ERROR|ERROR|WARNING):|'
                            r'(?:Parse|Parser) Error:|resources still in use at exit|'
                            r'ObjectDB instances? (?:were |was )?leaked', re.M)
    if diagnostic.search(text):
        raise RuntimeError('clean import contains a raw diagnostic or leak')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--port", type=int, default=6365)
    parser.add_argument("--suite", action="append", help="Exact strict singleton suite; may be repeated")
    parser.add_argument("--dependency", action="append", default=[], help="Additional exact diagnostic dependency to pin")
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    pinned_files = FILES + ARTIFACTS + args.dependency
    pins = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in pinned_files}
    (out / "source-sha256.json").write_text(json.dumps(pins, indent=2) + "\n")
    record = {"commands": [], "source_unchanged": False}
    sidecars = {p: p.read_bytes() for p in (ROOT / "godot").rglob("*.import")}
    project = ROOT / "godot/project.godot"
    original_project = project.read_bytes()
    isolated_name = "Redwall-ug-ground-pace"
    if b"config/use_custom_user_dir" in original_project:
        raise RuntimeError("Refuse to overwrite a preexisting custom user directory")
    test_project = original_project.replace(b"[application]\n", (
        '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + isolated_name + '"\n').encode(), 1)
    record["project_sha256_before"] = hashlib.sha256(original_project).hexdigest()
    record["custom_user_dir_name"] = isolated_name
    record["project_test_sha256"] = hashlib.sha256(test_project).hexdigest()
    assets = ROOT / "godot/demo/assets"
    record["assets_present_before"] = assets.exists()
    registry = ROOT / "docs/persistence_state_registry.md"
    original_registry = registry.read_bytes()
    record["registry_sha256_before"] = hashlib.sha256(original_registry).hexdigest()
    appendix = b""
    if b"### `godot/scripts/core/underground_room_frontier_publication.gd`" not in original_registry:
        appendix = (ROOT / "docs/validation/evidence/underground-room-frontier-publication-2026-10-04/final-2/registry-diagnostic-append.md").read_bytes()
        if hashlib.sha256(appendix).hexdigest() != "61e35bcb7275713b8544b081023b3efd544f088aa6e49ff3569cfc170a657395":
            raise RuntimeError("Accepted1161 diagnostic appendix drift")
    record["registry_append_sha256"] = hashlib.sha256(appendix).hexdigest()
    record["registry_diagnostic_sha256"] = hashlib.sha256(original_registry + appendix).hexdigest()
    status = 0

    def run(command, log_name):
        started = time.monotonic()
        with (out / log_name).open("w") as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        record["commands"].append({"command": command, "exit_code": result.returncode,
                                   "seconds": round(time.monotonic() - started, 3), "log": log_name})
        print(log_name, result.returncode, flush=True)
        for line in (out / log_name).read_text().splitlines():
            if line.startswith(("diagnostics:", "log:", "ok:", "error:", "SCRIPT ERROR:")) \
                    or " test(s)," in line or "GDScript warning(s)" in line or line.startswith("HOT-REACH"):
                print(line, flush=True)
        if result.returncode:
            raise RuntimeError(log_name)

    with tempfile.TemporaryDirectory(prefix="ug-ground-pace-assets-", dir=ROOT.parent) as temporary:
        parked = Path(temporary) / "assets"
        try:
            (out / "accepted1161-diagnostic-append.md").write_bytes(appendix)
            project.write_bytes(test_project)
            registry.write_bytes(original_registry + appendix)
            if assets.exists():
                assets.rename(parked)
            shutil.rmtree(ROOT / "godot/.godot", ignore_errors=True)
            run(["godot", "--headless", "--path", "godot", "--editor", "--quit"], "clean-import.log")
            validate_import_log((out / "clean-import.log").read_text())
            record["clean_import_raw_diagnostics"] = 0
            sys.path.insert(0, str(ROOT / "tools"))
            import ci_test_shards as shards
            plan = shards.make_plan(len(shards.discover(ROOT)), repo=ROOT,
                                    weights_path=ROOT / "tools/ci_test_shard_weights.json")
            for suite in args.suite or SUITES:
                index = next(i for i, group in enumerate(plan["shards"]) if group == [suite])
                run(["./tools/run_tests.sh", "--shard", f"{index}/{plan['shard_count']}",
                     "--output-dir", str(out)], suite + ".log")
            run(["python3", "tools/gdscript_warnings.py", "--max", "0", "--port", str(args.port),
                 "--json", str(out / "analyzer.json"), *FILES], "analyzer.log")
        except Exception as error:
            status = 1
            record["error"] = str(error)
        finally:
            for sidecar in (ROOT / "godot").rglob("*.import"):
                if sidecar not in sidecars:
                    sidecar.unlink()
            for sidecar, data in sidecars.items():
                sidecar.write_bytes(data)
            registry.write_bytes(original_registry)
            record["registry_sha256_after"] = hashlib.sha256(registry.read_bytes()).hexdigest()
            record["registry_restored"] = registry.read_bytes() == original_registry
            project.write_bytes(original_project)
            record["project_restored"] = project.read_bytes() == original_project
            if parked.exists():
                parked.rename(assets)
            record["assets_restored"] = assets.exists() == record["assets_present_before"]
            record["source_unchanged"] = pins == {
                name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in pinned_files}
            if not record["registry_restored"] or not record["assets_restored"] or not record["source_unchanged"] or not record["project_restored"]:
                status = 1
            record["exit_code"] = status
            (out / "invocation.json").write_text(json.dumps(record, indent=2) + "\n")
    return status


if __name__ == "__main__":
    raise SystemExit(main())
