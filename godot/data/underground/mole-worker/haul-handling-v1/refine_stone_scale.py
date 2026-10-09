#!/usr/bin/env python3
"""Refine ADR 1206's carried-lump scale to 1 mm/unit: the largest squashed lump clear of the reviewed body.

Same placement, lump and solid-body test as derive_stone_scale.py. The sweep walks up in 0.001 m/unit steps
from 0.140 and stops at the first scale with any solid body vertex inside. The adopted constant is the last
clear step. This is the size rule Brendan chose ("smaller lump, new grip"); the new grip proves its own pose.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

import derive_stone_scale as D

A, PS = D.A, D.PS
START_MM, STOP_MM = 140, 180


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    A.require(not args.out.exists(), "STONE_OUTPUT_EXISTS")
    stone = json.loads(D.STONE.read_text())
    unit = np.asarray(stone["points"], dtype=np.float64)
    tri = np.asarray(stone["indices"], dtype=np.int32).reshape(-1, 3)
    grip = json.loads(D.ROWS.read_text())["station"]["grip_contacts"]
    contacts = np.array([[float(n) / float(d) for n, d in row["C_minus_R_u"]] for row in grip]) + [0, 0, 576] + D.S_U
    _, body, _, _, topology, _, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    source = np.load(D.POSE, allow_pickle=False)
    case = {"frames": 1, "matrices": source["matrices"][1:2], "grounding": source["grounding"][1:2]}
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    solid_tri, _ = PS.hand_partition(body, body_tri, topology["rig_binding"])
    solid = A.I.points_at(case, body, 0)[np.unique(body_tri[solid_tri])]
    rows, adopted = [], None
    for mm in range(START_MM, STOP_MM + 1):
        s = mm / 1000
        row = D.assess((s, s * D.SQUASH, s), unit, tri, contacts, solid)
        rows.append(row)
        if row["solid_vertices_inside"]:
            break
        adopted = row
    A.require(adopted is not None and rows[-1]["solid_vertices_inside"] > 0, "STONE_SCALE_BRACKET")
    report = {"schema": 1, "adr": "1206", "production_qualified": False,
              "rule": "largest uniform scale (0.001 m/unit grid) with squash 0.8, no rotation, no solid vertex of the "
                      "reviewed static pose inside the lump at S",
              "adopted_scale_m": adopted["scale_m"], "adopted": adopted, "first_refused": rows[-1], "sweep": rows,
              "inputs_sha256": {str(p.relative_to(A.I.ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in (Path(__file__), Path(D.__file__), D.STONE, D.ROWS, D.POSE)}}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"adopted": adopted, "first_refused": rows[-1]}))


if __name__ == "__main__":
    main()
