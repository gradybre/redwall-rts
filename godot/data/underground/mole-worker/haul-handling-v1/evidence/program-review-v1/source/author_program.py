#!/usr/bin/env python3
"""Author source-only approach/lift/recovery from the reviewed actual grip; no runtime timing or quantity mapping."""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path

import numpy as np

import author_handling as A

STATIC = A.I.HERE / "evidence/static-contact-review-v1/candidate"


def rotation_blend(first: np.ndarray, last: np.ndarray, share: float) -> np.ndarray:
    """Proper shortest rotation through Rodrigues; the existing rig scale remains unchanged."""
    delta = last @ np.linalg.inv(first)
    require_rotation = np.max(np.abs(delta.T @ delta - np.eye(3)))
    A.require(require_rotation < 1e-5 and abs(np.linalg.det(delta) - 1) < 1e-5,
              "HANDLING_RIG_ROTATION_SOURCE")
    cosine = max(-1., min(1., float((np.trace(delta) - 1) * .5)))
    angle = float(np.arccos(cosine))
    if angle < 1e-8:
        return first.copy()
    A.require(angle < np.pi - 1e-4, "HANDLING_AMBIGUOUS_HALF_TURN")
    axis = np.array([delta[2, 1] - delta[1, 2], delta[0, 2] - delta[2, 0], delta[1, 0] - delta[0, 1]])
    axis /= np.linalg.norm(axis)
    skew = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
    turn = np.eye(3) + np.sin(angle * share) * skew + (1 - np.cos(angle * share)) * skew @ skew
    return turn @ first


def global_blend(first: list, last: list, parents: list, share: float) -> list:
    a, b = A.locals_of(first, parents), A.locals_of(last, parents)
    result = []
    for at, parent in enumerate(parents):
        local = a[at].copy()
        local[:3, :3] = rotation_blend(a[at][:3, :3], b[at][:3, :3], share)
        local[:3, 3] = a[at][:3, 3] * (1 - share) + b[at][:3, 3] * share
        result.append(result[parent] @ local if parent >= 0 else local)
    return result


def solve_arm_grips(pose: list, contact: list, stock: np.ndarray, original_stock: np.ndarray) -> list:
    """Both source hand/stock relations are retained; original arm segments cannot stretch to reach them."""
    result = [row.copy() for row in pose]
    relative = stock @ np.linalg.inv(original_stock)
    for shoulder, elbow, wrist in ((13, 14, 15), (17, 18, 19)):
        target_hand = relative @ contact[wrist]
        start, middle, end = [pose[at][:3, 3] for at in (shoulder, elbow, wrist)]
        target = target_hand[:3, 3]
        bent = A.RIG.knee_target(start, middle, end, target)
        for bone, old_start, old_end, new_start, new_end in (
                (shoulder, start, middle, start, bent), (elbow, middle, end, bent, target)):
            result[bone][:3, :3] = A.RIG.rotation_between(old_end - old_start, new_end - new_start) @ pose[bone][:3, :3]
            result[bone][:3, 3] = new_start
        result[wrist] = target_hand
    return result


def held_hub(hub: list, contact: list, original_stock: np.ndarray, lean: int, rise: int, advance: int) -> tuple:
    """Keep the actual planted base while lifting the complete parcel away from body/face geometry."""
    A.require(0 <= lean <= 45 and 256 <= rise <= 640 and 256 <= advance <= 512, "HANDLING_LOADED_CANDIDATE")
    angle = -np.deg2rad(lean)
    turn = np.array([[1., 0., 0.], [0., np.cos(angle), -np.sin(angle)], [0., np.sin(angle), np.cos(angle)]])
    matrix = np.eye(4)
    matrix[:3, :3] = turn
    pivot = hub[9][:3, 3]
    matrix[:3, 3] = pivot - turn @ pivot
    pose = [row.copy() if at < 9 else matrix @ row for at, row in enumerate(hub)]
    stock = original_stock.copy()
    stock[1, 3] += rise / 1024
    stock[2, 3] = -advance / 1024
    return solve_arm_grips(pose, contact, stock, original_stock), stock


