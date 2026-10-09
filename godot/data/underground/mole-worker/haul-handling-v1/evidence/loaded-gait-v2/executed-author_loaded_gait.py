#!/usr/bin/env python3
"""Additive exact-one-unit wood gait candidate from the current rig and original carry legs."""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path

import numpy as np

import author_handling as A
import author_program as LIFT

HUB = A.I.HERE / "evidence/program-review-v1/candidate/lift.npz"
MAX_KEYS = 256


def case_of(palettes: list, grounds: list, loop: int = 0) -> dict:
    A.require(2 <= len(palettes) <= MAX_KEYS, "HAUL_GAIT_KEY_CAPACITY")
    return {"frames": len(palettes), "matrices": np.asarray(palettes, dtype=np.float32),
            "grounding": np.asarray(grounds, dtype=np.float32), "source_loop_mode": loop,
            "source_duration_s": Fraction(len(palettes) - 1, 30)}


def ground_key(palette: np.ndarray, guess: float, body: dict) -> np.float32:
    """Author a tiny source floor gap; a later exact proof must validate every triangle and support interval."""
    current = {"frames": 1, "matrices": palette[None, :], "grounding": np.array([guess], dtype=np.float32)}
    points = A.I.points_at(current, body, 0)
    return np.float32(float(current["grounding"][0]) + (1 / 512 - float(points[:, 1].min())) / 1024)


def carry_keys(carry: dict, held: list, held_stock: np.ndarray, parents: list, inverse: list,
               inverse_inverse: list, body: dict) -> dict:
    """Retain actual carry legs/hips and constant authored loaded upper local joints and complete stock."""
    locals_ = A.locals_of(held, parents)
    palettes, grounds = [], []
    for frame in range(carry["frames"]):
        original = A.globals_at(carry, frame, inverse_inverse)
        moved = [row.copy() for row in original[:9]]
        for at in range(9, 24):
            moved.append(moved[parents[at]] @ locals_[at])
        stock = moved[9] @ np.linalg.inv(held[9]) @ held_stock
        palette = np.concatenate((A.encoded(moved, inverse), A.packed(stock)[None, :]))
        palettes.append(palette)
        grounds.append(ground_key(palette, float(carry["grounding"][frame]), body))
    result = case_of(palettes, grounds, 1)
    A.require(np.array_equal(result["matrices"][0], result["matrices"][-1]) and
              result["grounding"][0] == result["grounding"][-1], "HAUL_GAIT_LOOP_JOIN")
    return result


def entry_keys(held: list, destination: list, held_stock: np.ndarray, parents: list, inverse: list,
               held_palette: np.ndarray, held_ground: float, gait: dict, body: dict, segments: int) -> dict:
    """Source-only local rig blend into the carry loop; full interval and native checks are still required."""
    palettes, grounds = [], []
    start, finish = A.locals_of(held, parents), A.locals_of(destination, parents)
    for frame in range(segments + 1):
        share = frame / segments
        share = share * share * (3 - 2 * share)
        moved = []
        for at, parent in enumerate(parents):
            local = start[at].copy()
            local[:3, :3] = LIFT.rotation_blend(start[at][:3, :3], finish[at][:3, :3], share)
            if parent < 0:
                local[:3, 3] = start[at][:3, 3] * (1 - share) + finish[at][:3, 3] * share
            moved.append(moved[parent] @ local if parent >= 0 else local)
        stock = moved[9] @ np.linalg.inv(held[9]) @ held_stock
        palette = np.concatenate((A.encoded(moved, inverse), A.packed(stock)[None, :]))
        palettes.append(palette)
        grounds.append(ground_key(palette, held_ground, body))
    result = case_of(palettes, grounds)
    result["matrices"][0], result["grounding"][0] = held_palette, held_ground
    result["matrices"][-1], result["grounding"][-1] = gait["matrices"][0], gait["grounding"][0]
    return result


def floor_switches(first: np.ndarray, last: np.ndarray) -> list:
    """Find authoring keys of the actual sole-height lower envelope; the independent proof remains exact."""
    slopes = last - first
    time, result = 0., []
    active = int(np.argmin(first))
    for _ in range(16):
        denominator = slopes[active] - slopes
        valid = denominator > 1e-12
        crossings = np.full(len(first), np.inf)
        crossings[valid] = (first[valid] - first[active]) / denominator[valid]
        crossings[(crossings <= time + 1e-8) | (crossings >= 1 - 1e-8)] = np.inf
        target = int(np.argmin(crossings))
        value = float(crossings[target])
        if not np.isfinite(value):
            return result
        result.append(value)
        time, active = value, target
    raise ValueError("HAUL_GAIT_FLOOR_SWITCH_CAPACITY")


