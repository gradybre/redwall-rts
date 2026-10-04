#!/usr/bin/env python3
"""Inspect and author a distinct BASIC-tool installation source; never grant BUILD permission."""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("actual_mole_source", HERE / "assess_stair_rig.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
A, P = M.A, M.P
PREFIX_SHA = "edd562056b12f732fbf60f0536207ba2afd1dce650d19df552ecf1e75ff9cf81"


def target_faces(packet):
    """Read the actual pinned candidate face relative to its station, without guessing reach or support."""
    rows = packet.get("fastening_candidates")
    P.require(packet.get("schema") == 1 and packet.get("engineering_only") is True and
              type(rows) is list and len(rows) == 2, "INSTALL_PREFIX")
    result = []
    for row in rows:
        bounds, root = row.get("target_bounds_u"), row.get("station_root_u")
        P.require(row.get("face") == "positive_y" and row.get("yaw_u16") == 0 and
                  type(bounds) is list and len(bounds) == 6 and type(root) is list and len(root) == 3 and
                  all(type(v) is int and abs(v) <= 8192 for v in bounds+root) and
                  all(bounds[i] < bounds[i+3] for i in range(3)), "INSTALL_TARGET_FACE")
        local = [v-root[i % 3] for i, v in enumerate(bounds)]
        P.require(local[4] == 0, "INSTALL_TARGET_HEIGHT")
        result.append({"assembly": row["assembly"], "existing_target_kind": row["existing_target_kind"],
                       "target_bounds_u": bounds, "station_root_u": root,
                       "local_target_box_u": local, "local_patch_limits_u": [local[0], 0, local[2], local[3], 0, local[5]],
                       "scope": "candidate existing face only; no authored stroke, stance or work permission"})
    return result


def workpiece_targets(packet):
    """Map two existing billed bearers to root-approved, non-supporting fitting poses."""
    original = target_faces(packet)
    parts = packet.get("parts")
    P.require(type(parts) is list and len(parts) == 14, "INSTALL_PART_CENSUS")
    transforms = [(1, [-896,-192,-2048,-768,-64,0], [1024,192,-768],
                   [-1024,0,0,1024,128,128]),
                  (8, [-896,-320,-2560,-768,-192,-2048], [2304,320,-2816],
                   [-256,0,-2048,256,128,-1920])]
    result = []
    for assembly, (part_id, expected, translation, wanted) in enumerate(transforms):
        part = parts[part_id]
        P.require(part.get("id") == part_id and part.get("assembly") == assembly and
                  part.get("bounds_u") == expected, "INSTALL_BILLED_PART_IDENTITY")
        corners = [[z+translation[0], y+translation[1], -x+translation[2]]
                   for x in (expected[0],expected[3]) for y in (expected[1],expected[4])
                   for z in (expected[2],expected[5])]
        bounds = [min(row[a] for row in corners) for a in range(3)] + \
                 [max(row[a] for row in corners) for a in range(3)]
        P.require(bounds == wanted, "INSTALL_WORKPIECE_TRANSFORM")
        root = original[assembly]["station_root_u"]
        local = [v-root[i % 3] for i,v in enumerate(bounds)]
        result.append({"assembly":assembly, "existing_target_kind":original[assembly]["existing_target_kind"],
            "station_root_u":root, "source_part_id":part_id, "source_part_name":part["name"],
            "source_part_bounds_u":expected, "source_quarter_turn":1, "source_translation_u":translation,
            "target_bounds_u":bounds, "local_target_box_u":local,
            "local_patch_limits_u":[local[0],128,local[2],local[3],128,local[5]],
            "target_kind":"paid_wip_bearer_candidate", "worker_support":False,
            "scope":"authored workpiece pose only; requires actual paid WIP and source-part binding"})
    return result


def prop_points(case, frame, part):
    P.require(len(part["geometry"]) == 1 and 0 <= frame < case["frames"], "INSTALL_TOOL_SOURCE")
    source = part["geometry"][0]["points"].astype(np.float64)
    P.require(0 < len(source) <= 131072 and source.shape[1:] == (3,) and np.all(np.isfinite(source)),
              "INSTALL_TOOL_CAPACITY")
    matrix = P._affine64(case["matrices"][frame, 24])
    points = source @ matrix[:3, :3].T + matrix[:3, 3]
    points[:, 1] += float(case["grounding"][frame])
    return points*1024


def inspect(cases, parts, rig, packet):
    parents, _, inverse_inverse = A.hierarchy(rig)
    globals_, _, fit = A.joints(cases[0], 8, parents, inverse_inverse)
    grounding = float(cases[0]["grounding"][8])
    source = parts[1]["geometry"][0]["points"]
    ready = prop_points(cases[0], 8, parts[1])
    work = [prop_points(cases[2], frame, parts[1]) for frame in (0, cases[2]["frames"]//2, cases[2]["frames"]-1)]
    vertices = sorted({148, *[int(operation(source[:, axis])) for operation in (np.argmin, np.argmax) for axis in range(3)]})
    return {"source_vertex_count": len(source), "source_triangles": 1150,
            "tool_source_bounds": [*source.min(axis=0).tolist(), *source.max(axis=0).tolist()],
            "ready_tool_bounds_u": [*ready.min(axis=0).tolist(), *ready.max(axis=0).tolist()],
            "source_vertex_candidates": [{"vertex": at, "source_m": source[at].tolist(), "ready_u": ready[at].tolist(),
                                          "downward_reference_u": [points[at].tolist() for points in work],
                                          "meaning": "known previously witnessed pick tip" if at == 148 else "raw mesh extremum; anatomical/head label unreviewed"}
                                         for at in vertices],
            "ready_joints_u": [{"bind": at, "name": rig["rig_binding"]["bones"][at]["name"],
                                "point": ((globals_[at][:3, 3]+[0, grounding, 0])*1024).tolist()}
                               for at in (9, 10, 11, 16, 17, 18, 19)],
            "actual_hand_fit": fit.tolist(), "targets": target_faces(packet),
            "source_scope": "floating inspection of actual source coefficients for authoring only; no continuous/contact/native proof",
            "production_qualified": False}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    parser.add_argument("--candidate", action="store_true")
    parser.add_argument("--lean-degrees", type=int, default=35)
    parser.add_argument("--azimuth-degrees", type=int, default=30)
    parser.add_argument("--x-u", type=int, default=128)
    parser.add_argument("--z-u", type=int, default=-448)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "INSTALL_OUTPUT_EXISTS")
    prefix = HERE/"stair-sequence-prefix-v1/first-entry-prefix-v1.source.json"
    paths = [Path(__file__), Path(M.__file__), Path(M.D.__file__), Path(A.__file__), Path(M.C.__file__),
             Path(M.C.H.__file__), Path(M.W.__file__), Path(M.W.H.__file__), Path(M.S.__file__),
             Path(P.__file__), Path(P.content.__file__), Path(P.envelope.__file__), Path(G.__file__), prefix]
    pins = {str(p.relative_to(P.ROOT)): P.content.file_hash(p) for p in paths}
    packet = P.content.read_json(prefix, PREFIX_SHA, 65536)
    cases, parts, rig, topology, roots, sources, historical = M.read_actual_source()
    if args.candidate:
        write_candidate(args, cases, parts, rig, topology, roots, sources, historical, packet, pins)
        return
    report = inspect(cases, parts, rig, packet)
    report.update(schema=1, producer_sources=pins, verified_source_files=sources,
                  compact_source_sha256=M.COMPACT_SHA, prefix_source_sha256=PREFIX_SHA,
                  historical_source_snapshot=historical)
    P.require(all(P.content.file_hash(P.ROOT/path) == digest for path, digest in pins.items()), "INSTALL_SOURCE_DRIFT")
    args.out.mkdir(parents=True)
    with (args.out/"inspection.json").open("x") as stream:
        json.dump(report, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"targets": report["targets"], "vertices": report["source_vertex_candidates"],
                      "production_qualified": False}, indent=2))

