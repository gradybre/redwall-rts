#!/usr/bin/env python3
"""Author connected-rig handling candidates from exact existing inputs; no runtime source publication."""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np

import inspect_source as I

SPEC = importlib.util.spec_from_file_location("handling_rig_geometry", I.PROOF / "author_stair_motion.py")
RIG = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RIG)
P = I.SOURCE.P
require = I.require


def hierarchy(topology: dict) -> tuple:
    rows = topology["rig_binding"]["bones"]
    require(len(rows) == 24 and all(row["bone"] == row["bind"] == at and
            -1 <= row["parent"] < at for at, row in enumerate(rows)), "HANDLING_HIERARCHY")
    inverse = [I.affine(np.asarray(row["inverse_bind"], dtype=np.float64)) for row in rows]
    return [row["parent"] for row in rows], inverse, [np.linalg.inv(row) for row in inverse]


def globals_at(case: dict, frame: int, inverse_inverse: list) -> list:
    return [I.affine(case["matrices"][frame, at]) @ inverse_inverse[at] for at in range(24)]


def locals_of(globals_: list, parents: list) -> list:
    return [np.linalg.inv(globals_[parent]) @ value if parent >= 0 else value.copy()
            for parent, value in zip(parents, globals_)]


def encoded(globals_: list, inverse: list) -> np.ndarray:
    result = np.empty((24, 12), dtype=np.float32)
    for at, (current, binding) in enumerate(zip(globals_, inverse)):
        matrix = current @ binding
        require(np.all(np.isfinite(matrix)) and np.max(np.abs(matrix)) <= 1024, "HANDLING_POSE_CAPACITY")
        result[at, :9] = matrix[:3, :3].T.reshape(-1)
        result[at, 9:] = matrix[:3, 3]
    return result


def packed(matrix: np.ndarray) -> np.ndarray:
    return np.concatenate((matrix[:3, :3].T.reshape(-1), matrix[:3, 3])).astype(np.float32)


def planted_carry(ready: dict, carry: dict, topology: dict) -> tuple:
    """Use current ready hips/feet, the actual carry upper rotations and unchanged local joint lengths."""
    parents, inverse, inverse_inverse = hierarchy(topology)
    base = globals_at(ready, 8, inverse_inverse)
    original = globals_at(carry, 0, inverse_inverse)
    base_local, source_local = locals_of(base, parents), locals_of(original, parents)
    moved = [row.copy() for row in base]
    for at in range(9, 24):
        local = source_local[at].copy()
        local[:3, 3] = base_local[at][:3, 3]
        moved[at] = moved[parents[at]] @ local
    # The imported log span is read from its actual palette rather than reauthoring its scale.
    native_log = I.affine(carry["matrices"][0, 24])
    original_span = np.linalg.norm(original[19][:3, 3] - original[15][:3, 3])
    overhang = float(np.linalg.norm(native_log[:3, 1]) - original_span)
    require(0 < overhang < .25, "HANDLING_LOG_OVERHANG")
    return moved, inverse, log_between(moved, overhang), overhang


def log_between(globals_: list, overhang: float) -> np.ndarray:
    """The existing demo's complete finite cylinder fit, without altering its vertex geometry."""
    left, right = globals_[15][:3, 3], globals_[19][:3, 3]
    across = right - left
    span = float(np.linalg.norm(across))
    require(.001 < span < 2 and 0 < overhang < .25, "HANDLING_LOG_FIT")
    axis = across / span
    side = np.cross([0., 1., 0.], axis)
    require(float(np.linalg.norm(side)) > .01, "HANDLING_LOG_VERTICAL")
    side /= np.linalg.norm(side)
    matrix = np.eye(4)
    matrix[:3, :3] = np.stack((np.cross(axis, side), axis * (span + overhang), side), axis=1)
    matrix[:3, 3] = (left + right) * .5
    return matrix


