#!/usr/bin/env python3
"""Recheck source-identical all-yaw ground proof and pin current consumers; emit no certificate bits."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("cardinal_publication", HERE.parents[1] / "compile_profile_publication.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
P, C, Q, S = M.P, M.C, M.Q, M.S
GROUND_PROOF_SHA = "9e1e5d1bec451588e431dff6a669052a2677111a52898bbec7c33b4ab0b5014b"
GROUND_SOURCE_SHA = "92867c982add6e8ae9337f8afb1a91fc2299110f6e64ac9cad9017a9a51faf9e"
GROUND_ROLES_SHA = "84cf43a446a6e5d42d9bc2c0398caea681dcaa46bdf0491320346d4c6ddf80c6"
CONSUMERS = (
    "godot/scripts/core/underground_profiles.gd",
    "godot/scripts/core/underground_work_face.gd",
    "godot/scripts/core/underground_connector_contacts.gd",
    "godot/scripts/core/underground_routes.gd",
    "godot/scripts/core/underground_world_routes.gd",
    "godot/demo/cast/underground_actor.gd",
    "godot/demo/cast/underground_actor_content.gd",
    "godot/data/underground/mole-worker/mole_profile_driver.gd",
)
MAX_SOURCE_BYTES = 1048576


def handoff_refusal(record, cases, basis, census):
    """An old true flag is insufficient: require every actual finite fade edge, count and numerical basis."""
    handoffs = record.get("carry_handoffs", {})
    expected = C.H.handoff_sets(cases)
    checked = handoffs.get("checked")
    P.require(record.get("schema") == 2 and record.get("content_sha256") == GROUND_SOURCE_SHA and
              record.get("source_rederived") is True and record.get("production_qualified") is False and
              record.get("world_basis_sha256") == basis.digest and
              record.get("inverse_heading_norm") == P.envelope.fraction_record(basis.inverse_norm),
              "SOURCE_GROUND_IDENTITY")
    P.require(handoffs.get("clear") is True and handoffs.get("unresolved") == [] and
              type(checked) is list and 0 < len(checked) == len(expected) <= 512,
              "SOURCE_GROUND_HANDOFF_CENSUS")
    total = 0
    for row, wanted in zip(checked, expected):
        P.require(type(row) is dict and {k: row.get(k) for k in ("from", "interval", "to", "corners")} == wanted and
                  type(row.get("checks")) is int and 0 < row["checks"] <= C.H.MAX_CHECKS,
                  "SOURCE_GROUND_HANDOFF_EDGE")
        total += row["checks"]
    P.require(type(handoffs.get("checks")) is int and 0 < total == handoffs["checks"] <= C.H.MAX_CHECKS and
              tuple(handoffs.get(key) for key in ("body_triangles", "tool_triangles", "intentional_grip_triangles")) == census,
              "SOURCE_GROUND_PRIMITIVE_CENSUS")


def same_ground_sources(actual, prior):
    """Reuse only identical finite source bytes, including loop mode and short final interval duration."""
    P.require(len(actual) >= 2 and len(prior) >= 2 and
              all(Q.same_source(actual[index], prior[index]) for index in (0, 1)),
              "SOURCE_GROUND_CLIP_DRIFT")


def compile_ground(carry):
    """All body/clothing/tool primitives and full foot support survive both mandatory collision roles."""
    P.require(len(carry) == 2 and carry[0]["kind"] == "body" and carry[1]["kind"] == "attachment" and
              carry[1]["floor_u"] is None and carry[1]["support_u"] is None,
              "SOURCE_GROUND_PART_CENSUS")
    full, floor = carry[0]["full_u"], carry[0]["floor_u"]
    P.require(floor is not None and full[1] < 0 < full[4] and floor[1] < floor[4] == 0,
              "SOURCE_GROUND_FLOOR")
    body = [[full[0], 0, full[2], *full[3:]], floor, carry[1]["full_u"]]
    support = C.union([row["support_u"] for row in carry])
    P.require(all(support[a] <= floor[a] <= floor[a + 3] <= support[a + 3] for a in range(3)),
              "SOURCE_GROUND_STANCE")
    roles = {"BODY_HELD_LOAD": body, "TURN_RECOVERY": body, "STANCE_SUPPORT": [support]}
    ground_coverage(body, support, roles)
    return roles


def ground_coverage(body, support, roles):
    """A missing mandatory BODY row cannot borrow TURN's presence, or vice versa."""
    P.require(set(roles) == {"BODY_HELD_LOAD", "TURN_RECOVERY", "STANCE_SUPPORT"} and
              len(body) == 3 and roles["STANCE_SUPPORT"] == [support], "SOURCE_GROUND_ROLE_CENSUS")
    for role in ("BODY_HELD_LOAD", "TURN_RECOVERY"):
        P.require(type(roles[role]) is list and len(roles[role]) == 3, "SOURCE_GROUND_ROLE_CENSUS")
        for actual in body:
            P.require(any(all(row[a] <= actual[a] <= actual[a + 3] <= row[a + 3] for a in range(3))
                          for row in roles[role]), "SOURCE_GROUND_PRIMITIVE_GAP")


