#!/usr/bin/env python3
"""Native image of the claw/paw source (ADR 1217 step 3b): the open paw, no tool, one part. Offline evidence only.

Eleven approved clips, every one pinned by its approval record:

| Clip | From |
|---|---|
| stand, walk | the corrected tool-free stand and walk (step 1c, `stand-walk-v2`) |
| dig_entry, dig_stroke, dig_recovery | pa from the corrected ready key (step 1c's `dig-pa`) |
| seat_entry, seat_work, seat_recovery | paw handling, candidate a (step 2) |
| tap_entry, tap_work, tap_recovery | paw seating, candidate a (step 2) |

The image has one part: the original imported body (the open paw, `a938d479…`). The accepted Content encoder,
isolated runner steps and verifier equations are reused; the capture script is the accepted v8 one without the
pick-paw derivative and the second part.

    $PY .../native_claw.py compile --palette <all-cast-v9> --grip-palette <mole-grip-v3> --out <dir>
    $PY .../native_claw.py run --palette ... --grip-palette ... --body <body.glb> --out <dir>
    $PY .../native_claw.py verify --palette ... --grip-palette ... --capture <dir> --out <json>
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys
import tempfile
import time

import numpy as np

HERE = Path(__file__).resolve().parent
MOLE = HERE.parent
sys.path.insert(0, str(MOLE / "haul-handling-v1"))
import compile_native_program as C  # noqa: E402
import run_native_program as N  # noqa: E402
import verify_native_program as V  # noqa: E402

I, ROOT = C.I, C.ROOT
STAND_V2 = MOLE / "stand-walk-v2/evidence/stand-walk-v2"
PAW = HERE / "evidence/paw-seat-v1/candidate-a"
SOURCES = {"stand": (STAND_V2, "stand", 1), "walk": (STAND_V2, "walk", 1),
           "dig_entry": (STAND_V2 / "dig-pa", "entry", 0), "dig_stroke": (STAND_V2 / "dig-pa", "stroke", 0),
           "dig_recovery": (STAND_V2 / "dig-pa", "recovery", 0),
           "seat_entry": (PAW, "seat_entry", 0), "seat_work": (PAW, "seat_work", 0),
           "seat_recovery": (PAW, "seat_recovery", 0), "tap_entry": (PAW, "tap_entry", 0),
           "tap_work": (PAW, "tap_work", 0), "tap_recovery": (PAW, "tap_recovery", 0)}
CLIPS = tuple(SOURCES)
CAPTURE = HERE / "native/capture_claw_native.gd"
CONTENT_NAME = "claw-paw.ugactor"
STRIDE = 24 * 12
READY = 8
OWN = (Path(__file__), CAPTURE, MOLE / "haul-handling-v1/compile_native_program.py",
       MOLE / "haul-handling-v1/run_native_program.py", MOLE / "haul-handling-v1/verify_native_program.py",
       MOLE / "haul-handling-v1/native_replay/project.godot")


def record_pins() -> dict:
    """Each clip's digest from its approval record: step 1c's candidate and proof, step 2's candidate."""
    stand = C.read_json(STAND_V2 / "candidate.json")["clips"]
    dig = C.read_json(STAND_V2 / "proof.json", 64 * 1024 * 1024)["dig_pa"]["clips"]
    paw = C.read_json(PAW / "candidate.json")["clips"]
    expected = {"stand": stand["stand"]["sha256"], "walk": stand["walk"]["sha256"],
                **{f"dig_{n}": dig[n] for n in ("entry", "stroke", "recovery")},
                **{name: paw[name]["sha256"] for name in CLIPS if name.startswith(("seat", "tap"))}}
    pins = {}
    for name in CLIPS:
        folder, file, _ = SOURCES[name]
        path = folder / (file + ".npz")
        I.require(C.digest(path) == expected[name], "CLAW_NATIVE_CLIP_PIN")
        pins[str(path.relative_to(ROOT))] = expected[name]
    pins[str(Path(__file__).relative_to(ROOT))] = C.digest(Path(__file__))
    return pins


