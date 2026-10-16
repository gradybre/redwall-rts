#!/usr/bin/env python3
"""Proofs of the basic stair carry (decision 1981 §1): the accepted provers, unchanged, with the load as a part.

The clips are re-authored and checked byte for byte against `evidence/clips-v1/` first. Then, for wood and stone:

| Clip | Proofs |
|---|---|
| `descent` | two-deck terrain (`prove_stair_terrain`); the flight L0 -> T5 and the bottom T5 -> T6 -> floor (`prove_stair_sequence` over `prove_descent_flight`) |
| `ascent` | terrain; the flight T5 -> L0; the bottom floor -> T6 -> T5 (`prove_descent_flight.segments`' ascent rule extended by the sill and the floor) |
| `approach` | the handoff prover (`prove_stair_handoffs`) on L0 (the bottom fixture as it stands) and on the floor (the fixture translated so F stands at the approach's start, the floor slab as its standing deck) |
| `retreat` | the handoff prover on L0 |
| `turn` | the handoff prover on the floor (the fixture translated so F stands at A on T0, the floor slab as its deck) |
| `back_up` | the approach's proofs: it is the approach's exact reverse, so every rendered interval is the same pair of keys |
| every clip | arm self-clearance (`prove_claw_pair.self_rows`); body against load and the continuous two-hand grip (`prove_loaded_gait.prove`); for stone, exact star containment at every key (`stone_geometry.solid_inside`) |

The empty floor end: the walk-off on the floor (handoff prover) and self-clearance; claw row 55 (the half-turn) on
the floor; claw row 54 (the ascent) floor -> T6 -> T5. The claw clips are rebuilt from their own authors and checked
against their stored bytes.

The handoff prover's two pick-era guards are replaced by the claw turn's own checks (`author_claw_turn.claw_guards`),
as step 5b did. The terrain and sequence provers take the load in the tool's slot natively; the empty and claw runs
use M7's one-part census (`author_claw_stairs.body_only`).

    $PY .../prove_stair_carry.py <clips-dir> <out.json>
"""
from __future__ import annotations

import argparse
import contextlib
import json
from pathlib import Path
import sys

import numpy as np

import author_stair_carry as AUTHOR
import stair_carry_source as SC

CS, SRC, W, TURN, PH, AH = SC.CS, SC.SRC, SC.W, AUTHOR.TURN, AUTHOR.PH, AUTHOR.AH
import prove_loaded_gait as LGP  # noqa: E402  (haul-handling-v1, on the path through SC)
import prove_stone_star as STAR  # noqa: E402
import stone_geometry as STONE_GEOMETRY  # noqa: E402

FLOOR_SLAB, SILL, T5_DECK = 77, 82, 66
FIXTURES = {"L0": ((0, 0, 0), (0, 0)), "floor_approach": ((0, 1024, 4439), (0, FLOOR_SLAB)),
            "floor_turn": ((0, 896, 3584), (7, FLOOR_SLAB))}
HANDOFF_RUNS = {"approach": ("L0", "floor_approach"), "retreat": ("L0",), "turn": ("floor_turn",)}
FLOOR_ARRIVAL, FLOOR_ASCENT_START = (0, -1024, -5975), (0, -1024, -5801)


def fixture(name: str) -> dict:
    """The bottom fixture (L0 ... T5, the sill, the floor and the seventh row), translated, standing deck swapped."""
    solids, _ = CS.FLIGHT.bottom(CS.FLIGHT.read_prefix(), 7)
    W.require(solids[FLOOR_SLAB] == [-1024, -1152, -7168, 1024, -1024, 0] and solids[SILL][4] == -896,
              "STAIR_CARRY_BOTTOM_FIXTURE")
    shift, (a, b) = FIXTURES[name]
    moved = [[v + shift[k % 3] for k, v in enumerate(box)] for box in solids]
    moved[a], moved[b] = moved[b], moved[a]
    return {"solids_u": moved, "name": name, "shift_u": list(shift), "swapped_indices": [a, b]}


def ascent_bottom() -> list:
    """The ascent's last two segments from the floor: `prove_descent_flight.segments`' ascent rule for j = 7, 6."""
    decks = CS.FLIGHT.derivation(CS.FLIGHT.read_prefix(), 7)["decks"] + [SILL, FLOOR_SLAB]
    start = CS.FLIGHT.ASCENT_START
    return [{"origin_u": [start[0], start[1] - 128 * j, start[2] - 512 * j], "quarter_turn": 2,
             "support_solids": [decks[j + 1], decks[j]]} for j in (7, 6)]


