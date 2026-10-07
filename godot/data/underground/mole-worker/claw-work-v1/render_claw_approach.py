#!/usr/bin/env python3
"""Review images for the narrow tool-free claw approach and retreat (ADR 1217 step 4d). Not a proof.

Drawn with the accepted painter renderer (`render_tread_install.panel`) on the open paw (source 4's body), paws
tinted. Outlines: the narrow row's BODY box (green), row 42's all-yaw BODY box (red) and the pending bearer prism
(brown), all station-local at yaw 0.

- `overview.png`: ready key 8 at H (L0 bearer) and at the L0 contact (T0 bearer), front and side.
- `motion.png`: side views of the approach. The walk at a fixed heading with the root 1,024, 512 and 0 u behind the
  station (every 6th key), then the READY fade from walk key 31 at shares 0, 1/4, 1/2, 3/4 and 1.
- `paws.png`: close-ups (x0.9) of the right paw and thigh in the walk-to-ready fade from keys 30-33 at share 5/8,
  where the paw passes nearest the thigh.

    $PY .../render_claw_approach.py <approach-dir> <out-dir>
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw

import author_claw_approach as A

SRC = A.SRC
SPEC = importlib.util.spec_from_file_location("approach_painter", SRC.I.PROOF / "render_tread_install.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)
PAW_RGB, NARROW_RGB, WIDE_RGB, BEARER_RGB = (196, 120, 96), (40, 140, 60), (190, 40, 40), (150, 100, 40)
WIDE_BODY = [-712, 0, -712, 712, 930, 712]
SITES = {"H": "H (L0 bearer, assembly 0)", "L0 contact": "L0 contact (T0 bearer, assembly 1)"}
FADE_KEY, NEAR_KEYS, NEAR_SHARE = 31, (30, 31, 32, 33), 0.625


def colours(data: dict) -> list:
    """Paw triangles tinted; the rest the standard body colour."""
    geometry, triangles = data["body"]["geometry"][0], data["triangles"]
    paw = np.any(np.isin(geometry["ids"], [15, 19]) & (geometry["weights"] > 0), axis=1)[triangles].any(axis=1)
    return [PAW_RGB if p else R.BODY_RGB for p in paw]


def pose(data: dict, frames: tuple, weights: tuple, offset_z: float = 0.0) -> np.ndarray:
    """Body vertices (u) for one blend of stored keys (stand keys first, then walk), root moved along +Z."""
    stand, walk = data["stand"], data["walk"]
    mats = np.concatenate([stand["matrices"][:, :24], walk["matrices"][:, :24]]).astype(np.float64)
    grounds = np.concatenate([stand["grounding"], walk["grounding"]]).astype(np.float64)
    w = np.asarray(weights, dtype=np.float64)
    case = {"frames": 1, "matrices": np.tensordot(w, mats[list(frames)], 1)[None].astype(np.float32),
            "grounding": np.array([float(w @ grounds[list(frames)])], dtype=np.float32)}
    points = SRC.I.points_at(case, data["body"], 0)
    points[:, 2] += offset_z
    return points


def panel(data, colour, points, title, view, scale, focus, size, boxes) -> Image.Image:
    """One painter view with outlined boxes."""
    return R.panel(size, title, [(points, data["triangles"], colour)], boxes, view[1], scale, focus)


def grid(panels: list, columns: int, size: tuple, note: str) -> Image.Image:
    """Panels on a grid with a footnote."""
    rows = -(-len(panels) // columns)
    sheet = Image.new("RGB", (size[0] * columns, size[1] * rows + 24), R.BACKGROUND)
    for at, image in enumerate(panels):
        sheet.paste(image, ((at % columns) * size[0], (at // columns) * size[1]))
    ImageDraw.Draw(sheet).text((12, size[1] * rows + 6), note, fill=(120, 35, 30))
    return sheet


def overview(data, colour, narrow) -> Image.Image:
    """Ready key 8 at both sites, front and side, with the three outlines."""
    size, panels = (520, 560), []
    ready = pose(data, (A.READY,), (1.0,))
    for label, site in SITES.items():
        boxes = [(narrow, NARROW_RGB), (WIDE_BODY, WIDE_RGB), (A.BEARERS[site], BEARER_RGB)]
        for view in (R.VIEWS[0], R.VIEWS[1]):
            panels.append(panel(data, colour, ready, f"{label}, ready key 8: {view[0].split(',')[0]}", view, .32,
                                np.array([0., 420., -150.]), size, boxes))
    return grid(panels, 4, size, "Green: narrow row BODY box. Red: row 42 all-yaw BODY box. Brown: pending bearer "
                "prism. Station-local, yaw 0, facing -Z. Review aid only; author_claw_approach.py decides.")


def motion(data, colour, narrow) -> Image.Image:
    """The fixed-heading walk with the root behind the station, then the fade into ready."""
    size, panels, walk0 = (300, 380), [], data["stand"]["frames"]
    boxes = [(narrow, NARROW_RGB), (A.BEARERS[SITES["L0 contact"]], BEARER_RGB)]
    for offset in (1024, 512, 0):
        for key in range(0, data["walk"]["frames"] - 1, 6):
            panels.append(panel(data, colour, pose(data, (walk0 + key,), (1.0,), offset), f"walk {key}, root +{offset}",
                                R.VIEWS[1], .13, np.array([0., 420., 450.]), size, boxes))
    for share in (0, .25, .5, .75, 1):
        points = pose(data, (walk0 + FADE_KEY, A.READY), (1 - share, share))
        panels.append(panel(data, colour, points, f"fade walk {FADE_KEY} -> ready {share:.2f}", R.VIEWS[1], .22,
                            np.array([0., 420., 300.]), size, boxes))
    return grid(panels, 8, size, "Side views, forward to the right; the T0 bearer at the L0 contact. Rows: root "
                "1,024, 512 and 0 u behind the station; last row the READY fade. Retreat replays these in reverse.")


def paws(data, colour) -> Image.Image:
    """The right paw nearest the thigh in the walk-to-ready fade."""
    size, panels, walk0 = (440, 400), [], data["stand"]["frames"]
    for key in NEAR_KEYS:
        points = pose(data, (walk0 + key, A.READY), (1 - NEAR_SHARE, NEAR_SHARE))
        paw = data["body"]["geometry"][0]["ids"][:, 0] == 19
        focus = points[paw].mean(0)
        for view in (R.VIEWS[0], R.VIEWS[1]):
            panels.append(panel(data, colour, points, f"fade walk {key} -> ready 5/8: {view[0].split(',')[0]} (x0.9)",
                                view, .9, focus, size, []))
    return grid(panels, 4, size, "Right paw (tinted) against the right thigh in the READY fade. Review aid only.")


def main() -> int:
    """Render the three images and record their digests."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("approach", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    A.require(not args.out.exists(), "RENDER_EXISTS")
    record = json.loads((args.approach / "approach.json").read_text())
    data = A.sources(SRC.PALETTE, SRC.PALETTE.parent / "mole-grip-v3.ugpal", SRC.PALETTE.parent / "world-yaw-v1.ugyaw")
    colour, narrow = colours(data), record["canonical_roles"]["BODY_HELD_LOAD"][0]
    args.out.mkdir(parents=True)
    overview(data, colour, narrow).save(args.out / "overview.png")
    motion(data, colour, narrow).save(args.out / "motion.png")
    paws(data, colour).save(args.out / "paws.png")
    review = {"images_sha256": {n: SRC.sha(args.out / n) for n in ("overview.png", "motion.png", "paws.png")},
              "renderer_sha256": SRC.sha(Path(__file__)), "approach_sha256": SRC.sha(args.approach / "approach.json")}
    (args.out / "review.json").write_text(json.dumps(review, indent=2) + "\n")
    print(json.dumps(review["images_sha256"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
