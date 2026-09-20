#!/usr/bin/env python3
"""Independent draft section4 wire oracle; no production module imported.

Not a semantic-valid world fixture. Fixed census is from the source capacity proof;
primary/child mappings are the proposed contract. Stream SHA256 without retaining
whole-section bytes. This intentionally supports arbitrary signed wire values.
"""
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CENSUS = json.loads((ROOT / "fixed-column-census.json").read_text())
LAYOUT = json.loads((ROOT.parents[2] / "planning" / "component_columns_layout.json").read_text())


def value_at(owner, field, row, kind, patterned):
    if not patterned:
        return 0
    n = owner * 100003 + field * 701 + row * 17
    if kind == "u8":
        return n % 256
    bits = 32 if kind == "i32" else 64
    if row == 0:
        return -(1 << (bits - 1))
    if row == 1:
        return (1 << (bits - 1)) - 1
    if row == 2:
        return -1
    n *= 1 if kind == "i32" else 1000000007
    return -n if row % 2 else n


def generate(patterned):
    digest = hashlib.sha256()
    at = 0
    pins = []

    def emit(data):
        nonlocal at
        digest.update(data)
        at += len(data)

    emit(struct.pack("<I", 18))
    for owner, (census, layout) in enumerate(zip(CENSUS["owners"], LAYOUT["owners"])):
        assert census["owner"] == layout["owner"]
        assert at == layout["section_offset"]
        start = at
        key = census["owner"].encode("ascii")
        framing = struct.pack("<I", len(key)) + key
        framing += struct.pack("<IQQ", census["owner_schema_version"],
                               layout["primary_count"], layout["payload_bytes"])
        framing += struct.pack("<I", len(layout["child_extents"]))
        framing += b"".join(struct.pack("<Q", count) for count in layout["child_extents"])
        emit(framing)
        pins.append(dict(owner=census["owner"], offset=start, framing_hex=framing.hex()))
        for field in census["fields"]:
            emit(struct.pack("<Q", field["count"]))
            fmt, width = {"u8": ("B", 1), "i32": ("i", 4), "i64": ("q", 8)}[field["type"]]
            for first in range(0, field["count"], 65536 // width):
                stop = min(field["count"], first + 65536 // width)
                values = [value_at(owner, field["ordinal"], row, field["type"], patterned)
                          for row in range(first, stop)]
                emit(struct.pack("<" + fmt * len(values), *values))
        assert at - start == layout["block_bytes"]
    assert at == 12947565
    return dict(pattern="boundary_pattern" if patterned else "all_zero_wire", bytes=at,
                sha256=digest.hexdigest(), owner_framing=pins)


if __name__ == "__main__":
    result = dict(scope="independent structural bytes; neither pattern is a semantic world",
                  row_count=193184, fixtures=[generate(False), generate(True)])
    (ROOT / "independent-wire-goldens.json").write_text(json.dumps(result, indent=2) + "\n")
    for fixture in result["fixtures"]:
        print(fixture["pattern"], fixture["bytes"], fixture["sha256"])
