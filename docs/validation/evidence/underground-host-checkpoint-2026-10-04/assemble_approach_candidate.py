#!/usr/bin/env python3
"""Create a diagnostic-only v3 wire from exact old geometry and the real approach compiler.

This is a native/integration test input, not a qualified production publication.
The existing immutable v2 files and the production Catalog are never changed.
Runtime fixture certificate bits let the native test evaluate the candidate;
they do not establish native, consumer, or world acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[4]
LEGACY = ROOT / "godot/data/underground/mole-worker/profile-publication-v2/mole-worker.ugprof"
LEGACY_SHA = "b8033048f55d38ff477388bc6be528a096fd847d040c24faaf374a5e8cfea0ac"
ACTOR_SHA = "adc617642313ac004c050d4877ef0b9f4024bb9c88e3ea92ce9a924471bd5ab9"
PROGRAM_SHA = "5caaec976eb3f8995784dc5f8d98cdb6c233020372d87964620b0da1c4e41c6e"
# This diagnostic increment admits only the complete independently inspected source-4 report.
# A caller-supplied checksum proves transport, not source-derived geometric completeness.
REPORT_SHA = "e9cf37e7de319c9b07b9fda875760201dad5b41bd181a3e6d381bbea6cd4eedd"
REPORT_CANONICAL_SHA = "d013b145724dedb49efef421adb133c95dfff422a423857342fe6ef20f8ea924"
HEADER = struct.Struct("<8sIqIII")
ROW = struct.Struct("<18i3q2B")
BOX = struct.Struct("<7i")
ROLES = ("BODY_HELD_LOAD", "STANCE_SUPPORT", "TURN_RECOVERY", "WORK_APPROACH",
         "WORK_STROKE", "CONTACT_POINT", "CONTACT_PATCH")
CONTENT_REVISION = 2
PROFILE_COUNT, BOX_COUNT, WIRE_BYTES, PAIRED_BYTES = 26, 250, 9620, 19224


def require(value: bool, code: str) -> None:
    if not value:
        raise ValueError(code)


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def legacy_rows(raw: bytes) -> list[tuple[list[int], bytes]]:
    """The old accepted wire is a byte-exact prerequisite, not caller-authored geometry."""
    require(sha(raw) == LEGACY_SHA and len(raw) == 7268, "APPROACH_LEGACY_HASH")
    require(HEADER.unpack_from(raw) == (b"UGPROF01", 1, 1, 18, 194, 1), "APPROACH_LEGACY_HEADER")
    require(raw[32:64].hex() == ACTOR_SHA and raw[-8:] == b"UGPEND01", "APPROACH_LEGACY_SOURCE")
    result, first = [], 0
    for index in range(18):
        fields = list(ROW.unpack_from(raw, 64 + index * ROW.size))
        require(fields[14] == first and fields[15] > 0 and fields[21:] == [15, 0],
                "APPROACH_LEGACY_ROW")
        begin = 64 + 18 * ROW.size + first * BOX.size
        result.append((fields, raw[begin:begin + fields[15] * BOX.size]))
        first += fields[15]
    require(first == 194, "APPROACH_LEGACY_BOXES")
    return result


def approach_rows(report: dict) -> list[dict]:
    """Admit only the source compiler's complete eight exact-heading WALK/READY unions."""
    require(type(report) is dict and report.get("schema") == 1 and report.get("source_program") == 5
            and report.get("actor_sha256") == ACTOR_SHA and report.get("source_program_sha256") == PROGRAM_SHA
            and report.get("verified_source_files") == 537 and report.get("certificate_bits_written") == 0,
            "APPROACH_SOURCE_REPORT")
    require(report.get("root_domain_u") == [0, -32256, 0, 262144, 16896, 262144]
            and report.get("ready_time_q16") == 524288 and report.get("fade_time_q16") == 491520,
            "APPROACH_SOURCE_PROGRAM")
    rows = report.get("rows")
    require(type(rows) is list and len(rows) == 8, "APPROACH_ROW_CENSUS")
    for index, row in enumerate(rows, 2):
        policy = 1 if index < 6 else 2
        yaw = (index - 2) % 4 * 16384
        require(type(row) is dict and row.get("profile") == index and row.get("selection_policy") == policy
                and row.get("yaw") == yaw and row.get("path_yaw") == (yaw + (32768 if policy == 2 else 0)) % 65536
                and row.get("mode") == 1 and row.get("posture") == 0 and row.get("yaw_kind") == 0,
                "APPROACH_ROW_IDENTITY")
        require(type(row.get("roles")) is dict and set(row["roles"]) == set(ROLES[:3]),
                "APPROACH_REQUIRED_ROLES")
    return rows


