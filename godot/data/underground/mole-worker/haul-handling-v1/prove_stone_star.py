#!/usr/bin/env python3
"""Exact star-shaped containment for a stone pose (ADR 1206): no solid body vertex inside or on the lump.

Supplements the shared static/program provers, whose containment test assumes a convex stock. Their surface
separation is unchanged and still required; this replaces only the containment half for the non-convex lump.
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
import stone_geometry as SG


def solid_vertices(body: dict, topology: dict) -> tuple:
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    solid, _ = PS.hand_partition(body, body_tri, topology["rig_binding"])
    return np.unique(body_tri[solid])


def frame_case(path: Path, frame: int) -> dict:
    with np.load(path, allow_pickle=False) as image:
        return {"frames": 1, "matrices": image["matrices"][frame:frame + 1], "grounding": image["grounding"][frame:frame + 1]}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "poses", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--frames", type=int, nargs="+", required=True)
    args = parser.parse_args()
    A.require(not args.out.exists(), "STONE_OUTPUT_EXISTS")
    _, body, _, _, topology, _, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    stone, tri = G.stone_part()
    vertices = solid_vertices(body, topology)
    rows = [{"frame": frame, "solid_vertices_inside": SG.solid_inside(frame_case(args.poses, frame), body, stone, tri, vertices)}
            for frame in args.frames]
    result = {"schema": 1, "adr": "1206", "production_qualified": False, "poses": str(args.poses.name),
              "solid_vertices": len(vertices), "frames": rows,
              "no_solid_vertex_inside": all(not row["solid_vertices_inside"] for row in rows),
              "scope": "Exact star-shaped containment about the lump's origin; surface separation is proved separately.",
              "source_sha256": {str(p.resolve().relative_to(A.I.ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in (Path(__file__), Path(SG.__file__), Path(G.__file__), args.poses)}}
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"out": str(args.out), "no_solid_vertex_inside": result["no_solid_vertex_inside"]}))


if __name__ == "__main__":
    main()
