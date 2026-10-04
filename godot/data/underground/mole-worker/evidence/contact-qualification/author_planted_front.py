#!/usr/bin/env python3
"""Author a fixed-foot low/front source candidate from supplied local joints; no support or contact permission."""
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
SPEC = importlib.util.spec_from_file_location("state_source_program", HERE / "compile_state_program.py")
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)
P, S, W = C.P, C.S, C.W


def hierarchy(native: dict) -> tuple:
    """Only the supplied finite mole hierarchy is eligible for this authored local-joint correction."""
    rig = native.get("rig_binding", {})
    bones = rig.get("bones")
    P.require(type(bones) is list and len(bones) == 24 and rig.get("right_hand") == 19,
              "PLANTED_RIG")
    parents, inverse = [], []
    for at, bone in enumerate(bones):
        P.require(bone.get("bone") == bone.get("bind") == at and type(bone.get("parent")) is int and
                  -1 <= bone["parent"] < at, "PLANTED_HIERARCHY")
        parents.append(bone["parent"])
        inverse.append(P._affine64(np.asarray(bone["inverse_bind"], dtype=np.float32)))
    P.require(bones[0]["name"] == "Hips" and bones[8]["name"] == "RightToeBase" and
              bones[9]["name"] == "Spine02" and parents[9] == 0, "PLANTED_LOWER_BODY")
    return parents, inverse, [np.linalg.inv(value) for value in inverse]


def joints(case: dict, frame: int, parents: list, inverse_inverse: list) -> tuple:
    """Derive actual globals/locals and the held-tool fit from the supplied palette, never an inferred reach."""
    actual = [P._affine64(case["matrices"][frame, at]) @ inverse_inverse[at] for at in range(24)]
    local = [np.linalg.inv(actual[parent]) @ actual[at] if parent >= 0 else actual[at]
             for at, parent in enumerate(parents)]
    fit = np.linalg.inv(actual[19]) @ P._affine64(case["matrices"][frame, 24])
    return actual, local, fit


def put_pose(result: dict, frame: int, globals_: list, inverse: list, fit: np.ndarray, ready: dict) -> None:
    """Keep all nine lower-body source matrices and the foot-plane grounding bit-identical."""
    for at in range(9, 25):
        value = globals_[at] @ inverse[at] if at < 24 else globals_[19] @ fit
        P.require(np.all(np.isfinite(value)) and np.max(np.abs(value)) <= 1024, "PLANTED_AFFINE_CAPACITY")
        result["matrices"][frame, at, :9] = value[:3, :3].T.reshape(-1)
        result["matrices"][frame, at, 9:] = value[:3, 3]
    result["matrices"][frame, :9] = ready["matrices"][8, :9]
    result["grounding"][frame] = ready["grounding"][8]


def plant_work(ready: dict, work: dict, native: dict) -> dict:
    """Retain the idle hips/legs and local bone translations while using actual source upper-body rotations."""
    P.require(ready["frames"] > 8 and work["matrices"].shape == (work["frames"], 25, 12), "PLANTED_SOURCE")
    parents, inverse, inverse_inverse = hierarchy(native)
    base, base_local, _ = joints(ready, 8, parents, inverse_inverse)
    result = dict(work, matrices=work["matrices"].copy(), grounding=work["grounding"].copy())
    for frame in range(work["frames"]):
        _, source_local, fit = joints(work, frame, parents, inverse_inverse)
        moved = list(base)
        for at in range(9, 24):
            local = source_local[at].copy()
            P._polar(local[:3, :3])
            local[:3, 3] = base_local[at][:3, 3]
            moved[at] = moved[parents[at]] @ local
        put_pose(result, frame, moved, inverse, fit, ready)
    result["id"] = "mole_worker.planted_front.source30_48_v1"
    result["planted_recipe"] = {"ready_frame": 8, "unchanged_skin_bones": list(range(9)),
        "authored_local_bases": list(range(9, 24)), "translations": "actual ready local translations",
        "tool_fit": "actual corrected source work hand fit each frame", "grounding": "exact ready value"}
    return result


