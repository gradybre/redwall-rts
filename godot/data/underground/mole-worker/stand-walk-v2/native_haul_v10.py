#!/usr/bin/env python3
"""Native images of the haul sources with the corrected stand, walk and joins (ADR 1217 step 3; ADR 1199 successor).

The published images stay untouched: wood v8 (`native-program-v8`, source 2) and stone v9 (`native-program-v9`,
source 3). Their successors differ only in the tool-free clips Brendan approved in step 1c:

- **wood v10** = v8's twelve clips, with `stand`, `walk`, `enter_haul` and `leave_haul` taken from
  `evidence/stand-walk-v2/` (same key counts: 122, 45, 31, 31);
- **stone v10** = v9's ten clips, with `enter_haul_stone` and `leave_haul_stone` taken from there (31, 31).

The accepted v8/v9 compilers, runners, capture scripts and verifiers are reused unchanged: this module only
points their clip readers at the corrected, pinned files and gives each successor its own output. Every corrected
clip is pinned by the step-1c candidate record.

    $PY .../native_haul_v10.py compile --image wood|stone --palette <all-cast-v9> --grip-palette <mole-grip-v3> --out <dir>
    $PY .../native_haul_v10.py run --image wood|stone --palette ... --grip-palette ... --body <body.glb> --out <dir>
    $PY .../native_haul_v10.py verify --image wood|stone --palette ... --grip-palette ... --capture <dir> --out <json>
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import sys
import tempfile
import time

import numpy as np

HERE = Path(__file__).resolve().parent
HAUL = HERE.parent / "haul-handling-v1"
sys.path.insert(0, str(HAUL))
import compile_native_program_v8 as C8  # noqa: E402
import compile_native_program_v9 as C9  # noqa: E402
import run_native_program as N  # noqa: E402
import run_native_program_v9 as R9  # noqa: E402
import verify_native_program_v8 as V8  # noqa: E402
import verify_native_program_v9 as V9  # noqa: E402

C = C8.C
CORRECTED = HERE / "evidence/stand-walk-v2"
RECORD = CORRECTED / "candidate.json"
RECORD_SHA = "64579a455aefd4b5bc8863bd369e045cef13923ea1f0655437af6a4310fd1ecb"
IMAGES = {"wood": {"names": C8.TOOL_FREE, "content": "haul-handling.ugactor",
                   "capture": HAUL / "native_replay_v8/capture_native_program.gd", "masks": C8.MASKS},
          "stone": {"names": ("enter_haul_stone", "leave_haul_stone"), "content": "stone-handling.ugactor",
                    "capture": HAUL / "native_replay_v9/capture_native_program.gd", "masks": C9.MASKS}}
OWN = (Path(__file__), HAUL / "compile_native_program.py", HAUL / "compile_native_program_v8.py",
       HAUL / "compile_native_program_v9.py", HAUL / "run_native_program.py", HAUL / "native_replay/project.godot",
       HAUL / "native_replay_v8/capture_native_program.gd", HAUL / "native_replay_v9/capture_native_program.gd",
       HAUL / "run_native_program_v9.py")
MAX_CLIP_BYTES = 4 * 256 * 301 + 4096


def corrected_pins() -> dict:
    """The step-1c record and every corrected clip it names, hash-checked."""
    C.I.require(C.digest(RECORD) == RECORD_SHA, "HAUL_V10_RECORD")
    record = C.read_json(RECORD)
    pins = {str(RECORD.relative_to(C.ROOT)): RECORD_SHA}
    for name, row in record["clips"].items():
        path = CORRECTED / (name + ".npz")
        C.I.require(C.digest(path) == row["sha256"], "HAUL_V10_CLIP")
        pins[str(path.relative_to(C.ROOT))] = row["sha256"]
    return pins


def load_clip(name: str, count: int, loop: int) -> dict:
    """One bounded read of a pinned corrected clip."""
    path = CORRECTED / (name + ".npz")
    raw = path.read_bytes()
    C.I.require(len(raw) <= MAX_CLIP_BYTES and hashlib.sha256(raw).hexdigest() == corrected_pins()[
        str(path.relative_to(C.ROOT))], "HAUL_V10_CLIP")
    with np.load(io.BytesIO(raw), allow_pickle=False) as image:
        matrices, grounding = image["matrices"].copy(), image["grounding"].copy()
    C.I.require(matrices.shape[0] == count and grounding.shape == (count,), "HAUL_V10_SHAPE")
    return {"frames": count, "matrices": matrices, "grounding": grounding, "source_loop_mode": loop,
            "source_duration_s": C8.Fraction(count - 1, 30)}


def patch_wood() -> None:
    """Point the v8 compiler at the corrected tool-free clips."""
    original = C.reviewed_inputs
    C8.reviewed_inputs = lambda: {**original(), **corrected_pins(), str(Path(__file__).relative_to(C.ROOT)):
                                  C.digest(Path(__file__))}
    C8.clip_path = lambda name: CORRECTED / (name + ".npz") if name in C8.TOOL_FREE else C.clip_path(name)
    C8.load_empty_case = load_clip


def patch_stone() -> None:
    """Point the v9 compiler at the corrected stone joins."""
    joins = IMAGES["stone"]["names"]
    original_path, original_inputs = C9.clip_path, C9.reviewed_inputs
    C9.clip_path = lambda name: CORRECTED / (name + ".npz") if name in joins else original_path(name)

    def inputs() -> dict:
        pins = {}
        review = C.read_json(C9.REVIEW)
        for name in C9.CLIPS:
            if name not in joins:
                relative = str(original_path(name).relative_to(C.ROOT))
                C.I.require(review["sha256"][relative] == C.digest(original_path(name)), "STONE_V10_REVIEWED_CLIP")
                pins[relative] = review["sha256"][relative]
        pins.update(corrected_pins())
        pins[str(C9.STONE.relative_to(C.ROOT))] = C9.STONE_SHA
        pins[str(C9.BITS.relative_to(C.ROOT))] = C9.BITS_SHA
        pins[str(C.BASIS.relative_to(C.ROOT))] = C.BASIS_SHA
        pins[str(Path(__file__).relative_to(C.ROOT))] = C.digest(Path(__file__))
        return pins
    C9.reviewed_inputs = inputs
    del original_inputs


def compile_image(image: str, palette: Path, grip: Path, out: Path) -> dict:
    """Compile one successor image with the accepted compiler."""
    if image == "wood":
        patch_wood()
        return C8.compile_program(palette, grip, out)
    patch_stone()
    return C9.compile_program(palette, grip, out)


def replay(args: argparse.Namespace, sources: dict, commands: list) -> None:
    """The accepted four steps (compile, isolated import, analyzer, real non-headless replay)."""
    compilation = args.out / "compiled"
    commands.append(N.run([sys.executable, "-B", str(Path(__file__)), "compile", "--image", args.image,
                           "--palette", str(args.palette), "--grip-palette", str(args.grip_palette),
                           "--out", str(compilation)], args.out / "compile.log"))
    C.I.require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "HAUL_V10_COMPILE")
    report = C.read_json(compilation / "compilation.json")
    image = IMAGES[args.image]
    with tempfile.TemporaryDirectory(prefix="native-replay-", dir=HERE) as temporary:
        project = Path(temporary)
        assets = N.stage_project(project, sources, args.body)
        shutil.copyfile(image["capture"], project / "capture_native_program.gd")
        C.write_json(args.out / "staged-assets.json", assets)
        spec = {"content": str((compilation / image["content"]).resolve()), "content_sha256": report["content_sha256"],
                "basis": str(C.BASIS.resolve()), "basis_sha256": C.BASIS_SHA,
                "basis_producer_sha256": report["basis_producer_sha256"],
                "reserve_bytes": report["presentation_only_reservation"]["admitted_peak_bytes"],
                "body": "res://demo/assets/cast/mole_digger/body.glb", "body_sha256": C.digest(args.body),
                "views": N.VIEWS, "part_masks": list(image["masks"]), "production_qualified": False,
                "runtime_admitted": False}
        C.write_json(args.out / "spec.json", spec)
        steps = ([args.godot, "--headless", "--path", str(project), "--editor", "--quit"], "import.log"), \
            ([sys.executable, "-B", str(C.ROOT / "tools/gdscript_warnings.py"), "--project", str(project), "--port",
              "6364", "--godot", args.godot, "--json", str((args.out / "analyzer.json").resolve()),
              str(project / "capture_native_program.gd")], "analyzer.log"), \
            ([args.godot, "--path", str(project), "--script", "res://capture_native_program.gd", "--",
              str((args.out / "spec.json").resolve()), str(args.out.resolve())], "native.log")
        for command, log in steps:
            commands.append(N.run(command, args.out / log))
            C.I.require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "HAUL_V10_" + log)


def run(args: argparse.Namespace) -> None:
    """Replay with pinned sources and an invocation record."""
    C.I.require(not args.out.exists(), "HAUL_V10_OUTPUT_EXISTS")
    args.out.mkdir(parents=True)
    sources = R9.closure() if args.image == "stone" else N.closure()  # stone draws the real lump factory
    pins = {str(path.relative_to(C.ROOT)): C.digest(path) for path in OWN}
    pins.update({"godot/" + name: value for name, value in sources.items()})
    C.write_json(args.out / "source-sha256.json", pins)
    commands, error, started = [], None, time.monotonic()
    try:
        replay(args, sources, commands)
    except Exception as failure:
        error = str(failure)
    finally:
        unchanged = all(C.digest(C.ROOT / path) == expected for path, expected in pins.items())
        C.write_json(args.out / "invocation.json", {"commands": commands, "source_sha256": pins,
                     "argv": [sys.executable, "-B", *sys.argv], "source_unchanged": unchanged,
                     "custom_user_directory": N.USER, "elapsed_seconds": time.monotonic() - started, "error": error,
                     "production_qualified": False, "runtime_admitted": False})
    C.I.require(error is None and unchanged and len(commands) == 4, "HAUL_V10_INCOMPLETE:" + str(error))


def verify(args: argparse.Namespace) -> dict:
    """The accepted verifier on the successor capture; stone's cross-image stand join reads the wood v10 capture."""
    if args.image == "wood":
        patch_wood()
        return V8.verify(args.capture, args.palette, args.grip_palette)
    patch_stone()
    V9.V8_CAPTURE = args.wood_capture / "native.bin"
    return V9.verify(args.capture, args.palette, args.grip_palette)


def main() -> int:
    """compile | run | verify."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=("compile", "run", "verify"))
    parser.add_argument("--image", choices=tuple(IMAGES), required=True)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--body", type=Path)
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--wood-capture", type=Path)
    parser.add_argument("--godot", default="/opt/homebrew/bin/godot")
    args = parser.parse_args()
    args.out = args.out.resolve()  # The runner's subprocesses run from the repository root.
    if args.action == "compile":
        result = compile_image(args.image, args.palette, args.grip_palette, args.out)
        print(json.dumps({k: result[k] for k in ("wire_bytes", "frames", "clips", "content_sha256")}))
    elif args.action == "run":
        run(args)
    else:
        C.I.require(not args.out.exists(), "HAUL_V10_OUTPUT_EXISTS")
        result = verify(args)
        C.write_json(args.out, result)
        print(json.dumps({k: v for k, v in result.items() if k != "scope"})[:2000])
    return 0


if __name__ == "__main__":
    sys.exit(main())
