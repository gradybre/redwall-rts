#!/usr/bin/env python3
"""Narrow tool-free approach and retreat rows on the claw source (ADR 1217 step 4d; Brendan's option 1).

The pick-era approach (READY_FORWARD, rows 2-5) and retreat (READY_BACKWARD, rows 6-9) were not new motion
(`work-approach-v1/compile_work_approach.py`). They are the source's walk clip played at a **fixed body heading**
while the root moves straight along the station line, joined to the ready key 8 by the driver's READY fade:

- the roles are the whole outward hull of every walk key and ready key 8 (`whole_roles`), with no yaw sweep, so
  the box is the walk's own narrow hull, oriented to the four headings by the exact quarter turns;
- the retreat plays the same poses in reverse, so it shares every box;
- the handoffs are the finite fade simplices of `prove_state_handoffs.handoff_sets` that these rows use, selected
  as `compile_work_approach.selected_handoffs` selects them: ready to walk start, and every walk interval to ready.
  The idle-to-ready fades belong to a STAND row, which source 4 does not carry (ADR 1217 step 4c.3).

This module applies that recipe to the claw image's own stand and walk (source 4, open paw, no tool). Nothing is
authored: the clips are the approved step-1c clips, pinned through the claw image's record. It proves:

1. **Self-clearance over every handoff:** each arm against the rest of the body and arm against arm, on every fade
   simplex (`prove_state_handoffs.separated_simplex`, all positive blend shares).
2. **The pending bearers:** every body triangle on every handoff simplex, with the root anywhere from the station
   to 4,096 u behind it along the station line (the span the pick's endpoint certificate covers), against the
   L0 bearer at H and the T0 bearer at the L0 contact. The bearer prisms are the published certificate's
   station-local prisms (`qualified-assembly-v1/source_program.gd::bearer_refusal`). A root offset t in [0, 4096]
   along +Z is folded into the prism, which is extended by 4,096 u along -Z.

    $PY .../author_claw_approach.py <out-dir> --world-basis <world-yaw-v1.ugyaw> [--palette ...] [--grip-palette ...]
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import sys
import time

import numpy as np

import derive_claw_rows as DC
import derive_claw_stand_rows as DS
import prove_claw_pair as PAIRPROOF

SRC, NC, P, C, N = DS.SRC, DS.NC, DC.P, DC.C, DC.N
SPEC = importlib.util.spec_from_file_location("claw_approach_handoffs", SRC.I.PROOF / "prove_state_handoffs.py")
W = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(W)
READY = NC.READY
SPAN_U = 4096
BEARERS = {"H (L0 bearer, assembly 0)": [-192, 0, -512, 1856, 128, -384],
           "L0 contact (T0 bearer, assembly 1)": [-256, 0, -512, 256, 128, -384]}
POLICIES = {"READY_FORWARD": 1, "READY_BACKWARD": 2}
ROW_BOX_LIMIT = 12
UNRESOLVED_CAPACITY = 4096  # Every unresolved pair is recorded, not only the first; the verdict needs none.


def require(value: bool, code: str) -> None:
    """Every refusal names its failed fact."""
    if not value:
        raise ValueError("CLAW_APPROACH_" + code)


def sources(palette: Path, grip: Path, basis_path: Path) -> dict:
    """The open body, triangles, the claw image's stand and walk, and per-key outward enclosures."""
    src = SRC.read_claw_source(palette)
    body = NC.open_body(palette, grip)
    require(body["geometry"][0]["points"].shape == src["body"]["geometry"][0]["points"].shape, "BODY")
    clips = DS.image_clips()
    with basis_path.open("rb") as stream:
        basis = N.CardinalBasis(stream, DC.BASIS_SHA, DC.BASIS_PRODUCER)
    stand, walk = clips["clips"]["stand"], clips["clips"]["walk"]
    caches = [DC.endpoint(case, body, SRC.ROOT_BOUNDS, basis) for case in (stand, walk)]
    low = np.concatenate([cache["low"] for cache in caches])
    high = np.concatenate([cache["high"] for cache in caches])
    return {"src": src, "body": body, "triangles": src["triangles"], "stand": stand, "walk": walk,
            "low": low, "high": high, "basis": basis, "pins": clips["pins"],
            "padding_q24": [[int(v) for v in cache["padding"]] for cache in caches]}