def source_blobs(revision):
    """Read exact immutable Git objects, never concurrent working-tree bytes or an implied current HEAD."""
    P.require(type(revision) is str and re.fullmatch(r"[0-9a-f]{40}", revision) is not None,
              "SOURCE_CONSUMER_REVISION")
    kind = subprocess.run(["git", "cat-file", "-t", revision], cwd=P.ROOT, capture_output=True, check=True).stdout
    P.require(kind.strip() == b"commit", "SOURCE_CONSUMER_REVISION")
    result = {}
    for name in CONSUMERS:
        key = revision + ":" + name
        count = int(subprocess.run(["git", "cat-file", "-s", key], cwd=P.ROOT, capture_output=True, check=True).stdout)
        P.require(0 < count <= MAX_SOURCE_BYTES, "SOURCE_CONSUMER_CAPACITY")
        raw = subprocess.run(["git", "cat-file", "blob", key], cwd=P.ROOT, capture_output=True, check=True).stdout
        P.require(len(raw) == count, "SOURCE_CONSUMER_READ")
        result[name] = raw
    return result


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    parser.add_argument("--consumer-revision", required=True)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "SOURCE_GATE_OUTPUT_EXISTS")
    paths = [HERE / "compact-program-proof-v1.json", HERE / "compact-program-source-v1/mole-worker.ugactor",
             HERE / "compact-program-compile-v2/result/roles.json"]
    wanted = [GROUND_PROOF_SHA, GROUND_SOURCE_SHA, GROUND_ROLES_SHA]
    P.require(all(P.content.file_hash(path) == digest for path, digest in zip(paths, wanted)), "SOURCE_GROUND_INPUT")
    producers = M.producer_pins() | {str(Path(__file__).relative_to(P.ROOT)): P.content.file_hash(Path(__file__))}
    basis_path = P.ROOT / "godot/demo/assets/underground-matrices/world-yaw-v1.ugyaw"
    inputs = M.input_pins(basis_path) | {str(path.relative_to(P.ROOT)): digest for path, digest in zip(paths, wanted)}
    cases, parts, rig, topology, roots, count, historical, actual_roles = M.source_program()
    prior = S.read_image(paths[1], GROUND_SOURCE_SHA, parts)
    same_ground_sources(cases, prior)
    proof = P.content.read_json(paths[0], GROUND_PROOF_SHA, 1048576)
    Q.producer_refusal(proof)
    with basis_path.open("rb") as stream:
        basis = C.H.InverseHeading(stream, M.BASIS_SHA, M.BASIS_PRODUCER)
    ids, omitted = S.body_triangle_ids(parts[0], topology[0][0], rig["rig_binding"])
    handoff_refusal(proof, cases, basis, (len(ids), len(topology[1][0]), omitted))
    carry = C.carry_bounds(cases, parts, topology, roots, basis)
    roles = compile_ground(carry)
    previous = P.content.read_json(paths[2], GROUND_ROLES_SHA, 1048576)
    P.require(roles == previous["roles"]["stand"] == previous["roles"]["ground_walk"] ==
              actual_roles["roles"]["stand"] == actual_roles["roles"]["ground_walk"], "SOURCE_GROUND_ROLE_DRIFT")
    blobs = source_blobs(args.consumer_revision)
    # This pins readable source for independent compatibility review. A hash is
    # not a proof that a consumer enforces every role, and it grants no World permission.
    consumers = {name: hashlib.sha256(raw).hexdigest() for name, raw in blobs.items()}
    report = {"schema": 1, "actor_image_sha256": M.IMAGE_SHA, "ground_proof_sha256": GROUND_PROOF_SHA,
              "all_yaw_handoff_proof_reused": True, "ground_clips_source_timing_equal": True,
              "handoff_checks": proof["carry_handoffs"]["checks"], "handoff_simplices": len(proof["carry_handoffs"]["checked"]),
              "roles": {"0": roles, "1": roles}, "ground_enclosures": carry,
              "world_basis_sha256": basis.digest, "inverse_heading_norm": P.envelope.fraction_record(basis.inverse_norm),
              "world_root_bounds_u": roots, "verified_source_files": count, "historical_source_snapshot": historical,
              "producer_sources": producers, "input_sources": inputs,
              "consumer_source_commit": args.consumer_revision, "consumer_sources": consumers,
              "consumer_compatibility_review_required": True, "certificate_bits_written": 0, "production_qualified": False,
              "scope": "All-yaw ground source enclosure and exact accepted finite fades; immutable consumer bytes are review inputs only",
              "remaining": ["CURRENT_CONSUMER_COMPATIBILITY_REVIEW", "NATIVE_PROTOCOL4_REPLAY", "EXACT_RUNTIME_SOURCE_BINDING",
                            "IMMUTABLE_PROFILE_PUBLICATION", "ACTUAL_WORLD_WIP_HANDLING_AND_MOVEMENT"]}
    P.require(all(P.content.file_hash(P.ROOT / name) == digest for name, digest in producers.items()), "SOURCE_GATE_PRODUCER_DRIFT")
    P.require(all(P.content.file_hash(P.ROOT / name) == digest for name, digest in inputs.items()), "SOURCE_GATE_INPUT_DRIFT")
    args.out.mkdir(parents=True)
    for name, raw in blobs.items():
        with (args.out / (Path(name).name + ".txt")).open("xb") as output:
            output.write(raw)
    with (args.out / "ground-closure.json").open("x") as output:
        json.dump(report, output, indent=2)
        output.write("\n")
    print(json.dumps({"ground_rows": 2, "role_boxes": 2 * sum(map(len, roles.values())),
                      "reused_handoff_checks": report["handoff_checks"], "consumer_sources": len(consumers),
                      "certificate_bits_written": 0, "production_qualified": False}))


if __name__ == "__main__":
    main()
