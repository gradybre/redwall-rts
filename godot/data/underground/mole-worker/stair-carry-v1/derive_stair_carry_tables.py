#!/usr/bin/env python3
"""The stair tables of rows 71-84 (decision 1981): root, heading and supporting deck per key. Derived, never chosen.

The runtime stair program samples a rooted row's integer root track and heading per key and checks that every deck
its proofs stood on is installed (ADR 1229 increment 3). For each row, in the frame of its start root:

| Rows | Keys | Decks |
|---|---|---|
| descent, ascent | the M7 recipe's integer root track (the ascent turned by the exact half turn, as row 54) and the deck of the first support of each interval in the terrain proof | the terrain fixture's two decks (turned for the ascent) |
| approach, retreat | the handoff recipe's root and heading per key | the standing deck of their L0 runs: L0's deck (the approach is also used on the floor, whose slab covers that deck in the approach's frame) |
| walk-off, back-ups | likewise (a back-up's keys are its approach's, reversed) | used only at the stair's foot: the floor slab of the floor run, in the row's start frame |
| turn | likewise | the deck row 55's table records (the floor slab covers it) |

**Cross-check.** The loaded gaits and the half-turn use the same recipes as content 10's rows 53, 54 and 55, so their
keys and decks must equal `qualified-claw-stair-motion-v1`'s programs for those rows exactly; this tool refuses
otherwise.

    $PY .../derive_stair_carry_tables.py <clips-dir> <proof.json> <out.json>
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct
import sys

import author_stair_carry as AUTHOR
import prove_stair_carry as PROVE
import stair_carry_source as SC

SRC, W, AH = SC.SRC, SC.W, AUTHOR.AH
HALF = 32768
CLAW_TABLES = SC.MOLE / "qualified-claw-stair-motion-v1/stair-motion.ugstair"
CLAW_TABLES_SHA = "e7840c7babc9bbe21c8f8c36a3d3a313172bc4a3adff9f13dcd6f4a99c25a58b"  # Content 10's published stair tables (ADR 1229 increment 3).
FLOOR_ONLY = ("empty_walk_off", "empty_back_up", "back_up")  # Rows used only at the stair's foot.
TURN_DECK = [-1024, -64, -169, 1024, 0, 343]  # Row 55's recorded standing deck (T0 in the frame of A).
IMAGE_CLIPS = {"wood": ("hold", "approach", "descent", "ascent", "turn", "retreat", "back_up", "empty_walk_off",
                        "empty_back_up"),
               "stone": ("hold", "approach", "descent", "ascent", "turn", "retreat", "back_up")}
ORDER = [("empty", "empty_walk_off", 71), ("empty", "empty_back_up", 72)] + \
    [(item, name, first + at) for item, first in (("wood", 73), ("stone", 79))
     for at, name in enumerate(AUTHOR.LOADED)]


def claw_programs() -> dict:
    """Content 10's stair tables by row: (keys, decks, end, yaws)."""
    raw = CLAW_TABLES.read_bytes()
    W.require(SRC.sha(CLAW_TABLES) == CLAW_TABLES_SHA and raw[:8] == b"UGSTRM01" and raw[-8:] == b"UGSTEND1", "STAIR_CARRY_CLAW_TABLES")
    _, _, programs, keys, decks = struct.unpack_from("<IqIII", raw, 8)
    at = 64
    rows = [struct.unpack_from("<12i", raw, at + 48 * p) for p in range(programs)]
    key_at, deck_at = at + 48 * programs, at + 48 * programs + 20 * keys
    result = {}
    for p in rows:
        result[p[0]] = {"keys": [list(struct.unpack_from("<5i", raw, key_at + 20 * (p[3] + k))) for k in range(p[2])],
                        "decks": [list(struct.unpack_from("<6i", raw, deck_at + 24 * (p[5] + d))) for d in range(p[4])],
                        "end": list(p[6:9]), "yaw": [p[9], p[10]]}
    return result


def turned(box: list) -> list:
    """A box turned by the exact half turn about the root (x and z negate), as `publish_claw_stair_motion`."""
    return [-box[3], box[1], -box[5], -box[0], box[4], -box[2]]


