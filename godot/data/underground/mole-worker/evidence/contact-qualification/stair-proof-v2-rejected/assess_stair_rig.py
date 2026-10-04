#!/usr/bin/env python3
"""Measure the accepted mole rig for a stepped-foot source authoring packet; never emit travel permission."""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("compact_source_author", HERE / "author_compact_program.py")
D = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(D)
A, C, P, S, W = D.A, D.C, D.P, D.S, D.W
COMPACT_SHA = "f575382e1fdc4b5e20b70254a8c7a5b3ebf6f0256266627dc79d43f3e12dae37"
LEGS = (("left", 1, 2, 3, 4), ("right", 5, 6, 7, 8))


def read_actual_source():
    """Use the same complete raw/import closure as the accepted compact source, without filename-based reuse."""
    command = W.read_record(HERE / "analysis-carry-arm-v7/invocation.json")["command"]
    def value(key):
        return command[command.index("--" + key) + 1]
    proof = P.content.read_json(Path(value("proof")), value("proof-sha256"))
    plan = P.content.read_json(Path(value("plan")), value("plan-sha256"), 65536)
    original, sources, historical = W.extract_original(Path(value("source")), value("source-sha256"), proof, plan,
                                                       Path(value("import-archive")))
    parts = original[0]["geometry"]
    rig = P.content.read_json(Path(value("topology")), value("topology-sha256"), P.MAX_TOPOLOGY_BYTES)
    topology = P.read_topology(Path(value("topology")), value("topology-sha256"), value("content-sha256"), parts)
    image = HERE / "compact-program-compile-v2/result/mole-worker.ugactor"
    cases = S.read_image(image, COMPACT_SHA, parts)
    D.check_program(cases)
    return cases, parts, rig, topology, plan["world_root_bounds_u"], sources, historical


def selected_foot_vertices(part, triangles, foot_binds):
    """Retain complete triangles touched by the real foot/toe weights, including their mixed vertices."""
    geometry = part["geometry"][0]
    ids, weights = geometry["ids"], geometry["weights"]
    P.require(ids.shape == weights.shape and ids.ndim == 2 and len(ids) == len(geometry["points"]),
              "STAIR_FOOT_CENSUS")
    P.require(triangles.ndim == 2 and triangles.shape[1] == 3 and len(triangles) > 0 and
              np.all(triangles >= 0) and np.all(triangles < len(ids)), "STAIR_FOOT_TOPOLOGY")
    chosen = np.any(np.isin(ids, foot_binds) & (weights > 0), axis=1)
    rows = triangles[np.any(chosen[triangles], axis=1)]
    P.require(len(rows) > 0, "STAIR_FOOT_MISSING")
    return np.unique(rows), len(rows)


def anatomical_foot_triangles(part, triangles, foot_binds):
    """Source label: any vertex's dominant actual influence is foot/toe; retain its entire mixed triangle.

    Tiny imported weights can reach the crotch. They still affect every real
    body/solid equation but do not make that crotch a planted foot. Ties retain
    both labels conservatively. This never removes a collision primitive.
    """
    geometry = part["geometry"][0]
    ids, weights = geometry["ids"], geometry["weights"]
    P.require(ids.shape == weights.shape and ids.ndim == 2 and len(ids) == len(geometry["points"]) and
              triangles.ndim == 2 and triangles.shape[1] == 3 and np.all(triangles >= 0) and
              np.all(triangles < len(ids)) and np.all(weights >= 0), "STAIR_ANATOMY_CENSUS")
    dominant = np.max(weights, axis=1)
    matches = np.isin(ids, foot_binds) & (weights == dominant[:, None]) & (weights > 0)
    selected = np.any(np.any(matches, axis=1)[triangles], axis=1)
    P.require(np.any(selected), "STAIR_ANATOMY_MISSING")
    return selected


def two_leg_necessary_span(left, right, leading, rise_u, advance_u):
    """A diagnostic necessary reach test for fixed pelvis orientation; intersection is never gait clearance.

    Each unchanged-length leg constrains the common pelvis translation to a
    sphere centred at target ankle minus its ready hip. Two disjoint spheres
    prove this particular planted pair impossible without changing the pelvis
    orientation or leg lengths. Intersecting spheres do not establish knee,
    joint-limit, balance, terrain or whole-body feasibility.
    """
    P.require(leading in (0, 1) and type(rise_u) is int and 0 <= rise_u <= 512 and
              type(advance_u) is int and 0 <= advance_u <= 1024, "STAIR_REACH_ARGUMENT")
    centers = [np.asarray(row["ankle_u"]) - np.asarray(row["hip_u"]) for row in (left, right)]
    centers[leading] = centers[leading] + np.array([0, rise_u, -advance_u])
    distance = float(np.linalg.norm(centers[0] - centers[1]))
    radius = float(sum(left["segments_u"]) + sum(right["segments_u"]))
    return {"leading_foot": LEGS[leading][0], "rise_u": rise_u, "ankle_advance_u": advance_u,
            "root_sphere_center_distance_u": distance, "sum_segment_radii_u": radius,
            "disjoint_diagnostic": distance > radius,
            "scope": "floating source-authoring diagnostic; fixed ready pelvis orientation, no gameplay qualification"}


