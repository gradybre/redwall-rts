#!/usr/bin/env python3
"""Paw seating of the stair treads T1…T5 and the T6 sill (ADR 1217 step 2b, ADR 1209). Source-local, yaw 0.

Brendan (2026-10-07): the treads below T0 are fitted by paw with step 2's approved motion, adapted per tread as the
proofs require. This tool re-authors the approved motion at each tread site and proves it:

- **Fixture (published).** ADR 1209's station-local tread fixture (`author_tread_install.fixture`, station 310 u
  behind T_{k−1}'s far edge): the support deck, superset bearer/post sides, the deck behind and its sides, and the
  workpiece, T_k's left bearer quarter-turned across T_{k−1}'s forward top edge, z ∈ [−310, −182]. One fixture
  covers every tread T1…T5. The T6 sill is the same with its bearer cut to 64 u (ADR 1209 D1): plane y = 64.
- **Recipe.** The approved recipe (candidate a) first; it cannot reach this close, so lean and hip drop are
  varied nearest-first (`nearest_recipes`) until one clears every proof at both sites. Head lift and palm rolls
  are kept.
- **Contacts (derived).** As at L0/T0, mirrored about the station: x = ±128 (row 16's own x), at the workpiece's
  z centre (−246), on its top plane.
- **Proofs.** Step 2's, unchanged (`prove_paw_seat.world`, `contact`, `self_rows`): every triangle against every
  solid with sole support, a paw pressing no deeper than the tap's 2 u, each contact's single downward crossing
  with its patch on the workpiece top, and self-clearance per arm and arm against arm.

Writes, per site, the six clips, `candidate.json` and `proof.json`.

    $PY .../prove_tread_seat.py <out-dir>
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np

import author_paw_seat as SEAT
import prove_claw_pair as PAIRPROOF
import prove_paw_seat as PAWPROOF

W, SRC, P = SEAT.W, SEAT.SRC, PAWPROOF.P
TREAD_SPEC = importlib.util.spec_from_file_location("tread_fixture", SRC.I.PROOF / "author_tread_install.py")
TREAD = importlib.util.module_from_spec(TREAD_SPEC)
TREAD_SPEC.loader.exec_module(TREAD)
APPROVED = SRC.HERE / "evidence/paw-seat-v1/candidate-a/candidate.json"
STATION_D = TREAD.STATION_D
SILL_PLANE_U = 64  # ADR 1209 D1: T6's bearers cut to 64 u.
PARTS = ("work", "entry", "recovery")


def tread_fixture(plane: int) -> dict:
    """ADR 1209's station-local tread fixture, with the workpiece's top at `plane`."""
    packet = P.content.read_json(TREAD.PREFIX, TREAD.I.PREFIX_SHA, 65536)
    fixture = TREAD.fixture(packet, STATION_D)
    solids = [list(box) for box in fixture["solids_u"]]
    solids[fixture["workpiece_solid"]][4] = plane
    return dict(fixture, solids_u=solids)


def site(plane: int) -> tuple:
    """The site dictionary for `author_paw_seat` and its fixture."""
    fixture = tread_fixture(plane)
    work = fixture["solids_u"][fixture["workpiece_solid"]]
    z = (work[2] + work[5]) / 2
    contact = {side: np.array([x, float(plane), z]) for side, x in (("right", 128.), ("left", -128.))}
    return {"name": f"tread_plane_{plane}", "plane": plane, "contact": contact,
            "section": np.array(work, dtype=np.float64)}, fixture


def prove(src: dict, recipe: dict, plane: int, out: Path) -> dict:
    """Author the approved recipe at one site, write its clips and prove them."""
    where, fixture = site(plane)
    programs = SEAT.author(src, recipe, where)
    out.mkdir(parents=True)
    clips = {}
    for name, cases in programs.items():
        for part, case in zip(PARTS, cases):
            path = out / f"{name}_{part}.npz"
            W.write_case(path, case)
            clips[f"{name}_{part}"] = {"id": case["id"], "frames": case["frames"], "sha256": SRC.sha(path)}
    offsets, vertices = SEAT.seat_offsets(src, recipe, where)
    record = {"palm_vertices": vertices}
    sets = PAIRPROOF.classes(src)
    result, clear = {}, True
    for name, cases in programs.items():
        rows = {}
        for part, case in zip(PARTS[:2], cases[:2]):
            keys, padding, _ = PAWPROOF.ONE.hulls(src, case)
            rows[part] = {"self": PAIRPROOF.self_rows(src, case, keys, padding, sets, None),
                          "world": PAWPROOF.world(src, case, fixture, sets, plane)}
            clear = clear and rows[part]["self"]["clear"] and rows[part]["world"]["clear"]
        if name == "tap":
            rows["contact"] = PAWPROOF.contact(src, cases[0], record, plane)
            top = fixture["solids_u"][fixture["workpiece_solid"]]
            limits = [top[0], plane, top[2], top[3], plane, top[5]]
            rows["patches_on_workpiece"] = all(PAWPROOF.ONE.contained(c["patch_u"], limits)
                                               for c in rows["contact"].values())
            clear = clear and rows["patches_on_workpiece"]
        result[name] = rows
    candidate = {"schema": 1, "decision": "1217", "recipe": recipe, "plane_u": plane, "station_from_far_edge_u":
                 STATION_D, "contact_targets_u": {s: v.tolist() for s, v in where["contact"].items()},
                 "palm_vertices": vertices, "seat_offsets_u": offsets, "fixture": fixture, "clips": clips,
                 "production_qualified": False}
    (out / "candidate.json").write_text(json.dumps(candidate, indent=2) + "\n")
    proof = {"schema": 1, "decision": "1217", "clear": bool(clear), **result, "production_qualified": False}
    (out / "proof.json").write_text(json.dumps(proof, indent=1) + "\n")
    return proof


def nearest_recipes(approved: dict) -> list:
    """The approved recipe first, then lean and hip drop varied in whole steps, nearest first (head lift and palm
    rolls kept). The approved recipe is unreachable at the tread's shorter reach, so the pose must adapt."""
    grid = [(lean, drop) for lean in range(0, 61, 10) for drop in (0, 32, 64, 96)]
    grid.sort(key=lambda row: (abs(row[0] - approved["lean_degrees"]) / 10 + abs(row[1] - approved["drop_u"]) / 32,
                               row))
    return [dict(approved, lean_degrees=lean, drop_u=drop) for lean, drop in grid]


