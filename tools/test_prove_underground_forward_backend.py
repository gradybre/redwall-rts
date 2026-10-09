#!/usr/bin/env python3
"""Finite adversarial source/math checks. Synthetic basis bytes never qualify a renderer."""
from fractions import Fraction
import hashlib
import io
import json
import math
from pathlib import Path
import random
import struct
import tempfile
import unittest

import prove_underground_forward_backend as F


def metadata():
    return {"schema": 2, "engine": {"major": 4, "minor": 7, "patch": 2, "hash": F.ENGINE_HASH,
            "build": "official", "status": "stable"}, "source": {"sha256": "1" * 64},
            "coefficient_source_sha256": F.NATIVE_SOURCE_SHA, "rendering_driver": "metal",
            "rendering_method": "forward_plus", "display_server": "macOS", "api_version": "4.0",
            "heading_count": 65536, "orientation": "0=-Z,+quarter=-X; +Y up",
            "coefficient_order": ["basis.x.x", "basis.z.x"], "physical_qualified": False}


def image(meta=None, row=(1.0, 0.0), version=2, count=65536):
    raw = json.dumps(meta if meta is not None else metadata()).encode()
    return b"UGYAW002" + struct.pack("<III", version, count, len(raw)) + raw + struct.pack("<ff", *row) * count + b"UGYEND02"


def read(raw, digest=None):
    return F.BasisSource(io.BytesIO(raw), digest or hashlib.sha256(raw).hexdigest(), "1" * 64)


def f32(value):
    return struct.unpack("<f", struct.pack("<f", float(value)))[0]


def evaluate(terms, order, balanced=False):
    values = []
    for index in order:
        value = 1.0
        for operand in terms[index]:
            value = f32(value * float(operand))
        values.append(value)
    if balanced:
        while len(values) > 1:
            values = [f32(sum(values[i:i + 2])) for i in range(0, len(values), 2)]
        return Fraction(values[0])
    value = 0.0
    for term in values:
        value = f32(value + term)
    return Fraction(value)


class BasisTests(unittest.TestCase):
    def test_stream_complete_census_and_cardinals(self):
        basis = read(image())
        self.assertEqual(basis.norm_max, 1)
        self.assertEqual(basis.norm_min, 1)
        self.assertEqual(len(basis.cardinals), 4)
        self.assertLessEqual(basis.offset, F.MAX_FILE_BYTES)
        self.assertFalse(hasattr(basis, "coefficients"))

    def test_finite_nonunit_values_are_not_normalized(self):
        c = f32(math.sqrt(0.5))
        basis = read(image(row=(c, c)))
        self.assertEqual(basis.norm_max, 2 * Fraction(c) ** 2)
        self.assertNotEqual(basis.norm_max, 1)
        self.assertEqual(basis.certificate()["inverse_norm_squared_max"], F.rational_record(1 / basis.norm_min))

    def test_missing_duplicate_and_unsupported_source_are_refused(self):
        for raw in (image(count=65535), image(version=1), image()[:-9], image() + b"x"):
            with self.assertRaises(F.Refused):
                read(raw)
        with self.assertRaisesRegex(F.Refused, "DIGEST"):
            read(image(), "0" * 64)

    def test_nonfinite_and_degenerate_rows_refuse(self):
        for row in ((float("nan"), 0.0), (float("inf"), 1.0), (0.0, 0.0), (1.0, 1.0), (2.0, 0.0)):
            with self.assertRaises(F.Refused):
                read(image(row=row))

    def test_metadata_capacity_and_producer_are_not_authority_flags(self):
        meta = metadata()
        meta["source"]["sha256"] = "2" * 64
        with self.assertRaisesRegex(F.Refused, "PRODUCER"):
            read(image(meta))
        meta = metadata()
        meta["physical_qualified"] = True
        with self.assertRaisesRegex(F.Refused, "MEANING"):
            read(image(meta))
        meta["padding"] = "x" * 1024
        with self.assertRaisesRegex(F.Refused, "CAPACITY"):
            read(image(meta))

    def test_actual_backend_and_borrowed_source_cannot_be_relabelled(self):
        for key, value in (("rendering_driver", "opengl3"), ("rendering_method", "mobile"),
                           ("display_server", "headless"), ("api_version", "4.1"),
                           ("coefficient_source_sha256", "2" * 64)):
            meta = metadata()
            meta[key] = value
            with self.assertRaises(F.Refused):
                read(image(meta))
        meta = metadata()
        meta["engine"]["major"] = True
        with self.assertRaisesRegex(F.Refused, "ENGINE"):
            read(image(meta))

    def test_shader_manifest_refresh_cannot_authorize_changed_code(self):
        # Negative fixture has the exact census and refreshed local hashes, but
        # source_contract additionally requires independently reviewed pins.
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            rows = []
            for path in F.ENGINE_SOURCES:
                (directory / path.replace("/", "__")).write_bytes(b"modified\n")
                rows.append({"path": path, "url": "https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/" + path,
                             "bytes": 9, "sha256": hashlib.sha256(b"modified\n").hexdigest()})
            (directory / "manifest.json").write_text(json.dumps({"records": rows}))
            with self.assertRaisesRegex(F.Refused, "SOURCE_DRIFT"):
                F.source_contract(directory)


