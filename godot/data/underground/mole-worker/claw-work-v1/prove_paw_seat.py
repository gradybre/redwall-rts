#!/usr/bin/env python3
"""Exact source proofs for one paw handling/seating candidate (ADR 1217 step 2). Source-local, yaw 0; no permission.

The candidate is rebuilt from its recipe and must match its stored clips byte for byte. For both programs (handling
`seat`, seating `tap`) and both installations (L0 from H, T0 from station 3; the accepted install fixtures,
`install-source-proof-v4/prove_candidate.target_prisms`, unchanged):

1. **World prisms with sole support** (step 1's construction, body only): every triangle against every solid on
   every rendered interval, with the accepted sole rule on the support solid. Against the bearer (the paid WIP
   workpiece), non-paw triangles must separate from the whole prism, and paw triangles from the prism lowered to
   one integer unit below the tap's deepest key (y ≤ 125): a paw may rest on the bearer and press into its top by
   no more than the accepted tap's own 2 u.
2. **Seating contact.** In the tap, each paw's palm vertex crosses the top plane (y = 128) downward on exactly one
   rendered edge; anchor and patch by step 1's construction (the clip is shifted down by 128 u so the plane is
   y = 0); each patch lies on both bearers' top faces.
3. **Self-clearance** with no exception: each arm against everything without that arm's weight, and arm against
   arm (`prove_claw_pair.self_rows`).

    $PY .../prove_paw_seat.py <candidate-dir>
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np

import author_paw_seat as SEAT
import prove_claw_pair as PAIRPROOF

W, SRC, A = SEAT.W, SEAT.SRC, SEAT.A
ONE, T, P = PAIRPROOF.ONE, PAIRPROOF.T, PAIRPROOF.P
Q = P.SCALE // 1024
V4_SPEC = importlib.util.spec_from_file_location(
    "paw_install_fixtures", SRC.I.PROOF / "install-source-proof-v4/prove_candidate.py")
V4 = importlib.util.module_from_spec(V4_SPEC)
V4_SPEC.loader.exec_module(V4)
SKIN_TOP_U = SEAT.PLANE_U - SEAT.TAP_DEPTH_U - 1
PARTS = ("work", "entry", "recovery")


def fixtures() -> list:
    """The accepted station-local install fixtures: L0 (assembly 0, from H) and T0 (assembly 1, from station 3)."""
    packet = P.content.read_json(SRC.I.PROOF / "stair-sequence-prefix-v1/first-entry-prefix-v1.source.json",
                                 V4.I.PREFIX_SHA, 65536)
    return V4.target_prisms(packet, V4.I.workpiece_targets(packet))


def load(candidate: Path, src: dict) -> tuple:
    """Stored clips, checked against their record and against a rebuild."""
    record = json.loads((candidate / "candidate.json").read_text())
    programs = SEAT.author(src, record["recipe"])
    for name, cases in programs.items():
        for part, case in zip(PARTS, cases):
            path = candidate / f"{name}_{part}.npz"
            W.require(SRC.sha(path) == record["clips"][f"{name}_{part}"]["sha256"], "PAW_SEAT_CLIP_PIN")
            with np.load(path, allow_pickle=False) as image:
                W.require(image["matrices"].tobytes() == case["matrices"].tobytes(), "PAW_SEAT_REBUILD")
    return record, programs


def pair_refusal(tri_low, tri_high, box, skin, paw, counter) -> bool:
    """Whether one triangle interval fails to separate from one solid under the bearer rule."""
    if paw and skin is not None:
        return not T.separated_box(tri_low, tri_high, skin, counter)
    return not T.separated_box(tri_low, tri_high, box, counter)


def world(src: dict, case: dict, fixture: dict, sets: dict) -> dict:
    """Every triangle against every solid on every interval; sole support on solid 0."""
    keys, padding, _ = ONE.hulls(src, case)
    boxes = [np.asarray(b, dtype=np.int64) * Q for b in fixture["solids_u"]]
    target = fixture["workpiece_solid"]
    skin = boxes[target].copy()
    skin[4] = SKIN_TOP_U * Q
    triangles, counter, cache = src["triangles"], [0], {}
    exact = lambda frame, vertex: cache.setdefault((frame, vertex), T.exact_source_y(src["body"], case, frame, vertex))
    unresolved, pairs, soles, contacts = [], 0, 0, 0
    for first, last in P.rendered_intervals(case):
        raw = (np.stack([keys[first][0], keys[last][0]]), np.stack([keys[first][1], keys[last][1]]))
        low, high = raw[0] - padding, raw[1] + padding
        _, failures = ONE.feet_rows(src, case, raw, low, high, (first, last), sets, boxes[0], exact)
        unresolved += failures
        tl, th = low[:, triangles], high[:, triangles]
        mn, mx = tl.min((0, 2)), th.max((0, 2))
        for solid, box in enumerate(boxes):
            for tri in np.flatnonzero(np.all(mn <= box[3:], axis=1) & np.all(mx >= box[:3], axis=1)):
                pairs += 1
                if solid == 0 and any(m[tri] for m in sets["feet"]) and T.inside_projection(tl[:, tri], th[:, tri], box) \
                        and T.source_above_plane(raw[0], raw[1], triangles[tri], (first, last), 0, exact):
                    soles += 1
                    continue
                paw = bool(sets["paw"][tri]) and solid == target
                if pair_refusal(tl[:, tri], th[:, tri], box, skin if solid == target else None, paw, counter):
                    unresolved.append({"interval": first, "triangle": int(tri), "solid": solid})
                elif paw and not T.separated_box(tl[:, tri], th[:, tri], box, counter):
                    contacts += 1
                if len(unresolved) >= T.MAX_UNRESOLVED:
                    return {"clear": False, "unresolved": unresolved, "stopped_at_limit": True}
    return {"clear": not unresolved, "unresolved": unresolved, "pairs": pairs, "numerical_sole_pairs": soles,
            "paw_resting_on_bearer_pairs": contacts, "checks": counter[0], "skin_top_u": SKIN_TOP_U}


def contact(src: dict, case: dict, record: dict) -> dict:
    """Each palm vertex's one downward crossing of the top plane, with anchor and patch (plane shifted to 0)."""
    shifted = dict(case, grounding=(case["grounding"] - np.float32(SEAT.PLANE_U / 1024)).astype(np.float32))
    keys, padding, _ = ONE.hulls(src, shifted)
    result = {}
    for side, vertex in record["palm_vertices"].items():
        row = ONE.claw_contact(src, shifted, vertex, keys, padding)
        row["anchor_u"][1] += SEAT.PLANE_U
        row["patch_u"][1] += SEAT.PLANE_U
        row["patch_u"][4] += SEAT.PLANE_U
        result[side] = row
    return result


