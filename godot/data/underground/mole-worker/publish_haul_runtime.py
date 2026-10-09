#!/usr/bin/env python3
"""Create-only content-5 runtime mole profile publication `qualified-haul-v6/` (ADR 1200).

Content 5 is content 4 plus a third source block: the native haul image v8 (ADR 1198 step 4a) and
seven tool-free rows sorted by key within that source:

    30 A  STAND  YAW_ALL                     (empty-walk-v1, ADR 1199)
    31 A' WALK   YAW_ALL                     (empty-walk-v1)
    32 B  CARRY  YAW_ALL   wood 1000..1000   (haul-rows-v1)
    33 C  HAUL load    yaw 0      no cargo   (haul-rows-v1, CONTACT_HAUL_GRIP)
    34 C  HAUL load    yaw 16384  no cargo   (exact 90-degree integer rotation of 33)
    35 D  HAUL unload  yaw 0      wood 1000  (haul-rows-v1, CONTACT_HAUL_GRIP)
    36 D  HAUL unload  yaw 16384  wood 1000  (exact 90-degree integer rotation of 35)

Rows 0-29, boxes 0-280 and sources 0-1 must be byte-identical to content 4. Every box is copied
from the reviewed integer JSON; nothing is widened or invented. The ground pace catalog gains two
RATE_GROUND_CAP rows (31 WALK, 32 CARRY) that reuse the adopted Movement profile and cap; no new
pace constant exists. The motion bank's tables are unchanged and only rebound to the new wire.

    python3 godot/data/underground/mole-worker/publish_haul_runtime.py
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
OLD = HERE / "qualified-handling-v5"
OUTPUT = HERE / "qualified-haul-v6"
HAUL = HERE / "haul-handling-v1/evidence"
OLD_WIRE_SHA = "17d9c229fdfe8ad1923f004db136653ab9834994ba946061be38ec7a2c862ff9"
OLD_GROUND_SHA = "877be0982eb6945c4c4f014e9de428b3ab278d1fddc630080e9c6bfe341a1ea8"
OLD_MOTION_SHA = "16c3c6b030c21fa9185a706493815b87441cfbfe8ceed2fdaa5733c0c4693fcc"
HAUL_SOURCE_SHA = "cc8542712705248f944d7430cbba0b7a365860f0073473c2fc0cb9106cf97a85"
INPUTS = {
    "rows": (HAUL / "haul-rows-v1/rows.json", "9919b1cd181116e94eadb50739ad3b38d7b5b4de86582e64388a3226cbca92e7"),
    "walk": (HAUL / "empty-walk-v1/empty-walk.json", "aef74ac0015eb5ce2ae088428100e56d7964458da52b93edb771f5236c430170"),
    "image": (HAUL / "native-program-v8/compiled/haul-handling.ugactor", HAUL_SOURCE_SHA),
    "items": (ROOT / "godot/data/item_definitions.json", "a44243af22c22258ce2999f42504b22e33f7584d6d374b2063c01efefaa981ab"),
}
JOBS_CATALOG = ROOT / "godot/scripts/core/catalog.gd"
HEADER, ROW, BOX, PACE = struct.Struct("<8sIqIII"), struct.Struct("<18i3q2B"), struct.Struct("<7i"), struct.Struct("<7iq")
OLD_COUNTS, NEW_REVISION, SOURCE = (4, 30, 281, 2), 5, 2
I64_AT = 32 + 12 + 17421 * 4 + 12
BYTE_AT = I64_AT + 67 * 8 + 12
ROLES = {"BODY_HELD_LOAD": 0, "STANCE_SUPPORT": 1, "TURN_RECOVERY": 2, "WORK_APPROACH": 3, "WORK_STROKE": 4}
MODE_STAND, MODE_WALK, MODE_CARRY, MODE_WORK = 0, 1, 2, 3
YAW_EXACT, YAW_ALL, QUARTER = 0, 1, 16384
CONTACT_NONE, CONTACT_HAUL_GRIP = 0, 4
CERT_REQUIRED, POLICY_AUTOMATIC, PROFILE_REVISION = 15, 0, 1
STATES = {MODE_STAND: 257, MODE_WALK: 451, MODE_CARRY: 453, MODE_WORK: 329}
# The pace rows reuse the existing ground Movement profile/revision and RATE_GROUND_CAP (kind 0, rate 0).
GROUND_PACE_PROFILES = (31, 32)


def require(value: bool, code: str) -> None:
    """Every refusal names the exact failed publication fact."""
    if not value:
        raise ValueError("HAUL_RUNTIME_" + code)


def sha(raw: bytes) -> str:
    """Lower-case hex SHA256."""
    return hashlib.sha256(raw).hexdigest()


def read_inputs() -> dict:
    """Each reviewed input is read once and pinned by SHA-256."""
    data = {}
    for name, (path, digest) in INPUTS.items():
        raw = path.read_bytes()
        require(sha(raw) == digest, "INPUT_" + name.upper())
        data[name] = raw
    return data


def compiled_ids(items_json: bytes) -> tuple[int, int]:
    """Wood's compiled ItemDefinition id (ascending ASCII ids, catalog.gd) and JobKind HAUL."""
    ids = sorted(item["id"] for item in json.loads(items_json)["items"])
    require(len(ids) == len(set(ids)) and "wood" in ids, "ITEM_IDS")
    match = re.search(r'const JOB_KIND: Dictionary = \{\s*"HAUL": (\d+),', JOBS_CATALOG.read_text())
    require(match is not None, "JOB_KIND_HAUL")
    return ids.index("wood"), int(match.group(1))


