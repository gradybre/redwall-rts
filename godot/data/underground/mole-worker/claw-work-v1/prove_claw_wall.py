#!/usr/bin/env python3
"""Exact world proof of the one claw stroke at a wall (decision 1971). Source-local, yaw 0; no permission.

The clips are M1's approved ones (`stand-walk-v2/dig-pa`, pinned through `native_claw.record_pins`), the station is
the derived wall row's (`evidence/claw-wall-rows-v1/rows.json`: the wall `W` u ahead of the root). Step 1's accepted
machinery is reused unchanged: endpoint vertex hulls in Q24 with the full native residual (`prove_claw_stroke.hulls`),
the accepted sole-support rule and `separated_box` (`prove_stair_terrain`).

**The wall fixture**, yaw 0, forward is -z, the root at the origin on the open cell's floor:

| # | Solid | Rule |
|---|---|---|
| 0 | the open cell's floor (SUPPORT), up to the wall plane | soles rest on it (the accepted rule); paw triangles may scrape it below the plane |
| 1 | natural earth under the target and beyond (the level's floor) | paw triangles may scrape it below the plane |
| 2 | the target cube, laterally centred in the window where the whole stroke box fits | paw triangles may enter it, in every clip |
| 3, 4 | the cubes left and right of the target | everything separates |
| 5 | the cube row beyond the target | everything separates |
| 6 | the earth above the target's band (the column's upper quanta and their neighbours) | everything separates |

**The scrape (P-1971-2 (a)).** A paw triangle may meet solids 0 and 1 only while its whole interval hull lies inside
the row's own below-plane stroke box; any other meeting must separate. **Column digging (P-1971-3 (b))** works the
upper quanta with the bottom cube already open: solid 2 removed, which only removes constraints, and nothing reaches
solid 6. Limb self-clearance is the approved one: the clips are unchanged, and `stand-walk-v2`'s `dig_pa` record
proves both arms on every interval with no exception.

    $PY .../prove_claw_wall.py <rows.json> <out.json> [--palette ...] [--grip-palette ...]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np

import derive_claw_rows as R
import prove_claw_pair as PAIR
import prove_claw_stroke as ONE

NC, SRC, P, T = R.NC, R.SRC, R.P, ONE.T
Q = P.SCALE // 1024
CLIPS = ("dig_stroke", "dig_entry")
SELF_RECORD = SRC.HERE.parent / "stand-walk-v2/evidence/stand-walk-v2/proof.json"
FLOOR, UNDER, TARGET = 0, 1, 2


def require(value: bool, code: str) -> None:
    """Every refusal names its failed fact."""
    P.require(value, "CLAW_WALL_PROOF_" + code)


def fixture(row: dict, wall: int) -> dict:
    """The wall fixture's solids (u). The target sits in the middle of the lateral window where the whole yaw-0
    stroke box lies inside it, the placement the room planner's box fit selects when both neighbours are earth."""
    stroke = row["canonical_roles"]["WORK_STROKE"]
    low, high = min(b[0] for b in stroke), max(b[3] for b in stroke)
    require(high - low < 1024, "STROKE_WIDER_THAN_CUBE")
    left = (high - 1024 + low) // 2
    near, far, right = -wall, -wall - 1024, left + 1024
    solids = [[-2048, -1024, near, 2048, 0, 2048], [-2048, -1024, far - 1024, 2048, 0, near],
              [left, 0, far, right, 1024, near], [-2048, 0, far, left, 1024, near], [right, 0, far, 2048, 1024, near],
              [-2048, 0, far - 1024, 2048, 1024, far], [-2048, 1024, far - 1024, 2048, 2048, near]]
    labels = ["open cell floor (support)", "natural earth under the target", "target cube (paid Site, uncut)",
              "earth left of the target", "earth right of the target", "earth beyond the target",
              "earth above the target's band"]
    return {"solids_u": solids, "labels": labels, "scrape_u": [b for b in stroke if b[4] <= 0]}


def scraped(low: np.ndarray, high: np.ndarray, triangle: np.ndarray, box: list) -> bool:
    """The triangle's clipped below-plane hull on this interval (`clipped_triangle_floor`, interiors included) lies
    inside an integer box (u), closed. The part above the plane meets no floor solid."""
    clipped = P.clipped_triangle_floor(low, high, triangle[None, :])
    return clipped is not None and all(box[a] * Q <= clipped[a] and clipped[a + 3] <= box[a + 3] * Q for a in range(3))


def classify(tri: int, solid: int, sets: dict, low, high, triangles, ground: dict, allowed: tuple) -> str:
    """Which admitted meeting a triangle/solid pair is, or '' when it must separate."""
    if solid == TARGET and sets["paw"][tri] and TARGET in allowed:
        return "paw_target"
    if solid in (FLOOR, UNDER) and sets["paw"][tri] \
            and any(scraped(low, high, triangles[tri], b) for b in ground["scrape_u"]):
        return "paw_scrape"
    return ""


