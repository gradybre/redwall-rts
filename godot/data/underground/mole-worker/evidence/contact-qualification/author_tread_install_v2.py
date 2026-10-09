#!/usr/bin/env python3
"""ADR 1209 step 4, revision 2: the tread install tap with the pick held as the accepted fitting motion holds it.

Brendan's review of revision 1 (`author_tread_install.py`, candidates v1–v3): the pick looked awkward. The handle
stood too steep (60°) and crossed the body. Revision 1's station, workpiece, fixture, planted legs, torso pitch,
tap keys, entry, recovery and every proof are reused unchanged from that module. One thing changes: **where the
elbow goes**.

`author_install_source.poll_pose` places the elbow on the original bend side (`knee_target`) and then turns the
forearm onto it. Close to the feet that bend side folds the forearm across the handle, so revision 1 had to
stand the handle up to clear it. Here the elbow is chosen instead on the circle of every elbow position that
keeps both arm links their exact length (the swivel). The chosen point is the one whose forearm direction, seen
from the hand, is closest to the accepted ready grip's. The wrist then keeps the accepted hand-to-forearm
relation as nearly as the reach allows, and the handle can lean as in the accepted motion (25–50°). Every other
line of the solver is the accepted one; the deviation that remains is recorded per key.

    $PY .../author_tread_install_v2.py <out> --x-u 240 --z-u -300 --lean-degrees 35 --azimuth-degrees 45 --torso-degrees 0
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
SPEC = importlib.util.spec_from_file_location("tread_install_v1", HERE / "author_tread_install.py")
V1 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V1)
I, M, P, S = V1.I, V1.M, V1.P, V1.S
LEAN_DOMAIN = (25, 50)
AZIMUTH_DOMAIN = (0, 90)
SWIVEL_SAMPLES = 720
require = V1.require


def tool_and_hand(ready: dict, tool: dict, rig: dict, point: list, lean: int, azimuth: int) -> tuple:
    """The accepted tool orientation and placement (`poll_pose`, lines unchanged), and the hand that holds it."""
    require(type(lean) is int and LEAN_DOMAIN[0] <= lean <= LEAN_DOMAIN[1] and type(azimuth) is int
            and AZIMUTH_DOMAIN[0] <= azimuth <= AZIMUTH_DOMAIN[1] and np.max(np.abs(point)) <= 2048, "POSE_INPUT")
    parents, inverse, inverse_inverse = I.A.hierarchy(rig)
    actual, _, fit = I.A.joints(ready, 8, parents, inverse_inverse)
    require([parents[18], parents[19]] == [17, 18], "ARM_HIERARCHY")
    matrix = P._affine64(ready["matrices"][8, 24])
    old_quaternion, _ = P._polar(matrix[:3, :3])
    old_rotation = P._rotation(old_quaternion)
    angle, turn = np.deg2rad(lean), np.deg2rad(azimuth)
    x_axis, y_axis = np.array([0., np.sin(angle), np.cos(angle)]), np.array([-1., 0., 0.])
    outward = np.array([[np.cos(turn), 0, np.sin(turn)], [0, 1, 0], [-np.sin(turn), 0, np.cos(turn)]])
    desired = outward @ np.stack((x_axis, y_axis, np.cross(x_axis, y_axis)), axis=1)
    matrix[:3, :3] = desired @ old_rotation.T @ matrix[:3, :3]
    source = np.asarray(tool["geometry"][0]["points"][I.POLL_VERTEX], dtype=np.float64)
    grounded = np.asarray(point, dtype=np.float64) / 1024
    grounded[1] -= float(ready["grounding"][8])
    matrix[:3, 3] = grounded - matrix[:3, :3] @ source
    return actual, inverse, fit, matrix @ np.linalg.inv(fit)


def swivel_elbow(shoulder: np.ndarray, target: np.ndarray, upper: float, lower: float, wanted: np.ndarray) -> tuple:
    """The elbow on the exact-length circle whose forearm direction is closest to `wanted` (a unit vector)."""
    vector = target - shoulder
    distance = float(np.linalg.norm(vector))
    require(abs(upper - lower) + 1e-7 < distance < upper + lower - 1e-7, "ARM_REACH")
    axis = vector / distance
    along = (upper * upper - lower * lower + distance * distance) / (2 * distance)
    radius = float(np.sqrt(max(0., upper * upper - along * along)))
    first = np.cross(axis, [0., 1., 0.] if abs(axis[1]) < .9 else [1., 0., 0.])
    first /= np.linalg.norm(first)
    second = np.cross(axis, first)
    angles = np.linspace(0, 2 * np.pi, SWIVEL_SAMPLES, endpoint=False)
    elbows = shoulder + along * axis + radius * (np.cos(angles)[:, None] * first + np.sin(angles)[:, None] * second)
    forearms = (target - elbows) / lower
    best = int(np.argmax(forearms @ wanted))
    deviation = float(np.degrees(np.arccos(np.clip(forearms[best] @ wanted, -1, 1))))
    return elbows[best], deviation


def swivel_pose(ready: dict, tool: dict, rig: dict, point: list, lean: int, azimuth: int) -> tuple:
    """`poll_pose` with the wrist-preserving swivel elbow; the limb-closing rotations are the accepted ones."""
    actual, inverse, fit, hand = tool_and_hand(ready, tool, rig, point, lean, azimuth)
    shoulder, elbow, wrist = [actual[index][:3, 3] for index in (17, 18, 19)]
    target = hand[:3, 3]
    hand_turn = hand[:3, :3] @ np.linalg.inv(actual[19][:3, :3])
    wanted = hand_turn @ (wrist - elbow)
    wanted /= np.linalg.norm(wanted)
    middle, deviation = swivel_elbow(shoulder, target, float(np.linalg.norm(elbow - shoulder)),
                                     float(np.linalg.norm(wrist - elbow)), wanted)
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
    return result, {"maximum_link_length_error_m": float(error), "wrist_deviation_degrees": deviation,
                    "hand_origin_u": ((hand[:3, 3] + [0, ready["grounding"][8], 0]) * 1024).tolist(),
                    "poll_u": I.prop_points(result, 0, tool)[I.POLL_VERTEX].tolist()}


def source_motion(ready: dict, tool: dict, rig: dict, recipe: dict) -> tuple:
    """Revision 1's tap keys and planted entry/recovery, posed with the swivel elbow."""
    frames, diagnostics = [], []
    base = V1.pitched_ready(ready, rig, recipe["torso_degrees"])
    for at in range(17):
        share = at / 16
        height = V1.PLANE_U + 80 - (82 * share * share * (3 - 2 * share))
        pose, facts = swivel_pose(base, tool, rig, [recipe["x_u"], height, recipe["z_u"]],
                                  recipe["lean_degrees"], recipe["azimuth_degrees"])
        frames.append(pose["matrices"][0])
        diagnostics.append(facts)
    work = dict(ready, id="mole_worker.install_tread.tap_v2", frames=33, source_loop_mode=0,
                source_duration_s=Fraction(32, 30), duration_q16=32 * 65536,
                matrices=np.stack(frames + frames[-2::-1]),
                grounding=np.full(33, ready["grounding"][8], dtype=np.float32))
    entry = I.A.planted_entry(ready, work, rig, 31)
    entry["id"] = "mole_worker.install_tread.entry_v2"
    recovery = P.indexed_sequence(entry, list(range(30, -1, -1)), "mole_worker.install_tread.recovery_v2", False)
    return [work, entry, recovery], diagnostics


