#!/usr/bin/env python3
"""Author static two-hand grip candidates on the carried stone lump (ADR 1206); never runtime permission.

The pose recipe is wood's (author_handling.contact_pose): the reviewed carry hub, an actual torso lean about
the spine, an actual hip squat that keeps both feet, and fixed-length two-link arm solves. Only the hand targets
and the stock differ:

* the stock is the captured procedural lump (evidence/stone-source-v1) at the adopted 0.150 m/unit scale with
  the dressing's 0.8 vertical squash and no rotation (evidence/stone-scale-v2), resting 1/512 u above the floor
  with its centre on S = (0, 0, -ahead);
* each hand keeps the orientation it has on the wood stock at the same station, and is translated inward along
  X by its own `--in` amount (plus the shared raise and per-hand back offsets), so the palms close on the lump.

Every body/clothing triangle and every stone triangle is kept. Candidates are judged by prove_stone_contact.py.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

import author_handling as A

HERE = Path(__file__).resolve().parent
STONE = HERE / "evidence/stone-source-v1/native-stone.json"
STONE_SHA = "ddcb70bf666021ded1b12741f3a741e25ffb9d37b79ed9c95f71f74dcb091a6e"
SCALE = HERE / "evidence/stone-scale-v2/fine.json"
SCALE_M = 0.15
SQUASH = 0.8


def stone_part() -> tuple[dict, np.ndarray]:
    """The exact captured lump as a rigid single-surface part, plus its triangle list."""
    A.require(hashlib.sha256(STONE.read_bytes()).hexdigest() == STONE_SHA, "STONE_SOURCE_IDENTITY")
    A.require(json.loads(SCALE.read_text())["adopted_scale_m"] == [SCALE_M, SCALE_M * SQUASH, SCALE_M],
              "STONE_SCALE_IDENTITY")
    capture = json.loads(STONE.read_text())
    points = np.asarray(capture["points"], dtype="<f4")
    indices = np.asarray(capture["indices"], dtype=np.int32)
    A.require(points.shape == (70, 3) and indices.shape == (324,) and np.all((0 <= indices) & (indices < 70)),
              "STONE_TOPOLOGY")
    part = {"name": "stone", "binds": 0,
            "geometry": [{"points": points, "ids": np.zeros((70, 1), dtype=np.int32),
                          "weights": np.ones((70, 1), dtype=np.float32)}]}
    return part, indices.reshape(-1, 3)


def stone_rest(stone: dict, grounding: float, ahead_u: int) -> np.ndarray:
    """Lump scale, unrotated, lowest vertex 1/512 u above the floor, centre over S."""
    matrix = np.eye(4)
    matrix[:3, :3] = np.diag([SCALE_M, SCALE_M * SQUASH, SCALE_M])
    low = float((stone["geometry"][0]["points"].astype(np.float64) @ matrix[:3, :3].T)[:, 1].min())
    matrix[:3, 3] = [0., -low - grounding + 1 / (512 * 1024), -ahead_u / 1024]
    return matrix


def grip_pose(hub: list, hub_log: np.ndarray, inverse: list, grounding: float, log: dict, stone: dict,
              recipe: dict) -> tuple:
    """Wood's lean/squat/arm solve with each hand moved inward onto the lump; link lengths never change."""
    lean, ahead, drop = recipe["lean"], recipe["ahead"], recipe["drop"]
    left_in, right_in = recipe["in"]
    A.require(all(type(v) is int and 0 <= v <= 384 for v in (left_in, right_in)), "STONE_GRIP_CANDIDATE")
    # Wood's own solve fixes the torso and each hand's orientation on a stock at this station.
    pose, _, wood = A.contact_pose(hub, hub_log, inverse, grounding, lean, ahead, log, drop,
                                   recipe["raise"], recipe["back"][0], recipe["back"][1])
    moved = [row.copy() for row in pose]
    error = 0.
    for (shoulder, elbow, wrist), shift in (((13, 14, 15), left_in), ((17, 18, 19), -right_in)):
        target_hand = pose[wrist].copy()
        target_hand[0, 3] += shift / 1024
        start, old_middle, old_end = [moved[index][:3, 3] for index in (shoulder, elbow, wrist)]
        target = target_hand[:3, 3]
        middle = A.RIG.knee_target(start, old_middle, old_end, target)
        for bone, previous_start, previous_end, final_start, final_end in (
                (shoulder, start, old_middle, start, middle), (elbow, old_middle, old_end, middle, target)):
            final = moved[bone].copy()
            final[:3, :3] = A.RIG.rotation_between(previous_end - previous_start, final_end - final_start) @ final[:3, :3]
            final[:3, 3] = final_start
            moved[bone] = final
        moved[wrist] = target_hand
        error = max(error, abs(np.linalg.norm(middle - start) - np.linalg.norm(old_middle - start)),
                    abs(np.linalg.norm(target - middle) - np.linalg.norm(old_end - old_middle)))
    A.require(error < 1e-10, "STONE_LINK_LENGTH_DRIFT")
    stock = stone_rest(stone, grounding, ahead)
    points = stone["geometry"][0]["points"].astype(np.float64) @ stock[:3, :3].T + stock[:3, 3] + [0, grounding, 0]
    return moved, stock, {"maximum_arm_link_error_m": max(error, wood["maximum_arm_link_error_m"]),
                          "lean_degrees": lean, "hip_drop_u": drop, "grip_raise_u": recipe["raise"],
                          "grip_back_u": recipe["back"], "grip_in_u": recipe["in"],
                          "station_R_minus_S_u": [0, 0, ahead], "stone_scale_m": [SCALE_M, SCALE_M * SQUASH, SCALE_M],
                          "stock_mesh_bounds_u": A.I.box(points * 1024)}


