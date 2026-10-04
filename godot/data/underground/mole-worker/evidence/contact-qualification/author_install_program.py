#!/usr/bin/env python3
"""Compose the accepted INSTALL source with the compact hub; never emit production permission."""
from fractions import Fraction
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import struct

import numpy as np

HERE = Path(__file__).resolve().parent


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


I = module("install_source_program", "author_install_source.py")
Q = module("compact_source_program", "compile_compact_program.py")
M, P, S, C = I.M, I.P, I.M.S, I.M.C
COMPACT = HERE / "compact-program-compile-v2/result"
INSTALL = HERE / "install-source-v4"
INSTALL_SHA = "cae2e9b210ce1019153b298c8f98504683f080a150c66d030d113d18b4b678e9"
PROOF_SHA = "a5685deb7d65ec524548f717b3d425d38bbd4a9d2b181425205ca4bfcbb0cbbd"
ROLES_SHA = "84cf43a446a6e5d42d9bc2c0398caea681dcaa46bdf0491320346d4c6ddf80c6"
PROGRAM_SHA = "22d25b7a0f542c86ed75e22c71b4f076eed7423ac46a756bf9e58c72aca1df2f"
CONSUMER_SHA = "39025061a4852c791bdeed9257d70ab983972573708d71564913552541c3ca8d"
NAMES = (*Q.D.NAMES, "install_work", "install_entry", "install_recovery")
PROFILE_NAMES = (*Q.PROFILE_NAMES, "install")
ROLE_NAMES = {"BODY_HELD_LOAD", "STANCE_SUPPORT", "TURN_RECOVERY", "WORK_APPROACH",
              "WORK_STROKE", "CONTACT_POINT", "CONTACT_PATCH"}
MAX_PINS = 2048
CONSUMERS = ("underground_profiles", "underground_work_face", "underground_connector_contacts",
             "underground_routes", "underground_world_routes")


def checked_pins(pins):
    """An accepted report cannot survive a missing or changed producer/input, even when its flag is true."""
    P.require(type(pins) is dict and 0 < len(pins) <= MAX_PINS, "INSTALL_PROGRAM_PIN_CENSUS")
    for name, digest in pins.items():
        P.require(type(name) is str and type(digest) is str and len(digest) == 64,
                  "INSTALL_PROGRAM_PIN_SHAPE")
        path = (P.ROOT / name).resolve()
        P.require(path.is_relative_to(P.ROOT) and path.is_file() and P.content.file_hash(path) == digest,
                  "INSTALL_PROGRAM_SOURCE_DRIFT")


def image_metadata(directory, digest, source_file, proof_file):
    """Read the same finite image's exact embedded JSON digests before trusting its source records."""
    image = directory / "mole-worker.ugactor"
    P.require(image.is_file() and 184 <= image.stat().st_size <= 4 * P.content.MAX_SCALARS + 8192,
              "INSTALL_PROGRAM_IMAGE_CAPACITY")
    P.require(P.content.file_hash(image) == digest, "INSTALL_PROGRAM_IMAGE_SOURCE")
    with image.open("rb") as stream:
        header = stream.read(184)
    P.require(header[:8] == b"UGACNT01" and struct.unpack_from("<I", header, 8)[0] == 1,
              "INSTALL_PROGRAM_IMAGE_HEADER")
    source = P.content.read_json(directory / source_file, header[88:120].hex(), 1048576) if source_file else None
    proof = P.content.read_json(directory / proof_file, header[120:152].hex(), 1048576)
    plan = P.content.read_json(directory / "plan.json", header[152:184].hex(), 65536)
    P.require(list(struct.unpack_from("<6i", header, 32)) == plan["world_root_bounds_u"],
              "INSTALL_PROGRAM_ROOTS")
    return source, proof, plan


