#!/usr/bin/env python3
"""Compile exact ground pace identities; this offline artifact grants no route or actor permission."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[4]
PROFILE_PATH = "godot/data/underground/mole-worker/profile-publication-v3/mole-worker.ugprof"
PROFILE_SHA = "a581f90aa0db07187a1dfc1f0836bd7f3de39d401ff944db07a3958649b1c204"
LEVEL_PATH = "godot/data/underground/initial_level_pack.uglvl"
LEVEL_SHA = "c5deb094b335bf6e5db018eeed591a115086b79bd909f829ed6e34166db81f94"
MOVEMENT_PATH = "godot/scripts/core/movement.gd"
RESIDENTS_PATH = "godot/scripts/core/residents.gd"
PROFILE_OWNER_PATH = "godot/scripts/core/underground_profiles.gd"
MAX_PROFILE_BYTES = 40 + 64 * 32 + 256 * 98 + 3072 * 28
MOVEMENT_KEY = "starter.ground.adult.mole"
OUTPUT_NAME = "ground-pace.ugconn"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_pinned(path, expected, maximum):
    require(0 < path.stat().st_size <= maximum, "GROUND_INPUT_CAPACITY")
    data = path.read_bytes()
    require(len(data) <= maximum and digest(data) == expected, "GROUND_INPUT_SHA")
    return data


def integer_constant(source, name):
    matches = re.findall(r"^const " + re.escape(name) + r": int = (\d+)(?:\s*#.*)?$", source, re.M)
    require(len(matches) == 1, "GROUND_CONSTANT_" + name)
    return int(matches[0])


def name_array(source, name):
    matches = re.findall(r"^const " + re.escape(name) + r": Array\[StringName\] = \[([^]]*)\]", source, re.M)
    require(len(matches) == 1, "GROUND_ARRAY_" + name)
    values = re.findall(r'&"([A-Za-z0-9_.]+)"', matches[0])
    require(values and len(values) == len(set(values)), "GROUND_ARRAY_VALUES_" + name)
    return values


def movement_identity(movement, residents):
    """Read the existing key order and ASCII species identity, never copy or invent a speed."""
    keys = name_array(movement, "PROFILE_KEYS")
    species = name_array(movement, "PROFILE_SPECIES_KEYS")
    require(len(keys) == len(species) and MOVEMENT_KEY in keys, "GROUND_MOVEMENT_KEY")
    profile = keys.index(MOVEMENT_KEY)
    require(species[profile] == "mole", "GROUND_MOVEMENT_SPECIES")
    all_species = sum((name_array(residents, "SPECIES_" + size + "_KEYS")
                       for size in ("SMALL", "MEDIUM", "LARGE")), [])
    require(len(all_species) == len(set(all_species)) and "mole" in all_species,
            "GROUND_RESIDENT_SPECIES")
    return {"profile_id": profile, "profile_key": MOVEMENT_KEY,
            "profile_revision": integer_constant(movement, "PROFILE_FIRST_REVISION"),
            "species_id": sorted(all_species).index("mole"),
            "life_stage": integer_constant(residents, "LIFE_STAGE_ADULT")}


def walking_rows(image, identity, mode_walk, required_certificate):
    """Bound the complete wire before indexing; emit only its actual exact WALK descriptors."""
    require(40 <= len(image) <= MAX_PROFILE_BYTES and image[:8] == b"UGPROF01"
            and image[-8:] == b"UGPEND01", "GROUND_PROFILE_FORMAT")
    version, revision, count, boxes, sources = struct.unpack_from("<IqIII", image, 8)
    require(version == 2 and revision > 0 and 1 <= count <= 256 and 1 <= boxes <= 3072
            and sources == 1, "GROUND_PROFILE_HEADER")
    require(len(image) == 40 + 32 * sources + 98 * count + 28 * boxes,
            "GROUND_PROFILE_LENGTH")
    rows, excluded = [], []
    for profile in range(count):
        row = struct.unpack_from("<18i3q2B", image, 32 + 32 * sources + 98 * profile)
        if row[4] != mode_walk:
            excluded.append({"profile_id": profile, "mode": row[4]})
            continue
        require(row[0] == 0 and row[1:3] == (identity["species_id"], identity["life_stage"])
                and row[18] > 0 and row[21] == required_certificate,
                "GROUND_PROFILE_IDENTITY")
        rows.append({"profile_id": profile, "profile_revision": row[18], "mode": row[4],
                     "yaw_kind": row[10], "yaw": row[11], "selection_policy": row[22]})
    require(1 <= len(rows) <= 256, "GROUND_PACE_COUNT")
    return revision, image[32:64], rows, excluded


def encode(profile_revision, source_digest, level_revision, level_digest, identity, rows):
    """The six absent tables consume no wire payload; each pace preserves the legacy 36-byte shape."""
    require(profile_revision > 0 and level_revision > 0 and len(source_digest) == 32
            and len(level_digest) == 32 and 1 <= len(rows) <= 256, "GROUND_ENCODE_HEADER")
    ids = [row["profile_id"] for row in rows]
    require(ids == sorted(set(ids)), "GROUND_PACE_ORDER")
    out = bytearray(b"UGCONN01")
    out.extend(struct.pack("<Iq7I3q", 2, 1, 0, 0, 0, 0, 0, 0, len(rows),
                           profile_revision, level_revision, 0))
    out.extend(source_digest)
    out.extend(level_digest)
    for row in rows:
        out.extend(struct.pack("<7iq", row["profile_id"], -1, 0, identity["profile_id"],
                               identity["profile_revision"], 0, 0, row["profile_revision"]))
    out.extend(b"UGCEND01")
    require(len(out) == 144 + 36 * len(rows), "GROUND_ENCODE_LENGTH")
    return bytes(out)


def build(root=ROOT):
    profile = read_pinned(root / PROFILE_PATH, PROFILE_SHA, MAX_PROFILE_BYTES)
    levels = read_pinned(root / LEVEL_PATH, LEVEL_SHA, 156)
    movement = (root / MOVEMENT_PATH).read_text()
    residents = (root / RESIDENTS_PATH).read_text()
    owner = (root / PROFILE_OWNER_PATH).read_text()
    identity = movement_identity(movement, residents)
    revision, source, rows, excluded = walking_rows(profile, identity,
        integer_constant(owner, "MODE_WALK"), integer_constant(owner, "CERT_REQUIRED"))
    require(levels[:8] == b"UGLEVEL1" and levels[-8:] == b"UGLEND01"
            and struct.unpack_from("<I", levels, 8)[0] == 1, "GROUND_LEVEL_FORMAT")
    level_revision = struct.unpack_from("<q", levels, 12)[0]
    wire = encode(revision, source, level_revision, hashlib.sha256(levels).digest(), identity, rows)
    inputs = [PROFILE_PATH, LEVEL_PATH, MOVEMENT_PATH, RESIDENTS_PATH, PROFILE_OWNER_PATH,
              "godot/scripts/core/catalog.gd",
              "godot/data/underground/ground-pace-v1/compile_ground_pace.py"]
    manifest = {"schema": 1, "wire_version": 2, "catalog_revision": 1,
        "artifact": OUTPUT_NAME, "artifact_sha256": digest(wire), "artifact_bytes": len(wire),
        "counts": {"variants": 0, "points": 0, "regions": 0, "parts": 0,
                   "vertices": 0, "materials": 0, "paces": len(rows)},
        "profile_content_revision": revision, "profile_source_id": 0,
        "profile_source_sha256": source.hex(), "profile_wire_sha256": digest(profile),
        "level_revision": level_revision, "level_sha256": digest(levels),
        "movement": identity, "rate_kind": "RATE_GROUND_CAP", "rate_value": 0,
        "rows": rows, "excluded_non_walk": excluded,
        "inputs": {name: digest((root / name).read_bytes()) for name in inputs},
        "source": "Exact current immutable WALK identities; actual Movement supplies every rate.",
        "runtime_activation_qualified": False, "clearance_or_actor_permission": False,
        "native_memory_measured": False}
    return wire, manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    wire, manifest = build()
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / OUTPUT_NAME).write_bytes(wire)
    (args.out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"{OUTPUT_NAME}: {len(wire)} bytes, {manifest['counts']['paces']} exact WALK rows, {digest(wire)}")


if __name__ == "__main__":
    main()
