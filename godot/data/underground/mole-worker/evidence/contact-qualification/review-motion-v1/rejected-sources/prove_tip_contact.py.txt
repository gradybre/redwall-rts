#!/usr/bin/env python3
"""Exact source-vertex crossing and complete tool/face patch; no production permission is emitted."""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("self_source", HERE / "prove_self_clearance.py")
S = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(S)
P = S.P


def crossing(part: dict, matrices: np.ndarray, grounding: np.ndarray, vertex: int,
             first: int, last: int, roots: list[int]) -> dict:
    """Strict opposite endpoint intervals witness contact without claiming an integer anchor lies on the exact trajectory."""
    P.require(part["binds"] == 0 and len(part["geometry"]) == 1 and
              type(vertex) is int and 0 <= vertex < len(part["geometry"][0]["points"]) and
              type(first) is int and type(last) is int and last == first + 1 and
              0 <= first < last < len(matrices), "TIP_SOURCE_SELECTION")
    raw = P._vertex_hulls(part, matrices, grounding)
    padding, residual = P._residual_padding(part, matrices, grounding, roots, raw)
    points = part["geometry"][0]["points"]
    source = [Fraction(float(value)) for value in points[vertex]]
    intervals, ideal = [], []
    for frame in (first, last):
        low, high = P._vertex_hulls(part, matrices[frame:frame+1], grounding[frame:frame+1])[0]
        intervals.append((low[vertex] - padding, high[vertex] + padding))
        transform = matrices[frame, 0]
        exact = [sum(source[axis] * Fraction(float(transform[axis * 3 + out])) for axis in range(3)) +
                 Fraction(float(transform[9 + out])) for out in range(3)]
        exact[1] += Fraction(float(grounding[frame]))
        ideal.append(exact)
    P.require(int(intervals[0][0][1]) > 0 and int(intervals[1][1][1]) < 0, "TIP_NO_ROBUST_FACE_CROSSING")
    share = ideal[0][1] / (ideal[0][1] - ideal[1][1])
    P.require(0 < share < 1, "TIP_CROSSING_PARAMETER")
    contact = [(1 - share) * first_value + share * last_value
               for first_value, last_value in zip(ideal[0], ideal[1])]
    P.require(contact[1] == 0, "TIP_FACE_EQUATION")
    anchor = [round(value * 1024) for value in contact]
    return {"vertex": vertex, "first_frame": first, "last_frame": last,
            "source_point_f32_m": [float(value) for value in source],
            "endpoint_intervals_q24": [[low.tolist(), high.tolist()] for low, high in intervals],
            "endpoint_ideal_m": [[P.envelope.fraction_record(value) for value in point] for point in ideal],
            "ideal_crossing_share": P.envelope.fraction_record(share),
            "ideal_crossing_m": [P.envelope.fraction_record(value) for value in contact],
            "authored_anchor_u": anchor, "residual_m": residual,
            "anchor_semantics": "nearest/even integer focus to exact ideal crossing; complete patch owns native trajectory uncertainty",
            "crossing_semantics": "actual endpoint enclosures lie strictly on opposite sides; complete interpolated tool envelope bounds the swept contact"}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("analysis", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "TIP_OUTPUT_EXISTS")
    command = json.loads((args.analysis / "invocation.json").read_text())["command"]
    def value(key):
        return command[command.index("--" + key) + 1]
    proof = P.content.read_json(Path(value("proof")), value("proof-sha256"))
    plan = P.content.read_json(Path(value("plan")), value("plan-sha256"), 65536)
    original, _, pins = P.content.extract(Path(value("source")), value("source-sha256"), proof, plan,
                                         Path(value("import-archive")))
    topology = P.read_topology(Path(value("topology")), value("topology-sha256"), value("content-sha256"),
                               original[0]["geometry"])
    image = args.analysis / "result/mole-worker.ugactor"
    expected = json.loads((args.analysis / "result/compilation.json").read_text())["content_sha256"]
    cases = S.read_image(image, expected, original[0]["geometry"])
    body_binds = original[0]["geometry"][0]["binds"]
    tool = original[0]["geometry"][1]
    case = dict(cases[6], geometry=[tool], matrices=cases[6]["matrices"][:, body_binds:body_binds+1])
    # This exact authored source tip is the downward stone-head point. Native
    # evidence must identify this same source vertex on the rendered original prop.
    witness = crossing(tool, case["matrices"], case["grounding"], 148, 17, 18, plan["world_root_bounds_u"])
    triangle_ids = np.flatnonzero(np.any(topology[1][0] == witness["vertex"], axis=1)).tolist()
    P.require(triangle_ids, "TIP_SOURCE_TOPOLOGY")
    envelope = P.continuous_floor(case, [topology[1]], plan["world_root_bounds_u"])[0]
    floor = envelope["floor_intersection_u"]
    P.require(floor is not None and floor[1] < 0 and floor[4] == 0, "TIP_PATCH_MISSING")
    patch = [floor[0], 0, floor[2], floor[3], 0, floor[5]]
    anchor = witness["authored_anchor_u"]
    P.require(patch[0] <= anchor[0] <= patch[3] and patch[2] <= anchor[2] <= patch[5], "TIP_ANCHOR_PATCH")
    report = {"schema": 1, "content_sha256": expected, "source_sha256": value("source-sha256"),
              "topology_sha256": value("topology-sha256"), "mesh_sha256": P.content.geometry_fingerprint(tool).hex(),
              "clip": 6, "part": 1, "source_triangles": triangle_ids, "witness": witness,
              "contact_kind": 2, "contact_patch_u": patch, "complete_tool_primitive_proof": envelope,
              "exact_yaw": 0, "production_qualified": False, "native_witness": "PENDING",
              "verified_source_files": pins,
              "producer_sources": {str(Path(path).relative_to(P.ROOT)): P.content.file_hash(Path(path))
                                   for path in (__file__, S.__file__, P.__file__, P.envelope.__file__)}}
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"anchor_u": anchor, "patch_u": patch, "image_sha256": expected,
                      "production_qualified": False}, indent=2))


if __name__ == "__main__":
    main()
