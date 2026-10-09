#!/usr/bin/env python3
"""Create-only v4 input for tests; no production, native or world certificate is issued.

The exact accepted v3 rows and complete reviewed short-step roles are immutable
inputs. Diagnostic flags permit executing the candidate consumer, not publishing
it. The authoritative production publisher remains a separate reviewed owner.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[5]
OLD = ROOT / "godot/data/underground/mole-worker/profile-publication-v3/mole-worker.ugprof"
OLD_SHA = "a581f90aa0db07187a1dfc1f0836bd7f3de39d401ff944db07a3958649b1c204"
REPORT = ROOT / "docs/validation/evidence/underground-short-work-step-2026-10-05/source-3/result/step-program.json"
REPORT_SHA = "fff35c8c2ead2f43a68a242ca3ac156f9348af1880a00dd7ebbb16aaa1f476a0"
ACTOR_SHA = "adc617642313ac004c050d4877ef0b9f4024bb9c88e3ea92ce9a924471bd5ab9"
PARENT_SHA = "5caaec976eb3f8995784dc5f8d98cdb6c233020372d87964620b0da1c4e41c6e"
EVIDENCE = ROOT / "docs/validation/evidence/underground-short-work-step-runtime-2026-10-05"
HEADER, ROW, BOX = struct.Struct("<8sIqIII"), struct.Struct("<18i3q2B"), struct.Struct("<7i")
PROFILE_COUNT, BOX_COUNT, WIRE_BYTES, PAIRED_BYTES = 29, 271, 10502, 20988
CONTENT_REVISION = 3


def need(value, code):
    if not value:
        raise ValueError(code)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def bounded(path, size, digest):
    need(path.is_file() and not path.is_symlink() and path.stat().st_size <= size,
         "STEP_INPUT_CAPACITY")
    raw = path.read_bytes()
    need(len(raw) <= size and sha(raw) == digest, "STEP_INPUT_HASH")
    return raw


def old_rows(raw):
    need(sha(raw) == OLD_SHA and len(raw) == 9620, "STEP_OLD_HASH")
    need(HEADER.unpack_from(raw) == (b"UGPROF01", 2, 2, 26, 250, 1) and
         raw[32:64].hex() == ACTOR_SHA and raw[-8:] == b"UGPEND01", "STEP_OLD_HEADER")
    result, first = [], 0
    for index in range(26):
        fields = list(ROW.unpack_from(raw, 64 + index * ROW.size))
        policy = 0 if index < 2 else (1 if index < 6 else (2 if index < 10 else 3))
        need(fields[14] == first and 0 < fields[15] <= 12 and fields[21:] == [15, policy],
             "STEP_OLD_ROW")
        offset = 64 + 26 * ROW.size + first * BOX.size
        result.append((fields, raw[offset:offset + fields[15] * BOX.size]))
        first += fields[15]
    need(first == 250, "STEP_OLD_BOXES")
    return result


def source_rows(raw):
    """A caller cannot strip provenance, alter a box or rehash a self-labelled report."""
    need(len(raw) <= 4 * 1024 * 1024 and sha(raw) == REPORT_SHA, "STEP_REPORT_HASH")
    report = json.loads(raw)
    need(report["schema"] == 1 and report["protocol"] == "finite-work-step-v1" and
         report["actor_sha256"] == ACTOR_SHA and report["parent_program_sha256"] == PARENT_SHA and
         report["verified_source_files"] == 537 and report["certificate_bits_written"] == 0 and
         report["production_qualified"] is False, "STEP_REPORT_SOURCE")
    need(report["ready_clip"] == 0 and report["ready_time_q16"] == 524288 and
         report["fade_time_q16"] == 491520 and report["walk_duration_q16"] == 2097153 and
         report["integer_protocol"]["pace_u_per_second"] == 3277 and
         report["integer_protocol"]["distance_u"] == 232, "STEP_REPORT_PROTOCOL")
    rows = report["rows"]
    need(len(rows) == 2, "STEP_ROW_COUNT")
    for row, direction in zip(rows, (1, -1)):
        need(row["direction"] == direction and row["mode"] == "WALK" and
             row["body_yaw"] == 49152 and row["path_yaw"] == (49152 if direction == 1 else 16384),
             "STEP_SOURCE_DIRECTION")
    return rows


def boxes_into(roles):
    result = bytearray()
    names = ("BODY_HELD_LOAD", "STANCE_SUPPORT", "TURN_RECOVERY")
    need(set(roles) == set(names), "STEP_ROLE_KEYS")
    for role, name in enumerate(names):
        values = roles[name]
        need(len(values) == (1 if role == 1 else 3), "STEP_ROLE_COUNT")
        for bounds in values:
            need(len(bounds) == 6 and all(type(v) is int and -(1 << 31) <= v < (1 << 31)
                 for v in bounds) and all(bounds[a] < bounds[a + 3] for a in range(3)), "STEP_ROLE_BOUNDS")
            result.extend(BOX.pack(*bounds, role))
    return bytes(result)


def encode(old, report):
    previous, compiled = old_rows(old), source_rows(report)
    selected = [(list(f), b, i) for i, (f, b) in enumerate(previous[:10])]
    for row, policy in zip(compiled, (4, 5)):
        fields = list(previous[5][0])
        fields[22] = policy
        selected.append((fields, boxes_into(row["roles"]), None))
    ground = list(previous[1][0])
    ground[22] = 6
    selected.append((ground, previous[1][1], 1))
    selected.extend((list(f), b, i + 10) for i, (f, b) in enumerate(previous[10:]))
    records, boxes, mapping, first = bytearray(), bytearray(), [], 0
    for index, (fields, data, predecessor) in enumerate(selected):
        count = len(data) // BOX.size
        need(len(data) % BOX.size == 0 and 0 < count <= 12, "STEP_OUTPUT_BOXES")
        fields[14:16] = [first, count]
        records.extend(ROW.pack(*fields))
        boxes.extend(data)
        mapping.append({"profile": index, "policy": fields[22], "revision": fields[18],
                        "content_revision": CONTENT_REVISION, "predecessor": predecessor,
                        "first_box": first, "box_count": count})
        first += count
    need(len(selected) == PROFILE_COUNT and first == BOX_COUNT, "STEP_OUTPUT_CENSUS")
    wire = HEADER.pack(b"UGPROF01", 2, CONTENT_REVISION, PROFILE_COUNT, BOX_COUNT, 1)
    wire += bytes.fromhex(ACTOR_SHA) + records + boxes + b"UGPEND01"
    need(len(wire) == WIRE_BYTES and 2 * (len(wire) - 8) == PAIRED_BYTES, "STEP_OUTPUT_BYTES")
    return wire, mapping


def write_candidate(out):
    need(not out.exists() and not out.is_symlink(), "STEP_OUTPUT_EXISTS")
    need(out.resolve().is_relative_to(EVIDENCE), "STEP_DIAGNOSTIC_OUTPUT_ONLY")
    report = bounded(REPORT, 4 * 1024 * 1024, REPORT_SHA)
    wire, mapping = encode(bounded(OLD, 9620, OLD_SHA), report)
    manifest = {"schema": 1, "diagnostic_only": True, "production_qualified": False,
                "native_qualified": False, "world_activation_qualified": False,
                "certificate_flags": 15, "certificate_scope": "candidate execution only; no new qualification",
                "predecessor_wire_sha256": OLD_SHA, "source_report_sha256": REPORT_SHA,
                "serializer_sha256": sha(Path(__file__).read_bytes()), "wire_sha256": sha(wire),
                "protocol": 6, "content_revision": 3, "profile_count": PROFILE_COUNT,
                "box_count": BOX_COUNT, "wire_bytes": WIRE_BYTES, "paired_bank_bytes": PAIRED_BYTES,
                "mapping": mapping, "remaining": ["CURRENT_RUNTIME_REVIEW", "CANONICAL_NATIVE_REPLAY",
                                                    "SOURCE_CONSUMER_PUBLICATION", "WORLD_QUALIFICATION"]}
    out.mkdir(parents=True)
    (out / "mole-worker.ugprof").write_bytes(wire)
    (out / "step-program.json").write_bytes(report)
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    result = write_candidate(args.out)
    print(json.dumps({key: result[key] for key in ("wire_sha256", "wire_bytes", "diagnostic_only")}))


if __name__ == "__main__":
    main()
