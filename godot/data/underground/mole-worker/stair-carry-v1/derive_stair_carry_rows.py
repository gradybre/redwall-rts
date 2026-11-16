#!/usr/bin/env python3
"""Integer profile rows of the basic stair carry (decision 1981): rows 71-84. Derived, never chosen.

Every box is the accepted derivation's (`claw-work-v1/derive_stair_rows.py`), extended from one body part to the
body and its load:

| Rows | Clip | Roles |
|---|---|---|
| gaits (descent, ascent) | `descent`, `ascent` with their integer root tracks | BODY_HELD_LOAD = TURN_RECOVERY = every key's complete outward hull of the body **and the load** plus its integer root, widened 1 u for the ceil root (`rooted_row`); STANCE_SUPPORT = the feet likewise; oriented to the heading |
| handoffs (approach, retreat, turn, walk-off) | the handoff clips | BODY_HELD_LOAD = TURN_RECOVERY = the union of the accepted handoff prover's exact interval enclosures of every part (heading enclosed), rebased to the start root; STANCE_SUPPORT = its lowest 128 u (`turn_row`) |
| back-ups | the approach reversed | the approach's boxes rebased to the back-up's start (the approach's end) |

The handoff enclosures are read from `evidence/proof-v1.json` (the runs on L0; the turn's and the walk-off's on the
floor: the enclosures are of the motion, not of the fixture). The gait hulls are computed here from the clips with
the native World's cardinal residual, as `derive_stair_rows` does.

    $PY .../derive_stair_carry_rows.py <clips-dir> <proof.json> <out.json>
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np

import author_stair_carry as AUTHOR
import prove_stair_carry as PROVE
import stair_carry_source as SC

CS, SRC, W, AH = SC.CS, SC.SRC, SC.W, AUTHOR.AH
sys.path.insert(0, str(SC.MOLE / "claw-work-v1"))
import derive_claw_rows as DC  # noqa: E402
import derive_stair_rows as DS  # noqa: E402

N, P = DC.N, DC.P
import compile_native_program as HAUL_NATIVE  # noqa: E402  (haul-handling-v1)

HALF = 32768
# (name, yaw, family mask); the order is each source's key order (WALK before CARRY), then the table's. Every row
# names connector family 0 (EARTH_TIMBER): its edges belong to the stair's Placement, whose authored paces carry
# DEC-050's ticks (decision 1981, P-1981-3); a ground edge could only take Movement's cap.
EMPTY_ROWS = (("empty_walk_off", 0, 1), ("empty_back_up", 0, 1))
LOADED_ROWS = (("approach", 0, 1), ("descent", 0, 1), ("ascent", HALF, 1), ("turn", 0, 1), ("retreat", HALF, 1),
               ("back_up", 0, 1))
HANDOFF_RUN = {"approach": "L0", "retreat": "L0", "turn": "floor_turn", "empty_walk_off": "floor_approach"}


def native_part(item: str, closure: dict) -> dict:
    """The load exactly as the image draws it (the native wrapper of the log; the stone's native bits)."""
    part = closure["items"][item]["part"]
    return HAUL_NATIVE.wrapped_stock(part) if item == "wood" else part


def hull_boxes(case: dict, parts: list, basis, vertices: list) -> list:
    """Per key, the outward integer box of the given vertices of every part (each with its own residual)."""
    boxes = [None] * case["frames"]
    offset = 0
    for part, chosen in zip(parts, vertices):
        count = max(1, part["binds"])
        cache = DC.endpoint(dict(case, matrices=case["matrices"][:, offset:offset + count]), part, SRC.ROOT_BOUNDS,
                            basis)
        offset += count
        if chosen is None or len(chosen) == 0:
            continue
        for k, box in enumerate(DS.key_boxes(cache, chosen)):
            boxes[k] = box if boxes[k] is None else DS.union([boxes[k], box])
    return boxes


def gait_row(case: dict, parts: list, triangles: list, basis, heading: int) -> dict:
    """`derive_stair_rows.rooted_row` over the body and its load."""
    roots = case["stair_recipe"]["root_u"]
    whole = hull_boxes(case, parts, basis, [np.unique(t) for t in triangles])
    feet = hull_boxes(case, parts[:1], basis, [DS.feet_vertices(parts[0], triangles[0])])
    body = DS.union([DS.shifted(b, r, 1) for b, r in zip(whole, roots)])
    stance = DS.union([DS.shifted(b, r, 1) for b, r in zip(feet, roots)])
    roles = {"BODY_HELD_LOAD": [body], "STANCE_SUPPORT": [stance], "TURN_RECOVERY": [body]}
    return {"roles": {role: [N.orient_box(b, heading) for b in boxes] for role, boxes in roles.items()},
            "root_end_u": [roots[-1][0], roots[-1][1], roots[-1][2]] if heading == 0 else
            [-roots[-1][0], roots[-1][1], -roots[-1][2]]}


def handoff_row(proof: dict, case: dict, shift: list | None = None) -> dict:
    """`derive_stair_rows.turn_row` from the prover's enclosures of every part, rebased to the start root."""
    keys = case["handoff_recipe"]["keys"]
    start = keys[0]["root_u"] if shift is None else shift
    boxes = [box for part in proof["interval_boxes_u"] for box in part]
    whole = DS.union([[b[a] - start[a % 3] for a in range(6)] for b in boxes])
    floor = [whole[0], whole[1], whole[2], whole[3], min(whole[4], whole[1] + 128), whole[5]]
    end = keys[-1]["root_u"]
    return {"roles": {"BODY_HELD_LOAD": [whole], "STANCE_SUPPORT": [floor], "TURN_RECOVERY": [whole]},
            "root_end_u": [end[a] - start[a] for a in range(3)]}


def back_up_row(approach: dict, case: dict) -> dict:
    """The approach's boxes in the frame of its end root, where the reversed clip starts."""
    keys = case["handoff_recipe"]["keys"]  # Reversed: keys[0] is the approach's end.
    first, last = keys[0]["root_u"], keys[-1]["root_u"]
    end = approach["root_end_u"]
    roles = {role: [[b[a] - end[a % 3] for a in range(6)] for b in boxes] for role, boxes in approach["roles"].items()}
    return {"roles": roles, "root_end_u": [last[a] - first[a] for a in range(3)]}


def rows_of(group: str, cases: dict, proofs: dict, parts: list, triangles: list, basis, table: tuple) -> list:
    """The rows of one group, in table order."""
    result, derived = [], {}
    for name, yaw, families in table:
        case = cases[name]
        if name in ("descent", "ascent"):
            row = gait_row(case, parts, triangles, basis, 0 if name == "descent" else 2)
        elif name in HANDOFF_RUN:
            row = handoff_row(proofs[name][HANDOFF_RUN[name]], case)
        else:
            row = back_up_row(derived["approach" if group != "empty" else "empty_walk_off"], case)
        derived[name] = row
        W.require(sum(map(len, row["roles"].values())) <= 12, "STAIR_CARRY_BOX_CAPACITY")
        result.append({"name": name, "group": group, "yaw": yaw, "family_mask": family_mask(families), **row})
    return result


def family_mask(families: int) -> int:
    """1 = EARTH_TIMBER (connector family 0), as rows 53-55."""
    W.require(families == 1, "STAIR_CARRY_FAMILY")
    return families


def derive(clips_dir: Path, proof_path: Path, basis_path: Path) -> dict:
    """Every row, after checking the stored clips."""
    closure = SC.closure()
    table, _ = AH.read_basis()
    clips = AUTHOR.author(closure, table)
    PROVE.check_stored(clips_dir, clips)
    record = json.loads(proof_path.read_text())
    W.require(record["proofs"]["clear"] is True, "STAIR_CARRY_PROOF_NOT_CLEAR")
    with basis_path.open("rb") as stream:
        basis = N.CardinalBasis(stream, DC.BASIS_SHA, DC.BASIS_PRODUCER)
    body, body_tri = closure["body"], closure["body_triangles"]
    rows = rows_of("empty", clips["empty"], {"empty_walk_off": record["proofs"]["floor_end"]["empty_walk_off"]},
                   [body], [body_tri], basis, EMPTY_ROWS)
    for item in SC.ITEMS:
        parts = [body, native_part(item, closure)]
        rows += rows_of(item, clips[item], record["proofs"][item], parts,
                        [body_tri, closure["items"][item]["triangles"]], basis, LOADED_ROWS)
    return {"schema": 1, "decision": "1981", "rows": rows, "basis": basis.cardinal_certificate(),
            "world_root_bounds_u": SRC.ROOT_BOUNDS, "proof_sha256": SRC.sha(proof_path),
            "production_qualified": False}


def main() -> int:
    """Derive and write the record."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("clips", type=Path)
    parser.add_argument("proof", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--world-basis", type=Path,
                        default=SRC.ROOT / "godot/demo/assets/underground-matrices/world-yaw-v1.ugyaw")
    args = parser.parse_args()
    W.require(not args.out.exists(), "STAIR_CARRY_ROWS_EXIST")
    result = derive(args.clips, args.proof, args.world_basis)
    result["producer_sources"] = {str(Path(p).resolve().relative_to(SRC.ROOT)): SRC.sha(Path(p)) for p in
                                  (__file__, DS.__file__, DC.__file__, AUTHOR.__file__)}
    args.out.write_text(json.dumps(result, indent=1, default=str) + "\n")
    print(json.dumps([{"row": f"{r['group']}.{r['name']}", "yaw": r["yaw"], "end": r["root_end_u"],
                       "body": r["roles"]["BODY_HELD_LOAD"][0]} for r in result["rows"]]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
