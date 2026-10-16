#!/usr/bin/env python3
"""Create-only content-12 mole profile publication `qualified-stair-carry-v13/` (decision 1981). Data only, not active.

Content 12 is content 11 (`qualified-claw-wall-v12`) with the basic stair carry and the stair's empty floor end:

- **Sources 0-5** and **rows 0-70** are content 11's, byte for byte (no published row moves).
- **Source 6** is the wood stair-carry image and **source 7** the stone one (`stair-carry-v1/native_stair_carry.py`,
  native-verified). Appending sources renumbers nothing: Profiles orders keys within each source only (ADR 1198).
- **71-72** (source 6, WALK, no cargo): the empty walk-off and back-up, row 31's words.
- **73-78** (source 6, CARRY wood) and **79-84** (source 7, CARRY stone): approach, descent, ascent, turn, retreat,
  back-up, each with row 32's or 37's words.
- Every new row is YAW_EXACT at its derived heading, names connector family 0 (EARTH_TIMBER, mask 1) and carries one
  of the rooted-travel policy words (`underground_profiles.gd`, decision 1981): 10 the forward handoffs, 11 the
  back-ups, 12 the stair gaits, 13 the half-turn. Its boxes are `stair-carry-v1/evidence/rows-v1.json`'s, copied as
  derived.

**Ground paces:** content 11's twenty-six caps, unchanged; only the revision becomes 12 (the new rows are connector
rows: their DEC-050 paces are the bundle's authored rows, decision 1981 P-1981-3).
**Motion bank:** content 11's, rebound to revision 12 and the new wire, as each content successor did.

    python3 godot/data/underground/mole-worker/publish_stair_carry_runtime.py
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
OLD = HERE / "qualified-claw-wall-v12"
OUTPUT = HERE / "qualified-stair-carry-v13"
OLD_WIRE_SHA = "2913e9ba8c6a27aa7a500d2ba944014f8345b363a0b31e611764e8b2460eea0c"
OLD_GROUND_SHA = "c83d399b9fa52e69a08a646febb085357fc6e74d3352d026dd285084bdef56e3"
OLD_MOTION_SHA = "8e5b5bc25119245f29dc1fbe6dfb24fba216bbe256cb79b60f82f0864015fc7f"
ROWS_RECORD = HERE / "stair-carry-v1/evidence/rows-v1.json"
IMAGES = {6: HERE / "stair-carry-v1/evidence/native-stair-carry-v1/wood/compiled/compilation.json",
          7: HERE / "stair-carry-v1/evidence/native-stair-carry-v1/stone/compiled/compilation.json"}
VERIFICATIONS = (HERE / "stair-carry-v1/evidence/native-stair-carry-v1/wood-verification.json",
                 HERE / "stair-carry-v1/evidence/native-stair-carry-v1/stone-verification.json")
OLD_COUNTS, NEW_REVISION = (11, 71, 595, 6), 12
F_SOURCE, F_MODE, F_CARGO, F_YAW_KIND, F_YAW, F_FAMILIES, F_FIRST_BOX, F_POLICY = 0, 4, 8, 10, 11, 12, 14, 22
MODE_WALK, MODE_CARRY, YAW_EXACT = 1, 2, 0
ROOTED_TRAVEL, ROOTED_BACKWARD, ROOTED_STAIR, ROOTED_TURN = 10, 11, 12, 13
POLICY = {"empty_walk_off": ROOTED_TRAVEL, "empty_back_up": ROOTED_BACKWARD, "approach": ROOTED_TRAVEL,
          "descent": ROOTED_STAIR, "ascent": ROOTED_STAIR, "turn": ROOTED_TURN, "retreat": ROOTED_TRAVEL,
          "back_up": ROOTED_BACKWARD}
GROUPS = (("empty", 6, 31), ("wood", 6, 32), ("stone", 7, 37))  # (group, source, template row)
EMPTY_ROWS, WOOD_ROWS, STONE_ROWS = (71, 72), tuple(range(73, 79)), tuple(range(79, 85))
LOADED = ("approach", "descent", "ascent", "turn", "retreat", "back_up")


def require(value: bool, code: str) -> None:
    """Every refusal names the exact failed publication fact."""
    if not value:
        raise ValueError("STAIR_CARRY_RUNTIME_" + code)


def sha(raw: bytes) -> str:
    """Lower-case hex SHA-256."""
    return hashlib.sha256(raw).hexdigest()


def read_rows() -> list:
    """The derived rows in publication order (empty pair, wood, stone)."""
    record = json.loads(ROWS_RECORD.read_text())
    rows = record["rows"]
    require(record["decision"] == "1981" and [(r["group"], r["name"]) for r in rows] ==
            [("empty", "empty_walk_off"), ("empty", "empty_back_up")] +
            [(item, name) for item in ("wood", "stone") for name in LOADED], "ROWS_CENSUS")
    return rows


def image_digests() -> dict:
    """The two images' content digests, each verified natively."""
    result = {}
    for (source, path), verification in zip(IMAGES.items(), VERIFICATIONS):
        compiled, checked = json.loads(path.read_text()), json.loads(verification.read_text())
        require(checked["coefficient_mismatches"] == 0 and checked["clips"] == compiled["clip_names"] and
                checked["content_sha256"] == compiled["content_sha256"] and checked["runtime_admitted"] is False,
                "IMAGE_VERIFICATION")
        result[source] = bytes.fromhex(compiled["content_sha256"])
    return result


