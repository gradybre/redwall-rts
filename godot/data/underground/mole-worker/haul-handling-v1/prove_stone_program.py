#!/usr/bin/env python3
"""Continuous source proof of a stone motion clip (ADR 1206): wood's prove_program.prove on the lump.

Unchanged from wood: every affine interpolation interval of every full body/clothing triangle against every
stone triangle (solid separation), a closed-cell foot contact shared by both ends of every interval, nothing
below the floor at any key and, while the stone is carried, both exact hand-edge/stone-triangle certificates on
every interval. Added for the non-convex lump: exact star-shaped containment at every key.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

import author_handling as A
import author_stone_grip as G
import prove_program as PP
import prove_stone_star as SP
import stone_geometry as SG

WITNESSES = A.I.HERE / "evidence/stone-contact-v1/static-contact.json"
GRIP_CLIPS = ("lift", "place", "hold", "enter", "carry", "exit")


def prove_clip(inputs: tuple, path: Path, grip: bool) -> dict:
    _, body, _, _, topology, _, _, _ = inputs
    stone, stone_tri = G.stone_part()
    case = PP.load_case(path)
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    pairs = json.loads(WITNESSES.read_text())["static_source"]["hand_contact_witnesses"]
    result = PP.prove(case, body, stone, body_tri, stone_tri, topology["rig_binding"], pairs, grip)
    vertices = SP.solid_vertices(body, topology)
    inside = [{"frame": at, "vertices": found} for at in range(case["frames"])
              if (found := SG.solid_inside(PP.at_frame(case, at), body, stone, stone_tri, vertices))]
    result["star_contained_vertices"] = inside
    result["non_grip_separation"] = not result["unresolved"] and not result["initial_contained_vertices"] and not inside
    result["passes"] = (result["all_intervals_complete"] and result["non_grip_separation"] and
                        not result["floor_penetrations"] and result["supported_feet"] and
                        (result["continuous_two_hand_contact"] or not grip))
    return result


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "clip-file", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--grip", action="store_true", help="the stone is carried: require both hand certificates")
    args = parser.parse_args()
    A.require(not args.out.exists(), "STONE_OUTPUT_EXISTS")
    result = prove_clip(A.I.current_inputs(args.palette, args.grip_palette), args.clip_file, args.grip)
    paths = (Path(__file__), Path(PP.__file__), Path(SG.__file__), Path(G.__file__), args.clip_file, WITNESSES)
    report = {"schema": 1, "adr": "1206", "production_qualified": False, "clip": args.clip_file.name,
              "grip_required": args.grip, "source_proof": result,
              "scope": "All affine source interpolation intervals, full current triangles; exact star containment at every key. No native error allowance, timing or runtime permission.",
              "source_sha256": {str(p.resolve().relative_to(A.I.ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"clip": args.clip_file.name, "passes": result["passes"], "pairs": result["pairs"],
                      "unresolved": len(result["unresolved"]), "star_inside": len(result["star_contained_vertices"]),
                      "grip_failures": len(result["grip_failures"]), "floor_bad": len(result["floor_penetrations"]),
                      "support_failures": len(result["support_failures"])}))


if __name__ == "__main__":
    main()
