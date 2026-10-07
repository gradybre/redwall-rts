#!/usr/bin/env python3
"""Create-only content-8 mole profile publication `qualified-claw-split-v9/` (ADR 1217 step 4c; DEC-052). Data only.

Content 8 is content 7 (`qualified-claw-v8`, which stays published and unused) with the claw/paw source split in
two, mirroring the pick/assembly split of sources 0 and 1 (ADR 1190: one Frontier source; a distinct set-down
program):

- **source 4** is the claw image (stand, walk, dig and tap clips; `native-claw-split-v1/claw`), and **source 5** the
  paw-handling image (the seat clips; `native-claw-split-v1/paw`). Sources 0-3 keep content 7's digests.
- **Rows 0-41** keep content 7's words and boxes exactly, so no published ID moves.
- **Source 4's block**, in key order:

      42 WALK, YAW_ALL, POLICY_CANONICAL_GROUND   (claw-split-rows-v1/stand-walk.json)
      43 dig yaw 0      44 tap yaw 0
      45 dig yaw 16384  46 tap yaw 16384
      47 dig yaw 32768  48 tap yaw 32768
      49 dig yaw 49152  50 tap yaw 49152           (content 7's rows 42, 43, 45-50, words and boxes, re-homed)

- **Source 5's block:** 51, paw handling (content 7's row 44, re-homed).

**The WALK row's policy.** Rows 30/31 are automatic. An automatic source-4 STAND or WALK would have exactly row
30's or 31's identity, and Profiles refuses such a pair at load (`PROFILE_AMBIGUOUS_KEY`: the key excludes the
source). Profiles admits non-automatic policies on WALK rows only, and the only one a YAW_ALL WALK may carry is
`POLICY_CANONICAL_GROUND`, the policy of the pick's Frontier travel row 12. Row 42 therefore copies row 31's words
with source 4 and that policy, which makes it the tool-free counterpart of row 12. The derived STAND row cannot be
published: no other policy is admitted for STAND, and an automatic copy is ambiguous. Every box is copied from a
derived record; nothing is widened or invented.

**Ground paces.** Row 42 gets a RATE_GROUND_CAP row (family -1), as rows 1-12, 31, 32 and 37 have, reusing the
adopted Movement profile and cap. No new pace constant exists. The ground catalog binds source 4, the Frontier
source, so that a first-entry bundle can carry these bytes unchanged next to a structure that binds source 4
(`entry_source_constants`: the ground and structure headers must agree). It holds only ground caps, which may name
any source of the content (ADR 1200), so the binding grants nothing.

The motion bank is rebound to the new wire and revision only. Activation is separate (ADR 1217 step 5).

    python3 godot/data/underground/mole-worker/publish_claw_split_runtime.py
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import struct
import sys

import publish_claw_runtime as PUB7
import publish_haul_runtime as H

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = HERE / "qualified-claw-v8"
OUTPUT = HERE / "qualified-claw-split-v9"
OLD_WIRE_SHA = "8b79294f390fb8b16899ca83be70d01baa0eaf800f071d9042e2e1250cff2355"
OLD_GROUND_SHA = "50d1400aa6a1f1a5b116a9e62d3cfb08a5bc61bf555428472529669860d7e5fd"
OLD_MOTION_SHA = "482456e1f9b6c58264b39b243d8faebd2083f7d1cc99a8eacbf1c0af9c4cdbe3"
SPLIT = HERE / "claw-work-v1/evidence/native-claw-split-v1"
INPUTS = {"claw": (SPLIT / "claw/compiled/claw.ugactor",
                   "2b58852e0e39d3ae1c697ed5487081cead7ce80efc8a30662e469fd33059af5b"),
          "paw": (SPLIT / "paw/compiled/paw-handling.ugactor",
                  "cbe80b76b3b9eb5fbd857865eac27b7a0c6f0fa251df53e52c471c457a865e2a"),
          "rows": PUB7.INPUTS["rows"],
          "walk": (HERE / "claw-work-v1/evidence/claw-split-rows-v1/stand-walk.json",
                   "85394d1842971cc2ba3f845da88f2bcbedc5fdce4e2ffcba7ae6791561008f24")}
OLD_COUNTS, NEW_REVISION, CLAW_SOURCE, PAW_SOURCE = (7, 51, 472, 5), 8, 4, 5
F_SOURCE, F_FIRST_BOX, F_BOX_COUNT, F_POLICY = PUB7.F_SOURCE, PUB7.F_FIRST_BOX, PUB7.F_BOX_COUNT, 22
POLICY_AUTOMATIC, POLICY_CANONICAL_GROUND = 0, 6
WALK_TEMPLATE = 31
CLAW_ROWS = (42, 43, 45, 46, 47, 48, 49, 50)  # content 7's dig/tap rows, in content 7's key order
HANDLING_ROW = 44
KEEP = 42  # rows 0-41
NEW_ROWS = {42: "WALK, YAW_ALL, canonical ground (source 4)", 43: "dig yaw 0", 44: "tap yaw 0",
            45: "dig yaw 16384", 46: "tap yaw 16384", 47: "dig yaw 32768", 48: "tap yaw 32768",
            49: "dig yaw 49152", 50: "tap yaw 49152", 51: "paw handling yaw 0 (source 5)"}
GROUND_PACE_PROFILES = (42,)


def require(value: bool, code: str) -> None:
    """Every refusal names the exact failed publication fact."""
    if not value:
        raise ValueError("CLAW_SPLIT_RUNTIME_" + code)


def sha(raw: bytes) -> str:
    """Lower-case hex SHA-256."""
    return hashlib.sha256(raw).hexdigest()


def read_inputs() -> dict:
    """Every input pinned by SHA-256."""
    data = {}
    for name, (path, digest) in INPUTS.items():
        raw = path.read_bytes()
        require(sha(raw) == digest, "INPUT_" + name.upper())
        data[name] = raw
    return data


def walk_row(fields: list, rows: list, record: dict) -> tuple:
    """Row 31's words on source 4 with the canonical-ground policy; boxes from the derived WALK roles."""
    derived = {row["row"]: row for row in record["rows"]}["claw WALK"]
    require(derived["mode"] == 1 and derived["yaw_kind"] == "YAW_ALL" and derived["tool"] == -1, "WALK_RECORD")
    boxes = PUB7.role_boxes(derived["roles"])
    template = list(fields[WALK_TEMPLATE])
    require(template[F_POLICY] == POLICY_AUTOMATIC and template[4] == 1 and template[10] == 1, "WALK_TEMPLATE")
    require([b[6] for b in boxes] == [b[6] for b in rows[WALK_TEMPLATE]], "WALK_LAYOUT")
    template[F_SOURCE], template[F_POLICY] = CLAW_SOURCE, POLICY_CANONICAL_GROUND
    return template, boxes


