#!/usr/bin/env python3
"""Create-only content-7 mole profile publication `qualified-claw-v8/` (ADR 1217 step 4; DEC-052). Data only.

Content 7 is content 6 (`qualified-stone-v7`) with:

- **sources 2 and 3** swapped to the haul images that carry the corrected stand, walk and joins (wood v10, stone v10;
  ADR 1217 step 3a), and **rows 30/31** (tool-free STAND/WALK) re-derived from those clips
  (`stand-walk-v2/proof.json`, the accepted `prove_empty_walk.derive_rows`): the body sweep grows from 651 to 712 u;
- **source 4**, the claw/paw image (step 3b), and its **nine rows** after row 41, from `claw-rows-v1/rows.json`:

      42 dig  yaw 0      44 seat (handling, ASSEMBLY)   43 tap yaw 0
      45 dig  yaw 16384  46 tap yaw 16384
      47 dig  yaw 32768  48 tap yaw 32768
      49 dig  yaw 49152  50 tap yaw 49152

  (per-source key order: every row of a heading shares one key; within a key, dig, tap, then the handling row).
  Dig and tap rows copy rows 13 and 16's descriptor words (BUILD WORK, anchor-and-patch contact, source-work
  policy, states 329) with no tool; the handling row copies row 29's (states 457, assembly-palm contact,
  assembly-handling policy) with no tool.

Rows 0–29 and 32–41 keep their exact bytes, so no published ID moves; the pick rows stay published and dormant
(DEC-052). Every box is copied from the derived records; nothing is widened or invented. The ground pace catalog
and motion bank are rebound to the new wire and revision only. Activation is separate (ADR 1217 step 5).

    python3 godot/data/underground/mole-worker/publish_claw_runtime.py
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import struct
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = HERE / "qualified-stone-v7"
OUTPUT = HERE / "qualified-claw-v8"
OLD_WIRE_SHA = "30c3dc1f5e9162f5530f410c437ed6f85d28dc6879f88dec81cb193ea87b0df5"
OLD_GROUND_SHA = "7fc1eeb45200292dd90e5659c494159485e56b0b487cbfc5c70d1346b2c6dc13"
OLD_MOTION_SHA = "3024e922f8959f0c386ba9c5d136cdc2a96c35c9de5c860dec03030a9b4d292c"
WOOD_V10 = HERE / "stand-walk-v2/evidence/native-haul-v10-wood/compiled"
STONE_V10 = HERE / "stand-walk-v2/evidence/native-haul-v10-stone/compiled"
CLAW = HERE / "claw-work-v1/evidence/native-claw-v1/compiled"
INPUTS = {"wood": (WOOD_V10 / "haul-handling.ugactor", "fa8dc668f7ae881d5fcc88a9dd1b6796b7f37466d0cca5e1994647e04a54dc71"),
          "stone": (STONE_V10 / "stone-handling.ugactor", "1756932c3839c3dbf2d66a715f65f5dfea7861ddafdf7f5921687b821040e6e6"),
          "claw": (CLAW / "claw-paw.ugactor", "6be24202d75c31011423de4fe8dd62358d66497412f733c087c3b130561caae6"),
          "rows": (HERE / "claw-work-v1/evidence/claw-rows-v1/rows.json",
                   "540bb052151f3c54a8972640e6ad7067967083b22f8dbd6f075e94aa131666e0"),
          "stand_rows": (HERE / "stand-walk-v2/evidence/stand-walk-v2/proof.json",
                         "6a90c2887e587471ce0ee82eff176512aecb6881347a227c6b4ba2e36ebb8190")}
HEADER, ROW, BOX = struct.Struct("<8sIqIII"), struct.Struct("<18i3q2B"), struct.Struct("<7i")
OLD_COUNTS, NEW_REVISION, CLAW_SOURCE = (6, 42, 377, 4), 7, 4
ROLES = {"BODY_HELD_LOAD": 0, "STANCE_SUPPORT": 1, "TURN_RECOVERY": 2, "WORK_APPROACH": 3, "WORK_STROKE": 4,
         "CONTACT_POINT": 5, "CONTACT_PATCH": 6}
TEMPLATE = {"dig": 13, "tap": 16, "seat": 29}
STAND_ROWS = {30: "A STAND", 31: "A' WALK"}
F_SOURCE, F_TOOL, F_TOOL_VARIANT, F_YAW, F_FIRST_BOX, F_BOX_COUNT = 0, 6, 7, 11, 14, 15


def require(value: bool, code: str) -> None:
    """Every refusal names the exact failed publication fact."""
    if not value:
        raise ValueError("CLAW_RUNTIME_" + code)


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
    stand = json.loads((HERE / "stand-walk-v2/evidence/native-haul-v10-wood/compiled/compilation.json").read_text())
    require(any(k.endswith("stand-walk-v2/candidate.json") for k in stand["source_sha256"]), "STAND_RECORD")
    return data


def parse(wire: bytes) -> tuple:
    """(sources, rows as field lists, boxes per row) of a UGPROF01 wire."""
    magic, version, revision, count, boxes, sources = HEADER.unpack_from(wire)
    require(magic == b"UGPROF01" and version == 2 and wire[-8:] == b"UGPEND01", "WIRE_FORMAT")
    digests = [wire[32 + 32 * s:64 + 32 * s] for s in range(sources)]
    at = 32 + 32 * sources
    fields = [list(ROW.unpack_from(wire, at + 98 * r)) for r in range(count)]
    base = at + 98 * count
    rows = [[BOX.unpack_from(wire, base + 28 * k) for k in range(f[F_FIRST_BOX], f[F_FIRST_BOX] + f[F_BOX_COUNT])]
            for f in fields]
    return revision, digests, fields, rows


def role_boxes(roles: dict) -> list:
    """Boxes in ascending role order, exactly as derived."""
    result = []
    for name, role in sorted(ROLES.items(), key=lambda item: item[1]):
        result.extend(tuple(box) + (role,) for box in roles.get(name, []))
    return result


def claw_rows(old_fields: list, record: dict) -> list:
    """(fields, boxes) of the nine claw rows, in per-source key order."""
    derived = {(row["program"], row["yaw"]): row for row in record["rows"]}
    order = [(0, "dig"), (0, "tap"), (0, "seat")] + [(yaw, name) for yaw in (16384, 32768, 49152)
                                                   for name in ("dig", "tap")]
    result = []
    for yaw, name in order:
        fields = list(old_fields[TEMPLATE[name]])
        require(fields[F_TOOL] == 54 and fields[F_YAW] == 0, "TEMPLATE_ROW")
        fields[F_SOURCE], fields[F_TOOL], fields[F_TOOL_VARIANT], fields[F_YAW] = CLAW_SOURCE, -1, -1, yaw
        result.append((fields, role_boxes(derived[(name, yaw)]["roles"])))
    return result


def stand_rows(old_rows: list, proof: dict) -> dict:
    """Rows 30/31 boxes from the corrected derivation; the role layout must be unchanged."""
    derived = {row["row"]: row for row in proof["rows"]["rows"]}
    result = {}
    for index, name in STAND_ROWS.items():
        boxes = role_boxes(derived[name]["roles"])
        require(len(boxes) == len(old_rows[index]) and [b[6] for b in boxes] == [b[6] for b in old_rows[index]],
                "STAND_ROW_LAYOUT")
        result[index] = boxes
    return result


def encode(digests: list, fields: list, rows: list) -> bytes:
    """A complete UGPROF01 wire; first-box indices recomputed in row order."""
    count, total = len(fields), sum(map(len, rows))
    wire = HEADER.pack(b"UGPROF01", 2, NEW_REVISION, count, total, len(digests)) + b"".join(digests)
    first, packed, boxes = 0, b"", b""
    for row_fields, row_boxes in zip(fields, rows):
        row_fields = list(row_fields)
        row_fields[F_FIRST_BOX], row_fields[F_BOX_COUNT] = first, len(row_boxes)
        packed += ROW.pack(*row_fields)
        boxes += b"".join(BOX.pack(*box) for box in row_boxes)
        first += len(row_boxes)
    return wire + packed + boxes + b"UGPEND01"


def build_wire(data: dict) -> tuple:
    """Content 7's wire and the facts its checks need."""
    old = (OLD / "mole-worker.ugprof").read_bytes()
    require(sha(old) == OLD_WIRE_SHA, "OLD_WIRE")
    revision, digests, fields, rows = parse(old)
    require((revision, len(fields), sum(map(len, rows)), len(digests)) == OLD_COUNTS, "OLD_COUNTS")
    digests = digests[:2] + [bytes.fromhex(sha(data["wood"])), bytes.fromhex(sha(data["stone"])),
                             bytes.fromhex(sha(data["claw"]))]
    rows = [list(r) for r in rows]
    for index, boxes in stand_rows(rows, json.loads(data["stand_rows"])).items():
        rows[index] = boxes
    for row_fields, row_boxes in claw_rows(fields, json.loads(data["rows"])):
        fields.append(row_fields)
        rows.append(row_boxes)
    return encode(digests, fields, rows), old


