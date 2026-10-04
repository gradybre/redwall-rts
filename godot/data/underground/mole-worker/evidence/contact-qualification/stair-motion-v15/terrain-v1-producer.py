#!/usr/bin/env python3
"""Finite source-only triangle/tread proof. Numerical sole contacts never excuse source penetration."""
from __future__ import annotations

import argparse
from fractions import Fraction
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("stair_author", HERE / "author_stair_motion.py")
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)
M, P, S = A.M, A.P, A.S
MAX_CHECKS = 2_000_000
MAX_DEPTH = 10
MAX_UNRESOLVED = 32
MAX_TRIANGLES = 131072
MAX_EXACT_VERTICES = 32768
AXIS_Q = 16384


def fixture_boxes(rise):
    """Complete positive prisms, including their top surfaces; no diagnostic contact-band omission."""
    P.require(type(rise) is int and rise in (-256, -128, 128, 256), "STEP_TERRAIN_FIXTURE")
    boxes = [[-1024, -64, -169, 1024, 0, 343],
             [-1024, rise - 64, -681, 1024, rise, -169]]
    for step, top in ((0, 0), (512, rise)):
        for low_x in (-896, 768):
            for low_s in (64, 320):
                boxes.append([low_x, -1024, 343-step-low_s-128, low_x+128, top-64, 343-step-low_s])
    return boxes


def projected_box_separation(low, high, box, axis):
    """Every accepted separation uses exact bounded integer projection, including the whole solid box."""
    P.require(axis.shape == (3,) and axis.dtype == np.int64 and np.any(axis) and
              np.all(np.abs(axis) <= AXIS_Q), "STEP_TERRAIN_AXIS")
    tri_low = int(np.sum(np.where(axis >= 0, low, high) * axis, axis=-1).min())
    tri_high = int(np.sum(np.where(axis >= 0, high, low) * axis, axis=-1).max())
    box_low = int(np.sum(np.where(axis >= 0, box[:3], box[3:]) * axis))
    box_high = int(np.sum(np.where(axis >= 0, box[3:], box[:3]) * axis))
    return tri_high < box_low or box_high < tri_low


def axes(low, high):
    yield from np.eye(3, dtype=np.int64)
    middle = (low.astype(np.float64) + high) / 2
    for triangle in (middle[0], middle[1], (middle[0] + middle[1]) / 2):
        edges = np.roll(triangle, -1, axis=0) - triangle
        directions = [np.cross(edges[0], edges[1])]
        directions.extend(np.cross(edge, base) for edge in edges for base in np.eye(3))
        for direction in directions:
            magnitude = float(np.max(np.abs(direction)))
            if magnitude > 0:
                value = np.rint(direction / magnitude * AXIS_Q).astype(np.int64)
                if np.any(value):
                    yield value


