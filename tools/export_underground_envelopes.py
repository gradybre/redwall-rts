#!/usr/bin/env python3
"""Source-bound continuous envelopes from exact Godot imported records (decision1080).

This cold exporter streams the native source image. Dyadic interval operations round
outward, including quaternion normalization and skinning. Source mathematics and
actual engine numerical/presentation qualification remain separate certificate fields.
"""
from __future__ import annotations

import argparse
from functools import lru_cache
from dataclasses import dataclass
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import struct
from typing import BinaryIO, Iterator

MAX_BYTES = 64 * 1024 * 1024
MAX_TEXT = 1024 * 1024
MAX_CASES, MAX_BONES, MAX_CLIPS, MAX_TRACKS, MAX_KEYS = 128, 64, 32, 192, 8192
MAX_VERTICES, MAX_PARTS = 200000, 32
FIXED = 1 << 48
TRANSIT = ("idle", "walk", "cautious_crouch_walk_forward", "carry_heavy_object_walk")
GODOT_SOURCE_HASH = "ed1daf0bf001b61586d9930840f2f1394092c079"


class Refused(ValueError):
    """A missing identity or unsupported mathematical premise cannot become a profile."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise Refused(code)


def integer(value: object, low: int, high: int) -> bool:
    return type(value) is int and low <= value <= high


@dataclass(frozen=True)
class Interval:
    """Closed dyadic interval, with no inward rounding or binary-float arithmetic."""

    low: int
    high: int

    def __post_init__(self) -> None:
        require(type(self.low) is int and type(self.high) is int and self.low <= self.high,
                "INTERVAL_ORDER")
        require(max(abs(self.low), abs(self.high)).bit_length() <= 160, "INTERVAL_CAPACITY")

    @staticmethod
    def exact(value: int | float | Fraction) -> Interval:
        require(type(value) in (int, float, Fraction), "NUMBER_TYPE")
        if type(value) is float:
            require(math.isfinite(value) and abs(value) <= 1000000, "NONFINITE_OR_EXTREME")
        scaled = Fraction(value) * FIXED
        return Interval(scaled.numerator // scaled.denominator,
                        -(-scaled.numerator // scaled.denominator))

    def __add__(self, other: Interval) -> Interval:
        return Interval(self.low + other.low, self.high + other.high)

    def __neg__(self) -> Interval:
        return Interval(-self.high, -self.low)

    def __sub__(self, other: Interval) -> Interval:
        return self + -other

    def __mul__(self, other: Interval) -> Interval:
        products = [self.low * other.low, self.low * other.high,
                    self.high * other.low, self.high * other.high]
        return Interval(min(products) // FIXED, -(-max(products) // FIXED))

    def reciprocal_positive(self) -> Interval:
        require(self.low > 0, "NORMALIZATION_ZERO")
        return Interval(FIXED * FIXED // self.high, -(-FIXED * FIXED // self.low))

    def square(self) -> Interval:
        smallest = 0 if self.low <= 0 <= self.high else min(self.low * self.low, self.high * self.high)
        largest = max(self.low * self.low, self.high * self.high)
        return Interval(smallest // FIXED, -(-largest // FIXED))

    def sqrt(self) -> Interval:
        require(self.low >= 0, "NEGATIVE_SQRT")
        lo = math.isqrt(self.low * FIXED)
        hi = math.isqrt(self.high * FIXED)
        return Interval(lo, hi if hi * hi == self.high * FIXED else hi + 1)

    def hull(self, other: Interval) -> Interval:
        return Interval(min(self.low, other.low), max(self.high, other.high))

    def intersect(self, other: Interval) -> Interval:
        require(max(self.low, other.low) <= min(self.high, other.high), "EMPTY_PROOF_INTERSECTION")
        return Interval(max(self.low, other.low), min(self.high, other.high))

    def units(self) -> tuple[int, int]:
        return self.low * 1024 // FIXED, -(-self.high * 1024 // FIXED)


ZERO, ONE, TWO = (Interval.exact(n) for n in (0, 1, 2))
ROTATION_COMPONENT = Interval(-FIXED, FIXED)


def vector(values: list[float]) -> list[Interval]:
    return [v if isinstance(v, Interval) else Interval.exact(v) for v in values]


def dot(a: list[Interval], b: list[Interval]) -> Interval:
    require(len(a) == len(b), "DOT_SHAPE")
    return sum((x * y for x, y in zip(a, b)), ZERO)


def unit_quaternion(values: list[float]) -> list[Interval]:
    require(len(values) == 4, "QUATERNION_SHAPE")
    q = vector(values)
    factor = sum((v.square() for v in q), ZERO).sqrt().reciprocal_positive()
    return [v * factor for v in q]


def conjugate(q: list[Interval]) -> list[Interval]:
    return [-q[0], -q[1], -q[2], q[3]]


def quaternion_multiply(a: list[Interval], b: list[Interval]) -> list[Interval]:
    x, y, z, w = a
    i, j, k, r = b
    return [w*i+x*r+y*k-z*j, w*j+y*r+z*i-x*k, w*k+z*r+x*j-y*i, w*r-x*i-y*j-z*k]


def rotation_matrix(q: list[Interval]) -> list[list[Interval]]:
    x, y, z, w = q
    return [[ONE-TWO*(y.square()+z.square()), TWO*(x*y-z*w), TWO*(x*z+y*w)],
            [TWO*(x*y+z*w), ONE-TWO*(x.square()+z.square()), TWO*(y*z-x*w)],
            [TWO*(x*z-y*w), TWO*(y*z+x*w), ONE-TWO*(x.square()+y.square())]]


def multiply(a: list[list[Interval]], b: list[list[Interval]]) -> list[list[Interval]]:
    return [[sum((a[r][k] * b[k][c] for k in range(3)), ZERO) for c in range(3)] for r in range(3)]


def transform_point(basis: list[list[Interval]], origin: list[Interval], point: list[Interval]) -> list[Interval]:
    return [dot(basis[r], point) + origin[r] for r in range(3)]


def affine(raw: list[float]) -> tuple[list[list[Interval]], list[Interval]]:
    require(len(raw) == 12, "AFFINE_SHAPE")
    return [[Interval.exact(raw[c*3+r]) for c in range(3)] for r in range(3)], vector(raw[9:12])


def quaternion_hull(values: list[list[float]]) -> list[list[Interval]]:
    """Enclose a single SLERP arc or normalized positive cone (not Godot rest-relative mixing).

    A common cone with pairwise positive dot products keeps Godot's shortest-arc
    sign choice inside that cone. An unsupported cone expands to every rotation;
    it never silently assumes equivalent component-wise quaternion interpolation.
    """
    require(bool(values), "ROTATION_STATE_MISSING")
    anchor = unit_quaternion(values[0])
    inverse = conjugate(anchor)
    local: list[list[Interval]] = []
    for value in values:
        q = unit_quaternion(value)
        alignment = dot(anchor, q)
        if alignment.high < 0:
            q = [-v for v in q]
        elif alignment.low <= 0:
            return [[ROTATION_COMPONENT for _ in range(3)] for _ in range(3)]
        delta = quaternion_multiply(inverse, q)
        # w >= sqrt(1/2) gives pairwise separation <= pi/2 on S3.
        if delta[3].low < 0 or delta[3].low * delta[3].low < FIXED * FIXED // 2:
            return [[ROTATION_COMPONENT for _ in range(3)] for _ in range(3)]
        local.append(delta)
    box = [local[0][i] for i in range(4)]
    for row in local[1:]:
        box = [a.hull(b) for a, b in zip(box, row)]
    norm = sum((v.square() for v in box), ZERO).sqrt()
    qbox = [(v * norm.reciprocal_positive()).intersect(ROTATION_COMPONENT) for v in box]
    result = multiply(rotation_matrix(anchor), rotation_matrix(qbox))
    return [[value.intersect(ROTATION_COMPONENT) for value in row] for row in result]


def atan_fraction_bounds(value: Fraction, terms: int = 32) -> tuple[Fraction, Fraction]:
    """Alternating-series rational bounds; no decimal approximation is assumed exact."""
    require(0 < value <= Fraction(1, 5) and 1 <= terms <= 128, "ATAN_PROOF_DOMAIN")
    total = sum(((-1)**n * value**(2*n+1) / (2*n+1) for n in range(terms)), Fraction(0))
    following = (-1)**terms * value**(2*terms+1) / (2*terms+1)
    return min(total, total+following), max(total, total+following)


def pi_interval() -> Interval:
    """Machin's exact identity pi=16 atan(1/5)-4 atan(1/239), rounded outward once."""
    low_a, high_a = atan_fraction_bounds(Fraction(1, 5))
    low_b, high_b = atan_fraction_bounds(Fraction(1, 239))
    low, high = 16*low_a-4*high_b, 16*high_a-4*low_b
    return Interval(Interval.exact(low).low, Interval.exact(high).high)


PI = pi_interval()


@lru_cache(maxsize=32768)
def trig_point(kind: str, value: int) -> Interval:
    """Outward Taylor proof on [-pi,pi]; float trig is never used as a certificate."""
    require(kind in ("sin", "cos", "sinc") and abs(value) <= PI.high, "TRIG_DOMAIN")
    x = Interval(value, value)
    term = x if kind == "sin" else ONE
    result = term
    for index in range(1, 21):
        denominator = (2*index)*(2*index+1) if kind in ("sin", "sinc") else (2*index-1)*(2*index)
        term = term*x.square()*Interval.exact(Fraction(1, denominator))
        result = result-term if index % 2 else result+term
    denominator = 42*43 if kind in ("sin", "sinc") else 41*42
    following = term*x.square()*Interval.exact(Fraction(1, denominator))
    # Subsequent absolute terms have ratio <= pi²/(42*43) < 1/2.
    residual = 2*max(abs(following.low), abs(following.high))
    return result+Interval(-residual, residual)


