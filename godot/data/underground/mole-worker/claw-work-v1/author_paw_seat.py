#!/usr/bin/env python3
"""ADR 1217 step 2 (M5 + M4a): paw handling and paw seating of the L0/T0 bearers, no tool. Source only.

The paid installation has two motions today, both holding the pick: handling (row 29, `qualified-assembly-v1`: the
left palm comes to rest on the delivered bearer's top while the right hand holds the pick) and fastening (INSTALL
row 16, `install-source-v4`: the adze end taps the bearer's top at the contact plane y = 128). Brendan's DEC-052:
moles seat and fasten timber by paw. Both motions are re-authored with both paws, from the approved corrected
tool-free stand (step 1c) and with step 1b's approved posture recipe (`author_claw_pair.posture`: hip drop with sole
planting, squared shoulders, lean, head lift) and its arm solve:

- **Targets (published).** Both bearers sit in the same station-local section, z ∈ [−512, −384], y ∈ [0, 128]
  (`author_install_source.workpiece_targets`: L0 from H, T0 from station 3). Row 16's contact point is
  (128, 128, −448). The right paw works there and the left paw at its mirror, (−128, 128, −448); both lie on both
  bearers' top faces.
- **Paw frame.** Palm down, claws forward: `hand_rotation` with tilt 90° and the recipe's roll per paw.
- **Contact vertex (derived).** The paw's lowest vertex in its work frame (the paw's own vertices, measured in the
  hand frame the recipe gives), so it is the first point of the paw to meet the bearer.
- **Handling (`seat`).** Both contact vertices rest on the bearer's top (y = 128) for two identical keys, as the
  accepted handling seat does. Entry, 31 keys from ready: first the body settles into the work posture with the
  arms carried as they hang; then both arms reach, each contact vertex on the path of the accepted handling entry
  (to 128 u above its work point over 30/46 of the reach, then straight down), the elbows turning outward. Recovery
  is the exact reverse. The paw's lowest skinned point
  rests 1/512 u above the top, the accepted seat's own gap (`seat_offsets`).
- **Seating (`tap`).** The accepted fitting tap's height law, unchanged: 17 keys lowering the contact from 80 u
  above the top to 2 u below it (208 → 126 at plane 128), smoothstep, mirrored to 33 keys. Both paws press
  together. Entry and recovery as for handling, into and out of the tap's first key.

    $PY .../author_paw_seat.py <out> --lean-degrees 40 --drop-u 96 --head-lift-degrees 30 \\
        --right-roll-degrees 0 --left-roll-degrees 0
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np

import author_claw_pair as PAIR

W, SRC, A, LIFT = PAIR.W, PAIR.SRC, PAIR.A, PAIR.LIFT
require = W.require
STAND_V2 = SRC.MOLE / "stand-walk-v2/evidence/stand-walk-v2"
PLANE_U = 128  # The fastening contact plane: the bearer's top (row 16, ADR 1116).
CONTACT = {"right": np.array([128., PLANE_U, -448.]), "left": np.array([-128., PLANE_U, -448.])}
SECTION = np.array([-192, 0, -512, 256, PLANE_U, -384])  # Both bearers' common station-local section.
TAP_RAISE_U, TAP_DEPTH_U, TAP_KEYS = 80, 2, 17  # The accepted tap: 208 → 126 about plane 128, 17 keys.
PALM_DOWN_TILT = 90
ENTRY_LIFT_U = 128  # The accepted handling entry raises the paw 128 u over its contact (`clear_entry`)
RAISE_SHARE = 30 / 46  # ... over its first 30 of 46 entry intervals, then lowers it.
DOMAINS = {"lean_degrees": (0, 90), "drop_u": (0, 176), "head_lift_degrees": (0, 60),
           "right_roll_degrees": (0, 345), "left_roll_degrees": (0, 345)}


def corrected_source() -> dict:
    """The claw source closure with the approved corrected stand (step 1c) as its ready hub, pinned."""
    src = SRC.read_claw_source()
    record = json.loads((STAND_V2 / "candidate.json").read_text())
    path = STAND_V2 / "stand.npz"
    require(SRC.sha(path) == record["clips"]["stand"]["sha256"], "PAW_SEAT_STAND_PIN")
    with np.load(path, allow_pickle=False) as image:
        stand = {"frames": len(image["matrices"]), "matrices": image["matrices"].copy(),
                 "grounding": image["grounding"].copy()}
    return dict(src, stand=stand, hub=A.globals_at(stand, SRC.READY_FRAME, src["inverse_inverse"]),
                grounding=np.float32(stand["grounding"][SRC.READY_FRAME]), stand_sha256=SRC.sha(path))


def paw_points(src: dict, side: str) -> tuple:
    """The paw's rigid vertices (all weight on the hand bone, so the hand frame places them exactly) and their
    hand-local points."""
    geometry = src["body"]["geometry"][0]
    hand = PAIR.ARMS[side][2]
    dominant = geometry["ids"][np.arange(len(geometry["ids"])), np.argmax(geometry["weights"], axis=1)]
    bind = W.affine_of(src["rig"]["bones"][hand]["inverse_bind"])
    local = geometry["points"].astype(np.float64) @ bind[:3, :3].T + bind[:3, 3]
    rigid = ~np.any((geometry["ids"] != hand) & (geometry["weights"] > 0), axis=1)
    candidates = np.flatnonzero((dominant == hand) & rigid)
    return candidates, local[candidates]


def palm_vertex(src: dict, side: str, rotation: np.ndarray) -> tuple:
    """The paw's lowest vertex in the given hand frame (lowest index on ties) and its hand-local point."""
    candidates, local = paw_points(src, side)
    heights = local @ rotation[1]
    best = float(heights.min())
    at = int(np.flatnonzero(heights == best).min())
    return int(candidates[at]), local[at]


