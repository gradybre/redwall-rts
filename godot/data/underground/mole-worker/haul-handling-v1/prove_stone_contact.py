#!/usr/bin/env python3
"""Exact static stone-grip proof (ADR 1206): wood's prove_static_contact.prove applied to the lump, unchanged.

The same complete rules hold: every solid (non-grip) body triangle separates from every stone triangle, no solid
vertex lies inside the closed stone, each hand has an exact rational edge/triangle witness on the stone, and
both soles and the stone have exact floor contacts in the one-unit cell with nothing below the floor.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

import author_handling as A
import author_stone_grip as G
import prove_static_contact as PS


def prove_candidate(inputs: tuple, candidate: Path) -> dict:
    _, body, _, _, topology, _, _, _ = inputs
    stone, stone_tri = G.stone_part()
    source = np.load(candidate / "poses.npz", allow_pickle=False)
    case = {"frames": 1, "matrices": source["matrices"][1:2], "grounding": source["grounding"][1:2]}
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    return PS.prove(case, body, stone, body_tri, stone_tri, topology["rig_binding"])


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "candidate", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    A.require(not args.out.exists(), "STONE_OUTPUT_EXISTS")
    proof = prove_candidate(A.I.current_inputs(args.palette, args.grip_palette), args.candidate)
    proof["wood_triangles_meaning"] = "stone triangles (field name kept from the shared wood prover)"
    passed = (proof["non_grip_separation"] and proof["source_contact_exists"] and
              proof["floor"]["source_not_below_floor"] and proof["floor"]["three_contacts_present"])
    result = {"schema": 1, "adr": "1206", "production_qualified": False, "static_source": proof,
              "passes_static_rules": passed,
              "scope": "Exact F32 input coefficients evaluated as source rational skin geometry; no native error or temporal qualification.",
              "source_sha256": {str(p.resolve().relative_to(A.I.ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in (Path(__file__), Path(PS.__file__), Path(G.__file__), Path(A.__file__),
                                          G.STONE, args.candidate / "poses.npz", args.candidate / "candidate.json")},
              "pending": ["human grip review", "lift/place program", "loaded gait", "joins", "native error enclosure",
                          "runtime source/quantity/role admission"]}
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"output": str(args.out), "passes": passed, "separation": proof["non_grip_separation"],
                      "contact": proof["source_contact_exists"], "unresolved": len(proof["unresolved"]),
                      "inside": len(proof["non_grip_vertices_inside_stock"]),
                      "floor": proof["floor"]["three_contacts_present"], "pairs": proof["pairs"]}))


if __name__ == "__main__":
    main()
