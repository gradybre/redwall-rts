#!/usr/bin/env python3
"""Derive integer stone haul profile-row geometry from the approved, natively replayed stone clips (ADR 1206).

Exactly derive_haul_rows.py's derivation (ADR 1198 step 2), including its corrected clipped-triangle floor
maximum (`clip_below`), the palette/native-world residuals and both native heading tables, applied to the ten
v9 stone clips: CARRY stone (all yaws), HAUL load stone and HAUL unload stone (exact yaw 0). The station and both
hand contacts are re-derived exactly from the approved grip (stone-contact-v1). Nothing is published here.
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import sys
import types

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import compile_native_program_v9 as C9  # noqa: E402
import derive_haul_rows as D  # noqa: E402

I, ROOT, require = D.I, D.ROOT, D.require
OUT = HERE / "evidence/stone-rows-v1/rows.json"
STATIC_DIR = HERE / "evidence/stone-contact-v1"
NATIVE_PLAN = HERE / "evidence/native-program-v9/compiled/plan.json"
STONE_TRIANGLES = 108


def load_sources(palette: Path, grip: Path) -> tuple:
    C9.reviewed_inputs()
    _, body, _, _, topology, _, _, _ = I.current_inputs(palette, grip)
    stone = C9.stone_part()
    cases = dict(zip(C9.CLIPS, C9.cases_from_sources(body, stone)))
    require(json.loads(NATIVE_PLAN.read_text())["world_root_bounds_u"] == D.ROOTS, "STONE_ROWS_ROOTS")
    require(cases["recovery"]["matrices"].tobytes() == cases["approach"]["matrices"][::-1].tobytes() and
            cases["place"]["matrices"].tobytes() == cases["lift"]["matrices"][::-1].tobytes() and
            cases["exit"]["matrices"].tobytes() == cases["enter"]["matrices"][::-1].tobytes(), "STONE_ROWS_EXACT_REVERSAL")
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int64).reshape(-1, 3)
    stone_tri = np.asarray(json.loads(C9.STONE.read_text())["indices"], dtype=np.int64).reshape(-1, 3)
    require(body_tri.shape == (10209, 3) and stone_tri.shape == (STONE_TRIANGLES, 3), "STONE_ROWS_TRIANGLE_CENSUS")
    return body, stone, cases, body_tri, stone_tri


def station(cases: dict, body: dict, stone: dict, body_tri: np.ndarray, stone_tri: np.ndarray) -> dict:
    """R is the source root; S is the stone rest origin projected to the floor; both grips re-derived exactly."""
    lift, place, approach = cases["lift"], cases["place"], cases["approach"]
    with np.load(STATIC_DIR / "poses.npz", allow_pickle=False) as static:
        require(static["matrices"][1].tobytes() == lift["matrices"][0].tobytes() and
                static["grounding"][1] == lift["grounding"][0], "STONE_ROWS_STATIC_POSE")
    require(place["matrices"][-1].tobytes() == lift["matrices"][0].tobytes() and
            np.all(approach["matrices"][:, 24] == lift["matrices"][0, 24]) and
            np.all(cases["recovery"]["matrices"][:, 24] == lift["matrices"][0, 24]), "STONE_ROWS_STATION_FIXTURE")
    origin = [Fraction(float(v)) for v in lift["matrices"][0, 24, 9:]]
    anchor = [origin[0] * 1024, Fraction(0), origin[2] * 1024]
    require(all(v.denominator == 1 for v in anchor) and [int(v) for v in anchor] == [0, 0, -576], "STONE_ROWS_STATION")
    pose = {"matrices": lift["matrices"][0:1], "grounding": lift["grounding"][0:1]}
    reviewed = json.loads((STATIC_DIR / "static-contact.json").read_text())["static_source"]["hand_contact_witnesses"]
    contacts = []
    for row in reviewed:
        first = [D.STATIC.exact_vertex(pose, body, int(v), 0) for v in body_tri[row["body_triangle"]]]
        second = [D.STATIC.exact_vertex(pose, stone, int(v), 24) for v in stone_tri[row["wood_triangle"]]]
        witness = D.STATIC.edge_witness(first, second)
        require(witness is not None and all(witness[k] == row[k] for k in ("edge", "share", "point_u")) and
                body_tri[row["body_triangle"]].tolist() == row["body_vertices"], "STONE_ROWS_GRIP_WITNESS")
        point = [Fraction(n, d) for n, d in witness["point_u"]]
        c_s = [p - a for p, a in zip(point, anchor)]
        contacts.append({"hand_bone": row["hand"], "body_triangle": row["body_triangle"],
                         "stone_triangle": row["wood_triangle"], "body_edge": witness["edge"],
                         "edge_share": witness["share"], "C_minus_S_u": [D.ratio(v) for v in c_s],
                         "C_minus_S_cell_u": D.cell(c_s), "C_minus_R_u": [D.ratio(v) for v in point],
                         "C_minus_R_cell_u": D.cell(point), "C_minus_S_approx_u": [round(float(v), 6) for v in c_s]})
    return {"R_u": [0, 0, 0], "S_u": [int(v) for v in anchor], "R_minus_S_u": [-int(v) for v in anchor],
            "S_definition": "stone rest origin projected to the floor plane Y=0 (fixed through approach, lift frame 0, place end and recovery)",
            "contact_poses": {"load": "lift frame 0 (= approved static grip v1)", "unload": "place final frame (byte-identical)"},
            "grip_contacts": contacts}


def producer_pins() -> dict:
    pending, seen, paths = [sys.modules[__name__], D, C9], set(), set()
    while pending:
        module = pending.pop()
        if id(module) in seen or not getattr(module, "__file__", None):
            continue
        seen.add(id(module))
        require(len(seen) <= 200, "STONE_ROWS_PRODUCER_CAPACITY")
        path = Path(module.__file__).resolve()
        if path.is_relative_to(ROOT) and path.suffix == ".py":
            paths.add(path)
            pending.extend(v for v in vars(module).values() if isinstance(v, types.ModuleType))
    return {str(p.relative_to(ROOT)): D.sha(p) for p in sorted(paths)}


def input_pins() -> dict:
    paths = {C9.clip_path(name) for name in C9.CLIPS}
    paths |= {C9.STONE, C9.BITS, STATIC_DIR / "static-contact.json", STATIC_DIR / "static-contact-star.json",
              STATIC_DIR / "poses.npz", D.NATIVE.BASIS, I.PROOF / "topology-v5/topology.json", NATIVE_PLAN,
              HERE / "evidence/native-program-v9/compiled/stone-handling.ugactor"}
    return {str(p.relative_to(ROOT)): D.sha(p) for p in sorted(paths)}


def stone_rows(swept: dict, exact: dict, table) -> list:
    carry = D.carry_row(swept, table)
    carry.update(name="haul_carry_stone_1000", cargo="stone")
    load = D.work_row("haul_load_stone_1000", exact, "approach", "lift", "recovery",
                      {"cargo": None, "quantity_milli": [0, 0]}, False)
    unload = D.work_row("haul_unload_stone_1000", exact, "hold", "place", "recovery",
                        {"cargo": "stone", "quantity_milli": [1000, 1000]}, True)
    return [carry, load, unload]


def derive(palette: Path, grip: Path, world_v1: Path) -> dict:
    producers, inputs = producer_pins(), input_pins()
    body, stone, cases, body_tri, stone_tri = load_sources(palette, grip)
    tables = [D.read_v1(world_v1), D.read_v2(D.NATIVE.BASIS)]
    table = D.worst(tables)
    parts, triangles = [body, stone], [body_tri, stone_tri]
    exact = {n: D.phase_record(n, cases[n], parts, triangles, D.exact_corners(cases[n], parts, table))
             for n in ("approach", "lift", "place", "recovery", "hold")}
    swept = {n: D.phase_record(n, cases[n], parts, triangles, D.all_yaw_corners(cases[n], parts, table))
             for n in ("hold", "enter", "carry", "exit")}
    rows = stone_rows(swept, exact, table)
    require(producer_pins() == producers and input_pins() == inputs, "STONE_ROWS_SOURCE_DRIFT")
    return {"schema": 1, "adr": "1206", "units": "1/1024 m, root-relative source frame; yaw 0 faces -Z; +Y up",
            "production_qualified": False, "certificate_bits_written": 0,
            "scope": "Integer geometry for three tool-free stone rows; publication and the grip certificate are later steps.",
            "external_inputs_sha256": {"palette": I.PALETTE_SHA, "grip_palette": I.GRIP_SHA, "world_basis_v1": D.WORLD_V1_SHA},
            "input_sha256": inputs, "producer_sha256": producers,
            "mesh": {"body_sha256": I.BODY, "stone_bits_sha256": C9.BITS_SHA, "body_triangles": 10209,
                     "stone_triangles": STONE_TRIANGLES, "stone_array_mesh_sha256": I.CONTENT.geometry_fingerprint(stone).hex()},
            "world_root_bounds_u": D.ROOTS, "native_tables": [t.record() for t in tables],
            "phases": {"yaw_exact": exact, "all_yaw": swept},
            "station": station(cases, body, stone, body_tri, stone_tri), "rows": rows}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    parser.add_argument("--world-basis", type=Path, required=True, help="world-yaw-v1.ugyaw (UGYAW001)")
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()
    require(not args.out.exists() and not args.out.is_symlink(), "STONE_ROWS_OUTPUT_EXISTS")
    raw = D.encode(derive(args.palette, args.grip_palette, args.world_basis))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("xb") as stream:
        stream.write(raw)
    print(json.dumps({"out": str(args.out), "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}))


if __name__ == "__main__":
    main()