def consumer_contract():
    """Only the exact reviewed mandatory-BODY consumers may interpret this shared phase partition.

    This is a compile-time source contract, not runtime attestation. A changed
    consumer requires a new review and this digest must change; production
    binding must still compare its actual loaded consumers with these pins.
    """
    value = P.content.read_json(HERE / "install-program-consumers-v1/contract.json", CONSUMER_SHA, 65536)
    P.require(value.get("schema") == 1 and value.get("production_qualified") is False and
              type(value.get("consumer_sources")) is list and len(value["consumer_sources"]) == len(CONSUMERS),
              "INSTALL_PROGRAM_CONSUMER_CENSUS")
    for name, row in zip(CONSUMERS, value["consumer_sources"]):
        expected = HERE / "install-program-consumers-v1" / (name + ".gd.txt")
        P.require(row.get("source") == "godot/scripts/core/" + name + ".gd" and
                  row.get("snapshot") == str(expected.relative_to(P.ROOT)) and
                  expected.is_file() and P.content.file_hash(expected) == row.get("sha256"),
                  "INSTALL_PROGRAM_CONSUMER_BODY_CONTRACT")
    return value


def equivalent_rendered_edges(previous, current):
    """A looping tap is legal only when every emitted native endpoint and timing is exactly the proved one."""
    before, after = P.rendered_intervals(previous), P.rendered_intervals(current)
    P.require(previous["frames"] == current["frames"] and len(before) == len(after) and
              P.rendered_timing(previous)[1] == P.rendered_timing(current)[1], "INSTALL_PROGRAM_EDGE_TIMING")
    for old, new in zip(before, after):
        P.require(all(C.same_pose(previous, a, current, b) for a, b in zip(old, new)),
                  "INSTALL_PROGRAM_EDGE_SOURCE")
    return [{"proved": list(old), "rendered": list(new)} for old, new in zip(before, after)]


def check_program(cases):
    """One exact hub, stable old roles and a separately bound INSTALL triple; no instant source switch."""
    P.require(len(cases) == 14, "INSTALL_PROGRAM_CLIP_CENSUS")
    Q.D.check_program(cases[:11])
    for at in (11, 12, 13):
        loop, duration = P.rendered_timing(cases[at])
        P.require(loop == int(at == 11) and duration > 0, "INSTALL_PROGRAM_TIMING")
    P.require(C.same_pose(cases[0], 8, cases[12], 0) and
              C.same_pose(cases[12], cases[12]["frames"] - 1, cases[11], 0) and
              C.same_pose(cases[11], 0, cases[11], cases[11]["frames"] - 1), "INSTALL_PROGRAM_ENDPOINT")
    P.require(S.reusable_timing(cases[13], cases[12], True) and
              cases[13]["matrices"].tobytes() == cases[12]["matrices"][::-1].tobytes() and
              cases[13]["grounding"].tobytes() == cases[12]["grounding"][::-1].tobytes(),
              "INSTALL_PROGRAM_RECOVERY")
    P.require(sum(case["frames"] for case in cases) <= P.content.MAX_FRAMES, "INSTALL_PROGRAM_FRAME_CAPACITY")


def assemble(compact, install, names):
    P.require(len(compact) == 11 and len(install) == 3 and len(names) == 14, "INSTALL_PROGRAM_CLIP_CENSUS")
    cases = [dict(case, id=names[at]) for at, case in enumerate([*compact, *install])]
    P.require(P.rendered_timing(install[0])[0] == 0, "INSTALL_PROGRAM_PROVED_WORK_TIMING")
    cases[11]["source_loop_mode"] = 1
    edges = equivalent_rendered_edges(install[0], cases[11])
    check_program(cases)
    P.require(all(Q.same_source(old, new) for old, new in zip(compact, cases[:11])),
              "INSTALL_PROGRAM_OLD_SOURCE_DRIFT")
    return cases, edges


