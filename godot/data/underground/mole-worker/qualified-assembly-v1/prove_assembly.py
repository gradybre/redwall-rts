#!/usr/bin/env python3
"""Complete continuous body/pick/wood/support proof for a finite assembly candidate."""
from __future__ import annotations

import argparse
from fractions import Fraction as F
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

import author_assembly as A

I, P, N = A.I, A.P, A.I.A.N
T = I.module("assembly_complete_terrain", I.A.CONTACT / "prove_stair_terrain.py")
# Use the accepted bounded ZIP/NPY loader. Both member headers close before any
# NumPy materialization; this module never calls np.load on caller data.
_old_path = list(sys.path)
try:
    sys.path.insert(0, str(I.HERE.parent / "haul-handling-v1"))
    L = I.module("assembly_bounded_source_images", I.HERE.parent / "haul-handling-v1/prove_loaded_gait.py")
finally:
    sys.path[:] = _old_path

MAX_BYTES = 2 * 1024 * 1024
MAX_FAILURES = 32
MAX_EXACT = 65536
UNIT = P.SCALE // 1024


def fraction_record(value):
    return [value.numerator, value.denominator]


def exact_vertex(case, part, frame, vertex, offset):
    surface = part["geometry"][0]
    point = [F(float(x)) for x in surface["points"][vertex]]
    influences = zip(surface["ids"][vertex], surface["weights"][vertex]) if part["binds"] else ((0, 1),)
    out = [F(0), F(0), F(0)]
    for bone, weight in influences:
        if weight == 0:
            continue
        row = [F(float(x)) for x in case["matrices"][frame, offset + int(bone)]]
        for axis in range(3):
            out[axis] += F(float(weight)) * (row[9+axis] + sum(row[axis+3*a]*point[a] for a in range(3)))
    out[1] += F(float(case["grounding"][frame]))
    return tuple(x * 1024 for x in out)


def sources(candidate):
    path = candidate / "report.json"
    P.require(path.is_file() and not path.is_symlink() and path.stat().st_size <= MAX_BYTES,
              "ASSEMBLY_CANDIDATE_CAPACITY")
    report = json.loads(path.read_text())
    rows = report.get("clips")
    P.require(type(rows) is list and len(rows) == 3 and [row.get("clip") for row in rows] ==
              ["entry", "seat", "recovery"], "ASSEMBLY_CLIP_ORDER")
    clips = []
    for row in rows:
        path = candidate / (row["clip"] + ".npz")
        P.require(path.is_file() and not path.is_symlink() and path.stat().st_size <= L.MAX_IMAGE_BYTES and
                  hashlib.sha256(path.read_bytes()).hexdigest() ==
                  row["sha256"], "ASSEMBLY_IMAGE_HASH")
        case = L.load_case(path, 0)
        shifts = row.get("beam_offset_z_u")
        P.require(type(shifts) is list and len(shifts) == case["frames"] and
                  all(type(v) is int and v == 0 for v in shifts), "ASSEMBLY_BEAM_TRACK")
        clips.append(case)
    P.require(all(row["beam_offset_z_u"] == [0] * clip["frames"] for row, clip in zip(rows, clips)),
              "ASSEMBLY_COMPLETE_TRACK")
    P.require([clip["frames"] for clip in clips] == [55, 2, 55], "ASSEMBLY_FRAME_CENSUS")
    P.require(np.array_equal(clips[1]["matrices"][0], clips[1]["matrices"][1]) and
              clips[1]["grounding"][0] == clips[1]["grounding"][1], "ASSEMBLY_STATIONARY_CONTACT")
    return report, clips


def candidate_pins(candidate):
    """Fixed four-file input identity; the exact NPZ payloads are independently bounded by sources()."""
    names = ("report.json", "entry.npz", "seat.npz", "recovery.npz")
    return {name: I.A.digest(candidate / name) for name in names}


