#!/usr/bin/env python3
"""ADR 1216 step 1: a curled-claw paw for the pick-holding sources, authored for Brendan's visual review.

This is the successor to the accepted closed paw (`mole_grip_source.gd`). That paw has no finger bones; it is a
fixed mesh change that narrows the 845 finger vertices toward a line along the finger axis (hand-local Y), shaped
for a shaft running *along* the fingers. Brendan chose a paw that wraps a shaft running *across* them, for the
pick sources only (ADR 1216). This author derives that shape. Nothing is baked or presented: the palette,
presentation, proofs and GDScript port wait for his approval of the shape.

**Source mesh.** The accepted proofs carry the closed paw. The accepted contraction is exactly invertible per
vertex, given the vertex's own hand weight, so the original paw's hand-local positions are recovered from it. The
round-trip error is recorded; the GDScript port will start from the true original mesh instead.

**The deformation**, in hand-local metres. Each vertex moves in proportion to its own right-hand weight `w`, as in
the accepted derivative:

1. **Thin the fingers.** This uses the accepted derivative's own profile, `t = smoothstep((y − 0.025) / 0.105)`,
   with the accepted 70% narrowing. Here it narrows **thickness only**, along Z toward the paw's mid-plane, and
   keeps the fingers side by side across X so they can lie along the shaft.
2. **Place the shaft on the palm.** The palm is the smooth +Z face (the furred back is −Z).
   - Its axis runs along hand-local X at `lateral-1`'s height, y = 0.078 (the accepted socket's).
   - It rests on the thinned palm: z = palm surface + the shaft radius.
   - The palm surface is the 95th percentile of the thinned finger-band z (y in [0.03, 0.09]).
   - The radius is the pick shaft's measured half-diameter at the accepted pick scale.
3. **Curl.** Beyond the shaft (y > 0.078), each finger cross-section turns rigidly about the shaft axis toward the
   palm by φ = (y − 0.078) / ρ, blended by the vertex's hand weight w. Here ρ is the shaft radius plus half the thinned finger thickness, the neutral
   fibre's radius. The neutral fibre keeps its length, and the fingers wrap as far as their own length reaches.

The pick fit follows the shaft: `lateral-1` translated along Z onto the palm (`fit.json`, "lateral-2").

**Witnesses** (floats, for review):
- the palm and finger vertices within one shaft radius of the shaft surface;
- their angular cover around the shaft;
- paw vertices inside the shaft.

These are not the exact grip proof, which comes after approval with the successor grip exclusion.

    $PY .../author_curled_paw.py <out-dir>
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("author_pick_refit", HERE / "author_pick_refit.py")
F = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(F)
P, I, M = F.P, F.I, F.M
CENTRE_M = np.array([-40., 80., 5.]) / 1024  # the accepted closed paw's contraction centre (its socket)
START_M, SPAN_M, NARROW, SHORTEN = 0.025, 0.105, 0.7, 0.15  # the accepted derivative's own profile
PALM_BAND_M = (0.03, 0.09)
PALM_PERCENTILE = 95
SECTORS = 24
LATERAL_FIT = HERE / "pick-fit-v1" / "lateral-1" / "fit.json"
require = F.require


def profile(y: np.ndarray, weight: np.ndarray) -> np.ndarray:
    """The accepted derivative's smoothstep factor, scaled by the vertex's own hand weight."""
    t = np.clip((y - START_M) / SPAN_M, 0, 1)
    return t * t * (3 - 2 * t) * weight


def accepted_closed(original: np.ndarray, weight: np.ndarray) -> np.ndarray:
    """The accepted contraction (`mole_grip_source.gd::_deform_vertex`), applied to hand-local points."""
    factor = profile(original[:, 1], weight)
    out = original.copy()
    out[:, 0] = CENTRE_M[0] + (original[:, 0] - CENTRE_M[0]) * (1 - NARROW * factor)
    out[:, 2] = CENTRE_M[2] + (original[:, 2] - CENTRE_M[2]) * (1 - NARROW * factor)
    out[:, 1] = START_M + (original[:, 1] - START_M) * (1 - SHORTEN * factor)
    return out


def recover_original(closed: np.ndarray, weight: np.ndarray) -> tuple:
    """Invert the accepted contraction per vertex (monotone in y), and report the round-trip error."""
    low, high = np.full(len(closed), -1.0), np.full(len(closed), 1.0)
    for _ in range(80):
        middle = (low + high) / 2
        y = START_M + (middle - START_M) * (1 - SHORTEN * profile(middle, weight))
        below = y < closed[:, 1]
        low, high = np.where(below, middle, low), np.where(below, high, middle)
    y = (low + high) / 2
    factor = profile(y, weight)
    original = np.stack([CENTRE_M[0] + (closed[:, 0] - CENTRE_M[0]) / (1 - NARROW * factor), y,
                         CENTRE_M[2] + (closed[:, 2] - CENTRE_M[2]) / (1 - NARROW * factor)], axis=1)
    error = float(np.abs(accepted_closed(original, weight) - closed).max())
    require(error < 1e-9, "PAW_INVERSION")
    return original, error


def thin(original: np.ndarray, weight: np.ndarray, mid_z: float) -> np.ndarray:
    """Step 1: the accepted profile narrows thickness only, toward the paw's mid-plane."""
    out = original.copy()
    out[:, 2] = mid_z + (original[:, 2] - mid_z) * (1 - NARROW * profile(original[:, 1], weight))
    return out


