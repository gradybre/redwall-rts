#!/usr/bin/env python3
"""Exact source proofs for one two-paw claw-stroke candidate (ADR 1217 step 1b). Source-local, yaw 0; no permission.

The candidate is rebuilt from its recipe and must match its stored clips byte for byte. Step 1's proofs
(`prove_claw_stroke.py`) are reused unchanged, with both paws in place of one:

1. **Claw contact, each paw.** Each claw tip crosses the face downward on exactly one rendered edge; the anchor
   and patch follow the accepted construction, and each patch must lie on the moved-in cube's top face.
2. **Below the face.** The clipped below-face hull of every non-foot triangle lies inside the moved-in cube, and
   only paw triangles (either hand) reach it. The entry reaches nothing below the face.
3. **World prisms.** Every triangle against every ground solid on every interval, with the accepted sole-support
   rule; paw triangles may be in the target cube only during the stroke.
4. **Self-clearance, both sides and between the arms.** Right-arm triangles against the rest of the body, left-arm
   triangles against the rest, and right-arm against left-arm triangles. "Arm" triangles have all their weight on
   that arm's three bones; for each arm, "the rest" is every triangle with no weight on that arm's bones (step 1's
   rule, per side). Only that arm's mixed shoulder-seam triangles are excluded, and they are counted. The accepted stand already rests the left paw into the left thigh (ready key 8 held still does not
   separate 9 such pairs). In the entry only, unseparated left-paw × left-thigh pairs are reported apart as that
   contact being released, and they must occupy a prefix of the entry from the ready key; every other pair is
   proved, and the stroke admits no exception.

    $PY .../prove_claw_pair.py <candidate-dir>
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np

import author_claw_pair as PAIR
import prove_claw_stroke as ONE

W, SRC, T, P = PAIR.W, PAIR.SRC, ONE.T, ONE.P
CLIP_NAMES = ("stroke", "entry", "recovery")
STATION = {"station_inset_u": PAIR.STATION_INSET_U}


def load(candidate: Path, src: dict) -> tuple:
    """The stored clips, checked against their record and against a rebuild from the recipe."""
    record = json.loads((candidate / "candidate.json").read_text())
    cases, authored = PAIR.author(src, record["recipe"])
    W.require(authored["claw_vertices"] == record["claw_vertices"], "CLAW_PAIR_PROOF_VERTEX")
    for name, case in zip(CLIP_NAMES, cases):
        path = candidate / (name + ".npz")
        W.require(SRC.sha(path) == record["clips"][name]["sha256"], "CLAW_PAIR_PROOF_CLIP_PIN")
        with np.load(path, allow_pickle=False) as image:
            W.require(image["matrices"].tobytes() == case["matrices"].tobytes() and
                      image["grounding"].tobytes() == case["grounding"].tobytes(), "CLAW_PAIR_PROOF_REBUILD")
    return record, cases


def classes(src: dict) -> dict:
    """Triangle classes from the real skin weights, for both arms."""
    geometry, triangles = src["body"]["geometry"][0], src["triangles"]
    positive = geometry["weights"] > 0
    weighted = lambda bones: np.any(np.isin(geometry["ids"], bones) & positive, axis=1)
    only = lambda bones: ~np.any(~np.isin(geometry["ids"], bones) & positive, axis=1)
    feet = T.foot_membership(src["body"], triangles)
    return {"feet": feet, "any_foot": feet[0] | feet[1],
            "paw": np.any(weighted([PAIR.ARMS["right"][2], PAIR.ARMS["left"][2]])[triangles], axis=1),
            "right": np.all(only(PAIR.ARMS["right"])[triangles], axis=1),
            "left": np.all(only(PAIR.ARMS["left"])[triangles], axis=1),
            "not_right": ~np.any(weighted(PAIR.ARMS["right"])[triangles], axis=1),
            "not_left": ~np.any(weighted(PAIR.ARMS["left"])[triangles], axis=1)}


PAIRINGS = (("right_arm_vs_rest", "right", "not_right"), ("left_arm_vs_rest", "left", "not_left"),
            ("right_arm_vs_left_arm", "right", "left"))


RELEASE_CAPACITY = 4096


def separation(src: dict, case: dict, keys: list, padding: np.ndarray, first: np.ndarray, second: np.ndarray,
               release: np.ndarray | None) -> dict:
    """Step 1's interval separation (`ONE.S.separated`) of two triangle sets.

    With `release` (first-set and second-set masks), unseparated pairs between those two subsets are recorded
    apart as the stand's own thigh contact being released, instead of failing; every other pair must separate.
    """
    triangles = src["triangles"]
    a_ids, b_ids = np.flatnonzero(first), np.flatnonzero(second)
    unresolved, released, pairs, checks = [], [], 0, 0
    for start, end in P.rendered_intervals(case):
        low = np.stack([keys[start][0], keys[end][0]]) - padding
        high = np.stack([keys[start][1], keys[end][1]]) + padding
        al, ah = low[:, triangles[a_ids]].transpose(1, 0, 2, 3), high[:, triangles[a_ids]].transpose(1, 0, 2, 3)
        bl, bh = low[:, triangles[b_ids]].transpose(1, 0, 2, 3), high[:, triangles[b_ids]].transpose(1, 0, 2, 3)
        amin, amax, bmin, bmax = al.min(axis=(1, 2)), ah.max(axis=(1, 2)), bl.min(axis=(1, 2)), bh.max(axis=(1, 2))
        counter = [0]
        for a in range(len(a_ids)):
            for b in np.flatnonzero(np.all(bmin <= amax[a], axis=1) & np.all(bmax >= amin[a], axis=1)):
                pairs += 1
                if ONE.S.separated(al[a], ah[a], bl[b], bh[b], counter):
                    continue
                pair = {"interval": start, "triangles": [int(a_ids[a]), int(b_ids[b])]}
                if release is not None and release[0][a_ids[a]] and release[1][b_ids[b]]:
                    released.append(pair)
                    W.require(len(released) <= RELEASE_CAPACITY, "CLAW_PAIR_RELEASE_CAPACITY")
                    continue
                unresolved.append(pair)
                if len(unresolved) >= 32:
                    return {"clear": False, "unresolved": unresolved, "stopped_at_limit": True}
        checks += counter[0]
    return {"clear": not unresolved, "unresolved": unresolved, "pairs": pairs, "checks": checks,
            "released_stand_contact": release_summary(released, case),
            "first_triangles": len(a_ids), "second_triangles": len(b_ids)}


def release_summary(released: list, case: dict) -> dict:
    """The released pairs' interval range; they must occupy a prefix of the clip from interval 0 (paw leaving)."""
    intervals = sorted({row["interval"] for row in released})
    prefix = intervals == list(range(len(intervals)))
    return {"pairs": len(released), "intervals": intervals, "is_prefix_from_ready": prefix,
            "paw_triangles": len({row["triangles"][0] for row in released}),
            "thigh_triangles": len({row["triangles"][1] for row in released})}


