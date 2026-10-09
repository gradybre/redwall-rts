#!/usr/bin/env python3
"""The side-on tread station (ADR 1217 step 2c, ADR 1209 step 5): derived from published geometry, then proved.

Brendan (2026-10-07) chose side-on fitting: on T_{k-1} the mole turns a quarter turn and stands beside T_k's bearer,
so the bearer sits at the paws' reach as at L0/T0. This tool derives that station from published data only and
runs the accepted proofs on it, with the approved paw handling/seating clips (`paw-seat-v1/candidate-a`) unchanged.

**Published inputs.**

- The tread fixture of ADR 1209 (`author_tread_install.fixture`, via `prove_tread_seat.tread_fixture`): T_{k-1}'s
  deck `[-1024,-64,-310, 1024,0,202]` (512 u deep, the T0 deck of the prefix artifact), the deck behind, the
  bearer/post supersets and the workpiece, T_k's bearer quarter-turned across T_{k-1}'s forward edge,
  `[-256,0,-310, 256,P,-182]` (P = 128 for T1...T5, 64 for the T6 sill, ADR 1209 D1). Station-local to ADR 1209's
  310 u station (yaw 0, on T_{k-1}'s deck top).
- The trench's side walls at |x| >= 1024 (`prove_descent_flight.trench`, from the prefix cut groups), up to the
  surface, 128 k above T_{k-1}'s top.
- The approved paw clips and their contact targets (+-128, P, -448) (`paw-seat-v1/candidate-a`, pinned).
- The approved corrected stand (step 1c), whose key 8 is the ready hub of every paw clip.
- The published quarter turn (`claw_source.quarter`): yaw 16384 maps local (x, z) to world (z, -x), facing -x.

**Derivation.** A quarter turn makes the mole's lateral axis the tread's depth axis (z). The accepted support rule
(`prove_claw_stroke.feet_rows`, `inside_projection`) needs every foot vertex inside the support deck's projection,
so a side-on station exists only if the feet's lateral span fits in the deck's depth. Both are exact here:

1. **Footing (exact).** For every key of the stand and of the approved seat and tap clips (entry and work; the
   recovery is the entry reversed), the exact rational skin equation (`prove_claw_stroke.exact_point`) of the left
   foot's leftmost vertex and the right foot's rightmost vertex. Their difference is a lower bound on the foot span;
   if it exceeds the deck depth on every key, no side-on station on T_{k-1} has footing: `TREAD_SIDE_FOOTING`.
2. **Paw spread (exact integers).** After the quarter turn the bearer runs along the mole's forward axis; its top is
   128 u wide across the mole. The approved contacts lie 256 u apart across the mole, so at most one can lie on the
   top: `TREAD_SIDE_PAW_SPREAD`.
3. **The best side-on station, proved anyway** (so the refusal is also the accepted prover's): facing -x, with
   both contacts' forward reach (448 u) at the bearer's centre along its length (x_s = 0 + 448), and the feet
   centred on the deck's depth (z_s = deck centre + the feet's lateral centre, rounded to the nearest unit). The
   fixture is turned into the mole frame exactly and `prove_paw_seat.world` runs on the seat and tap work clips.
4. **The quarter turn (float diagnostic).** The ready feet's z extent as the body turns from yaw 0 to 90 degrees
   about the root: the largest yaw at which the feet still fit the deck's depth.

Writes `station.json` to the output directory. Exit status 2 when the station is refused (the expected result).

    $PY .../derive_tread_side_station.py <out-dir>
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import json
import math
from pathlib import Path
import sys

import numpy as np

import author_paw_seat as SEAT
import prove_claw_pair as PAIRPROOF
import prove_paw_seat as PAWPROOF
import prove_tread_seat as TREADSEAT

W, SRC, ONE, T = SEAT.W, SEAT.SRC, PAWPROOF.ONE, PAIRPROOF.T
FLIGHT = TREADSEAT.TREAD
CANDIDATE = SRC.HERE / "evidence/paw-seat-v1/candidate-a"
QUARTER_YAW = 16384  # The published quarter turn (`claw_source.quarter`): facing -x.
SITES = {"tread": {"tread": 3, "plane": SEAT.PLANE_U},  # representative T_k of T1...T5, fitted from T_{k-1}
         "sill": {"tread": 6, "plane": TREADSEAT.SILL_PLANE_U}}  # the T6 sill (ADR 1209 D1), fitted from T5
LEFT_FOOT, RIGHT_FOOT = 0, 1  # `T.foot_membership` order: the -x (left) foot first.


def u(value: Fraction) -> Fraction:
    """Metres to units."""
    return value * 1024


def to_world(points: np.ndarray, station: tuple, yaw_degrees: float = 90.) -> np.ndarray:
    """Mole-local points placed at a station, turned by yaw about the root (90 = the published quarter turn)."""
    angle = math.radians(yaw_degrees)
    c, s = math.cos(angle), math.sin(angle)
    x, z = points[:, 0], points[:, 2]
    return np.stack((c * x + s * z + station[0], points[:, 1], -s * x + c * z + station[1]), axis=1)


def box_to_local(box: list, station: tuple) -> list:
    """The exact inverse of the quarter turn for an axis-aligned box: local x = -(z - z_s), local z = x - x_s."""
    x0, y0, z0, x1, y1, z1 = box
    return [-(z1 - station[1]), y0, x0 - station[0], -(z0 - station[1]), y1, x1 - station[0]]


def trench_walls(tread: int, fixture: dict) -> list:
    """The side walls beside T_{k-1}, station-local, from the prefix cut groups, up to the surface."""
    packet = PAWPROOF.P.content.read_json(FLIGHT.PREFIX, FLIGHT.I.PREFIX_SHA, 65536)
    cut = packet["cut_groups"][0]["bounds_u"]
    W.require(cut[0] == -1024 and cut[3] == 1024 and cut[4] == 0, "TREAD_SIDE_TRENCH")
    solids = fixture["solids_u"]
    z0, z1 = min(b[2] for b in solids) - FLIGHT.DECK_DEPTH, max(b[5] for b in solids)
    floor, top = FLIGHT.FLOOR_LOCAL, 128 * tread
    return [[cut[0] - 1024, floor, z0, cut[0], top, z1], [cut[3], floor, z0, cut[3] + 1024, top, z1]]


def foot_extremes(src: dict, sets: dict, case: dict, frame: int) -> tuple:
    """The left foot's leftmost and the right foot's rightmost vertex at one key (chosen in float)."""
    points = SRC.I.points_at(case, src["body"], frame)
    left = np.unique(src["triangles"][sets["feet"][LEFT_FOOT]])
    right = np.unique(src["triangles"][sets["feet"][RIGHT_FOOT]])
    return int(left[np.argmin(points[left, 0])]), int(right[np.argmax(points[right, 0])])


def footing(src: dict, sets: dict, clips: dict) -> dict:
    """The exact foot span on every key of every clip the side-on station would play."""
    narrowest, rows = None, {}
    for name, case in clips.items():
        spans = []
        for frame in range(case["frames"]):
            left, right = foot_extremes(src, sets, case, frame)
            low, high = (u(ONE.exact_point(src, case, frame, v)[0]) for v in (left, right))
            spans.append(high - low)
            if narrowest is None or high - low < narrowest[0]:
                narrowest = (high - low, name, frame, left, right, low, high)
        rows[name] = {"keys": case["frames"], "min_span_u": float(min(spans)), "max_span_u": float(max(spans))}
    span, name, frame, left, right, low, high = narrowest
    return {"per_clip": rows, "narrowest": {"clip": name, "key": frame, "left_vertex": left, "right_vertex": right,
            "left_x_u": [low.numerator, low.denominator], "right_x_u": [high.numerator, high.denominator],
            "span_u": [span.numerator, span.denominator], "span_u_float": float(span)}, "span": span}


def ready_feet(src: dict, sets: dict) -> np.ndarray:
    """Every foot vertex at the ready key, in units."""
    points = SRC.I.points_at(src["stand"], src["body"], SRC.READY_FRAME)
    return points[np.unique(src["triangles"][sets["any_foot"]])]


def station_of(src: dict, sets: dict, fixture: dict, record: dict) -> tuple:
    """The best side-on station: contacts' reach at the bearer's centre, feet centred on the deck's depth."""
    deck, work = fixture["solids_u"][fixture["support_solid"]], fixture["solids_u"][fixture["workpiece_solid"]]
    reach = -int(record["contact_targets_u"]["right"][2])
    W.require(reach == -int(record["contact_targets_u"]["left"][2]) == 448, "TREAD_SIDE_REACH")
    feet = ready_feet(src, sets)
    lateral_centre = (float(feet[:, 0].min()) + float(feet[:, 0].max())) / 2
    x_s = (work[0] + work[3]) // 2 + reach
    z_s = int(math.floor((deck[2] + deck[5]) / 2 + lateral_centre + .5))
    return (x_s, z_s), {"bearer_centre_x_u": (work[0] + work[3]) // 2, "reach_u": reach,
                        "deck_centre_z_u": (deck[2] + deck[5]) / 2, "feet_lateral_centre_u": lateral_centre}