def squatted(hub: list, drop_u: float) -> list:
    """The same two-link solve as the reviewed static source, with a finite fractional authoring key."""
    A.require(0 <= drop_u <= 96, "HANDLING_SQUAT_KEY")
    moved = [row.copy() for row in hub]
    for row in moved:
        row[1, 3] -= drop_u / 1024
    for hip, knee, ankle, toe in ((1, 2, 3, 4), (5, 6, 7, 8)):
        start = moved[hip][:3, 3]
        target = hub[ankle][:3, 3]
        middle = A.RIG.knee_target(start, moved[knee][:3, 3], moved[ankle][:3, 3], target)
        for bone, old_start, old_end, final_start, final_end in (
                (hip, hub[hip][:3, 3], hub[knee][:3, 3], start, middle),
                (knee, hub[knee][:3, 3], hub[ankle][:3, 3], middle, target)):
            moved[bone][:3, :3] = A.RIG.rotation_between(old_end - old_start, final_end - final_start) @ hub[bone][:3, :3]
            moved[bone][:3, 3] = final_start
        moved[ankle], moved[toe] = hub[ankle].copy(), hub[toe].copy()
    return moved


def lifting(hub: list, contact: list, stock: np.ndarray, share: float, lean: int, rise: int, advance: int) -> tuple:
    A.require(0 <= share <= 1, "HANDLING_PHASE_KEY")
    smoothed = share * share * (3 - 2 * share)
    pose = squatted(hub, 96 * (1 - smoothed))
    angle = -np.deg2rad(95 * (1 - smoothed) + lean * smoothed)
    turn = np.array([[1., 0., 0.], [0., np.cos(angle), -np.sin(angle)], [0., np.sin(angle), np.cos(angle)]])
    matrix = np.eye(4)
    matrix[:3, :3] = turn
    pivot = pose[9][:3, 3]
    matrix[:3, 3] = pivot - turn @ pivot
    pose = [row.copy() if at < 9 else matrix @ row for at, row in enumerate(pose)]
    parcel = stock.copy()
    parcel[1, 3] += rise * smoothed / 1024
    parcel[2, 3] = stock[2, 3] * (1 - smoothed) - advance * smoothed / 1024
    return solve_arm_grips(pose, contact, parcel, stock), parcel


def diagnostic_at(case: dict, at: int, body: dict, wood: dict, topology: dict) -> dict:
    current = {**case, "frames": 1, "matrices": case["matrices"][at:at + 1],
               "grounding": case["grounding"][at:at + 1]}
    return A.assess(current, body, wood, topology)


def write_case(path: Path, case: dict) -> None:
    np.savez(path, matrices=case["matrices"], grounding=case["grounding"])


def phase_cases(lift: dict) -> dict:
    """World stock is a proof fixture during empty approach/recovery, not an attached cargo part."""
    approach = {**lift, "matrices": lift["matrices"][::-1].copy(), "grounding": lift["grounding"][::-1].copy()}
    approach["matrices"][:, 24] = lift["matrices"][0, 24]
    recovery = {**approach, "matrices": approach["matrices"][::-1].copy(), "grounding": approach["grounding"][::-1].copy()}
    place = {**lift, "matrices": lift["matrices"][::-1].copy(), "grounding": lift["grounding"][::-1].copy()}
    return {"approach": approach, "lift": lift, "place": place, "recovery": recovery}


