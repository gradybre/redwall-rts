#!/usr/bin/env python3
"""Complete static source triangle separation and exact hand/wood witnesses; never native or runtime permission."""
from __future__ import annotations

import argparse
from fractions import Fraction as F
import hashlib
import json
from pathlib import Path

import numpy as np

import author_handling as A
import render_candidate as R

MAX_PAIRS = 100000
Q = A.P.SCALE


def hand_partition(body: dict, triangles: np.ndarray, rig: dict) -> tuple:
    """Whole distal-palm triangles may self-grip wood; mixed boundary triangles and all world geometry remain."""
    ids, weights = body["geometry"][0]["ids"], body["geometry"][0]["weights"]
    groups = []
    for hand in (15, 19):
        shares = np.sum(np.where(ids == hand, weights, 0), axis=1)
        bind = A.I.affine(np.asarray(rig["bones"][hand]["inverse_bind"]))
        local = body["geometry"][0]["points"].astype(np.float64) @ bind[:3, :3].T + bind[:3, 3]
        # This is the current accepted right-palm source boundary, applied
        # explicitly to both real palms. Imported mixed skin weights do not
        # turn distal fingers into wrists. No triangle crossing the anatomical
        # boundary is removed; every triangle remains in the full world hull.
        distal = (shares > 0) & (local[:, 1] > .025)
        groups.append(np.flatnonzero(np.all(distal[triangles], axis=1)))
    remaining = np.ones(len(triangles), dtype=bool)
    for rows in groups:
        remaining[rows] = False
    A.require(len(set(groups[0]) & set(groups[1])) == 0 and all(len(rows) for rows in groups),
              "HANDLING_HAND_PARTITION")
    return np.flatnonzero(remaining), groups


def exact_vertex(case: dict, part: dict, index: int, offset: int) -> tuple:
    surface = part["geometry"][0]
    point = [F(float(value)) for value in surface["points"][index]]
    result = [F(0), F(0), F(0)]
    influences = zip(surface["ids"][index], surface["weights"][index]) if part["binds"] else ((0, 1),)
    for bone, weight in influences:
        if weight == 0:
            continue
        matrix = [F(float(value)) for value in case["matrices"][0, offset + int(bone)]]
        for axis in range(3):
            result[axis] += F(float(weight)) * (matrix[9 + axis] + sum(matrix[column * 3 + axis] * point[column] for column in range(3)))
    result[1] += F(float(case["grounding"][0]))
    return tuple(value * 1024 for value in result)


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def edge_witness(first: list, second: list):
    """Exact rational segment/triangle intersection; an interval overlap alone never proves contact."""
    normal = cross(sub(second[1], second[0]), sub(second[2], second[0]))
    if not any(normal):
        return None
    for at in range(3):
        start, end = first[at], first[(at + 1) % 3]
        direction = sub(end, start)
        denominator = dot(normal, direction)
        if denominator == 0:
            continue
        share = dot(normal, sub(second[0], start)) / denominator
        if not 0 <= share <= 1:
            continue
        point = tuple(start[axis] + share * direction[axis] for axis in range(3))
        if all(dot(normal, cross(sub(second[(index + 1) % 3], second[index]), sub(point, second[index]))) >= 0
               for index in range(3)):
            return {"edge": [at, (at + 1) % 3], "share": [share.numerator, share.denominator],
                    "point_u": [[v.numerator, v.denominator] for v in point]}
    return None


def bounds(case: dict, body: dict, wood: dict) -> list:
    result = []
    for part, offset in ((body, 0), (wood, 24)):
        size = max(1, part["binds"])
        result.append(A.P._vertex_hulls(part, case["matrices"][:, offset:offset + size], case["grounding"])[0])
    return result


def solid_containment(case: dict, body: dict, wood: dict, solid: np.ndarray, body_tri: np.ndarray,
                      wood_tri: np.ndarray, a_bounds: tuple, b_bounds: tuple) -> list:
    """Surface separation alone cannot reject a triangle wholly inside a closed stock mesh."""
    al, ah = a_bounds
    bl, bh = b_bounds
    vertices = np.unique(body_tri[solid])
    possible = vertices[np.all(al[vertices] <= bh.max(axis=0), axis=1) &
                        np.all(ah[vertices] >= bl.min(axis=0), axis=1)]
    if not len(possible):
        return []
    points = [exact_vertex(case, wood, at, 24) for at in range(len(bl))]
    center = tuple(sum(point[axis] for point in points) / len(points) for axis in range(3))
    planes = []
    for tri in wood_tri:
        a, b, c = [points[int(at)] for at in tri]
        normal = cross(sub(b, a), sub(c, a))
        if dot(normal, sub(center, a)) > 0:
            normal = tuple(-value for value in normal)
        if any(normal):
            planes.append((a, normal))
    contained = []
    for vertex in possible:
        point = exact_vertex(case, body, int(vertex), 0)
        if all(dot(normal, sub(point, anchor)) <= 0 for anchor, normal in planes):
            contained.append(int(vertex))
    return contained


