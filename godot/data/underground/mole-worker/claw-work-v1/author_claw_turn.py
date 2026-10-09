#!/usr/bin/env python3
"""Tool-free stepped half-turn and reposition on a tread (ADR 1209 step 5, ADR 1142, ADR 1217). Source only.

After fitting T_{k+1} from T_k the fitter must face up the stair. The accepted descent ends 169 u behind the tread's
far edge facing down; the accepted ascent starts 343 u behind it facing up. ADR 1142's candidate 6 ("turn",
`author_stair_handoffs.py`, sha d9a71169...) is exactly that 174 u reposition with a half-turn on T0: 271 keys,
alternating real footfalls with narrowed ankle stations while the pelvis turns. An in-place turn does not fit a
512 u tread (the feet stay on the deck only up to 71 degrees, ADR 1217 step 2c).

**Re-derived, not re-designed.** `author_stair_handoffs.source_case("turn", ...)` runs unchanged, with the same
episode controls, foot stations, knee guidance and sole solve, on the approved tool-free ready (corrected stand key
8, open paw). Only the ready changes. As in M7, a 25th identity slot pads the 24-slot claw palette for the author
and is stripped from the result. If self-clearance needs it, the right upper arm gets M7's approved eased outward
swing (step 1c's swing), with the angle searched by bisection; the endpoints stay the ready key.

**Proofs** (the accepted handoff prover, `prove_stair_handoffs.prove`: every Q16 phase, the finite heading table
range by interval arithmetic and subdivision, every triangle against every solid, full-foot support with a
continuous contact witness). Two of its guards are about the pick-era source and are replaced by this tool's own
checks, as M7 replaced the part census:

- `HANDOFF_PROOF_ENDPOINT` pins the pick ready's digest: here both endpoints must equal the claw ready key exactly;
- `HANDOFF_PROOF_PARTS` pins two parts, 22 solids and the tool's 1,150 triangles: here one body part with 10,209
  triangles, and every solid a valid integer prism.

**Fixture per tread.** The turn happens on T_m (m = 0...5: after fitting T1...T6). The whole derived descent with the
T6 sill and the seventh row (`prove_descent_flight.bottom(spec, 7)`: L0, T0...T5, their bearings, the sill, the
floor, side and end walls) is translated by m pitches, so T_m sits where T0 is in the turn's program frame, and
T_m's deck takes list index 7 (the turn's support primitive). Every solid is kept.

**Self-clearance** (`prove_claw_pair.self_rows`), every interval, in the body frame: the heading and root are
common to the whole body.

    $PY .../author_claw_turn.py <out-dir>
"""
from __future__ import annotations

import argparse
import contextlib
import json
from pathlib import Path
import sys

import numpy as np

import author_claw_stairs as CS

SEAT, SRC, W, ONE, PAIRPROOF = CS.SEAT, CS.SRC, CS.W, CS.ONE, CS.PAIRPROOF
PH = CS.load("claw_turn_handoff_proof", CS.PROOF / "prove_stair_handoffs.py")
AH = PH.A
AH_SHA = "d9a711690e2da698adef2eabb6354e6dbc552fc6e2454b5055d9533c636adbda"
REPLACED = ("HANDOFF_PROOF_ENDPOINT", "HANDOFF_PROOF_PARTS")
TREADS = range(6)  # T0...T5, the decks a fitter turns on after fitting T1...T6.
ENVELOPE = CS.ENVELOPE_FRAMES


def envelope(frame: int, frames: int) -> float:
    """M7's swing envelope for a clip of `frames` keys."""
    last = frames - 1
    return CS.ASC.smooth(min(1., frame / ENVELOPE)) * CS.ASC.smooth(min(1., (last - frame) / ENVELOPE))


def swing(src: dict, case: dict, degrees: dict) -> dict:
    """M7's eased outward upper-arm swing on this clip (endpoints untouched)."""
    if not any(degrees.values()):
        return case
    rig = (src["parents"], src["inverse"], src["inverse_inverse"])
    axes = {s: CS.STANDV2.axis_in_parent(src["stand"], rig, CS.STANDV2.UPPER_ARM[s],
                                         CS.STANDV2.outward_sign(src["stand"], rig, s)) for s in degrees}
    matrices = case["matrices"].copy()
    for frame in range(case["frames"]):
        share = envelope(frame, case["frames"])
        if share == 0:
            continue
        one = {"frames": 1, "matrices": matrices[frame:frame + 1, :24].copy(), "grounding": case["grounding"][frame:frame + 1]}
        matrices[frame, :24] = CS.STANDV2.swung(one, rig, {s: (v * share, axes[s]) for s, v in degrees.items()})["matrices"][0]
    return dict(case, matrices=matrices)


def author(src: dict, table: np.ndarray, degrees: dict | None = None) -> dict:
    """Candidate 6's turn on the claw ready (25-slot), with the swing if any."""
    W.require(SRC.sha(Path(AH.__file__)) == AH_SHA, "CLAW_TURN_AUTHOR_DRIFT")
    ready, topology = CS.ready_source(src)
    case = AH.source_case("turn", ready, src["topology"], topology, table)
    case["geometry"] = [src["body"]]
    case = swing(src, case, degrees or {})
    for end in (0, -1):
        W.require(np.array_equal(case["matrices"][end, :24], src["stand"]["matrices"][SRC.READY_FRAME]), "CLAW_TURN_READY")
    return case