def turn_diagnostic(src: dict, sets: dict, deck: list) -> dict:
    """Float: the ready feet's z extent while the body turns about the root, 0 to 90 degrees."""
    feet = ready_feet(src, sets)
    depth, extents = deck[5] - deck[2], []
    for degrees in range(91):
        z = to_world(feet, (0, 0), degrees)[:, 2]
        extents.append(round(float(z.max() - z.min()), 1))
    fits = next((d - 1 for d, extent in enumerate(extents) if extent > depth), 90)
    return {"deck_depth_u": depth, "feet_z_extent_u_by_degree": extents, "largest_yaw_that_fits_degrees": fits,
            "z_extent_at_0_u": extents[0], "z_extent_at_90_u": extents[90], "max_z_extent_u": max(extents)}


def summary(result: dict) -> dict:
    """The accepted world prover's outcome, by kind."""
    rows = result["unresolved"]
    supports = [r for r in rows if r.get("kind") == "SUPPORT"]
    pairs = [r for r in rows if "solid" in r]
    return {"clear": result["clear"], "unresolved": len(rows), "stopped_at_limit": bool(result.get("stopped_at_limit")),
            "support_failures": len(supports), "first_support_intervals": sorted({r["interval"] for r in supports})[:8],
            "solids_met": sorted({r["solid"] for r in pairs}),
            "other": sorted({r.get("kind") for r in rows if "solid" not in r and r.get("kind") != "SUPPORT"})}


