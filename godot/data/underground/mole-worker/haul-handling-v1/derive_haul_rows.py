#!/usr/bin/env python3
"""Derive integer haul profile-row geometry from the reviewed haul packet (ADR 1198 step 2).

Three tool-free mole rows are derived from the eight already reviewed and
natively replayed haul clips: CARRY (all yaws), HAUL load and HAUL unload
(exact yaw 0). Every box is the outward integer enclosure of the complete body
and stock meshes over the clip's exact rendered intervals, including the same
palette/native-world residuals and native-table heading terms the published
mole rows use. Nothing is published to the runtime and no certificate bit is
written; step 3 owns the profile format and the curved grip certificate.

Units are 1024 per metre, root-relative, in the source frame (yaw 0 faces -Z,
which is the convention of the existing YAW_EXACT rows and the native table).
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import sys
import types

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import compile_native_program as NATIVE  # noqa: E402
import prove_static_contact as STATIC  # noqa: E402

I = NATIVE.I
ROOT = I.ROOT
_SPEC = importlib.util.spec_from_file_location(
    "haul_rows_cardinal_proof", HERE.parent / "evidence/contact-qualification/prove_cardinal_profiles.py")
N = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(N)
P, STATE = N.P, N.C
H = STATE.H
require = I.require

OUT = HERE / "evidence/haul-rows-v1/rows.json"
ROOTS = list(NATIVE.BOUNDS)
WOOD_TOPOLOGY = HERE / "evidence/wood-topology-v1.json"
WOOD_TOPOLOGY_SHA = "66255515b72899999456ac927a669f46683132fe0f2333940485aeab6b98ba7e"
STATIC_DIR = HERE / "evidence/static-contact-review-v1"
STATIC_CONTACT_SHA = "5f7839659edf811e6a71c72f0e4770d7cc4a4512be3572307b104868f4327f52"
STATION_PACKET_SHA = "ed572f3cc8e31c1e2c32f00df0502445a70fd42cd3dd51d45381fe9b958bd859"
STATIC_POSES_SHA = "996d0b4a0666e57d01c5f3592632e4c1f36c914854aae78a61ed91f8c3750894"
FORWARD_PRODUCER = "df6bb71866a5839815b112f544348b6ca436020bb56d9c46293455f817d5e018"
WORLD_V1_SHA = "de8c3b04fde4bec30b0b85bf2bf82e01604e9c17cfcb3fdf4029af0f4d43ebf9"
WORLD_V1_PRODUCER = "e68ec74b02bb227a065d9881ca2c12fe3b1ef122f032e7bb1324213d3031813f"
ROLE_IDS = {"BODY_HELD_LOAD": 0, "STANCE_SUPPORT": 1, "TURN_RECOVERY": 2, "WORK_APPROACH": 3, "WORK_STROKE": 4}
MODE = {"CARRY": 2, "WORK": 3}
STATES = {"IDLE": 1, "CARRY": 4, "WORK": 8, "ENTRY": 64, "REVERSAL": 128, "RECOVERY": 256}
MAX_BOXES = 12
Q = P.SCALE // 1024


# ---------------------------------------------------------------- native tables

class Table:
    """The four numbers the existing proofs read from a 65,536-row native heading table."""

    def __init__(self, kind: str, digest: str, producer: str, norm_squared: Fraction, inverse_norm: Fraction,
                 cardinals: list):
        require(len(cardinals) == 4 and norm_squared > 0 and inverse_norm > 0, "HAUL_ROWS_BASIS_CENSUS")
        self.canonical = [N.canonical_coefficients(c, s, at) for at, (c, s) in enumerate(cardinals)]
        # Same admission as N.CardinalBasis: another table must be reviewed, not rounded.
        require(all(c == 1 and abs(s) < Fraction(1, 1 << 20) for c, s in self.canonical),
                "HAUL_ROWS_CARDINAL_NEAR_IDENTITY")
        self.kind, self.digest, self.producer = kind, digest, producer
        self.norm_squared, self.inverse_norm = norm_squared, inverse_norm
        self.max_sine = max(abs(s) for _, s in self.canonical)

    def record(self) -> dict:
        f = P.envelope.fraction_record
        return {"format": self.kind, "sha256": self.digest, "producer_sha256": self.producer,
                "norm_squared_max": f(self.norm_squared), "inverse_norm_max": f(self.inverse_norm),
                "cardinal_sine_max": f(self.max_sine)}


def read_v1(path: Path) -> Table:
    """The table bound into the published mole rows (UGYAW001), read by the existing reviewed reader."""
    with path.open("rb") as stream:
        basis = N.CardinalBasis(stream, WORLD_V1_SHA, WORLD_V1_PRODUCER)
    return Table("UGYAW001", WORLD_V1_SHA, WORLD_V1_PRODUCER, basis.norm_squared, basis.inverse_norm,
                 basis._cardinals)


def read_v2(path: Path) -> Table:
    """The Metal table the haul native replay used (UGYAW002); same row arithmetic as the v1 readers."""
    raw = path.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == NATIVE.BASIS_SHA and raw[:8] == b"UGYAW002", "HAUL_ROWS_FORWARD_BASIS")
    version, rows, size = struct.unpack_from("<III", raw, 8)
    require(version == 2 and rows == 65536 and 0 < size <= 1024 and
            len(raw) == 20 + size + rows * 8 + 8 and raw[-8:] == b"UGYEND02", "HAUL_ROWS_FORWARD_FORMAT")
    metadata = json.loads(raw[20:20 + size])
    require(metadata["source"]["sha256"] == FORWARD_PRODUCER and
            metadata.get("orientation") == "0=-Z,+quarter=-X; +Y up", "HAUL_ROWS_FORWARD_PRODUCER")
    values = np.frombuffer(raw, dtype="<f4", count=rows * 2, offset=20 + size).reshape(rows, 2)
    require(np.all(np.isfinite(values)) and np.all(np.abs(values) <= 1), "HAUL_ROWS_FORWARD_COEFFICIENT")
    pairs = {(float(c), float(s)) for c, s in values}
    norm_squared, inverse_norm = Fraction(0), Fraction(0)
    for c, s in pairs:
        c, s = Fraction(c), Fraction(s)
        norm = c * c + s * s
        require(norm > 0, "HAUL_ROWS_FORWARD_SINGULAR")
        norm_squared = max(norm_squared, norm)
        inverse_norm = max(inverse_norm, H.InverseHeading.inverse_row_norm(c, s))
    cardinals = [tuple(Fraction(float(v)) for v in values[yaw]) for yaw in N.YAWS]
    return Table("UGYAW002", NATIVE.BASIS_SHA, FORWARD_PRODUCER, norm_squared, inverse_norm, cardinals)


def worst(tables: list) -> Table:
    """Cover both admitted native tables; each term takes its larger value."""
    result = Table.__new__(Table)
    result.kind, result.digest, result.producer = "both", None, None
    result.norm_squared = max(t.norm_squared for t in tables)
    result.inverse_norm = max(t.inverse_norm for t in tables)
    result.max_sine = max(t.max_sine for t in tables)
    result.canonical = None
    return result


# ---------------------------------------------------------------- geometry

def clip_below(low: np.ndarray, high: np.ndarray, triangles: np.ndarray) -> list | None:
    """Q24 bounds of every whole triangle's portion at or below Y=0 over one rendered interval.

    low/high are (2, vertices, 3) outward endpoint intervals. Same relaxation as
    compile_profiles.clipped_triangle_floor (minima from (min X, min Y), maxima
    from (max X, min Y), admitted corners plus exact plane crossings), with the
    maximum crossing taken as a maximum.
    """
    lo = low[:, triangles].transpose(1, 0, 2, 3).reshape(-1, 6, 3)
    hi = high[:, triangles].transpose(1, 0, 2, 3).reshape(-1, 6, 3)
    require(np.all(lo > -(1 << 29)) and np.all(hi < (1 << 29)), "HAUL_ROWS_CLIP_CAPACITY")
    admitted = lo[:, :, 1] <= 0
    relevant = np.any(admitted, axis=1)
    if not np.any(relevant):
        return None
    lo, hi, admitted = lo[relevant], hi[relevant], admitted[relevant]
    heights = lo[:, :, 1]
    result = [0, int(np.where(admitted, heights, np.iinfo(np.int64).max).min()), 0, 0, 0, 0]
    for axis in (0, 2):
        small = int(np.where(admitted, lo[:, :, axis], np.iinfo(np.int64).max).min())
        large = int(np.where(admitted, hi[:, :, axis], np.iinfo(np.int64).min).max())
        for a in range(6):
            for b in range(6):
                crossing = admitted[:, a] & ~admitted[:, b]
                if not np.any(crossing):
                    continue
                ya, yb = heights[crossing, a], heights[crossing, b]
                span = yb - ya
                small = min(small, int(np.floor_divide(lo[crossing, a, axis] * yb - lo[crossing, b, axis] * ya, span).min()))
                large = max(large, int((-np.floor_divide(-(hi[crossing, a, axis] * yb - hi[crossing, b, axis] * ya), span)).max()))
        result[axis], result[axis + 3] = small, large
    return result


def floor_box(case: dict, low: np.ndarray, high: np.ndarray, triangles: np.ndarray) -> list | None:
    """Union over the clip's exact rendered intervals (including a loop's wrap), widened to integer units."""
    boxes = [clip_below(low[[a, b]], high[[a, b]], triangles) for a, b in P.rendered_intervals(case)]
    boxes = [box for box in boxes if box is not None]
    if not boxes:
        return None
    box = P.outward_units(np.array([min(b[a] for b in boxes) for a in range(3)], dtype=np.int64),
                          np.array([max(b[a + 3] for b in boxes) for a in range(3)], dtype=np.int64))
    require(box[4] == 0 and box[1] < 0, "HAUL_ROWS_FLOOR_PLANE")
    return box


def part_rows(case: dict, parts: list, triangles: list, corners: list) -> list:
    """Full, floor-portion and above-plane boxes of each part over one clip."""
    rows = []
    for part, tris, (low, high, padding) in zip(parts, triangles, corners):
        full = P.outward_units(low.min(axis=(0, 1)), high.max(axis=(0, 1)))
        floor = floor_box(case, low, high, tris)
        above = None if full[4] <= 0 else [full[0], max(0, full[1]), full[2], *full[3:]]
        rows.append({"name": part["name"], "full_u": full, "floor_u": floor, "above_u": above,
                     "padding_q24": [int(v) for v in padding]})
    return rows


def stance(parts: list, triangles: list, corners: list, floor: list) -> dict:
    """The existing full foot/toe triangle projection onto Y=0 (compile_state_program.foot_projection)."""
    low, high, _ = corners[0]
    feet = STATE.foot_projection(parts[0], [triangles[0]], low, high, floor)
    return {"support_u": feet["support_u"], "source_foot_bounds_u": feet["source_foot_bounds_u"],
            "foot_triangles": feet["triangles"]}


def exact_corners(case: dict, parts: list, table: Table) -> list:
    """Yaw-exact rows: N.endpoint_cache (palette, native world and cardinal-heading residuals)."""
    cache = N.endpoint_cache(case, parts, ROOTS, table)
    return [(row["low"], row["high"], row["padding"]) for row in cache]


def all_yaw_corners(case: dict, parts: list, table: Table) -> list:
    """All-yaw rows: the published rows' H.vertex_corners (residual mapped through the inverse heading norm)."""
    result, offset = [], 0
    for part in parts:
        low, high, _, padding = H.vertex_corners(case, part, offset, ROOTS, table.inverse_norm)
        result.append((low, high, padding))
        offset += max(1, part["binds"])
    require(offset == case["matrices"].shape[1], "HAUL_ROWS_UNCONSUMED_PALETTE")
    return result


