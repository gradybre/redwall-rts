#!/usr/bin/env python3
"""Integer profile rows for the tread and stair clips (ADR 1229 content 10). Derived, never chosen.

Every row comes from an approved clip of the native claw/paw v2 images (`native_claw_stairs.py`), enclosed by the
accepted cardinal derivation (`derive_claw_rows.endpoint`: complete outward Q24 vertex hulls with the local, native
World and cardinal residual) in the frame of the row's start root:

| Row | Clip | Roles |
|---|---|---|
| step back / step forward (POLICY_SHORT_BACKWARD/FORWARD, yaw 0, ground) | `step_back`, `step_forward` | BODY = TURN = every key's hull swept along the 141 u path; STANCE = the feet's hull swept likewise |
| descent (POLICY_STAIR, yaw 0, EARTH_TIMBER) | `descent` with M7's root track | BODY = TURN = every key's hull plus its integer root, widened 1 u for the ceil root; STANCE = the feet likewise |
| ascent (POLICY_STAIR, yaw 32768) | `ascent`, the same, oriented by the exact half turn | as descent |
| half-turn (POLICY_STAIR, yaw 0, ends at 32768) | `turn` | BODY = TURN = the union of the accepted handoff prover's exact interval enclosures (`prove_stair_handoffs`, heading enclosed), rebased to the start root; STANCE = the feet's part of them |
| tread fitting (POLICY_SOURCE_WORK, INSTALL, CONTACT_TREAD_FIT, yaw 0) | `tread_tap_*` | `derive_claw_rows.tap_roles` split at the bearer's top (128 u), without contact boxes (DEC-058) |
| tread handling (POLICY_ASSEMBLY_HANDLING, yaw 0, source 5) | `tread_seat_*` | `derive_claw_rows.seat_roles` |

    $PY .../derive_stair_rows.py <out.json> --world-basis <world-yaw-v1.ugyaw> [--palette ...] [--grip-palette ...]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np

import derive_claw_rows as DC
import native_claw_stairs as NS

NC, SRC, P, C, N = DC.NC, DC.SRC, DC.P, DC.C, DC.N
PLANE_U = 128  # The tread bearer's top (ADR 1209); the tread rows split there as the INSTALL rows do.
SPAN_U = 141  # Derived in prove_tread_step_back.distances (169 -> 310 u).


def require(value: bool, code: str) -> None:
    """Every refusal names its failed derivation fact."""
    P.require(value, "STAIR_ROWS_" + code)


def union(boxes: list) -> list:
    """`compile_state_program.union` folded pairwise (it admits at most 64 boxes per call)."""
    result = None
    for box in boxes:
        result = C.union([result, box])
    return result


def key_boxes(cache: dict, vertices: np.ndarray) -> list:
    """Per key, the outward integer box of the given vertices (u)."""
    return [P.outward_units(cache["low"][k, vertices].min(axis=0), cache["high"][k, vertices].max(axis=0))
            for k in range(len(cache["low"]))]


def shifted(box: list, root: list, extra: int = 0) -> list:
    """A box moved by an integer root, widened by `extra` on every face (the ceil root's [0, 1) u)."""
    return [box[a] + root[a % 3] - (extra if a < 3 else -extra) for a in range(6)]


def swept_span(box: list, span: int) -> list:
    """A box swept from root 0 to root z = +span or -span (sign of span)."""
    return [box[0], box[1], box[2] + min(0, span), box[3], box[4], box[5] + max(0, span)]


def feet_vertices(body: dict, triangles: np.ndarray) -> np.ndarray:
    """Every vertex of a foot triangle (`foot_membership`)."""
    feet = DC.ONE.T.foot_membership(body, triangles)
    return np.unique(triangles[feet[0] | feet[1]])


def step_row(name: str, case: dict, body: dict, triangles: np.ndarray, basis, span: int) -> dict:
    """A finite short step along -Z (forward) or +Z (backward) by `span`, root anywhere on the path."""
    cache = DC.endpoint(case, body, SRC.ROOT_BOUNDS, basis)
    whole = union(key_boxes(cache, np.unique(triangles)))
    feet = union(key_boxes(cache, feet_vertices(body, triangles)))
    body_box, stance = swept_span(whole, span), swept_span(feet, span)
    return {"name": name, "yaw": 0, "family_mask": 0,
            "roles": {"BODY_HELD_LOAD": [body_box], "STANCE_SUPPORT": [stance], "TURN_RECOVERY": [body_box]}}


def rooted_row(name: str, case: dict, roots: list, body: dict, triangles: np.ndarray, basis, heading: int) -> dict:
    """A stair gait with its integer root track, in its own frame, then oriented to its heading."""
    cache = DC.endpoint(case, body, SRC.ROOT_BOUNDS, basis)
    whole = [shifted(b, r, 1) for b, r in zip(key_boxes(cache, np.unique(triangles)), roots)]
    feet = [shifted(b, r, 1) for b, r in zip(key_boxes(cache, feet_vertices(body, triangles)), roots)]
    body_box, stance = union(whole), union(feet)
    roles = {"BODY_HELD_LOAD": [body_box], "STANCE_SUPPORT": [stance], "TURN_RECOVERY": [body_box]}
    return {"name": name, "yaw": N.YAWS[heading], "family_mask": 1, "root_end_u": roots[-1],
            "roles": {role: [N.orient_box(b, heading) for b in boxes] for role, boxes in roles.items()}}


def turn_row(src: dict, body: dict) -> dict:
    """The half-turn: the accepted handoff prover's exact interval enclosures on T0, rebased to the start root."""
    import author_claw_turn as TURN
    record = json.loads((NS.TURN / "candidate.json").read_text())
    table, _ = TURN.AH.read_basis()
    case = TURN.author(src, table, record["arm_swing_degrees"])
    with np.load(NS.TURN / "turn.npz", allow_pickle=False) as image:
        require(image["matrices"].tobytes() == case["matrices"][:, :24].tobytes(), "TURN_REBUILD")
    ground = TURN.fixture(0)
    with TURN.claw_guards(case, ground):
        proof = TURN.PH.prove(case, case["handoff_recipe"], [src["body"]], [[src["triangles"]]], SRC.ROOT_BOUNDS,
                              ground, table)
    require(proof["clear"], "TURN_PROOF")
    start = case["handoff_recipe"]["keys"][0]["root_u"]
    boxes = [[b[a] - start[a % 3] for a in range(6)] for b in proof["parts"][0]["full_interval_boxes_program_u"]]
    whole = union(boxes)
    floor = [whole[0], whole[1], whole[2], whole[3], min(whole[4], whole[1] + 128), whole[5]]
    return {"name": "turn", "yaw": 0, "yaw_end": 32768, "family_mask": 1,
            "root_end_u": [case["handoff_recipe"]["keys"][-1]["root_u"][a] - start[a] for a in range(3)],
            "checks": proof["checks"],
            "roles": {"BODY_HELD_LOAD": [whole], "STANCE_SUPPORT": [floor], "TURN_RECOVERY": [whole]}}


def fit_rows(cases: dict, body: dict, triangles: np.ndarray, basis, ready_case: dict) -> list:
    """The tread fitting tap (no contact boxes) and the tread handling seat, yaw 0."""
    paw = DC.masks(body, triangles)
    parts, caches = {}, {}
    for key, name in (("work", "tread_tap_work"), ("entry", "tread_tap_entry")):
        parts[key], caches[key] = DC.clip_parts(cases[name], body, triangles, paw, SRC.ROOT_BOUNDS, basis, PLANE_U)
    ready, ready_cache = DC.clip_parts(ready_case, body, triangles, paw, SRC.ROOT_BOUNDS, basis, PLANE_U)
    support = DC.stance(body, triangles, [(caches["work"], parts["work"]["rest"]["below"]),
                                          (caches["entry"], parts["entry"]["rest"]["below"]),
                                          (ready_cache, ready["rest"]["below"])])
    work, entry = parts["work"], parts["entry"]
    split = lambda rows: [rows["rest"]["lower"], C.union([rows["rest"]["upper"], rows["paw"]["full"]])]
    tap = {"BODY_HELD_LOAD": C.body_boxes({"full_bounds_u": work["rest"]["full"],
                                            "floor_intersection_u": work["rest"]["floor"]}),
           "STANCE_SUPPORT": [support], "TURN_RECOVERY": split(entry), "WORK_APPROACH": split(ready),
           "WORK_STROKE": C.partitions_complete([work["paw"]["above"], work["paw"]["below"]], work["paw"]["full"])}
    seat_parts, seat_caches = {}, {}
    for key, name in (("work", "tread_seat_work"), ("entry", "tread_seat_entry")):
        seat_parts[key], seat_caches[key] = DC.clip_parts(cases[name], body, triangles, paw, SRC.ROOT_BOUNDS, basis, 0)
    seat_ready, seat_ready_cache = DC.clip_parts(ready_case, body, triangles, paw, SRC.ROOT_BOUNDS, basis, 0)
    seat_support = DC.stance(body, triangles, [(seat_caches["work"], seat_parts["work"]["rest"]["below"]),
                                               (seat_caches["entry"], seat_parts["entry"]["rest"]["below"]),
                                               (seat_ready_cache, seat_ready["rest"]["below"])])
    seat = DC.seat_roles(seat_parts, seat_ready, seat_support)
    for roles in (tap, seat):
        require(sum(map(len, roles.values())) <= 12, "BOX_CAPACITY")
    return [{"name": "tread_tap", "yaw": 0, "roles": tap}, {"name": "tread_seat", "yaw": 0, "roles": seat}]


def derive(palette: Path, grip: Path, basis_path: Path) -> dict:
    """All seven rows."""
    import author_claw_stairs as CS
    body = NC.open_body(palette, grip)
    rows = {}
    for image in ("claw", "paw"):
        NS.select(image)
        rows.update({c["id"].split(".")[-1]: c for c in NC.cases(body)})
    src = SEAT_SOURCE()
    triangles = src["triangles"]
    with basis_path.open("rb") as stream:
        basis = N.CardinalBasis(stream, DC.BASIS_SHA, DC.BASIS_PRODUCER)
    ready = P.indexed_sequence(rows["stand"], [NC.READY, NC.READY], "claw_exact_ready", False)
    stairs = CS.author(src, json.loads((NS.STAIRS / "candidate.json").read_text())["arm_swing_degrees"])
    for gait in ("descent", "ascent"):
        require(np.array_equal(stairs[gait]["matrices"][:, :24], rows[gait]["matrices"]), "STAIR_REBUILD_" + gait)
    result = [step_row("step_back", rows["step_back"], body, triangles, basis, SPAN_U),
              step_row("step_forward", rows["step_forward"], body, triangles, basis, -SPAN_U),
              rooted_row("descent", rows["descent"], stairs["descent"]["stair_recipe"]["root_u"], body, triangles, basis, 0),
              rooted_row("ascent", rows["ascent"], stairs["ascent"]["stair_recipe"]["root_u"], body, triangles, basis, 2),
              turn_row(src, body)] + fit_rows(rows, body, triangles, basis, ready)
    return {"schema": 1, "decision": ["1229", "1217", "1209"], "rows": result, "basis": basis.cardinal_certificate(),
            "world_root_bounds_u": SRC.ROOT_BOUNDS, "plane_u": PLANE_U, "span_u": SPAN_U,
            "production_qualified": False}


def SEAT_SOURCE() -> dict:
    """The corrected claw source (step 1c), the closure every approved clip was authored on."""
    import author_paw_seat as SEAT
    return SEAT.corrected_source()


def main() -> int:
    """Derive and write the record."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("--world-basis", type=Path, required=True)
    parser.add_argument("--palette", type=Path, default=SRC.PALETTE)
    parser.add_argument("--grip-palette", type=Path, default=SRC.PALETTE.parent / "mole-grip-v3.ugpal")
    args = parser.parse_args()
    require(not args.out.exists(), "OUTPUT_EXISTS")
    result = derive(args.palette, args.grip_palette, args.world_basis)
    result["producer_sources"] = {str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p)
                                  for p in (Path(__file__), Path(DC.__file__), Path(NS.__file__))}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=1, default=str) + "\n")
    print(json.dumps([{"row": r["name"], "yaw": r["yaw"], "boxes": sum(map(len, r["roles"].values())),
                       "body": r["roles"]["BODY_HELD_LOAD"][0]} for r in result["rows"]]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