def recipe_pose(src: dict, recipe: dict) -> dict:
    """Step 1b's posture recipe with no dig fields."""
    return {"drop_u": recipe["drop_u"], "lean_degrees": recipe["lean_degrees"],
            "head_lift_degrees": recipe["head_lift_degrees"]}


def axis_turn(axis: np.ndarray, degrees: float) -> np.ndarray:
    """Rodrigues rotation about a unit axis."""
    angle = np.deg2rad(degrees)
    skew = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
    return np.eye(3) + np.sin(angle) * skew + (1 - np.cos(angle)) * skew @ skew


def elbow_out(pose: list, side: str, target: np.ndarray, weight: float) -> list:
    """Turn the upper arm about the shoulder→wrist-target line so the elbow points away from the midline.

    The accepted two-link solve keeps the elbow on its current bend side. From the hanging stand, bringing a paw
    forward onto the bearer swings the left elbow back into the hip; this sets the bend side outward first. The
    turn is about the line through the shoulder and the target, so the solve that follows reaches the same target
    with unchanged links. `weight` is the share of the signed turn applied (the entry ramps it from 0 to 1).
    """
    shoulder_bone, elbow_bone, wrist_bone = PAIR.ARMS[side]
    shoulder, elbow = pose[shoulder_bone][:3, 3], pose[elbow_bone][:3, 3]
    axis = target - shoulder
    axis /= np.linalg.norm(axis)
    current = (elbow - shoulder) - axis * np.dot(elbow - shoulder, axis)
    outward = np.array([1. if side == "right" else -1., 0., 0.])
    wanted = outward - axis * np.dot(outward, axis)
    if np.linalg.norm(current) < 1e-9 or np.linalg.norm(wanted) < 1e-9:
        return pose
    current, wanted = current / np.linalg.norm(current), wanted / np.linalg.norm(wanted)
    angle = weight * np.arctan2(np.dot(np.cross(current, wanted), axis), np.dot(current, wanted))
    turn = axis_turn(axis, np.degrees(angle))
    spin = np.eye(4)
    spin[:3, :3] = turn
    spin[:3, 3] = shoulder - turn @ shoulder
    return [spin @ row if at in (shoulder_bone, elbow_bone, wrist_bone) else row for at, row in enumerate(pose)]


def solved(src: dict, base: list, rotations: dict, targets: dict, palms: dict, weight: float = 1.0) -> list:
    """Both arms on one posture, elbows out, each contact vertex on its target."""
    pose, grounding = base, float(src["grounding"])
    for side in ("right", "left"):
        hand = PAIR.ARMS[side][2]
        wrist_target = (np.asarray(targets[side], dtype=np.float64) / 1024 - [0., grounding, 0.] -
                        rotations[side] @ palms[side])
        pose = elbow_out(pose, side, wrist_target, weight)
        pose, _ = PAIR.solve(pose, side, rotations[side], palms[side], targets[side], grounding)
        require(np.allclose(pose[hand][:3, :3], rotations[side]), "PAW_SEAT_HAND_FRAME")
    return pose


