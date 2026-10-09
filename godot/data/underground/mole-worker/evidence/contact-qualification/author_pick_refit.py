#!/usr/bin/env python3
"""ADR 1209 step 4, revision 4: a successor pick fit with the paw closed across the shaft, lower down the handle.

Brendan's review of revision 3: re-fit the grip. The accepted fit (the source `pick_fit` behind the authored
socket offset `(-40, 80, 5)/1024`, `mole_grip_source.gd`) runs the shaft *along* the paw's finger axis (hand-local
−Y), so the handle's end butts into the palm. This author derives a new hand-to-pick transform. It changes no
mesh, palette, rig, existing fit or evidence. The closed paw is the accepted derivative (845 contracted vertices,
hand-local y > 0.025), unchanged.

Every number is read from the accepted sources:

- **Scale**: the accepted fit's own uniform pick scale (0.2892).
- **Shaft centre line**: tool-local y = 0.1948, z = 0, the `prop_local_grip_m` line of the pick binding.
- **Where the shaft crosses the paw**: the accepted socket point, hand-local `(-40, 80, 5)/1024` m. This is the
  centre the authored paw closes around. The shaft runs across the paw along hand-local X, the paw's widest
  principal axis, instead of along Y.
- **Head axis**: the pick's head (tool-local z) lies along the paw's finger axis, hand-local +Y, so the head points
  forward from the knuckles. The head end of the shaft is on the paw's medial side (+X) or lateral side (−X), as
  the candidate's `side` says.
- **Grip position along the shaft**: the handle's end stands out past the paw's edge by `protrusion` shaft
  diameters. 0 is flush. The paw's edge is the closed patch's extreme X on that side, and the shaft diameter is
  the shaft section's measured y extent.

The grip witnesses are recorded with each fit; the proofs are the accepted ones:

- **No paw–shaft penetration beyond the authored grip patch**: `prove_self_clearance.prove`, body area, which
  excludes only triangles wholly inside the 845-vertex patch. It runs on the ready carry re-held with the new fit.
- **Palm contact**: the number of patch vertices inside the shaft's own radius (a float witness).
- **Wrap**: the angular coverage, around the shaft axis, of patch vertices within one shaft radius of its surface
  over the paw's width, in 24 sectors of 15° (a float witness).

    $PY .../author_pick_refit.py <out-dir> --side medial --protrusion 1
"""
from __future__ import annotations

import argparse
import contextlib
from fractions import Fraction
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("tread_install_v2", HERE / "author_tread_install_v2.py")
V2 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V2)
V1, I, M, P, S = V2.V1, V2.I, V2.M, V2.P, V2.S
HAND = 19
SOCKET_M = np.array([-40., 80., 5.]) / 1024
PATCH_Y_M = 0.025
SIDES = {"medial": 1, "lateral": -1}
SECTORS = 24
require = V2.require


def hand_local(parts: list, rig: dict) -> tuple:
    """Rest body vertices in the right hand's bind frame, and the authored grip patch mask."""
    geometry = parts[0]["geometry"][0]
    bind = P._affine64(np.asarray(rig["rig_binding"]["bones"][HAND]["inverse_bind"], dtype=np.float32))
    share = np.sum(np.where(geometry["ids"] == HAND, geometry["weights"], 0), axis=1)
    local = np.asarray(geometry["points"], dtype=float) @ bind[:3, :3].T + bind[:3, 3]
    patch = (share > 0) & (local[:, 1] > PATCH_Y_M)
    require(int(patch.sum()) == 845, "PATCH_CENSUS")
    return local, patch


def shaft_section(tool: dict, rig: dict) -> dict:
    """The shaft centre line and diameter from the pick binding and the pick mesh."""
    points = np.asarray(tool["geometry"][0]["points"], dtype=float)
    grip = np.asarray(rig["pick_binding"]["prop_local_grip_m"], dtype=float)
    section = points[np.abs(points[:, 0] - grip[0]) < 0.05]
    diameter = float(section[:, 1].max() - section[:, 1].min())
    return {"centre_y": float(grip[1]), "centre_z": float(grip[2]), "diameter": diameter,
            "end_x": float(points[:, 0].max())}


def derive_fit(accepted: np.ndarray, local: np.ndarray, patch: np.ndarray, section: dict, side: str,
               protrusion: int) -> tuple:
    """The new hand-local pick transform and the derivation record."""
    require(side in SIDES and type(protrusion) is int and 0 <= protrusion <= 3, "FIT_INPUT")
    scale = float(np.linalg.norm(accepted[:3, 0]))
    sign = SIDES[side]
    rotation = np.stack([[-sign, 0., 0.], [0., 0., sign], [0., 1., 0.]], axis=1)
    require(abs(np.linalg.det(rotation) - 1) < 1e-12, "FIT_ROTATION")
    edge = float(local[patch][:, 0].min() if sign > 0 else local[patch][:, 0].max())
    butt_hand_x = edge - sign * protrusion * section["diameter"] * scale
    grip_x = section["end_x"] - (SOCKET_M[0] - butt_hand_x) * sign / scale
    fit = np.eye(4)
    fit[:3, :3] = rotation * scale
    fit[:3, 3] = SOCKET_M - fit[:3, :3] @ np.array([grip_x, section["centre_y"], section["centre_z"]])
    return fit, {"scale": scale, "side": side, "protrusion_shaft_diameters": protrusion,
                 "paw_edge_hand_x_m": edge, "butt_hand_x_m": butt_hand_x, "grip_tool_x": grip_x,
                 "socket_hand_m": SOCKET_M.tolist(), "shaft": section, "rotation_tool_to_hand": rotation.tolist()}