def fixture(m: int) -> dict:
    """The whole derived descent, sill and seventh row, translated so T_m stands where T0 does; T_m's deck at 7."""
    spec = CS.FLIGHT.read_prefix()
    solids, _ = CS.FLIGHT.bottom(spec, 7)
    decks = CS.FLIGHT.derivation(spec, 7)["decks"]
    shift = (0, 128 * m, 512 * m)
    moved = [[v + shift[a % 3] for a, v in enumerate(box)] for box in solids]
    deck = decks[m + 1]  # decks: L0, T0, T1, ...
    moved[7], moved[deck] = moved[deck], moved[7]
    W.require(moved[7] == [-1024, -192, -2560, 1024, -128, -2048], "CLAW_TURN_DECK")
    return {"solids_u": moved, "standing_deck": f"T{m}", "swapped_indices": [7, deck], "shift_u": list(shift)}


@contextlib.contextmanager
def claw_guards(case: dict, ground: dict):
    """Check this tool's replacements, then let the prover run without the two pick-era guards."""
    ready = AH.D.pose_digest({"matrices": case["matrices"][:, :24], "grounding": case["grounding"]}, 0)
    W.require(ready == AH.D.pose_digest({"matrices": case["matrices"][:, :24], "grounding": case["grounding"]},
                                        case["frames"] - 1), "CLAW_TURN_ENDPOINT")
    W.require(all(type(b) is list and len(b) == 6 and all(type(v) is int and abs(v) <= AH.MAX_LOCAL_U for v in b)
                  and all(b[a] < b[a + 3] for a in range(3)) for b in ground["solids_u"]), "CLAW_TURN_SOLIDS")
    accepted = PH.P.require

    def require(value, code):
        if code not in REPLACED:
            accepted(value, code)
    PH.P.require = require
    try:
        yield
    finally:
        PH.P.require = accepted


def self_clear(src: dict, case: dict) -> dict:
    """`prove_claw_pair.self_rows` in the body frame."""
    return CS.self_clear(src, case, PAIRPROOF.classes(src))


def search(src: dict, table: np.ndarray) -> tuple:
    """Smallest whole-degree right-arm swing that clears self-clearance (0 if none is needed), as M7."""
    trail = []

    def clears(value: int) -> bool:
        ok = self_clear(src, author(src, table, {"right": value}))["right_arm_vs_rest"]["clear"]
        trail.append({"side": "right", "degrees": value, "clear": ok})
        print(json.dumps(trail[-1]), file=sys.stderr, flush=True)
        return ok
    if clears(0):
        return {"right": 0}, trail
    low, high = 0, CS.MAX_SWING
    W.require(clears(high), "CLAW_TURN_NO_SWING")
    while high - low > 1:
        middle = (low + high) // 2
        low, high = (low, middle) if clears(middle) else (middle, high)
    return {"right": high}, trail


def main() -> int:
    """Author, write and prove."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "CLAW_TURN_OUTPUT_EXISTS")
    src = SEAT.corrected_source()
    table, basis = AH.read_basis()
    degrees, trail = search(src, table)
    case = author(src, table, degrees)
    args.out.mkdir(parents=True)
    W.write_case(args.out / "turn.npz", dict(case, matrices=case["matrices"][:, :24].copy()))
    recipe = case["handoff_recipe"]
    parts, topology = [src["body"]], [[src["triangles"]]]
    report = {"self": self_clear(src, case)}
    for m in TREADS:
        ground = fixture(m)
        with claw_guards(case, ground):
            result = PH.prove(case, recipe, parts, topology, SRC.ROOT_BOUNDS, ground, table)
        report[f"T{m}"] = {"clear": result["clear"], "checks": result["checks"],
                           "unresolved": result["unresolved"], "supports": len(result.get("supports", [])),
                           "fixture": {k: v for k, v in ground.items() if k != "solids_u"}}
        print(json.dumps({f"T{m}": {"clear": result["clear"], "checks": result["checks"],
                                    "unresolved": len(result["unresolved"])}}), flush=True)
    clear = report["self"]["clear"] and all(report[f"T{m}"]["clear"] for m in TREADS)
    record = {"schema": 1, "decision": ["1209", "1142", "1217"], "motion": "tool-free half-turn and reposition on a tread",
              "author": "author_stair_handoffs.source_case('turn') unchanged (candidate 6)", "author_sha256": AH_SHA,
              "keys": case["frames"], "controls_u": recipe["controls_u"], "heading_controls": recipe["heading_controls"],
              "arm_swing_degrees": degrees, "swing_search": trail, "basis": basis,
              "clip_sha256": SRC.sha(args.out / "turn.npz"), "stand_sha256": src["stand_sha256"],
              "replaced_guards": list(REPLACED), "clear": bool(clear), "production_qualified": False,
              "producer_sources": {str(Path(p).resolve().relative_to(SRC.ROOT)): SRC.sha(Path(p)) for p in
                                   (__file__, AH.__file__, PH.__file__, CS.__file__)}}
    (args.out / "candidate.json").write_text(json.dumps(record, indent=2, default=str) + "\n")
    (args.out / "proof.json").write_text(json.dumps(report, indent=1, default=str) + "\n")
    print(json.dumps({"clear": clear, "swing": degrees}))
    return 0 if clear else 2


if __name__ == "__main__":
    sys.exit(main())
