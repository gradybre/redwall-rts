#!/usr/bin/env python3
"""ADR 1209 step 4: why the tread-install candidates pitch the torso back (a search record, not a proof).

For each recipe it builds the two tap end keys (poll at y = 208 and 126) and checks two things: the tool's
sampled vertices below the contact plane stay inside the workpiece (v4's `INSTALL_ACTIVE_TOOL_ESCAPES_WORKPIECE`
rule), and the accepted continuous self-clearance proof (`prove_self_clearance.prove`, body area) over the
interval between the keys. A recipe that passes both is only a search hit: the authored candidates in
`tread-install-v1/` carry the complete proofs.

    $PY .../probe_tread_install.py <out.json>
"""
from __future__ import annotations

import argparse
import contextlib
from fractions import Fraction
import importlib.util
import io
import itertools
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("tread_install", HERE / "author_tread_install.py")
T = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(T)
I = T.I
GRIDS = {
    "upright": {"torso": [0], "x": [128], "z": [-278, -246], "lean": [25, 30, 35, 40, 45, 50, 55, 60], "azimuth": [0, 15, 30, 45, 60]},
    "pitched_back": {"torso": [-20, -25, -30, -35], "x": [128], "z": [-278, -262, -246], "lean": [50, 55, 60], "azimuth": [30]},
}


def probe(ready: dict, parts: list, rig: dict, topology: list, roots: list, recipe: tuple) -> str:
    """One recipe's verdict: IK, ESCAPE, SELF or CLEAR."""
    torso, x, z, lean, azimuth = recipe
    keys = []
    try:
        base = T.pitched_ready(ready, rig, torso)
        for height in (208, 126):
            pose, _ = T.poll_pose(base, parts[1], rig, [x, height, z], lean, azimuth)
            keys.append(pose["matrices"][0])
            tool = I.prop_points(pose, 0, parts[1])
            low = tool[tool[:, 1] < T.PLANE_U]
            if not ((np.abs(low[:, 0]) < 256).all() and (low[:, 2] > -T.STATION_D).all()
                    and (low[:, 2] < -T.STATION_D + 128).all()):
                return "ESCAPE"
    except ValueError:
        return "IK"
    case = dict(ready, frames=2, source_loop_mode=0, duration_q16=65536, source_duration_s=Fraction(1, 30),
                matrices=np.stack(keys), grounding=np.full(2, ready["grounding"][8], dtype=np.float32), geometry=parts)
    with contextlib.redirect_stderr(io.StringIO()):
        result = T.S.prove(case, parts, topology, rig["rig_binding"], roots, "body")
    return "CLEAR" if result["clear"] else "SELF"


def main() -> int:
    """Run both grids and write every verdict."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    T.require(not args.out.exists(), "PROBE_OUTPUT_EXISTS")
    T.M.W.snapshot_sources = T.FLIGHT.historical_snapshot
    original, parts, rig, topology, roots, _, _ = T.M.read_actual_source()
    report = {"schema": 1, "decision": "1209", "station_from_far_edge_u": T.STATION_D, "grids": {}}
    for name in ("upright", "pitched_back"):
        grid = GRIDS[name]
        rows = []
        for recipe in itertools.product(grid["torso"], grid["x"], grid["z"], grid["lean"], grid["azimuth"]):
            rows.append({"torso": recipe[0], "x_u": recipe[1], "z_u": recipe[2], "lean": recipe[3],
                         "azimuth": recipe[4], "verdict": probe(original[0], parts, rig, topology, roots, recipe)})
        counts = {v: sum(r["verdict"] == v for r in rows) for v in ("CLEAR", "SELF", "ESCAPE", "IK")}
        report["grids"][name] = {"counts": counts, "rows": rows}
        print(json.dumps({name: counts}), flush=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
