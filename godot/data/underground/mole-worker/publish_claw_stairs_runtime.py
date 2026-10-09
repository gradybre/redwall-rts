#!/usr/bin/env python3
"""Create-only content-10 mole profile publication `qualified-claw-stairs-v11/` (ADR 1229). Data only.

Content 10 is content 9 (`qualified-claw-approach-v10`, active) with the tread and stair rows:

- **Sources 0-3** are content 9's. **Source 4** is the claw v2 image (`b85f9195...`: content 9's eight clips plus
  the tread tap, the two short steps, the descent, the ascent and the half-turn) and **source 5** the paw v2 image
  (`9cdafc55...`: plus the tread handling seat). Both are native-verified (ADR 1217 §6.1).
- **Rows 0-50** keep content 9's words and boxes.
- **51-55** are new source-4 WALK rows, each with row 42's words and these changes:
  - 51: step back (POLICY_SHORT_BACKWARD, YAW_EXACT 0);
  - 52: step forward (POLICY_SHORT_FORWARD, YAW_EXACT 0);
  - 53: descent (POLICY_STAIR, YAW_EXACT 0, family mask 1 = EARTH_TIMBER);
  - 54: ascent (POLICY_STAIR, YAW_EXACT 32768, family mask 1);
  - 55: half-turn (POLICY_STAIR_TURN, YAW_EXACT 0, family mask 1; its program ends at 32768). A separate policy:
    with POLICY_STAIR it would share the descent's key and heading, which Profiles refuses as ambiguous.
- **56-63** are content 9's dig/tap rows 51-58, unchanged. Source 4's WALK rows must precede its WORK rows
  (Profiles key order), so they move by 5.
- **64** is the tread fitting row: row 52's (yaw-0 tap) words with contact kind CONTACT_TREAD_FIT (DEC-058).
- **65** is content 9's paw handling row 59; **66** is the tread handling row, with row 59's words.
- Every new row's boxes are `claw-work-v1/evidence/stair-rows-v1/rows.json`'s, copied as derived.

**Ground paces:** content 9's twenty-four caps plus one per short step (rows 51 and 52), as the narrow rows have.
They reuse the adopted Movement cap. Stair paces are authored connector rows of the T1-T6 structure catalog
(DEC-050), not ground caps.

    python3 godot/data/underground/mole-worker/publish_claw_stairs_runtime.py
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
OLD = HERE / "qualified-claw-approach-v10"
OUTPUT = HERE / "qualified-claw-stairs-v11"
OLD_WIRE_SHA = "c8e34f12865e05b735772bd9db1a836c65720db2d3a03e84e617a7c8c2589e3b"
OLD_GROUND_SHA = "7bcaec942694df24d5fb01cec08b87d2da7d8b6d5806b02715c75b453acd307c"
ROWS_RECORD = HERE / "claw-work-v1/evidence/stair-rows-v1/rows.json"
IMAGES = {4: HERE / "claw-work-v1/evidence/native-claw-stairs-v1/claw/compiled/compilation.json",
          5: HERE / "claw-work-v1/evidence/native-claw-stairs-v1/paw/compiled/compilation.json"}
OLD_COUNTS, NEW_REVISION = (9, 60, 517, 6), 10
F_SOURCE, F_YAW_KIND, F_YAW, F_FAMILIES, F_FIRST_BOX, F_CONTACT, F_POLICY = 0, 10, 11, 12, 14, 17, 22
POLICY_SHORT_FORWARD, POLICY_SHORT_BACKWARD, POLICY_STAIR, POLICY_STAIR_TURN, CONTACT_TREAD_FIT = 4, 5, 8, 9, 5
WALK_TEMPLATE, TAP_TEMPLATE, HANDLING = 42, 52, 59
KEEP = 51  # Rows 0-50 keep their index.
STEP_BACK, STEP_FORWARD, DESCENT, ASCENT, TURN = 51, 52, 53, 54, 55
DIG_ROWS, TAP_ROWS, TREAD_TAP, HANDLING_ROW, TREAD_HANDLING = (56, 58, 60, 62), (57, 59, 61, 63), 64, 65, 66
NEW_WALK = (("step_back", POLICY_SHORT_BACKWARD, 0), ("step_forward", POLICY_SHORT_FORWARD, 0),
            ("descent", POLICY_STAIR, 1), ("ascent", POLICY_STAIR, 1), ("turn", POLICY_STAIR_TURN, 1))


def require(value: bool, code: str) -> None:
    """Every refusal names the exact failed publication fact."""
    if not value:
        raise ValueError("CLAW_STAIRS_RUNTIME_" + code)


def sha(raw: bytes) -> str:
    """Lower-case hex SHA-256."""
    return hashlib.sha256(raw).hexdigest()


def read_rows() -> dict:
    """The derived rows by name."""
    record = json.loads(ROWS_RECORD.read_text())
    rows = {row["name"]: row for row in record["rows"]}
    require(set(rows) == {"step_back", "step_forward", "descent", "ascent", "turn", "tread_tap", "tread_seat"},
            "ROWS_CENSUS")
    return rows


def image_digests() -> dict:
    """The v2 images' content digests from their native compilation records."""
    return {source: bytes.fromhex(json.loads(path.read_text())["content_sha256"]) for source, path in IMAGES.items()}