def contacts_world(record: dict, station: tuple, work: list) -> dict:
    """Where the approved contacts land after the quarter turn, and whether each lies on the bearer's top."""
    result = {}
    for side, point in record["contact_targets_u"].items():
        x_w, z_w = station[0] + int(point[2]), station[1] - int(point[0])
        on_top = work[0] < x_w < work[3] and work[2] < z_w < work[5]
        result[side] = {"world_xz_u": [x_w, z_w], "on_bearer_top": on_top}
    return result


def prove_site(src: dict, sets: dict, programs: dict, record: dict, label: str, spec: dict) -> dict:
    """The best side-on station at one site, with the accepted world prover on the seat and tap work clips."""
    _, fixture = TREADSEAT.site(spec["plane"])
    station, how = station_of(src, sets, fixture, record)
    walls = trench_walls(spec["tread"], fixture)
    solids = fixture["solids_u"] + walls
    labels = fixture["source_labels"] + ["trench side wall, -x", "trench side wall, +x"]
    local = dict(fixture, solids_u=[box_to_local(b, station) for b in solids], source_labels=labels)
    deck, work = fixture["solids_u"][fixture["support_solid"]], fixture["solids_u"][fixture["workpiece_solid"]]
    feet = to_world(ready_feet(src, sets), station)
    world = {name: summary(PAWPROOF.world(src, programs[name][0], local, sets, spec["plane"]))
             for name in ("seat", "tap")}
    return {"tread": spec["tread"], "plane_u": spec["plane"], "station_xz_u": list(station), "yaw": QUARTER_YAW,
            "station_derivation": how, "fixture_station_local": solids, "fixture_labels": labels,
            "ready_feet_world_z_u": [float(feet[:, 2].min()), float(feet[:, 2].max())],
            "deck_z_u": [deck[2], deck[5]], "feet_over_far_edge_u": float(deck[2] - feet[:, 2].min()),
            "feet_over_riser_u": float(feet[:, 2].max() - deck[5]),
            "contacts": contacts_world(record, station, work), "world_proof": world}