def planted_entry(ready: dict, work: dict, native: dict, count: int = 31) -> dict:
    """A finite local-rig entry preserves planted feet through every authored and rendered source interval."""
    P.require(type(count) is int and 3 <= count <= 121, "PLANTED_ENTRY_CAPACITY")
    parents, inverse, inverse_inverse = hierarchy(native)
    base, first, fit0 = joints(ready, 8, parents, inverse_inverse)
    _, last, fit1 = joints(work, 0, parents, inverse_inverse)
    pivot = np.ones(4)
    pivot[:3] = np.asarray(native["pick_binding"]["prop_local_grip_m"], dtype=np.float32)
    grip0, grip1 = fit0 @ pivot, fit1 @ pivot
    P.require(np.max(np.abs(grip0 - grip1)) < 1e-4, "PLANTED_GRIP_DRIFT")
    result = dict(work, id="mole_worker.planted_front.entry_v1", frames=count, source_loop_mode=0,
                  source_duration_s=Fraction(count - 1, 30), duration_q16=(count - 1) * 65536,
                  matrices=np.empty((count, 25, 12), dtype=np.float32), grounding=np.empty(count, dtype=np.float32))
    for frame in range(count):
        share = frame / (count - 1)
        moved = list(base)
        for at in range(9, 24):
            local = P._interpolate_local(first[at], last[at], share)
            moved[at] = moved[parents[at]] @ local
        fit = P._interpolate_local(fit0, fit1, share * share)
        fit[:3, 3] = ((1 - share) * grip0 + share * grip1)[:3] - fit[:3, :3] @ pivot[:3]
        put_pose(result, frame, moved, inverse, fit, ready)
    result["matrices"][0], result["grounding"][0] = ready["matrices"][8], ready["grounding"][8]
    result["matrices"][-1], result["grounding"][-1] = work["matrices"][0], work["grounding"][0]
    return result


def depress_upper_arm(case: dict, native: dict, degrees: int) -> dict:
    """Authored shoulder pitch changes real connected joints and the whole pick, never just a contact point."""
    P.require(type(degrees) is int and 0 <= degrees <= 45, "PLANTED_DEPRESSION")
    _, inverse, inverse_inverse = hierarchy(native)
    P.require(native["rig_binding"]["bones"][17]["name"] == "RightArm", "PLANTED_DEPRESSION_SOURCE")
    result = dict(case, matrices=case["matrices"].copy(), grounding=case["grounding"].copy())
    angle = -math.radians(degrees)
    cosine, sine = math.cos(angle), math.sin(angle)
    basis = np.array([[1, 0, 0], [0, cosine, -sine], [0, sine, cosine]])
    for frame in range(case["frames"]):
        arm = P._affine64(case["matrices"][frame, 17]) @ inverse_inverse[17]
        rotation = np.eye(4)
        rotation[:3, :3] = basis
        rotation[:3, 3] = arm[:3, 3] - basis @ arm[:3, 3]
        for bone in (17, 18, 19, 24):
            transformed = rotation @ P._affine64(case["matrices"][frame, bone])
            result["matrices"][frame, bone, :9] = transformed[:3, :3].T.reshape(-1)
            result["matrices"][frame, bone, 9:] = transformed[:3, 3]
    result["planted_recipe"] = dict(case["planted_recipe"], right_upper_arm_depression_degrees=degrees,
        pitch_axis="actor +X around actual RightArm origin; proper connected joint and held-tool transform")
    return result