def rotate_quarter(box: tuple) -> tuple:
    """Exact yaw 0 -> yaw 16384 box map, checked against published rows 13 -> 17: x' = z, z' = -x."""
    x0, y0, z0, x1, y1, z1 = box[:6]
    return (z0, y0, -x1, z1, y1, -x0) + tuple(box[6:])


def rows_of(wire: bytes, counts: tuple) -> tuple[list, list]:
    """Decode (fields, boxes) of every row of a UGPROF01 wire."""
    _, rows, boxes, sources = counts
    at = 32 + 32 * sources
    fields = [ROW.unpack_from(wire, at + 98 * r) for r in range(rows)]
    base = at + 98 * rows
    return fields, [[BOX.unpack_from(wire, base + 28 * k) for k in range(f[14], f[14] + f[15])] for f in fields]


def check_rotation(old: bytes) -> None:
    """The convention is the published one: every 13 -> 17 box and field is the quarter turn."""
    fields, boxes = rows_of(old, OLD_COUNTS)
    require(fields[13][11] == 0 and fields[17][11] == QUARTER, "ROTATION_ROWS")
    require([rotate_quarter(b) for b in boxes[13]] == boxes[17], "ROTATION_CONVENTION")


def json_boxes(entries: list) -> list:
    """Boxes exactly as the derivation wrote them, in its order."""
    out = []
    for entry in entries:
        bounds = entry["bounds_u"]
        require(len(bounds) == 6 and all(type(v) is int for v in bounds), "BOX_FORMAT")
        require(ROLES[entry["role"]] == entry["role_id"], "BOX_ROLE")
        out.append(tuple(bounds) + (entry["role_id"],))
    return out


def ground_boxes(geometry: dict) -> list:
    """A/A' roles in the published rows-0/1/12 order: body/load, stance support, turn recovery."""
    roles = geometry["roles"]
    out = []
    for name in ("BODY_HELD_LOAD", "STANCE_SUPPORT", "TURN_RECOVERY"):
        out += [tuple(bounds) + (ROLES[name],) for bounds in roles[name]]
    require(len(out) == geometry["box_count"], "GROUND_BOX_COUNT")
    return out


