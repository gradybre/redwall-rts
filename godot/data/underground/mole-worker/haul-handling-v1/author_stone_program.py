#!/usr/bin/env python3
"""Author the stone's four-phase approach/lift/place/recovery from the approved v1 grip (ADR 1206).

Wood's program recipe (author_program.py) unchanged: from the exact static contact pose, the hips rise out of
the squat and the torso lifts from the 95-degree lean to the hub lean (smoothstep), the stock translates up by
`rise` and out to `advance` without rotating, and both fixed-length arms are re-solved so each hand keeps its
exact relation to the stock. Approach and recovery reverse the lift with the stone left on the floor (world
geometry, not cargo); place is the exact reverse of lift. Frame 0 of lift is the approved pose byte for byte.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

import author_handling as A
import author_program as AP
import author_stone_grip as G

STATIC = A.I.HERE / "evidence/stone-contact-v1"


def static_pose() -> tuple:
    """The approved v1 contact pose and its stone stock matrix."""
    original = np.load(STATIC / "poses.npz", allow_pickle=False)
    return original, A.I.affine(original["matrices"][1, 24])


def smooth(value: float) -> float:
    value = min(1., max(0., value))
    return value * value * (3 - 2 * value)


def staged_lifting(hub: list, contact: list, stock: np.ndarray, share: float, lean: int, rise: int, advance: int,
                   stage: tuple) -> tuple:
    """Wood's lift with the stone's two translations staged in sixteenths of the clip.

    The body follows author_program.lifting exactly (squat and lean on one smoothstep). The stone, which starts
    1.7 mm from the snout, first eases `stage[4]` u away from the worker over [0, stage[0]] sixteenths, rises
    by `rise` over [stage[2], stage[3]], and is drawn in to `advance` over [stage[0], stage[1]] once the head
    has lifted clear. Each leg is its own smoothstep; the stone never rotates. (0, 16, 0, 16, 0) is wood's path.
    """
    A.require(0 <= share <= 1 and len(stage) == 5 and 0 <= stage[0] < stage[1] <= 16 and
              0 <= stage[2] < stage[3] <= 16 and 0 <= stage[4] <= 256 and (stage[0] > 0 or stage[4] == 0),
              "STONE_PHASE_KEY")
    body_share = smooth(share)
    pose = AP.squatted(hub, 96 * (1 - body_share))
    angle = -np.deg2rad(95 * (1 - body_share) + lean * body_share)
    turn = np.array([[1., 0., 0.], [0., np.cos(angle), -np.sin(angle)], [0., np.sin(angle), np.cos(angle)]])
    matrix = np.eye(4)
    matrix[:3, :3] = turn
    pivot = pose[9][:3, 3]
    matrix[:3, 3] = pivot - turn @ pivot
    pose = [row.copy() if at < 9 else matrix @ row for at, row in enumerate(pose)]
    out = smooth((share * 16 - stage[0]) / (stage[1] - stage[0]))
    up = smooth((share * 16 - stage[2]) / (stage[3] - stage[2]))
    parcel = stock.copy()
    parcel[1, 3] += rise * up / 1024
    clear = stock[2, 3] - stage[4] * (smooth(share * 16 / stage[0]) if stage[0] else 1.) / 1024
    parcel[2, 3] = clear * (1 - out) - advance * out / 1024
    return AP.solve_arm_grips(pose, contact, parcel, stock), parcel


def author(inputs: tuple, lean: int, rise: int, advance: int, segments: int, stage: tuple = (0, 16, 0, 16, 0)) -> tuple:
    rows, body, _, _, topology, compact, _, _ = inputs
    parents, inverse, inverse_inverse = A.hierarchy(topology)
    original, stock = static_pose()
    contact = A.globals_at({"matrices": original["matrices"], "grounding": original["grounding"]}, 1, inverse_inverse)
    hub, _, _, _ = A.planted_carry(compact[0], rows[A.I.CASE_IDS[2]], topology)
    grounding = float(original["grounding"][1])
    A.require(2 <= segments <= 120 and 0 <= lean <= 45 and 256 <= rise <= 640 and 256 <= advance <= 768,
              "STONE_PROGRAM_CANDIDATE")
    authored = [staged_lifting(hub, contact, stock, at / segments, lean, rise, advance, stage)
                for at in range(segments + 1)]
    case, corrections = AP.source_case([row[0] for row in authored], [row[1] for row in authored],
                                       inverse, grounding, body, topology)
    case["matrices"][0] = original["matrices"][1]
    case["grounding"][0] = original["grounding"][1]
    return case, corrections


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--hub-lean", type=int, default=20)
    parser.add_argument("--hub-rise", type=int, default=448)
    parser.add_argument("--hub-advance", type=int, default=384)
    parser.add_argument("--segments", type=int, default=60)
    parser.add_argument("--stage", type=int, nargs=5, default=[0, 16, 0, 16, 0],
                        metavar=("PULL_START", "PULL_END", "RISE_START", "RISE_END", "CLEAR_U"))
    args = parser.parse_args()
    A.require(not args.out.exists(), "STONE_OUTPUT_EXISTS")
    inputs = A.I.current_inputs(args.palette, args.grip_palette)
    case, corrections = author(inputs, args.hub_lean, args.hub_rise, args.hub_advance, args.segments,
                               tuple(args.stage))
    args.out.mkdir(parents=True)
    AP.write_case(args.out / "poses.npz", case)
    clips = {}
    for name, clip in AP.phase_cases(case).items():
        AP.write_case(args.out / (name + ".npz"), clip)
        clips[name] = {"frames": clip["frames"], "loop_mode": 0, "source_samples_only_not_gameplay_rate": True,
                       "stock_role": "world_target" if name in ("approach", "recovery") else "actual_carried_parcel",
                       "sha256": hashlib.sha256((args.out / (name + ".npz")).read_bytes()).hexdigest()}
    (args.out / "candidate.json").write_text(json.dumps({
        "schema": 1, "adr": "1206", "production_qualified": False,
        "scope": "Finite four-phase stone source candidate; every interval remains unqualified until its separate proof.",
        "recipe": {"lean": args.hub_lean, "stock_rise_u": args.hub_rise, "stock_advance_u": args.hub_advance,
                   "segments": args.segments, "stage_sixteenths_and_clear_u": args.stage},
        "source_static_pose_sha256": hashlib.sha256((STATIC / "poses.npz").read_bytes()).hexdigest(),
        "stone_capture_sha256": G.STONE_SHA, "sole_corrections": corrections, "clips": clips,
        "producer_sha256": {str(Path(p).relative_to(A.I.ROOT)): hashlib.sha256(Path(p).read_bytes()).hexdigest()
                            for p in (__file__, AP.__file__, A.__file__, G.__file__)}}, indent=2) + "\n")
    print(json.dumps({"output": str(args.out), "frames": case["frames"], "production_qualified": False}))


if __name__ == "__main__":
    main()
