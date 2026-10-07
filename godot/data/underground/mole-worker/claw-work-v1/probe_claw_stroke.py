#!/usr/bin/env python3
"""Bounded authoring search for the claw stroke (ADR 1217 step 1); fixed arm lengths are never relaxed.

For each recipe on the grid, every one of the 32 distinct stroke keys must solve with the unchanged arm links.
Solvable recipes are then sampled in float: the lowest vertex outside the right paw must stay at or above the
face (the soles rest 1/512 u above it), and every right-paw vertex below the face must lie inside the target cube.
Reach is necessary, not sufficient: the exact proofs in `prove_claw_stroke.py` decide.

    $PY .../probe_claw_stroke.py <out.json>
"""
from __future__ import annotations

import argparse
import itertools
import json
from pathlib import Path
import sys

import numpy as np

import author_claw_stroke as W

SRC, A = W.SRC, W.A
GRID = {"x_u": (128, 160), "anchor_z_u": (-640, -608, -576, -544, -512, -480), "rake_u": (32, 64),
        "lean_degrees": (40, 50, 60, 70), "drop_u": (32, 64, 96), "tilt_degrees": (45, 60, 75),
        "roll_degrees": (90, 180, 270), "station_inset_u": (0, 106)}


def solvable(src: dict, recipe: dict, claw: np.ndarray) -> bool:
    """Every stroke key solves with unchanged arm links."""
    base, _ = W.posture(src, recipe["drop_u"], recipe["lean_degrees"])
    try:
        for target in W.loop_targets(recipe)[:-1]:
            W.reach(base, claw, target, recipe, float(src["grounding"]))
    except ValueError:
        return False
    return True


def sample(src: dict, recipe: dict, vertex: int, paw: np.ndarray) -> dict:
    """Float checks over the stroke keys only (the entry is checked by the exact proofs)."""
    work, _, _, _ = W.work_clip(src, recipe)
    cube = W.target_cube(src, recipe)
    lowest, escapes = np.inf, 0
    for frame in range(work["frames"] - 1):
        points = SRC.I.points_at(work, src["body"], frame)
        lowest = min(lowest, float(points[~paw, 1].min()))
        below = points[paw & (points[:, 1] < 0)]
        escapes += int(np.sum((below[:, 0] <= cube[0]) | (below[:, 0] >= cube[3]) |
                              (below[:, 2] <= cube[2]) | (below[:, 2] >= cube[5])))
    return {"lowest_non_paw_u": round(lowest, 3), "paw_vertices_below_face_outside_cube": escapes}


def main() -> int:
    """Run the grid and write every row."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("--palette", type=Path, default=SRC.PALETTE)
    args = parser.parse_args()
    W.require(not args.out.exists(), "CLAW_OUTPUT_EXISTS")
    src = SRC.read_claw_source(args.palette)
    vertex, claw = W.claw_vertex(src)
    geometry = src["body"]["geometry"][0]
    paw = np.any((geometry["ids"] == 19) & (geometry["weights"] > 0), axis=1)
    rows = []
    for values in itertools.product(*GRID.values()):
        recipe = dict(zip(GRID, values))
        cube = W.target_cube(src, recipe)
        if not (cube[2] < recipe["anchor_z_u"] and recipe["anchor_z_u"] + recipe["rake_u"] < cube[5]):
            continue
        row = {"recipe": recipe, "solvable": solvable(src, recipe, claw)}
        if row["solvable"]:
            row.update(sample(src, recipe, vertex, paw))
        rows.append(row)
    clear = [r for r in rows if r["solvable"] and r["lowest_non_paw_u"] >= 0 and
             r["paw_vertices_below_face_outside_cube"] == 0]
    result = {"schema": 1, "decision": "1217", "grid": GRID, "claw_vertex": vertex, "candidates": len(rows),
              "solvable": sum(r["solvable"] for r in rows), "sampled_clear": len(clear), "rows": rows,
              "production_qualified": False}
    args.out.write_text(json.dumps(result, indent=1) + "\n")
    print(json.dumps({k: result[k] for k in ("candidates", "solvable", "sampled_clear", "claw_vertex")}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
