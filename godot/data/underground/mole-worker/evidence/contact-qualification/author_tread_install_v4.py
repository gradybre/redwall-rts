#!/usr/bin/env python3
"""ADR 1209 step 4, revision 4: the tread install tap on the curled pick paw (ADR 1216).

The approved curled paw holds the pick across the paw on the palm (the lateral-2 fit). This revision re-runs the
tap on it, using the v4 source closure (`curl_source.read_curl_source`). Everything else is reused unchanged
from revisions 1 and 2:

- the station (310 u behind the far edge) and the bearer workpiece;
- the station-local fixture;
- revision 2's swivel elbow, aimed at the ready carry's own wrist. The paw holds the pick in a new place, so the
  ready wrist is the natural one;
- the 17-key tap, its mirror, the planted entry and its exact reverse;
- every accepted proof: the crossing patch, the tool inside the workpiece, continuous self-clearance and the
  world prisms. The self-clearance grip exclusion is the accepted predicate, which selects the same 845-vertex
  patch on the curled mesh (`prove_curl_grip.py`).

The handle lean stays in the accepted 25–50° range and the torso is upright unless a candidate says otherwise.

    $PY .../author_tread_install_v4.py <out> --x-u 0 --z-u -246 --lean-degrees 35 --azimuth-degrees 30 --torso-degrees 0
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent


def load(name: str, path: Path):
    """Import one sibling script by path."""
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


V2 = load("tread_install_v2", HERE / "author_tread_install_v2.py")
C = load("curl_source", HERE / "curl_source.py")
V1, I, P = V2.V1, V2.I, V2.P
require = V2.require


def encode(out: Path, cases: list, report: dict, roots: list) -> None:
    """The create-only candidate image, bound to the v4 palette and its grip-proof-v3 envelopes."""
    proof = P.content.read_json(C.PROOF, C.PROOF_SHA)
    plan = {"revision": 107, "world_root_bounds_u": roots, "clips": [case["id"] for case in cases]}
    raw_report = (json.dumps(report, indent=2) + "\n").encode()
    raw_plan = (json.dumps(plan, indent=2) + "\n").encode()
    image, budget = P.content.encode(cases, plan, proof, C.UGPAL_SHA, hashlib.sha256(raw_report).hexdigest(),
                                     hashlib.sha256(raw_plan).hexdigest())
    out.mkdir(parents=True)
    for name, raw in (("candidate.json", raw_report), ("plan.json", raw_plan), ("mole-worker.ugactor", image)):
        with (out / name).open("xb") as stream:
            stream.write(raw)
    (out / "compilation.json").write_text(json.dumps({"content_sha256": hashlib.sha256(image).hexdigest(),
        "content_bytes": len(image), "presentation_budget": budget, "production_qualified": False}, indent=2) + "\n")


def source_motion(ready: dict, tool: dict, rig: dict, recipe: dict) -> tuple:
    """Revision 2's motion; its tap and entry ids name this revision."""
    cases, diagnostics = V2.source_motion(ready, tool, rig, recipe)
    names = ("mole_worker.install_tread.tap_v4", "mole_worker.install_tread.entry_v4", "mole_worker.install_tread.recovery_v4")
    for case, name in zip(cases, names):
        case["id"] = name
    return cases, diagnostics


def main() -> int:
    """Author one candidate on the curled paw, prove it, and write it."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    for name in ("x-u", "z-u", "lean-degrees", "azimuth-degrees", "torso-degrees"):
        parser.add_argument("--" + name, type=int, required=True)
    args = parser.parse_args()
    require(not args.out.exists(), "OUTPUT_EXISTS")
    require(-256 < args.x_u < 256 and -V1.STATION_D < args.z_u < -V1.STATION_D + 128, "TARGET_OFF_WORKPIECE")
    recipe = {"x_u": args.x_u, "z_u": args.z_u, "lean_degrees": args.lean_degrees,
              "azimuth_degrees": args.azimuth_degrees, "torso_degrees": args.torso_degrees,
              "elbow_rule": "wrist_preserving_swivel", "grip": "curled paw, lateral-2 fit (ADR 1216)",
              "contact_plane_y_u": V1.PLANE_U, "poll_y_u": [208, 126, 208]}
    packet = P.content.read_json(V1.PREFIX, I.PREFIX_SHA, 65536)
    cases_in, parts, rig, topology, roots, sources, historical = C.read_curl_source()
    ready = cases_in[0]
    station = V1.fixture(packet, V1.STATION_D)
    cases, diagnostics = source_motion(ready, parts[1], rig, recipe)
    result = V1.prove(cases, parts, topology, rig, roots, station, recipe)
    paths = [Path(__file__), Path(V2.__file__), Path(V1.__file__), Path(V1.V4.__file__), Path(C.__file__),
             V1.PREFIX, C.UGPAL, C.PROOF, C.PLAN, C.TOPOLOGY, C.CURLED_PAW]
    pins = {str(p.resolve().relative_to(P.ROOT)): P.content.file_hash(p) for p in paths}
    report = {"schema": 1, "decision": "1209", "revision": 4, "station": V1.station_bounds(ready, parts),
              "station_from_far_edge_u": V1.STATION_D, "fixture": station, "source_recipe": recipe,
              "poll_source_vertex": I.POLL_VERTEX, "pose_solver_diagnostics": diagnostics,
              "wall_margin": V1.extents(cases, parts), "producer_sources": pins,
              "verified_source_files": sources, "historical_source_snapshot": historical,
              "remaining": ["BRENDAN_REVIEW", "ARRIVAL_REPOSITION_FROM_DESCENT_END", "T6_SILL_WORKPIECE_PLANE_64",
                            "HANDLING_PROGRAM", "NATIVE_TAP_CAPTURE", "INTEGER_ROWS_AND_CONTENT_7"],
              "production_qualified": False}
    encode(args.out, cases, report, roots)
    with (args.out / "proof.json").open("x") as stream:
        json.dump({"schema": 1, "decision": "1209", "revision": 4, "clear": result["clear"], **result,
                   "production_qualified": False}, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"clear": result["clear"], "contacts": [row["anchor_u"] for row in result["contacts"]],
                      "wrist_deviation_max_degrees": max(d["wrist_deviation_degrees"] for d in diagnostics)}))
    return 0 if result["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