def prove(src: dict, record: dict, programs: dict) -> dict:
    """Both programs on both installations."""
    sets = PAIRPROOF.classes(src)
    result, clear = {}, True
    tops = [fixture["solids_u"][fixture["workpiece_solid"]] for fixture in fixtures()]
    for name, cases in programs.items():
        rows = {}
        for part, case in zip(PARTS[:2], cases[:2]):
            keys, padding, _ = ONE.hulls(src, case)
            row = {"self": PAIRPROOF.self_rows(src, case, keys, padding, sets, None),
                   "world": {f"assembly_{f['assembly']}": world(src, case, f, sets) for f in fixtures()}}
            clear = clear and row["self"]["clear"] and all(w["clear"] for w in row["world"].values())
            rows[part] = row
        W.require(np.array_equal(cases[2]["matrices"], cases[1]["matrices"][::-1]), "PAW_SEAT_REVERSE")
        rows["recovery"] = {"reused_exact_reverse_of": "entry"}
        if name == "tap":
            rows["contact"] = contact(src, cases[0], record)
            rows["patches_on_both_bearers"] = all(ONE.contained(c["patch_u"], [t[0], SEAT.PLANE_U, t[2], t[3],
                                                                                SEAT.PLANE_U, t[5]])
                                                  for c in rows["contact"].values() for t in tops)
            clear = clear and rows["patches_on_both_bearers"]
        result[name] = rows
    return {"clear": bool(clear), **result}


def main() -> int:
    """Prove one candidate and write proof.json beside it."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("candidate", type=Path)
    args = parser.parse_args()
    out = args.candidate / "proof.json"
    W.require(not out.exists(), "PAW_SEAT_PROOF_EXISTS")
    src = SEAT.corrected_source()
    record, programs = load(args.candidate, src)
    result = prove(src, record, programs)
    producers = [Path(__file__), Path(SEAT.__file__), Path(PAIRPROOF.__file__), Path(ONE.__file__),
                 Path(V4.__file__), Path(T.__file__)]
    result.update(schema=1, decision="1217", exact_yaw=0, production_qualified=False,
                  producer_sources={str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p) for p in producers})
    out.write_text(json.dumps(result, indent=1) + "\n")
    summary = {name: {part: {"self": result[name][part]["self"]["clear"],
                             "world": {k: len(v["unresolved"]) for k, v in result[name][part]["world"].items()}}
                      for part in PARTS[:2]} for name in ("seat", "tap")}
    print(json.dumps({"clear": result["clear"], "summary": summary,
                      "tap_contacts": {s: c["anchor_u"] for s, c in result["tap"]["contact"].items()}}))
    return 0 if result["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
