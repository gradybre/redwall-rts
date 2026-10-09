#!/usr/bin/env python3
"""Independently compare the v8 native capture (12 clips) with complete reviewed haul and tool-free geometry.

The v7 verifier's independent equations (World matrix, skinning, exact rational hand witness)
are reused unchanged; only the clip table, loop set, part masks and joins are v8's.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct

import numpy as np

import compile_native_program_v8 as C8
import verify_native_program as V

C, N = V.C, V.N
HERE, ROOT = C.HERE, C.ROOT
INTS, FLOATS, ROW_BYTES, DTYPE = V.INTS, V.FLOATS, V.ROW_BYTES, V.DTYPE
COUNTS, MASKS, LOOPS = C8.COUNTS, C8.MASKS, C8.LOOPS
ROWS = 3 * sum(4 * (n - 1) + 1 for n in COUNTS)
STAND, WALK, ENTER_HAUL, LEAVE_HAUL = (C8.CLIPS.index(n) for n in C8.TOOL_FREE)
READY = 8  # author_empty_walk.READY_FRAME: the stand key both joins meet.
CONTACT = (1, 2, 4, 5, 6, 7)  # lift, place, hold, enter, carry, exit; plus approach end and recovery start.


def capture(path: Path) -> np.ndarray:
    expected = 16 + ROWS * ROW_BYTES
    C.I.require(path.is_file() and not path.is_symlink() and path.stat().st_size == expected,
                "HAUL_NATIVE_CAPTURE_CAPACITY")
    with path.open("rb") as stream:
        raw = stream.read(expected + 1)
    C.I.require(len(raw) == expected and raw[:8] == b"UGHNAT01" and
                struct.unpack_from("<II", raw, 8) == (INTS, FLOATS), "HAUL_NATIVE_CAPTURE_HEADER")
    rows = np.frombuffer(raw, dtype=DTYPE, count=ROWS, offset=16)
    C.I.require(np.all(np.isfinite(rows["values"])), "HAUL_NATIVE_CAPTURE_NONFINITE")
    return rows


def chosen(clip: int, elapsed: int) -> tuple:
    """Independent restatement of Content.clip_into for a whole-key Q16 duration."""
    C.I.require(type(clip) is int and 0 <= clip < len(COUNTS), "HAUL_NATIVE_CLOCK")
    count = COUNTS[clip]
    duration = (count - 1) * 65536
    C.I.require(type(elapsed) is int and 0 <= elapsed <= duration, "HAUL_NATIVE_CLOCK")
    time = elapsed % duration if LOOPS[clip] else elapsed
    first = sum(COUNTS[:clip])
    at, share = divmod(time, 65536)
    after = min(at + 1, count - 1)
    if LOOPS[clip] and at == count - 2:
        after = 0
    if time == duration:
        after = at
    return first + at, first + after, share


def source_sample(case: dict, clip: int, elapsed: int) -> tuple:
    a, b, share = chosen(clip, elapsed)
    first = sum(COUNTS[:clip])
    t = share / 65536
    pose = case["matrices"][a - first].astype(np.float64) * (1 - t) + case["matrices"][b - first].astype(np.float64) * t
    ground = float(case["grounding"][a - first]) * (1 - t) + float(case["grounding"][b - first]) * t
    return pose, ground


def row_refusal(row, view_index: int, clip: int, elapsed: int, case: dict, pair: np.ndarray) -> tuple:
    view = N.VIEWS[view_index]
    meta = [view_index, clip, elapsed, *chosen(clip, elapsed), view["yaw"], MASKS[clip]]
    C.I.require(row["meta"].tolist() == meta, "HAUL_NATIVE_EVENT")
    pose, ground = source_sample(case, clip, elapsed)
    C.I.require(np.array_equal(row["values"], V.expected_values(pose, ground, view, pair)), "HAUL_NATIVE_COEFFICIENT")
    return pose, ground


def join_refusal(rows: np.ndarray) -> dict:
    """v7's nine joins and three reversals, plus the four tool-free joins and their reversal."""
    table = {(int(row["meta"][0]), int(row["meta"][1]), int(row["meta"][2])): row["values"] for row in rows}
    end = lambda clip: (COUNTS[clip] - 1) * 65536
    joins = [(0, 1), (1, 4), (4, 5), (5, 6), (6, 7), (7, 4), (4, 2), (2, 3), (3, 0)]
    for view in range(3):
        for a, b in joins:
            C.I.require(np.array_equal(table[view, a, end(a)], table[view, b, 0]), "HAUL_NATIVE_JOIN")
        for a, at, b, bt in ((STAND, READY * 65536, ENTER_HAUL, 0), (ENTER_HAUL, end(ENTER_HAUL), 0, 0),
                             (3, end(3), LEAVE_HAUL, 0), (LEAVE_HAUL, end(LEAVE_HAUL), STAND, READY * 65536)):
            C.I.require(np.array_equal(table[view, a, at], table[view, b, bt]), "HAUL_NATIVE_JOIN")
        for a, b in ((0, 3), (1, 2), (5, 7), (ENTER_HAUL, LEAVE_HAUL)):
            for elapsed in range(0, end(a) + 1, 16384):
                C.I.require(np.array_equal(table[view, a, elapsed], table[view, b, end(a) - elapsed]),
                            "HAUL_NATIVE_REVERSAL")
    return {"exact_joins_per_view": len(joins) + 4, "exact_reversal_pairs_per_view": 4, "views": 3}


