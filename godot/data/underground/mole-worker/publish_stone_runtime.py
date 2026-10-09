#!/usr/bin/env python3
"""Create-only content-6 runtime mole profile publication `qualified-stone-v7/` (ADR 1206).

Content 6 is content 5 (`qualified-haul-v6`) plus a fourth source block: the native stone image v9 and five
tool-free stone rows sorted by key within that source:

    37 CARRY        YAW_ALL    stone 1000..1000   (stone-rows-v1)
    38 HAUL load    yaw 0      no cargo           (stone-rows-v1, CONTACT_HAUL_GRIP)
    39 HAUL load    yaw 16384  no cargo           (exact 90-degree integer rotation of 38)
    40 HAUL unload  yaw 0      stone 1000         (stone-rows-v1, CONTACT_HAUL_GRIP)
    41 HAUL unload  yaw 16384  stone 1000         (exact 90-degree integer rotation of 40)

Rows 0-36, boxes 0-333 and sources 0-2 must be byte-identical to content 5. Every box is copied from the
derived integer JSON; nothing is widened or invented. Stone is compiled item 53 (5,000 g/unit, as wood). The
ground pace catalog gains one RATE_GROUND_CAP row (37 CARRY) reusing the adopted Movement profile and cap; no
new pace constant exists. The motion bank's tables are unchanged and only rebound to the new wire.

    python3 godot/data/underground/mole-worker/publish_stone_runtime.py
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import struct
import sys

import publish_haul_runtime as H

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = HERE / "qualified-haul-v6"
OUTPUT = HERE / "qualified-stone-v7"
STONE = HERE / "haul-handling-v1/evidence"
OLD_WIRE_SHA = "dc4969e4dc562e39b941a7fefa4be4b72851490f59492f0b04b3f26954bc5d8e"
OLD_GROUND_SHA = "1ae7ffc421f2a93deac4ccde12a843652da1fd46c91f58c28c559979015422f0"
OLD_MOTION_SHA = "b9eb5b950669c8356a3f7d97997b8cf209ff0588384833e98c4e0da84bc58f5b"
STONE_SOURCE_SHA = "49ff3018d363c7dbad05df0af91368e8fec11e30525c2f8231e6a959f80a7b95"
INPUTS = {
    "rows": (STONE / "stone-rows-v1/rows.json", "caa36d82092d775fd9acaacac8c11a3e6a082964400875fd3430ba4f84cca004"),
    "image": (STONE / "native-program-v9/compiled/stone-handling.ugactor", STONE_SOURCE_SHA),
    "items": H.INPUTS["items"],
}
OLD_COUNTS, NEW_REVISION, SOURCE = (5, 37, 334, 3), 6, 3
GROUND_PACE_PROFILES = (37,)
STONE_ITEM = 53


def require(value: bool, code: str) -> None:
    """Every refusal names the exact failed publication fact."""
    if not value:
        raise ValueError("STONE_RUNTIME_" + code)


def read_inputs() -> dict:
    data = {}
    for name, (path, digest) in INPUTS.items():
        raw = path.read_bytes()
        require(H.sha(raw) == digest, "INPUT_" + name.upper())
        data[name] = raw
    return data


def stone_id(items_json: bytes) -> int:
    """Stone's compiled ItemDefinition id: ascending ASCII ids (catalog.gd), the same rule as wood's 60."""
    ids = sorted(item["id"] for item in json.loads(items_json)["items"])
    require(ids.index("stone") == STONE_ITEM, "ITEM_ID")
    mass = {item["id"]: item["mass_g"] for item in json.loads(items_json)["items"]}
    require(mass["stone"] == mass["wood"] == 5000, "ITEM_MASS")
    return STONE_ITEM


def new_rows(data: dict) -> list:
    """Five (key fields, quantity, boxes) rows in per-source key order: CARRY, load x2, unload x2."""
    stone = stone_id(data["items"])
    _, haul = H.compiled_ids(data["items"])
    derived = {row["name"]: row for row in json.loads(data["rows"])["rows"]}
    carry = derived["haul_carry_stone_1000"]
    load, unload = derived["haul_load_stone_1000"], derived["haul_unload_stone_1000"]
    require(carry["mode"] == H.MODE_CARRY and carry["yaw_kind"] == H.YAW_ALL and carry["cargo"] == "stone"
            and carry["quantity_milli"] == [1000, 1000] and carry["states"] == H.STATES[H.MODE_CARRY]
            and carry["tool"] == -1, "CARRY_ROW")
    for row, cargo in ((load, None), (unload, "stone")):
        require(row["mode"] == H.MODE_WORK and row["yaw_kind"] == H.YAW_EXACT and row["yaw"] == 0
                and row["work_kind"] == "HAUL" and row["tool"] == -1 and row["cargo"] == cargo
                and row["states"] == H.STATES[H.MODE_WORK], "HAUL_ROW")
    out = [(H.MODE_CARRY, stone, H.YAW_ALL, 0, -1, H.CONTACT_NONE, (1000, 1000), H.json_boxes(carry["boxes"]))]
    for row, cargo, quantity in ((load, -1, (0, 0)), (unload, stone, (1000, 1000))):
        boxes = H.json_boxes(row["boxes"])
        for yaw in (0, H.QUARTER):
            out.append((H.MODE_WORK, cargo, H.YAW_EXACT, yaw, haul, H.CONTACT_HAUL_GRIP, quantity,
                        boxes if yaw == 0 else [H.rotate_quarter(b) for b in boxes]))
    return out


def encode_row(row: tuple, first: int) -> bytes:
    """publish_haul_runtime.encode_row with this block's source index."""
    mode, cargo, yaw_kind, yaw, work, contact, (low, high), boxes = row
    return H.ROW.pack(SOURCE, 6, 0, 6, mode, 0, -1, -1, cargo, -1, yaw_kind, yaw, 0, H.STATES[mode], first,
                      len(boxes), work, contact, H.PROFILE_REVISION, low, high, H.CERT_REQUIRED, H.POLICY_AUTOMATIC)