def interval_pairs(src, case, keys, padding, sets, ground, boxes, allowed, tally) -> None:
    """Every triangle against every solid on every rendered interval; admitted meetings are counted apart."""
    triangles, counter, cache = src["triangles"], [0], {}
    exact = lambda frame, vertex: cache.setdefault((frame, vertex), T.exact_source_y(src["body"], case, frame, vertex))
    for first, last in P.rendered_intervals(case):
        raw = (np.stack([keys[first][0], keys[last][0]]), np.stack([keys[first][1], keys[last][1]]))
        low, high = raw[0] - padding, raw[1] + padding
        tally["unresolved"] += ONE.feet_rows(src, case, raw, low, high, (first, last), sets, boxes[FLOOR], exact)[1]
        tl, th = low[:, triangles], high[:, triangles]
        mn, mx = tl.min((0, 2)), th.max((0, 2))
        for solid, box in enumerate(boxes):
            if box is None:
                continue
            for tri in np.flatnonzero(np.all(mn <= box[3:], axis=1) & np.all(mx >= box[:3], axis=1)):
                tally["pairs"] += 1
                if solid == FLOOR and any(m[tri] for m in sets["feet"]) and T.inside_projection(tl[:, tri], th[:, tri], box) \
                        and T.source_above_plane(raw[0], raw[1], triangles[tri], (first, last), 0, exact):
                    tally["soles"] += 1
                    continue
                kind = classify(tri, solid, sets, low, high, triangles, ground, allowed)
                if kind:
                    tally[kind] += 1
                elif not T.separated_box(tl[:, tri], th[:, tri], box, counter):
                    tally["unresolved"].append({"interval": first, "triangle": int(tri), "solid": solid})
                    if len(tally["unresolved"]) >= T.MAX_UNRESOLVED:
                        return
    tally["checks"] += counter[0]


def world(src: dict, case: dict, sets: dict, ground: dict, column: bool) -> dict:
    """One clip against the fixture; `column` opens the target cube (an upper quantum's work)."""
    keys, padding, residual = ONE.hulls(src, case)
    boxes = [np.asarray(b, dtype=np.int64) * Q for b in ground["solids_u"]]
    if column:
        boxes[TARGET] = None
    tally = {"pairs": 0, "soles": 0, "paw_target": 0, "paw_scrape": 0, "checks": 0, "unresolved": []}
    interval_pairs(src, case, keys, padding, sets, ground, boxes, () if column else (TARGET,), tally)
    return {"clear": not tally["unresolved"], **tally, "residual_m": residual}


def self_record() -> dict:
    """The approved limb self-clearance of the same clips (step 1c's `dig_pa`), checked against their pins."""
    record = json.loads(SELF_RECORD.read_text())["dig_pa"]
    pins = NC.record_pins()
    for name in ("entry", "stroke", "recovery"):
        path = "godot/data/underground/mole-worker/stand-walk-v2/evidence/stand-walk-v2/dig-pa/" + name + ".npz"
        require(pins[path] == record["clips"][name], "SELF_CLIP_PIN")
    require(record["clear"] and record["stroke"]["self"]["clear"] and record["entry"]["self"]["clear"], "SELF")
    return {"record": str(SELF_RECORD.relative_to(SRC.ROOT)), "clear": True, "release_allowed": record["release_allowed"]}


def prove(rows: dict, palette: Path, grip: Path) -> dict:
    """The stroke and the entry, with the target solid (the bottom quantum) and open (an upper quantum)."""
    src = SRC.read_claw_source(palette)
    body = NC.open_body(palette, grip)
    cases = {c["id"].split(".")[-1]: c for c in NC.cases(body)}
    require(np.array_equal(cases["dig_recovery"]["matrices"], cases["dig_entry"]["matrices"][::-1]), "REVERSE")
    sets = PAIR.classes(src)
    ground = fixture(rows["rows"][0], rows["wall_distance_u"])
    result = {name: {mode: world(src, cases[name], sets, ground, mode == "column") for mode in ("bottom", "column")}
              for name in CLIPS}
    clear = all(result[n][m]["clear"] for n in CLIPS for m in ("bottom", "column"))
    return {"clear": clear, "fixture": ground, "wall_distance_u": rows["wall_distance_u"], **result,
            "dig_recovery": {"reused_exact_reverse_of": "dig_entry"}, "self_clearance": self_record()}


def main() -> int:
    """Prove the wall rows' station and write the record."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("rows", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--palette", type=Path, default=SRC.PALETTE)
    parser.add_argument("--grip-palette", type=Path, default=SRC.PALETTE.parent / "mole-grip-v3.ugpal")
    args = parser.parse_args()
    require(not args.out.exists(), "OUTPUT_EXISTS")
    rows = json.loads(args.rows.read_text())
    result = prove(rows, args.palette, args.grip_palette)
    producers = [Path(__file__), Path(R.__file__), Path(PAIR.__file__), Path(ONE.__file__), Path(T.__file__)]
    result.update(schema=1, decision="1971", exact_yaw=0, production_qualified=False, rows_sha256=SRC.sha(args.rows),
                  producer_sources={str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p) for p in producers})
    args.out.write_text(json.dumps(result, indent=1, default=str) + "\n")
    print(json.dumps({"clear": result["clear"], **{n: {m: {k: result[n][m][k] for k in
          ("pairs", "soles", "paw_target", "paw_scrape")} | {"unresolved": len(result[n][m]["unresolved"])}
          for m in ("bottom", "column")} for n in CLIPS}}))
    return 0 if result["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
