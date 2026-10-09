#!/usr/bin/env python3
"""Adversarial finite arithmetic and source/role contract checks; no fixture is production content."""
from fractions import Fraction as F
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

import numpy as np

SPEC = importlib.util.spec_from_file_location("profile_publication", Path(__file__).with_name("compile_profile_publication.py"))
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
N, P = M.N, M.P


class PublicationTests(unittest.TestCase):
    def test_fixed_18_row_map_preserves_yaw_zero_roles(self):
        self.assertEqual([M.row_identity(n) for n in range(6)], [(0, None), (1, None), (2, 0), (3, 0), (4, 0), (5, 0)])
        self.assertEqual(M.row_identity(17), (5, 49152))
        self.assertEqual(len({M.row_identity(n) for n in range(2, 18)}), 16)
        for value in (-1, 18, True, 2.0):
            with self.assertRaises(P.envelope.Refused):
                M.row_identity(value)

    def test_native_cardinals_are_factored_not_rounded(self):
        native = ((F(1), F(0)), (F(np.float32(-4.371138828673793e-8).item()), F(1)),
                  (F(-1), F(np.float32(-8.742277657347586e-8).item())),
                  (F(np.float32(1.1924880638503055e-8).item()), F(-1)))
        point = [F(-4, 3), F(7, 5), F(9, 7)]
        for ordinal, (c, s) in enumerate(native):
            a, b = N.canonical_coefficients(c, s, ordinal)
            near = [a * point[0] + b * point[2], point[1], -b * point[0] + a * point[2]]
            exact = [c * point[0] + s * point[2], point[1], -s * point[0] + c * point[2]]
            self.assertEqual(N.exact_cardinal(near, ordinal), exact)
            self.assertEqual(a, 1)
            if ordinal:
                self.assertNotEqual(b, 0)
                self.assertNotEqual(N.exact_cardinal(point, ordinal), exact)

    def test_signed_cardinal_box_keeps_closed_patch_and_negative_extents(self):
        box = [-190, 0, -678, 49, 0, -536]
        self.assertEqual(N.orient_box(box, 1), [-678, 0, -49, -536, 0, 190])
        self.assertEqual(N.orient_box(N.orient_box(box, 1), 3), box)
        with self.assertRaises(P.envelope.Refused):
            N.orient_box([0, 0, 0, 1 << 30, 1, 1], 0)

    def test_actual_native_normal_drift_changes_contact_patch(self):
        epsilon = F(1, 1 << 22)
        error = [F(1, 1 << 18)] * 3
        first = [F(-3, 8), F(1, 2), F(-767, 1024)]
        last = [F(3, 8), F(3, 4), F(-769, 1024)]
        original = N.contact_patch(first, last, error, 2, -768)
        moved = [[p[0] + epsilon * p[2], p[1], p[2] - epsilon * p[0]] for p in (first, last)]
        actual = N.contact_patch(*moved, error, 2, -768)
        self.assertNotEqual(original["exact_ideal_endpoints_m"], actual["exact_ideal_endpoints_m"])
        self.assertEqual(actual["patch_u"][2], -768)
        self.assertEqual(actual["patch_u"][5], -768)
        for a in range(3):
            self.assertLessEqual(actual["patch_u"][a], actual["anchor_u"][a])
            self.assertGreaterEqual(actual["patch_u"][a + 3], actual["anchor_u"][a])

    def test_contact_refuses_tap_or_understated_crossing(self):
        error = [F(1, 1024)] * 3
        for last in ([F(0), F(1, 2048), F(0)], [F(0), F(-1, 2048), F(0)]):
            with self.assertRaises(P.envelope.Refused):
                N.contact_patch([F(0), F(1), F(0)], last, error, 1, 0)
        with self.assertRaises(P.envelope.Refused):
            N.contact_patch([F(0), F(-1), F(0)], [F(0), F(1), F(0)], error, 1, 0)

    def test_clipped_full_triangle_keeps_interior_crossing(self):
        case = {"frames": 2, "source_loop_mode": 0, "duration_q16": 65536, "source_duration_s": F(1, 30)}
        vertices = np.array([[[-2, 1, -2], [2, 1, -2], [0, 3, 2]]] * 2, dtype=np.int64) * P.SCALE
        row = {"low": vertices, "high": vertices.copy()}
        triangle = np.array([[0, 1, 2]], dtype=np.int64)
        negative = N.clipped_portion(case, row, triangle, 2, 0)
        positive = N.clipped_portion(case, row, triangle, 2, 0, True)
        self.assertEqual(negative, [-2048, 1024, -2048, 2048, 2048, 0])
        self.assertEqual(positive, [-1024, 2048, 0, 1024, 3072, 2048])

    def test_rendered_closing_edge_is_included(self):
        case = {"frames": 4, "source_loop_mode": 1, "duration_q16": 3 * 65536, "source_duration_s": F(3, 30)}
        self.assertEqual(P.rendered_intervals(case), [(0, 1), (1, 2), (2, 0)])
        # Sourceframe3 cannot replace the actual closing endpoint0.
        vertices = np.array([[[0, 1, 0], [1, 1, 0], [0, 2, 0]],
                             [[0, 1, 0], [1, 1, 0], [0, 2, 0]],
                             [[0, 1, -2], [1, 1, -2], [0, 2, -2]],
                             [[0, 1, -2], [1, 1, -2], [0, 2, -2]]], dtype=np.int64) * P.SCALE
        row = {"low": vertices, "high": vertices.copy()}
        self.assertEqual(N.clipped_portion(case, row, np.array([[0, 1, 2]], dtype=np.int64), 2, -1024)[5], -1024)

    def test_missing_body_and_role_reclassification_refuse(self):
        box = [-1, 0, -1, 1, 1, 1]
        roles = {role: [box.copy()] for role in M.ROLE_NAMES}
        obligations = {phase: [{"part": 0, "role": "BODY_HELD_LOAD", "bounds_u": box},
                               {"part": 0, "role": "BODY_HELD_LOAD", "bounds_u": box},
                               {"part": 1, "role": "WORK_STROKE" if phase == "work" else "TURN_RECOVERY", "bounds_u": box}]
                       for phase in ("ready", "entry", "work", "recovery")}
        M.cover_rows(obligations, roles)
        roles["BODY_HELD_LOAD"] = []
        with self.assertRaises(P.envelope.Refused):
            M.cover_rows(obligations, roles)
        roles["BODY_HELD_LOAD"] = [box]
        obligations["entry"][-1]["role"] = "WORK_STROKE"
        with self.assertRaises(P.envelope.Refused):
            M.cover_rows(obligations, roles)

    def test_common_residual_covers_finite_rotation_and_axis_swap(self):
        low = np.array([[-16, -1, -8]], dtype=np.int64) * P.SCALE
        high = np.array([[16, 2, 8]], dtype=np.int64) * P.SCALE
        local, world = F(1, 1 << 30), (F(1, 1 << 29), F(1, 1 << 28), F(1, 1 << 27))
        maximum_sine = F(1, 1 << 24)
        with patch.object(P.envelope, "palette_residual", return_value=local), \
                patch.object(P.envelope, "world_residual", return_value=world):
            padding, record = N.common_padding({}, None, None, None, [(low, high)], maximum_sine)
        for sine in (maximum_sine, -maximum_sine):
            for x in (-16, 16):
                for z in (-8, 8):
                    for ex in (-local, local):
                        for ez in (-local, local):
                            dx = sine * z + ex + sine * ez
                            dz = -sine * x - sine * ex + ez
                            self.assertLessEqual(abs(dx) + max(world[0], world[2]), F(int(padding[0]), P.SCALE))
                            self.assertLessEqual(abs(dz) + max(world[0], world[2]), F(int(padding[2]), P.SCALE))
        old_padding = -(-(local + max(world[0], world[2])) * P.SCALE // 1)
        self.assertGreater(abs(maximum_sine * 16), F(int(old_padding), P.SCALE))
        self.assertEqual(record["orientation_error_m"][1], P.envelope.fraction_record(maximum_sine * 16))

    def test_common_residual_refuses_unsupported_coefficients_and_overflow(self):
        source = np.zeros((1, 3), dtype=np.int64)
        with self.assertRaises(P.envelope.Refused):
            N.common_padding({}, None, None, None, [(source, source)], F(1, 2))
        source[0, 0] = N.MAX_ABS_Q24
        with self.assertRaises(P.envelope.Refused):
            N.common_padding({}, None, None, None, [(source, source)], F(0))


if __name__ == "__main__":
    unittest.main()
