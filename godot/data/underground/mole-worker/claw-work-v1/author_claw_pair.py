#!/usr/bin/env python3
"""ADR 1217 step 1b (M1, Brendan's review): the two-paw alternating claw stroke, at the moved-in cut station.

Brendan chose both paws scooping alternately and the cut stations moved in by 106 u (1,430 u from the entry
centre). This author reuses step 1's recipe (`author_claw_stroke.py`) unchanged for everything but the second paw:

- **Posture:** the tool-free stand key 8, the hip drop with sole planting (`W.posture`), then the upper body
  squared (the idle stands with its shoulder line turned 26°; `squaring` measures and removes it), then the lean.
- **Each paw:** the accepted fixed-length arm solve with forearm closing (`W.solve_arm`'s method, for either arm),
  aimed at that paw's own claw tip: its most distal vertex along its hand-local +Y, derived from the mesh. Each
  hand turns as one frame by `W.hand_rotation` with its own tilt and roll.
- **Loop:** step 1's closed ellipse (`W.loop_targets`), 80 u above the face to 60 u below, for each paw at its own
  lateral offset. The left paw runs half a cycle (16 keys) behind the right, so one paw scoops while the other
  recovers.
- **Clip start:** the stroke starts at loop key 8, where the right claw descends and the left claw rises, both
  10 u above the face (y = 10 + 70·cos 90°). So the entry never reaches below the face, and each claw crosses
  the face downward exactly once per cycle.
- **Head:** raised about the neck joint by `head_lift_degrees`, so the snout stays clear of the forearms when
  leaning: the mole looks ahead at the face.
- **Entry:** 31 keys from ready key 8; the drop, squaring, lean and head lift grow by smoothstep, while each claw tip
  moves straight from its ready offset to its first offset from its own shoulder, and each hand turns by the
  shortest rotation, in the first half (`ARM_LEAD`): the left paw rests on the left thigh at ready and must leave it before the body drops. Both
  arms are solved on every key. **Recovery** is the exact reverse.

Source only; `prove_claw_pair.py` holds the exact proofs.

    $PY .../author_claw_pair.py <out> --right-x-u 128 --left-x-u -128 --anchor-z-u -608 --rake-u 32 \\
        --lean-degrees 60 --drop-u 96 --tilt-degrees 60 --right-roll-degrees 90 --left-roll-degrees 90 --head-lift-degrees 30
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

import author_claw_stroke as W

SRC, A, RIG, LIFT = W.SRC, W.A, W.RIG, W.LIFT
require = W.require
ARMS = {"right": (17, 18, 19), "left": (13, 14, 15)}
HALF_CYCLE = (W.WORK_KEYS - 1) // 2
START_KEY = (W.WORK_KEYS - 1) // 4  # A quarter turn after the top: the right claw descends, the left rises.
HEAD_PIVOT = 20  # neck
DESCENDANTS = {9: frozenset(range(9, 24)), HEAD_PIVOT: frozenset(range(20, 24))}  # Spine02's and neck's subtrees.
ARM_LEAD = 2  # Entry: the claws finish their path at half the entry, before the drop and lean finish.
STATION_INSET_U = 106  # Brendan's ruling (DEC-052 follow-up 1): the derived maximum, 512 − 406.
DOMAINS = {"right_x_u": (0, 256), "left_x_u": (-256, 0), "anchor_z_u": (-768, -420), "rake_u": (16, 192),
           "lean_degrees": (0, 90), "drop_u": (0, 176), "tilt_degrees": (0, 120),
           "right_roll_degrees": (0, 345), "left_roll_degrees": (0, 345), "head_lift_degrees": (0, 60)}


def squaring(src: dict) -> np.ndarray:
    """The rotation that squares the stand's shoulders, measured from the stand itself.

    The supplied idle holds its shoulder line (LeftArm → RightArm joints) turned 26° about the vertical and
    tilted 3.5°, the left shoulder back and up. One paw never noticed; two paws need both shoulders forward. This
    is the proper rotation (yaw, then roll) that carries the measured line onto the body's lateral axis.
    """
    line = src["hub"][ARMS["right"][0]][:3, 3] - src["hub"][ARMS["left"][0]][:3, 3]
    yaw = np.arctan2(line[2], line[0])
    turn = np.array([[np.cos(yaw), 0., np.sin(yaw)], [0., 1., 0.], [-np.sin(yaw), 0., np.cos(yaw)]])
    level = turn @ line
    roll = -np.arctan2(level[1], level[0])
    tilt = np.array([[np.cos(roll), -np.sin(roll), 0.], [np.sin(roll), np.cos(roll), 0.], [0., 0., 1.]])
    return tilt @ turn


def posture(src: dict, recipe: dict, share: float) -> list:
    """Step 1's drop and sole planting, the upper body (bones 9–23) squared about Spine02 (`squaring`), step 1's
    lean, then the head (bones 20–23) raised about the neck joint by `head_lift_degrees`, each by `share`. All three
    turns are rigid, as ADR 1144's lean is."""
    pose, _ = W.posture(src, recipe["drop_u"] * share, 0)
    pose = rigid(pose, 9, LIFT.rotation_blend(np.eye(3), squaring(src), share))
    pose = W.lean(pose, recipe["lean_degrees"] * share)
    lift = np.deg2rad(recipe["head_lift_degrees"] * share)
    pitch = np.array([[1., 0., 0.], [0., np.cos(lift), -np.sin(lift)], [0., np.sin(lift), np.cos(lift)]])
    return rigid(pose, HEAD_PIVOT, pitch)


