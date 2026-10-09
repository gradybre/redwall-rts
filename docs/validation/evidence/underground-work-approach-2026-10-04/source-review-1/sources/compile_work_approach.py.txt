#!/usr/bin/env python3
"""Compile complete fixed-heading walk/ready source geometry, never qualification bits."""
from __future__ import annotations

import argparse
import copy
from contextlib import contextmanager
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
CONTACT = HERE.parent / "evidence/contact-qualification"
SPEC = importlib.util.spec_from_file_location("accepted_approach_inputs", CONTACT / "source-gates-v3/renew_source_closure.py")
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)
G, M = A.G, A.G.M
P, C, N, S = M.P, M.C, M.N, M.S
ROOT = P.ROOT
ONE = 65536
READY_TIME = 8 * ONE
FADE_TIME = 15 * 32768
FORWARD = 1
BACKWARD = 2
SOURCE_WORK = 3
MAX_REPORT_BYTES = 4 * 1024 * 1024
ADAPTER_SHA = "1dcdbe1ea5e1a4ae1d097897cfd81dd0c7c821eae05ee78b6140cd2aa6b82272"
LOCATORS = HERE / "source-input-locators.json"
LOCATORS_SHA = "523cbfedbedc428b3763407cf44a6c689f7399a5d167bce188c5e8110e5c3b69"


def digest(path):
    return P.content.file_hash(path)


@contextmanager
def original_source_inputs():
    """Four additional exact old inputs, never replacements for current consumer verification."""
    A.exact_file(LOCATORS, LOCATORS_SHA)
    record = json.loads(LOCATORS.read_text())
    rows = record["rows"]
    P.require(record["source_commit"] == A.HISTORICAL_COMMIT and len(rows) == 4 and
              [row["path"] for row in rows] == ["res://scripts/core/work.gd",
                  "res://scripts/systems/settlement_system.gd", "res://scripts/systems/ui_manager.gd",
                  "res://scripts/ui/ui_world_session.gd"], "APPROACH_HISTORICAL_CENSUS")
    reader = M.I.M.W
    with A.same_source_inputs(reader):
        original = reader.snapshot_sources

        def snapshot(metadata, destination):
            pinned = [metadata["manifest"], *metadata["sources"]]
            P.require(len(pinned) <= 2049, "APPROACH_HISTORICAL_CAPACITY")
            for row in rows:
                matches = [old for old in pinned if old["path"] == row["path"]]
                P.require(matches and all(old["sha256"] == row["sha256"] for old in matches),
                          "APPROACH_HISTORICAL_PIN")
            blobs = [(row, A.historical_blob(row)) for row in rows]
            result = original(metadata, destination)
            for row, raw in blobs:
                target = destination / row["path"][6:]
                P.require(target.is_file() and not target.is_symlink() and
                          target.resolve().is_relative_to(destination.resolve()), "APPROACH_HISTORICAL_PATH")
                target.unlink()  # Original snapshot may hard-link a current input. Never write through it.
                with target.open("xb") as stream:
                    stream.write(raw)
                result[row["path"]] = {"commit": A.HISTORICAL_COMMIT, "sha256": row["sha256"],
                                       "git_object": row["git_object"]}
            return result

        try:
            reader.snapshot_sources = snapshot
            yield
        finally:
            reader.snapshot_sources = original


