#!/usr/bin/env python3
"""Float clearance aids for the human stone-motion review (ADR 1206); the exact proofs are separate.

For every key of every stone clip it reports the smallest radial gap between any solid (non-grip) body vertex
and the lump, the dominant bone of that vertex, and the stone's height range, so the reviewer can see where
the motion runs closest (e.g. the snout during lift).
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

CLIPS = {"approach": "stone-program-v1", "lift": "stone-program-v1", "place": "stone-program-v1",
         "recovery": "stone-program-v1", "hold": "stone-gait-v1", "enter": "stone-gait-v1", "carry": "stone-gait-v1",
         "exit": "stone-gait-v1", "enter_haul_stone": "stone-joins-v1", "leave_haul_stone": "stone-joins-v1"}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    A.require(not args.out.exists(), "STONE_OUTPUT_EXISTS")
    _, body, _, _, topology, _, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    stone, tri = G.stone_part()
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    solid, hands = PS.hand_partition(body, body_tri, topology["rig_binding"])
    vertices = np.setdiff1d(np.unique(body_tri[solid]), np.unique(body_tri[np.concatenate(hands)]))
    geometry = body["geometry"][0]
    dominant = np.take_along_axis(geometry["ids"], geometry["weights"].argmax(axis=1)[:, None], axis=1)[:, 0]
    names = [row.get("name") for row in topology["rig_binding"]["bones"]]
    report, inputs = {}, {}
    for clip, folder in CLIPS.items():
        path = A.I.HERE / "evidence" / folder / (clip + ".npz")
        inputs[str(path.relative_to(A.I.ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
        with np.load(path, allow_pickle=False) as image:
            matrices, grounding = image["matrices"], image["grounding"]
        closest = None
        for frame in range(len(matrices)):
            case = {"frames": 1, "matrices": matrices[frame:frame + 1], "grounding": grounding[frame:frame + 1]}
            points = A.I.points_at(case, body, 0)[vertices]
            lump = A.I.points_at(case, stone, 0, 24)
            origin = np.array([matrices[frame, 24, 9], matrices[frame, 24, 10] + grounding[frame],
                               matrices[frame, 24, 11]], dtype=np.float64) * 1024
            radius, distance = D.ray_radius(lump, tri, origin, points)
            gap = distance - radius
            at = int(np.argmin(gap))
            if closest is None or gap[at] < closest["min_gap_u"]:
                closest = {"min_gap_u": round(float(gap[at]), 2), "key": frame,
                           "bone": names[int(dominant[vertices[at]])], "point_u": points[at].round(1).tolist()}
        report[clip] = {"keys": len(matrices), "closest": closest}
    result = {"schema": 1, "adr": "1206", "production_qualified": False, "clips": report, "inputs_sha256": inputs,
              "scope": "Float radial diagnostics at keys only; continuous exact proofs are in each clip's *-proof.json."}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({clip: row["closest"] for clip, row in report.items()}, indent=1))


if __name__ == "__main__":
    main()
