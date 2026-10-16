#!/usr/bin/env python3
"""Native images of the stair carry (decision 1981): sources 6 (wood) and 7 (stone) of content 12.

Each image is the item's approved hold plus the derived stair-carry clips (`evidence/clips-v1/`, pinned by their
candidate record); the wood image also carries the empty floor pair, on the closed paw with the stock hidden (mask
body only), exactly as the haul images carry their empty stand and walk:

| Image | Clips (in order) | Parts | Masks |
|---|---|---|---|
| wood (`stair-carry-wood.ugactor`) | hold, approach, descent, ascent, turn, retreat, back_up, empty_walk_off, empty_back_up | body (closed paw), the native log | 3 (body and stock), the empty pair 1 |
| stone (`stair-carry-stone.ugactor`) | hold, approach, descent, ascent, turn, retreat, back_up | body, the native stone lump | 3 |

The empty clips' hidden stock column is the S fixture transform the haul image shows at its approach and joins (the
`compile_native_program_v8.fixture` value), so nothing is moved or invented.

The accepted encoder (`underground_actor_content.encode` through `inspect_source.CONTENT`), the accepted runner steps
(compile, clean isolated import, analyzer, real non-headless Metal replay: `run_native_program`), the accepted
capture scripts (v8 for wood, v9 for stone, which draws the real lump factory) and the accepted verifier equations
(`verify_native_program`) are reused unchanged. The verifier here checks every row's event and coefficients, the
source-to-native vertex error, the floor on every flat clip (the descent and ascent are root-local: their support is
proved on the terrain, flight and bottom fixtures), the exact two-hand witness on every loaded row, every clip's ends
on the hub, the back-ups as exact reversals, and the cross-image joins with the v10 haul images (the hold, and the
stand key 8 for the empty pair).

    $PY .../native_stair_carry.py compile --image wood|stone --palette <all-cast-v9> --grip-palette <mole-grip-v3> --out <dir>
    $PY .../native_stair_carry.py run --image wood|stone --palette ... --grip-palette ... --body <body.glb> --out <dir>
    $PY .../native_stair_carry.py verify --image wood|stone --palette ... --grip-palette ... --capture <dir> --out <json>
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import io
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
HAUL = MOLE / "haul-handling-v1"
sys.path.insert(0, str(HAUL))
import compile_native_program as C  # noqa: E402
import compile_native_program_v8 as C8  # noqa: E402
import compile_native_program_v9 as C9  # noqa: E402
import run_native_program as N  # noqa: E402
import run_native_program_v9 as R9  # noqa: E402
import verify_native_program as V  # noqa: E402
import verify_native_program_v8 as V8  # noqa: E402

I = C.I
CLIPS_DIR = HERE / "evidence/clips-v1"
CANDIDATE = CLIPS_DIR / "candidate.json"
LOADED = ("approach", "descent", "ascent", "turn", "retreat", "back_up")
EMPTY = ("empty_walk_off", "empty_back_up")
ROOTED = ("descent", "ascent")
BODY_ONLY, BODY_AND_STOCK = 1, 3
HOLDS = {"wood": HAUL / "evidence/loaded-gait-review-v1/candidate/hold.npz",
         "stone": HAUL / "evidence/stone-gait-v1/hold.npz"}
WITNESSES = {"wood": HAUL / "evidence/static-contact-review-v1/static-contact.json",
             "stone": HAUL / "evidence/stone-contact-v1/static-contact.json"}
V10 = MOLE / "stand-walk-v2/evidence"
IMAGES = {"wood": {"clips": ("hold",) + LOADED + EMPTY, "content": "stair-carry-wood.ugactor",
                   "capture": HAUL / "native_replay_v8/capture_native_program.gd",
                   "v10": V10 / "native-haul-v10-wood", "v10_clips": C8.CLIPS},
          "stone": {"clips": ("hold",) + LOADED, "content": "stair-carry-stone.ugactor",
                    "capture": HAUL / "native_replay_v9/capture_native_program.gd",
                    "v10": V10 / "native-haul-v10-stone", "v10_clips": tuple(json.loads(
                        (V10 / "native-haul-v10-stone/compiled/compilation.json").read_text())["clip_names"])}}
OWN = (Path(__file__), HAUL / "compile_native_program.py", HAUL / "compile_native_program_v8.py",
       HAUL / "compile_native_program_v9.py", HAUL / "run_native_program.py", HAUL / "run_native_program_v9.py",
       HAUL / "native_replay/project.godot", HAUL / "native_replay_v8/capture_native_program.gd",
       HAUL / "native_replay_v9/capture_native_program.gd", HAUL / "verify_native_program.py",
       HAUL / "verify_native_program_v8.py")
MAX_CLIP_BYTES = 4 * 512 * 301 + 4096


def require(value: bool, code: str) -> None:
    """Every refusal names its failed fact."""
    I.require(value, "STAIR_CARRY_NATIVE_" + code)


def masks(image: str) -> tuple:
    """Body only for the empty pair; body and stock otherwise."""
    return tuple(BODY_ONLY if name in EMPTY else BODY_AND_STOCK for name in IMAGES[image]["clips"])


def clip_pins(image: str) -> dict:
    """Every clip of the image, checked against its record (the candidate, or the v10 image's hold pin)."""
    record = C.read_json(CANDIDATE)
    pins = {str(CANDIDATE.relative_to(C.ROOT)): C.digest(CANDIDATE)}
    hold = HOLDS[image]
    expected = C.read_json(IMAGES[image]["v10"] / "compiled/compilation.json")["source_sha256"]
    relative = str(hold.relative_to(C.ROOT))
    if relative in expected:
        require(expected[relative] == C.digest(hold), "HOLD_PIN")
    pins[relative] = C.digest(hold)
    for name in IMAGES[image]["clips"][1:]:
        group = "empty" if name in EMPTY else image
        path = CLIPS_DIR / group / f"{name}.npz"
        require(C.digest(path) == record["clips"][group][name]["sha256"], "CLIP_PIN:" + name)
        pins[str(path.relative_to(C.ROOT))] = C.digest(path)
    return pins


def read_clip(path: Path, pins: dict) -> dict:
    """One bounded read of a pinned clip."""
    raw = path.read_bytes()
    require(len(raw) <= MAX_CLIP_BYTES and hashlib.sha256(raw).hexdigest() == pins[str(path.relative_to(C.ROOT))],
            "CLIP_READ")
    with np.load(io.BytesIO(raw), allow_pickle=False) as image:
        matrices, grounding = image["matrices"].copy(), image["grounding"].copy()
    require(matrices.dtype == np.float32 and matrices.shape[1] in (24, 25) and matrices.shape[2] == 12 and
            grounding.shape == (len(matrices),) and np.all(np.isfinite(matrices)), "CLIP_SHAPE")
    return {"frames": len(matrices), "matrices": matrices, "grounding": grounding, "source_loop_mode": 0,
            "source_duration_s": Fraction(len(matrices) - 1, 30)}


def hidden_stock() -> np.ndarray:
    """The S fixture stock transform: key 0 of the reviewed approach, as the v8 image hides its stand/walk stock."""
    with np.load(C.clip_path("approach"), allow_pickle=False) as image:
        return image["matrices"][0, 24].copy()


def parts(image: str, palette: Path, grip: Path) -> list:
    """The body and the load exactly as the haul images draw them."""
    _, body, wood, _, _, _, _, _ = I.current_inputs(palette, grip)
    return [body, C.wrapped_stock(wood) if image == "wood" else C9.stone_part()]


def cases(image: str, geometry: list) -> list:
    """Every clip of the image as an encoder case."""
    pins, result = clip_pins(image), []
    for name in IMAGES[image]["clips"]:
        group = "empty" if name in EMPTY else image
        path = HOLDS[image] if name == "hold" else CLIPS_DIR / group / f"{name}.npz"
        case = read_clip(path, pins)
        if case["matrices"].shape[1] == 24:
            column = np.broadcast_to(hidden_stock(), (case["frames"], 1, 12))
            case["matrices"] = np.concatenate((case["matrices"], column), axis=1).astype(np.float32)
        case.update(id=f"stair_carry_v1.{image}.{name}", geometry=geometry)
        result.append(case)
    return result


def compile_image(image: str, palette: Path, grip: Path, out: Path) -> dict:
    """Encode one image with the accepted encoder and record it."""
    require(not out.exists(), "OUTPUT_EXISTS")
    pins = {**clip_pins(image), str(Path(__file__).relative_to(C.ROOT)): C.digest(Path(__file__)),
            str(C.BASIS.relative_to(C.ROOT)): C.BASIS_SHA}
    geometry = parts(image, palette, grip)
    clips = cases(image, geometry)
    out.mkdir(parents=True)
    names, frame_counts = IMAGES[image]["clips"], [c["frames"] for c in clips]
    program = {"schema": 1, "decision": "1981", "production_qualified": False, "item": image,
               "quantity_milli": 1000, "active_tool": None, "parts": ["body", "stock"],
               "clips": [{"id": c["id"], "frames": c["frames"], "loop": 0, "duration_q16": (c["frames"] - 1) * 65536,
                          "part_visibility_mask": m} for c, m in zip(clips, masks(image))],
               "source_clock": "presentation sampling only; the stair carry's pace is DEC-050's (decision 1981)"}
    program_sha = C.write_json(out / "program.json", program)
    proof = {"schema": 1, "production_qualified": False, "source_sha256": pins, "world_basis": {"sha256": C.BASIS_SHA},
             "scope": "decision 1981's source proofs (evidence/proof-v1.json); native replay pending"}
    proof_sha = C.write_json(out / "proof.json", proof)
    plan = {"schema": 1, "revision": 1, "world_root_bounds_u": C.BOUNDS, "clips": list(names),
            "part_visibility_masks": list(masks(image)), "runtime_admitted": False}
    plan_sha = C.write_json(out / "plan.json", plan)
    wire, budget = I.CONTENT.encode(clips, plan, proof, program_sha, proof_sha, plan_sha)
    (out / IMAGES[image]["content"]).write_bytes(wire)
    raw = C.BASIS.read_bytes()
    metadata = json.loads(raw[20:20 + struct.unpack_from("<I", raw, 16)[0]])
    report = {"schema": 1, "decision": "1981", "image": image, "source_sha256": pins,
              "content_sha256": hashlib.sha256(wire).hexdigest(), "wire_bytes": len(wire), "parts": 2,
              "clips": len(names), "clip_names": list(names), "clip_frames": frame_counts,
              "part_visibility_masks": list(masks(image)), "frames": sum(frame_counts),
              "basis_sha256": C.BASIS_SHA, "basis_producer_sha256": metadata["source"]["sha256"],
              "presentation_only_reservation": budget, "production_qualified": False, "runtime_admitted": False}
    C.write_json(out / "compilation.json", report)
    return report


def replay(args: argparse.Namespace, sources: dict, commands: list) -> None:
    """The accepted four steps, as `native_haul_v10.replay`."""
    compilation = args.out / "compiled"
    commands.append(N.run([sys.executable, "-B", str(Path(__file__)), "compile", "--image", args.image,
                           "--palette", str(args.palette), "--grip-palette", str(args.grip_palette),
                           "--out", str(compilation)], args.out / "compile.log"))
    require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], "COMPILE")
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
                "views": N.VIEWS, "part_masks": list(masks(args.image)), "production_qualified": False,
                "runtime_admitted": False}
        C.write_json(args.out / "spec.json", spec)
        steps = ([args.godot, "--headless", "--path", str(project), "--editor", "--quit"], "import.log"), \
            ([sys.executable, "-B", str(C.ROOT / "tools/gdscript_warnings.py"), "--project", str(project), "--port",
              "6481", "--godot", args.godot, "--json", str((args.out / "analyzer.json").resolve()),
              str(project / "capture_native_program.gd")], "analyzer.log"), \
            ([args.godot, "--path", str(project), "--script", "res://capture_native_program.gd", "--",
              str((args.out / "spec.json").resolve()), str(args.out.resolve())], "native.log")
        for command, log in steps:
            commands.append(N.run(command, args.out / log))
            require(commands[-1]["exit_code"] == 0 and not commands[-1]["diagnostics"], log)


