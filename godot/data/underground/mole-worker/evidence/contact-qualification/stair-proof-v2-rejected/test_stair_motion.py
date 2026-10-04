#!/usr/bin/env python3
"""Small adversarial checks for fixed-length source authoring, not gait admission."""
import importlib.util
from pathlib import Path
import unittest

import numpy as np

SPEC = importlib.util.spec_from_file_location("stair_motion", Path(__file__).with_name("author_stair_motion.py"))
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)


class StairMotionTests(unittest.TestCase):
    def test_proper_rotations_include_antiparallel(self):
        for target in ([0, 0, -1], [0, 1, 0], [1, 1, 1]):
            matrix = A.rotation_between([0, 0, 1], target)
            self.assertTrue(np.allclose(matrix.T @ matrix, np.eye(3), atol=1e-12))
            self.assertAlmostEqual(float(np.linalg.det(matrix)), 1, places=12)
            self.assertTrue(np.allclose(matrix @ [0, 0, 1], np.asarray(target) / np.linalg.norm(target)))

    def test_actual_link_lengths_are_preserved(self):
        hip, knee, ankle, target = (np.array(value, dtype=float) for value in ([0, 1, 0], [0, .5, .3], [0, 0, 0], [0, .4, -.4]))
        result = A.knee_target(hip, knee, ankle, target)
        self.assertAlmostEqual(float(np.linalg.norm(result-hip)), float(np.linalg.norm(knee-hip)), places=12)
        self.assertAlmostEqual(float(np.linalg.norm(target-result)), float(np.linalg.norm(ankle-knee)), places=12)
        with self.assertRaisesRegex(ValueError, "STEP_LEG_REACH"):
            A.knee_target(hip, knee, ankle, np.array([0, -10, 0.]))

    def test_integer_roots_exact_endpoints_and_fixed_plant(self):
        for rise in (-256, -128, 128, 256):
            root, feet, mask = A.tracks(0, rise)
            self.assertEqual(root.tolist(), [0, 0, 0])
            self.assertEqual(mask, 3)
            root, feet, mask = A.tracks(A.FRAME_COUNT-1, rise)
            self.assertEqual(root.tolist(), [0, rise, -512])
            self.assertEqual([row.tolist() for row in feet], [[0., rise, -512.], [0., rise, -512.]])
            for frame in range(1, A.PHASE_FRAMES):
                root, feet, mask = A.tracks(frame, rise)
                self.assertEqual(feet[0].tolist(), [0., 0., 0.])
                self.assertEqual(mask, 1)
                self.assertEqual(root.dtype, np.int32)

    def test_lift_precedes_horizontal_traverse(self):
        first, last = np.array([0., 0., 0.]), np.array([0., 256., -343.])
        self.assertEqual(A.swing(first, last, .2)[2], 0)
        self.assertEqual(A.swing(first, last, .5)[1], 320)
        self.assertEqual(A.swing(first, last, .8)[2], -343)

    def test_authoring_skin_uses_all_positive_weights_and_grounding(self):
        palette = np.zeros((25, 12), dtype=np.float32)
        palette[:, :9] = np.eye(3).T.reshape(-1)
        palette[1, 9:] = [0, 2, 0]
        geometry = {"points": np.array([[1, 3, -2]], dtype=np.float32),
                    "ids": np.array([[0, 1, 2, 3]], dtype=np.int32),
                    "weights": np.array([[.25, .75, 0, 0]], dtype=np.float32)}
        part = {"binds": 24, "geometry": [geometry]}
        result = A.source_positions(part, palette, -.5)
        self.assertEqual(result.tolist(), [[1024., 4096., -2048.]])
        self.assertEqual(geometry["points"].tolist(), [[1., 3., -2.]])
        geometry["weights"][0, 0] = -.1
        with self.assertRaisesRegex(ValueError, "STEP_AUTHOR_SKIN_INPUT"):
            A.source_positions(part, palette, 0)

    def test_authoring_skin_refuses_foreign_bind_and_nonfinite_source(self):
        palette = np.zeros((25, 12), dtype=np.float32)
        geometry = {"points": np.zeros((1, 3), dtype=np.float32),
                    "ids": np.array([[24, 0, 0, 0]], dtype=np.int32),
                    "weights": np.array([[1, 0, 0, 0]], dtype=np.float32)}
        part = {"binds": 24, "geometry": [geometry]}
        with self.assertRaisesRegex(ValueError, "STEP_AUTHOR_SKIN_INPUT"):
            A.source_positions(part, palette, 0)
        geometry["ids"][0, 0] = 0
        palette[0, 0] = np.nan
        with self.assertRaisesRegex(ValueError, "STEP_AUTHOR_SKIN_INPUT"):
            A.source_positions(part, palette, 0)


if __name__ == "__main__":
    unittest.main()
