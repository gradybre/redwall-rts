#!/usr/bin/env python3
"""Render a stone grip candidate for the human grip review (ADR 1206); not a clearance proof.

Image 1 uses wood's review views (render_candidate.py: front, side, top; every body/clothing and stone
triangle, painter-sorted). Image 2 zooms on each hand from the front and the side so the reviewer can judge
seating, wrist clearance and finger placement. Grip (distal palm) triangles are tinted; the stone is grey.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import author_handling as A
import author_stone_grip as G
import prove_static_contact as PS

STONE_RGB = [128, 124, 116]
BODY_RGB = [125, 134, 146]
GRIP_RGB = [196, 120, 96]
# (horizontal, vertical, depth, sign_x, sign_y, near): wood's three views; `near` +1 when a larger depth is nearer.
VIEWS = (("Front", (0, 1, 2, 1, 1, -1)), ("Side, forward to right", (2, 1, 0, -1, 1, -1)),
         ("Top, forward up", (0, 2, 1, 1, -1, 1)))


def panel(target: Image.Image, box: tuple, title: str, meshes: list, axes: tuple, scale: float,
          focus: np.ndarray) -> None:
    """Orthographic painter view of every triangle, clipped to its box; `focus` (u) is the panel centre."""
    left, top, width, height = box
    image = Image.new("RGB", (width, height), (243, 242, 235))
    draw = ImageDraw.Draw(image)
    x0, y0 = 0, 0
    horizontal, vertical, depth, sign_x, sign_y, near = axes
    cx, cy = x0 + width / 2, y0 + 30 + (height - 30) / 2
    def projected(points):
        return np.stack((cx + sign_x * (points[:, horizontal] - focus[horizontal]) * scale,
                         cy - sign_y * (points[:, vertical] - focus[vertical]) * scale), axis=1)
    if vertical == 1:
        floor = cy + focus[1] * scale
        draw.line((x0 + 5, floor, x0 + width - 5, floor), fill=(55, 80, 60), width=2)
    triangles = []
    for points, indices, colours in meshes:
        shown = projected(points)
        for tri, colour in zip(indices, colours):
            v = points[tri]
            normal = np.cross(v[1] - v[0], v[2] - v[0])
            light = .58 + .42 * abs(float(normal @ np.array([.2, .8, -.4]))) / max(1., float(np.linalg.norm(normal)))
            rgb = tuple(int(c) for c in np.clip(np.asarray(colour) * light, 0, 255))
            triangles.append((near * float(v[:, depth].mean()), [tuple(p) for p in shown[tri]], rgb))
    for _, points, rgb in sorted(triangles, key=lambda row: row[0]):
        draw.polygon(points, fill=rgb)
    draw.rectangle((x0, y0, x0 + width - 1, y0 + height - 1), outline=(190, 190, 185))
    draw.text((x0 + 8, y0 + 8), title, fill=(30, 35, 40))
    target.paste(image, (left, top))


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "candidate", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    A.require(not args.out.exists(), "STONE_OUTPUT_EXISTS")
    _, body, _, _, topology, _, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    stone, stone_tri = G.stone_part()
    source = np.load(args.candidate / "poses.npz", allow_pickle=False)
    case = {"frames": 2, "matrices": source["matrices"], "grounding": source["grounding"]}
    points = A.I.points_at(case, body, 1)
    cargo = A.I.points_at(case, stone, 1, 24)
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    _, hands = PS.hand_partition(body, body_tri, topology["rig_binding"])
    grip = np.zeros(len(body_tri), dtype=bool)
    grip[np.concatenate(hands)] = True
    meshes = [(points, body_tri, [GRIP_RGB if g else BODY_RGB for g in grip]),
              (cargo, stone_tri, [STONE_RGB] * len(stone_tri))]
    args.out.mkdir(parents=True)
    overview = Image.new("RGB", (1710, 560), (243, 242, 235))
    draw = ImageDraw.Draw(overview)
    centre = np.array([0., 300., -300.])
    for at, (name, axes) in enumerate(VIEWS):
        panel(overview, (at * 570, 0, 570, 530), name, meshes, axes, .43, centre)
    draw.text((20, 538), "UNQUALIFIED authoring preview (ADR 1206 stone grip); orthographic painter rendering is not a clearance proof",
              fill=(120, 35, 30))
    overview.save(args.out / "overview.png")
    hands_image = Image.new("RGB", (1600, 860), (243, 242, 235))
    draw = ImageDraw.Draw(hands_image)
    for row, (label, rows) in enumerate((("Left hand", hands[0]), ("Right hand", hands[1]))):
        focus = points[np.unique(body_tri[rows])].mean(axis=0)
        for column, (name, axes) in enumerate(VIEWS):
            panel(hands_image, (column * 533, row * 420, 533, 410), f"{label}: {name} (x1.3)", meshes, axes,
                  1.3, focus)
    draw.text((20, 842), "Grip (distal palm) triangles tinted; stone grey. Zoomed review aid only.", fill=(120, 35, 30))
    hands_image.save(args.out / "hands.png")
    digests = {name: hashlib.sha256((args.out / name).read_bytes()).hexdigest() for name in ("overview.png", "hands.png")}
    print(json.dumps({"render": str(args.out), "sha256": digests, "qualification": False}))


if __name__ == "__main__":
    main()