def run(args: argparse.Namespace) -> None:
    """Replay with pinned sources and an invocation record."""
    require(not args.out.exists(), "OUTPUT_EXISTS")
    args.out.mkdir(parents=True)
    sources = R9.closure() if args.image == "stone" else N.closure()
    pins = {str(path.relative_to(C.ROOT)): C.digest(path) for path in OWN}
    pins.update({"godot/" + name: value for name, value in sources.items()})
    C.write_json(args.out / "source-sha256.json", pins)
    commands, error, started = [], None, time.monotonic()
    try:
        replay(args, sources, commands)
    except Exception as failure:  # The record keeps the failure; the require below reports it.
        error = str(failure)
    finally:
        unchanged = all(C.digest(C.ROOT / path) == expected for path, expected in pins.items())
        C.write_json(args.out / "invocation.json", {"commands": commands, "source_sha256": pins,
                     "argv": [sys.executable, "-B", *sys.argv], "source_unchanged": unchanged,
                     "custom_user_directory": N.USER, "elapsed_seconds": time.monotonic() - started, "error": error,
                     "production_qualified": False, "runtime_admitted": False})
    require(error is None and unchanged and len(commands) == 4, "INCOMPLETE:" + str(error))


def capture(path: Path, rows: int) -> np.ndarray:
    """The native capture's rows, bounded."""
    expected = 16 + rows * V.ROW_BYTES
    require(path.is_file() and path.stat().st_size == expected, "CAPTURE_CAPACITY")
    raw = path.read_bytes()
    require(raw[:8] == b"UGHNAT01" and struct.unpack_from("<II", raw, 8) == (V.INTS, V.FLOATS), "CAPTURE_HEADER")
    result = np.frombuffer(raw, dtype=V.DTYPE, count=rows, offset=16)
    require(np.all(np.isfinite(result["values"])), "CAPTURE_NONFINITE")
    return result


