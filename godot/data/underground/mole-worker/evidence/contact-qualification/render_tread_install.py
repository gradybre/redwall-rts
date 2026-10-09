#!/usr/bin/env python3
"""Render a tread-install candidate for Brendan's review (ADR 1209 step 4); not a clearance proof.

`overview.png`: the contact key (the poll on the workpiece) from the front, the side and the top, with every
body/clothing and pick triangle painter-sorted and the fixture prisms drawn as outlines. `hands.png`: the right
hand and adze at the workpiece, and the feet between the workpiece and the riser behind, zoomed x1.3.
`motion.png`: side views of the entry (keys 0, 10, 20, 30) and the tap (keys 0 and 16). `review.json` holds
float vertex gaps for the reviewer. Grip (palm) triangles are tinted; the proofs in `proof.json` decide.

    $PY .../render_tread_install.py <candidate-dir> <out-dir>
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
SPEC = importlib.util.spec_from_file_location("tread_install", HERE / "author_tread_install.py")
T = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(T)
I, P = T.I, T.P
BODY_RGB, GRIP_RGB, TOOL_RGB = (125, 134, 146), (196, 120, 96), (150, 112, 70)
PRISM_RGB = {0: (60, 110, 60), 3: (60, 110, 60), 6: (190, 120, 20)}
VIEWS = (("Front", (0, 1, 2, 1, 1, -1)), ("Side, forward to right", (2, 1, 0, -1, 1, -1)),
         ("Top, forward up", (0, 2, 1, 1, -1, 1)))
BACKGROUND = (243, 242, 235)


def project(points: np.ndarray, axes: tuple, focus: np.ndarray, scale: float, centre: tuple) -> np.ndarray:
    """Orthographic projection of u coordinates into panel pixels."""
    horizontal, vertical, _, sign_x, sign_y, _ = axes
    return np.stack((centre[0] + sign_x * (points[:, horizontal] - focus[horizontal]) * scale,
                     centre[1] - sign_y * (points[:, vertical] - focus[vertical]) * scale), axis=1)


def box_edges(box: list) -> list:
    """The twelve edges of an axis-aligned prism."""
    corners = np.array([[x, y, z] for x in (box[0], box[3]) for y in (box[1], box[4]) for z in (box[2], box[5])],
                       dtype=float)
    pairs = [(a, b) for a in range(8) for b in range(a + 1, 8) if bin(a ^ b).count("1") == 1]
    return [(corners[a], corners[b]) for a, b in pairs]


def panel(size: tuple, title: str, meshes: list, prisms: list, axes: tuple, scale: float, focus: np.ndarray) -> Image.Image:
    """Painter view of every triangle, then the fixture prisms' outlines on top."""
    width, height = size
    image = Image.new("RGB", size, BACKGROUND)
    draw = ImageDraw.Draw(image)
    centre = (width / 2, 30 + (height - 30) / 2)
    depth, near = axes[2], axes[5]
    triangles = []
    for points, indices, colours in meshes:
        shown = project(points, axes, focus, scale, centre)
        for tri, colour in zip(indices, colours):
            v = points[tri]
            normal = np.cross(v[1] - v[0], v[2] - v[0])
            light = .58 + .42 * abs(float(normal @ np.array([.2, .8, -.4]))) / max(1., float(np.linalg.norm(normal)))
            rgb = tuple(int(c) for c in np.clip(np.asarray(colour) * light, 0, 255))
            triangles.append((near * float(v[:, depth].mean()), [tuple(p) for p in shown[tri]], rgb))
    for _, points, rgb in sorted(triangles, key=lambda row: row[0]):
        draw.polygon(points, fill=rgb)
    for box, rgb in prisms:
        for a, b in box_edges(box):
            ends = project(np.stack((a, b)), axes, focus, scale, centre)
            draw.line([tuple(ends[0]), tuple(ends[1])], fill=rgb, width=2)
    draw.rectangle((0, 0, width - 1, height - 1), outline=(190, 190, 185))
    draw.text((8, 8), title, fill=(30, 35, 40))
    return image


def load(candidate: Path) -> tuple:
    """Rebuild the candidate from its own recipe and check it against the stored image."""
    record = json.loads((candidate / "candidate.json").read_text())
    T.M.W.snapshot_sources = T.FLIGHT.historical_snapshot
    original, parts, rig, topology, roots, _, _ = T.M.read_actual_source()
    cases, _ = T.source_motion(original[0], parts[1], rig, record["source_recipe"])
    compiled = json.loads((candidate / "compilation.json").read_text())
    stored = I.M.S.read_image(candidate / "mole-worker.ugactor", compiled["content_sha256"], parts)
    for actual, expected in zip(stored, cases):
        T.require(actual["matrices"].tobytes() == expected["matrices"].tobytes(), "RENDER_SOURCE_DRIFT")
    return record, cases, parts, rig, topology


def pose(case: dict, frame: int, parts: list) -> tuple:
    """Body and tool vertices (u) at one key."""
    body = I.G.source_positions(parts[0], case["matrices"][frame], case["grounding"][frame])
    return body, I.prop_points(case, frame, parts[1])


