#!/usr/bin/env python3
"""Create-only claw stair motion tables `qualified-claw-stair-motion-v1/` (ADR 1229 increment 3). Data only.

The successor of the pick-era motion catalog's stair banks for content 10's source-proved travel rows. For each row
it records, in the frame of the row's start root (world yaw 0, the Placement's rotation 0):

| Row | Motion | Keys | Root and heading | Fixture decks (support primitives) |
|---|---|---:|---|---|
| 51 | step back 169 -> 310 u | 2 | the 141 u span (`tread-step-back-v1`) | the standing deck, from that proof's fixture |
| 52 | step forward 310 -> 169 u | 2 | the -141 u span (`tread-step-forward-v1`) | likewise |
| 53 | descent | 91 | the accepted descent root track (ADR 1217 M7: "the root tracks are the accepted ones"), the content-10 motion wire's gait 1 | M7's terrain proof decks; the deck of each interval from its support rows |
| 54 | ascent | 91 | the accepted ascent root track, gait 0, turned by the exact half turn | likewise, turned |
| 55 | half-turn | 271 | handoff program 1 (step 5b: the author runs unchanged, same controls and solve) | the standing deck (the descent's upper deck) |

Nothing is chosen: every number is read from a pinned input and cross-checked against the claw records (end roots
against `stair-rows-v1`, the turn's controls against `claw-turn-v1`). The tick counts are not here: DEC-050's
paces are the bundle's authored connector rows.

Wire `UGSTRM01` (little-endian):
- 32-byte header: magic, u32 version 1, s64 profile content revision 10, u32 program count, u32 key count,
  u32 deck count; then the 32-byte SHA-256 of the content-10 profile wire.
- programs: 12 x i32 each: row, rooted (0 short step, 1 root track), key count, first key, deck count, first deck,
  end x/y/z, start yaw, end yaw, claw image clip ordinal.
- keys: 5 x i32 each: root x/y/z, heading, the deck index supporting the interval that starts at the key.
- decks: 6 x i32 each (half-open box). Footer `UGSTEND1`.

    python3 godot/data/underground/mole-worker/publish_claw_stair_motion.py
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OUTPUT = HERE / "qualified-claw-stair-motion-v1"
CONTENT = HERE / "qualified-claw-stairs-v11"
EVIDENCE = HERE / "claw-work-v1/evidence"
INPUTS = {
    CONTENT / "mole-worker.ugprof": "9791eb59b778cf9fe0b4c66dfd7181c58706abd6ed1a8e6a90a73daafa7f3317",
    CONTENT / "motion.ugmotion": "8055dd9bd31a48c71137470309bd5748e0d439a71f195aa0a5fcb0d26ca7f5d6",
    EVIDENCE / "stair-rows-v1/rows.json": "4d8ec575798d6169503fd7d7cfea683698771054d0e02c7dbdb751aac8a1a525",
}
RECORDS = ("claw-stairs-v1/proof.json", "claw-turn-v1/candidate.json", "tread-step-back-v1/step_back.json",
           "tread-step-forward-v1/step_forward.json")
CONTENT_REVISION = 10
I32, I64, BYT = 17421, 67, 640
HANDOFF, PROGRAM = 4798, 16903
GAIT_BASE, GAIT_ROWS = [0, 24, 570, 1290, 3378, 4354, 4534], [2, 182, 180, 348, 122, 180, 44]
HANDOFF_BASE, HANDOFF_ROWS = [0, 24, 2289, 4989, 9075, 11523, 11973], [3, 453, 450, 681, 306, 450, 22]
STEP_BACK, STEP_FORWARD, DESCENT, ASCENT, TURN = 51, 52, 53, 54, 55
CLIP = {STEP_BACK: 11, STEP_FORWARD: 12, DESCENT: 13, ASCENT: 14, TURN: 15}  # claw v2 plan.json ordinals
HALF = 32768


def require(value: bool, code: str) -> None:
    """Every refusal names the failed derivation fact."""
    if not value:
        raise ValueError("CLAW_STAIR_MOTION_" + code)


def sha(raw: bytes) -> str:
    """Lower-case hex SHA-256."""
    return hashlib.sha256(raw).hexdigest()


def pinned(path: Path, expected: str) -> bytes:
    """One input, byte-pinned."""
    raw = path.read_bytes()
    require(sha(raw) == expected, "INPUT_" + path.name)
    return raw


def motion_ints(raw: bytes) -> list:
    """The I32 column of a UGMOTN01 wire."""
    require(raw[:8] == b"UGMOTN01" and struct.unpack_from("<q", raw, 16)[0] == CONTENT_REVISION, "MOTION_HEADER")
    require(raw[32:44] == b"I032" + struct.pack("<II", 4, I32), "MOTION_COLUMN")
    return list(struct.unpack_from("<%di" % I32, raw, 44))


def gait_roots(ints: list, program: int) -> list:
    """The 91 integer root keys of one gait program, source-local."""
    return [[ints[GAIT_BASE[1] + f * GAIT_ROWS[1] + program * 91 + k] for f in range(3)] for k in range(91)]


def handoff_keys(ints: list, program: int) -> list:
    """The keys (x, y, z, heading) of one handoff program, fixed-fixture coordinates."""
    first = ints[HANDOFF + HANDOFF_BASE[0] + program]
    last = ints[PROGRAM + 16 * 5 + program + 2]
    return [[ints[HANDOFF + HANDOFF_BASE[1] + f * HANDOFF_ROWS[1] + first + k] for f in range(4)]
            for k in range(last + 1)]


def turned(box: list) -> list:
    """A box turned by the exact half turn about the root (x and z negate)."""
    return [-box[3], box[1], -box[5], -box[0], box[4], -box[2]]


def rows_record(raw: bytes) -> dict:
    """The derived rows by name."""
    return {row["name"]: row for row in json.loads(raw)["rows"]}


def step_program(row: int, record: dict, span: int, decks_from: int) -> dict:
    """A short step: two keys over the span, the proof fixture's support deck moved into the start frame."""
    require(record["span_u"] == abs(span) and record["clear"] is True, "STEP_RECORD")
    deck = list(record["fixture"]["solids_u"][0])
    require(deck[1] == -64 and deck[4] == 0 and deck[2] == -record["station_from_far_edge_u"], "STEP_DECK")
    deck = [deck[a] + (decks_from if a % 3 == 2 else 0) for a in range(6)]
    return {"row": row, "rooted": 0, "keys": [[0, 0, 0, 0, 0], [0, 0, span, 0, 0]], "decks": [deck],
            "end": [0, 0, span], "yaw": (0, 0)}


