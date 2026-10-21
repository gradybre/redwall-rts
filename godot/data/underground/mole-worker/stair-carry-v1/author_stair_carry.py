#!/usr/bin/env python3
"""The basic stair carry (decision 1981): the accepted stair and handoff authors, run unchanged on the haul hold.

Every accepted stair motion moves only the leg bones 1-8 of one standing key; the hips, the upper body and every
rigid part keep that key exactly. So the same authors, given the haul images' **hold** as their ready, walk the stair
with the arms and the load fixed in the root frame, and the certified grip of the hold holds on every key.

| Clip | Author (unchanged) | Ready | Used on |
|---|---|---|---|
| `approach` | `author_stair_handoffs.source_case("approach")` (ADR 1142), 343 u forward | hold | H (L0, -1536) -> A(L0); F -> F' (the floor walk-off) |
| `descent` | `author_stair_descent.source_case` with M7's recipe (`stair-descent-v7` case 0) | hold | A -> A, L0 ... T6 -> floor |
| `ascent` | `author_stair_motion.source_case` with M7's recipe (`stair-motion-v15` case 0) | hold | floor -> U(T6) ... U(T0) -> U(L0) |
| `turn` | `author_stair_handoffs.source_case("turn")` (ADR 1142 candidate 6) | hold | F -> the floor's ascent start |
| `retreat` | `author_stair_handoffs.source_case("retreat")`, 169 u | hold | U(L0) -> H |
| `back_up` | the `approach` clip, exactly reversed | hold | F' -> F |
| `empty_walk_off`, `empty_back_up` | the approach and its reverse | the corrected stand key 8 | F -> F', F' -> F |

**One proof-configuration correction (decision 1981, P-1981-7 (a), the coordinator's ruling).** The handoff author
declares only the left foot planted at its first and last keys ("Exact ready has the right foot slightly raised"),
which is true of the stand ready and not of the hold, which stands on both feet. Here the planted feet of those two
keys are derived from the ready itself: a foot is planted when one of its vertices lies in the provers' contact cell
(exact source gap in [0, 1) u, `prove_stair_terrain.contact_witness`). The stand ready gives "left only", exactly as
before; the hold gives both feet. The wrapper changes only that recorded mask: no pose, recipe value, foot track,
root track or palette changes, and the accepted `author_stair_handoffs.py` is not edited.

**No arm swing.** M7 needed a 3 degree right-arm swing for the hanging paw; on the hold the arms hold the load, and
a swing would break the grip, so none is applied (the proofs decide).

    $PY .../author_stair_carry.py <out-dir>
"""
from __future__ import annotations

import argparse
import contextlib
import json
from pathlib import Path
import sys

import numpy as np

import stair_carry_source as SC

CS, SRC, W = SC.CS, SC.SRC, SC.W
sys.path.insert(0, str(SC.MOLE / "claw-work-v1"))
import author_claw_turn as TURN  # noqa: E402

AH, PH = TURN.AH, TURN.PH
TERRAIN = CS.TERRAIN
AH_SHA = TURN.AH_SHA
LOADED = ("approach", "descent", "ascent", "turn", "retreat", "back_up")
EMPTY = ("empty_walk_off", "empty_back_up")
HANDOFFS = ("approach", "turn", "retreat")
CONTACT_CELL_U = 1  # `prove_stair_terrain.contact_witness`: an exact source gap in [0, 1) u.


def planted_mask(ready: dict) -> int:
    """The feet of the ready key whose lowest exact source vertex lies in the contact cell of the floor plane."""
    body = ready["geometry"][0]
    triangles = ready["triangles"]
    mask = 0
    for side, members in enumerate(TERRAIN.foot_membership(body, triangles)):
        vertices = np.unique(triangles[members])
        gaps = [TERRAIN.exact_source_y(body, ready, SC.READY_FRAME, int(v)) for v in vertices]
        W.require(min(gaps) >= 0, "STAIR_CARRY_READY_BELOW_FLOOR")
        if min(gaps) < CONTACT_CELL_U:
            mask |= 1 << side
    W.require(mask & 1, "STAIR_CARRY_READY_UNSUPPORTED")
    return mask