def build_wire(old: bytes, rows: list) -> bytes:
    """Append source 3, its rows after row 36 and its boxes after box 333; earlier bytes stay exact."""
    require(H.HEADER.unpack_from(old) == (b"UGPROF01", 2) + OLD_COUNTS and old[-8:] == b"UGPEND01", "OLD_HEADER")
    _, count, boxes, sources = OLD_COUNTS
    rows_at, boxes_at = 32 + 32 * sources, 32 + 32 * sources + 98 * count
    first, encoded, primitives = boxes, b"", b""
    for row in rows:
        encoded += encode_row(row, first)
        primitives += b"".join(H.BOX.pack(*box) for box in row[7])
        first += len(row[7])
    wire = H.HEADER.pack(b"UGPROF01", 2, NEW_REVISION, count + len(rows), first, sources + 1)
    wire += old[32:rows_at] + bytes.fromhex(STONE_SOURCE_SHA) + old[rows_at:boxes_at] + encoded
    return wire + old[boxes_at:-8] + primitives + b"UGPEND01"


def check_superset(old: bytes, new: bytes) -> None:
    """Rows 0-36, boxes 0-333 and sources 0-2 are byte-identical to content 5; source 3 is the stone image."""
    o_rev, o_rows, o_boxes, o_src = struct.unpack_from("<qIII", old, 12)
    n_rev, n_rows, n_boxes, n_src = struct.unpack_from("<qIII", new, 12)
    require((o_rev, o_rows, o_boxes, o_src) == OLD_COUNTS, "OLD_COUNTS")
    require((n_rev, n_rows, n_src) == (NEW_REVISION, 42, 4) and n_boxes > o_boxes, "NEW_COUNTS")
    require(old[32:128] == new[32:128] and new[128:160].hex() == STONE_SOURCE_SHA, "SOURCES_0_2")
    old_rows, new_rows_at = 32 + 96, 32 + 128
    require(old[old_rows:old_rows + o_rows * 98] == new[new_rows_at:new_rows_at + o_rows * 98], "ROWS_0_36")
    old_boxes, new_boxes = old_rows + o_rows * 98, new_rows_at + n_rows * 98
    require(old[old_boxes:old_boxes + o_boxes * 28] == new[new_boxes:new_boxes + o_boxes * 28], "BOXES_0_333")
    require(len(new) == 40 + 128 + 98 * n_rows + 28 * n_boxes and new[-8:] == b"UGPEND01", "NEW_SIZE")


