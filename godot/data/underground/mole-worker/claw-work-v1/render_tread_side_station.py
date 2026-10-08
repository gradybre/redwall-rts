#!/usr/bin/env python3
"""Review images for the side-on tread station (ADR 1217 step 2c). A review aid, not a proof.

The approved paw clips (`paw-seat-v1/candidate-a`, rebuilt and pin-checked by `prove_paw_seat.load`) are placed at
the best side-on station of `derive_tread_side_station.py` (its `station.json`), turned the published quarter
(facing -x), and drawn in the tread's station-local frame with the accepted painter renderer
(`render_tread_install.panel`) at the standard views. Paws are tinted brown, feet blue. Green: T_{k-1}'s deck, the
deck behind and their supports; orange: T_k's bearer being fitted; grey: the trench side walls.

Per site (`tread-t3/`, `sill-t6/`):

- `overview.png`: the tap's deepest key (paws pressing) from the front, the side and the top.
- `hands.png`: the handling seat and the tap's deepest key around the bearer, x0.9 (both paws in frame).
- `motion.png`: the quarter turn at the station (top views of the ready stand's feet only, turned 0, 30, 60, 71 and
  90 degrees about the root; 71 is the largest whole degree whose feet still fit the deck's depth), then front views
  of tap keys 0, 8 and 16.

    $PY .../render_tread_side_station.py <station.json> <out-dir>
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np

import derive_tread_side_station as SIDE
import render_claw_stroke as ONE_RENDER

SEAT, SRC, W, PAWPROOF = SIDE.SEAT, SIDE.SRC, SIDE.W, SIDE.PAWPROOF
R = ONE_RENDER.R
DEEPEST_TAP = 16
PAW_RGB, FOOT_RGB = (196, 120, 96), (90, 120, 200)
GREEN, ORANGE, GREY = (60, 110, 60), (190, 120, 20), (140, 140, 140)
TURN_DEGREES = (0, 30, 60, 71, 90)


def colours(src: dict, sets: dict) -> list:
    """Per-triangle colour: paw, foot or body."""
    return [PAW_RGB if p else FOOT_RGB if f else R.BODY_RGB for p, f in zip(sets["paw"], sets["any_foot"])]


def prisms(site: dict) -> list:
    """The station-local fixture: supports green, the bearer orange, the trench walls grey."""
    solids, labels = site["fixture_station_local"], site["fixture_labels"]
    rows = []
    for box, label in zip(solids, labels):
        rgb = ORANGE if label.startswith("paid WIP") else GREY if label.startswith("trench") else GREEN
        if rgb is GREY:
            box = [max(box[0], -1200), box[1], box[2], min(box[3], 1200), box[4], box[5]]
        rows.append((box, rgb))
    return rows


def meshes(src: dict, case: dict, frame: int, station: tuple, tint: list, degrees: float = 90.) -> list:
    """The body at one key, placed at the station and turned by `degrees`."""
    points = SIDE.to_world(SRC.I.points_at(case, src["body"], frame), station, degrees)
    return [(points, src["triangles"], tint)]


def render(src: dict, sets: dict, programs: dict, site: dict, out: Path) -> dict:
    """Write the three images for one site and return their digests."""
    station, tint, boxes = tuple(site["station_xz_u"]), colours(src, sets), prisms(site)
    seat, tap, stand = programs["seat"][0], programs["tap"][0], src["stand"]
    focus = np.array([180., 300., -60.])
    name = "T6 sill (bearer top 64 u)" if site["plane_u"] == 64 else f"T{site['tread']} (bearer top 128 u)"
    note = (f"UNQUALIFIED review aid (ADR 1217 step 2c): {name}, side-on station {station}, yaw 16384. "
            "Blue: feet; brown: paws; green: decks; orange: bearer; grey: trench walls.")
    deepest = meshes(src, tap, DEEPEST_TAP, station, tint)
    overview = [R.panel((570, 530), f"{view} (tap key {DEEPEST_TAP})", deepest, boxes, axes, .40, focus)
                for view, axes in R.VIEWS]
    ONE_RENDER.sheet((570, 530), overview, 3, note).save(out / "overview.png")
    anchor = np.array([0., float(site["plane_u"]) + 40., float(station[1])])  # between the two contacts
    hands = [R.panel((533, 410), f"{label}: {view} (x0.9)", meshes(src, case, frame, station, tint), boxes, axes,
                     .9, anchor)
             for label, case, frame in (("handling seat", seat, 0), (f"tap key {DEEPEST_TAP}", tap, DEEPEST_TAP))
             for view, axes in R.VIEWS]
    ONE_RENDER.sheet((533, 410), hands, 3, "Feet blue, paws brown. Zoomed review aid only.").save(out / "hands.png")
    top = R.VIEWS[2][1]
    feet = [src["triangles"][sets["any_foot"]], [FOOT_RGB] * int(sets["any_foot"].sum())]
    ready = SRC.I.points_at(stand, src["body"], SRC.READY_FRAME)
    centre = np.array([float(station[0]), 0., -54.])
    turn = [R.panel((480, 450), f"Top, feet only: ready stand turned {d} deg",
                    [(SIDE.to_world(ready, station, d), *feet)], boxes, top, .55, centre)
            for d in TURN_DEGREES]
    side = [R.panel((480, 450), f"Front: tap key {k}", meshes(src, tap, k, station, tint), boxes, R.VIEWS[0][1],
                    .45, focus) for k in (0, 8, DEEPEST_TAP)]
    ONE_RENDER.sheet((480, 450), turn + side, 4, note).save(out / "motion.png")
    return {image: SRC.sha(out / image) for image in ("overview.png", "hands.png", "motion.png")}


def main() -> int:
    """Render both sites."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("station", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "TREAD_SIDE_RENDER_EXISTS")
    record = json.loads(args.station.read_text())
    src = SEAT.corrected_source()
    _, programs = PAWPROOF.load(SIDE.CANDIDATE, src)
    sets = SIDE.PAIRPROOF.classes(src)
    review = {"renderer_sha256": SRC.sha(Path(__file__)), "station_sha256": SRC.sha(args.station), "images_sha256": {}}
    for label, folder in (("tread", "tread-t3"), ("sill", "sill-t6")):
        (args.out / folder).mkdir(parents=True)
        review["images_sha256"][folder] = render(src, sets, programs, record["sites"][label], args.out / folder)
    (args.out / "review.json").write_text(json.dumps(review, indent=2) + "\n")
    print(json.dumps(review["images_sha256"], indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