def new_rows(data: dict) -> list:
    """Seven (key fields, quantity range, boxes) rows, already in per-source key order."""
    wood, haul = compiled_ids(data["items"])
    walk = {row["row"]: row for row in json.loads(data["walk"])["profile_geometry"]["rows"]}
    derived = {row["name"]: row for row in json.loads(data["rows"])["rows"]}
    stand, moving = walk["A STAND"], walk["A' WALK"]
    carry = derived["haul_carry_wood_1000"]
    load, unload = derived["haul_load_wood_1000"], derived["haul_unload_wood_1000"]
    for row, mode in ((stand, MODE_STAND), (moving, MODE_WALK)):
        require(row["mode"] == mode and row["yaw_kind"] == "YAW_ALL" and row["tool"] == -1 and row["cargo"] == -1
                and row["quantity_milli"] == [0, 0] and row["states"] == STATES[mode], "EMPTY_WALK_ROW")
    require(carry["mode"] == MODE_CARRY and carry["yaw_kind"] == YAW_ALL and carry["cargo"] == "wood"
            and carry["quantity_milli"] == [1000, 1000] and carry["states"] == STATES[MODE_CARRY], "CARRY_ROW")
    for row, cargo in ((load, None), (unload, "wood")):
        require(row["mode"] == MODE_WORK and row["yaw_kind"] == YAW_EXACT and row["yaw"] == 0
                and row["work_kind"] == "HAUL" and row["tool"] == -1 and row["cargo"] == cargo
                and row["states"] == STATES[MODE_WORK], "HAUL_ROW")
    out = [(MODE_STAND, -1, YAW_ALL, 0, -1, CONTACT_NONE, (0, 0), ground_boxes(stand)),
           (MODE_WALK, -1, YAW_ALL, 0, -1, CONTACT_NONE, (0, 0), ground_boxes(moving)),
           (MODE_CARRY, wood, YAW_ALL, 0, -1, CONTACT_NONE, (1000, 1000), json_boxes(carry["boxes"]))]
    for row, cargo, quantity in ((load, -1, (0, 0)), (unload, wood, (1000, 1000))):
        boxes = json_boxes(row["boxes"])
        for yaw in (0, QUARTER):
            out.append((MODE_WORK, cargo, YAW_EXACT, yaw, haul, CONTACT_HAUL_GRIP, quantity,
                        boxes if yaw == 0 else [rotate_quarter(b) for b in boxes]))
    return out


def encode_row(row: tuple, first: int) -> bytes:
    """Exact UGPROF01 field order; species/stage/rig are the published mole's (6, 0, 6)."""
    mode, cargo, yaw_kind, yaw, work, contact, (low, high), boxes = row
    return ROW.pack(SOURCE, 6, 0, 6, mode, 0, -1, -1, cargo, -1, yaw_kind, yaw, 0, STATES[mode], first,
                    len(boxes), work, contact, PROFILE_REVISION, low, high, CERT_REQUIRED, POLICY_AUTOMATIC)


def build_wire(old: bytes, rows: list) -> bytes:
    """Append source 2, its rows after row 29 and its boxes after box 280; earlier bytes stay exact."""
    require(HEADER.unpack_from(old) == (b"UGPROF01", 2) + OLD_COUNTS and old[-8:] == b"UGPEND01", "OLD_HEADER")
    _, count, boxes, sources = OLD_COUNTS
    rows_at, boxes_at = 32 + 32 * sources, 32 + 32 * sources + 98 * count
    first, encoded, primitives = boxes, b"", b""
    for row in rows:
        encoded += encode_row(row, first)
        primitives += b"".join(BOX.pack(*box) for box in row[7])
        first += len(row[7])
    wire = HEADER.pack(b"UGPROF01", 2, NEW_REVISION, count + len(rows), first, sources + 1)
    wire += old[32:rows_at] + bytes.fromhex(HAUL_SOURCE_SHA) + old[rows_at:boxes_at] + encoded
    return wire + old[boxes_at:-8] + primitives + b"UGPEND01"


