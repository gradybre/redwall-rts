#!/usr/bin/env python3
"""Check unchanged rooted gait against an explicit finite surrounding timber fixture.

The reviewed two-deck proof supplies continuous full-foot contact witnesses.
This supplement checks their actual destination deck and every complete
body/clothing/tool triangle against all supplied positive prisms. Exact
cardinal fixture transforms are source-frame geometry, not native yaw grants.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("accepted_stair_terrain", HERE / "prove_stair_terrain.py")
T = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(T)
A, M, P, S = T.A, T.M, T.P, T.S
MAX_SEGMENTS = 4
MAX_SOLIDS = 32
MAX_COORD = 8192


def turn(vector, quarter):
    """Exact source-axis cardinal transform; no float heading or rounded native basis."""
    P.require(type(quarter) is int and 0 <= quarter < 4 and len(vector) == 3 and
              all(type(value) is int and abs(value) <= 2*MAX_COORD for value in vector), "SEQUENCE_TURN")
    x, y, z = vector
    return ((x, y, z), (z, y, -x), (-x, y, -z), (-z, y, x))[quarter]


def local_box(box, segment):
    """Pull the complete positive fixture prism into a segment's exact source frame."""
    origin, quarter = segment["origin_u"], segment["quarter_turn"]
    corners = [turn([x-origin[0], y-origin[1], z-origin[2]], (-quarter) % 4)
               for x in (box[0], box[3]) for y in (box[1], box[4]) for z in (box[2], box[5])]
    result = [min(row[axis] for row in corners) for axis in range(3)] + \
             [max(row[axis] for row in corners) for axis in range(3)]
    P.require(all(abs(value) <= MAX_COORD for value in result), "SEQUENCE_LOCAL_CAPACITY")
    return result


def endpoint(segment, root):
    rotated = turn(root, segment["quarter_turn"])
    return [a+b for a, b in zip(segment["origin_u"], rotated)]


def validate_fixture(fixture, recipe):
    P.require(type(fixture) is dict and type(fixture.get("schema")) is int and fixture["schema"] == 1 and
              fixture.get("engineering_only") is True and type(fixture.get("rise_u")) is int and
              fixture["rise_u"] == recipe["rise_u"],
              "SEQUENCE_FIXTURE")
    solids, segments = fixture.get("solids_u"), fixture.get("segments")
    P.require(type(solids) is list and 2 <= len(solids) <= MAX_SOLIDS and
              type(segments) is list and 1 <= len(segments) <= MAX_SEGMENTS, "SEQUENCE_CAPACITY")
    for box in solids:
        P.require(type(box) is list and len(box) == 6 and
                  all(type(v) is int and abs(v) <= MAX_COORD for v in box) and
                  all(box[axis] < box[axis+3] for axis in range(3)), "SEQUENCE_POSITIVE_SOLID")
    for index, segment in enumerate(segments):
        P.require(type(segment) is dict, "SEQUENCE_SEGMENT")
        origin, quarter, supports = (segment.get(key) for key in ("origin_u", "quarter_turn", "support_solids"))
        P.require(type(origin) is list and len(origin) == 3 and
                  all(type(v) is int and abs(v) <= MAX_COORD for v in origin) and
                  type(quarter) is int and 0 <= quarter < 4 and type(supports) is list and len(supports) == 2 and
                  all(type(v) is int and 0 <= v < len(solids) for v in supports) and supports[0] != supports[1],
                  "SEQUENCE_SEGMENT")
        for deck, solid in enumerate(supports):
            box = local_box(solids[solid], segment)
            P.require(box[4] == (0 if deck == 0 else recipe["rise_u"]), "SEQUENCE_SUPPORT_PLANE")
        if index:
            previous = segments[index-1]
            P.require(previous["quarter_turn"] == quarter and
                      endpoint(previous, recipe["root_u"][-1]) == endpoint(segment, recipe["root_u"][0]) and
                      previous["support_solids"][1] == supports[0], "SEQUENCE_DISCONTINUOUS_ROOT_OR_SUPPORT")
    return solids, segments


