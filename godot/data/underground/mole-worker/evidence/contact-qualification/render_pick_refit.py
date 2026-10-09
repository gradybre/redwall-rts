#!/usr/bin/env python3
"""Close-up of the paw holding the pick at the ready carry: the accepted fit beside successor fits (ADR 1216).

Each row is the compact ready carry (key 8) with one fit, viewed from the front, the right side and above, all
centred on the accepted grip pivot at the same zoom. A review aid, not a proof.

    $PY .../render_pick_refit.py <out.png> <fit.json> [<fit.json> ...]
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent


def load(name: str, path: Path):
    """Import one sibling script by path."""
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


GRIP = load("render_tread_grip", HERE / "render_tread_grip.py")
REFIT = load("author_pick_refit", HERE / "author_pick_refit.py")
R, T = GRIP.R, GRIP.T
SCALE = 0.9


def main() -> int:
    """One row per fit: the accepted fit first."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("fits", nargs="+", type=Path)
    args = parser.parse_args()
    T.require(not args.out.exists(), "REFIT_RENDER_OUTPUT_EXISTS")
    T.M.W.snapshot_sources = T.FLIGHT.historical_snapshot
    original, parts, rig, topology, _, _, _ = T.M.read_actual_source()
    ids, _ = T.I.M.S.body_triangle_ids(parts[0], topology[0][0], rig["rig_binding"])
    grip = np.ones(len(topology[0][0]), dtype=bool)
    grip[ids] = False
    rows = [("accepted fit", original[0])]
    for path in args.fits:
        fit = np.asarray(json.loads(path.read_text())["fit_hand_to_pick"])
        rows.append(("successor " + path.parent.name, REFIT.refit_ready(original[0], rig, fit)))
    focus = GRIP.grip_point(original[0], 8, rig)
    sheet = Image.new("RGB", (GRIP.PANEL[0] * 3, (GRIP.PANEL[1] + 10) * len(rows)), R.BACKGROUND)
    for row, (label, case) in enumerate(rows):
        meshes = R.meshes_at(case, 8, parts, topology, grip)
        for column, (name, axes) in enumerate(GRIP.VIEWS):
            sheet.paste(R.panel(GRIP.PANEL, f"{label}, ready carry: {name} (x{SCALE})", meshes, [], axes, SCALE, focus),
                        (column * GRIP.PANEL[0], row * (GRIP.PANEL[1] + 10)))
    sheet.save(args.out)
    print(json.dumps({"image": str(args.out), "sha256": hashlib.sha256(args.out.read_bytes()).hexdigest()}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
