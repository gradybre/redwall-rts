#!/usr/bin/env python3
"""Author stationary handling at the complete delivered bearer; never emit permission."""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path

import numpy as np

import inspect_assembly as I

P = I.P
A = I.M.I.I.A
G = I.M.I.I.G


def turn(axis, radians):
    axis = np.asarray(axis, dtype=np.float64)
    axis /= np.linalg.norm(axis)
    x, y, z = axis
    skew = np.array([[0., -z, y], [z, 0., -x], [-y, x, 0.]])
    return np.eye(3) + np.sin(radians) * skew + (1 - np.cos(radians)) * (skew @ skew)


def arm(moved, original, shoulder, elbow, wrist, hand):
    """Close the actual two rigid links, retaining the source hand frame and skin."""
    start, middle, last = [moved[at][:3, 3].copy() for at in (shoulder, elbow, wrist)]
    target = hand[:3, 3]
    bend = G.knee_target(start, middle, last, target)
    hand_turn = hand[:3, :3] @ np.linalg.inv(moved[wrist][:3, :3])
    forearm_turn = G.rotation_between(hand_turn @ (last - middle), target - bend) @ hand_turn
    upper_turn = G.rotation_between(forearm_turn @ (middle - start), bend - start) @ forearm_turn
    moved[shoulder][:3, :3] = upper_turn @ moved[shoulder][:3, :3]
    moved[elbow][:3, :3] = forearm_turn @ moved[elbow][:3, :3]
    moved[elbow][:3, 3] = bend
    moved[wrist] = hand.copy()
    error = max(abs(np.linalg.norm(bend-start)-np.linalg.norm(middle-start)),
                abs(np.linalg.norm(target-bend)-np.linalg.norm(last-middle)))
    P.require(error < 1e-10, "ASSEMBLY_ARM_LENGTH")
    return error


def pose(ready, rig, lean, wrist_u, roll, entry_share=1.0):
    """One real free-hand contact pose. The right hand retains the actual BASIC pick fit."""
    P.require(type(lean) is int and 0 <= lean <= 85 and type(roll) is int and -180 <= roll <= 180 and
              len(wrist_u) == 3 and all(type(v) in (int, float) and np.isfinite(v) and abs(v) <= 1024 for v in wrist_u),
              "ASSEMBLY_POSE_ARGUMENT")
    P.require(np.isfinite(entry_share) and 0 <= entry_share <= 1, "ASSEMBLY_ENTRY_SHARE")
    parents, inverse, inv_inv = A.hierarchy(rig)
    original, _, fit = A.joints(ready, 8, parents, inv_inv)
    torso = np.eye(4)
    torso[:3, :3] = turn([1, 0, 0], -np.deg2rad(lean)*entry_share)
    pivot = original[9][:3, 3]
    torso[:3, 3] = pivot - torso[:3, :3] @ pivot
    moved = [row.copy() if at < 9 else torso @ row for at, row in enumerate(original)]
    hand = original[15].copy()
    align = G.rotation_between(hand[:3, 1], [0., -1., 0.])
    hand[:3, :3] = turn([0, -1, 0], np.deg2rad(roll)) @ align @ hand[:3, :3]
    hand[:3, 3] = np.asarray(wrist_u, dtype=np.float64) / 1024
    hand[1, 3] -= float(ready["grounding"][8])
    if entry_share != 1.0:
        hand = P._interpolate_local(original[15], hand, entry_share)
    tool_hand = original[19].copy()
    tool_hand[0, 3] += 112 * entry_share / 1024
    errors = [arm(moved, original, 13, 14, 15, hand), arm(moved, original, 17, 18, 19, tool_hand)]
    result = dict(ready, id="mole_worker.assembly_position.pose_v1", frames=1,
                  matrices=ready["matrices"][8:9].copy(), grounding=ready["grounding"][8:9].copy())
    A.put_pose(result, 0, moved, inverse, fit, ready)
    return result, {"lean_degrees": lean, "left_wrist_u": wrist_u, "palm_roll_degrees": roll,
                    "maximum_arm_link_error_m": max(errors), "lower_body_matches_planted_reference": True,
                    "pick_fit_unchanged": True, "right_hand_outward_u": 112}