def check_superset(old: bytes, new: bytes) -> None:
    """Rows 0-29, boxes 0-280 and sources 0-1 are byte-identical to content 4; source 2 is the haul image."""
    o_rev, o_rows, o_boxes, o_src = struct.unpack_from("<qIII", old, 12)
    n_rev, n_rows, n_boxes, n_src = struct.unpack_from("<qIII", new, 12)
    require((o_rev, o_rows, o_boxes, o_src) == OLD_COUNTS, "OLD_COUNTS")
    require(n_rev == NEW_REVISION and n_src == 3 and n_rows > o_rows and n_boxes > o_boxes, "NEW_COUNTS")
    require(old[32:96] == new[32:96] and new[96:128].hex() == HAUL_SOURCE_SHA, "SOURCES_0_1")
    old_rows, new_rows_at = 32 + 64, 32 + 96
    require(old[old_rows:old_rows + o_rows * 98] == new[new_rows_at:new_rows_at + o_rows * 98], "ROWS_0_29")
    old_boxes, new_boxes = old_rows + o_rows * 98, new_rows_at + n_rows * 98
    require(old[old_boxes:old_boxes + o_boxes * 28] == new[new_boxes:new_boxes + o_boxes * 28], "BOXES_0_280")
    require(len(new) == 40 + 96 + 98 * n_rows + 28 * n_boxes and new[-8:] == b"UGPEND01", "NEW_SIZE")


def check_key_order(new: bytes) -> None:
    """Profiles validates key order per source (ADR 1198); the new block must already be sorted."""
    fields, _ = rows_of(new, struct.unpack_from("<qIII", new, 12))
    block = [f for f in fields if f[0] == SOURCE]
    keys = [f[1:10] + (f[16],) for f in block]
    require(keys == sorted(keys) and [f[0] for f in fields[:30]].count(SOURCE) == 0, "KEY_ORDER")


def build_ground(old: bytes) -> bytes:
    """Content 4 ground paces plus RATE_GROUND_CAP rows for 31 WALK and 32 CARRY, same Movement source."""
    head = struct.unpack_from("<8sIq7I3q", old)
    require(head == (b"UGCONN01", 2, 1, 0, 0, 0, 0, 0, 0, 12, 4, 1, 0) and len(old) == 576, "GROUND_HEADER")
    paces = [PACE.unpack_from(old, 136 + 36 * r) for r in range(12)]
    require(all(p == (r + 1, -1, 0, 1, 1, 0, 0, 1) for r, p in enumerate(paces)), "GROUND_ROWS")
    out = bytearray(old[:-8])
    struct.pack_into("<I", out, 44, 12 + len(GROUND_PACE_PROFILES))
    struct.pack_into("<q", out, 48, NEW_REVISION)
    for profile in GROUND_PACE_PROFILES:
        out += PACE.pack(profile, -1, 0, paces[0][3], paces[0][4], 0, 0, PROFILE_REVISION)
    return bytes(out) + b"UGCEND01"


def rebind_motion(motion: bytes, wire_sha: str, numerical: str) -> bytes:
    """Change only the profile revisions, embedded wire digest and input manifest digest."""
    require(sha(motion) == OLD_MOTION_SHA and len(motion) == 70936, "MOTION_ORIGINAL")
    require(struct.unpack_from("<q", motion, 16) == (4,) and struct.unpack_from("<3q", motion, I64_AT) == (1, 4, 4)
            and motion[BYTE_AT + 160:BYTE_AT + 192].hex() == OLD_WIRE_SHA, "MOTION_LAYOUT")
    out = bytearray(motion)
    struct.pack_into("<q", out, 16, NEW_REVISION)
    struct.pack_into("<2q", out, I64_AT + 8, NEW_REVISION, NEW_REVISION)
    out[BYTE_AT + 160:BYTE_AT + 192] = bytes.fromhex(wire_sha)
    out[BYTE_AT + 384:BYTE_AT + 416] = bytes.fromhex(numerical)
    ranges = [(16, 24), (I64_AT + 8, I64_AT + 24), (BYTE_AT + 160, BYTE_AT + 192), (BYTE_AT + 384, BYTE_AT + 416)]
    require(all(a == b or any(lo <= i < hi for lo, hi in ranges) for i, (a, b) in enumerate(zip(motion, out))),
            "MOTION_FOREIGN_DELTA")
    return bytes(out)


