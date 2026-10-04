#!/usr/bin/env python3
"""Read-only integer census of the engineering prefix; no motion permission."""
import hashlib
import itertools
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def overlap(a, b):
    return all(a[i] < b[i + 3] and b[i] < a[i + 3] for i in range(3))


def rotate_xz(box, turns, root_x, root_z):
    points = []
    for x, z in itertools.product((box[0], box[3]), (box[2], box[5])):
        for _ in range(turns):
            x, z = -z, x
        points.append((root_x + x, root_z + z))
    return [min(p[0] for p in points), box[1], min(p[1] for p in points),
            max(p[0] for p in points), box[4], max(p[1] for p in points)]


def main():
    for name, pin in json.loads((ROOT / "input-sha256.json").read_text()).items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == pin["sha256"]
    source = json.loads((ROOT / "prefix-source.json").read_text())
    parts = source["parts"]
    cubes = []
    for group in source["cut_groups"]:
        a, b, c, d, e, f = group["bounds_u"]
        rows = [[x, y, z, x + 1024, y + 1024, z + 1024]
                for y in range(b, e, 1024) for z in range(c, f, 1024)
                for x in range(a, d, 1024)]
        assert len(rows) == group["whole_1024u_cubes"]
        cubes.extend(rows)
    assert len({tuple(row) for row in cubes}) == 6
    for part in parts:
        box = part["bounds_u"]
        enclosing = source["cut_groups"][part["assembly"]]["bounds_u"]
        assert all(enclosing[i] <= box[i] < box[i + 3] <= enclosing[i + 3] for i in range(3))
    assert not any(overlap(a["bounds_u"], b["bounds_u"]) for a, b in itertools.combinations(parts, 2))
    assert not any(overlap(bearing["bounds_u"], cube)
                   for bearing in source["natural_bearings"] for cube in cubes)
    down = json.loads((ROOT / "down-constituent.json").read_text())["adjacent_primitive_proof"]
    entry = json.loads((ROOT / "entry-constituent.json").read_text())["parts"]
    body = [part["floor_intersection_u"] for part in down + entry if part["kind"] == "body"]
    stance = [min(b[i] for b in body) for i in range(3)] + [max(b[i] for b in body) for i in range(3, 6)]
    tip = next(part["floor_intersection_u"] for part in down if part["kind"] == "attachment")
    stations = []
    for z in [-512, -1536, -2560]:
        for x, rotation in [(-1408, 1), (1408, 3)]:
            feet = rotate_xz(stance, rotation, x, z)
            tool = rotate_xz(tip, rotation, x, z)
            cube = [-1024 if x < 0 else 0, -1024, z - 512,
                    0 if x < 0 else 1024, 0, z + 512]
            assert feet[3] <= -1024 or feet[0] >= 1024
            assert all(cube[i] <= tool[i] and tool[i + 3] <= cube[i + 3] for i in range(3))
            stations.append({"root_u": [x, 0, z], "yaw_u16": (-rotation * 16384) % 65536,
                             "stance_u": feet, "below_floor_tool_u": tool, "target_cube_u": cube})
    print(json.dumps({"engineering_only": True, "production_qualified": False,
                      "timber_prisms": len(parts), "paid_cubes": len(cubes),
                      "natural_bearings": len(source["natural_bearings"]),
                      "constituent_stance_u": stance, "stations": stations}, indent=2))


if __name__ == "__main__":
    main()