def claw_rows_checked(fields: list, rows: list, record: dict) -> None:
    """Content 7's claw rows are exactly the derived record's boxes (content 7's own publication rule)."""
    derived = {(row["program"], row["yaw"]): PUB7.role_boxes(row["roles"]) for row in record["rows"]}
    order = [(0, "dig"), (0, "tap"), (0, "seat")] + [(y, n) for y in (16384, 32768, 49152) for n in ("dig", "tap")]
    for index, (yaw, name) in enumerate(order):
        require(rows[42 + index] == derived[(name, yaw)] and fields[42 + index][F_SOURCE] == CLAW_SOURCE, "CLAW_ROWS")


def encode(digests: list, fields: list, rows: list) -> bytes:
    """A complete UGPROF01 wire; first-box indices recomputed in row order."""
    wire = PUB7.HEADER.pack(b"UGPROF01", 2, NEW_REVISION, len(fields), sum(map(len, rows)), len(digests))
    wire += b"".join(digests)
    first, packed, boxes = 0, b"", b""
    for row_fields, row_boxes in zip(fields, rows):
        row_fields = list(row_fields)
        row_fields[F_FIRST_BOX], row_fields[F_BOX_COUNT] = first, len(row_boxes)
        packed += PUB7.ROW.pack(*row_fields)
        boxes += b"".join(PUB7.BOX.pack(*box) for box in row_boxes)
        first += len(row_boxes)
    return wire + packed + boxes + b"UGPEND01"