def phase_record(name: str, case: dict, parts: list, triangles: list, corners: list) -> dict:
    rows = part_rows(case, parts, triangles, corners)
    require(rows[0]["floor_u"] is not None and rows[0]["above_u"] is not None, "HAUL_ROWS_BODY_PLANE")
    return {"clip": name, "frames": case["frames"], "rendered_intervals": len(P.rendered_intervals(case)),
            "loop": case["source_loop_mode"], "parts": rows,
            "stance": stance(parts, triangles, corners, rows[0]["floor_u"])}


# ---------------------------------------------------------------- rows

def boxes_of(roles: dict) -> list:
    result = [{"role": role, "role_id": ROLE_IDS[role], "bounds_u": box}
              for role in ROLE_IDS for box in roles.get(role, []) if box is not None]
    require(3 <= len(result) <= MAX_BOXES and all(len(b["bounds_u"]) == 6 and
            all(b["bounds_u"][a] < b["bounds_u"][a + 3] for a in range(3)) for b in result), "HAUL_ROWS_BOX_CENSUS")
    return result


def body_pair(phase: dict) -> list:
    body = phase["parts"][0]
    return [body["above_u"], body["floor_u"]]


def stroke(phase: dict) -> list:
    """Every stock primitive portion; partitions_complete refuses an omitted side."""
    stock = phase["parts"][1]
    sides = [stock["above_u"], stock["floor_u"]]
    return STATE.partitions_complete(sides, stock["full_u"])


