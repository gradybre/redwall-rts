#!/usr/bin/env python3
"""Review images for the tool-free stair gaits (ADR 1217 M7). A review aid, not a proof.

The candidate's clips are rebuilt (`author_claw_stairs.author` with its recorded arm swing) and checked against the
stored clips byte for byte, then drawn on the derived flight (`prove_descent_flight.derivation`, and `bottom` with
seven rows for the sill) with the accepted painter renderer. Paws brown, feet blue, timber and earth green.

- `tread/overview.png`: the descent T1 -> T2 at key 18 (the right leg lifting past the right paw, where the
  pick-free arm needed its swing), front, side and top.
- `tread/motion.png`: side views of the descent T1 -> T2 at keys 0, 15, 30, 45, 60, 75, 90, then the ascent T2 -> T1
  at keys 0, 30, 60, 90.
- `sill/overview.png`, `sill/motion.png`: the same for the descent T5 -> T6 (the sill) and T6 -> the floor.

    $PY .../render_claw_stairs.py <candidate-dir> <out-dir>
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np

import author_claw_stairs as CS
import render_claw_stroke as ONE_RENDER

SEAT, SRC, W = CS.SEAT, CS.SRC, CS.W
R = ONE_RENDER.R
PAW_RGB, FOOT_RGB, GREEN = (196, 120, 96), (90, 120, 200), (60, 110, 60)
FOCUS_KEY = 18
DESCENT_KEYS = (0, 15, 30, 45, 60, 75, 90)
ASCENT_KEYS = (0, 30, 60, 90)


def rebuilt(src: dict, folder: Path) -> dict:
    """The stored clips, checked against a rebuild."""
    record = json.loads((folder / "candidate.json").read_text())
    cases = CS.author(src, record["arm_swing_degrees"])
    for gait, case in cases.items():
        W.require(SRC.sha(folder / f"{gait}.npz") == record["clips"][gait]["sha256"], "CLAW_STAIR_RENDER_PIN")
        with np.load(folder / f"{gait}.npz", allow_pickle=False) as image:
            W.require(image["matrices"].tobytes() == case["matrices"][:, :24].tobytes(), "CLAW_STAIR_RENDER_REBUILD")
    return cases


def placed(src: dict, case: dict, frame: int, segment: dict, tint: list) -> list:
    """The body at one key, on its segment (the root track and the segment's exact cardinal turn)."""
    body = dict(case, matrices=case["matrices"][:, :24])
    points = SRC.I.points_at(body, src["body"], frame) + np.asarray(case["stair_recipe"]["root_u"][frame], float)
    quarter = segment["quarter_turn"]
    x, z = points[:, 0].copy(), points[:, 2].copy()
    if quarter == 2:
        x, z = -x, -z
    W.require(quarter in (0, 2), "CLAW_STAIR_RENDER_TURN")
    world = np.stack((x, points[:, 1], z), axis=1) + np.asarray(segment["origin_u"], float)
    return [(world, src["triangles"], tint)]


def near(solids: list, segment: dict) -> list:
    """Solids within reach of one segment, outlined green."""
    z = segment["origin_u"][2]
    return [(box, GREEN) for box in solids if box[2] < z + 1200 and box[5] > z - 1800 and box[0] > -2000 and box[3] < 2000
            and box[4] > segment["origin_u"][1] - 1100]


def render_site(src: dict, cases: dict, solids: list, down: dict, up: dict | None, label: str, out: Path,
                tint: list) -> dict:
    """Both images for one site."""
    out.mkdir(parents=True)
    boxes = near(solids, down)
    focus = np.asarray(down["origin_u"], float) + np.array([0., 350., -256.])
    note = f"UNQUALIFIED review aid (ADR 1217 M7): {label}; feet blue, paws brown; green: decks, posts and trench."
    key = placed(src, cases["descent"], FOCUS_KEY, down, tint)
    overview = [R.panel((570, 530), f"{view} (descent key {FOCUS_KEY})", key, boxes, axes, .4, focus)
                for view, axes in R.VIEWS]
    ONE_RENDER.sheet((570, 530), overview, 3, note).save(out / "overview.png")
    side = R.VIEWS[1][1]
    panels = [R.panel((480, 450), f"Side: descent key {k}", placed(src, cases["descent"], k, down, tint), boxes, side, .3,
                      focus) for k in DESCENT_KEYS]
    if up is not None:
        panels += [R.panel((480, 450), f"Side: ascent key {k}", placed(src, cases["ascent"], k, up, tint),
                           near(solids, up), side, .3, focus) for k in ASCENT_KEYS]
    else:
        panels.append(R.panel((480, 450), "Side: descent key 90 (on the sill)", placed(src, cases["descent"], 90, down, tint),
                              boxes, side, .3, focus))
    ONE_RENDER.sheet((480, 450), panels, 4, note).save(out / "motion.png")
    return {name: SRC.sha(out / name) for name in ("overview.png", "motion.png")}


def main() -> int:
    """Render the representative tread and the sill."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "CLAW_STAIR_RENDER_EXISTS")
    src = SEAT.corrected_source()
    cases = rebuilt(src, args.candidate)
    sets = CS.PAIRPROOF.classes(src)
    tint = [PAW_RGB if p else FOOT_RGB if f else R.BODY_RGB for p, f in zip(sets["paw"], sets["any_foot"])]
    spec = CS.FLIGHT.read_prefix()
    flight = CS.FLIGHT.derivation(spec)
    down = CS.FLIGHT.segments(flight["decks"], "descent")
    up = CS.FLIGHT.segments(flight["decks"], "ascent")
    bottom_solids, bottom_segments = CS.FLIGHT.bottom(spec, 7)
    digests = {"tread": render_site(src, cases, flight["solids"], down[2], up[3], "descent T1 -> T2, ascent T2 -> T1",
                                    args.out / "tread", tint),
               "sill": render_site(src, cases, bottom_solids, bottom_segments[0], None, "descent T5 -> T6 (the sill)",
                                   args.out / "sill", tint)}
    (args.out / "review.json").write_text(json.dumps({"images_sha256": digests, "renderer_sha256": SRC.sha(Path(__file__)),
                                                      "candidate_sha256": SRC.sha(args.candidate / "candidate.json")},
                                                     indent=2) + "\n")
    print(json.dumps(digests, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
