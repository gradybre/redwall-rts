#!/usr/bin/env python3
"""Author the tool-free stand/walk and its joins into the haul program (ADR 1198 step 1); source only.

The supplied tool-free Meshy clips `mole_digger.idle.plain` and `mole_digger.walk.plain`
are bound to the current mole body and rig exactly as ADR 1144's handling sources are.
Matrices stay byte-identical to the pinned palette. Only grounding is re-authored (the
same 1/512 u sole gap as the loaded gait), the native wrap key is closed on key 0, and
the walk gains the measured sole-transfer keys the reviewed gait recipe adds. Two joins
connect the stand's ready key with the haul program's empty `approach` start and
`recovery` end, which are the same byte-identical pose. No pick part exists here.
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import io
import json
from pathlib import Path
import zipfile

import numpy as np

import author_handling as A
import author_loaded_gait as G
import author_program as LIFT

PROGRAM = A.I.HERE / "evidence/program-review-v1/candidate"
APPROACH_SHA = "213e4f9ca9e77b791795c0596424d05f2ebc2edd88431850588fecebe2f922f4"
RECOVERY_SHA = "d6add16d6f559ed8f3a1cb015aeec78e3ead24f7878169d9467bee7e7a7b9034"
STAND_ID, WALK_ID = A.I.CASE_IDS[0], A.I.CASE_IDS[1]
READY_FRAME = 8  # The driver's existing ready_time_q16 = 8 * 65536 protocol.
JOIN_SEGMENTS = 30  # P.rig_transition's existing 31-key entry default.
CLIPS = ("stand", "walk", "enter_haul", "leave_haul")
ZIP_TIME = (1980, 1, 1, 0, 0, 0)


def require(condition: bool, code: str) -> None:
    A.require(condition, code)


def write_case(path: Path, case: dict) -> None:
    """Byte-reproducible NPZ (fixed member order and timestamp) readable by every existing loader."""
    with zipfile.ZipFile(path, "x", compression=zipfile.ZIP_STORED) as image:
        for name in ("matrices", "grounding"):
            stream = io.BytesIO()
            np.lib.format.write_array(stream, np.ascontiguousarray(case[name]), allow_pickle=False)
            image.writestr(zipfile.ZipInfo(name + ".npy", ZIP_TIME), stream.getvalue())


def read_program(name: str, expected: str) -> dict:
    path = PROGRAM / (name + ".npz")
    require(hashlib.sha256(path.read_bytes()).hexdigest() == expected, "EMPTY_WALK_PROGRAM_PIN")
    with np.load(path, allow_pickle=False) as image:
        return {"frames": len(image["matrices"]), "matrices": image["matrices"].copy(),
                "grounding": image["grounding"].copy(), "source_loop_mode": 0,
                "source_duration_s": Fraction(len(image["matrices"]) - 1, 30)}


def closed_loop(row: dict, body: dict) -> tuple:
    """Exact supplied matrices; re-grounded keys; the native wrap sample becomes key 0 exactly."""
    require(row["frames"] >= 3 and row["matrices"].shape[1:] == (24, 12) and row["source_loop_mode"] == 1 and
            len(row["geometry"]) == 1 and row["geometry"][0]["kind"] == "body", "EMPTY_WALK_SOURCE_SHAPE")
    wrap = float(np.max(np.abs(row["matrices"][0].astype(np.float64) - row["matrices"][-1])))
    require(wrap < 1e-5, "EMPTY_WALK_WRAP_SAMPLE")
    palettes = [row["matrices"][frame].copy() for frame in range(row["frames"] - 1)] + [row["matrices"][0].copy()]
    grounds = [G.ground_key(palette, float(row["grounding"][at % (row["frames"] - 1)]), body)
               for at, palette in enumerate(palettes)]
    return G.case_of(palettes, grounds, 1), wrap


def join_keys(start: np.ndarray, start_ground: np.float32, finish: np.ndarray, finish_ground: np.float32,
              rig: tuple, body: dict, segments: int) -> dict:
    """Local-rig smoothstep blend, as the loaded-gait entry; exact endpoint bytes, sole gap on interior keys."""
    parents, inverse, inverse_inverse = rig
    one = lambda palette, ground: {"frames": 1, "matrices": palette[None, :], "grounding": np.array([ground])}
    first = A.globals_at(one(start, start_ground), 0, inverse_inverse)
    last = A.globals_at(one(finish, finish_ground), 0, inverse_inverse)
    palettes, grounds = [], []
    for frame in range(segments + 1):
        share = frame / segments
        share = share * share * (3 - 2 * share)
        palette = A.encoded(LIFT.global_blend(first, last, parents, share), inverse)
        palettes.append(palette)
        grounds.append(G.ground_key(palette, float(start_ground) * (1 - share) + float(finish_ground) * share, body))
    result = G.case_of(palettes, grounds)
    result["matrices"][0], result["grounding"][0] = start, start_ground
    result["matrices"][-1], result["grounding"][-1] = finish, finish_ground
    return result


def with_fixture(case: dict, stock: np.ndarray) -> dict:
    """Display the floor stock at S as world geometry (the approach's own role), never as attached cargo."""
    column = np.broadcast_to(stock, (case["frames"], 1, 12))
    return {**case, "matrices": np.concatenate((case["matrices"], column), axis=1).astype(np.float32)}


def reversed_case(case: dict) -> dict:
    return {**case, "matrices": case["matrices"][::-1].copy(), "grounding": case["grounding"][::-1].copy()}


def author(rows: dict, body: dict, topology: dict) -> tuple:
    """Return the four clips plus their authoring record; every proof remains separate and exact."""
    rig = A.hierarchy(topology)
    stand, stand_wrap = closed_loop(rows[STAND_ID], body)
    original_walk, walk_wrap = closed_loop(rows[WALK_ID], body)
    walk, walk_keys = G.support_keys(original_walk, body, topology)
    approach, recovery = read_program("approach", APPROACH_SHA), read_program("recovery", RECOVERY_SHA)
    hub, stock = approach["matrices"][0], approach["matrices"][0, 24]
    require(np.array_equal(recovery["matrices"][-1], hub) and recovery["grounding"][-1] == approach["grounding"][0] and
            np.array_equal(recovery["matrices"][:, 24], np.broadcast_to(stock, (recovery["frames"], 12))),
            "EMPTY_WALK_PROGRAM_JOIN")
    blended = join_keys(stand["matrices"][READY_FRAME], stand["grounding"][READY_FRAME], hub[:24],
                        approach["grounding"][0], rig, body, JOIN_SEGMENTS)
    enter, enter_keys = G.support_keys(blended, body, topology)
    require(np.array_equal(enter["matrices"][-1], hub[:24]) and enter["grounding"][-1] == approach["grounding"][0],
            "EMPTY_WALK_JOIN_ENDPOINT")
    clips = {"stand": stand, "walk": walk, "enter_haul": with_fixture(enter, stock),
             "leave_haul": with_fixture(reversed_case(enter), stock)}
    record = {"stand": {"source": STAND_ID, "native_wrap_max_abs": stand_wrap, "keys": "original frames 0..n-2, key n-1 = key 0"},
              "walk": {"source": WALK_ID, "native_wrap_max_abs": walk_wrap, "support_transfer_keys": walk_keys,
                       "original_rendered_intervals": original_walk["frames"] - 1,
                       "authored_rendered_intervals": walk["frames"] - 1,
                       "cadence_note": "transfer keys lengthen the source cycle; playback follows the adopted ground pace cap, not this clock"},
              "enter_haul": {"from": ["stand", READY_FRAME], "to": ["approach", 0], "segments": JOIN_SEGMENTS,
                             "support_transfer_keys": enter_keys,
                             "method": "local proper-rotation shortest blend and local translation blend (author_program.global_blend), smoothstep share"},
              "leave_haul": {"from": ["recovery", recovery["frames"] - 1], "to": ["stand", READY_FRAME],
                             "method": "exact reverse of enter_haul"}}
    return clips, record


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    require(not args.out.exists() and not args.out.is_symlink(), "HANDLING_OUTPUT_EXISTS")
    rows, body, _, _, topology, _, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    clips, record = author(rows, body, topology)
    args.out.mkdir(parents=True)
    for name, case in clips.items():
        write_case(args.out / (name + ".npz"), case)
    metadata = {"schema": 1, "production_qualified": False, "tool": None, "cargo": None,
                "source_palette_sha256": A.I.PALETTE_SHA, "current_mesh_palette_sha256": A.I.GRIP_SHA,
                "source_body_sha256": A.I.BODY, "approach_sha256": APPROACH_SHA, "recovery_sha256": RECOVERY_SHA,
                "producer_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                "ready_frame": READY_FRAME,
                "clips": {name: {"frames": case["frames"], "loop_mode": case["source_loop_mode"],
                                 "matrix_columns": case["matrices"].shape[1],
                                 "stock_role": "world_target" if case["matrices"].shape[1] == 25 else None,
                                 "sha256": hashlib.sha256((args.out / (name + ".npz")).read_bytes()).hexdigest()}
                          for name, case in clips.items()},
                "authoring": record, "source_timing_only": True, "runtime_walk_rate_adopted": False,
                "missing": ["native replay (native-program v8)", "body self-clearance", "foot sliding / root advance",
                            "runtime profile rows and presentation binding", "joint memory admission"]}
    (args.out / "candidate.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(json.dumps({"output": str(args.out), "clips": {k: v["frames"] for k, v in metadata["clips"].items()},
                      "production_qualified": False}))


if __name__ == "__main__":
    main()