def compact_carry(case: dict, native: dict, degrees: int) -> dict:
    """An authored shoulder yaw brings the actual held tool beside the body; lower joints and grip are unchanged."""
    P.require(type(degrees) is int and -60 <= degrees <= 60, "PLANTED_CARRY_YAW")
    _, _, inverse_inverse = hierarchy(native)
    P.require(native["rig_binding"]["bones"][16]["name"] == "RightShoulder", "PLANTED_CARRY_SOURCE")
    result = dict(case, matrices=case["matrices"].copy(), grounding=case["grounding"].copy())
    angle = math.radians(degrees)
    cosine, sine = math.cos(angle), math.sin(angle)
    basis = np.array([[cosine, 0, sine], [0, 1, 0], [-sine, 0, cosine]])
    for frame in range(case["frames"]):
        shoulder = P._affine64(case["matrices"][frame, 16]) @ inverse_inverse[16]
        rotate = np.eye(4)
        rotate[:3, :3] = basis
        rotate[:3, 3] = shoulder[:3, 3] - basis @ shoulder[:3, 3]
        for bone in (16, 17, 18, 19, 24):
            transformed = rotate @ P._affine64(case["matrices"][frame, bone])
            result["matrices"][frame, bone, :9] = transformed[:3, :3].T.reshape(-1)
            result["matrices"][frame, bone, 9:] = transformed[:3, 3]
    result["compact_recipe"] = {"ready_clavicle_yaw_degrees": degrees,
        "pivot": "actual RightShoulder origin each frame; connected subtree and entire held tool",
        "unchanged_bones": list(range(16)) + list(range(20, 24)), "grounding": "exact original"}
    return result


