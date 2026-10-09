#!/usr/bin/env python3
"""Compile reviewable integer engineering heights to the tiny immutable runtime wire image."""
from pathlib import Path
import argparse
import hashlib
import json
import struct


ROOT = Path(__file__).resolve().parent


def encode(source):
    """No float conversion, guessed defaults, implicit levels or movement permission."""
    if type(source) is not dict or type(source.get("schema")) is not int or source["schema"] != 1:
        raise ValueError("LEVEL_SOURCE_SCHEMA")
    if type(source.get("content_revision")) is not int or not 1 <= source["content_revision"] < (1 << 63):
        raise ValueError("LEVEL_SOURCE_SCHEMA")
    domain = source["domain"]
    fields = []
    for key in ("datum_u", "min_quantum", "size_quanta"):
        values = domain[key]
        if type(values) is not list or len(values) != 3:
            raise ValueError("LEVEL_SOURCE_DOMAIN")
        fields.extend(values)
    fields.extend(source[key] for key in ("level_spacing_u", "clear_height_u", "protected_roof_band_u", "required_footing_u"))
    offsets, rises = source["section_offsets_u"], source["short_stair_rises_u"]
    if type(offsets) is not list or type(rises) is not list or not 1 <= len(offsets) <= 9 or not 1 <= len(rises) <= 8:
        raise ValueError("LEVEL_SOURCE_CAPACITY")
    if any(type(value) is not int or not -(1 << 31) <= value < (1 << 31) for value in [*fields, *offsets, *rises]):
        raise ValueError("LEVEL_SOURCE_INTEGER")
    result = b"UGLEVEL1" + struct.pack("<Iq", 1, source["content_revision"])
    result += struct.pack("<13iI", *fields, len(offsets))
    result += struct.pack("<" + "i" * len(offsets) + "I", *offsets, len(rises))
    return result + struct.pack("<" + "i" * len(rises), *rises) + b"UGLEND01"


def unique_object(pairs):
    """Reject conflicting repeated JSON keys rather than silently selecting the last value."""
    result = {}
    for name, value in pairs:
        if name in result:
            raise ValueError("LEVEL_SOURCE_DUPLICATE_KEY")
        result[name] = value
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "initial_level_pack.json")
    parser.add_argument("--out", type=Path, default=ROOT / "initial_level_pack.uglvl")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.source.stat().st_size > 16384:
        raise ValueError("LEVEL_SOURCE_CAPACITY")
    data = encode(json.loads(args.source.read_text(), object_pairs_hook=unique_object))
    if args.check:
        if args.out.read_bytes() != data:
            raise ValueError("LEVEL_COMPILED_DRIFT")
    else:
        with args.out.open("xb") as stream:
            stream.write(data)
    print(f"{hashlib.sha256(data).hexdigest()}  {args.out.name} ({len(data)} bytes)")


if __name__ == "__main__":
    main()