def compact(result: dict) -> dict:
    """The facts later steps read; the exact witnesses stay reproducible from the clips."""
    supports = [{"interval": s["interval"], "foot": s["foot"], "deck": s.get("deck", s.get("primitive")),
                 "vertex": s.get("continuous_contact_vertex", s.get("vertex"))} for s in result.get("supports", [])]
    row = {"clear": bool(result["clear"]), "unresolved": result["unresolved"][:8],
           "unresolved_count": len(result["unresolved"]), "checks": result.get("checks"),
           "pairs": result.get("pairs"), "supports": supports}
    if "fixture_boxes_u" in result:
        row["fixture_boxes_u"] = result["fixture_boxes_u"]
    if result.get("parts") and "full_interval_boxes_program_u" in result["parts"][0]:
        row["interval_boxes_u"] = [p["full_interval_boxes_program_u"] for p in result["parts"]]
    return json.loads(json.dumps(row, default=str))


def gait_proofs(case: dict, parts: list, topology: list, gait: str, one_part: bool) -> dict:
    """Terrain, flight and bottom of one gait."""
    roots, recipe = SRC.ROOT_BOUNDS, case["stair_recipe"]
    CS.SEQ.MAX_SEGMENTS, CS.SEQ.MAX_SOLIDS = CS.FLIGHT.MAX_SEGMENTS, CS.FLIGHT.MAX_SOLIDS
    guard = CS.body_only if one_part else contextlib.nullcontext
    with guard():
        terrain = json.loads(json.dumps(CS.TERRAIN.prove(case, parts, topology, roots, recipe), default=str))
    rows = {"terrain": compact(terrain)}
    if not terrain["clear"]:
        return rows
    spec = CS.FLIGHT.read_prefix()
    solids, bottom = CS.FLIGHT.bottom(spec, 7)
    flight = CS.FLIGHT.derivation(spec)
    plans = {"flight": (flight["solids"], CS.FLIGHT.segments(flight["decks"], gait)),
             "bottom": (solids, bottom if gait == "descent" else ascent_bottom())}
    for name, (fixture_solids, segments) in plans.items():
        ground = {"schema": 1, "engineering_only": True, "rise_u": recipe["rise_u"], "solids_u": fixture_solids,
                  "segments": segments}
        with guard():
            rows[name] = compact(CS.SEQ.prove(case, parts, topology, roots, recipe, terrain, ground))
    return rows


def handoff_proofs(case: dict, parts: list, topology: list, runs: tuple, table: np.ndarray) -> dict:
    """The handoff prover on each named fixture."""
    rows = {}
    for name in runs:
        ground = fixture(name)
        with TURN.claw_guards(case, ground):
            result = PH.prove(case, case["handoff_recipe"], parts, topology, SRC.ROOT_BOUNDS, ground, table)
        rows[name] = dict(compact(result), fixture={k: v for k, v in ground.items() if k != "solids_u"})
    return rows


def load_proofs(case: dict, closure: dict, item: str) -> dict:
    """Body against load, the continuous grip, and (stone) star containment at every key."""
    row = closure["items"][item]
    body, body_tri = closure["body"], closure["body_triangles"].astype(np.int32)
    result = LGP.prove(case, body, row["part"], body_tri, row["triangles"].astype(np.int32),
                       closure["topology"]["rig_binding"], row["witnesses"])
    record = {"non_grip_separation": bool(result["non_grip_separation"]), "pairs": result["pairs"],
              "unresolved": result["unresolved"][:8], "continuous_two_hand_contact":
              bool(result["continuous_two_hand_contact"]), "grip_failures": len(result["grip_failures"])}
    if item == "stone":
        vertices = STAR.solid_vertices(body, closure["topology"])
        inside = [k for k in range(case["frames"]) if STONE_GEOMETRY.solid_inside(
            {"frames": 1, "matrices": case["matrices"][k:k + 1], "grounding": case["grounding"][k:k + 1]},
            body, row["part"], row["triangles"].astype(np.int32), vertices)]
        record["star_contained_keys"] = inside
    record["clear"] = record["non_grip_separation"] and record["continuous_two_hand_contact"] and \
        not record.get("star_contained_keys")
    return record


def self_proof(closure: dict, case: dict, source: dict) -> dict:
    """Arm self-clearance in the body frame."""
    result = CS.self_clear(source, case, CS.PAIRPROOF.classes(source))
    return {k: (v["clear"] if isinstance(v, dict) and "clear" in v else v) for k, v in result.items()}