def chosen(counts: list, clip: int, elapsed: int) -> tuple:
    """Content.clip_into for a non-looping clip at a Q16 time."""
    count, first = counts[clip], sum(counts[:clip])
    duration = (count - 1) * 65536
    require(0 <= elapsed <= duration, "CLOCK")
    at, share = divmod(elapsed, 65536)
    after = at if elapsed == duration else min(at + 1, count - 1)
    return first + at, first + after, share


def table_of(rows: np.ndarray) -> dict:
    """(view, clip, elapsed) -> values."""
    return {(int(r["meta"][0]), int(r["meta"][1]), int(r["meta"][2])): r["values"] for r in rows}


def joins(image: str, rows: np.ndarray, counts: list) -> dict:
    """Every clip ends on its hub; the back-ups reverse their approach; the hold and stand join the v10 image."""
    table, names = table_of(rows), IMAGES[image]["clips"]
    end = lambda clip: (counts[clip] - 1) * 65536
    v10 = C.read_json(IMAGES[image]["v10"] / "compiled/compilation.json")
    v10_rows = capture(IMAGES[image]["v10"] / "native.bin", 3 * sum(4 * (n - 1) + 1 for n in v10["clip_frames"]))
    other, others = table_of(v10_rows), list(IMAGES[image]["v10_clips"])
    checked = 0
    for view in range(3):
        hold = table[view, 0, 0]
        require(np.array_equal(hold, other[view, others.index("hold"), 0]), "V10_HOLD_JOIN")
        for clip, name in enumerate(names):
            hub = hold if name not in EMPTY else other[view, others.index("stand"), V8.READY * 65536]
            for at in (0, end(clip)):
                require(np.array_equal(table[view, clip, at], hub), "HUB_JOIN:" + name)
                checked += 1
        for back, forward in (("back_up", "approach"), ("empty_back_up", "empty_walk_off")):
            if back not in names:
                continue
            a, b = names.index(back), names.index(forward)
            for elapsed in range(0, end(a) + 1, 16384):
                require(np.array_equal(table[view, a, elapsed], table[view, b, end(a) - elapsed]), "REVERSAL:" + back)
    return {"hub_joins": checked, "cross_image_joins_per_view": 1 + int("empty_walk_off" in names),
            "v10_capture_sha256": C.digest(IMAGES[image]["v10"] / "native.bin"), "views": 3}


