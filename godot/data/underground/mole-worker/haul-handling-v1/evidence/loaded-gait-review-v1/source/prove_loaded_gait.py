#!/usr/bin/env python3
"""Complete source triangles, alternating foot support and curved grips for the loaded gait candidate."""
from __future__ import annotations

import argparse
from fractions import Fraction as F
import hashlib
import json
from pathlib import Path

import numpy as np

import author_handling as A
import prove_carried_grip as GRIP
import prove_program as P
import prove_static_contact as S
import render_candidate as R

MAX_KEYS = 256
MAX_PAIRS = 100000
MAX_UNRESOLVED = 32


def load_case(path: Path, loop: int) -> dict:
    A.require(path.is_file() and path.stat().st_size <= 4 * MAX_KEYS * 301 + 4096, "HAUL_GAIT_IMAGE_CAPACITY")
    with np.load(path, allow_pickle=False) as image:
        A.require(set(image.files) == {"matrices", "grounding"}, "HAUL_GAIT_IMAGE_SHAPE")
        matrices, grounding = image["matrices"], image["grounding"]
    A.require(matrices.dtype == np.float32 and matrices.ndim == 3 and matrices.shape[1:] == (25, 12) and
              2 <= len(matrices) <= MAX_KEYS and grounding.dtype == np.float32 and
              grounding.shape == (len(matrices),) and np.all(np.isfinite(matrices)) and
              np.all(np.isfinite(grounding)) and loop in (0, 1), "HAUL_GAIT_KEYS")
    return {"frames": len(matrices), "matrices": matrices, "grounding": grounding,
            "source_loop_mode": loop, "source_duration_s": F(len(matrices) - 1, 30)}