def rigid(pose: list, pivot_bone: int, rotation: np.ndarray) -> list:
    """Turn bones `pivot_bone` and after it in the chain (indices up to 23 that descend from it) about its joint."""
    pivot = pose[pivot_bone][:3, 3]
    turn = np.eye(4)
    turn[:3, :3] = rotation
    turn[:3, 3] = pivot - rotation @ pivot
    moved = DESCENDANTS[pivot_bone]
    return [turn @ value if at in moved else value for at, value in enumerate(pose)]


def claw_of(src: dict, side: str) -> tuple:
    """A paw's most distal vertex along its hand-local +Y (lowest index on ties) and its hand-local point."""
    geometry = src["body"]["geometry"][0]
    hand = ARMS[side][2]
    dominant = geometry["ids"][np.arange(len(geometry["ids"])), np.argmax(geometry["weights"], axis=1)]
    bind = W.affine_of(src["rig"]["bones"][hand]["inverse_bind"])
    local = geometry["points"].astype(np.float64) @ bind[:3, :3].T + bind[:3, 3]
    candidates = np.flatnonzero(dominant == hand)
    best = float(local[candidates, 1].max())
    vertex = int(candidates[local[candidates, 1] == best].min())
    return vertex, local[vertex]


def solve(pose: list, side: str, rotation: np.ndarray, claw_local: np.ndarray, target_u: np.ndarray,
          grounding: float) -> tuple:
    """The accepted fixed-length two-link solve with forearm closing, for either arm."""
    shoulder_bone, elbow_bone, wrist_bone = ARMS[side]
    hand = pose[wrist_bone].copy()
    hand[:3, :3] = rotation
    goal = np.asarray(target_u, dtype=np.float64) / 1024
    goal[1] -= grounding
    hand[:3, 3] = goal - rotation @ claw_local
    shoulder, elbow, wrist = [pose[at][:3, 3] for at in ARMS[side]]
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
    require(error < 1e-10, "CLAW_PAIR_ARM_LENGTH_DRIFT")
    return moved, error


def paw_loop(recipe: dict, side: str) -> list:
    """Step 1's ellipse at this paw's lateral offset, phased so the clip starts at START_KEY (left: + half)."""
    one = dict(recipe, x_u=recipe[side + "_x_u"])
    loop = W.loop_targets(one)[:-1]
    shift = START_KEY + (HALF_CYCLE if side == "left" else 0)
    return [loop[(key + shift) % len(loop)] for key in range(len(loop))]


def claw_point(pose: list, side: str, claw_local: np.ndarray, grounding: float) -> np.ndarray:
    """A pose's claw tip for one paw, in u."""
    hand = pose[ARMS[side][2]]
    return (hand[:3, :3] @ claw_local + hand[:3, 3] + [0., grounding, 0.]) * 1024


def both_paws(src: dict, pose: list, recipe: dict, targets: dict, rotations: dict) -> tuple:
    """Solve the right arm, then the left, on the same posture."""
    grounding, worst = float(src["grounding"]), 0.
    for side in ("right", "left"):
        pose, error = solve(pose, side, rotations[side], claw_of(src, side)[1], targets[side], grounding)
        worst = max(worst, error)
    return pose, worst


def rotations_of(base: list, recipe: dict) -> dict:
    """Each hand's stroke frame from the leaned posture's own hand frame."""
    return {side: W.hand_rotation(base[ARMS[side][2]], recipe["tilt_degrees"], recipe[side + "_roll_degrees"])
            for side in ARMS}


def work_clip(src: dict, recipe: dict) -> tuple:
    """32 distinct keys plus the exact repeat of key 0."""
    base = posture(src, recipe, 1.0)
    rotations = rotations_of(base, recipe)
    loops = {side: paw_loop(recipe, side) for side in ARMS}
    palettes, first, facts = [], None, []
    for key in range(len(loops["right"])):
        pose, error = both_paws(src, base, recipe, {s: loops[s][key] for s in ARMS}, rotations)
        first = pose if first is None else first
        palettes.append(A.encoded(pose, src["inverse"]))
        facts.append({"key": key, "maximum_link_length_error_m": float(error),
                      "claw_targets_u": {s: [round(float(v), 4) for v in loops[s][key]] for s in ARMS}})
    palettes.append(palettes[0].copy())
    return W.case_of(palettes, src["grounding"], "mole_worker.claw_dig.pair_stroke_v1"), first, facts


def shoulder_u(pose: list, side: str, grounding: float) -> np.ndarray:
    """A pose's shoulder joint for one arm, in u."""
    return (pose[ARMS[side][0]][:3, 3] + [0., grounding, 0.]) * 1024