def palm_rows(body, triangles, rig):
    """Name complete left distal-palm triangles; this is a contact role, never a world-air exclusion."""
    surface = body["geometry"][0]
    share = np.sum(np.where(surface["ids"] == 15, surface["weights"], 0), axis=1)
    binding = P._affine64(np.asarray(rig["rig_binding"]["bones"][15]["inverse_bind"], dtype=np.float32))
    local = surface["points"].astype(np.float64) @ binding[:3, :3].T + binding[:3, 3]
    distal = (share > 0) & (local[:, 1] > .025)
    palm = np.all(distal[triangles], axis=1)
    P.require(0 < int(palm.sum()) < len(triangles), "ASSEMBLY_PALM_PARTITION")
    return palm


def clip_triangle_box(triangle, bounds):
    """Authoring-only floating closed-box intersection; the independent proof uses exact arithmetic."""
    points = list(triangle)
    for axis in range(3):
        for plane, sign in ((bounds[axis], 1), (bounds[axis + 3], -1)):
            output = []
            for at, first in enumerate(points):
                last = points[(at + 1) % len(points)]
                a, b = (first[axis] - plane) * sign, (last[axis] - plane) * sign
                if a >= 0:
                    output.append(first)
                if (a < 0) != (b < 0):
                    output.append(first + (last-first) * (a / (a-b)))
            points = output
            if not points:
                return False
    return True


def diagnostics(case, parts, topology, rig, beam):
    body = G.source_positions(parts[0], case["matrices"][0], case["grounding"][0])
    tool = I.M.I.I.prop_points(case, 0, parts[1])
    triangles = topology[0][0]
    palm = palm_rows(parts[0], triangles, rig)
    crossings = []
    for points, rows, role in ((body, triangles, "body"), (tool, topology[1][0], "pick")):
        low, high = points[rows].min(axis=1), points[rows].max(axis=1)
        possible = np.flatnonzero(np.all(low <= beam[3:], axis=1) & np.all(high >= beam[:3], axis=1))
        for at in possible:
            if clip_triangle_box(points[rows[at]], beam):
                crossings.append({"part": role, "triangle": int(at),
                                  "contact_palm": bool(role == "body" and palm[at])})
    return {"body_bounds_u": [*body.min(axis=0).tolist(), *body.max(axis=0).tolist()],
            "pick_bounds_u": [*tool.min(axis=0).tolist(), *tool.max(axis=0).tolist()],
            "left_palm_triangles": int(palm.sum()), "beam_intersections": crossings,
            "non_contact_intersections": sum(not row["contact_palm"] for row in crossings),
            "palm_intersections": sum(row["contact_palm"] for row in crossings),
            "minimum_body_height_u": float(body[:, 1].min()), "minimum_pick_height_u": float(tool[:, 1].min()),
            "scope": "Sampled floating source inspection only; no continuous, native or runtime certificate."}


def top_contact(ready, parts, topology, rig, lean, wrist_u, roll, beam):
    """Solve a real distal vertex just above the actual top; no palm triangle is allowed to sink into wood."""
    wrist = list(wrist_u)
    palm = palm_rows(parts[0], topology[0][0], rig)
    vertices = np.unique(topology[0][0][palm])
    records = []
    for iteration in range(24):
        candidate, recipe = pose(ready, rig, lean, wrist, roll)
        points = G.source_positions(parts[0], candidate["matrices"][0], candidate["grounding"][0])
        inside = vertices[np.all(points[vertices][:, [0, 2]] > np.asarray(beam)[[0, 2]], axis=1) &
                          np.all(points[vertices][:, [0, 2]] < np.asarray(beam)[[3, 5]], axis=1)]
        P.require(len(inside) > 0, "ASSEMBLY_CONTACT_REACH")
        vertex = int(inside[np.argmin(points[inside, 1])])
        residual = beam[4] + 1 / 512 - float(points[vertex, 1])
        records.append({"iteration": iteration, "vertex": vertex, "residual_u": residual})
        if abs(residual) <= 1 / 2048:
            recipe.update(contact_vertex=vertex, contact_point_u=points[vertex].tolist(),
                          top_plane_u=beam[4], contact_solve_gap_u=[1, 512],
                          contact_solve_tolerance_u=[1, 2048], solve_iterations=records)
            return candidate, recipe
        wrist[1] += residual
    raise ValueError("ASSEMBLY_CONTACT_CONVERGENCE")


