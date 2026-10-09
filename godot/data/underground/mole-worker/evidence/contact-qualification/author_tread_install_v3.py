#!/usr/bin/env python3
"""ADR 1209 step 4, revision 3: the hand meets the handle as in the accepted fitting motion's contact pose.

Brendan's review of revision 2 (`author_tread_install_v2.py`): the grip looked strange. The hand's orientation
on the shaft read wrong; it should wrap the handle from the side, thumb toward the head, as a held pick does,
not hold its end from above.

The hand-to-pick fit is rigid in every revision (the source's own grip; no regrip). What changes how the fist
reads is the wrist: where the forearm enters the hand. Revision 2 chose the elbow so the forearm entered as in
the *ready* carry. The ready carry holds the pick up and forward, so with the head lowered to strike, the
forearm came down onto the fist from above. The accepted fitting motion (`install-source-v4`) strikes downward
with its wrist bent the other way: the forearm runs forward into the side of the fist and the shaft leaves it
down toward the head.

Revision 3 keeps revision 2's swivel elbow but aims it at **the accepted contact key's wrist** (v4 work key 16):
the forearm direction seen from the hand there, read from the pinned v4 image. With v4's own handle lean and
azimuth (35°, 30°) the hand, wrist and pick then sit as in v4 wherever the arm can reach it. Everything else is
revision 2's or revision 1's, unchanged, including every proof. The remaining wrist difference from v4 is
recorded per key.

    $PY .../author_tread_install_v3.py <out> --x-u 208 --z-u -300 --lean-degrees 35 --azimuth-degrees 30 --torso-degrees -15
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("tread_install_v2", HERE / "author_tread_install_v2.py")
V2 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V2)
V1, I, M, P, S = V2.V1, V2.I, V2.M, V2.P, V2.S
ACCEPTED = HERE / "install-source-v4"
ACCEPTED_CONTACT_KEY = 16
require = V2.require


def accepted_forearm(parts: list, rig: dict) -> np.ndarray:
    """The unit elbow-to-wrist direction in the hand's frame at v4's contact key, from the pinned v4 image."""
    compiled = json.loads((ACCEPTED / "compilation.json").read_text())
    cases = S.read_image(ACCEPTED / "mole-worker.ugactor", compiled["content_sha256"], parts)
    parents, _, inverse_inverse = I.A.hierarchy(rig)
    actual, _, _ = I.A.joints(cases[0], ACCEPTED_CONTACT_KEY, parents, inverse_inverse)
    local = np.linalg.inv(actual[19][:3, :3]) @ (actual[19][:3, 3] - actual[18][:3, 3])
    return local / np.linalg.norm(local)


ROLL_DOMAIN = (-90, 90)


def rolled(hand: np.ndarray, fit: np.ndarray, point: list, ready: dict, roll: int) -> np.ndarray:
    """Turn the pick and the hand that holds it about the handle's own axis, through the adze contact point.

    Roll 0 is the accepted orientation. The hand-to-pick fit stays rigid, so the fist turns around the handle
    with it; the adze end (vertex 478) stays exactly on its contact point.
    """
    require(type(roll) is int and ROLL_DOMAIN[0] <= roll <= ROLL_DOMAIN[1], "ROLL_INPUT")
    if roll == 0:
        return hand
    matrix = hand @ fit
    axis = matrix[:3, 0] / np.linalg.norm(matrix[:3, 0])
    angle = np.deg2rad(roll)
    skew = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
    turn = np.eye(3) + np.sin(angle) * skew + (1 - np.cos(angle)) * skew @ skew
    centre = np.asarray(point, dtype=np.float64) / 1024
    centre[1] -= float(ready["grounding"][8])
    result = matrix.copy()
    result[:3, :3] = turn @ matrix[:3, :3]
    result[:3, 3] = centre + turn @ (matrix[:3, 3] - centre)
    return result @ np.linalg.inv(fit)


def matched_pose(ready: dict, tool: dict, rig: dict, point: list, lean: int, azimuth: int, forearm: np.ndarray,
                 roll: int = 0) -> tuple:
    """Revision 2's swivel pose with the elbow aimed at the accepted contact wrist instead of the ready carry's."""
    actual, inverse, fit, hand = V2.tool_and_hand(ready, tool, rig, point, lean, azimuth)
    hand = rolled(hand, fit, point, ready, roll)
    shoulder, elbow, wrist = [actual[index][:3, 3] for index in (17, 18, 19)]
    target = hand[:3, 3]
    wanted = hand[:3, :3] @ forearm
    middle, deviation = V2.swivel_elbow(shoulder, target, float(np.linalg.norm(elbow - shoulder)),
                                        float(np.linalg.norm(wrist - elbow)), wanted / np.linalg.norm(wanted))
    hand_turn = hand[:3, :3] @ np.linalg.inv(actual[19][:3, :3])
    moved = [row.copy() for row in actual]
    close_forearm = I.G.rotation_between(hand_turn @ (wrist - elbow), target - middle)
    moved[18][:3, :3] = close_forearm @ hand_turn @ actual[18][:3, :3]
    moved[18][:3, 3] = middle
    forearm_turn = moved[18][:3, :3] @ np.linalg.inv(actual[18][:3, :3])
    close_upper = I.G.rotation_between(forearm_turn @ (elbow - shoulder), middle - shoulder)
    moved[17][:3, :3] = close_upper @ forearm_turn @ actual[17][:3, :3]
    moved[17][:3, 3] = shoulder
    moved[19] = hand
    result = dict(ready, frames=1, matrices=ready["matrices"][8:9].copy(), grounding=ready["grounding"][8:9].copy())
    I.A.put_pose(result, 0, moved, inverse, fit, ready)
    error = max(abs(np.linalg.norm(middle - shoulder) - np.linalg.norm(elbow - shoulder)),
                abs(np.linalg.norm(target - middle) - np.linalg.norm(wrist - elbow)))
    require(error < 1e-10, "ARM_LENGTH_DRIFT")
    return result, {"maximum_link_length_error_m": float(error), "wrist_deviation_from_v4_degrees": deviation,
                    "hand_origin_u": ((hand[:3, 3] + [0, ready["grounding"][8], 0]) * 1024).tolist(),
                    "poll_u": I.prop_points(result, 0, tool)[I.POLL_VERTEX].tolist()}


def source_motion(ready: dict, tool: dict, rig: dict, recipe: dict, parts: list) -> tuple:
    """Revision 1's tap keys and planted entry/recovery, posed with the v4-matched wrist."""
    forearm = accepted_forearm(parts, rig)
    frames, diagnostics = [], []
    base = V1.pitched_ready(ready, rig, recipe["torso_degrees"])
    for at in range(17):
        share = at / 16
        height = V1.PLANE_U + 80 - (82 * share * share * (3 - 2 * share))
        pose, facts = matched_pose(base, tool, rig, [recipe["x_u"], height, recipe["z_u"]],
                                   recipe["lean_degrees"], recipe["azimuth_degrees"], forearm,
                                   recipe["roll_degrees"])
        frames.append(pose["matrices"][0])
        diagnostics.append(facts)
    work = dict(ready, id="mole_worker.install_tread.tap_v3", frames=33, source_loop_mode=0,
                source_duration_s=Fraction(32, 30), duration_q16=32 * 65536,
                matrices=np.stack(frames + frames[-2::-1]),
                grounding=np.full(33, ready["grounding"][8], dtype=np.float32))
    entry = I.A.planted_entry(ready, work, rig, 31)
    entry["id"] = "mole_worker.install_tread.entry_v3"
    recovery = P.indexed_sequence(entry, list(range(30, -1, -1)), "mole_worker.install_tread.recovery_v3", False)
    return [work, entry, recovery], diagnostics, forearm