def support(phases: list) -> list:
    box = STATE.union([p["stance"]["support_u"] for p in phases])
    floors = STATE.union([p["parts"][0]["floor_u"] for p in phases])
    require(box[1] < box[4] == 0 and all(box[a] <= floors[a] <= floors[a + 3] <= box[a + 3] for a in range(3)),
            "HAUL_ROWS_STANCE")
    return box


def work_row(name: str, phases: dict, approach: str, work: str, recovery: str, cargo: dict, approach_stock: bool) -> dict:
    """HAUL rows follow the published dig/install role pattern: productive stock is WORK_STROKE."""
    ready = phases[approach]
    approach_boxes = body_pair(ready)
    if approach_stock:
        approach_boxes = [STATE.union([approach_boxes[0], ready["parts"][1]["full_u"]]), approach_boxes[1]]
    roles = {"BODY_HELD_LOAD": body_pair(phases[work]),
             "STANCE_SUPPORT": [support([phases[n] for n in (approach, work, recovery)])],
             "TURN_RECOVERY": body_pair(phases[recovery]),
             "WORK_APPROACH": approach_boxes,
             "WORK_STROKE": stroke(phases[work])}
    coverage = [{"clip": approach, "part": 0, "role": "WORK_APPROACH"},
                {"clip": work, "part": 0, "role": "BODY_HELD_LOAD"},
                {"clip": work, "part": 1, "role": "WORK_STROKE"},
                {"clip": recovery, "part": 0, "role": "TURN_RECOVERY"}]
    if approach_stock:
        coverage.append({"clip": approach, "part": 1, "role": "WORK_APPROACH"})
    return dict(name=name, mode=MODE["WORK"], mode_name="WORK", yaw_kind=0, yaw_kind_name="YAW_EXACT", yaw=0,
                states=STATES["IDLE"] | STATES["WORK"] | STATES["ENTRY"] | STATES["RECOVERY"],
                posture=0, tool=-1, tool_variant=-1, **cargo, work_kind="HAUL", clips=[approach, work, recovery],
                boxes=boxes_of(roles), coverage=coverage)


