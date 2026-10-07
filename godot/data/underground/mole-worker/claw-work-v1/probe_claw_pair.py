#!/usr/bin/env python3
"""Bounded authoring search for the two-paw stroke (ADR 1217 step 1b); fixed arm lengths are never relaxed.

Every stroke key must solve both arms with unchanged links. Solvable recipes are sampled in float on the stroke
keys: the lowest vertex outside both paws must stay at or above the face, every paw vertex below the face must lie
in the moved-in cube, and the smallest vertex distance between the two arms is recorded on every other key. The exact proofs in
`prove_claw_pair.py` decide.

    $PY .../probe_claw_pair.py <out.json>
"""
from __future__ import annotations

import argparse
import itertools
import json
from pathlib import Path
import sys

import numpy as np

import author_claw_pair as PAIR

W, SRC = PAIR.W, PAIR.SRC
GRID = {"right_x_u": (128, 160, 192, 224), "left_x_u": (-128, -160, -192, -224), "anchor_z_u": (-544, -512),
        "rake_u": (32,), "lean_degrees": (60, 70), "drop_u": (96, 128), "tilt_degrees": (60,),
        "right_roll_degrees": (90,), "left_roll_degrees": (0, 45, 90), "head_lift_degrees": (0, 30, 60)}
MIRRORED = True  # The paws dig at mirrored lateral offsets.


def weighted(src: dict, bones: tuple) -> np.ndarray:
    """Vertices with any weight on the given bones."""
    geometry = src["body"]["geometry"][0]
    return np.any(np.isin(geometry["ids"], bones) & (geometry["weights"] > 0), axis=1)


def sample(src: dict, recipe: dict) -> dict:
    """Float checks over the 32 distinct stroke keys."""
    work, _, _ = PAIR.work_clip(src, recipe)
    cube = PAIR.target_cube(src)
    paws = weighted(src, (15, 19))
    right, left = weighted(src, PAIR.ARMS["right"]), weighted(src, PAIR.ARMS["left"])
    right, left = right & ~left, left & ~right
    lowest, escapes, apart = np.inf, 0, np.inf
    for frame in range(work["frames"] - 1):
        points = SRC.I.points_at(work, src["body"], frame)
        lowest = min(lowest, float(points[~paws, 1].min()))
        below = points[paws & (points[:, 1] < 0)]
        escapes += int(np.sum((below[:, 0] <= cube[0]) | (below[:, 0] >= cube[3]) |
                              (below[:, 2] <= cube[2]) | (below[:, 2] >= cube[5])))
        if frame % 2:
            continue
        a, b = points[right], points[left]
        for at in range(0, len(a), 512):
            apart = min(apart, float(np.sqrt(((a[at:at + 512, None] - b[None]) ** 2).sum(-1)).min()))
    return {"lowest_non_paw_u": round(lowest, 3), "paw_vertices_below_face_outside_cube": escapes,
            "arm_to_arm_vertex_gap_u": round(apart, 1)}


def solvable(src: dict, recipe: dict) -> bool:
    """Both arms solve on every stroke key."""
    try:
        PAIR.work_clip(src, recipe)
    except ValueError:
        return False
    return True


def main() -> int:
    """Run the grid and write every row."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("--palette", type=Path, default=SRC.PALETTE)
    args = parser.parse_args()
    W.require(not args.out.exists(), "CLAW_PAIR_OUTPUT_EXISTS")
    src = SRC.read_claw_source(args.palette)
    rows = []
    for values in itertools.product(*GRID.values()):
        recipe = dict(zip(GRID, values))
        if MIRRORED and recipe["left_x_u"] != -recipe["right_x_u"]:
            continue
        row = {"recipe": recipe, "solvable": solvable(src, recipe)}
        if row["solvable"]:
            row.update(sample(src, recipe))
        rows.append(row)
        print(json.dumps(row), file=sys.stderr, flush=True)
    clear = [r for r in rows if r["solvable"] and r["lowest_non_paw_u"] >= 0 and
             r["paw_vertices_below_face_outside_cube"] == 0]
    result = {"schema": 1, "decision": "1217", "grid": GRID, "candidates": len(rows),
              "solvable": sum(r["solvable"] for r in rows), "sampled_clear": len(clear), "rows": rows,
              "production_qualified": False}
    args.out.write_text(json.dumps(result, indent=1) + "\n")
    print(json.dumps({k: result[k] for k in ("candidates", "solvable", "sampled_clear")}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