def check(old: bytes, new: bytes) -> None:
    """Unchanged rows keep their words and boxes; sources 0/1 keep their digests; claw keys are sorted."""
    _, old_digests, old_fields, old_rows = parse(old)
    revision, digests, fields, rows = parse(new)
    require(revision == NEW_REVISION and len(fields) == 51 and len(digests) == 5 and digests[:2] == old_digests[:2],
            "NEW_COUNTS")
    for index in range(42):
        same_words = [v for k, v in enumerate(fields[index]) if k not in (F_FIRST_BOX,)] == \
            [v for k, v in enumerate(old_fields[index]) if k not in (F_FIRST_BOX,)]
        require(same_words and (index in STAND_ROWS or rows[index] == old_rows[index]), "ROW_PRESERVED")
    block = [f for f in fields if f[F_SOURCE] == CLAW_SOURCE]
    keys = [tuple(f[1:10]) + (f[16],) for f in block]
    require(len(block) == 9 and keys == sorted(keys) and all(f[F_TOOL] == -1 for f in block), "CLAW_KEY_ORDER")


def build_ground(old: bytes) -> bytes:
    """The content-6 ground paces, revision bumped only."""
    require(sha(old) == OLD_GROUND_SHA, "OLD_GROUND")
    out = bytearray(old)
    struct.pack_into("<q", out, 48, NEW_REVISION)
    return bytes(out)