def tip_crossings(case: dict, part: dict, roots: list[int], plane_u: int) -> list[dict]:
    """Positive motion into the exact front plane must be witnessed by the actual head vertex with full residual."""
    matrices = case["matrices"][:, 24:25]
    hulls = P._vertex_hulls(part, matrices, case["grounding"])
    padding, errors = P._residual_padding(part, matrices, case["grounding"], roots, hulls)
    uncertainty = [Fraction(int(x), P.SCALE) for x in padding]
    source = [Fraction(float(x)) for x in part["geometry"][0]["points"][148]]
    points = []
    for frame, row in enumerate(matrices[:, 0]):
        point = [sum(source[a] * Fraction(float(row[a * 3 + axis])) for a in range(3)) +
                 Fraction(float(row[9 + axis])) for axis in range(3)]
        point[1] += Fraction(float(case["grounding"][frame]))
        points.append(point)
    plane, result = Fraction(plane_u, 1024), []
    for first, last in P.rendered_intervals(case):
        a, b = points[first], points[last]
        if not (a[2] - uncertainty[2] > plane and b[2] + uncertainty[2] < plane):
            continue
        delta = a[2] - b[2]
        shares = [(a[2] - plane - uncertainty[2]) / delta, (a[2] - plane + uncertainty[2]) / delta]
        P.require(0 < shares[0] <= shares[1] < 1, "PLANTED_CROSSING")
        low, high = [], []
        for axis in (0, 1):
            ends = [(1 - share) * a[axis] + share * b[axis] for share in shares]
            lo, hi = (min(ends) - uncertainty[axis]) * 1024, (max(ends) + uncertainty[axis]) * 1024
            low.append(lo.numerator // lo.denominator)
            high.append(-(-hi.numerator // hi.denominator))
        share = (a[2] - plane) / delta
        result.append({"vertex": 148, "frame_pair": [first, last],
            "anchor_u": [round(((1-share)*a[axis] + share*b[axis])*1024) for axis in range(3)],
            "patch_u": [*low, plane_u, *high, plane_u], "residual_m": errors,
            "share_range": [P.envelope.fraction_record(x) for x in shares]})
    return result


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("analysis", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--depression-degrees", type=int, default=0)
    parser.add_argument("--ready-yaw-degrees", type=int, default=0)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "PLANTED_OUTPUT_EXISTS")
    producer_paths = (__file__, C.__file__, C.H.__file__, W.__file__, W.H.__file__, S.__file__,
                      P.__file__, P.content.__file__, P.envelope.__file__)
    producers = {str(Path(path).relative_to(P.ROOT)): P.content.file_hash(Path(path)) for path in producer_paths}
    invocation = W.read_record(args.analysis / "invocation.json")["command"]
    def value(key):
        return invocation[invocation.index("--" + key) + 1]
    proof = P.content.read_json(Path(value("proof")), value("proof-sha256"))
    plan = P.content.read_json(Path(value("plan")), value("plan-sha256"), 65536)
    original, pins, historical = W.extract_original(Path(value("source")), value("source-sha256"), proof, plan,
                                                    Path(value("import-archive")))
    parts = original[0]["geometry"]
    topology = P.read_topology(Path(value("topology")), value("topology-sha256"), value("content-sha256"), parts)
    rig = P.content.read_json(Path(value("topology")), value("topology-sha256"), P.MAX_TOPOLOGY_BYTES)
    down = S.read_image(args.analysis / "result/mole-worker.ugactor", C.DOWN_SHA, parts)
    carried = [compact_carry(dict(original[index], **down[index]), rig, args.ready_yaw_degrees) for index in (0, 1)]
    ready = carried[0]
    work = plant_work(ready, dict(original[-1], **down[6]), rig)
    work = depress_upper_arm(work, rig, args.depression_degrees)
    entry = planted_entry(ready, work, rig)
    recovery = P.indexed_sequence(entry, list(range(entry["frames"]-1, -1, -1)), "mole_worker.planted_front.recovery_v1", False)
    cases = carried + [dict(original[index], **down[index]) for index in range(2, 6)] + [work, entry, recovery]
    roots = plan["world_root_bounds_u"]
    report = {"schema": 1, "parent_image_sha256": C.DOWN_SHA, "recipe": work["planted_recipe"],
        "compact_ready": ready["compact_recipe"],
        "plane_z_u": -768, "requested_target_y_u": [-256, 768], "source_triangles_unchanged": True,
        "contact_candidates": tip_crossings(work, parts[1], roots, -768),
        "parts": {"work": P.continuous_floor(work, topology, roots), "entry": P.continuous_floor(entry, topology, roots)},
        "verified_source_files": pins, "historical_source_snapshot": historical, "production_qualified": False,
        "remaining": ["NATIVE_VISUAL_REVIEW", "FULL_SELF_CLEARANCE", "SOURCE_CONTACT_PATCH_REVIEW", "COMPLETE_STATE_UNION",
                      "REAL_STANCE_AND_PAID_APPROACH", "PROFILE_DRIVER_BINDING"]}
    report["foot_support"] = {}
    for name, case in (("work", work), ("entry", entry)):
        low, high, _, _ = C.H.vertex_corners(case, parts[0], 0, roots, Fraction(1))
        report["foot_support"][name] = C.foot_projection(parts[0], topology[0], low, high,
            report["parts"][name][0]["floor_intersection_u"])
    report["plane_portions"] = {name: [{"kind": part["kind"],
        "forward": W.H.plane_portion(case, part, topology[index], 0 if index == 0 else 24, roots, -768)}
        for index, part in enumerate(parts)] for name, case in (("work", work), ("entry", entry))}
    report["producer_sources"] = producers
    plan = dict(plan, revision=plan["revision"] + 4, clips=[case["id"] for case in cases])
    raw_plan = (json.dumps(plan, indent=2) + "\n").encode()
    raw_report = (json.dumps(report, indent=2) + "\n").encode()
    image, budget = P.content.encode(cases, plan, proof, C.DOWN_SHA, hashlib.sha256(raw_report).hexdigest(), hashlib.sha256(raw_plan).hexdigest())
    P.require(all(P.content.file_hash(P.ROOT / path) == digest for path, digest in producers.items()),
              "PLANTED_SOURCE_DRIFT")
    args.out.mkdir(parents=True)
    for name, data in (("candidate.json", raw_report), ("plan.json", raw_plan), ("mole-worker.ugactor", image)):
        with (args.out/name).open("xb") as stream:
            stream.write(data)
    (args.out/"compilation.json").write_text(json.dumps({"content_sha256": hashlib.sha256(image).hexdigest(),
        "content_bytes": len(image), "presentation_budget": budget, "production_qualified": False}, indent=2) + "\n")
    print(json.dumps({"contacts": report["contact_candidates"], "parts": report["parts"], "production_qualified": False}, indent=2))


if __name__ == "__main__":
    main()
