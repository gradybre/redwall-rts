#!/usr/bin/env python3
"""Inspect exact accepted body/pick and paid bearer source; emit no permission."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
APPROACH = HERE.parent / "work-approach-v1/compile_work_approach.py"
APPROACH_SHA = "de98c0c3d7de383844bc2369300668d511d8256f7858ec95a5e2c6ca7d08ab9a"


def module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


if (not APPROACH.is_file() or APPROACH.is_symlink() or
        hashlib.sha256(APPROACH.read_bytes()).hexdigest() != APPROACH_SHA):
    raise ValueError("ASSEMBLY_INPUT_ADAPTER")
A = module("assembly_original_inputs", APPROACH)
M, P = A.M, A.P


def source_inputs():
    """Reconstruct all original source inputs; this does not attest current consumers."""
    P.require(APPROACH_SHA and A.digest(APPROACH) == APPROACH_SHA, "ASSEMBLY_INPUT_ADAPTER")
    basis = ROOT / "godot/demo/assets/underground-matrices/world-yaw-v1.ugyaw"
    with A.original_source_inputs():
        pins = M.input_pins(basis)
        cases, parts, rig, topology, roots, count, historical, roles = M.source_program()
        P.require(count == 537 and M.input_pins(basis) == pins, "ASSEMBLY_SOURCE_CLOSURE")
    return cases, parts, rig, topology, roots, count, historical, roles, pins


def targets():
    """Derive complete paid bearer boxes from the immutable existing timber parts, never a new bill or mesh."""
    authors = M.I.I
    prefix = A.CONTACT / "stair-sequence-prefix-v1/first-entry-prefix-v1.source.json"
    packet = P.content.read_json(prefix, authors.PREFIX_SHA, 65536)
    return authors.workpiece_targets(packet)


def inspect():
    """Keep source dimensions and actual skinning separate from candidate contact claims."""
    cases, parts, rig, topology, roots, count, historical, _, pins = source_inputs()
    ready = cases[0]
    authors = M.I.I
    parents, inverse, inverse_inverse = authors.A.hierarchy(rig)
    globals_, _, fit = authors.A.joints(ready, 8, parents, inverse_inverse)
    grounding = float(ready["grounding"][8])
    prefix = A.CONTACT / "stair-sequence-prefix-v1/first-entry-prefix-v1.source.json"
    packet = P.content.read_json(prefix, authors.PREFIX_SHA, 65536)
    target = authors.workpiece_targets(packet)
    hands = []
    for joint in (9, 12, 13, 14, 15, 16, 17, 18, 19):
        hands.append({"bind": joint, "name": rig["rig_binding"]["bones"][joint]["name"],
                      "root_u": ((globals_[joint][:3, 3] + [0, grounding, 0]) * 1024).tolist()})
    P.require(len(cases) == 14 and len(parts) == 2 and len(parents) == 24 and
              [sum(len(s) for s in rows) for rows in topology] == [10209, 1150], "ASSEMBLY_SOURCE_COUNTS")
    return {"schema": 1, "status": "SOURCE_INSPECTION_ONLY", "production_qualified": False,
            "actor_sha256": M.IMAGE_SHA, "profile_source_count": 1, "existing_clips": len(cases),
            "verified_source_files": count, "source_inputs": pins, "historical_source_snapshot": historical,
            "body_triangles": 10209, "pick_triangles": 1150, "body_bones": 24,
            "palette_rows": int(ready["matrices"].shape[1]), "root_domain_u": roots,
            "ready_pose_sha256": hashlib.sha256(ready["matrices"][8].tobytes() +
                ready["grounding"][8:9].tobytes()).hexdigest(),
            "ready_joint_positions_u": hands, "right_hand_pick_fit": fit.tolist(),
            "targets": target,
            "notes": ["Bill mass is whole-assembly accounting, not the selected bearer mass.",
                      "A hand triangle witness is not a planar contact profile or runtime permission."]}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "ASSEMBLY_OUTPUT_EXISTS")
    result = inspect()
    result["producer_sources"] = {str(p.relative_to(ROOT)): A.digest(p) for p in (Path(__file__), APPROACH)}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("x") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")
    print(json.dumps({k: result[k] for k in ("status", "verified_source_files", "ready_joint_positions_u", "targets")}))


if __name__ == "__main__":
    main()