def release_masks(src: dict) -> tuple:
    """Left-paw triangles (any LeftHand weight) and left-thigh triangles (LeftUpLeg the dominant bone).

    The accepted stand (ADR 1199, rows 30/31) rests the left paw into the left thigh: held still at ready key 8,
    9 such triangle pairs do not separate. The entry pulls the paw out; those pairs are reported apart.
    """
    geometry, triangles = src["body"]["geometry"][0], src["triangles"]
    paw = np.any((geometry["ids"] == PAIR.ARMS["left"][2]) & (geometry["weights"] > 0), axis=1)
    dominant = geometry["ids"][np.arange(len(geometry["ids"])), np.argmax(geometry["weights"], axis=1)]
    names = [bone["name"] for bone in src["rig"]["bones"]]
    thigh = dominant == names.index("LeftUpLeg")
    return np.any(paw[triangles], axis=1), np.any(thigh[triangles], axis=1)


def ready_contact(src: dict, sets: dict, release: tuple) -> dict:
    """The stand's own left-paw/left-thigh contact: ready key 8 held still, with the release category."""
    ready = src["stand"]["matrices"][SRC.READY_FRAME]
    case = W.case_of([ready, ready], src["grounding"], "ready")
    keys, padding, _ = ONE.hulls(src, case)
    row = separation(src, case, keys, padding, sets["left"], sets["not_left"], release)
    return {"clear_apart_from_contact": row["clear"], **row["released_stand_contact"]}


