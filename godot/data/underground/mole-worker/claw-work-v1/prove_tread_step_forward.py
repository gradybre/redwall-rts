#!/usr/bin/env python3
"""The tool-free 141 u step forward on a tread, from the fitting station back to the turn's start. Source only.

After fitting T_{k+1}, the fitter returns from the tread station (310 u behind T_k's far edge) to 169 u behind it,
where ADR 1142's stepped half-turn (candidate 6, re-derived tool-free in `author_claw_turn.py`) begins. This is
the step back of `prove_tread_step_back.py` in the other direction, by the same recipe: ADR 1164's finite short
step on the approved claw walk, two ticks at 3277 u/s, the walk sampled **forward** from key 0 (keys 0, 1, 2),
between READY fades.

Proofs and fixture are the step back's (root anywhere on the path, swept solids, support on the shrunk deck,
self-clearance), with one solid added: T_{k+1} is now fitted, so the next tread and everything under it is a
superset prism ahead of and below the far edge.

    $PY .../prove_tread_step_forward.py <out-dir>
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import json
import math
from pathlib import Path
import sys

import numpy as np

import prove_tread_step_back as SB

SEAT, SRC, W, ONE, PAIRPROOF = SB.SEAT, SB.SRC, SB.W, SB.ONE, SB.PAIRPROOF
NEXT_TREAD_LABEL = "T_{k+1} fitted: its deck and everything under it (superset)"


def step_case(src: dict, walk: dict, span: int) -> tuple:
    """READY -> walk keys sampled forward for the movement ticks -> READY."""
    moves = math.ceil(Fraction(span * SB.REF.HZ, SB.REF.PACE))
    keys = list(range(moves + 1))
    matrices = [src["stand"]["matrices"][SRC.READY_FRAME]] + [walk["matrices"][k] for k in keys] + \
        [src["stand"]["matrices"][SRC.READY_FRAME]]
    grounding = [src["stand"]["grounding"][SRC.READY_FRAME]] + [walk["grounding"][k] for k in keys] + \
        [src["stand"]["grounding"][SRC.READY_FRAME]]
    count = len(matrices)
    case = {"id": "mole_worker.claw_step_forward.v1", "frames": count, "matrices": np.asarray(matrices, np.float32),
            "grounding": np.asarray(grounding, np.float32), "source_loop_mode": 0,
            "source_duration_s": Fraction(count - 1, 30), "duration_q16": (count - 1) * 65536}
    return case, {"moves": moves, "walk_keys": keys, "pace_u_per_s": SB.REF.PACE, "hz": SB.REF.HZ}


def fixture(span: int) -> dict:
    """The step back's fixture plus the fitted next tread."""
    ground = SB.fixture(span)
    deck = ground["solids_u"][0]
    floor = SB.TREADSEAT.TREAD.FLOOR_LOCAL
    following = [deck[0], floor, deck[2] - SB.TREADSEAT.TREAD.DECK_DEPTH, deck[3], -128, deck[2]]
    return dict(ground, solids_u=ground["solids_u"] + [following], labels=ground["labels"] + [NEXT_TREAD_LABEL],
                swept_u=ground["swept_u"] + [following[:5] + [following[5] + span]])


def derive(out: Path) -> dict:
    """Build, prove, write."""
    src = SEAT.corrected_source()
    sets = PAIRPROOF.classes(src)
    where = SB.distances()
    walk = SB.walk_clip()
    case, timing = step_case(src, walk, where["span_u"])
    ground = fixture(where["span_u"])
    keys, padding, _ = ONE.hulls(src, case)
    result = {"world": SB.world(src, case, ground, sets), "self": PAIRPROOF.self_rows(src, case, keys, padding, sets, None)}
    clear = result["world"]["clear"] and result["self"]["clear"]
    out.mkdir(parents=True)
    W.write_case(out / "step_forward.npz", case)
    record = {"schema": 1, "decision": ["1209", "1217"], "motion": "tool-free 141 u step forward on a tread",
              "recipe": "ADR 1164 finite short step on the approved claw walk, forward; no authored key",
              **where, **timing, "clip_sha256": SRC.sha(out / "step_forward.npz"), "walk_sha256": SRC.sha(SB.WALK),
              "stand_sha256": src["stand_sha256"], "fixture": ground, "clear": bool(clear), **result,
              "next_tread_fitted": True, "production_qualified": False,
              "producer_sources": {str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p) for p in
                                   (Path(__file__), Path(SB.__file__))}}
    (out / "step_forward.json").write_text(json.dumps(record, indent=1, default=str) + "\n")
    return record


def main() -> int:
    """Derive and prove once."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "STEP_FORWARD_OUTPUT_EXISTS")
    record = derive(args.out)
    print(json.dumps({"clear": record["clear"], "walk_keys": record["walk_keys"],
                      "world_unresolved": len(record["world"]["unresolved"]),
                      "fade_without_witness": [f["interval"] for f in record["world"]["ready_fade_without_contact_witness"]],
                      "self": record["self"]["clear"]}))
    return 0 if record["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