def entry_clip(src: dict, recipe: dict, first: list) -> dict:
    """Ready key 8 to the stroke's first key, both arms solved on every key.

    Each claw tip moves on the straight line between its ready and first offsets from its own shoulder, carried by
    the shoulder as the posture changes, at the leading share (`ARM_LEAD`).
    """
    grounding = float(src["grounding"])
    claws = {side: claw_of(src, side)[1] for side in ARMS}
    start = {s: claw_point(src["hub"], s, claws[s], grounding) - shoulder_u(src["hub"], s, grounding) for s in ARMS}
    finish = {s: claw_point(first, s, claws[s], grounding) - shoulder_u(first, s, grounding) for s in ARMS}
    palettes = []
    for key in range(W.ENTRY_KEYS):
        share = smooth(key / (W.ENTRY_KEYS - 1))
        lead = smooth(min(1., ARM_LEAD * key / (W.ENTRY_KEYS - 1)))
        pose = posture(src, recipe, share)
        rotations = {s: LIFT.rotation_blend(src["hub"][ARMS[s][2]][:3, :3], first[ARMS[s][2]][:3, :3], lead)
                     for s in ARMS}
        targets = {s: shoulder_u(pose, s, grounding) + start[s] * (1 - lead) + finish[s] * lead for s in ARMS}
        pose, _ = both_paws(src, pose, recipe, targets, rotations)
        palettes.append(A.encoded(pose, src["inverse"]))
    palettes[0] = src["stand"]["matrices"][SRC.READY_FRAME].copy()
    palettes[-1] = A.encoded(first, src["inverse"])
    return W.case_of(palettes, src["grounding"], "mole_worker.claw_dig.pair_entry_v1")


def smooth(share: float) -> float:
    """Smoothstep, as step 1's entry."""
    return share * share * (3 - 2 * share)


def target_cube(src: dict) -> list:
    """The first episode's cube from the moved-in station (Brendan's ruling)."""
    return W.target_cube(src, {"station_inset_u": STATION_INSET_U})


def author(src: dict, recipe: dict) -> tuple:
    """Stroke, entry and its exact reverse as recovery, plus the authoring record."""
    for name, (low, high) in DOMAINS.items():
        require(type(recipe.get(name)) is int and low <= recipe[name] <= high, "CLAW_PAIR_RECIPE_" + name.upper())
    require(STATION_INSET_U == SRC.stance_inset_limit(), "CLAW_PAIR_STATION_INSET")
    cube = target_cube(src)
    require(cube[2] < recipe["anchor_z_u"] and recipe["anchor_z_u"] + recipe["rake_u"] < cube[5] and
            cube[0] < recipe["left_x_u"] < recipe["right_x_u"] < cube[3], "CLAW_PAIR_TARGET_OFF_FACE")
    work, first, facts = work_clip(src, recipe)
    entry = entry_clip(src, recipe, first)
    recovery = dict(entry, id="mole_worker.claw_dig.pair_recovery_v1", matrices=entry["matrices"][::-1].copy(),
                    grounding=entry["grounding"][::-1].copy())
    record = {"claw_vertices": {side: claw_of(src, side)[0] for side in ARMS}, "work_keys": facts,
              "station_inset_u": STATION_INSET_U, "start_loop_key": START_KEY, "left_phase_keys": HALF_CYCLE}
    return [work, entry, recovery], record


def main() -> int:
    """Author one candidate and write its clips and record."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    for name in DOMAINS:
        parser.add_argument("--" + name.replace("_", "-"), dest=name, type=int, required=True)
    parser.add_argument("--palette", type=Path, default=SRC.PALETTE)
    args = parser.parse_args()
    require(not args.out.exists(), "CLAW_PAIR_OUTPUT_EXISTS")
    src = SRC.read_claw_source(args.palette)
    recipe = {name: getattr(args, name) for name in DOMAINS}
    cases, record = author(src, recipe)
    args.out.mkdir(parents=True)
    names = ("stroke", "entry", "recovery")
    for name, case in zip(names, cases):
        W.write_case(args.out / (name + ".npz"), case)
    producers = [Path(__file__), Path(W.__file__), Path(SRC.__file__), Path(A.__file__), Path(LIFT.__file__)]
    report = {"schema": 1, "decision": "1217", "motion": "M1 two-paw alternating claw stroke (BRACE, CUT, FINISH)",
              "recipe": recipe, "loop": {"top_u": W.TOP_U, "depth_u": W.DEPTH_U, "keys": W.WORK_KEYS},
              "entry_keys": W.ENTRY_KEYS, "target": dict(src["target"], moved_cube_local_u=target_cube(src)),
              "source_pins": src["pins"], "ready_frame": SRC.READY_FRAME, **record,
              "clips": {name: {"id": case["id"], "frames": case["frames"],
                               "sha256": hashlib.sha256((args.out / (name + ".npz")).read_bytes()).hexdigest()}
                        for name, case in zip(names, cases)},
              "producer_sources": {str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p) for p in producers},
              "tool": None, "paw": "open (original cast mesh)", "production_qualified": False}
    (args.out / "candidate.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"out": str(args.out), "claw_vertices": record["claw_vertices"]}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