def between(ready, first_case, last_case, rig, count):
    """Finite actual local-joint interpolation; exact endpoint palettes close both joins."""
    P.require(type(count) is int and 3 <= count <= 121, "ASSEMBLY_TRANSITION_CAPACITY")
    parents, inverse, inv_inv = A.hierarchy(rig)
    base, _, fit = A.joints(ready, 8, parents, inv_inv)
    _, first, fit0 = A.joints(first_case, 0, parents, inv_inv)
    _, last, fit1 = A.joints(last_case, 0, parents, inv_inv)
    P.require(np.max(np.abs(fit0-fit)) < 1e-5 and np.max(np.abs(fit1-fit)) < 1e-5,
              "ASSEMBLY_PICK_FIT")
    result = dict(last_case, frames=count, source_loop_mode=0, source_duration_s=Fraction(count-1, 30),
                  duration_q16=(count-1)*65536, matrices=np.empty((count, 25, 12), dtype=np.float32),
                  grounding=np.empty(count, dtype=np.float32))
    for frame in range(count):
        moved = list(base)
        for at in range(9, 24):
            moved[at] = moved[parents[at]] @ P._interpolate_local(first[at], last[at], frame/(count-1))
        A.put_pose(result, frame, moved, inverse, fit, ready)
    result["matrices"][0], result["grounding"][0] = first_case["matrices"][0], first_case["grounding"][0]
    result["matrices"][-1], result["grounding"][-1] = last_case["matrices"][0], last_case["grounding"][0]
    return result


def clear_entry(ready, contact, recipe, rig):
    wrist = list(recipe["left_wrist_u"])
    wrist[1] += 128
    raised, _ = pose(ready, rig, recipe["lean_degrees"], wrist, recipe["palm_roll_degrees"])
    # Solve actual arm links along a direct free-space hand path. Interpolating
    # local elbow frames alone made an unnecessary overhead arc in candidate6.
    first = dict(raised, frames=31, source_loop_mode=0, source_duration_s=Fraction(30, 30),
                 duration_q16=30*65536, matrices=np.empty((31, 25, 12), dtype=np.float32),
                 grounding=np.full(31, ready["grounding"][8], dtype=np.float32))
    for frame in range(31):
        part, _ = pose(ready, rig, recipe["lean_degrees"], wrist, recipe["palm_roll_degrees"], frame/30)
        first["matrices"][frame] = part["matrices"][0]
    first["matrices"][0] = ready["matrices"][8]
    first["matrices"][-1] = raised["matrices"][0]
    last = between(ready, raised, contact, rig, 17)
    return dict(first, frames=47, source_duration_s=Fraction(46, 30), duration_q16=46*65536,
                matrices=np.concatenate((first["matrices"], last["matrices"][1:])),
                grounding=np.concatenate((first["grounding"], last["grounding"][1:])))