# Offline source authoring only. Every emitted coefficient remains subject to
# the independent continuous/native/terrain proofs; these choices grant no work.
POLL_VERTEX = 478  # Actual broad adze extremity; the loop at652 is rejected, never a hammer contact.
AUTHOR_SPEC = importlib.util.spec_from_file_location("install_arm_geometry", HERE/"author_stair_motion.py")
G = importlib.util.module_from_spec(AUTHOR_SPEC)
AUTHOR_SPEC.loader.exec_module(G)


def poll_pose(ready, part, rig, poll_u, lean_degrees=35, azimuth_degrees=30):
    """Put the actual broad stone adze end at an authored point with unchanged arm links and the real grip."""
    P.require(type(lean_degrees) is int and 25 <= lean_degrees <= 50 and
              type(azimuth_degrees) is int and 15 <= azimuth_degrees <= 45 and
              np.asarray(poll_u).shape == (3,) and np.all(np.isfinite(poll_u)) and
              np.max(np.abs(poll_u)) <= 2048, "INSTALL_POSE_INPUT")
    parents, inverse, inverse_inverse = A.hierarchy(rig)
    actual, _, fit = A.joints(ready, 8, parents, inverse_inverse)
    P.require([parents[18], parents[19]] == [17, 18], "INSTALL_ARM_HIERARCHY")
    tool = P._affine64(ready["matrices"][8, 24])
    # Left multiplication by a proper rotation preserves the complete native
    # source basis Gram matrix, including its finite source deviations.
    old_quaternion, _ = P._polar(tool[:3, :3])
    old_rotation = P._rotation(old_quaternion)
    angle = np.deg2rad(lean_degrees)
    x_axis = np.array([0., np.sin(angle), np.cos(angle)])
    y_axis = np.array([-1., 0., 0.])
    azimuth = np.deg2rad(azimuth_degrees)
    outward = np.array([[np.cos(azimuth),0,np.sin(azimuth)],[0,1,0],
                        [-np.sin(azimuth),0,np.cos(azimuth)]])
    desired = outward @ np.stack((x_axis, y_axis, np.cross(x_axis, y_axis)), axis=1)
    tool[:3, :3] = desired @ old_rotation.T @ tool[:3, :3]
    source = np.asarray(part["geometry"][0]["points"][POLL_VERTEX], dtype=np.float64)
    grounded = np.asarray(poll_u, dtype=np.float64)/1024
    grounded[1] -= float(ready["grounding"][8])
    tool[:3, 3] = grounded - tool[:3, :3] @ source
    hand = tool @ np.linalg.inv(fit)
    shoulder, elbow, wrist = [actual[index][:3, 3] for index in (17, 18, 19)]
    target = hand[:3, 3]
    middle = G.knee_target(shoulder, elbow, wrist, target)
    moved = [row.copy() for row in actual]
    for bone, start, end, old_start, old_end in (
            (17, shoulder, middle, shoulder, elbow), (18, middle, target, elbow, wrist)):
        moved[bone][:3, :3] = G.rotation_between(old_end-old_start, end-start) @ actual[bone][:3, :3]
        moved[bone][:3, 3] = start
    # An endpoint-only IK solve leaves the original forearm roll behind while
    # the hand turns the head. Match the original hand/forearm frame first,
    # then use only a proper rotation to close each actual limb direction.
    # This changes real deformed wrist/arm geometry, never the palm exclusion.
    hand_turn = hand[:3, :3] @ np.linalg.inv(actual[19][:3, :3])
    close_forearm = G.rotation_between(hand_turn @ (wrist-elbow), target-middle)
    moved[18][:3, :3] = close_forearm @ hand_turn @ actual[18][:3, :3]
    forearm_turn = moved[18][:3, :3] @ np.linalg.inv(actual[18][:3, :3])
    close_upper = G.rotation_between(forearm_turn @ (elbow-shoulder), middle-shoulder)
    moved[17][:3, :3] = close_upper @ forearm_turn @ actual[17][:3, :3]
    moved[19] = hand
    result = dict(ready, frames=1, matrices=ready["matrices"][8:9].copy(), grounding=ready["grounding"][8:9].copy())
    A.put_pose(result, 0, moved, inverse, fit, ready)
    error = max(abs(np.linalg.norm(middle-shoulder)-np.linalg.norm(elbow-shoulder)),
                abs(np.linalg.norm(target-middle)-np.linalg.norm(wrist-elbow)))
    P.require(error < 1e-10, "INSTALL_ARM_LENGTH_DRIFT")
    return result, {"maximum_link_length_error_m": float(error), "hand_origin_u":
                    ((hand[:3, 3]+[0, ready["grounding"][8], 0])*1024).tolist(),
                    "poll_u": prop_points(result, 0, part)[POLL_VERTEX].tolist()}