def validate_endpoint_pose(case):
    P.require(np.array_equal(case["matrices"][0], case["matrices"][-1]) and
              case["grounding"][0] == case["grounding"][-1], "SEQUENCE_DISCONTINUOUS_POSE")


def retained_supports(base, case, recipe, topology):
    """The pinned reviewed baseline is a proof dependency, not an unverified caller success flag."""
    P.require(base.get("clear") is True and base.get("unresolved") == [] and
              base.get("root_contract") == A.ROOT_CONTRACT and base.get("exact_yaw") == 0 and
              base.get("fixture_boxes_u") == T.fixture_boxes(recipe["rise_u"]) and
              base.get("rendered_edges") == [list(pair) for pair in P.rendered_intervals(case)] and
              [row.get("triangles") for row in base.get("parts", [])] == [len(part[0]) for part in topology],
              "SEQUENCE_BASE_PROOF")
    rows = base.get("supports")
    P.require(type(rows) is list and 0 < len(rows) <= 2*(A.FRAME_COUNT-1), "SEQUENCE_BASE_SUPPORT")
    covered = set()
    for row in rows:
        frame, foot, deck = (row.get(name) for name in ("interval", "foot", "deck"))
        bounds = row.get("full_foot_enclosure_u")
        P.require(type(frame) is int and 0 <= frame < A.FRAME_COUNT-1 and type(foot) is int and foot in (0, 1) and
                  type(deck) is int and deck in (0, 1) and type(bounds) is list and len(bounds) == 6 and
                  all(type(v) is int and abs(v) <= MAX_COORD for v in bounds) and
                  all(bounds[axis] < bounds[axis+3] for axis in range(3)) and
                  all(row.get(key) is True for key in ("projection_inside", "source_not_below_plane", "source_contact_cell")),
                  "SEQUENCE_BASE_SUPPORT")
        P.require(recipe["planted_mask"][frame] & recipe["planted_mask"][frame+1] & (1 << foot) and
                  T.plane_for(foot, frame, frame+1, recipe, recipe["rise_u"]) == {deck}, "SEQUENCE_BASE_SUPPORT")
        covered.add(frame)
    P.require(covered == set(range(A.FRAME_COUNT-1)), "SEQUENCE_BASE_SUPPORT_COVERAGE")
    return rows


def support_fits(row, boxes, segment):
    box = boxes[segment["support_solids"][row["deck"]]]
    bounds = row["full_foot_enclosure_u"]
    return all(box[axis] <= bounds[axis] and bounds[axis+3] <= box[axis+3] for axis in (0, 2))


