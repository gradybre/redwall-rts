#!/usr/bin/env python3
"""Encode the ten approved stone clips (ADR 1206) as one finite native image; offline, never runtime.

A separate image (source 3), not a v8 extension: the `.ugactor` wire has one fixed part list, the stone is a
different mesh from the wood stock, and v8's twelve clips plus these ten exceed the sixteen-clip limit. Parts are
the current body (24 binds) and the captured procedural stone lump (rigid); every clip shows both (mask 3). The
stand/walk clips stay in v8: `enter_haul_stone` starts from v8's stand key 8 body pose byte for byte.

The v7/v8 compilers are reused unchanged; v8 and its outputs are untouched.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

import numpy as np

import compile_native_program as C

I = C.I
HERE, ROOT = C.HERE, C.ROOT
REVIEW = HERE / "evidence/stone-motion-review-v1/invocation.json"
STONE = HERE / "evidence/stone-source-v1/native-stone.json"
STONE_SHA = "ddcb70bf666021ded1b12741f3a741e25ffb9d37b79ed9c95f71f74dcb091a6e"
# stone-source-v1 JSON numbers lose 16 negative zeros; the fingerprint hashes bits, so v9 reads exact bytes.
BITS = HERE / "evidence/stone-source-v2/native-stone-bits.json"
BITS_SHA = "991948c275ff3e87965229725ef3f77b6997d3fdc87294694fb46d16e5e0c119"
CLIPS = ("approach", "lift", "place", "recovery", "hold", "enter", "carry", "exit",
         "enter_haul_stone", "leave_haul_stone")
COUNTS = (61, 61, 61, 61, 2, 65, 219, 65, 31, 31)
FOLDERS = ("stone-program-v1",) * 4 + ("stone-gait-v1",) * 4 + ("stone-joins-v1",) * 2
LOOPS = tuple(int(name == "carry") for name in CLIPS)
MASKS = (3,) * len(CLIPS)
FRAMES = sum(COUNTS)
STRIDE = 24 * 12 + 12
SCALE = (0.15, 0.12, 0.15)


def clip_path(name: str) -> Path:
    return HERE / "evidence" / FOLDERS[CLIPS.index(name)] / (name + ".npz")


def reviewed_inputs() -> dict:
    """Every approved clip through the motion review's own SHA-256 manifest, plus the stone capture."""
    review = C.read_json(REVIEW)
    I.require(review["production_qualified"] is False and review["adr"] == "1206", "STONE_NATIVE_REVIEW_SCOPE")
    pins = {str(REVIEW.relative_to(ROOT)): C.digest(REVIEW)}
    for name in CLIPS:
        relative = str(clip_path(name).relative_to(ROOT))
        I.require(review["sha256"][relative] == C.digest(clip_path(name)), "STONE_NATIVE_REVIEWED_CLIP")
        pins[relative] = review["sha256"][relative]
    I.require(C.digest(STONE) == STONE_SHA and C.digest(BITS) == BITS_SHA, "STONE_NATIVE_SOURCE")
    pins[str(STONE.relative_to(ROOT))] = STONE_SHA
    pins[str(BITS.relative_to(ROOT))] = BITS_SHA
    I.require(C.digest(C.BASIS) == C.BASIS_SHA, "STONE_NATIVE_BASIS")
    pins[str(C.BASIS.relative_to(ROOT))] = C.BASIS_SHA
    pins[str(Path(__file__).relative_to(ROOT))] = C.digest(Path(__file__))
    return pins


def stone_part() -> dict:
    """The engine ArrayMesh as a rigid attachment: exact float32 vertex bits, native format and AABB.

    The bits must equal stone-source-v1's numbers (the proofs' geometry) value for value, and the Python
    transcript must reproduce the fingerprint the engine computed for the real mesh.
    """
    bits, source = C.read_json(BITS), C.read_json(STONE)
    points = np.frombuffer(bytes.fromhex(bits["points_le_f32_hex"]), dtype="<f4").reshape(-1, 3).copy()
    indices = np.frombuffer(bytes.fromhex(bits["indices_le_i32_hex"]), dtype="<i4")
    aabb = np.frombuffer(bytes.fromhex(bits["aabb_le_f32_hex"]), dtype="<f4")
    I.require(points.shape == (70, 3) and indices.tolist() == source["indices"] and
              np.array_equal(points, np.asarray(source["points"], dtype="<f4")) and
              bits["format"] == source["format"] and bits["vertex_count"] == 70, "STONE_NATIVE_GEOMETRY")
    part = {"binds": 0, "instance_material_override": False, "kind": "attachment", "mesh_resource": "",
            "name": "stone", "surface_formats": [bits["format"]], "surfaces": 1,
            "mesh_aabb": [float(v) for v in aabb],
            "geometry": [{"points": points, "ids": np.zeros((70, 0), dtype=np.uint32),
                          "weights": np.zeros((70, 0), dtype=np.float32)}]}
    I.require(I.CONTENT.geometry_fingerprint(part).hex() == bits["mesh_sha256"], "STONE_NATIVE_MESH_DIGEST")
    return part