class ArithmeticTests(unittest.TestCase):
    def test_four_and_eight_influence_expansion_preserves_every_weight(self):
        for count in (4, 8):
            rows = [(Fraction(i, 16), Fraction(-i, 8), Fraction(2 * i, 32), Fraction(1, 4)) for i in range(count)]
            weights = [Fraction(1, count)] * count
            point = [Fraction(3, 8), Fraction(4, 16), Fraction(-1, 8)]
            terms = F.skin_component_terms(point, rows, weights)
            expected = sum(w * sum(a * b for a, b in zip(row, (*point, 1))) for w, row in zip(weights, rows))
            actual = sum(math.prod(term) for term in terms)
            self.assertEqual(actual, expected)
            bound = F.polynomial_bound(terms)
            self.assertEqual(bound["operations"], count * 12 - 1)
            self.assertGreater(bound["flushing"], 0)

    def test_cancellation_reassociation_is_covered_by_absolute_terms(self):
        terms = [(Fraction(1 << 20), Fraction(1)), (Fraction(1, 1024), Fraction(1)),
                 (Fraction(-(1 << 20)), Fraction(1)), (Fraction(1, 2048), Fraction(1))]
        exact = sum(math.prod(term) for term in terms)
        a, b = evaluate(terms, range(4)), evaluate(terms, [0, 2, 1, 3])
        self.assertNotEqual(a, b)
        bound = F.polynomial_bound(terms)["error"]
        self.assertLessEqual(abs(a - exact), bound)
        self.assertLessEqual(abs(b - exact), bound)
        # A relative bound against the cancelled answer is demonstrably false.
        self.assertGreater(abs(a - exact), F.gamma(7) * abs(exact))

    def test_random_expanded_and_balanced_native_float32_trees(self):
        rng = random.Random(1132)
        for count in (4, 8):
            for _ in range(50):
                point = [Fraction(f32(rng.uniform(-8, 8))) for _ in range(3)]
                rows = [[Fraction(f32(rng.uniform(-16, 16))) for _ in range(4)] for _ in range(count)]
                weights = [Fraction(f32(rng.random())) for _ in range(count)]
                terms = F.skin_component_terms(point, rows, weights)
                bound = F.polynomial_bound(terms)["error"]
                exact = sum(math.prod(term) for term in terms)
                order = list(range(len(terms)))
                rng.shuffle(order)
                for balanced in (False, True):
                    self.assertLessEqual(abs(evaluate(terms, order, balanced) - exact), bound)

    def test_input_and_output_flushes_are_not_zeroed_out_of_certificate(self):
        terms = [(Fraction(1, 1 << 140), Fraction(1 << 24), Fraction(1 << 24))]
        result = F.polynomial_bound(terms)
        exact = math.prod(terms[0])
        self.assertLess(result["rounding"], exact)
        self.assertGreater(result["flushing"], exact)
        self.assertGreaterEqual(result["error"], exact)  # A permitted input flush returns zero.

    def test_fixed_world_affine_retains_root_and_negative_coordinates(self):
        terms = F.affine_component_terms([Fraction(1, 4), -7, 4], [1, 0, -1, 262144])
        self.assertEqual(sum(math.prod(t) for t in terms), Fraction(1, 4) - 4 + 262144)
        self.assertEqual(F.polynomial_bound(terms)["operations"], 7)

    def test_nonfinite_overbudget_wrong_skin_and_boolean_inputs_refuse(self):
        for terms in ([], [(1,)] * 33, [(1, 2, 3, 4)], [(float("nan"),)], [(True,)], [(1 << 25,)],
                      [(Fraction(1, 3),)], [(Fraction(1, 1 << 257),)]):
            with self.assertRaises(F.Refused):
                F.polynomial_bound(terms)
        for count in (0, 3, 16):
            with self.assertRaises(F.Refused):
                F.skin_component_terms([0, 0, 0], [[1] * 4] * count, [Fraction(1, 4)] * count)
        for weights in ([0] * 4, [-1, 1, 1, 1], [2, 0, 0, 0]):
            with self.assertRaises(F.Refused):
                F.skin_component_terms([0, 0, 0], [[1] * 4] * 4, weights)

    def test_gamma_and_worst_case_intermediates_stay_finite(self):
        terms = [(F.MAX_OPERAND,) * 3] * 32
        bound = F.polynomial_bound(terms)
        self.assertEqual(bound["operations"], 95)
        self.assertLess(bound["magnitude"] + bound["error"], 1 << 80)
        for count in (-1, 96, True):
            with self.assertRaises(F.Refused):
                F.gamma(count)


if __name__ == "__main__":
    unittest.main()