def rebind_motion(motion: bytes, wire_sha: str, numerical: str) -> bytes:
    """`publish_stone_runtime.rebind_motion`'s rule: profile revisions, wire digest and input manifest only."""
    sys.path.insert(0, str(HERE))
    import publish_haul_runtime as H
    require(sha(motion) == OLD_MOTION_SHA and struct.unpack_from("<q", motion, 16) == (6,) and
            motion[H.BYTE_AT + 160:H.BYTE_AT + 192].hex() == OLD_WIRE_SHA, "MOTION_LAYOUT")
    out = bytearray(motion)
    struct.pack_into("<q", out, 16, NEW_REVISION)
    struct.pack_into("<2q", out, H.I64_AT + 8, NEW_REVISION, NEW_REVISION)
    out[H.BYTE_AT + 160:H.BYTE_AT + 192] = bytes.fromhex(wire_sha)
    out[H.BYTE_AT + 384:H.BYTE_AT + 416] = bytes.fromhex(numerical)
    return bytes(out)


def accessor(old_text: str, wire_sha: str, data: dict) -> str:
    """Content 6's accessor shape with the new wire and source digests, and current consumer digests."""
    text = old_text.replace(OLD_WIRE_SHA, wire_sha)
    text = text.replace("## Generated by publish_stone_runtime.py (ADR 1206). Do not edit.",
                        "## Generated by publish_claw_runtime.py (ADR 1217). Do not edit.")
    text = re.sub(r'const HAUL_SOURCE_SHA: String = "[0-9a-f]{64}"', f'const HAUL_SOURCE_SHA: String = "{sha(data["wood"])}"', text)
    text = re.sub(r'const STONE_SOURCE_SHA: String = "[0-9a-f]{64}"', f'const STONE_SOURCE_SHA: String = "{sha(data["stone"])}"', text)
    text = text.replace("const ACTOR_SHA:", f'const CLAW_SOURCE_SHA: String = "{sha(data["claw"])}"\nconst ACTOR_SHA:', 1)
    paths = re.findall(r'"(res://[^"]+\.gd)"', text)
    digests = re.search(r"const DIGESTS: PackedStringArray = \[\n(.*?)\n\]", text, re.S)
    current = [sha((ROOT / ("godot/" + p.removeprefix("res://"))).read_bytes()) for p in paths]
    return text[:digests.start(1)] + "\n".join(f'\t"{d}",' for d in current) + text[digests.end(1):]


