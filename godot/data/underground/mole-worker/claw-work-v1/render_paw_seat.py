#!/usr/bin/env python3
"""Review images for one paw handling/seating candidate (ADR 1217 step 2). A review aid, not a proof.

Drawn with the accepted painter renderer (`render_tread_install.panel`), both paws tinted, the T0 installation's
fixture outlined (green: L0 deck and supports; orange: the T0 bearer being fitted):

- `overview.png`: the tap's deepest key (the paws pressing the bearer) from the front, the side and the top.
- `hands.png`: both paws on the bearer, ×1.3: the handling seat (row 1) and the tap's deepest key (row 2).
- `motion.png`: side views of the handling entry (keys 0, 15, 22, 30) and the tap (keys 0, 8, 16, 24).

    $PY .../render_paw_seat.py <candidate-dir> <out-dir>
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np

import prove_paw_seat as PROOF
import render_claw_stroke as ONE_RENDER

SEAT, SRC, W = PROOF.SEAT, PROOF.SRC, PROOF.W
R = ONE_RENDER.R
DEEPEST_TAP = 16  # The tap's 17 lowering keys end at key 16, 2 u below the top.
FOCUS = np.array([0., 300., -200.])


def prisms() -> list:
    """The T0 installation's solids: supports green, the bearer orange."""
    fixture = PROOF.fixtures()[1]
    target = fixture["workpiece_solid"]
    return [(box, (190, 120, 20) if at == target else (60, 110, 60)) for at, box in enumerate(fixture["solids_u"])]


def paw_mask(src: dict) -> np.ndarray:
    """Triangles with any hand weight."""
    geometry = src["body"]["geometry"][0]
    return np.any(np.isin(geometry["ids"], [15, 19]) & (geometry["weights"] > 0), axis=1)[src["triangles"]].any(axis=1)


def render(src: dict, programs: dict, out: Path) -> dict:
    """Write the three images and return their digests."""
    paw, boxes = paw_mask(src), prisms()
    seat_work, seat_entry = programs["seat"][0], programs["seat"][1]
    tap = programs["tap"][0]
    note = "UNQUALIFIED authoring preview (ADR 1217 paw seating); orange: T0 bearer; green: L0 deck and supports."
    deepest = ONE_RENDER.meshes_at(src, tap, DEEPEST_TAP, paw)
    overview = [R.panel((570, 530), f"{name} (tap key {DEEPEST_TAP}, paws pressing)", deepest, boxes, axes, .5, FOCUS)
                for name, axes in R.VIEWS]
    ONE_RENDER.sheet((570, 530), overview, 3, note).save(out / "overview.png")
    anchor = np.array([0., 128., -448.])
    hands = [R.panel((533, 410), f"{label}: {name} (x1.3)", ONE_RENDER.meshes_at(src, case, frame, paw), boxes,
                     axes, 1.3, anchor)
             for label, case, frame in (("handling seat", seat_work, 0), (f"tap key {DEEPEST_TAP}", tap, DEEPEST_TAP))
             for name, axes in R.VIEWS]
    ONE_RENDER.sheet((533, 410), hands, 3, "Both paws tinted. Zoomed review aid only.").save(out / "hands.png")
    keys = [(seat_entry, 0, "handling entry 0 (ready)"), (seat_entry, 15, "handling entry 15"),
            (seat_entry, 22, "handling entry 22"), (seat_entry, 30, "handling entry 30 = seat"),
            (tap, 0, "tap 0 (raised 80 u)"), (tap, 8, "tap 8"), (tap, 16, "tap 16 (pressed)"), (tap, 24, "tap 24")]
    motion = [R.panel((480, 450), "Side: " + title, ONE_RENDER.meshes_at(src, case, frame, paw), boxes,
                      R.VIEWS[1][1], .45, FOCUS) for case, frame, title in keys]
    ONE_RENDER.sheet((480, 450), motion, 4, note).save(out / "motion.png")
    return {name: SRC.sha(out / name) for name in ("overview.png", "hands.png", "motion.png")}


def main() -> int:
    """Render one candidate's review images."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "PAW_SEAT_RENDER_EXISTS")
    src = SEAT.corrected_source()
    _, programs = PROOF.load(args.candidate, src)
    args.out.mkdir(parents=True)
    digests = render(src, programs, args.out)
    review = {"images_sha256": digests, "renderer_sha256": SRC.sha(Path(__file__)),
              "candidate_sha256": SRC.sha(args.candidate / "candidate.json"),
              "proof_sha256": SRC.sha(args.candidate / "proof.json")}
    (args.out / "review.json").write_text(json.dumps(review, indent=2) + "\n")
    print(json.dumps(digests))
    return 0


if __name__ == "__main__":
    sys.exit(main())