def check_key_order(new: bytes) -> None:
    """Profiles validates key order per source; the new block must already be sorted."""
    fields, _ = H.rows_of(new, struct.unpack_from("<qIII", new, 12))
    block = [f for f in fields if f[0] == SOURCE]
    keys = [f[1:10] + (f[16],) for f in block]
    require(len(block) == 5 and keys == sorted(keys) and [f[0] for f in fields[:37]].count(SOURCE) == 0, "KEY_ORDER")


def build_ground(old: bytes) -> bytes:
    """Content 5 ground paces (14 rows) plus a RATE_GROUND_CAP row for 37 CARRY, same Movement source."""
    head = struct.unpack_from("<8sIq7I3q", old)
    require(head == (b"UGCONN01", 2, 1, 0, 0, 0, 0, 0, 0, 14, 5, 1, 0) and len(old) == 648, "GROUND_HEADER")
    paces = [H.PACE.unpack_from(old, 136 + 36 * r) for r in range(14)]
    require(all(p == (r + 1, -1, 0, 1, 1, 0, 0, 1) for r, p in enumerate(paces[:12])) and
            [p[0] for p in paces[12:]] == [31, 32], "GROUND_ROWS")
    out = bytearray(old[:-8])
    struct.pack_into("<I", out, 44, 14 + len(GROUND_PACE_PROFILES))
    struct.pack_into("<q", out, 48, NEW_REVISION)
    for profile in GROUND_PACE_PROFILES:
        out += H.PACE.pack(profile, -1, 0, paces[0][3], paces[0][4], 0, 0, H.PROFILE_REVISION)
    return bytes(out) + b"UGCEND01"


def rebind_motion(motion: bytes, wire_sha: str, numerical: str) -> bytes:
    """Change only the profile revisions (5 -> 6), embedded wire digest and input manifest digest."""
    require(H.sha(motion) == OLD_MOTION_SHA and len(motion) == 70936, "MOTION_ORIGINAL")
    require(struct.unpack_from("<q", motion, 16) == (5,) and struct.unpack_from("<3q", motion, H.I64_AT) == (1, 5, 5)
            and motion[H.BYTE_AT + 160:H.BYTE_AT + 192].hex() == OLD_WIRE_SHA, "MOTION_LAYOUT")
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


def accessor(old_text: str, wire_sha: str) -> str:
    """Same shape as v6 with the new wire, the stone source digest, and current consumer digests."""
    text = old_text.replace(OLD_WIRE_SHA, wire_sha)
    text = text.replace("## Generated by publish_haul_runtime.py (ADR 1200). Do not edit.",
                        "## Generated by publish_stone_runtime.py (ADR 1206). Do not edit.")
    text = text.replace("const ACTOR_SHA:", f'const STONE_SOURCE_SHA: String = "{STONE_SOURCE_SHA}"\nconst ACTOR_SHA:', 1)
    paths = re.findall(r'"(res://[^"]+\.gd)"', text)
    digests = re.search(r"const DIGESTS: PackedStringArray = \[\n(.*?)\n\]", text, re.S)
    current = [H.sha((ROOT / ("godot/" + p.removeprefix("res://"))).read_bytes()) for p in paths]
    block = "\n".join(f'\t"{d}",' for d in current)
    return text[:digests.start(1)] + block + text[digests.end(1):]