def shaft_on_palm(thinned: np.ndarray, hand: np.ndarray, radius: float) -> tuple:
    """Step 2: the shaft axis (y, z) at the socket's height, resting on the thinned palm (+Z face)."""
    band = hand & (thinned[:, 1] >= PALM_BAND_M[0]) & (thinned[:, 1] < PALM_BAND_M[1])
    palm = float(np.percentile(thinned[band, 2], PALM_PERCENTILE))
    fingers = hand & (thinned[:, 1] > CENTRE_M[1])
    thickness = float(np.percentile(thinned[fingers, 2], PALM_PERCENTILE) - np.percentile(thinned[fingers, 2], 100 - PALM_PERCENTILE))
    return np.array([CENTRE_M[1], palm + radius]), palm, thickness


def curl(thinned: np.ndarray, weight: np.ndarray, axis_yz: np.ndarray, rho: float) -> np.ndarray:
    """Step 3: beyond the shaft, each cross-section turns about the shaft axis toward the palm by arc length."""
    out = thinned.copy()
    beyond = thinned[:, 1] > axis_yz[0]
    angle = (thinned[beyond, 1] - axis_yz[0]) / rho
    radial = axis_yz[1] - thinned[beyond, 2]
    bent_y = axis_yz[0] + radial * np.sin(angle)
    bent_z = axis_yz[1] - radial * np.cos(angle)
    share = weight[beyond]
    out[beyond, 1] = (1 - share) * thinned[beyond, 1] + share * bent_y
    out[beyond, 2] = (1 - share) * thinned[beyond, 2] + share * bent_z
    return out


def witness(curled: np.ndarray, hand: np.ndarray, axis_yz: np.ndarray, radius: float, width: tuple) -> dict:
    """Float witnesses: paw vertices touching the shaft surface, inside it, and their cover around it."""
    across = hand & (curled[:, 0] >= width[0]) & (curled[:, 0] <= width[1])
    offset = curled[across][:, 1:] - axis_yz
    distance = np.linalg.norm(offset, axis=1)
    shell = (distance >= radius) & (distance < 2 * radius)
    angles = np.arctan2(offset[shell, 1], offset[shell, 0])
    sectors = np.unique(((angles + np.pi) / (2 * np.pi) * SECTORS).astype(int) % SECTORS)
    return {"paw_vertices_inside_shaft": int((distance < radius).sum()),
            "paw_vertices_in_contact_shell": int(shell.sum()),
            "wrap_sectors_covered": int(len(sectors)), "wrap_sectors": SECTORS,
            "wrap_degrees": float(len(sectors) * 360 / SECTORS)}