def new_rows(fields: list, derived: list) -> list:
    """(fields, boxes) of rows 71-84 from the templates' words."""
    result, at = [], 0
    for group, source, template in GROUPS:
        words = list(fields[template])
        mode = MODE_WALK if group == "empty" else MODE_CARRY
        require(words[F_SOURCE] in (2, 3) and words[F_MODE] == mode and words[F_POLICY] == 0 and
                (words[F_CARGO] == -1) == (group == "empty") and words[6] == -1, "TEMPLATE_" + group)
        count = 2 if group == "empty" else 6
        for row in derived[at:at + count]:
            require(row["group"] == group and row["family_mask"] == 1, "ROW_GROUP")
            out = list(words)
            out[F_SOURCE], out[F_YAW_KIND], out[F_YAW] = source, YAW_EXACT, row["yaw"]
            out[F_FAMILIES], out[F_POLICY] = row["family_mask"], POLICY[row["name"]]
            result.append((out, PUB7.role_boxes(row["roles"])))
        at += count
    return result


def build_wire(derived: list) -> tuple:
    """Rows 0-70 unchanged, then rows 71-84; sources 6 and 7 appended."""
    old = (OLD / "mole-worker.ugprof").read_bytes()
    require(sha(old) == OLD_WIRE_SHA, "OLD_WIRE")
    revision, digests, fields, rows = PUB7.parse(old)
    require((revision, len(fields), sum(map(len, rows)), len(digests)) == OLD_COUNTS, "OLD_COUNTS")
    images = image_digests()
    order = [(fields[i], rows[i]) for i in range(len(fields))] + new_rows(fields, derived)
    saved, PUB9.NEW_REVISION = PUB9.NEW_REVISION, NEW_REVISION  # Content 9's encoder at revision 12.
    try:
        return PUB9.encode(list(digests) + [images[6], images[7]], [list(f) for f, _ in order],
                           [list(r) for _, r in order]), old
    finally:
        PUB9.NEW_REVISION = saved


def check(old: bytes, new: bytes) -> None:
    """Sources 0-5 and rows 0-70 unchanged; each source's rows key-sorted; no two new rows share policy, key and yaw."""
    _, old_digests, old_fields, old_rows = PUB7.parse(old)
    revision, digests, fields, rows = PUB7.parse(new)
    require(revision == NEW_REVISION and len(fields) == 85 and digests[:6] == old_digests and len(digests) == 8,
            "NEW_COUNTS")
    for index in range(71):
        same = [v for k, v in enumerate(fields[index]) if k != F_FIRST_BOX] == \
            [v for k, v in enumerate(old_fields[index]) if k != F_FIRST_BOX]
        require(same and rows[index] == old_rows[index], "ROW_PRESERVED")
    for source in range(len(digests)):
        keys = [tuple(f[1:10]) + (f[16],) for f in fields if f[F_SOURCE] == source]
        require(keys == sorted(keys), "KEY_ORDER")
    seen = set()
    for f in fields[71:]:
        identity = (f[F_POLICY], tuple(f[1:10]), f[16], f[F_YAW])
        require(identity not in seen, "AMBIGUOUS_KEY")
        seen.add(identity)


def build_ground(old: bytes) -> bytes:
    """Content 11's twenty-six ground caps at revision 12."""
    require(sha(old) == OLD_GROUND_SHA, "OLD_GROUND")
    require(struct.unpack_from("<I", old, 44)[0] == 26 and struct.unpack_from("<q", old, 48)[0] == 11, "GROUND_HEADER")
    out = bytearray(old)
    struct.pack_into("<q", out, 48, NEW_REVISION)
    return bytes(out)