def plant_feet(ready, rig, down_u):
    """Move the actual ankle/toes through original leg links, preserving every mixed skin influence."""
    P.require(len(down_u) == 2 and all(np.isfinite(v) and abs(v) < 32 for v in down_u),
              "ASSEMBLY_FOOT_SOLVE_CAPACITY")
    parents, inverse, inv_inv = A.hierarchy(rig)
    original, _, _ = A.joints(ready, 8, parents, inv_inv)
    moved = [row.copy() for row in original]
    for side, (hip, knee, ankle, toe) in enumerate(((1, 2, 3, 4), (5, 6, 7, 8))):
        start, middle, last = [original[at][:3, 3] for at in (hip, knee, ankle)]
        target = last - np.asarray([0., down_u[side]/1024, 0.])
        bend = G.knee_target(start, middle, last, target)
        for bone, a, b, x, y in ((hip, start, middle, start, bend), (knee, middle, last, bend, target)):
            moved[bone][:3, :3] = G.rotation_between(b-a, y-x) @ original[bone][:3, :3]
            moved[bone][:3, 3] = x
        for at in (ankle, toe):
            moved[at][:3, 3] = original[at][:3, 3] + target-last
    palette = ready["matrices"][8].copy()
    for at in range(1, 9):
        matrix = moved[at] @ inverse[at]
        palette[at, :9], palette[at, 9:] = matrix[:3, :3].T.reshape(-1), matrix[:3, 3]
    return palette


def planted_reference(ready, part, triangles, rig):
    """The ready right sole is above the plane; explicitly plant it before handling and reverse afterward."""
    feet = [G.M.anatomical_foot_triangles(part, triangles, pair) for pair in ((3, 4), (7, 8))]
    vertices = [np.unique(triangles[rows]) for rows in feet]
    down, records = [0., 0.], []
    for iteration in range(24):
        palette = plant_feet(ready, rig, down)
        points = G.source_positions(part, palette, ready["grounding"][8])
        anchors = [int(rows[np.argmin(points[rows, 1])]) for rows in vertices]
        residual = [float(points[at, 1]) - 1/512 for at in anchors]
        records.append({"iteration": iteration, "down_u": list(down), "vertices": anchors,
                        "source_height_u": [float(points[at, 1]) for at in anchors]})
        if max(abs(v) for v in residual) <= 1/2048:
            break
        down = [a+b for a, b in zip(down, residual)]
    else:
        raise ValueError("ASSEMBLY_FOOT_CONVERGENCE")
    result = dict(ready, matrices=ready["matrices"].copy(), grounding=ready["grounding"].copy())
    result["matrices"][8] = palette
    entry = np.stack([plant_feet(ready, rig, [v*at/8 for v in down]) for at in range(9)])
    entry[0], entry[-1] = ready["matrices"][8], palette
    return result, entry, {"foot_down_u": down, "source_contact_vertices": anchors,
                           "solve": records, "unchanged_ready_endpoints": True,
                           "plant_intervals": 8, "unplant_intervals": 8}


