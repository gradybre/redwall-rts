#!/usr/bin/env python3
"""Adversarial local tests for the diagnostic stair source reader; no renderer or source asset required."""
import importlib.util
from pathlib import Path
import unittest

import numpy as np

SPEC = importlib.util.spec_from_file_location("stair_rig", Path(__file__).with_name("assess_stair_rig.py"))
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)


class StairRigAssessmentTests(unittest.TestCase):
    def test_complete_mixed_triangle_is_retained(self):
        part = {"geometry": [{"ids": np.array([[3, 0], [0, 0], [0, 0], [7, 0]]),
                 "weights": np.array([[.5, .5], [1., 0.], [1., 0.], [1., 0.]]), "points": np.zeros((4, 3))}]}
        chosen, count = A.selected_foot_vertices(part, np.array([[0, 1, 2], [1, 2, 3]]), [3, 4])
        self.assertEqual(chosen.tolist(), [0, 1, 2])
        self.assertEqual(count, 1)

    def test_zero_weight_and_missing_foot_refuse(self):
        part = {"geometry": [{"ids": np.array([[3, 0]] * 3), "weights": np.array([[0., 1.]] * 3),
                                "points": np.zeros((3, 3))}]}
        with self.assertRaisesRegex(ValueError, "STAIR_FOOT_MISSING"):
            A.selected_foot_vertices(part, np.array([[0, 1, 2]]), [3, 4])

    def test_reach_is_only_necessary_and_preserves_inputs(self):
        leg = {"ankle_u": [0, 0, 0], "hip_u": [0, 100, 0], "segments_u": [60, 60]}
        self.assertFalse(A.two_leg_necessary_span(leg, leg, 0, 128, 128)["disjoint_diagnostic"])
        self.assertTrue(A.two_leg_necessary_span(leg, leg, 0, 256, 256)["disjoint_diagnostic"])
        self.assertEqual(leg["ankle_u"], [0, 0, 0])
        self.assertIn("no gameplay qualification", A.two_leg_necessary_span(leg, leg, 0, 128, 128)["scope"])

    def test_invalid_reach_arguments_refuse(self):
        leg = {"ankle_u": [0, 0, 0], "hip_u": [0, 100, 0], "segments_u": [60, 60]}
        for lead, rise, advance in ((2, 128, 128), (0, True, 128), (0, 513, 128), (0, 128, 1025)):
            with self.assertRaisesRegex(ValueError, "STAIR_REACH_ARGUMENT"):
                A.two_leg_necessary_span(leg, leg, lead, rise, advance)

    def test_dominant_anatomy_keeps_whole_boundary_but_not_stray_crotch_weight(self):
        part = {"geometry": [{"ids": np.array([[3, 0], [0, 0], [0, 0], [3, 0], [0, 0], [0, 0]]),
                 "weights": np.array([[.75, .25], [1., 0.], [1., 0.], [.001, .999], [1., 0.], [1., 0.]]),
                 "points": np.zeros((6, 3))}]}
        triangles = np.array([[0, 1, 2], [3, 4, 5]])
        chosen = A.anatomical_foot_triangles(part, triangles, [3, 4])
        self.assertEqual(chosen.tolist(), [True, False])
        self.assertEqual(np.unique(triangles[chosen]).tolist(), [0, 1, 2])
        self.assertEqual(triangles.tolist(), [[0, 1, 2], [3, 4, 5]])
        self.assertEqual(len(triangles), 2)  # Collision census remains complete.

    def test_equal_dominant_foot_labels_are_both_retained(self):
        part = {"geometry": [{"ids": np.array([[3, 7], [0, 0], [0, 0]]),
                 "weights": np.array([[.5, .5], [1., 0.], [1., 0.]]), "points": np.zeros((3, 3))}]}
        triangle = np.array([[0, 1, 2]])
        self.assertTrue(A.anatomical_foot_triangles(part, triangle, [3, 4])[0])
        self.assertTrue(A.anatomical_foot_triangles(part, triangle, [7, 8])[0])


if __name__ == "__main__":
    unittest.main()