def cases(body: dict) -> list:
    """Every approved clip as a Content case on the open-paw body."""
    result = []
    for name in CLIPS:
        folder, file, loop = SOURCES[name]
        with np.load(folder / (file + ".npz"), allow_pickle=False) as image:
            matrices, grounding = image["matrices"][:, :24].copy(), image["grounding"].copy()
        count = len(matrices)
        result.append({"id": "claw_work_v1." + name, "frames": count, "matrices": matrices, "grounding": grounding,
                       "source_loop_mode": loop, "source_duration_s": Fraction(count - 1, 30),
                       "duration_q16": (count - 1) * 65536, "geometry": [body]})
    return result


def open_body(palette: Path, grip: Path) -> dict:
    """The original cast body (the open paw), checked by fingerprint."""
    rows, _, _, _, _, _, _, _ = I.current_inputs(palette, grip)
    body = rows[I.CASE_IDS[0]]["geometry"][0]
    I.require(I.CONTENT.geometry_fingerprint(body).hex() == I.OLD_BODY, "CLAW_NATIVE_OPEN_BODY")
    return body


def compile_image(palette: Path, grip: Path, out: Path) -> dict:
    """Encode the eleven clips with the accepted Content encoder."""
    I.require(not out.exists(), "CLAW_NATIVE_OUTPUT_EXISTS")
    pins = record_pins()
    body = open_body(palette, grip)
    clips = cases(body)
    out.mkdir(parents=True)
    program = {"schema": 1, "production_qualified": False, "active_tool": None, "parts": ["body (open paw)"],
               "clips": [{"id": c["id"], "frames": c["frames"], "loop": c["source_loop_mode"]} for c in clips],
               "body_sha256": I.OLD_BODY, "source_clock": "presentation sampling only; no dig or work rate"}
    program_sha = C.write_json(out / "program.json", program)
    proof = {"schema": 1, "production_qualified": False, "world_basis": {"sha256": C.BASIS_SHA},
             "scope": "approved exact source proofs (claw dig, paw seat, corrected stand/walk); native replay separate",
             "source_sha256": pins}
    proof_sha = C.write_json(out / "proof.json", proof)
    plan = {"schema": 1, "revision": 1, "world_root_bounds_u": C.BOUNDS, "clips": list(CLIPS),
            "runtime_admitted": False}
    plan_sha = C.write_json(out / "plan.json", plan)
    wire, budget = I.CONTENT.encode(clips, plan, proof, program_sha, proof_sha, plan_sha)
    frames = sum(c["frames"] for c in clips)
    I.require(len(wire) == 184 + 72 + len(CLIPS) * 48 + frames * (STRIDE + 1) * 4 + 8, "CLAW_NATIVE_WIRE_CENSUS")
    (out / CONTENT_NAME).write_bytes(wire)
    raw = C.BASIS.read_bytes()
    metadata = json.loads(raw[20:20 + struct.unpack_from("<I", raw, 16)[0]])
    report = {"schema": 1, "source_sha256": pins, "source_unchanged": record_pins() == pins,
              "content_sha256": hashlib.sha256(wire).hexdigest(), "wire_bytes": len(wire), "parts": 1,
              "clips": len(CLIPS), "clip_names": list(CLIPS), "clip_frames": [c["frames"] for c in clips],
              "frames": frames, "basis_sha256": C.BASIS_SHA, "basis_producer_sha256": metadata["source"]["sha256"],
              "presentation_only_reservation": budget, "production_qualified": False, "runtime_admitted": False}
    I.require(report["source_unchanged"], "CLAW_NATIVE_SOURCE_CHANGED")
    C.write_json(out / "compilation.json", report)
    return report


def replay(args: argparse.Namespace, sources: dict, commands: list) -> None:
    """The accepted four steps: compile, isolated import, analyzer, real non-headless replay."""
    compilation = args.out / "compiled"
    commands.append(N.run([sys.executable, "-B", str(Path(__file__)), "compile", "--palette", str(args.palette),
                           "--grip-palette", str(args.grip_palette), "--out", str(compilation)], args.out / "compile.log"))
    I.require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "CLAW_NATIVE_COMPILE")
    report = C.read_json(compilation / "compilation.json")
    with tempfile.TemporaryDirectory(prefix="native-replay-", dir=HERE) as temporary:
        project = Path(temporary)
        C.write_json(args.out / "staged-assets.json", N.stage_project(project, sources, args.body))
        shutil.copyfile(CAPTURE, project / "capture_native_program.gd")
        spec = {"content": str((compilation / CONTENT_NAME).resolve()), "content_sha256": report["content_sha256"],
                "basis": str(C.BASIS.resolve()), "basis_sha256": C.BASIS_SHA,
                "basis_producer_sha256": report["basis_producer_sha256"],
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
            I.require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "CLAW_NATIVE_" + log)