def encode_boxes(roles: dict) -> bytes:
    """Keep every complete outward integer box; no clipping, scaling or missing-role substitution."""
    result = bytearray()
    for role, name in enumerate(ROLES[:3]):
        values = roles[name]
        require(type(values) is list and len(values) == (1 if role == 1 else 3), "APPROACH_ROLE_COUNT")
        for bounds in values:
            require(type(bounds) is list and len(bounds) == 6 and all(type(v) is int and -(1 << 31) <= v < (1 << 31)
                    for v in bounds) and all(bounds[a] < bounds[a + 3] for a in range(3)), "APPROACH_BOX")
            result.extend(BOX.pack(*bounds, role))
    return bytes(result)


def encode_candidate(legacy: bytes, report: dict) -> tuple[bytes, list[dict]]:
    """Serialize explicit diagnostic policies; source/native qualification remains outside this helper."""
    old = legacy_rows(legacy)
    require(sha(json.dumps(report, sort_keys=True, separators=(",", ":"), allow_nan=False).encode())
            == REPORT_CANONICAL_SHA, "APPROACH_REPORT_PROOF")
    compiled = approach_rows(report)
    selected = [(list(fields), boxes) for fields, boxes in old[:2]]
    for row in compiled:
        fields = list(old[1][0])
        fields[10], fields[11], fields[22] = row["yaw_kind"], row["yaw"], row["selection_policy"]
        selected.append((fields, encode_boxes(row["roles"])))
    for fields, boxes in old[2:]:
        fields = list(fields)
        fields[22] = 3
        selected.append((fields, boxes))
    rows, boxes, mapping, first = bytearray(), bytearray(), [], 0
    for index, (fields, encoded) in enumerate(selected):
        count = len(encoded) // BOX.size
        require(len(encoded) % BOX.size == 0 and count <= 12, "APPROACH_BOX_CENSUS")
        fields[14], fields[15] = first, count
        rows.extend(ROW.pack(*fields))
        boxes.extend(encoded)
        mapping.append({"profile": index, "selection_policy": fields[22], "profile_revision": fields[18],
                        "content_revision": CONTENT_REVISION, "yaw": fields[11], "first_box": first,
                        "box_count": count, "legacy_profile": index if index < 2 else (index - 8 if index >= 10 else None)})
        first += count
    require(len(selected) == PROFILE_COUNT and first == BOX_COUNT, "APPROACH_WIRE_CENSUS")
    wire = HEADER.pack(b"UGPROF01", 2, CONTENT_REVISION, PROFILE_COUNT, BOX_COUNT, 1)
    wire += bytes.fromhex(ACTOR_SHA) + rows + boxes + b"UGPEND01"
    require(len(wire) == WIRE_BYTES and 2 * (len(wire) - 8) == PAIRED_BYTES, "APPROACH_WIRE_BYTES")
    return wire, mapping


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--report-sha", required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    require(not args.out.exists() and not args.out.is_symlink(), "APPROACH_OUTPUT_EXISTS")
    require(args.out.resolve().is_relative_to(ROOT / "docs/validation/evidence"), "APPROACH_DIAGNOSTIC_OUTPUT_ONLY")
    raw = args.report.read_bytes()
    require(len(raw) <= 4 * 1024 * 1024 and sha(raw) == args.report_sha == REPORT_SHA, "APPROACH_REPORT_HASH")
    wire, mapping = encode_candidate(LEGACY.read_bytes(), json.loads(raw))
    manifest = {"schema": 1, "diagnostic_only": True, "production_qualified": False,
                "native_qualified": False, "world_activation_qualified": False,
                "certificate_flags": 15, "certificate_scope": "native/integration fixture only; not published qualification",
                "source_report_sha256": sha(raw), "legacy_wire_sha256": LEGACY_SHA,
                "serializer_sha256": sha(Path(__file__).read_bytes()), "wire_sha256": sha(wire),
                "wire_version": 2, "content_revision": CONTENT_REVISION, "profile_count": PROFILE_COUNT,
                "box_count": BOX_COUNT, "wire_bytes": WIRE_BYTES, "paired_bank_bytes": PAIRED_BYTES,
                "mapping": mapping, "remaining": ["NATIVE_CANONICAL_CLOCK", "CURRENT_NINE_CONSUMER_CLOSURE",
                                                    "INDEPENDENT_REVIEW", "PRODUCTION_PUBLICATION"]}
    args.out.mkdir(parents=True)
    (args.out / "mole-worker.ugprof").write_bytes(wire)
    (args.out / "approach-program.json").write_bytes(raw)
    (args.out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"wire_sha256": sha(wire), "wire_bytes": len(wire), "diagnostic_only": True}))


if __name__ == "__main__":
    main()
