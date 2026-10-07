#!/usr/bin/env python3
"""ADR 1209 step 4: how each tread-install candidate holds the pick, beside the accepted fitting motion (v4).

Read from the stored images at the contact key (the work clip's key 16; v4's own work key 16). Float
diagnostics for the review table, not proofs:

- **shaft elevation**: the angle above horizontal of the line from the adze end (vertex 478) to the grip pivot;
- **shaft lateral**: the grip pivot's x minus the adze end's x. Positive means the hand is outboard of the head,
  so the shaft does not cross in front of the body;
- **wrist deviation**: the angle between the forearm's direction seen from the hand and the same direction in the
  accepted ready grip (compact ready key 8); 0 means the wrist is held exactly as in the ready pose.

    $PY .../compare_tread_install.py <out.json> <name>=<candidate-dir> ...
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np

import importlib.util

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("tread_install_v2", HERE / "author_tread_install_v2.py")
V2 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V2)
I, P = V2.I, V2.P
ACCEPTED = HERE / "install-source-v4"


def forearm_in_hand(case: dict, frame: int, rig: dict) -> np.ndarray:
    """The unit elbow-to-wrist direction expressed in the hand's own frame."""
    parents, _, inverse_inverse = I.A.hierarchy(rig)
    actual, _, _ = I.A.joints(case, frame, parents, inverse_inverse)
    direction = actual[19][:3, 3] - actual[18][:3, 3]
    local = np.linalg.inv(actual[19][:3, :3]) @ direction
    return local / np.linalg.norm(local)


def holding(case: dict, frame: int, parts: list, rig: dict, ready_local: np.ndarray) -> dict:
    """Shaft elevation and lateral offset, grip position and wrist deviation at one key."""
    pivot = np.asarray(rig["pick_binding"]["prop_local_grip_m"], dtype=float)
    matrix = P._affine64(case["matrices"][frame, 24])
    grip = (matrix[:3, :3] @ pivot + matrix[:3, 3]) * 1024
    grip[1] += float(case["grounding"][frame]) * 1024
    poll = I.prop_points(case, frame, parts[1])[I.POLL_VERTEX]
    shaft = grip - poll
    elevation = float(np.degrees(np.arctan2(shaft[1], np.hypot(shaft[0], shaft[2]))))
    deviation = float(np.degrees(np.arccos(np.clip(forearm_in_hand(case, frame, rig) @ ready_local, -1, 1))))
    return {"shaft_elevation_degrees": round(elevation, 1), "shaft_lateral_u": round(float(shaft[0])),
            "grip_u": [round(float(v)) for v in grip], "poll_u": [round(float(v)) for v in poll],
            "wrist_deviation_degrees": round(deviation, 1)}


def read_cases(folder: Path, parts: list) -> list:
    """The stored image's clips, by its own compilation digest."""
    compiled = json.loads((folder / "compilation.json").read_text())
    return I.M.S.read_image(folder / "mole-worker.ugactor", compiled["content_sha256"], parts)


def main() -> int:
    """Measure the accepted v4 and every named candidate, and write the table."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("candidates", nargs="+")
    args = parser.parse_args()
    V2.require(not args.out.exists(), "COMPARE_OUTPUT_EXISTS")
    I.M.W.snapshot_sources = V2.V1.FLIGHT.historical_snapshot
    original, parts, rig, _, _, _, _ = I.M.read_actual_source()
    ready_local = forearm_in_hand(original[0], 8, rig)
    rows = {"accepted v4 (L0 -> T0)": holding(read_cases(ACCEPTED, parts)[0], 16, parts, rig, ready_local)}
    for item in args.candidates:
        name, folder = item.split("=", 1)
        record = json.loads((Path(folder) / "candidate.json").read_text())
        row = holding(read_cases(Path(folder), parts)[0], 16, parts, rig, ready_local)
        row["recipe"] = record["source_recipe"]
        rows[name] = row
    args.out.write_text(json.dumps({"schema": 1, "decision": "1209", "contact_key": 16, "rows": rows,
                                    "scope": "float diagnostics for review; not a proof"}, indent=2) + "\n")
    print(json.dumps(rows, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
