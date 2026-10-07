#!/usr/bin/env python3
"""ADR 1217 / ADR 1199 successor: the tool-free stand and walk with both paws out of the thighs. Source only.

Brendan chose to fix at the source (2026-10-07) that the accepted tool-free stand (ADR 1199, rows 30/31) rests
its paws inside its thighs. Measured with step 1b's exact interval separation (`claw-work-v1/prove_claw_pair.py`,
each arm against every triangle with no weight on that arm):

- stand: the left paw is unseparated from the left thigh on 75 of its 121 intervals; the right paw from the right
  thigh and shin on 41 (open paw) or 21 (closed paw);
- walk: the left paw against the left thigh on 3 of 44 intervals; the right paw is clear.

The correction is the smallest constant outward swing of each upper arm that separates every pair:

- **One rotation per arm, every key.** Bone 13 (LeftArm) or 17 (RightArm) turns about its own joint, about the
  body's forward axis expressed in its parent's frame at ready key 8, by the same angle on every key. Forearm,
  hand and every other bone keep their supplied local transforms, so the supplied idle and walk motion, their
  loop closure and their rhythm are unchanged; only the arm hangs further out.
- **The angle is searched, not chosen:** bisection over whole degrees in [0, 30] for the smallest angle at which the
  stand and the walk separate every pair on both bodies (the closed paw drawn by the haul sources, the open paw used
  to dig), with the angle one degree less shown to fail. Sign: away from the body's midline.
- **Grounding** is the supplied clips' own; the arms carry no support. The prover re-checks floor and support.
- **Joins.** The wood and stone stand↔haul joins are re-authored by their accepted recipes
  (`author_empty_walk.join_keys` then `author_loaded_gait.support_keys`) from the corrected ready key 8 to each haul
  program's unchanged first key; leave is the exact reverse.

The published clips, images and content 5/6 are untouched; these are successors.

    $PY .../author_stand_walk_v2.py <out> [--palette ...] [--grip-palette ...]
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
MOLE = HERE.parent
ROOT = MOLE.parents[3]
sys.path.insert(0, str(MOLE / "haul-handling-v1"))
sys.path.insert(0, str(MOLE / "claw-work-v1"))
import author_empty_walk as E  # noqa: E402
import author_handling as A  # noqa: E402
import author_loaded_gait as G  # noqa: E402
import prove_claw_pair as PAIRPROOF  # noqa: E402

SRC = PAIRPROOF.SRC
EVIDENCE = MOLE / "haul-handling-v1/evidence"
PUBLISHED = {"stand": (EVIDENCE / "empty-walk-v1/candidate/stand.npz", 1,
                       "7086ef2a3aab64537d7822393c04ece86d67879e59e1c7e54d333a5c7f974c7d"),
             "walk": (EVIDENCE / "empty-walk-v1/candidate/walk.npz", 1,
                      "046ef4a7f4855b7f5243e66066bc8d27373689471e055f628e94c357cfa1b06e")}
HAUL = {"wood": (EVIDENCE / "program-review-v1/candidate", ("enter_haul", "leave_haul"), E.APPROACH_SHA),
        "stone": (EVIDENCE / "stone-program-v1", ("enter_haul_stone", "leave_haul_stone"),
                  "ad51f1e34ef77b0807966a160fc271cdd735ef1653f94bfb1c2ab49d412fe2d7")}
UPPER_ARM = {"left": 13, "right": 17}
FORWARD = np.array([0., 0., -1.])
MAX_DEGREES = 30
require = A.require


def load(path: Path, loop: int, digest: str) -> dict:
    """A published clip, hash-checked."""
    raw = path.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == digest, "STAND_V2_INPUT_PIN")
    with np.load(path, allow_pickle=False) as image:
        matrices, grounding = image["matrices"].copy(), image["grounding"].copy()
    return {"frames": len(matrices), "matrices": matrices, "grounding": grounding, "source_loop_mode": loop,
            "source_duration_s": Fraction(len(matrices) - 1, 30)}


def axis_in_parent(stand: dict, rig: tuple, bone: int, sign: float) -> np.ndarray:
    """The body's forward axis in the upper arm's parent frame at ready key 8 (unit length, signed outward)."""
    parents, _, inverse_inverse = rig
    parent = A.globals_at(stand, E.READY_FRAME, inverse_inverse)[parents[bone]]
    unit, _, rows = np.linalg.svd(parent[:3, :3])
    local = (unit @ rows).T @ (sign * FORWARD)
    return local / np.linalg.norm(local)


def turn(axis: np.ndarray, degrees: float) -> np.ndarray:
    """Rodrigues rotation."""
    angle = np.deg2rad(degrees)
    skew = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
    return np.eye(3) + np.sin(angle) * skew + (1 - np.cos(angle)) * skew @ skew


def swung(case: dict, rig: tuple, offsets: dict) -> dict:
    """Every key with each upper arm's local rotation pre-turned by its constant offset (degrees, axis)."""
    parents, inverse, inverse_inverse = rig
    columns = case["matrices"].shape[1]
    matrices = case["matrices"].copy()
    for frame in range(case["frames"]):
        globals_ = A.globals_at(case, frame, inverse_inverse)
        locals_ = A.locals_of(globals_, parents)
        for side, (degrees, axis) in offsets.items():
            bone = UPPER_ARM[side]
            locals_[bone][:3, :3] = turn(axis, degrees) @ locals_[bone][:3, :3]
        rebuilt = []
        for at, parent in enumerate(parents):
            rebuilt.append(rebuilt[parent] @ locals_[at] if parent >= 0 else locals_[at])
        matrices[frame, :24] = A.encoded(rebuilt, inverse)
    require(columns == matrices.shape[1], "STAND_V2_COLUMNS")
    return dict(case, matrices=matrices)


