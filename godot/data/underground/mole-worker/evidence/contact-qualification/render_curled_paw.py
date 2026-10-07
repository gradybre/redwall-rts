#!/usr/bin/env python3
"""ADR 1216 step 1 review images: the curled paw on the pick shaft, beside the accepted grip, at one zoom.

`grip.png`: the compact ready carry, from the front, the right side and above, centred on the paw.
- Row 1 is the accepted closed paw with the accepted fit.
- Row 2 is the curled paw with the `lateral-2` fit.

`paw-alone.png`: the right paw in its own frame, without the pick.
- Row 1 is the accepted closed paw.
- Row 2 is the curled paw.
- The shaft's cross-section is drawn as an outline.
- Views: palm (+Z), side (+X) and fingertips (+Y).

A review aid, not a proof.

    $PY .../render_curled_paw.py <paw-dir> <out-dir>
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


def load(name: str, path: Path):
    """Import one sibling script by path."""
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


GRIP = load("render_tread_grip", HERE / "render_tread_grip.py")
REFIT = load("author_pick_refit", HERE / "author_pick_refit.py")
PAW = load("author_curled_paw", HERE / "author_curled_paw.py")
R, T = GRIP.R, GRIP.T
SCALE = 1.6
PAW_SCALE = 1.8
PAW_VIEWS = (("palm (+Z toward camera)", (0, 1, 2, 1, 1, 1)), ("side (+X toward camera)", (2, 1, 0, -1, 1, 1)),
             ("fingertips (+Y toward camera)", (0, 2, 1, 1, 1, 1)))


def with_points(parts: list, points: np.ndarray) -> list:
    """The body part with replaced rest points; every other field is the accepted one."""
    body = dict(parts[0])
    body["geometry"] = [dict(parts[0]["geometry"][0], points=points.astype(np.float32))]
    return [body, parts[1]]


def grip_sheet(original: list, parts: list, rig: dict, topology: list, grip: np.ndarray, paw: dict, rest: np.ndarray) -> Image.Image:
    """Two rows of the ready carry: accepted grip, then curled paw with the lateral-2 fit."""
    curled_parts = with_points(parts, rest)
    refit = REFIT.refit_ready(original[0], rig, np.asarray(paw["fit_hand_to_pick_lateral_2"]))
    rows = [("accepted closed paw, accepted fit", original[0], parts), ("curled paw, lateral-2 fit", refit, curled_parts)]
    focus = GRIP.grip_point(original[0], 8, rig)
    sheet = Image.new("RGB", (GRIP.PANEL[0] * 3, (GRIP.PANEL[1] + 10) * len(rows)), R.BACKGROUND)
    for row, (label, case, body) in enumerate(rows):
        meshes = R.meshes_at(case, 8, body, topology, grip)
        for column, (name, axes) in enumerate(GRIP.VIEWS):
            sheet.paste(R.panel(GRIP.PANEL, f"{label}: {name} (x{SCALE})", meshes, [], axes, SCALE, focus),
                        (column * GRIP.PANEL[0], row * (GRIP.PANEL[1] + 10)))
    return sheet


def shaft_outline(paw: dict, x_range: list) -> list:
    """The shaft as a prism outline in hand-local u (its square hull around the axis, across the paw)."""
    y, z = (v * 1024 for v in paw["shaft_axis_yz_m"])
    r = paw["shaft_radius_m"] * 1024
    return [([x_range[0] * 1024 - 40, y - r, z - r, x_range[1] * 1024 + 40, y + r, z + r], (190, 120, 20))]


def paw_sheet(parts: list, rig: dict, topology: list, paw: dict, curled_local: np.ndarray) -> Image.Image:
    """The paw alone in its own frame: accepted closed paw, then curled."""
    closed, _ = REFIT.hand_local(parts, rig)
    weight = np.clip(np.sum(np.where(parts[0]["geometry"][0]["ids"] == REFIT.HAND, parts[0]["geometry"][0]["weights"], 0), axis=1), 0, 1)
    triangles = topology[0][0]
    keep = triangles[np.all(weight[triangles] > 0, axis=1)]
    sheet = Image.new("RGB", (GRIP.PANEL[0] * 3, (GRIP.PANEL[1] + 10) * 2), R.BACKGROUND)
    for row, (label, local) in enumerate((("accepted closed paw", closed), ("curled paw", curled_local))):
        points = local * 1024
        colours = [(196, 120, 96) if points[t, 1].mean() > PAW.CENTRE_M[1] * 1024 else (125, 134, 146) for t in keep]
        prisms = shaft_outline(paw, paw["paw_width_x_m"]) if row == 1 else []
        for column, (name, axes) in enumerate(PAW_VIEWS):
            sheet.paste(R.panel(GRIP.PANEL, f"{label}: {name} (x{PAW_SCALE})", [(points, keep, colours)], prisms, axes,
                                PAW_SCALE, np.array([-10., 70., 20.])), (column * GRIP.PANEL[0], row * (GRIP.PANEL[1] + 10)))
    ImageDraw.Draw(sheet).text((10, sheet.height - 14), "Hand frame. Tinted: the finger region beyond the socket line. "
                               "Orange outline: the shaft (curled row). Review aid only.", fill=(120, 35, 30))
    return sheet


def main() -> int:
    """Write grip.png and paw-alone.png and their digests."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paw_dir", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    T.require(not args.out.exists(), "PAW_RENDER_OUTPUT_EXISTS")
    T.M.W.snapshot_sources = T.FLIGHT.historical_snapshot
    original, parts, rig, topology, _, _, _ = T.M.read_actual_source()
    paw = json.loads((args.paw_dir / "paw.json").read_text())
    rest = np.load(args.paw_dir / "curled-rest-points.npy")
    T.require(hashlib.sha256((args.paw_dir / "curled-rest-points.npy").read_bytes()).hexdigest()
              == paw["curled_rest_points_sha256"], "PAW_POINTS_DRIFT")
    ids, _ = T.I.M.S.body_triangle_ids(parts[0], topology[0][0], rig["rig_binding"])
    grip = np.ones(len(topology[0][0]), dtype=bool)
    grip[ids] = False
    derived = PAW.derive(parts, rig)
    args.out.mkdir(parents=True)
    grip_sheet(original, parts, rig, topology, grip, paw, rest).save(args.out / "grip.png")
    paw_sheet(parts, rig, topology, paw, derived["curled_local"]).save(args.out / "paw-alone.png")
    digests = {name: hashlib.sha256((args.out / name).read_bytes()).hexdigest() for name in ("grip.png", "paw-alone.png")}
    (args.out / "images.json").write_text(json.dumps({"schema": 1, "images_sha256": digests,
        "renderer_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}, indent=2) + "\n")
    print(json.dumps(digests))
    return 0


if __name__ == "__main__":
    sys.exit(main())