def rebind_motion(motion: bytes, wire_sha: str, numerical: str) -> bytes:
    """Content 11's motion bank rebound to revision 12 and the new wire."""
    require(sha(motion) == OLD_MOTION_SHA and struct.unpack_from("<q", motion, 16) == (11,) and
            motion[H.BYTE_AT + 160:H.BYTE_AT + 192].hex() == OLD_WIRE_SHA, "MOTION_LAYOUT")
    out = bytearray(motion)
    struct.pack_into("<q", out, 16, NEW_REVISION)
    struct.pack_into("<2q", out, H.I64_AT + 8, NEW_REVISION, NEW_REVISION)
    out[H.BYTE_AT + 160:H.BYTE_AT + 192] = bytes.fromhex(wire_sha)
    out[H.BYTE_AT + 384:H.BYTE_AT + 416] = bytes.fromhex(numerical)
    return bytes(out)


def row_constants(images: dict) -> str:
    """The new sources' digests and row IDs."""
    pack = lambda values: "[" + ", ".join(map(str, values)) + "]"
    return "\n".join([
        "## Decision 1981 (content 12): the stair carry (source 6 wood, source 7 stone) and the stair's empty floor end.",
        f'const STAIR_CARRY_WOOD_SOURCE_SHA: String = "{images[6].hex()}"',
        f'const STAIR_CARRY_STONE_SOURCE_SHA: String = "{images[7].hex()}"',
        "## The empty walk-off and back-up at the stair's foot (source 6, WALK).",
        f"const STAIR_EMPTY_FLOOR_ROWS: PackedInt32Array = {pack(EMPTY_ROWS)}",
        "## Approach, descent, ascent, half-turn, retreat and back-up, carrying one unit.",
        f"const STAIR_CARRY_WOOD_ROWS: PackedInt32Array = {pack(WOOD_ROWS)}",
        f"const STAIR_CARRY_STONE_ROWS: PackedInt32Array = {pack(STONE_ROWS)}"])


def accessor(old_text: str, wire_sha: str, images: dict) -> str:
    """Content 11's accessor with the new wire, the new sources and rows, and freshly read consumer digests."""
    text = old_text.replace(OLD_WIRE_SHA, wire_sha)
    text = text.replace("## Generated by publish_claw_wall_runtime.py (decision 1971). Do not edit.",
                        "## Generated by publish_stair_carry_runtime.py (decision 1981). Do not edit.")
    require(text.count("const ACTOR_SHA:") == 1 and "publish_stair_carry_runtime.py" in text, "ACCESSOR_SHAPE")
    text = text.replace("const ACTOR_SHA:", row_constants(images) + "\nconst ACTOR_SHA:", 1)
    paths = re.findall(r'"(res://[^"]+\.gd)"', text)
    found = re.search(r"const DIGESTS: PackedStringArray = \[\n(.*?)\n\]", text, re.S)
    current = [sha((ROOT / ("godot/" + p.removeprefix("res://"))).read_bytes()) for p in paths]
    return text[:found.start(1)] + "\n".join(f'\t"{d}",' for d in current) + text[found.end(1):]


def build() -> dict:
    """All outputs in memory; nothing is written here."""
    wire, old = build_wire(read_rows())
    check(old, wire)
    images = image_digests()
    ground = build_ground((OLD / "ground-pace.ugconn").read_bytes())
    pins = {str((OLD / "motion.ugmotion").relative_to(ROOT)): OLD_MOTION_SHA,
            str((OUTPUT / "mole-worker.ugprof").relative_to(ROOT)): sha(wire),
            str(Path(__file__).resolve().relative_to(ROOT)): sha(Path(__file__).read_bytes())}
    numerical = sha(json.dumps(pins, sort_keys=True, separators=(",", ":")).encode())
    motion = rebind_motion((OLD / "motion.ugmotion").read_bytes(), sha(wire), numerical)
    constants = accessor((OLD / "catalog_source.gd").read_text(), sha(wire), images)
    _, count, boxes, sources = struct.unpack_from("<qIII", wire, 12)
    manifest = {"schema": 1, "decision": ["1981", "1971", "1229", "1217"], "content_revision": NEW_REVISION,
                "profile_count": count, "box_count": boxes, "source_count": sources, "wire_sha256": sha(wire),
                "wire_bytes": len(wire), "paired_bank_bytes": 2 * (len(wire) - 8),
                "sources": {"6": images[6].hex(), "7": images[7].hex()},
                "rows": {"0-70": "content 11", "71-72": "the empty walk-off and back-up (source 6, WALK)",
                         "73-78": "the wood stair carry: approach, descent, ascent, turn, retreat, back-up (source 6)",
                         "79-84": "the stone stair carry, the same six (source 7)"},
                "inputs": {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in
                           (ROWS_RECORD, *IMAGES.values(), *VERIFICATIONS)},
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