def program(ready, parts, topology, rig, lean, wrist, roll):
    """Touch the exact final prism without moving its corners or creating a handling rate."""
    ready, foot_entry, feet = planted_reference(ready, parts[0], topology[0][0], rig)
    beam = [-192, 0, -512, 1856, 128, -384]
    placed, facts = top_contact(ready, parts, topology, rig, lean, wrist, roll, beam)
    recipes = [facts, facts]
    work = dict(ready, id="mole_worker.assembly_seat.contact_v1", frames=2, source_loop_mode=0,
                source_duration_s=Fraction(1, 30), duration_q16=65536,
                matrices=np.repeat(placed["matrices"], 2, axis=0),
                grounding=np.full(2, ready["grounding"][8], dtype=np.float32))
    entry = clear_entry(ready, work, recipes[0], rig)
    entry = dict(entry, frames=55, source_duration_s=Fraction(54, 30), duration_q16=54*65536,
                 matrices=np.concatenate((foot_entry[:-1], entry["matrices"])),
                 grounding=np.full(55, ready["grounding"][8], dtype=np.float32))
    entry["id"] = "mole_worker.assembly_seat.entry_v1"
    last = dict(work, frames=1, matrices=work["matrices"][-1:].copy(), grounding=work["grounding"][-1:].copy())
    final_entry = clear_entry(ready, last, recipes[-1], rig)
    recovery = P.indexed_sequence(final_entry, list(range(46, -1, -1)),
                                  "mole_worker.assembly_seat.recovery_v1", False)
    recovery = dict(recovery, frames=55, source_duration_s=Fraction(54, 30), duration_q16=54*65536,
                    matrices=np.concatenate((recovery["matrices"], foot_entry[-2::-1])),
                    grounding=np.full(55, ready["grounding"][8], dtype=np.float32))
    return [entry, work, recovery], [[0] * 55, [0, 0], [0] * 55], recipes, feet


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--lean", type=int, default=70)
    parser.add_argument("--wrist", type=int, nargs=3, default=[-128, 224, -352])
    parser.add_argument("--roll", type=int, default=0)
    parser.add_argument("--program", action="store_true")
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "ASSEMBLY_OUTPUT_EXISTS")
    cases, parts, rig, topology, _, count, _, _, pins = I.source_inputs()
    if args.program:
        clips, offsets, recipes, feet = program(cases[0], parts, topology, rig, args.lean, args.wrist, args.roll)
        args.out.mkdir(parents=True)
        records = []
        for name, clip, shifts in zip(("entry", "seat", "recovery"), clips, offsets):
            path = args.out / (name + ".npz")
            np.savez(path, matrices=clip["matrices"], grounding=clip["grounding"])
            summaries = []
            for frame in range(clip["frames"]):
                sample = dict(clip, frames=1, matrices=clip["matrices"][frame:frame+1],
                              grounding=clip["grounding"][frame:frame+1])
                facts = diagnostics(sample, parts, topology, rig,
                                    [-192, 0, -512 + shifts[frame], 1856, 128, -384 + shifts[frame]])
                summaries.append({k: facts[k] for k in ("non_contact_intersections", "palm_intersections",
                                  "minimum_body_height_u", "minimum_pick_height_u", "body_bounds_u", "pick_bounds_u")})
            records.append({"clip": name, "frames": clip["frames"], "intervals": clip["frames"] - 1,
                            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "beam_offset_z_u": shifts,
                            "sampled": summaries})
        report = {"status": "UNQUALIFIED_SOURCE_CANDIDATE", "production_qualified": False,
                  "verified_source_files": count, "clips": records, "contact_recipes": recipes,
                  "foot_plant": feet,
                  "source_inputs": pins, "root_delta_u": [0, 0, 0], "adopted_rate": None,
                  "motion": "The complete delivered bearer remains at the exact final prism throughout stationary seating and recovery.",
                  "remaining": ["COMPLETE_CONTINUOUS_SOURCE_PROOF", "NATIVE_REPLAY", "ACTUAL_PAID_OWNER_BINDING"]}
        (args.out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"clips": [{"name": row["clip"], "frames": row["frames"],
                    "non_contact_intersections": sum(v["non_contact_intersections"] for v in row["sampled"]),
                    "palm_intersections": sum(v["palm_intersections"] for v in row["sampled"])} for row in records],
                    "contact_vertices": sorted({row["contact_vertex"] for row in recipes}), "qualified": False}))
        return
    candidate, recipe = pose(cases[0], rig, args.lean, args.wrist, args.roll)
    # Both existing bill-owned included bearers have the same complete Y/Z section.
    boxes = [[-192, 0, -512, 1856, 128, -384], [-256, 0, -512, 256, 128, -384]]
    report = {"status": "UNQUALIFIED_SOURCE_CANDIDATE", "production_qualified": False,
              "verified_source_files": count, "recipe": recipe, "source_inputs": pins,
              "targets": [diagnostics(candidate, parts, topology, rig, box) for box in boxes]}
    args.out.mkdir(parents=True)
    np.savez(args.out / "pose.npz", matrices=candidate["matrices"], grounding=candidate["grounding"])
    report["pose_sha256"] = hashlib.sha256((args.out / "pose.npz").read_bytes()).hexdigest()
    (args.out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"recipe": recipe, "targets": report["targets"]}))


if __name__ == "__main__":
    main()
