#!/usr/bin/env python3
"""The one claw stroke at a wall: four WORK rows derived from M1's approved clips (decision 1971). Derived only.

Brendan (2026-10-15, P-1971-1 (b)): the one stroke is M1, the approved two-paw claw stroke (ADR 1217 step 1b,
candidate pa, re-proved from the corrected ready as `stand-walk-v2/dig-pa`). Nothing is authored or captured: the
clips and the claw image are content 10's. This applies `derive_claw_rows.py`'s accepted derivation (outward Q24
hulls with the cardinal residual, the skin-weight paw split, the foot projection, exact quarter turns) with two
changes, both forced by a wall ahead instead of a top face below:

1. **The paws are the stroke in every clip.** The entry's paws join `WORK_STROKE`; `TURN_RECOVERY` keeps only the
   rest of the body. The recovery is the entry's exact reverse, so the same boxes cover it.
2. **The contact lies on the wall plane.** For each heading, each claw tip's first forward crossing of the plane
   `forward = W`, in the entry and then the stroke (`prove_cardinal_profiles.contact_patch`, axis z). CONTACT_POINT
   is the right paw's anchor and CONTACT_PATCH the union of both paws' patches.

**The wall distance W is derived, not chosen:** the smallest forward distance that keeps every box except the stroke
out of the wall. That is the maximum forward reach of the wall row's own non-stroke boxes and of the travel rows
that arrive at and leave the station (content 10's narrow approach 43-46 and retreat 47-50).

    $PY .../derive_claw_wall_rows.py <out.json> --world-basis <world-yaw-v1.ugyaw> [--palette ...] [--grip-palette ...]
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import struct
import sys

import derive_claw_rows as R

NC, ONE, SRC, N, P, C = R.NC, R.ONE, R.SRC, R.N, R.P, R.C
CONTENT_10 = SRC.HERE.parent / "qualified-claw-stairs-v11/mole-worker.ugprof"
CONTENT_10_SHA = "9791eb59b778cf9fe0b4c66dfd7181c58706abd6ed1a8e6a90a73daafa7f3317"
TRAVEL_ROWS = (43, 44, 45, 46, 47, 48, 49, 50)  # Narrow approach (READY_FORWARD) and retreat, yaws 0..49152.
DIG_ROWS = (56, 58, 60, 62)  # Content 10's M1 rows at yaws 0..49152; the wall rows are their siblings.
STROKE = 4


def require(value: bool, code: str) -> None:
    """Every refusal names its failed derivation fact."""
    P.require(value, "CLAW_WALL_ROWS_" + code)


def published_rows(rows: tuple) -> dict:
    """(fields, boxes) of content-10 rows, read from the pinned wire (98-byte rows, 28-byte boxes)."""
    wire = CONTENT_10.read_bytes()
    require(hashlib.sha256(wire).hexdigest() == CONTENT_10_SHA, "CONTENT_10_PIN")
    count, _, sources = struct.unpack_from("<III", wire, 20)
    at, row, box = 32 + 32 * sources, struct.Struct("<18i3q2B"), struct.Struct("<7i")
    result = {}
    for profile in rows:
        fields = row.unpack_from(wire, at + 98 * profile)
        result[profile] = (fields, [list(box.unpack_from(wire, at + 98 * count + 28 * k))
                                    for k in range(fields[14], fields[14] + fields[15])])
    return result


def travel_reach() -> int:
    """The forward reach of the travel rows at their own heading (yaw-0 frame: forward is -z)."""
    rows = published_rows(TRAVEL_ROWS)
    reach = 0
    for index, profile in enumerate(TRAVEL_ROWS):
        fields, boxes = rows[profile]
        require(fields[0] == 4 and fields[4] == 1 and fields[10] == 0 and fields[11] == 16384 * (index % 4),
                "TRAVEL_ROW")
        turned = [N.orient_box(b[:6], (4 - index % 4) % 4) for b in boxes]  # Back to the canonical heading.
        reach = max(reach, max(-b[2] for b in turned))
    return reach


def wall_distance(roles: dict) -> int:
    """W: every non-stroke box of the wall row and of its travel rows stays at or behind the wall plane."""
    own = max(-box[2] for role, boxes in roles.items() if role not in ("WORK_STROKE", "CONTACT_POINT",
                                                                       "CONTACT_PATCH") for box in boxes)
    wall = max(own, travel_reach())
    reach = max(-box[2] for box in roles["WORK_STROKE"])
    require(wall < reach, "STROKE_SHORT_OF_WALL")
    return wall


def wall_contact(body: dict, clips: list, vertex: int, canonical: tuple, wall: int) -> dict:
    """The claw tip's first forward crossing of the wall plane z = -W, entry then stroke, with its residual patch.

    The right tip crosses in the entry; the left, half a cycle behind (step 1b), first crosses in the stroke."""
    plane = Fraction(-wall, 1024)
    for case, cache in clips:
        errors = [Fraction(int(v), P.SCALE) for v in cache["padding"]]
        for first, last in P.rendered_intervals(case):
            a = R.exact_point(body, case, first, vertex, canonical)
            b = R.exact_point(body, case, last, vertex, canonical)
            if a[2] - errors[2] > plane and b[2] + errors[2] < plane:
                return dict(N.contact_patch(a, b, errors, 2, -wall), clip=case["id"], rendered_edge=[first, last])
    raise ValueError("CLAW_WALL_ROWS_CONTACT_MISSING")


def wall_roles(parts: dict, ready: dict, support: list) -> dict:
    """`dig_roles` with the entry's paws moved into the stroke; contacts are added per heading."""
    work, entry = parts["work"], parts["entry"]
    require(entry["paw"]["below"] is None and ready["paw"]["below"] is None, "RECOVERY_PAW_FLOOR")
    lift = lambda rows: [rows["full"][0], 0, rows["full"][2], *rows["full"][3:]]
    stroke = C.partitions_complete([work["paw"]["above"], work["paw"]["below"]], work["paw"]["full"])
    return {"BODY_HELD_LOAD": C.body_boxes({"full_bounds_u": work["rest"]["full"],
                                            "floor_intersection_u": work["rest"]["below"]}),
            "STANCE_SUPPORT": [support],
            "TURN_RECOVERY": [lift(entry["rest"]), entry["rest"]["below"]],
            "WORK_APPROACH": [C.union([lift(ready["rest"]), ready["paw"]["full"]]), ready["rest"]["below"]],
            "WORK_STROKE": stroke + [entry["paw"]["full"]]}


