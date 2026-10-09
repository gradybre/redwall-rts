#!/usr/bin/env python3
"""ADR 1217 step 1 (M1): the downward claw stroke for BRACE, CUT and FINISH on a cube's top face. Source only.

One program serves all three paid phases, as the pick's downward program did (ADR 1188). It is authored at yaw 0
from the tool-free open-paw closure (`claw_source.py`), for the Frontier's first episode: cube 0, worked from
station 4, 512 u behind its near face.

The pose reuses accepted recipes; only the claw path is new:

- **Planted lower body.** The tool-free stand key 8 (ADR 1199) with ADR 1144's hip drop (`squatted_hub`: the
  ankles and toes keep their exact transforms; the knees re-solve with unchanged leg lengths).
- **Torso lean.** ADR 1144's rigid lean of bones 9–23 about Spine02.
- **Right arm.** The accepted fixed-length two-link solve with its forearm-roll closing (`author_install_source.
  poll_pose`), aimed so that the claw tip, not a tool, meets the target. The hand turns as one rigid frame: claws
  (hand-local +Y) pointing down and forward by `tilt`, rolled about the claws by `roll` (0: palm toward the body).
- **Claw tip.** The open paw's distal-most right-hand vertex along the finger axis, derived from the mesh.
- **Stroke.** A closed 33-key loop in the sagittal plane: from above the face, forward and down through the face
  at the anchor, raking back below it, and up through the face behind the anchor. The left arm keeps the leaned
  pose. The root grounding stays the ready key's, so the soles stay planted.
- **Entry.** 31 keys from ready key 8: the drop and lean grow by smoothstep while the claw tip travels straight
  from its ready point to the stroke's first target and the hand turns by the shortest rotation; the same arm solve
  runs on every key. Recovery is the exact reverse.

Nothing here grants work, a profile row or World permission. `prove_claw_stroke.py` holds the exact proofs.

    $PY .../author_claw_stroke.py <out> --x-u 128 --anchor-z-u -608 --rake-u 32 --lean-degrees 60 \
        --drop-u 96 --tilt-degrees 60 --roll-degrees 90 --station-inset-u 106
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import io
import json
from pathlib import Path
import sys
import zipfile

import numpy as np

import claw_source as SRC

A = SRC.A
RIG = A.RIG
require = SRC.require
sys.path.insert(0, str(SRC.MOLE / "haul-handling-v1"))
import author_program as LIFT  # noqa: E402

WORK_KEYS = 33
ENTRY_KEYS = 31
TOP_U = 80  # Claw height above the face at the loop top: the accepted fitting tap raises its poll 208 − 128 = 80 u.
DEPTH_U = 60  # Claw depth below the face: the accepted downward stroke's below-face stroke box reaches y = −60 (row 13).
RIGHT_ARM = (17, 18, 19)
ZIP_TIME = (1980, 1, 1, 0, 0, 0)
DOMAINS = {"x_u": (-256, 256), "anchor_z_u": (-768, -520), "rake_u": (16, 192), "lean_degrees": (0, 90),
           "drop_u": (0, 176), "tilt_degrees": (0, 120),
           "roll_degrees": (0, 345), "station_inset_u": (0, 106)}


def claw_vertex(src: dict) -> tuple:
    """The right paw's distal-most vertex along hand-local +Y (lowest index on ties) and its hand-local point."""
    geometry = src["body"]["geometry"][0]
    dominant = geometry["ids"][np.arange(len(geometry["ids"])), np.argmax(geometry["weights"], axis=1)]
    hand = int(src["rig"]["right_hand"])
    bind = affine_of(src["rig"]["bones"][hand]["inverse_bind"])
    local = geometry["points"].astype(np.float64) @ bind[:3, :3].T + bind[:3, 3]
    candidates = np.flatnonzero(dominant == hand)
    best = float(local[candidates, 1].max())
    vertex = int(candidates[local[candidates, 1] == best].min())
    return vertex, local[vertex]


def affine_of(raw: list) -> np.ndarray:
    """A 12-scalar packed bone matrix as a 4x4 affine."""
    return SRC.I.affine(np.asarray(raw, dtype=np.float64))


def lean(pose: list, degrees: float) -> list:
    """ADR 1144's rigid forward lean of bones 9-23 about Spine02 (author_handling.contact_pose)."""
    angle = -np.deg2rad(degrees)
    turn = np.array([[1., 0., 0.], [0., np.cos(angle), -np.sin(angle)], [0., np.sin(angle), np.cos(angle)]])
    rotation = np.eye(4)
    rotation[:3, :3] = turn
    pivot = pose[9][:3, 3]
    rotation[:3, 3] = pivot - turn @ pivot
    return [value.copy() if at < 9 else rotation @ value for at, value in enumerate(pose)]


