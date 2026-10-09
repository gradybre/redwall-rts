#!/usr/bin/env python3
"""Native images of the split claw and paw-handling sources (ADR 1217 step 4b, content 8). Offline evidence only.

Successor of `native_claw.py` (step 3b), which stays published with its one eleven-clip image. Content 8 needs two
images, mirroring the pick/assembly split of sources 0 and 1 (ADR 1190: one Frontier source, a distinct set-down
program):

| Image | Runtime source | Clips (the approved, pinned clips of step 3b, unchanged) |
|---|---|---|
| claw (`claw.ugactor`) | 4 | stand, walk, dig_entry, dig_stroke, dig_recovery, tap_entry, tap_work, tap_recovery |
| paw (`paw-handling.ugactor`) | 5 | seat_entry, seat_work, seat_recovery |

Nothing is re-authored. The accepted Content encoder, the step-3b capture script, the isolated runner steps and the
verifier equations are reused unchanged: this module only selects each image's clips and content name, as
`stand-walk-v2/native_haul_v10.py` did for the haul successors. The joins are checked per image; the paw image has
no stand, so its ready joins are checked across images against the claw capture's stand key 8, as the stone image
v9 checked its stand join against wood v8.

    $PY .../native_claw_split.py compile --image claw|paw --palette <all-cast-v9> --grip-palette <mole-grip-v3> --out <dir>
    $PY .../native_claw_split.py run --image claw|paw --palette ... --grip-palette ... --body <body.glb> --out <dir>
    $PY .../native_claw_split.py verify --image claw --palette ... --grip-palette ... --capture <dir> --out <json>
    $PY .../native_claw_split.py verify --image paw ... --capture <dir> --claw-capture <claw dir> --out <json>
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import sys
import tempfile
import time

import numpy as np

import native_claw as NC

C, N, I = NC.C, NC.N, NC.I
ROOT = C.ROOT
IMAGES = {"claw": {"clips": ("stand", "walk", "dig_entry", "dig_stroke", "dig_recovery", "tap_entry", "tap_work",
                             "tap_recovery"), "content": "claw.ugactor",
                   "programs": (("dig_entry", "dig_stroke", "dig_recovery"), ("tap_entry", "tap_work", "tap_recovery"))},
          "paw": {"clips": ("seat_entry", "seat_work", "seat_recovery"), "content": "paw-handling.ugactor",
                  "programs": (("seat_entry", "seat_work", "seat_recovery"),)}}
OWN = NC.OWN + (Path(__file__),)
ORIGINAL_PINS = NC.record_pins


def select(image: str) -> None:
    """Point the accepted step-3b compiler and verifier at one image's clips and content name."""
    I.require(image in IMAGES, "CLAW_SPLIT_IMAGE")
    NC.CLIPS = IMAGES[image]["clips"]
    NC.CONTENT_NAME = IMAGES[image]["content"]
    NC.record_pins = lambda: {**ORIGINAL_PINS(), str(Path(__file__).relative_to(ROOT)): C.digest(Path(__file__))}


def compile_image(image: str, palette: Path, grip: Path, out: Path) -> dict:
    """Encode one image with the accepted Content encoder."""
    select(image)
    return NC.compile_image(palette, grip, out)


def replay(args: argparse.Namespace, sources: dict, commands: list) -> None:
    """The accepted four steps: compile, isolated import, analyzer, real non-headless replay."""
    compilation = args.out / "compiled"
    commands.append(N.run([sys.executable, "-B", str(Path(__file__)), "compile", "--image", args.image,
                           "--palette", str(args.palette), "--grip-palette", str(args.grip_palette),
                           "--out", str(compilation)], args.out / "compile.log"))
    I.require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "CLAW_SPLIT_COMPILE")
    report = C.read_json(compilation / "compilation.json")
    with tempfile.TemporaryDirectory(prefix="native-replay-", dir=NC.HERE) as temporary:
        project = Path(temporary)
        C.write_json(args.out / "staged-assets.json", N.stage_project(project, sources, args.body))
        shutil.copyfile(NC.CAPTURE, project / "capture_native_program.gd")
        spec = {"content": str((compilation / IMAGES[args.image]["content"]).resolve()),
                "content_sha256": report["content_sha256"], "basis": str(C.BASIS.resolve()),
                "basis_sha256": C.BASIS_SHA, "basis_producer_sha256": report["basis_producer_sha256"],
                "reserve_bytes": report["presentation_only_reservation"]["admitted_peak_bytes"],
                "body": "res://demo/assets/cast/mole_digger/body.glb", "body_sha256": C.digest(args.body),
                "views": N.VIEWS, "production_qualified": False, "runtime_admitted": False}
        C.write_json(args.out / "spec.json", spec)
        steps = (([args.godot, "--headless", "--path", str(project), "--editor", "--quit"], "import.log"),
                 ([sys.executable, "-B", str(ROOT / "tools/gdscript_warnings.py"), "--project", str(project), "--port",
                   "6364", "--godot", args.godot, "--json", str((args.out / "analyzer.json").resolve()),
                   str(project / "capture_native_program.gd")], "analyzer.log"),
                 ([args.godot, "--path", str(project), "--script", "res://capture_native_program.gd", "--",
                   str((args.out / "spec.json").resolve()), str(args.out.resolve())], "native.log"))
        for command, log in steps:
            commands.append(N.run(command, args.out / log))
            I.require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "CLAW_SPLIT_" + log)


