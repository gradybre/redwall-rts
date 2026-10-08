#!/usr/bin/env python3
"""Tool-free stair gaits (ADR 1217 M7, ADR 1209): the accepted 128 u descent and ascent on the claw ready. Source only.

The accepted gaits (`stair-descent-v7` case 0, `stair-motion-v15` case 0, ADRs 1139/1142) move only the leg bones
1-8 of the compact ready key 8 along their recipe's foot and root tracks; every other joint keeps the ready key.
The pick is part of that ready. This tool re-runs **the same authors with the same recipe values** on the
approved tool-free ready: key 8 of the corrected stand (step 1c), open paw, no tool. So the legs follow the
accepted tracks, and the upper body is the approved tool-free ready, the pose rows 30/31/42 stand in.

**Unchanged:** `author_stair_descent.source_case` (advance 256, drop 128, leading foot 360, guide 0, toe 20°) and
`author_stair_motion.source_case` (lead advance 68, lead lift 50), as their candidates record. The authors expect a
25-slot palette (24 body bones and the tool); the claw palette has 24 slots, so a 25th identity slot is appended for
authoring and stripped from the result. No body vertex is bound to it.

**The one adjustment the proofs need.** With the pick gone the right paw hangs by the right thigh (step 1c), and
the accepted leg lift brushes it. So the right upper arm swings further out by step 1c's own swing
(`author_stand_walk_v2.swung`, same axis and sign), eased in and out over half a phase so both ready endpoints stay
exactly the ready key. The angle is searched as step 1c's was: bisection over whole degrees in [0, 30], with one
degree less shown to fail. The left arm is clear at 0.

**Proofs** (the accepted provers, unchanged except their part census):

1. **Two-deck terrain** (`prove_stair_terrain.prove`): every triangle against both decks, with continuous
   full-foot contact witnesses per planted foot.
2. **The flight** (`prove_stair_sequence.prove` over `prove_descent_flight.derivation`): L0 to T5 and back, with the
   risers, treads and trench, both gaits.
3. **The bottom** (`prove_descent_flight.bottom`, seven rows): T5 to T6 (the sill) to the floor, descent.
4. **Self-clearance** (`prove_claw_pair.self_rows`): each arm against the rest (legs included) and arm against
   arm, every interval.

The provers check `len(parts) == 2` (body and tool) inside a combined guard. A tool-free source has one part, so
that one census is replaced by this tool's own check (one body part, 24 binds); the other conditions in the same
guard are re-checked here first. This follows `author_tread_install._WiderPoseInput`'s precedent.

    $PY .../author_claw_stairs.py <out-dir>
"""
from __future__ import annotations

import argparse
import contextlib
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np

import author_paw_seat as SEAT
import prove_claw_pair as PAIRPROOF

W, SRC, ONE = SEAT.W, SEAT.SRC, PAIRPROOF.ONE
PROOF = SRC.I.PROOF


def load(name: str, path: Path):
    """Import an accepted module by path."""
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


DESC = load("claw_stair_descent", PROOF / "author_stair_descent.py")
ASC = DESC.A
TERRAIN = load("claw_stair_terrain", PROOF / "prove_stair_terrain.py")
SEQ = load("claw_stair_sequence", PROOF / "prove_stair_sequence.py")
FLIGHT = load("claw_stair_flight", PROOF / "prove_descent_flight.py")
P = TERRAIN.P
RECIPES = {"descent": {"rise": -128, "advance": 256, "drop": 128, "lead_foot": 360, "guide": 0., "toe_degrees": 20},
           "ascent": {"rise": 128, "lead_advance": 68, "lead_lift": 50}}
ACCEPTED = {"descent": "stair-descent-v7/candidate.json", "ascent": "stair-motion-v15/candidate.json"}
CENSUS_CODES = ("STEP_TERRAIN_PROGRAM", "SEQUENCE_PROGRAM")
STANDV2 = load("claw_stand_walk_v2", SRC.MOLE / "stand-walk-v2/author_stand_walk_v2.py")
ENVELOPE_FRAMES = ASC.PHASE_FRAMES // 2  # The swing eases in and out over half a gait phase.
MAX_SWING = STANDV2.MAX_DEGREES


def accepted_recipes() -> dict:
    """The recipe values as the accepted candidates record them; this tool's constants must match."""
    rows = {}
    for gait, path in ACCEPTED.items():
        record = json.loads((PROOF / path).read_text())
        rows[gait] = next(r for r in record["attempts"] if r["status"] == "SOURCE_CANDIDATE_ONLY" and
                          r["rise_u"] == RECIPES[gait]["rise"])
    d, a = rows["descent"], rows["ascent"]
    W.require((d["root_advance_u"], d["root_drop_u"], d["leading_foot_advance_u"], d["guide_magnitude"],
               d["toe_first_degrees"]) == (256, 128, 360, 0., 20) and
              (a["lead_root_advance_u"], a["lead_root_lift_u"]) == (68, 50), "CLAW_STAIR_RECIPE_DRIFT")
    return rows


