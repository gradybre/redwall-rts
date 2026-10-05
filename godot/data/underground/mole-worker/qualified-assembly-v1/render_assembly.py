#!/usr/bin/env python3
"""Full-triangle orthographic authoring inspection, never native or clearance evidence."""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import prove_assembly as B


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--clip", type=int, default=1)
    parser.add_argument("--frame", type=int, default=16)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    B.P.require(not args.out.exists(), "ASSEMBLY_OUTPUT_EXISTS")
    report, clips = B.sources(args.candidate)
    _, parts, rig, topology, _, _, _, _, _ = B.I.source_inputs()
    B.P.require(0 <= args.clip < 3 and 0 <= args.frame < clips[args.clip]["frames"], "ASSEMBLY_RENDER_ARGUMENT")
    case = clips[args.clip]
    body = B.A.G.source_positions(parts[0], case["matrices"][args.frame], case["grounding"][args.frame])
    tool = B.I.M.I.I.prop_points(case, args.frame, parts[1])
    dz = report["clips"][args.clip]["beam_offset_z_u"][args.frame]
    beam = np.asarray([[x, y, z+dz] for x in (-256, 256) for y in (0, 128) for z in (-512, -384)])
    faces = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    beam_tri = np.asarray([[face[0], face[1], face[2]] for face in faces] +
                          [[face[0], face[2], face[3]] for face in faces], dtype=np.int32)
    palms = B.A.palm_rows(parts[0], topology[0][0], rig)
    image = Image.new("RGB", (1800, 700), (241, 240, 232))
    draw = ImageDraw.Draw(image)
    for panel, (name, axes) in enumerate((("Front", (0, 1, 2, 1)), ("Right side", (2, 1, 0, -1)),
                                         ("Left side", (2, 1, 0, 1)))):
        horizontal, vertical, depth, sign = axes
        cx, cy, scale = panel*600 + 295, 615, .56
        draw.line((panel*600+10, cy, panel*600+590, cy), fill=(45, 80, 48), width=2)
        ordered = []
        for points, triangles, kind in ((body, topology[0][0], 0), (tool, topology[1][0], 1), (beam, beam_tri, 2)):
            projected = np.stack((cx+points[:, horizontal]*sign*scale, cy-points[:, vertical]*scale), axis=1)
            for at, triangle in enumerate(triangles):
                vertices = points[triangle]
                normal = np.cross(vertices[1]-vertices[0], vertices[2]-vertices[0])
                shade = .60 + .4*abs(float(normal @ [.3, .8, -.4]))/max(1., np.linalg.norm(normal))
                base = [122, 134, 146] if kind == 0 else [86, 71, 53] if kind == 1 else [165, 100, 48]
                if kind == 0 and palms[at]:
                    base = [190, 138, 119]
                color = tuple(int(v) for v in np.clip(np.asarray(base)*shade, 0, 255))
                ordered.append((float(vertices[:, depth].mean())*(1 if panel != 2 else -1),
                                [tuple(point) for point in projected[triangle]], color))
        for _, points, color in sorted(ordered, reverse=True, key=lambda row: row[0]):
            draw.polygon(points, fill=color)
        draw.text((panel*600+15, 18), name + " — complete source body, pick and T0 bearer", fill=(25, 32, 38))
    draw.text((20, 667), "UNQUALIFIED source inspection: orthographic painter output is not a native or clearance proof.", fill=(135, 30, 30))
    image.save(args.out)


if __name__ == "__main__":
    main()
