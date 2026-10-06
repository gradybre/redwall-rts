#!/usr/bin/env python3
"""Numeric aids for the human stone-grip review (ADR 1206); float diagnostics beside the exact proof.

For one candidate it reports, against the closed star-shaped lump (radial test, as derive_stone_scale.py):
* per hand, how many grip (distal palm) vertices are inside and the deepest radial penetration, in u;
* wrist clearance: the smallest radial gap of any solid vertex whose dominant bone is the forearm or hand;
* torso clearance: the smallest radial gap of any other solid vertex;
* the exact sole and stone floor gaps, copied from the candidate's static-contact.json.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

import author_handling as A
import author_stone_grip as G
import derive_stone_scale as D
import prove_static_contact as PS

ARM_BONES = {"left": (14, 15), "right": (18, 19)}


def radial(points: np.ndarray, stone_u: np.ndarray, tri: np.ndarray, centre: np.ndarray) -> np.ndarray:
    """Signed radial gap in u: positive outside the lump, negative inside."""
    radius, distance = D.ray_radius(stone_u, tri, centre, points)
    return distance - radius


def review(inputs: tuple, candidate: Path) -> dict:
    _, body, _, _, topology, _, _, _ = inputs
    stone, tri = G.stone_part()
    source = np.load(candidate / "poses.npz", allow_pickle=False)
    case = {"frames": 2, "matrices": source["matrices"], "grounding": source["grounding"]}
    points = A.I.points_at(case, body, 1)
    stone_u = A.I.points_at(case, stone, 1, 24)
    centre = stone_u.mean(axis=0)
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    solid, hands = PS.hand_partition(body, body_tri, topology["rig_binding"])
    geometry = body["geometry"][0]
    dominant = np.take_along_axis(geometry["ids"], geometry["weights"].argmax(axis=1)[:, None], axis=1)[:, 0]
    grip_vertices = [np.unique(body_tri[rows]) for rows in hands]
    solid_vertices = np.setdiff1d(np.unique(body_tri[solid]), np.concatenate(grip_vertices))
    result = {"hands": {}, "stone_bounds_u": A.I.box(stone_u)}
    for side, vertices in zip(("left", "right"), grip_vertices):
        gap = radial(points[vertices], stone_u, tri, centre)
        arm = solid_vertices[np.isin(dominant[solid_vertices], ARM_BONES[side])]
        result["hands"][side] = {"grip_vertices": len(vertices), "grip_vertices_inside": int(np.sum(gap < 0)),
                                 "deepest_grip_penetration_u": round(float(-gap.min()), 2),
                                 "wrist_forearm_min_gap_u": round(float(radial(points[arm], stone_u, tri, centre).min()), 2)}
    rest = solid_vertices[~np.isin(dominant[solid_vertices], ARM_BONES["left"] + ARM_BONES["right"])]
    gaps = radial(points[rest], stone_u, tri, centre)
    nearest = int(rest[int(np.argmin(gaps))])
    result["torso_legs_head_min_gap_u"] = round(float(gaps.min()), 2)
    result["torso_legs_head_nearest"] = {"vertex": nearest, "point_u": points[nearest].round(1).tolist(),
                                         "dominant_bone": topology["rig_binding"]["bones"][int(dominant[nearest])].get("name")}
    proof = json.loads((candidate / "static-contact.json").read_text())["static_source"]
    result["floor_contacts_exact"] = [{"role": row["role"], "gap_u": row["source_gap_u"][0] / row["source_gap_u"][1]}
                                      for row in proof["floor"]["contacts"]]
    result["witness_points_u"] = [[round(n / d, 2) for n, d in w["point_u"]] for w in proof["hand_contact_witnesses"]]
    return result


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "candidate", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    A.require(not args.out.exists(), "STONE_OUTPUT_EXISTS")
    result = review(A.I.current_inputs(args.palette, args.grip_palette), args.candidate)
    result.update({"schema": 1, "adr": "1206", "production_qualified": False,
                   "scope": "Float radial diagnostics for a human reviewer; the exact rules are in static-contact.json.",
                   "inputs_sha256": {str(p.resolve().relative_to(A.I.ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                     for p in (Path(__file__), args.candidate / "poses.npz",
                                               args.candidate / "static-contact.json")}})
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result["hands"]), result["torso_legs_head_min_gap_u"])


if __name__ == "__main__":
    main()