def item_proofs(closure: dict, item: str, clips: dict, table: np.ndarray) -> dict:
    """Every proof of one item's six clips."""
    row = closure["items"][item]
    parts, topology = [closure["body"], row["part"]], [[closure["body_triangles"]], [row["triangles"]]]
    report = {}
    for name, case in clips.items():
        rows = {"self": self_proof(closure, case, closure["self_source"]), "load": load_proofs(case, closure, item)}
        if name in ("descent", "ascent"):
            rows.update(gait_proofs(case, parts, topology, name, False))
        elif name in HANDOFF_RUNS:
            rows.update(handoff_proofs(case, parts, topology, HANDOFF_RUNS[name], table))
        else:
            rows["reverse_of_approach"] = reversal(case, clips["approach"])
        report[name] = rows
        print(json.dumps({item: {name: clear(rows)}}), flush=True)
    return report


def reversal(case: dict, approach: dict) -> dict:
    """The back-up is the approach's exact reverse: same keys, same rendered intervals, opposite order."""
    same = bool(np.array_equal(case["matrices"], approach["matrices"][::-1]) and
                np.array_equal(case["grounding"], approach["grounding"][::-1]))
    return {"clear": same, "proofs": "the approach's (every interval is the same key pair, reversed in time)"}


def claw_floor(closure: dict, table: np.ndarray) -> dict:
    """The empty floor end: the walk-off, claw row 55 on the floor and claw row 54 floor -> T6 -> T5."""
    claw, empty = closure["claw"], AUTHOR.empty_clips(closure, table)
    walk = empty["empty_walk_off"]
    report = {"empty_walk_off": {"self": self_proof(closure, walk, closure["self_source"]),
                                 **handoff_proofs(walk, [closure["body"]], [[closure["body_triangles"]]],
                                                  ("floor_approach",), table)},
              "empty_back_up": {"reverse_of_approach": reversal(empty["empty_back_up"], walk)}}
    record = json.loads((SC.MOLE / "claw-work-v1/evidence/claw-turn-v1/candidate.json").read_text())
    turn = TURN.author(claw, table, record["arm_swing_degrees"])
    W.require(SRC.sha(SC.MOLE / "claw-work-v1/evidence/claw-turn-v1/turn.npz") == record["clip_sha256"], "CLAW_TURN_PIN")
    with np.load(SC.MOLE / "claw-work-v1/evidence/claw-turn-v1/turn.npz", allow_pickle=False) as image:
        W.require(np.array_equal(image["matrices"], turn["matrices"][:, :24]), "CLAW_TURN_REBUILD")
    report["claw_turn_55"] = handoff_proofs(turn, [claw["body"]], [[claw["triangles"]]], ("floor_turn",), table)
    stairs = json.loads((SC.MOLE / "claw-work-v1/evidence/claw-stairs-v1/candidate.json").read_text())
    ascent = CS.author(claw, stairs["arm_swing_degrees"])["ascent"]
    with np.load(SC.MOLE / "claw-work-v1/evidence/claw-stairs-v1/ascent.npz", allow_pickle=False) as image:
        W.require(np.array_equal(image["matrices"], ascent["matrices"][:, :24]), "CLAW_ASCENT_REBUILD")
    report["claw_ascent_54"] = gait_proofs(ascent, [claw["body"]], [[claw["triangles"]]], "ascent", True)
    del report["claw_ascent_54"]["flight"]  # Already proved by M7; only the bottom is new.
    return report


def clear(rows: dict) -> bool:
    """Every nested proof row is clear."""
    return all(clear(v) if isinstance(v, dict) and "clear" not in v else bool(v["clear"]) if isinstance(v, dict)
               else True for v in rows.values())


def check_stored(folder: Path, clips: dict) -> None:
    """The re-authored clips equal the stored ones byte for byte."""
    for group, cases in clips.items():
        for name, case in cases.items():
            with np.load(folder / group / f"{name}.npz", allow_pickle=False) as image:
                stored = image["matrices"]
                W.require(np.array_equal(stored, case["matrices"][:, :stored.shape[1]]) and
                          np.array_equal(image["grounding"], case["grounding"]), "STAIR_CARRY_REBUILD:" + name)


def main() -> int:
    """Re-author, check, prove and write the report."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("clips", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "STAIR_CARRY_PROOF_EXISTS")
    closure = SC.closure()
    table, basis = AH.read_basis()
    clips = AUTHOR.author(closure, table)
    check_stored(args.clips, clips)
    report = {item: item_proofs(closure, item, clips[item], table) for item in SC.ITEMS}
    report["floor_end"] = claw_floor(closure, table)
    report["clear"] = clear(report)
    record = {"schema": 1, "decision": "1981", "basis": basis, "proofs": report,
              "producer_sources": {str(Path(p).resolve().relative_to(SRC.ROOT)): SRC.sha(Path(p)) for p in
                                   (__file__, AUTHOR.__file__, SC.__file__, PH.__file__, LGP.__file__)},
              "production_qualified": False}
    args.out.write_text(json.dumps(record, indent=1, default=str) + "\n")
    print(json.dumps({"clear": report["clear"]}))
    return 0 if report["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
