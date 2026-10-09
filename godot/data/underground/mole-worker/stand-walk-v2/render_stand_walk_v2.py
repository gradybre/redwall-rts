#!/usr/bin/env python3
"""Review images for the corrected tool-free stand and walk (ADR 1217 / 1199 successor). Not a proof.

Drawn with the accepted painter renderer (`render_tread_install.panel`) on the closed paw (the body rows 30/31 draw);
the paws are tinted, the thighs shaded darker:

- `paws.png`: close-ups (×0.9) of the left paw against the left thigh and the right paw against the right thigh, front
  and side, at stand ready key 8 and at the stand key where each paw sinks deepest into its thigh (measured, float).
  Row pairs: published (ADR 1199) above corrected.
- `walk.png`: the walk cycle, front and side, every 6th key; published above corrected.
- `overview.png`: the whole mole at ready key 8, front and side, published beside corrected.

    $PY .../render_stand_walk_v2.py <candidate-dir> <out-dir>
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw

import author_stand_walk_v2 as V2

A, E, SRC = V2.A, V2.E, V2.SRC
SPEC = importlib.util.spec_from_file_location("stand_painter", SRC.I.PROOF / "render_tread_install.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)
PAW_RGB, THIGH_RGB = (196, 120, 96), (98, 104, 118)
HANDS = {"left": 15, "right": 19}
THIGHS = {"left": "LeftUpLeg", "right": "RightUpLeg"}
WALK_STEP = 6


def colours(src: dict) -> list:
    """Paw triangles tinted, thigh triangles darker, the rest the standard body colour."""
    geometry, triangles = src["body"]["geometry"][0], src["triangles"]
    names = [bone["name"] for bone in src["rig"]["bones"]]
    dominant = geometry["ids"][np.arange(len(geometry["ids"])), np.argmax(geometry["weights"], axis=1)]
    paw = np.isin(geometry["ids"], list(HANDS.values())) & (geometry["weights"] > 0)
    paw = np.any(paw, axis=1)[triangles].any(axis=1)
    thigh = np.isin(dominant, [names.index(n) for n in THIGHS.values()])[triangles].any(axis=1)
    return [PAW_RGB if p else THIGH_RGB if t else R.BODY_RGB for p, t in zip(paw, thigh)]


def points(src: dict, case: dict, frame: int) -> np.ndarray:
    """Body vertices (u) at one key."""
    return SRC.I.points_at(dict(case, matrices=case["matrices"][:, :24]), src["body"], frame)


def deepest(src: dict, case: dict, side: str) -> int:
    """The stand key where the paw's vertices come closest to (or furthest into) the thigh's (float)."""
    geometry = src["body"]["geometry"][0]
    names = [bone["name"] for bone in src["rig"]["bones"]]
    dominant = geometry["ids"][np.arange(len(geometry["ids"])), np.argmax(geometry["weights"], axis=1)]
    paw, thigh = dominant == HANDS[side], dominant == names.index(THIGHS[side])
    gaps = []
    for frame in range(case["frames"] - 1):
        p = points(src, case, frame)
        a, b = p[paw], p[thigh]
        gaps.append(min(float(np.sqrt(((a[i:i + 256, None] - b[None]) ** 2).sum(-1)).min())
                        for i in range(0, len(a), 256)))
    return int(np.argmin(gaps))


def paw_vertices(src: dict, side: str) -> np.ndarray:
    """Vertices whose dominant bone is the paw."""
    geometry = src["body"]["geometry"][0]
    return geometry["ids"][np.arange(len(geometry["ids"])), np.argmax(geometry["weights"], axis=1)] == HANDS[side]


def panel(src, colour, case, frame, title, axes, scale, focus, size) -> Image.Image:
    """One painter view."""
    return R.panel(size, title, [(points(src, case, frame), src["triangles"], colour)], [], axes, scale, focus)


def grid(panels: list, columns: int, size: tuple, note: str) -> Image.Image:
    """Panels on a grid with a footnote."""
    rows = -(-len(panels) // columns)
    sheet = Image.new("RGB", (size[0] * columns, size[1] * rows + 24), R.BACKGROUND)
    for at, image in enumerate(panels):
        sheet.paste(image, ((at % columns) * size[0], (at // columns) * size[1]))
    ImageDraw.Draw(sheet).text((12, size[1] * rows + 6), note, fill=(120, 35, 30))
    return sheet


def paws_sheet(src, colour, old, new) -> Image.Image:
    """Front and side close-ups of each paw at its thigh, published above corrected."""
    size, panels = (440, 400), []
    for side in ("left", "right"):
        keys = [E.READY_FRAME, deepest(src, old["stand"], side)]
        for label, clips in (("published", old), ("corrected", new)):
            for frame in keys:
                focus = points(src, clips["stand"], frame)[paw_vertices(src, side)].mean(0)
                for name, axes in (R.VIEWS[0], R.VIEWS[1]):
                    panels.append(panel(src, colour, clips["stand"], frame, f"{label}, {side} paw, stand {frame}: "
                                        f"{name.split(',')[0]} (x0.9)", axes, .9, focus, size))
    return grid(panels, 4, size, "Paws tinted, thighs darker. Each pair of rows: published (ADR 1199) "
                "above corrected. Review aid only; prove_stand_walk_v2.py decides.")


def walk_sheet(src, colour, old, new) -> Image.Image:
    """The walk cycle, front and side, published above corrected."""
    size, frames = (300, 380), list(range(0, old["walk"]["frames"] - 1, WALK_STEP))
    panels = []
    for name, axes in (R.VIEWS[0], R.VIEWS[1]):
        for label, clips in (("published", old), ("corrected", new)):
            panels += [panel(src, colour, clips["walk"], f, f"{label} walk {f}: {name.split(',')[0]}", axes, .36,
                             np.array([0., 420., 0.]), size) for f in frames]
    return grid(panels, len(frames), size, "Walk cycle every 6th key. Rows: front published, front corrected, side "
                "published, side corrected.")


def main() -> int:
    """Render the three images."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    A.require(not args.out.exists(), "STAND_V2_RENDER_EXISTS")
    _, closed, _, _, _, _, _, _ = A.I.current_inputs(SRC.PALETTE, SRC.PALETTE.parent / "mole-grip-v3.ugpal")
    src = dict(SRC.read_claw_source(), body=closed)
    colour = colours(src)
    old = {name: V2.load(path, loop, digest) for name, (path, loop, digest) in V2.PUBLISHED.items()}
    record = json.loads((args.candidate / "candidate.json").read_text())
    new = {name: V2.load(args.candidate / (name + ".npz"), old[name]["source_loop_mode"],
                         record["clips"][name]["sha256"]) for name in old}
    args.out.mkdir(parents=True)
    paws_sheet(src, colour, old, new).save(args.out / "paws.png")
    walk_sheet(src, colour, old, new).save(args.out / "walk.png")
    size = (520, 560)
    overview = [panel(src, colour, clips["stand"], E.READY_FRAME, f"{label} ready key 8: {name.split(',')[0]}", axes,
                      .5, np.array([0., 420., 0.]), size)
                for name, axes in (R.VIEWS[0], R.VIEWS[1]) for label, clips in (("published", old), ("corrected", new))]
    grid(overview, 4, size, "Closed paw (rows 30/31's body). Review aid only.").save(args.out / "overview.png")
    review = {"images_sha256": {n: SRC.sha(args.out / n) for n in ("paws.png", "walk.png", "overview.png")},
              "renderer_sha256": SRC.sha(Path(__file__)), "candidate_sha256": SRC.sha(args.candidate / "candidate.json")}
    (args.out / "review.json").write_text(json.dumps(review, indent=2) + "\n")
    print(json.dumps(review["images_sha256"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
