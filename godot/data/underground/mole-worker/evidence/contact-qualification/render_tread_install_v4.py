#!/usr/bin/env python3
"""Review images for a revision-4 tread-install candidate on the curled paw (ADR 1209 step 4, ADR 1216).

The candidate is rebuilt from its recipe on the curled-paw source closure, checked against its stored image, and
drawn with revision 1's renderer:

- `overview.png`, `hands.png` and `motion.png`, the same views as before;
- `grip.png`, the paw on the handle at the contact key from the front, the right side and the top, at ×1.4 on the
  grip pivot. Row 1 is the accepted fitting motion (v4, closed paw, accepted fit). Row 2 is the candidate (curled
  paw, lateral-2 fit).

A review aid, not a proof.

    $PY .../render_tread_install_v4.py <candidate-dir> <out-dir>
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
V4AUTH = load("author_tread_install_v4", HERE / "author_tread_install_v4.py")
R, T = GRIP.R, GRIP.T
C, I = V4AUTH.C, V4AUTH.I
ACCEPTED = HERE / "install-source-v4"


def grip_mask(parts: list, topology: list, rig: dict) -> np.ndarray:
    """The accepted grip-exclusion triangles, tinted in every view."""
    ids, _ = I.M.S.body_triangle_ids(parts[0], topology[0][0], rig["rig_binding"])
    mask = np.ones(len(topology[0][0]), dtype=bool)
    mask[ids] = False
    return mask


def rebuild(candidate: Path) -> tuple:
    """The candidate's motion on the curled closure, byte-checked against its stored image."""
    record = json.loads((candidate / "candidate.json").read_text())
    cases_in, parts, rig, topology, _, _, _ = C.read_curl_source()
    cases, _ = V4AUTH.source_motion(cases_in[0], parts[1], rig, record["source_recipe"])
    compiled = json.loads((candidate / "compilation.json").read_text())
    stored = I.M.S.read_image(candidate / "mole-worker.ugactor", compiled["content_sha256"], parts)
    for actual, expected in zip(stored, cases):
        T.require(actual["matrices"].tobytes() == expected["matrices"].tobytes(), "RENDER_SOURCE_DRIFT")
    return record, cases, parts, rig, topology


def accepted_contact() -> tuple:
    """The accepted fitting motion's contact key on the accepted (closed-paw) source closure."""
    T.M.W.snapshot_sources = T.FLIGHT.historical_snapshot
    _, parts, rig, topology, _, _, _ = T.M.read_actual_source()
    compiled = json.loads((ACCEPTED / "compilation.json").read_text())
    cases = I.M.S.read_image(ACCEPTED / "mole-worker.ugactor", compiled["content_sha256"], parts)
    return cases[0], parts, rig, topology


def grip_sheet(candidate: tuple, accepted: tuple) -> Image.Image:
    """Two rows at one zoom: the accepted v4 contact, then the candidate's contact."""
    rows = [("accepted v4, closed paw", *accepted), ("candidate, curled paw", *candidate)]
    sheet = Image.new("RGB", (GRIP.PANEL[0] * 3, (GRIP.PANEL[1] + 10) * 2 + 20), R.BACKGROUND)
    for row, (label, case, parts, rig, topology) in enumerate(rows):
        meshes = R.meshes_at(case, 16, parts, topology, grip_mask(parts, topology, rig))
        focus = GRIP.grip_point(case, 16, rig)
        for column, (name, axes) in enumerate(GRIP.VIEWS):
            sheet.paste(R.panel(GRIP.PANEL, f"{label}: {name} (x{GRIP.SCALE})", meshes, [], axes, GRIP.SCALE, focus),
                        (column * GRIP.PANEL[0], row * (GRIP.PANEL[1] + 10)))
    ImageDraw.Draw(sheet).text((10, sheet.height - 16), "Contact key, zoomed on the grip pivot. Tinted: the grip "
                               "patch excluded by the accepted self-clearance rule. Review aid only.", fill=(120, 35, 30))
    return sheet


def main() -> int:
    """Render the four images and their digests."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    T.require(not args.out.exists(), "RENDER_OUTPUT_EXISTS")
    record, cases, parts, rig, topology = rebuild(args.candidate)
    accepted = accepted_contact()
    mask = grip_mask(parts, topology, rig)
    prisms = [(box, R.PRISM_RGB[at]) for at, box in enumerate(record["fixture"]["solids_u"]) if at in R.PRISM_RGB]
    work = cases[0]
    contact = R.meshes_at(work, 16, parts, topology, mask)
    args.out.mkdir(parents=True)
    overview = Image.new("RGB", (1710, 560), R.BACKGROUND)
    for at, (name, axes) in enumerate(R.VIEWS):
        overview.paste(R.panel((570, 530), name + " (contact key)", contact, prisms, axes, .43, np.array([0., 360., -60.])), (at * 570, 0))
    overview.save(args.out / "overview.png")
    poll = I.prop_points(work, 16, parts[1])[I.POLL_VERTEX]
    hands = Image.new("RGB", (1600, 860), R.BACKGROUND)
    for row, (label, focus) in enumerate((("Adze on the workpiece", poll), ("Feet, workpiece and riser", np.array([0., 90., 0.])))):
        for column, (name, axes) in enumerate(R.VIEWS):
            hands.paste(R.panel((533, 410), f"{label}: {name} (x1.3)", contact, prisms, axes, 1.3, focus), (column * 533, row * 420))
    hands.save(args.out / "hands.png")
    keys = [(cases[1], 0, "entry 0 (ready)"), (cases[1], 10, "entry 10"), (cases[1], 20, "entry 20"),
            (cases[1], 30, "entry 30"), (work, 0, "tap 0 (poll raised)"), (work, 16, "tap 16 (contact)")]
    motion = Image.new("RGB", (1710, 1080), R.BACKGROUND)
    for at, (case, frame, title) in enumerate(keys):
        motion.paste(R.panel((570, 530), "Side: " + title, R.meshes_at(case, frame, parts, topology, mask), prisms,
                             R.VIEWS[1][1], .43, np.array([0., 360., -60.])), ((at % 3) * 570, (at // 3) * 540))
    motion.save(args.out / "motion.png")
    grip_sheet((work, parts, rig, topology), accepted).save(args.out / "grip.png")
    numbers = R.review_numbers(record, cases, parts, topology, mask)
    numbers["images_sha256"] = {n: hashlib.sha256((args.out / n).read_bytes()).hexdigest()
                                for n in ("overview.png", "hands.png", "motion.png", "grip.png")}
    numbers["renderer_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    (args.out / "review.json").write_text(json.dumps(numbers, indent=2) + "\n")
    print(json.dumps(numbers["images_sha256"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