def build_wire(data: dict) -> tuple:
    """Content 8's wire from content 7's rows and the two split images."""
    old = (OLD / "mole-worker.ugprof").read_bytes()
    require(sha(old) == OLD_WIRE_SHA, "OLD_WIRE")
    revision, digests, fields, rows = PUB7.parse(old)
    require((revision, len(fields), sum(map(len, rows)), len(digests)) == OLD_COUNTS, "OLD_COUNTS")
    claw_rows_checked(fields, rows, json.loads(data["rows"]))
    walk = walk_row(fields, rows, json.loads(data["walk"]))
    new_digests = digests[:4] + [bytes.fromhex(sha(data["claw"])), bytes.fromhex(sha(data["paw"]))]
    new_fields, new_rows = [list(f) for f in fields[:KEEP]], [list(r) for r in rows[:KEEP]]
    new_fields.append(walk[0])
    new_rows.append(walk[1])
    for index in CLAW_ROWS:
        new_fields.append(list(fields[index]))
        new_rows.append(list(rows[index]))
    handling = list(fields[HANDLING_ROW])
    handling[F_SOURCE] = PAW_SOURCE
    new_fields.append(handling)
    new_rows.append(list(rows[HANDLING_ROW]))
    return encode(new_digests, new_fields, new_rows), old


def check(old: bytes, new: bytes) -> None:
    """Rows 0-41 and sources 0-3 unchanged; each new block key-sorted; nothing on source 4/5 holds a tool."""
    _, old_digests, old_fields, old_rows = PUB7.parse(old)
    revision, digests, fields, rows = PUB7.parse(new)
    require(revision == NEW_REVISION and len(fields) == 52 and len(digests) == 6 and digests[:4] == old_digests[:4],
            "NEW_COUNTS")
    for index in range(KEEP):
        same = [v for k, v in enumerate(fields[index]) if k != F_FIRST_BOX] == \
            [v for k, v in enumerate(old_fields[index]) if k != F_FIRST_BOX]
        require(same and rows[index] == old_rows[index], "ROW_PRESERVED")
    for source, count in ((CLAW_SOURCE, 9), (PAW_SOURCE, 1)):
        block = [f for f in fields if f[F_SOURCE] == source]
        keys = [tuple(f[1:10]) + (f[16],) for f in block]
        require(len(block) == count and keys == sorted(keys) and all(f[6] == -1 for f in block), "KEY_ORDER")
    require([f[F_SOURCE] for f in fields[KEEP:]] == [CLAW_SOURCE] * 9 + [PAW_SOURCE], "BLOCK_LAYOUT")


def build_ground(old: bytes, claw_digest: bytes) -> bytes:
    """Content 7's ground caps plus row 42's cap; revision 8; bound to source 4 (the Frontier source)."""
    require(sha(old) == OLD_GROUND_SHA, "OLD_GROUND")
    head = struct.unpack_from("<8sIq7I3q", old)
    require(head == (b"UGCONN01", 2, 1, 0, 0, 0, 0, 0, 0, 15, 7, 1, 0) and len(old) == 684, "GROUND_HEADER")
    paces = [H.PACE.unpack_from(old, 136 + 36 * r) for r in range(15)]
    require(all(p[1:] == (-1, 0, 1, 1, 0, 0, 1) for p in paces) and paces[-1][0] < GROUND_PACE_PROFILES[0], "GROUND_ROWS")
    out = bytearray(old[:-8])
    struct.pack_into("<I", out, 44, 15 + len(GROUND_PACE_PROFILES))
    struct.pack_into("<q", out, 48, NEW_REVISION)
    struct.pack_into("<q", out, 64, CLAW_SOURCE)
    out[72:104] = claw_digest
    for profile in GROUND_PACE_PROFILES:
        out += H.PACE.pack(profile, *paces[0][1:])
    return bytes(out) + b"UGCEND01"


def rebind_motion(motion: bytes, wire_sha: str, numerical: str) -> bytes:
    """The content-7 rule: profile revisions, wire digest and input manifest digest only."""
    require(sha(motion) == OLD_MOTION_SHA and struct.unpack_from("<q", motion, 16) == (7,) and
            motion[H.BYTE_AT + 160:H.BYTE_AT + 192].hex() == OLD_WIRE_SHA, "MOTION_LAYOUT")
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


