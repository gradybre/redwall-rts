#!/usr/bin/env python3
"""Integer profile rows for the claw/paw source (ADR 1217 step 4, content 7). Derived, never chosen.

The accepted cardinal derivation (`compile_profile_publication.compile_work`, `compile_state_program.work_roles`)
is applied to the approved claw/paw clips, with one change forced by the source: there is no tool part. The open-
paw body is enclosed once per clip (complete outward Q24 vertex hulls, local and native World residual, and the
pinned basis's four exact cardinal deviations: `prove_cardinal_profiles.common_padding`), then partitioned by the
real skin weights into the **paws** (every triangle with hand weight) and the **rest of the body**. The paws play
the part the pick played: they alone may make the stroke.

| Row | Clips | Roles (canonical yaw 0, then the exact quarter turns) |
|---|---|---|
| dig, 4 yaws (BRACE/CUT/FINISH) | dig entry/stroke/recovery, ready = stand key 8 | BODY_HELD_LOAD = the body above and on the floor; WORK_STROKE = the paws above and below the face; TURN_RECOVERY = entry (body and paws) and its floor; WORK_APPROACH = ready and its floor; STANCE_SUPPORT = the union of the foot projections; CONTACT_POINT/PATCH from the face crossing |
| seat tap, 4 yaws (INSTALL) | tap entry/work/recovery | as the accepted INSTALL rows: the body split at the contact plane y = 128; WORK_STROKE = the paws below and above it |
| handling, yaw 0 (ASSEMBLY) | seat entry/work/recovery | as accepted row 29 without its tool box |

**Contacts.** For each heading, the right and left paws' contact vertices (the approved records) cross the plane
downward on one rendered edge each (`prove_cardinal_profiles.contact_patch`, exact rational skin equation, the
basis's canonical coefficients). CONTACT_POINT is the right paw's anchor; CONTACT_PATCH is the union of both paws'
patches, which stays planar.

    $PY .../derive_claw_rows.py <out.json> --world-basis <world-yaw-v1.ugyaw> [--palette ...] [--grip-palette ...]
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np

import native_claw as NC
import prove_claw_stroke as ONE

SRC = ONE.SRC
SPEC = importlib.util.spec_from_file_location("claw_cardinal", SRC.I.PROOF / "prove_cardinal_profiles.py")
N = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(N)
P, C = N.P, N.C
BASIS_SHA = "de8c3b04fde4bec30b0b85bf2bf82e01604e9c17cfcb3fdf4029af0f4d43ebf9"
BASIS_PRODUCER = "e68ec74b02bb227a065d9881ca2c12fe3b1ef122f032e7bb1324213d3031813f"
HANDS = (15, 19)
PROGRAMS = {"dig": ("dig_entry", "dig_stroke", "dig_recovery", 0, 4),
            "tap": ("tap_entry", "tap_work", "tap_recovery", 128, 4),
            "seat": ("seat_entry", "seat_work", "seat_recovery", None, 1)}
STAND_DIG = ONE.W.SRC.HERE.parent / "stand-walk-v2/evidence/stand-walk-v2/proof.json"
PAW = SRC.HERE / "evidence/paw-seat-v1/candidate-a/candidate.json"


def require(value: bool, code: str) -> None:
    """Every refusal names its failed derivation fact."""
    P.require(value, "CLAW_ROWS_" + code)


def endpoint(case: dict, body: dict, roots: list, basis) -> dict:
    """Outward per-key vertex enclosures with the cardinal residual (`common_padding`)."""
    raw = P._vertex_hulls(body, case["matrices"], case["grounding"])
    padding, errors = N.common_padding(body, case["matrices"], case["grounding"], roots, raw, basis.max_sine)
    low = np.empty((case["frames"], len(body["geometry"][0]["points"]), 3), dtype=np.int64)
    high = np.empty_like(low)
    for frame in range(case["frames"]):
        a, b = P._vertex_hulls(body, case["matrices"][frame:frame + 1], case["grounding"][frame:frame + 1])[0]
        low[frame], high[frame] = a - padding, b + padding
    return {"low": low, "high": high, "padding": padding, "errors": errors}


def rows_of(case: dict, cache: dict, triangles: np.ndarray, plane: int = 0) -> dict:
    """Complete bounds of one triangle set, and its clipped parts below and above an exact plane."""
    vertices = np.unique(triangles)
    full = P.outward_units(cache["low"][:, vertices].min(axis=(0, 1)), cache["high"][:, vertices].max(axis=(0, 1)))
    below = N.clipped_portion(case, cache, triangles, 1, plane)
    above = N.clipped_portion(case, cache, triangles, 1, plane, True)
    return {"full": full, "below": below, "above": above}


def masks(body: dict, triangles: np.ndarray) -> np.ndarray:
    """Paw triangles: any vertex with hand weight."""
    geometry = body["geometry"][0]
    hand = np.any(np.isin(geometry["ids"], HANDS) & (geometry["weights"] > 0), axis=1)
    return np.any(hand[triangles], axis=1)


def exact_point(body: dict, case: dict, frame: int, vertex: int, canonical: tuple) -> list:
    """The exact rational skin equation of one vertex (metres), in the canonical frame of one heading."""
    x, y, z = ONE.exact_point({"body": body}, case, frame, vertex)
    c, s = canonical
    return [c * x + s * z, y, -s * x + c * z]


def contact(body: dict, case: dict, cache: dict, vertex: int, canonical: tuple, plane: int) -> dict:
    """The vertex's first downward crossing of the plane, with the complete residual patch."""
    errors = [Fraction(int(v), P.SCALE) for v in cache["padding"]]
    for first, last in P.rendered_intervals(case):
        a, b = exact_point(body, case, first, vertex, canonical), exact_point(body, case, last, vertex, canonical)
        if a[1] - errors[1] > Fraction(plane, 1024) and b[1] + errors[1] < Fraction(plane, 1024):
            return N.contact_patch(a, b, errors, 1, plane)
    raise ValueError("CLAW_ROWS_CONTACT_MISSING")


