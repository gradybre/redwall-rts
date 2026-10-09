#!/usr/bin/env python3
"""Independently compare actual native coefficients with complete reviewed haul geometry."""
from __future__ import annotations

import argparse
from fractions import Fraction as F
import json
from pathlib import Path
import struct

import numpy as np

import compile_native_program as C
import prove_static_contact as S
import run_native_program as N

HERE, ROOT = C.HERE, C.ROOT
INTS, FLOATS = 8, 314
ROW_BYTES = 4 * (INTS + FLOATS)
ROWS = 3 * sum(4 * (n - 1) + 1 for n in C.COUNTS)
DTYPE = np.dtype([("meta", "<i4", (INTS,)), ("values", "<f4", (FLOATS,))])


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
    C.I.require(type(clip) is int and 0 <= clip < 8, "HAUL_NATIVE_CLOCK")
    count = C.COUNTS[clip]
    duration = (count - 1) * 65536
    C.I.require(type(elapsed) is int and 0 <= elapsed <= duration, "HAUL_NATIVE_CLOCK")
    time = elapsed % duration if clip == 6 else elapsed
    first = sum(C.COUNTS[:clip])
    at, share = divmod(time, 65536)
    after = min(at + 1, count - 1)
    if clip == 6 and at == count - 2:
        after = 0
    if time == duration:
        after = at
    return first + at, first + after, share


def source_sample(case: dict, clip: int, elapsed: int) -> tuple:
    a, b, share = chosen(clip, elapsed)
    first = sum(C.COUNTS[:clip])
    t = share / 65536
    pose = case["matrices"][a - first].astype(np.float64) * (1 - t) + case["matrices"][b - first].astype(np.float64) * t
    ground = float(case["grounding"][a - first]) * (1 - t) + float(case["grounding"][b - first]) * t
    return pose, ground


def world_matrix(local: np.ndarray, grounding: float, root: list, c: float, s: float) -> np.ndarray:
    # Independent scalar equation; unlike Actor, this verifier does not call its helper.
    matrix = local.reshape(4, 3).astype(np.float64)
    result = matrix.copy()
    result[:, 0] = c * matrix[:, 0] + s * matrix[:, 2]
    result[:, 2] = -s * matrix[:, 0] + c * matrix[:, 2]
    result[3] += np.asarray(root, dtype=np.float64) / 1024
    result[3, 1] += grounding
    return result.reshape(12).astype("<f4")


def expected_values(pose: np.ndarray, ground: float, view: dict, pair: np.ndarray) -> np.ndarray:
    stored, grounding = pose.astype("<f4"), float(np.float32(ground))
    identity = np.asarray([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0], dtype="<f4")
    c, s = map(float, pair)
    return np.concatenate((stored[:24].reshape(-1), world_matrix(stored[24], grounding, view["root_u"], c, s),
                           world_matrix(identity, grounding, view["root_u"], c, s), pair)).astype("<f4")


def row_refusal(row, view_index: int, clip: int, elapsed: int, case: dict, pair: np.ndarray) -> tuple:
    view = N.VIEWS[view_index]
    meta = [view_index, clip, elapsed, *chosen(clip, elapsed), view["yaw"], 0]
    C.I.require(row["meta"].tolist() == meta, "HAUL_NATIVE_EVENT")
    pose, ground = source_sample(case, clip, elapsed)
    C.I.require(np.array_equal(row["values"], expected_values(pose, ground, view, pair)), "HAUL_NATIVE_COEFFICIENT")
    return pose, ground


def skin(part: dict, pose: np.ndarray) -> np.ndarray:
    surface = part["geometry"][0]
    points = surface["points"].astype(np.float64)
    if not part["binds"]:
        return points @ pose[0, :9].reshape(3, 3) + pose[0, 9:]
    result = np.zeros_like(points)
    ids, weights = surface["ids"], surface["weights"]
    for at in range(weights.shape[1]):
        matrix = pose[ids[:, at]]
        result += (np.einsum("ni,nij->nj", points, matrix[:, :9].reshape(-1, 3, 3)) + matrix[:, 9:]) * weights[:, at, None]
    return result


def transformed(points: np.ndarray, matrix: np.ndarray) -> np.ndarray:
    return points @ matrix[:9].reshape(3, 3) + matrix[9:]


def exact_point(part: dict, pose: np.ndarray, index: int, world: np.ndarray | None) -> tuple:
    surface = part["geometry"][0]
    point = tuple(F(float(v)) for v in surface["points"][index])
    values = [F(0), F(0), F(0)]
    influences = zip(surface["ids"][index], surface["weights"][index]) if part["binds"] else ((0, 1),)
    for bone, weight in influences:
        if not weight:
            continue
        matrix = tuple(F(float(v)) for v in pose[int(bone)])
        for axis in range(3):
            values[axis] += F(float(weight)) * (matrix[9 + axis] + sum(matrix[3 * col + axis] * point[col] for col in range(3)))
    if world is not None:
        matrix = tuple(F(float(v)) for v in world)
        values = [matrix[9 + a] + sum(matrix[3 * c + a] * values[c] for c in range(3)) for a in range(3)]
    return tuple(v * 1024 for v in values)


def hand_contacts(values: np.ndarray, body: dict, wood: dict, pairs: list) -> bool:
    body_pose, stock, world = values[:288].reshape(24, 12), values[288:300].reshape(1, 12), values[300:312]
    for pair in pairs:
        first = [exact_point(body, body_pose, at, world) for at in pair["body_vertices"]]
        second = [exact_point(wood, stock, at, None) for at in pair["wood_vertices"]]
        if S.edge_witness(first, second) is None:
            return False
    return True