@contextlib.contextmanager
def endpoint_support(mask: int):
    """Record `mask` as the planted feet of the handoff's first and last keys; every other key is the author's."""
    W.require(SRC.sha(Path(AH.__file__)) == AH_SHA, "STAIR_CARRY_HANDOFF_AUTHOR_DRIFT")
    accepted = AH.frame_track

    def frame_track(frame, controls, headings, stations):
        root, yaw, feet, angles, plant, lift = accepted(frame, controls, headings, stations)
        if frame in (0, (len(controls) - 1) * AH.PHASE_FRAMES):
            plant = mask
        return root, yaw, feet, angles, plant, lift
    AH.frame_track = frame_track
    try:
        yield
    finally:
        AH.frame_track = accepted


def handoff(name: str, ready: dict, topology: list, rig: dict, table: np.ndarray, mask: int) -> dict:
    """One ADR 1142 handoff on `ready`, its endpoint support derived from the ready."""
    with endpoint_support(mask):
        case = AH.source_case(name, ready, rig, topology, table)
    case["geometry"] = list(ready["geometry"])
    case["endpoint_planted_mask"] = mask
    return case


def reversed_case(case: dict, name: str) -> dict:
    """The exact reverse of a clip: its keys in the opposite order, as each recovery reverses its entry."""
    recipe = dict(case["handoff_recipe"], keys=case["handoff_recipe"]["keys"][::-1], name=name)
    return dict(case, id=case["id"] + ".reversed", matrices=case["matrices"][::-1].copy(),
                grounding=case["grounding"][::-1].copy(), handoff_recipe=recipe, reverse_of="approach")


def gaits(ready: dict, rig: dict, topology: list) -> dict:
    """M7's descent and ascent recipes, unchanged, on `ready`."""
    d, a = CS.RECIPES["descent"], CS.RECIPES["ascent"]
    descent = CS.DESC.source_case(ready, rig, topology, d["rise"], d["advance"], d["drop"], d["lead_foot"],
                                  d["guide"], d["toe_degrees"])
    ascent = CS.ASC.source_case(ready, rig, a["rise"], a["lead_advance"], a["lead_lift"], topology)
    for case in (descent, ascent):
        case["geometry"] = list(ready["geometry"])
    return {"descent": descent, "ascent": ascent}


def loaded_clips(closure: dict, item: str, table: np.ndarray) -> dict:
    """The six loaded clips of one item."""
    row = closure["items"][item]
    ready = dict(row["ready"], triangles=closure["body_triangles"])
    topology = [[closure["body_triangles"]], [row["triangles"]]]
    rig, mask = closure["topology"], planted_mask(ready)
    clips = gaits(row["ready"], rig, topology)
    for name in HANDOFFS:
        clips[name] = handoff(name, row["ready"], topology, rig, table, mask)
    clips["back_up"] = reversed_case(clips["approach"], "back_up")
    for name, case in clips.items():
        for end in (0, -1):
            W.require(np.array_equal(case["matrices"][end], row["hold"]), "STAIR_CARRY_HOLD_ENDPOINT:" + name)
    return {name: clips[name] for name in LOADED}


def empty_clips(closure: dict, table: np.ndarray) -> dict:
    """The empty walk-off and back-up on the corrected stand (body only)."""
    ready = dict(closure["empty"], triangles=closure["body_triangles"])
    mask = planted_mask(ready)
    W.require(mask == 1, "STAIR_CARRY_STAND_SUPPORT")  # The accepted author's own value for the stand ready.
    walk = handoff("approach", closure["empty"], [[closure["body_triangles"]]], closure["topology"], table, mask)
    walk["id"] = "mole_worker.stair_carry.empty_walk_off"
    return {"empty_walk_off": walk, "empty_back_up": reversed_case(walk, "empty_back_up")}