def ready_source(src: dict) -> tuple:
    """The claw ready as the accepted authors read a source: 25 slots, body part, rig and topology."""
    matrices = src["stand"]["matrices"]
    W.require(matrices.shape[1:] == (24, 12) and src["body"]["binds"] == 24, "CLAW_STAIR_CENSUS")
    ids = src["body"]["geometry"][0]["ids"]
    W.require(int(ids.max()) < 24, "CLAW_STAIR_SLOT")
    identity = np.array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0], dtype=np.float32)
    padded = np.concatenate([matrices, np.broadcast_to(identity, (len(matrices), 1, 12))], axis=1)
    ready = {"frames": len(matrices), "matrices": padded, "grounding": src["stand"]["grounding"],
             "geometry": [src["body"]]}
    topology = [[src["triangles"]]]
    return ready, topology


def envelope(frame: int) -> float:
    """0 at both ready endpoints, 1 in between, eased over half a phase (the accepted smoothstep)."""
    last = ASC.FRAME_COUNT - 1
    return ASC.smooth(min(1., frame / ENVELOPE_FRAMES)) * ASC.smooth(min(1., (last - frame) / ENVELOPE_FRAMES))


def swing_arms(src: dict, case: dict, degrees: dict) -> dict:
    """Step 1c's outward upper-arm swing (`author_stand_walk_v2.swung`, same axis and sign), scaled per key by
    `envelope`, on top of the corrected ready's own swing. The endpoints keep the ready key exactly."""
    rig = (src["parents"], src["inverse"], src["inverse_inverse"])
    axes = {side: STANDV2.axis_in_parent(src["stand"], rig, STANDV2.UPPER_ARM[side],
                                         STANDV2.outward_sign(src["stand"], rig, side)) for side in degrees}
    matrices = case["matrices"].copy()
    for frame in range(case["frames"]):
        share = envelope(frame)
        if share == 0 or not any(degrees.values()):
            continue
        one = {"frames": 1, "matrices": matrices[frame:frame + 1, :24].copy(), "grounding": case["grounding"][frame:frame + 1]}
        moved = STANDV2.swung(one, rig, {side: (value * share, axes[side]) for side, value in degrees.items()})
        matrices[frame, :24] = moved["matrices"][0]
    return dict(case, matrices=matrices)


def self_clear(src: dict, case: dict, sets: dict) -> dict:
    """`prove_claw_pair.self_rows` on the 24-slot clip."""
    body = dict(case, matrices=case["matrices"][:, :24])
    keys, padding, _ = ONE.hulls(src, body)
    return PAIRPROOF.self_rows(src, body, keys, padding, sets, None)


def search(src: dict, base: dict, sets: dict) -> tuple:
    """Per arm, the smallest whole-degree swing that clears both gaits (bisection over [0, 30], as step 1c), with one
    degree less shown to fail. An arm already clear at 0 keeps 0."""
    found, trail = {}, []
    for side in ("right", "left"):
        def clears(value: int) -> bool:
            degrees = dict(found, **{side: value})
            ok = all(self_clear(src, swing_arms(src, case, degrees), sets)[f"{side}_arm_vs_rest"]["clear"]
                     for case in base.values())
            trail.append({"side": side, "degrees": value, "clear": ok})
            print(json.dumps(trail[-1]), file=sys.stderr, flush=True)
            return ok
        if clears(0):
            found[side] = 0
            continue
        low, high = 0, MAX_SWING
        W.require(clears(high), "CLAW_STAIR_NO_SWING")
        while high - low > 1:
            middle = (low + high) // 2
            low, high = (low, middle) if clears(middle) else (middle, high)
        found[side] = high
    return found, trail


def author(src: dict, degrees: dict | None = None) -> dict:
    """Both gaits on the claw ready, 25-slot (authoring/proof width), with the arm swing applied."""
    ready, topology = ready_source(src)
    d, a = RECIPES["descent"], RECIPES["ascent"]
    descent = DESC.source_case(ready, src["topology"], topology, d["rise"], d["advance"], d["drop"], d["lead_foot"],
                               d["guide"], d["toe_degrees"])
    ascent = ASC.source_case(ready, src["topology"], a["rise"], a["lead_advance"], a["lead_lift"], topology)
    for case in (descent, ascent):
        case["geometry"] = [src["body"]]
    cases = {"descent": descent, "ascent": ascent}
    if degrees:
        cases = {gait: swing_arms(src, case, degrees) for gait, case in cases.items()}
    for case in cases.values():
        for end in (0, -1):
            W.require(np.array_equal(case["matrices"][end, :24], src["stand"]["matrices"][SRC.READY_FRAME]),
                      "CLAW_STAIR_READY")
    return cases


