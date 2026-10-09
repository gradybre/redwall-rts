#!/usr/bin/env python3
"""ADR 1216: the curled paw's grip proof at the re-held ready carry, on the v4 source closure.

1. **No paw–pick penetration beyond the grip exclusion.** This is the accepted continuous self-clearance proof,
   `prove_self_clearance.prove` with area "body", unchanged. Its exclusion predicate (right-hand-weighted vertices
   at hand-local y > 0.025) selects exactly the same 845 vertices and 448 triangles on the curled mesh: the curl
   only moves vertices beyond the shaft line (y > 0.078) and keeps them there. So the accepted exclusion applies
   with no successor rule, and it is checked by count.
2. **Palm and claws on the shaft.** The same exact interval separation test is run between the pick and only the
   excluded grip triangles. Pairs it cannot separate are exact contact witnesses; at least one is required.
3. **Wrap.** The angular cover, around the shaft axis, of the grip vertices lying within one shaft radius of the
   shaft's surface (a float witness; at least 90° is required).

    $PY .../prove_curl_grip.py <out.json>
"""
from __future__ import annotations

import argparse
import contextlib
from fractions import Fraction
import importlib.util
import io
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("curl_source", HERE / "curl_source.py")
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)
F, P, I = C.F, C.P, C.I
S = I.M.S
SECTORS = 24
WRAP_MINIMUM_DEGREES = 90


def static_case(ready: dict, parts: list) -> dict:
    """The ready key as a two-key static clip, the shape the accepted provers take."""
    return dict(ready, frames=2, source_loop_mode=0, duration_q16=65536, source_duration_s=Fraction(1, 30),
                matrices=np.stack([ready["matrices"][8]] * 2), grounding=np.full(2, ready["grounding"][8], dtype=np.float32),
                geometry=parts)


def contact_pairs(case: dict, parts: list, topology: list, rig: dict, roots: list) -> dict:
    """The accepted exact test between the pick and the excluded grip triangles only."""
    accepted = S.body_triangle_ids
    ids, omitted = accepted(parts[0], topology[0][0], rig["rig_binding"])
    excluded = np.setdiff1d(np.arange(len(topology[0][0])), ids)
    S.body_triangle_ids = lambda body, triangles, binding: (excluded, 0)
    try:
        with contextlib.redirect_stderr(io.StringIO()):
            result = S.prove(case, parts, topology, rig["rig_binding"], roots, "body")
    finally:
        S.body_triangle_ids = accepted
    return {"grip_triangles": int(len(excluded)), "accepted_exclusion_omitted": omitted,
            "unseparated_pairs_found": len(result["unresolved"]), "stopped_at_limit": bool(result.get("stopped_at_limit")),
            "witnesses": result["unresolved"][:8]}


def wrap_cover(case: dict, parts: list, rig: dict, topology: list) -> dict:
    """Grip vertices within one shaft radius of the shaft surface, and their angular cover about its axis."""
    body = I.G.source_positions(parts[0], case["matrices"][0], case["grounding"][0])
    ids, _ = S.body_triangle_ids(parts[0], topology[0][0], rig["rig_binding"])
    excluded = np.setdiff1d(np.arange(len(topology[0][0])), ids)
    vertices = np.unique(topology[0][0][excluded])
    tool = P._affine64(case["matrices"][0, 24])
    axis = tool[:3, 0] / np.linalg.norm(tool[:3, 0])
    pivot = np.asarray(rig["pick_binding"]["prop_local_grip_m"], dtype=float)
    centre = (tool[:3, :3] @ pivot + tool[:3, 3]) * 1024
    centre[1] += float(case["grounding"][0]) * 1024
    radius = json.loads(C.CURLED_PAW.read_text())["shaft_radius_m"] * 1024
    offset = body[vertices] - centre
    radial = offset - np.outer(offset @ axis, axis)
    distance = np.linalg.norm(radial, axis=1)
    shell = (distance >= radius) & (distance < 2 * radius)
    first = np.cross(axis, [0., 1., 0.])
    first /= np.linalg.norm(first)
    second = np.cross(axis, first)
    angles = np.arctan2(radial[shell] @ second, radial[shell] @ first)
    sectors = np.unique(((angles + np.pi) / (2 * np.pi) * SECTORS).astype(int) % SECTORS)
    return {"shaft_radius_u": radius, "grip_vertices_in_shell": int(shell.sum()),
            "wrap_sectors_covered": int(len(sectors)), "wrap_degrees": float(len(sectors) * 360 / SECTORS)}


def main() -> int:
    """All three parts on the re-held ready key; exit 2 unless every one holds."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    F.require(not args.out.exists(), "OUTPUT_EXISTS")
    cases, parts, rig, topology, roots, sources, historical = C.read_curl_source()
    case = static_case(cases[0], parts)
    with contextlib.redirect_stderr(io.StringIO()):
        penetration = S.prove(case, parts, topology, rig["rig_binding"], roots, "body")
    contact = contact_pairs(case, parts, topology, rig, roots)
    wrap = wrap_cover(case, parts, rig, topology)
    clear = penetration["clear"] and contact["unseparated_pairs_found"] > 0 and wrap["wrap_degrees"] >= WRAP_MINIMUM_DEGREES \
        and penetration.get("intentional_grip_triangles") == 448
    paths = [Path(__file__), Path(C.__file__), Path(F.__file__)]
    report = {"schema": 1, "decision": "1216", "clear": bool(clear),
              "no_penetration_beyond_grip_exclusion": {k: penetration[k] for k in ("clear", "checks", "pairs", "body_triangles",
                                                                                   "intentional_grip_triangles", "tool_triangles")},
              "palm_and_claw_contact": contact, "wrap": wrap,
              "producer_sources": {str(p.resolve().relative_to(P.ROOT)): P.content.file_hash(p) for p in paths},
              "verified_source_files": sources, "historical_source_snapshot": historical, "production_qualified": False}
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"clear": report["clear"], "penetration_clear": penetration["clear"],
                      "contact_pairs": contact["unseparated_pairs_found"], "wrap_degrees": wrap["wrap_degrees"]}))
    return 0 if clear else 2


if __name__ == "__main__":
    sys.exit(main())
