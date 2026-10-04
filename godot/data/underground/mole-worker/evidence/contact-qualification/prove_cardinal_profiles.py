#!/usr/bin/env python3
"""Finite native cardinal enclosures for the actual mole program; no runtime permission."""
from __future__ import annotations

from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("install_program_for_cardinals", HERE / "author_install_program.py")
I = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(I)
P, S, C, Q = I.P, I.S, I.C, I.Q
YAWS = (0, 16384, 32768, 49152)
MAX_FRAMES = 128
MAX_VERTICES = 32768
MAX_ENDPOINT_SCALARS = MAX_FRAMES * MAX_VERTICES * 3 * 2
MAX_ABS_Q24 = 1 << 29


def canonical_coefficients(c: Fraction, s: Fraction, ordinal: int) -> tuple[Fraction, Fraction]:
    """Factor the exact table R=J*D; J is only a coordinate change, never a replacement for R."""
    P.require(type(ordinal) is int and 0 <= ordinal < 4 and isinstance(c, Fraction) and
              isinstance(s, Fraction) and abs(c) <= 1 and abs(s) <= 1, "CARDINAL_COEFFICIENT")
    return ((c, s), (s, -c), (-c, -s), (-s, c))[ordinal]


class CardinalBasis(C.H.InverseHeading):
    """Read/hash the same complete native stream once, retaining only four exact coefficients."""

    def __init__(self, stream, digest: str, producer: str):
        self._cardinals = []
        self._coefficient = 0
        super().__init__(stream, digest, producer)
        P.require(len(self._cardinals) == 4 and self._coefficient == 65536,
                  "CARDINAL_BASIS_CENSUS")
        self.canonical = [canonical_coefficients(c, s, i) for i, (c, s) in enumerate(self._cardinals)]
        # This proof specialization is admitted only for the actual pinned
        # native table. Another backend/table must be reviewed, not rounded.
        P.require(all(c == 1 and abs(s) < Fraction(1, 1 << 20) for c, s in self.canonical),
                  "CARDINAL_NEAR_IDENTITY_UNSUPPORTED")
        self.max_sine = max(abs(s) for _, s in self.canonical)

    def read(self, count):
        raw = super().read(count)
        # InverseHeading advances rows only after the metadata was decoded;
        # neither an eight-byte metadata block nor the footer is a yaw row.
        if count == 8 and self.rows > self._coefficient:
            if self._coefficient in YAWS:
                self._cardinals.append(tuple(Fraction(value) for value in struct.unpack("<ff", raw)))
            self._coefficient = self.rows
        return raw

    def cardinal_certificate(self):
        return dict(self.certificate(), inverse_norm=P.envelope.fraction_record(self.inverse_norm),
                    cardinals=[{"yaw": yaw, "native_c_s": [P.envelope.fraction_record(v) for v in pair],
                                "canonical_c_s": [P.envelope.fraction_record(v) for v in canonical]}
                               for yaw, pair, canonical in zip(YAWS, self._cardinals, self.canonical)])


