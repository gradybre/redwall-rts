#!/usr/bin/env python3
"""Independently compare the v9 native capture (ten stone clips, ADR 1206) with the approved stone geometry.

The v7 verifier's independent equations (World matrix, skinning, exact rational hand witness) are reused
unchanged. v9 adds the stone's own clip table, joins and reversals, and one cross-image join: the stone image's
`enter_haul_stone` key 0 body coefficients equal v8's native `stand` key 8 body coefficients in every view.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct

import numpy as np

import compile_native_program_v9 as C9
import verify_native_program as V
import verify_native_program_v8 as V8

C, N = V.C, V.N
HERE, ROOT = C.HERE, C.ROOT
INTS, FLOATS, ROW_BYTES, DTYPE = V.INTS, V.FLOATS, V.ROW_BYTES, V.DTYPE
COUNTS, MASKS, LOOPS = C9.COUNTS, C9.MASKS, C9.LOOPS
ROWS = 3 * sum(4 * (n - 1) + 1 for n in COUNTS)
ENTER, LEAVE = C9.CLIPS.index("enter_haul_stone"), C9.CLIPS.index("leave_haul_stone")
CONTACT = (1, 2, 4, 5, 6, 7)
WITNESSES = HERE / "evidence/stone-contact-v1/static-contact.json"
V8_CAPTURE = HERE / "evidence/native-program-v8/native.bin"


def capture(path: Path, rows: int = ROWS) -> np.ndarray:
    expected = 16 + rows * ROW_BYTES
    C.I.require(path.is_file() and not path.is_symlink() and path.stat().st_size == expected,
                "STONE_NATIVE_CAPTURE_CAPACITY")
    with path.open("rb") as stream:
        raw = stream.read(expected + 1)
    C.I.require(len(raw) == expected and raw[:8] == b"UGHNAT01" and
                struct.unpack_from("<II", raw, 8) == (INTS, FLOATS), "STONE_NATIVE_CAPTURE_HEADER")
    result = np.frombuffer(raw, dtype=DTYPE, count=rows, offset=16)
    C.I.require(np.all(np.isfinite(result["values"])), "STONE_NATIVE_CAPTURE_NONFINITE")
    return result


def chosen(clip: int, elapsed: int) -> tuple:
    """Independent restatement of Content.clip_into for a whole-key Q16 duration."""
    C.I.require(type(clip) is int and 0 <= clip < len(COUNTS), "STONE_NATIVE_CLOCK")
    count = COUNTS[clip]
    duration = (count - 1) * 65536
    C.I.require(type(elapsed) is int and 0 <= elapsed <= duration, "STONE_NATIVE_CLOCK")
    time = elapsed % duration if LOOPS[clip] else elapsed
    first = sum(COUNTS[:clip])
    at, share = divmod(time, 65536)
    after = min(at + 1, count - 1)
    if LOOPS[clip] and at == count - 2:
        after = 0
    if time == duration:
        after = at
    return first + at, first + after, share


def row_refusal(row, view_index: int, clip: int, elapsed: int, case: dict, pair: np.ndarray) -> tuple:
    view = N.VIEWS[view_index]
    meta = [view_index, clip, elapsed, *chosen(clip, elapsed), view["yaw"], MASKS[clip]]
    C.I.require(row["meta"].tolist() == meta, "STONE_NATIVE_EVENT")
    a, b, share = chosen(clip, elapsed)
    first, t = sum(COUNTS[:clip]), share / 65536
    pose = case["matrices"][a - first].astype(np.float64) * (1 - t) + case["matrices"][b - first].astype(np.float64) * t
    ground = float(case["grounding"][a - first]) * (1 - t) + float(case["grounding"][b - first]) * t
    C.I.require(np.array_equal(row["values"], V.expected_values(pose, ground, view, pair)), "STONE_NATIVE_COEFFICIENT")
    return pose, ground


def join_refusal(rows: np.ndarray) -> dict:
    table = {(int(row["meta"][0]), int(row["meta"][1]), int(row["meta"][2])): row["values"] for row in rows}
    end = lambda clip: (COUNTS[clip] - 1) * 65536
    joins = [(0, 1), (1, 4), (4, 5), (5, 6), (6, 7), (7, 4), (4, 2), (2, 3), (3, 0), (ENTER, 0), (3, LEAVE)]
    for view in range(3):
        for a, b in joins:
            C.I.require(np.array_equal(table[view, a, end(a)], table[view, b, 0]), "STONE_NATIVE_JOIN")
        for a, b in ((0, 3), (1, 2), (5, 7), (ENTER, LEAVE)):
            for elapsed in range(0, end(a) + 1, 16384):
                C.I.require(np.array_equal(table[view, a, elapsed], table[view, b, end(a) - elapsed]),
                            "STONE_NATIVE_REVERSAL")
    return {"exact_joins_per_view": len(joins), "exact_reversal_pairs_per_view": 4, "views": 3}


def stand_join(rows: np.ndarray) -> dict:
    """v8's native stand@8 and v9's enter_haul_stone@0: identical body and World coefficients per view."""
    v8 = capture(V8_CAPTURE, V8.ROWS)
    stand = {(int(r["meta"][0]), int(r["meta"][1]), int(r["meta"][2])): r["values"] for r in v8}
    mine = {(int(r["meta"][0]), int(r["meta"][1]), int(r["meta"][2])): r["values"] for r in rows}
    for view in range(3):
        a, b = stand[view, V8.STAND, V8.READY * 65536], mine[view, ENTER, 0]
        C.I.require(np.array_equal(a[:288], b[:288]) and np.array_equal(a[300:], b[300:]), "STONE_NATIVE_STAND_JOIN")
    return {"cross_image_stand_joins": 3, "v8_capture_sha256": C.digest(V8_CAPTURE),
            "compared": "body bone coefficients, body World transform and basis coefficients; the stock column differs by image"}


def verify(folder: Path, palette: Path, grip: Path) -> dict:
    report, spec = C.read_json(folder / "report.json"), C.read_json(folder / "spec.json")
    compiled = C.read_json(folder / "compiled/compilation.json")
    C.I.require(report["production_qualified"] is False and report["runtime_admitted"] is False and report["failures"] == []
                and report["rows"] == ROWS and report["assertions"] >= 4 * ROWS
                and report["content_sha256"] == compiled["content_sha256"] == spec["content_sha256"]
                and report["basis_sha256"] == C.BASIS_SHA and spec["views"] == N.VIEWS
                and spec["part_masks"] == list(MASKS) == compiled["part_visibility_masks"]
                and compiled["clip_names"] == list(C9.CLIPS) and compiled["clip_frames"] == list(COUNTS),
                "STONE_NATIVE_REPORT")
    C.I.require(report["rendering_driver"] == "metal" and report["rendering_method"] == "forward_plus" and
                report["display_server"] == "macOS" and report["api_version"] == "4.0" and
                report["user_directory"].endswith("/" + N.USER), "STONE_NATIVE_BACKEND")
    _, body, _, _, _, _, _, _ = C.I.current_inputs(palette, grip)
    stone = C9.stone_part()
    cases = C9.cases_from_sources(body, stone)
    rows = capture(folder / "native.bin")
    raw = C.BASIS.read_bytes()
    count = struct.unpack_from("<I", raw, 16)[0]
    basis = np.frombuffer(raw, dtype="<f4", count=65536 * 2, offset=20 + count).reshape(-1, 2)
    witnesses = C.read_json(WITNESSES)["static_source"]["hand_contact_witnesses"]
    maxima, floors, contacts, at = [0.0, 0.0], [float("inf")] * 2, 0, 0
    for view_index, view in enumerate(N.VIEWS):
        for clip, case in enumerate(cases):
            duration = (case["frames"] - 1) * 65536
            for elapsed in range(0, duration + 1, 16384):
                row = rows[at]
                pose, ground = row_refusal(row, view_index, clip, elapsed, case, basis[view["yaw"]])
                for part_index, part in enumerate((body, stone)):
                    error, floor = V8.part_error(part, part_index, pose, ground, row["values"], view, basis[view["yaw"]])
                    maxima[part_index] = max(maxima[part_index], error)
                    floors[part_index] = min(floors[part_index], floor)
                if clip in CONTACT or clip == 0 and elapsed == duration or clip == 3 and elapsed == 0:
                    C.I.require(V.hand_contacts(row["values"], body, stone, witnesses), "STONE_NATIVE_HAND_CONTACT")
                    contacts += 2
                at += 1
    C.I.require(at == ROWS and min(floors) >= 0, "STONE_NATIVE_FLOOR")
    return {"schema": 1, "adr": "1206", "rows": ROWS, "clips": list(C9.CLIPS), "clip_frames": list(COUNTS),
            "part_visibility_masks": list(MASKS), "native_visibility_rows_checked": ROWS,
            "complete_vertices_per_row": [17172, 70], "complete_triangles": [10209, 108],
            "coefficient_mismatches": 0, "max_source_to_native_input_vertex_error_u": maxima,
            "minimum_visible_floor_gap_u": {"body": floors[0], "stone": floors[1]},
            "exact_rational_two_hand_witnesses": contacts, "joins": join_refusal(rows), "stand_join": stand_join(rows),
            "native_capture_sha256": C.digest(folder / "native.bin"), "production_qualified": False,
            "runtime_admitted": False,
            "scope": "Actual native registered matrix inputs at all keys and quarter intervals, and the actual native "
            "MeshInstance visibility of both parts at every row. Exact rational hand intersections use those "
            "coefficients; complete vertex reconstruction uses binary64. GPU shader roundoff and unsampled Q16 times "
            "are not certified. No finite World support/traversal, loaded turns, foot sliding/root advance or "
            "gameplay timing is granted."}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "capture", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    C.I.require(not args.out.exists() and not args.out.is_symlink(), "STONE_NATIVE_OUTPUT_EXISTS")
    result = verify(args.capture, args.palette, args.grip_palette)
    C.write_json(args.out, result)
    print(json.dumps({k: v for k, v in result.items() if k != "scope"}, indent=1))


if __name__ == "__main__":
    main()
