#!/usr/bin/env python3
"""Review images for the tool-free half-turn on a tread (ADR 1209 step 5). A review aid, not a proof.

The clip is rebuilt (`author_claw_turn.author` with its recorded swing) and checked against the stored clip, then
placed in the turn's program frame by the handoff equation (`author_stair_handoffs.program_points`: body basis
from the key's heading, then the fixed-frame root) on the per-tread fixture of `author_claw_turn.fixture`.
Paws brown, feet blue; green: decks, posts, sill and trench.

Per site (`tread/` on T2, `sill/` on T5, after fitting the sill T6):

- `overview.png`: key 135 (mid-turn) from the front, the side and the top.
- `motion.png`: top views at keys 0, 45, 90, 135, 180, 225 and 270, then a side view at key 270 (facing up the
  stair at the ascent's start).

    $PY .../render_claw_turn.py <candidate-dir> <out-dir>
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np

import author_claw_turn as TURN
import render_claw_stroke as ONE_RENDER

SEAT, SRC, W, AH = TURN.SEAT, TURN.SRC, TURN.W, TURN.AH
R = ONE_RENDER.R
PAW_RGB, FOOT_RGB, GREEN = (196, 120, 96), (90, 120, 200), (60, 110, 60)
KEYS = (0, 45, 90, 135, 180, 225, 270)
FOCUS = np.array([0., 200., -2304.])


def placed(src: dict, case: dict, frame: int, table: np.ndarray, tint: list) -> list:
    """The body at one key in the program frame."""
    row = case["handoff_recipe"]["keys"][frame]
    body = dict(case, matrices=case["matrices"][:, :24])
    points = AH.program_points(SRC.I.points_at(body, src["body"], frame), row["root_u"], row["yaw"], table)
    return [(points, src["triangles"], tint)]


def boxes(m: int) -> list:
    """Fixture solids near the turn."""
    rows = TURN.fixture(m)["solids_u"]
    return [(b, GREEN) for b in rows if b[2] < -1400 and b[5] > -3300 and b[4] > -1100 and b[0] > -1100 and b[3] < 1100]


def render_site(src: dict, case: dict, table: np.ndarray, m: int, label: str, out: Path, tint: list) -> dict:
    """Both images for one tread."""
    out.mkdir(parents=True)
    prisms = boxes(m)
    note = f"UNQUALIFIED review aid (ADR 1209 step 5): half-turn on {label}; feet blue, paws brown; green: timber, trench."
    mid = placed(src, case, 135, table, tint)
    overview = [R.panel((570, 530), f"{view} (turn key 135)", mid, prisms, axes, .4, FOCUS) for view, axes in R.VIEWS]
    ONE_RENDER.sheet((570, 530), overview, 3, note).save(out / "overview.png")
    top = R.VIEWS[2][1]
    panels = [R.panel((480, 450), f"Top: turn key {k}", placed(src, case, k, table, tint), prisms, top, .45, FOCUS)
              for k in KEYS]
    panels.append(R.panel((480, 450), "Side: key 270 (ascent start)", placed(src, case, 270, table, tint), prisms,
                          R.VIEWS[1][1], .35, FOCUS))
    ONE_RENDER.sheet((480, 450), panels, 4, note).save(out / "motion.png")
    return {name: SRC.sha(out / name) for name in ("overview.png", "motion.png")}


def main() -> int:
    """Render T2 and T5."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "CLAW_TURN_RENDER_EXISTS")
    record = json.loads((args.candidate / "candidate.json").read_text())
    src = SEAT.corrected_source()
    table, _ = AH.read_basis()
    case = TURN.author(src, table, record["arm_swing_degrees"])
    W.require(SRC.sha(args.candidate / "turn.npz") == record["clip_sha256"], "CLAW_TURN_RENDER_PIN")
    with np.load(args.candidate / "turn.npz", allow_pickle=False) as image:
        W.require(image["matrices"].tobytes() == case["matrices"][:, :24].tobytes(), "CLAW_TURN_RENDER_REBUILD")
    sets = TURN.PAIRPROOF.classes(src)
    tint = [PAW_RGB if p else FOOT_RGB if f else R.BODY_RGB for p, f in zip(sets["paw"], sets["any_foot"])]
    digests = {"tread": render_site(src, case, table, 2, "T2 (after fitting T3)", args.out / "tread", tint),
               "sill": render_site(src, case, table, 5, "T5 (after fitting the T6 sill)", args.out / "sill", tint)}
    (args.out / "review.json").write_text(json.dumps({"images_sha256": digests, "renderer_sha256": SRC.sha(Path(__file__)),
                                                      "candidate_sha256": SRC.sha(args.candidate / "candidate.json")},
                                                     indent=2) + "\n")
    print(json.dumps(digests, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
