#!/usr/bin/env python3
"""Adversarial exact solid-volume and contact tests; no source-qualified stair fixture."""
from fractions import Fraction
import copy
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

import numpy as np

SPEC = importlib.util.spec_from_file_location("stair_terrain", Path(__file__).with_name("prove_stair_terrain.py"))
T = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(T)


class StairTerrainTests(unittest.TestCase):
    def test_full_solid_rejects_contained_triangle(self):
        triangle = np.array([[2, 2, 2], [3, 2, 2], [2, 3, 2]], dtype=np.int64)
        endpoints = np.stack([triangle, triangle])
        self.assertFalse(T.separated_box(endpoints, endpoints, np.array([0, 0, 0, 5, 5, 5], dtype=np.int64), [0]))

    def test_clear_endpoints_do_not_erase_middle_collision(self):
        triangle = np.array([[0, 1, 1], [0, 2, 1], [0, 1, 2]], dtype=np.int64)
        endpoints = np.stack([triangle + [-10, 0, 0], triangle + [10, 0, 0]])
        box = np.array([-1, 0, 0, 1, 3, 3], dtype=np.int64)
        for at in (0, 1):
            only = np.stack([endpoints[at], endpoints[at]])
            self.assertTrue(T.separated_box(only, only, box, [0]))
        self.assertFalse(T.separated_box(endpoints, endpoints, box, [0]))

    def test_boundaries_and_exhaustion_do_not_authorize(self):
        triangle = np.array([[0, 1, 1], [0, 2, 1], [0, 1, 2]], dtype=np.int64)
        endpoints = np.stack([triangle, triangle])
        box = np.array([0, 0, 0, 1, 3, 3], dtype=np.int64)
        self.assertFalse(T.separated_box(endpoints, endpoints, box, [0]))
        with patch.object(T, "MAX_CHECKS", 1):
            with self.assertRaisesRegex(ValueError, "STEP_TERRAIN_CHECK_CAPACITY"):
                T.separated_box(endpoints, endpoints, box, [0])

    def test_exact_source_penetration_cannot_hide_in_numerical_box(self):
        low = np.array([[[0, -1, 0]], [[0, -1, 0]]], dtype=np.int64)
        high = low + [0, 2, 0]
        self.assertTrue(T.source_above_plane(low, high, [0], (0, 1), 0, lambda *_: Fraction(1, 1000000)))
        self.assertFalse(T.source_above_plane(low, high, [0], (0, 1), 0, lambda *_: Fraction(-1, 1000000)))

    def test_entire_projection_not_just_contact_point_requires_support(self):
        low = np.array([[-1, 0, 1], [1, 0, 1]], dtype=np.int64)
        high = low.copy()
        self.assertFalse(T.inside_projection(low, high, np.array([0, -1, 0, 3, 0, 3], dtype=np.int64)))

    def test_exact_skin_y_keeps_mixed_weights_and_grounding(self):
        geometry = {"points": np.array([[0., .25, 0.]], dtype=np.float32),
                    "ids": np.array([[0, 1, 2, 3]], dtype=np.int32),
                    "weights": np.array([[.25, .75, 0, 0]], dtype=np.float32)}
        matrices = np.zeros((1, 4, 12), dtype=np.float32)
        matrices[:, :, 4] = 1
        matrices[0, 1, 10] = .5
        case = {"matrices": matrices, "grounding": np.array([-.125], dtype=np.float32)}
        self.assertEqual(T.exact_source_y({"geometry": [geometry]}, case, 0, 0), 512)

    def test_positive_fixture_includes_full_deck_top_and_all_posts(self):
        boxes = T.fixture_boxes(128)
        self.assertEqual(len(boxes), 10)
        self.assertEqual(boxes[:2], [[-1024, -64, -169, 1024, 0, 343], [-1024, 64, -681, 1024, 128, -169]])
        self.assertTrue(all(box[1] == -1024 and (box[3] <= -768 or box[0] >= 768) for box in boxes[2:]))

    def test_root_is_once_after_nonunit_weighted_geometry(self):
        scale = T.P.SCALE // 1024
        local = np.array([[[0, 20*scale, 0]], [[0, 20*scale, 0]]], dtype=np.int64)
        roots = np.array([[0, 100, -512], [0, 128, -512]], dtype=np.int64)
        low, high = T.translated_endpoint_hulls(local, local, roots)
        self.assertEqual((low // scale).tolist(), [[[0, 120, -512]], [[0, 148, -512]]])
        self.assertTrue(np.array_equal(low, high))
        self.assertEqual((local // scale).tolist(), [[[0, 20, 0]], [[0, 20, 0]]])

    def test_recipe_rejects_wrapping_roots_and_false_plant_before_arithmetic(self):
        recipe = {"root_contract": T.A.ROOT_CONTRACT, "rise_u": 128, "run_u": 512, "phase_frames": 30,
                  "edge_z_u": -169, "root_u": [[0, 0, 0], [0, 128, -512]],
                  "ankle_translation_u": [[[0, 0, 0], [0, 0, 0]], [[0, 128, -512], [0, 128, -512]]],
                  "planted_mask": [3, 3]}
        T.validate_recipe(recipe, 2)
        for key, value in (("root_u", [[1 << 50, 0, 0], [0, 128, -512]]), ("planted_mask", [0, 3]),
                           ("root_u", [[0, 0., 0], [0, 128, -512]]), ("rise_u", True)):
            changed = copy.deepcopy(recipe)
            changed[key] = value
            with self.assertRaisesRegex(ValueError, "STEP_TERRAIN_RECIPE"):
                T.validate_recipe(changed, 2)

    def test_signed_ceil_root_error_is_nonnegative_and_less_than_one(self):
        for numerator in (-65537, -65536, -32769, -1, 0, 1, 32769, 65536, 65537):
            rounded = -(-numerator // 65536)
            error = Fraction(rounded) - Fraction(numerator, 65536)
            self.assertGreaterEqual(error, 0)
            self.assertLess(error, 1)


if __name__ == "__main__":
    unittest.main()
