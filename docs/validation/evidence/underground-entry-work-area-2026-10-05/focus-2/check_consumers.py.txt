#!/usr/bin/env python3
"""Strict focused suite: assets aside, delete own cache, clean import, analyzer and input restoration."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
FILES = ["godot/scripts/core/underground_profiles.gd", "godot/test/test_underground_profiles.gd"]
BAD = re.compile(r"^\s*(?:USER )?(?:SCRIPT ERROR|ERROR|WARNING):|(?:Parse|Parser) Error:|"
                 r"resources still in use at exit|ObjectDB instances? (?:were |was )?leaked", re.M)


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--port", type=int, default=6494)
    parser.add_argument("--suite", action="append", default=[])
    parser.add_argument("--file", action="append", default=[])
    args = parser.parse_args()
    FILES.extend(args.file)
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    assets, cache = ROOT/"godot/demo/assets", ROOT/"godot/.godot"
    parked_assets = out/".assets"
    pins = {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in FILES}
    sidecars = {p: p.read_bytes() for pattern in ("*.import", "*.uid") for p in (ROOT/"godot").rglob(pattern)}
    had_assets, had_cache = assets.exists(), cache.exists()
    record = {"source_before": pins, "commands": []}
    if assets.is_symlink() or cache.is_symlink(): raise ValueError("OWNED_DIRECTORY_REQUIRED")
    if had_assets: assets.rename(parked_assets)
    if had_cache: shutil.rmtree(cache)
    project = ROOT/"godot/project.godot"
    original_project = project.read_bytes()
    if b"config/use_custom_user_dir" in original_project: raise ValueError("CUSTOM_USER_DIR_EXISTS")
    registry = ROOT/"docs/persistence_state_registry.md"
    original_registry = registry.read_bytes()
    project.write_bytes(original_project.replace(b"[application]\n", b'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Redwall-entry-work-area-1191"\n', 1))
    status = 1
    try:
        commands = [(["godot", "--headless", "--path", "godot", "--editor", "--quit"], "import.log"),
                    (["python3", "tools/gdscript_warnings.py", "--max", "0", "--port", str(args.port),
                      "--json", str(out/"analyzer.json"), *FILES], "analyzer.log")]
        if args.suite:
            sys.path.insert(0, str(ROOT/"tools"))
            import ci_test_shards as shards
            plan = shards.make_plan(len(shards.discover(ROOT)), repo=ROOT,
                                    weights_path=ROOT/"tools/ci_test_shard_weights.json")
            for suite in args.suite:
                index = next(i for i, group in enumerate(plan["shards"]) if group == [suite])
                commands.insert(-1, (["./tools/run_tests.sh", "--shard", f"{index}/{plan['shard_count']}",
                                      "--output-dir", str(out)], suite+".log"))
        for command, name in commands:
            with (out/name).open("x") as log:
                result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=600)
            bad = bool(BAD.search((out/name).read_text()))
            print(name, result.returncode, "raw_bad", bad, flush=True)
            record["commands"].append({"command": command, "exit": result.returncode, "raw_bad": bad})
            if name == "analyzer.log":
                editor = Path(os.environ.get("TMPDIR", "/tmp"))/f"gdscript_warnings_editor_{args.port}.log"
                if editor.is_file():
                    raw = editor.read_bytes()
                    (out/"editor.log").write_bytes(raw)
                    record["editor_sha256"] = hashlib.sha256(raw).hexdigest()
            if result.returncode != 0 or bad: raise ValueError(name)
        editor = Path(os.environ.get("TMPDIR", "/tmp"))/f"gdscript_warnings_editor_{args.port}.log"
        if not editor.is_file(): raise ValueError("EDITOR_RECEIPT_MISSING")
        raw = editor.read_bytes()
        (out/"editor.log").write_bytes(raw)
        record["editor_sha256"] = hashlib.sha256(raw).hexdigest()
        if BAD.search(raw.decode(errors="replace")): raise ValueError("EDITOR_DIAGNOSTIC")
        status = 0
    except Exception as error:
        record["error"] = str(error)
    finally:
        project.write_bytes(original_project)
        record["project_restored"] = project.read_bytes() == original_project
        record["registry_unchanged"] = registry.read_bytes() == original_registry
        if had_assets: parked_assets.rename(assets)
        for pattern in ("*.import", "*.uid"):
            for p in (ROOT/"godot").rglob(pattern):
                if p not in sidecars: p.unlink()
        for p, raw in sidecars.items(): p.write_bytes(raw)
        record.update(source_after={p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in FILES},
                      cache_clean_import=cache.exists(), assets_restored=assets.exists() == had_assets,
                      sidecars_restored=all(p.read_bytes() == raw for p, raw in sidecars.items()))
        record["source_unchanged"] = record["source_before"] == record["source_after"]
        if not all(record[k] for k in ("cache_clean_import", "assets_restored", "sidecars_restored", "source_unchanged", "project_restored", "registry_unchanged")): status = 1
        record["exit"] = status
        (out/"invocation.json").write_text(json.dumps(record, indent=2)+"\n")
    return status


if __name__ == "__main__":
    raise SystemExit(main())
