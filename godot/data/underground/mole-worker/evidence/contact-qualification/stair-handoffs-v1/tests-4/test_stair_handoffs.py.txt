#!/usr/bin/env python3
"""Finite source equation tests; synthetic matrices never stand in for the real stair proof."""
import importlib.util
from pathlib import Path
import unittest

import numpy as np

SPEC = importlib.util.spec_from_file_location("new_stair_handoffs", Path(__file__).with_name("author_stair_handoffs.py"))
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)


class HandoffSourceTests(unittest.TestCase):
    def setUp(self):
        self.table = np.zeros((65536, 2), dtype=np.float32)
        self.table[:, 0] = 1
        self.table[16384] = [0, 1]
        self.table[32768] = [-1, 0]

    def test_negative_signed_ceil_precedes_outer_orientation(self):
        roots = [[0, 0, -2], [0, 0, -3]]
        root, yaw = A.phase_root_heading(roots, [0, 32768], A.ONE//2)
        self.assertEqual(root, [0, 0, -2])
        self.assertEqual(yaw, 16384)
        result = A.program_points(np.array([[2., 0., 0.]]), root, yaw, self.table)
        np.testing.assert_array_equal(result, [[0, 0, -4]])
        wrong_double_root = A.program_points(np.array([[2., 0., -2.]]), root, yaw, self.table)
        self.assertFalse(np.array_equal(result, wrong_double_root))
        wrong_rotated_root = A.program_points(np.array([[2., 0., -2.]]), [0, 0, 0], yaw, self.table)
        self.assertFalse(np.array_equal(result, wrong_rotated_root))

    def test_actual_nonunit_basis_is_not_silently_normalized_for_playback(self):
        self.table[1] = [1, np.float32(1/1024)]
        point = np.array([[1024., 0., 2048.]])
        actual = A.program_points(point, [7, 0, 11], 1, self.table)
        np.testing.assert_array_equal(actual, [[1033, 0, 2058]])
        self.assertFalse(np.array_equal(actual, point @ A.proper_heading(self.table, 1).T+[7, 0, 11]))

    def test_terminal_source_pair_is_identical_and_stationary_intervals_remain(self):
        roots, yaws, _ = A.episode_controls("turn")
        self.assertEqual(A.phase_keys(270*A.ONE, 271), (270, 270, 0))
        self.assertEqual(roots[-1], roots[-2])
        self.assertEqual(yaws[-1], yaws[-2])
        self.assertEqual([b-a for a, b in zip(roots[0], roots[-1])], [0, 0, 174])
        self.assertEqual((yaws[0], yaws[-1]), (0, 32768))

    def test_invalid_phase_root_heading_and_program_refuse(self):
        for q in (-1, 2*A.ONE, True):
            with self.assertRaises(ValueError):
                A.phase_keys(q, 2)
        for roots, yaws in (([[0, 0, 0], [0, 0, True]], [0, 0]),
                            ([[0, 0, 0], [0, 0, 0]], [0, 32769]),
                            ([[0, 0, 0], [0, 0, 0]], [0])):
            with self.assertRaises(ValueError):
                A.phase_root_heading(roots, yaws, 0)
        with self.assertRaises(ValueError):
            A.episode_controls("unreviewed")

    def test_exact_approach_and_retreat_do_not_move_the_timber_fixture(self):
        for name, start, end, yaw, delta in (("approach", -1536, -1879, 0, -343),
                                            ("retreat", -1705, -1536, 32768, 169)):
            roots, yaws, support = A.episode_controls(name)
            self.assertEqual((roots[0], roots[-1]), ([0, 0, start], [0, 0, end]))
            self.assertEqual(roots[-1][2]-roots[0][2], delta)
            self.assertEqual(yaws, [yaw]*4)
            self.assertEqual(support, 0)

    def test_each_authored_interval_preserves_an_explicit_planted_foot(self):
        roots, yaws, _ = A.episode_controls("turn")
        stations = [(np.array([[-100., -64., -2300.], [100., -64., -2300.]]), [yaw, yaw]) for yaw in yaws]
        rows = [A.frame_track(i, roots, yaws, stations) for i in range(271)]
        self.assertTrue(all(first[4] & last[4] for first, last in zip(rows, rows[1:])))
        self.assertEqual(rows[0][4], 1)
        self.assertEqual(rows[-1][4], 1)

    def test_full_foot_plant_does_not_follow_the_moving_pelvis(self):
        controls, headings, _ = A.episode_controls("approach")
        stations = [(np.array([[-100., 75., -1536.], [100., 80., z]]), [0, 0])
                    for z in (-1536., -1728., -1728., -1879.)]
        first = A.frame_track(1, controls, headings, stations)
        middle = A.frame_track(15, controls, headings, stations)
        self.assertNotEqual(first[0], middle[0])
        np.testing.assert_array_equal(first[2][0], middle[2][0])
        self.assertGreater(middle[2][1, 1], first[2][1, 1])

    def test_flat_step_uses_actual_lower_lift_without_lowering_support(self):
        roots, yaws, _ = A.episode_controls("turn")
        stations = [(np.array([[-100., -53., -2300.], [100., -48., -2300.]]), [yaw, yaw]) for yaw in yaws]
        row = A.frame_track(15, roots, yaws, stations)
        self.assertEqual(row[5][1], 32.)
        self.assertEqual(row[2][1, 1], -16.)
        self.assertEqual(row[2][0, 1], -53.)
        self.assertEqual(row[0][1], -128)


if __name__ == "__main__":
    unittest.main()