def build() -> dict:
    """All outputs in memory; nothing is written here."""
    data = read_inputs()
    old = (OLD / "mole-worker.ugprof").read_bytes()
    require(H.sha(old) == OLD_WIRE_SHA, "OLD_WIRE")
    rows = new_rows(data)
    wire = build_wire(old, rows)
    check_superset(old, wire)
    check_key_order(wire)
    old_ground = (OLD / "ground-pace.ugconn").read_bytes()
    require(H.sha(old_ground) == OLD_GROUND_SHA, "OLD_GROUND")
    ground = build_ground(old_ground)
    pins = {str((OLD / "motion.ugmotion").relative_to(ROOT)): OLD_MOTION_SHA,
            str((OUTPUT / "mole-worker.ugprof").relative_to(ROOT)): H.sha(wire),
            str(Path(__file__).resolve().relative_to(ROOT)): H.sha(Path(__file__).read_bytes())}
    numerical = H.sha(json.dumps(pins, sort_keys=True, separators=(",", ":")).encode())
    motion = rebind_motion((OLD / "motion.ugmotion").read_bytes(), H.sha(wire), numerical)
    constants = accessor((OLD / "catalog_source.gd").read_text(), H.sha(wire))
    _, count, boxes, _ = struct.unpack_from("<qIII", wire, 12)
    consumers = {"godot/" + p.removeprefix("res://"): d for p, d in
                 zip(re.findall(r'"(res://[^"]+\.gd)"', constants), re.findall(r'"([0-9a-f]{64})",', constants))}
    manifest = {"schema": 1, "decision": "1206", "content_revision": NEW_REVISION, "profile_count": count,
                "box_count": boxes, "source_count": 4, "wire_sha256": H.sha(wire), "wire_bytes": len(wire),
                "paired_bank_bytes": 2 * (len(wire) - 8), "stone_source_sha256": STONE_SOURCE_SHA,
                "superset_of": {"wire_sha256": OLD_WIRE_SHA, "rows": "0-36", "boxes": "0-333", "sources": "0-2"},
                "stone_rows": {"37": "CARRY stone 1000", "38": "HAUL load stone yaw 0", "39": "HAUL load stone yaw 16384",
                               "40": "HAUL unload stone yaw 0", "41": "HAUL unload stone yaw 16384"},
                "stone_item": {"compiled_id": STONE_ITEM, "mass_g": 5000},
                "rotation": "yaw 16384 boxes = (z0, y0, -x1, z1, y1, -x0) of yaw 0 (the content-5 convention)",
                "inputs": {str(p.relative_to(ROOT)): d for p, d in INPUTS.values()},
                "ground_sha256": H.sha(ground), "ground_pace_profiles": list(GROUND_PACE_PROFILES),
                "ground_pace_rule": "RATE_GROUND_CAP row reusing the existing Movement profile; no new pace constant",
                "motion_sha256": H.sha(motion), "motion_inputs": pins, "motion_numerical_input_sha256": numerical,
                "consumers": consumers,
                "not_qualified": ["presentation of the source-3 image (ContentSet holds three sources)"]}
    return {"mole-worker.ugprof": wire, "ground-pace.ugconn": ground, "motion.ugmotion": motion,
            "catalog_source.gd": constants.encode(), "manifest.json": (json.dumps(manifest, indent=2) + "\n").encode()}


def main() -> int:
    """Create the publication exactly once."""
    require(not OUTPUT.exists(), "OUTPUT_EXISTS")
    outputs = build()
    OUTPUT.mkdir()
    for name, raw in outputs.items():
        (OUTPUT / name).write_bytes(raw)
    print("published", OUTPUT.relative_to(ROOT), "wire", H.sha(outputs["mole-worker.ugprof"])[:12],
          "motion", H.sha(outputs["motion.ugmotion"])[:12], "ground", H.sha(outputs["ground-pace.ugconn"])[:12])
    return 0


if __name__ == "__main__":
    sys.exit(main())