def derive(parts: list, rig: dict) -> dict:
    """Every step from the accepted sources; returns points and the derivation record."""
    geometry = parts[0]["geometry"][0]
    weight = np.clip(np.sum(np.where(geometry["ids"] == F.HAND, geometry["weights"], 0), axis=1), 0, 1)
    closed, patch = F.hand_local(parts, rig)
    original, error = recover_original(closed, weight)
    hand = weight > 0.5
    mid_z = float(np.median(original[hand & (original[:, 1] > START_M), 2]))
    thinned = thin(original, weight, mid_z)
    lateral = json.loads(LATERAL_FIT.read_text())
    radius = lateral["grip_witness"]["shaft_radius_m"]
    axis_yz, palm, thickness = shaft_on_palm(thinned, hand, radius)
    rho = radius + thickness / 2
    curled = curl(thinned, weight, axis_yz, rho)
    paw = (float(original[patch, 0].min()), float(original[patch, 0].max()))
    fit = np.asarray(lateral["fit_hand_to_pick"])
    fit[2, 3] += axis_yz[1] - CENTRE_M[2]
    reach = float((original[hand, 1].max() - axis_yz[0]) / rho)
    return {"original_local": original, "curled_local": curled, "weight": weight, "fit": fit,
            "record": {"inversion_round_trip_error_m": error, "mid_plane_z_m": mid_z, "palm_surface_z_m": palm,
                       "finger_thickness_after_thinning_m": thickness, "shaft_radius_m": radius,
                       "shaft_axis_yz_m": axis_yz.tolist(), "neutral_radius_m": rho,
                       "full_curl_degrees_at_finger_tip": float(np.degrees(reach)),
                       "moved_vertices": int(np.any(np.abs(curled - original) > 1e-12, axis=1).sum()),
                       "witness": witness(curled, hand, axis_yz, radius, paw), "paw_width_x_m": list(paw)}}


def rest_points(local: np.ndarray, weight: np.ndarray, parts: list, rig: dict) -> np.ndarray:
    """Mesh-space rest points for the hand-weighted vertices; every other vertex stays byte-identical."""
    bind = P._affine64(np.asarray(rig["rig_binding"]["bones"][F.HAND]["inverse_bind"], dtype=np.float32))
    points = np.asarray(parts[0]["geometry"][0]["points"], dtype=np.float64).copy()
    moved = weight > 0
    inverse = np.linalg.inv(bind)
    points[moved] = local[moved] @ inverse[:3, :3].T + inverse[:3, 3]
    return points


def main() -> int:
    """Derive the curled paw and write its record, fit and point sets."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    require(not args.out.exists(), "OUTPUT_EXISTS")
    M.W.snapshot_sources = F.V1.FLIGHT.historical_snapshot
    original, parts, rig, topology, roots, sources, historical = M.read_actual_source()
    result = derive(parts, rig)
    args.out.mkdir(parents=True)
    rest = rest_points(result["curled_local"], result["weight"], parts, rig)
    np.save(args.out / "curled-rest-points.npy", rest.astype(np.float32))
    paths = [Path(__file__), Path(F.__file__), LATERAL_FIT]
    record = {"schema": 1, "decision": "1216", "step": 1, **result["record"],
              "fit_hand_to_pick_lateral_2": result["fit"].tolist(),
              "curled_rest_points_sha256": hashlib.sha256((args.out / "curled-rest-points.npy").read_bytes()).hexdigest(),
              "producer_sources": {str(p.resolve().relative_to(P.ROOT)): P.content.file_hash(p) for p in paths},
              "verified_source_files": sources, "historical_source_snapshot": historical,
              "scope": "authored shape for review only: no palette, presentation, GDScript port or proof",
              "production_qualified": False}
    (args.out / "paw.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result["record"].items()}, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
