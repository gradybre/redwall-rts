#!/usr/bin/env python3
"""Close-up of the right hand on the pick handle (ADR 1209 step 4, revision 3); a review aid, not a proof.

Each row is one pose, zoomed x1.4 on the grip pivot: from the front, from the mole's right side (the hand toward
the camera) and from above. Rows are given as `label=<image-dir>:<clip>:<key>`; `label=ready` draws the compact
ready carry (key 8), the source the grip comes from. Grip (palm) triangles are tinted; the pick is brown.

    $PY .../render_tread_grip.py <out.png> "accepted v4=.../install-source-v4:0:16" "d=.../candidate-d:0:16" ...
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("render_tread_install", HERE / "render_tread_install.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)
T, I, P = R.T, R.I, R.P
VIEWS = (("front", (0, 1, 2, 1, 1, -1)), ("right side (hand toward camera)", (2, 1, 0, 1, 1, 1)),
         ("top", (0, 2, 1, 1, -1, 1)))
SCALE = 1.4
PANEL = (420, 360)


def grip_point(case: dict, frame: int, rig: dict) -> np.ndarray:
    """The pick's own grip pivot in u, the panel focus."""
    pivot = np.asarray(rig["pick_binding"]["prop_local_grip_m"], dtype=float)
    matrix = P._affine64(case["matrices"][frame, 24])
    point = (matrix[:3, :3] @ pivot + matrix[:3, 3]) * 1024
    point[1] += float(case["grounding"][frame]) * 1024
    return point


def pose_case(spec: str, original: list, parts: list) -> tuple:
    """The (case, key) a row names, read from its pinned image."""
    if spec == "ready":
        return original[0], 8
    folder, clip, key = spec.rsplit(":", 2)
    compiled = json.loads((Path(folder) / "compilation.json").read_text())
    cases = I.M.S.read_image(Path(folder) / "mole-worker.ugactor", compiled["content_sha256"], parts)
    return cases[int(clip)], int(key)


def main() -> int:
    """One row of three zoomed views per pose."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("rows", nargs="+")
    args = parser.parse_args()
    T.require(not args.out.exists(), "GRIP_OUTPUT_EXISTS")
    T.M.W.snapshot_sources = T.FLIGHT.historical_snapshot
    original, parts, rig, topology, _, _, _ = T.M.read_actual_source()
    ids, _ = I.M.S.body_triangle_ids(parts[0], topology[0][0], rig["rig_binding"])
    grip = np.ones(len(topology[0][0]), dtype=bool)
    grip[ids] = False
    sheet = Image.new("RGB", (PANEL[0] * 3, (PANEL[1] + 10) * len(args.rows) + 20), R.BACKGROUND)
    for row, item in enumerate(args.rows):
        label, spec = item.split("=", 1)
        case, key = pose_case(spec, original, parts)
        meshes = R.meshes_at(case, key, parts, topology, grip)
        focus = grip_point(case, key, rig)
        for column, (name, axes) in enumerate(VIEWS):
            sheet.paste(R.panel(PANEL, f"{label}: {name} (x{SCALE})", meshes, [], axes, SCALE, focus),
                        (column * PANEL[0], row * (PANEL[1] + 10)))
    ImageDraw.Draw(sheet).text((10, sheet.height - 16), "Right hand on the pick, zoomed on the grip pivot. Palm "
                               "triangles tinted. Review aid only; the proofs decide clearance.", fill=(120, 35, 30))
    sheet.save(args.out)
    print(json.dumps({"image": str(args.out), "sha256": hashlib.sha256(args.out.read_bytes()).hexdigest()}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