def part_error(part: dict, part_index: int, pose: np.ndarray, ground: float, actual: np.ndarray,
               view: dict, coefficients: np.ndarray) -> tuple:
    start, size = ((0, 24), (24, 1))[part_index]
    source_points = V.skin(part, pose[start:start + size])
    source_points[:, 1] += ground
    c, s = map(float, coefficients)
    ideal = source_points.copy()
    ideal[:, 0] = c * source_points[:, 0] + s * source_points[:, 2]
    ideal[:, 2] = -s * source_points[:, 0] + c * source_points[:, 2]
    ideal += np.asarray(view["root_u"]) / 1024
    if part_index == 0:
        observed = V.transformed(V.skin(part, actual[:288].reshape(24, 12)), actual[300:312].astype(np.float64))
    else:
        observed = V.skin(part, actual[288:300].reshape(1, 12))
    return float(np.max(np.abs(observed - ideal))) * 1024, float(observed[:, 1].min()) * 1024 - view["root_u"][1]


def verify(folder: Path, palette: Path, grip: Path) -> dict:
    report, spec = C.read_json(folder / "report.json"), C.read_json(folder / "spec.json")
    compiled = C.read_json(folder / "compiled/compilation.json")
    C.I.require(report["production_qualified"] is False and report["runtime_admitted"] is False and report["failures"] == []
                and report["rows"] == ROWS and report["assertions"] >= 4 * ROWS
                and report["content_sha256"] == compiled["content_sha256"] == spec["content_sha256"]
                and report["basis_sha256"] == C.BASIS_SHA and spec["views"] == N.VIEWS
                and spec["part_masks"] == list(MASKS) == compiled["part_visibility_masks"]
                and compiled["clip_names"] == list(C8.CLIPS) and compiled["clip_frames"] == list(COUNTS),
                "HAUL_NATIVE_REPORT")
    C.I.require(report["rendering_driver"] == "metal" and report["rendering_method"] == "forward_plus" and
                report["display_server"] == "macOS" and report["api_version"] == "4.0" and
                report["user_directory"].endswith("/" + N.USER), "HAUL_NATIVE_BACKEND")
    _, body, wood, _, _, _, _, _ = C.I.current_inputs(palette, grip)
    cases = C8.cases_from_sources(body, C.wrapped_stock(wood))
    rows = capture(folder / "native.bin")
    raw = C.BASIS.read_bytes()
    count = struct.unpack_from("<I", raw, 16)[0]
    basis = np.frombuffer(raw, dtype="<f4", count=65536 * 2, offset=20 + count).reshape(-1, 2)
    witnesses = C.read_json(HERE / "evidence/static-contact-review-v1/static-contact.json")["static_source"]["hand_contact_witnesses"]
    maxima, floors, hidden_floor, contacts, at = [0.0, 0.0], [float("inf")] * 2, float("inf"), 0, 0
    for view_index, view in enumerate(N.VIEWS):
        for clip, case in enumerate(cases):
            duration = (case["frames"] - 1) * 65536
            for elapsed in range(0, duration + 1, 16384):
                row = rows[at]
                pose, ground = row_refusal(row, view_index, clip, elapsed, case, basis[view["yaw"]])
                for part_index, part in enumerate((body, wood)):
                    error, floor = part_error(part, part_index, pose, ground, row["values"], view, basis[view["yaw"]])
                    maxima[part_index] = max(maxima[part_index], error)
                    if MASKS[clip] & (1 << part_index):
                        floors[part_index] = min(floors[part_index], floor)
                    else:
                        hidden_floor = min(hidden_floor, floor)
                if clip in CONTACT or clip == 0 and elapsed == duration or clip == 3 and elapsed == 0:
                    C.I.require(V.hand_contacts(row["values"], body, wood, witnesses), "HAUL_NATIVE_HAND_CONTACT")
                    contacts += 2
                at += 1
    C.I.require(at == ROWS and min(floors) >= 0, "HAUL_NATIVE_FLOOR")
    return {"schema": 1, "rows": ROWS, "clips": list(C8.CLIPS), "clip_frames": list(COUNTS),
            "part_visibility_masks": list(MASKS), "native_visibility_rows_checked": ROWS,
            "complete_vertices_per_row": [17172, 522], "complete_triangles": [10209, 768],
            "coefficient_mismatches": 0, "max_source_to_native_input_vertex_error_u": maxima,
            "minimum_visible_floor_gap_u": {"body": floors[0], "stock": floors[1]},
            "hidden_stock_minimum_height_u": hidden_floor,
            "exact_rational_two_hand_witnesses": contacts, "joins": join_refusal(rows),
            "native_capture_sha256": C.digest(folder / "native.bin"), "production_qualified": False,
            "runtime_admitted": False,
            "scope": "Actual native registered matrix inputs at all keys and quarter intervals, and the actual native "
            "MeshInstance visibility of both parts at every row. Exact rational hand intersections use those "
            "coefficients; complete vertex reconstruction uses binary64. The hidden stand/walk stock coefficient "
            "is the S fixture value; it is neither rendered nor a physical claim, so it is excluded from the floor "
            "proof and reported separately. GPU shader roundoff and unsampled Q16 times are not certified. "
            "No finite World support/traversal, loaded turns, foot sliding/root advance or gameplay timing is granted."}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "capture", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    C.I.require(not args.out.exists() and not args.out.is_symlink(), "HAUL_NATIVE_OUTPUT_EXISTS")
    result = verify(args.capture, args.palette, args.grip_palette)
    C.write_json(args.out, result)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
