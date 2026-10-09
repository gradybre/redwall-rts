#!/usr/bin/env python3
"""Float diagnostics for the options after the side-on refusal (ADR 1217 step 2c). A decision aid, not a proof.

Both use the approved paw recipe family (`author_paw_seat`, head lift 60, palms rolled 90) and the accepted
fixed-length arm solve; a recipe "reaches" when every arm solves with unchanged links.

1. **Paws closer together** (side-on with the paws re-placed on the 128 u bearer top): the approved recipe with the
   contacts at (+-c, 128, -448); the smallest vertex gap between the two arms at the seat key, and each paw's x
   extent.
2. **Reach at the stance level** (seating T_k from two treads up, where the bearer's top is level with the stance
   and its near face 553 u ahead): the largest forward reach at plane 0 and plane 128 over a lean x drop grid.

    $PY .../probe_tread_side_options.py <out.json>
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
APPROVED = {"lean_degrees": 40, "drop_u": 64, "head_lift_degrees": 60, "right_roll_degrees": 90,
            "left_roll_degrees": 90}
SPREADS = (16, 32, 48, 64, 96, 128)
AHEAD = range(448, 640, 16)
LEANS, DROPS = (40, 50, 60, 70, 80, 90), (0, 64, 128, 176)


def site(plane: int, ahead: int, spread: int) -> dict:
    """Contacts at (+-spread, plane, -ahead) over a 512 x 128 bearer section centred on them."""
    section = np.array([-256., plane - 128, -ahead - 64, 256., plane, -ahead + 64])
    return {"name": "probe", "plane": plane, "section": section,
            "contact": {"right": np.array([spread, float(plane), -ahead]),
                        "left": np.array([-spread, float(plane), -ahead])}}


def arm_masks(src: dict) -> tuple:
    """Vertices weighted to each arm, and the paw vertices."""
    geometry = src["body"]["geometry"][0]
    weighted = lambda bones: np.any(np.isin(geometry["ids"], bones) & (geometry["weights"] > 0), axis=1)
    return weighted((17, 18, 19)), weighted((13, 14, 15)), weighted((15, 19))


def spreads(src: dict) -> list:
    """Arm-to-arm gap and paw extents with the paws brought together."""
    right, left, paw = arm_masks(src)
    rows = []
    for spread in SPREADS:
        palettes, _ = SEAT.program_keys(src, APPROVED, [float(SEAT.PLANE_U)], site(SEAT.PLANE_U, 448, spread))
        points = SRC.I.points_at(W.case_of(palettes * 2, src["grounding"], "probe"), src["body"], 0)
        a, b = points[right & ~left], points[left & ~right]
        gap = min(float(np.sqrt(((a[i:i + 512, None] - b[None]) ** 2).sum(-1)).min()) for i in range(0, len(a), 512))
        rows.append({"contact_x_u": spread, "arm_gap_u": round(gap, 1),
                     "right_paw_x_u": np.round([points[paw & right, 0].min(), points[paw & right, 0].max()], 1).tolist(),
                     "left_paw_x_u": np.round([points[paw & left, 0].min(), points[paw & left, 0].max()], 1).tolist()})
    return rows


def reach(src: dict) -> dict:
    """Recipes whose arms solve at each forward reach, per plane."""
    result = {}
    for plane in (0, SEAT.PLANE_U):
        rows = []
        for ahead in AHEAD:
            ok = []
            for lean, drop in itertools.product(LEANS, DROPS):
                recipe = dict(APPROVED, lean_degrees=lean, drop_u=drop)
                try:
                    SEAT.program_keys(src, recipe, [float(plane)], site(plane, ahead, 128))
                    ok.append([lean, drop])
                except ValueError:
                    pass
            rows.append({"ahead_u": ahead, "solving_lean_drop": ok})
        result[str(plane)] = {"rows": rows, "largest_reach_u": max((r["ahead_u"] for r in rows if r["solving_lean_drop"]),
                                                                   default=None)}
    return result


def main() -> int:
    """Run both diagnostics and write them."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "TREAD_SIDE_PROBE_EXISTS")
    src = SEAT.corrected_source()
    result = {"schema": 1, "decision": "1217", "approved_recipe": APPROVED, "paws_together": spreads(src),
              "reach_by_plane": reach(src), "production_qualified": False,
              "producer_sources": {str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p)
                                   for p in (Path(__file__), Path(SEAT.__file__))}}
    args.out.write_text(json.dumps(result, indent=1) + "\n")
    print(json.dumps({"paws_together": result["paws_together"],
                      "largest_reach_u": {k: v["largest_reach_u"] for k, v in result["reach_by_plane"].items()}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
