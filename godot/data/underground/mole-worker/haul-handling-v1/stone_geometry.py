#!/usr/bin/env python3
"""Exact containment in the carried stone lump (ADR 1206).

The shared wood prover's `solid_containment` tests a point against every face plane, which is exact only for a
convex stock. The lump is not convex. It is a sphere whose vertices were pushed radially, so it is star-shaped
about its own origin (the stock transform's translation). For a star-shaped closed mesh, a point p lies inside
or on it exactly when, for the face whose cone from the origin o contains p - o, the barycentric weights of
p - o in that cone sum to at most one. Every step below is rational arithmetic on the exact source vertices.
"""
from __future__ import annotations

from fractions import Fraction as F

import numpy as np

import author_handling as A
import prove_static_contact as S


def det(a: tuple, b: tuple, c: tuple):
    return S.dot(a, S.cross(b, c))


def origin(case: dict, offset: int = 24) -> tuple:
    """The exact world image (u) of the stone's local origin at the case's single frame."""
    m = [F(float(v)) for v in case["matrices"][0, offset]]
    return (m[9] * 1024, (m[10] + F(float(case["grounding"][0]))) * 1024, m[11] * 1024)


def faces(case: dict, stone: dict, tri: np.ndarray) -> tuple:
    """Exact face cones; refuses a mesh whose non-degenerate faces are not all oriented alike about o."""
    o = origin(case)
    points = [S.sub(S.exact_vertex(case, stone, at, 24), o) for at in range(len(stone["geometry"][0]["points"]))]
    rows = []
    for a, b, c in tri:
        pa, pb, pc = points[int(a)], points[int(b)], points[int(c)]
        volume = det(pa, pb, pc)
        if volume != 0:
            rows.append((pa, pb, pc, volume))
    signs = {row[3] > 0 for row in rows}
    A.require(len(signs) == 1 and len(rows) > 0, "STONE_NOT_STAR_SHAPED")
    return o, rows


def contained(point: tuple, o: tuple, rows: list) -> bool:
    """Exact: p is inside or on the closed lump. Refuses a direction no face cone covers."""
    d = S.sub(point, o)
    if not any(d):
        return True
    for pa, pb, pc, volume in rows:
        alpha, beta, gamma = det(d, pb, pc), det(pa, d, pc), det(pa, pb, d)
        if volume > 0 and alpha >= 0 and beta >= 0 and gamma >= 0 or \
                volume < 0 and alpha <= 0 and beta <= 0 and gamma <= 0:
            return (alpha + beta + gamma) / volume <= 1
    raise ValueError("STONE_CONE_COVERAGE")


def solid_inside(case: dict, body: dict, stone: dict, tri: np.ndarray, solid_vertices: np.ndarray) -> list:
    """Every solid body vertex inside or on the stone at the case's frame (exact); bounds prefilter only."""
    o, rows = faces(case, stone, tri)
    stone_u = A.I.points_at(case, stone, 0, 24)
    low, high = stone_u.min(axis=0) - 1, stone_u.max(axis=0) + 1
    body_u = A.I.points_at(case, body, 0)
    near = solid_vertices[np.all((body_u[solid_vertices] >= low) & (body_u[solid_vertices] <= high), axis=1)]
    return [int(at) for at in near if contained(S.exact_vertex(case, body, int(at), 0), o, rows)]