def squat(hub: list, drop_u: float) -> list:
    """`author_handling.squatted_hub` for a fractional drop (entry keys); the work pose uses the original."""
    moved = [row.copy() for row in hub]
    if drop_u == 0:
        return moved
    for row in moved:
        row[1, 3] -= drop_u / 1024
    for hip, knee, ankle, toe in ((1, 2, 3, 4), (5, 6, 7, 8)):
        start, target = moved[hip][:3, 3], hub[ankle][:3, 3]
        middle = RIG.knee_target(start, moved[knee][:3, 3], moved[ankle][:3, 3], target)
        for bone, old_start, old_end, final_start, final_end in (
                (hip, hub[hip][:3, 3], hub[knee][:3, 3], start, middle),
                (knee, hub[knee][:3, 3], hub[ankle][:3, 3], middle, target)):
            moved[bone][:3, :3] = RIG.rotation_between(old_end - old_start, final_end - final_start) @ hub[bone][:3, :3]
            moved[bone][:3, 3] = final_start
        moved[ankle], moved[toe] = hub[ankle].copy(), hub[toe].copy()
    return moved


def posture(src: dict, drop_u: float, lean_degrees: float) -> tuple:
    """Hip drop, then ADR 1144's sole planting (`plant_soles`: each ankle moves only vertically until its lowest
    anatomical sole vertex sits 1/512 u above the floor again), then the torso lean."""
    pose = A.squatted_hub(src["hub"], drop_u) if type(drop_u) is int else squat(src["hub"], drop_u)
    planted, facts = A.plant_soles(pose, np.eye(4), src["inverse"], float(src["grounding"]), src["body"],
                                   src["topology"])
    return lean(planted, lean_degrees), facts


def hand_rotation(old: np.ndarray, tilt_degrees: float, roll_degrees: float) -> np.ndarray:
    """A proper rotation of the hand frame: claws (+Y) down and forward by `tilt`, rolled about the claws.

    Roll 0 turns the palm (+Z) toward the body; roll 180 turns it away, so the claws' curl leads into the face.
    Left multiplication keeps the native basis Gram matrix, as the accepted poll solve does.
    """
    unit, _, rows = np.linalg.svd(old[:3, :3])
    current = unit @ rows
    tilt, roll = np.deg2rad(tilt_degrees), np.deg2rad(roll_degrees)
    fingers = np.array([0., -np.cos(tilt), -np.sin(tilt)])
    toward_body = np.array([0., -np.sin(tilt), np.cos(tilt)])
    palm = np.cos(roll) * toward_body + np.sin(roll) * np.cross(fingers, toward_body)
    desired = np.stack((np.cross(fingers, palm), fingers, palm), axis=1)
    return desired @ current.T @ old[:3, :3]


def solve_arm(pose: list, rotation: np.ndarray, claw_local: np.ndarray, target_u: np.ndarray,
              grounding: float) -> tuple:
    """Put the claw tip on `target_u` with the hand turned to `rotation`, by the accepted fixed-length arm solve
    and forearm closing (`author_install_source.poll_pose`)."""
    shoulder_bone, elbow_bone, wrist_bone = RIGHT_ARM
    hand = pose[wrist_bone].copy()
    hand[:3, :3] = rotation
    goal = np.asarray(target_u, dtype=np.float64) / 1024
    goal[1] -= grounding
    hand[:3, 3] = goal - rotation @ claw_local
    shoulder, elbow, wrist = [pose[at][:3, 3] for at in RIGHT_ARM]
    target = hand[:3, 3]
    middle = RIG.knee_target(shoulder, elbow, wrist, target)
    moved = [row.copy() for row in pose]
    hand_turn = rotation @ np.linalg.inv(pose[wrist_bone][:3, :3])
    close = RIG.rotation_between(hand_turn @ (wrist - elbow), target - middle)
    moved[elbow_bone][:3, :3] = close @ hand_turn @ pose[elbow_bone][:3, :3]
    moved[elbow_bone][:3, 3] = middle
    turn = moved[elbow_bone][:3, :3] @ np.linalg.inv(pose[elbow_bone][:3, :3])
    upper = RIG.rotation_between(turn @ (elbow - shoulder), middle - shoulder)
    moved[shoulder_bone][:3, :3] = upper @ turn @ pose[shoulder_bone][:3, :3]
    moved[wrist_bone] = hand
    error = max(abs(np.linalg.norm(middle - shoulder) - np.linalg.norm(elbow - shoulder)),
                abs(np.linalg.norm(target - middle) - np.linalg.norm(wrist - elbow)))
    require(error < 1e-10, "CLAW_ARM_LENGTH_DRIFT")
    return moved, error


