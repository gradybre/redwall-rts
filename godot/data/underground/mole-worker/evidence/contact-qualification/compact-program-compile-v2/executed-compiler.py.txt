#!/usr/bin/env python3
"""Compile the complete version2 source program and every physical role; emit no qualification flag."""
import argparse
from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("compact_author", HERE / "author_compact_program.py")
D = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(D)
A, C, P, S, W = D.A, D.C, D.P, D.S, D.W
PROFILE_NAMES = ("stand", "ground_walk", "down", "high", "front")
INPUTS = {
    "body-clearance-loop-v6.json": "429a299b28ff49a5f081eb3a3c4780ec606b5da7d82f6bdd06848ef034c91fe6",
    "downward-tip-witness-v3.json": "a2013bb81af272e29b348cdfb2506713ed20807f6a6a9d0e93bade5259e1f1ff",
    "high-wall-proof-v3.json": "06bbd46b447befd36afae7181307a007bfd8587d6de1e5ff44d932f33559e293",
    "planted-native-proof-v3.json": "473d834d93560e418add7d6341aacc75adbe0d7a04468bf31f63b759d915fd48"}


def producer_refusal(record, field="producer_sources"):
    """An accepted finite result cannot transfer to drifted executable source or a replaced input."""
    P.require(type(record.get(field)) is dict and 0 < len(record[field]) <= 1024, "COMPACT_PROOF_PIN_CENSUS")
    for name, expected in record[field].items():
        path = (P.ROOT / name).resolve()
        P.require(path.is_relative_to(P.ROOT) and P.content.file_hash(path) == expected, "COMPACT_PROOF_SOURCE_DRIFT")


def interval_refusal(row, case):
    """Require the exact emitted loop/timing edge census, not only a true success field."""
    edges = [list(edge) for edge in P.rendered_intervals(case)]
    loop, duration = P.rendered_timing(case)
    P.require(row.get("clear") is True and row.get("unresolved") == [] and row.get("exact_yaw") == 0 and
              row.get("rendered_edges") == edges and row.get("intervals") == len(edges) and
              row.get("loop_mode") == loop and row.get("duration_q16") == duration and
              type(row.get("checks")) is int and row["checks"] > 0, "COMPACT_INTERVAL_PROOF")


def same_source(left, right):
    """Proof reuse requires native bytes plus exact loop and short-final-interval semantics."""
    return (P.rendered_timing(left) == P.rendered_timing(right) and
            left["matrices"].tobytes() == right["matrices"].tobytes() and
            left["grounding"].tobytes() == right["grounding"].tobytes())


def contact_refusal(tip, axis, plane):
    """The selected genuine contact owns one exact source plane and a complete positive-area patch."""
    anchor, patch = tip["anchor_u"], tip["patch_u"]
    P.require(len(anchor) == 3 and len(patch) == 6 and all(type(v) is int for v in anchor + patch) and
              all(patch[a] <= anchor[a] <= patch[a + 3] for a in range(3)) and
              anchor[axis] == patch[axis] == patch[axis + 3] == plane and
              all(patch[a] < patch[a + 3] for a in range(3) if a != axis), "COMPACT_CONTACT_PATCH")


def read_program_metadata(directory, image_digest):
    """Candidate and plan are decoded from the same exact bytes whose digests the immutable image carries."""
    path = directory / "mole-worker.ugactor"
    P.require(path.is_file() and 184 <= path.stat().st_size <= 4 * P.content.MAX_SCALARS + 8192,
              "COMPACT_IMAGE_CAPACITY")
    P.require(P.content.file_hash(path) == image_digest, "COMPACT_IMAGE_SOURCE")
    with path.open("rb") as stream:
        header = stream.read(184)
    P.require(len(header) == 184 and header[:8] == b"UGACNT01" and header[88:120] == header[120:152],
              "COMPACT_IMAGE_METADATA")
    candidate = P.content.read_json(directory / "candidate.json", header[120:152].hex(), 1048576)
    plan = P.content.read_json(directory / "plan.json", header[152:184].hex(), 65536)
    P.require(candidate.get("schema") == 2 and candidate.get("clips") == list(D.NAMES) and
              candidate.get("profile_roles") == dict(zip(PROFILE_NAMES, range(5))) and
              candidate.get("ready_clip") == 0 and candidate.get("ready_time_q16") == 8 * 65536 and
              candidate.get("production_qualified") is False, "COMPACT_PROGRAM_METADATA")
    producer_refusal(candidate)
    return candidate, plan