def source_motion(ready, part, rig, x_u=128, z_u=-448, lean_degrees=35, azimuth_degrees=30):
    """A distinct short adze fitting tap, planted lower body and exact recovery; no reused dig interval."""
    P.require(type(x_u) is int and -128 <= x_u <= 192 and type(z_u) is int and -480 <= z_u <= -416,
              "INSTALL_SOURCE_TARGET")
    frames = []
    diagnostics = []
    for at in range(17):
        share = at/16
        height = 128+80-(82*share*share*(3-2*share))
        pose, facts = poll_pose(ready, part, rig, [x_u, height, z_u], lean_degrees, azimuth_degrees)
        frames.append(pose["matrices"][0]); diagnostics.append(facts)
    source = dict(ready, id="mole_worker.install_adze.tap_v4", frames=33, source_loop_mode=0,
                  source_duration_s=Fraction(32,30), duration_q16=32*65536,
                  matrices=np.stack(frames+frames[-2::-1]),
                  grounding=np.full(33,ready["grounding"][8],dtype=np.float32))
    entry = A.planted_entry(ready, source, rig, 31)
    entry["id"] = "mole_worker.install_adze.entry_v4"
    recovery = P.indexed_sequence(entry,list(range(30,-1,-1)),"mole_worker.install_adze.recovery_v4",False)
    return source, entry, recovery, diagnostics