def run(args: argparse.Namespace) -> None:
    """Replay with pinned sources and an invocation record."""
    I.require(not args.out.exists(), "CLAW_NATIVE_OUTPUT_EXISTS")
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
    I.require(error is None and unchanged and len(commands) == 4, "CLAW_NATIVE_INCOMPLETE:" + str(error))


def timing(counts: list, loops: list, clip: int, elapsed: int) -> tuple:
    """Independent restatement of Content.clip_into for a whole-key Q16 duration."""
    count, duration = counts[clip], (counts[clip] - 1) * 65536
    time_ = elapsed % duration if loops[clip] else elapsed
    first = sum(counts[:clip])
    at, share = divmod(time_, 65536)
    after = min(at + 1, count - 1)
    if loops[clip] and at == count - 2:
        after = 0
    if time_ == duration:
        after = at
    return first + at, first + after, share


def expected_row(case: dict, first: int, chosen: tuple, view: dict, pair: np.ndarray) -> tuple:
    """The accepted coefficient equation with the absent second part as identity."""
    a, b, share = chosen
    t = share / 65536
    pose = case["matrices"][a - first].astype(np.float64) * (1 - t) + case["matrices"][b - first].astype(np.float64) * t
    ground = float(case["grounding"][a - first]) * (1 - t) + float(case["grounding"][b - first]) * t
    padded = np.concatenate((pose, np.array([[1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]], dtype=np.float64)))
    values = V.expected_values(padded, ground, view, pair)
    values[288:300] = np.array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0], dtype="<f4")
    return pose, ground, values


def body_error(body: dict, pose: np.ndarray, ground: float, actual: np.ndarray, view: dict, pair: np.ndarray) -> tuple:
    """Source-to-native vertex error and the native vertices (u, world)."""
    source = V.skin(body, pose)
    source[:, 1] += ground
    c, s = map(float, pair)
    ideal = source.copy()
    ideal[:, 0] = c * source[:, 0] + s * source[:, 2]
    ideal[:, 2] = -s * source[:, 0] + c * source[:, 2]
    ideal += np.asarray(view["root_u"]) / 1024
    observed = V.transformed(V.skin(body, actual[:288].reshape(24, 12)), actual[300:312].astype(np.float64))
    return float(np.max(np.abs(observed - ideal))) * 1024, observed


def joins(rows: np.ndarray, counts: list) -> int:
    """Exact joins: ready → each entry, entry end → work start, work end → recovery start, recovery end → ready;
    and each recovery is the exact reverse of its entry."""
    table = {(int(r["meta"][0]), int(r["meta"][1]), int(r["meta"][2])): r["values"] for r in rows}
    end = lambda clip: (counts[clip] - 1) * 65536
    stand, checked = CLIPS.index("stand"), 0
    for view in range(3):
        for program in ("dig", "seat", "tap"):
            entry, work = CLIPS.index(program + "_entry"), CLIPS.index(program + ("_stroke" if program == "dig" else "_work"))
            recovery = CLIPS.index(program + "_recovery")
            pairs = ((stand, READY * 65536, entry, 0), (entry, end(entry), work, 0), (work, end(work), recovery, 0),
                     (recovery, end(recovery), stand, READY * 65536))
            for a, at, b, bt in pairs:
                I.require(np.array_equal(table[view, a, at], table[view, b, bt]), "CLAW_NATIVE_JOIN")
                checked += 1
            for elapsed in range(0, end(entry) + 1, 16384):
                I.require(np.array_equal(table[view, entry, elapsed], table[view, recovery, end(entry) - elapsed]),
                          "CLAW_NATIVE_REVERSAL")
    return checked