def walk_rows(fields: list, derived: dict) -> list:
    """(fields, boxes) of rows 51-55 from row 42's words."""
    template = list(fields[WALK_TEMPLATE])
    require(template[F_SOURCE] == 4 and template[4] == 1 and template[F_POLICY] == 6 and template[F_FAMILIES] == 0,
            "WALK_TEMPLATE")
    result = []
    for name, policy, families in NEW_WALK:
        row = derived[name]
        words = list(template)
        words[F_YAW_KIND], words[F_YAW], words[F_FAMILIES], words[F_POLICY] = 0, row["yaw"], families, policy
        require(row.get("family_mask", 0) == families, "FAMILY_" + name)
        result.append((words, PUB7.role_boxes(row["roles"])))
    return result


def fit_rows(fields: list, derived: dict) -> tuple:
    """Row 64 (tread fitting, source 4) and row 66 (tread handling, source 5)."""
    tap = list(fields[TAP_TEMPLATE])
    require(tap[F_SOURCE] == 4 and tap[4] == 3 and tap[F_YAW] == 0 and tap[F_POLICY] == 3 and tap[F_CONTACT] == 2,
            "TAP_TEMPLATE")
    tap[F_CONTACT] = CONTACT_TREAD_FIT
    seat = list(fields[HANDLING])
    require(seat[F_SOURCE] == 5 and seat[F_POLICY] == 7, "HANDLING_TEMPLATE")
    return ((tap, PUB7.role_boxes(derived["tread_tap"]["roles"])),
            (seat, PUB7.role_boxes(derived["tread_seat"]["roles"])))


def build_wire(derived: dict) -> tuple:
    """Rows 0-50, 51-55, content 9's 51-58, 64, content 9's 59, 66; sources 4 and 5 replaced."""
    old = (OLD / "mole-worker.ugprof").read_bytes()
    require(sha(old) == OLD_WIRE_SHA, "OLD_WIRE")
    revision, digests, fields, rows = PUB7.parse(old)
    require((revision, len(fields), sum(map(len, rows)), len(digests)) == OLD_COUNTS, "OLD_COUNTS")
    digests = list(digests)
    for source, digest in image_digests().items():
        digests[source] = digest
    tap, seat = fit_rows(fields, derived)
    order = [(fields[i], rows[i]) for i in range(KEEP)] + walk_rows(fields, derived) + \
        [(fields[i], rows[i]) for i in range(51, 59)] + [tap, (fields[59], rows[59]), seat]
    new_fields = [list(f) for f, _ in order]
    new_rows = [list(r) for _, r in order]
    saved, PUB9.NEW_REVISION = PUB9.NEW_REVISION, NEW_REVISION  # Content 9's encoder at revision 10.
    try:
        return PUB9.encode(digests, new_fields, new_rows), old
    finally:
        PUB9.NEW_REVISION = saved