def carry_row(phases: dict, table: Table) -> dict:
    """Loaded turning in place is certified by the radial sweep of every extent, as rows 0 and 1 are."""
    names = ("hold", "enter", "carry", "exit")
    canonical = {
        "body_above_u": STATE.union([phases[n]["parts"][0]["above_u"] for n in names]),
        "body_floor_u": STATE.union([phases[n]["parts"][0]["floor_u"] for n in names]),
        "stock_u": STATE.union([phases[n]["parts"][1]["full_u"] for n in names]),
        "support_u": support([phases[n] for n in names])}
    require(all(phases[n]["parts"][1]["floor_u"] is None for n in names), "HAUL_ROWS_CARRIED_STOCK_FLOOR")
    swept = {key: STATE.rotated_box(box, table.norm_squared) for key, box in canonical.items()}
    held = [swept["body_above_u"], swept["body_floor_u"], swept["stock_u"]]
    roles = {"BODY_HELD_LOAD": held, "STANCE_SUPPORT": [swept["support_u"]], "TURN_RECOVERY": held}
    coverage = [{"clip": n, "part": part, "role": role} for n in names for part in (0, 1)
                for role in ("BODY_HELD_LOAD", "TURN_RECOVERY")]
    return dict(name="haul_carry_wood_1000", mode=MODE["CARRY"], mode_name="CARRY", yaw_kind=1,
                yaw_kind_name="YAW_ALL", yaw=0,
                states=STATES["IDLE"] | STATES["CARRY"] | STATES["ENTRY"] | STATES["REVERSAL"] | STATES["RECOVERY"],
                posture=0, tool=-1, tool_variant=-1, cargo="wood", quantity_milli=[1000, 1000], work_kind=None,
                clips=list(names), canonical_u=canonical, boxes=boxes_of(roles), coverage=coverage)


