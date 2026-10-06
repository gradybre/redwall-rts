#!/usr/bin/env python3
"""Bounded float search for stone grip candidates (ADR 1206); fixed arm lengths are never relaxed.

Like probe_contact_reach.py for wood: it ranks recipes, it proves nothing. Per recipe it reports, at sampled
vertices, how many distal-palm vertices of each hand lie inside the lump (contact needs some inside and some
outside) and how many solid body vertices do (must be zero). Finalists go to prove_stone_contact.py.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
from pathlib import Path

import numpy as np

import author_handling as A
import author_stone_grip as G
import derive_stone_scale as D
import prove_static_contact as PS


def inside(points: np.ndarray, stone_u: np.ndarray, tri: np.ndarray, centre: np.ndarray) -> np.ndarray:
    radius, distance = D.ray_radius(stone_u, tri, centre, points)
    return distance < radius


def score(inputs: tuple, recipe: dict, cache: dict) -> dict:
    rows, body, log, _, topology, compact, _, _ = inputs
    try:
        cases, result = G.author(inputs, recipe, False)
    except (ValueError, A.I.ENVELOPE.Refused) as error:
        return {"recipe": recipe, "refusal": str(error)}
    case = {"frames": 1, "matrices": cases[1]["matrices"], "grounding": cases[1]["grounding"]}
    points = A.I.points_at(case, body, 0)
    stone_u = A.I.points_at(case, cache["stone"], 0, 24)
    centre = stone_u.mean(axis=0)
    hands = [inside(points[rows_], stone_u, cache["tri"], centre) for rows_ in cache["hands"]]
    solid = inside(points[cache["solid"]], stone_u, cache["tri"], centre)
    return {"recipe": recipe, "hand_inside": [int(h.sum()) for h in hands], "hand_vertices": [len(h) for h in hands],
            "solid_inside": int(solid.sum()), "stone_bounds_u": A.I.box(stone_u)}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--stage", type=int, choices=(1, 2), default=1)
    args = parser.parse_args()
    A.require(not args.out.exists(), "STONE_OUTPUT_EXISTS")
    inputs = A.I.current_inputs(args.palette, args.grip_palette)
    _, body, _, _, topology, _, _, _ = inputs
    stone, tri = G.stone_part()
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    solid, hands = PS.hand_partition(body, body_tri, topology["rig_binding"])
    cache = {"stone": stone, "tri": tri, "solid": np.setdiff1d(np.unique(body_tri[solid]),
                                                               np.unique(body_tri[np.concatenate(hands)])),
             "hands": [np.unique(body_tri[rows]) for rows in hands]}
    results = []
    if args.stage == 1:
        grid = [{"lean": lean, "ahead": ahead, "drop": 96, "raise": raise_, "back": [192, 160], "in": [inward, inward]}
                for lean, ahead, raise_, inward in itertools.product((85, 95), range(448, 705, 64), (64, 128, 192),
                                                                     range(128, 289, 32))]
    else:
        # Stage 2 narrows stage 1's shallowest two-hand crossing (lean 95, ahead 576, raise 128, in 224).
        grid = [{"lean": 95, "ahead": 576, "drop": 96, "raise": raise_, "back": [192, 160], "in": [left, right]}
                for raise_, left, right in itertools.product((96, 112, 128, 144, 160), range(184, 241, 8),
                                                             range(184, 249, 8))]
    for recipe in grid:
        results.append(score(inputs, recipe, cache))
    good = [r for r in results if "refusal" not in r and r["solid_inside"] == 0 and
            all(0 < n < total for n, total in zip(r["hand_inside"], r["hand_vertices"]))]
    report = {"schema": 1, "adr": "1206", "production_qualified": False,
              "purpose": "bounded float ranking of stone grip recipes; not contact, clearance or support proof",
              "stage": args.stage, "candidates": len(results), "solid_clear_with_both_hands_crossing": good, "results": results,
              "producer_sources": {str(Path(p).relative_to(A.I.ROOT)): hashlib.sha256(Path(p).read_bytes()).hexdigest()
                                   for p in (__file__, G.__file__, A.__file__, D.__file__)}}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"stage": args.stage, "candidates": len(results), "good": len(good)}))


if __name__ == "__main__":
    main()