def contacts(body: dict, clips: list, vertices: dict, canonical: tuple, wall: int) -> dict:
    """Both claw tips' wall crossings; the right paw's anchor and the union patch."""
    tips = {side: wall_contact(body, clips, vertex, canonical, wall) for side, vertex in vertices.items()}
    patch = C.union([tip["patch_u"] for tip in tips.values()])
    anchor = tips["right"]["anchor_u"]
    require(0 < anchor[1] < 1024 and patch[2] == patch[5] == -wall and anchor[2] == -wall, "CONTACT_PLANE")
    require(all(patch[a] < patch[a + 3] for a in (0, 1)), "PATCH_AREA")
    return {"anchor_u": anchor, "patch_u": patch, "paws": tips}


def heading_row(roles: dict, tip: dict, heading: int) -> dict:
    """One heading's oriented row; the stroke must contain the anchor (WorkFace's stroke-reaches rule)."""
    canonical = dict(roles, CONTACT_POINT=[tip["anchor_u"] * 2], CONTACT_PATCH=[tip["patch_u"]])
    require(sum(map(len, canonical.values())) <= 12, "BOX_CAPACITY")
    point = tip["anchor_u"]
    require(any(all(b[a] <= point[a] <= b[a + 3] for a in range(3)) for b in roles["WORK_STROKE"]), "STROKE_ANCHOR")
    return {"program": "wall", "yaw": N.YAWS[heading], "canonical_roles": canonical, "contact": tip,
            "roles": {role: [N.orient_box(box, heading) for box in rows] for role, rows in canonical.items()}}


def derive(palette: Path, grip: Path, basis_path: Path) -> dict:
    """The four wall rows, W and their inputs."""
    body = NC.open_body(palette, grip)
    cases = {c["id"].split(".")[-1]: c for c in NC.cases(body)}
    triangles = SRC.read_claw_source(palette)["triangles"]
    with basis_path.open("rb") as stream:
        basis = N.CardinalBasis(stream, R.BASIS_SHA, R.BASIS_PRODUCER)
    ready_case = P.indexed_sequence(cases["stand"], [NC.READY, NC.READY], "claw_exact_ready", False)
    paw = R.masks(body, triangles)
    parts, caches = {}, {}
    for key, name in (("work", "dig_stroke"), ("entry", "dig_entry")):
        parts[key], caches[key] = R.clip_parts(cases[name], body, triangles, paw, SRC.ROOT_BOUNDS, basis, 0)
    ready, ready_cache = R.clip_parts(ready_case, body, triangles, paw, SRC.ROOT_BOUNDS, basis, 0)
    support = R.stance(body, triangles, [(caches["work"], parts["work"]["rest"]["below"]),
                                         (caches["entry"], parts["entry"]["rest"]["below"]),
                                         (ready_cache, ready["rest"]["below"])])
    roles = wall_roles(parts, ready, support)
    wall = wall_distance(roles)
    vertices = R.contact_vertices()["dig"]
    clips = [(cases["dig_entry"], caches["entry"]), (cases["dig_stroke"], caches["work"])]
    rows = [heading_row(roles, contacts(body, clips, vertices, canonical, wall), h)
            for h, canonical in enumerate(basis.canonical)]
    return {"schema": 1, "decision": "1971", "wall_distance_u": wall, "travel_reach_u": travel_reach(),
            "rows": rows, "replaces_none": "content 10's rows 56/58/60/62 stay the top-face rows",
            "dig_rows_of_the_same_clips": list(DIG_ROWS), "basis": basis.cardinal_certificate(),
            "world_root_bounds_u": SRC.ROOT_BOUNDS, "image_record": NC.record_pins(),
            "content_10_wire_sha256": CONTENT_10_SHA, "production_qualified": False}


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
                                  for p in (Path(__file__), Path(R.__file__), Path(N.__file__))}
    args.out.write_text(json.dumps(result, indent=1, default=str) + "\n")
    print(json.dumps({"wall_distance_u": result["wall_distance_u"],
                      "rows": [{"yaw": r["yaw"], "anchor_u": r["contact"]["anchor_u"],
                                "boxes": sum(map(len, r["roles"].values()))} for r in result["rows"]]}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
