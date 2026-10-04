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
        self.assertTrue(np.allclose(D.guided_knee(hip, knee, ankle, ankle, 0), knee))
        with self.assertRaisesRegex(ValueError, "DESCENT_LEG_REACH"):
            D.guided_knee(hip, knee, ankle, target+[0, -10, 0], 1.)

    def test_actual_bend_transport_cannot_flip_at_a_projected_pole_crossing(self):
        hip, knee, ankle = [np.array(row, dtype=float) for row in ([0, 0, 0], [.3, -.4, 0], [0, -.8, 0])]
        previous = None
        for step in range(101):
            angle = -1.2 + step*.024
            target = np.array([0., -.7*np.cos(angle), -.7*np.sin(angle)])
            middle = D.guided_knee(hip, knee, ankle, target, .5, 1)
            self.assertGreater(middle[0], 0)
            if previous is not None:
                self.assertLess(np.linalg.norm(middle-previous), .02)
            previous = middle

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

    def test_trailing_lift_holds_root_until_foot_can_advance(self):
        for frame in range(30, 38):
            root, feet, plant = D.tracks(frame, -128, 256, 128, 347)
            self.assertEqual(root.tolist(), [0, -128, -256])
            self.assertEqual(feet[0][2], 0.)
            self.assertEqual(feet[1].tolist(), [0., -128., -347.])
            if frame > 30:
                self.assertEqual(plant, 2)
        self.assertLess(D.tracks(40, -128, 256, 128, 347)[0][2], -256)
        self.assertEqual(D.tracks(60, -128, 256, 128, 347)[0].tolist(), [0, -128, -400])


if __name__ == "__main__":
    unittest.main()