def prove(case, parts, topology, world_roots, recipe, base, fixture):
    T.validate_recipe(recipe, case["frames"])
    P.require(case["source_loop_mode"] == 0 and case["frames"] == A.FRAME_COUNT and
              P.rendered_timing(case)[1] == (A.FRAME_COUNT-1)*65536 and len(parts) == 2,
              "SEQUENCE_PROGRAM")
    validate_endpoint_pose(case)
    solid_rows, segments = validate_fixture(fixture, recipe)
    supports = retained_supports(base, case, recipe, topology)
    segment_boxes_u = [[local_box(box, segment) for box in solid_rows] for segment in segments]
    segment_boxes = [[np.asarray(box, dtype=np.int64)*(P.SCALE//1024) for box in boxes] for boxes in segment_boxes_u]
    checks, pairs, contacts, exact_cache, offset = [0], 0, 0, {}, 0
    unresolved, support_rows, part_reports = [], [], []
    for at, segment in enumerate(segments):
        for row in supports:
            okay = support_fits(row, segment_boxes_u[at], segment)
            support_rows.append({"segment": at, "interval": row["interval"], "foot": row["foot"],
                                 "solid": segment["support_solids"][row["deck"]], "projection_inside": okay})
            if not okay:
                unresolved.append({"kind": "SUPPORT", **support_rows[-1]})
    P.require(len(unresolved) <= T.MAX_UNRESOLVED, "SEQUENCE_SUPPORT_REFUSAL_CAPACITY")

    def exact(frame, vertex):
        key = frame, vertex
        if key not in exact_cache:
            P.require(len(exact_cache) < T.MAX_EXACT_VERTICES, "SEQUENCE_EXACT_CAPACITY")
            exact_cache[key] = T.exact_source_y(parts[0], case, frame, vertex)+recipe["root_u"][frame][1]
        return exact_cache[key]

    for part_index, part in enumerate(parts):
        P.require(len(part["geometry"]) == len(topology[part_index]) == 1, "SEQUENCE_SURFACES")
        triangles = topology[part_index][0]
        P.require(0 < len(triangles) <= T.MAX_TRIANGLES, "SEQUENCE_TRIANGLE_CAPACITY")
        count = max(1, part["binds"])
        matrices = case["matrices"][:, offset:offset+count]
        all_raw = P._vertex_hulls(part, matrices, case["grounding"])
        padding, residual = P._residual_padding(part, matrices, case["grounding"], world_roots, all_raw)
        memberships = T.foot_membership(part, triangles) if part_index == 0 else []
        previous = P._vertex_hulls(part, matrices[:1], case["grounding"][:1])[0]
        for frame, following_frame in P.rendered_intervals(case):
            following = P._vertex_hulls(part, matrices[following_frame:following_frame+1], case["grounding"][following_frame:following_frame+1])[0]
            roots = np.asarray([recipe["root_u"][frame], recipe["root_u"][following_frame]], dtype=np.int64)
            raw_low, raw_high = T.translated_endpoint_hulls(np.stack([previous[0], following[0]]),
                                                           np.stack([previous[1], following[1]]), roots)
            low, high = raw_low-padding, raw_high+padding+P.SCALE//1024
            previous = following
            tri_low, tri_high = low[:, triangles], high[:, triangles]
            broad_low, broad_high = tri_low.min(axis=(0, 2)), tri_high.max(axis=(0, 2))
            allowed = [T.plane_for(side, frame, following_frame, recipe, recipe["rise_u"]) for side in (0, 1)] if part_index == 0 else []
            for segment_index, boxes in enumerate(segment_boxes):
                segment = segments[segment_index]
                for solid, box in enumerate(boxes):
                    possible = np.flatnonzero(np.all(broad_low <= box[3:], axis=1) & np.all(broad_high >= box[:3], axis=1))
                    for triangle in possible:
                        pairs += 1
                        contact = False
                        if part_index == 0:
                            for side in (0, 1):
                                matching = any(segment["support_solids"][deck] == solid for deck in allowed[side])
                                if matching and memberships[side][triangle] and T.inside_projection(tri_low[:, triangle], tri_high[:, triangle], box) and \
                                        T.source_above_plane(raw_low, raw_high, triangles[triangle], (frame, following_frame),
                                                             segment_boxes_u[segment_index][solid][4], exact):
                                    contact = True
                                    break
                        if contact:
                            contacts += 1
                        elif not T.separated_box(tri_low[:, triangle], tri_high[:, triangle], box, checks):
                            unresolved.append({"kind": "SOLID", "segment": segment_index, "part": part_index,
                                               "interval": frame, "triangle": int(triangle), "solid": solid})
                        if len(unresolved) >= T.MAX_UNRESOLVED:
                            return {"clear": False, "unresolved": unresolved, "checks": checks[0], "pairs": pairs,
                                    "numerical_contact_pairs": contacts, "supports": support_rows, "stopped_at_witness_limit": True}
            if frame % 30 == 0:
                print("stair-sequence-progress "+json.dumps({"part": part_index, "interval": frame, "pairs": pairs,
                      "checks": checks[0], "unresolved": len(unresolved)}), file=sys.stderr, flush=True)
        part_reports.append({"part": part_index, "triangles": len(triangles), "native_padding_q24": padding.tolist(), "native_residual_m": residual})
        offset += count
    return {"clear": not unresolved, "unresolved": unresolved, "checks": checks[0], "pairs": pairs,
            "numerical_contact_pairs": contacts, "supports": support_rows, "parts": part_reports,
            "segments": len(segments), "intervals_per_segment": A.FRAME_COUNT-1,
            "exact_endpoint_pose_match": True, "exact_endpoint_root_and_support_match": True,
            "exact_source_vertices": len(exact_cache), "fixture_prisms": len(solid_rows),
            "native_source_yaw": 0, "exact_fixture_turns_are_native_yaw_permissions": False}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("preview", type=Path)
    parser.add_argument("base_proof", type=Path)
    parser.add_argument("base_proof_sha256")
    parser.add_argument("fixture", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "SEQUENCE_OUTPUT_EXISTS")
    _, parts, _, topology, world_roots, sources, historical = M.read_actual_source()
    compilation = M.W.read_record(args.preview/"compilation.json")
    image = args.preview/"mole-worker.ugactor"
    cases = S.read_image(image, compilation["content_sha256"], parts)
    with image.open("rb") as stream:
        header = stream.read(184)
    candidate = P.content.read_json(args.preview/"candidate.json", header[120:152].hex(), 1048576)
    base = P.content.read_json(args.base_proof, args.base_proof_sha256, 2*1048576)
    fixture = P.content.read_json(args.fixture, P.content.file_hash(args.fixture), 65536)
    rise = fixture.get("rise_u")
    recipes = [row for row in candidate["attempts"] if row["status"] == "SOURCE_CANDIDATE_ONLY"]
    P.require(len(recipes) == len(cases) and 0 < len(cases) <= 4 and base.get("content_sha256") == compilation["content_sha256"], "SEQUENCE_BASE_IDENTITY")
    choices = [(case, recipe) for case, recipe in zip(cases, recipes) if recipe["rise_u"] == rise]
    base_rows = [row for row in base["clips"] if row["rise_u"] == rise]
    P.require(len(choices) == len(base_rows) == 1, "SEQUENCE_CASE_CENSUS")
    pins = {}
    for record in (candidate, base):
        P.require(type(record.get("producer_sources")) is dict and 0 < len(record["producer_sources"]) <= 32, "SEQUENCE_PRODUCER_CENSUS")
        for path, digest in record["producer_sources"].items():
            P.require(P.content.file_hash(P.ROOT/path) == digest, "SEQUENCE_PRODUCER_DRIFT")
            P.require(path not in pins or pins[path] == digest, "SEQUENCE_PRODUCER_CONFLICT")
            pins[path] = digest
    paths = [Path(__file__), Path(T.__file__), image, args.preview/"candidate.json", args.base_proof, args.fixture]
    for path in paths:
        name, digest = str(path.resolve().relative_to(P.ROOT)), P.content.file_hash(path)
        P.require(name not in pins or pins[name] == digest, "SEQUENCE_PRODUCER_CONFLICT")
        pins[name] = digest
    case, recipe = choices[0]
    report = {"schema": 1, "result": prove(case, parts, topology, world_roots, recipe, base_rows[0], fixture),
              "content_sha256": compilation["content_sha256"], "baseline_proof_sha256": args.base_proof_sha256,
              "producer_sources": pins, "verified_source_files": sources, "historical_source_snapshot": historical,
              "scope": "complete unchanged source triangles against explicit surrounding engineering prisms, inherited continuous contact witnesses and exact repeated endpoints; source-local yaw0, no native rotated-heading, landing turn, pace, installed support or production permission",
              "production_qualified": False}
    P.require(all(P.content.file_hash(P.ROOT/path) == digest for path, digest in pins.items()), "SEQUENCE_SOURCE_DRIFT")
    with args.out.open("x") as output:
        json.dump(report, output, indent=2)
        output.write("\n")
    print(json.dumps({"clear": report["result"]["clear"], "unresolved": len(report["result"]["unresolved"]),
                      "checks": report["result"]["checks"], "production_qualified": False}))
    if not report["result"]["clear"]:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
