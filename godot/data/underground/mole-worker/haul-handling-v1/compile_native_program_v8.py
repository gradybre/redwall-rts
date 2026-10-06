#!/usr/bin/env python3
"""Encode the eight reviewed haul clips plus the four tool-free clips (ADR 1198 step 4a); offline, never runtime.

The finite `.ugactor` wire has one fixed part list and a uniform per-frame stride, so every
frame carries one transform for every part. It has no per-clip part-presence field. Part
presence is the Actor's existing per-instance mask (`Actor.set_parts_visible`, "Actual
Gear/Haul presentation chooses parts"). The tool-free `stand` and `walk` clips therefore keep
the stock part's coefficient at the exact S fixture transform the approach/joins already
display, and the plan binds a per-clip visibility mask (body only) into the image digest.
No stock geometry is moved, scaled, collapsed or invented; the hidden coefficient is the
fixture's own existing value, so joins stay byte-exact across the whole row.

The v7 compiler (`compile_native_program.py`) is reused unchanged and remains its own
reproduction.
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import io
import json
from pathlib import Path
import struct

import numpy as np

import compile_native_program as C

I = C.I
HERE, ROOT = C.HERE, C.ROOT
EMPTY = HERE / "evidence/empty-walk-v1"
TOOL_FREE = ("stand", "walk", "enter_haul", "leave_haul")
CLIPS = C.CLIPS + TOOL_FREE
COUNTS = C.COUNTS + (122, 45, 31, 31)
LOOPS = tuple(int(name in ("carry", "stand", "walk")) for name in CLIPS)
BODY_ONLY, BODY_AND_STOCK = 1, 3
MASKS = tuple(BODY_ONLY if name in ("stand", "walk") else BODY_AND_STOCK for name in CLIPS)
FRAMES = sum(COUNTS)
STRIDE = 24 * 12 + 12
EMPTY_SHA = {"stand": "7086ef2a3aab64537d7822393c04ece86d67879e59e1c7e54d333a5c7f974c7d",
             "walk": "046ef4a7f4855b7f5243e66066bc8d27373689471e055f628e94c357cfa1b06e",
             "enter_haul": "739a59754a85d74b753814d400893cb3a5485f72cacfe8ca5b1fc033289111b0",
             "leave_haul": "e02e66a32ec7e815d596cee7ed3e0ea69eae4c2b6c749740fbabc6c6f3d5109c"}
MAX_EMPTY_BYTES = 4 * 256 * 301 + 4096


def empty_inputs() -> dict:
    """Pin the accepted empty-walk candidate through its recorded output manifest."""
    invocation = C.read_json(EMPTY / "invocation.json")
    I.require(invocation["source_unchanged"] is True and invocation["production_qualified"] is False and
              invocation["palette_sha256"] == I.PALETTE_SHA and invocation["grip_palette_sha256"] == I.GRIP_SHA,
              "HAUL_NATIVE_V8_EMPTY_SCOPE")
    pins = {str((EMPTY / "invocation.json").relative_to(ROOT)): C.digest(EMPTY / "invocation.json")}
    for relative, expected in invocation["output_sha256"].items():
        path = EMPTY / relative
        I.require(C.digest(path) == expected, "HAUL_NATIVE_V8_EMPTY_OUTPUT")
        pins[str(path.relative_to(ROOT))] = expected
    candidate = C.read_json(EMPTY / "candidate/candidate.json")
    for name, count in zip(TOOL_FREE, COUNTS[8:]):
        row = candidate["clips"][name]
        I.require(row["frames"] == count and row["sha256"] == EMPTY_SHA[name] == C.digest(clip_path(name)),
                  "HAUL_NATIVE_V8_EMPTY_CLIP")
    return pins


def load_empty_case(name: str, count: int, loop: int) -> dict:
    """One bounded read of the exact pinned bytes; arrays decode only from those verified bytes."""
    path = clip_path(name)
    I.require(path.is_file() and not path.is_symlink() and path.stat().st_size <= MAX_EMPTY_BYTES,
              "HAUL_NATIVE_V8_EMPTY_CAPACITY")
    with path.open("rb") as stream:
        raw = stream.read(MAX_EMPTY_BYTES + 1)
    I.require(len(raw) <= MAX_EMPTY_BYTES and hashlib.sha256(raw).hexdigest() == EMPTY_SHA[name],
              "HAUL_NATIVE_V8_EMPTY_CLIP")
    with np.load(io.BytesIO(raw), allow_pickle=False) as image:
        I.require(sorted(image.files) == ["grounding", "matrices"], "HAUL_NATIVE_V8_SOURCE_SHAPE")
        matrices, grounding = image["matrices"].copy(), image["grounding"].copy()
    columns = 24 if name in ("stand", "walk") else 25
    I.require(matrices.dtype == np.float32 and matrices.shape == (count, columns, 12) and
              grounding.dtype == np.float32 and grounding.shape == (count,) and
              np.all(np.isfinite(matrices)) and np.all(np.isfinite(grounding)), "HAUL_NATIVE_V8_SOURCE_SHAPE")
    return {"frames": count, "matrices": matrices, "grounding": grounding, "source_loop_mode": loop,
            "source_duration_s": Fraction(count - 1, 30)}


def reviewed_inputs() -> dict:
    pins = C.reviewed_inputs()
    pins.update(empty_inputs())
    pins[str(Path(__file__).relative_to(ROOT))] = C.digest(Path(__file__))
    return pins


def clip_path(name: str) -> Path:
    return EMPTY / "candidate" / (name + ".npz") if name in TOOL_FREE else C.clip_path(name)


def fixture(cases: list) -> np.ndarray:
    """The S stock transform shown by approach key 0, recovery's end and both joins; one exact value."""
    stock = cases[0]["matrices"][0, 24]
    for name in ("enter_haul", "leave_haul"):
        case = cases[CLIPS.index(name)]
        I.require(np.array_equal(case["matrices"][:, 24], np.broadcast_to(stock, (case["frames"], 12))),
                  "HAUL_NATIVE_V8_FIXTURE")
    I.require(np.array_equal(cases[3]["matrices"][-1, 24], stock), "HAUL_NATIVE_V8_FIXTURE")
    return stock


