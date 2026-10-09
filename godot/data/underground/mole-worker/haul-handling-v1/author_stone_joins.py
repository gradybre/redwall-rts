#!/usr/bin/env python3
"""Author the joins between the tool-free stand and the stone program (ADR 1206); source only.

Wood's join recipe (author_empty_walk.py) unchanged: `enter_haul_stone` blends from the reviewed stand's ready
key (stand key 8 of evidence/empty-walk-v1) into the stone approach's first key with the local-rig smoothstep
blend and sole-transfer keys; `leave_haul_stone` is its exact reverse, out of the stone recovery's last key
(the same pose). The floor stone at S is world geometry in both. The stand and walk clips are wood's, reused.
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path

import numpy as np

import author_empty_walk as E
import author_handling as A
import author_loaded_gait as G

PROGRAM = A.I.HERE / "evidence/stone-program-v1"
STAND = A.I.HERE / "evidence/empty-walk-v1/candidate/stand.npz"


def read(path: Path) -> dict:
    with np.load(path, allow_pickle=False) as image:
        return {"frames": len(image["matrices"]), "matrices": image["matrices"].copy(),
                "grounding": image["grounding"].copy(), "source_loop_mode": 0,
                "source_duration_s": Fraction(len(image["matrices"]) - 1, 30)}


def author(body: dict, topology: dict) -> tuple:
    rig = A.hierarchy(topology)
    stand = read(STAND)
    approach, recovery = read(PROGRAM / "approach.npz"), read(PROGRAM / "recovery.npz")
    hub, stock = approach["matrices"][0], approach["matrices"][0, 24]
    A.require(np.array_equal(recovery["matrices"][-1], hub) and recovery["grounding"][-1] == approach["grounding"][0],
              "STONE_JOIN_PROGRAM")
    blended = E.join_keys(stand["matrices"][E.READY_FRAME], stand["grounding"][E.READY_FRAME], hub[:24],
                          approach["grounding"][0], rig, body, E.JOIN_SEGMENTS)
    enter, keys = G.support_keys(blended, body, topology)
    A.require(np.array_equal(enter["matrices"][-1], hub[:24]) and enter["grounding"][-1] == approach["grounding"][0],
              "STONE_JOIN_ENDPOINT")
    clips = {"enter_haul_stone": E.with_fixture(enter, stock),
             "leave_haul_stone": E.with_fixture(E.reversed_case(enter), stock)}
    return clips, {"from": ["stand", E.READY_FRAME], "to": ["stone approach", 0], "segments": E.JOIN_SEGMENTS,
                   "support_transfer_keys": keys}


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    A.require(not args.out.exists() and not args.out.is_symlink(), "STONE_OUTPUT_EXISTS")
    _, body, _, _, topology, _, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    clips, record = author(body, topology)
    args.out.mkdir(parents=True)
    for name, case in clips.items():
        E.write_case(args.out / (name + ".npz"), case)
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    metadata = {"schema": 1, "adr": "1206", "production_qualified": False, "tool": None,
                "stand_sha256": digest(STAND), "approach_sha256": digest(PROGRAM / "approach.npz"),
                "recovery_sha256": digest(PROGRAM / "recovery.npz"), "authoring": record,
                "producer_sha256": {str(Path(p).relative_to(A.I.ROOT)): digest(Path(p)) for p in (__file__, E.__file__)},
                "clips": {name: {"frames": case["frames"], "stock_role": "world_target",
                                 "sha256": digest(args.out / (name + ".npz"))} for name, case in clips.items()}}
    (args.out / "candidate.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(json.dumps({"output": str(args.out), "clips": {k: v["frames"] for k, v in metadata["clips"].items()}}))


if __name__ == "__main__":
    main()
