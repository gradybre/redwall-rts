#!/usr/bin/env python3
"""Compile the exact L0/T0 structure and approved bills, without work or travel permission.

The current source is deliberately a structural subset. It does not emit a
Frontier, a Workpieces image, a stair pace, or an activated runtime source.
Those require their own complete worker/contact/handling proof.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[4]
SPEC = "docs/design/underground-planning/first-entry-prefix-v1.json"
SPEC_SHA = "edd562056b12f732fbf60f0536207ba2afd1dce650d19df552ecf1e75ff9cf81"
PROFILE = "godot/data/underground/mole-worker/qualified-step-v4/mole-worker.ugprof"
PROFILE_SHA = "830ee531a432f9cef8a24a85f1c017be21253301bc46bf55e0a6b97807a4ec4e"
GROUND = "godot/data/underground/mole-worker/qualified-step-v4/ground-pace.ugconn"
GROUND_SHA = "454eaab1b2a722aab2700285d31a0bcc093312dad211208da7993baa32bc2f24"
LEVELS = "godot/data/underground/initial_level_pack.uglvl"
LEVELS_SHA = "c5deb094b335bf6e5db018eeed591a115086b79bd909f829ed6e34166db81f94"
OUTPUT = "godot/data/underground/first-entry-prefix-v1/structural-v1"
PRODUCER = "godot/data/underground/first-entry-prefix-v1/compile_entry_prefix.py"
OWNERS = (
    "godot/scripts/core/underground_connector_catalog.gd",
    "godot/scripts/core/underground_connector_assemblies.gd",
    "godot/scripts/core/underground_connector_recipes.gd",
    "godot/scripts/core/connector_geometry.gd",
    "godot/scripts/core/room_space.gd",
)


def require(value, name):
    if not value:
        raise ValueError("ENTRY_STRUCTURE_" + name)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read(root, name, expected, maximum):
    path = root / name
    require(path.is_file() and not path.is_symlink() and
            path.resolve().is_relative_to(root.resolve()) and 0 < path.stat().st_size <= maximum,
            "INPUT_PATH:" + name)
    raw = path.read_bytes()
    require(len(raw) <= maximum and sha(raw) == expected, "INPUT_SHA:" + name)
    return raw


def words(values, revision=None):
    require(all(type(v) is int and -(1 << 31) <= v < (1 << 31) for v in values), "INTEGER")
    raw = struct.pack("<" + "i" * len(values), *values)
    return raw if revision is None else raw + struct.pack("<q", revision)


def valid_box(box):
    require(type(box) is list and len(box) == 6 and
            all(type(v) is int and abs(v) <= 32768 for v in box) and
            all(box[a] < box[a + 3] for a in range(3)), "BOX")


def structure(spec):
    """Check an exact partition and natural bearing/cut separation before any serialization."""
    require(spec["schema"] == 1 and spec["engineering_only"] is True and
            spec["production_qualified"] is False, "SCOPE")
    require(len(spec["parts"]) == 14 and len(spec["assemblies"]) == 2 and
            len(spec["natural_bearings"]) == 8 and len(spec["cut_groups"]) == 2,
            "CENSUS")
    require(spec["coordinate_contract"]["units_per_metre"] == 1024 and
            spec["coordinate_contract"]["removed_cube_floor_local_y_u"] == -1024,
            "DATUM")
    for index, part in enumerate(spec["parts"]):
        require(part["id"] == index and part["assembly"] == index // 7, "PARTITION")
        valid_box(part["bounds_u"])
    require(spec["sequence_fixture"]["solids_u"] == [p["bounds_u"] for p in spec["parts"]],
            "MOTION_GEOMETRY_IDENTITY")
    for index, group in enumerate(spec["assemblies"]):
        require(group["id"] == index and group["included_parts"] == list(range(index * 7, index * 7 + 7))
                and group["kind"] == ("landing" if index == 0 else "tread") and
                group["wood_milli"] == (4000 if index == 0 else 1000) and
                group["build_milli_wu"] == (32000 if index == 0 else 12000), "APPROVED_BILL")
    for bearing in spec["natural_bearings"]:
        valid_box(bearing["bounds_u"])
        require(bearing["bounds_u"][4] == -1024, "BEARING_DATUM")
        for cut in spec["cut_groups"]:
            valid_box(cut["bounds_u"])
            require(all(v % 1024 == 0 for v in cut["bounds_u"]), "CUT_LATTICE")
            a, b = bearing["bounds_u"], cut["bounds_u"]
            require(any(a[i] >= b[i + 3] or b[i] >= a[i + 3] for i in range(3)), "CUT_BEARING_OVERLAP")


def source_metadata(profile, ground, levels):
    """Preserve all twelve existing ground paces byte-for-byte; no stair-family rate is authored."""
    require(struct.unpack_from("<8sIqIII", profile) == (b"UGPROF01", 2, 3, 29, 271, 1)
            and len(profile) == 10502 and profile[-8:] == b"UGPEND01", "PROFILE_HEADER")
    require(struct.unpack_from("<8sIq7I3q", ground) ==
            (b"UGCONN01", 2, 1, 0, 0, 0, 0, 0, 0, 12, 3, 1, 0)
            and len(ground) == 576 and ground[-8:] == b"UGCEND01" and
            ground[72:104] == profile[32:64] and ground[104:136] == hashlib.sha256(levels).digest(),
            "GROUND_SOURCE")
    heights = []
    for row in range(29):
        fields = struct.unpack_from("<18i3q2B", profile, 64 + row * 98)
        require(fields[21] == 15, "PROFILE_CERTIFICATE")
        for ordinal in range(fields[14], fields[14] + fields[15]):
            box = struct.unpack_from("<7i", profile, 64 + 29 * 98 + ordinal * 28)
            if box[6] in (0, 2, 3):
                heights.append(box[4])
    for row in range(12):
        pace = struct.unpack_from("<7iq", ground, 136 + row * 36)
        require(pace[0] == row + 1 and pace[1:3] == (-1, 0) and pace[5:7] == (0, 0), "GROUND_ONLY")
    return max(heights), ground[136:-8]


def catalog(spec, profile, ground, levels):
    height, paces = source_metadata(profile, ground, levels)
    parts = spec["parts"]
    deck0, deck1 = parts[0]["bounds_u"], parts[7]["bounds_u"]
    # LANDING boxes are floor metadata. Complete body/footing still need actual World proof.
    floors = [[p[0], p[4], p[2], p[3], p[4] + 1, p[5], 17, 0] for p in (deck0, deck1)]
    bounds = [p["bounds_u"] for p in parts + spec["natural_bearings"] + spec["cut_groups"]]
    envelope = [min(b[a] for b in bounds) for a in range(3)] + [max(b[a + 3] for b in bounds) for a in range(3)]
    envelope[4] = height
    # The near edge is the sole source opening; the uncut half metre after T0 is no floor.
    opening = [deck0[0], 0, -128, deck0[3], height, 0, 19, 0]
    regions = [envelope + [16, 0], *floors, opening]
    regions += [b["bounds_u"] + [18, 0] for b in spec["natural_bearings"]]
    regions += [p["bounds_u"] + [20, 0] for p in parts]
    start = spec["sequence_fixture"]["segments"][0]["origin_u"]
    end = [start[0], start[1] + spec["sequence_fixture"]["rise_u"], start[2] - 512]
    header = b"UGCONN01" + struct.pack("<Iq7I3q", 1, 1, 1, 2, len(regions), 14, 56, 1, 12, 3, 1, 0)
    out = header + profile[32:64] + hashlib.sha256(levels).digest()
    variant = [0, 0, 1, *start, *end, 0, 0, 0, 0, 0, 2, 0, len(regions), 0, 14, 0, 56, 0, 0, 1, 0, 1]
    require(len(variant) == 26, "VARIANT_SIZE")
    out += words(variant, 1) + words(start + [0]) + words(end + [0])
    out += b"".join(words(row) for row in regions)
    for p in parts:
        b = p["bounds_u"]
        out += words([3 if p["id"] % 7 >= 3 else 0, b[4] - b[1], 0, -1, 0, 0, 0, p["id"] * 4, 4])
    for p in parts:
        b = p["bounds_u"]
        for x, z in ((b[0], b[2]), (b[3], b[2]), (b[3], b[5]), (b[0], b[5])):
            out += words([x, b[4], z])
    out += words([1024]) + paces + b"UGCEND01"
    require(len(out) == 2732, "CATALOG_SIZE")
    return out


def grouping(catalog_wire):
    out = b"UGASMB01" + struct.pack("<IqqqiqII", 1, 1, 1, 1, 0, 1, 2, 14)
    out += hashlib.sha256(catalog_wire).digest()
    out += words([0, 0, 7, 0]) + words([1, 7, 7, 7]) + b"UGAEND01"
    require(len(out) == 128, "GROUP_SIZE")
    return out


def recipes(spec, catalog_wire, group_wire):
    out = b"UGRECP01" + struct.pack("<IqqqiqI", 1, 1, 1, 1, 0, 1, 2)
    out += hashlib.sha256(catalog_wire).digest() + hashlib.sha256(group_wire).digest()
    for index, assembly in enumerate(spec["assemblies"]):
        out += struct.pack("<iiq8sq", index * 7, 1, assembly["build_milli_wu"], b"wood", assembly["wood_milli"])
        out += bytes(48)
    out += b"UGREND01"
    require(len(out) == 284, "RECIPE_SIZE")
    return out


def build(root=ROOT):
    inputs = {SPEC: SPEC_SHA, PROFILE: PROFILE_SHA, GROUND: GROUND_SHA, LEVELS: LEVELS_SHA}
    raw = {p: read(root, p, h, 131072) for p, h in inputs.items()}
    spec = json.loads(raw[SPEC])
    structure(spec)
    cat = catalog(spec, raw[PROFILE], raw[GROUND], raw[LEVELS])
    group = grouping(cat)
    outputs = {"structure.ugconn": cat, "assemblies.ugasmb": group, "recipes.ugrecp": recipes(spec, cat, group)}
    for name in (PRODUCER, *OWNERS):
        path = root / name
        require(path.is_file() and not path.is_symlink(), "PRODUCER_PATH")
        inputs[name] = sha(path.read_bytes())
    manifest = {"schema": 1, "scope": "Exact authored L0/T0 structural source and approved wood-only bills",
                "source_geometry_only": True, "entry_workflow_qualified": False,
                "world_activation_qualified": False, "traversal_qualified": False,
                "frontier_emitted": False, "workpieces_emitted": False,
                "profile_content_revision": 3, "catalog_revision": 1,
                "grouping_revision": 1, "recipe_revision": 1, "variant_revision": 1,
                "catalog_counts": [1, 2, 26, 14, 56, 1, 12],
                "assembly_count": 2, "wood_milli": 5000, "build_milli_wu": 44000,
                "cut_cube_count": 6, "inputs": inputs,
                "outputs": {p: {"sha256": sha(b), "bytes": len(b)} for p, b in outputs.items()},
                "remaining": ["source-positive excavation Frontier", "paid handling Workpieces and execution",
                              "entry owner integration", "complete descent to room depth"]}
    outputs["manifest.json"] = (json.dumps(manifest, indent=2) + "\n").encode()
    return outputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    outputs = build()
    if args.check:
        require(args.out.is_dir() and {p.name for p in args.out.iterdir()} == set(outputs), "OUTPUT_CENSUS")
        for name, raw in outputs.items():
            require((args.out / name).read_bytes() == raw, "OUTPUT_DRIFT:" + name)
    else:
        args.out.mkdir(parents=True, exist_ok=False)
        for name, raw in outputs.items():
            (args.out / name).write_bytes(raw)
    print("L0/T0 structural packet: 14 included parts, 8 natural bearings, 2 wood-only bills; no work or travel permission")


if __name__ == "__main__":
    main()