def invariant(case: dict, hold: np.ndarray) -> bool:
    """The hips, the upper body (bones 9-23) and the load column equal the hold on every key."""
    keys = case["frames"]
    return bool(np.array_equal(case["matrices"][:, 0], np.repeat(hold[None, 0], keys, axis=0)) and
                np.array_equal(case["matrices"][:, 9:], np.repeat(hold[None, 9:], keys, axis=0)))


def author(closure: dict, table: np.ndarray) -> dict:
    """Every clip: {"wood": {...}, "stone": {...}, "empty": {...}}."""
    result = {item: loaded_clips(closure, item, table) for item in SC.ITEMS}
    for item in SC.ITEMS:
        for name, case in result[item].items():
            W.require(invariant(case, closure["items"][item]["hold"]), "STAIR_CARRY_UPPER_BODY:" + name)
    result["empty"] = empty_clips(closure, table)
    return result


def clip_record(case: dict, path: Path) -> dict:
    """The stored facts of one written clip."""
    row = {"id": case["id"], "frames": case["frames"], "sha256": SRC.sha(path)}
    if "stair_recipe" in case:
        row["recipe"] = {k: v for k, v in case["stair_recipe"].items() if not isinstance(v, list)}
        row["root_end_u"] = case["stair_recipe"]["root_u"][-1]
    if "handoff_recipe" in case:
        recipe = case["handoff_recipe"]
        row["handoff"] = {"name": recipe["name"], "controls_u": recipe["controls_u"],
                          "heading_controls": recipe["heading_controls"],
                          "first_key": recipe["keys"][0], "last_key": recipe["keys"][-1]}
        row["endpoint_planted_mask"] = case["endpoint_planted_mask"]
    if "reverse_of" in case:
        row["reverse_of"] = case["reverse_of"]
    return row


def write(out: Path, clips: dict) -> dict:
    """Write every clip (25 slots loaded, 24 slots empty) and return their records."""
    records = {}
    for group, cases in clips.items():
        (out / group).mkdir(parents=True)
        records[group] = {}
        for name, case in cases.items():
            matrices = case["matrices"] if group != "empty" else case["matrices"][:, :24]
            path = out / group / f"{name}.npz"
            W.write_case(path, dict(case, matrices=np.ascontiguousarray(matrices)))
            records[group][name] = clip_record(case, path)
    return records


def main() -> int:
    """Author and write; the proofs are `prove_stair_carry.py`."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "STAIR_CARRY_OUTPUT_EXISTS")
    closure = SC.closure()
    table, basis = AH.read_basis()
    clips = author(closure, table)
    records = write(args.out, clips)
    record = {"schema": 1, "decision": ["1981", "1217", "1209", "1142"], "motion": "the basic stair carry",
              "recipes": {"descent": CS.RECIPES["descent"], "ascent": CS.RECIPES["ascent"],
                          "handoffs": "author_stair_handoffs.episode_controls, unchanged"},
              "accepted_recipes": {g: {k: v for k, v in r.items() if not isinstance(v, list)}
                                   for g, r in CS.accepted_recipes().items()},
              "handoff_author_sha256": AH_SHA, "basis": basis, "arm_swing_degrees": {"right": 0, "left": 0},
              "endpoint_support_rule": "a foot is planted at a handoff's first and last keys when one of its "
                                       "vertices lies in the contact cell [0, 1) u (P-1981-7 (a))",
              "clips": records, "source_pins": closure["pins"], "production_qualified": False,
              "producer_sources": {str(Path(p).resolve().relative_to(SRC.ROOT)): SRC.sha(Path(p)) for p in
                                   (__file__, SC.__file__, AH.__file__, CS.DESC.__file__, CS.ASC.__file__)}}
    (args.out / "candidate.json").write_text(json.dumps(record, indent=2, default=str) + "\n")
    print(json.dumps({group: {n: r["frames"] for n, r in rows.items()} for group, rows in records.items()}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