def cases_from_sources(body: dict, wood: dict) -> list:
    cases = C.cases_from_review(body, wood)
    for name, count, loop in zip(TOOL_FREE, COUNTS[8:], LOOPS[8:]):
        case = load_empty_case(name, count, loop)
        case.update(id="haul_handling_v1." + name, geometry=[body, wood])
        cases.append(case)
    stock = fixture(cases)
    for case in cases[8:10]:
        # Hidden part (mask BODY_ONLY): exact existing fixture coefficient, body columns byte-identical.
        column = np.broadcast_to(stock, (case["frames"], 1, 12))
        case["matrices"] = np.concatenate((case["matrices"], column), axis=1).astype(np.float32)
    I.require([c["frames"] for c in cases] == list(COUNTS) and sum(COUNTS) == 824, "HAUL_NATIVE_V8_FRAME_CENSUS")
    return cases


def compile_program(palette: Path, grip: Path, out: Path) -> dict:
    I.require(not out.exists() and not out.is_symlink(), "HAUL_NATIVE_OUTPUT_EXISTS")
    pins = reviewed_inputs()
    _, body, wood, _, _, _, _, _ = I.current_inputs(palette, grip)
    wood = C.wrapped_stock(wood)
    pins[str(C.WRAPPER.relative_to(ROOT))] = C.WRAPPER_SHA
    cases = cases_from_sources(body, wood)
    out.mkdir(parents=True)
    program = {"schema": 1, "production_qualified": False, "quantity_milli": 1000,
               "item": "wood", "mass_g": 5000, "active_tool": None,
               "clips": [{"id": c["id"], "source_sha256": C.digest(clip_path(n)), "frames": c["frames"],
                          "loop": c["source_loop_mode"], "duration_q16": (c["frames"] - 1) * 65536,
                          "part_visibility_mask": mask}
                         for n, c, mask in zip(CLIPS, cases, MASKS)],
               "parts": ["body", "stock"],
               "part_visibility": "Actor.set_parts_visible(mask) on clip selection; the wire has no per-clip "
                                  "part presence. Hidden stand/walk stock keeps the exact S fixture coefficient.",
               "source_clock": "presentation sampling only; no hauling speed or work rate",
               "empty_stock": "approach/recovery/join stock is an existing World fixture, never carried cargo permission",
               "body_sha256": I.BODY, "wood_source_sha256": I.LOG,
               "wood_array_mesh_sha256": I.CONTENT.geometry_fingerprint(wood).hex(),
               "native_wrapper_sha256": C.WRAPPER_SHA}
    program_sha = C.write_json(out / "program.json", program)
    proof = {"schema": 1, "production_qualified": False,
             "scope": "accepted continuous source proofs (haul program, loaded gait, empty walk); native replay pending",
             "world_basis": {"sha256": C.BASIS_SHA}, "source_sha256": pins}
    proof_sha = C.write_json(out / "proof.json", proof)
    plan = {"schema": 1, "revision": 1, "world_root_bounds_u": C.BOUNDS, "clips": list(CLIPS),
            "part_visibility_masks": list(MASKS), "runtime_admitted": False}
    plan_sha = C.write_json(out / "plan.json", plan)
    wire, budget = I.CONTENT.encode(cases, plan, proof, program_sha, proof_sha, plan_sha)
    I.require(len(wire) == 184 + 2 * 72 + len(CLIPS) * 48 + FRAMES * (STRIDE + 1) * 4 + 8, "HAUL_NATIVE_WIRE_CENSUS")
    (out / "haul-handling.ugactor").write_bytes(wire)
    raw = C.BASIS.read_bytes()
    metadata = json.loads(raw[20:20 + struct.unpack_from("<I", raw, 16)[0]])
    after = reviewed_inputs()
    after[str(C.WRAPPER.relative_to(ROOT))] = C.digest(C.WRAPPER)
    report = {"schema": 1, "source_sha256": pins, "source_unchanged": after == pins,
              "content_sha256": hashlib.sha256(wire).hexdigest(), "wire_bytes": len(wire),
              "parts": 2, "clips": len(CLIPS), "clip_names": list(CLIPS), "clip_frames": list(COUNTS),
              "part_visibility_masks": list(MASKS), "frames": FRAMES, "scalars": FRAMES * (STRIDE + 1),
              "basis_sha256": C.BASIS_SHA, "basis_producer_sha256": metadata["source"]["sha256"],
              "presentation_only_reservation": budget, "production_qualified": False,
              "runtime_admitted": False}
    I.require(report["source_unchanged"], "HAUL_NATIVE_SOURCE_CHANGED")
    C.write_json(out / "compilation.json", report)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    result = compile_program(args.palette, args.grip_palette, args.out)
    print(json.dumps({key: result[key] for key in ("wire_bytes", "frames", "clips", "content_sha256",
                                                    "runtime_admitted")}))


if __name__ == "__main__":
    main()
