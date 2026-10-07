#!/usr/bin/env python3
"""Exact proofs of the corrected tool-free stand, walk and joins, and of the approved dig from it (ADR 1217).

For the candidate written by `author_stand_walk_v2.py`:

1. **Floor and support** (`prove_empty_walk.support_proof`, unchanged): stand, walk and the four joins on the closed
   paw (the haul sources' body), stand and walk also on the open paw (the dig body).
2. **Paws out of the body** (step 1b's per-arm interval separation, with **no exception**): each arm against every
   triangle with no weight on that arm, on every rendered interval, on both bodies.
3. **Stock separation of the joins** (`prove_empty_walk.join_proof` for wood, `prove_stone_joins.prove` for stone,
   both unchanged).
4. **Row geometry** (`prove_empty_walk.derive_rows`, unchanged): the all-yaw STAND/WALK boxes the corrected clips
   would publish, beside rows 30/31.
5. **The approved dig (pa) from the corrected ready key**, re-authored by `author_claw_pair` and proved by
   `prove_claw_pair.prove_clip` with the stand-contact release switched off.

    $PY .../prove_stand_walk_v2.py <candidate-dir> --world-basis <world-yaw-v1.ugyaw>
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np

import author_stand_walk_v2 as V2

A, E, SRC, PAIRPROOF = V2.A, V2.E, V2.SRC, V2.PAIRPROOF
sys.path.insert(0, str(V2.MOLE / "haul-handling-v1"))
import prove_empty_walk as EW  # noqa: E402
import prove_stone_joins as STONE  # noqa: E402

PAIR = PAIRPROOF.PAIR
PA = json.loads((SRC.HERE / "evidence/claw-pair-v1/candidate-pa/candidate.json").read_text())["recipe"]
STAND_CLIPS = ("stand", "walk")
JOIN_CLIPS = ("enter_haul", "leave_haul", "enter_haul_stone", "leave_haul_stone")


def clip(folder: Path, name: str) -> dict:
    """A candidate clip (25 columns for joins, which carry the floor stock as world geometry)."""
    loop = 1 if name in STAND_CLIPS else 0
    return EW.load_case(folder / (name + ".npz"), 24 if name in STAND_CLIPS else 25, loop)


def separation(src: dict, case: dict, bodies: list) -> dict:
    """Per-arm separation with no exception, every body."""
    body_case = dict(case, matrices=case["matrices"][:, :24])
    sets = PAIRPROOF.classes(src)
    rows = {}
    for label, body in bodies:
        probe = dict(src, body=body)
        keys, padding, _ = PAIRPROOF.ONE.hulls(probe, body_case)
        for side in ("left", "right"):
            row = PAIRPROOF.separation(probe, body_case, keys, padding, sets[side], sets["not_" + side], None)
            row.pop("released_stand_contact", None)
            rows[f"{label}/{side}"] = row
    return rows


def corrected_source(src: dict, folder: Path) -> dict:
    """The claw source closure with its ready hub taken from the corrected stand."""
    stand = clip(folder, "stand")
    return dict(src, stand=stand, hub=A.globals_at(stand, SRC.READY_FRAME, src["inverse_inverse"]),
                grounding=np.float32(stand["grounding"][SRC.READY_FRAME]))


def dig(src: dict, folder: Path) -> dict:
    """pa from the corrected ready key: clips written beside the candidate, every proof with no exception."""
    fixed = corrected_source(src, folder)
    cases, record = PAIR.author(fixed, PA)
    out = folder / "dig-pa"
    out.mkdir()
    for name, case in zip(PAIRPROOF.CLIP_NAMES, cases):
        E.write_case(out / (name + ".npz"), case)
    sets = PAIRPROOF.classes(fixed)
    stroke = PAIRPROOF.prove_clip(fixed, record, cases[0], sets, None, True)
    entry = PAIRPROOF.prove_clip(fixed, record, cases[1], sets, None, False)
    clear = (stroke["world"]["clear"] and stroke["self"]["clear"] and stroke["patches_inside_cube_face"] and
             entry["world"]["clear"] and entry["self"]["clear"] and entry["nothing_below_face"])
    return {"clear": bool(clear), "recipe": PA, "claw_vertices": record["claw_vertices"],
            "clips": {name: SRC.sha(out / (name + ".npz")) for name in PAIRPROOF.CLIP_NAMES},
            "stroke": stroke, "entry": entry, "recovery": {"reused_exact_reverse_of": "entry"},
            "release_allowed": False}


def prove(folder: Path, basis: Path) -> dict:
    """Every proof; `clear` only when all pass."""
    inputs = A.I.current_inputs(SRC.PALETTE, SRC.PALETTE.parent / "mole-grip-v3.ugpal")
    _, closed, wood, _, topology, _, _, _ = inputs
    src = SRC.read_claw_source()
    triangles = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    both = [("closed", closed), ("open", src["body"])]
    result = {"support": {}, "separation": {}}
    for name in STAND_CLIPS + JOIN_CLIPS:
        case = clip(folder, name)
        bodies = both if name in STAND_CLIPS else both[:1]
        result["support"][name] = {label: EW.support_proof(case, body, triangles) for label, body in bodies}
        result["separation"][name] = separation(src, case, bodies)
    wood_tri = EW.R.wood_topology(EW.WOOD, wood)
    result["wood_stock"] = {name: EW.join_proof(clip(folder, name), closed, wood, triangles, wood_tri,
                                                topology["rig_binding"]) for name in JOIN_CLIPS[:2]}
    result["stone"] = STONE.prove(inputs, folder)
    result["rows"] = EW.derive_rows(EW.load_clips(folder), closed, triangles, basis)
    result["dig_pa"] = dig(src, folder)
    result["clear"] = verdict(result)
    return result


def verdict(result: dict) -> bool:
    """All proofs pass."""
    support = all(row["supported_feet"] and not row["floor_penetrations"]
                  for by_body in result["support"].values() for row in by_body.values())
    apart = all(row["clear"] for by_side in result["separation"].values() for row in by_side.values())
    wood = all(row["all_intervals_complete"] and not row["unresolved"] and not row["initial_contained_vertices"]
               and not row["floor_penetrations"] for row in result["wood_stock"].values())
    stone = all(row["passes"] for row in result["stone"].values())
    return bool(support and apart and wood and stone and result["dig_pa"]["clear"])


def main() -> int:
    """Prove one candidate and write proof.json beside it."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--world-basis", type=Path, required=True)
    args = parser.parse_args()
    out = args.candidate / "proof.json"
    A.require(not out.exists(), "STAND_V2_PROOF_EXISTS")
    result = prove(args.candidate, args.world_basis)
    result.update(schema=1, decisions=["1217", "1199"], production_qualified=False,
                  producer_sources={str(Path(p).resolve().relative_to(V2.ROOT)): SRC.sha(Path(p))
                                    for p in (__file__, V2.__file__, EW.__file__, STONE.__file__, PAIRPROOF.__file__,
                                              PAIR.__file__)})
    out.write_text(json.dumps(result, indent=1, default=str) + "\n")
    print(json.dumps({"clear": result["clear"],
                      "separation": {n: {k: len(v["unresolved"]) for k, v in r.items()}
                                     for n, r in result["separation"].items()},
                      "dig_pa": result["dig_pa"]["clear"]}))
    return 0 if result["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