def sample_interval(count, duration, time, backward=False):
    """The exact Content loop equation, including its one-Q16-unit final WALK interval."""
    P.require(type(count) is int and 2 <= count <= P.MAX_SEQUENCE and type(duration) is int and
              (count - 2) * ONE < duration <= (count - 1) * ONE and
              type(time) is int and 0 <= time < (1 << 31) and type(backward) is bool,
              "APPROACH_PHASE_ARGUMENT")
    q = time % duration
    if backward:
        q = (duration - q) % duration
    final_start = (count - 2) * ONE
    if q >= final_start:
        return [count - 2, 0, (q - final_start) * ONE // (duration - final_start)]
    return [q // ONE, q // ONE + 1, q % ONE]


def interval_contract(case):
    """Retain each interval in both directions; source duration never comes from distance."""
    loop, duration = P.rendered_timing(case)
    P.require(loop == 1 and case["frames"] == 34 and duration == 2097153,
              "APPROACH_WALK_TIMING")
    intervals = P.rendered_intervals(case)
    forward = []
    for a, b in intervals:
        start = a * ONE
        end = min((a + 1) * ONE, duration)
        P.require(start < end and 0 <= a < case["frames"] and 0 <= b < case["frames"],
                  "APPROACH_INTERVAL")
        forward.append({"a": a, "b": b, "from_q16": start, "to_q16": end})
    backward = [{"a": row["b"], "b": row["a"],
                 "from_q16": duration - row["to_q16"], "to_q16": duration - row["from_q16"]}
                for row in reversed(forward)]
    P.require(forward[-1] == {"a": 32, "b": 0, "from_q16": 2097152, "to_q16": 2097153} and
              backward[0] == {"a": 0, "b": 32, "from_q16": 0, "to_q16": 1},
              "APPROACH_SHORT_SEAM")
    return {"clip": 1, "loop": loop, "keys": case["frames"], "duration_q16": duration,
            "forward": forward, "backward": backward,
            "sampling": "Content.clip_into(1, q % D) or Content.clip_into(1, (D - q % D) % D)",
            "root": "existing directed ground WALK distance; body heading fixed; backward path heading differs by32768",
            "time_reversal": "For every source phase q, backward uses the same finite pose as forward at(-q mod D); reversing root displacement reverses each foot/body/tool world trajectory.",
            "new_pace": False, "root_y_delta": 0}


def selected_handoffs(cases, proof):
    """Require the accepted full proof, then select actual ready/walk simplices without inventing joins."""
    expected = C.H.handoff_sets(cases)
    selected = [row for row in expected if row["from"] in ("ready", "walk")]
    checked = proof["carry_handoffs"]["checked"]
    result = []
    for row in selected:
        hits = [old for old in checked if all(old.get(key) == value for key, value in row.items())]
        P.require(len(hits) == 1, "APPROACH_HANDOFF_GAP")
        result.append(copy.deepcopy(hits[0]))
    P.require(len(result) == 34 and result[0]["from"] == "ready" and
              result[0]["interval"] == [8, 8] and result[0]["to"] == "walk-start" and
              result[-1]["interval"] == [32, 0] and result[-1]["to"] == "ready",
              "APPROACH_HANDOFF_CENSUS")
    return result


def whole_roles(cases, parts, topology, roots, basis):
    """Every complete body/tool triangle and actual foot projection survives in all required roles."""
    ready = P.indexed_sequence(cases[0], [8, 8], "approach_exact_ready", False)
    complete = C.H.case_union([cases[1], ready], (0, 1))
    cache = N.endpoint_cache(complete, parts, roots, basis)
    full = [P.outward_units(row["low"].min(axis=(0, 1)), row["high"].max(axis=(0, 1))) for row in cache]
    floor = []
    for row, triangles in zip(cache, topology):
        clipped = P.clipped_triangle_floor(np.stack([row["low"].min(axis=0)] * 2),
                                          np.stack([row["high"].max(axis=0)] * 2), triangles[0])
        floor.append(None if clipped is None else P.outward_units(np.array(clipped[:3]), np.array(clipped[3:])))
    P.require(len(full) == 2 and floor[0] is not None and floor[1] is None,
              "APPROACH_PRIMITIVE_FLOOR")
    stance = C.foot_projection(parts[0], topology[0], cache[0]["low"], cache[0]["high"], floor[0])
    body = [[full[0][0], 0, full[0][2], *full[0][3:]], floor[0], full[1]]
    roles = {"BODY_HELD_LOAD": body, "TURN_RECOVERY": copy.deepcopy(body),
             "STANCE_SUPPORT": [stance["support_u"]]}
    G.ground_coverage(body, stance["support_u"], roles)
    P.require(sum(map(len, roles.values())) == 7, "APPROACH_ROLE_CENSUS")
    return roles, {"full_primitives_u": full, "floor_primitives_u": floor, "stance": stance,
                   "corner_count": complete["frames"], "native_residual": [row["errors"] for row in cache],
                   "continuous_bound": "whole endpoint convex hull includes every triangle and every admitted matrix/ground fade"}


def work_joins(cases):
    """All four unchanged productive families start/end at the same actual ready palette and grounding."""
    result = []
    for work in (2, 5, 8, 11):
        entry, recovery = work + 1, work + 2
        P.require(C.same_pose(cases[0], 8, cases[entry], 0) and
                  C.same_pose(cases[entry], cases[entry]["frames"] - 1, cases[work], 0) and
                  C.same_pose(cases[work], 0, cases[recovery], 0) and
                  C.same_pose(cases[recovery], cases[recovery]["frames"] - 1, cases[0], 8),
                  "APPROACH_WORK_JOIN")
        result.append({"work": work, "entry": entry, "recovery": recovery, "ready_clip": 0,
                       "ready_time_q16": READY_TIME, "palette_and_grounding_identical": True})
    return result


def retained_census():
    """Joint current Profile/Level/Motion/Session coexistence; not an independent-max or native claim."""
    profiles, boxes, sources = 26, 250, 1
    paired = 2 * (98 * profiles + 28 * boxes + 32 * sources + 32)
    terms = {"paired_profiles": paired, "profile_controls": 32768, "levels": 2292,
             "paired_motion": 141720, "decode": 4096, "motion_caller": 176,
             "motion_helpers": 4096, "motion_native_provisional": 32768, "session": 1536}
    total = sum(terms.values())
    P.require(paired == 19224 and total == 238676 and total <= 262144, "APPROACH_JOINT_CAPACITY")
    return {"profile_count": profiles, "box_count": boxes, "source_count": sources,
            "terms": terms, "total": total, "reservation": 262144, "remaining": 262144 - total,
            "paired_delta": paired - 14520, "actor_image_delta": 0,
            "used_pace_rows": 8, "pace_bytes_within_existing_banks": 576,
            "driver_and_routes_retained_delta_pending_census": True, "native_measured": False}


def compile_approach():
    """Root publication hook: reconstruct exact input sources before returning additive rows, never bits."""
    P.require(digest(Path(A.__file__)) == ADAPTER_SHA, "APPROACH_INPUT_ADAPTER")
    basis_path = ROOT / "godot/demo/assets/underground-matrices/world-yaw-v1.ugyaw"
    with original_source_inputs():
        sources = M.input_pins(basis_path)
        cases, parts, rig, topology, roots, count, historical, _ = M.source_program()
        P.require(M.input_pins(basis_path) == sources, "APPROACH_INPUT_DRIFT")
    prior_path = CONTACT / "compact-program-source-v1/mole-worker.ugactor"
    prior = S.read_image(prior_path, G.GROUND_SOURCE_SHA, parts)
    G.same_ground_sources(cases, prior)
    proof_path = CONTACT / "compact-program-proof-v1.json"
    proof = P.content.read_json(proof_path, G.GROUND_PROOF_SHA, 1048576)
    M.Q.producer_refusal(proof)
    with basis_path.open("rb") as stream:
        inverse = C.H.InverseHeading(stream, M.BASIS_SHA, M.BASIS_PRODUCER)
    ids, omitted = S.body_triangle_ids(parts[0], topology[0][0], rig["rig_binding"])
    G.handoff_refusal(proof, cases, inverse, (len(ids), len(topology[1][0]), omitted))
    with basis_path.open("rb") as stream:
        basis = N.CardinalBasis(stream, M.BASIS_SHA, M.BASIS_PRODUCER)
    roles, geometry = whole_roles(cases, parts, topology, roots, basis)
    rows = []
    for policy in (FORWARD, BACKWARD):
        for heading, yaw in enumerate(N.YAWS):
            rows.append({"profile": 2 + (policy - 1) * 4 + heading, "selection_policy": policy,
                         "mode": 1, "posture": 0, "yaw_kind": 0, "yaw": yaw,
                         "path_yaw": (yaw + (32768 if policy == BACKWARD else 0)) % 65536,
                         "roles": {role: [N.orient_box(box, heading) for box in values]
                                   for role, values in roles.items()}})
    producer = M.producer_pins() | {str(Path(__file__).relative_to(ROOT)): digest(Path(__file__)),
                                  str(Path(A.__file__).relative_to(ROOT)): ADAPTER_SHA,
                                  str(Path(G.__file__).relative_to(ROOT)): digest(Path(G.__file__))}
    sources.update({str(prior_path.relative_to(ROOT)): G.GROUND_SOURCE_SHA,
                    str(proof_path.relative_to(ROOT)): G.GROUND_PROOF_SHA,
                    str(A.LOCATORS.relative_to(ROOT)): A.LOCATORS_SHA,
                    str(LOCATORS.relative_to(ROOT)): LOCATORS_SHA})
    return {"schema": 1, "source_program": 5, "actor_sha256": M.IMAGE_SHA,
            "source_program_sha256": M.PROGRAM_SHA, "ready_clip": 0, "ready_time_q16": READY_TIME,
            "fade_time_q16": FADE_TIME, "clip_timing": [{"loop": P.rendered_timing(case)[0],
                "duration_q16": P.rendered_timing(case)[1], "keys": case["frames"]} for case in cases],
            "walk": interval_contract(cases[1]), "handoffs": selected_handoffs(cases, proof),
            "work_joins": work_joins(cases), "canonical_roles": roles, "geometry": geometry,
            "rows": rows, "basis": basis.cardinal_certificate(), "root_domain_u": roots,
            "verified_source_files": count, "historical_source_snapshot": historical,
            "source_inputs": sources, "producer_sources": producer, "census": retained_census(),
            "certificate_bits_written": 0, "native_replay": False, "production_qualified": False,
            "remaining": ["CANONICAL_ROUTES_SOURCE_CLOCK", "CURRENT_CONSUMER_CLOSURE", "NATIVE_BACKWARD_ROOT_REPLAY",
                          "INDEPENDENT_REVIEW", "QUALIFIED_PUBLICATION", "ACTUAL_PAID_ROOM_APPROACH_AND_RETREAT"]}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "APPROACH_OUTPUT_EXISTS")
    result = compile_approach()
    raw = (json.dumps(result, indent=2) + "\n").encode()
    P.require(len(raw) <= MAX_REPORT_BYTES, "APPROACH_REPORT_CAPACITY")
    for key in ("source_inputs", "producer_sources"):
        P.require(all(digest(ROOT / path) == sha for path, sha in result[key].items()), "APPROACH_SOURCE_DRIFT")
    args.out.mkdir(parents=True)
    with (args.out / "approach-program.json").open("xb") as output:
        output.write(raw)
    print(json.dumps({"profiles": len(result["rows"]), "boxes": sum(sum(map(len, row["roles"].values())) for row in result["rows"]),
                      "verified_source_files": result["verified_source_files"], "joint_bytes": result["census"]["total"],
                      "certificate_bits_written": 0, "production_qualified": False}))


if __name__ == "__main__":
    main()
