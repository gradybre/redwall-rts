#!/usr/bin/env python3
"""Derive the carried stone lump's scale from the certified wood grip (ADR 1206); never a published size.

The lump (evidence/stone-source-v1/native-stone.json) rests on the floor at S, centred on S in X/Z, with the
dressing's 0.8 vertical squash and no rotation, scaled by s metres per unit. For each s the tool asks:

* seat: do both certified hand contacts (rows.json grip_contacts, C - S) lie on or inside the closed lump?
* clear: does every solid (non-grip) body vertex of the reviewed static pose lie outside it?

The lump is a radially displaced sphere, so it is star-shaped about its centre: a point is inside exactly when
it is no farther from the centre than the surface along the same ray. Float diagnostics only; a chosen size
still needs the exact static-contact proof.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

import author_handling as A
import prove_static_contact as PS

HERE = Path(__file__).resolve().parent
STONE = HERE / "evidence/stone-source-v1/native-stone.json"
ROWS = HERE / "evidence/haul-rows-v1/rows.json"
POSE = HERE / "evidence/static-contact-review-v1/candidate/poses.npz"
SQUASH = 0.8
S_U = np.array([0.0, 0.0, -576.0])


def ray_radius(points: np.ndarray, tri: np.ndarray, centre: np.ndarray, queries: np.ndarray) -> np.ndarray:
    """Distance from the centre to the surface along each query's ray (Moller-Trumbore, all triangles)."""
    d = queries - centre
    norm = np.linalg.norm(d, axis=1)
    d = d / norm[:, None]
    a, b, c = points[tri[:, 0]], points[tri[:, 1]], points[tri[:, 2]]
    e1, e2 = b - a, c - a
    best = np.full(len(queries), np.inf)
    for k in range(len(tri)):
        p = np.cross(d, e2[k])
        det = p @ e1[k]
        ok = np.abs(det) > 1e-12
        inv = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
        t_vec = centre - a[k]
        u = (p @ t_vec) * inv
        q = np.cross(t_vec, e1[k])
        v = (d * q).sum(axis=1) * inv
        t = (q @ e2[k]) * inv
        hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0)
        best = np.where(hit, np.minimum(best, t), best)
    A.require(np.all(np.isfinite(best)), "STONE_NOT_STAR_SHAPED")
    return best, norm


def lump(scale_m: tuple, unit: np.ndarray) -> tuple:
    """World lump vertices in u, resting 1/512 u above the floor at S like the wood stock."""
    points = unit * np.asarray(scale_m) * 1024
    centre = np.array([S_U[0], -points[:, 1].min() + 1 / 512, S_U[2]])
    return points + centre, centre


def assess(scale_m: tuple, unit: np.ndarray, tri: np.ndarray, contacts: np.ndarray, solid: np.ndarray) -> dict:
    points, centre = lump(scale_m, unit)
    radius, distance = ray_radius(points, tri, centre, np.concatenate((contacts, solid)))
    ratio = distance / radius
    return {"scale_m": [round(v, 6) for v in scale_m], "contact_ratio": ratio[:2].round(4).tolist(),
            "seats_both": bool(np.all(ratio[:2] <= 1)), "solid_vertices_inside": int(np.sum(ratio[2:] < 1)),
            "lump_bounds_u": np.concatenate((points.min(0), points.max(0))).round(1).tolist()}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    A.require(not args.out.exists(), "STONE_OUTPUT_EXISTS")
    stone = json.loads(STONE.read_text())
    unit = np.asarray(stone["points"], dtype=np.float64)
    tri = np.asarray(stone["indices"], dtype=np.int32).reshape(-1, 3)
    grip = json.loads(ROWS.read_text())["station"]["grip_contacts"]
    contacts = np.array([[float(n) / float(d) for n, d in row["C_minus_R_u"]] for row in grip]) + [0, 0, 576] + S_U
    _, body, _, _, topology, _, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    source = np.load(POSE, allow_pickle=False)
    case = {"frames": 1, "matrices": source["matrices"][1:2], "grounding": source["grounding"][1:2]}
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    solid_tri, _ = PS.hand_partition(body, body_tri, topology["rig_binding"])
    solid = A.I.points_at(case, body, 0)[np.unique(body_tri[solid_tri])]
    sweep = [assess((s, s * SQUASH, s), unit, tri, contacts, solid) for s in np.arange(0.02, 0.801, 0.01)]
    seat = next((row for row in sweep if row["seats_both"]), None)
    clear = [row for row in sweep if row["solid_vertices_inside"] == 0]
    # Relaxed shape: drop the squash and stretch the lump along the log's own envelope (a stone rod).
    grid = [round(v, 2) for v in np.arange(0.04, 0.121, 0.02)]
    rods = [assess((sx, sy, sz), unit, tri, contacts, solid) for sx in np.round(np.arange(0.32, 0.561, 0.04), 2)
            for sy in grid for sz in grid + [round(v, 2) for v in np.arange(0.16, 0.561, 0.08)]]
    report = {"schema": 1, "adr": "1206", "production_qualified": False,
              "rod_sweep_seats_and_clears": [row for row in rods if row["seats_both"] and not row["solid_vertices_inside"]],
              "rod_sweep_closest": min(rods, key=lambda row: max(row["contact_ratio"]) + row["solid_vertices_inside"]),
              "rule": "lump at S on the floor, squash 0.8, no rotation, uniform scale s m/unit",
              "contacts_u": contacts.round(3).tolist(), "solid_body_vertices": len(solid),
              "smallest_seating_scale": seat, "largest_clear_scale": clear[-1] if clear else None,
              "feasible": bool(seat and clear and seat["scale_m"][0] <= clear[-1]["scale_m"][0]),
              "sweep": sweep,
              "inputs_sha256": {str(p.relative_to(A.I.ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in (Path(__file__), STONE, ROWS, POSE)}}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: report[k] for k in ("smallest_seating_scale", "largest_clear_scale", "feasible")}))


if __name__ == "__main__":
    main()