def source_case(rows: list, stocks: list, inverse: list, grounding: float, body: dict, topology: dict) -> tuple:
    matrices, corrections = [], []
    for pose, stock in zip(rows, stocks):
        planted, correction = A.plant_soles(pose, stock, inverse, grounding, body, topology)
        matrices.append(np.concatenate((A.encoded(planted, inverse), A.packed(stock)[None, :])))
        corrections.append(correction)
    return {"frames": len(rows), "matrices": np.asarray(matrices, dtype=np.float32),
            "grounding": np.full(len(rows), grounding, dtype=np.float32),
            "source_loop_mode": 0, "source_duration_s": Fraction(len(rows) - 1, 30)}, corrections


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--hub-lean", type=int, default=20)
    parser.add_argument("--hub-rise", type=int, default=448)
    parser.add_argument("--hub-advance", type=int, default=384)
    parser.add_argument("--segments", type=int, default=0,
                        help="0 emits just the diagnostic hub; 2..120 emits the finite four-phase candidate")
    args = parser.parse_args()
    A.require(not args.out.exists(), "HANDLING_OUTPUT_EXISTS")
    rows, body, wood, _, topology, compact, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    parents, inverse, inverse_inverse = A.hierarchy(topology)
    original = np.load(STATIC / "poses.npz", allow_pickle=False)
    static = {"matrices": original["matrices"], "grounding": original["grounding"]}
    contact = A.globals_at(static, 1, inverse_inverse)
    stock = A.I.affine(original["matrices"][1, 24])
    hub, _, _, _ = A.planted_carry(compact[0], rows[A.I.CASE_IDS[2]], topology)
    lifted, held_stock = held_hub(hub, contact, stock, args.hub_lean, args.hub_rise, args.hub_advance)
    grounding = float(original["grounding"][1])
    A.require(args.segments == 0 or 2 <= args.segments <= 120, "HANDLING_FRAME_CAPACITY")
    if args.segments:
        authored = [lifting(hub, contact, stock, at / args.segments, args.hub_lean, args.hub_rise,
                            args.hub_advance) for at in range(args.segments + 1)]
        case, corrections = source_case([row[0] for row in authored], [row[1] for row in authored],
                                       inverse, grounding, body, topology)
        # The original accepted endpoint is copied exactly, not reconstructed under an approximate join.
        case["matrices"][0] = original["matrices"][1]
        case["grounding"][0] = original["grounding"][1]
    else:
        case, corrections = source_case([contact, lifted], [stock, held_stock], inverse, grounding, body, topology)
    args.out.mkdir(parents=True)
    write_case(args.out / "poses.npz", case)
    clips = {}
    if args.segments:
        for name, clip in phase_cases(case).items():
            write_case(args.out / (name + ".npz"), clip)
            clips[name] = {"frames": clip["frames"], "loop_mode": 0,
                           "source_samples_only_not_gameplay_rate": True,
                           "stock_role": "world_target" if name in ("approach", "recovery") else "actual_carried_parcel",
                           "sha256": hashlib.sha256((args.out / (name + ".npz")).read_bytes()).hexdigest()}
    (args.out / "candidate.json").write_text(json.dumps({"schema": 1, "production_qualified": False,
        "scope": "Finite four-phase source candidate; every interval remains unqualified until its separate proof." if args.segments else
                 "Loaded hub pose only; no temporal segment has been emitted or qualified yet.",
        "recipe": {"lean": args.hub_lean, "stock_rise_u": args.hub_rise, "stock_advance_u": args.hub_advance},
        "source_static_pose_sha256": hashlib.sha256((STATIC / "poses.npz").read_bytes()).hexdigest(),
        "source_program_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "sole_corrections": corrections, "clips": clips,
        "diagnostics": [diagnostic_at(case, at, body, wood, topology) for at in (0, case["frames"] // 2, case["frames"] - 1)],
        "missing": ["continuous lift/approach/return", "loaded gait/turn/joins", "native proof", "quantity mapping", "runtime admission"]}, indent=2) + "\n")
    (args.out / "executed-author_program.py").write_bytes(Path(__file__).read_bytes())
    print(json.dumps({"output": str(args.out), "frames": case["frames"], "production_qualified": False}))


if __name__ == "__main__":
    main()
