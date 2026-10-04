#!/usr/bin/env python3
"""Bounded continuous source proof for the finite handling keys; no native/runtime qualification."""
from __future__ import annotations

import argparse
from fractions import Fraction as F
import hashlib
import json
from pathlib import Path

import numpy as np

import author_handling as A
import prove_static_contact as S
import render_candidate as R

MAX_FRAMES = 121
MAX_PAIRS = 100000
MAX_UNRESOLVED = 32


def polynomial_nonnegative(values: tuple) -> bool:
    """Exact minimum of c+b*t+a*t*t over the closed unit interval."""
    c, b, a = values
    if c < 0 or c + b + a < 0:
        return False
    if a > 0 and 0 < -b < 2 * a:
        return 4 * a * c - b * b >= 0
    return True


def linear_product(a: tuple, b: tuple) -> tuple:
    return a[0] * b[0], a[0] * b[1] + a[1] * b[0], a[1] * b[1]


def linear(values: tuple) -> tuple:
    return values[0], values[1] - values[0]


def interval_contact(first: list, last: list, stock_first: list, stock_last: list, edge: tuple) -> bool:
    """One fixed hand edge crosses one translating stock triangle at every common source time.

    Endpoint skin vertices are affine in time under the actual matrix interpolation.
    The stock triangle's orientation is constant. Signed plane distances are linear;
    each barycentric half-plane numerator is quadratic, with its exact interval minimum checked.
    """
    origin = (stock_first[0], stock_last[0])
    stock = [S.sub(point, origin[0]) for point in stock_first]
    if stock != [S.sub(point, origin[1]) for point in stock_last]:
        return False
    normal = S.cross(S.sub(stock[1], stock[0]), S.sub(stock[2], stock[0]))
    if not any(normal):
        return False
    rows = [[S.sub(points[at], anchor) for at in edge] for points, anchor in zip((first, last), origin)]
    distances = [[S.dot(normal, point) for point in row] for row in rows]
    if all(row[0] <= 0 <= row[1] for row in distances):
        rows = [row[::-1] for row in rows]
        distances = [row[::-1] for row in distances]
    if not all(row[0] >= 0 >= row[1] and row[0] > row[1] for row in distances):
        return False
    d0 = linear((distances[0][0], distances[1][0]))
    d1 = linear((distances[0][1], distances[1][1]))
    for at in range(3):
        start, end = stock[at], stock[(at + 1) % 3]
        side = S.sub(end, start)
        value = [[S.dot(normal, S.cross(side, S.sub(point, start))) for point in row] for row in rows]
        first_side = linear((value[0][0], value[1][0]))
        last_side = linear((value[0][1], value[1][1]))
        positive, negative = linear_product(d0, last_side), linear_product(d1, first_side)
        if not polynomial_nonnegative(tuple(a - b for a, b in zip(positive, negative))):
            return False
    return True


def load_case(path: Path) -> dict:
    A.require(path.is_file() and path.stat().st_size <= 4 * MAX_FRAMES * 301 + 4096,
              "HANDLING_PROGRAM_IMAGE_CAPACITY")
    with np.load(path, allow_pickle=False) as image:
        A.require(set(image.files) == {"matrices", "grounding"}, "HANDLING_PROGRAM_IMAGE_SHAPE")
        matrices, grounding = image["matrices"], image["grounding"]
    A.require(matrices.dtype == np.float32 and matrices.ndim == 3 and matrices.shape[1:] == (25, 12) and
              2 <= len(matrices) <= MAX_FRAMES and grounding.dtype == np.float32 and
              grounding.shape == (len(matrices),) and np.all(np.isfinite(matrices)) and
              np.all(np.isfinite(grounding)), "HANDLING_PROGRAM_KEYS")
    A.require(np.array_equal(matrices[:, 24, :9], np.broadcast_to(matrices[0, 24, :9], (len(matrices), 9))),
              "HANDLING_PROGRAM_STOCK_ROTATION")
    return {"frames": len(matrices), "matrices": matrices, "grounding": grounding,
            "source_loop_mode": 0, "source_duration_s": F(len(matrices) - 1, 30)}


def at_frame(case: dict, frame: int) -> dict:
    return {**case, "frames": 1, "matrices": case["matrices"][frame:frame + 1],
            "grounding": case["grounding"][frame:frame + 1]}


