#!/usr/bin/env python3
"""The stair carry's source closure (decision 1981): bodies, loads, holds and readies, all pinned. Source reading only.

Every input is already published and approved:

- **Body.** The closed paw the haul images draw (`mole-grip-v3`'s firm grip derivative, `29f8d321…`), through
  `inspect_source.current_inputs`, as the haul rows 30-41 were derived.
- **Loads.** The wood log of the supplied carry clip (522 vertices) with its native triangle list
  (`wood-topology-v1.json`, `66255515…`), and the stone lump as the stone image draws it (`compile_native_program_v9
  .stone_part`: the exact float32 bits and native format) with the captured triangles (`stone-source-v1`).
- **Holds.** Key 0 of each item's approved `hold` clip (the last key of the approved lift; the carry loop's
  enter/exit endpoint), pinned by the digests the v10 haul images record.
- **The empty ready.** The corrected stand key 8 (step 1c), the hub of rows 30/31/42, on the closed paw.
- **The grip.** Each item's certified two-hand contact witnesses (`static-contact-review-v1`, `stone-contact-v1`).

The palettes are read from the staged demo assets (cloned from the frozen `redwall-rts-codex-ug-space` worktree,
ADR 1192 §6) and checked by their whole-file digests.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
MOLE = HERE.parent
sys.path.insert(0, str(MOLE / "claw-work-v1"))
import author_claw_stairs as CS  # noqa: E402  (also puts haul-handling-v1 on the path)

sys.path.insert(0, str(MOLE / "haul-handling-v1"))
import author_stone_grip as STONE  # noqa: E402
import compile_native_program_v9 as C9  # noqa: E402
import render_candidate as RENDER  # noqa: E402

SRC, W = CS.SRC, CS.W
I = SRC.I
ROOT = SRC.ROOT
ITEMS = ("wood", "stone")
PALETTE = ROOT / "godot/demo/assets/underground-matrices/all-cast-v9.ugpal"
GRIP = ROOT / "godot/demo/assets/underground-matrices/mole-grip-v3.ugpal"
HAUL = MOLE / "haul-handling-v1/evidence"
HOLDS = {"wood": (HAUL / "loaded-gait-review-v1/candidate/hold.npz",
                  "778fee6b52ccdb154f667d169cd620cce13e6c887ab136ae3b22d68bf9b3f20f"),
         "stone": (HAUL / "stone-gait-v1/hold.npz",
                   "a28934d9e7a1da9f7a9019360cc4fe92a9c88af2247fa159d70b527b7f848f77")}
WITNESSES = {"wood": HAUL / "static-contact-review-v1/static-contact.json",
             "stone": HAUL / "stone-contact-v1/static-contact.json"}
WOOD_TOPOLOGY = HAUL / "wood-topology-v1.json"
CARGO = {"wood": 60, "stone": 53}  # Compiled item ids (rows 32 and 37).
READY_FRAME = SRC.READY_FRAME
TRIANGLES = SRC.TRIANGLES


def sha(path: Path) -> str:
    """Lower-case hex SHA-256 of a file."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_hold(item: str) -> tuple:
    """(25x12 palette, grounding) of the item's approved hold key."""
    path, expected = HOLDS[item]
    W.require(sha(path) == expected, "STAIR_CARRY_HOLD_PIN:" + item)
    with np.load(path, allow_pickle=False) as image:
        matrices, grounding = image["matrices"].copy(), image["grounding"].copy()
    W.require(matrices.dtype == np.float32 and matrices.shape == (2, 25, 12) and
              np.array_equal(matrices[0], matrices[1]) and grounding[0] == grounding[1], "STAIR_CARRY_HOLD_SHAPE")
    return matrices[0], np.float32(grounding[0])


def load_part(item: str, wood: dict) -> tuple:
    """(part, triangles) of the carried unit, as the proofs and the native image use it."""
    if item == "wood":
        return wood, RENDER.wood_topology(WOOD_TOPOLOGY, wood).astype(np.int64)
    return C9.stone_part(), STONE.stone_part()[1].astype(np.int64)


def witnesses(item: str) -> list:
    """The certified two-hand contact witnesses of the item's static grip."""
    return json.loads(WITNESSES[item].read_text())["static_source"]["hand_contact_witnesses"]


def ready_case(palette: np.ndarray, grounding: np.float32, geometry: list) -> dict:
    """A nine-key still clip of one 25-slot palette: the accepted authors read their ready at key 8."""
    W.require(palette.shape == (25, 12), "STAIR_CARRY_READY_SHAPE")
    return {"frames": READY_FRAME + 1, "matrices": np.repeat(palette[None], READY_FRAME + 1, axis=0),
            "grounding": np.full(READY_FRAME + 1, grounding, dtype=np.float32), "geometry": geometry}


def closure() -> dict:
    """Every pinned input of the stair carry, read once."""
    rows, body, wood, _, topology, _, _, _ = I.current_inputs(PALETTE, GRIP)
    del rows
    body_tri = np.asarray(topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int64).reshape(-1, 3)
    W.require(body_tri.shape == (TRIANGLES, 3) and body["binds"] == 24, "STAIR_CARRY_BODY")
    claw = CS.SEAT.corrected_source()
    items = {}
    for item in ITEMS:
        part, part_tri = load_part(item, wood)
        hold, ground = read_hold(item)
        items[item] = {"part": part, "triangles": part_tri, "hold": hold, "grounding": ground,
                       "witnesses": witnesses(item), "cargo": CARGO[item],
                       "ready": ready_case(hold, ground, [body, part])}
    stand = claw["stand"]["matrices"][READY_FRAME]
    identity = np.array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0], dtype=np.float32)
    empty = ready_case(np.concatenate([stand, identity[None]]), claw["stand"]["grounding"][READY_FRAME], [body])
    return {"body": body, "body_triangles": body_tri, "topology": topology, "claw": claw,
            "self_source": dict(claw, body=body), "items": items, "empty": empty,
            "pins": {"palette": I.PALETTE_SHA, "grip_palette": I.GRIP_SHA, "closed_body": I.BODY,
                     "topology": I.TOPOLOGY_SHA, "stand": claw["stand_sha256"],
                     "wood_topology": sha(WOOD_TOPOLOGY), "stone_capture": STONE.STONE_SHA,
                     **{f"{item}_hold": HOLDS[item][1] for item in ITEMS}}}