def common_padding(part, matrices, grounding, roots, hulls, max_sine: Fraction):
    """Enclose J^-1(actual R*source), including D-I, local decode/blend and native World arithmetic.

    For the exact admitted table D=[1,d;-d,1]. The source-dependent |d*z|
    and |d*x| terms stay explicit. No unit-norm assumption or generic margin
    appears. Native horizontal residual axes may swap under J, so use their
    maximum; Y does not change. Returned padding covers every admitted yaw.
    """
    P.require(isinstance(max_sine, Fraction) and 0 <= max_sine < Fraction(1, 1 << 20) and
              0 < len(hulls) <= 8, "CARDINAL_PADDING_INPUT")
    low = np.min(np.stack([h[0].min(axis=0) for h in hulls]), axis=0)
    high = np.max(np.stack([h[1].max(axis=0) for h in hulls]), axis=0)
    P.require(np.all(low > -MAX_ABS_Q24) and np.all(high < MAX_ABS_Q24), "CARDINAL_SOURCE_CAPACITY")
    local_error = P.envelope.palette_residual(part, matrices, grounding)
    local_q = -(-local_error.numerator * P.SCALE // local_error.denominator)
    local = [P.envelope.Interval((int(low[a]) - local_q) * (P.envelope.FIXED // P.SCALE),
                                 (int(high[a]) + local_q) * (P.envelope.FIXED // P.SCALE)) for a in range(3)]
    native_error = P.envelope.world_residual(part, matrices, grounding, local, roots)
    source_magnitude = [Fraction(max(abs(int(low[a])), abs(int(high[a]))), P.SCALE) for a in range(3)]
    horizontal = max(native_error[0], native_error[2])
    errors = [max_sine * source_magnitude[2] + (1 + max_sine) * local_error + horizontal,
              local_error + native_error[1],
              max_sine * source_magnitude[0] + (1 + max_sine) * local_error + horizontal]
    padding = np.array([-(-v.numerator * P.SCALE // v.denominator) for v in errors], dtype=np.int64)
    P.require(all(v >= 0 for v in errors) and
              int(max(np.abs(low).max(), np.abs(high).max())) + int(padding.max()) < MAX_ABS_Q24,
              "CARDINAL_RESIDUAL_CAPACITY")
    return padding, {"canonical_error_m": [P.envelope.fraction_record(v) for v in errors],
                     "local_error_m": P.envelope.fraction_record(local_error),
                     "world_error_m": [P.envelope.fraction_record(v) for v in native_error],
                     "orientation_error_m": [P.envelope.fraction_record(max_sine * source_magnitude[a])
                                              for a in (2, 0)],
                     "maximum_actual_canonical_sine": P.envelope.fraction_record(max_sine)}


def endpoint_cache(case, parts, roots, basis):
    """Complete outward per-vertex endpoints with an explicit finite offline allocation bound."""
    P.require(len(parts) == 2 and 2 <= case["frames"] <= MAX_FRAMES and
              all(len(part["geometry"]) == 1 for part in parts), "CARDINAL_ENDPOINT_CENSUS")
    result, offset, scalars = [], 0, 0
    for part in parts:
        count = max(1, part["binds"])
        vertices = len(part["geometry"][0]["points"])
        scalars += case["frames"] * vertices * 3 * 2
        P.require(0 < vertices <= MAX_VERTICES and scalars <= MAX_ENDPOINT_SCALARS,
                  "CARDINAL_ENDPOINT_CAPACITY")
        matrices = case["matrices"][:, offset:offset + count]
        raw = P._vertex_hulls(part, matrices, case["grounding"])
        padding, errors = common_padding(part, matrices, case["grounding"], roots, raw, basis.max_sine)
        low = np.empty((case["frames"], vertices, 3), dtype=np.int64)
        high = np.empty_like(low)
        for frame in range(case["frames"]):
            a, b = P._vertex_hulls(part, matrices[frame:frame + 1], case["grounding"][frame:frame + 1])[0]
            low[frame], high[frame] = a - padding, b + padding
        result.append({"low": low, "high": high, "padding": padding, "errors": errors})
        offset += count
    P.require(offset == case["matrices"].shape[1], "CARDINAL_UNCONSUMED_PALETTE")
    return result


def clipped_portion(case, row, triangles, axis=1, plane_u=0, positive=False):
    """All triangle interiors on the exact rendered edges; retain either side of one exact plane."""
    P.require(axis in (1, 2) and type(plane_u) is int and abs(plane_u) <= 2097152 and
              type(positive) is bool, "CARDINAL_PARTITION_PLANE")
    order = (0, 1, 2) if axis == 1 else (0, 2, 1)
    low, high = row["low"][:, :, order].copy(), row["high"][:, :, order].copy()
    plane = plane_u * (P.SCALE // 1024)
    if positive:
        low[:, :, 1], high[:, :, 1] = -high[:, :, 1].copy(), -low[:, :, 1].copy()
        plane = -plane
    boxes = []
    for first, last in P.rendered_intervals(case):
        clipped = P.clipped_triangle_floor(low[[first, last]], high[[first, last]], triangles, plane)
        if clipped is not None:
            a, b = clipped[:3], clipped[3:]
            if positive:
                a[1], b[1] = -b[1], -a[1]
            boxes.append([a[order[k]] for k in range(3)] + [b[order[k]] for k in range(3)])
    if not boxes:
        return None
    return P.outward_units(np.array([min(b[a] for b in boxes) for a in range(3)], dtype=np.int64),
                           np.array([max(b[a + 3] for b in boxes) for a in range(3)], dtype=np.int64))


def enclosure_rows(case, parts, topology, cache):
    P.require(len(parts) == len(topology) == len(cache) == 2 and
              all(len(surfaces) == 1 for surfaces in topology), "CARDINAL_PRIMITIVE_CENSUS")
    rows = []
    for part, triangles, row in zip(parts, topology, cache):
        full = P.outward_units(row["low"].min(axis=(0, 1)), row["high"].max(axis=(0, 1)))
        floor = clipped_portion(case, row, triangles[0])
        rows.append({"kind": part["kind"], "name": part["name"], "full_bounds_u": full,
                     "floor_intersection_u": floor, "above_floor_u": [full[0], max(0, full[1]), full[2], *full[3:]],
                     "native_triangles": len(triangles[0]), "intervals": len(P.rendered_intervals(case)),
                     "rendered_edges": [list(edge) for edge in P.rendered_intervals(case)],
                     "loop_mode": P.rendered_timing(case)[0], "duration_q16": P.rendered_timing(case)[1],
                     "yaw_scope": list(YAWS), "canonical_residual": row["errors"]})
    return rows


def exact_cardinal(point, ordinal):
    """Exact J coordinate permutation. Native D was already included by the endpoint proof."""
    P.require(len(point) == 3 and type(ordinal) is int and 0 <= ordinal < 4, "CARDINAL_ROTATION_INPUT")
    x, y, z = point
    return ([x, y, z], [z, y, -x], [-x, y, -z], [-z, y, x])[ordinal]


def orient_box(box, ordinal):
    P.require(len(box) == 6 and all(type(v) is int and abs(v) <= 2097152 for v in box) and
              all(box[a] <= box[a + 3] for a in range(3)), "CARDINAL_BOX_INPUT")
    corners = [exact_cardinal([x, y, z], ordinal) for x in (box[0], box[3])
               for y in (box[1], box[4]) for z in (box[2], box[5])]
    return [min(p[a] for p in corners) for a in range(3)] + [max(p[a] for p in corners) for a in range(3)]


def exact_tip(case, part, vertex, frame, canonical):
    P.require(part["binds"] == 0 and 0 <= vertex < len(part["geometry"][0]["points"]) and
              0 <= frame < case["frames"], "CARDINAL_TIP_SOURCE")
    source = [Fraction(float(value)) for value in part["geometry"][0]["points"][vertex]]
    matrix = case["matrices"][frame, 24]
    point = [sum(source[a] * Fraction(float(matrix[a * 3 + axis])) for a in range(3)) +
             Fraction(float(matrix[9 + axis])) for axis in range(3)]
    point[1] += Fraction(float(case["grounding"][frame]))
    c, s = canonical
    return [c * point[0] + s * point[2], point[1], -s * point[0] + c * point[2]]


def contact_patch(first, last, errors, axis, plane_u):
    """Exact native-table ideal tip plus complete normal/tangent residual crossing enclosure."""
    P.require(len(first) == len(last) == len(errors) == 3 and axis in (1, 2) and
              all(isinstance(v, Fraction) for v in first + last + errors) and all(v >= 0 for v in errors),
              "CARDINAL_CONTACT_INPUT")
    plane = Fraction(plane_u, 1024)
    P.require(first[axis] - errors[axis] > plane and last[axis] + errors[axis] < plane,
              "CARDINAL_CONTACT_NO_CROSSING")
    delta = first[axis] - last[axis]
    shares = [(first[axis] - plane - errors[axis]) / delta, (first[axis] - plane + errors[axis]) / delta]
    P.require(0 < shares[0] <= shares[1] < 1, "CARDINAL_CONTACT_PARAMETER")
    lower, upper = [], []
    for coordinate in range(3):
        if coordinate == axis:
            lower.append(plane_u)
            upper.append(plane_u)
            continue
        ends = [(1 - share) * first[coordinate] + share * last[coordinate] for share in shares]
        lo, hi = (min(ends) - errors[coordinate]) * 1024, (max(ends) + errors[coordinate]) * 1024
        lower.append(lo.numerator // lo.denominator)
        upper.append(-(-hi.numerator // hi.denominator))
    share = (first[axis] - plane) / delta
    anchor = [round(((1 - share) * a + share * b) * 1024) for a, b in zip(first, last)]
    result = {"anchor_u": anchor, "patch_u": lower + upper,
              "exact_ideal_endpoints_m": [[P.envelope.fraction_record(v) for v in row] for row in (first, last)],
              "share_range": [P.envelope.fraction_record(v) for v in shares],
              "residual_m": [P.envelope.fraction_record(v) for v in errors]}
    Q.contact_refusal(result, axis, plane_u)
    return result


def find_contacts(case, part, topology, cache, basis, vertex, axis, plane_u):
    """The same genuine stone-head vertex must cross the selected face at every required heading."""
    triangles = np.flatnonzero(np.any(topology == vertex, axis=1)).tolist()
    P.require(triangles and len(triangles) <= 128, "CARDINAL_CONTACT_TOPOLOGY")
    errors = [Fraction(int(v), P.SCALE) for v in cache["padding"]]
    result = []
    for ordinal, canonical in enumerate(basis.canonical):
        witnesses = []
        for first, last in P.rendered_intervals(case):
            a = exact_tip(case, part, vertex, first, canonical)
            b = exact_tip(case, part, vertex, last, canonical)
            plane = Fraction(plane_u, 1024)
            if a[axis] - errors[axis] <= plane or b[axis] + errors[axis] >= plane:
                continue
            witness = contact_patch(a, b, errors, axis, plane_u)
            witness.update(vertex=vertex, source_triangles=triangles, frame_pair=[first, last], yaw=YAWS[ordinal])
            witnesses.append(witness)
        P.require(witnesses, "CARDINAL_CONTACT_MISSING")
        # Immutable source order selects the first forward strike; no nearest
        # sampled extremum or backward tap can manufacture a contact.
        result.append(witnesses[0])
    return result


def prove_self(case, parts, topology, rig, cache):
    """One canonical interval proof encloses all four actual native headings and every original primitive."""
    body_ids, omitted = S.body_triangle_ids(parts[0], topology[0][0], rig["rig_binding"])
    triangles = [topology[0][0][body_ids], topology[1][0]]
    rows = [(r["low"][:, t], r["high"][:, t]) for r, t in zip(cache, triangles)]
    checks, pairs, unresolved = [0], 0, []
    for first, last in P.rendered_intervals(case):
        (al, ah), (bl, bh) = [(lo[[first, last]].transpose(1, 0, 2, 3),
                               hi[[first, last]].transpose(1, 0, 2, 3)) for lo, hi in rows]
        amin, amax = al.min(axis=(1, 2)), ah.max(axis=(1, 2))
        bmin, bmax = bl.min(axis=(1, 2)), bh.max(axis=(1, 2))
        for tool in range(len(bl)):
            for body in np.flatnonzero(np.all(amin <= bmax[tool], axis=1) & np.all(amax >= bmin[tool], axis=1)):
                pairs += 1
                if not S.separated(al[body], ah[body], bl[tool], bh[tool], checks):
                    unresolved.append({"frame_pair": [first, last], "body_triangle": int(body_ids[body]),
                                       "tool_triangle": tool})
                    if len(unresolved) >= 32:
                        return {"clear": False, "unresolved": unresolved, "checks": checks[0], "pairs": pairs}
        print(json.dumps({"cardinal_self": case.get("id", ""), "frame": first,
                          "checks": checks[0], "unresolved": len(unresolved)}), file=sys.stderr, flush=True)
    return {"clear": not unresolved, "unresolved": unresolved, "checks": checks[0], "pairs": pairs,
            "body_triangles": len(body_ids), "intentional_grip_triangles": omitted,
            "tool_triangles": len(triangles[1]), "intervals": len(P.rendered_intervals(case)),
            "rendered_edges": [list(edge) for edge in P.rendered_intervals(case)],
            "loop_mode": P.rendered_timing(case)[0], "duration_q16": P.rendered_timing(case)[1],
            "yaw_scope": list(YAWS), "source_frame": "J inverse of native World; D-I explicitly enclosed"}