def gait_program(row: int, roots: list, proof: dict, half: bool) -> dict:
    """A rooted stair gait: its roots and the terrain proof's decks, turned for the ascent."""
    terrain = proof["terrain"]
    require(terrain["clear"] is True and len(terrain["supports"]) == 90 and proof["flight"]["clear"] is True
            and proof["self"]["clear"] is True, "GAIT_PROOF")
    decks = [list(b) for b in terrain["fixture_boxes_u"][:2]]
    require(decks[0] == [-1024, -64, -169, 1024, 0, 343] and decks[1][2] == -681 and decks[1][5] == -169, "GAIT_DECKS")
    support = [s["deck"] for s in terrain["supports"]]
    require([s["interval"] for s in terrain["supports"]] == list(range(90)) and set(support) == {0, 1}, "GAIT_SUPPORT")
    yaw = HALF if half else 0
    keys = []
    for k, r in enumerate(roots):
        point = [-r[0], r[1], -r[2]] if half else list(r)
        keys.append(point + [yaw, support[min(k, 89)]])
    if half:
        decks = [turned(d) for d in decks]
    return {"row": row, "rooted": 1, "keys": keys, "decks": decks, "end": keys[-1][:3], "yaw": (yaw, yaw)}


def turn_program(keys: list, turn: dict, standing: list) -> dict:
    """The half-turn: handoff program 1 rebased to its start root, checked against the claw turn's controls."""
    start = keys[0][:3]
    require(len(keys) == turn["keys"] == 271 and turn["clear"] is True, "TURN_RECORD")
    relative = [[k[0] - start[0], k[1] - start[1], k[2] - start[2], k[3], 0] for k in keys]
    roots = {tuple(k[:3]) for k in keys}
    require(all(tuple(c) in roots for c in turn["controls_u"]) and turn["controls_u"][0] == start, "TURN_CONTROLS")
    headings = {k[3] for k in keys}
    require(all(h in headings for h in turn["heading_controls"]) and keys[0][3] == 0 and keys[-1][3] == HALF,
            "TURN_HEADINGS")
    return {"row": TURN, "rooted": 1, "keys": relative, "decks": [list(standing)], "end": relative[-1][:3],
            "yaw": (0, HALF)}