def build() -> dict:
    """All outputs in memory; nothing is written here."""
    data = read_inputs()
    wire, old = build_wire(data)
    check(old, wire)
    ground = build_ground((OLD / "ground-pace.ugconn").read_bytes())
    pins = {str((OLD / "motion.ugmotion").relative_to(ROOT)): OLD_MOTION_SHA,
            str((OUTPUT / "mole-worker.ugprof").relative_to(ROOT)): sha(wire),
            str(Path(__file__).resolve().relative_to(ROOT)): sha(Path(__file__).read_bytes())}
    numerical = sha(json.dumps(pins, sort_keys=True, separators=(",", ":")).encode())
    motion = rebind_motion((OLD / "motion.ugmotion").read_bytes(), sha(wire), numerical)
    constants = accessor((OLD / "catalog_source.gd").read_text(), sha(wire), data)
    _, count, boxes, _ = struct.unpack_from("<qIII", wire, 12)
    manifest = {"schema": 1, "decision": "1217", "content_revision": NEW_REVISION, "profile_count": count,
                "box_count": boxes, "source_count": 5, "wire_sha256": sha(wire), "wire_bytes": len(wire),
                "paired_bank_bytes": 2 * (len(wire) - 8),
                "sources": {"2": sha(data["wood"]), "3": sha(data["stone"]), "4": sha(data["claw"])},
                "re_derived_rows": {"30": "STAND, corrected stand (ADR 1217 step 1c)", "31": "WALK, corrected walk"},
                "claw_rows": {"42": "dig yaw 0", "43": "tap yaw 0", "44": "paw handling yaw 0", "45": "dig yaw 16384",
                              "46": "tap yaw 16384", "47": "dig yaw 32768", "48": "tap yaw 32768",
                              "49": "dig yaw 49152", "50": "tap yaw 49152"},
                "dormant_rows": "0-29 (pick, DEC-052)", "superset_of": {"wire_sha256": OLD_WIRE_SHA},
                "inputs": {str(p.relative_to(ROOT)): sha(data[n]) for n, (p, _) in INPUTS.items()},
                "ground_sha256": sha(ground), "motion_sha256": sha(motion), "motion_inputs": pins,
                "motion_numerical_input_sha256": numerical, "runtime_admitted": False,
                "not_qualified": ["source programs and Routes dispatch for source 4 (ADR 1217 step 5)",
                                  "presentation of source 4", "consumer renewal and activation"]}
    return {"mole-worker.ugprof": wire, "ground-pace.ugconn": ground, "motion.ugmotion": motion,
            "catalog_source.gd": constants.encode(), "manifest.json": (json.dumps(manifest, indent=2) + "\n").encode()}


def main() -> int:
    """Create the publication exactly once."""
    require(not OUTPUT.exists(), "OUTPUT_EXISTS")
    outputs = build()
    OUTPUT.mkdir()
    for name, raw in outputs.items():
        (OUTPUT / name).write_bytes(raw)
    print("published", OUTPUT.relative_to(ROOT), "wire", sha(outputs["mole-worker.ugprof"])[:12],
          "motion", sha(outputs["motion.ugmotion"])[:12])
    return 0


if __name__ == "__main__":
    sys.exit(main())