def outward_sign(stand: dict, rig: tuple, side: str) -> float:
    """The sign that moves the paw away from the midline (checked on the hand joint at ready key 8)."""
    _, _, inverse_inverse = rig
    hand = {"left": 15, "right": 19}[side]
    before = A.globals_at(stand, E.READY_FRAME, inverse_inverse)[hand][0, 3]
    for sign in (1., -1.):
        moved = swung(stand, rig, {side: (5., axis_in_parent(stand, rig, UPPER_ARM[side], sign))})
        after = A.globals_at(moved, E.READY_FRAME, inverse_inverse)[hand][0, 3]
        if abs(after) > abs(before):
            return sign
    raise ValueError("STAND_V2_OUTWARD")


def offsets_of(stand: dict, rig: tuple, degrees: dict) -> dict:
    """{side: (degrees, outward axis)}."""
    return {side: (value, axis_in_parent(stand, rig, UPPER_ARM[side], outward_sign(stand, rig, side)))
            for side, value in degrees.items()}


def joins(stand: dict, body: dict, topology: dict, rig: tuple) -> dict:
    """The wood and stone joins by their accepted recipe from the corrected ready key."""
    result = {}
    for cargo, (folder, names, digest) in HAUL.items():
        approach = load(folder / "approach.npz", 0, digest)
        hub, stock = approach["matrices"][0], approach["matrices"][0, 24]
        blended = E.join_keys(stand["matrices"][E.READY_FRAME], stand["grounding"][E.READY_FRAME], hub[:24],
                              approach["grounding"][0], rig, body, E.JOIN_SEGMENTS)
        enter, keys = G.support_keys(blended, body, topology)
        require(np.array_equal(enter["matrices"][-1], hub[:24]), "STAND_V2_JOIN_ENDPOINT")
        result[names[0]] = E.with_fixture(enter, stock)
        result[names[1]] = E.with_fixture(E.reversed_case(enter), stock)
    return result