def prove(case: dict, body: dict, wood: dict, body_tri: np.ndarray, wood_tri: np.ndarray, rig: dict,
          contact_pairs: list) -> dict:
    solid, hands = S.hand_partition(body, body_tri, rig)
    feet = [np.unique(body_tri[A.RIG.M.anatomical_foot_triangles(body, body_tri, bones)])
            for bones in ([3, 4], [7, 8])]
    endpoints = [[A.P._vertex_hulls(part, case["matrices"][frame:frame + 1, offset:offset + max(1, part["binds"])],
                                  case["grounding"][frame:frame + 1])[0] for frame in range(case["frames"])]
                 for part, offset in ((body, 0), (wood, 24))]
    floors = [P.endpoint_floor(case, at, [endpoints[0][at], endpoints[1][at]], body, wood, feet)
              for at in range(case["frames"])]
    contained = S.solid_containment(P.at_frame(case, 0), body, wood, solid, body_tri, wood_tri,
                                    endpoints[0][0], endpoints[1][0])
    unresolved, support_failures, grip_failures, interval_rows = [], [], [], []
    checks, pairs = [0], 0
    intervals = A.P.rendered_intervals(case)
    for first, last in intervals:
        al, ah = [np.stack([endpoints[0][at][side] for at in (first, last)]) for side in (0, 1)]
        bl, bh = [np.stack([endpoints[1][at][side] for at in (first, last)]) for side in (0, 1)]
        amin, amax = al[:, body_tri].min(axis=(0, 2)), ah[:, body_tri].max(axis=(0, 2))
        bmin, bmax = bl[:, wood_tri].min(axis=(0, 2)), bh[:, wood_tri].max(axis=(0, 2))
        pair_start, check_start = pairs, checks[0]
        for stock, tri in enumerate(wood_tri):
            possible = solid[np.all(amin[solid] <= bmax[stock], axis=1) & np.all(amax[solid] >= bmin[stock], axis=1)]
            for index in possible:
                pairs += 1
                A.require(pairs <= MAX_PAIRS, "HAUL_GAIT_PAIR_CAPACITY")
                if not A.I.SOURCE.separated(al[:, body_tri[index]], ah[:, body_tri[index]], bl[:, tri], bh[:, tri], checks):
                    unresolved.append({"interval": [first, last], "body_triangle": int(index), "wood_triangle": stock})
                    if len(unresolved) >= MAX_UNRESOLVED:
                        break
            if len(unresolved) >= MAX_UNRESOLVED:
                break
        witnesses = []
        for side in (0, 1):
            a, b = floors[first]["contacts"][side], floors[last]["contacts"][side]
            shared = [at for at in a.keys() & b.keys() if 0 <= a[at] <= 1 and 0 <= b[at] <= 1]
            witnesses.append(min(shared) if shared else None)
        if all(at is None for at in witnesses):
            support_failures.append({"interval": [first, last]})
        contact_results = [GRIP.actual_contact(case, body, wood, body_tri, wood_tri, pair, first, last) for pair in contact_pairs]
        for hand, result in enumerate(contact_results):
            if not result["contact"]:
                grip_failures.append({"interval": [first, last], "hand": hand, "result": result})
        interval_rows.append({"interval": [first, last], "pairs": pairs - pair_start, "checks": checks[0] - check_start,
                              "foot_contact_vertices": witnesses, "grips": contact_results})
        if len(unresolved) >= MAX_UNRESOLVED:
            break
    complete = len(interval_rows) == len(intervals) and len(unresolved) < MAX_UNRESOLVED
    floor_bad = [{"frame": at, "vertices": result["bad"]} for at, result in enumerate(floors) if result["bad"]]
    return {"all_intervals_complete": complete, "non_grip_separation": complete and not unresolved and not contained,
            "unresolved": unresolved, "initial_contained_vertices": contained, "pairs": pairs, "checks": checks[0],
            "floor_penetrations": floor_bad, "supported_feet": complete and not support_failures,
            "support_failures": support_failures, "continuous_two_hand_contact": complete and not grip_failures,
            "grip_failures": grip_failures, "body_triangles": len(body_tri), "non_grip_triangles": len(solid),
            "intentional_grip_triangles": [len(row) for row in hands], "stock_triangles": len(wood_tri),
            "body_union_u": A.P.outward_units(np.stack([row[0] for row in endpoints[0]]).min(axis=(0, 1)),
                                              np.stack([row[1] for row in endpoints[0]]).max(axis=(0, 1))),
            "stock_union_u": A.P.outward_units(np.stack([row[0] for row in endpoints[1]]).min(axis=(0, 1)),
                                               np.stack([row[1] for row in endpoints[1]]).max(axis=(0, 1))),
            "foot_union_u": [A.P.outward_units(np.stack([raw[0][rows] for raw in endpoints[0]]).min(axis=(0, 1)),
                                               np.stack([raw[1][rows] for raw in endpoints[0]]).max(axis=(0, 1))) for rows in feet],
            "rendered_timing": A.P.rendered_timing(case), "intervals": interval_rows}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "candidate", "wood-topology", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--clip", choices=("hold", "enter", "carry", "exit"), default="carry")
    args = parser.parse_args()
    A.require(not args.out.exists(), "HANDLING_OUTPUT_EXISTS")
    _, body, wood, _, topology, _, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    case = load_case(args.candidate / (args.clip + ".npz"), 1 if args.clip == "carry" else 0)
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    wood_tri = R.wood_topology(args.wood_topology, wood)
    accepted = A.I.HERE / "evidence/static-contact-review-v1/static-contact.json"
    pairs = json.loads(accepted.read_text())["static_source"]["hand_contact_witnesses"]
    result = prove(case, body, wood, body_tri, wood_tri, topology["rig_binding"], pairs)
    paths = (Path(__file__), Path(GRIP.__file__), Path(P.__file__), Path(S.__file__), Path(A.__file__),
             Path(A.I.SOURCE.__file__), Path(A.P.__file__), args.candidate / (args.clip + ".npz"), accepted, args.wood_topology)
    report = {"schema": 1, "production_qualified": False, "clip": args.clip, "source_proof": result,
              "scope": "Exact rendered affine source edges, including penultimate-to-first loop wrap; no native error, adopted rate, root advance or runtime permission.",
              "source_sha256": {str(path.resolve().relative_to(A.I.ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}}
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"clip": args.clip, "complete": result["all_intervals_complete"], "non_grip_separation": result["non_grip_separation"],
                      "pairs": result["pairs"], "unresolved": len(result["unresolved"]), "grip_failures": len(result["grip_failures"]),
                      "floor_bad": len(result["floor_penetrations"]), "support_failures": len(result["support_failures"])}))


if __name__ == "__main__":
    main()
