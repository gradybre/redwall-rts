#!/usr/bin/env python3
"""Inspect and author a distinct BASIC-tool installation source; never grant BUILD permission."""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("actual_mole_source", HERE / "assess_stair_rig.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
A, P = M.A, M.P
PREFIX_SHA = "edd562056b12f732fbf60f0536207ba2afd1dce650d19df552ecf1e75ff9cf81"


def target_faces(packet):
    """Read the actual pinned candidate face relative to its station, without guessing reach or support."""
    rows = packet.get("fastening_candidates")
    P.require(packet.get("schema") == 1 and packet.get("engineering_only") is True and
              type(rows) is list and len(rows) == 2, "INSTALL_PREFIX")
    result = []
    for row in rows:
        bounds, root = row.get("target_bounds_u"), row.get("station_root_u")
        P.require(row.get("face") == "positive_y" and row.get("yaw_u16") == 0 and
                  type(bounds) is list and len(bounds) == 6 and type(root) is list and len(root) == 3 and
                  all(type(v) is int and abs(v) <= 8192 for v in bounds+root) and
                  all(bounds[i] < bounds[i+3] for i in range(3)), "INSTALL_TARGET_FACE")
        local = [v-root[i % 3] for i, v in enumerate(bounds)]
        P.require(local[4] == 0, "INSTALL_TARGET_HEIGHT")
        result.append({"assembly": row["assembly"], "existing_target_kind": row["existing_target_kind"],
                       "target_bounds_u": bounds, "station_root_u": root,
                       "local_target_box_u": local, "local_patch_limits_u": [local[0], 0, local[2], local[3], 0, local[5]],
                       "scope": "candidate existing face only; no authored stroke, stance or work permission"})
    return result


def prop_points(case, frame, part):
    P.require(len(part["geometry"]) == 1 and 0 <= frame < case["frames"], "INSTALL_TOOL_SOURCE")
    source = part["geometry"][0]["points"].astype(np.float64)
    P.require(0 < len(source) <= 131072 and source.shape[1:] == (3,) and np.all(np.isfinite(source)),
              "INSTALL_TOOL_CAPACITY")
    matrix = P._affine64(case["matrices"][frame, 24])
    points = source @ matrix[:3, :3].T + matrix[:3, 3]
    points[:, 1] += float(case["grounding"][frame])
    return points*1024


def inspect(cases, parts, rig, packet):
    parents, _, inverse_inverse = A.hierarchy(rig)
    globals_, _, fit = A.joints(cases[0], 8, parents, inverse_inverse)
    grounding = float(cases[0]["grounding"][8])
    source = parts[1]["geometry"][0]["points"]
    ready = prop_points(cases[0], 8, parts[1])
    work = [prop_points(cases[2], frame, parts[1]) for frame in (0, cases[2]["frames"]//2, cases[2]["frames"]-1)]
    vertices = sorted({148, *[int(operation(source[:, axis])) for operation in (np.argmin, np.argmax) for axis in range(3)]})
    return {"source_vertex_count": len(source), "source_triangles": 1150,
            "tool_source_bounds": [*source.min(axis=0).tolist(), *source.max(axis=0).tolist()],
            "ready_tool_bounds_u": [*ready.min(axis=0).tolist(), *ready.max(axis=0).tolist()],
            "source_vertex_candidates": [{"vertex": at, "source_m": source[at].tolist(), "ready_u": ready[at].tolist(),
                                          "downward_reference_u": [points[at].tolist() for points in work],
                                          "meaning": "known previously witnessed pick tip" if at == 148 else "raw mesh extremum; anatomical/head label unreviewed"}
                                         for at in vertices],
            "ready_joints_u": [{"bind": at, "name": rig["rig_binding"]["bones"][at]["name"],
                                "point": ((globals_[at][:3, 3]+[0, grounding, 0])*1024).tolist()}
                               for at in (9, 10, 11, 16, 17, 18, 19)],
            "actual_hand_fit": fit.tolist(), "targets": target_faces(packet),
            "source_scope": "floating inspection of actual source coefficients for authoring only; no continuous/contact/native proof",
            "production_qualified": False}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "INSTALL_OUTPUT_EXISTS")
    prefix = HERE/"stair-sequence-prefix-v1/first-entry-prefix-v1.source.json"
    paths = [Path(__file__), Path(M.__file__), Path(M.D.__file__), Path(A.__file__), Path(M.C.__file__),
             Path(M.C.H.__file__), Path(M.W.__file__), Path(M.W.H.__file__), Path(M.S.__file__),
             Path(P.__file__), Path(P.content.__file__), Path(P.envelope.__file__), prefix]
    pins = {str(p.relative_to(P.ROOT)): P.content.file_hash(p) for p in paths}
    packet = P.content.read_json(prefix, PREFIX_SHA, 65536)
    cases, parts, rig, _, _, sources, historical = M.read_actual_source()
    report = inspect(cases, parts, rig, packet)
    report.update(schema=1, producer_sources=pins, verified_source_files=sources,
                  compact_source_sha256=M.COMPACT_SHA, prefix_source_sha256=PREFIX_SHA,
                  historical_source_snapshot=historical)
    P.require(all(P.content.file_hash(P.ROOT/path) == digest for path, digest in pins.items()), "INSTALL_SOURCE_DRIFT")
    args.out.mkdir(parents=True)
    with (args.out/"inspection.json").open("x") as stream:
        json.dump(report, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"targets": report["targets"], "vertices": report["source_vertex_candidates"],
                      "production_qualified": False}, indent=2))


if __name__ == "__main__":
    main()