def gait_table(case: dict, terrain: dict, half: bool) -> dict:
    """`publish_claw_stair_motion.gait_program` from this clip's recipe and terrain proof."""
    W.require(terrain["clear"] is True, "STAIR_CARRY_TABLE_TERRAIN")
    decks = [list(b) for b in terrain["fixture_boxes_u"][:2]]
    first = {}
    for support in terrain["supports"]:
        first.setdefault(support["interval"], support["deck"])
    W.require(sorted(first) == list(range(case["frames"] - 1)) and set(first.values()) <= {0, 1},
              "STAIR_CARRY_TABLE_SUPPORT")
    yaw = HALF if half else 0
    keys = []
    for k, r in enumerate(case["stair_recipe"]["root_u"]):
        point = [-r[0], r[1], -r[2]] if half else list(r)
        keys.append(point + [yaw, first[min(k, case["frames"] - 2)]])
    if half:
        decks = [turned(d) for d in decks]
    return {"keys": keys, "decks": decks, "end": keys[-1][:3], "yaw": [yaw, yaw]}


def handoff_table(case: dict, deck: list, start: list | None = None) -> dict:
    """A handoff's keys in its start frame, and the deck it stood on."""
    rows = case["handoff_recipe"]["keys"]
    origin = rows[0]["root_u"]
    keys = [[r["root_u"][a] - origin[a] for a in range(3)] + [r["yaw"], 0] for r in rows]
    base = origin if start is None else start
    stood = [deck[a] - base[a % 3] for a in range(6)]
    return {"keys": keys, "decks": [stood], "end": keys[-1][:3], "yaw": [keys[0][3], keys[-1][3]]}


def table_of(name: str, case: dict, proofs: dict) -> dict:
    """The program of one row."""
    if name in ("descent", "ascent"):
        return gait_table(case, proofs[name]["terrain"], name == "ascent")
    if name == "turn":
        start = case["handoff_recipe"]["keys"][0]["root_u"]
        return handoff_table(case, [TURN_DECK[a] + start[a % 3] for a in range(6)])
    run = PROVE.fixture("floor_approach" if name in FLOOR_ONLY else "L0")
    return handoff_table(case, run["solids_u"][case["handoff_recipe"]["keys"][0]["support_primitive"]])


def derive(clips_dir: Path, proof_path: Path) -> dict:
    """Every table, cross-checked against content 10's rows 53-55."""
    closure = SC.closure()
    table, _ = AH.read_basis()
    clips = AUTHOR.author(closure, table)
    PROVE.check_stored(clips_dir, clips)
    record = json.loads(proof_path.read_text())["proofs"]
    W.require(record["clear"] is True, "STAIR_CARRY_PROOF_NOT_CLEAR")
    claw = claw_programs()
    programs = []
    for group, name, row in ORDER:
        case = clips[group][name]
        program = table_of(name, case, record.get(group, {}))
        image = "wood" if group in ("wood", "empty") else "stone"
        programs.append({"row": row, "group": group, "name": name, "rooted": 1, "source": 6 if image == "wood" else 7,
                         "clip": IMAGE_CLIPS[image].index(name), **program})
        twin = {"descent": 53, "ascent": 54, "turn": 55}.get(name)
        if twin is not None:
            W.require(program["keys"] == claw[twin]["keys"] and program["decks"] == claw[twin]["decks"] and
                      program["end"] == claw[twin]["end"] and program["yaw"] == claw[twin]["yaw"],
                      "STAIR_CARRY_TABLE_TWIN:" + name)
    return {"schema": 1, "decision": "1981", "programs": programs, "claw_tables_sha256": SRC.sha(CLAW_TABLES),
            "proof_sha256": SRC.sha(proof_path), "production_qualified": False}


def main() -> int:
    """Derive and write the record."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("clips", type=Path)
    parser.add_argument("proof", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "STAIR_CARRY_TABLES_EXIST")
    result = derive(args.clips, args.proof)
    result["producer_sources"] = {str(Path(p).resolve().relative_to(SRC.ROOT)): SRC.sha(Path(p))
                                  for p in (__file__, AUTHOR.__file__, PROVE.__file__)}
    args.out.write_text(json.dumps(result, indent=1) + "\n")
    print(json.dumps([{"row": p["row"], "name": p["name"], "keys": len(p["keys"]), "end": p["end"], "yaw": p["yaw"],
                       "decks": p["decks"], "clip": p["clip"]} for p in result["programs"]]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
