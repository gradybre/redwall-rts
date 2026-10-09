#!/usr/bin/env python3
"""Review images for one claw-stroke candidate (ADR 1217 step 1). A review aid, not a proof.

The candidate is rebuilt from its recipe and checked against its stored clips (`prove_claw_stroke.load`), then
drawn with the accepted painter renderer of the tread-install packets (`render_tread_install.panel`), at the same
standard views:

- `overview.png`: the contact key (the stroke key just past the claw's face crossing) from the front, the side and
  the top, with the target cube (orange) and the support earth (green) outlined.
- `hands.png`: the paw at the contact key and at the deepest key (16), on the cube's top face, zoomed ×1.3.
- `motion.png`: side views of entry keys 0, 15 and 30 and stroke keys 0, 4, 8, 12, 16 and 24.

The right paw (every triangle with RightHand weight) is tinted.

    $PY .../render_claw_stroke.py <candidate-dir> <out-dir>
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

import prove_claw_stroke as PROOF

W, SRC = PROOF.W, PROOF.SRC
RENDER_SPEC = importlib.util.spec_from_file_location("claw_painter", SRC.I.PROOF / "render_tread_install.py")
R = importlib.util.module_from_spec(RENDER_SPEC)
RENDER_SPEC.loader.exec_module(R)
PAW_RGB = (196, 120, 96)
PRISMS = {0: (60, 110, 60), 4: (190, 120, 20)}
WIDE = np.array([0., 300., -300.])
DEEPEST_KEY = 16  # The loop's bottom: key 16 of 32 is half a turn after the top.


def meshes_at(src: dict, case: dict, frame: int, paw: np.ndarray) -> list:
    """The body at one key, right paw tinted."""
    points = SRC.I.points_at(case, src["body"], frame)
    return [(points, src["triangles"], [PAW_RGB if p else R.BODY_RGB for p in paw])]


def contact_key(record: dict) -> int:
    """The stroke key that closes the claw's descending face crossing."""
    return int(record["stroke"]["contact"]["rendered_edge"][1])


def sheet(size: tuple, panels: list, columns: int, note: str) -> Image.Image:
    """Paste panels on a grid and add a footnote."""
    width, height = size
    rows = -(-len(panels) // columns)
    image = Image.new("RGB", (width * columns, height * rows + 24), R.BACKGROUND)
    for at, panel in enumerate(panels):
        image.paste(panel, ((at % columns) * width, (at // columns) * height))
    ImageDraw.Draw(image).text((12, height * rows + 6), note, fill=(120, 35, 30))
    return image


def render(src: dict, record: dict, proof: dict, cases: list, out: Path) -> dict:
    """Write the three images and return their digests."""
    geometry = src["body"]["geometry"][0]
    paw = np.any(np.isin(geometry["ids"], [19]) & (geometry["weights"] > 0), axis=1)[src["triangles"]].any(axis=1)
    prisms = [(box, PRISMS[at]) for at, box in enumerate(PROOF.fixture(src, record["recipe"])["solids_u"]) if at in PRISMS]
    stroke, entry = cases[0], cases[1]
    key = contact_key(proof)
    contact = meshes_at(src, stroke, key, paw)
    note = "UNQUALIFIED authoring preview (ADR 1217 claw stroke); orange: target cube; green: support earth."
    overview = [R.panel((570, 530), f"{name} (stroke key {key}, contact)", contact, prisms, axes, .43, WIDE)
                for name, axes in R.VIEWS]
    sheet((570, 530), overview, 3, note).save(out / "overview.png")
    anchor = np.asarray(proof["stroke"]["contact"]["anchor_u"], dtype=float)
    deepest = meshes_at(src, stroke, DEEPEST_KEY, paw)
    hands = [R.panel((533, 410), f"{label}: {name} (x1.3)", meshes, prisms, axes, 1.3, anchor)
             for label, meshes in ((f"Contact, stroke key {key}", contact), (f"Deepest, stroke key {DEEPEST_KEY}", deepest))
             for name, axes in R.VIEWS]
    sheet((533, 410), hands, 3, "Right paw tinted. Zoomed review aid only.").save(out / "hands.png")
    keys = [(entry, 0, "entry 0 (ready)"), (entry, 15, "entry 15"), (entry, 30, "entry 30 = stroke 0"),
            (stroke, 4, "stroke 4"), (stroke, 8, "stroke 8"), (stroke, 12, "stroke 12"),
            (stroke, 16, "stroke 16 (deepest)"), (stroke, 24, "stroke 24"), (stroke, key, f"stroke {key} (contact)")]
    motion = [R.panel((570, 530), "Side: " + title, meshes_at(src, case, frame, paw), prisms, R.VIEWS[1][1], .43, WIDE)
              for case, frame, title in keys]
    sheet((570, 530), motion, 3, note).save(out / "motion.png")
    return {name: hashlib.sha256((out / name).read_bytes()).hexdigest()
            for name in ("overview.png", "hands.png", "motion.png")}


def main() -> int:
    """Render one candidate's review images."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--palette", type=Path, default=SRC.PALETTE)
    args = parser.parse_args()
    W.require(not args.out.exists(), "CLAW_RENDER_OUTPUT_EXISTS")
    src = SRC.read_claw_source(args.palette)
    record, cases = PROOF.load(args.candidate, src)
    proof = json.loads((args.candidate / "proof.json").read_text())
    args.out.mkdir(parents=True)
    digests = render(src, record, proof, cases, args.out)
    review = {"images_sha256": digests, "renderer_sha256": SRC.sha(Path(__file__)),
              "candidate_sha256": SRC.sha(args.candidate / "candidate.json"),
              "proof_sha256": SRC.sha(args.candidate / "proof.json")}
    (args.out / "review.json").write_text(json.dumps(review, indent=2) + "\n")
    print(json.dumps(digests))
    return 0


if __name__ == "__main__":
    sys.exit(main())