def verify_rows(image: str, rows: np.ndarray, clips: list, geometry: list, counts: list) -> dict:
    """Events, coefficients, vertex error, floor and the two-hand witness on every row."""
    raw = C.BASIS.read_bytes()
    basis = np.frombuffer(raw, dtype="<f4", count=65536 * 2, offset=20 + struct.unpack_from("<I", raw, 16)[0]).reshape(-1, 2)
    witnesses = C.read_json(WITNESSES[image])["static_source"]["hand_contact_witnesses"]
    names, mask = IMAGES[image]["clips"], masks(image)
    maxima, floors, contacts, at = [0.0, 0.0], [float("inf")] * 2, 0, 0
    for view_index, view in enumerate(N.VIEWS):
        for clip, case in enumerate(clips):
            for elapsed in range(0, (case["frames"] - 1) * 65536 + 1, 16384):
                row, (a, b, share) = rows[at], chosen(counts, clip, elapsed)
                require(row["meta"].tolist() == [view_index, clip, elapsed, a, b, share, view["yaw"], mask[clip]], "EVENT")
                first, t = sum(counts[:clip]), share / 65536
                pose = case["matrices"][a - first].astype(np.float64) * (1 - t) + case["matrices"][b - first].astype(np.float64) * t
                ground = float(case["grounding"][a - first]) * (1 - t) + float(case["grounding"][b - first]) * t
                require(np.array_equal(row["values"], V.expected_values(pose, ground, view, basis[view["yaw"]])),
                        "COEFFICIENT")
                for part_index, part in enumerate(geometry):
                    error, floor = V8.part_error(part, part_index, pose, ground, row["values"], view, basis[view["yaw"]])
                    maxima[part_index] = max(maxima[part_index], error)
                    if names[clip] not in ROOTED and mask[clip] & (1 << part_index):
                        floors[part_index] = min(floors[part_index], floor)
                if names[clip] not in EMPTY:
                    require(V.hand_contacts(row["values"], geometry[0], geometry[1], witnesses), "HAND_CONTACT")
                    contacts += 2
                at += 1
    require(at == len(rows) and min(floors) >= 0, "FLOOR")
    return {"max_source_to_native_input_vertex_error_u": maxima,
            "minimum_visible_floor_gap_u": {"body": floors[0], "stock": floors[1]},
            "exact_rational_two_hand_witnesses": contacts}


