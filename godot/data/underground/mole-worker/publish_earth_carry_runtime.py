#!/usr/bin/env python3
"""Create-only content-13 mole profile publication `qualified-earth-carry-v14/` (decision 2042). Data only, not active.

Content 13 is content 12 (`qualified-stair-carry-v13`) with one basic earth carry. Brendan ruled P-2042-1 (a) "Stone
lump, earth colour": earth is carried as the approved stone lump, so every stone proof is an earth proof and the
earth rows are the stone rows with their cargo changed (P-2042-3 (a)):

- **Sources 0-7** and **rows 0-84** are content 12's, byte for byte (no published row moves).
- **Source 8** repeats source 3's digest (the stone haul image v10) and **source 9** repeats source 7's (the stone
  stair-carry image): the same solid and clips. New sources are needed only because Profiles keys rows by source and
  `excavated_earth` (compiled item 11) sorts before stone (53), so earth rows appended to sources 3 or 7 would break
  each source's key order (`underground_profiles.gd` `PROFILE_KEY_ORDER`). The earth colour is presentation only (the
  images carry geometry, never a material, `compile_native_program_v9.stone_part`).
- **85-89** (source 8): stone's level rows 37-41 (CARRY, two loads, two unloads), cargo 53 -> 11.
- **90-95** (source 9): stone's stair-carry rows 79-84 (approach, descent, ascent, turn, retreat, back-up), cargo
  53 -> 11.
- Every row that carries a cargo carries **5,000 milli-U** (P-2042-2 (a): the same 5,000 g as every certified wood
  or stone trip; `excavated_earth` is 1,000 g/U). The load rows keep 0..0.
- Every other word, every box, policy byte and revision is the template's.

**Ground paces:** content 12's twenty-six caps, plus row 85 with row 37's cap (the level carry's ground cap); the
stair rows are connector rows, as content 12's. Revision 13.
**Motion bank:** content 12's, rebound to revision 13 and the new wire.

    python3 godot/data/underground/mole-worker/publish_earth_carry_runtime.py
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import struct
import sys

import publish_claw_approach_runtime as PUB9
import publish_claw_runtime as PUB7
import publish_haul_runtime as H

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = HERE / "qualified-stair-carry-v13"
OUTPUT = HERE / "qualified-earth-carry-v14"
ITEMS = ROOT / "godot/data/item_definitions.json"
OLD_WIRE_SHA = "fa96acbeac96ca3860f2368c88c9287a51a5eadba29cd9530ea14c6c5e95e202"
OLD_GROUND_SHA = "3234f2d25eeed0e535f68316d555919855741c9067263eb7443edaf94991d75c"
OLD_MOTION_SHA = "05e4c692eed1a4eef778e99c16f9866e8a78c52abea9c2276fb4f577401c5598"
OLD_COUNTS, NEW_REVISION = (12, 85, 637, 8), 13
F_SOURCE, F_CARGO, F_FIRST_BOX = 0, 8, 14
Q_MIN, Q_MAX = 19, 20  # The row tuple's int64 quantity fields (after 18 int32 words and the revision).
STONE_SOURCES = {3: 8, 7: 9}  # template source -> earth source
LEVEL_TEMPLATES, STAIR_TEMPLATES = tuple(range(37, 42)), tuple(range(79, 85))
LEVEL_ROWS, STAIR_ROWS = tuple(range(85, 90)), tuple(range(90, 96))
EARTH_QUANTITY_MILLI = 5000
GROUND_HEADER_AT, GROUND_ROWS_AT, GROUND_ROW_BYTES = 44, 136, 36


def require(value: bool, code: str) -> None:
    """Every refusal names the exact failed publication fact."""
    if not value:
        raise ValueError("EARTH_CARRY_RUNTIME_" + code)


def sha(raw: bytes) -> str:
    """Lower-case hex SHA-256."""
    return hashlib.sha256(raw).hexdigest()


def item_id(key: str) -> int:
    """A compiled item id: its index in ascending-ASCII order of `item_definitions.json` (ADR 1206: stone 53)."""
    data = json.loads(ITEMS.read_text())
    items = data if isinstance(data, list) else data["items"]
    keys = sorted(item["id"] for item in items)
    require(key in keys, "ITEM_" + key)
    return keys.index(key)


def earth_rows(fields: list, rows: list) -> list:
    """(fields, boxes) of rows 85-95 from the stone templates: source and cargo moved, quantity 5,000."""
    stone, earth = item_id("stone"), item_id("excavated_earth")
    result = []
    for template in LEVEL_TEMPLATES + STAIR_TEMPLATES:
        words = list(fields[template])
        require(words[F_SOURCE] in STONE_SOURCES and words[F_CARGO] in (-1, stone), "TEMPLATE_" + str(template))
        carries = words[F_CARGO] == stone
        require((words[Q_MIN], words[Q_MAX]) == ((1000, 1000) if carries else (0, 0)), "TEMPLATE_QUANTITY")
        words[F_SOURCE] = STONE_SOURCES[words[F_SOURCE]]
        if carries:
            words[F_CARGO] = earth
            words[Q_MIN] = words[Q_MAX] = EARTH_QUANTITY_MILLI
        result.append((words, list(rows[template])))
    return result


def build_wire() -> tuple:
    """Rows 0-84 unchanged, then rows 85-95; sources 8 and 9 appended (the stone images' own digests)."""
    old = (OLD / "mole-worker.ugprof").read_bytes()
    require(sha(old) == OLD_WIRE_SHA, "OLD_WIRE")
    revision, digests, fields, rows = PUB7.parse(old)
    require((revision, len(fields), sum(map(len, rows)), len(digests)) == OLD_COUNTS, "OLD_COUNTS")
    order = [(list(fields[i]), list(rows[i])) for i in range(len(fields))] + earth_rows(fields, rows)
    saved, PUB9.NEW_REVISION = PUB9.NEW_REVISION, NEW_REVISION  # Content 9's encoder at revision 13.
    try:
        return PUB9.encode(list(digests) + [digests[3], digests[7]], [f for f, _ in order],
                           [r for _, r in order]), old
    finally:
        PUB9.NEW_REVISION = saved


def check(old: bytes, new: bytes) -> None:
    """Sources 0-7 and rows 0-84 unchanged; each source's rows key-sorted; earth rows equal their templates except
    source, cargo and quantity."""
    _, old_digests, old_fields, old_rows = PUB7.parse(old)
    revision, digests, fields, rows = PUB7.parse(new)
    require(revision == NEW_REVISION and len(fields) == 96 and digests[:8] == old_digests and
            digests[8:] == [old_digests[3], old_digests[7]], "NEW_COUNTS")
    for index in range(85):
        same = [v for k, v in enumerate(fields[index]) if k != F_FIRST_BOX] == \
            [v for k, v in enumerate(old_fields[index]) if k != F_FIRST_BOX]
        require(same and rows[index] == old_rows[index], "ROW_PRESERVED")
    for source in range(len(digests)):
        keys = [tuple(f[1:10]) + (f[16],) for f in fields if f[F_SOURCE] == source]
        require(keys == sorted(keys), "KEY_ORDER")
    for row, template in zip(LEVEL_ROWS + STAIR_ROWS, LEVEL_TEMPLATES + STAIR_TEMPLATES):
        moved = {F_SOURCE, F_CARGO, F_FIRST_BOX, Q_MIN, Q_MAX}
        require(all(fields[row][k] == old_fields[template][k] for k in range(len(fields[row])) if k not in moved) and
                rows[row] == old_rows[template], "TEMPLATE_IDENTITY_" + str(row))


def build_ground(old: bytes, profile_revision: int) -> bytes:
    """Content 12's twenty-six caps plus row 85 with row 37's cap, at revision 13."""
    require(sha(old) == OLD_GROUND_SHA and struct.unpack_from("<I", old, GROUND_HEADER_AT)[0] == 26 and
            struct.unpack_from("<q", old, GROUND_HEADER_AT + 4)[0] == 12 and len(old) == 1080, "GROUND_HEADER")
    paces = [H.PACE.unpack_from(old, GROUND_ROWS_AT + GROUND_ROW_BYTES * r) for r in range(26)]
    stone = [p for p in paces if p[0] == LEVEL_TEMPLATES[0]]
    require(len(stone) == 1 and paces[-1][0] < LEVEL_ROWS[0], "GROUND_STONE_CAP")
    earth = (LEVEL_ROWS[0],) + stone[0][1:7] + (profile_revision,)
    out = bytearray(old[:-8])
    struct.pack_into("<I", out, GROUND_HEADER_AT, 27)
    struct.pack_into("<q", out, GROUND_HEADER_AT + 4, NEW_REVISION)
    out += H.PACE.pack(*earth)
    return bytes(out) + old[-8:]


def rebind_motion(motion: bytes, old_wire_sha: str, wire_sha: str, numerical: str) -> bytes:
    """Content 12's motion bank rebound to revision 13 and the new wire."""
    require(sha(motion) == OLD_MOTION_SHA and struct.unpack_from("<q", motion, 16) == (12,) and
            motion[H.BYTE_AT + 160:H.BYTE_AT + 192].hex() == old_wire_sha, "MOTION_LAYOUT")
    out = bytearray(motion)
    struct.pack_into("<q", out, 16, NEW_REVISION)
    struct.pack_into("<2q", out, H.I64_AT + 8, NEW_REVISION, NEW_REVISION)
    out[H.BYTE_AT + 160:H.BYTE_AT + 192] = bytes.fromhex(wire_sha)
    out[H.BYTE_AT + 384:H.BYTE_AT + 416] = bytes.fromhex(numerical)
    ranges = [(16, 24), (H.I64_AT + 8, H.I64_AT + 24), (H.BYTE_AT + 160, H.BYTE_AT + 192),
              (H.BYTE_AT + 384, H.BYTE_AT + 416)]
    require(all(a == b or any(lo <= i < hi for lo, hi in ranges) for i, (a, b) in enumerate(zip(motion, out))),
            "MOTION_FOREIGN_DELTA")
    return bytes(out)


def row_constants(earth: int) -> str:
    """The earth rows, item and payload."""
    pack = lambda values: "[" + ", ".join(map(str, values)) + "]"
    return "\n".join([
        "## Decision 2042 (content 13): the earth carry, the stone lump drawn in earth colour (P-2042-1 (a)).",
        f"const EARTH_ITEM: int = {earth}",
        f"const EARTH_QUANTITY_MILLI: int = {EARTH_QUANTITY_MILLI}",
        "const EARTH_LEVEL_SOURCE: int = 8",
        "const EARTH_STAIR_SOURCE: int = 9",
        "## The level carry: CARRY, load at yaw 0 and a quarter turn, unload at yaw 0 and a quarter turn (rows 37-41's).",
        f"const EARTH_LEVEL_ROWS: PackedInt32Array = {pack(LEVEL_ROWS)}",
        "## The stair carry: approach, descent, ascent, half-turn, retreat, back-up (rows 79-84's).",
        f"const EARTH_STAIR_ROWS: PackedInt32Array = {pack(STAIR_ROWS)}"])


def accessor(old_text: str, wire_sha: str, earth: int) -> str:
    """Content 12's accessor with the new wire, the earth rows, and freshly read consumer digests."""
    text = old_text.replace(OLD_WIRE_SHA, wire_sha)
    text = text.replace("## Generated by publish_stair_carry_runtime.py (decision 1981). Do not edit.",
                        "## Generated by publish_earth_carry_runtime.py (decision 2042). Do not edit.")
    require(text.count("const ACTOR_SHA:") == 1 and "publish_earth_carry_runtime.py" in text, "ACCESSOR_SHAPE")
    text = text.replace("const ACTOR_SHA:", row_constants(earth) + "\nconst ACTOR_SHA:", 1)
    paths = re.findall(r'"(res://[^"]+\.gd)"', text)
    found = re.search(r"const DIGESTS: PackedStringArray = \[\n(.*?)\n\]", text, re.S)
    current = [sha((ROOT / ("godot/" + p.removeprefix("res://"))).read_bytes()) for p in paths]
    return text[:found.start(1)] + "\n".join(f'\t"{d}",' for d in current) + text[found.end(1):]


def build() -> dict:
    """All outputs in memory; nothing is written here."""
    wire, old = build_wire()
    check(old, wire)
    earth = item_id("excavated_earth")
    _, _, fields, _ = PUB7.parse(wire)
    old_ground = (OLD / "ground-pace.ugconn").read_bytes()
    ground = build_ground(old_ground, fields[LEVEL_ROWS[0]][18])
    old_motion = (OLD / "motion.ugmotion").read_bytes()
    pins = {str((OLD / "motion.ugmotion").relative_to(ROOT)): sha(old_motion),
            str((OUTPUT / "mole-worker.ugprof").relative_to(ROOT)): sha(wire),
            str(Path(__file__).resolve().relative_to(ROOT)): sha(Path(__file__).read_bytes())}
    numerical = sha(json.dumps(pins, sort_keys=True, separators=(",", ":")).encode())
    motion = rebind_motion(old_motion, OLD_WIRE_SHA, sha(wire), numerical)
    constants = accessor((OLD / "catalog_source.gd").read_text(), sha(wire), earth)
    _, count, boxes, sources = struct.unpack_from("<qIII", wire, 12)
    manifest = {"schema": 1, "decision": ["2042", "1981", "1206"], "content_revision": NEW_REVISION,
                "profile_count": count, "box_count": boxes, "source_count": sources, "wire_sha256": sha(wire),
                "wire_bytes": len(wire), "paired_bank_bytes": 2 * (len(wire) - 8),
                "sources": {"8": "source 3's digest (stone haul image v10)", "9": "source 7's digest (stone stair image)"},
                "rows": {"0-84": "content 12", "85-89": "earth level carry: rows 37-41 with cargo 11 and 5,000 milli-U",
                         "90-95": "earth stair carry: rows 79-84 with cargo 11 and 5,000 milli-U"},
                "earth_item": earth, "earth_quantity_milli": EARTH_QUANTITY_MILLI,
                "inputs": {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in
                           (OLD / "mole-worker.ugprof", OLD / "ground-pace.ugconn", OLD / "catalog_source.gd", ITEMS)},
                "ground_sha256": sha(ground), "motion_sha256": sha(motion), "motion_inputs": pins,
                "runtime_admitted": False}
    return {"mole-worker.ugprof": wire, "ground-pace.ugconn": ground, "motion.ugmotion": motion,
            "catalog_source.gd": constants.encode(), "manifest.json": (json.dumps(manifest, indent=2) + "\n").encode()}


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
