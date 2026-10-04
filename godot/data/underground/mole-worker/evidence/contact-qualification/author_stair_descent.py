#!/usr/bin/env python3
"""Independent forward-facing descent source candidate; never reverse ascent or authorize a stair."""
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
SPEC = importlib.util.spec_from_file_location("accepted_ascent_author", HERE / "author_stair_motion.py")
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)
M, P = A.M, A.P


def tracks(frame, rise, advance=220, drop=128, lead_foot=400):
    """Independent finite descent phases, with one complete planted foot retained throughout."""
    P.require(type(frame) is int and 0 <= frame < A.FRAME_COUNT and rise in (-128, -256) and
              type(advance) is int and 128 <= advance <= 256 and type(drop) is int and 64 <= drop <= 192 and
              type(lead_foot) is int and 347 <= lead_foot <= 448, "DESCENT_TRACK_ARGUMENT")
    phase = min(2, frame // A.PHASE_FRAMES)
    share = (frame - phase*A.PHASE_FRAMES) / A.PHASE_FRAMES
    blend = A.smooth(share)
    # Hold the pelvis during the first quarter of the trailing-foot lift;
    # advancing before that actual foot can move would overextend its leg.
    # This is source authoring: the emitted integer rows still own playback.
    horizontal_blend = A.smooth(max(0., (share-.25)/.75)) if phase == 1 else blend
    heights, advances = (0, -drop, rise, rise), (0, advance, 400, 512)
    root = np.array([0, round((1-blend)*heights[phase]+blend*heights[phase+1]),
                     -round((1-horizontal_blend)*advances[phase]+horizontal_blend*advances[phase+1])], dtype=np.int32)
    left_s, right_s = (0, 0, 512, 512), (0, lead_foot, lead_foot, 512)
    left_y, right_y = (0, 0, rise, rise), (0, rise, rise, rise)
    feet = []
    for stations, levels in ((left_s, left_y), (right_s, right_y)):
        first = np.array([0, levels[phase], -stations[phase]], dtype=float)
        last = np.array([0, levels[phase+1], -stations[phase+1]], dtype=float)
        feet.append(A.swing(first, last, share) if not np.array_equal(first, last) else first)
    plant = (1 if phase in (0, 2) else 2) if 0 < share < 1 else 3
    return root, feet, plant


def bend_strength(frame, magnitude):
    """Smooth finite guide, exactly zero at both unchanged ready endpoints; no abrupt knee flip."""
    P.require(type(frame) is int and 0 <= frame < A.FRAME_COUNT and
              type(magnitude) in (int, float) and math.isfinite(magnitude) and 0 <= magnitude <= 2,
              "DESCENT_GUIDE_ARGUMENT")
    phase = frame / (A.FRAME_COUNT-1)
    return magnitude * 16 * phase * phase * (1-phase) * (1-phase)


def foot_angles(frame, degrees):
    """Explicit toe-first lowering and later flat recovery; actual full-foot support is still proved separately."""
    P.require(type(frame) is int and 0 <= frame < A.FRAME_COUNT and type(degrees) is int and 0 <= degrees <= 40,
              "DESCENT_FOOT_ANGLE")
    phase = min(2, frame//A.PHASE_FRAMES)
    share = (frame-phase*A.PHASE_FRAMES)/A.PHASE_FRAMES
    amount = -degrees*math.pi/180
    left, right = ((0., amount*A.smooth(share)) if phase == 0 else
                   (amount*A.smooth(share), amount) if phase == 1 else
                   (amount*(1-A.smooth(share)), amount*(1-A.smooth(share))))
    return left, right


def rotate_foot(moved, actual, ankle, toe, target, angle):
    """Rotate both actual ankle/toe frames together around the ankle; preserve the original toe link exactly."""
    P.require(math.isfinite(angle) and -math.pi/4 <= angle <= 0, "DESCENT_FOOT_ROTATION")
    cosine, sine = math.cos(angle), math.sin(angle)
    rotation = np.array([[1., 0., 0.], [0., cosine, -sine], [0., sine, cosine]])
    moved[ankle][:3, :3] = rotation @ actual[ankle][:3, :3]
    moved[ankle][:3, 3] = target
    moved[toe][:3, :3] = rotation @ actual[toe][:3, :3]
    moved[toe][:3, 3] = target + rotation @ (actual[toe][:3, 3]-actual[ankle][:3, 3])


def guided_knee(hip, old_knee, old_ankle, target, strength, side=0):
    """Transport the actual bend plane continuously, then apply an explicit bounded source twist.

    A projected mixed pole can cross zero and flip abruptly while the input
    pole varies smoothly. Transporting the original bend plane by the proper
    direction rotation preserves its side; no source bone length changes.
    """
    upper = old_knee-hip
    first, last = float(np.linalg.norm(upper)), float(np.linalg.norm(old_ankle-old_knee))
    vector = target-hip
    distance = float(np.linalg.norm(vector))
    P.require(side in (0, 1) and all(math.isfinite(value) for value in (first, last, distance, strength)) and 0 <= strength <= 2 and
              abs(first-last)+1e-7 < distance < first+last-1e-7, "DESCENT_LEG_REACH")
    direction = vector/distance
    old_direction = (old_ankle-hip)/np.linalg.norm(old_ankle-hip)
    original_bend = upper-old_direction*np.dot(upper, old_direction)
    transported = A.rotation_between(old_direction, direction) @ original_bend
    angle = strength * (math.pi/4) * (-1 if side == 0 else 1)
    bend = transported*math.cos(angle) + np.cross(direction, transported)*math.sin(angle)
    bend -= direction*np.dot(bend, direction)
    P.require(float(np.linalg.norm(bend)) > 1e-8, "DESCENT_KNEE_PLANE")
    bend /= np.linalg.norm(bend)
    along = (first*first-last*last+distance*distance)/(2*distance)
    return hip+along*direction+math.sqrt(max(0, first*first-along*along))*bend


def frame_palette(ready, actual, inverse, root, feet, strength, angles=(0., 0.)):
    moved = [value.copy() for value in actual]
    length_error = 0.
    for side, (_, hip, knee, ankle, toe) in enumerate(M.LEGS):
        target = actual[ankle][:3, 3]+(feet[side]-root)/1024
        middle = guided_knee(actual[hip][:3, 3], actual[knee][:3, 3], actual[ankle][:3, 3], target, strength, side)
        for bone, start, end, old_start, old_end in (
                (hip, actual[hip][:3, 3], middle, actual[hip][:3, 3], actual[knee][:3, 3]),
                (knee, middle, target, actual[knee][:3, 3], actual[ankle][:3, 3])):
            moved[bone][:3, :3] = A.rotation_between(old_end-old_start, end-start) @ actual[bone][:3, :3]
            moved[bone][:3, 3] = start
            length_error = max(length_error, abs(float(np.linalg.norm(end-start)-np.linalg.norm(old_end-old_start))))
        rotate_foot(moved, actual, ankle, toe, target, angles[side])
    palette = ready["matrices"][8].copy()
    for at in range(1, 9):
        transform = moved[at] @ inverse[at]
        palette[at, :9], palette[at, 9:] = transform[:3, :3].T.reshape(-1), transform[:3, 3]
    P.require(length_error < 1e-10 and np.all(np.isfinite(palette)), "DESCENT_LINK_DRIFT")
    return palette, length_error


def solve_frame(ready, actual, inverse, root, feet, part, foot_vertices, plant, strength, angles=(0., 0.)):
    corrected = [value.copy() for value in feet]
    for iteration in range(A.SOLE_ITERATIONS):
        palette, error = frame_palette(ready, actual, inverse, root, corrected, strength, angles)
        positions = A.source_positions(part, palette, ready["grounding"][8])+root
        anchors = [int(vertices[np.argmin(positions[vertices, 1])]) for vertices in foot_vertices]
        residual = [float(feet[side][1])+(float(A.SOLE_SOURCE_LIFT_U) if plant & (1 << side) else 0.)-
                    float(positions[anchors[side], 1]) for side in (0, 1)]
        if max(abs(value) for value in residual) <= float(A.SOLE_SOLVE_TOLERANCE_U):
            return palette, error, [float(corrected[side][1]-feet[side][1]) for side in (0, 1)], iteration+1
        for side in (0, 1):
            corrected[side][1] += residual[side]
            P.require(abs(corrected[side][1]-feet[side][1]) < 64, "DESCENT_SOLE_CAPACITY")
    raise ValueError("DESCENT_SOLE_CONVERGENCE")


def source_case(ready, rig, topology, rise, advance, drop, lead_foot, guide, toe_degrees):
    parents, inverse, inverse_inverse = A.A.hierarchy(rig)
    actual, _, _ = A.A.joints(ready, 8, parents, inverse_inverse)
    part = ready["geometry"][0]
    foot_vertices = [np.unique(topology[0][0][M.anatomical_foot_triangles(part, topology[0][0], (ankle, toe))])
                     for _, _, _, ankle, toe in M.LEGS]
    case = dict(ready, id="mole_worker.descent_diagnostic."+str(rise), frames=A.FRAME_COUNT, source_loop_mode=0,
                source_duration_s=Fraction(A.FRAME_COUNT-1, 30), duration_q16=(A.FRAME_COUNT-1)*65536,
                matrices=np.empty((A.FRAME_COUNT, 25, 12), dtype=np.float32),
                grounding=np.full(A.FRAME_COUNT, ready["grounding"][8], dtype=np.float32))
    roots, feet_rows, masks, corrections, iterations, guides, error_max = [], [], [], [], [], [], 0.
    for frame in range(A.FRAME_COUNT):
        root, feet, plant = tracks(frame, rise, advance, drop, lead_foot)
        strength = bend_strength(frame, guide)
        try:
            palette, error, correction, count = solve_frame(ready, actual, inverse, root, feet, part, foot_vertices, plant,
                                                           strength, foot_angles(frame, toe_degrees))
        except ValueError as failure:
            raise ValueError(str(failure)+"_FRAME_"+str(frame)) from failure
        case["matrices"][frame] = palette
        roots.append(root.tolist())
        feet_rows.append([value.tolist() for value in feet])
        masks.append(plant)
        corrections.append(correction)
        iterations.append(count)
        guides.append(strength)
        error_max = max(error_max, error)
    case["matrices"][0] = case["matrices"][-1] = ready["matrices"][8]
    case["stair_recipe"] = {"rise_u": rise, "run_u": 512, "edge_z_u": -169, "phase_frames": A.PHASE_FRAMES,
        "root_contract": A.ROOT_CONTRACT, "root_u": roots, "ankle_translation_u": feet_rows, "planted_mask": masks,
        "guide_strength": guides, "guide_magnitude": guide, "root_advance_u": advance, "root_drop_u": drop,
        "leading_foot_advance_u": lead_foot, "foot_vertex_counts": [len(value) for value in foot_vertices],
        "sole_ankle_correction_u": corrections, "sole_solver_iterations": iterations,
        "max_link_length_error_m": error_max,
        "source_method": "independent forward-facing descent; actual unchanged bone lengths, proper transport of the source knee plane with an explicit smooth side-dependent twist, full anatomical foot solve; no reversed anatomy, modified geometry, or gameplay movement"}
    case["stair_recipe"]["root_horizontal_lift_hold"] = "phase1 holds the first quarter while the trailing foot lifts, then smooth advance; explicit integer root rows own playback"
    case["stair_recipe"]["toe_first_degrees"] = toe_degrees
    case["stair_recipe"]["foot_rotation_rule"] = "actual ankle/toe frames rotate together, with unchanged link length, before whole-foot minimum solve; every body primitive and whole-foot projection stays in the independent proof"
    return case


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    parser.add_argument("--advance", type=int, default=220)
    parser.add_argument("--drop", type=int, default=128)
    parser.add_argument("--leading-foot", type=int, default=400)
    parser.add_argument("--guide", type=float, default=1.)
    parser.add_argument("--toe-degrees", type=int, default=0)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "DESCENT_OUTPUT_EXISTS")
    paths = (__file__, A.__file__, M.__file__, M.D.__file__, A.A.__file__, A.C.__file__, A.C.H.__file__, A.W.__file__,
             A.W.H.__file__, A.S.__file__, P.__file__, P.content.__file__, P.envelope.__file__)
    pins = {str(Path(path).relative_to(P.ROOT)): P.content.file_hash(Path(path)) for path in paths}
    cases, parts, rig, topology, roots, sources, historical = M.read_actual_source()
    cases[0]["geometry"] = parts
    command = A.W.read_record(HERE/"analysis-carry-arm-v7/invocation.json")["command"]
    proof = P.content.read_json(Path(command[command.index("--proof")+1]), command[command.index("--proof-sha256")+1])
    candidates, attempts = [], []
    for rise in (-128, -256):
        try:
            case = source_case(cases[0], rig, topology, rise, args.advance, args.drop, args.leading_foot, args.guide, args.toe_degrees)
            case["geometry"] = parts
            candidates.append(case)
            attempts.append({"status": "SOURCE_CANDIDATE_ONLY", **case["stair_recipe"]})
        except ValueError as error:
            attempts.append({"rise_u": rise, "status": "REFUSED", "error": str(error)})
    report = {"schema": 1, "compact_source_sha256": M.COMPACT_SHA, "attempts": attempts,
              "producer_sources": pins, "verified_source_files": sources, "historical_source_snapshot": historical,
              "production_qualified": False, "remaining": ["COMPLETE_TRIANGLE_TERRAIN_AND_SUPPORT", "TOOL_BODY_AND_NATIVE",
                  "ACTUAL_INTEGER_ROOT_AND_PHASE_OWNER", "TRANSITION_RETREAT_AND_INSTALLED_SUPPORT"]}
    plan = {"revision": 101, "world_root_bounds_u": roots, "clips": [case["id"] for case in candidates]}
    raw_report, raw_plan = (json.dumps(report, indent=2)+"\n").encode(), (json.dumps(plan, indent=2)+"\n").encode()
    P.require(all(P.content.file_hash(P.ROOT/path) == digest for path, digest in pins.items()), "DESCENT_SOURCE_DRIFT")
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