def accessor(old_text: str, wire_sha: str) -> str:
    """Same shape as v5 with the new wire, the haul source digest, and current consumer digests."""
    text = old_text.replace(OLD_WIRE_SHA, wire_sha)
    text = text.replace("## Generated by publish_handling_runtime.py (ADR 1194). Do not edit.",
                        "## Generated by publish_haul_runtime.py (ADR 1200). Do not edit.")
    text = text.replace("const ACTOR_SHA:", f'const HAUL_SOURCE_SHA: String = "{HAUL_SOURCE_SHA}"\nconst ACTOR_SHA:', 1)
    paths = re.findall(r'"(res://[^"]+\.gd)"', text)
    old_digests = re.search(r"const DIGESTS: PackedStringArray = \[\n(.*?)\n\]", text, re.S)
    current = [sha((ROOT / ("godot/" + p.removeprefix("res://"))).read_bytes()) for p in paths]
    block = "\n".join(f'\t"{d}",' for d in current)
    return text[:old_digests.start(1)] + block + text[old_digests.end(1):]


def build() -> dict:
    """All outputs in memory; nothing is written here."""
    data = read_inputs()
    old = (OLD / "mole-worker.ugprof").read_bytes()
    require(sha(old) == OLD_WIRE_SHA, "OLD_WIRE")
    check_rotation(old)
    rows = new_rows(data)
    wire = build_wire(old, rows)
    check_superset(old, wire)
    check_key_order(wire)
    old_ground = (OLD / "ground-pace.ugconn").read_bytes()
    require(sha(old_ground) == OLD_GROUND_SHA, "OLD_GROUND")
    ground = build_ground(old_ground)
    pins = {str((OLD / "motion.ugmotion").relative_to(ROOT)): OLD_MOTION_SHA,
            str((OUTPUT / "mole-worker.ugprof").relative_to(ROOT)): sha(wire),
            str(Path(__file__).resolve().relative_to(ROOT)): sha(Path(__file__).read_bytes())}
    numerical = sha(json.dumps(pins, sort_keys=True, separators=(",", ":")).encode())
    motion = rebind_motion((OLD / "motion.ugmotion").read_bytes(), sha(wire), numerical)
    constants = accessor((OLD / "catalog_source.gd").read_text(), sha(wire))
    _, count, boxes, _ = struct.unpack_from("<qIII", wire, 12)
    consumers = {"godot/" + p.removeprefix("res://"): d for p, d in
                 zip(re.findall(r'"(res://[^"]+\.gd)"', constants), re.findall(r'"([0-9a-f]{64})",', constants))}
    manifest = {"schema": 1, "decision": "1200", "content_revision": NEW_REVISION, "profile_count": count,
                "box_count": boxes, "source_count": 3, "wire_sha256": sha(wire), "wire_bytes": len(wire),
                "paired_bank_bytes": 2 * (len(wire) - 8), "haul_source_sha256": HAUL_SOURCE_SHA,
                "superset_of": {"wire_sha256": OLD_WIRE_SHA, "rows": "0-29", "boxes": "0-280", "sources": "0-1"},
                "haul_rows": {"30": "A STAND", "31": "A' WALK", "32": "B CARRY wood 1000",
                              "33": "C HAUL load yaw 0", "34": "C HAUL load yaw 16384",
                              "35": "D HAUL unload yaw 0", "36": "D HAUL unload yaw 16384"},
                "rotation": "yaw 16384 boxes = (z0, y0, -x1, z1, y1, -x0) of yaw 0, checked against rows 13 -> 17",
                "inputs": {str(p.relative_to(ROOT)): d for p, d in INPUTS.values()},
                "ground_sha256": sha(ground), "ground_pace_profiles": list(GROUND_PACE_PROFILES),
                "ground_pace_rule": "RATE_GROUND_CAP rows reusing the existing Movement profile; no new pace constant",
                "motion_sha256": sha(motion), "motion_inputs": pins, "motion_numerical_input_sha256": numerical,
                "consumers": consumers,
                "not_qualified": ["curved grip certificate module", "presentation of source-2 rows",
                                  "station seam floor support at S", "joint memory census"]}
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
          "motion", sha(outputs["motion.ugmotion"])[:12], "ground", sha(outputs["ground-pace.ugconn"])[:12])
    return 0


if __name__ == "__main__":
    sys.exit(main())
