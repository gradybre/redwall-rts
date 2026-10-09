#!/usr/bin/env python3
"""Prove the tool-free stand/walk/join sources and derive their all-yaw integer profile rows (ADR 1198 step 1).

Source proof: no exact current-mesh vertex below the floor at any key, and at least one
anatomical foot vertex inside the closed [0, 1] u floor cell at both ends of every
rendered interval (affine interpolation keeps it there). The joins additionally keep
every non-grip body triangle separated from the floor stock at S, reusing
`prove_program.prove`. Row geometry reuses the exact derivation of published ground rows
0/1/12 (`compile_state_program.carry_bounds`): the stand+walk convex source hull, the
outward native/world residual for the whole root range, the clipped whole-triangle floor
contact and the complete foot projection, each swept about the root over every native
heading. Nothing here grants a route, World support, profile publication or runtime use.
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np

import author_empty_walk as E
import author_handling as A
import prove_program as PROGRAM
import prove_static_contact as S
import render_candidate as R

SPEC = importlib.util.spec_from_file_location("empty_walk_state_program", A.I.PROOF / "compile_state_program.py")
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)
BASIS_SHA = "de8c3b04fde4bec30b0b85bf2bf82e01604e9c17cfcb3fdf4029af0f4d43ebf9"
BASIS_PRODUCER = "e68ec74b02bb227a065d9881ca2c12fe3b1ef122f032e7bb1324213d3031813f"
ROOT_BOUNDS = [0, -32256, 0, 262144, 16896, 262144]
WOOD = A.I.HERE / "evidence/wood-topology-v1.json"
STATES = {"STAND": 257, "WALK": 451}  # Published rows 0 and 1: IDLE|RECOVERY and IDLE|WALK|ENTRY|REVERSAL|RECOVERY.
MAX_KEYS = 256


def load_case(path: Path, columns: int, loop: int) -> dict:
    require = A.require
    require(path.is_file() and path.stat().st_size <= 4 * MAX_KEYS * 301 + 4096, "EMPTY_WALK_IMAGE_CAPACITY")
    with np.load(path, allow_pickle=False) as image:
        require(set(image.files) == {"matrices", "grounding"}, "EMPTY_WALK_IMAGE_SHAPE")
        matrices, grounding = image["matrices"], image["grounding"]
    require(matrices.dtype == np.float32 and matrices.shape[1:] == (columns, 12) and 2 <= len(matrices) <= MAX_KEYS and
            grounding.dtype == np.float32 and grounding.shape == (len(matrices),) and
            np.all(np.isfinite(matrices)) and np.all(np.isfinite(grounding)), "EMPTY_WALK_KEYS")
    return {"frames": len(matrices), "matrices": matrices, "grounding": grounding, "source_loop_mode": loop,
            "source_duration_s": Fraction(len(matrices) - 1, 30)}


def load_clips(candidate: Path) -> dict:
    return {"stand": load_case(candidate / "stand.npz", 24, 1), "walk": load_case(candidate / "walk.npz", 24, 1),
            "enter_haul": load_case(candidate / "enter_haul.npz", 25, 0),
            "leave_haul": load_case(candidate / "leave_haul.npz", 25, 0)}


def foot_vertices(body: dict, body_tri: np.ndarray) -> list:
    return [np.unique(body_tri[A.RIG.M.anatomical_foot_triangles(body, body_tri, bones)]) for bones in ([3, 4], [7, 8])]


def support_proof(case: dict, body: dict, body_tri: np.ndarray) -> dict:
    """Exact floor and one-foot support on every rendered interval, including a loop's wrap edge."""
    feet = foot_vertices(body, body_tri)
    hulls = [A.P._vertex_hulls(body, case["matrices"][at:at + 1, :24], case["grounding"][at:at + 1])[0]
             for at in range(case["frames"])]
    floors = [PROGRAM.endpoint_floor(case, at, [hulls[at]], body, None, feet) for at in range(case["frames"])]
    failures, rows = [], []
    for first, last in A.P.rendered_intervals(case):
        witnesses = []
        for side in (0, 1):
            a, b = floors[first]["contacts"][side], floors[last]["contacts"][side]
            shared = [at for at in a.keys() & b.keys() if 0 <= a[at] <= 1 and 0 <= b[at] <= 1]
            witnesses.append(min(shared) if shared else None)
        if all(at is None for at in witnesses):
            failures.append([first, last])
        rows.append({"interval": [first, last], "foot_contact_vertices": witnesses})
    bad = [{"frame": at, "vertices": row["bad"]} for at, row in enumerate(floors) if row["bad"]]
    low = np.stack([row[0] for row in hulls])
    high = np.stack([row[1] for row in hulls])
    return {"floor_penetrations": bad, "supported_feet": not failures, "support_failures": failures,
            "rendered_timing": list(A.P.rendered_timing(case)), "intervals": rows,
            "body_union_u": A.P.outward_units(low.min(axis=(0, 1)), high.max(axis=(0, 1))),
            "foot_union_u": [A.P.outward_units(low[:, rows_].min(axis=(0, 1)), high[:, rows_].max(axis=(0, 1)))
                             for rows_ in feet],
            "body_triangles": len(body_tri)}


