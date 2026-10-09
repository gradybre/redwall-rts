#!/usr/bin/env python3
"""Exact source proofs for one claw-stroke candidate (ADR 1217 step 1). Source-local, yaw 0; no permission.

The candidate is rebuilt from its recipe and must match its stored clips byte for byte. Every proof uses the
accepted rational/interval machinery: endpoint vertex hulls in Q24 with the full native local and world residual
(`compile_profiles._vertex_hulls`, `_residual_padding`), so each rendered interval's triangles, interiors
included, are enclosed.

1. **Claw contact.** The claw-tip vertex's endpoint enclosures lie strictly on opposite sides of the face on one
   descending rendered edge. The exact rational skin equation gives the ideal crossing; the integer anchor is its
   nearest point and the patch adds the interval uncertainty (the accepted `crossing_patch` construction, for a
   skinned vertex).
2. **Below the face.** The whole clipped convex hull of every non-foot triangle below the face, over every rendered
   interval (`clipped_triangle_floor`), lies inside the target cube, and only right-paw triangles reach it. The entry
   and recovery reach nothing below the face.
3. **World prisms.** Every body triangle on every interval is separated from every ground solid, except: sole
   triangles resting on the support solid (the accepted numerical sole-contact rule), and right-paw triangles in the
   target cube during the stroke. Each foot keeps its full projection on the support and a real source contact.
4. **Limb self-clearance.** Every right-arm triangle (all of its weights on RightArm, RightForeArm or RightHand) is
   separated from every triangle with no weight on those three bones, on every rendered interval. Only the
   triangles that mix both (the skinned shoulder seam) are excluded, and they are counted.

    $PY .../prove_claw_stroke.py <candidate-dir>
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np

import author_claw_stroke as W

SRC, A = W.SRC, W.A
S = SRC.I.SOURCE
P = S.P
TERRAIN_SPEC = importlib.util.spec_from_file_location("claw_terrain", SRC.I.PROOF / "prove_stair_terrain.py")
T = importlib.util.module_from_spec(TERRAIN_SPEC)
TERRAIN_SPEC.loader.exec_module(T)
Q = P.SCALE // 1024
ARM_BONES = (17, 18, 19)
CLIP_NAMES = ("stroke", "entry", "recovery")


def load(candidate: Path, src: dict) -> tuple:
    """The stored clips, checked against their record and against a rebuild from the recipe."""
    record = json.loads((candidate / "candidate.json").read_text())
    cases, authored = W.author(src, record["recipe"])
    W.require(authored["claw_vertex"] == record["claw_vertex"], "CLAW_PROOF_VERTEX")
    for name, case in zip(CLIP_NAMES, cases):
        path = candidate / (name + ".npz")
        W.require(SRC.sha(path) == record["clips"][name]["sha256"], "CLAW_PROOF_CLIP_PIN")
        with np.load(path, allow_pickle=False) as image:
            W.require(image["matrices"].tobytes() == case["matrices"].tobytes() and
                      image["grounding"].tobytes() == case["grounding"].tobytes(), "CLAW_PROOF_REBUILD")
    return record, cases


def hulls(src: dict, case: dict) -> tuple:
    """Per-key outward vertex enclosures in Q24, the residual padding and its record."""
    part = src["body"]
    whole = P._vertex_hulls(part, case["matrices"], case["grounding"])
    padding, residual = P._residual_padding(part, case["matrices"], case["grounding"], src["roots"], whole)
    keys = [P._vertex_hulls(part, case["matrices"][f:f + 1], case["grounding"][f:f + 1])[0]
            for f in range(case["frames"])]
    return keys, padding, residual


def exact_point(src: dict, case: dict, frame: int, vertex: int) -> list:
    """The exact rational skin equation of one source vertex, in metres (`exact_source_y` on all axes)."""
    geometry = src["body"]["geometry"][0]
    point = [Fraction(float(v)) for v in geometry["points"][vertex]]
    result = [Fraction(0), Fraction(float(case["grounding"][frame])), Fraction(0)]
    for bind, weight in zip(geometry["ids"][vertex], geometry["weights"][vertex]):
        factor = Fraction(float(weight))
        if factor:
            row = case["matrices"][frame, int(bind)]
            for out in range(3):
                moved = Fraction(float(row[9 + out])) + sum(Fraction(float(row[out + 3 * axis])) * point[axis]
                                                            for axis in range(3))
                result[out] += factor * moved
    return result


def claw_contact(src: dict, case: dict, vertex: int, keys: list, padding: np.ndarray) -> dict:
    """The one descending face crossing of the claw tip: integer anchor and complete planar patch."""
    found = []
    for first, last in P.rendered_intervals(case):
        a_low, a_high = keys[first][0][vertex] - padding, keys[first][1][vertex] + padding
        b_low, b_high = keys[last][0][vertex] - padding, keys[last][1][vertex] + padding
        if not (int(a_low[1]) > 0 and int(b_high[1]) < 0):
            continue
        a, b = exact_point(src, case, first, vertex), exact_point(src, case, last, vertex)
        uncertainty = [Fraction(int(v), P.SCALE) for v in padding]
        delta = a[1] - b[1]
        shares = [(a[1] - uncertainty[1]) / delta, (a[1] + uncertainty[1]) / delta]
        W.require(0 < shares[0] <= shares[1] < 1, "CLAW_CONTACT_SHARE")
        nominal = a[1] / delta
        anchor = [round(((1 - nominal) * a[0] + nominal * b[0]) * 1024), 0,
                  round(((1 - nominal) * a[2] + nominal * b[2]) * 1024)]
        low, high = [], []
        for axis in (0, 2):
            values = [((1 - s) * a[axis] + s * b[axis]) * 1024 for s in shares]
            lo, hi = min(values) - uncertainty[axis] * 1024, max(values) + uncertainty[axis] * 1024
            low.append(lo.numerator // lo.denominator)
            high.append(-(-hi.numerator // hi.denominator))
        found.append({"vertex": vertex, "rendered_edge": [first, last], "anchor_u": anchor,
                      "patch_u": [low[0], 0, low[1], high[0], 0, high[1]],
                      "share_range": [P.envelope.fraction_record(s) for s in shares]})
    W.require(len(found) == 1, "CLAW_CONTACT_COUNT")
    return found[0]


def masks(src: dict) -> dict:
    """Triangle classes from the real skin weights: feet, right paw, right arm, and the rest of the body."""
    geometry, triangles = src["body"]["geometry"][0], src["triangles"]
    weighted = lambda bones: np.any(np.isin(geometry["ids"], bones) & (geometry["weights"] > 0), axis=1)
    only_arm = ~np.any(~np.isin(geometry["ids"], ARM_BONES) & (geometry["weights"] > 0), axis=1)
    feet = T.foot_membership(src["body"], triangles)
    return {"feet": feet, "any_foot": feet[0] | feet[1],
            "paw": np.any(weighted([19])[triangles], axis=1),
            "arm": np.all(only_arm[triangles], axis=1),
            "rest": ~np.any(weighted(ARM_BONES)[triangles], axis=1)}


def below_face(case: dict, keys: list, padding: np.ndarray, triangles: np.ndarray, classes: dict) -> dict:
    """The clipped below-face hull of every non-foot triangle, and which triangles reach the face."""
    chosen = triangles[~classes["any_foot"]]
    ids = np.flatnonzero(~classes["any_foot"])
    boxes, reaching = [], set()
    for first, last in P.rendered_intervals(case):
        low = np.stack([keys[first][0], keys[last][0]]) - padding
        high = np.stack([keys[first][1], keys[last][1]]) + padding
        box = P.clipped_triangle_floor(low, high, chosen)
        if box is not None:
            boxes.append(box)
            reaching.update(int(t) for t in ids[low[:, chosen, 1].min(axis=(0, 2)) <= 0])
    if not boxes:
        return {"bounds_u": None, "triangles": 0, "only_paw": True}
    lo = np.asarray([min(b[a] for b in boxes) for a in range(3)], dtype=np.int64)
    hi = np.asarray([max(b[a] for b in boxes) for a in range(3, 6)], dtype=np.int64)
    return {"bounds_u": P.outward_units(lo, hi), "triangles": len(reaching),
            "only_paw": bool(all(classes["paw"][t] for t in reaching))}


def fixture(src: dict, recipe: dict) -> dict:
    """Ground solids around the first episode's cube, station-local yaw 0. The support solid is the accepted
    "retained exterior earth, ending at exact future pocket edge" (`target_prisms`, assembly 0), ending at the
    cube's near face wherever the station stands."""
    cube = W.target_cube(src, recipe)
    near, far = cube[5], cube[2]
    solids = [[-2048, -1024, near, 2048, 0, 1024], [-2048, -1024, far, cube[0], 0, near],
              [cube[3], -1024, far, 2048, 0, near], [-2048, -1024, -2560, 2048, 0, far], cube]
    labels = ["retained exterior earth (support)", "earth left of the cube", "earth right of the cube",
              "earth beyond the cube", "target cube (paid Site, uncut)"]
    return {"solids_u": solids, "source_labels": labels, "support_solid": 0, "target_solid": 4}


