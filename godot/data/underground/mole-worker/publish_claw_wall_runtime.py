#!/usr/bin/env python3
"""Create-only content-11 mole profile publication `qualified-claw-wall-v12/` (decision 1971). Data only, not active.

Content 11 is content 10 (`qualified-claw-stairs-v11`, active) with the one claw stroke's wall rows:

- **Sources 0-5** and **rows 0-66** are content 10's, byte for byte (no published row moves).
- **67-70** are the wall rows at yaws 0, 16384, 32768 and 49152 (P-1971-1 (b)). Each keeps the words of content 10's
  M1 row at the same heading (56, 58, 60, 62: source 4, WORK, BUILD, SOURCE_WORK, anchor and patch) and carries
  `claw-work-v1/evidence/claw-wall-rows-v1/rows.json`'s boxes, copied as derived. They play the same dig clips.
- They are appended after source 5's rows: Profiles orders rows by key within each source only (ADR 1198), and
  source 4's same-key run grows from 9 to 13 of the 16 allowed.

**Ground paces:** content 10's twenty-six caps, unchanged; only the revision becomes 11 (WORK rows take no cap).
**Motion bank:** content 10's, rebound to revision 11 and the new wire, as each content successor did.

    python3 godot/data/underground/mole-worker/publish_claw_wall_runtime.py
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
OLD = HERE / "qualified-claw-stairs-v11"
OUTPUT = HERE / "qualified-claw-wall-v12"
OLD_WIRE_SHA = "9791eb59b778cf9fe0b4c66dfd7181c58706abd6ed1a8e6a90a73daafa7f3317"
OLD_GROUND_SHA = "e155bf5dfbbde5ddda7702b510d8e299ad8516154c69e024efb1a77f591bc081"
OLD_MOTION_SHA = "8055dd9bd31a48c71137470309bd5748e0d439a71f195aa0a5fcb0d26ca7f5d6"
ROWS_RECORD = HERE / "claw-work-v1/evidence/claw-wall-rows-v1/rows.json"
OLD_COUNTS, NEW_REVISION = (10, 67, 547, 6), 11
F_SOURCE, F_MODE, F_YAW_KIND, F_YAW, F_FIRST_BOX, F_WORK, F_CONTACT, F_POLICY = 0, 4, 10, 11, 14, 16, 17, 22
DIG_ROWS, WALL_ROWS = (56, 58, 60, 62), (67, 68, 69, 70)


def require(value: bool, code: str) -> None:
    """Every refusal names the exact failed publication fact."""
    if not value:
        raise ValueError("CLAW_WALL_RUNTIME_" + code)


def sha(raw: bytes) -> str:
    """Lower-case hex SHA-256."""
    return hashlib.sha256(raw).hexdigest()


def read_rows() -> list:
    """The derived wall rows, in heading order."""
    record = json.loads(ROWS_RECORD.read_text())
    require(record["decision"] == "1971" and record["content_10_wire_sha256"] == OLD_WIRE_SHA, "ROWS_RECORD")
    rows = record["rows"]
    require([row["yaw"] for row in rows] == [0, 16384, 32768, 49152], "ROWS_CENSUS")
    return rows


def wall_rows(fields: list, derived: list) -> list:
    """(fields, boxes) of rows 67-70: each M1 row's words with the derived wall boxes."""
    result = []
    for template, row in zip(DIG_ROWS, derived):
        words = list(fields[template])
        require(words[F_SOURCE] == 4 and words[F_MODE] == 3 and words[F_WORK] == 1 and words[F_POLICY] == 3
                and words[F_CONTACT] == 2 and words[F_YAW_KIND] == 0 and words[F_YAW] == row["yaw"], "DIG_TEMPLATE")
        result.append((words, PUB7.role_boxes(row["roles"])))
    return result


def build_wire(derived: list) -> tuple:
    """Rows 0-66 unchanged, then the four wall rows."""
    old = (OLD / "mole-worker.ugprof").read_bytes()
    require(sha(old) == OLD_WIRE_SHA, "OLD_WIRE")
    revision, digests, fields, rows = PUB7.parse(old)
    require((revision, len(fields), sum(map(len, rows)), len(digests)) == OLD_COUNTS, "OLD_COUNTS")
    order = [(fields[i], rows[i]) for i in range(len(fields))] + wall_rows(fields, derived)
    saved, PUB9.NEW_REVISION = PUB9.NEW_REVISION, NEW_REVISION  # Content 9's encoder at revision 11.
    try:
        return PUB9.encode(list(digests), [list(f) for f, _ in order], [list(r) for _, r in order]), old
    finally:
        PUB9.NEW_REVISION = saved


