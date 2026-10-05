#!/usr/bin/env python3
"""Rebuild and encode the exact supported assembly source. This writes no runtime permission."""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path

import numpy as np

import prove_assembly as B

I, P = B.I, B.P
READY_SHA = "393edbafa3490d93e19959d5b8e84b5022bfd475a2afdfca79754712e7fdf462"
NAMES = ("entry", "seat", "recovery")
COUNTS = (55, 2, 55)


def read(path, limit=2*1024*1024):
    P.require(path.is_file() and not path.is_symlink() and path.stat().st_size <= limit,
              "ASSEMBLY_INPUT_CAPACITY")
    raw = path.read_bytes()
    value = json.loads(raw)
    P.require(type(value) is dict, "ASSEMBLY_INPUT_FORMAT")
    return value, hashlib.sha256(raw).hexdigest()


def proof_inputs(packet, images, pins):
    """Do not accept proof labels detached from the exact bounded candidate and original source."""
    P.require(packet.get("production_qualified") is False and packet.get("all_clear") is True and
              packet.get("candidate_inputs") == images and packet.get("verified_source_files") == 537 and
              packet.get("source_inputs") == pins, "ASSEMBLY_PROOF_IDENTITY")
    producers = packet.get("producer_sources")
    P.require(type(producers) is dict and 1 <= len(producers) <= 16, "ASSEMBLY_PROOF_PRODUCERS")
    for name, digest in producers.items():
        path = Path(name)
        P.require(not path.is_absolute() and ".." not in path.parts and path.suffix == ".py" and
                  I.A.digest(I.ROOT/path) == digest, "ASSEMBLY_PROOF_PRODUCER_DRIFT")


def proof_census(terrain, tool):
    """All complete intervals and parts remain in the admitted proof; no endpoint-only result qualifies."""
    rows, self_rows = terrain.get("clips"), tool.get("results")
    P.require(type(rows) is list and type(self_rows) is list and len(rows) == len(self_rows) == 3,
              "ASSEMBLY_PROOF_CENSUS")
    for name, count, row, self_row in zip(NAMES, COUNTS, rows, self_rows):
        P.require(row.get("clip") == name and row.get("frames") == count and row.get("intervals") == count-1 and
                  row.get("clear") is True and row.get("complete") is True and row.get("failures") == [] and
                  [part.get("triangles") for part in row.get("parts", [])] == [10209, 1150] and
                  len(row.get("full_foot_support", [])) == 2*(count-1), "ASSEMBLY_TERRAIN_CENSUS")
        P.require([(v.get("interval"), v.get("foot")) for v in row["full_foot_support"]] ==
                  [(at, side) for at in range(count-1) for side in range(2)] and
                  all(v.get("source_above") is True and (v.get("source_vertex", -1) >= 0 or not v.get("required"))
                      for v in row["full_foot_support"]), "ASSEMBLY_COMPLETE_SUPPORT")
        contacts = row.get("hand_contact", [])
        P.require(len(contacts) == (2 if name == "seat" else 0) and
                  all(v.get("valid") is True for v in contacts), "ASSEMBLY_COMPLETE_CONTACT")
        P.require(self_row.get("clip") == name and self_row.get("intervals") == count-1 and
                  self_row.get("clear") is True and self_row.get("unresolved") == [] and
                  self_row.get("body_triangles") == 9761 and self_row.get("intentional_grip_triangles") == 448 and
                  self_row.get("tool_triangles") == 1150 and self_row.get("rendered_edges") ==
                  [[at, at+1] for at in range(count-1)], "ASSEMBLY_FULL_TOOL_BODY")


