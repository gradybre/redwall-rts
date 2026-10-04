#!/usr/bin/env python3
"""Small adversarial source-authoring checks, not terrain or movement qualification."""
import importlib.util
from pathlib import Path
import unittest

import numpy as np

SPEC = importlib.util.spec_from_file_location("descent", Path(__file__).with_name("author_stair_descent.py"))
D = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(D)


class DescentTests(unittest.TestCase):
    def test_guided_joint_preserves_real_lengths(self):
        hip, knee, ankle, target = [np.array(row, dtype=float) for row in
                                   ([0, 1, 0], [.2, .5, .1], [.2, 0, .2], [.1, .3, -.3])]
        for strength in (0., .5, 1., 2.):
            middle = D.guided_knee(hip, knee, ankle, target, strength)
            self.assertAlmostEqual(np.linalg.norm(middle-hip), np.linalg.norm(knee-hip), places=12)
            self.assertAlmostEqual(np.linalg.norm(target-middle), np.linalg.norm(ankle-knee), places=12)
        self.assertTrue(np.allclose(D.guided_knee(hip, knee, ankle, target, 0), D.A.knee_target(hip, knee, ankle, target)))
        with self.assertRaisesRegex(ValueError, "DESCENT_LEG_REACH"):
            D.guided_knee(hip, knee, ankle, target+[0, -10, 0], 1.)

    def test_guide_has_exact_unchanged_endpoints(self):
        self.assertEqual(D.bend_strength(0, 1.), 0)
        self.assertEqual(D.bend_strength(90, 1.), 0)
        self.assertEqual(D.bend_strength(45, 1.), 1)
        for frame in range(91):
            self.assertTrue(0 <= D.bend_strength(frame, 1.) <= 1)

    def test_descent_is_forward_and_keeps_an_explicit_support_foot(self):
        for rise in (-128, -256):
            self.assertEqual(D.tracks(0, rise)[0].tolist(), [0, 0, 0])
            self.assertEqual(D.tracks(90, rise)[0].tolist(), [0, rise, -512])
            for frame in range(1, 30):
                root, feet, plant = D.tracks(frame, rise)
                self.assertEqual(feet[0].tolist(), [0., 0., 0.])
                self.assertEqual(plant, 1)
                self.assertLessEqual(root[2], 0)
        with self.assertRaisesRegex(ValueError, "DESCENT_TRACK_ARGUMENT"):
            D.tracks(1, 128)


if __name__ == "__main__":
    unittest.main()