def support_keys(case: dict, body: dict, topology: dict) -> tuple:
    """Split common affine source intervals at alternating-foot contact transfers, preserving all meshes."""
    triangles = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    feet = np.unique(np.concatenate([triangles[A.RIG.M.anatomical_foot_triangles(body, triangles, side)]
                                     for side in ([3, 4], [7, 8])]))
    heights = [A.I.points_at(case, body, frame)[feet, 1] for frame in range(case["frames"])]
    palettes, grounds = [case["matrices"][0].copy()], [case["grounding"][0]]
    keys = [{"original_frame": 0}]
    for frame in range(case["frames"] - 1):
        for share in floor_switches(heights[frame], heights[frame + 1]):
            palette = ((1 - share) * case["matrices"][frame].astype(np.float64) +
                       share * case["matrices"][frame + 1].astype(np.float64)).astype(np.float32)
            guess = (1 - share) * float(case["grounding"][frame]) + share * float(case["grounding"][frame + 1])
            palettes.append(palette)
            grounds.append(ground_key(palette, guess, body))
            keys.append({"original_interval": [frame, frame + 1], "source_share": share,
                         "reason": "actual sole-height lower-envelope switch"})
        palettes.append(case["matrices"][frame + 1].copy())
        grounds.append(case["grounding"][frame + 1])
        keys.append({"original_frame": frame + 1})
    return case_of(palettes, grounds, case["source_loop_mode"]), keys


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--entry-segments", type=int, default=60)
    args = parser.parse_args()
    A.require(not args.out.exists() and not args.out.is_symlink(), "HANDLING_OUTPUT_EXISTS")
    A.require(2 <= args.entry_segments <= 120, "HAUL_GAIT_ENTRY_CAPACITY")
    rows, body, wood, _, topology, _, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    parents, inverse, inverse_inverse = A.hierarchy(topology)
    with np.load(HUB, allow_pickle=False) as source:
        matrix, ground = source["matrices"][-1].copy(), float(source["grounding"][-1])
    hub = case_of([matrix, matrix], [ground, ground])
    held = A.globals_at(hub, 0, inverse_inverse)
    stock = A.I.affine(matrix[24])
    original_gait = carry_keys(rows[A.I.CASE_IDS[2]], held, stock, parents, inverse, inverse_inverse, body)
    original_entry = entry_keys(held, A.globals_at(original_gait, 0, inverse_inverse), stock, parents, inverse, matrix, ground,
                               original_gait, body, args.entry_segments)
    gait, gait_keys = support_keys(original_gait, body, topology)
    entry, entry_key_map = support_keys(original_entry, body, topology)
    exit_ = {**entry, "matrices": entry["matrices"][::-1].copy(), "grounding": entry["grounding"][::-1].copy()}
    args.out.mkdir(parents=True)
    clips = {"hold": hub, "enter": entry, "carry": gait, "exit": exit_}
    for name, case in clips.items():
        LIFT.write_case(args.out / (name + ".npz"), case)
    LIFT.write_case(args.out / "poses.npz", gait)
    metadata = {"schema": 1, "production_qualified": False,
                "variant": {"name": "wood_one_unit_v1", "quantity_milli": 1000,
                            "mass_g": 5000, "mass_scope": "Existing Catalog wood mapping; no new density or balancing rule.",
                            "other_quantities": "Refuse this physical source; general Inventory and partial transfers remain unchanged."},
                "source_hub_sha256": hashlib.sha256(HUB.read_bytes()).hexdigest(),
                "producer_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                "source_palette_sha256": A.I.PALETTE_SHA, "source_body_sha256": A.I.BODY, "source_wood_sha256": A.I.LOG,
                "clips": {name: {"frames": case["frames"], "loop_mode": case["source_loop_mode"],
                                  "sha256": hashlib.sha256((args.out / (name + ".npz")).read_bytes()).hexdigest()}
                          for name, case in clips.items()},
                "source_timing_only": True, "runtime_carry_rate_adopted": False,
                "support_transfer_keys": {"carry": gait_keys, "enter": entry_key_map},
                "transfer_key_scope": "Common affine source points are split at actual foot-height switches; every full body/stock primitive is retained, then independently re-proved.",
                "missing": ["continuous body/stock/foot proof", "native arithmetic", "turns", "empty-ground approach join",
                            "actual distance/root progression", "runtime exact1U/station/contact binding", "joint memory admission"]}
    (args.out / "candidate.json").write_text(json.dumps(metadata, indent=2) + "\n")
    (args.out / "executed-author_loaded_gait.py").write_bytes(Path(__file__).read_bytes())
    print(json.dumps({"output": str(args.out), "clips": metadata["clips"], "production_qualified": False}))


if __name__ == "__main__":
    main()
