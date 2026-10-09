#!/usr/bin/env python3
"""Exact-one-unit stone gait (hold, enter, carry loop, exit) from the stone lift's hub (ADR 1206).

Wood's recipe (author_loaded_gait.py) unchanged: the held upper body and stone come from the final key of the
proved stone lift; hips and legs come from every key of the supplied carry_heavy_object_walk; the stone follows
the spine bone rigidly; the entry is a local-joint smoothstep blend into the loop; lower-envelope sole-transfer
keys are added where the original keys would lose support. Variant: exactly 1,000 quantity-milli of stone
(Catalog 5,000 g/unit); no rate, density or balance constant.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

import author_handling as A
import author_loaded_gait as LG
import author_program as LIFT
import author_stone_grip as G

HUB = A.I.HERE / "evidence/stone-program-v1/lift.npz"


def author(inputs: tuple, entry_segments: int) -> dict:
    rows, body, _, _, topology, _, _, _ = inputs
    parents, inverse, inverse_inverse = A.hierarchy(topology)
    with np.load(HUB, allow_pickle=False) as source:
        matrix, ground = source["matrices"][-1].copy(), float(source["grounding"][-1])
    hub = LG.case_of([matrix, matrix], [ground, ground])
    held = A.globals_at(hub, 0, inverse_inverse)
    stock = A.I.affine(matrix[24])
    original_gait = LG.carry_keys(rows[A.I.CASE_IDS[2]], held, stock, parents, inverse, inverse_inverse, body)
    original_entry = LG.entry_keys(held, A.globals_at(original_gait, 0, inverse_inverse), stock, parents, inverse,
                                   matrix, ground, original_gait, body, entry_segments)
    gait, gait_keys = LG.support_keys(original_gait, body, topology)
    entry, entry_keys = LG.support_keys(original_entry, body, topology)
    exit_ = {**entry, "matrices": entry["matrices"][::-1].copy(), "grounding": entry["grounding"][::-1].copy()}
    return {"clips": {"hold": hub, "enter": entry, "carry": gait, "exit": exit_},
            "transfer_keys": {"carry": gait_keys, "enter": entry_keys}}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--entry-segments", type=int, default=60)
    args = parser.parse_args()
    A.require(not args.out.exists() and not args.out.is_symlink(), "STONE_OUTPUT_EXISTS")
    A.require(2 <= args.entry_segments <= 120, "STONE_GAIT_ENTRY_CAPACITY")
    result = author(A.I.current_inputs(args.palette, args.grip_palette), args.entry_segments)
    args.out.mkdir(parents=True)
    for name, case in result["clips"].items():
        LIFT.write_case(args.out / (name + ".npz"), case)
    metadata = {"schema": 1, "adr": "1206", "production_qualified": False,
                "variant": {"name": "stone_one_unit_v1", "item": "stone", "quantity_milli": 1000, "mass_g": 5000,
                            "mass_scope": "Existing Catalog stone mapping; no new density or balancing rule."},
                "source_hub_sha256": hashlib.sha256(HUB.read_bytes()).hexdigest(), "stone_capture_sha256": G.STONE_SHA,
                "producer_sha256": {str(Path(p).relative_to(A.I.ROOT)): hashlib.sha256(Path(p).read_bytes()).hexdigest()
                                    for p in (__file__, LG.__file__, A.__file__)},
                "clips": {name: {"frames": case["frames"], "loop_mode": case["source_loop_mode"],
                                 "sha256": hashlib.sha256((args.out / (name + ".npz")).read_bytes()).hexdigest()}
                          for name, case in result["clips"].items()},
                "source_timing_only": True, "runtime_carry_rate_adopted": False,
                "support_transfer_keys": result["transfer_keys"]}
    (args.out / "candidate.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(json.dumps({"output": str(args.out), "clips": {k: v["frames"] for k, v in metadata["clips"].items()}}))


if __name__ == "__main__":
    main()