# ---------------------------------------------------------------- station and contacts

def ratio(value: Fraction) -> list:
    return [value.numerator, value.denominator]


def cell(point: list) -> list:
    """Smallest integer box containing an exact rational point (degenerate on an integer coordinate)."""
    return [v.numerator // v.denominator for v in point] + [-(-v.numerator // v.denominator) for v in point]


def station(cases: dict, body: dict, wood: dict, body_tri: np.ndarray, wood_tri: np.ndarray) -> dict:
    """R is the source root; S is the stock rest anchor on the floor; both grips are re-derived exactly."""
    lift, place, approach = cases["lift"], cases["place"], cases["approach"]
    with np.load(STATIC_DIR / "candidate/poses.npz", allow_pickle=False) as static:
        require(static["matrices"][1].tobytes() == lift["matrices"][0].tobytes() and
                static["grounding"][1] == lift["grounding"][0], "HAUL_ROWS_STATIC_POSE")
    require(place["matrices"][-1].tobytes() == lift["matrices"][0].tobytes() and
            np.all(approach["matrices"][:, 24] == lift["matrices"][0, 24]) and
            np.all(cases["recovery"]["matrices"][:, 24] == lift["matrices"][0, 24]), "HAUL_ROWS_STATION_FIXTURE")
    stock = [Fraction(float(v)) for v in lift["matrices"][0, 24, 9:]]
    anchor = [stock[0] * 1024, Fraction(0), stock[2] * 1024]
    packet = json.loads((STATIC_DIR / "station-contact-packet.json").read_text())
    require(all(v.denominator == 1 for v in anchor) and [int(v) for v in anchor] == packet["S_u"] and
            packet["R_u"] == [0, 0, 0], "HAUL_ROWS_STATION_OFFSET")
    r_minus_s = [-int(v) for v in anchor]
    pose = {"matrices": lift["matrices"][0:1], "grounding": lift["grounding"][0:1]}
    reviewed = json.loads((STATIC_DIR / "static-contact.json").read_text())["static_source"]["hand_contact_witnesses"]
    contacts = []
    for row in reviewed:
        first = [STATIC.exact_vertex(pose, body, int(v), 0) for v in body_tri[row["body_triangle"]]]
        second = [STATIC.exact_vertex(pose, wood, int(v), 24) for v in wood_tri[row["wood_triangle"]]]
        witness = STATIC.edge_witness(first, second)
        require(witness is not None and all(witness[k] == row[k] for k in ("edge", "share", "point_u")) and
                body_tri[row["body_triangle"]].tolist() == row["body_vertices"], "HAUL_ROWS_GRIP_WITNESS")
        point = [Fraction(n, d) for n, d in witness["point_u"]]
        c_s = [p - a for p, a in zip(point, anchor)]
        c_r = point
        contacts.append({"hand_bone": row["hand"], "body_triangle": row["body_triangle"],
                         "wood_triangle": row["wood_triangle"], "body_edge": witness["edge"],
                         "edge_share": witness["share"], "C_minus_S_u": [ratio(v) for v in c_s],
                         "C_minus_S_cell_u": cell(c_s), "C_minus_R_u": [ratio(v) for v in c_r],
                         "C_minus_R_cell_u": cell(c_r),
                         "C_minus_S_approx_u": [round(float(v), 6) for v in c_s]})
    return {"R_u": [0, 0, 0], "S_u": [int(v) for v in anchor], "R_minus_S_u": r_minus_s,
            "S_definition": "stock rest transform origin projected to the floor plane Y=0 (fixed through approach, lift frame 0, place end and recovery)",
            "contact_poses": {"load": "lift frame 0 (= static review pose)", "unload": "place final frame (byte-identical)"},
            "grip_contacts": contacts}


# ---------------------------------------------------------------- pins and assembly

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def producer_pins() -> dict:
    """Transitive Python authoring/proof helpers actually imported, like compile_profile_publication."""
    pending, seen, paths = [sys.modules[__name__], N, NATIVE, STATIC], set(), set()
    while pending:
        module = pending.pop()
        if id(module) in seen or not getattr(module, "__file__", None):
            continue
        seen.add(id(module))
        require(len(seen) <= 160, "HAUL_ROWS_PRODUCER_CAPACITY")
        path = Path(module.__file__).resolve()
        if path.is_relative_to(ROOT) and path.suffix == ".py":
            paths.add(path)
            pending.extend(v for v in vars(module).values() if isinstance(v, types.ModuleType))
    return {str(p.relative_to(ROOT)): sha(p) for p in sorted(paths)}


def input_pins() -> dict:
    paths = {NATIVE.clip_path(name) for name in NATIVE.CLIPS}
    paths |= {WOOD_TOPOLOGY, STATIC_DIR / "static-contact.json", STATIC_DIR / "station-contact-packet.json",
              STATIC_DIR / "candidate/poses.npz", NATIVE.BASIS, I.PROOF / "topology-v5/topology.json",
              NATIVE.WRAPPER, HERE / "evidence/native-program-v7/compiled/plan.json"}
    result = {str(p.relative_to(ROOT)): sha(p) for p in sorted(paths)}
    expected = {WOOD_TOPOLOGY: WOOD_TOPOLOGY_SHA, STATIC_DIR / "static-contact.json": STATIC_CONTACT_SHA,
                STATIC_DIR / "station-contact-packet.json": STATION_PACKET_SHA,
                STATIC_DIR / "candidate/poses.npz": STATIC_POSES_SHA, NATIVE.BASIS: NATIVE.BASIS_SHA,
                I.PROOF / "topology-v5/topology.json": I.TOPOLOGY_SHA, NATIVE.WRAPPER: NATIVE.WRAPPER_SHA}
    require(all(result[str(p.relative_to(ROOT))] == d for p, d in expected.items()), "HAUL_ROWS_INPUT_PIN")
    return result


def load_sources(palette: Path, grip: Path) -> tuple:
    """Reviewed-output pins first (NATIVE.reviewed_inputs refuses any drift), then the exact meshes and clips."""
    NATIVE.reviewed_inputs()
    _, body, wood, _, topology, _, _, _ = I.current_inputs(palette, grip)
    wood = NATIVE.wrapped_stock(wood)
    cases = dict(zip(NATIVE.CLIPS, NATIVE.cases_from_review(body, wood)))
    require(json.loads((HERE / "evidence/native-program-v7/compiled/plan.json").read_text())["world_root_bounds_u"]
            == ROOTS, "HAUL_ROWS_ROOTS")
    require(cases["recovery"]["matrices"].tobytes() == cases["approach"]["matrices"][::-1].tobytes() and
            cases["place"]["matrices"].tobytes() == cases["lift"]["matrices"][::-1].tobytes() and
            cases["exit"]["matrices"].tobytes() == cases["enter"]["matrices"][::-1].tobytes(), "HAUL_ROWS_EXACT_REVERSAL")
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int64).reshape(-1, 3)
    wood_json = I.CONTENT.read_json(WOOD_TOPOLOGY, WOOD_TOPOLOGY_SHA, 8 * 1024 * 1024)
    wood_tri = np.asarray(wood_json["indices"], dtype=np.int64).reshape(-1, 3)
    require(body_tri.shape == (10209, 3) and wood_tri.shape == (768, 3), "HAUL_ROWS_TRIANGLE_CENSUS")
    return body, wood, cases, body_tri, wood_tri