def roles(data: dict) -> tuple:
    """`whole_roles` for one body part: the hull of every walk key and ready key 8, its floor and foot stance."""
    walk_from = data["stand"]["frames"]
    frames = [READY] + list(range(walk_from, walk_from + data["walk"]["frames"]))
    low, high = data["low"][frames], data["high"][frames]
    full = P.outward_units(low.min(axis=(0, 1)), high.max(axis=(0, 1)))
    clipped = P.clipped_triangle_floor(np.stack([low.min(axis=0)] * 2), np.stack([high.max(axis=0)] * 2),
                                       data["triangles"])
    require(clipped is not None, "FLOOR")
    floor = P.outward_units(np.array(clipped[:3]), np.array(clipped[3:]))
    stance = C.foot_projection(data["body"], [data["triangles"]], low, high, floor)
    support = stance["support_u"]
    require(all(support[a] <= floor[a] <= floor[a + 3] <= support[a + 3] for a in range(3)), "STANCE")
    body = [[full[0], 0, full[2], *full[3:]], floor]
    canonical = {"BODY_HELD_LOAD": body, "TURN_RECOVERY": [list(b) for b in body], "STANCE_SUPPORT": [support]}
    return canonical, {"full_u": full, "floor_u": floor, "support_u": support, "corner_count": len(frames)}


def rows(canonical: dict) -> list:
    """Forward and backward at the four exact headings; backward walks the same poses along the reversed path."""
    result = []
    for name, policy in POLICIES.items():
        for heading, yaw in enumerate(N.YAWS):
            result.append({"policy": name, "selection_policy": policy, "mode": 1, "yaw_kind": "YAW_EXACT",
                           "yaw": yaw, "path_yaw": (yaw + (32768 if policy == 2 else 0)) % 65536,
                           "tool": -1, "states": 451,
                           "roles": {role: [N.orient_box(box, heading) for box in boxes]
                                     for role, boxes in canonical.items()}})
    require(all(sum(map(len, r["roles"].values())) <= ROW_BOX_LIMIT for r in result), "BOX_CAPACITY")
    return result


def simplex(data: dict, corners: list, ids: np.ndarray) -> tuple:
    """(low, high) per triangle and corner: shape (triangles, corners, 3, 3), Q24."""
    tri = data["triangles"][ids]
    low = data["low"][corners][:, tri].transpose(1, 0, 2, 3)
    high = data["high"][corners][:, tri].transpose(1, 0, 2, 3)
    return low, high


def separate_sets(data: dict, corners: list, first: np.ndarray, second: np.ndarray, counter: list) -> list:
    """Every overlapping pair of two triangle sets separated on one fade simplex."""
    al, ah = simplex(data, corners, np.flatnonzero(first))
    bl, bh = simplex(data, corners, np.flatnonzero(second))
    amin, amax = al.min(axis=(1, 2)), ah.max(axis=(1, 2))
    bmin, bmax = bl.min(axis=(1, 2)), bh.max(axis=(1, 2))
    failed = []
    for a in range(len(al)):
        for b in np.flatnonzero(np.all(bmin <= amax[a], axis=1) & np.all(bmax >= amin[a], axis=1)):
            if not W.separated_simplex(al[a], ah[a], bl[b], bh[b], counter):
                failed.append([int(np.flatnonzero(first)[a]), int(np.flatnonzero(second)[b])])
    return failed


def approach_handoffs(data: dict) -> list:
    """The ready/walk fade simplices, as `compile_work_approach.selected_handoffs` selects them."""
    result = [row for row in W.handoff_sets([data["stand"], data["walk"]]) if row["from"] in ("ready", "walk")]
    require(len(result) == data["walk"]["frames"] and result[0]["corners"] == [READY, READY, data["stand"]["frames"]],
            "HANDOFF_CENSUS")
    return result


def self_clearance(data: dict) -> dict:
    """Arm against rest and arm against arm on every approach handoff simplex, no exception."""
    sets = PAIRPROOF.classes(data["src"])
    counter, unresolved, checked = [0], [], 0
    for handoff in approach_handoffs(data):
        for label, first, second in PAIRPROOF.PAIRINGS:
            for pair in separate_sets(data, handoff["corners"], sets[first], sets[second], counter):
                unresolved.append({"handoff": handoff["from"], "interval": handoff["interval"], "pairing": label,
                                   "triangles": pair})
            require(len(unresolved) <= UNRESOLVED_CAPACITY, "SELF_UNRESOLVED_CAPACITY")
        checked += 1
    return {"clear": not unresolved, "unresolved": unresolved, "handoffs": checked, "checks": counter[0]}