def check(old: bytes, new: bytes) -> None:
    """Sources 0-3 unchanged; moved rows unchanged; each source's block key-sorted."""
    _, old_digests, old_fields, old_rows = PUB7.parse(old)
    revision, digests, fields, rows = PUB7.parse(new)
    require(revision == NEW_REVISION and len(fields) == 67 and digests[:4] == old_digests[:4], "NEW_COUNTS")
    same = lambda a, b: [v for k, v in enumerate(a) if k != F_FIRST_BOX] == [v for k, v in enumerate(b) if k != F_FIRST_BOX]
    pairs = list(zip(range(KEEP), range(KEEP))) + list(zip(range(56, 64), range(51, 59))) + [(65, 59)]
    for new_index, old_index in pairs:
        require(same(fields[new_index], old_fields[old_index]) and rows[new_index] == old_rows[old_index],
                "ROW_PRESERVED")
    for source in (4, 5):
        block = [f for f in fields if f[F_SOURCE] == source]
        keys = [tuple(f[1:10]) + (f[16],) for f in block]
        require(keys == sorted(keys), "KEY_ORDER")


def build_ground(old: bytes) -> bytes:
    """Content 9's twenty-four ground caps plus the two short steps; revision 10."""
    require(sha(old) == OLD_GROUND_SHA, "OLD_GROUND")
    count = struct.unpack_from("<I", old, 44)[0]
    require(count == 24 and len(old) == 136 + 36 * 24 + 8, "GROUND_HEADER")
    paces = [H.PACE.unpack_from(old, 136 + 36 * r) for r in range(count)]
    require([p[0] for p in paces[16:]] == list(range(43, 51)), "GROUND_ROWS")
    out = bytearray(old[:-8])
    struct.pack_into("<I", out, 44, count + 2)
    struct.pack_into("<q", out, 48, NEW_REVISION)
    for profile in (STEP_BACK, STEP_FORWARD):
        out += H.PACE.pack(profile, *paces[16][1:])
    return bytes(out) + b"UGCEND01"


def row_constants() -> str:
    """Row IDs for the source programs and the bundle."""
    pack = lambda values: "[" + ", ".join(map(str, values)) + "]"
    return "\n".join([
        "## ADR 1229 (content 10): the tread and stair rows.",
        f"const CLAW_STEP_BACK_ROW: int = {STEP_BACK}",
        f"const CLAW_STEP_FORWARD_ROW: int = {STEP_FORWARD}",
        f"const CLAW_DESCENT_ROW: int = {DESCENT}",
        f"const CLAW_ASCENT_ROW: int = {ASCENT}",
        f"const CLAW_TURN_ROW: int = {TURN}",
        f"const CLAW_TREAD_TAP_ROW: int = {TREAD_TAP}",
        f"const PAW_TREAD_HANDLING_ROW: int = {TREAD_HANDLING}"])


def accessor(old_text: str, wire_sha: str, digests: dict) -> str:
    """Content 9's accessor with the new wire, source digests and row IDs."""
    text = old_text.replace(OLD_WIRE_SHA, wire_sha)
    text = text.replace("## Generated by publish_claw_approach_runtime.py (ADR 1217 step 4e). Do not edit.",
                        "## Generated by publish_claw_stairs_runtime.py (ADR 1229). Do not edit.")
    for name, source in (("CLAW_SOURCE_SHA", 4), ("PAW_SOURCE_SHA", 5)):
        text = re.sub(rf'const {name}: String = "[0-9a-f]+"', f'const {name}: String = "{digests[source].hex()}"', text)
    text = re.sub(r"const CLAW_DIG_ROWS: PackedInt32Array = \[[^\]]*\]",
                  f"const CLAW_DIG_ROWS: PackedInt32Array = [{', '.join(map(str, DIG_ROWS))}]", text)
    text = re.sub(r"const CLAW_TAP_ROWS: PackedInt32Array = \[[^\]]*\]",
                  f"const CLAW_TAP_ROWS: PackedInt32Array = [{', '.join(map(str, TAP_ROWS))}]", text)
    text = re.sub(r"const PAW_HANDLING_ROW: int = \d+", f"const PAW_HANDLING_ROW: int = {HANDLING_ROW}", text)
    require(text.count("const ACTOR_SHA:") == 1, "ACCESSOR_SHAPE")
    text = text.replace("const ACTOR_SHA:", row_constants() + "\nconst ACTOR_SHA:", 1)
    paths = re.findall(r'"(res://[^"]+\.gd)"', text)
    found = re.search(r"const DIGESTS: PackedStringArray = \[\n(.*?)\n\]", text, re.S)
    current = [sha((ROOT / ("godot/" + p.removeprefix("res://"))).read_bytes()) for p in paths]
    return text[:found.start(1)] + "\n".join(f'\t"{d}",' for d in current) + text[found.end(1):]