@lru_cache(maxsize=32768)
def acos_point(value: int) -> Interval:
    """An approximate seed is accepted only after two exact outward cosine inequalities prove it."""
    require(0 <= value <= FIXED, "ACOS_DOMAIN")
    if value == FIXED:
        return ZERO
    if value == 0:
        return Interval(PI.low//2, -(-PI.high//2))
    seed = int(math.acos(value/FIXED)*FIXED)
    span = 1
    for _ in range(64):
        low, high = max(0, seed-span), min(PI.high//2+1, seed+span)
        lower_proved = low == 0 or trig_point("cos", low).low >= value
        upper_proved = high >= PI.high//2 or trig_point("cos", high).high <= value
        if lower_proved and upper_proved:
            return Interval(low, high)
        span *= 2
    raise Refused("ACOS_PROOF_CAPACITY")


def acos_range(value: Interval) -> Interval:
    clipped = value.intersect(Interval(0, FIXED))
    return Interval(acos_point(clipped.high).low, acos_point(clipped.low).high)


def sinc_range(value: Interval) -> Interval:
    require(0 <= value.low <= value.high <= PI.high, "SINC_DOMAIN")
    # sin(x)/x is positive and decreasing on [0,pi].
    return Interval(trig_point("sinc", value.high).low, trig_point("sinc", value.low).high)


def norm(values: list[Interval]) -> Interval:
    return sum((v.square() for v in values), ZERO).sqrt()


def normalize(values: list[Interval]) -> list[Interval]:
    scale = norm(values).reciprocal_positive()
    return [(value*scale).intersect(ROTATION_COMPONENT) for value in values]


def relative_log(rest: list[Interval], value: list[float]) -> tuple[list[Interval], list[Interval]] | None:
    """Shortest rest-relative S3 logarithm; an unproved sign/branch refuses the tighter enclosure."""
    delta = normalize(quaternion_multiply(conjugate(rest), unit_quaternion(value)))
    if delta[3].high < 0:
        delta = [-v for v in delta]
    if delta[3].low < 0:
        return None
    angle = acos_range(delta[3])
    factor = sinc_range(angle).reciprocal_positive()
    return [v*factor for v in delta[:3]], delta


def exponential(value: list[Interval]) -> list[Interval]:
    angle = norm(value)
    require(angle.high <= PI.high, "EXPONENTIAL_DOMAIN")
    factor = sinc_range(angle)
    cosine = Interval(trig_point("cos", angle.high).low, trig_point("cos", angle.low).high)
    return normalize([v*factor for v in value]+[cosine])


def _component_upper(centre: Interval, radius: int) -> int:
    cosine = trig_point("cos", radius)
    if centre.high >= cosine.low:
        return FIXED
    c = Interval(centre.high, centre.high)
    radial = (ONE-c.square()).intersect(Interval(0, FIXED)).sqrt()
    return min(FIXED, (c*cosine+radial*trig_point("sin", radius)).high)


def rotation_ball(centre: list[list[Interval]], radius: int) -> list[list[Interval]]:
    """Every output unit column remains inside the certified SO3 angular ball."""
    if radius >= PI.low:
        return [[ROTATION_COMPONENT for _ in range(3)] for _ in range(3)]
    return [[Interval(-_component_upper(-value, radius), _component_upper(value, radius))
             for value in row] for row in centre]


def mixer_rotation(rest_value: list[float], values: list[list[float]], segments: list[tuple]) -> list[list[Interval]]:
    """All nonnegative rest-relative product blends, with ANY number of active clips.

    Write normalized delta_i=exp(X_i), sum(w_i)=1. Bi-invariant S3 distance and
    the nonexpansive quaternion exponential give
      d(product exp(w_i X_i), exp(X0)) <= sum w_i |X_i-X0| <= max |X_i-X0|.
    Native Godot4.7.2 uses exactly this rest-relative product, not a convex
    quaternion blend. The log map is pi/2-Lipschitz on the chosen hemisphere;
    nearest segment endpoints add at most pi/4 times the full S3 key-arc length.
    """
    require(bool(values), "ROTATION_STATE_MISSING")
    rest = unit_quaternion(rest_value)
    records = [relative_log(rest, q) for q in values]
    free = [[ROTATION_COMPONENT for _ in range(3)] for _ in range(3)]
    if any(record is None for record in records):
        return free
    vectors = [record[0] for record in records]
    centre = [Interval((min(v[a].low for v in vectors)+max(v[a].high for v in vectors))//2,
                       (min(v[a].low for v in vectors)+max(v[a].high for v in vectors))//2) for a in range(3)]
    radius = max(norm([a-b for a,b in zip(v,centre)]).high for v in vectors)
    curve = 0
    for first, second in segments:
        a, b = relative_log(rest, first), relative_log(rest, second)
        if a is None or b is None or dot(a[1], b[1]).low <= 0:
            return free
        arc = acos_range(dot(a[1],b[1])).high
        curve = max(curve, -(-arc*PI.high//(4*FIXED)))
    physical_radius = 2*(radius+curve)
    reference = normalize(quaternion_multiply(rest, exponential(centre)))
    return rotation_ball(rotation_matrix(reference), physical_radius)


class NativeSource:
    """Finite streaming reader; the digest is over the exact bytes actually decoded."""

    def __init__(self, stream: BinaryIO, expected_sha256: str):
        require(len(expected_sha256) == 64 and all(c in "0123456789abcdef" for c in expected_sha256), "SOURCE_HASH_FORMAT")
        self.stream, self.expected = stream, expected_sha256
        self.hash = hashlib.sha256()
        self.offset = self.vertices = self.keys = 0
        require(self.read(8) == b"UGNSRC01", "SOURCE_SCHEMA")
        self.version = self.u32()
        require(self.version in (1, 2, 3), "SOURCE_SCHEMA")
        try:
            self.metadata = json.loads(self.text())
        except (ValueError, UnicodeError) as error:
            raise Refused("SOURCE_METADATA") from error
        require(isinstance(self.metadata, dict) and isinstance(self.metadata.get("cases"), list), "SOURCE_METADATA")
        self.count = self.counted(MAX_CASES)
        require(self.count == len(self.metadata["cases"]), "SOURCE_CASE_CENSUS")

    def read(self, count: int) -> bytes:
        require(integer(count, 0, MAX_BYTES - self.offset), "SOURCE_BYTE_CAPACITY")
        data = self.stream.read(count)
        require(len(data) == count, "SOURCE_TRUNCATED")
        self.hash.update(data)
        self.offset += count
        return data

    def u32(self) -> int:
        return struct.unpack("<I", self.read(4))[0]

    def counted(self, maximum: int, minimum: int = 1) -> int:
        count = self.u32()
        require(minimum <= count <= maximum, "SOURCE_COUNT_CAPACITY")
        return count

    def text(self) -> str:
        count = self.counted(MAX_TEXT, 0)
        try:
            return self.read(count).decode("utf-8", "strict")
        except UnicodeError as error:
            raise Refused("SOURCE_TEXT_ENCODING") from error

    def numbers(self, count: int) -> list[float]:
        values = list(struct.unpack("<" + "d" * count, self.read(8 * count)))
        require(all(math.isfinite(v) and abs(v) <= 1000000 for v in values), "SOURCE_NUMBER")
        return values

    def cases(self) -> Iterator[dict]:
        seen: set[str] = set()
        for index in range(self.count):
            row = self.case()
            require(row["id"] not in seen and row["id"] == self.metadata["cases"][index]["id"], "SOURCE_CASE_IDENTITY")
            require(row["cast"] == self.metadata["cases"][index]["cast"] and row["species"] == self.metadata["cases"][index]["species"], "SOURCE_CAST_IDENTITY")
            require([item["key"] for item in row["items"]] == self.metadata["cases"][index]["attachments"],
                    "SOURCE_ATTACHMENT_CENSUS")
            seen.add(row["id"])
            yield row
        require(self.read(8) == b"UGNEND01" and self.u32() == self.count and self.text() == "", "SOURCE_COMPLETION")
        require(self.stream.read(1) == b"", "SOURCE_TRAILING_BYTES")
        require(self.hash.hexdigest() == self.expected, "SOURCE_HASH_MISMATCH")

    def case(self) -> dict:
        row = {"id": self.text(), "cast": self.text(), "species": self.text(), "height": self.numbers(1)[0],
               "skeleton_to_actor": self.numbers(12), "actor_transform": self.numbers(12)}
        row["bones"] = [self.bone() for _ in range(self.counted(MAX_BONES))]
        validate_hierarchy(row["bones"])
        row["clips"] = [self.clip(len(row["bones"])) for _ in range(self.counted(MAX_CLIPS))]
        row["body"] = [self.part(len(row["bones"])) for _ in range(self.counted(MAX_PARTS))]
        row["items"] = [self.item(len(row["bones"])) for _ in range(self.counted(16, 0))]
        row["modifiers"] = [(self.text(), self.text(), self.u32(), self.numbers(1)[0]) for _ in range(self.counted(8, 0))]
        row["stoop_found"] = self.u32()
        row["up"], row["right"] = self.numbers(3), self.numbers(3)
        row["tail_refusal"], row["tail_metadata"] = self.text(), self.text()
        row["bindings"] = self.numbers(6)
        row["presentation"] = json.loads(self.text()) if self.version >= 2 else {}
        if self.version >= 3:
            row["motion_scale"] = self.numbers(1)[0]
            row["player_script"], row["skeleton_script"], row["has_reset"] = self.text(), self.text(), self.u32()
            row["tail_clearances"] = self.numbers(self.counted(9, 0))
            row["tail_tip"] = self.numbers(3)
            row["tail_floor"] = self.numbers(1)[0]
            require(row["motion_scale"] > 0 and row["player_script"] == row["skeleton_script"] == ""
                    and row["has_reset"] == 0, "NATIVE_POSTPROCESS_UNSUPPORTED")
        return row

    def bone(self) -> dict:
        name, parent = self.text(), self.u32()
        return {"name": name, "parent": -1 if parent == 0xffffffff else parent, "rest": self.numbers(12),
                "position": self.numbers(3), "rotation": self.numbers(4), "scale": self.numbers(3)}

    def clip(self, bones: int) -> dict:
        row = {"name": self.text(), "length": self.numbers(1)[0], "loop": self.u32()}
        require(row["length"] > 0 and row["loop"] in (0, 1), "SOURCE_CLIP_SEMANTICS")
        row["tracks"] = [self.track(bones) for _ in range(self.counted(MAX_TRACKS, 0))]
        targets = [(t["bone"], t["type"]) for t in row["tracks"]]
        require(len(targets) == len(set(targets)), "SOURCE_DUPLICATE_TRACK")
        return row

    def track(self, bones: int) -> dict:
        row = {"path": self.text(), "bone": self.u32(), "type": self.u32(), "interpolation": self.u32(), "wrap": self.u32()}
        require(row["bone"] < bones and row["type"] in (1, 2, 3) and row["interpolation"] in (0, 1) and row["wrap"] in (0, 1), "SOURCE_TRACK_SEMANTICS")
        count = self.counted(MAX_KEYS)
        self.keys += count
        require(self.keys <= 500000, "SOURCE_TOTAL_KEY_CAPACITY")
        row["keys"] = [self.numbers(6 if row["type"] == 2 else 5) for _ in range(count)]
        require(all(key[0] >= 0 and key[1] == 1 for key in row["keys"]) and
                all(a[0] < b[0] for a, b in zip(row["keys"], row["keys"][1:])), "SOURCE_KEY_SEMANTICS")
        return row

    def part(self, bones: int) -> dict:
        row = {"path": self.text(), "transform": self.numbers(12)}
        row["binds"] = [(self.u32(), self.numbers(12)) for _ in range(self.counted(MAX_BONES, 0))]
        require(all(b < bones for b, _ in row["binds"]), "SOURCE_BIND_BONE")
        row["surfaces"] = [self.surface(len(row["binds"])) for _ in range(self.counted(MAX_PARTS))]
        return row

    def surface(self, binds: int) -> list[tuple[list[float], list[tuple[int, float]]]]:
        count, stride = self.counted(MAX_VERTICES), self.u32()
        self.vertices += count
        require(self.vertices <= MAX_VERTICES * 8 and (stride in (4, 8) if binds else stride == 0), "SOURCE_SURFACE_CAPACITY")
        vertices = []
        for _ in range(count):
            point = self.numbers(3)
            influences = [(self.u32(), self.numbers(1)[0]) for _ in range(stride)]
            require(all(b < binds and w >= 0 for b, w in influences) and
                    (not influences or sum(Fraction(w) for _, w in influences) > 0), "SOURCE_WEIGHT")
            vertices.append((point, influences))
        return vertices

    def item(self, bones: int) -> dict:
        row = {"key": self.text(), "fit": self.numbers(12), "left": self.u32(), "right": self.u32()}
        require(row["left"] < bones and row["right"] < bones, "SOURCE_ATTACHMENT_BONE")
        row["surfaces"] = []
        total = 0
        for _ in range(self.counted(MAX_PARTS)):
            count = self.counted(MAX_VERTICES)
            total += count
            require(total <= MAX_VERTICES, "SOURCE_ATTACHMENT_CAPACITY")
            row["surfaces"].append([self.numbers(3) for _ in range(count)])
        return row


def validate_hierarchy(bones: list[dict]) -> list[int]:
    names = [bone["name"] for bone in bones]
    require(len(names) == len(set(names)) and all(names), "SOURCE_BONE_NAMES")
    order, pending = [], set(range(len(bones)))
    while pending:
        ready = sorted(i for i in pending if bones[i]["parent"] == -1 or bones[i]["parent"] in order)
        require(bool(ready), "SOURCE_HIERARCHY_CYCLE_OR_PARENT")
        order.extend(ready)
        pending.difference_update(ready)
    return order


def hull_vectors(values: list[list[float]]) -> list[Interval]:
    result = vector(values[0])
    for value in values[1:]:
        result = [a.hull(b) for a, b in zip(result, vector(value))]
    return result


def bone_domains(case: dict, clips: list[str], posture: str, windows: dict | None = None, mixer: bool = False) -> list[dict]:
    require(posture in ("upright", "stooped"), "POSTURE_UNSUPPORTED")
    allowed_scripts = {"res://demo/cast/stoop_modifier.gd", "res://scripts/presentation/tail_ground_constraint.gd",
                       "res://scripts/presentation/tail_flat_roll.gd"}
    proof = case.get("presentation", {})
    require(all((kind == "SpringBoneSimulator3D" and script == "") or script in allowed_scripts or
                (kind == "PhysicalBoneSimulator3D" and script == "" and proof.get("physical_bones") == 0
                 and proof.get("physical_simulating") is False)
                for kind, script, _, _ in case["modifiers"]), "MODIFIER_BINDING_UNSUPPORTED")
    requested = {"cast/" + name for name in clips}
    actual = {clip["name"]: clip for clip in case["clips"]}
    require(requested <= actual.keys(), "REQUIRED_STATE_MISSING")
    domains = [{key: [] for key in ("position", "rotation", "scale")} for bone in case["bones"]]
    for name in sorted(requested):
        require(bool(actual[name]["tracks"]), "REQUIRED_STATE_EMPTY")
        written = set()
        for track in actual[name]["tracks"]:
            key = {1: "position", 2: "rotation", 3: "scale"}[track["type"]]
            values = track["keys"] if windows is None else window_keys(track, windows[name], actual[name])
            exact_values = [k[2:] for k in values]
            if key == "position" and "motion_scale" in case:
                exact_values = [[v*Interval.exact(case["motion_scale"]) for v in vector(row)] for row in exact_values]
            domains[track["bone"]][key].extend(exact_values)
            written.add((track["bone"], key))
        for bone, original in enumerate(case["bones"]):
            for key in ("position", "rotation", "scale"):
                if (bone, key) not in written:
                    domains[bone][key].append(original[key])
    segments = [[] for _ in case["bones"]]
    for name in requested:
        for track in actual[name]["tracks"]:
            if track["type"] == 2:
                segments[track["bone"]].extend((a[2:], b[2:]) for a,b in zip(track["keys"],track["keys"][1:]))
                if actual[name]["loop"] and track["wrap"]:
                    segments[track["bone"]].append((track["keys"][-1][2:],track["keys"][0][2:]))
    result = []
    for bone_index, (bone, domain) in enumerate(zip(case["bones"], domains)):
        free = bone["name"].startswith("tail_") or (posture == "stooped" and bone["name"] in
                ("Spine02", "Spine01", "Spine", "neck", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"))
        rotation = [[ROTATION_COMPONENT for _ in range(3)] for _ in range(3)] if free else (
            mixer_rotation(bone["rotation"], domain["rotation"], segments[bone_index]) if mixer else quaternion_hull(domain["rotation"]))
        position, scale = hull_vectors(domain["position"]), hull_vectors(domain["scale"])
        if posture == "stooped" and bone["name"] == "Hips":
            # Parent inverse can change local components. The global drop is handled below.
            require(bone["parent"] == -1 or case["bones"][bone["parent"]]["name"] == "Root", "STOOP_HIPS_PARENT_UNSUPPORTED")
        result.append({"basis": [[rotation[r][c] * scale[c] for c in range(3)] for r in range(3)],
                       "origin": position, "scale_bound": max(max(abs(v.low), abs(v.high)) for v in scale)})
    return result


def global_domains(case: dict, clips: list[str], posture: str, windows: dict | None = None, mixer: bool = False) -> list[dict]:
    local = bone_domains(case, clips, posture, windows, mixer)
    result: list[dict] = [{} for _ in local]
    for i in validate_hierarchy(case["bones"]):
        parent, row = case["bones"][i]["parent"], local[i]
        if parent < 0:
            result[i] = dict(row)
        else:
            above = result[parent]
            bound = -(-above["scale_bound"] * row["scale_bound"] // FIXED)
            basis = multiply(above["basis"], row["basis"])
            result[i] = {"basis": [[v.intersect(Interval(-bound, bound)) for v in line] for line in basis],
                         "origin": transform_point(above["basis"], above["origin"], row["origin"]), "scale_bound": bound}
        if posture == "stooped" and case["bones"][i]["name"] == "Hips":
            drop = Interval.exact(case["height"]) * Interval.exact(case["bindings"][2])
            for axis, up in enumerate(case["up"]):
                result[i]["origin"][axis] = result[i]["origin"][axis] - Interval(0, drop.high) * Interval.exact(up)
    return result


def tail_constraint_domains(case: dict, globals_: list[dict]) -> dict[int, tuple[Interval, Interval, list[Interval]]]:
    """Exact upright source-math consequence of the actual final tail-ground modifier.

    A segment ending at y<c is swung up, with dy clamped at its unchanged length.
    Thus y_next >= min(c, y_base + length), even if the base itself is below c.
    This is NOT a numerical certificate for the modifier's native float execution.
    """
    if not case.get("tail_clearances"):
        return {}
    require(len(case["tail_clearances"]) == 9 and case.get("tail_floor") == 0., "TAIL_CONSTRAINT_SOURCE")
    require(case["skeleton_to_actor"] == [1.,0.,0.,0.,1.,0.,0.,0.,1.,0.,0.,0.], "TAIL_CONSTRAINT_AXES")
    modifiers = case["modifiers"]
    ground = [i for i, (_,script,active,influence) in enumerate(modifiers)
              if script == "res://scripts/presentation/tail_ground_constraint.gd" and active == 1 and influence == 1.]
    native=case.get("presentation",{})
    require(len(ground)==1 and all(script == "res://scripts/presentation/tail_flat_roll.gd" or
                (kind == "PhysicalBoneSimulator3D" and script == "" and native.get("physical_bones")==0
                 and native.get("physical_simulating") is False)
                for kind,script,_,_ in modifiers[ground[0]+1:]), "TAIL_CONSTRAINT_ORDER")
    names = {b["name"]:i for i,b in enumerate(case["bones"])}
    require(all("tail_%02d"%i in names for i in range(8)), "TAIL_CONSTRAINT_CHAIN")
    indices = [names["tail_%02d"%i] for i in range(8)]
    require(all(case["bones"][indices[i]]["parent"] == indices[i-1] for i in range(1,8)), "TAIL_CONSTRAINT_CHAIN")
    require(all(globals_[i]["scale_bound"] == FIXED for i in indices), "TAIL_CONSTRAINT_SCALE")
    require(not any(t["bone"] in indices and t["type"] == 1 for clip in case["clips"] for t in clip["tracks"]),
            "TAIL_TRANSLATION_TRACK_UNSUPPORTED")
    lower = globals_[indices[0]]["origin"][1].low
    result = {}
    for at, index in enumerate(indices):
        offset = vector(case["bones"][indices[at+1]]["position"] if at<7 else case["tail_tip"])
        length = norm(offset)
        require(length.low>0, "TAIL_CONSTRAINT_ZERO_SEGMENT")
        following = min(Interval.exact(case["tail_clearances"][at+1]).low, lower+length.low)
        result[index] = (Interval(lower,lower),Interval(following,following),offset)
        lower = following
    return result


def tail_influence_lower(point: list[Interval], start: Interval, end: Interval,
                         offset: list[Interval]) -> int:
    """Any chosen 0<=t<=1 proves p=t*d+r; rigid rotation cannot lower r by more than its norm.

    The floating projection proposes a tight t only. Exact intervals then prove
    the decomposition at that dyadic t; its approximate choice is never evidence.
    """
    p=[float(Fraction(v.low+v.high,2*FIXED)) for v in point]
    d=[float(Fraction(v.low+v.high,2*FIXED)) for v in offset]
    projection=sum(a*b for a,b in zip(p,d))/sum(v*v for v in d)
    require(math.isfinite(projection), "TAIL_PROJECTION_NONFINITE")
    t=Interval.exact(Fraction(max(0,min(4096,round(projection*4096))),4096))
    radial=norm([v-t*axis for v,axis in zip(point,offset)])
    return ((ONE-t)*start+t*end).low-radial.high


def include(bounds: list[Interval] | None, point: list[Interval]) -> list[Interval]:
    return point if bounds is None else [a.hull(b) for a, b in zip(bounds, point)]


def body_bounds(case: dict, globals_: list[dict]) -> list[Interval]:
    """Use each actual positive influence; no all-skeleton body sphere is substituted."""
    bounds = None
    for part in case["body"]:
        outer_basis, outer_origin = affine(part["transform"])
        bind_affines = [affine(raw) for _, raw in part["binds"]]
        for surface in part["surfaces"]:
            for point, influences in surface:
                p = vector(point)
                if not influences:
                    bounds = include(bounds, transform_point(outer_basis, outer_origin, p))
                    continue
                posed = [ZERO, ZERO, ZERO]
                for bind, weight in influences:
                    if weight == 0:
                        continue
                    bone = globals_[part["binds"][bind][0]]
                    local = transform_point(*bind_affines[bind], p)
                    moved = transform_point(bone["basis"], bone["origin"], local)
                    posed = [a + b * Interval.exact(weight) for a, b in zip(posed, moved)]
                bounds = include(bounds, transform_point(outer_basis, outer_origin, posed))
    require(bounds is not None, "BODY_GEOMETRY_MISSING")
    return bounds


def all_yaw(bounds: list[Interval]) -> list[Interval]:
    radius = (bounds[0].square() + bounds[2].square()).sqrt().high
    return [Interval(-radius, radius), bounds[1], Interval(-radius, radius)]


def units(bounds: list[Interval]) -> list[int]:
    rounded = [value.units() for value in bounds]
    output = [value[0] for value in rounded] + [value[1] for value in rounded]
    require(all(-(1 << 31) <= value < (1 << 31) for value in output), "PROFILE_COORDINATE_OVERFLOW")
    return output



def window_keys(track: dict, window: tuple[float, float], clip: dict) -> list[list[float]]:
    """Every intersected full source segment, including loop wrap; this is not temporal sampling."""
    low, high = window
    require(0 <= low <= high <= clip["length"], "WINDOW_RANGE")
    keys = track["keys"]
    chosen = {i for i, key in enumerate(keys) if low <= key[0] <= high}
    before = [i for i, key in enumerate(keys) if key[0] <= low]
    after = [i for i, key in enumerate(keys) if key[0] >= high]
    chosen.add(before[-1] if before else 0)
    chosen.add(after[0] if after else len(keys)-1)
    if clip["loop"] and track["wrap"] and (low <= keys[0][0] or high >= keys[-1][0]):
        chosen.update((0, len(keys)-1))
    return [keys[i] for i in sorted(chosen)]


class FastSkin:
    """Outward Q24 int64 vectorization of the SAME positive-weight skin equation.

    NumPy only accelerates exact integer operations. Every product and accumulated
    reduction is bounded before it executes; unsupported magnitudes refuse.
    One case's finite mesh owns the scratch; this is offline, never runtime state.
    """
    SCALE = 1 << 24
    LIMIT = (1 << 62)-1

    def __init__(self, case: dict):
        try:
            import numpy as np
        except ImportError as error:
            raise Refused("NUMPY_REQUIRED_FOR_BOUNDED_EXPORT") from error
        self.np, self.case = np, case
        self.parts = []
        self._tail_projection = {}
        for part in case["body"]:
            vertices = [v for surface in part["surfaces"] for v in surface]
            require(bool(vertices) and len(vertices) <= MAX_VERTICES, "FAST_VERTEX_CAPACITY")
            points = self.exact([v[0] for v in vertices])
            outer_basis, outer_origin = affine(part["transform"])
            if not part["binds"]:
                self.parts.append((None, points, None, outer_basis, outer_origin))
                continue
            stride = len(vertices[0][1])
            require(stride in (4, 8) and all(len(v[1]) == stride for v in vertices), "FAST_INFLUENCE_SHAPE")
            bind_ids = np.asarray([[b for b, _ in v[1]] for v in vertices], dtype=np.int64)
            weights = self.exact([[w for _, w in v[1]] for v in vertices])
            raw = [affine(matrix) for _, matrix in part["binds"]]
            bases = self.intervals([basis for basis, _ in raw])
            origins = self.intervals([origin for _, origin in raw])
            local = self.affine((bases[0][bind_ids], bases[1][bind_ids]),
                                (origins[0][bind_ids], origins[1][bind_ids]),
                                (points[0][:, None, :], points[1][:, None, :]))
            indices = np.asarray([i for i, _ in part["binds"]], dtype=np.int64)[bind_ids]
            self.parts.append((indices, local, weights, outer_basis, outer_origin))

    def exact(self, value):
        # Scaling finite binary64 by a power of two is exact here; refuse before narrowing.
        array = self.np.asarray(value, dtype=self.np.float64)
        require(self.np.all(self.np.isfinite(array)) and float(self.np.max(self.np.abs(array))) <= 1024,
                "FAST_SOURCE_MAGNITUDE")
        return (self.np.floor(array*self.SCALE).astype(self.np.int64),
                self.np.ceil(array*self.SCALE).astype(self.np.int64))

    def intervals(self, values):
        array = self.np.asarray(values, dtype=object)
        lo = self.np.asarray([v.low * self.SCALE // FIXED for v in array.flat], dtype=object)
        hi = self.np.asarray([-(-v.high * self.SCALE // FIXED) for v in array.flat], dtype=object)
        require(max(max(abs(int(v)) for v in lo), max(abs(int(v)) for v in hi)) <= self.LIMIT,
                "FAST_INTERVAL_CAPACITY")
        return lo.astype(self.np.int64).reshape(array.shape), hi.astype(self.np.int64).reshape(array.shape)

    def magnitude(self, pair):
        return max(abs(int(self.np.min(pair[0]))), abs(int(self.np.max(pair[1]))))

    def multiply(self, a, b):
        require(self.magnitude(a)*self.magnitude(b) <= self.LIMIT, "FAST_PRODUCT_CAPACITY")
        first = a[0]*b[0]
        low, high = first, first
        for x, y in ((a[0], b[1]), (a[1], b[0]), (a[1], b[1])):
            product = x*y
            low, high = self.np.minimum(low, product), self.np.maximum(high, product)
        return low // self.SCALE, -((-high)//self.SCALE)

    def add(self, a, b):
        require(self.magnitude(a)+self.magnitude(b) <= self.LIMIT, "FAST_SUM_CAPACITY")
        return a[0]+b[0], a[1]+b[1]

    def affine(self, basis, origin, point):
        rows = []
        for axis in range(3):
            value = (origin[0][..., axis], origin[1][..., axis])
            for column in range(3):
                term = self.multiply((basis[0][..., axis, column], basis[1][..., axis, column]),
                                     (point[0][..., column], point[1][..., column]))
                value = self.add(value, term)
            rows.append(value)
        return self.np.stack([v[0] for v in rows], axis=-1), self.np.stack([v[1] for v in rows], axis=-1)

    def bounds(self, globals_: list[dict], tail_ground: bool = False) -> list[Interval]:
        bases = self.intervals([bone["basis"] for bone in globals_])
        origins = self.intervals([bone["origin"] for bone in globals_])
        bounds = None
        tail = tail_constraint_domains(self.case,globals_) if tail_ground else {}
        for part_id,(indices, points, weights, outer_basis, outer_origin) in enumerate(self.parts):
            moved = points
            if indices is not None:
                moved = self.affine((bases[0][indices], bases[1][indices]),
                                    (origins[0][indices], origins[1][indices]), points)
                for bone,(start,end,offset) in tail.items():
                    at=self.np.where(indices==bone)
                    for vertex,influence in zip(*at):
                        key=(part_id,int(vertex),int(influence),start.low,end.low)
                        if key not in self._tail_projection:
                            point=[Interval(int(points[0][vertex,influence,a])*(FIXED//self.SCALE),
                                            int(points[1][vertex,influence,a])*(FIXED//self.SCALE)) for a in range(3)]
                            self._tail_projection[key]=tail_influence_lower(point,start,end,offset)*self.SCALE//FIXED
                        moved[0][vertex,influence,1]=max(moved[0][vertex,influence,1],self._tail_projection[key])
                        require(moved[0][vertex,influence,1] <= moved[1][vertex,influence,1], "TAIL_PROOF_INTERSECTION")
                moved = self.multiply(moved, (weights[0][..., None], weights[1][..., None]))
                require(self.magnitude(moved)*indices.shape[1] <= self.LIMIT, "FAST_REDUCTION_CAPACITY")
                moved = moved[0].sum(axis=1), moved[1].sum(axis=1)
            moved = self.affine(self.intervals(outer_basis), self.intervals(outer_origin), moved)
            part_bounds = [Interval(int(moved[0][:, i].min())*(FIXED//self.SCALE),
                                    int(moved[1][:, i].max())*(FIXED//self.SCALE)) for i in range(3)]
            bounds = include(bounds, part_bounds)
        require(bounds is not None, "BODY_GEOMETRY_MISSING")
        return bounds


def clip_envelope(case: dict, name: str, steps: int = 64) -> list[Interval]:
    """Union continuous source-segment enclosures over bounded time partitions, not sampled poses."""
    require(integer(steps, 1, 512), "PARTITION_CAPACITY")
    actual = {clip["name"]: clip for clip in case["clips"]}
    require("cast/"+name in actual, "REQUIRED_STATE_MISSING")
    clip = actual["cast/"+name]
    evaluator = FastSkin(case)
    bounds = None
    for part in range(steps):
        low = clip["length"]*part/steps
        high = clip["length"]*(part+1)/steps
        domains = global_domains(case, [name], "upright", {"cast/"+name: (low, high)})
        bounds = include(bounds, evaluator.bounds(domains))
    return bounds

def build_report(path: Path, sha256: str) -> dict:
    rows = []
    with path.open("rb") as stream:
        source = NativeSource(stream, sha256)
        for case in source.cases():
            clips = list(TRANSIT)
            if any(item["key"] == "mole_pick" for item in case["items"]):
                clips.append("heavy_hammer_swing")
            globals_ = global_domains(case, clips, "upright", mixer=True)
            bounds = FastSkin(case).bounds(globals_)
            rows.append({"id": case["id"], "cast": case["cast"], "species": case["species"],
                         "posture": "upright", "clips": clips, "body_fixed_xyz_u": units(bounds),
                         "body_all_yaw_xyz_u": units(all_yaw(bounds)),
                         "status": "CONTINUOUS_SOURCE_MATH_ONLY", "qualified": False,
                         "remaining": ["NATIVE_NUMERICAL_RESIDUAL", "ATTACHMENT_ENCLOSURE", "ACTUAL_OWNER_KEY_AND_STANCE"]})
            print(case["id"], rows[-1]["body_all_yaw_xyz_u"], flush=True)
        metadata = source.metadata
    return {"schema": 1, "source_sha256": sha256, "native_source_metadata": metadata, "profiles": rows,
            "method": "outward dyadic source intervals; rest-relative product blending via proven S3 logarithmic-radius bound; full skin influences; unrestricted tail rotations",
            "qualified_profile_count": 0}


class PaletteSource(NativeSource):
    """Bounded streaming input for the specified finite matrix renderer, not sampled live animation."""

    def __init__(self, stream: BinaryIO, expected_sha256: str):
        require(len(expected_sha256) == 64 and all(c in "0123456789abcdef" for c in expected_sha256), "SOURCE_HASH_FORMAT")
        self.stream, self.expected = stream, expected_sha256
        self.hash = hashlib.sha256()
        self.offset = self.frames = 0
        require(self.read(8) == b"UGPAL001", "PALETTE_SCHEMA")
        self.schema = self.u32()
        require(self.schema in (1, 2), "PALETTE_SCHEMA")
        self.metadata = self.record()
        if self.schema == 2:
            require(type(self.metadata.get("grounding_schema")) is int and self.metadata["grounding_schema"] == 1, "PALETTE_GROUNDING_SCHEMA")
        require(isinstance(self.metadata.get("cases"), list), "PALETTE_METADATA")
        self.count = self.counted(MAX_CASES)
        require(self.count == len(self.metadata["cases"]), "PALETTE_CASE_CENSUS")

    def read(self, count: int) -> bytes:
        require(integer(count, 0, 128 * 1024 * 1024 - self.offset), "PALETTE_BYTE_CAPACITY")
        data = self.stream.read(count)
        require(len(data) == count, "PALETTE_TRUNCATED")
        self.hash.update(data)
        self.offset += count
        return data

    def record(self) -> dict:
        try:
            value = json.loads(self.text())
        except (ValueError, UnicodeError) as error:
            raise Refused("PALETTE_METADATA") from error
        require(type(value) is dict, "PALETTE_METADATA")
        return value

    def cases(self) -> Iterator[dict]:
        seen = set()
        for expected in self.metadata["cases"]:
            require(self.u32() == 0x43415345, "PALETTE_CASE_MARKER")
            case = self.record()
            for key in ("id", "cast", "species", "life_stage", "clip", "scenario"):
                require(type(case.get(key)) is str and case[key] == expected.get(key), "PALETTE_STATE_IDENTITY")
            require(case["id"] not in seen, "PALETTE_DUPLICATE_CASE")
            seen.add(case["id"])
            require(integer(case.get("parts"), 1, 16) and integer(case.get("body_parts"), 1, case["parts"]), "PALETTE_PART_CAPACITY")
            require(integer(case.get("frames"), 1, 8192) and case.get("sample_hz") == 30, "PALETTE_FRAME_CAPACITY")
            length = case.get("source_duration_s")
            require(type(length) in (int, float) and math.isfinite(length) and 0 < length <= 40, "PALETTE_DURATION")
            require(case["frames"] == math.ceil(length * 30) + 1, "PALETTE_FRAME_CENSUS")
            require(case.get("attachments") == expected.get("attachments"), "PALETTE_ATTACHMENT_CENSUS")
            binding = case.get("held_tool_binding", "demo_clip_specific")
            require(binding == expected.get("held_tool_binding", "demo_clip_specific") and
                    binding in ("demo_clip_specific", "set_work_tool"), "PALETTE_HELD_TOOL_BINDING")
            if binding == "set_work_tool":
                require(case["attachments"] == ["mole_pick"] and case["clip"] in
                        ("idle", "walk", "cautious_crouch_walk_forward"), "PALETTE_HELD_TOOL_BINDING")
            case["geometry"] = [self.part() for _ in range(case["parts"])]
            require(sum(len(s["points"]) for p in case["geometry"] for s in p["geometry"]) <= MAX_VERTICES, "PALETTE_VERTEX_CAPACITY")
            require(all(p["kind"] == "body" for p in case["geometry"][:case["body_parts"]]), "PALETTE_BODY_CENSUS")
            items = case["geometry"][case["body_parts"]:]
            require(all(p["kind"] == "attachment" for p in items) and [p["name"] for p in items] == case["attachments"], "PALETTE_ATTACHMENT_CENSUS")
            stride = sum(max(1, part["binds"]) * 12 for part in case["geometry"])
            require((stride + int(self.schema == 2)) * case["frames"] <= 4194304, "PALETTE_SCALAR_CAPACITY")
            case["matrices"], case["grounding"] = self.matrix_frames(case["frames"], stride)
            yield case
        require(self.u32() == 0x444f4e45 and self.u32() == self.count and self.u32() == self.frames, "PALETTE_COMPLETION")
        require(self.stream.read(1) == b"", "PALETTE_TRAILING_BYTES")
        require(self.hash.hexdigest() == self.expected, "SOURCE_HASH_MISMATCH")

    def part(self) -> dict:
        part = self.record()
        require(part.get("kind") in ("body", "attachment") and type(part.get("name")) is str, "PALETTE_PART_IDENTITY")
        require(integer(part.get("binds"), 0, 64) and integer(part.get("surfaces"), 1, 16), "PALETTE_PART_CAPACITY")
        require(part["kind"] == "body" or part["binds"] == 0, "PALETTE_ATTACHMENT_SKIN")
        formats = part.get("surface_formats")
        require(type(formats) is list and len(formats) == part["surfaces"] and all(integer(v, 0, (1 << 63)-1) for v in formats), "PALETTE_FORMAT_CENSUS")
        part["geometry"] = [self.surface(part["binds"]) for _ in range(part["surfaces"])]
        for surface, format_value in zip(part["geometry"], formats):
            require(not format_value & ((1 << 25) | (1 << 28)), "PALETTE_UNSUPPORTED_VERTEX_FORMAT")
            if part["binds"]:
                require(not format_value & (1 << 29), "PALETTE_COMPRESSED_SKIN_UNREVIEWED")
                require(format_value & (3 << 10) == 3 << 10, "PALETTE_SKIN_FORMAT")
                require(surface["weights"].shape[1] == (8 if format_value & (1 << 27) else 4), "PALETTE_SKIN_FORMAT")
        return part

    def surface(self, binds: int) -> dict:
        import numpy as np
        count, stride = self.counted(MAX_VERTICES), self.u32()
        require(stride in ((4, 8) if binds else (0,)), "PALETTE_INFLUENCE_SHAPE")
        raw = self.read(count * (12 + stride * 8))
        values = np.frombuffer(raw, dtype="<f4").reshape(count, 3 + stride * 2)
        points = values[:, :3]
        require(np.isfinite(points).all() and np.max(np.abs(points)) <= 1024, "PALETTE_VERTEX")
        ids = np.frombuffer(raw, dtype="<u4").reshape(values.shape)[:, 3::2]
        weights = values[:, 4::2]
        if binds:
            require(np.isfinite(weights).all() and np.min(weights) >= 0 and np.max(weights) <= 1 and
                    np.all(np.sum(weights, axis=1, dtype=np.float64) > 0) and np.max(ids) < binds, "PALETTE_INFLUENCE")
        return {"points": points, "ids": ids, "weights": weights}

    def matrix_frames(self, count: int, stride: int):
        import numpy as np
        raw, roots = bytearray(), bytearray()
        for frame in range(count):
            require(self.u32() == 0x4652414d and self.u32() == frame, "PALETTE_FRAME_ORDER")
            if self.schema == 2:
                root = self.read(4)
                value = struct.unpack("<f", root)[0]
                require(math.isfinite(value) and abs(value) <= 1024, "PALETTE_GROUNDING")
                roots.extend(root)
            data = self.read(stride * 4)
            values = np.frombuffer(data, dtype="<f4")
            require(np.isfinite(values).all() and np.max(np.abs(values)) <= 1024, "PALETTE_MATRIX")
            raw.extend(data)
        require(self.u32() == 0x454e4443 and self.u32() == count, "PALETTE_CASE_COMPLETION")
        self.frames += count
        return np.frombuffer(raw, dtype="<f4").reshape(count, stride // 12, 12), (np.frombuffer(roots, dtype="<f4") if self.schema == 2 else None)


def gamma32(operations: int) -> Fraction:
    """Binary32 bound including directed rounding; GLSL4.10 does not mandate round-to-nearest."""
    require(integer(operations, 0, 1024), "RESIDUAL_OPERATION_CAPACITY")
    return Fraction(operations, (1 << 23) - operations)


def palette_residual(part: dict, matrices, grounding=None) -> Fraction:
    """Bound fixed-weight CPU interpolation, UNORM16 decode and native affine skin arithmetic.

    This local-coordinate guarantee assumes the checked original PBR/no-displacement
    path, highp binary32 shader arithmetic and the pinned Godot skin equations. It
    does not certify a different shader, unbound root transform or policy permission.
    """
    import numpy as np
    m = Fraction(float(np.max(np.abs(matrices))))
    tiny = Fraction(1, 1 << 126)  # Also covers flushed subnormal results.
    # Twelve binary64 operations cover both time blends and the transition; then
    # one float32 scratch store. Fixed weights/complements are exact dyadic values.
    cpu_error = m * Fraction(12, (1 << 52) - 12)
    coefficient_error = cpu_error + (m + cpu_error) / (1 << 23) + tiny
    largest = Fraction(0)
    for surface, format_value in zip(part["geometry"], part["surface_formats"]):
        points = surface["points"]
        # Float32 values converted to Q24 with outward integer rounding before reduction.
        l1 = Fraction(int(np.ceil(np.abs(points.astype(np.float64)) * (1 << 24)).sum(axis=1).max()), 1 << 24)
        decode_error = Fraction(0)
        if format_value & (1 << 29):  # Godot ARRAY_FLAG_COMPRESS_ATTRIBUTES; exact pinned format bit.
            bounds = part.get("mesh_aabb")
            require(type(bounds) is list and len(bounds) == 6 and all(type(v) in (int, float) and math.isfinite(v) for v in bounds),
                    "PALETTE_COMPRESSED_BOUND_MISSING")
            require(all(v >= 0 for v in bounds[3:]) and max(abs(v) for v in bounds) <= 1024, "PALETTE_COMPRESSED_BOUND_CAPACITY")
            # CPU and GPU each decode the same UNORM16 value, multiply by the
            # exact source size and add the exact source origin. Four rounded
            # operations per side cover conversion and both affine operations.
            decode_magnitude = max(Fraction(abs(v)) for v in bounds[:3]) + max(Fraction(v) for v in bounds[3:]) + 1
            decode_error = 2 * gamma32(4) * decode_magnitude + 8 * tiny
        if part["binds"]:
            weights = surface["weights"]
            total = Fraction(int(np.ceil(weights.astype(np.float64) * (1 << 24)).sum(axis=1).max()), 1 << 24)
            count = weights.shape[1]
            weight_error = Fraction(count, 1 << 22)
            matrix_error = weight_error*m + (total+weight_error)*coefficient_error + gamma32(32)*(total+weight_error)*(m+coefficient_error) + 32*tiny
            matrix_bound = total*m
        else:
            matrix_error, matrix_bound = coefficient_error, m
        residual = matrix_error*(l1+1) + (matrix_bound+matrix_error)*3*decode_error
        residual += gamma32(16)*(matrix_bound+matrix_error)*(l1+1+3*decode_error) + 16*tiny
        if grounding is not None:
            require(len(grounding) == len(matrices) and np.isfinite(grounding).all() and np.max(np.abs(grounding)) <= 1024,
                    "PALETTE_GROUNDING")
            root = Fraction(float(np.max(np.abs(grounding))))
            root_cpu = root * Fraction(12, (1 << 52) - 12)
            root_error = root_cpu + (root + root_cpu) / (1 << 23) + tiny
            # The same post-skin translation reaches body and held items. Cover
            # both the static part's extra CPU origin sum/store and the skinned
            # part's native identity-basis model transform, never weight it twice.
            residual += root_error + gamma32(32) * (matrix_bound*(l1+1) + root + root_error + residual) + 32*tiny
        largest = max(largest, residual)
    return largest


def palette_part_envelope(part: dict, matrices, grounding=None) -> tuple[list[Interval], Fraction]:
    """Exact outward endpoint hull encloses every positive affine temporal/transition blend of those frames."""
    import numpy as np
    math_ = FastSkin.__new__(FastSkin)
    math_.np = np
    bounds = None
    prepared = [(math_.exact(surface["points"]), surface["ids"], math_.exact(surface["weights"]) if part["binds"] else None)
                for surface in part["geometry"]]
    if grounding is not None:
        require(len(grounding) == len(matrices) and np.isfinite(grounding).all() and np.max(np.abs(grounding)) <= 1024, "PALETTE_GROUNDING")
    for frame_id, frame in enumerate(matrices):
        base = frame[:, :9].reshape(-1, 3, 3).transpose(0, 2, 1)
        bases, origins = math_.exact(base), math_.exact(frame[:, 9:])
        for points, ids, weights in prepared:
            if part["binds"]:
                moved = math_.affine((bases[0][ids], bases[1][ids]), (origins[0][ids], origins[1][ids]),
                                     (points[0][:, None, :], points[1][:, None, :]))
                moved = math_.multiply(moved, (weights[0][..., None], weights[1][..., None]))
                require(math_.magnitude(moved) * ids.shape[1] <= math_.LIMIT, "FAST_REDUCTION_CAPACITY")
                moved = moved[0].sum(axis=1), moved[1].sum(axis=1)
            else:
                moved = math_.affine((bases[0][0], bases[1][0]), (origins[0][0], origins[1][0]), points)
            current = [Interval(int(moved[0][:, a].min())*(FIXED//math_.SCALE), int(moved[1][:, a].max())*(FIXED//math_.SCALE)) for a in range(3)]
            if grounding is not None:
                current[1] = current[1] + Interval.exact(float(grounding[frame_id]))
            bounds = include(bounds, current)
    require(bounds is not None, "PALETTE_EMPTY_GEOMETRY")
    residual = palette_residual(part, matrices, grounding)
    pad = Interval.exact(residual).high
    return [Interval(v.low-pad, v.high+pad) for v in bounds], residual


class WorldBasisSource:
    """Complete native heading source. The exact maximum norm includes every binary32 row."""

    def __init__(self, stream: BinaryIO, expected_sha256: str, producer_sha256: str):
        for digest in (expected_sha256, producer_sha256):
            require(type(digest) is str and len(digest) == 64 and all(c in "0123456789abcdef" for c in digest),
                    "WORLD_BASIS_SOURCE_HASH")
        self.stream, self.hash = stream, hashlib.sha256()
        header = self.read(20)
        require(header[:8] == b"UGYAW001", "WORLD_BASIS_SCHEMA")
        version, count, metadata_bytes = struct.unpack("<III", header[8:])
        require(version == 1 and count == 65536 and 1 <= metadata_bytes <= 1024, "WORLD_BASIS_CAPACITY")
        try:
            self.metadata = json.loads(self.read(metadata_bytes))
        except (ValueError, UnicodeError) as error:
            raise Refused("WORLD_BASIS_METADATA") from error
        require(type(self.metadata) is dict and type(self.metadata.get("source")) is dict and
                self.metadata["source"].get("sha256") == producer_sha256, "WORLD_BASIS_PRODUCER")
        self.backend = palette_backend_certificate(self.metadata)
        self.norm_squared = Fraction(0)
        self.max_component = Fraction(0)
        self.max_norm_yaw = 0
        for yaw in range(count):
            c, s = struct.unpack("<ff", self.read(8))
            require(math.isfinite(c) and math.isfinite(s) and abs(c) <= 1 and abs(s) <= 1, "WORLD_BASIS_COEFFICIENT")
            c, s = Fraction(c), Fraction(s)
            norm = c*c + s*s
            if norm > self.norm_squared:
                self.norm_squared, self.max_norm_yaw = norm, yaw
            self.max_component = max(self.max_component, abs(c), abs(s))
        require(self.read(8) == b"UGYEND01" and self.stream.read(1) == b"", "WORLD_BASIS_FOOTER")
        require(self.hash.hexdigest() == expected_sha256, "WORLD_BASIS_DIGEST")
        require(self.norm_squared > 0, "WORLD_BASIS_DEGENERATE")
        self.digest, self.producer_digest = expected_sha256, producer_sha256

    def read(self, count: int) -> bytes:
        data = self.stream.read(count)
        require(len(data) == count, "WORLD_BASIS_TRUNCATED")
        self.hash.update(data)
        return data

    def certificate(self) -> dict:
        return {"sha256": self.digest, "producer_sha256": self.producer_digest,
                "heading_count": 65536, "exact_norm_squared": fraction_record(self.norm_squared),
                "max_norm_yaw": self.max_norm_yaw, "max_component": fraction_record(self.max_component),
                "metadata": self.metadata, "backend_certificate": self.backend}


def fraction_record(value: Fraction) -> dict:
    return {"numerator": value.numerator, "denominator": value.denominator}


def world_root_bounds(values: object) -> tuple[Fraction, Fraction, Fraction]:
    """The caller binds the full actual Domain identity; this math admits only exact binary32 roots."""
    require(type(values) is list and len(values) == 6 and all(integer(v, -(1 << 24), 1 << 24) for v in values),
            "WORLD_ROOT_PRECISION")
    require(all(values[a] < values[a+3] for a in range(3)), "WORLD_ROOT_BOUNDS")
    return tuple(Fraction(max(abs(values[a]), abs(values[a+3])), 1024) for a in range(3))


def native_all_yaw(bounds: list[Interval], norm_squared: Fraction) -> list[Interval]:
    """Cauchy-Schwarz over the entire finite table, including native coefficient norm overshoot."""
    require(Fraction(0) < norm_squared <= 2, "WORLD_BASIS_NORM")
    radius = ((bounds[0].square() + bounds[2].square()) * Interval.exact(norm_squared)).sqrt().high
    return [Interval(-radius, radius), bounds[1], Interval(-radius, radius)]


def _blend_coefficient_error(magnitude: Fraction) -> Fraction:
    cpu = magnitude * Fraction(12, (1 << 52)-12)
    return cpu + (magnitude+cpu) / (1 << 23) + Fraction(1, 1 << 126)


def _world_store_error(magnitude: Fraction) -> Fraction:
    """Eight double operations dominate either explicit Actor expression; one directed-or-nearest F32 store."""
    cpu = magnitude * Fraction(8, (1 << 52)-8)
    return cpu + gamma32(1)*(magnitude+cpu) + Fraction(1, 1 << 126)


def _surface_input_bound(part: dict, surface: dict, format_value: int) -> Fraction:
    """Conservative actual decoded vertex L1, retaining the original compressed-attribute decode difference."""
    import numpy as np
    points = surface["points"]
    l1 = Fraction(int(np.ceil(np.abs(points.astype(np.float64))*(1 << 24)).sum(axis=1).max()), 1 << 24)
    if format_value & (1 << 29):
        bounds = part.get("mesh_aabb")
        require(type(bounds) is list and len(bounds) == 6 and
                all(type(v) in (int, float) and math.isfinite(v) and abs(v) <= 1024 for v in bounds) and
                all(v >= 0 for v in bounds[3:]), "PALETTE_COMPRESSED_BOUND_MISSING")
        decode_magnitude = max(Fraction(abs(v)) for v in bounds[:3]) + max(Fraction(v) for v in bounds[3:]) + 1
        l1 += 3 * (2*gamma32(4)*decode_magnitude + 8*Fraction(1, 1 << 126))
    return l1


def world_residual(part: dict, matrices, grounding, local_bounds: list[Interval], roots: list[int]) -> tuple[Fraction, ...]:
    """Additional error of the explicit top-level world model, before view/projection/rasterization.

    Local bounds already include skin/decode/blend error. Static parts additionally
    compose the stored local matrix with finite yaw in binary64 then binary32.
    The body model has an exact table basis; only its common origin is newly stored.
    All coordinates retain full source geometry. No camera transform is a physical
    animation or contact input, and no screen-space numerical claim is made here.
    """
    import numpy as np
    root = world_root_bounds(roots)
    require(grounding is not None and len(grounding) == len(matrices), "WORLD_GROUNDING_REQUIRED")
    require(np.isfinite(grounding).all() and np.max(np.abs(grounding)) <= 1024, "PALETTE_GROUNDING")
    g = Fraction(float(np.max(np.abs(grounding))))
    g += _blend_coefficient_error(g)
    tiny = Fraction(1, 1 << 126)
    residual = [Fraction(0)]*3
    if part["binds"]:
        # Skin output omits the common Y. Subtracting grounding can enlarge its
        # absolute value by at most g; local bounds contain the actual skin error.
        local = [Fraction(max(abs(v.low), abs(v.high)), FIXED) for v in local_bounds]
        local[1] += g
        for a in range(3):
            origin_error = _world_store_error(root[a] + g)
            dot_bound = local[0]+local[2] if a != 1 else local[1]
            residual[a] = origin_error + gamma32(16)*(dot_bound+root[a]+g+origin_error) + 16*tiny
        return tuple(residual)
    m = Fraction(float(np.max(np.abs(matrices))))
    m += _blend_coefficient_error(m)
    coefficient_error = _world_store_error(2*m)
    for surface, format_value in zip(part["geometry"], part["surface_formats"]):
        l1 = _surface_input_bound(part, surface, format_value)
        for a in range(3):
            origin_bound = 2*m+g+root[a]
            origin_error = _world_store_error(origin_bound)
            error = coefficient_error*l1 + origin_error
            error += gamma32(16)*((2*m+coefficient_error)*l1+origin_bound+origin_error) + 16*tiny
            residual[a] = max(residual[a], error)
    return tuple(residual)


def world_part_envelope(part: dict, matrices, grounding, basis: WorldBasisSource,
                        root_bounds_u: list[int]) -> tuple[list[Interval], list[dict]]:
    """One bound covers every source blend, every native table heading and every admitted integer root."""
    local, _ = palette_part_envelope(part, matrices, grounding)
    return world_from_local(part, matrices, grounding, local, basis, root_bounds_u)


def world_from_local(part: dict, matrices, grounding, local: list[Interval], basis: WorldBasisSource,
                     root_bounds_u: list[int]) -> tuple[list[Interval], list[dict]]:
    """Reuse one already computed local enclosure without another complete source-vertex pass."""
    additional = world_residual(part, matrices, grounding, local, root_bounds_u)
    bounds = native_all_yaw(local, basis.norm_squared)
    result = [Interval(v.low-Interval.exact(r).high, v.high+Interval.exact(r).high) for v, r in zip(bounds, additional)]
    return result, [fraction_record(r) for r in additional]


def verify_world_basis_binding(metadata: dict, basis: WorldBasisSource, root_bounds_u: list[int]) -> None:
    """Same exact source backend and reviewed actual producer are mandatory before writing a world report."""
    world_root_bounds(root_bounds_u)
    for key in ("rendering_driver", "rendering_method", "display_server", "api_version"):
        require(metadata.get(key) == basis.metadata.get(key), "WORLD_BASIS_BACKEND_MISMATCH")
    producer = Path(__file__).resolve().with_name("bake_underground_world_basis.gd")
    require(producer.is_file() and producer.stat().st_size <= MAX_TEXT, "WORLD_BASIS_PRODUCER_MISSING")
    require(hashlib.sha256(producer.read_bytes()).hexdigest() == basis.producer_digest, "WORLD_BASIS_PRODUCER_DRIFT")


def palette_backend_certificate(metadata: dict) -> dict:
    """This numerical proof is for the pinned desktop GL path, not silently for mediump ES/Vulkan."""
    engine = metadata.get("engine", {})
    require(type(engine) is dict and (engine.get("major"), engine.get("minor"), engine.get("patch")) == (4, 7, 2),
            "PALETTE_ENGINE_UNREVIEWED")
    require(engine.get("hash") == GODOT_SOURCE_HASH and engine.get("build") == "official" and engine.get("status") == "stable",
            "PALETTE_ENGINE_SOURCE_UNREVIEWED")
    require(metadata.get("rendering_driver") == "opengl3" and metadata.get("rendering_method") == "gl_compatibility"
            and metadata.get("display_server") in ("macOS", "Windows", "X11", "Wayland"), "PALETTE_BACKEND_UNREVIEWED")
    version = metadata.get("api_version", "")
    require(type(version) is str and version.startswith(("4.1", "4.2", "4.3", "4.4", "4.5", "4.6")),
            "PALETTE_GL_PRECISION_UNREVIEWED")
    return {"engine": engine, "driver": metadata["rendering_driver"], "api_version": version,
            "specification": "https://registry.khronos.org/OpenGL/specs/gl/GLSLangSpec.4.10.pdf",
            "attribute_specification": "https://registry.khronos.org/OpenGL/specs/gl/glspec41.core.pdf#page=28",
            "sections": ["4.5", "4.5.1"], "single_precision_rounding": "directed or nearest; unit bound 2^-23",
            "shader_contract": "Godot4.7.2 original no-displacement desktop OpenGL skin and scene shaders"}


def verify_palette_sources(metadata: dict, project_root: Path | None = None, import_archive: Path | None = None) -> int:
    """Recheck every available raw/import/presentation input; absent assets never preserve a success claim."""
    entries = metadata.get("sources")
    require(type(entries) is list and 1 <= len(entries) <= 2048, "PALETTE_SOURCE_CLOSURE")
    entries = [metadata.get("manifest"), *entries]
    project_root = (project_root or Path(__file__).resolve().parents[1]/"godot").resolve()
    seen = {}
    for entry in entries:
        require(type(entry) is dict and type(entry.get("path")) is str and type(entry.get("sha256")) is str,
                "PALETTE_SOURCE_PIN")
        name, expected = entry["path"], entry["sha256"]
        path = ((project_root/name[6:]) if name.startswith("res://") else Path(name)).resolve()
        require(not name.startswith("res://") or path.is_relative_to(project_root), "PALETTE_RESOURCE_PATH")
        require(len(expected) == 64 and all(c in "0123456789abcdef" for c in expected), "PALETTE_SOURCE_PIN")
        require(str(path) not in seen or seen[str(path)] == expected, "PALETTE_CONFLICTING_PIN")
        if str(path) in seen:
            continue
        # Godot's regenerated imported scenes contain changing resource identities.
        # A preserved byte-identical image may satisfy only an imported-cache pin;
        # original assets, scripts and manifests must still exist and match in place.
        generated_import = name.startswith("res://demo/assets/") and name.endswith(".import")
        if import_archive is not None and (name.startswith("res://.godot/imported/") or generated_import):
            archived = import_archive / (expected + ".input")
            require(archived.is_file(), "PALETTE_IMPORT_ARCHIVE_MISSING")
            candidate = archived
        else:
            candidate = path
        require(candidate.is_file() and candidate.stat().st_size <= 268435456, "PALETTE_SOURCE_MISSING_OR_CAPACITY")
        digest = hashlib.sha256()
        with candidate.open("rb") as source:
            while chunk := source.read(65536):
                digest.update(chunk)
        require(digest.hexdigest() == expected, "PALETTE_SOURCE_DRIFT")
        seen[str(path)] = expected
    return len(seen)


def build_palette_report(path: Path, sha256: str, import_archive: Path | None = None,
                         world_basis: WorldBasisSource | None = None, root_bounds_u: list[int] | None = None) -> dict:
    """A local renderer certificate, with world identity/contact/level qualification explicitly separate."""
    rows = []
    with path.open("rb") as stream:
        source = PaletteSource(stream, sha256)
        backend = palette_backend_certificate(source.metadata)
        pins = verify_palette_sources(source.metadata, import_archive=import_archive)
        if world_basis is not None:
            verify_world_basis_binding(source.metadata, world_basis, root_bounds_u)
        for case in source.cases():
            offset = 0
            parts = []
            for part in case["geometry"]:
                count = max(1, part["binds"])
                bounds, residual = palette_part_envelope(part, case["matrices"][:, offset:offset+count], case["grounding"])
                offset += count
                parts.append({"kind": part["kind"], "name": part["name"], "bounds_u": units(bounds),
                              "all_yaw_bounds_u": units(all_yaw(bounds)),
                              "residual_m": {"numerator": residual.numerator, "denominator": residual.denominator}})
                if world_basis is not None:
                    world_bounds, errors = world_from_local(part, case["matrices"][:, offset-count:offset],
                        case["grounding"], bounds, world_basis, root_bounds_u)
                    parts[-1].update(world_all_headings_bounds_u=units(world_bounds), world_additional_residual_m=errors)
            rows.append({k: case[k] for k in ("id", "cast", "species", "life_stage", "clip", "scenario", "frames")})
            rows[-1].update({"parts": parts, "local_representation_enclosed": True, "production_qualified": False,
                            "held_tool_binding": case.get("held_tool_binding", "demo_clip_specific"),
                            "common_post_skin_grounding": case["grounding"] is not None,
                            "remaining": ["ACTUAL_RENDERER_SOURCE_BINDING", "NATIVE_VISUAL_GATE", "WORLD_ROOT_TRANSFORM", "STANCE_CONTACT_AND_POLICY"]})
            if world_basis is not None:
                rows[-1]["world_model_representation_enclosed"] = True
                rows[-1]["remaining"] = ["EXACT_ACTOR_CONTENT_AND_DOMAIN_BINDING", "NATIVE_ANIMATED_QUALITY",
                    "COMPLETE_REQUIRED_STATE_UNIONS", "STANCE_WORK_CONTACT_AND_POLICY"]
            print(case["id"], parts[0]["bounds_u"], flush=True)
    report = {"schema": 1, "source_sha256": sha256, "profiles": rows, "qualified_profile_count": 0,
            "backend_certificate": backend, "verified_source_files": pins,
            "import_archive": str(import_archive) if import_archive is not None else None,
            "method": "finite final binary32 matrices plus common post-skin Y; outward Q24 endpoint hull; identical convex positive interpolation; explicit IEEE/UNORM/decode residual"}
    if world_basis is not None:
        report.update(world_basis=world_basis.certificate(), world_root_bounds_u=root_bounds_u,
            world_method="complete native table norm; explicit top-level binary64 composition, binary32 stores and pre-view model arithmetic",
            binding_requirement="actual immutable Domain descriptor and complete palette/table digests; full translated body admission remains authoritative owner work",
            excluded="view/projection/rasterization error is not physical deformation; no arbitrary parent, pitch, scale or extra shader")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--palette", action="store_true", help="bound the specified finite native matrix presentation")
    parser.add_argument("--import-archive", type=Path, help="exact content-addressed imported images preserved by the baker")
    parser.add_argument("--world-basis", type=Path, help="complete source-bound finite native heading stream")
    parser.add_argument("--world-basis-sha256")
    parser.add_argument("--world-basis-producer-sha256")
    parser.add_argument("--world-root-bounds", nargs=6, type=int, help="exact finite half-open actual Domain XYZ bounds in 1/1024m units")
    args = parser.parse_args()
    require(not args.out.exists() and args.out.resolve() != args.source.resolve(), "OUTPUT_EXISTS_OR_OVERWRITES_SOURCE")
    require(args.palette or args.import_archive is None, "IMPORT_ARCHIVE_REQUIRES_PALETTE")
    world_args = [args.world_basis, args.world_basis_sha256, args.world_basis_producer_sha256, args.world_root_bounds]
    require(not any(v is not None for v in world_args) or (args.palette and all(v is not None for v in world_args)), "WORLD_ARGUMENTS_INCOMPLETE")
    basis = None
    if args.world_basis is not None:
        require(args.out.resolve() != args.world_basis.resolve(), "OUTPUT_OVERWRITES_WORLD_SOURCE")
        with args.world_basis.open("rb") as stream:
            basis = WorldBasisSource(stream, args.world_basis_sha256, args.world_basis_producer_sha256)
    report = build_palette_report(args.source, args.sha256, args.import_archive, basis, args.world_root_bounds) if args.palette else build_report(args.source, args.sha256)
    with args.out.open("x") as stream:
        json.dump(report, stream, indent=2)
        stream.write("\n")


if __name__ == "__main__":
    main()