def reachable(src: dict, recipe: dict) -> bool:
    """Both programs author at both sites with unchanged arm links."""
    try:
        for plane in (SEAT.PLANE_U, SILL_PLANE_U):
            SEAT.author(src, recipe, site(plane)[0])
    except ValueError:
        return False
    return True


def main() -> int:
    """Prove the tread (T1…T5) and sill (T6) sites with the nearest reachable recipe that clears both."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "TREAD_SEAT_OUTPUT_EXISTS")
    approved = json.loads(APPROVED.read_text())["recipe"]
    src = SEAT.corrected_source()
    trail = []
    for attempt, recipe in enumerate(nearest_recipes(approved)):
        if not reachable(src, recipe):
            trail.append({"recipe": recipe, "reachable": False})
            continue
        folder = args.out / f"attempt-{attempt:02d}"
        summary = {label: prove(src, recipe, plane, folder / label)
                   for label, plane in (("tread", SEAT.PLANE_U), ("sill", SILL_PLANE_U))}
        clear = all(row["clear"] for row in summary.values())
        trail.append({"recipe": recipe, "reachable": True, "folder": folder.name, "clear": clear})
        print(json.dumps(trail[-1]), file=sys.stderr, flush=True)
        if clear:
            break
    (args.out / "summary.json").write_text(json.dumps({"approved": approved, "trail": trail,
        "producer_sources": {str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p)
                             for p in (Path(__file__), Path(SEAT.__file__), Path(PAWPROOF.__file__),
                                       Path(TREAD.__file__))}}, indent=2) + "\n")
    print(json.dumps(trail[-1]))
    return 0 if trail and trail[-1].get("clear") else 2


if __name__ == "__main__":
    sys.exit(main())