def run(args: argparse.Namespace) -> None:
    """Replay one image with pinned sources and an invocation record."""
    I.require(not args.out.exists(), "CLAW_SPLIT_OUTPUT_EXISTS")
    args.out.mkdir(parents=True)
    sources = N.closure()
    pins = {str(path.relative_to(ROOT)): C.digest(path) for path in OWN}
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
                     "argv": [sys.executable, "-B", *sys.argv], "source_unchanged": unchanged,
                     "custom_user_directory": N.USER, "elapsed_seconds": time.monotonic() - started, "error": error,
                     "production_qualified": False, "runtime_admitted": False})
    I.require(error is None and unchanged and len(commands) == 4, "CLAW_SPLIT_INCOMPLETE:" + str(error))


def table_of(rows: np.ndarray) -> dict:
    """(view, clip, elapsed) -> the captured coefficient row."""
    return {(int(r["meta"][0]), int(r["meta"][1]), int(r["meta"][2])): r["values"] for r in rows}


def claw_ready(capture: Path) -> dict:
    """The claw capture's stand key 8 per view: the hub every paw program must leave from and return to."""
    report = C.read_json(capture / "compiled/compilation.json")
    I.require(report["clip_names"] == list(IMAGES["claw"]["clips"]), "CLAW_SPLIT_CLAW_CAPTURE")
    counts = report["clip_frames"]
    rows = NC.V8_capture(capture / "native.bin", 3 * sum(4 * (n - 1) + 1 for n in counts))
    table = table_of(rows)
    return {view: table[view, 0, NC.READY * 65536] for view in range(3)}


def joins_for(image: str, ready: dict | None):
    """Exact joins per program: ready -> entry, entry -> work, work -> recovery, recovery -> ready, and each
    recovery the exact reverse of its entry. The claw image's ready is its own stand key 8; the paw image's is the
    claw capture's."""
    def joins(rows: np.ndarray, counts: list) -> int:
        table, checked = table_of(rows), 0
        end = lambda clip: (counts[clip] - 1) * 65536
        for view in range(3):
            hub = table[view, 0, NC.READY * 65536] if ready is None else ready[view]
            for names in IMAGES[image]["programs"]:
                entry, work, recovery = (NC.CLIPS.index(name) for name in names)
                pairs = ((hub, table[view, entry, 0]), (table[view, entry, end(entry)], table[view, work, 0]),
                         (table[view, work, end(work)], table[view, recovery, 0]),
                         (table[view, recovery, end(recovery)], hub))
                for a, b in pairs:
                    I.require(np.array_equal(a, b), "CLAW_SPLIT_JOIN")
                    checked += 1
                for elapsed in range(0, end(entry) + 1, 16384):
                    I.require(np.array_equal(table[view, entry, elapsed], table[view, recovery, end(entry) - elapsed]),
                              "CLAW_SPLIT_REVERSAL")
        return checked
    return joins


def verify(args: argparse.Namespace) -> dict:
    """The accepted step-3b verifier on one image, with that image's joins."""
    select(args.image)
    ready = None
    if args.image == "paw":
        I.require(args.claw_capture is not None, "CLAW_SPLIT_CLAW_CAPTURE")
        ready = claw_ready(args.claw_capture)
    NC.joins = joins_for(args.image, ready)
    result = NC.verify(args.capture, args.palette, args.grip_palette)
    result["image"] = args.image
    result["join_hub"] = "own stand key 8" if ready is None else "claw capture stand key 8 (cross-image)"
    if ready is not None:
        result["claw_capture_sha256"] = C.digest(args.claw_capture / "native.bin")
    return result


def main() -> int:
    """compile | run | verify."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=("compile", "run", "verify"))
    parser.add_argument("--image", choices=tuple(IMAGES), required=True)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--body", type=Path)
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--claw-capture", type=Path)
    parser.add_argument("--godot", default="/opt/homebrew/bin/godot")
    args = parser.parse_args()
    args.out = args.out.resolve()  # The runner's subprocesses run from the repository root.
    if args.action == "compile":
        result = compile_image(args.image, args.palette, args.grip_palette, args.out)
        print(json.dumps({k: result[k] for k in ("wire_bytes", "frames", "clips", "content_sha256")}))
    elif args.action == "run":
        run(args)
    else:
        I.require(not args.out.exists(), "CLAW_SPLIT_OUTPUT_EXISTS")
        result = verify(args)
        C.write_json(args.out, result)
        print(json.dumps({k: v for k, v in result.items() if k != "scope"}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