def wrap_witness(fit: np.ndarray, local: np.ndarray, patch: np.ndarray, section: dict) -> dict:
    """Float witnesses: patch vertices inside the shaft, and their angular cover around it across the paw."""
    axis = fit[:3, 0] / np.linalg.norm(fit[:3, 0])
    centre = SOCKET_M
    radius = section["diameter"] * float(np.linalg.norm(fit[:3, 0])) / 2
    vectors = local[patch] - centre
    along = vectors @ axis
    radial = vectors - np.outer(along, axis)
    distance = np.linalg.norm(radial, axis=1)
    inside = int((distance < radius).sum())
    shell = (distance >= radius) & (distance < 2 * radius)
    basis_u = np.cross(axis, [0., 0., 1.])
    basis_u /= np.linalg.norm(basis_u)
    basis_v = np.cross(axis, basis_u)
    angles = np.arctan2(radial[shell] @ basis_v, radial[shell] @ basis_u)
    sectors = np.unique(((angles + np.pi) / (2 * np.pi) * SECTORS).astype(int) % SECTORS)
    return {"shaft_radius_m": radius, "patch_vertices_inside_shaft": inside,
            "patch_vertices_in_contact_shell": int(shell.sum()), "wrap_sectors_covered": int(len(sectors)),
            "wrap_sectors": SECTORS, "wrap_degrees": float(len(sectors) * 360 / SECTORS),
            "paw_width_along_shaft_m": float(along.max() - along.min())}


def refit_ready(ready: dict, rig: dict, fit: np.ndarray) -> dict:
    """The compact ready carry with the same paw holding the pick by the new fit (bone 24 only changes)."""
    parents, inverse, inverse_inverse = I.A.hierarchy(rig)
    actual, _, _ = I.A.joints(ready, 8, parents, inverse_inverse)
    result = dict(ready, matrices=ready["matrices"].copy(), grounding=ready["grounding"].copy())
    I.A.put_pose(result, 8, actual, inverse, fit, ready)
    return result


def ready_self_proof(ready: dict, parts: list, topology: list, rig: dict, roots: list) -> dict:
    """The accepted self-clearance proof on the re-held ready key (a two-key static case)."""
    case = dict(ready, frames=2, source_loop_mode=0, duration_q16=65536, source_duration_s=Fraction(1, 30),
                matrices=np.stack([ready["matrices"][8]] * 2), grounding=np.full(2, ready["grounding"][8], dtype=np.float32),
                geometry=parts)
    with contextlib.redirect_stderr(io.StringIO()):
        return S.prove(case, parts, topology, rig["rig_binding"], roots, "body")


def main() -> int:
    """Derive one fit, prove the re-held ready key, and write the fit record."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("--side", choices=sorted(SIDES), required=True)
    parser.add_argument("--protrusion", type=int, required=True)
    args = parser.parse_args()
    require(not args.out.exists(), "OUTPUT_EXISTS")
    M.W.snapshot_sources = V1.FLIGHT.historical_snapshot
    original, parts, rig, topology, roots, sources, historical = M.read_actual_source()
    parents, _, inverse_inverse = I.A.hierarchy(rig)
    _, _, accepted = I.A.joints(original[0], 8, parents, inverse_inverse)
    local, patch = hand_local(parts, rig)
    section = shaft_section(parts[1], rig)
    fit, derivation = derive_fit(accepted, local, patch, section, args.side, args.protrusion)
    witness = wrap_witness(fit, local, patch, section)
    proof = ready_self_proof(refit_ready(original[0], rig, fit), parts, topology, rig, roots)
    paths = [Path(__file__), Path(V2.__file__), Path(V1.__file__), Path(I.__file__)]
    record = {"schema": 1, "decision": "1209", "revision": 4, "fit_hand_to_pick": fit.tolist(),
              "accepted_fit_hand_to_pick": accepted.tolist(), "derivation": derivation, "grip_witness": witness,
              "ready_self_clearance": {k: proof[k] for k in ("clear", "checks", "pairs") if k in proof} |
              {"unresolved": proof.get("unresolved", [])[:8]},
              "producer_sources": {str(p.resolve().relative_to(P.ROOT)): P.content.file_hash(p) for p in paths},
              "verified_source_files": sources, "historical_source_snapshot": historical,
              "supersedes": "nothing: a successor fit for the tread install tap only; the accepted fit stays in every other motion",
              "production_qualified": False}
    args.out.mkdir(parents=True)
    (args.out / "fit.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({"ready_clear": proof["clear"], "witness": witness, "grip_tool_x": derivation["grip_tool_x"]}))
    return 0 if proof["clear"] else 2


if __name__ == "__main__":
    sys.exit(main())