def stance(body: dict, triangles: np.ndarray, rows: list) -> list:
    """The union of the accepted foot projections over the clips (`foot_projection`)."""
    supports = []
    for cache, floor in rows:
        supports.append(C.foot_projection(body, [triangles], cache["low"], cache["high"], floor)["support_u"])
    return C.union(supports)


def dig_roles(parts: dict, ready: dict, support: list, tip: dict) -> dict:
    """`work_roles` with the paws in place of the pick."""
    work, entry = parts["work"], parts["entry"]
    body = C.body_boxes({"full_bounds_u": work["rest"]["full"], "floor_intersection_u": work["rest"]["below"]})
    floor = C.union([work["rest"]["below"], entry["rest"]["below"]])
    require(all(support[a] <= floor[a] <= floor[a + 3] <= support[a + 3] for a in range(3)), "STANCE")
    require(entry["paw"]["below"] is None and ready["paw"]["below"] is None, "RECOVERY_PAW_FLOOR")
    lift = lambda rows: [rows["full"][0], 0, rows["full"][2], *rows["full"][3:]]
    return {"BODY_HELD_LOAD": body, "STANCE_SUPPORT": [support],
            "TURN_RECOVERY": [C.union([lift(entry["rest"]), entry["paw"]["full"]]), entry["rest"]["below"]],
            "WORK_APPROACH": [C.union([lift(ready["rest"]), ready["paw"]["full"]]), ready["rest"]["below"]],
            "WORK_STROKE": C.partitions_complete([work["paw"]["above"], work["paw"]["below"]], work["paw"]["full"]),
            "CONTACT_POINT": [tip["anchor_u"] * 2], "CONTACT_PATCH": [tip["patch_u"]]}


def tap_roles(parts: dict, ready: dict, support: list, tip: dict, plane: int) -> dict:
    """The accepted INSTALL split at the contact plane, with the paws in place of the adze."""
    work, entry = parts["work"], parts["entry"]
    floor = work["rest"]["floor"]
    body = C.body_boxes({"full_bounds_u": work["rest"]["full"], "floor_intersection_u": floor})
    split = lambda rows: [rows["rest"]["lower"], C.union([rows["rest"]["upper"], rows["paw"]["full"]])]
    return {"BODY_HELD_LOAD": body, "STANCE_SUPPORT": [support], "TURN_RECOVERY": split(entry),
            "WORK_APPROACH": split(ready),
            "WORK_STROKE": C.partitions_complete([work["paw"]["above"], work["paw"]["below"]], work["paw"]["full"]),
            "CONTACT_POINT": [tip["anchor_u"] * 2], "CONTACT_PATCH": [tip["patch_u"]]}


def seat_roles(parts: dict, ready: dict, support: list) -> dict:
    """Accepted row 29's role layout without its tool box: body and floor for work, entry and ready."""
    whole = lambda rows: [C.union([[rows["rest"]["full"][0], 0, *rows["rest"]["full"][2:]], rows["paw"]["full"]]),
                          rows["rest"]["below"]]
    return {"BODY_HELD_LOAD": whole(parts["work"]), "TURN_RECOVERY": whole(parts["entry"]),
            "WORK_APPROACH": whole(ready), "STANCE_SUPPORT": [support]}