def source_proof_refusal(record, cases, topology, roots):
    """Require complete bounded body/tool/foot/fixture proof, not a sampled success or missing primitive set."""
    census = [sum(len(surface) for surface in rows) for rows in topology]
    P.require(len(cases) == 3 and len(census) == 2 and record.get("schema") == 1 and
              record.get("content_sha256") == INSTALL_SHA and record.get("source_local_yaw0_candidate_clear") is True and
              record.get("production_qualified") is False and record.get("native_domain_roots_u") == roots and
              set(record.get("self", {})) == set(record.get("world", {})) == set(record.get("local", {})) == {"0", "1", "2"},
              "INSTALL_PROGRAM_PROOF_CENSUS")
    for at, case in enumerate(cases):
        key = str(at)
        row = record["self"][key]
        Q.interval_refusal(row, case)
        P.require(row["body_triangles"] + row["intentional_grip_triangles"] == census[0] and
                  row["tool_triangles"] == census[1] and row["pairs"] > 0, "INSTALL_PROGRAM_PRIMITIVE_CENSUS")
        P.require(len(record["local"][key]) == 2 and len(record["world"][key]) == 2,
                  "INSTALL_PROGRAM_PRIMITIVE_CENSUS")
        for part, local in enumerate(record["local"][key]):
            P.require(local["native_triangles"] == census[part] and local["exact_yaw"] == 0 and
                      local["rendered_edges"] == [list(edge) for edge in P.rendered_intervals(case)] and
                      local["loop_mode"] == 0 and local["duration_q16"] == P.rendered_timing(case)[1],
                      "INSTALL_PROGRAM_PRIMITIVE_CENSUS")
        for world in record["world"][key]:
            P.require(world["clear"] is True and world["unresolved"] == [] and world["primitive_census"] == census and
                      world["target_is_worker_support"] is False and world["intervals"] == len(P.rendered_intervals(case)) and
                      len(world["supports"]) == 2 * world["intervals"], "INSTALL_PROGRAM_WORLD_PROOF")
            for interval in range(world["intervals"]):
                feet = world["supports"][2 * interval:2 * interval + 2]
                P.require([row["foot"] for row in feet] == [0, 1] and
                          all(row["interval"] == interval and row["full_projection_inside"] is True and
                              row["source_above"] is True for row in feet) and
                          any(row["source_contact_vertex"] >= 0 for row in feet), "INSTALL_PROGRAM_SUPPORT_PROOF")
    P.require(record["self"]["2"].get("reused_exact_reverse_clip") == 1 and
              Q.same_source(cases[2], P.indexed_sequence(cases[1], list(range(cases[1]["frames"] - 1, -1, -1)),
                                                       "installation_exact_reverse", False)), "INSTALL_PROGRAM_RECOVERY")