def self_rows(src: dict, case: dict, keys: list, padding: np.ndarray, sets: dict, release: tuple | None) -> dict:
    """The three pairings on every rendered interval; only the left arm against the rest may release."""
    rows = {name: separation(src, case, keys, padding, sets[first], sets[second],
                             release if name == "left_arm_vs_rest" else None)
            for name, first, second in PAIRINGS}
    rows["excluded_shoulder_seam_triangles"] = {side: int(len(src["triangles"]) - int(sets[side].sum()) -
                                                          int(sets["not_" + side].sum())) for side in ("right", "left")}
    released = rows["left_arm_vs_rest"].get("released_stand_contact", {"pairs": 0, "is_prefix_from_ready": True})
    rows["clear"] = all(rows[name]["clear"] for name, _, _ in PAIRINGS) and \
        (released["pairs"] == 0 or released["is_prefix_from_ready"])
    return rows


def prove_clip(src: dict, record: dict, case: dict, sets: dict, release: tuple, productive: bool) -> dict:
    """All proofs for one clip."""
    keys, padding, residual = ONE.hulls(src, case)
    below = ONE.below_face(case, keys, padding, src["triangles"], sets)
    row = {"residual_m": residual, "below_face": below,
           "world": ONE.world(src, STATION, case, keys, padding, sets, productive, below),
           "self": self_rows(src, case, keys, padding, sets, None if productive else release)}
    if productive:
        cube = PAIR.target_cube(src)
        row["contact"] = {side: ONE.claw_contact(src, case, record["claw_vertices"][side], keys, padding)
                          for side in PAIR.ARMS}
        row["patches_inside_cube_face"] = all(ONE.contained(c["patch_u"], cube) for c in row["contact"].values())
    else:
        row["nothing_below_face"] = below["bounds_u"] is None
    return row


def prove(src: dict, record: dict, cases: list) -> dict:
    """The stroke and entry; the recovery is the entry's exact reverse."""
    sets = classes(src)
    release = release_masks(src)
    stroke = prove_clip(src, record, cases[0], sets, release, True)
    entry = prove_clip(src, record, cases[1], sets, release, False)
    W.require(np.array_equal(cases[2]["matrices"], cases[1]["matrices"][::-1]), "CLAW_PAIR_REVERSE")
    clear = (stroke["world"]["clear"] and stroke["self"]["clear"] and stroke["patches_inside_cube_face"] and
             entry["world"]["clear"] and entry["self"]["clear"] and entry["nothing_below_face"])
    return {"clear": bool(clear), "stand_ready_contact": ready_contact(src, sets, release), "stroke": stroke,
            "entry": entry,
            "recovery": {"reused_exact_reverse_of": "entry"}}


def main() -> int:
    """Prove one candidate and write proof.json beside it."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--palette", type=Path, default=SRC.PALETTE)
    args = parser.parse_args()
    out = args.candidate / "proof.json"
    W.require(not out.exists(), "CLAW_PAIR_PROOF_EXISTS")
    src = SRC.read_claw_source(args.palette)
    record, cases = load(args.candidate, src)
    result = prove(src, record, cases)
    producers = [Path(__file__), Path(PAIR.__file__), Path(ONE.__file__), Path(W.__file__), Path(SRC.__file__),
                 Path(T.__file__), Path(P.__file__)]
    result.update(schema=1, decision="1217", exact_yaw=0, production_qualified=False,
                  producer_sources={str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p) for p in producers})
    out.write_text(json.dumps(result, indent=1) + "\n")
    stroke = result["stroke"]
    print(json.dumps({"clear": result["clear"], "contacts": {s: c["anchor_u"] for s, c in stroke["contact"].items()},
                      "below_face_u": stroke["below_face"]["bounds_u"],
                      "world_unresolved": [len(result[n]["world"]["unresolved"]) for n in ("stroke", "entry")],
                      "self_clear": [result[n]["self"]["clear"] for n in ("stroke", "entry")]}))
    return 0 if result["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