def separates(src: dict, case: dict, sides: tuple, bodies: list) -> dict:
    """Exact per-arm separation (step 1b's rule, no exception) on each body; {body/side: unresolved count}."""
    sets = PAIRPROOF.classes(src)
    result = {}
    for label, body in bodies:
        probe = dict(src, body=body)
        keys, padding, _ = PAIRPROOF.ONE.hulls(probe, case)
        for side in sides:
            row = PAIRPROOF.separation(probe, case, keys, padding, sets[side], sets["not_" + side], None)
            result[f"{label}/{side}"] = len(row["unresolved"])
    return result


def clears(src: dict, clips: dict, rig: tuple, bodies: list, side: str, degrees: int, trail: list) -> bool:
    """Whether a swing of `degrees` separates every pair of this arm on the stand and the walk, every body."""
    offsets = offsets_of(clips["stand"], rig, {side: float(degrees)})
    counts = {name: separates(src, swung(case, rig, offsets), (side,), bodies) for name, case in clips.items()}
    trail.append({"side": side, "degrees": degrees, "unresolved": counts})
    print(json.dumps(trail[-1]), file=sys.stderr, flush=True)
    return all(value == 0 for row in counts.values() for value in row.values())


def search(src: dict, clips: dict, rig: tuple, bodies: list) -> tuple:
    """Per arm, the whole degree d where d separates every pair and d − 1 does not (bisection on [0, MAX_DEGREES]).

    0 must fail (the measured contact) and MAX_DEGREES must clear; both ends and the final pair are checked.
    """
    found, trail = {}, []
    for side in ("left", "right"):
        low, high = 0, MAX_DEGREES
        require(not clears(src, clips, rig, bodies, side, low, trail), "STAND_V2_NO_CONTACT")
        require(clears(src, clips, rig, bodies, side, high, trail), "STAND_V2_NO_SWING")
        while high - low > 1:
            middle = (low + high) // 2
            if clears(src, clips, rig, bodies, side, middle, trail):
                high = middle
            else:
                low = middle
        found[side] = high
    return found, trail


def main() -> int:
    """Search, author and write the corrected stand, walk and joins."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("--palette", type=Path, default=SRC.PALETTE)
    parser.add_argument("--grip-palette", type=Path, default=SRC.PALETTE.parent / "mole-grip-v3.ugpal")
    args = parser.parse_args()
    require(not args.out.exists(), "STAND_V2_OUTPUT_EXISTS")
    _, closed, _, _, topology, _, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    src = SRC.read_claw_source(args.palette)
    rig = A.hierarchy(topology)
    clips = {name: load(path, loop, digest) for name, (path, loop, digest) in PUBLISHED.items()}
    bodies = [("closed", closed), ("open", src["body"])]
    found, trail = search(src, clips, rig, bodies)
    offsets = offsets_of(clips["stand"], rig, {side: float(value) for side, value in found.items()})
    corrected = {name: swung(case, rig, offsets) for name, case in clips.items()}
    corrected.update(joins(corrected["stand"], closed, topology, rig))
    args.out.mkdir(parents=True)
    for name, case in corrected.items():
        E.write_case(args.out / (name + ".npz"), case)
    record = {"schema": 1, "decisions": ["1217", "1199"], "production_qualified": False, "tool": None,
              "swing_degrees": found, "axes_parent_local": {s: offsets[s][1].tolist() for s in offsets},
              "search": trail, "published_inputs": {k: v[2] for k, v in PUBLISHED.items()},
              "clips": {name: {"frames": case["frames"], "loop_mode": case["source_loop_mode"],
                               "sha256": hashlib.sha256((args.out / (name + ".npz")).read_bytes()).hexdigest()}
                        for name, case in corrected.items()},
              "producer_sources": {str(Path(p).resolve().relative_to(ROOT)): SRC.sha(Path(p))
                                   for p in (__file__, E.__file__, A.__file__, G.__file__, PAIRPROOF.__file__)}}
    (args.out / "candidate.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({"swing_degrees": found, "clips": list(corrected)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
