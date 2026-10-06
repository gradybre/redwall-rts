#!/usr/bin/env python3
"""Prove the stone stand joins (ADR 1206) with wood's join rules (prove_empty_walk.py).

Per join: exact floor and one-foot support on every rendered interval (prove_empty_walk.support_proof), complete
non-grip separation from the floor stone (prove_empty_walk.join_proof = prove_program.prove without grip), and
exact star containment at every key. The joins' all-yaw enclosure against rows A/A' is checked when the stone
rows are derived.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

import author_handling as A
import author_stone_grip as G
import prove_empty_walk as EW
import prove_program as PP
import prove_stone_star as SP
import stone_geometry as SG

CLIPS = ("enter_haul_stone", "leave_haul_stone")


def prove(inputs: tuple, folder: Path) -> dict:
    _, body, _, _, topology, _, _, _ = inputs
    stone, stone_tri = G.stone_part()
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    vertices = SP.solid_vertices(body, topology)
    result = {}
    for name in CLIPS:
        case = EW.load_case(folder / (name + ".npz"), 25, 0)
        proof = EW.support_proof(case, body, body_tri)
        proof["stock_separation"] = EW.join_proof(case, body, stone, body_tri, stone_tri, topology["rig_binding"])
        proof["star_contained_vertices"] = [
            {"frame": at, "vertices": found} for at in range(case["frames"])
            if (found := SG.solid_inside(PP.at_frame(case, at), body, stone, stone_tri, vertices))]
        separation = proof["stock_separation"]
        proof["passes"] = (proof["supported_feet"] and not proof["floor_penetrations"] and
                           separation["all_intervals_complete"] and not separation["unresolved"] and
                           not separation["initial_contained_vertices"] and not separation["floor_penetrations"] and
                           not proof["star_contained_vertices"])
        result[name] = proof
    return result


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "candidate", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    A.require(not args.out.exists(), "STONE_OUTPUT_EXISTS")
    proofs = prove(A.I.current_inputs(args.palette, args.grip_palette), args.candidate)
    paths = [Path(__file__), Path(EW.__file__), Path(PP.__file__), Path(SG.__file__)] + \
        [args.candidate / (name + ".npz") for name in CLIPS]
    report = {"schema": 1, "adr": "1206", "production_qualified": False, "source_proof": proofs,
              "passes": all(row["passes"] for row in proofs.values()),
              "source_sha256": {str(p.resolve().relative_to(A.I.ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"passes": report["passes"], **{k: {"support": v["supported_feet"], "floor": len(v["floor_penetrations"]),
                      "unresolved": len(v["stock_separation"]["unresolved"]), "star": len(v["star_contained_vertices"])}
                      for k, v in proofs.items()}}))


if __name__ == "__main__":
    main()
