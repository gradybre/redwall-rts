#!/usr/bin/env python3
"""Reproduce the explicit actual foot labels; this reader never removes collision geometry."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np

SOURCE = Path(__file__).resolve().parent.parent / "assess_stair_rig.py"
SPEC = importlib.util.spec_from_file_location("actual_stair_anatomy", SOURCE)
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    M.P.require(not args.out.exists() and not args.out.is_symlink(), "ANATOMY_OUTPUT_EXISTS")
    source_pin = M.P.content.file_hash(SOURCE)
    _, parts, rig, topology, _, _, _ = M.read_actual_source()
    part, triangles = parts[0], topology[0][0]
    geometry = part["geometry"][0]
    rows = []
    for side, _, _, ankle, toe in M.LEGS:
        mask = M.anatomical_foot_triangles(part, triangles, (ankle, toe))
        vertices = np.unique(triangles[mask])
        rows.append({"side": side, "triangles": int(mask.sum()), "vertices": len(vertices),
                     "triangle_mask_sha256": hashlib.sha256(mask.astype(np.uint8).tobytes()).hexdigest(),
                     "contains_crotch_vertex_5862": bool(5862 in vertices)})
    influences = [{"bone": rig["rig_binding"]["bones"][int(bone)]["name"], "weight": float(weight)}
                  for bone, weight in zip(geometry["ids"][5862], geometry["weights"][5862]) if weight > 0]
    report = {"schema": 1,
              "label": "largest actual positive foot/toe influence; every touched triangle kept whole; ties retained",
              "source_sha256": source_pin,
              "topology_sha256": hashlib.sha256(triangles.tobytes()).hexdigest(),
              "whole_collision_triangles": len(triangles), "whole_collision_vertices": len(geometry["points"]),
              "foot_contacts": rows, "original_overbroad_example": {"vertex": 5862, "influences": influences},
              "collision_omissions": 0, "production_qualified": False}
    M.P.require(M.P.content.file_hash(SOURCE) == source_pin, "ANATOMY_SOURCE_DRIFT")
    with args.out.open("x") as output:
        json.dump(report, output, indent=2)
        output.write("\n")


if __name__ == "__main__":
    main()