def derive(palette: Path, grip: Path, world_v1: Path) -> dict:
    producers, inputs = producer_pins(), input_pins()
    body, wood, cases, body_tri, wood_tri = load_sources(palette, grip)
    tables = [read_v1(world_v1), read_v2(NATIVE.BASIS)]
    table = worst(tables)
    parts, triangles = [body, wood], [body_tri, wood_tri]
    exact = {n: phase_record(n, cases[n], parts, triangles, exact_corners(cases[n], parts, table))
             for n in ("approach", "lift", "place", "recovery", "hold")}
    swept = {n: phase_record(n, cases[n], parts, triangles, all_yaw_corners(cases[n], parts, table))
             for n in ("hold", "enter", "carry", "exit")}
    rows = [carry_row(swept, table),
            work_row("haul_load_wood_1000", exact, "approach", "lift", "recovery",
                     {"cargo": None, "quantity_milli": [0, 0]}, False),
            work_row("haul_unload_wood_1000", exact, "hold", "place", "recovery",
                     {"cargo": "wood", "quantity_milli": [1000, 1000]}, True)]
    require(producer_pins() == producers and input_pins() == inputs, "HAUL_ROWS_SOURCE_DRIFT")
    return {"schema": 1, "adr": "1198 step 2", "units": "1/1024 m, root-relative source frame; yaw 0 faces -Z; +Y up",
            "production_qualified": False, "certificate_bits_written": 0,
            "scope": "Integer geometry for three tool-free rows; profile format, haul-grip certificate, catalog ids and publication are later steps.",
            "external_inputs_sha256": {"palette": I.PALETTE_SHA, "grip_palette": I.GRIP_SHA, "world_basis_v1": WORLD_V1_SHA},
            "input_sha256": inputs, "producer_sha256": producers,
            "mesh": {"body_sha256": I.BODY, "wood_sha256": I.LOG, "body_triangles": 10209, "wood_triangles": 768,
                     "wood_array_mesh_sha256": I.CONTENT.geometry_fingerprint(wood).hex()},
            "world_root_bounds_u": ROOTS, "native_tables": [t.record() for t in tables],
            "phases": {"yaw_exact": exact, "all_yaw": swept},
            "station": station(cases, body, wood, body_tri, wood_tri), "rows": rows}


def encode(report: dict) -> bytes:
    return (json.dumps(report, indent=1, sort_keys=True) + "\n").encode()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    parser.add_argument("--world-basis", type=Path, required=True, help="world-yaw-v1.ugyaw (UGYAW001)")
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()
    require(not args.out.exists() and not args.out.is_symlink(), "HAUL_ROWS_OUTPUT_EXISTS")
    raw = encode(derive(args.palette, args.grip_palette, args.world_basis))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("xb") as stream:
        stream.write(raw)
    print(json.dumps({"out": str(args.out), "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}))


if __name__ == "__main__":
    main()