def programs() -> tuple:
    """All five programs, the profile wire and the input census."""
    raw = {path: pinned(path, digest) for path, digest in INPUTS.items()}
    records = {name: json.loads((EVIDENCE / name).read_text()) for name in RECORDS}
    ints = motion_ints(raw[CONTENT / "motion.ugmotion"])
    rows = rows_record(raw[EVIDENCE / "stair-rows-v1/rows.json"])
    proof = records["claw-stairs-v1/proof.json"]
    descent = gait_program(DESCENT, gait_roots(ints, 1), proof["descent"], False)
    ascent = gait_program(ASCENT, gait_roots(ints, 0), proof["ascent"], True)
    turn = turn_program(handoff_keys(ints, 1), records["claw-turn-v1/candidate.json"], descent["decks"][0])
    back = step_program(STEP_BACK, records["tread-step-back-v1/step_back.json"], 141, 141)
    forward = step_program(STEP_FORWARD, records["tread-step-forward-v1/step_forward.json"], -141, 0)
    require(descent["end"] == rows["descent"]["root_end_u"] == [0, -128, -512], "DESCENT_END")
    require(ascent["end"] == [0, 128, 512] and rows["ascent"]["root_end_u"] == [0, 128, -512], "ASCENT_END")
    require(turn["end"] == rows["turn"]["root_end_u"] == [0, 0, 174], "TURN_END")
    census = {str(p.relative_to(ROOT)): d for p, d in INPUTS.items()}
    census.update({str((EVIDENCE / n).relative_to(ROOT)): sha((EVIDENCE / n).read_bytes()) for n in RECORDS})
    census[str(Path(__file__).resolve().relative_to(ROOT))] = sha(Path(__file__).read_bytes())
    return [back, forward, descent, ascent, turn], raw[CONTENT / "mole-worker.ugprof"], census


def serialize(table: list, profile: bytes) -> bytes:
    """The UGSTRM01 wire."""
    keys = sum(len(p["keys"]) for p in table)
    decks = sum(len(p["decks"]) for p in table)
    out = b"UGSTRM01" + struct.pack("<IqIII", 1, CONTENT_REVISION, len(table), keys, decks)
    out += hashlib.sha256(profile).digest()
    first_key = first_deck = 0
    for p in table:
        out += struct.pack("<12i", p["row"], p["rooted"], len(p["keys"]), first_key, len(p["decks"]), first_deck,
                           *p["end"], p["yaw"][0], p["yaw"][1], CLIP[p["row"]])
        first_key += len(p["keys"])
        first_deck += len(p["decks"])
    for p in table:
        for key in p["keys"]:
            out += struct.pack("<5i", *key)
    for p in table:
        for deck in p["decks"]:
            require(all(deck[a] < deck[a + 3] for a in range(3)), "DECK_BOX")
            out += struct.pack("<6i", *deck)
    return out + b"UGSTEND1"


def accessor(wire: bytes, table: list) -> str:
    """The generated pin file the runtime owner reads."""
    return "\n".join([
        "extends RefCounted",
        "## Generated by publish_claw_stair_motion.py (ADR 1229). Do not edit.",
        "",
        'const WIRE_PATH: String = "res://data/underground/mole-worker/qualified-claw-stair-motion-v1/stair-motion.ugstair"',
        'const WIRE_SHA: String = "%s"' % sha(wire),
        "const WIRE_BYTES: int = %d" % len(wire),
        "const CONTENT_REVISION: int = %d" % CONTENT_REVISION,
        "const PROGRAM_COUNT: int = %d" % len(table),
        "const KEY_COUNT: int = %d" % sum(len(p["keys"]) for p in table),
        "const DECK_COUNT: int = %d" % sum(len(p["decks"]) for p in table),
        "",
    ])


def build() -> dict:
    """Every output file, in memory."""
    table, profile, census = programs()
    wire = serialize(table, profile)
    manifest = {"schema": 1, "decision": ["1229", "1217", "1209"], "content_revision": CONTENT_REVISION,
                "wire_sha256": sha(wire), "wire_bytes": len(wire),
                "programs": [{"row": p["row"], "keys": len(p["keys"]), "decks": p["decks"], "end_u": p["end"],
                              "yaw": list(p["yaw"]), "clip": CLIP[p["row"]]} for p in table],
                "inputs": census, "runtime_admitted": False}
    return {"stair-motion.ugstair": wire, "catalog_source.gd": accessor(wire, table).encode(),
            "manifest.json": (json.dumps(manifest, indent=2) + "\n").encode()}


def main() -> int:
    """Create the publication exactly once."""
    require(not OUTPUT.exists(), "OUTPUT_EXISTS")
    outputs = build()
    OUTPUT.mkdir()
    for name, raw in outputs.items():
        (OUTPUT / name).write_bytes(raw)
    print("published", OUTPUT.relative_to(ROOT), {n: sha(r)[:12] for n, r in outputs.items()})
    return 0


if __name__ == "__main__":
    sys.exit(main())