def main() -> int:
    """Author one revision-2 candidate, prove it with revision 1's unchanged proofs, and write it."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    for name in ("x-u", "z-u", "lean-degrees", "azimuth-degrees", "torso-degrees"):
        parser.add_argument("--" + name, type=int, required=True)
    args = parser.parse_args()
    require(not args.out.exists(), "OUTPUT_EXISTS")
    require(-256 < args.x_u < 256 and -V1.STATION_D < args.z_u < -V1.STATION_D + 128, "TARGET_OFF_WORKPIECE")
    recipe = {"x_u": args.x_u, "z_u": args.z_u, "lean_degrees": args.lean_degrees,
              "azimuth_degrees": args.azimuth_degrees, "torso_degrees": args.torso_degrees,
              "elbow_rule": "wrist_preserving_swivel", "contact_plane_y_u": V1.PLANE_U, "poll_y_u": [208, 126, 208]}
    M.W.snapshot_sources = V1.FLIGHT.historical_snapshot
    packet = P.content.read_json(V1.PREFIX, I.PREFIX_SHA, 65536)
    original, parts, rig, topology, roots, sources, historical = M.read_actual_source()
    bounds = V1.station_bounds(original[0], parts)
    station = V1.fixture(packet, V1.STATION_D)
    cases, diagnostics = source_motion(original[0], parts[1], rig, recipe)
    result = V1.prove(cases, parts, topology, rig, roots, station, recipe)
    paths = [Path(__file__), Path(V1.__file__), Path(V1.V4.__file__), Path(I.__file__), Path(V1.FLIGHT.__file__), V1.PREFIX]
    pins = {str(p.resolve().relative_to(P.ROOT)): P.content.file_hash(p) for p in paths}
    report = {"schema": 1, "decision": "1209", "revision": 2, "station": bounds, "station_root_local_u": [0, 0, 0],
              "station_from_far_edge_u": V1.STATION_D, "fixture": station, "source_recipe": recipe,
              "poll_source_vertex": I.POLL_VERTEX, "pose_solver_diagnostics": diagnostics,
              "wall_margin": V1.extents(cases, parts), "producer_sources": pins,
              "verified_source_files": sources, "historical_source_snapshot": historical,
              "remaining": ["BRENDAN_REVIEW", "ARRIVAL_REPOSITION_FROM_DESCENT_END", "T6_SILL_WORKPIECE_PLANE_64",
                            "HANDLING_PROGRAM", "NATIVE_CAPTURE", "INTEGER_ROWS_AND_CONTENT_7"],
              "production_qualified": False}
    V1.encode(args.out, cases, report, roots)
    with (args.out / "proof.json").open("x") as stream:
        json.dump({"schema": 1, "decision": "1209", "revision": 2, "clear": result["clear"], **result,
                   "production_qualified": False}, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"clear": result["clear"], "contacts": [row["anchor_u"] for row in result["contacts"]],
                      "wrist_deviation_max_degrees": max(d["wrist_deviation_degrees"] for d in diagnostics)}))
    return 0 if result["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
