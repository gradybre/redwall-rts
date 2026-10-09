#!/usr/bin/env python3
"""General paw working motion for fitting the treads T1...T5 and the T6 sill (ADR 1217 step 2d, ADR 1209). Source only.

Brendan (2026-10-08): "General digging motion, does not need to line up perfectly." The treads are fitted from ADR
1209's tread station (310 u behind T_{k-1}'s far edge, yaw 0, facing down the stair) with a general paw working
motion. The paws need not make an exact certified contact with the bearer, so step 2's contact crossing and patch
requirement is dropped for tread fitting. The work is accounted by the Job/Work model as usual.

**Motion.** The approved paw handling seat and seating tap (`author_paw_seat`, candidate a's method), unchanged in
construction, re-posed at the tread station with the adjustments the proofs need:

- lean, hip drop, head lift and palm rolls (`author_paw_seat.DOMAINS`);
- paw spacing (+-x) and the work point's z over the bearer;
- the work height: the paws work at `work_y` u above T_{k-1}'s deck, the same for the treads and the sill, so one
  program serves both (as one program serves L0 and T0). The tap's lowest key is 2 u below the work plane, so at
  131 u the paws come within 1 u of a tread bearer's top and never enter it; the sill's bearer is 64 u lower.

**Proofs that stay** (the physical safety proofs; each is the accepted one, unchanged):

- **World with sole support** (`prove_paw_seat.world`): every triangle against every solid on every rendered
  interval, with the accepted sole rule on T_{k-1}'s deck. Solids: ADR 1209's tread fixture (the support deck, the
  bearer/post supersets, the deck behind (riser) and its supersets, the bearer) plus the trench side walls
  (`derive_tread_side_station.trench_walls`, superset height of the deepest tread). The bearer is a hard solid for
  every triangle, paws included: the call passes the work plane P + 3, so the paw skin is the whole bearer.
- **Self-clearance with no exception** (`prove_claw_pair.self_rows`): each arm against everything without that arm's
  weight (legs included) and arm against arm.

Recovery is the exact reverse of the entry. Both sites, the tread (bearer top 128) and the sill (64), use one recipe.

    $PY .../prove_tread_fit.py <out> --work-y-u 131 --contact-z-u -300 --paw-x-u 224 --lean-degrees 15 --drop-u 96 \\
        --head-lift-degrees 60 --right-roll-degrees 90 --left-roll-degrees 90
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np

import author_paw_seat as SEAT
import derive_tread_side_station as SIDE
import prove_claw_pair as PAIRPROOF
import prove_paw_seat as PAWPROOF
import prove_tread_seat as TREADSEAT

W, SRC, ONE = SEAT.W, SEAT.SRC, PAWPROOF.ONE
SITES = {"tread": SEAT.PLANE_U, "sill": TREADSEAT.SILL_PLANE_U}
WALL_TREAD = 6  # The deepest fitting station (the sill from T5): its walls are the tallest, a superset for all.
EXTRA = {"work_y_u": (SEAT.PLANE_U + SEAT.TAP_DEPTH_U + 1, 512), "contact_z_u": (-309, -183), "paw_x_u": (64, 256)}
PARTS = ("work", "entry", "recovery")


def site(recipe: dict, plane: int) -> tuple:
    """The work site over the bearer and the tread fixture with the trench walls."""
    _, fixture = TREADSEAT.site(plane)
    work = fixture["solids_u"][fixture["workpiece_solid"]]
    W.require(work[4] == plane and work[2] < recipe["contact_z_u"] < work[5] and recipe["paw_x_u"] < work[3],
              "TREAD_FIT_OFF_BEARER")
    height = recipe["work_y_u"]
    W.require(height - SEAT.TAP_DEPTH_U > plane, "TREAD_FIT_WORK_BELOW_TOP")
    contact = {"right": np.array([recipe["paw_x_u"], float(height), recipe["contact_z_u"]]),
               "left": np.array([-recipe["paw_x_u"], float(height), recipe["contact_z_u"]])}
    where = {"name": f"tread_fit_{plane}", "plane": height, "contact": contact, "section": np.array(work, dtype=float)}
    walls = SIDE.trench_walls(WALL_TREAD, fixture)
    full = dict(fixture, solids_u=fixture["solids_u"] + walls,
                source_labels=fixture["source_labels"] + ["trench side wall, -x", "trench side wall, +x"])
    return where, full


def prove_site(src: dict, recipe: dict, plane: int, out: Path, sets: dict) -> dict:
    """Author both programs at one site, write the clips and run the kept proofs."""
    where, fixture = site(recipe, plane)
    seat_recipe = {k: recipe[k] for k in SEAT.DOMAINS}
    programs = SEAT.author(src, seat_recipe, where)
    out.mkdir(parents=True)
    clips, rows, clear = {}, {}, True
    for name, cases in programs.items():
        W.require(np.array_equal(cases[2]["matrices"], cases[1]["matrices"][::-1]), "TREAD_FIT_REVERSE")
        for part, case in zip(PARTS, cases):
            path = out / f"{name}_{part}.npz"
            W.write_case(path, case)
            clips[f"{name}_{part}"] = {"id": case["id"], "frames": case["frames"], "sha256": SRC.sha(path)}
        rows[name] = {}
        for part, case in zip(PARTS[:2], cases[:2]):
            keys, padding, _ = ONE.hulls(src, case)
            self_row = PAIRPROOF.self_rows(src, case, keys, padding, sets, None)
            world_row = PAWPROOF.world(src, case, fixture, sets, plane + SEAT.TAP_DEPTH_U + 1)
            rows[name][part] = {"self": self_row, "world": world_row}
            clear = clear and self_row["clear"] and world_row["clear"]
        rows[name]["recovery"] = {"reused_exact_reverse_of": "entry"}
    candidate = {"schema": 1, "decision": ["1217", "1209"], "recipe": recipe, "bearer_top_u": plane,
                 "work_plane_u": where["plane"], "contact_targets_u": {s: v.tolist() for s, v in where["contact"].items()},
                 "station_from_far_edge_u": TREADSEAT.STATION_D, "fixture": fixture, "clips": clips,
                 "exact_bearer_contact_required": False, "production_qualified": False}
    (out / "candidate.json").write_text(json.dumps(candidate, indent=2) + "\n")
    proof = {"schema": 1, "decision": ["1217", "1209"], "clear": bool(clear), **rows,
             "bearer_rule": "hard solid for every triangle (paw skin = whole bearer)", "production_qualified": False}
    (out / "proof.json").write_text(json.dumps(proof, indent=1) + "\n")
    return proof


def brief(proof: dict) -> dict:
    """Unresolved counts per program, part and proof."""
    return {name: {part: {"self": proof[name][part]["self"]["clear"],
                          "world_unresolved": len(proof[name][part]["world"]["unresolved"])}
                   for part in PARTS[:2]} for name in ("seat", "tap")}


def main() -> int:
    """Prove one recipe at the tread and the sill."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    for name in list(SEAT.DOMAINS) + list(EXTRA):
        parser.add_argument("--" + name.replace("_", "-"), dest=name, type=int, required=True)
    args = parser.parse_args()
    W.require(not args.out.exists(), "TREAD_FIT_OUTPUT_EXISTS")
    recipe = {name: getattr(args, name) for name in list(SEAT.DOMAINS) + list(EXTRA)}
    for name, (low, high) in {**SEAT.DOMAINS, **EXTRA}.items():
        W.require(low <= recipe[name] <= high, "TREAD_FIT_RECIPE_" + name.upper())
    src = SEAT.corrected_source()
    sets = PAIRPROOF.classes(src)
    result = {label: prove_site(src, recipe, plane, args.out / label, sets) for label, plane in SITES.items()}
    summary = {"schema": 1, "recipe": recipe, "clear": all(r["clear"] for r in result.values()),
               "sites": {label: {"clear": r["clear"], **brief(r)} for label, r in result.items()},
               "producer_sources": {str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p) for p in
                                    (Path(__file__), Path(SEAT.__file__), Path(PAWPROOF.__file__),
                                     Path(PAIRPROOF.__file__), Path(TREADSEAT.__file__), Path(SIDE.__file__))}}
    (args.out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary["sites"]))
    return 0 if summary["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