def build() -> dict:
    """All outputs in memory; nothing is written here."""
    derived = read_rows()
    wire, old = build_wire(derived)
    check(old, wire)
    ground = build_ground((OLD / "ground-pace.ugconn").read_bytes())
    digests = image_digests()
    pins = {str((OLD / "motion.ugmotion").relative_to(ROOT)): sha((OLD / "motion.ugmotion").read_bytes()),
            str((OUTPUT / "mole-worker.ugprof").relative_to(ROOT)): sha(wire),
            str(Path(__file__).resolve().relative_to(ROOT)): sha(Path(__file__).read_bytes())}
    numerical = sha(json.dumps(pins, sort_keys=True, separators=(",", ":")).encode())
    motion = rebind_motion((OLD / "motion.ugmotion").read_bytes(), sha(wire), numerical)
    constants = accessor((OLD / "catalog_source.gd").read_text(), sha(wire), digests)
    _, count, boxes, _ = struct.unpack_from("<qIII", wire, 12)
    manifest = {"schema": 1, "decision": ["1229", "1217", "1209"], "content_revision": NEW_REVISION,
                "profile_count": count, "box_count": boxes, "source_count": 6, "wire_sha256": sha(wire),
                "wire_bytes": len(wire), "paired_bank_bytes": 2 * (len(wire) - 8),
                "sources": {"4": digests[4].hex(), "5": digests[5].hex()},
                "rows": {"0-50": "content 9", "51": "step back", "52": "step forward", "53": "descent (stair)",
                         "54": "ascent (stair)", "55": "half-turn (stair)", "56-63": "content 9's 51-58 (dig/tap)",
                         "64": "tread fitting (CONTACT_TREAD_FIT)", "65": "content 9's 59 (paw handling)",
                         "66": "tread handling (source 5)"},
                "inputs": {str(ROWS_RECORD.relative_to(ROOT)): sha(ROWS_RECORD.read_bytes()),
                           **{str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in IMAGES.values()}},
                "ground_sha256": sha(ground), "ground_pace_profiles_added": [STEP_BACK, STEP_FORWARD],
                "motion_sha256": sha(motion), "motion_inputs": pins, "runtime_admitted": False}
    return {"mole-worker.ugprof": wire, "ground-pace.ugconn": ground, "motion.ugmotion": motion,
            "catalog_source.gd": constants.encode(), "manifest.json": (json.dumps(manifest, indent=2) + "\n").encode()}


def rebind_motion(motion: bytes, wire_sha: str, numerical: str) -> bytes:
    """Content 9's motion bank rebound to revision 10 and the new wire, as each content successor did."""
    require(struct.unpack_from("<q", motion, 16) == (9,) and
            motion[H.BYTE_AT + 160:H.BYTE_AT + 192].hex() == OLD_WIRE_SHA, "MOTION_LAYOUT")
    out = bytearray(motion)
    struct.pack_into("<q", out, 16, NEW_REVISION)
    struct.pack_into("<2q", out, H.I64_AT + 8, NEW_REVISION, NEW_REVISION)
    out[H.BYTE_AT + 160:H.BYTE_AT + 192] = bytes.fromhex(wire_sha)
    out[H.BYTE_AT + 384:H.BYTE_AT + 416] = bytes.fromhex(numerical)
    return bytes(out)


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