def join_proof(case: dict, body: dict, wood: dict, body_tri: np.ndarray, wood_tri: np.ndarray, rig: dict) -> dict:
    """Reuse the accepted program prover for stock separation; grip is not claimed by an empty join."""
    result = PROGRAM.prove(case, body, wood, body_tri, wood_tri, rig, [], False)
    result.pop("support_failures")
    result.pop("supported_feet")
    result.pop("continuous_two_hand_contact")
    result.pop("grip_failures")
    return result


def rotated_points(points: np.ndarray, yaw: int) -> np.ndarray:
    """Sampled native heading; sampling is a test witness only, the sweep proof is integer and exact."""
    angle = 2 * np.pi * yaw / 65536
    c, s = np.cos(angle), np.sin(angle)
    return np.stack((c * points[:, 0] + s * points[:, 2], points[:, 1], -s * points[:, 0] + c * points[:, 2]), axis=1)


def ground_roles(enclosure: list) -> tuple:
    """Same role assembly as published rows 0/1/12, with the absent pick's third box omitted."""
    A.require(len(enclosure) == 1 and enclosure[0]["kind"] == "body", "EMPTY_WALK_PART_CENSUS")
    body = enclosure[0]
    full, floor, support = body["full_u"], body["floor_u"], body["support_u"]
    A.require(floor is not None and full[1] < 0 < full[4] and floor[1] < floor[4] == 0 and
              support[4] == 0 and support[1] < 0, "EMPTY_WALK_FLOOR")
    boxes = [[full[0], 0, full[2], *full[3:]], floor]
    A.require(all(support[a] <= floor[a] <= floor[a + 3] <= support[a + 3] for a in range(3)), "EMPTY_WALK_STANCE")
    return {"BODY_HELD_LOAD": boxes, "TURN_RECOVERY": boxes, "STANCE_SUPPORT": [support]}, body


def row(name: str, mode: int, roles: dict) -> dict:
    return {"row": name, "mode": mode, "mode_name": name.split()[-1], "posture": 0, "yaw_kind": "YAW_ALL", "yaw": 0,
            "tool": -1, "tool_variant": -1, "cargo": -1, "cargo_variant": -1, "quantity_milli": [0, 0],
            "families": 0, "states": STATES[name.split()[-1]], "work_kind": -1, "contact_kind": 0,
            "box_count": sum(map(len, roles.values())), "roles": roles}