def contact_pose(hub: list, hub_log: np.ndarray, inverse: list, grounding: float,
                 lean_degrees: int, ahead_u: int, log: dict) -> tuple:
    """Lean actual torso, solve both fixed-length arms, and keep the full log resting on the source floor."""
    require(30 <= lean_degrees <= 100 and 256 <= ahead_u <= 896, "HANDLING_CONTACT_CANDIDATE")
    angle = -np.deg2rad(lean_degrees)
    turn = np.array([[1., 0., 0.], [0., np.cos(angle), -np.sin(angle)],
                     [0., np.sin(angle), np.cos(angle)]])
    rotation = np.eye(4)
    rotation[:3, :3] = turn
    pivot = hub[9][:3, 3]
    rotation[:3, 3] = pivot - turn @ pivot
    moved = [value.copy() if at < 9 else rotation @ value for at, value in enumerate(hub)]
    # Preserve full source length/radius. Choose an axis-aligned stock pose, then derive its actual bottom.
    stock = np.eye(4)
    stock[:3, :3] = np.stack(([0., 1., 0.], [np.linalg.norm(hub_log[:3, 1]), 0., 0.], [0., 0., -1.]), axis=1)
    vertices = log["geometry"][0]["points"].astype(np.float64)
    source = vertices @ stock[:3, :3].T
    stock[:3, 3] = [0., -float(source[:, 1].min()) - grounding, -ahead_u / 1024]
    relative = stock @ np.linalg.inv(hub_log)
    max_error = 0.
    for shoulder, elbow, wrist in ((13, 14, 15), (17, 18, 19)):
        target_hand = relative @ hub[wrist]
        start, old_middle, old_end = [moved[index][:3, 3] for index in (shoulder, elbow, wrist)]
        target = target_hand[:3, 3]
        middle = RIG.knee_target(start, old_middle, old_end, target)
        for bone, previous_start, previous_end, final_start, final_end in (
                (shoulder, start, old_middle, start, middle), (elbow, old_middle, old_end, middle, target)):
            final = moved[bone].copy()
            final[:3, :3] = RIG.rotation_between(previous_end - previous_start, final_end - final_start) @ final[:3, :3]
            final[:3, 3] = final_start
            moved[bone] = final
        moved[wrist] = target_hand
        max_error = max(max_error, abs(np.linalg.norm(middle - start) - np.linalg.norm(old_middle - start)),
                        abs(np.linalg.norm(target - middle) - np.linalg.norm(old_end - old_middle)))
    require(max_error < 1e-10, "HANDLING_LINK_LENGTH_DRIFT")
    return moved, stock, {"maximum_arm_link_error_m": max_error, "lean_degrees": lean_degrees,
                          "station_R_minus_S_u": [0, 0, ahead_u],
                          "stock_mesh_bounds_u": I.box((vertices @ stock[:3, :3].T + stock[:3, 3] + [0, grounding, 0]) * 1024)}


def one_case(globals_: list, cargo: np.ndarray, inverse: list, grounding: float, parts: list) -> dict:
    matrix = np.concatenate((encoded(globals_, inverse), packed(cargo)[None, :]))
    return {"frames": 1, "matrices": matrix[None, :], "grounding": np.asarray([grounding], dtype=np.float32),
            "geometry": parts, "source_loop_mode": 0, "source_duration_s": Fraction(1, 30)}


def assess(case: dict, body: dict, log: dict, topology: dict) -> dict:
    body_points = I.points_at(case, body, 0)
    cargo = I.points_at(case, log, 0, 24)
    ids, weights = body["geometry"][0]["ids"], body["geometry"][0]["weights"]
    rows = []
    for hand in (15, 19):
        belongs = np.any((ids == hand) & (weights >= np.max(weights, axis=1)[:, None]), axis=1)
        vertices = np.flatnonzero(belongs)
        points = body_points[vertices]
        distances = np.sum((points[:, None, :] - cargo[None, :, :]) ** 2, axis=2)
        at = np.unravel_index(np.argmin(distances), distances.shape)
        rows.append({"hand_bone": hand, "body_vertex": int(vertices[at[0]]), "wood_vertex": int(at[1]),
                     "body_point_u": points[at[0]].tolist(), "wood_point_u": cargo[at[1]].tolist(),
                     "sampled_vertex_distance_u": float(np.sqrt(distances[at]))})
    return {"sampled_body_u": I.box(body_points), "sampled_wood_u": I.box(cargo), "nearest_vertex_diagnostics": rows,
            "scope": "Nearest vertices do not establish triangle contact, separation, support or native residual."}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--lean", type=int, default=85)
    parser.add_argument("--ahead", type=int, default=512)
    args = parser.parse_args()
    require(not args.out.exists() and not args.out.is_symlink(), "HANDLING_OUTPUT_EXISTS")
    rows, body, log, _, topology, compact, _, _ = I.current_inputs(args.palette, args.grip_palette)
    hub, inverse, hub_log, overhang = planted_carry(compact[0], rows[I.CASE_IDS[2]], topology)
    grounding = float(compact[0]["grounding"][8])
    pose, stock, recipe = contact_pose(hub, hub_log, inverse, grounding, args.lean, args.ahead, log)
    cases = [one_case(hub, hub_log, inverse, grounding, [body, log]),
             one_case(pose, stock, inverse, grounding, [body, log])]
    report = {"schema": 1, "status": "UNQUALIFIED_SOURCE_CANDIDATE", "production_qualified": False,
              "source_palette_sha256": I.PALETTE_SHA, "body_mesh_sha256": I.BODY, "wood_mesh_sha256": I.LOG,
              "actual_log_overhang_m": overhang, "recipe": recipe,
              "poses": [assess(case, body, log, topology) for case in cases],
              "producer_sources": {str(Path(p).relative_to(I.ROOT)): CONTENT_HASH(p) for p in
                                   (__file__, I.__file__, RIG.__file__)},
              "missing": ["complete entry/lift/recovery and interruption program", "all triangle contact and separation",
                          "continuous/native/world basis proof", "quantity/presentation mapping", "runtime station seam and joint admission"]}
    args.out.mkdir(parents=True)
    np.savez(args.out / "poses.npz", matrices=np.concatenate([case["matrices"] for case in cases]),
             grounding=np.concatenate([case["grounding"] for case in cases]))
    (args.out / "candidate.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"candidate": str(args.out), "recipe": recipe, "production_qualified": False}))


def CONTENT_HASH(path: str) -> str:
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


if __name__ == "__main__":
    main()