def join_refusal(rows: np.ndarray) -> dict:
    table = {(int(row["meta"][0]), int(row["meta"][1]), int(row["meta"][2])): row["values"] for row in rows}
    joins = [(0, 1), (1, 4), (4, 5), (5, 6), (6, 7), (7, 4), (4, 2), (2, 3), (3, 0)]
    for view in range(3):
        for a, b in joins:
            C.I.require(np.array_equal(table[view, a, (C.COUNTS[a] - 1) * 65536], table[view, b, 0]),
                        "HAUL_NATIVE_JOIN")
        for a, b in ((0, 3), (1, 2), (5, 7)):
            duration = (C.COUNTS[a] - 1) * 65536
            for elapsed in range(0, duration + 1, 16384):
                C.I.require(np.array_equal(table[view, a, elapsed], table[view, b, duration - elapsed]),
                            "HAUL_NATIVE_REVERSAL")
    return {"exact_joins_per_view": len(joins), "exact_reversal_pairs_per_view": 3, "views": 3}


def verify(folder: Path, palette: Path, grip: Path) -> dict:
    report, spec = C.read_json(folder / "report.json"), C.read_json(folder / "spec.json")
    compiled = C.read_json(folder / "compiled/compilation.json")
    C.I.require(report["production_qualified"] is False and report["runtime_admitted"] is False and report["failures"] == []
                and report["rows"] == ROWS and report["assertions"] >= 3 * ROWS
                and report["content_sha256"] == compiled["content_sha256"] == spec["content_sha256"]
                and report["basis_sha256"] == C.BASIS_SHA and spec["views"] == N.VIEWS, "HAUL_NATIVE_REPORT")
    C.I.require(report["rendering_driver"] == "metal" and report["rendering_method"] == "forward_plus" and
                report["display_server"] == "macOS" and report["api_version"] == "4.0" and
                report["user_directory"].endswith("/" + N.USER), "HAUL_NATIVE_BACKEND")
    _, body, wood, _, topology, _, _, _ = C.I.current_inputs(palette, grip)
    cases = C.cases_from_review(body, wood)
    rows = capture(folder / "native.bin")
    raw = C.BASIS.read_bytes()
    count = struct.unpack_from("<I", raw, 16)[0]
    basis = np.frombuffer(raw, dtype="<f4", count=65536 * 2, offset=20 + count).reshape(-1, 2)
    witnesses = C.read_json(HERE / "evidence/static-contact-review-v1/static-contact.json")["static_source"]["hand_contact_witnesses"]
    maxima, minimum_floor, contacts, at = [0.0, 0.0], float("inf"), 0, 0
    for view_index, view in enumerate(N.VIEWS):
        coefficients = basis[view["yaw"]]
        for clip, case in enumerate(cases):
            duration = (case["frames"] - 1) * 65536
            for elapsed in range(0, duration + 1, 16384):
                row = rows[at]
                pose, ground = row_refusal(row, view_index, clip, elapsed, case, coefficients)
                actual = row["values"]
                for part_index, (part, start, size) in enumerate(((body, 0, 24), (wood, 24, 1))):
                    source_points = skin(part, pose[start:start + size])
                    source_points[:, 1] += ground
                    c, s = map(float, coefficients)
                    ideal = source_points.copy()
                    ideal[:, 0] = c * source_points[:, 0] + s * source_points[:, 2]
                    ideal[:, 2] = -s * source_points[:, 0] + c * source_points[:, 2]
                    ideal += np.asarray(view["root_u"]) / 1024
                    observed = skin(part, actual[:288].reshape(24, 12)) if part_index == 0 \
                        else skin(part, actual[288:300].reshape(1, 12))
                    if part_index == 0:
                        observed = transformed(observed, actual[300:312].astype(np.float64))
                    maxima[part_index] = max(maxima[part_index], float(np.max(np.abs(observed - ideal))) * 1024)
                    minimum_floor = min(minimum_floor, float(observed[:, 1].min()) * 1024 - view["root_u"][1])
                contact = clip in (1, 2, 4, 5, 6, 7) or clip == 0 and elapsed == duration or clip == 3 and elapsed == 0
                if contact:
                    C.I.require(hand_contacts(actual, body, wood, witnesses), "HAUL_NATIVE_HAND_CONTACT")
                    contacts += 2
                at += 1
    C.I.require(at == ROWS and minimum_floor >= 0, "HAUL_NATIVE_FLOOR")
    return {"schema": 1, "rows": ROWS, "complete_vertices_per_row": [17172, 522],
            "complete_triangles": [10209, 768], "coefficient_mismatches": 0,
            "max_source_to_native_input_vertex_error_u": maxima, "minimum_floor_gap_u": minimum_floor,
            "exact_rational_two_hand_witnesses": contacts, "joins": join_refusal(rows),
            "native_capture_sha256": C.digest(folder / "native.bin"), "production_qualified": False,
            "runtime_admitted": False, "scope": "Actual native registered matrix inputs at all keys and quarter intervals. "
            "Exact rational hand intersections use those coefficients; complete vertex reconstruction uses binary64. "
            "GPU shader roundoff and unsampled Q16 times are not certified by this sampled witness. "
            "No finite World support/traversal, loaded turns, empty-ground handoff or gameplay timing is granted."}


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
