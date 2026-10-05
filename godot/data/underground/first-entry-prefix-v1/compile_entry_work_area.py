#!/usr/bin/env python3
"""Create-only diagnostic Frontier with complete original entry work-area selectors.

This preserves every accepted predecessor and all actual profile geometry. The
packet does not publish Locations, qualify terrain or grant paid construction.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct

HERE = Path(__file__).resolve().parent
LOADER = importlib.util.spec_from_file_location("entry_diagnostic", HERE / "rebind_handling_diagnostic.py")
D = importlib.util.module_from_spec(LOADER)
LOADER.loader.exec_module(D)
F = D.F
S = D.S
COUNTS = [2, 8, 2, 10, 12, 6]
H = [-832, 0, 512]
M = [-832, 0, 2048]
R = [-832, 0, 1536]
H_AIR = [-445, 0, -732, 910, 1036, 346]
H_FOOT = [-274, -1, -274, 299, 0, 249]
GROUND_AIR = [-1256, 0, -1256, 1256, 1036, 1256]
GROUND_FOOT = [-406, -1, -406, 406, 0, 406]
BEARER = [-1024, 0, 0, 1024, 128, 128]


def require(ok, code):
    if not ok:
        raise ValueError("ENTRY_WORK_AREA_" + code)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def profile_boxes(raw, row):
    """Decode the exact two-source diagnostic; source hashes are checked before this helper."""
    fields = struct.unpack_from("<18i3q2B", raw, 96 + row * 98)
    return [list(struct.unpack_from("<7i", raw, 96 + 30 * 98 + i * 28))
            for i in range(fields[14], fields[14] + fields[15])]


def tables(spec):
    table, travel = F.tables(spec)
    table[4][0][4:7] = H
    table[4][1][4:7] = M
    table[4][2][4:7] = R
    table[4].extend([table[4][1].copy(), table[4][2].copy()])
    travel[0:3] = [2, 2, 6]
    travel.extend([12, 12])
    table[0][0][8] = 2
    for episode in table[5]:
        episode[15:17] = [10, 11]
    return table, travel


def perimeter(storage, work):
    """Full all-yaw turns stay outside the six cut cubes and the pending timber."""
    side = -2560 if work[0] < 0 else 2560
    points = [storage, [storage[0], 0, 1536], [side, 0, 1536], [side, 0, work[2]], work]
    return [point.copy() for index, point in enumerate(points) if index == 0 or point != points[index - 1]]


def contains(outer, inner):
    return all(outer[i] <= inner[i] and inner[i + 3] <= outer[i + 3] for i in range(3))


def sweep(box, first, last):
    return [min(first[i], last[i]) + box[i] for i in range(3)] + \
        [max(first[i], last[i]) + box[i + 3] for i in range(3)]


def endpoint_contains(profile, air, foot):
    """Every complete BODY/recovery/support box fits; no role or held-pick component is omitted."""
    for box in profile:
        if box[6] not in (0, 1, 2, 3):
            continue
        if box[1] < 0:
            if box[4] > 0 or not contains(foot, box):
                return False
        elif not contains(air, box):
            return False
    return True


def validate(table, travel, profile):
    """Static full-source fit is evidence, never a substitute for current World permission."""
    require([len(rows) for rows in table] == COUNTS and len(travel) == 12, "CENSUS")
    require(table[4][1] == table[4][10] and table[4][2] == table[4][11], "STORAGE_ALIASES")
    require(travel[:3] == [2, 2, 6] and travel[10:] == [12, 12], "TRAVEL_SELECTION")
    require(table[0][0][7:9] == [1, 2], "INSTALL_APPROACH_RETREAT")
    require(all(e[15:17] == [10, 11] and e[:6] == F.cube(i) for i, e in enumerate(table[5])), "CUT_IDENTITY")
    require(table[4][0][4:7] == H and table[1][0][1:4] == H, "WORK_STATION")
    for row in [2, 6, 16, 29]:
        require(endpoint_contains(profile_boxes(profile, row), H_AIR, H_FOOT), "H_COMPLETE_SOURCE")
    require(not endpoint_contains(profile_boxes(profile, 12), H_AIR, H_FOOT), "H_MUST_EXCLUDE_ALL_YAW")
    walk = profile_boxes(profile, 12)
    require(endpoint_contains(walk, GROUND_AIR, GROUND_FOOT), "GROUND_COMPLETE_SOURCE")
    for selector in [1, 2]:
        point = table[4][selector][4:7]
        require(not F.overlaps(F.translated(GROUND_AIR, point), BEARER), "STORAGE_BLOCKED")
        require(all(not F.overlaps(F.translated(GROUND_FOOT, point), F.cube(c)) for c in range(6)), "STORAGE_FOOT_IN_CUT")
    paths = []
    for ordinal in range(6):
        work = table[4][ordinal + 4][4:7]
        require(work == F.side_root(ordinal), "DIG_ROOT_CHANGED")
        for selector in [10, 11]:
            points = perimeter(table[4][selector][4:7], work)
            for first, last in zip(points, points[1:]):
                require(sum(first[i] != last[i] for i in range(3)) == 1, "NON_AXIAL_PATH")
                for box in walk:
                    if box[6] not in (0, 1, 2, 3) or box[1] >= 0:
                        continue
                    require(box[4] <= 0 and all(not F.overlaps(sweep(box, first, last), F.cube(c))
                                               for c in range(6)), "FULL_FOOT_SWEEP_IN_CUT")
            paths.append({"from_selector": selector, "to_selector": ordinal + 4, "profile": 12, "points": points})
    blocked = [ordinal + 4 for ordinal in range(6)
               if F.overlaps(F.translated(GROUND_AIR, F.side_root(ordinal)), BEARER)]
    require(blocked == [4, 5], "RETIREMENT_SCOPE")
    return {"scope": "Static source layout; current terrain, graph and paid proof required",
            "handling_point": H, "handling_air": H_AIR, "handling_foot": H_FOOT,
            "ground_air": GROUND_AIR, "ground_foot": GROUND_FOOT,
            "retire_after_completed_cut_selectors": blocked, "perimeter_paths": paths}


def serialize(table, travel, predecessor):
    """Revision2 carries two extra travel selectors without changing the reader schema."""
    header = bytearray(predecessor[:220])
    struct.pack_into("<q", header, 12, 2)
    struct.pack_into("<6I", header, 68, *COUNTS)
    out = bytes(header)
    for index, rows in enumerate(table):
        for ordinal, row in enumerate(rows):
            out += S.words(row)
            if index == 1:
                out += struct.pack("<qiqiqiq", 1, -1, 0, -1, 0, -1, 0)
            elif index == 4:
                out += struct.pack("<iq", travel[ordinal], 1)
    out += b"UGFEND01"
    require(len(out) == 2292, "WIRE_SIZE")
    return out


def build(profile):
    predecessor = D.build(profile)  # Includes exact SHA, unmodified rows and all predecessor pins.
    spec = json.loads(S.read(S.ROOT, S.SPEC, S.SPEC_SHA, 131072))
    table, travel = tables(spec)
    layout = validate(table, travel, profile)
    wire = serialize(table, travel, predecessor["frontier.ugfront"])
    layout_raw = (json.dumps(layout, indent=2) + "\n").encode()
    manifest = {"schema": 1, "scope": "Diagnostic work area, same exact content4 profiles",
                "production_qualified": False, "paid_execution_qualified": False,
                "native_route_qualified": False, "frontier_revision": 2, "table_counts": COUNTS,
                "reader_bank_bytes": 4112, "profile_sha256": sha(profile),
                "producer_sha256": sha(Path(__file__).read_bytes()),
                "predecessor_manifest_sha256": sha(predecessor["manifest.json"]),
                "outputs": {"frontier.ugfront": {"bytes": len(wire), "sha256": sha(wire)},
                            "layout.json": {"bytes": len(layout_raw), "sha256": sha(layout_raw)}},
                "remaining": ["current World source/masks/retirement proof", "actual paid START/handling/fastening",
                              "native canonical forward/backward replay", "complete memory closure and independent review"]}
    return {"frontier.ugfront": wire, "layout.json": layout_raw,
            "manifest.json": (json.dumps(manifest, indent=2) + "\n").encode()}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--profile", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    require(args.profile.is_file() and not args.profile.is_symlink() and args.profile.stat().st_size == 10912, "PROFILE_PATH")
    require(not args.out.exists() and args.out.resolve().is_relative_to(S.ROOT / "docs/validation/evidence"), "OUTPUT_PATH")
    packet = build(args.profile.read_bytes())
    args.out.mkdir(parents=True)
    for name, raw in packet.items():
        (args.out / name).write_bytes(raw)
    print(json.dumps({name: sha(raw) for name, raw in packet.items()}, indent=2))


if __name__ == "__main__":
    main()