def stroke_frames(src: dict, recipe: dict) -> tuple:
    """The work posture, each hand's palm-down frame and its contact vertex in that frame."""
    base = PAIR.posture(src, recipe_pose(src, recipe), 1.0)
    rotations = {side: W.hand_rotation(base[PAIR.ARMS[side][2]], PALM_DOWN_TILT, recipe[side + "_roll_degrees"])
                 for side in PAIR.ARMS}
    vertices = {side: palm_vertex(src, side, rotations[side]) for side in PAIR.ARMS}
    return base, rotations, vertices


def tap_heights() -> list:
    """33 contact heights: the accepted tap's 17 lowering keys, mirrored."""
    down = []
    for key in range(TAP_KEYS):
        share = key / (TAP_KEYS - 1)
        down.append(PLANE_U + TAP_RAISE_U - (TAP_RAISE_U + TAP_DEPTH_U) * share * share * (3 - 2 * share))
    return down + down[-2::-1]


def seat_offsets(src: dict, recipe: dict) -> tuple:
    """Per paw, the height offset that rests its lowest skinned vertex over the bearer 1/512 u above the top (the accepted
    handling seat's own gap and 1/2048 u tolerance, `author_assembly.top_contact`), and that vertex."""
    base, rotations, vertices = stroke_frames(src, recipe)
    palms = {side: vertices[side][1] for side in PAIR.ARMS}
    geometry = src["body"]["geometry"][0]
    offsets, lowest = {side: 0. for side in PAIR.ARMS}, {}
    for _ in range(24):
        targets = {s: np.array([CONTACT[s][0], PLANE_U + offsets[s], CONTACT[s][2]]) for s in PAIR.ARMS}
        pose = solved(src, base, rotations, targets, palms)
        case = W.case_of([A.encoded(pose, src["inverse"])] * 2, src["grounding"], "seat")
        points = SRC.I.points_at(case, src["body"], 0)
        residual = {}
        for side in PAIR.ARMS:
            weighted = np.any((geometry["ids"] == PAIR.ARMS[side][2]) & (geometry["weights"] > 0), axis=1)
            over = np.all((points[:, [0, 2]] > SECTION[[0, 2]]) & (points[:, [0, 2]] < SECTION[[3, 5]]), axis=1)
            paw = np.flatnonzero(weighted & over)
            require(len(paw) > 0, "PAW_SEAT_OFF_BEARER")
            lowest[side] = int(paw[np.argmin(points[paw, 1])])
            residual[side] = PLANE_U + 1 / 512 - float(points[lowest[side], 1])
        if max(abs(v) for v in residual.values()) <= 1 / 2048:
            return offsets, lowest
        offsets = {s: offsets[s] + residual[s] for s in PAIR.ARMS}
    raise ValueError("PAW_SEAT_CONTACT_CONVERGENCE")


def program_keys(src: dict, recipe: dict, heights: list) -> tuple:
    """Palettes for one stationary program whose lowest paw points sit at the given heights above CONTACT's x/z."""
    base, rotations, vertices = stroke_frames(src, recipe)
    palms = {side: vertices[side][1] for side in PAIR.ARMS}
    offsets, _ = seat_offsets(src, recipe)
    palettes, first = [], None
    for height in heights:
        targets = {side: np.array([CONTACT[side][0], height + offsets[side], CONTACT[side][2]])
                   for side in PAIR.ARMS}
        pose = solved(src, base, rotations, targets, palms)
        first = pose if first is None else first
        palettes.append(A.encoded(pose, src["inverse"]))
    return palettes, first


def entry(src: dict, recipe: dict, first: list, case_id: str, raise_u: float) -> dict:
    """Ready key 8 to `first` in two halves: the body settles into the work posture with the arms carried as they
    hang, then the arms reach: each contact vertex follows `approach` from where it hangs to its work point, each
    hand turns by the shortest rotation, and the elbows ramp outward (`elbow_out`)."""
    grounding = float(src["grounding"])
    base = PAIR.posture(src, recipe_pose(src, recipe), 1.0)
    palms = {side: vertex[1] for side, vertex in stroke_frames(src, recipe)[2].items()}
    hands = {side: PAIR.ARMS[side][2] for side in PAIR.ARMS}
    point = lambda pose, side: (pose[hands[side]][:3, :3] @ palms[side] + pose[hands[side]][:3, 3] +
                                [0., grounding, 0.]) * 1024
    start, finish = {s: point(base, s) for s in PAIR.ARMS}, {s: point(first, s) for s in PAIR.ARMS}
    palettes, half = [], (W.ENTRY_KEYS - 1) // 2
    for key in range(W.ENTRY_KEYS):
        if key <= half:
            pose = PAIR.posture(src, recipe_pose(src, recipe), PAIR.smooth(key / half))
        else:
            reach = PAIR.smooth((key - half) / (W.ENTRY_KEYS - 1 - half))
            rotations = {s: LIFT.rotation_blend(base[hands[s]][:3, :3], first[hands[s]][:3, :3], reach)
                         for s in PAIR.ARMS}
            targets = {s: approach(start[s], finish[s], reach, raise_u) for s in PAIR.ARMS}
            pose = solved(src, base, rotations, targets, palms, reach)
        palettes.append(A.encoded(pose, src["inverse"]))
    palettes[0] = src["stand"]["matrices"][SRC.READY_FRAME].copy()
    palettes[-1] = A.encoded(first, src["inverse"])
    return W.case_of(palettes, src["grounding"], case_id)