def meshes_at(case: dict, frame: int, parts: list, topology: list, grip: np.ndarray) -> list:
    """Coloured body (grip tinted) and tool meshes at one key."""
    body, tool = pose(case, frame, parts)
    body_tri, tool_tri = topology[0][0], topology[1][0]
    return [(body, body_tri, [GRIP_RGB if g else BODY_RGB for g in grip]), (tool, tool_tri, [TOOL_RGB] * len(tool_tri))]


def outside_gap(points: np.ndarray, box: list) -> float:
    """Smallest float distance from any vertex to the prism (0 when a vertex is inside)."""
    low, high = np.asarray(box[:3], dtype=float), np.asarray(box[3:], dtype=float)
    delta = np.maximum(np.maximum(low - points, points - high), 0)
    return float(np.sqrt((delta ** 2).sum(axis=1)).min())


def review_numbers(record: dict, cases: list, parts: list, topology: list, grip: np.ndarray) -> dict:
    """Float vertex gaps for the reviewer: body to each prism over every key, and tool to non-grip body."""
    solids, labels = record["fixture"]["solids_u"], record["fixture"]["source_labels"]
    gaps = {label: [] for label in labels}
    tool_body = []
    keep = np.ones(len(parts[0]["geometry"][0]["points"]), dtype=bool)
    keep[np.unique(topology[0][0][grip])] = False
    for case in cases:
        for frame in range(case["frames"]):
            body, tool = pose(case, frame, parts)
            above = body[body[:, 1] > 1]
            for box, label in zip(solids, labels):
                gaps[label].append(outside_gap(above, box))
            near = body[keep]
            tool_body.append(min(float(np.sqrt(((near[None] - tool[i:i + 64, None]) ** 2).sum(-1)).min())
                                 for i in range(0, len(tool), 64)))
    return {"body_above_sole_to_prism_min_u": {k: round(min(v), 1) for k, v in gaps.items()},
            "tool_to_non_grip_body_min_u": round(min(tool_body), 1),
            "scope": "float vertex diagnostics over every key of entry/work/recovery; not a clearance proof"}


def main() -> int:
    """Write overview.png, hands.png, motion.png and review.json."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    T.require(not args.out.exists(), "RENDER_OUTPUT_EXISTS")
    record, cases, parts, rig, topology = load(args.candidate)
    ids, omitted = I.M.S.body_triangle_ids(parts[0], topology[0][0], rig["rig_binding"])
    grip = np.ones(len(topology[0][0]), dtype=bool)
    grip[ids] = False
    prisms = [(box, PRISM_RGB.get(at, (120, 120, 120))) for at, box in enumerate(record["fixture"]["solids_u"])
              if at in PRISM_RGB]
    work = cases[0]
    contact = meshes_at(work, 16, parts, topology, grip)
    args.out.mkdir(parents=True)
    overview = Image.new("RGB", (1710, 560), BACKGROUND)
    for at, (name, axes) in enumerate(VIEWS):
        overview.paste(panel((570, 530), name + " (contact key)", contact, prisms, axes, .43,
                             np.array([0., 360., -60.])), (at * 570, 0))
    ImageDraw.Draw(overview).text((20, 538), "UNQUALIFIED authoring preview (ADR 1209 tread install); green: support "
                                  "deck and the deck behind; orange: the workpiece. Not a clearance proof.", fill=(120, 35, 30))
    overview.save(args.out / "overview.png")
    poll = I.prop_points(work, 16, parts[1])[I.POLL_VERTEX]
    hands = Image.new("RGB", (1600, 860), BACKGROUND)
    for row, (label, focus) in enumerate((("Adze on the workpiece", poll), ("Feet, workpiece and riser", np.array([0., 90., 0.])))):
        for column, (name, axes) in enumerate(VIEWS):
            hands.paste(panel((533, 410), f"{label}: {name} (x1.3)", contact, prisms, axes, 1.3, focus),
                        (column * 533, row * 420))
    ImageDraw.Draw(hands).text((20, 842), "Grip (palm) triangles tinted. Zoomed review aid only.", fill=(120, 35, 30))
    hands.save(args.out / "hands.png")
    keys = [(cases[1], 0, "entry 0 (ready)"), (cases[1], 10, "entry 10"), (cases[1], 20, "entry 20"),
            (cases[1], 30, "entry 30"), (work, 0, "tap 0 (poll raised)"), (work, 16, "tap 16 (contact)")]
    motion = Image.new("RGB", (1710, 1080), BACKGROUND)
    for at, (case, frame, title) in enumerate(keys):
        motion.paste(panel((570, 530), "Side: " + title, meshes_at(case, frame, parts, topology, grip), prisms,
                           VIEWS[1][1], .43, np.array([0., 360., -60.])), ((at % 3) * 570, (at // 3) * 540))
    motion.save(args.out / "motion.png")
    numbers = review_numbers(record, cases, parts, topology, grip)
    numbers["images_sha256"] = {n: hashlib.sha256((args.out / n).read_bytes()).hexdigest()
                                for n in ("overview.png", "hands.png", "motion.png")}
    numbers["renderer_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    (args.out / "review.json").write_text(json.dumps(numbers, indent=2) + "\n")
    print(json.dumps(numbers))
    return 0


if __name__ == "__main__":
    sys.exit(main())