def separated_box(low, high, box, counter, depth=0):
    """An endpoint hull encloses the exact affine rendered interval; subdivision never samples it away."""
    counter[0] += 1
    P.require(counter[0] <= MAX_CHECKS, "STEP_TERRAIN_CHECK_CAPACITY")
    P.require(low.shape == high.shape == (2, 3, 3) and low.dtype == high.dtype == np.int64 and
              box.shape == (6,) and box.dtype == np.int64 and np.all(low <= high) and
              np.all(box[:3] < box[3:]) and all(np.all(np.abs(value) < (1 << 29)) for value in (low, high, box)),
              "STEP_TERRAIN_INTEGER_CAPACITY")
    if any(projected_box_separation(low, high, box, axis) for axis in axes(low, high)):
        return True
    if depth >= MAX_DEPTH:
        return False
    middle_low = (low[0] + low[1]) // 2
    middle_high = -(-(high[0] + high[1]) // 2)
    return separated_box(np.stack([low[0], middle_low]), np.stack([high[0], middle_high]), box, counter, depth+1) and \
        separated_box(np.stack([middle_low, low[1]]), np.stack([middle_high, high[1]]), box, counter, depth+1)


def exact_source_y(part, case, frame, vertex):
    """Exact rational source skin equation, before native arithmetic error; used only near a sole plane."""
    geometry = part["geometry"][0]
    point = [Fraction(float(value)) for value in geometry["points"][vertex]]
    result = Fraction(float(case["grounding"][frame]))
    for bind, weight in zip(geometry["ids"][vertex], geometry["weights"][vertex]):
        factor = Fraction(float(weight))
        if not factor:
            continue
        row = case["matrices"][frame, int(bind)]
        moved = Fraction(float(row[10]))
        for axis in range(3):
            moved += Fraction(float(row[1 + 3 * axis])) * point[axis]
        result += factor * moved
    return result * 1024


def source_above_plane(raw_low, raw_high, vertices, frames, plane, exact):
    """Outward intervals may be inconclusive, but a real source point below the plane always refuses."""
    threshold = plane * (P.SCALE // 1024)
    for endpoint, frame in enumerate(frames):
        for vertex in vertices:
            if int(raw_low[endpoint, vertex, 1]) >= threshold:
                continue
            if int(raw_high[endpoint, vertex, 1]) < threshold or exact(frame, int(vertex)) < plane:
                return False
    return True


def plane_for(side, frame, next_frame, recipe, rise):
    """Only a declared plant endpoint owns a potential numerical sole contact; a middle swing has none."""
    result = set()
    for at in (frame, next_frame):
        if recipe["planted_mask"][at] & (1 << side):
            height, z = recipe["ankle_translation_u"][at][side][1:]
            if height == 0 and z == 0:
                result.add(0)
            elif height == rise and z in tuple(-value for value in A.RIGHT_ADVANCES[1:]):
                result.add(1)
            else:
                raise ValueError("STEP_TERRAIN_PLANT_IDENTITY")
    return result


def foot_membership(part, triangles):
    return [M.anatomical_foot_triangles(part, triangles, (ankle, toe)) for _, _, _, ankle, toe in M.LEGS]


def inside_projection(low, high, box):
    return all(int(low[..., axis].min()) >= int(box[axis]) and
               int(high[..., axis].max()) <= int(box[axis+3]) for axis in (0, 2))


def prove(case, parts, topology, roots, recipe):
    P.require(recipe.get("root_contract") == A.ROOT_CONTRACT and
              case["source_loop_mode"] == 0 and case["frames"] == A.FRAME_COUNT and
              P.rendered_timing(case)[1] == (A.FRAME_COUNT-1)*65536 and len(parts) == 2 and
              len(recipe["root_u"]) == len(recipe["planted_mask"]) == len(recipe["ankle_translation_u"]) == case["frames"],
              "STEP_TERRAIN_PROGRAM")
    rise = recipe["rise_u"]
    boxes_u = fixture_boxes(rise)
    boxes = [np.asarray(box, dtype=np.int64) * (P.SCALE // 1024) for box in boxes_u]
    unresolved, supports, part_reports = [], [], []
    checks, pairs, contacts, offset = [0], 0, 0, 0
    exact_cache = {}
    def exact(frame, vertex):
        key = frame, vertex
        if key not in exact_cache:
            P.require(len(exact_cache) < MAX_EXACT_VERTICES, "STEP_TERRAIN_EXACT_CAPACITY")
            exact_cache[key] = exact_source_y(parts[0], case, frame, vertex) + recipe["root_u"][frame][1]
        return exact_cache[key]
    for part_index, part in enumerate(parts):
        P.require(len(part["geometry"]) == len(topology[part_index]) == 1, "STEP_TERRAIN_SURFACES")
        triangles = topology[part_index][0]
        P.require(0 < len(triangles) <= MAX_TRIANGLES, "STEP_TERRAIN_TRIANGLE_CAPACITY")
        count = max(1, part["binds"])
        matrices = case["matrices"][:, offset:offset+count]
        all_raw = P._vertex_hulls(part, matrices, case["grounding"])
        padding, residual = P._residual_padding(part, matrices, case["grounding"], roots, all_raw)
        memberships = foot_membership(part, triangles) if part_index == 0 else []
        foot_vertices = [np.unique(triangles[mask]) for mask in memberships]
        previous = P._vertex_hulls(part, matrices[:1], case["grounding"][:1])[0]
        for frame, next_frame in P.rendered_intervals(case):
            following = P._vertex_hulls(part, matrices[next_frame:next_frame+1], case["grounding"][next_frame:next_frame+1])[0]
            roots_q24 = np.asarray([recipe["root_u"][frame], recipe["root_u"][next_frame]], dtype=np.int64) * (P.SCALE // 1024)
            raw_low = np.stack([previous[0], following[0]]) + roots_q24[:, None, :]
            raw_high = np.stack([previous[1], following[1]]) + roots_q24[:, None, :]
            # Actor receives ceil(root interpolation) once after skinning.
            # Compared with the exact affine endpoint root path this adds
            # [0, 1)u per axis, never a downward displacement into a sole plane.
            low, high = raw_low-padding, raw_high+padding+(P.SCALE // 1024)
            previous = following
            allowed = [plane_for(side, frame, next_frame, recipe, rise) for side in (0, 1)] if part_index == 0 else []
            if part_index == 0:
                plant = recipe["planted_mask"][frame] & recipe["planted_mask"][next_frame]
                P.require(plant != 0, "STEP_TERRAIN_UNSUPPORTED_INTERVAL")
                for side in (0, 1):
                    if not plant & (1 << side):
                        continue
                    P.require(len(allowed[side]) == 1, "STEP_TERRAIN_SUPPORT_IDENTITY")
                    deck = next(iter(allowed[side]))
                    vertices = foot_vertices[side]
                    support_low, support_high = low[:, vertices].min(axis=(0, 1)), high[:, vertices].max(axis=(0, 1))
                    projection_ok = inside_projection(low[:, vertices], high[:, vertices], boxes[deck])
                    source_ok = source_above_plane(raw_low, raw_high, vertices, (frame, next_frame), boxes_u[deck][4], exact)
                    # A source contact must be within the single world-unit cell
                    # adjoining the plane. A visible floating foot cannot become
                    # support merely because its broad box lies above a deck.
                    near_vertices = vertices[np.argsort(raw_low[0, vertices, 1])[:8]]
                    gaps = [min(exact(at, int(v)) for v in near_vertices) - boxes_u[deck][4] for at in (frame, next_frame)]
                    near_ok = all(Fraction(0) <= gap < 1 for gap in gaps)
                    row = {"interval": frame, "foot": side, "deck": deck,
                           "full_foot_enclosure_u": P.outward_units(support_low, support_high),
                           "exact_source_gap_u": [[gap.numerator, gap.denominator] for gap in gaps],
                           "projection_inside": projection_ok, "source_not_below_plane": source_ok, "source_contact_cell": near_ok}
                    supports.append(row)
                    if not (projection_ok and source_ok and near_ok):
                        unresolved.append({"kind": "SUPPORT", **row})
            tri_low, tri_high = low[:, triangles], high[:, triangles]
            broad_low, broad_high = tri_low.min(axis=(0, 2)), tri_high.max(axis=(0, 2))
            for section, box in enumerate(boxes):
                possible = np.flatnonzero(np.all(broad_low <= box[3:], axis=1) & np.all(broad_high >= box[:3], axis=1))
                for triangle in possible:
                    pairs += 1
                    contact = False
                    if part_index == 0 and section < 2:
                        vertices = triangles[triangle]
                        for side in (0, 1):
                            if section in allowed[side] and memberships[side][triangle] and \
                                    inside_projection(tri_low[:, triangle], tri_high[:, triangle], box) and \
                                    source_above_plane(raw_low, raw_high, vertices, (frame, next_frame), boxes_u[section][4], exact):
                                contact = True
                                break
                    if contact:
                        contacts += 1
                    elif not separated_box(tri_low[:, triangle], tri_high[:, triangle], box, checks):
                        unresolved.append({"kind": "SOLID", "part": part_index, "interval": frame,
                                           "triangle": int(triangle), "section": section})
                    if len(unresolved) >= MAX_UNRESOLVED:
                        return {"clear": False, "unresolved": unresolved, "supports": supports,
                                "checks": checks[0], "pairs": pairs, "numerical_contact_pairs": contacts,
                                "stopped_at_witness_limit": True, "production_qualified": False}
            print("stair-terrain-progress " + json.dumps({"part": part_index, "interval": frame,
                  "pairs": pairs, "checks": checks[0], "unresolved": len(unresolved)}), file=sys.stderr, flush=True)
        part_reports.append({"part": part_index, "triangles": len(triangles), "native_padding_q24": padding.tolist(),
                             "native_residual_m": residual})
        offset += count
    return {"clear": not unresolved, "unresolved": unresolved, "supports": supports, "checks": checks[0],
            "pairs": pairs, "numerical_contact_pairs": contacts, "parts": part_reports,
            "exact_source_vertices": len(exact_cache), "fixture_boxes_u": boxes_u, "rendered_edges": P.rendered_intervals(case),
            "source_contact_semantics": "complete real foot/toe triangles only; source vertices on/above exact deck top, full native footprint supported; only numerical enclosure may overlap the positive deck",
            "exact_yaw": 0, "root_contract": A.ROOT_CONTRACT,
            "root_rounding_extra_q24": [0, P.SCALE // 1024], "production_qualified": False}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("preview", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "STEP_TERRAIN_OUTPUT_EXISTS")
    _, parts, _, topology, roots, sources, historical = M.read_actual_source()
    compilation = M.W.read_record(args.preview/"compilation.json")
    image = args.preview/"mole-worker.ugactor"
    cases = S.read_image(image, compilation["content_sha256"], parts)
    with image.open("rb") as stream:
        header = stream.read(184)
    candidate = P.content.read_json(args.preview/"candidate.json", header[120:152].hex(), 1048576)
    for path, digest in candidate["producer_sources"].items():
        P.require(P.content.file_hash(P.ROOT/path) == digest, "STEP_TERRAIN_AUTHOR_DRIFT")
    recipes = [row for row in candidate["attempts"] if row["status"] == "SOURCE_CANDIDATE_ONLY"]
    P.require(len(recipes) == len(cases) and 0 < len(cases) <= 4, "STEP_TERRAIN_CASE_CENSUS")
    paths = (__file__, A.__file__, M.__file__, M.D.__file__, M.A.__file__, M.C.__file__, M.C.H.__file__, M.W.__file__, M.W.H.__file__,
             S.__file__, P.__file__, P.content.__file__, P.envelope.__file__, image, args.preview/"candidate.json")
    pins = {str(Path(path).resolve().relative_to(P.ROOT)): P.content.file_hash(Path(path)) for path in paths}
    results = [{"rise_u": recipe["rise_u"], **prove(case, parts, topology, roots, recipe)} for case, recipe in zip(cases, recipes)]
    report = {"schema": 1, "content_sha256": compilation["content_sha256"], "clips": results,
              "producer_sources": pins, "verified_source_files": sources, "historical_source_snapshot": historical,
              "scope": "source-local yaw0 affine triangle/deck proof, explicit foot-phase support and retained native arithmetic error; not actor/tool self-clearance, actual mover, entry/retreat, paid geometry or travel permission",
              "production_qualified": False}
    P.require(all(P.content.file_hash(P.ROOT/path) == digest for path, digest in pins.items()), "STEP_TERRAIN_SOURCE_DRIFT")
    with args.out.open("x") as output:
        json.dump(report, output, indent=2)
        output.write("\n")
    print(json.dumps({"clips": [{"rise_u": row["rise_u"], "clear": row["clear"], "checks": row["checks"],
                                "unresolved": len(row["unresolved"])} for row in results], "production_qualified": False}))
    if not all(row["clear"] for row in results):
        raise SystemExit(2)


if __name__ == "__main__":
    main()
