#!/usr/bin/env python3
"""Bounded float search for the tread fitting motion (ADR 1217 step 2d); arm lengths are never relaxed.

Each recipe authors both programs at the tread site (`prove_tread_fit.site`, bearer top 128). On every third key of
both entries and works, plus each clip's last key, it measures in float: the smallest vertex gap between arm-only
vertices and leg vertices (dominant hip/leg bones, no arm weight), and the number of vertices strictly inside the
bearer, the deck behind or below the support deck's top over the deck. `prove_tread_fit.py` decides.

    $PY .../probe_tread_fit.py <out.json>
"""
from __future__ import annotations

import argparse
import itertools
import json
from pathlib import Path
import sys

import numpy as np

import author_paw_seat as SEAT
import prove_tread_fit as FIT

W, SRC = SEAT.W, SEAT.SRC
GRID = {"work_y_u": (131, 160, 192, 256), "contact_z_u": (-300, -270), "paw_x_u": (176, 224),
        "lean_degrees": (0, 15, 30), "drop_u": (48, 96), "head_lift_degrees": (60,),
        "right_roll_degrees": (90,), "left_roll_degrees": (90,)}


def masks(src: dict) -> tuple:
    """Arm-only and leg vertices."""
    geometry = src["body"]["geometry"][0]
    weighted = geometry["weights"] > 0
    arm_bones = [13, 14, 15, 17, 18, 19]
    arm = ~np.any(~np.isin(geometry["ids"], arm_bones) & weighted, axis=1)
    dominant = geometry["ids"][np.arange(len(geometry["ids"])), np.argmax(geometry["weights"], axis=1)]
    leg = np.isin(dominant, [1, 2, 5, 6]) & ~np.any(np.isin(geometry["ids"], arm_bones) & weighted, axis=1)
    return arm, leg


def inside(points: np.ndarray, box: list) -> int:
    """Vertices strictly inside a box."""
    return int(np.sum(np.all((points > np.asarray(box[:3])) & (points < np.asarray(box[3:])), axis=1)))


def sample(src: dict, recipe: dict, arm: np.ndarray, leg: np.ndarray) -> dict:
    """Float measures over both programs."""
    where, fixture = FIT.site(recipe, SEAT.PLANE_U)
    programs = SEAT.author(src, {k: recipe[k] for k in SEAT.DOMAINS}, where)
    solids = fixture["solids_u"]
    gap, bearer, behind = np.inf, 0, 0
    for name in ("seat", "tap"):
        for case in programs[name][:2]:
            for frame in sorted(set(range(0, case["frames"], 3)) | {case["frames"] - 1}):
                p = SRC.I.points_at(case, src["body"], frame)
                a, b = p[arm], p[leg]
                gap = min(gap, min(float(np.sqrt(((a[i:i + 512, None] - b[None]) ** 2).sum(-1)).min())
                                   for i in range(0, len(a), 512)))
                bearer += inside(p, solids[fixture["workpiece_solid"]])
                behind += inside(p, solids[3])
    return {"arm_leg_gap_u": round(gap, 1), "vertices_in_bearer": bearer, "vertices_in_deck_behind": behind}


def main() -> int:
    """Run the grid and write every row."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "TREAD_FIT_PROBE_EXISTS")
    src = SEAT.corrected_source()
    arm, leg = masks(src)
    rows = []
    for values in itertools.product(*GRID.values()):
        recipe = dict(zip(GRID, values))
        try:
            row = {"recipe": recipe, "solvable": True, **sample(src, recipe, arm, leg)}
        except ValueError as refusal:
            row = {"recipe": recipe, "solvable": False, "refusal": str(refusal)}
        rows.append(row)
        print(json.dumps(row), file=sys.stderr, flush=True)
    ranked = sorted((r for r in rows if r["solvable"] and r["vertices_in_bearer"] == 0 and
                     r["vertices_in_deck_behind"] == 0), key=lambda r: (-r["arm_leg_gap_u"]))
    result = {"schema": 1, "decision": "1217", "grid": GRID, "candidates": len(rows),
              "solvable": sum(r["solvable"] for r in rows), "float_clear_ranked": ranked[:20], "rows": rows,
              "production_qualified": False}
    args.out.write_text(json.dumps(result, indent=1) + "\n")
    print(json.dumps({k: result[k] for k in ("candidates", "solvable")} | {"best": ranked[:5]}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