def box_triangles(box: list) -> np.ndarray:
    """The twelve triangles of an axis-aligned prism (u) as exact Q24 corners."""
    scale = P.SCALE // 1024
    x, y, z = (box[0], box[3]), (box[1], box[4]), (box[2], box[5])
    corner = lambda i, j, k: [x[i] * scale, y[j] * scale, z[k] * scale]
    faces = [((0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)), ((0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)),
             ((0, 0, 0), (0, 1, 0), (0, 1, 1), (0, 0, 1)), ((1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)),
             ((0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)), ((0, 1, 0), (1, 1, 0), (1, 1, 1), (0, 1, 1))]
    triangles = []
    for a, b, c, d in faces:
        triangles += [[corner(*a), corner(*b), corner(*c)], [corner(*a), corner(*c), corner(*d)]]
    return np.array(triangles, dtype=np.int64)


def bearer_clearance(data: dict, prism: list) -> dict:
    """Every body triangle on every handoff simplex against the prism extended by the 4,096 u span."""
    swept = [prism[0], prism[1], prism[2] - SPAN_U, prism[3], prism[4], prism[5]]
    fixed = box_triangles(swept)
    ids = np.arange(len(data["triangles"]))
    counter, unresolved, candidates = [0], [], 0
    low_box, high_box = fixed.min(axis=(0, 1)), fixed.max(axis=(0, 1))
    for handoff in approach_handoffs(data):
        al, ah = simplex(data, handoff["corners"], ids)
        amin, amax = al.min(axis=(1, 2)), ah.max(axis=(1, 2))
        near = np.flatnonzero(np.all(amin <= high_box, axis=1) & np.all(amax >= low_box, axis=1))
        corners = len(handoff["corners"])
        for a in near:
            for tri in fixed:
                candidates += 1
                b = np.repeat(tri[None], corners, axis=0)
                if not W.separated_simplex(al[a], ah[a], b, b.copy(), counter):
                    unresolved.append({"handoff": handoff["from"], "interval": handoff["interval"],
                                       "triangle": int(a)})
                    break
        require(len(unresolved) < 32, "BEARER_UNRESOLVED:" + json.dumps(unresolved[:4]))
    return {"clear": not unresolved, "unresolved": unresolved, "prism_u": prism, "swept_prism_u": swept,
            "candidate_pairs": candidates, "checks": counter[0]}


def derive(palette: Path, grip: Path, basis_path: Path) -> dict:
    """Rows and every proof."""
    data = sources(palette, grip, basis_path)
    canonical, geometry = roles(data)
    started = time.monotonic()
    self_proof = self_clearance(data)
    bearers = {name: bearer_clearance(data, prism) for name, prism in BEARERS.items()}
    clear = self_proof["clear"] and all(row["clear"] for row in bearers.values())
    return {"schema": 1, "decision": "1217", "source": 4, "body": "open paw (original import, a938d479…)",
            "recipe": "work-approach-v1 whole_roles: fixed-heading walk keys + ready key 8; no yaw sweep",
            "canonical_roles": canonical, "geometry": geometry, "rows": rows(canonical),
            "proofs": {"self_clearance": self_proof, "bearers": bearers}, "clear": bool(clear),
            "proof_seconds": time.monotonic() - started, "clip_sha256": data["pins"],
            "claw_image_sha256": DS.CLAW_IMAGE_SHA, "padding_q24": data["padding_q24"],
            "ready_key": READY, "span_u": SPAN_U, "world_basis_sha256": DC.BASIS_SHA,
            "production_qualified": False}


def main() -> int:
    """Derive, prove and write the record once."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("--world-basis", type=Path, required=True)
    parser.add_argument("--palette", type=Path, default=SRC.PALETTE)
    parser.add_argument("--grip-palette", type=Path, default=SRC.PALETTE.parent / "mole-grip-v3.ugpal")
    args = parser.parse_args()
    require(not args.out.exists(), "OUTPUT_EXISTS")
    result = derive(args.palette, args.grip_palette, args.world_basis)
    result["producer_sources"] = {str(Path(p).resolve().relative_to(SRC.ROOT)): SRC.sha(Path(p))
                                  for p in (__file__, DC.__file__, DS.__file__, PAIRPROOF.__file__, W.__file__)}
    args.out.mkdir(parents=True)
    (args.out / "approach.json").write_text(json.dumps(result, indent=1, default=str) + "\n")
    print(json.dumps({"clear": result["clear"], "roles": result["canonical_roles"],
                      "self": {k: result["proofs"]["self_clearance"][k] for k in ("clear", "handoffs", "checks")},
                      "bearers": {n: r["clear"] for n, r in result["proofs"]["bearers"].items()}}))
    return 0 if result["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