def check_prior_proofs(cases, parts, compact, basis):
    """Compose only the exact accepted productive/stance sources and new compact entry/handoff proof."""
    fixed = {name: P.content.read_json(HERE / name, digest, 1048576) for name, digest in INPUTS.items()}
    down = fixed["body-clearance-loop-v6.json"]
    high = fixed["high-wall-proof-v3.json"]
    native = fixed["planted-native-proof-v3.json"]
    for record in (down, high, fixed["downward-tip-witness-v3.json"], compact):
        producer_refusal(record)
    producer_refusal(native, "producer_and_input_sources")
    P.require(down["image_sha256"] == C.DOWN_SHA and high["content_sha256"] == C.HIGH_SHA and
              high["source_matrices_timing_grounding_rederived"] is True and
              high["native_tip_samples"] == 9 and native["native_points_enclosed"] == 9 and
              native["authoring_target_refusal"] == "", "COMPACT_PRIOR_PROOF")
    planted = S.read_image(HERE / "planted-front-source-v4/mole-worker.ugactor", native["content_sha256"], parts)
    primitive = P.content.read_json(HERE / "planted-front-proof-v1.json", native["source_proof_sha256"], 1048576)
    producer_refusal(primitive)
    P.require(primitive["content_sha256"] == native["content_sha256"] and primitive["source_rederived"] is True and
              primitive["exact_recovery"] is True, "COMPACT_PLANTED_PROOF")
    for current, previous in ((0, 0), (1, 1), (8, 6), (9, 7), (10, 8)):
        P.require(same_source(cases[current], planted[previous]), "COMPACT_PLANTED_SOURCE")
    interval_refusal(down["clips"]["6"], cases[2])
    interval_refusal(high["clips"]["6"]["self_contact"], cases[5])
    for current, previous in ((0, 0), (1, 1), (8, 6), (9, 7)):
        interval_refusal(primitive["clips"][str(previous)], cases[current])
    interval_refusal(compact["revised_down_high_entry"], cases[3])
    handoffs = compact["carry_handoffs"]
    P.require(compact.get("source_rederived") is True and compact.get("production_qualified") is False and
              compact["world_basis_sha256"] == basis.digest and
              compact["inverse_heading_norm"] == P.envelope.fraction_record(basis.inverse_norm) and
              handoffs.get("clear") is True and handoffs.get("unresolved") == [] and
              [{k: row[k] for k in ("from", "interval", "to", "corners")} for row in handoffs["checked"]]
              == C.H.handoff_sets(cases), "COMPACT_HANDOFF_PROOF")
    down_tip = fixed["downward-tip-witness-v3.json"]
    P.require(down_tip["content_sha256"] == C.DOWN_SHA and down_tip["exact_yaw"] == 0, "COMPACT_DOWN_TIP")
    tips = {"down": {"anchor_u": down_tip["witness"]["authored_anchor_u"], "patch_u": down_tip["contact_patch_u"]},
            "high": high["tip"], "front": native["witness"]}
    for name, axis, plane in (("down", 1, 0), ("high", 2, -536), ("front", 2, -768)):
        contact_refusal(tips[name], axis, plane)
    return tips


def wall_partitions(work, entry, parts, topology, roots, plane):
    """Retain both complete sides of every tool/entry primitive; never clip the genuine forward stroke."""
    return {"work": [W.H.plane_portion(work, parts[1], topology[1], 24, roots, plane, side) for side in (False, True)],
            "entry": [[W.H.plane_portion(entry, part, topology[index], 0 if index == 0 else 24,
                                         roots, plane, side) for side in (False, True)]
                      for index, part in enumerate(parts)]}