def accessor(old_text: str, wire_sha: str, data: dict) -> str:
    """Content 7's accessor shape with the new wire, the split source digests, and current consumer digests."""
    text = old_text.replace(OLD_WIRE_SHA, wire_sha)
    text = text.replace("## Generated by publish_claw_runtime.py (ADR 1217). Do not edit.",
                        "## Generated by publish_claw_split_runtime.py (ADR 1217 step 4c). Do not edit.")
    text = re.sub(r'const CLAW_SOURCE_SHA: String = "[0-9a-f]{64}"',
                  f'const CLAW_SOURCE_SHA: String = "{sha(data["claw"])}"\n'
                  f'const PAW_SOURCE_SHA: String = "{sha(data["paw"])}"', text)
    require(text.count(sha(data["claw"])) == 1 and text.count(sha(data["paw"])) == 1, "ACCESSOR_SOURCES")
    paths = re.findall(r'"(res://[^"]+\.gd)"', text)
    digests = re.search(r"const DIGESTS: PackedStringArray = \[\n(.*?)\n\]", text, re.S)
    current = [sha((ROOT / ("godot/" + p.removeprefix("res://"))).read_bytes()) for p in paths]
    return text[:digests.start(1)] + "\n".join(f'\t"{d}",' for d in current) + text[digests.end(1):]


def manifest(wire: bytes, ground: bytes, motion: bytes, pins: dict, numerical: str, data: dict) -> dict:
    """The publication record."""
    _, count, boxes, _ = struct.unpack_from("<qIII", wire, 12)
    return {"schema": 1, "decision": "1217", "content_revision": NEW_REVISION, "profile_count": count,
            "box_count": boxes, "source_count": 6, "wire_sha256": sha(wire), "wire_bytes": len(wire),
            "paired_bank_bytes": 2 * (len(wire) - 8), "sources": {"4": sha(data["claw"]), "5": sha(data["paw"])},
            "new_rows": {str(k): v for k, v in NEW_ROWS.items()},
            "walk_policy": "POLICY_CANONICAL_GROUND: an automatic copy of row 30/31 is PROFILE_AMBIGUOUS_KEY",
            "stand_row": "not published: STAND admits only the automatic policy, which duplicates row 30's key",
            "dormant_rows": "0-29 (pick, DEC-052)", "superset_of": {"wire_sha256": OLD_WIRE_SHA, "rows": "0-41"},
            "inputs": {str(p.relative_to(ROOT)): sha(data[n]) for n, (p, _) in INPUTS.items()},
            "ground_sha256": sha(ground), "ground_pace_profiles": list(GROUND_PACE_PROFILES),
            "ground_source": CLAW_SOURCE, "motion_sha256": sha(motion), "motion_inputs": pins,
            "motion_numerical_input_sha256": numerical, "runtime_admitted": False,
            "not_qualified": ["source programs and Routes dispatch for sources 4/5 (ADR 1217 step 5)",
                              "presentation of sources 4/5", "consumer renewal and activation"]}


def build() -> dict:
    """All outputs in memory; nothing is written here."""
    data = read_inputs()
    wire, old = build_wire(data)
    check(old, wire)
    ground = build_ground((OLD / "ground-pace.ugconn").read_bytes(), bytes.fromhex(sha(data["claw"])))
    pins = {str((OLD / "motion.ugmotion").relative_to(ROOT)): OLD_MOTION_SHA,
            str((OUTPUT / "mole-worker.ugprof").relative_to(ROOT)): sha(wire),
            str(Path(__file__).resolve().relative_to(ROOT)): sha(Path(__file__).read_bytes())}
    numerical = sha(json.dumps(pins, sort_keys=True, separators=(",", ":")).encode())
    motion = rebind_motion((OLD / "motion.ugmotion").read_bytes(), sha(wire), numerical)
    constants = accessor((OLD / "catalog_source.gd").read_text(), sha(wire), data)
    record = manifest(wire, ground, motion, pins, numerical, data)
    return {"mole-worker.ugprof": wire, "ground-pace.ugconn": ground, "motion.ugmotion": motion,
            "catalog_source.gd": constants.encode(), "manifest.json": (json.dumps(record, indent=2) + "\n").encode()}


def main() -> int:
    """Create the publication exactly once."""
    require(not OUTPUT.exists(), "OUTPUT_EXISTS")
    outputs = build()
    OUTPUT.mkdir()
    for name, raw in outputs.items():
        (OUTPUT / name).write_bytes(raw)
    print("published", OUTPUT.relative_to(ROOT), "wire", sha(outputs["mole-worker.ugprof"])[:12],
          "ground", sha(outputs["ground-pace.ugconn"])[:12], "motion", sha(outputs["motion.ugmotion"])[:12])
    return 0


if __name__ == "__main__":
    sys.exit(main())