def approach(start: np.ndarray, finish: np.ndarray, lead: float, raise_u: float) -> np.ndarray:
    """The accepted handling entry's path: to a point `raise_u` above the work start over the first 30 of 46
    intervals, then straight down (`author_assembly.clear_entry`). While rising, the paw moves forward first (the
    square root of the share) and sideways and up later (its square), so it leaves the body before it turns in."""
    above = finish + np.array([0., raise_u, 0.])
    if lead < RAISE_SHARE:
        share = lead / RAISE_SHARE
        return start + (above - start) * np.array([share * share, share * share, np.sqrt(share)])
    share = (lead - RAISE_SHARE) / (1 - RAISE_SHARE)
    return above * (1 - share) + finish * share


def program(src: dict, recipe: dict, name: str, heights: list) -> list:
    """[entry, work, recovery] for one program."""
    palettes, first = program_keys(src, recipe, heights)
    work = W.case_of(palettes, src["grounding"], f"mole_worker.paw_{name}.work_v1")
    raise_u = max(0., ENTRY_LIFT_U - (heights[0] - PLANE_U))  # The tap starts 80 u up already: rise to 128 only.
    into = entry(src, recipe, first, f"mole_worker.paw_{name}.entry_v1", raise_u)
    out = dict(into, id=f"mole_worker.paw_{name}.recovery_v1", matrices=into["matrices"][::-1].copy(),
               grounding=into["grounding"][::-1].copy())
    return [work, into, out]


def author(src: dict, recipe: dict) -> dict:
    """Both programs: handling (`seat`) and seating (`tap`)."""
    for name, (low, high) in DOMAINS.items():
        require(type(recipe.get(name)) is int and low <= recipe[name] <= high, "PAW_SEAT_RECIPE_" + name.upper())
    return {"seat": program(src, recipe, "seat", [float(PLANE_U), float(PLANE_U)]),
            "tap": program(src, recipe, "tap", tap_heights())}


def main() -> int:
    """Author one candidate and write its clips and record."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    for name in DOMAINS:
        parser.add_argument("--" + name.replace("_", "-"), dest=name, type=int, required=True)
    args = parser.parse_args()
    require(not args.out.exists(), "PAW_SEAT_OUTPUT_EXISTS")
    src = corrected_source()
    recipe = {name: getattr(args, name) for name in DOMAINS}
    programs = author(src, recipe)
    args.out.mkdir(parents=True)
    clips = {}
    for name, cases in programs.items():
        for part, case in zip(("work", "entry", "recovery"), cases):
            path = args.out / f"{name}_{part}.npz"
            W.write_case(path, case)
            clips[f"{name}_{part}"] = {"id": case["id"], "frames": case["frames"], "sha256": SRC.sha(path)}
    producers = [Path(__file__), Path(PAIR.__file__), Path(W.__file__), Path(SRC.__file__)]
    report = {"schema": 1, "decision": "1217", "motion": "M5 paw handling (seat) and M4a paw seating (tap)",
              "recipe": recipe, "contact_targets_u": {s: v.tolist() for s, v in CONTACT.items()},
              "palm_vertices": seat_offsets(src, recipe)[1],
              "seat_offsets_u": seat_offsets(src, recipe)[0], "plane_u": PLANE_U,
              "tap": {"raise_u": TAP_RAISE_U, "depth_u": TAP_DEPTH_U, "keys": 2 * TAP_KEYS - 1},
              "stand_sha256": src["stand_sha256"], "source_pins": src["pins"], "clips": clips,
              "producer_sources": {str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p) for p in producers},
              "tool": None, "paw": "open (original cast mesh)", "production_qualified": False}
    (args.out / "candidate.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"out": str(args.out), "palm_vertices": report["palm_vertices"]}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
