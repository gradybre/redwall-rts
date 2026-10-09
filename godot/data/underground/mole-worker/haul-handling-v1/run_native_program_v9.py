#!/usr/bin/env python3
"""Isolated exact-source native replay of the ten-clip stone image (v9, ADR 1206); v7/v8 runners unchanged.

Same four steps as `run_native_program_v8.py`: compile, clean isolated import, analyzer, real non-headless
Metal/Forward+ replay. The staged script closure additionally includes the real stone factory
(`demo/tunnel/bore_dressing.gd`) and everything it loads, so the replay draws the actual lump.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import sys
import tempfile
import time

import compile_native_program_v9 as C9
import run_native_program as N

C, HERE, ROOT = N.C, N.HERE, N.ROOT
OWN = ("compile_native_program.py", "compile_native_program_v9.py", "run_native_program.py",
       "run_native_program_v9.py", "native_replay/project.godot", "native_replay_v9/capture_native_program.gd")
FACTORY = "demo/tunnel/bore_dressing.gd"


def closure() -> dict:
    """The v7 runtime closure plus the stone factory's own closure, by the same preload/extends walk."""
    original = N.RUNTIME
    try:
        N.RUNTIME = original + (FACTORY,)
        return N.closure()
    finally:
        N.RUNTIME = original


def stage_project(target: Path, sources: dict, body: Path) -> dict:
    assets = N.stage_project(target, sources, body)
    shutil.copyfile(HERE / "native_replay_v9/capture_native_program.gd", target / "capture_native_program.gd")
    return assets


def replay(args: argparse.Namespace, sources: dict, commands: list) -> None:
    compilation = args.out / "compiled"
    command = [sys.executable, "-B", str(HERE / "compile_native_program_v9.py"), "--palette", str(args.palette),
               "--grip-palette", str(args.grip_palette), "--out", str(compilation)]
    commands.append(N.run(command, args.out / "compile.log"))
    C.I.require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "STONE_NATIVE_COMPILE")
    report = C.read_json(compilation / "compilation.json")
    with tempfile.TemporaryDirectory(prefix="native-replay-", dir=HERE) as temporary:
        project = Path(temporary)
        C.write_json(args.out / "staged-assets.json", stage_project(project, sources, args.body))
        spec = {"content": str((compilation / "stone-handling.ugactor").resolve()),
                "content_sha256": report["content_sha256"], "basis": str(C.BASIS.resolve()),
                "basis_sha256": C.BASIS_SHA, "basis_producer_sha256": report["basis_producer_sha256"],
                "reserve_bytes": report["presentation_only_reservation"]["admitted_peak_bytes"],
                "body": "res://demo/assets/cast/mole_digger/body.glb", "body_sha256": C.digest(args.body),
                "views": N.VIEWS, "part_masks": list(C9.MASKS), "production_qualified": False,
                "runtime_admitted": False}
        C.write_json(args.out / "spec.json", spec)
        commands.append(N.run([args.godot, "--headless", "--path", str(project), "--editor", "--quit"],
                              args.out / "import.log"))
        C.I.require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "STONE_NATIVE_IMPORT")
        commands.append(N.run([sys.executable, "-B", str(ROOT / "tools/gdscript_warnings.py"),
                               "--project", str(project), "--port", "6364", "--godot", args.godot,
                               "--json", str((args.out / "analyzer.json").resolve()),
                               str(project / "capture_native_program.gd")], args.out / "analyzer.log"))
        C.I.require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "STONE_NATIVE_ANALYZER")
        commands.append(N.run([args.godot, "--path", str(project), "--script", "res://capture_native_program.gd", "--",
                               str((args.out / "spec.json").resolve()), str(args.out.resolve())], args.out / "native.log"))
        C.I.require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "STONE_NATIVE_REPLAY")


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "body", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--godot", default="/opt/homebrew/bin/godot")
    args = parser.parse_args()
    C.I.require(not args.out.exists() and not args.out.is_symlink(), "STONE_NATIVE_OUTPUT_EXISTS")
    args.out.mkdir(parents=True)
    sources = closure()
    pins = {str((HERE / name).relative_to(ROOT)): C.digest(HERE / name) for name in OWN}
    pins.update({"godot/" + name: value for name, value in sources.items()})
    C.write_json(args.out / "source-sha256.json", pins)
    commands, error, started = [], None, time.monotonic()
    try:
        replay(args, sources, commands)
    except Exception as failure:
        error = str(failure)
    finally:
        unchanged = all(C.digest(ROOT / path) == expected for path, expected in pins.items())
        C.write_json(args.out / "invocation.json", {"commands": commands, "source_sha256": pins,
                     "argv": [sys.executable, "-B", *sys.argv],
                     "source_unchanged": unchanged, "main_project_untouched": True, "custom_user_directory": N.USER,
                     "elapsed_seconds": time.monotonic() - started, "error": error,
                     "production_qualified": False, "runtime_admitted": False})
    C.I.require(error is None and unchanged and len(commands) == 4, "STONE_NATIVE_INCOMPLETE:" + str(error))
    print(json.dumps({"output": str(args.out), "steps": len(commands), "source_unchanged": unchanged,
                      "production_qualified": False}))


if __name__ == "__main__":
    main()