def reach(pose: list, claw_local: np.ndarray, target_u: np.ndarray, recipe: dict, grounding: float) -> tuple:
    """`solve_arm` with the recipe's hand frame (tilt and roll)."""
    rotation = hand_rotation(pose[RIGHT_ARM[2]], recipe["tilt_degrees"], recipe["roll_degrees"])
    return solve_arm(pose, rotation, claw_local, target_u, grounding)


def claw_point_u(pose: list, claw_local: np.ndarray, grounding: float) -> np.ndarray:
    """The claw tip of a pose, in u."""
    hand = pose[RIGHT_ARM[2]]
    return (hand[:3, :3] @ claw_local + hand[:3, 3] + [0., grounding, 0.]) * 1024


def loop_targets(recipe: dict) -> list:
    """33 claw-tip targets on a closed ellipse: top, forward-down through the anchor, back below, up, top.

    The face crossings are exactly the anchor (descending) and anchor + rake (ascending).
    """
    centre_y = (TOP_U - DEPTH_U) / 2
    radius_y = (TOP_U + DEPTH_U) / 2
    cosine = np.sqrt(1 - (centre_y / radius_y) ** 2)
    centre_z = recipe["anchor_z_u"] + recipe["rake_u"] / 2
    radius_z = recipe["rake_u"] / 2 / cosine
    result = []
    for key in range(WORK_KEYS):
        angle = np.pi / 2 + 2 * np.pi * (key % (WORK_KEYS - 1)) / (WORK_KEYS - 1)
        result.append(np.array([recipe["x_u"], centre_y + radius_y * np.sin(angle),
                                centre_z + radius_z * np.cos(angle)]))
    return result


def case_of(palettes: list, grounding: np.float32, case_id: str) -> dict:
    """A linear clip with the ready grounding on every key."""
    count = len(palettes)
    return {"id": case_id, "frames": count, "matrices": np.asarray(palettes, dtype=np.float32),
            "grounding": np.full(count, grounding, dtype=np.float32), "source_loop_mode": 0,
            "source_duration_s": Fraction(count - 1, 30), "duration_q16": (count - 1) * 65536}


def work_clip(src: dict, recipe: dict) -> tuple:
    """The 33-key stroke loop and its per-key solver facts; key 32 repeats key 0 exactly."""
    vertex, claw_local = claw_vertex(src)
    base, _ = posture(src, recipe["drop_u"], recipe["lean_degrees"])
    palettes, poses, facts = [], [], []
    for key, target in enumerate(loop_targets(recipe)[:-1]):
        pose, error = reach(base, claw_local, target, recipe, float(src["grounding"]))
        poses.append(pose)
        palettes.append(A.encoded(pose, src["inverse"]))
        facts.append({"key": key, "claw_target_u": [round(float(v), 4) for v in target],
                      "maximum_link_length_error_m": float(error)})
    palettes.append(palettes[0].copy())
    return case_of(palettes, src["grounding"], "mole_worker.claw_dig.stroke_v1"), poses[0], facts, vertex


def entry_clip(src: dict, recipe: dict, first: list) -> dict:
    """Ready key 8 to the stroke's first key, by smoothstep share: the drop and lean grow, the claw tip moves on
    the straight line from its ready point to the stroke's first target, and the hand turns by the shortest
    rotation (`author_program.rotation_blend`); the arm is solved on every key."""
    _, claw_local = claw_vertex(src)
    grounding = float(src["grounding"])
    hand = RIGHT_ARM[2]
    start, finish = claw_point_u(src["hub"], claw_local, grounding), claw_point_u(first, claw_local, grounding)
    palettes = []
    for key in range(ENTRY_KEYS):
        share = key / (ENTRY_KEYS - 1)
        share = share * share * (3 - 2 * share)
        pose, _ = posture(src, recipe["drop_u"] * share, recipe["lean_degrees"] * share)
        rotation = LIFT.rotation_blend(src["hub"][hand][:3, :3], first[hand][:3, :3], share)
        pose, _ = solve_arm(pose, rotation, claw_local, start * (1 - share) + finish * share, grounding)
        palettes.append(A.encoded(pose, src["inverse"]))
    palettes[0] = src["stand"]["matrices"][SRC.READY_FRAME].copy()
    palettes[-1] = A.encoded(first, src["inverse"])
    return case_of(palettes, src["grounding"], "mole_worker.claw_dig.entry_v1")


def target_cube(src: dict, recipe: dict) -> list:
    """The first episode's cube relative to the station, moved toward the worker by the station inset."""
    cube = list(src["target"]["cube_local_u"])
    cube[2] += recipe["station_inset_u"]
    cube[5] += recipe["station_inset_u"]
    return cube