def pose_diagnostics(case, parts):
    """Finite-frame inspection is explicitly distinct from a continuous primitive or contact proof."""
    body, tool = [], []
    for at in range(case["frames"]):
        body.append(G.source_positions(parts[0], case["matrices"][at], case["grounding"][at]))
        tool.append(prop_points(case, at, parts[1]))
    body, tool = np.stack(body), np.stack(tool)
    below = tool[tool[:, :, 1] < 0]
    return {"frames": case["frames"], "body_bounds_u": [*body.min((0, 1)).tolist(), *body.max((0, 1)).tolist()],
            "tool_bounds_u": [*tool.min((0, 1)).tolist(), *tool.max((0, 1)).tolist()],
            "tool_below_zero_source_vertices": len(below), "tool_below_zero_bounds_u":
            [*below.min(0).tolist(), *below.max(0).tolist()] if len(below) else [],
            "scope": "sampled source vertices only; triangle interiors/interpolation/native residual remain unproved"}


def write_candidate(args, cases, parts, rig, topology, roots, sources, historical, packet, pins):
    """Emit one source-pinned finite candidate; an absent proof never becomes a production flag."""
    work, entry, recovery, diagnostics = source_motion(cases[0], parts[1], rig, args.x_u, args.z_u,
                                                       args.lean_degrees, args.azimuth_degrees)
    candidates = [work, entry, recovery]
    for case in candidates:
        case["geometry"] = parts
    report = {"schema": 1, "compact_source_sha256": M.COMPACT_SHA, "prefix_source_sha256": PREFIX_SHA,
        "targets": workpiece_targets(packet), "poll_source_vertex": POLL_VERTEX,
        "contact_source_kind": "actual broad adze end; INSTALL meaning remains under native/source review",
        "contact_source_point_m": parts[1]["geometry"][0]["points"][POLL_VERTEX].tolist(),
        "source_recipe": {"lean_degrees": args.lean_degrees, "azimuth_degrees":args.azimuth_degrees,
                          "poll_xz_u": [args.x_u, args.z_u], "contact_plane_y_u":128,
                          "poll_y_u": [208, 126, 208], "productive_frames": 33, "entry_frames": 31,
                          "unchanged_lower_binds": list(range(9)), "unmodified_arm_lengths": True,
                          "hand_fit": "exact actual compact-ready fit; no socket regrip or tool substitution"},
        "pose_solver_diagnostics": diagnostics, "diagnostics": [pose_diagnostics(case, parts) for case in candidates],
        "source_triangle_census": [sum(len(rows) for rows in primitive) for primitive in topology],
        "verified_source_files": sources, "historical_source_snapshot": historical, "producer_sources": pins,
        "remaining": ["CONTINUOUS_BODY_TOOL_SELF_CLEARANCE", "SOURCE_POLL_PATCH_AND_FULL_TARGET_CLEARANCE",
                      "FULL_ENTRY_RECOVERY_SUPPORT", "NATIVE_MATERIAL_GRIP_AND_FASTENING_REVIEW",
                      "ACTUAL_BUILD_JOB_GEAR_PROFILE_AND_PAID_TARGET_BINDING"], "production_qualified": False}
    command = M.W.read_record(HERE/"analysis-carry-arm-v7/invocation.json")["command"]
    proof = P.content.read_json(Path(command[command.index("--proof")+1]), command[command.index("--proof-sha256")+1])
    plan = {"revision": 105, "world_root_bounds_u": roots, "clips": [case["id"] for case in candidates]}
    raw_report = (json.dumps(report, indent=2)+"\n").encode()
    raw_plan = (json.dumps(plan, indent=2)+"\n").encode()
    image, budget = P.content.encode(candidates, plan, proof, M.COMPACT_SHA, hashlib.sha256(raw_report).hexdigest(),
                                     hashlib.sha256(raw_plan).hexdigest())
    P.require(all(P.content.file_hash(P.ROOT/path) == digest for path, digest in pins.items()), "INSTALL_SOURCE_DRIFT")
    args.out.mkdir(parents=True)
    for name, raw in (("candidate.json", raw_report), ("plan.json", raw_plan), ("mole-worker.ugactor", image)):
        with (args.out/name).open("xb") as stream:
            stream.write(raw)
    (args.out/"compilation.json").write_text(json.dumps({"content_sha256": hashlib.sha256(image).hexdigest(),
        "content_bytes": len(image), "presentation_budget": budget, "production_qualified": False}, indent=2)+"\n")
    print(json.dumps({"content_sha256": hashlib.sha256(image).hexdigest(), "diagnostics": report["diagnostics"],
                      "production_qualified": False}, indent=2))


if __name__ == "__main__":
    main()