def derive_rows(clips: dict, body: dict, body_tri: np.ndarray, basis_path: Path) -> dict:
    with basis_path.open("rb") as stream:
        basis = C.H.InverseHeading(stream, BASIS_SHA, BASIS_PRODUCER)
    surfaces = [[body_tri.astype(np.int64)]]
    enclosure = C.carry_bounds([clips["stand"], clips["walk"]], [body], surfaces, ROOT_BOUNDS, basis)
    roles, measured = ground_roles(enclosure)
    # Diagnostic for ADR 1198 step 2: the joins' own all-yaw enclosure, same derivation.
    joins = C.carry_bounds([clips["enter_haul"], clips["leave_haul"]], [body], surfaces, ROOT_BOUNDS, basis)
    join_roles, join_measured = ground_roles(joins)
    inside = all(any(all(outer[a] <= box[a] <= box[a + 3] <= outer[a + 3] for a in range(3)) for outer in roles[name])
                 for name, boxes in join_roles.items() for box in boxes)
    return {"rows": [row("A STAND", 0, roles), row("A' WALK", 1, roles)],
            "ground_enclosure": measured,
            "join_enclosure": {"roles": join_roles, "source_full_u": join_measured["source_full_u"],
                               "source_floor_u": join_measured["source_floor_u"],
                               "support_source_u": join_measured["stance"]["support_u"],
                               "within_row_roles": inside},
            "world_root_bounds_u": ROOT_BOUNDS,
            "world_basis_sha256": basis.digest, "world_basis_norm_squared": C.P.envelope.fraction_record(basis.norm_squared),
            "inverse_heading_norm": C.P.envelope.fraction_record(basis.inverse_norm),
            "derivation": "compile_state_program.carry_bounds over stand+walk keys; rotated_box sweeps about the root"}


def producer_pins() -> dict:
    paths = [Path(__file__), Path(E.__file__), Path(A.__file__), Path(A.I.__file__), Path(PROGRAM.__file__),
             Path(S.__file__), Path(R.__file__), Path(C.__file__), Path(C.H.__file__), Path(C.P.__file__),
             Path(A.RIG.__file__), Path(A.I.SOURCE.__file__), Path(E.G.__file__), Path(E.LIFT.__file__)]
    return {str(path.resolve().relative_to(A.I.ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(set(path.resolve() for path in paths))}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "candidate", "world-basis", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    A.require(not args.out.exists() and not args.out.is_symlink(), "HANDLING_OUTPUT_EXISTS")
    _, body, wood, _, topology, _, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    wood_tri = R.wood_topology(WOOD, wood)
    clips = load_clips(args.candidate)
    proofs = {name: support_proof(case, body, body_tri) for name, case in clips.items()}
    for name in ("enter_haul", "leave_haul"):
        proofs[name]["stock_separation"] = join_proof(clips[name], body, wood, body_tri, wood_tri, topology["rig_binding"])
    rows = derive_rows(clips, body, body_tri, args.world_basis)
    inputs = {"candidate/" + path.name: hashlib.sha256(path.read_bytes()).hexdigest()
              for path in sorted(args.candidate.glob("*")) if path.is_file()}
    report = {"schema": 1, "production_qualified": False, "certificate_bits_written": 0,
              "source_palette_sha256": A.I.PALETTE_SHA, "current_mesh_palette_sha256": A.I.GRIP_SHA,
              "topology_sha256": A.I.TOPOLOGY_SHA, "wood_topology_sha256": A.I.WOOD_TOPOLOGY_SHA,
              "candidate_sha256": inputs, "producer_sha256": producer_pins(),
              "source_proof": proofs, "profile_geometry": rows,
              "scope": "Source-only exact floor/one-foot support on rendered key intervals and stock separation for the joins; "
                       "all-yaw integer boxes in 1/1024 m, root-relative. No native replay, self-clearance, foot-slide, "
                       "route, World support or profile publication."}
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"rows": [{"row": r["row"], "roles": r["roles"]} for r in rows["rows"]],
                      "support": {k: v["supported_feet"] for k, v in proofs.items()},
                      "floor_bad": {k: len(v["floor_penetrations"]) for k, v in proofs.items()}}))


if __name__ == "__main__":
    main()
