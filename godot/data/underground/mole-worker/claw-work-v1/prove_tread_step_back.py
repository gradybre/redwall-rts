#!/usr/bin/env python3
"""The tool-free step back on a tread (ADR 1209 step 5, ADR 1217): descent end to the tread station. Source only.

The descent onto T_{k-1} ends at root far + 169. The tread fitting motion (ADR 1217 step 2d, DEC-058) works from
the tread station at far + 310. That leaves a 141 u step backward along the stair, facing down it. Both numbers
are derived: 169 from the accepted descent (`prove_descent_flight.DESCENT_START` plus one pitch, against T0's far
edge in the prefix artifact), and 310 from `author_tread_install.STATION_D`.

**Recipe: ADR 1164's finite short step, unchanged, on the approved claw walk.** That recipe is a finite prefix of
the unchanged supplied walk keys, played between READY fades at the adopted ground pace (3277 u/s at 30 Hz,
`work-step-v1/reference_program.PACE`), with the backward step sampling the walk in reverse from key 0. Here:

- **Moves.** ceil(141 x 30 / 3277) = 2 movement ticks (109.23 u, then clipped to the endpoint at 141).
- **Keys.** READY (stand key 8 of the approved corrected stand) -> walk 0 -> walk 43 -> walk 42 -> READY. The claw
  walk loops linearly over 44 keys (its key 44 is the seam), so walking backward from key 0 visits 43, then 42.
  Every key is an approved step-1c key; nothing is authored.
- **Root.** Every rendered interval of that sequence (each a convex blend of its two keys, as the accepted fades
  are) is proved with the root **anywhere** on the 141 u path, so no key-to-root timing is assumed.

**Proofs** (the accepted constructions, conservative over the span):

- **World with sole support.** Every triangle on every interval against every solid of ADR 1209's tread fixture,
  without the bearer (it is delivered after the fitter arrives, ADR 1209 step 5), plus the trench side walls. Each
  solid is extended by the span (the body at root t meets S exactly when the body at the station meets S - t). The
  feet must lie over the deck shrunk by the span, so they are supported at every root on the path, with the
  accepted per-foot rule (`prove_claw_stroke.feet_rows`).
- **Self-clearance** with no exception (`prove_claw_pair.self_rows`).

**Recorded, not silently excepted.** The two READY fades (ready -> walk 0, walk 42 -> ready) keep both feet over
the deck and penetrate nothing, but they have no single-vertex stance-contact witness. No READY<->walk fade of the
approved tool-free family has one: no walk key shares a foot vertex within 1 u of the floor with READY (the best is
1.53 u at key 7; at key 0 it is 6.91 u). The approved narrow approach and retreat rows (content 9, rows 43-50) fade
through the same blends. The record lists them under `ready_fade_without_contact_witness`; every other interval
must carry the witness.

    $PY .../prove_tread_step_back.py <out-dir>
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import importlib.util
import json
import math
from pathlib import Path
import sys

import numpy as np

import author_paw_seat as SEAT
import derive_tread_side_station as SIDE
import prove_claw_pair as PAIRPROOF
import prove_tread_fit as FIT
import prove_tread_seat as TREADSEAT

W, SRC, ONE, T, P = SEAT.W, SEAT.SRC, PAIRPROOF.ONE, PAIRPROOF.T, PAIRPROOF.P
Q = P.SCALE // 1024
REF_SPEC = importlib.util.spec_from_file_location("short_step_reference",
                                                  SRC.MOLE / "work-step-v1/reference_program.py")
REF = importlib.util.module_from_spec(REF_SPEC)
REF_SPEC.loader.exec_module(REF)
FLIGHT = TREADSEAT.TREAD.FLIGHT
WALK = SEAT.STAND_V2 / "walk.npz"


def distances() -> dict:
    """The descent's end and the station, both behind T_{k-1}'s far edge, from published geometry."""
    packet = PAIRPROOF.P.content.read_json(TREADSEAT.TREAD.PREFIX, TREADSEAT.TREAD.I.PREFIX_SHA, 65536)
    t0_far = packet["parts"][7]["bounds_u"][2]
    end = FLIGHT.DESCENT_START[2] - FLIGHT.RUN  # The descent from L0 onto T0 ends one pitch on.
    W.require(packet["parts"][7]["name"] == "T0_deck" and t0_far == -2560 and end == -2391, "STEP_BACK_GEOMETRY")
    arrival, station = end - t0_far, TREADSEAT.STATION_D
    return {"arrival_from_far_edge_u": arrival, "station_from_far_edge_u": station, "span_u": station - arrival}


def walk_clip() -> dict:
    """The approved step-1c walk, pinned by its record."""
    record = json.loads((SEAT.STAND_V2 / "candidate.json").read_text())
    W.require(SRC.sha(WALK) == record["clips"]["walk"]["sha256"] and record["clips"]["walk"]["loop_mode"] == 1,
              "STEP_BACK_WALK_PIN")
    with np.load(WALK, allow_pickle=False) as image:
        return {"frames": len(image["matrices"]), "matrices": image["matrices"].copy(),
                "grounding": image["grounding"].copy()}


def step_case(src: dict, walk: dict, span: int) -> tuple:
    """READY -> walk keys sampled backward for the movement ticks -> READY, as one linear clip."""
    moves = math.ceil(Fraction(span * REF.HZ, REF.PACE))
    loop = walk["frames"] - 1  # LOOP_LINEAR: the last key is the seam; the loop has frames - 1 keys.
    keys = [(-k) % loop for k in range(moves + 1)]
    matrices = [src["stand"]["matrices"][SRC.READY_FRAME]] + [walk["matrices"][k] for k in keys] + \
        [src["stand"]["matrices"][SRC.READY_FRAME]]
    grounding = [src["stand"]["grounding"][SRC.READY_FRAME]] + [walk["grounding"][k] for k in keys] + \
        [src["stand"]["grounding"][SRC.READY_FRAME]]
    count = len(matrices)
    case = {"id": "mole_worker.claw_step_back.v1", "frames": count, "matrices": np.asarray(matrices, np.float32),
            "grounding": np.asarray(grounding, np.float32), "source_loop_mode": 0,
            "source_duration_s": Fraction(count - 1, 30), "duration_q16": (count - 1) * 65536}
    return case, {"moves": moves, "walk_keys": keys, "pace_u_per_s": REF.PACE, "hz": REF.HZ}


def fixture(span: int) -> dict:
    """The tread fixture without the bearer, the trench walls added; collision solids extended by the span."""
    _, full = FIT.site({"work_y_u": 131, "contact_z_u": -300, "paw_x_u": 224}, SEAT.PLANE_U)
    keep = [i for i in range(len(full["solids_u"])) if i != full["workpiece_solid"]]
    solids = [full["solids_u"][i] for i in keep]
    labels = [full["source_labels"][i] for i in keep]
    deck = solids[0]
    W.require(labels[0].startswith("support deck") and deck[2] + span < deck[5], "STEP_BACK_DECK")
    support = [deck[0], deck[1], deck[2] + span, deck[3], deck[4], deck[5]]
    swept = [[b[0], b[1], b[2], b[3], b[4], b[5] + span] for b in solids]
    return {"solids_u": solids, "labels": labels, "swept_u": swept, "support_u": support}


def world(src: dict, case: dict, ground: dict, sets: dict) -> dict:
    """`prove_paw_seat.world`'s construction with a span: support on the shrunk deck, collisions on swept solids."""
    keys, padding, _ = ONE.hulls(src, case)
    boxes = [np.asarray(b, dtype=np.int64) * Q for b in ground["swept_u"]]
    support = np.asarray(ground["support_u"], dtype=np.int64) * Q
    triangles, counter, cache = src["triangles"], [0], {}
    exact = lambda frame, vertex: cache.setdefault((frame, vertex), T.exact_source_y(src["body"], case, frame, vertex))
    unresolved, pairs, soles, hover = [], 0, 0, []
    for first, last in P.rendered_intervals(case):
        raw = (np.stack([keys[first][0], keys[last][0]]), np.stack([keys[first][1], keys[last][1]]))
        low, high = raw[0] - padding, raw[1] + padding
        _, failures = ONE.feet_rows(src, case, raw, low, high, (first, last), sets, support, exact)
        fade = first == 0 or last == case["frames"] - 1
        hover += [f for f in failures if fade and f["kind"] == "NO_SOURCE_STANCE_CONTACT"]
        unresolved += [f for f in failures if not (fade and f["kind"] == "NO_SOURCE_STANCE_CONTACT")]
        tl, th = low[:, triangles], high[:, triangles]
        mn, mx = tl.min((0, 2)), th.max((0, 2))
        for solid, box in enumerate(boxes):
            for tri in np.flatnonzero(np.all(mn <= box[3:], axis=1) & np.all(mx >= box[:3], axis=1)):
                pairs += 1
                if solid == 0 and any(m[tri] for m in sets["feet"]) and T.inside_projection(tl[:, tri], th[:, tri], support) \
                        and T.source_above_plane(raw[0], raw[1], triangles[tri], (first, last), 0, exact):
                    soles += 1
                    continue
                if not T.separated_box(tl[:, tri], th[:, tri], box, counter):
                    unresolved.append({"interval": first, "triangle": int(tri), "solid": solid})
                if len(unresolved) >= T.MAX_UNRESOLVED:
                    return {"clear": False, "unresolved": unresolved, "stopped_at_limit": True}
    return {"clear": not unresolved, "unresolved": unresolved, "pairs": pairs, "numerical_sole_pairs": soles,
            "checks": counter[0], "ready_fade_without_contact_witness": hover}


