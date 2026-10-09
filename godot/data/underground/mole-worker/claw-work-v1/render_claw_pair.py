#!/usr/bin/env python3
"""Review images for one two-paw claw-stroke candidate (ADR 1217 step 1b). A review aid, not a proof.

Drawn with the accepted painter renderer (`render_tread_install.panel`) at the standard views, both paws tinted:

- `overview.png`: the right paw's contact key from the front, the side and the top, with the moved-in target
  cube (orange) and the support earth (green).
- `hands.png`: both paws at the right paw's contact key and at the left paw's contact key, front, side and top,
  ×1.3 on the midpoint of the two anchors.
- `motion.png`: front and side views of entry keys 0 and 30 and stroke keys 0, 8, 16 and 24.
- `compare.png`: the one-paw candidate a (step 1) above this candidate, side and front views at matching stroke
  phases, at one zoom.

    $PY .../render_claw_pair.py <candidate-dir> <out-dir>
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

import prove_claw_pair as PROOF
import render_claw_stroke as ONE_RENDER

PAIR, W, SRC = PROOF.PAIR, PROOF.W, PROOF.SRC
R = ONE_RENDER.R
ONE_A = SRC.HERE / "evidence/claw-stroke-v1/candidate-a"
WIDE = ONE_RENDER.WIDE


def tinted(src: dict, bones: tuple) -> np.ndarray:
    """Triangles with any weight on the given hand bones."""
    geometry = src["body"]["geometry"][0]
    return np.any(np.isin(geometry["ids"], bones) & (geometry["weights"] > 0), axis=1)[src["triangles"]].any(axis=1)


def contact_keys(proof: dict) -> dict:
    """Each paw's descending-crossing key."""
    return {side: int(row["rendered_edge"][1]) for side, row in proof["stroke"]["contact"].items()}


def views_row(src, cases, frames, paw, prisms, axes, label, size=(570, 530)) -> list:
    """One panel per (clip, key)."""
    return [R.panel(size, f"{label}: {title}", ONE_RENDER.meshes_at(src, case, frame, paw), prisms, axes, .43, WIDE)
            for case, frame, title in frames]


def render(src: dict, record: dict, proof: dict, cases: list, out: Path) -> dict:
    """Write the four images and return their digests."""
    paw = tinted(src, (15, 19))
    prisms = [(box, ONE_RENDER.PRISMS[at]) for at, box in enumerate(PROOF.ONE.fixture(src, PROOF.STATION)["solids_u"])
              if at in ONE_RENDER.PRISMS]
    stroke, entry = cases[0], cases[1]
    keys = contact_keys(proof)
    note = "UNQUALIFIED authoring preview (ADR 1217 two-paw claw stroke); orange: target cube; green: support earth."
    contact = ONE_RENDER.meshes_at(src, stroke, keys["right"], paw)
    overview = [R.panel((570, 530), f"{name} (stroke key {keys['right']}, right paw contact)", contact, prisms, axes,
                        .43, WIDE) for name, axes in R.VIEWS]
    ONE_RENDER.sheet((570, 530), overview, 3, note).save(out / "overview.png")
    anchors = [np.asarray(row["anchor_u"], dtype=float) for row in proof["stroke"]["contact"].values()]
    focus = (anchors[0] + anchors[1]) / 2
    hands = [R.panel((533, 410), f"{side} paw contact, key {key}: {name} (x1.3)",
                     ONE_RENDER.meshes_at(src, stroke, key, paw), prisms, axes, 1.3, focus)
             for side, key in keys.items() for name, axes in R.VIEWS]
    ONE_RENDER.sheet((533, 410), hands, 3, "Both paws tinted. Zoomed review aid only.").save(out / "hands.png")
    frames = [(entry, 0, "entry 0 (ready)"), (entry, 30, "entry 30 = stroke 0"), (stroke, 8, "stroke 8"),
              (stroke, 16, "stroke 16"), (stroke, 24, "stroke 24"), (stroke, 31, "stroke 31")]
    motion = views_row(src, cases, frames, paw, prisms, R.VIEWS[0][1], "Front") + \
        views_row(src, cases, frames, paw, prisms, R.VIEWS[1][1], "Side")
    ONE_RENDER.sheet((570, 530), motion, 6, note).save(out / "motion.png")
    compare_sheet(src, stroke, paw, prisms, keys).save(out / "compare.png")
    return {name: SRC.sha(out / name) for name in ("overview.png", "hands.png", "motion.png", "compare.png")}


def compare_sheet(src: dict, stroke: dict, paw: np.ndarray, prisms: list, keys: dict) -> Image.Image:
    """Row 1: one-paw candidate a at its contact and deepest keys; row 2: this candidate at both paws' contacts."""
    record = json.loads((ONE_A / "candidate.json").read_text())
    one, _ = W.author(src, record["recipe"])
    one_paw = tinted(src, (19,))
    frames_one = [(one[0], 9, "one paw (a), contact"), (one[0], 16, "one paw (a), deepest")]
    frames_two = [(stroke, keys["right"], "two paws, right contact"), (stroke, keys["left"], "two paws, left contact")]
    panels = []
    for frames, mask in ((frames_one, one_paw), (frames_two, paw)):
        for axes_name, axes in (R.VIEWS[1], R.VIEWS[0]):
            panels += views_row(src, None, frames, mask, prisms, axes, axes_name.split(",")[0])
    return ONE_RENDER.sheet((570, 530), panels, 4, "Top row: step 1's one-paw candidate a; bottom row: this "
                            "candidate. Same station (1,430 u), same zoom.")


def main() -> int:
    """Render one candidate's review images."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--palette", type=Path, default=SRC.PALETTE)
    args = parser.parse_args()
    W.require(not args.out.exists(), "CLAW_PAIR_RENDER_OUTPUT_EXISTS")
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