@contextlib.contextmanager
def body_only():
    """Replace only the part census of the two provers' combined program guard (checked by `program_ok`)."""
    modules = {id(m): m for m in (TERRAIN.P, SEQ.P, SEQ.T.P)}.values()
    saved = [(m, m.require) for m in modules]

    def guard(accepted):
        def require(value, code):
            if code not in CENSUS_CODES:
                accepted(value, code)
        return require
    for module, accepted in saved:
        module.require = guard(accepted)
    try:
        yield
    finally:
        for module, accepted in saved:
            module.require = accepted


def program_ok(case: dict, parts: list) -> None:
    """The guard's other conditions, and this tool's census: one body part with 24 binds."""
    W.require(case["source_loop_mode"] == 0 and case["frames"] == ASC.FRAME_COUNT and
              P.rendered_timing(case)[1] == (ASC.FRAME_COUNT - 1) * 65536 and
              len(parts) == 1 and parts[0]["binds"] == 24, "CLAW_STAIR_PROGRAM")


def summary(result: dict) -> dict:
    """Short form of a prover result."""
    return {"clear": result["clear"], "unresolved": len(result["unresolved"]), "pairs": result.get("pairs"),
            "first": result["unresolved"][:4]}


def prove(src: dict, cases: dict, out: Path) -> dict:
    """Terrain, flight, bottom and self proofs."""
    parts, topology = [src["body"]], [[src["triangles"]]]
    roots = SRC.ROOT_BOUNDS
    spec = FLIGHT.read_prefix()
    flight = FLIGHT.derivation(spec)
    SEQ.MAX_SEGMENTS, SEQ.MAX_SOLIDS = FLIGHT.MAX_SEGMENTS, FLIGHT.MAX_SOLIDS
    report = {}
    for gait, case in cases.items():
        program_ok(case, parts)
        recipe = case["stair_recipe"]
        with body_only():
            terrain = TERRAIN.prove(case, parts, topology, roots, recipe)
        terrain = json.loads(json.dumps(terrain, default=str))  # The sequence prover reads its base as stored JSON.
        rows = {"terrain": terrain}
        if terrain["clear"]:
            fixture = {"schema": 1, "engineering_only": True, "rise_u": recipe["rise_u"], "solids_u": flight["solids"],
                       "segments": FLIGHT.segments(flight["decks"], gait)}
            with body_only():
                rows["flight"] = SEQ.prove(case, parts, topology, roots, recipe, terrain, fixture)
            if gait == "descent":
                solids, segments = FLIGHT.bottom(spec, 7)
                bottom = {"schema": 1, "engineering_only": True, "rise_u": recipe["rise_u"], "solids_u": solids,
                          "segments": segments}
                with body_only():
                    rows["bottom"] = SEQ.prove(case, parts, topology, roots, recipe, terrain, bottom)
        rows["self"] = self_clear(src, case, PAIRPROOF.classes(src))
        report[gait] = rows
        print(json.dumps({gait: {k: (v["clear"] if isinstance(v, dict) and "clear" in v else v)
                                 for k, v in rows.items()}}), flush=True)
    return report


def main() -> int:
    """Author, write the clips and prove."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "CLAW_STAIR_OUTPUT_EXISTS")
    accepted = accepted_recipes()
    src = SEAT.corrected_source()
    swing, trail = search(src, author(src), PAIRPROOF.classes(src))
    cases = author(src, swing)
    args.out.mkdir(parents=True)
    clips = {}
    for gait, case in cases.items():
        stripped = dict(case, matrices=case["matrices"][:, :24].copy())
        W.write_case(args.out / f"{gait}.npz", stripped)
        clips[gait] = {"id": case["id"], "frames": case["frames"], "sha256": SRC.sha(args.out / f"{gait}.npz"),
                       "recipe": {k: v for k, v in case["stair_recipe"].items() if not isinstance(v, list)}}
    report = prove(src, cases, args.out)
    clear = all(all(v["clear"] for v in rows.values() if isinstance(v, dict) and "clear" in v)
                for rows in report.values())
    record = {"schema": 1, "decision": ["1217", "1209"], "motion": "M7 tool-free stair gaits",
              "accepted_recipes": {g: {k: v for k, v in r.items() if not isinstance(v, list)} for g, r in accepted.items()},
              "arm_swing_degrees": swing, "swing_search": trail, "swing_envelope_frames": ENVELOPE_FRAMES,
              "clips": clips, "clear": bool(clear), "stand_sha256": src["stand_sha256"], "source_pins": src["pins"],
              "production_qualified": False,
              "producer_sources": {str(Path(p).resolve().relative_to(SRC.ROOT)): SRC.sha(Path(p)) for p in
                                   (__file__, DESC.__file__, ASC.__file__, TERRAIN.__file__, SEQ.__file__,
                                    FLIGHT.__file__, PAIRPROOF.__file__, STANDV2.__file__)}}
    (args.out / "candidate.json").write_text(json.dumps(record, indent=2, default=str) + "\n")
    (args.out / "proof.json").write_text(json.dumps(report, indent=1, default=str) + "\n")
    print(json.dumps({"clear": clear}))
    return 0 if clear else 2


if __name__ == "__main__":
    sys.exit(main())
