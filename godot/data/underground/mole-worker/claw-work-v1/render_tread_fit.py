#!/usr/bin/env python3
"""Review images for one tread fitting candidate (ADR 1217 step 2d). A review aid, not a proof.

The candidate's clips are rebuilt from its recipe (`prove_tread_fit.site` + `author_paw_seat.author`) and checked
against the stored clips byte for byte, then drawn in the tread station's frame (ADR 1209's 310 u station, yaw 0)
with the accepted painter renderer at the standard views. Paws brown, feet blue; green: T_{k-1}'s deck, the deck
behind (riser) and their supports; orange: the bearer; grey: the trench side walls.

Per site (`tread/`, `sill/`):

- `overview.png`: the tap's deepest key from the front, the side and the top.
- `motion.png`: side views of handling entry keys 0, 15, 22 and 30 (the seat) and tap keys 0, 8, 16 and 24.

    $PY .../render_tread_fit.py <candidate-dir> <out-dir>
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np

import prove_tread_fit as FIT
import render_claw_stroke as ONE_RENDER

SEAT, SRC, W = FIT.SEAT, FIT.SRC, FIT.W
R = ONE_RENDER.R
PAW_RGB, FOOT_RGB = (196, 120, 96), (90, 120, 200)
GREEN, ORANGE, GREY = (60, 110, 60), (190, 120, 20), (140, 140, 140)
DEEPEST_TAP = 16
FOCUS = np.array([0., 300., -120.])


def programs_of(src: dict, folder: Path) -> tuple:
    """The stored clips of one site, checked against a rebuild."""
    record = json.loads((folder / "candidate.json").read_text())
    where, _ = FIT.site(record["recipe"], record["bearer_top_u"])
    programs = SEAT.author(src, {k: record["recipe"][k] for k in SEAT.DOMAINS}, where)
    for name, cases in programs.items():
        for part, case in zip(FIT.PARTS, cases):
            path = folder / f"{name}_{part}.npz"
            W.require(SRC.sha(path) == record["clips"][f"{name}_{part}"]["sha256"], "TREAD_FIT_CLIP_PIN")
            with np.load(path, allow_pickle=False) as image:
                W.require(image["matrices"].tobytes() == case["matrices"].tobytes(), "TREAD_FIT_REBUILD")
    return record, programs


def prisms(record: dict) -> list:
    """The fixture's solids, coloured; walls trimmed to the frame."""
    rows = []
    for box, label in zip(record["fixture"]["solids_u"], record["fixture"]["source_labels"]):
        if label.startswith("trench"):
            rows.append(([max(box[0], -1200), box[1], box[2], min(box[3], 1200), box[4], box[5]], GREY))
        else:
            rows.append((box, ORANGE if label.startswith("paid WIP") else GREEN))
    return rows


def render(src: dict, sets: dict, record: dict, programs: dict, out: Path) -> dict:
    """Write both images for one site."""
    tint = [PAW_RGB if p else FOOT_RGB if f else R.BODY_RGB for p, f in zip(sets["paw"], sets["any_foot"])]
    at = lambda case, frame: [(SRC.I.points_at(case, src["body"], frame), src["triangles"], tint)]
    boxes, seat_entry, tap = prisms(record), programs["seat"][1], programs["tap"][0]
    label = "T6 sill (bearer top 64 u)" if record["bearer_top_u"] == 64 else "T1...T5 (bearer top 128 u)"
    note = (f"UNQUALIFIED review aid (ADR 1217 step 2d): {label}; work height {record['work_plane_u']} u; "
            "feet blue, paws brown; green: decks; orange: bearer; grey: trench walls.")
    overview = [R.panel((570, 530), f"{view} (tap key {DEEPEST_TAP}, paws lowest)", at(tap, DEEPEST_TAP), boxes, axes,
                        .5, FOCUS) for view, axes in R.VIEWS]
    ONE_RENDER.sheet((570, 530), overview, 3, note).save(out / "overview.png")
    keys = [(seat_entry, 0, "handling entry 0 (ready)"), (seat_entry, 15, "handling entry 15"),
            (seat_entry, 22, "handling entry 22"), (seat_entry, 30, "handling entry 30 = seat"),
            (tap, 0, "tap 0 (raised 80 u)"), (tap, 8, "tap 8"), (tap, 16, "tap 16 (lowest)"), (tap, 24, "tap 24")]
    motion = [R.panel((480, 450), "Side: " + title, at(case, frame), boxes, R.VIEWS[1][1], .45, FOCUS)
              for case, frame, title in keys]
    ONE_RENDER.sheet((480, 450), motion, 4, note).save(out / "motion.png")
    return {name: SRC.sha(out / name) for name in ("overview.png", "motion.png")}


def main() -> int:
    """Render both sites of one candidate."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "TREAD_FIT_RENDER_EXISTS")
    src = SEAT.corrected_source()
    sets = FIT.PAIRPROOF.classes(src)
    review = {"renderer_sha256": SRC.sha(Path(__file__)), "summary_sha256": SRC.sha(args.candidate / "summary.json"),
              "images_sha256": {}}
    for site in FIT.SITES:
        record, programs = programs_of(src, args.candidate / site)
        (args.out / site).mkdir(parents=True)
        review["images_sha256"][site] = render(src, sets, record, programs, args.out / site)
    (args.out / "review.json").write_text(json.dumps(review, indent=2) + "\n")
    print(json.dumps(review["images_sha256"], indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
