#!/usr/bin/env python3
"""Exact polynomial grip certificates for affine source intervals whose complete stock may rotate."""
from __future__ import annotations

from fractions import Fraction as F
from math import comb

import prove_static_contact as S

MAX_DEGREE = 7
MAX_DEPTH = 10
MAX_NODES = 4095


def trim(values: tuple) -> tuple:
    while len(values) > 1 and values[-1] == 0:
        values = values[:-1]
    return values


def add(a: tuple, b: tuple) -> tuple:
    return trim(tuple((a[i] if i < len(a) else F(0)) + (b[i] if i < len(b) else F(0))
                      for i in range(max(len(a), len(b)))))


def neg(a: tuple) -> tuple:
    return tuple(-v for v in a)


def sub(a: tuple, b: tuple) -> tuple:
    return add(a, neg(b))


def mul(a: tuple, b: tuple) -> tuple:
    result = [F(0)] * (len(a) + len(b) - 1)
    if len(result) - 1 > MAX_DEGREE:
        raise ValueError("HAUL_GRIP_POLYNOMIAL_CAPACITY")
    for i, av in enumerate(a):
        for j, bv in enumerate(b):
            result[i + j] += av * bv
    return trim(tuple(result))


def vsub(a: tuple, b: tuple) -> tuple:
    return tuple(sub(x, y) for x, y in zip(a, b))


def vcross(a: tuple, b: tuple) -> tuple:
    return (sub(mul(a[1], b[2]), mul(a[2], b[1])), sub(mul(a[2], b[0]), mul(a[0], b[2])),
            sub(mul(a[0], b[1]), mul(a[1], b[0])))


def vdot(a: tuple, b: tuple) -> tuple:
    result = (F(0),)
    for first, second in zip(a, b):
        result = add(result, mul(first, second))
    return result


def vscale(a: tuple, b: tuple) -> tuple:
    return tuple(mul(a, value) for value in b)


def trajectory(first: tuple, last: tuple) -> tuple:
    return tuple((a, b - a) for a, b in zip(first, last))


def bernstein(values: tuple) -> tuple:
    degree = len(values) - 1
    if degree > MAX_DEGREE:
        raise ValueError("HAUL_GRIP_POLYNOMIAL_CAPACITY")
    return tuple(sum((values[k] * F(comb(i, k), comb(degree, k)) for k in range(i + 1)), F(0))
                 for i in range(degree + 1))


def positive_coefficients(values: tuple, strict: bool, counter: list, depth: int = 0) -> bool:
    counter[0] += 1
    if counter[0] > MAX_NODES:
        raise ValueError("HAUL_GRIP_PROOF_CAPACITY")
    if all(value > 0 if strict else value >= 0 for value in values):
        return True
    if values[0] < 0 or values[-1] < 0 or (strict and (values[0] == 0 or values[-1] == 0)):
        return False
    if depth >= MAX_DEPTH:
        return False
    row, left, right = values, [values[0]], [values[-1]]
    while len(row) > 1:
        row = tuple((row[i] + row[i + 1]) / 2 for i in range(len(row) - 1))
        left.append(row[0])
        right.append(row[-1])
    return positive_coefficients(tuple(left), strict, counter, depth + 1) and \
        positive_coefficients(tuple(reversed(right)), strict, counter, depth + 1)


def nonnegative(values: tuple, strict: bool = False, counter: list | None = None) -> bool:
    return positive_coefficients(bernstein(values), strict, [0] if counter is None else counter)


def interval_contact(first: list, last: list, stock_first: list, stock_last: list, edge: tuple) -> dict:
    """Every common interpolation time has a real hand-edge / complete-stock-triangle intersection.

    Plane distances have degree <=3 and each barycentric half-plane numerator <=7.
    Exact rational Bernstein enclosures are sufficient conditions; any unresolved sign refuses.
    """
    hand = [trajectory(first[at], last[at]) for at in edge]
    stock = [trajectory(a, b) for a, b in zip(stock_first, stock_last)]
    normal = vcross(vsub(stock[1], stock[0]), vsub(stock[2], stock[0]))
    first_distance = vdot(normal, vsub(hand[0], stock[0]))
    last_distance = vdot(normal, vsub(hand[1], stock[0]))
    if first_distance[0] <= 0 <= last_distance[0]:
        hand.reverse()
        first_distance, last_distance = last_distance, first_distance
    counter = [0]
    denominator = sub(first_distance, last_distance)
    if not (nonnegative(first_distance, counter=counter) and nonnegative(neg(last_distance), counter=counter)
            and nonnegative(denominator, strict=True, counter=counter)):
        return {"contact": False, "reason": "plane_crossing", "nodes": counter[0]}
    numerator = vsub(vscale(first_distance, hand[1]), vscale(last_distance, hand[0]))
    degrees = [len(first_distance) - 1, len(last_distance) - 1]
    for at in range(3):
        side = vsub(stock[(at + 1) % 3], stock[at])
        relative = vsub(numerator, vscale(denominator, stock[at]))
        condition = vdot(normal, vcross(side, relative))
        degrees.append(len(condition) - 1)
        if not nonnegative(condition, counter=counter):
            return {"contact": False, "reason": "triangle_interior", "edge": at, "nodes": counter[0]}
    return {"contact": True, "nodes": counter[0], "degrees": degrees}


def actual_contact(case: dict, body: dict, wood: dict, body_tri, wood_tri, pair: dict, first: int, last: int) -> dict:
    frames = [{**case, "matrices": case["matrices"][at:at + 1], "grounding": case["grounding"][at:at + 1], "frames": 1}
              for at in (first, last)]
    hands = [[S.exact_vertex(frame, body, int(vertex), 0) for vertex in body_tri[pair["body_triangle"]]] for frame in frames]
    stocks = [[S.exact_vertex(frame, wood, int(vertex), 24) for vertex in wood_tri[pair["wood_triangle"]]] for frame in frames]
    return interval_contact(*hands, *stocks, tuple(pair["edge"]))