def author(inputs: tuple, recipe: dict, plant: bool) -> tuple:
    """One candidate: [hub, pose] cases with the lump as part 24, and the recipe."""
    rows, body, log, _, topology, compact, _, _ = inputs
    stone, _ = stone_part()
    hub, inverse, hub_log, _ = A.planted_carry(compact[0], rows[A.I.CASE_IDS[2]], topology)
    grounding = float(compact[0]["grounding"][8])
    pose, stock, result = grip_pose(hub, hub_log, inverse, grounding, log, stone, recipe)
    if plant:
        pose, result["sole_contact"] = A.plant_soles(pose, stock, inverse, grounding, body, topology)
    cases = [A.one_case(hub, stock, inverse, grounding, [body, stone]),
             A.one_case(pose, stock, inverse, grounding, [body, stone])]
    return cases, result


def write(out: Path, cases: list, result: dict) -> None:
    A.require(not out.exists() and not out.is_symlink(), "STONE_OUTPUT_EXISTS")
    out.mkdir(parents=True)
    np.savez(out / "poses.npz", matrices=np.concatenate([case["matrices"] for case in cases]),
             grounding=np.concatenate([case["grounding"] for case in cases]))
    report = {"schema": 1, "status": "UNQUALIFIED_SOURCE_CANDIDATE", "production_qualified": False,
              "adr": "1206", "source_palette_sha256": A.I.PALETTE_SHA, "body_mesh_sha256": A.I.BODY,
              "stone_capture_sha256": STONE_SHA, "recipe": result,
              "producer_sources": {str(Path(p).relative_to(A.I.ROOT)): A.CONTENT_HASH(p)
                                   for p in (__file__, A.__file__, A.I.__file__, A.RIG.__file__)}}
    (out / "candidate.json").write_text(json.dumps(report, indent=2) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--lean", type=int, default=95)
    parser.add_argument("--ahead", type=int, default=576)
    parser.add_argument("--drop", type=int, default=96)
    parser.add_argument("--raise", dest="raise_", type=int, default=64)
    parser.add_argument("--back", type=int, nargs=2, default=[192, 160])
    parser.add_argument("--in", dest="in_", type=int, nargs=2, required=True)
    parser.add_argument("--plant-soles", action="store_true")
    args = parser.parse_args()
    recipe = {"lean": args.lean, "ahead": args.ahead, "drop": args.drop, "raise": args.raise_,
              "back": args.back, "in": args.in_}
    inputs = A.I.current_inputs(args.palette, args.grip_palette)
    cases, result = author(inputs, recipe, args.plant_soles)
    write(args.out, cases, result)
    print(json.dumps({"candidate": str(args.out), "recipe": result, "production_qualified": False}))


if __name__ == "__main__":
    main()
