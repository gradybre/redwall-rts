#!/usr/bin/env python3
"""Bounded authoring search for paw handling and seating (ADR 1217 step 2); arm lengths are never relaxed.

Every key of both programs must solve both arms with unchanged links. Solvable recipes are sampled in float on the
seat and tap keys: no non-paw vertex below the floor or inside the bearer's section, every paw vertex below the top
plane inside the section, and the smallest vertex gap between the two arms at each work clip's first key. `prove_paw_seat.py` decides.

    $PY .../probe_paw_seat.py <out.json>
"""
from __future__ import annotations

import argparse
import itertools
import json
from pathlib import Path
import sys

import numpy as np

import author_paw_seat as SEAT

W, SRC = SEAT.W, SEAT.SRC
GRID = {"lean_degrees": (20, 30, 40, 50, 60), "drop_u": (32, 64, 96), "head_lift_degrees": (30, 60),
        "right_roll_degrees": (0, 90, 180, 270), "left_roll_degrees": (0, 90, 180, 270)}
SECTION = SEAT.SECTION.tolist()


def sample(src: dict, recipe: dict, paw: np.ndarray) -> dict:
    """Float checks over the seat and the tap."""
    programs = SEAT.author(src, recipe)
    lowest, intrude, escapes, apart = np.inf, 0, 0, np.inf
    geometry = src["body"]["geometry"][0]
    right = np.any(np.isin(geometry["ids"], (17, 18, 19)) & (geometry["weights"] > 0), axis=1)
    left = np.any(np.isin(geometry["ids"], (13, 14, 15)) & (geometry["weights"] > 0), axis=1)
    for name in ("seat", "tap"):
        work = programs[name][0]
        for frame in range(work["frames"] - 1):
            p = SRC.I.points_at(work, src["body"], frame)
            lowest = min(lowest, float(p[~paw, 1].min()))
            inside = np.all((p > SECTION[:3]) & (p < SECTION[3:]), axis=1)
            intrude += int(np.sum(inside & ~paw))
            low = p[paw & (p[:, 1] < SEAT.PLANE_U) & (p[:, 2] > SECTION[2]) & (p[:, 2] < SECTION[5])]
            escapes += int(np.sum((low[:, 0] <= SECTION[0]) | (low[:, 0] >= SECTION[3])))
            if frame == 0:
                a, b = p[right & ~left], p[left & ~right]
                apart = min(apart, min(float(np.sqrt(((a[i:i + 512, None] - b[None]) ** 2).sum(-1)).min())
                                       for i in range(0, len(a), 512)))
    return {"lowest_non_paw_u": round(lowest, 3), "non_paw_vertices_in_section": intrude,
            "paw_vertices_below_top_outside_section": escapes, "arm_to_arm_vertex_gap_u": round(apart, 1)}


def main() -> int:
    """Run the grid and write every row."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "PAW_SEAT_OUTPUT_EXISTS")
    src = SEAT.corrected_source()
    geometry = src["body"]["geometry"][0]
    paw = np.any(np.isin(geometry["ids"], [15, 19]) & (geometry["weights"] > 0), axis=1)
    rows = []
    for values in itertools.product(*GRID.values()):
        recipe = dict(zip(GRID, values))
        try:
            row = {"recipe": recipe, "solvable": True, **sample(src, recipe, paw)}
        except ValueError:
            row = {"recipe": recipe, "solvable": False}
        rows.append(row)
        print(json.dumps(row), file=sys.stderr, flush=True)
    clear = [r for r in rows if r["solvable"] and r["lowest_non_paw_u"] >= 0 and
             r["non_paw_vertices_in_section"] == 0 and r["paw_vertices_below_top_outside_section"] == 0]
    result = {"schema": 1, "decision": "1217", "grid": GRID, "section_u": SECTION, "candidates": len(rows),
              "solvable": sum(r["solvable"] for r in rows), "sampled_clear": len(clear), "rows": rows,
              "production_qualified": False}
    args.out.write_text(json.dumps(result, indent=1) + "\n")
    print(json.dumps({k: result[k] for k in ("candidates", "solvable", "sampled_clear")}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
