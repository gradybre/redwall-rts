#!/usr/bin/env python3
"""Source-only stepped-foot candidates from the actual compact mole rig; no travel/support/pace permission."""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("stair_rig_assessment", HERE / "assess_stair_rig.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
A, C, P, S, W = M.A, M.C, M.P, M.S, M.W
PHASE_FRAMES = 30
FRAME_COUNT = 3 * PHASE_FRAMES + 1
ROOT_ADVANCES = (0, 150, 400, 512)
RIGHT_ADVANCES = (0, 343, 343, 512)
LEFT_ADVANCES = (0, 0, 512, 512)


def smooth(value):
    """Authoring interpolation only; the finite integer root table owns every emitted sample."""
    return value * value * (3 - 2 * value)


def rotation_between(first, last):
    """Proper rotation aligns real limb directions without scaling a source bone."""
    a, b = np.asarray(first, dtype=float), np.asarray(last, dtype=float)
    P.require(a.shape == b.shape == (3,) and np.all(np.isfinite(a)) and np.all(np.isfinite(b)) and
              np.linalg.norm(a) > 1e-9 and np.linalg.norm(b) > 1e-9, "STEP_ROTATION_ARGUMENT")
    a, b = a / np.linalg.norm(a), b / np.linalg.norm(b)
    cross, dot = np.cross(a, b), float(np.dot(a, b))
    if dot < -1 + 1e-10:
        axis = np.zeros(3)
        axis[int(np.argmin(np.abs(a)))] = 1
        axis = np.cross(a, axis)
        axis /= np.linalg.norm(axis)
        return 2 * np.outer(axis, axis) - np.eye(3)
    if dot > 1 - 1e-14:
        return np.eye(3)
    skew = np.array([[0, -cross[2], cross[1]], [cross[2], 0, -cross[0]], [-cross[1], cross[0], 0]])
    return np.eye(3) + skew + skew @ skew / (1 + dot)


def knee_target(hip, old_knee, old_ankle, target):
    """Solve the original two fixed-length segments, preserving the actual knee bend side; unreachable targets refuse."""
    upper, lower = old_knee - hip, old_ankle - old_knee
    first, last = float(np.linalg.norm(upper)), float(np.linalg.norm(lower))
    vector = target - hip
    distance = float(np.linalg.norm(vector))
    P.require(all(math.isfinite(x) for x in (first, last, distance)) and
              abs(first - last) + 1e-7 < distance < first + last - 1e-7, "STEP_LEG_REACH")
    direction = vector / distance
    bend = upper - direction * np.dot(upper, direction)
    P.require(float(np.linalg.norm(bend)) > 1e-8, "STEP_KNEE_PLANE")
    bend /= np.linalg.norm(bend)
    along = (first * first - last * last + distance * distance) / (2 * distance)
    height = math.sqrt(max(0, first * first - along * along))
    return hip + along * direction + height * bend


def swing(first, last, share):
    """Lift before traversing the riser, move above both support levels, then settle; never stretch through a wall."""
    value = np.asarray(first, dtype=float).copy()
    top = max(float(first[1]), float(last[1])) + 64
    if share < .25:
        value[1] += (top - value[1]) * smooth(share * 4)
    elif share < .75:
        value = (1 - smooth((share - .25) * 2)) * np.asarray(first) + smooth((share - .25) * 2) * np.asarray(last)
        value[1] = top
    else:
        value = np.asarray(last, dtype=float).copy()
        value[1] = top + (value[1] - top) * smooth((share - .75) * 4)
    return value


def tracks(frame, rise, lead_advance=150, lead_lift=0):
    """Finite diagnostic three-plant program; its speed is not a gameplay pace or route permission."""
    P.require(type(frame) is int and 0 <= frame < FRAME_COUNT and rise in (-256, -128, 128, 256) and
              type(lead_advance) is int and 0 <= lead_advance <= 200 and
              type(lead_lift) is int and 0 <= lead_lift <= 200, "STEP_PROGRAM_ARGUMENT")
    phase = min(2, frame // PHASE_FRAMES)
    share = (frame - phase * PHASE_FRAMES) / PHASE_FRAMES
    blend = smooth(share)
    heights = (0, lead_lift if rise > 0 else -lead_lift, rise, rise)
    advances = (0, lead_advance, 400, 512)
    root = np.array([0, round((1 - blend) * heights[phase] + blend * heights[phase + 1]),
                     -round((1 - blend) * advances[phase] + blend * advances[phase + 1])], dtype=np.int32)
    left_heights, right_heights = (0, 0, rise, rise), (0, rise, rise, rise)
    feet = []
    for index, (advances, levels) in enumerate(((LEFT_ADVANCES, left_heights), (RIGHT_ADVANCES, right_heights))):
        first = np.array([0, levels[phase], -advances[phase]], dtype=float)
        last = np.array([0, levels[phase + 1], -advances[phase + 1]], dtype=float)
        feet.append(swing(first, last, share) if not np.array_equal(first, last) else first)
    planted_mask = (1 if phase in (0, 2) else 2) if 0 < share < 1 else 3
    return root, feet, planted_mask


def source_case(ready, rig, rise, lead_advance=150, lead_lift=0):
    """Move the exact real joints and whole body/tool root; both source lengths and end poses are preserved."""
    parents, inverse, inverse_inverse = A.hierarchy(rig)
    actual, _, _ = A.joints(ready, 8, parents, inverse_inverse)
    result = dict(ready, id="mole_worker.stair_diagnostic." + str(rise), frames=FRAME_COUNT,
                  source_loop_mode=0, source_duration_s=Fraction(FRAME_COUNT - 1, 30),
                  duration_q16=(FRAME_COUNT - 1) * 65536,
                  matrices=np.empty((FRAME_COUNT, 25, 12), dtype=np.float32),
                  grounding=np.full(FRAME_COUNT, ready["grounding"][8], dtype=np.float32))
    root_rows, feet_rows, masks, length_error = [], [], [], 0.
    for frame in range(FRAME_COUNT):
        root, feet, planted_mask = tracks(frame, rise, lead_advance, lead_lift)
        moved = [value.copy() for value in actual]
        for side, (_, hip, knee, ankle, toe) in enumerate(M.LEGS):
            target = actual[ankle][:3, 3] + (feet[side] - root) / 1024
            middle = knee_target(actual[hip][:3, 3], actual[knee][:3, 3], actual[ankle][:3, 3], target)
            for bone, start, end, old_start, old_end in (
                    (hip, actual[hip][:3, 3], middle, actual[hip][:3, 3], actual[knee][:3, 3]),
                    (knee, middle, target, actual[knee][:3, 3], actual[ankle][:3, 3])):
                moved[bone][:3, :3] = rotation_between(old_end - old_start, end - start) @ actual[bone][:3, :3]
                moved[bone][:3, 3] = start
                length_error = max(length_error, abs(float(np.linalg.norm(end-start) - np.linalg.norm(old_end-old_start))))
            moved[ankle][:3, 3] = target
            moved[toe][:3, 3] = target + actual[toe][:3, 3] - actual[ankle][:3, 3]
        result["matrices"][frame] = ready["matrices"][8]
        for at in range(1, 9):
            transform = moved[at] @ inverse[at]
            result["matrices"][frame, at, :9] = transform[:3, :3].T.reshape(-1)
            result["matrices"][frame, at, 9:] = transform[:3, 3]
        result["matrices"][frame, :, 9:] += root / 1024
        root_rows.append([int(x) for x in root])
        feet_rows.append([value.tolist() for value in feet])
        masks.append(planted_mask)
    # An exact source-identical boundary is part of the program, not a nearly
    # equal IK endpoint or an immediate visible switch.
    for frame in (0, FRAME_COUNT - 1):
        result["matrices"][frame] = ready["matrices"][8]
        result["matrices"][frame, :, 9:] += np.asarray(root_rows[frame]) / 1024
    P.require(length_error < 1e-10 and np.all(np.isfinite(result["matrices"])), "STEP_SOURCE_LENGTH_DRIFT")
    result["stair_recipe"] = {"rise_u": rise, "run_u": 512, "edge_z_u": -169, "phase_frames": PHASE_FRAMES,
        "lead_root_advance_u": lead_advance, "lead_root_lift_u": lead_lift,
        "root_u": root_rows, "ankle_translation_u": feet_rows, "planted_mask": masks,
        "max_link_length_error_m": length_error, "root_equation": "source-only palette includes finite root table; no actual Transforms owner is moved",
        "knee_rule": "proper rotations; original two segment lengths and original bend-side projection",
        "all_other_source_joints": "compact idle frame8; original geometry, hand/tool fit and materials preserved"}
    return result


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    parser.add_argument("--lead-root-advance", type=int, default=150)
    parser.add_argument("--lead-root-lift", type=int, default=0)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "STEP_OUTPUT_EXISTS")
    paths = (__file__, M.__file__, M.D.__file__, A.__file__, C.__file__, C.H.__file__, W.__file__, W.H.__file__, S.__file__,
             P.__file__, P.content.__file__, P.envelope.__file__)
    producers = {str(Path(path).relative_to(P.ROOT)): P.content.file_hash(Path(path)) for path in paths}
    cases, parts, rig, _, roots, sources, historical = M.read_actual_source()
    command = W.read_record(HERE / "analysis-carry-arm-v7/invocation.json")["command"]
    proof = P.content.read_json(Path(command[command.index("--proof") + 1]), command[command.index("--proof-sha256") + 1])
    candidates, attempts = [], []
    for rise in (128, 256, -128, -256):
        try:
            result = source_case(cases[0], rig, rise, args.lead_root_advance, args.lead_root_lift)
            result["geometry"] = parts
            candidates.append(result)
            attempts.append({"status": "SOURCE_CANDIDATE_ONLY", **result["stair_recipe"]})
        except ValueError as error:
            attempts.append({"rise_u": rise, "status": "REFUSED", "error": str(error)})
    report = {"schema": 1, "compact_source_sha256": M.COMPACT_SHA, "attempts": attempts,
        "verified_source_files": sources, "historical_source_snapshot": historical, "producer_sources": producers,
        "remaining": ["CONTINUOUS_JOINT_BODY_TOOL_TERRAIN_CLEARANCE", "REAL_PHASE_FOOT_SUPPORT", "NATIVE_QUALITY", "ACTUAL_ROOT_AND_PHASE_OWNER",
                      "WHOLE_ENTRY_SHAPE_AND_COST_RECONCILIATION", "RENDERER_ROOT_CONTRACT"], "production_qualified": False}
    plan = {"revision": 100, "world_root_bounds_u": roots, "clips": [case["id"] for case in candidates]}
    raw_report, raw_plan = (json.dumps(report, indent=2)+"\n").encode(), (json.dumps(plan, indent=2)+"\n").encode()
    P.require(all(P.content.file_hash(P.ROOT / name) == digest for name, digest in producers.items()), "STEP_SOURCE_DRIFT")
    args.out.mkdir(parents=True)
    (args.out/"candidate.json").write_bytes(raw_report)
    (args.out/"plan.json").write_bytes(raw_plan)
    if candidates:
        image, budget = P.content.encode(candidates, plan, proof, M.COMPACT_SHA, hashlib.sha256(raw_report).hexdigest(), hashlib.sha256(raw_plan).hexdigest())
        (args.out/"mole-worker.ugactor").write_bytes(image)
        (args.out/"compilation.json").write_text(json.dumps({"content_sha256": hashlib.sha256(image).hexdigest(),
            "content_bytes": len(image), "presentation_budget": budget, "production_qualified": False}, indent=2)+"\n")
    print(json.dumps({"attempts": [{key: row[key] for key in ("rise_u", "status", "error") if key in row} for row in attempts],
                      "production_qualified": False}))


if __name__ == "__main__":
    main()