def contained(box: list, container: list) -> bool:
    """Closed containment of an integer box."""
    return box is not None and all(container[a] <= box[a] <= box[a + 3] <= container[a + 3] for a in range(3))


def feet_rows(src, case, raw, low, high, interval, classes, support, exact) -> tuple:
    """The accepted per-foot support rule: full projection on the support, source above it, a real contact."""
    rows, failures, touching = [], [], False
    triangles = src["triangles"]
    for side, mask in enumerate(classes["feet"]):
        vertices = np.unique(triangles[mask])
        inside = T.inside_projection(low[:, vertices], high[:, vertices], support)
        above = T.source_above_plane(raw[0], raw[1], vertices, interval, 0, exact)
        near = vertices[np.flatnonzero(raw[0][:, vertices, 1].min(axis=0) < Q)]
        witness, _ = T.contact_witness(near, interval, 0, exact)
        touching = touching or witness >= 0
        rows.append({"interval": interval[0], "foot": side, "inside": inside, "above": above, "contact": witness})
        if not inside or not above:
            failures.append({"kind": "SUPPORT", "interval": interval[0], "foot": side})
    if not touching:
        failures.append({"kind": "NO_SOURCE_STANCE_CONTACT", "interval": interval[0]})
    return rows, failures


def world(src: dict, recipe: dict, case: dict, keys: list, padding: np.ndarray, classes: dict, productive: bool,
          below: dict) -> dict:
    """Every triangle against every solid on every rendered interval (body only; there is no tool)."""
    ground = fixture(src, recipe)
    boxes = [np.asarray(b, dtype=np.int64) * Q for b in ground["solids_u"]]
    allow = productive and below["only_paw"] and contained(below["bounds_u"], ground["solids_u"][4])
    triangles, counter, cache = src["triangles"], [0], {}
    exact = lambda frame, vertex: cache.setdefault((frame, vertex), T.exact_source_y(src["body"], case, frame, vertex))
    supports, unresolved, pairs, soles, target_pairs = [], [], 0, 0, 0
    for first, last in P.rendered_intervals(case):
        raw = (np.stack([keys[first][0], keys[last][0]]), np.stack([keys[first][1], keys[last][1]]))
        low, high = raw[0] - padding, raw[1] + padding
        rows, failures = feet_rows(src, case, raw, low, high, (first, last), classes, boxes[0], exact)
        supports += rows
        unresolved += failures
        tl, th = low[:, triangles], high[:, triangles]
        mn, mx = tl.min((0, 2)), th.max((0, 2))
        for solid, box in enumerate(boxes):
            for tri in np.flatnonzero(np.all(mn <= box[3:], axis=1) & np.all(mx >= box[:3], axis=1)):
                pairs += 1
                if solid == 0 and any(m[tri] for m in classes["feet"]) and T.inside_projection(tl[:, tri], th[:, tri], box) \
                        and T.source_above_plane(raw[0], raw[1], triangles[tri], (first, last), 0, exact):
                    soles += 1
                elif solid == 4 and allow and classes["paw"][tri]:
                    target_pairs += 1
                elif not T.separated_box(tl[:, tri], th[:, tri], box, counter):
                    unresolved.append({"kind": "SOLID", "interval": first, "triangle": int(tri), "solid": solid})
                if len(unresolved) >= T.MAX_UNRESOLVED:
                    return {"clear": False, "unresolved": unresolved, "stopped_at_limit": True}
    return {"clear": not unresolved and (allow or not productive), "unresolved": unresolved,
            "paw_in_target_admitted": allow, "checks": counter[0], "pairs": pairs, "numerical_sole_pairs": soles, "intentional_paw_target_pairs": target_pairs,
            "supported_intervals": len(supports) // 2, "fixture": ground}


def self_clearance(src: dict, case: dict, keys: list, padding: np.ndarray, classes: dict) -> dict:
    """Right-arm triangles against the rest of the body on every rendered interval (`separated`, unchanged)."""
    triangles = src["triangles"]
    arm, rest = triangles[classes["arm"]], triangles[classes["rest"]]
    unresolved, pairs, checks = [], 0, 0
    for first, last in P.rendered_intervals(case):
        low = np.stack([keys[first][0], keys[last][0]]) - padding
        high = np.stack([keys[first][1], keys[last][1]]) + padding
        al, ah = low[:, arm].transpose(1, 0, 2, 3), high[:, arm].transpose(1, 0, 2, 3)
        bl, bh = low[:, rest].transpose(1, 0, 2, 3), high[:, rest].transpose(1, 0, 2, 3)
        amin, amax = al.min(axis=(1, 2)), ah.max(axis=(1, 2))
        bmin, bmax = bl.min(axis=(1, 2)), bh.max(axis=(1, 2))
        counter = [0]
        for a in range(len(arm)):
            for b in np.flatnonzero(np.all(bmin <= amax[a], axis=1) & np.all(bmax >= amin[a], axis=1)):
                pairs += 1
                if not S.separated(al[a], ah[a], bl[b], bh[b], counter):
                    unresolved.append({"interval": first, "arm_triangle": int(a), "rest_triangle": int(b)})
                    if len(unresolved) >= 32:
                        return {"clear": False, "unresolved": unresolved, "stopped_at_limit": True}
        checks += counter[0]
    excluded = int(len(triangles) - len(arm) - len(rest))
    return {"clear": not unresolved, "unresolved": unresolved, "pairs": pairs, "checks": checks,
            "arm_triangles": len(arm), "rest_triangles": len(rest), "excluded_shoulder_blend_triangles": excluded,
            "check_budget": "S.MAX_CHECKS per rendered interval"}


def prove(src: dict, record: dict, cases: list) -> dict:
    """All four proofs for the stroke and entry; the recovery is the entry's exact reverse."""
    classes = masks(src)
    result = {}
    for name, case in zip(CLIP_NAMES[:2], cases[:2]):
        keys, padding, residual = hulls(src, case)
        below = below_face(case, keys, padding, src["triangles"], classes)
        row = {"residual_m": residual, "below_face": below,
               "world": world(src, record["recipe"], case, keys, padding, classes, name == "stroke", below),
               "self": self_clearance(src, case, keys, padding, classes)}
        if name == "stroke":
            row["contact"] = claw_contact(src, case, record["claw_vertex"], keys, padding)
            row["patch_inside_cube_face"] = contained(row["contact"]["patch_u"], W.target_cube(src, record["recipe"]))
        else:
            row["nothing_below_face"] = below["bounds_u"] is None
        result[name] = row
    W.require(np.array_equal(cases[2]["matrices"], cases[1]["matrices"][::-1]), "CLAW_REVERSE")
    result["recovery"] = {"reused_exact_reverse_of": "entry"}
    stroke, entry = result["stroke"], result["entry"]
    clear = (stroke["world"]["clear"] and stroke["self"]["clear"] and stroke["patch_inside_cube_face"] and
             entry["world"]["clear"] and entry["self"]["clear"] and entry["nothing_below_face"])
    return {"clear": bool(clear), **result}


def main() -> int:
    """Prove one candidate and write proof.json beside it."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--palette", type=Path, default=SRC.PALETTE)
    args = parser.parse_args()
    out = args.candidate / "proof.json"
    W.require(not out.exists(), "CLAW_PROOF_EXISTS")
    src = SRC.read_claw_source(args.palette)
    record, cases = load(args.candidate, src)
    result = prove(src, record, cases)
    producers = [Path(__file__), Path(W.__file__), Path(SRC.__file__), Path(T.__file__), Path(S.__file__),
                 Path(P.__file__)]
    result.update(schema=1, decision="1217", exact_yaw=0, production_qualified=False,
                  producer_sources={str(p.resolve().relative_to(SRC.ROOT)): SRC.sha(p) for p in producers})
    out.write_text(json.dumps(result, indent=1) + "\n")
    stroke = result["stroke"]
    print(json.dumps({"clear": result["clear"], "anchor_u": stroke["contact"]["anchor_u"],
                      "patch_u": stroke["contact"]["patch_u"], "below_face_u": stroke["below_face"]["bounds_u"],
                      "world": [result[n]["world"].get("pairs") for n in ("stroke", "entry")],
                      "self": [result[n]["self"].get("pairs") for n in ("stroke", "entry")]}))
    return 0 if result["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