def prove_clip(name, case, shifts, parts, topology, rig, roots, basis, contact_vertex):
    cache = N.endpoint_cache(case, parts, roots, basis)
    feet = T.foot_membership(parts[0], topology[0][0])
    foot_vertices = [np.unique(topology[0][0][rows]) for rows in feet]
    palms = A.palm_rows(parts[0], topology[0][0], rig)
    bounds = [[-192, 0, -512, 1856, 128, -384], [-256, 0, -512, 256, 128, -384]]
    checks, failures, supports, contacts = [0], [], [], []
    solid_pairs, numerical_contacts, floor_pairs = 0, 0, 0
    exact_cache = {}

    def exact(part, frame, vertex):
        key = part, frame, vertex
        if key not in exact_cache:
            P.require(len(exact_cache) < MAX_EXACT, "ASSEMBLY_EXACT_CAPACITY")
            exact_cache[key] = exact_vertex(case, parts[part], frame, vertex, 0 if part == 0 else 24)
        return exact_cache[key]

    # All lower body coefficients are closed separately against exact ready;
    # nevertheless rederive full anatomical feet and source contact here.
    for frame in range(case["frames"] - 1):
        pair = [frame, frame+1]
        required_mask = 1 if (name == "entry" and frame < 8 or name == "recovery" and frame >= 46) else 3
        for side, vertices in enumerate(foot_vertices):
            low, high = cache[0]["low"][pair][:, vertices], cache[0]["high"][pair][:, vertices]
            near = vertices[np.argsort(cache[0]["low"][frame, vertices, 1])[:8]]
            witness = next((int(v) for v in near if all(0 <= exact(0, at, int(v))[1] < 1 for at in pair)), -1)
            source_ok = all(exact(0, at, int(v))[1] >= 0 for at in pair for v in
                            vertices[(cache[0]["low"][at, vertices, 1] - cache[0]["padding"][1]) < 0])
            supports.append({"interval": frame, "foot": side, "source_vertex": witness,
                             "bounds_u": P.outward_units(low.min(axis=(0, 1)), high.max(axis=(0, 1))),
                             "source_above": source_ok, "required": bool(required_mask & (1 << side))})
            if not source_ok or required_mask & (1 << side) and witness < 0:
                failures.append({"kind": "FOOT", "interval": frame, "foot": side})

        if name == "seat":
            for assembly, box in enumerate(bounds):
                positions = [exact(0, at, contact_vertex) for at in pair]
                okay = all(box[0] <= p[0] <= box[3] and 0 <= p[1]-128 < 1 and
                           box[2]+shifts[at] <= p[2] <= box[5]+shifts[at]
                           for at, p in zip(pair, positions))
                contacts.append({"interval": frame, "assembly": assembly, "vertex": contact_vertex,
                                 "source_gap_u": [fraction_record(p[1]-128) for p in positions], "valid": okay})
                if not okay:
                    failures.append({"kind": "CONTACT", "interval": frame, "assembly": assembly})

    for part, (row, triangles) in enumerate(zip(cache, topology)):
        indices = triangles[0]
        padding = row["padding"]
        for frame in range(case["frames"] - 1):
            pair = [frame, frame+1]
            low, high = row["low"][pair], row["high"][pair]
            raw_low, raw_high = low + padding, high - padding
            # A positive-weight affine triangle is above the floor iff every
            # endpoint vertex is. No sampled interior substitutes for this.
            for at in pair:
                for vertex in np.flatnonzero(row["low"][at, :, 1] + padding[1] < 0):
                    if exact(part, at, int(vertex))[1] < 0:
                        failures.append({"kind": "FLOOR", "part": part, "frame": at, "vertex": int(vertex)})
            below = np.flatnonzero(np.min(low[:, indices, 1], axis=(0, 2)) < 0)
            for triangle in below:
                floor_pairs += 1
                vertices = indices[triangle]
                source_above = T.source_above_plane(raw_low, raw_high, vertices, pair, 0,
                    lambda at, vertex: exact(part, at, vertex)[1])
                if part != 0 or not any(rows[triangle] for rows in feet) or not source_above:
                    failures.append({"kind": "FLOOR_NATIVE", "part": part, "interval": frame,
                                     "triangle": int(triangle)})
            # Subtract the same linearly interpolated complete-bearer track
            # from every skin vertex before continuous relative separation.
            low, high = low.copy(), high.copy()
            low[:, :, 2] -= np.asarray([shifts[at] for at in pair])[:, None] * UNIT
            high[:, :, 2] -= np.asarray([shifts[at] for at in pair])[:, None] * UNIT
            tri_low, tri_high = low[:, indices], high[:, indices]
            broad_low, broad_high = tri_low.min(axis=(0, 2)), tri_high.max(axis=(0, 2))
            for assembly, box_u in enumerate(bounds):
                box = np.asarray(box_u, dtype=np.int64) * UNIT
                possible = np.flatnonzero(np.all(broad_low <= box[3:], axis=1) & np.all(broad_high >= box[:3], axis=1))
                for triangle in possible:
                    solid_pairs += 1
                    vertices = indices[triangle]
                    contact = part == 0 and palms[triangle] and T.inside_projection(
                        tri_low[:, triangle], tri_high[:, triangle], box) and T.source_above_plane(
                        raw_low, raw_high, vertices, pair, 128, lambda at, v: exact(0, at, v)[1])
                    numerical_contacts += int(contact)
                    if not contact and not T.separated_box(tri_low[:, triangle], tri_high[:, triangle], box, checks):
                        failures.append({"kind": "BEARER", "part": part, "interval": frame,
                                         "triangle": int(triangle), "assembly": assembly})
                    if len(failures) >= MAX_FAILURES:
                        break
                if len(failures) >= MAX_FAILURES:
                    break
            if len(failures) >= MAX_FAILURES:
                break
        if len(failures) >= MAX_FAILURES:
            break
    return {"clip": name, "frames": case["frames"], "intervals": case["frames"]-1,
            "complete": len(failures) < MAX_FAILURES, "clear": not failures, "failures": failures,
            "solid_checks": checks[0], "full_foot_support": supports, "hand_contact": contacts,
            "solid_pairs": solid_pairs, "numerical_contact_pairs": numerical_contacts,
            "floor_numerical_pairs": floor_pairs,
            "exact_vertices": len(exact_cache), "parts": [{"triangles": len(topology[at][0]),
                "native_padding_q24": row["padding"].tolist(), "native_errors": row["errors"],
                "full_bounds_u": P.outward_units(row["low"].min(axis=(0, 1)), row["high"].max(axis=(0, 1)))}
                for at, row in enumerate(cache)],
            "contact_rule": "Only complete left distal-palm triangles wholly above the actual bearer top and with full native XZ projection inside that exact prism may overlap through numerical padding; source penetration always refuses."}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "ASSEMBLY_OUTPUT_EXISTS")
    report, clips = sources(args.candidate)
    images = candidate_pins(args.candidate)
    executed = {str(path.relative_to(I.ROOT)): I.A.digest(path) for path in
                (Path(__file__), Path(A.__file__), Path(I.__file__), Path(T.__file__), Path(L.__file__))}
    cases, parts, rig, topology, roots, count, _, _, pins = I.source_inputs()
    P.require(all(np.array_equal(clip["matrices"][:, :1], np.broadcast_to(cases[0]["matrices"][8, :1],
                  (clip["frames"], 1, 12))) and np.all(clip["grounding"] == cases[0]["grounding"][8])
                  for clip in clips), "ASSEMBLY_ORIGINAL_SUPPORT")
    P.require(np.array_equal(clips[0]["matrices"][0], cases[0]["matrices"][8]) and
              np.array_equal(clips[2]["matrices"][-1], cases[0]["matrices"][8]) and
              np.array_equal(clips[0]["matrices"][-1], clips[1]["matrices"][0]) and
              np.array_equal(clips[1]["matrices"][-1], clips[2]["matrices"][0]), "ASSEMBLY_EXACT_JOIN")
    with (I.ROOT / "godot/demo/assets/underground-matrices/world-yaw-v1.ugyaw").open("rb") as stream:
        basis = N.CardinalBasis(stream, I.M.BASIS_SHA, I.M.BASIS_PRODUCER)
    vertex = report["contact_recipes"][0]["contact_vertex"]
    P.require(type(vertex) is int and 0 <= vertex < len(parts[0]["geometry"][0]["points"]) and
              all(row["contact_vertex"] == vertex for row in report["contact_recipes"]), "ASSEMBLY_CONTACT_IDENTITY")
    results = []
    for row, clip in zip(report["clips"], clips):
        result = prove_clip(row["clip"], clip, row["beam_offset_z_u"], parts, topology, rig, roots, basis, vertex)
        results.append(result)
        print(json.dumps({"clip": result["clip"], "clear": result["clear"], "checks": result["solid_checks"],
                          "failures": result["failures"][:3]}), flush=True)
    packet = {"schema": 1, "production_qualified": False, "verified_source_files": count,
              "source_inputs": pins, "producer_sources": executed, "candidate_inputs": images, "clips": results,
              "all_clear": all(row["clear"] for row in results),
              "scope": "Complete affine interval source/native-error enclosure against both exact translated bearers and full ground support; native execution and live paid binding remain open."}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    P.require(all(I.A.digest(I.ROOT/path) == digest for path, digest in executed.items()), "ASSEMBLY_PRODUCER_DRIFT")
    P.require(candidate_pins(args.candidate) == images, "ASSEMBLY_CANDIDATE_DRIFT")
    with args.out.open("x") as stream:
        json.dump(packet, stream, indent=2); stream.write("\n")
    if not packet["all_clear"]:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
