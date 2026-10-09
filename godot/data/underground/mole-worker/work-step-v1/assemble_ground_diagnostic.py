#!/usr/bin/env python3
"""Reuse the exact accepted1166 compiler for the pinned diagnostic content3 rows.

Only the input path/digest changes. Actual Movement still supplies ground pace;
this artifact carries no physical, actor, source-publication or stair permission.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
COMPILER = ROOT / "godot/data/underground/ground-pace-v1/compile_ground_pace.py"
COMPILER_SHA = "14dbac8fa70c17648711db856cab2fe5b7666a53ae1a0ca61b2eb4761bebf539"
PROFILE = "docs/validation/evidence/underground-short-work-step-runtime-2026-10-05/profile-diagnostic-1/mole-worker.ugprof"
PROFILE_SHA = "830ee531a432f9cef8a24a85f1c017be21253301bc46bf55e0a6b97807a4ec4e"


def build():
    if hashlib.sha256(COMPILER.read_bytes()).hexdigest() != COMPILER_SHA:
        raise ValueError("STEP_GROUND_COMPILER_SHA")
    spec = importlib.util.spec_from_file_location("step_ground_compiler", COMPILER)
    compiler = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(compiler)
    compiler.PROFILE_PATH = PROFILE
    compiler.PROFILE_SHA = PROFILE_SHA
    wire, manifest = compiler.build(ROOT)
    assert manifest["profile_content_revision"] == 3
    assert [r["profile_id"] for r in manifest["rows"]] == list(range(1, 13))
    assert manifest["counts"] == {"variants": 0, "points": 0, "regions": 0, "parts": 0,
                                  "vertices": 0, "materials": 0, "paces": 12}
    manifest.update({"diagnostic_only": True, "production_qualified": False,
                     "source_publication_qualified": False,
                     "compiler_input_override": {"profile_path": PROFILE, "profile_sha256": PROFILE_SHA},
                     "diagnostic_wrapper_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()})
    return wire, manifest


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists() or args.out.is_symlink() or not args.out.resolve().is_relative_to(Path(__file__).parent):
        raise ValueError("STEP_GROUND_CREATE_ONLY")
    wire, manifest = build()
    args.out.mkdir(parents=True)
    (args.out / "ground-pace.ugconn").write_bytes(wire)
    (args.out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"bytes": len(wire), "sha256": hashlib.sha256(wire).hexdigest(), "diagnostic_only": True}))


if __name__ == "__main__":
    main()