def derive(out: Path) -> dict:
    """The whole derivation and its proofs."""
    src = SEAT.corrected_source()
    record, programs = PAWPROOF.load(CANDIDATE, src)
    sets = PAIRPROOF.classes(src)
    _, fixture = TREADSEAT.site(SEAT.PLANE_U)
    deck, work = fixture["solids_u"][fixture["support_solid"]], fixture["solids_u"][fixture["workpiece_solid"]]
    depth = deck[5] - deck[2]
    W.require(depth == FLIGHT.DECK_DEPTH == 512, "TREAD_SIDE_DECK_DEPTH")
    clips = {"stand": src["stand"]}
    for name in ("seat", "tap"):
        clips[f"{name}_entry"], clips[f"{name}_work"] = programs[name][1], programs[name][0]
    feet = footing(src, sets, clips)
    spread = int(record["contact_targets_u"]["right"][0]) - int(record["contact_targets_u"]["left"][0])
    width = work[5] - work[2]
    refusals = []
    if feet["span"] > depth:
        refusals.append("TREAD_SIDE_FOOTING")
    if spread > width:
        refusals.append("TREAD_SIDE_PAW_SPREAD")
    result = {"schema": 1, "decision": ["1217", "1209"], "motion": "side-on paw seating station (step 2c)",
              "candidate": str(CANDIDATE.relative_to(SRC.ROOT)), "candidate_sha256": SRC.sha(CANDIDATE / "candidate.json"),
              "deck_depth_u": depth, "bearer_top_width_across_mole_u": width, "contact_spread_u": spread,
              "footing": {k: v for k, v in feet.items() if k != "span"},
              "feet_excess_over_deck_depth_u": float(feet["span"] - depth),
              "turn": turn_diagnostic(src, sets, deck),
              "sites": {label: prove_site(src, sets, programs, record, label, spec) for label, spec in SITES.items()},
              "refusals": refusals, "station_admitted": not refusals,
              "stand_sha256": src["stand_sha256"], "source_pins": src["pins"], "production_qualified": False,
              "producer_sources": {str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p) for p in
                                   (Path(__file__), Path(SEAT.__file__), Path(PAWPROOF.__file__),
                                    Path(TREADSEAT.__file__), Path(ONE.__file__), Path(FLIGHT.__file__))}}
    out.mkdir(parents=True)
    (out / "station.json").write_text(json.dumps(result, indent=1) + "\n")
    return result


def main() -> int:
    """Derive, prove and write the record."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    W.require(not args.out.exists(), "TREAD_SIDE_OUTPUT_EXISTS")
    result = derive(args.out)
    print(json.dumps({"refusals": result["refusals"], "foot_span_u": result["footing"]["narrowest"]["span_u_float"],
                      "deck_depth_u": result["deck_depth_u"], "contact_spread_u": result["contact_spread_u"],
                      "bearer_width_u": result["bearer_top_width_across_mole_u"],
                      "sites": {k: {"station": v["station_xz_u"], "contacts": v["contacts"],
                                    "world": v["world_proof"]} for k, v in result["sites"].items()}}, indent=1))
    return 0 if result["station_admitted"] else 2


if __name__ == "__main__":
    sys.exit(main())