def compile_roles(cases, parts, topology, roots, basis, tips):
    """Every phase's complete source geometry has the same explicit role contract as the accepted v1 compiler."""
    carry = C.carry_bounds(cases, parts, topology, roots, basis)
    local = {str(clip): P.continuous_floor(cases[clip], topology, roots) for clip in (2, 3, 5, 6, 8, 9)}
    ready_case = P.indexed_sequence(cases[0], [8, 8], "compact_ready_exact", False)
    ready = P.continuous_floor(ready_case, topology, roots)
    feet = {}
    for clip in (2, 3, 5, 6, 8, 9):
        low, high, _, _ = C.H.vertex_corners(cases[clip], parts[0], 0, roots, Fraction(1))
        feet[str(clip)] = C.foot_projection(parts[0], topology[0], low, high,
                                          local[str(clip)][0]["floor_intersection_u"], clip == 2)
    walls = {"high": wall_partitions(cases[5], cases[6], parts, topology, roots, -536),
             "front": wall_partitions(cases[8], cases[9], parts, topology, roots, -768)}
    full = carry[0]["full_u"]
    body = [[full[0], 0, full[2], *full[3:]], carry[0]["floor_u"], carry[1]["full_u"]]
    roles = {"stand": {"BODY_HELD_LOAD": body, "TURN_RECOVERY": body,
                        "STANCE_SUPPORT": [C.union([row["support_u"] for row in carry])]}}
    roles["ground_walk"] = roles["stand"]
    for name, work, entry in (("down", 2, 3), ("high", 5, 6), ("front", 8, 9)):
        support = C.union([feet[str(work)]["support_u"], feet[str(entry)]["support_u"]])
        roles[name] = C.work_roles(local[str(work)], local[str(entry)], ready, tips[name], support, walls.get(name))
    return {"roles": roles, "carry": carry, "work_constituents": local, "ready": ready,
            "foot_support": feet, "wall_partitions": walls}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("preview", type=Path)
    parser.add_argument("proof", type=Path)
    parser.add_argument("proof_sha256")
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "COMPACT_COMPILE_OUTPUT_EXISTS")
    producers = {str(Path(path).relative_to(P.ROOT)): P.content.file_hash(Path(path)) for path in
                 (__file__, D.__file__, A.__file__, C.__file__, C.H.__file__, W.__file__, W.H.__file__, S.__file__,
                  P.__file__, P.content.__file__, P.envelope.__file__)}
    inputs = [args.proof, *(args.preview / name for name in ("mole-worker.ugactor", "candidate.json", "plan.json")),
              *(HERE / name for name in INPUTS), HERE / "planted-front-proof-v1.json",
              HERE / "planted-front-source-v4/mole-worker.ugactor", HERE / "high-wall-source-v4/mole-worker.ugactor",
              HERE / "analysis-carry-arm-v7/result/mole-worker.ugactor"]
    input_pins = {str(path.resolve()): P.content.file_hash(path) for path in inputs}
    compact = P.content.read_json(args.proof, args.proof_sha256, 1048576)
    command = W.read_record(HERE / "analysis-carry-arm-v7/invocation.json")["command"]
    def value(key):
        return command[command.index("--" + key) + 1]
    proof = P.content.read_json(Path(value("proof")), value("proof-sha256"))
    original_plan = P.content.read_json(Path(value("plan")), value("plan-sha256"), 65536)
    original, sources, historical = W.extract_original(Path(value("source")), value("source-sha256"), proof,
                                                       original_plan, Path(value("import-archive")))
    parts = original[0]["geometry"]
    topology = P.read_topology(Path(value("topology")), value("topology-sha256"), value("content-sha256"), parts)
    rig = P.content.read_json(Path(value("topology")), value("topology-sha256"), P.MAX_TOPOLOGY_BYTES)
    _, plan = read_program_metadata(args.preview, compact["content_sha256"])
    P.require(plan["world_root_bounds_u"] == original_plan["world_root_bounds_u"], "COMPACT_WORLD_SOURCE")
    cases = S.read_image(args.preview / "mole-worker.ugactor", compact["content_sha256"], parts)
    down = S.read_image(HERE / "analysis-carry-arm-v7/result/mole-worker.ugactor", C.DOWN_SHA, parts)
    high = S.read_image(HERE / "high-wall-source-v4/mole-worker.ugactor", C.HIGH_SHA, parts)
    C.source_cases(original, down, high, rig, W.read_record(HERE / "high-wall-source-v4/candidate.json")["entry_recipe"])
    expected = D.assemble(down, high, original, rig)
    P.require(len(cases) == len(expected) == 11 and all(same_source(a, b) for a, b in zip(cases, expected)),
              "COMPACT_COMPILE_SOURCE")
    cases = [dict(case, id=expected[index]["id"], geometry=parts) for index, case in enumerate(cases)]
    D.check_program(cases)
    with Path(value("world-basis")).open("rb") as stream:
        basis = C.H.InverseHeading(stream, proof["world_basis"]["sha256"], proof["world_basis"]["producer_sha256"])
    tips = check_prior_proofs(cases, parts, compact, basis)
    report = compile_roles(cases, parts, topology, plan["world_root_bounds_u"], basis, tips)
    program = {"schema": 2, "program_version": 2, "clips": list(D.NAMES), "profile_roles": dict(zip(PROFILE_NAMES, range(5))),
               "ready_clip": 0, "ready_time_q16": 8 * 65536, "fade_time_q16": 15 * 32768,
               "productive_source": [2, 5, 8], "entry_source": [3, 6, 9], "recovery_source": [4, 7, 10],
               "handoffs": C.H.handoff_sets(cases), "work_heading": 0,
               "ground_heading": "all65536 finite WorldBasis rows", "active_tool": "mole_pick",
               "manufacture": "BASIC", "cargo": "none", "production_qualified": False}
    report.update(schema=2, source_matrices_timing_grounding_rederived=True, source_images=[C.DOWN_SHA, C.HIGH_SHA],
                  source_program_sha256=compact["content_sha256"], verified_source_files=sources,
                  historical_source_snapshot=historical, contact=tips, compact_proof_sha256=args.proof_sha256,
                  accepted_prior_proofs=INPUTS, input_sources=input_pins, producer_sources=producers, production_qualified=False,
                  remaining=["INDEPENDENT_COMPACT_COMPILER_REVIEW", "NATIVE_COMPLETE_V2_DRIVER", "PROFILE_CERTIFICATE_BINDING",
                             "ACTUAL_SUPPORT_AND_WORK_FACE", "REAL_TREAD_TRANSITIONS", "PRESENTATION_PEAK"])
    raw_program, raw_report, raw_plan = ((json.dumps(data, indent=2) + "\n").encode() for data in (program, report, plan))
    image, budget = P.content.encode([dict(case, id=expected[index]["id"], geometry=parts) for index, case in enumerate(cases)],
                                    plan, proof, hashlib.sha256(raw_program).hexdigest(), hashlib.sha256(raw_report).hexdigest(),
                                    hashlib.sha256(raw_plan).hexdigest())
    P.require(all(P.content.file_hash(P.ROOT / path) == digest for path, digest in producers.items()), "COMPACT_COMPILE_DRIFT")
    P.require(all(P.content.file_hash(Path(path)) == digest for path, digest in input_pins.items()), "COMPACT_COMPILE_INPUT_DRIFT")
    args.out.mkdir(parents=True)
    for name, data in (("program.json", raw_program), ("roles.json", raw_report), ("plan.json", raw_plan), ("mole-worker.ugactor", image)):
        with (args.out / name).open("xb") as stream:
            stream.write(data)
    (args.out / "compilation.json").write_text(json.dumps({"content_sha256": hashlib.sha256(image).hexdigest(),
        "content_bytes": len(image), "frames": sum(case["frames"] for case in cases), "presentation_budget": budget,
        "production_qualified": False}, indent=2) + "\n")
    print(json.dumps({"roles": report["roles"], "budget": budget, "production_qualified": False}, indent=2))


if __name__ == "__main__":
    main()