def verify(args: argparse.Namespace) -> dict:
    """The accepted verifier equations on this image's capture."""
    folder = args.capture
    report, spec = C.read_json(folder / "report.json"), C.read_json(folder / "spec.json")
    compiled = C.read_json(folder / "compiled/compilation.json")
    counts = compiled["clip_frames"]
    rows_expected = 3 * sum(4 * (n - 1) + 1 for n in counts)
    require(report["failures"] == [] and report["rows"] == rows_expected and report["assertions"] >= 4 * rows_expected
            and report["content_sha256"] == compiled["content_sha256"] == spec["content_sha256"]
            and compiled["clip_names"] == list(IMAGES[args.image]["clips"])
            and spec["part_masks"] == list(masks(args.image)) == compiled["part_visibility_masks"]
            and report["rendering_driver"] == "metal" and report["display_server"] == "macOS", "REPORT")
    geometry = parts(args.image, args.palette, args.grip_palette)
    clips = cases(args.image, geometry)
    rows = capture(folder / "native.bin", rows_expected)
    result = {"schema": 1, "decision": "1981", "image": args.image, "rows": rows_expected,
              "clips": list(IMAGES[args.image]["clips"]), "clip_frames": counts, "coefficient_mismatches": 0,
              **verify_rows(args.image, rows, clips, geometry, counts), "joins": joins(args.image, rows, counts),
              "floor_rule": "every visible part of every clip except the root-local descent and ascent, whose "
                            "support is proved on the terrain, flight and bottom fixtures",
              "native_capture_sha256": C.digest(folder / "native.bin"), "production_qualified": False,
              "runtime_admitted": False}
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
    parser.add_argument("--godot", default="/opt/homebrew/bin/godot")
    args = parser.parse_args()
    args.out = args.out.resolve()
    if args.action == "compile":
        result = compile_image(args.image, args.palette, args.grip_palette, args.out)
        print(json.dumps({k: result[k] for k in ("wire_bytes", "frames", "clips", "content_sha256")}))
    elif args.action == "run":
        run(args)
    else:
        require(not args.out.exists(), "OUTPUT_EXISTS")
        result = verify(args)
        C.write_json(args.out, result)
        print(json.dumps(result)[:1500])
    return 0


if __name__ == "__main__":
    sys.exit(main())
