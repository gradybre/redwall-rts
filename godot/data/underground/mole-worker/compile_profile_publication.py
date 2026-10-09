#!/usr/bin/env python3
"""Compile source-bound cardinal mole profile proofs; unclosed native gates never emit certificate bits."""
from __future__ import annotations

import argparse
import copy
from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import types

import numpy as np

HERE = Path(__file__).resolve().parent
EVIDENCE = HERE / "evidence/contact-qualification"
SPEC = importlib.util.spec_from_file_location("cardinal_source_proof", EVIDENCE / "prove_cardinal_profiles.py")
N = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(N)
I, P, C, S, Q = N.I, N.P, N.C, N.S, N.Q
IMAGE_DIR = EVIDENCE / "install-program-compile-v3/result"
IMAGE_SHA = "adc617642313ac004c050d4877ef0b9f4024bb9c88e3ea92ce9a924471bd5ab9"
ROLES_SHA = "0f2da835a381460231c1560ea116fa3aafd51d32a4f3185f25b11b782bd4fd83"
PROGRAM_SHA = "5caaec976eb3f8995784dc5f8d98cdb6c233020372d87964620b0da1c4e41c6e"
PLAN_SHA = "ffdebb3cbacafab9766679cc5b7bd0894c80e6e3499ab91a1e3d225bf8991ee2"
BASIS_SHA = "de8c3b04fde4bec30b0b85bf2bf82e01604e9c17cfcb3fdf4029af0f4d43ebf9"
BASIS_PRODUCER = "e68ec74b02bb227a065d9881ca2c12fe3b1ef122f032e7bb1324213d3031813f"
WORK_NAMES = ("down", "high", "front", "install")
ROLE_NAMES = ("BODY_HELD_LOAD", "STANCE_SUPPORT", "TURN_RECOVERY", "WORK_APPROACH", "WORK_STROKE",
              "CONTACT_POINT", "CONTACT_PATCH")
SOURCE_FILES = ("mole-worker.ugactor", "program.json", "roles.json", "plan.json")
SOURCE_DIGESTS = (IMAGE_SHA, PROGRAM_SHA, ROLES_SHA, PLAN_SHA)
MAX_REPORT_BYTES = 4 * 1024 * 1024


