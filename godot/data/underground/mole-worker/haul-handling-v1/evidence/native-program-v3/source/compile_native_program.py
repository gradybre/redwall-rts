#!/usr/bin/env python3
"""Encode only the eight reviewed haul clips; offline native evidence, never runtime admission."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

import inspect_source as I
import prove_loaded_gait as G
import reproduce_loaded_gait as R

HERE, ROOT = I.HERE, I.ROOT
CLIPS = ("approach", "lift", "place", "recovery", "hold", "enter", "carry", "exit")
COUNTS = (61, 61, 61, 61, 2, 65, 219, 65)
BASIS = ROOT / "godot/data/underground/mole-worker/evidence/forward-plus-v1/focused-v3/forward.ugyaw"
BASIS_SHA = "bc8061e73781f2851c85d0c0e9868b24bc2c99e733ccfcfe8ab5717d5570bbf1"
BOUNDS = [0, -32256, 0, 262144, 16896, 262144]
MAX_JSON = 2 * 1024 * 1024


def digest(path: Path) -> str:
    return I.CONTENT.file_hash(path)


def read_json(path: Path, limit: int = MAX_JSON) -> dict:
    I.require(path.is_file() and not path.is_symlink() and path.stat().st_size <= limit, "HAUL_NATIVE_JSON_CAPACITY")
    result = json.loads(path.read_text())
    I.require(type(result) is dict, "HAUL_NATIVE_JSON_SHAPE")
    return result


def reviewed_inputs() -> dict:
    pins = R.sources()
    final = read_json(HERE / "evidence/loaded-gait-loader-review-v2/final/source-sha256.json")
    for name, expected in final.items():
        I.require(digest(HERE / name) == expected, "HAUL_NATIVE_REVIEWED_SOURCE")
    for name in ("program-review-v1", "loaded-gait-review-v1"):
        folder = HERE / "evidence" / name
        invocation = read_json(folder / "invocation.json")
        I.require(invocation["source_unchanged"] is True and invocation["production_qualified"] is False,
                  "HAUL_NATIVE_REVIEWED_SCOPE")
        for relative, expected in invocation["output_sha256"].items():
            path = folder / relative
            I.require(digest(path) == expected, "HAUL_NATIVE_REVIEWED_OUTPUT")
            pins[str(path.relative_to(ROOT))] = expected
    I.require(digest(BASIS) == BASIS_SHA, "HAUL_NATIVE_BASIS")
    pins[str(BASIS.relative_to(ROOT))] = BASIS_SHA
    pins[str(Path(__file__).relative_to(ROOT))] = digest(Path(__file__))
    return pins


def clip_path(name: str) -> Path:
    folder = "program-review-v1" if name in CLIPS[:4] else "loaded-gait-review-v1"
    return HERE / "evidence" / folder / "candidate" / (name + ".npz")


def cases_from_review(body: dict, wood: dict) -> list:
    cases = []
    for name, count in zip(CLIPS, COUNTS):
        case = G.load_case(clip_path(name), int(name == "carry"))
        I.require(case["frames"] == count, "HAUL_NATIVE_REVIEWED_COUNT")
        case.update(id="haul_handling_v1." + name, geometry=[body, wood])
        cases.append(case)
    I.require(sum(row["frames"] for row in cases) == 595, "HAUL_NATIVE_FRAME_CENSUS")
    return cases


def write_json(path: Path, value: dict) -> str:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    return digest(path)


def compile_program(palette: Path, grip: Path, out: Path) -> dict:
    I.require(not out.exists() and not out.is_symlink(), "HAUL_NATIVE_OUTPUT_EXISTS")
    pins = reviewed_inputs()
    _, body, wood, _, _, _, _, _ = I.current_inputs(palette, grip)
    cases = cases_from_review(body, wood)
    out.mkdir(parents=True)
    program = {"schema": 1, "production_qualified": False, "quantity_milli": 1000,
               "item": "wood", "mass_g": 5000, "active_tool": None,
               "clips": [{"id": c["id"], "source_sha256": digest(clip_path(n)), "frames": c["frames"],
                          "loop": c["source_loop_mode"], "duration_q16": (c["frames"] - 1) * 65536}
                         for n, c in zip(CLIPS, cases)],
               "source_clock": "presentation sampling only; no hauling speed or work rate",
               "empty_stock": "approach/recovery stock is an existing World fixture, never carried cargo permission",
               "body_sha256": I.BODY, "wood_sha256": I.LOG}
    program_sha = write_json(out / "program.json", program)
    proof = {"schema": 1, "production_qualified": False, "scope": "accepted continuous source proof; native replay pending",
             "world_basis": {"sha256": BASIS_SHA}, "source_sha256": pins}
    proof_sha = write_json(out / "proof.json", proof)
    plan = {"schema": 1, "revision": 1, "world_root_bounds_u": BOUNDS, "clips": list(CLIPS),
            "runtime_admitted": False}
    plan_sha = write_json(out / "plan.json", plan)
    wire, budget = I.CONTENT.encode(cases, plan, proof, program_sha, proof_sha, plan_sha)
    I.require(len(wire) == 184 + 2 * 72 + 8 * 48 + 595 * 301 * 4 + 8, "HAUL_NATIVE_WIRE_CENSUS")
    (out / "haul-handling.ugactor").write_bytes(wire)
    raw = BASIS.read_bytes()
    metadata = json.loads(raw[20:20 + struct.unpack_from("<I", raw, 16)[0]])
    report = {"schema": 1, "source_sha256": pins, "source_unchanged": reviewed_inputs() == pins,
              "content_sha256": hashlib.sha256(wire).hexdigest(), "wire_bytes": len(wire),
              "parts": 2, "clips": 8, "frames": 595, "scalars": 595 * 301,
              "basis_sha256": BASIS_SHA, "basis_producer_sha256": metadata["source"]["sha256"],
              "presentation_only_reservation": budget, "production_qualified": False,
              "runtime_admitted": False}
    I.require(report["source_unchanged"], "HAUL_NATIVE_SOURCE_CHANGED")
    write_json(out / "compilation.json", report)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    result = compile_program(args.palette, args.grip_palette, args.out)
    print(json.dumps({key: result[key] for key in ("wire_bytes", "frames", "content_sha256", "runtime_admitted")}))


if __name__ == "__main__":
    main()