def build(candidate, proof_path, tool_path):
    """Compile only a byte-exact reconstruction from the original 537-file authoring source."""
    report, actual = B.sources(candidate)
    images = B.candidate_pins(candidate)
    cases, parts, rig, topology, roots, count, historical, _, pins = I.source_inputs()
    wanted, offsets, recipes, feet = B.A.program(cases[0], parts, topology, rig, 70, [-128, 224, -352], 0)
    for row, observed, expected, track in zip(report["clips"], actual, wanted, offsets):
        P.require(row["beam_offset_z_u"] == track and np.array_equal(observed["matrices"], expected["matrices"]) and
                  np.array_equal(observed["grounding"], expected["grounding"]), "ASSEMBLY_REBUILD_MISMATCH")
        expected["geometry"] = parts
        P.require(expected["source_loop_mode"] == 0 and Fraction(expected["source_duration_s"])*30*65536 ==
                  (expected["frames"]-1)*65536, "ASSEMBLY_FINITE_SOURCE_TIME")
    ready = hashlib.sha256(cases[0]["matrices"][8].tobytes()+cases[0]["grounding"][8:9].tobytes()).hexdigest()
    P.require(ready == READY_SHA and report.get("foot_plant") == feet and report.get("contact_recipes") == recipes,
              "ASSEMBLY_RECIPE_OR_READY")
    terrain, terrain_sha = read(proof_path)
    tool, tool_sha = read(tool_path)
    proof_inputs(terrain, images, pins)
    proof_inputs(tool, images, pins)
    proof_census(terrain, tool)
    targets = I.targets()
    P.require([v["local_target_box_u"] for v in targets] ==
              [[-192, 0, -512, 1856, 128, -384], [-256, 0, -512, 256, 128, -384]],
              "ASSEMBLY_ORIGINAL_BEARER")
    producers = {str(path.relative_to(I.ROOT)): I.A.digest(path) for path in
                (Path(__file__), Path(B.__file__), Path(B.A.__file__), Path(I.__file__), Path(P.content.__file__))}
    plan = {"schema": 1, "revision": 1178, "world_root_bounds_u": roots,
            "clips": [case["id"] for case in wanted], "source_phase_protocol":
            "Q16 affine intervals, terminal(last,last,0); durations are source metadata, not an adopted work rate",
            "adopted_tick_rate": None, "world_permission": False}
    record = {"schema": 1, "parent_actor_sha256": I.M.IMAGE_SHA, "ready_pose_sha256": ready,
              "verified_source_files": count, "source_inputs": pins, "historical_source_snapshot": historical,
              "candidate_inputs": images, "producer_sources": producers,
              "proof_inputs": {"terrain": terrain_sha, "tool_body": tool_sha},
              "source_frames": list(COUNTS), "source_intervals": sum(v-1 for v in COUNTS),
              "mesh_fingerprints": [P.content.geometry_fingerprint(part).hex() for part in parts],
              "root_delta_u": [0, 0, 0], "root_yaw": 0, "targets": targets,
              "bearer_track_z_u": offsets, "contact_vertex": recipes[0]["contact_vertex"],
              "foot_plant": feet, "body_triangles": 10209, "pick_triangles": 1150,
              "palm_contact_triangles": int(B.A.palm_rows(parts[0], topology[0][0], rig).sum()),
              "scope": "Separate immutable handling source. The whole paid bill remains unchanged; the selected complete bearer remains ground-supported. No hauling, force simulation, runtime contact alias or paid state is emitted.",
              "production_qualified": False, "remaining": ["NATIVE_EXECUTION", "CANONICAL_HANDLING_OWNER",
                  "ACTUAL_LOOSE_INVENTORY_AND_PAID_WORKPIECE_BINDING", "SHARED_PROFILE_PUBLICATION"]}
    raw_record = (json.dumps(record, indent=2)+"\n").encode()
    raw_plan = (json.dumps(plan, indent=2)+"\n").encode()
    command = I.M.I.M.W.read_record(I.A.CONTACT/"analysis-carry-arm-v7/invocation.json")["command"]
    # The accepted proof supplies the exact already-qualified WorldBasis numerical equation.
    with I.A.original_source_inputs():
        basis_proof = P.content.read_json(Path(command[command.index("--proof")+1]),
                                         command[command.index("--proof-sha256")+1])
    image, budget = P.content.encode(wanted, plan, basis_proof, I.M.IMAGE_SHA,
        hashlib.sha256(raw_record).hexdigest(), hashlib.sha256(raw_plan).hexdigest())
    P.require(B.candidate_pins(candidate) == images and all(I.A.digest(I.ROOT/p) == sha for p, sha in producers.items()),
              "ASSEMBLY_SOURCE_DRIFT")
    compilation = {"schema": 1, "content_sha256": hashlib.sha256(image).hexdigest(), "content_bytes": len(image),
                   "parts": 2, "body_bones": 24, "palette_rows": 25, "clips": 3, "keys": sum(COUNTS),
                   "intervals": sum(v-1 for v in COUNTS), "presentation_budget": budget,
                   "production_qualified": False}
    return {"candidate.json": raw_record, "plan.json": raw_plan, "mole-worker.ugactor": image,
            "compilation.json": (json.dumps(compilation, indent=2)+"\n").encode()}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--proof", type=Path, required=True)
    parser.add_argument("--tool-proof", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "ASSEMBLY_OUTPUT_EXISTS")
    outputs = build(args.candidate, args.proof, args.tool_proof)
    args.out.mkdir(parents=True)
    for name, raw in outputs.items():
        with (args.out/name).open("xb") as stream:
            stream.write(raw)
    print(outputs["compilation.json"].decode(), end="")


if __name__ == "__main__":
    main()