def cases_from_sources(body: dict, stone: dict) -> list:
    cases = []
    for name, count, loop in zip(CLIPS, COUNTS, LOOPS):
        case = C.G.load_case(clip_path(name), loop)
        I.require(case["frames"] == count and case["matrices"].shape[1] == 25, "STONE_NATIVE_COUNT")
        case.update(id="haul_handling_v1.stone." + name, geometry=[body, stone])
        cases.append(case)
    I.require(sum(c["frames"] for c in cases) == FRAMES == 657, "STONE_NATIVE_FRAME_CENSUS")
    return cases


def compile_program(palette: Path, grip: Path, out: Path) -> dict:
    I.require(not out.exists() and not out.is_symlink(), "STONE_NATIVE_OUTPUT_EXISTS")
    pins = reviewed_inputs()
    _, body, _, _, _, _, _, _ = I.current_inputs(palette, grip)
    stone = stone_part()
    cases = cases_from_sources(body, stone)
    out.mkdir(parents=True)
    program = {"schema": 1, "production_qualified": False, "quantity_milli": 1000, "item": "stone",
               "mass_g": 5000, "active_tool": None,
               "clips": [{"id": c["id"], "source_sha256": C.digest(clip_path(n)), "frames": c["frames"],
                          "loop": c["source_loop_mode"], "duration_q16": (c["frames"] - 1) * 65536,
                          "part_visibility_mask": mask} for n, c, mask in zip(CLIPS, cases, MASKS)],
               "parts": ["body", "stone"],
               "stone_factory": "bore_dressing.gd::stone_mesh (unit lump), scaled (0.150, 0.120, 0.150) by the "
                                "clip's stock matrix; ADR 1206",
               "source_clock": "presentation sampling only; no hauling speed or work rate",
               "empty_stock": "approach/recovery/join stone is a World fixture, never carried cargo permission",
               "body_sha256": I.BODY, "stone_capture_sha256": STONE_SHA, "stone_bits_sha256": BITS_SHA,
               "stone_array_mesh_sha256": I.CONTENT.geometry_fingerprint(stone).hex()}
    program_sha = C.write_json(out / "program.json", program)
    proof = {"schema": 1, "production_qualified": False,
             "scope": "approved continuous source proofs (stone program, loaded gait, joins); native replay separate",
             "world_basis": {"sha256": C.BASIS_SHA}, "source_sha256": pins}
    proof_sha = C.write_json(out / "proof.json", proof)
    plan = {"schema": 1, "revision": 1, "world_root_bounds_u": C.BOUNDS, "clips": list(CLIPS),
            "part_visibility_masks": list(MASKS), "runtime_admitted": False}
    plan_sha = C.write_json(out / "plan.json", plan)
    wire, budget = I.CONTENT.encode(cases, plan, proof, program_sha, proof_sha, plan_sha)
    I.require(len(wire) == 184 + 2 * 72 + len(CLIPS) * 48 + FRAMES * (STRIDE + 1) * 4 + 8, "STONE_NATIVE_WIRE_CENSUS")
    (out / "stone-handling.ugactor").write_bytes(wire)
    raw = C.BASIS.read_bytes()
    metadata = json.loads(raw[20:20 + struct.unpack_from("<I", raw, 16)[0]])
    report = {"schema": 1, "source_sha256": pins, "source_unchanged": reviewed_inputs() == pins,
              "content_sha256": hashlib.sha256(wire).hexdigest(), "wire_bytes": len(wire),
              "parts": 2, "clips": len(CLIPS), "clip_names": list(CLIPS), "clip_frames": list(COUNTS),
              "part_visibility_masks": list(MASKS), "frames": FRAMES, "scalars": FRAMES * (STRIDE + 1),
              "basis_sha256": C.BASIS_SHA, "basis_producer_sha256": metadata["source"]["sha256"],
              "stone_array_mesh_sha256": program["stone_array_mesh_sha256"],
              "presentation_only_reservation": budget, "production_qualified": False, "runtime_admitted": False}
    I.require(report["source_unchanged"], "STONE_NATIVE_SOURCE_CHANGED")
    C.write_json(out / "compilation.json", report)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    result = compile_program(args.palette, args.grip_palette, args.out)
    print(json.dumps({key: result[key] for key in ("wire_bytes", "frames", "clips", "content_sha256",
                                                    "stone_array_mesh_sha256", "runtime_admitted")}))


if __name__ == "__main__":
    main()