def floor_proof(case: dict, body: dict, wood: dict, body_tri: np.ndarray, raw: list) -> dict:
    """Every source triangle is above the floor; both anatomical soles and the full stock retain real floor contacts."""
    penetrations, contacts = [], []
    for part, offset, (low, _) in zip((body, wood), (0, 24), raw):
        for vertex in np.flatnonzero(low[:, 1] < 0):
            height = exact_vertex(case, part, int(vertex), offset)[1]
            if height < 0:
                penetrations.append({"part": "body" if offset == 0 else "wood", "vertex": int(vertex),
                                     "height_u": [height.numerator, height.denominator]})
    for name, rows, part, offset, low in (
            ("left_foot", np.unique(body_tri[A.RIG.M.anatomical_foot_triangles(body, body_tri, [3, 4])]), body, 0, raw[0][0]),
            ("right_foot", np.unique(body_tri[A.RIG.M.anatomical_foot_triangles(body, body_tri, [7, 8])]), body, 0, raw[0][0]),
            ("stock", np.arange(len(raw[1][0])), wood, 24, raw[1][0])):
        possible = rows[low[rows, 1] <= Q // 1024]
        exact = [(exact_vertex(case, part, int(at), offset)[1], int(at)) for at in possible]
        found = [row for row in exact if 0 <= row[0] <= 1]
        if found:
            height, vertex = min(found)
            contacts.append({"role": name, "vertex": vertex, "source_gap_u": [height.numerator, height.denominator]})
    return {"source_not_below_floor": not penetrations, "penetrations": penetrations,
            "contacts": contacts, "three_contacts_present": len(contacts) == 3,
            "scope": "Exact rational source at this pose, within the one-unit source contact cell; native residual remains separate."}


def prove(case: dict, body: dict, wood: dict, body_tri: np.ndarray, wood_tri: np.ndarray, rig: dict) -> dict:
    solid, hands = hand_partition(body, body_tri, rig)
    (al, ah), (bl, bh) = bounds(case, body, wood)
    amin, amax = al[body_tri].min(axis=1), ah[body_tri].max(axis=1)
    bmin, bmax = bl[wood_tri].min(axis=1), bh[wood_tri].max(axis=1)
    pairs, checks, unresolved, stopped = 0, [0], [], False
    for stock, tri in enumerate(wood_tri):
        possible = solid[np.all(amin[solid] <= bmax[stock], axis=1) & np.all(amax[solid] >= bmin[stock], axis=1)]
        for index in possible:
            pairs += 1
            A.require(pairs <= MAX_PAIRS, "HANDLING_STATIC_PAIR_CAPACITY")
            a, b = body_tri[index], tri
            if not A.I.SOURCE.separated(np.stack([al[a]] * 2), np.stack([ah[a]] * 2),
                                        np.stack([bl[b]] * 2), np.stack([bh[b]] * 2), checks):
                unresolved.append({"body_triangle": int(index), "wood_triangle": stock})
                if len(unresolved) == 64:
                    stopped = True
                    break
        if stopped:
            break
    witnesses = []
    for hand, rows in zip((15, 19), hands):
        witness = None
        for index in rows:
            possible = np.flatnonzero(np.all(bmin <= amax[index], axis=1) & np.all(bmax >= amin[index], axis=1))
            for stock in possible:
                a = [exact_vertex(case, body, int(v), 0) for v in body_tri[index]]
                b = [exact_vertex(case, wood, int(v), 24) for v in wood_tri[stock]]
                witness = edge_witness(a, b)
                if witness is not None:
                    witness.update({"hand": hand, "body_triangle": int(index), "wood_triangle": int(stock),
                                    "body_vertices": body_tri[index].tolist(), "wood_vertices": wood_tri[stock].tolist()})
                    break
            if witness is not None:
                break
        witnesses.append(witness)
    contained = solid_containment(case, body, wood, solid, body_tri, wood_tri, (al, ah), (bl, bh))
    floor = floor_proof(case, body, wood, body_tri, [(al, ah), (bl, bh)])
    return {"non_grip_separation": not unresolved and not stopped and not contained, "completed": not stopped,
            "unresolved": unresolved, "pairs": pairs, "checks": checks[0],
            "non_grip_vertices_inside_stock": contained, "floor": floor,
            "body_triangles": len(body_tri), "solid_triangles": len(solid), "hand_triangles": [len(rows) for rows in hands],
            "wood_triangles": len(wood_tri), "body_source_bounds_u": A.P.outward_units(al.min(axis=0), ah.max(axis=0)),
            "wood_source_bounds_u": A.P.outward_units(bl.min(axis=0), bh.max(axis=0)), "hand_contact_witnesses": witnesses,
            "self_grip_rule": "Each complete triangle has positive exact hand influence and hand-local Y > 0.025m at all three vertices; all mixed boundary triangles remain solid and all original triangles remain world geometry.",
            "partition_sha256": hashlib.sha256(np.concatenate([solid, hands[0], hands[1]]).astype("<i4").tobytes()).hexdigest(),
            "source_contact_exists": all(witness is not None for witness in witnesses)}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "candidate", "wood-topology", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    A.require(not args.out.exists(), "HANDLING_OUTPUT_EXISTS")
    _, body, wood, _, topology, _, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    source = np.load(args.candidate / "poses.npz", allow_pickle=False)
    case = {"frames": 1, "matrices": source["matrices"][1:2], "grounding": source["grounding"][1:2]}
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    wood_tri = R.wood_topology(args.wood_topology, wood)
    result = {"schema": 1, "production_qualified": False,
              "static_source": prove(case, body, wood, body_tri, wood_tri, topology["rig_binding"]),
              "scope": "Exact F32 input coefficients evaluated as source rational skin geometry; no native error or temporal qualification.",
              "source_sha256": {str(p.resolve().relative_to(A.I.ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in
                                (Path(__file__), Path(A.__file__), Path(A.I.__file__), Path(R.__file__),
                                 Path(A.I.SOURCE.__file__), Path(A.P.__file__), args.candidate / "poses.npz", args.wood_topology)},
              "pending": ["full supported foot contacts", "native error enclosure", "every transition/loop/reversal/join",
                          "runtime source/quantity/role admission"]}
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    proof = result["static_source"]
    print(json.dumps({"output": str(args.out), "non_grip_separation": proof["non_grip_separation"],
                      "contact_exists": proof["source_contact_exists"], "pairs": proof["pairs"], "unresolved": len(proof["unresolved"])}))


if __name__ == "__main__":
    main()