def author(src: dict, recipe: dict) -> tuple:
    """Stroke, entry and its exact reverse as recovery, plus the authoring record."""
    for name, (low, high) in DOMAINS.items():
        require(type(recipe[name]) is int and low <= recipe[name] <= high, "CLAW_RECIPE_" + name.upper())
    require(recipe["station_inset_u"] <= SRC.stance_inset_limit(), "CLAW_STATION_INSET")
    cube = target_cube(src, recipe)
    require(cube[2] < recipe["anchor_z_u"] and recipe["anchor_z_u"] + recipe["rake_u"] < cube[5] and
            cube[0] < recipe["x_u"] < cube[3], "CLAW_TARGET_OFF_FACE")
    work, first, facts, vertex = work_clip(src, recipe)
    require(np.array_equal(work["matrices"][0], A.encoded(first, src["inverse"])), "CLAW_LOOP_START")
    entry = entry_clip(src, recipe, first)
    recovery = dict(entry, id="mole_worker.claw_dig.recovery_v1", matrices=entry["matrices"][::-1].copy(),
                    grounding=entry["grounding"][::-1].copy())
    return [work, entry, recovery], {"claw_vertex": vertex, "work_keys": facts}


def sampled(src: dict, cases: list, vertex: int) -> dict:
    """Float vertex diagnostics for the author (the exact proofs decide)."""
    geometry = src["body"]["geometry"][0]
    paw = np.any((geometry["ids"] == 19) & (geometry["weights"] > 0), axis=1)
    rows = []
    for case in cases:
        lowest_other, claw = [], []
        for frame in range(case["frames"]):
            points = SRC.I.points_at(case, src["body"], frame)
            lowest_other.append(float(points[~paw, 1].min()))
            claw.append(points[vertex].tolist())
        rows.append({"id": case["id"], "lowest_non_paw_vertex_u": round(min(lowest_other), 4),
                     "claw_y_range_u": [round(min(p[1] for p in claw), 2), round(max(p[1] for p in claw), 2)]})
    return {"clips": rows, "scope": "sampled float vertices only; prove_claw_stroke.py holds the exact proofs"}


def write_case(path: Path, case: dict) -> None:
    """Byte-reproducible NPZ, as `author_empty_walk.write_case`."""
    with zipfile.ZipFile(path, "x", compression=zipfile.ZIP_STORED) as image:
        for name in ("matrices", "grounding"):
            stream = io.BytesIO()
            np.lib.format.write_array(stream, np.ascontiguousarray(case[name]), allow_pickle=False)
            image.writestr(zipfile.ZipInfo(name + ".npy", ZIP_TIME), stream.getvalue())


def recipe_of(args: argparse.Namespace) -> dict:
    """The command line as a recipe dictionary."""
    return {name: getattr(args, name) for name in DOMAINS}


def main() -> int:
    """Author one candidate and write its clips and record."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    for name in DOMAINS:
        parser.add_argument("--" + name.replace("_", "-"), dest=name, type=int, required=True)
    parser.add_argument("--palette", type=Path, default=SRC.PALETTE)
    args = parser.parse_args()
    require(not args.out.exists(), "CLAW_OUTPUT_EXISTS")
    src = SRC.read_claw_source(args.palette)
    recipe = recipe_of(args)
    cases, record = author(src, recipe)
    args.out.mkdir(parents=True)
    names = ("stroke", "entry", "recovery")
    for name, case in zip(names, cases):
        write_case(args.out / (name + ".npz"), case)
    producers = [Path(__file__), Path(SRC.__file__), Path(A.__file__), Path(LIFT.__file__), Path(SRC.I.__file__)]
    report = {"schema": 1, "decision": "1217", "motion": "M1 claw downward stroke (BRACE, CUT, FINISH)",
              "recipe": recipe, "loop": {"top_u": TOP_U, "depth_u": DEPTH_U, "keys": WORK_KEYS},
              "entry_keys": ENTRY_KEYS, "target": src["target"], "source_pins": src["pins"],
              "ready_frame": SRC.READY_FRAME, **record, "sampled": sampled(src, cases, record["claw_vertex"]),
              "clips": {name: {"id": case["id"], "frames": case["frames"],
                               "sha256": hashlib.sha256((args.out / (name + ".npz")).read_bytes()).hexdigest()}
                        for name, case in zip(names, cases)},
              "producer_sources": {str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p) for p in producers},
              "tool": None, "paw": "open (original cast mesh)", "production_qualified": False}
    (args.out / "candidate.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"out": str(args.out), "claw_vertex": record["claw_vertex"], "sampled": report["sampled"]}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