def row_identity(profile):
    """Versioned protocol4 row map; source role is never inferred from first matching physical key."""
    P.require(type(profile) is int and 0 <= profile < 18, "PUBLICATION_PROFILE_ID")
    if profile < 2:
        return profile, None
    return 2 + (profile - 2) % 4, N.YAWS[(profile - 2) // 4]


def source_program():
    """Bind the accepted immutable program to actual source meshes/rig and exact same-file metadata."""
    for name, digest in zip(SOURCE_FILES, SOURCE_DIGESTS):
        P.require(P.content.file_hash(IMAGE_DIR / name) == digest, "PUBLICATION_SOURCE_DRIFT")
    program, roles, plan = I.image_metadata(IMAGE_DIR, IMAGE_SHA, "program.json", "roles.json")
    P.require(program["program_version"] == 3 and program["profile_roles"] == dict(zip(I.PROFILE_NAMES, range(6))) and
              program["ready_clip"] == 0 and program["ready_time_q16"] == 8 * 65536 and
              program["fade_time_q16"] == 15 * 32768, "PUBLICATION_PROGRAM")
    compact, parts, rig, topology, roots, count, historical = I.M.read_actual_source()
    cases = S.read_image(IMAGE_DIR / "mole-worker.ugactor", IMAGE_SHA, parts)
    for at, case in enumerate(cases):
        case.update(geometry=parts, id=I.NAMES[at])
    I.check_program(cases)
    P.require(len(cases) == 14 and roots == plan["world_root_bounds_u"] and
              all(Q.same_source(old, new) for old, new in zip(compact, cases[:11])) and
              [sum(len(surface) for surface in rows) for rows in topology] == [10209, 1150],
              "PUBLICATION_SOURCE_CENSUS")
    # Reauthor the three new poses through the exact accepted local-rig recipe,
    # not a matching filename. The first eleven bytes have independent accepted
    # source reconstruction in the compact program closure.
    _, candidate, install_plan = I.image_metadata(EVIDENCE / "install-source-v4", I.INSTALL_SHA,
                                                None, "candidate.json")
    P.require(install_plan["world_root_bounds_u"] == roots, "PUBLICATION_SOURCE_ROOTS")
    recipe = candidate["source_recipe"]
    expected = I.I.source_motion(compact[0], parts[1], rig, *recipe["poll_xz_u"],
                                 recipe["lean_degrees"], recipe["azimuth_degrees"])[:3]
    expected[0]["source_loop_mode"] = 1
    P.require(all(Q.same_source(old, new) for old, new in zip(expected, cases[11:])), "PUBLICATION_SOURCE_EQUATION")
    return cases, parts, rig, topology, roots, count, historical, roles


def cover_rows(obligations, roles):
    """A role cannot be omitted because another permissive role happens to enclose its geometry."""
    P.require(set(roles) == set(ROLE_NAMES) and sum(map(len, roles.values())) <= 12,
              "PUBLICATION_ROLE_CENSUS")
    P.require(set(obligations) == {"ready", "entry", "work", "recovery"}, "PUBLICATION_PHASE_CENSUS")
    for phase, rows in obligations.items():
        P.require(type(rows) is list and 3 <= len(rows) <= 7 and
                  {row["part"] for row in rows} == {0, 1}, "PUBLICATION_PRIMITIVE_CENSUS")
        for row in rows:
            P.require(row["role"] in ROLE_NAMES and row["role"] not in ("CONTACT_POINT", "CONTACT_PATCH", "STANCE_SUPPORT") and
                      (row["role"] == "WORK_STROKE") == (phase == "work" and row["part"] == 1),
                      "PUBLICATION_PRIMITIVE_ROLE")
            box = row["bounds_u"]
            P.require(box is not None and len(box) == 6 and
                      any(all(outer[a] <= box[a] <= box[a + 3] <= outer[a + 3] for a in range(3))
                          for outer in roles[row["role"]]), "PUBLICATION_PRIMITIVE_ROLE_GAP")


def _positive(box):
    return C.positive_box(box)


def dig_obligations(local, ready, wall=None):
    """All original body/tool portions; productive geometry alone owns the work-target exception."""
    obligations = {}
    for phase, rows in (("ready", ready), ("entry", local[1]), ("work", local[0]), ("recovery", local[1])):
        role = "WORK_APPROACH" if phase == "ready" else "TURN_RECOVERY"
        result = []
        if phase == "work":
            result.extend({"part": 0, "role": "BODY_HELD_LOAD", "bounds_u": box} for box in C.body_boxes(rows[0]))
            stroke = [rows[1]["above_floor_u"], rows[1]["floor_intersection_u"]] if wall is None else wall["work"]
            result.extend({"part": 1, "role": "WORK_STROKE", "bounds_u": box} for box in stroke if box is not None)
        elif wall is not None and phase != "ready":
            for part in (0, 1):
                result.extend({"part": part, "role": role, "bounds_u": _positive(box)}
                              for box in wall["entry"][part] if _positive(box) is not None)
            result.append({"part": 0, "role": role, "bounds_u": rows[0]["floor_intersection_u"]})
        else:
            result.extend({"part": 0, "role": role, "bounds_u": box} for box in C.body_boxes(rows[0]))
            result.append({"part": 1, "role": role, "bounds_u": rows[1]["full_bounds_u"]})
        obligations[phase] = result
    return obligations


def install_roles(local, ready, feet, below_body, below_tool, tip):
    """Same reviewed common-sole split, recomputed with every finite cardinal error included."""
    work, entry = local
    body = C.body_boxes(work[0])
    floor = body[1]
    P.require(floor == entry[0]["floor_intersection_u"] == ready[0]["floor_intersection_u"] and
              all(rows[1]["floor_intersection_u"] is None for rows in (work, entry, ready)),
              "PUBLICATION_INSTALL_FLOOR")
    low = C.union(below_body)
    P.require(low[4] == 128 and below_tool[4] == 128 and below_tool[1] > 0 and
              entry[1]["full_bounds_u"][1] > 128 and ready[1]["full_bounds_u"][1] > 128,
              "PUBLICATION_INSTALL_PARTITION")
    support = C.union([row["support_u"] for row in feet])
    P.require(all(support[a] <= floor[a] <= floor[a + 3] <= support[a + 3] for a in range(3)),
              "PUBLICATION_INSTALL_SUPPORT")
    rows = {"BODY_HELD_LOAD": body, "STANCE_SUPPORT": [support], "CONTACT_POINT": [tip["anchor_u"] * 2],
            "CONTACT_PATCH": [tip["patch_u"]]}
    obligations = {}
    for phase, current, role, at in (("ready", ready, "WORK_APPROACH", 1),
                                      ("entry", entry, "TURN_RECOVERY", 0),
                                      ("recovery", entry, "TURN_RECOVERY", 0)):
        full = current[0]["full_bounds_u"]
        lower = [low[0], 0, low[2], *low[3:]]
        upper = [full[0], 128, full[2], *full[3:]]
        rows[role] = [lower, C.union([upper, current[1]["full_bounds_u"]])]
        actual_low = [below_body[at][0], 0, below_body[at][2], *below_body[at][3:]]
        obligations[phase] = [{"part": 0, "role": "BODY_HELD_LOAD", "bounds_u": floor},
                              {"part": 0, "role": role, "bounds_u": actual_low},
                              {"part": 0, "role": role, "bounds_u": upper},
                              {"part": 1, "role": role, "bounds_u": current[1]["full_bounds_u"]}]
    tool = work[1]["full_bounds_u"]
    rows["WORK_STROKE"] = [below_tool, [tool[0], 128, tool[2], *tool[3:]]]
    obligations["work"] = [*({"part": 0, "role": "BODY_HELD_LOAD", "bounds_u": box} for box in body),
                            *({"part": 1, "role": "WORK_STROKE", "bounds_u": box} for box in rows["WORK_STROKE"])]
    I.role_refusal(rows, floor)
    cover_rows(obligations, rows)
    return rows, obligations


def compile_work(name, cases, parts, rig, topology, roots, basis, ready_case, ready_cache, ready, do_self):
    ordinal = WORK_NAMES.index(name)
    work_index = 2 + 3 * ordinal
    work, entry, recovery = cases[work_index:work_index + 3]
    P.require(S.reusable_timing(recovery, entry, True) and
              recovery["matrices"].tobytes() == entry["matrices"][::-1].tobytes() and
              recovery["grounding"].tobytes() == entry["grounding"][::-1].tobytes(), "PUBLICATION_EXACT_RECOVERY")
    caches = [N.endpoint_cache(case, parts, roots, basis) for case in (work, entry)]
    local = [N.enclosure_rows(case, parts, topology, cache) for case, cache in zip((work, entry), caches)]
    feet = [C.foot_projection(parts[0], topology[0], cache[0]["low"], cache[0]["high"], rows[0]["floor_intersection_u"],
                              name == "down" and at == 0)
            for at, (cache, rows) in enumerate(zip(caches, local))]
    feet.append(C.foot_projection(parts[0], topology[0], ready_cache[0]["low"], ready_cache[0]["high"],
                                  ready[0]["floor_intersection_u"]))
    axis, plane, vertex = ((1, 0, 148), (2, -536, 148), (2, -768, 148), (1, 128, I.I.POLL_VERTEX))[ordinal]
    contacts = N.find_contacts(work, parts[1], topology[1][0], caches[0][1], basis, vertex, axis, plane)
    wall = None
    if axis == 2:
        wall = {"work": [N.clipped_portion(work, caches[0][1], topology[1][0], 2, plane, side) for side in (True, False)],
                "entry": [[N.clipped_portion(entry, caches[1][part], topology[part][0], 2, plane, side)
                           for side in (True, False)] for part in (0, 1)]}
    result = []
    for heading, tip in enumerate(contacts):
        if name == "install":
            below_body = [N.clipped_portion(case, cache[0], topology[0][0], 1, 128)
                          for case, cache in ((entry, caches[1]), (ready_case, ready_cache))]
            below_tool = N.clipped_portion(work, caches[0][1], topology[1][0], 1, 128)
            roles, obligations = install_roles(local, ready, feet, below_body, below_tool, tip)
        else:
            roles = C.work_roles(local[0], local[1], ready, tip, C.union([f["support_u"] for f in feet]), wall)
            obligations = dig_obligations(local, ready, wall)
            cover_rows(obligations, roles)
        oriented = {role: [N.orient_box(box, heading) for box in rows] for role, rows in roles.items()}
        result.append({"id": 2 + 4 * heading + ordinal, "source_role": 2 + ordinal,
                       "yaw": N.YAWS[heading], "roles": oriented, "canonical_roles": roles,
                       "contact": tip, "coverage": obligations})
    self_proof = {}
    if do_self:
        for index, case, cache in zip((work_index, work_index + 1), (work, entry), caches):
            record = N.prove_self(case, parts, topology, rig, cache)
            P.require(record["clear"] and not record["unresolved"], "PUBLICATION_SELF_CONTACT")
            self_proof[str(index)] = record
        self_proof[str(work_index + 2)] = dict(self_proof[str(work_index + 1)],
                                               reused_exact_reverse_clip=work_index + 1,
                                               rendered_edges=[list(edge) for edge in P.rendered_intervals(recovery)])
    return {"source_role": name, "profiles": result, "work_and_entry": local, "support": feet,
            "wall_partitions": wall, "self_clearance": self_proof, "self_proved": do_self}


def producer_pins():
    """Pin the actual transitive Python authoring/math helpers, including indirectly imported rig code."""
    pending, seen, paths = [N], set(), {Path(__file__).resolve()}
    while pending:
        module = pending.pop()
        if id(module) in seen:
            continue
        seen.add(id(module))
        P.require(len(seen) <= 128, "PUBLICATION_PRODUCER_CAPACITY")
        path = Path(module.__file__).resolve()
        paths.add(path)
        for value in vars(module).values():
            if isinstance(value, types.ModuleType) and getattr(value, "__file__", None):
                child = Path(value.__file__).resolve()
                if child.is_relative_to(P.ROOT) and child.suffix == ".py":
                    pending.append(value)
    return {str(path.relative_to(P.ROOT)): P.content.file_hash(path) for path in sorted(paths)}


def input_pins(basis_path):
    """Pin immutable inputs before/after execution; the source reader separately rechecks all raw/import origins."""
    command = I.M.W.read_record(EVIDENCE / "analysis-carry-arm-v7/invocation.json")["command"]
    paths = [*(IMAGE_DIR / name for name in SOURCE_FILES), basis_path,
             EVIDENCE / "analysis-carry-arm-v7/invocation.json",
             EVIDENCE / "install-source-v4/mole-worker.ugactor", EVIDENCE / "install-source-v4/candidate.json",
             EVIDENCE / "install-source-v4/plan.json", EVIDENCE / "compact-program-compile-v2/result/mole-worker.ugactor"]
    paths.extend(Path(command[command.index("--" + key) + 1]) for key in ("source", "proof", "plan", "topology"))
    return {str(path.resolve().relative_to(P.ROOT)): P.content.file_hash(path) for path in paths}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    parser.add_argument("--world-basis", type=Path, default=P.ROOT / "godot/demo/assets/underground-matrices/world-yaw-v1.ugyaw")
    parser.add_argument("--roles", default=",".join(WORK_NAMES))
    parser.add_argument("--envelopes-only", action="store_true", help="Diagnostic only; never establishes self clearance or flags")
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "PUBLICATION_OUTPUT_EXISTS")
    selected = args.roles.split(",")
    P.require(0 < len(selected) <= 4 and len(set(selected)) == len(selected) and
              all(name in WORK_NAMES for name in selected), "PUBLICATION_ROLE_SELECTION")
    pins = producer_pins()
    inputs = input_pins(args.world_basis)
    cases, parts, rig, topology, roots, sources, historical, old_roles = source_program()
    with args.world_basis.open("rb") as stream:
        basis = N.CardinalBasis(stream, BASIS_SHA, BASIS_PRODUCER)
    ready_case = P.indexed_sequence(cases[0], [8, 8], "cardinal_exact_ready", False)
    ready_cache = N.endpoint_cache(ready_case, parts, roots, basis)
    ready = N.enclosure_rows(ready_case, parts, topology, ready_cache)
    args.out.mkdir(parents=True)
    # Save the executed input pins before any expensive proof. The final file
    # is create-only and refuses source drift; a failed run remains diagnostic.
    (args.out / "executed-source-sha256.json").write_text(json.dumps(pins, indent=2) + "\n")
    (args.out / "executed-input-sha256.json").write_text(json.dumps(inputs, indent=2) + "\n")
    profiles = []
    for name in selected:
        print("cardinal-role " + name, flush=True)
        result = compile_work(name, cases, parts, rig, topology, roots, basis, ready_case, ready_cache, ready,
                              not args.envelopes_only)
        raw = (json.dumps(result, indent=2) + "\n").encode()
        P.require(len(raw) <= MAX_REPORT_BYTES, "PUBLICATION_REPORT_CAPACITY")
        P.require(producer_pins() == pins and input_pins(args.world_basis) == inputs, "PUBLICATION_EXECUTED_SOURCE_DRIFT")
        with (args.out / (name + ".json")).open("xb") as output:
            output.write(raw)
        profiles.extend(result["profiles"])
    report = {"schema": 1, "program_version": 4, "source_image_sha256": IMAGE_SHA,
              "program_sha256": PROGRAM_SHA, "source_roles_sha256": ROLES_SHA, "plan_sha256": PLAN_SHA,
              "selected_source_roles": selected, "all_work_roles": selected == list(WORK_NAMES),
              "world_root_bounds_u": roots, "world_basis": basis.cardinal_certificate(),
              "native_primitive_census": [sum(map(len, part)) for part in topology],
              "verified_source_files": sources, "historical_source_snapshot": historical,
              "producer_sources": pins, "input_sources": inputs, "profile_count": len(profiles),
              "box_count": sum(sum(map(len, row["roles"].values())) for row in profiles),
              "self_clearance_proved": not args.envelopes_only, "production_qualified": False,
              "remaining": ["ALL_YAW_GROUND_SOURCE_CLOSURE", "EXACT_CARDINAL_NATIVE_BINDING", "CURRENT_CONSUMER_CLOSURE",
                            "INDEPENDENT_PUBLICATION_REVIEW", "ACTUAL_WORLD_WIP_SUPPORT_AND_HANDLING"],
              "certificate_bits_written": 0}
    checked = source_program()
    P.require(checked[5:7] == (sources, historical), "PUBLICATION_ORIGINAL_SOURCE_DRIFT")
    P.require(producer_pins() == pins and input_pins(args.world_basis) == inputs, "PUBLICATION_EXECUTED_SOURCE_DRIFT")
    with (args.out / "proof.json").open("x") as output:
        json.dump(report, output, indent=2)
        output.write("\n")
    print(json.dumps({"profiles": len(profiles), "boxes": report["box_count"], "self": not args.envelopes_only,
                      "certificate_bits_written": 0}))


if __name__ == "__main__":
    main()
