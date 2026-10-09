#!/usr/bin/env python3
"""Tool-free STAND/WALK rows of the claw source 4 (ADR 1217 step 4c, content 8). Derived, never chosen.

The step-4b decision puts the Frontier's endpoint travel on source 4, so source 4 needs its own WALK row (and the
STAND row that pairs with it, as rows 30/31 pair on source 2). They are derived exactly as rows 30/31 were
(ADR 1199; `prove_empty_walk.derive_rows`, re-run for the corrected clips in `stand-walk-v2/prove_stand_walk_v2.py`):

- `compile_state_program.carry_bounds` over every key of the stand and walk clips: the complete source hull, the
  outward native/World residual over the full root range, the clipped whole-triangle floor and the full foot
  projection, each swept about the root with `rotated_box` and the pinned world-yaw basis;
- `prove_empty_walk.ground_roles`: the role assembly of published rows 0/1/12 without the absent pick's box.

The only difference from rows 30/31 is the body: the claw image's own, the original open paw (`a938d479…`), where
rows 30/31 use the closed paw of the haul images. The clips are the claw image's own stand and walk, checked
against the claw image's compilation record (`native-claw-split-v1/claw`).

    $PY .../derive_claw_stand_rows.py <out.json> --world-basis <world-yaw-v1.ugyaw> [--palette ...] [--grip-palette ...]
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

import claw_source as SRC
import native_claw as NC

sys.path.insert(0, str(SRC.MOLE / "haul-handling-v1"))
import prove_empty_walk as EW  # noqa: E402

CLAW_IMAGE = SRC.HERE / "evidence/native-claw-split-v1/claw/compiled/compilation.json"
CLAW_IMAGE_SHA = "2b58852e0e39d3ae1c697ed5487081cead7ce80efc8a30662e469fd33059af5b"
NAMES = {"stand": "claw STAND", "walk": "claw WALK"}


def require(value: bool, code: str) -> None:
    """Every refusal names its failed derivation fact."""
    if not value:
        raise ValueError("CLAW_STAND_ROWS_" + code)


def image_clips() -> dict:
    """The claw image's own stand and walk clips, each checked against the image's compilation record."""
    record = json.loads(CLAW_IMAGE.read_text())
    require(record["content_sha256"] == CLAW_IMAGE_SHA and record["clip_names"][:2] == ["stand", "walk"], "IMAGE")
    clips, pins = {}, {}
    for name in ("stand", "walk"):
        folder, file, loop = NC.SOURCES[name]
        path = folder / (file + ".npz")
        relative = str(path.relative_to(SRC.ROOT))
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        require(record["source_sha256"].get(relative) == digest and loop == 1, "CLIP_PIN")
        clips[name], pins[relative] = EW.load_case(path, 24, loop), digest
    return {"clips": clips, "pins": pins}


def derive(palette: Path, grip: Path, basis_path: Path) -> dict:
    """Both rows from the open-paw body over the claw image's stand and walk."""
    body = NC.open_body(palette, grip)
    triangles = SRC.read_claw_source(palette)["triangles"].astype(np.int64)
    source = image_clips()
    with basis_path.open("rb") as stream:
        basis = EW.C.H.InverseHeading(stream, EW.BASIS_SHA, EW.BASIS_PRODUCER)
    enclosure = EW.C.carry_bounds([source["clips"]["stand"], source["clips"]["walk"]], [body], [[triangles]],
                                  EW.ROOT_BOUNDS, basis)
    roles, measured = EW.ground_roles(enclosure)
    return {"schema": 1, "decision": "1217", "source": 4, "body": "open paw (original import, a938d479…)",
            "rows": [EW.row(NAMES["stand"], 0, roles), EW.row(NAMES["walk"], 1, roles)],
            "ground_enclosure": measured, "clip_sha256": source["pins"], "claw_image_sha256": CLAW_IMAGE_SHA,
            "world_root_bounds_u": EW.ROOT_BOUNDS, "world_basis_sha256": basis.digest,
            "derivation": "compile_state_program.carry_bounds over stand+walk keys; prove_empty_walk.ground_roles",
            "production_qualified": False}


def main() -> int:
    """Derive and write the record once."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("--world-basis", type=Path, required=True)
    parser.add_argument("--palette", type=Path, default=SRC.PALETTE)
    parser.add_argument("--grip-palette", type=Path, default=SRC.PALETTE.parent / "mole-grip-v3.ugpal")
    args = parser.parse_args()
    require(not args.out.exists(), "OUTPUT_EXISTS")
    result = derive(args.palette, args.grip_palette, args.world_basis)
    result["producer_sources"] = {str(Path(p).resolve().relative_to(SRC.ROOT)): SRC.sha(Path(p))
                                  for p in (__file__, NC.__file__, EW.__file__, EW.C.__file__, SRC.__file__)}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=1, default=str) + "\n")
    print(json.dumps({r["row"]: r["roles"] for r in result["rows"]}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