def clip_parts(case: dict, body: dict, triangles: np.ndarray, paw: np.ndarray, roots: list, basis,
               plane: int) -> tuple:
    """Rest-of-body and paw rows of one clip, plus the rest's split at the contact plane."""
    cache = endpoint(case, body, roots, basis)
    rest, paws = rows_of(case, cache, triangles[~paw]), rows_of(case, cache, triangles[paw], plane)
    rest["floor"] = rest["below"]
    if plane:
        lower, upper = N.clipped_portion(case, cache, triangles[~paw], 1, plane), \
            N.clipped_portion(case, cache, triangles[~paw], 1, plane, True)
        rest["lower"] = [lower[0], 0, lower[2], *lower[3:]]
        rest["upper"] = upper
    return {"rest": rest, "paw": paws}, cache


def program_rows(name: str, clips: dict, body: dict, triangles: np.ndarray, roots: list, basis,
                 vertices: dict, ready_case: dict) -> list:
    """Canonical roles for one program and its oriented rows."""
    entry_name, work_name, _, plane, headings = PROGRAMS[name]
    paw = masks(body, triangles)
    parts, caches = {}, {}
    for key, case in (("work", clips[work_name]), ("entry", clips[entry_name])):
        parts[key], caches[key] = clip_parts(case, body, triangles, paw, roots, basis, plane or 0)
    ready, ready_cache = clip_parts(ready_case, body, triangles, paw, roots, basis, plane or 0)
    support = stance(body, triangles, [(caches["work"], parts["work"]["rest"]["below"]),
                                       (caches["entry"], parts["entry"]["rest"]["below"]),
                                       (ready_cache, ready["rest"]["below"])])
    result = []
    for heading in range(headings):
        if name == "seat":
            roles, tip = seat_roles(parts, ready, support), None
        else:
            tips = {s: contact(body, clips[work_name], caches["work"], v, basis.canonical[heading], plane)
                    for s, v in vertices.items()}
            patch = C.union([t["patch_u"] for t in tips.values()])
            tip = {"anchor_u": tips["right"]["anchor_u"], "patch_u": patch, "paws": tips}
            roles = (dig_roles(parts, ready, support, tip) if name == "dig"
                     else tap_roles(parts, ready, support, tip, plane))
        require(sum(map(len, roles.values())) <= 12, "BOX_CAPACITY")
        result.append({"program": name, "yaw": N.YAWS[heading], "canonical_roles": roles, "contact": tip,
                       "roles": {role: [N.orient_box(box, heading) for box in rows] for role, rows in roles.items()}})
    return result


def contact_vertices() -> dict:
    """The approved contact vertices: pa's claw tips (step 1b) and the paw seat's palm vertices (step 2)."""
    dig = json.loads((SRC.HERE / "evidence/claw-pair-v1/candidate-pa/candidate.json").read_text())["claw_vertices"]
    paw = json.loads(PAW.read_text())["palm_vertices"]
    return {"dig": dig, "tap": paw, "seat": paw}


def derive(palette: Path, grip: Path, basis_path: Path) -> dict:
    """All claw/paw rows."""
    body = NC.open_body(palette, grip)
    cases = {c["id"].split(".")[-1]: c for c in NC.cases(body)}
    triangles = SRC.read_claw_source(palette)["triangles"]
    with basis_path.open("rb") as stream:
        basis = N.CardinalBasis(stream, BASIS_SHA, BASIS_PRODUCER)
    ready = P.indexed_sequence(cases["stand"], [NC.READY, NC.READY], "claw_exact_ready", False)
    vertices = contact_vertices()
    rows = []
    for name in PROGRAMS:
        rows += program_rows(name, cases, body, triangles, SRC.ROOT_BOUNDS, basis, vertices[name], ready)
    return {"schema": 1, "decision": "1217", "rows": rows, "basis": basis.cardinal_certificate(),
            "world_root_bounds_u": SRC.ROOT_BOUNDS, "image_record": NC.record_pins(),
            "production_qualified": False}


def main() -> int:
    """Derive and write the rows record."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("--world-basis", type=Path, required=True)
    parser.add_argument("--palette", type=Path, default=SRC.PALETTE)
    parser.add_argument("--grip-palette", type=Path, default=SRC.PALETTE.parent / "mole-grip-v3.ugpal")
    args = parser.parse_args()
    require(not args.out.exists(), "OUTPUT_EXISTS")
    result = derive(args.palette, args.grip_palette, args.world_basis)
    result["producer_sources"] = {str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p)
                                  for p in (Path(__file__), Path(NC.__file__), Path(ONE.__file__), Path(N.__file__))}
    args.out.write_text(json.dumps(result, indent=1, default=str) + "\n")
    print(json.dumps([{"program": r["program"], "yaw": r["yaw"], "boxes": sum(map(len, r["roles"].values()))}
                      for r in result["rows"]]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