def part_below_plane(case, part, triangles, roots, offset=0, plane_u=128):
    """Enclose every whole primitive below the workpiece top; retain the complementary upper region."""
    P.require(((part["kind"] == "body" and part["binds"] == 24 and offset == 0) or
               (part["kind"] == "attachment" and part["binds"] == 0 and offset == 24)) and
              len(part["geometry"]) == 1 and plane_u == 128,
              "INSTALL_PROGRAM_BODY_PARTITION")
    matrices = case["matrices"][:, offset:offset + max(1, part["binds"])]
    whole = P._vertex_hulls(part, matrices, case["grounding"])
    padding, residual = P._residual_padding(part, matrices, case["grounding"], roots, whole)
    first = P._vertex_hulls(part, matrices[:1], case["grounding"][:1])[0]
    previous, boxes = first, []
    intervals = P.rendered_intervals(case)
    for _, frame in intervals:
        current = first if frame == 0 else P._vertex_hulls(part, matrices[frame:frame + 1], case["grounding"][frame:frame + 1])[0]
        clipped = P.clipped_triangle_floor(np.stack([previous[0], current[0]]) - padding,
                                          np.stack([previous[1], current[1]]) + padding,
                                          triangles, plane_u * (P.SCALE // 1024))
        if clipped is not None:
            boxes.append(clipped)
        previous = current
    P.require(bool(boxes), "INSTALL_PROGRAM_BODY_PARTITION_EMPTY")
    minimum = np.array([min(box[a] for box in boxes) for a in range(3)], dtype=np.int64)
    maximum = np.array([max(box[a] for box in boxes) for a in range(3, 6)], dtype=np.int64)
    return {"bounds_u": P.outward_units(minimum, maximum), "plane_u": plane_u,
            "native_triangles": len(triangles), "rendered_edges": [list(edge) for edge in intervals],
            "residual_m": residual, "complement": "all original part geometry at or above the exact same plane"}


def role_refusal(roles, common_floor):
    """Every consumer-visible part of the complete INSTALL program must survive serialization."""
    P.require(set(roles) == ROLE_NAMES and all(type(rows) is list and rows for rows in roles.values()) and
              sum(len(rows) for rows in roles.values()) <= 12, "INSTALL_PROGRAM_ROLE_CENSUS")
    P.require(common_floor is not None and len(common_floor) == 6 and common_floor[1] < common_floor[4] == 0 and
              common_floor in roles["BODY_HELD_LOAD"], "INSTALL_PROGRAM_COMMON_FLOOR_MISSING")
    for role, rows in roles.items():
        for box in rows:
            P.require(len(box) == 6 and all(type(v) is int and abs(v) <= 2097152 for v in box), "INSTALL_PROGRAM_ROLE_BOX")
            if role not in ("CONTACT_POINT", "CONTACT_PATCH"):
                P.require(all(box[a] < box[a + 3] for a in range(3)), "INSTALL_PROGRAM_ROLE_BOX")
    P.require(len(roles["CONTACT_POINT"]) == len(roles["CONTACT_PATCH"]) == 1 and
              roles["CONTACT_POINT"][0][:3] == roles["CONTACT_POINT"][0][3:], "INSTALL_PROGRAM_CONTACT_CENSUS")
    Q.contact_refusal({"anchor_u": roles["CONTACT_POINT"][0][:3], "patch_u": roles["CONTACT_PATCH"][0]}, 1, 128)


def compile_install_roles(proof, ready, partition):
    """Body/recovery/approach never inherit the active adze's strictly bounded workpiece exception."""
    work, entry = proof["local"]["0"], proof["local"]["1"]
    P.require(len(work) == len(entry) == len(ready) == 2 and
              all(row[0]["kind"] == "body" and row[1]["kind"] == "attachment" for row in (work, entry, ready)),
              "INSTALL_PROGRAM_PRIMITIVE_CENSUS")
    low = partition["bounds_u"]
    P.require(partition["native_triangles"] == entry[0]["native_triangles"] and low[4] == 128 and
              entry[1]["full_bounds_u"][1] > 128 and entry[1]["floor_intersection_u"] is None and
              ready[1]["floor_intersection_u"] is None, "INSTALL_PROGRAM_BODY_PARTITION")
    body, arrival = C.body_boxes(work[0]), C.body_boxes(ready[0])
    common_floor = body[1]
    P.require(common_floor == entry[0]["floor_intersection_u"] == ready[0]["floor_intersection_u"] ==
              proof["local"]["2"][0]["floor_intersection_u"], "INSTALL_PROGRAM_COMMON_FLOOR_DRIFT")
    full = entry[0]["full_bounds_u"]
    # BODY is mandatory in every actual contact/collision consumer. The exact
    # same planted sole residue is stored once there for the complete program;
    # remaining recovery/arrival portions cover Y>=0 without a duplicated row.
    recovery = [[low[0], 0, low[2], *low[3:]],
                C.union([[full[0], 128, full[2], *full[3:]], entry[1]["full_bounds_u"]])]
    ready_full = ready[0]["full_bounds_u"]
    approach = [[low[0], 0, low[2], *low[3:]],
                C.union([[ready_full[0], 128, ready_full[2], *ready_full[3:]], ready[1]["full_bounds_u"]])]
    source_foot_boxes = [row["full_foot_bounds_u"] for clip in ("0", "1") for row in proof["world"][clip][0]["supports"]]
    P.require(0 < len(source_foot_boxes) <= 4 * P.MAX_SEQUENCE, "INSTALL_PROGRAM_SUPPORT_CENSUS")
    # Reduce in fixed batches: the shared union helper deliberately caps each input batch at64.
    feet = C.union([C.union(source_foot_boxes[at:at + 64]) for at in range(0, len(source_foot_boxes), 64)])
    floor = C.union([row["floor_intersection_u"] for row in (work[0], entry[0], ready[0])])
    support = [feet[0], floor[1], feet[2], feet[3], 0, feet[5]]
    P.require(all(support[a] <= floor[a] <= floor[a + 3] <= support[a + 3] for a in range(3)),
              "INSTALL_PROGRAM_SUPPORT_PROOF")
    below = proof["below_target_plane"]["0"]["bounds_u"]
    tool = work[1]["full_bounds_u"]
    P.require(below is not None and below[4] == 128 and below[1] > 0 and tool[4] > 128,
              "INSTALL_PROGRAM_ACTIVE_ADZE")
    contact = proof["contacts"][0]
    roles = {"BODY_HELD_LOAD": body, "STANCE_SUPPORT": [support], "TURN_RECOVERY": recovery,
             "WORK_APPROACH": approach,
             "WORK_STROKE": [below, [tool[0], 128, tool[2], *tool[3:]]],
             "CONTACT_POINT": [contact["anchor_u"] * 2], "CONTACT_PATCH": [contact["patch_u"]]}
    role_refusal(roles, common_floor)
    for fixture in proof["fixture_prisms"]:
        target = fixture["solids_u"][fixture["workpiece_solid"]]
        P.require(all(target[a] <= below[a] <= below[a + 3] <= target[a + 3] for a in range(3)),
                  "INSTALL_PROGRAM_ACTIVE_ADZE_ESCAPES")
        for role in ("BODY_HELD_LOAD", "TURN_RECOVERY", "WORK_APPROACH"):
            P.require(all(not all(box[a] < target[a + 3] and target[a] < box[a + 3] for a in range(3))
                          for box in roles[role]), "INSTALL_PROGRAM_NONPRODUCTIVE_TARGET_COLLISION")
    return roles


def coverage_refusal(obligations, roles, common_floor):
    """Every complete primitive-side enclosure must fit its named mandatory role, not another exception."""
    role_refusal(roles, common_floor)
    P.require(set(obligations) == {"ready", "entry", "work", "recovery"}, "INSTALL_PROGRAM_PHASE_CENSUS")
    for phase, rows in obligations.items():
        expected = {"complete body below Y0": "BODY_HELD_LOAD"}
        if phase == "work":
            expected.update({"complete body above Y0": "BODY_HELD_LOAD", "complete active adze below Y128": "WORK_STROKE",
                             "complete active adze above Y128": "WORK_STROKE"})
        else:
            role = "WORK_APPROACH" if phase == "ready" else "TURN_RECOVERY"
            expected.update({"complete body in Y[0,128]": role, "complete body above Y128": role, "complete held tool": role})
        P.require(len(rows) == 4 and {row["part"]: row["role"] for row in rows} == expected,
                  "INSTALL_PROGRAM_COVERAGE_CENSUS")
        for row in rows:
            role, box = row["role"], row["bounds_u"]
            P.require(role in ROLE_NAMES and box is not None and
                      any(all(outer[a] <= box[a] <= box[a + 3] <= outer[a + 3] for a in range(3))
                          for outer in roles[role]), "INSTALL_PROGRAM_PRIMITIVE_ROLE_GAP")
        P.require(any(row["role"] == "BODY_HELD_LOAD" and row["bounds_u"] == common_floor for row in rows),
                  "INSTALL_PROGRAM_COMMON_FLOOR_MISSING")


def phase_coverage(cases, parts, topology, roots, roles, original_proof):
    """Recompute all original indices at every rendered edge in each phase, including the loop's actual close."""
    ready = P.indexed_sequence(cases[0], [8, 8], "install_ready_coverage", False)
    phases = {"ready": ready, "entry": cases[12], "work": cases[11], "recovery": cases[13]}
    common_floor = roles["BODY_HELD_LOAD"][1]
    obligations, records = {}, {}
    census = [sum(len(surface) for surface in surfaces) for surfaces in topology]
    P.require(census == original_proof["world"]["0"][0]["primitive_census"] and
              len(parts) == len(topology) == 2 and all(len(surface) == 1 for surface in topology),
              "INSTALL_PROGRAM_PRIMITIVE_CENSUS")
    for phase, case in phases.items():
        current = P.continuous_floor(case, topology, roots)
        P.require(current[0]["floor_intersection_u"] == common_floor and current[1]["floor_intersection_u"] is None,
                  "INSTALL_PROGRAM_COMMON_FLOOR_DRIFT")
        rows = [{"role": "BODY_HELD_LOAD", "bounds_u": common_floor, "part": "complete body below Y0"}]
        partitions = []
        if phase == "work":
            rows.append({"role": "BODY_HELD_LOAD", "bounds_u": current[0]["above_floor_u"], "part": "complete body above Y0"})
            partition = part_below_plane(case, parts[1], topology[1][0], roots, 24)
            partitions.append(partition)
            tool = current[1]["full_bounds_u"]
            rows.extend(({"role": "WORK_STROKE", "bounds_u": partition["bounds_u"], "part": "complete active adze below Y128"},
                         {"role": "WORK_STROKE", "bounds_u": [tool[0], 128, tool[2], *tool[3:]], "part": "complete active adze above Y128"}))
        else:
            role = "WORK_APPROACH" if phase == "ready" else "TURN_RECOVERY"
            partition = part_below_plane(case, parts[0], topology[0][0], roots)
            partitions.append(partition)
            low, full = partition["bounds_u"], current[0]["full_bounds_u"]
            rows.extend(({"role": role, "bounds_u": [low[0], 0, low[2], *low[3:]], "part": "complete body in Y[0,128]"},
                         {"role": role, "bounds_u": [full[0], 128, full[2], *full[3:]], "part": "complete body above Y128"},
                         {"role": role, "bounds_u": current[1]["full_bounds_u"], "part": "complete held tool"}))
        obligations[phase] = rows
        records[phase] = {"complete_primitives": census, "intervals": len(P.rendered_intervals(case)),
                          "rendered_edges": [list(edge) for edge in P.rendered_intervals(case)],
                          "local_enclosures": current, "partitions": partitions}
        print("install-program-coverage " + phase, flush=True)
    coverage_refusal(obligations, roles, common_floor)
    return {"clear": True, "obligations": obligations, "phases": records,
            "topology_sha256": [hashlib.sha256(surface[0].astype("<i8").tobytes()).hexdigest() for surface in topology],
            "proof": "All complete source triangles are consumed by the endpoint hull and exact plane-clipped relaxation; no primitive or interval is dropped."}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "INSTALL_PROGRAM_OUTPUT_EXISTS")
    consumers = consumer_contract()
    producers = {str(Path(path).relative_to(P.ROOT)): P.content.file_hash(Path(path)) for path in
                 (__file__, I.__file__, M.__file__, Q.__file__, Q.D.__file__, Q.A.__file__, C.__file__, C.H.__file__,
                  M.W.__file__, M.W.H.__file__, S.__file__, P.__file__, P.content.__file__, P.envelope.__file__)}
    inputs = {str(path.relative_to(P.ROOT)): P.content.file_hash(path) for path in
              [*(COMPACT / name for name in ("program.json", "roles.json", "plan.json", "mole-worker.ugactor")),
               *(INSTALL / name for name in ("candidate.json", "plan.json", "mole-worker.ugactor")),
               HERE / "install-source-proof-v4/proof.json", HERE / "install-program-consumers-v1/contract.json",
               *(P.ROOT / row["snapshot"] for row in consumers["consumer_sources"])]}
    old_program, old_roles, old_plan = image_metadata(COMPACT, M.COMPACT_SHA, "program.json", "roles.json")
    _, candidate, install_plan = image_metadata(INSTALL, INSTALL_SHA, None, "candidate.json")
    P.require(P.content.file_hash(COMPACT / "roles.json") == ROLES_SHA and
              P.content.file_hash(COMPACT / "program.json") == PROGRAM_SHA, "INSTALL_PROGRAM_PRIOR_IDENTITY")
    proof = P.content.read_json(HERE / "install-source-proof-v4/proof.json", PROOF_SHA, 1048576)
    for pins in (old_roles["producer_sources"], old_roles["input_sources"], candidate["producer_sources"], proof["source_pins"]):
        checked_pins(pins)
    compact, parts, rig, topology, roots, source_count, historical = M.read_actual_source()
    install = S.read_image(INSTALL / "mole-worker.ugactor", INSTALL_SHA, parts)
    recipe = candidate["source_recipe"]
    expected = I.source_motion(compact[0], parts[1], rig, *recipe["poll_xz_u"], recipe["lean_degrees"], recipe["azimuth_degrees"])[:3]
    P.require(all(Q.same_source(a, b) for a, b in zip(install, expected)) and len(install) == len(expected) == 3 and
              roots == install_plan["world_root_bounds_u"] == old_plan["world_root_bounds_u"], "INSTALL_PROGRAM_SOURCE_EQUATION")
    for case in [*compact, *install]:
        case["geometry"] = parts
    source_proof_refusal(proof, install, topology, roots)
    names = old_plan["clips"] + install_plan["clips"]
    cases, edges = assemble(compact, install, names)
    partition = part_below_plane(install[1], parts[0], topology[0][0], roots)
    install_roles = compile_install_roles(proof, old_roles["ready"], partition)
    coverage = phase_coverage(cases, parts, topology, roots, install_roles, proof)
    program = dict(old_program, schema=3, program_version=3, clips=list(NAMES),
                   profile_roles=dict(zip(PROFILE_NAMES, range(6))), productive_source=[2, 5, 8, 11],
                   entry_source=[3, 6, 9, 12], recovery_source=[4, 7, 10, 13],
                   install_target="actual paid WIP bearer only; source candidate is not runtime publication")
    report = {"schema": 3, "roles": dict(copy.deepcopy(old_roles["roles"]), install=install_roles),
              "source_matrices_timing_grounding_rederived": True, "old_roles_and_source_values_preserved": True,
              "install_proof_sha256": PROOF_SHA, "install_loop_edge_equivalence": edges,
              "entry_body_plane_partition": partition, "install_contact": proof["contacts"],
              "complete_install_phase_coverage": coverage, "mandatory_body_consumer_contract": consumers,
              "install_phase_partition": {"common_planted_floor": {"role": "BODY_HELD_LOAD",
                  "bounds_u": install_roles["BODY_HELD_LOAD"][1], "phases": ["ready", "entry", "work", "recovery"],
                  "proof": "Exact same full-triangle numerical sole enclosure in all four sources; mandatory BODY role always participates."},
                  "productive_body_above_floor": "BODY_HELD_LOAD", "entry_and_recovery_above_floor": "TURN_RECOVERY",
                  "ready_body_and_held_tool_above_floor": "WORK_APPROACH", "productive_active_adze": "WORK_STROKE"},
              "source_primitive_census": [sum(len(rows) for rows in surfaces) for surfaces in topology],
              "verified_source_files": source_count, "historical_source_snapshot": historical,
              "producer_sources": producers, "input_sources": inputs, "production_qualified": False,
              "scope": "source-local yaw0 INSTALL with complete unchanged compact source program; no actual handling or runtime target",
              "remaining": ["INDEPENDENT_INSTALL_PROGRAM_REVIEW", "NATIVE_V3_DRIVER", "PROFILE_CERTIFICATE_BINDING",
                            "ACTUAL_PAID_WIP_AND_CARRY_LAY_HANDLING", "ACTUAL_SUPPORT_TARGET_AND_RETREAT", "PRESENTATION_PEAK"]}
    plan = {"revision": 106, "world_root_bounds_u": roots, "clips": names}
    raw_program, raw_report, raw_plan = [(json.dumps(row, indent=2) + "\n").encode() for row in (program, report, plan)]
    command = M.W.read_record(HERE / "analysis-carry-arm-v7/invocation.json")["command"]
    original_proof = P.content.read_json(Path(command[command.index("--proof") + 1]), command[command.index("--proof-sha256") + 1])
    image, budget = P.content.encode(cases, plan, original_proof, hashlib.sha256(raw_program).hexdigest(),
                                    hashlib.sha256(raw_report).hexdigest(), hashlib.sha256(raw_plan).hexdigest())
    for pins in (producers, inputs, old_roles["producer_sources"], old_roles["input_sources"], candidate["producer_sources"], proof["source_pins"]):
        checked_pins(pins)
    args.out.mkdir(parents=True)
    for name, raw in (("mole-worker.ugactor", image), ("program.json", raw_program), ("roles.json", raw_report), ("plan.json", raw_plan)):
        with (args.out / name).open("xb") as stream:
            stream.write(raw)
    compiled = {"content_sha256": hashlib.sha256(image).hexdigest(), "content_bytes": len(image),
                "frames": sum(case["frames"] for case in cases), "clips": len(cases), "presentation_budget": budget,
                "driver_maximum_packed_bytes": 432, "driver_growth_bytes": 36, "production_qualified": False}
    (args.out / "compilation.json").write_text(json.dumps(compiled, indent=2) + "\n")
    print(json.dumps(dict(compiled, install_roles=install_roles), indent=2), flush=True)


if __name__ == "__main__":
    main()
