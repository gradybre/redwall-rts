#!/usr/bin/env python3
"""Bounded, read-only geometry diagnosis; writes no profile or qualification flag."""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[4]
PREFIX = Path("godot/data/underground/mole-worker/evidence/contact-qualification")
RAW_SHA = "08de54533d28b1a45a2e171180a0ca68812912f67c9b7294bf26c25eec424cda"
IMAGE_SHA = "adc617642313ac004c050d4877ef0b9f4024bb9c88e3ea92ce9a924471bd5ab9"
ROLES_SHA = "84cf43a446a6e5d42d9bc2c0398caea681dcaa46bdf0491320346d4c6ddf80c6"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("raw_source", type=Path)
    parser.add_argument("world_basis", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    assert not args.output.exists()
    path = ROOT / PREFIX / "prove_state_handoffs.py"
    spec = importlib.util.spec_from_file_location("accepted_handoff_bounds", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    P, S = module.P, module.S
    assert args.raw_source.stat().st_size == 5906853
    assert digest(args.raw_source) == RAW_SHA
    parts = None
    with args.raw_source.open("rb") as stream:
        reader = P.envelope.PaletteSource(stream, RAW_SHA)
        for case in reader.cases():
            if case["id"] == "mole_digger.idle.plain.held_pick.firm_grip_v1":
                parts = case["geometry"]
        assert parts is not None  # The full iterator has also checked hash/footer.
    image = ROOT / PREFIX / "install-program-compile-v3/result/mole-worker.ugactor"
    cases = S.read_image(image, IMAGE_SHA, parts)
    plan_path = ROOT / PREFIX / "install-program-compile-v3/result/plan.json"
    roots = json.loads(plan_path.read_text())["world_root_bounds_u"]
    roles_path = ROOT / PREFIX / "compact-program-compile-v2/result/roles.json"
    assert digest(roles_path) == ROLES_SHA
    roles = json.loads(roles_path.read_text())
    proof_path = ROOT / PREFIX / "compact-program-proof-v1.json"
    proof = json.loads(proof_path.read_text())
    f = proof["inverse_heading_norm"]
    inverse = Fraction(f["numerator"], f["denominator"])
    ready = P.indexed_sequence(cases[0], [8, 8], "exact_shared_ready", False)
    rows = {}
    for name, case in (("idle", cases[0]), ("walk", cases[1]), ("ready", ready)):
        row, offset = [], 0
        for part in parts:
            low, high, errors, padding = module.vertex_corners(case, part, offset, roots, inverse)
            bounds = P.outward_units(low.min(axis=(0, 1)), high.max(axis=(0, 1)))
            # An upper bound beyond the wall is a definite source-point witness,
            # rather than merely a loose AABB whose overlap might be spurious.
            frame, vertex = np.unravel_index(np.argmin(high[:, :, 2]), high[:, :, 2].shape)
            row.append({"kind": part["kind"], "bounds_u": bounds,
                        "native_padding_q24": [int(x) for x in padding],
                        "forward_vertex": {"frame": int(frame), "vertex": int(vertex),
                            "low_q24": [int(x) for x in low[frame, vertex]],
                            "high_q24": [int(x) for x in high[frame, vertex]],
                            "beyond_768_face_even_at_upper_bound": int(high[frame, vertex, 2]) < -768 * (P.SCALE // 1024)},
                        "residual_m": errors})
            offset += max(1, part["binds"])
        rows[name] = row
    def union(names, part):
        boxes = [rows[name][part]["bounds_u"] for name in names]
        return [min(box[a] for box in boxes) for a in range(3)] + [max(box[a] for box in boxes) for a in range(3, 6)]
    unions = {name: [union(selected, part) for part in range(2)] for name, selected in
              (("walk_and_every_walk_to_ready_convex_fade", ("walk", "ready")),
               ("idle_walk_and_all_ground_fades", ("idle", "walk", "ready")))}
    # Reproduce the accepted source-local hull before any all-heading expansion.
    assert unions["idle_walk_and_all_ground_fades"] == [row["source_full_u"] for row in roles["carry"]]
    cardinal_path = ROOT / PREFIX / "prove_cardinal_profiles.py"
    spec = importlib.util.spec_from_file_location("accepted_cardinal_bounds", cardinal_path)
    cardinal = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cardinal)
    with args.world_basis.open("rb") as stream:
        basis = cardinal.CardinalBasis(stream,
            "de8c3b04fde4bec30b0b85bf2bf82e01604e9c17cfcb3fdf4029af0f4d43ebf9",
            "e68ec74b02bb227a065d9881ca2c12fe3b1ef122f032e7bb1324213d3031813f")
    topology_path = ROOT / PREFIX / "topology-v5/topology.json"
    topology = P.read_topology(topology_path,
        "da623e5c7c3c5a6aff5c466b143425422f3aa2253497527c84f713738f997b42",
        "004ea5955ba8877ec3998be179945eb846ed4b8f88c82555dba2d07be4947d0a", parts)
    complete = module.case_union([cases[1], ready], (0, 1))
    cache = cardinal.endpoint_cache(complete, parts, roots, basis)
    full = [P.outward_units(r["low"].min(axis=(0, 1)), r["high"].max(axis=(0, 1))) for r in cache]
    floors = []
    for r, triangles in zip(cache, topology):
        clipped = P.clipped_triangle_floor(np.stack([r["low"].min(axis=0)] * 2),
                                          np.stack([r["high"].max(axis=0)] * 2), triangles[0])
        floors.append(None if clipped is None else P.outward_units(np.array(clipped[:3]), np.array(clipped[3:])))
    assert floors[1] is None
    stance = cardinal.C.foot_projection(parts[0], topology[0], cache[0]["low"], cache[0]["high"], floors[0])
    body_rows = [[full[0][0], 0, full[0][2], *full[0][3:]], floors[0], full[1]]
    local_roles = {"BODY_HELD_LOAD": body_rows, "TURN_RECOVERY": body_rows,
                   "STANCE_SUPPORT": [stance["support_u"]]}
    oriented = {str(yaw): {role: [cardinal.orient_box(box, index) for box in boxes]
                           for role, boxes in local_roles.items()}
                for index, yaw in enumerate(cardinal.YAWS)}
    support_evidence = {"phase_keys": complete["frames"], "complete_convex_hull": True,
        "native_basis": basis.cardinal_certificate(), "canonical_full_u": full,
        "canonical_floor_u": floors, "foot_support": stance,
        "canonical_roles": local_roles, "cardinal_roles": oriented,
        "canonical_residual": [r["errors"] for r in cache],
        "all_yaw_permission": False, "idle_clip_permission": False,
        "turn_permission": False}
    sources = [path, Path(S.__file__), Path(P.__file__), Path(P.content.__file__),
               Path(P.envelope.__file__), cardinal_path, Path(cardinal.C.__file__),
               image, plan_path, roles_path, proof_path, topology_path]
    result = {"schema": 1, "scope": "source-only wall-clearance diagnosis; no publication or activation",
              "source_reconstruction_repeated": False,
              "source_boundary": "exact accepted raw geometry and Actor image hashes; complete bounded binary readers; existing accepted proof lineage remains separately pinned",
              "raw_geometry": {"path": str(args.raw_source), "sha256": RAW_SHA},
              "sources": {str(p.relative_to(ROOT)): digest(p) for p in sources},
              "root_domain_u": roots, "q24_units_per_u": P.SCALE // 1024,
              "wall_forward_distance_u": 768, "rows": rows, "unions": unions,
              "complete_convex_fade_bound": True,
              "fixed_heading_support": support_evidence, "native_replay": False,
              "certificate_flags_written": 0, "production_qualified": False}
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"bounds": {name: [r["bounds_u"] for r in value] for name, value in rows.items()},
                      "unions": unions, "fixed_heading_roles": local_roles,
                      "production_qualified": False}, indent=2))


if __name__ == "__main__":
    main()