def fade_hover(src: dict, sets: dict, walk: dict) -> dict:
    """Float: for every walk key, the best single foot vertex's larger height at READY and at that key.

    The accepted witness needs one vertex within [0, 1) u of the floor at both ends of an interval. No walk key
    shares such a vertex with READY, so no READY<->walk fade of the approved tool-free family has the witness."""
    feet = np.unique(src["triangles"][sets["any_foot"]])
    ready = SRC.I.points_at(src["stand"], src["body"], SRC.READY_FRAME)[feet, 1]
    gaps = [float(np.maximum(ready, SRC.I.points_at(walk, src["body"], k)[feet, 1]).min())
            for k in range(walk["frames"] - 1)]
    return {"best_shared_gap_u_by_walk_key": [round(g, 3) for g in gaps], "smallest_u": round(min(gaps), 3)}


def derive(out: Path) -> dict:
    """Build the step, prove it and write the record and the clip."""
    src = SEAT.corrected_source()
    sets = PAIRPROOF.classes(src)
    where = distances()
    case, timing = step_case(src, walk_clip(), where["span_u"])
    ground = fixture(where["span_u"])
    keys, padding, _ = ONE.hulls(src, case)
    result = {"world": world(src, case, ground, sets), "ready_fade_hover_float": fade_hover(src, sets, walk_clip()),
              "self": PAIRPROOF.self_rows(src, case, keys, padding, sets, None)}
    clear = result["world"]["clear"] and result["self"]["clear"]
    out.mkdir(parents=True)
    W.write_case(out / "step_back.npz", case)
    record = {"schema": 1, "decision": ["1209", "1217"], "motion": "tool-free 141 u step back on a tread (ADR 1209 step 5)",
              "recipe": "ADR 1164 finite short step on the approved claw walk; no authored key", **where, **timing,
              "clip_sha256": SRC.sha(out / "step_back.npz"), "walk_sha256": SRC.sha(WALK),
              "stand_sha256": src["stand_sha256"], "fixture": ground, "clear": bool(clear), **result,
              "bearer_present": False, "production_qualified": False,
              "producer_sources": {str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p) for p in
                                   (Path(__file__), Path(FIT.__file__), Path(SIDE.__file__), Path(ONE.__file__),
                                    Path(PAIRPROOF.__file__), Path(REF.__file__))}}
    (out / "step_back.json").write_text(json.dumps(record, indent=1, default=str) + "\n")
    return record


def main() -> int:
    """Derive and prove once."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "STEP_BACK_OUTPUT_EXISTS")
    record = derive(args.out)
    print(json.dumps({"clear": record["clear"], "span_u": record["span_u"], "moves": record["moves"],
                      "walk_keys": record["walk_keys"], "world_unresolved": len(record["world"]["unresolved"]),
                      "self": record["self"]["clear"]}))
    return 0 if record["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