def main() -> int:
    """Author one revision-3 candidate, prove it with revision 1's unchanged proofs, and write it."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    for name in ("x-u", "z-u", "lean-degrees", "azimuth-degrees", "torso-degrees", "roll-degrees"):
        parser.add_argument("--" + name, type=int, required=True)
    args = parser.parse_args()
    require(not args.out.exists(), "OUTPUT_EXISTS")
    require(-256 < args.x_u < 256 and -V1.STATION_D < args.z_u < -V1.STATION_D + 128, "TARGET_OFF_WORKPIECE")
    recipe = {"x_u": args.x_u, "z_u": args.z_u, "lean_degrees": args.lean_degrees,
              "azimuth_degrees": args.azimuth_degrees, "torso_degrees": args.torso_degrees,
              "roll_degrees": args.roll_degrees, "elbow_rule": "swivel_matching_accepted_contact_wrist", "contact_plane_y_u": V1.PLANE_U,
              "poll_y_u": [208, 126, 208]}
    M.W.snapshot_sources = V1.FLIGHT.historical_snapshot
    packet = P.content.read_json(V1.PREFIX, I.PREFIX_SHA, 65536)
    original, parts, rig, topology, roots, sources, historical = M.read_actual_source()
    station = V1.fixture(packet, V1.STATION_D)
    cases, diagnostics, forearm = source_motion(original[0], parts[1], rig, recipe, parts)
    result = V1.prove(cases, parts, topology, rig, roots, station, recipe)
    paths = [Path(__file__), Path(V2.__file__), Path(V1.__file__), Path(V1.V4.__file__), Path(I.__file__),
             Path(V1.FLIGHT.__file__), V1.PREFIX, ACCEPTED / "mole-worker.ugactor", ACCEPTED / "compilation.json"]
    pins = {str(p.resolve().relative_to(P.ROOT)): P.content.file_hash(p) for p in paths}
    report = {"schema": 1, "decision": "1209", "revision": 3, "station": V1.station_bounds(original[0], parts),
              "station_root_local_u": [0, 0, 0], "station_from_far_edge_u": V1.STATION_D, "fixture": station,
              "source_recipe": recipe, "accepted_contact_forearm_in_hand": forearm.tolist(),
              "poll_source_vertex": I.POLL_VERTEX, "pose_solver_diagnostics": diagnostics,
              "wall_margin": V1.extents(cases, parts), "producer_sources": pins,
              "verified_source_files": sources, "historical_source_snapshot": historical,
              "remaining": ["BRENDAN_REVIEW", "ARRIVAL_REPOSITION_FROM_DESCENT_END", "T6_SILL_WORKPIECE_PLANE_64",
                            "HANDLING_PROGRAM", "NATIVE_CAPTURE", "INTEGER_ROWS_AND_CONTENT_7"],
              "production_qualified": False}
    V1.encode(args.out, cases, report, roots)
    with (args.out / "proof.json").open("x") as stream:
        json.dump({"schema": 1, "decision": "1209", "revision": 3, "clear": result["clear"], **result,
                   "production_qualified": False}, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"clear": result["clear"], "contacts": [row["anchor_u"] for row in result["contacts"]],
                      "wrist_from_v4_max_degrees": max(d["wrist_deviation_from_v4_degrees"] for d in diagnostics)}))
    return 0 if result["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