def verify(folder: Path, palette: Path, grip: Path) -> dict:
    """Every native row against the approved source equation; body floor outside the digging paws."""
    report, compiled = C.read_json(folder / "report.json"), C.read_json(folder / "compiled/compilation.json")
    counts, body = compiled["clip_frames"], open_body(palette, grip)
    clips = cases(body)
    loops = [c["source_loop_mode"] for c in clips]
    rows_expected = 3 * sum(4 * (n - 1) + 1 for n in counts)
    I.require(report["failures"] == [] and report["rows"] == rows_expected and
              report["content_sha256"] == compiled["content_sha256"] and report["rendering_driver"] == "metal" and
              report["display_server"] == "macOS", "CLAW_NATIVE_REPORT")
    rows = V8_capture(folder / "native.bin", rows_expected)
    raw = C.BASIS.read_bytes()
    basis = np.frombuffer(raw, dtype="<f4", count=65536 * 2, offset=20 + struct.unpack_from("<I", raw, 16)[0]).reshape(-1, 2)
    paw = np.any(np.isin(body["geometry"][0]["ids"], [15, 19]) & (body["geometry"][0]["weights"] > 0), axis=1)
    worst, floor, at = 0.0, float("inf"), 0
    for view_index, view in enumerate(N.VIEWS):
        for clip, case in enumerate(clips):
            first = sum(counts[:clip])
            for elapsed in range(0, (case["frames"] - 1) * 65536 + 1, 16384):
                row, chosen = rows[at], timing(counts, loops, clip, elapsed)
                I.require(row["meta"].tolist() == [view_index, clip, elapsed, *chosen, view["yaw"], 1], "CLAW_NATIVE_EVENT")
                pose, ground, values = expected_row(case, first, chosen, view, basis[view["yaw"]])
                I.require(np.array_equal(row["values"], values), "CLAW_NATIVE_COEFFICIENT")
                error, observed = body_error(body, pose, ground, row["values"], view, basis[view["yaw"]])
                worst = max(worst, error)
                kept = ~paw if CLIPS[clip].startswith("dig") else np.ones(len(paw), dtype=bool)
                floor = min(floor, float(observed[kept, 1].min()) * 1024 - view["root_u"][1])
                at += 1
    I.require(at == rows_expected and floor >= 0, "CLAW_NATIVE_FLOOR")
    return {"schema": 1, "adr": "1217", "rows": rows_expected, "clips": list(CLIPS), "clip_frames": counts,
            "coefficient_mismatches": 0, "max_source_to_native_input_vertex_error_u": worst,
            "minimum_floor_gap_u": floor, "floor_rule": "every body vertex, except paw vertices in the dig clips",
            "exact_joins": joins(rows, counts), "native_capture_sha256": C.digest(folder / "native.bin"),
            "production_qualified": False, "runtime_admitted": False,
            "scope": "Actual native registered matrix inputs at all keys and quarter intervals in three views; "
                     "binary64 vertex reconstruction. GPU shader roundoff and unsampled Q16 times are not certified."}


def V8_capture(path: Path, rows: int) -> np.ndarray:
    """The accepted capture reader for an arbitrary row count."""
    expected = 16 + rows * V.ROW_BYTES
    raw = path.read_bytes()
    I.require(len(raw) == expected and raw[:8] == b"UGHNAT01" and struct.unpack_from("<II", raw, 8) == (V.INTS, V.FLOATS),
              "CLAW_NATIVE_CAPTURE_HEADER")
    return np.frombuffer(raw, dtype=V.DTYPE, count=rows, offset=16)


def main() -> int:
    """compile | run | verify."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=("compile", "run", "verify"))
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--body", type=Path)
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--godot", default="/opt/homebrew/bin/godot")
    args = parser.parse_args()
    args.out = args.out.resolve()  # The runner's subprocesses run from the repository root.
    if args.action == "compile":
        result = compile_image(args.palette, args.grip_palette, args.out)
        print(json.dumps({k: result[k] for k in ("wire_bytes", "frames", "clips", "content_sha256")}))
    elif args.action == "run":
        run(args)
    else:
        I.require(not args.out.exists(), "CLAW_NATIVE_OUTPUT_EXISTS")
        result = verify(args.capture, args.palette, args.grip_palette)
        C.write_json(args.out, result)
        print(json.dumps({k: v for k, v in result.items() if k != "scope"}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
