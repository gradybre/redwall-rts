#!/usr/bin/env python3
"""Measure actual existing mole/cargo source inputs; never emit a profile or a qualification flag."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
PROOF = HERE.parent / "evidence/contact-qualification"
sys.path.insert(0, str(ROOT / "tools"))
import compile_underground_actor_content as CONTENT
import export_underground_envelopes as ENVELOPE

SPEC = importlib.util.spec_from_file_location("handling_source_reader", PROOF / "prove_self_clearance.py")
SOURCE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SOURCE)

PALETTE_SHA = "5b368eb3ad594b4a6f82b5981a891150e6f7053944daf888d4ab5aa293c822fe"
GRIP_SHA = "08de54533d28b1a45a2e171180a0ca68812912f67c9b7294bf26c25eec424cda"
TOPOLOGY_SHA = "da623e5c7c3c5a6aff5c466b143425422f3aa2253497527c84f713738f997b42"
COMPACT_SHA = "f575382e1fdc4b5e20b70254a8c7a5b3ebf6f0256266627dc79d43f3e12dae37"
OLD_BODY = "a938d479014ebd3a431a118a7b1c9f7aa0b522d0a33a5c5d281e58e1e2f497c1"
BODY = "29f8d3218fddfaa6f2369c1c1c7dfd9b0a429b3df5cbefa38c6bf6ab9364fe14"
LOG = "e897ab9a5683d9a79e64fcd0c41286a19114d233e2ec0ceeac0f639e15e22c80"
CASE_IDS = ("mole_digger.idle.plain", "mole_digger.walk.plain",
            "mole_digger.carry_heavy_object_walk.plain")
MAX_PALETTE_BYTES = 64 * 1024 * 1024


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError(code)


def read_selected(path: Path, digest: str, identifiers: tuple[str, ...]) -> tuple[dict, dict]:
    """Exhaust the bounded source so the final whole-file digest is checked, not just selected prefixes."""
    require(path.is_file() and path.stat().st_size <= MAX_PALETTE_BYTES, "HANDLING_PALETTE_CAPACITY")
    selected = {}
    with path.open("rb") as stream:
        reader = ENVELOPE.PaletteSource(stream, digest)
        ENVELOPE.palette_backend_certificate(reader.metadata)
        for case in reader.cases():
            if case["id"] in identifiers:
                require(case["id"] not in selected and case["cast"] == "mole_digger" and
                        case["species"] == "mole" and case["life_stage"] == "adult_presentation_candidate",
                        "HANDLING_CAST_IDENTITY")
                selected[case["id"]] = case
                require(sum(row["frames"] for row in selected.values()) <= 512, "HANDLING_FRAME_CAPACITY")
    require(set(selected) == set(identifiers), "HANDLING_SOURCE_MISSING")
    return selected, reader.metadata


def affine(value: np.ndarray) -> np.ndarray:
    require(value.shape == (12,) and np.all(np.isfinite(value)), "HANDLING_AFFINE")
    result = np.eye(4)
    result[:3, :3] = value[:9].reshape(3, 3).T
    result[:3, 3] = value[9:]
    return result


def points_at(case: dict, part: dict, frame: int, offset: int = 0) -> np.ndarray:
    """Floating source diagnostic only; all actual vertices/influences survive the shared grounding."""
    require(len(part["geometry"]) == 1 and 0 <= frame < case["frames"], "HANDLING_GEOMETRY_CENSUS")
    surface = part["geometry"][0]
    points = surface["points"].astype(np.float64)
    require(0 < len(points) <= CONTENT.MAX_VERTICES, "HANDLING_VERTEX_CAPACITY")
    if part["binds"]:
        ids, weights = surface["ids"], surface["weights"].astype(np.float64)
        require(ids.shape == weights.shape and len(ids) == len(points), "HANDLING_SKIN_CENSUS")
        result = np.zeros_like(points)
        for slot in range(ids.shape[1]):
            palette = case["matrices"][frame, offset + ids[:, slot]]
            basis = palette[:, :9].reshape(-1, 3, 3)
            moved = np.einsum("ni,nij->nj", points, basis) + palette[:, 9:]
            result += moved * weights[:, slot, None]
    else:
        matrix = affine(case["matrices"][frame, offset])
        result = points @ matrix[:3, :3].T + matrix[:3, 3]
    result[:, 1] += float(case["grounding"][frame])
    require(np.all(np.isfinite(result)), "HANDLING_NONFINITE")
    return result * 1024


def box(points: np.ndarray) -> list[float]:
    require(points.ndim == 2 and points.shape[1] == 3 and len(points) > 0, "HANDLING_POINT_SHAPE")
    return np.concatenate((points.min(axis=0), points.max(axis=0))).tolist()


def union(first: list[float] | None, second: list[float]) -> list[float]:
    return second if first is None else [min(first[a], second[a]) for a in range(3)] + \
        [max(first[a], second[a]) for a in range(3, 6)]


def current_inputs(palette: Path, grip: Path) -> tuple:
    """Borrow native motion and the unchanged current body separately; old-body evidence is not transferred."""
    rows, metadata = read_selected(palette, PALETTE_SHA, CASE_IDS)
    chosen = "mole_digger.idle.plain.held_pick.firm_grip_v1"
    grip_rows, grip_metadata = read_selected(grip, GRIP_SHA, (chosen,))
    parts = grip_rows[chosen]["geometry"]
    body, tool = parts
    carry = rows[CASE_IDS[2]]
    log = carry["geometry"][1]
    require(CONTENT.geometry_fingerprint(body).hex() == BODY and
            CONTENT.geometry_fingerprint(log).hex() == LOG and log["name"] == "log", "HANDLING_MESH_IDENTITY")
    for row in rows.values():
        require(CONTENT.geometry_fingerprint(row["geometry"][0]).hex() == OLD_BODY,
                "HANDLING_ORIGINAL_BODY_IDENTITY")
    topology = CONTENT.read_json(PROOF / "topology-v5/topology.json", TOPOLOGY_SHA, 8 * 1024 * 1024)
    require(topology["derived_body_sha256"] == BODY and len(topology["rig_binding"]["bones"]) == 24,
            "HANDLING_CURRENT_TOPOLOGY")
    compact = SOURCE.read_image(PROOF / "compact-program-compile-v2/result/mole-worker.ugactor", COMPACT_SHA, parts)
    return rows, body, log, tool, topology, compact, metadata, grip_metadata


def measure(palette: Path, grip: Path) -> dict:
    rows, body, log, tool, topology, compact, metadata, grip_metadata = current_inputs(palette, grip)
    geometry = body["geometry"][0]
    original = rows[CASE_IDS[0]]["geometry"][0]["geometry"][0]
    require(np.array_equal(geometry["points"], original["points"]), "HANDLING_CURRENT_POSITIONS_CHANGED")
    triangles = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int64).reshape(-1, 3)
    require(triangles.shape == (10209, 3) and np.all((triangles >= 0) & (triangles < len(geometry["points"]))),
            "HANDLING_TRIANGLE_CENSUS")
    influenced = np.any(np.isin(geometry["ids"], [3, 4, 7, 8]) & (geometry["weights"] > 0), axis=1)
    feet = np.unique(triangles[np.any(influenced[triangles], axis=1)])
    results = []
    for name, row in rows.items():
        body_box = foot_box = cargo_box = None
        for frame in range(row["frames"]):
            current = points_at(row, body, frame)
            body_box = union(body_box, box(current))
            foot_box = union(foot_box, box(current[feet]))
            if name == CASE_IDS[2]:
                cargo_box = union(cargo_box, box(points_at(row, log, frame, 24)))
        results.append({"id": name, "frames": row["frames"], "source_duration_s": row["source_duration_s"],
                        "sampled_current_body_u": body_box, "sampled_complete_foot_triangles_u": foot_box,
                        "sampled_cargo_u": cargo_box,
                        "first_last_palette_equal": row["matrices"][0].tobytes() == row["matrices"][-1].tobytes()})
    ready = compact[0]
    bones = topology["rig_binding"]["bones"]
    joints = []
    for index in (9, 12, 13, 14, 15, 16, 17, 18, 19):
        matrix = affine(ready["matrices"][8, index]) @ np.linalg.inv(affine(np.asarray(bones[index]["inverse_bind"])))
        joint = matrix[:3, 3] + [0, float(ready["grounding"][8]), 0]
        joints.append({"bone": index, "name": bones[index]["name"], "ready_u": (joint * 1024).tolist()})
    changed = np.any(geometry["ids"] != original["ids"], axis=1) | np.any(geometry["weights"] != original["weights"], axis=1)
    return {"schema": 1, "status": "AUTHORING_DIAGNOSTIC_ONLY", "production_qualified": False,
            "source_palette_sha256": PALETTE_SHA, "current_mesh_palette_sha256": GRIP_SHA,
            "current_body_mesh_sha256": BODY, "original_body_mesh_sha256": OLD_BODY,
            "wood_mesh_sha256": LOG, "body_vertices": len(geometry["points"]), "body_triangles": len(triangles),
            "wood_vertices": len(log["geometry"][0]["points"]), "current_weight_changed_vertices": int(changed.sum()),
            "body_positions_unchanged": True, "whole_foot_vertices": len(feet), "clips": results,
            "compact_ready_joints": joints, "compact_source_sha256": COMPACT_SHA,
            "source_metadata_sha256": hashlib.sha256(json.dumps(metadata, sort_keys=True).encode()).hexdigest(),
            "current_metadata_sha256": hashlib.sha256(json.dumps(grip_metadata, sort_keys=True).encode()).hexdigest(),
            "limitations": ["Sampled floats are authoring diagnostics, not outward continuous bounds.",
                            "Current body weights differ from original native capture; complete new proof is required.",
                            "No hand/cargo contact, complete join, support, quantity variant, native or runtime permission is granted."]}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    require(not args.out.exists() and not args.out.is_symlink(), "HANDLING_OUTPUT_EXISTS")
    report = measure(args.palette, args.grip_palette)
    paths = [Path(__file__), Path(CONTENT.__file__), Path(ENVELOPE.__file__), Path(SOURCE.__file__),
             Path(SOURCE.P.__file__), PROOF / "topology-v5/topology.json"]
    report["producer_sources"] = {str(path.relative_to(ROOT)): CONTENT.file_hash(path) for path in paths}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"output": str(args.out), "body_vertices": report["body_vertices"],
                      "body_triangles": report["body_triangles"], "wood_vertices": report["wood_vertices"],
                      "production_qualified": False}))


if __name__ == "__main__":
    main()
