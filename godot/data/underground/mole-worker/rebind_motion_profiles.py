#!/usr/bin/env python3
"""Rebind unchanged source-only stair tables to the reviewed complete profile-v3 image."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = HERE / "evidence/contact-qualification/motion-catalog-v1"
PROFILES = HERE / "profile-publication-v3"
OLD_SHA = "495b22dacb303152651f8ca061a0017aa72a4031e281ac1df34dd9035bf695a0"
PRODUCER_SHA = "035f5e58a5e2b2f689cd5de14f7fc184526c292fcdef7516faf6a00f1ff873ec"
PROFILE_SHA = "a581f90aa0db07187a1dfc1f0836bd7f3de39d401ff944db07a3958649b1c204"
PROFILE_MANIFEST_SHA = "8f210e11768131779e6c825d7a3d2509cb32076aedd6891e6573489d1b6814c1"
OLD_PROFILE_SHA = "b8033048f55d38ff477388bc6be528a096fd847d040c24faaf374a5e8cfea0ac"
I64_AT = 32 + 12 + 17421 * 4 + 12
BYTE_AT = I64_AT + 67 * 8 + 12


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def read(path, expected=None, maximum=4 * 1024 * 1024):
    require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(ROOT), "MOTION_REBIND_SOURCE_PATH")
    require(path.stat().st_size <= maximum, "MOTION_REBIND_SOURCE_SIZE")
    raw = path.read_bytes()
    require(expected is None or digest(raw) == expected, "MOTION_REBIND_SOURCE_HASH")
    return raw


def rebind(original, profile_wire, numerical_sha):
    """Change only joint/profile revisions and source-manifest digests; geometry and rates remain byte exact."""
    require(digest(original) == OLD_SHA and len(original) == 70936, "MOTION_REBIND_ORIGINAL")
    require(digest(profile_wire) == PROFILE_SHA and len(profile_wire) == 9620, "MOTION_REBIND_PROFILE")
    require(len(numerical_sha) == 64 and all(c in "0123456789abcdef" for c in numerical_sha), "MOTION_REBIND_MANIFEST")
    require(struct.unpack_from("<q", original, 16) == (1,) and
            struct.unpack_from("<3q", original, I64_AT) == (1, 1, 1) and
            original[BYTE_AT + 160:BYTE_AT + 192].hex() == OLD_PROFILE_SHA, "MOTION_REBIND_LAYOUT")
    result = bytearray(original)
    struct.pack_into("<q", result, 16, 2)
    struct.pack_into("<2q", result, I64_AT + 8, 2, 2)
    result[BYTE_AT + 160:BYTE_AT + 192] = bytes.fromhex(PROFILE_SHA)
    result[BYTE_AT + 384:BYTE_AT + 416] = bytes.fromhex(numerical_sha)
    ranges = [(16, 24), (I64_AT + 8, I64_AT + 24), (BYTE_AT + 160, BYTE_AT + 192),
              (BYTE_AT + 384, BYTE_AT + 416)]
    require(all(a == b or any(low <= index < high for low, high in ranges)
                for index, (a, b) in enumerate(zip(original, result))), "MOTION_REBIND_FOREIGN_DELTA")
    require(result[44:I64_AT - 12] == original[44:I64_AT - 12] and
            result[I64_AT + 24:BYTE_AT - 12] == original[I64_AT + 24:BYTE_AT - 12], "MOTION_REBIND_GEOMETRY_DELTA")
    return bytes(result), ranges


def inputs():
    """Reconstruct the complete accepted old source tables and require the current reviewed profile publication."""
    read(OLD / "pack_catalog.py", PRODUCER_SHA)
    spec = importlib.util.spec_from_file_location("accepted_original_motion_pack", OLD / "pack_catalog.py")
    producer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(producer)
    original, old_manifest = producer.compile_image(ROOT)
    require(original == read(OLD / "candidate-2/motion.ugmotion", OLD_SHA), "MOTION_REBIND_REPRODUCTION")
    profile_wire = read(PROFILES / "mole-worker.ugprof", PROFILE_SHA)
    # This fixed publication identity transitively binds the independent review,
    # complete proof closure, publisher, and all nine production consumers.
    # A caller cannot replace it with a self-declared qualification manifest.
    profile_raw = read(PROFILES / "manifest.json", PROFILE_MANIFEST_SHA)
    profile = json.loads(profile_raw)
    constants = read(PROFILES / "catalog_source.gd", profile["constants_sha256"])
    require(profile.get("source_geometry_qualified") is True and profile.get("world_activation_qualified") is False
            and profile.get("wire_sha256") == PROFILE_SHA and profile.get("content_revision") == 2
            and profile.get("profile_count") == 26 and profile.get("box_count") == 250,
            "MOTION_REBIND_PROFILE_QUALIFICATION")
    require(type(profile.get("prerequisite_pins")) is dict and 0 < len(profile["prerequisite_pins"]) <= 1024,
            "MOTION_REBIND_PROOF_CENSUS")
    for path, expected in profile["prerequisite_pins"].items():
        read(ROOT / path, expected, 32 * 1024 * 1024)
    pins = dict(old_manifest["source_pins"])
    pins.update({str((PROFILES / "mole-worker.ugprof").relative_to(ROOT)): PROFILE_SHA,
                 str((PROFILES / "manifest.json").relative_to(ROOT)): PROFILE_MANIFEST_SHA,
                 str((PROFILES / "catalog_source.gd").relative_to(ROOT)): digest(constants),
                 str((OLD / "pack_catalog.py").relative_to(ROOT)): PRODUCER_SHA,
                 str(Path(__file__).relative_to(ROOT)): digest(Path(__file__).read_bytes())})
    numerical_sha = digest(json.dumps(pins, sort_keys=True, separators=(",", ":")).encode())
    wire, ranges = rebind(original, profile_wire, numerical_sha)
    return wire, {"schema": 1, "content_revision": 2, "profiles_content_revision": 2,
                  "wire_sha256": digest(wire), "wire_bytes": len(wire), "bank_bytes": 70860,
                  "columns": {"i32": 17421, "i64": 67, "bytes": 640}, "source_pins": pins,
                  "numerical_input_manifest_sha256": numerical_sha, "original_wire_sha256": OLD_SHA,
                  "permitted_changed_byte_ranges": ranges, "all_original_geometry_preserved": True,
                  "all_original_permission_and_rate_values_preserved": True, "runtime_activation": False,
                  "pace_adopted": False, "scope": "Source-only profile binding; no runtime stair traversal qualification."}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    require(not args.out.exists() and not args.out.is_symlink(), "MOTION_REBIND_OUTPUT_EXISTS")
    require(args.out.resolve().is_relative_to(HERE), "MOTION_REBIND_OUTPUT_PATH")
    wire, manifest = inputs()
    for path, expected in manifest["source_pins"].items():
        read(ROOT / path, expected)
    args.out.mkdir(parents=True)
    with (args.out / "motion.ugmotion").open("xb") as stream:
        stream.write(wire)
    with (args.out / "manifest.json").open("x") as stream:
        stream.write(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"wire_sha256": digest(wire), "wire_bytes": len(wire), "runtime_activation": False}))


if __name__ == "__main__":
    main()
