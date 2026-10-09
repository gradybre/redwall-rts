#!/usr/bin/env python3
"""Create an isolated exact-source native replay without changing the main project or runtime owners."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

import compile_native_program as C

HERE, ROOT = C.HERE, C.ROOT
USER = "Redwall-ug-haul-native-1144"
RUNTIME = ("demo/cast/underground_actor.gd", "demo/cast/underground_actor_content.gd",
           "data/underground/mole-worker/mole_grip_source.gd")
VIEWS = [{"root_u": [16384, -4608, 8192], "yaw": 0},
         {"root_u": [20480, -4480, 12288], "yaw": 16384},
         {"root_u": [17413, 531, 9477], "yaw": 12345}]
MAX_FILES, MAX_SOURCE_BYTES = 512, 16 * 1024 * 1024
DIAGNOSTICS = ("ERROR:", "WARNING:", "SCRIPT ERROR:", "Parse Error:", "ObjectDB instances leaked",
               "resources still in use", "Orphan StringName")


def closure() -> dict:
    pending, result, size = list(RUNTIME), {}, 0
    while pending:
        name = pending.pop()
        if name in result:
            continue
        path = ROOT / "godot" / name
        C.I.require(path.is_file() and not path.is_symlink(), "HAUL_NATIVE_DEPENDENCY")
        size += path.stat().st_size
        C.I.require(len(result) < MAX_FILES and size <= MAX_SOURCE_BYTES, "HAUL_NATIVE_SOURCE_CAPACITY")
        text = path.read_text()
        result[name] = C.digest(path)
        for target in re.findall(r'(?:preload|load)\("res://([^"\n]+\.gd)"\)', text):
            pending.append(target)
        for target in re.findall(r'extends\s+"([^"\n]+\.gd)"', text):
            full = ROOT / "godot" / target[6:] if target.startswith("res://") else path.parent / target
            pending.append(str(full.resolve().relative_to(ROOT / "godot")))
    return result


def run(command: list, log: Path) -> dict:
    start = time.monotonic()
    with log.open("w") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, cwd=ROOT, check=False)
    raw = log.read_text()
    bad = [line for line in raw.splitlines() if any(marker in line for marker in DIAGNOSTICS)]
    return {"command": command, "exit_code": result.returncode, "elapsed_seconds": time.monotonic() - start,
            "log": log.name, "log_sha256": C.digest(log), "diagnostics": bad}


def stage_project(target: Path, sources: dict, body: Path) -> dict:
    for name, expected in sources.items():
        source = ROOT / "godot" / name
        C.I.require(C.digest(source) == expected, "HAUL_NATIVE_SOURCE_CHANGED")
        output = target / name
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, output)
    for name in ("project.godot", "capture_native_program.gd"):
        shutil.copyfile(HERE / "native_replay" / name, target / name)
    relative = "demo/assets/cast/mole_digger/body.glb"
    output = target / relative
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(body, output)
    imported = body.with_suffix(".glb.import")
    C.I.require(imported.is_file() and imported.stat().st_size <= 16384, "HAUL_NATIVE_IMPORT_SETTINGS")
    shutil.copyfile(imported, output.with_suffix(".glb.import"))
    return {relative: C.digest(body), relative + ".import": C.digest(imported)}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "body", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--godot", default="/opt/homebrew/bin/godot")
    args = parser.parse_args()
    C.I.require(not args.out.exists() and not args.out.is_symlink(), "HAUL_NATIVE_OUTPUT_EXISTS")
    args.out.mkdir(parents=True)
    sources = closure()
    own = [HERE / name for name in ("compile_native_program.py", "run_native_program.py")]
    own += list((HERE / "native_replay").glob("*"))
    pins = {str(path.relative_to(ROOT)): C.digest(path) for path in own if path.is_file()}
    pins.update({"godot/" + name: value for name, value in sources.items()})
    C.write_json(args.out / "source-sha256.json", pins)
    commands, error = [], None
    started = time.monotonic()
    try:
        compilation = args.out / "compiled"
        command = [sys.executable, "-B", str(HERE / "compile_native_program.py"), "--palette", str(args.palette),
                   "--grip-palette", str(args.grip_palette), "--out", str(compilation)]
        commands.append(run(command, args.out / "compile.log"))
        C.I.require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "HAUL_NATIVE_COMPILE")
        report = C.read_json(compilation / "compilation.json")
        with tempfile.TemporaryDirectory(prefix="native-replay-", dir=HERE) as temporary:
            project = Path(temporary)
            assets = stage_project(project, sources, args.body)
            C.write_json(args.out / "staged-assets.json", assets)
            spec = {"content": str((compilation / "haul-handling.ugactor").resolve()),
                    "content_sha256": report["content_sha256"], "basis": str(C.BASIS.resolve()),
                    "basis_sha256": C.BASIS_SHA, "basis_producer_sha256": report["basis_producer_sha256"],
                    "reserve_bytes": report["presentation_only_reservation"]["admitted_peak_bytes"],
                    "body": "res://demo/assets/cast/mole_digger/body.glb", "body_sha256": C.digest(args.body),
                    "views": VIEWS, "production_qualified": False, "runtime_admitted": False}
            C.write_json(args.out / "spec.json", spec)
            commands.append(run([args.godot, "--headless", "--path", str(project), "--editor", "--quit"],
                                args.out / "import.log"))
            C.I.require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "HAUL_NATIVE_IMPORT")
            commands.append(run([sys.executable, "-B", str(ROOT / "tools/gdscript_warnings.py"),
                                 "--project", str(project), "--port", "6364", "--godot", args.godot,
                                 "--json", str((args.out / "analyzer.json").resolve()),
                                 str(project / "capture_native_program.gd")], args.out / "analyzer.log"))
            C.I.require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "HAUL_NATIVE_ANALYZER")
            commands.append(run([args.godot, "--path", str(project), "--script", "res://capture_native_program.gd", "--",
                                 str((args.out / "spec.json").resolve()), str(args.out.resolve())], args.out / "native.log"))
            C.I.require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "HAUL_NATIVE_REPLAY")
    except Exception as failure:
        error = str(failure)
    finally:
        unchanged = all(C.digest(ROOT / path) == expected for path, expected in pins.items())
        C.write_json(args.out / "invocation.json", {"commands": commands, "source_sha256": pins,
                     "source_unchanged": unchanged, "main_project_untouched": True, "custom_user_directory": USER,
                     "elapsed_seconds": time.monotonic() - started, "error": error,
                     "production_qualified": False, "runtime_admitted": False})
    C.I.require(error is None and unchanged and len(commands) == 4, "HAUL_NATIVE_INCOMPLETE:" + str(error))
    print(json.dumps({"output": str(args.out), "steps": len(commands), "source_unchanged": unchanged,
                      "production_qualified": False}))


if __name__ == "__main__":
    main()