def measure(cases, parts, rig, topology, roots):
    """Measure original link lengths and exact outward ready foot geometry without modifying any source."""
    P.require(len(parts) == 2 and parts[0]["binds"] == 24 and len(topology[0]) == 1, "STAIR_BODY_CENSUS")
    parents, inverse, inverse_inverse = A.hierarchy(rig)
    actual, local, _ = A.joints(cases[0], 8, parents, inverse_inverse)
    grounding = float(cases[0]["grounding"][8])
    ready = dict(cases[0], frames=1, matrices=cases[0]["matrices"][8:9], grounding=cases[0]["grounding"][8:9])
    low, high, errors, padding = C.H.vertex_corners(ready, parts[0], 0, roots, Fraction(1))
    result = []
    for name, hip, knee, ankle, toe in LEGS:
        P.require((parents[knee], parents[ankle], parents[toe]) == (hip, knee, ankle), "STAIR_LEG_HIERARCHY")
        vertices, count = selected_foot_vertices(parts[0], topology[0][0], [ankle, toe])
        points = [(actual[at][:3, 3] + np.array([0, grounding, 0])) * 1024 for at in (hip, knee, ankle, toe)]
        bounds = P.outward_units(low[:, vertices].min(axis=(0, 1)), high[:, vertices].max(axis=(0, 1)))
        result.append({"side": name, "bones": [hip, knee, ankle, toe],
            "names": [rig["rig_binding"]["bones"][at]["name"] for at in (hip, knee, ankle, toe)],
            "hip_u": points[0].tolist(), "knee_u": points[1].tolist(), "ankle_u": points[2].tolist(),
            "toe_u": points[3].tolist(),
            "segments_u": [float(np.linalg.norm(points[1] - points[0])), float(np.linalg.norm(points[2] - points[1]))],
            "local_translations_m": [local[at][:3, 3].tolist() for at in (knee, ankle, toe)],
            "whole_foot_triangles": count, "whole_foot_vertices": len(vertices), "whole_foot_bounds_u": bounds,
            "source_padding_q24": [int(value) for value in padding], "native_residual_m": errors})
    necessary = [two_leg_necessary_span(*result, lead, rise, advance)
                 for rise in (128, 256) for advance in (128, 256, 384, 512) for lead in (0, 1)]
    return {"ready_clip": 0, "ready_frame": 8, "grounding_u": grounding * 1024,
            "hip_origin_u": ((actual[0][:3, 3] + np.array([0, grounding, 0])) * 1024).tolist(),
            "legs": result, "fixed_pelvis_reach_diagnostics": necessary,
            "rig_measurement_scope": "F32 source-derived diagnostic joint positions/lengths; outward integer foot mesh bounds include accepted native residual at yaw0",
            "requirements": ["real finite root track", "source-derived separate left/right foot contacts at each support height",
                             "swing foot/riser clearance", "knee and full body/tool primitive clearance", "landing turn and retreat",
                             "actual integer movement phase ownership", "exact installed tread/landing support", "native visual review"],
            "production_qualified": False}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "STAIR_ASSESSMENT_OUTPUT_EXISTS")
    paths = (__file__, D.__file__, A.__file__, C.__file__, C.H.__file__, W.__file__, W.H.__file__, S.__file__,
             P.__file__, P.content.__file__, P.envelope.__file__)
    producers = {str(Path(path).relative_to(P.ROOT)): P.content.file_hash(Path(path)) for path in paths}
    cases, parts, rig, topology, roots, sources, historical = read_actual_source()
    result = measure(cases, parts, rig, topology, roots)
    result.update(schema=1, compact_source_sha256=COMPACT_SHA, producer_sources=producers,
                  verified_source_files=sources, historical_source_snapshot=historical)
    P.require(all(P.content.file_hash(P.ROOT / name) == digest for name, digest in producers.items()), "STAIR_ASSESSMENT_SOURCE_DRIFT")
    raw = (json.dumps(result, indent=2) + "\n").encode()
    with args.out.open("xb") as output:
        output.write(raw)
    print(json.dumps({"sha256": hashlib.sha256(raw).hexdigest(), "legs": [row["whole_foot_bounds_u"] for row in result["legs"]],
                      "production_qualified": False}))


if __name__ == "__main__":
    main()
