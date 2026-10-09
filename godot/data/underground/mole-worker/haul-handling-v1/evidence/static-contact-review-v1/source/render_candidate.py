#!/usr/bin/env python3
"""Render every original source triangle for visual authoring; not a native or collision qualification."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import author_handling as A


def wood_topology(path: Path, wood: dict) -> np.ndarray:
    A.require(path.is_file() and path.stat().st_size <= 1024 * 1024 and
              hashlib.sha256(path.read_bytes()).hexdigest() == A.I.WOOD_TOPOLOGY_SHA, "HANDLING_WOOD_SOURCE")
    capture = json.loads(path.read_text())
    points = np.asarray(capture["points"], dtype="<f4")
    original = wood["geometry"][0]
    A.require(capture["vertex_count"] == len(points) == 522 and
              points.tobytes() == original["points"].astype("<f4").tobytes() and
              capture["bounds"] == wood["mesh_aabb"] and capture["format"] == wood["surface_formats"][0],
              "HANDLING_NATIVE_WOOD_IDENTITY")
    indices = np.asarray(capture["indices"], dtype=np.int32)
    A.require(indices.shape == (2304,) and np.all((0 <= indices) & (indices < 522)), "HANDLING_WOOD_TRIANGLES")
    return indices.reshape(-1, 3)


def panel(draw: ImageDraw.ImageDraw, x: int, title: str, body: np.ndarray, cargo: np.ndarray,
          body_tri: np.ndarray, wood_tri: np.ndarray, labels: np.ndarray, axes: tuple) -> None:
    horizontal, vertical, depth, sign_x, sign_y = axes
    scale, cx, cy = .43, x + 285, 455
    def projected(points):
        return np.stack((cx + sign_x * points[:, horizontal] * scale,
                         cy - sign_y * points[:, vertical] * scale), axis=1)
    grid = (216, 218, 215)
    for at in range(-768, 1025, 256):
        offset = at * scale
        draw.line((x + 20, cy - offset, x + 550, cy - offset), fill=grid)
        draw.line((cx + offset, 55, cx + offset, 520), fill=grid)
    draw.line((x + 20, cy, x + 550, cy), fill=(55, 80, 60), width=2)
    triangles = []
    for points, indices, is_wood in ((body, body_tri, False), (cargo, wood_tri, True)):
        shown = projected(points)
        for tri in indices:
            vertices = points[tri]
            normal = np.cross(vertices[1] - vertices[0], vertices[2] - vertices[0])
            brightness = .58 + .42 * abs(float(normal @ np.array([.2, .8, -.4]))) / max(1., float(np.linalg.norm(normal)))
            color = np.array([140, 84, 38] if is_wood else [125, 134, 146])
            if not is_wood and np.any(np.isin(labels[tri], [15, 19])):
                color = np.array([179, 142, 130])
            color = tuple(int(v) for v in np.clip(color * brightness, 0, 255))
            triangles.append((float(vertices[:, depth].mean()), [tuple(v) for v in shown[tri]], color))
    for _, points, color in sorted(triangles, key=lambda value: value[0], reverse=True):
        draw.polygon(points, fill=color)
    draw.text((x + 22, 15), title, fill=(30, 35, 40))
    draw.text((x + 22, 35), "All body / clothing / actual wood triangles; u=1/1024 m", fill=(65, 65, 65))


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--wood-topology", type=Path, required=True)
    parser.add_argument("--frame", type=int, default=1)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    A.require(not args.out.exists(), "HANDLING_OUTPUT_EXISTS")
    _, body, wood, _, topology, _, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    source = np.load(args.candidate / "poses.npz", allow_pickle=False)
    case = {"frames": len(source["matrices"]), "matrices": source["matrices"], "grounding": source["grounding"]}
    points = A.I.points_at(case, body, args.frame)
    cargo = A.I.points_at(case, wood, args.frame, 24)
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
    wood_tri = wood_topology(args.wood_topology, wood)
    geometry = body["geometry"][0]
    labels = np.take_along_axis(geometry["ids"], geometry["weights"].argmax(axis=1)[:, None], axis=1)[:, 0]
    output = Image.new("RGB", (1710, 560), (243, 242, 235))
    draw = ImageDraw.Draw(output)
    for at, (name, axes) in enumerate((("Front", (0, 1, 2, 1, 1)), ("Side, forward to right", (2, 1, 0, -1, 1)),
                                      ("Top, forward up", (0, 2, 1, 1, -1)))):
        panel(draw, at * 570, name, points, cargo, body_tri, wood_tri, labels, axes)
    draw.text((20, 538), "UNQUALIFIED authoring preview; orthographic painter rendering is not a clearance proof", fill=(120, 35, 30))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.out)
    print(json.dumps({"render": str(args.out), "sha256": hashlib.sha256(args.out.read_bytes()).hexdigest(),
                      "body_triangles": len(body_tri), "wood_triangles": len(wood_tri), "qualification": False}))


if __name__ == "__main__":
    main()