def contact_proof(case: dict, body: dict, wood: dict, body_tri: np.ndarray, wood_tri: np.ndarray,
                  pair: dict, frame: int) -> bool:
    body_vertices, stock_vertices = body_tri[pair["body_triangle"]], wood_tri[pair["wood_triangle"]]
    cases = [at_frame(case, at) for at in (frame, frame + 1)]
    first, last = [[S.exact_vertex(current, body, int(at), 0) for at in body_vertices] for current in cases]
    stock_first, stock_last = [[S.exact_vertex(current, wood, int(at), 24) for at in stock_vertices] for current in cases]
    return interval_contact(first, last, stock_first, stock_last, tuple(pair["edge"]))


def endpoint_floor(case: dict, frame: int, raw: list, body: dict, wood: dict, feet: list) -> dict:
    current = at_frame(case, frame)
    bad = []
    for part, offset, (low, _) in zip((body, wood), (0, 24), raw):
        for vertex in np.flatnonzero(low[:, 1] < 0):
            value = S.exact_vertex(current, part, int(vertex), offset)[1]
            if value < 0:
                bad.append({"part": offset, "vertex": int(vertex), "height_u": [value.numerator, value.denominator]})
    contacts = []
    for rows in feet:
        near = rows[raw[0][0][rows, 1] <= A.P.SCALE // 1024]
        contacts.append({int(at): S.exact_vertex(current, body, int(at), 0)[1] for at in near})
    return {"bad": bad, "contacts": contacts}


def prove(case: dict, body: dict, wood: dict, body_tri: np.ndarray, wood_tri: np.ndarray, rig: dict,
          contact_pairs: list, require_grip: bool) -> dict:
    solid, hands = S.hand_partition(body, body_tri, rig)
    feet = [np.unique(body_tri[A.RIG.M.anatomical_foot_triangles(body, body_tri, bones)])
            for bones in ([3, 4], [7, 8])]
    endpoints = [[A.P._vertex_hulls(part, case["matrices"][frame:frame + 1, offset:offset + max(1, part["binds"])],
                                  case["grounding"][frame:frame + 1])[0] for frame in range(case["frames"])]
                 for part, offset in ((body, 0), (wood, 24))]
    floors = [endpoint_floor(case, at, [endpoints[0][at], endpoints[1][at]], body, wood, feet)
              for at in range(case["frames"])]
    first_raw = [endpoints[0][0], endpoints[1][0]]
    contained = S.solid_containment(at_frame(case, 0), body, wood, solid, body_tri, wood_tri, *first_raw)
    unresolved, support_failures, grip_failures, interval_rows = [], [], [], []
    checks, pairs = [0], 0
    for frame in range(case["frames"] - 1):
        al, ah = [np.stack([endpoints[0][at][side] for at in (frame, frame + 1)]) for side in (0, 1)]
        bl, bh = [np.stack([endpoints[1][at][side] for at in (frame, frame + 1)]) for side in (0, 1)]
        amin, amax = al[:, body_tri].min(axis=(0, 2)), ah[:, body_tri].max(axis=(0, 2))
        bmin, bmax = bl[:, wood_tri].min(axis=(0, 2)), bh[:, wood_tri].max(axis=(0, 2))
        pair_start, check_start = pairs, checks[0]
        for stock, tri in enumerate(wood_tri):
            possible = solid[np.all(amin[solid] <= bmax[stock], axis=1) & np.all(amax[solid] >= bmin[stock], axis=1)]
            for index in possible:
                pairs += 1
                A.require(pairs <= MAX_PAIRS, "HANDLING_PROGRAM_PAIR_CAPACITY")
                if not A.I.SOURCE.separated(al[:, body_tri[index]], ah[:, body_tri[index]], bl[:, tri], bh[:, tri], checks):
                    unresolved.append({"interval": frame, "body_triangle": int(index), "wood_triangle": stock})
                    if len(unresolved) >= MAX_UNRESOLVED:
                        break
            if len(unresolved) >= MAX_UNRESOLVED:
                break
        witnesses = []
        for side in (0, 1):
            first, last = floors[frame]["contacts"][side], floors[frame + 1]["contacts"][side]
            shared = [at for at in first.keys() & last.keys() if 0 <= first[at] <= 1 and 0 <= last[at] <= 1]
            if not shared:
                support_failures.append({"interval": frame, "foot": side})
            witnesses.append(min(shared) if shared else None)
        if require_grip:
            for hand, pair in enumerate(contact_pairs):
                if not contact_proof(case, body, wood, body_tri, wood_tri, pair, frame):
                    grip_failures.append({"interval": frame, "hand": hand})
        interval_rows.append({"interval": [frame, frame + 1], "pairs": pairs - pair_start,
                              "checks": checks[0] - check_start, "foot_contact_vertices": witnesses})
        if len(unresolved) >= MAX_UNRESOLVED:
            break
    floor_bad = [{"frame": at, "vertices": result["bad"]} for at, result in enumerate(floors) if result["bad"]]
    complete = len(interval_rows) == case["frames"] - 1 and len(unresolved) < MAX_UNRESOLVED
    return {"all_intervals_complete": complete,
            "non_grip_separation": not unresolved and not contained, "unresolved": unresolved,
            "initial_contained_vertices": contained, "pairs": pairs, "checks": checks[0],
            "floor_penetrations": floor_bad, "supported_feet": complete and not support_failures, "support_failures": support_failures,
            "continuous_two_hand_contact": complete and require_grip and not grip_failures, "grip_failures": grip_failures,
            "foot_union_u": [A.P.outward_units(np.stack([raw[0][rows] for raw in endpoints[0]]).min(axis=(0, 1)),
                                               np.stack([raw[1][rows] for raw in endpoints[0]]).max(axis=(0, 1))) for rows in feet],
            "body_union_u": A.P.outward_units(np.stack([row[0] for row in endpoints[0]]).min(axis=(0, 1)),
                                              np.stack([row[1] for row in endpoints[0]]).max(axis=(0, 1))),
            "stock_union_u": A.P.outward_units(np.stack([row[0] for row in endpoints[1]]).min(axis=(0, 1)),
                                               np.stack([row[1] for row in endpoints[1]]).max(axis=(0, 1))),
            "body_triangles": len(body_tri), "non_grip_triangles": len(solid),
            "intentional_grip_triangles": [len(row) for row in hands], "stock_triangles": len(wood_tri),
            "intervals": interval_rows}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "candidate", "wood-topology", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--clip", choices=("approach", "lift", "place", "recovery"), default="lift")
    args = parser.parse_args()
    A.require(not args.out.exists(), "HANDLING_OUTPUT_EXISTS")
    _, body, wood, _, topology, _, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    case = load_case(args.candidate / (args.clip + ".npz"))
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    wood_tri = R.wood_topology(args.wood_topology, wood)
    accepted = A.I.HERE / "evidence/static-contact-review-v1/static-contact.json"
    pairs = json.loads(accepted.read_text())["static_source"]["hand_contact_witnesses"]
    result = prove(case, body, wood, body_tri, wood_tri, topology["rig_binding"], pairs, args.clip in ("lift", "place"))
    paths = (Path(__file__), Path(S.__file__), Path(A.__file__), Path(A.I.SOURCE.__file__), Path(A.P.__file__),
             args.candidate / (args.clip + ".npz"), accepted, args.wood_topology)
    report = {"schema": 1, "production_qualified": False, "clip": args.clip, "source_proof": result,
              "scope": "All affine source interpolation intervals, full current triangles. No native error allowance, timing adoption or runtime permission.",
              "contact_scope": "Exact translating stock plus quadratic rational hand-edge/triangle certificates; no planar runtime CONTACT_PATCH assertion.",
              "containment_scope": "Initial non-grip vertices outside the closed convex stock plus continuous surface separation; no non-grip vertex may enter without a refused crossing.",
              "source_sha256": {str(path.resolve().relative_to(A.I.ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}}
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"clip": args.clip, "complete": result["all_intervals_complete"],
                      "non_grip_separation": result["non_grip_separation"], "pairs": result["pairs"],
                      "unresolved": len(result["unresolved"]), "grip_failures": len(result["grip_failures"]),
                      "floor_bad": len(result["floor_penetrations"]), "support_failures": len(result["support_failures"])}))


if __name__ == "__main__":
    main()