def check(old: bytes, new: bytes) -> None:
    """Sources and rows 0-66 unchanged; each source's rows key-sorted; source 4's same-key run within 16."""
    _, old_digests, old_fields, old_rows = PUB7.parse(old)
    revision, digests, fields, rows = PUB7.parse(new)
    require(revision == NEW_REVISION and len(fields) == 71 and digests == old_digests, "NEW_COUNTS")
    for index in range(67):
        same = [v for k, v in enumerate(fields[index]) if k != F_FIRST_BOX] == \
            [v for k, v in enumerate(old_fields[index]) if k != F_FIRST_BOX]
        require(same and rows[index] == old_rows[index], "ROW_PRESERVED")
    for source in range(len(digests)):
        keys = [tuple(f[1:10]) + (f[16],) for f in fields if f[F_SOURCE] == source]
        require(keys == sorted(keys), "KEY_ORDER")
    work = [f for f in fields if f[F_SOURCE] == 4 and f[F_MODE] == 3]
    require(len(work) == 13 and len({tuple(f[1:10]) + (f[16],) for f in work}) == 1, "KEY_RUN")


def build_ground(old: bytes) -> bytes:
    """Content 10's twenty-six ground caps at revision 11."""
    require(sha(old) == OLD_GROUND_SHA, "OLD_GROUND")
    require(struct.unpack_from("<I", old, 44)[0] == 26 and struct.unpack_from("<q", old, 48)[0] == 10, "GROUND_HEADER")
    out = bytearray(old)
    struct.pack_into("<q", out, 48, NEW_REVISION)
    return bytes(out)


def rebind_motion(motion: bytes, wire_sha: str, numerical: str) -> bytes:
    """Content 10's motion bank rebound to revision 11 and the new wire."""
    require(sha(motion) == OLD_MOTION_SHA and struct.unpack_from("<q", motion, 16) == (10,) and
            motion[H.BYTE_AT + 160:H.BYTE_AT + 192].hex() == OLD_WIRE_SHA, "MOTION_LAYOUT")
    out = bytearray(motion)
    struct.pack_into("<q", out, 16, NEW_REVISION)
    struct.pack_into("<2q", out, H.I64_AT + 8, NEW_REVISION, NEW_REVISION)
    out[H.BYTE_AT + 160:H.BYTE_AT + 192] = bytes.fromhex(wire_sha)
    out[H.BYTE_AT + 384:H.BYTE_AT + 416] = bytes.fromhex(numerical)
    return bytes(out)


def accessor(old_text: str, wire_sha: str) -> str:
    """Content 10's accessor with the new wire, the wall rows and freshly read consumer digests."""
    text = old_text.replace(OLD_WIRE_SHA, wire_sha)
    text = text.replace("## Generated by publish_claw_stairs_runtime.py (ADR 1229). Do not edit.",
                        "## Generated by publish_claw_wall_runtime.py (decision 1971). Do not edit.")
    require(text.count("const ACTOR_SHA:") == 1, "ACCESSOR_SHAPE")
    rows = ", ".join(map(str, WALL_ROWS))
    text = text.replace("const ACTOR_SHA:", "## Decision 1971 (content 11): the one claw stroke's wall rows, yaws 0..49152."
                        f"\nconst CLAW_WALL_ROWS: PackedInt32Array = [{rows}]\nconst ACTOR_SHA:", 1)
    paths = re.findall(r'"(res://[^"]+\.gd)"', text)
    found = re.search(r"const DIGESTS: PackedStringArray = \[\n(.*?)\n\]", text, re.S)
    current = [sha((ROOT / ("godot/" + p.removeprefix("res://"))).read_bytes()) for p in paths]
    return text[:found.start(1)] + "\n".join(f'\t"{d}",' for d in current) + text[found.end(1):]


def build() -> dict:
    """All outputs in memory; nothing is written here."""
    wire, old = build_wire(read_rows())
    check(old, wire)
    ground = build_ground((OLD / "ground-pace.ugconn").read_bytes())
    pins = {str((OLD / "motion.ugmotion").relative_to(ROOT)): OLD_MOTION_SHA,
            str((OUTPUT / "mole-worker.ugprof").relative_to(ROOT)): sha(wire),
            str(Path(__file__).resolve().relative_to(ROOT)): sha(Path(__file__).read_bytes())}
    numerical = sha(json.dumps(pins, sort_keys=True, separators=(",", ":")).encode())
    motion = rebind_motion((OLD / "motion.ugmotion").read_bytes(), sha(wire), numerical)
    constants = accessor((OLD / "catalog_source.gd").read_text(), sha(wire))
    _, count, boxes, _ = struct.unpack_from("<qIII", wire, 12)
    manifest = {"schema": 1, "decision": ["1971", "1229", "1217"], "content_revision": NEW_REVISION,
                "profile_count": count, "box_count": boxes, "source_count": 6, "wire_sha256": sha(wire),
                "wire_bytes": len(wire), "paired_bank_bytes": 2 * (len(wire) - 8),
                "rows": {"0-66": "content 10", "67-70": "the claw stroke's wall rows, yaws 0..49152 (M1's clips)"},
                "inputs": {str(ROWS_RECORD.relative_to(ROOT)): sha(ROWS_RECORD.read_bytes())},
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
