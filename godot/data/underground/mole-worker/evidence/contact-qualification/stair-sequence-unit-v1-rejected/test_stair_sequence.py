#!/usr/bin/env python3
"""Finite fixture/seam adversarial tests; no gait or world activation."""
import copy
import importlib.util
from pathlib import Path
import unittest

import numpy as np

SPEC = importlib.util.spec_from_file_location("stair_sequence", Path(__file__).with_name("prove_stair_sequence.py"))
Q = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(Q)


class SequenceTests(unittest.TestCase):
    @staticmethod
    def fixture():
        return {"schema": 1, "engineering_only": True, "rise_u": 128,
                "solids_u": [[-1024, -64, -169, 1024, 0, 343], [-1024, 64, -681, 1024, 128, -169],
                             [-1024, 192, -1193, 1024, 256, -681]],
                "segments": [{"origin_u": [0, 0, 0], "quarter_turn": 0, "support_solids": [0, 1]},
                             {"origin_u": [0, 128, -512], "quarter_turn": 0, "support_solids": [1, 2]}]}

    @staticmethod
    def recipe():
        return {"rise_u": 128, "root_u": [[0, 0, 0], [0, 128, -512]]}

    def test_complete_positive_prism_and_capacity_refuse_before_use(self):
        fixture = self.fixture()
        Q.validate_fixture(fixture, self.recipe())
        for bad in ([0, 0, 0, 0, 1, 1], [0, 0, 0, 1, 1, 9000], [0, 0, 0, 1, 1, True]):
            candidate = copy.deepcopy(fixture)
            candidate['solids_u'].append(bad)
            with self.assertRaisesRegex(ValueError, 'SEQUENCE_POSITIVE_SOLID'):
                Q.validate_fixture(candidate, self.recipe())
        fixture['solids_u'] *= 11
        with self.assertRaisesRegex(ValueError, 'SEQUENCE_CAPACITY'):
            Q.validate_fixture(fixture, self.recipe())

    def test_endpoint_requires_exact_shared_root_support_and_orientation(self):
        fixture = self.fixture()
        for field, value in [('origin_u', [0, 128, -511]), ('support_solids', [0, 2]), ('quarter_turn', 2)]:
            candidate = copy.deepcopy(fixture)
            candidate['segments'][1][field] = value
            with self.assertRaises(ValueError):
                Q.validate_fixture(candidate, self.recipe())

    def test_fixture_rotation_is_exact_and_keeps_the_whole_box(self):
        segment = {'origin_u': [100, 200, 300], 'quarter_turn': 2}
        self.assertEqual(Q.local_box([95, 198, 293, 109, 210, 311], segment), [-9, -2, -11, 5, 10, 7])
        for quarter in range(4):
            value = [3, -5, 7]
            self.assertEqual(list(Q.turn(Q.turn(value, quarter), (-quarter) % 4)), value)

    def test_same_source_endpoint_pose_and_grounding_required(self):
        matrices = np.zeros((2, 1, 12), dtype=np.float32)
        case = {'matrices': matrices, 'grounding': np.array([0., 0.], dtype=np.float32)}
        Q.validate_endpoint_pose(case)
        matrices[1, 0, 10] = .0001
        with self.assertRaisesRegex(ValueError, 'SEQUENCE_DISCONTINUOUS_POSE'):
            Q.validate_endpoint_pose(case)
        matrices[1, 0, 10] = 0
        case['grounding'][1] = .0001
        with self.assertRaisesRegex(ValueError, 'SEQUENCE_DISCONTINUOUS_POSE'):
            Q.validate_endpoint_pose(case)

    def test_support_keeps_full_projection_not_only_contact_vertex(self):
        row = {'deck': 0, 'full_foot_enclosure_u': [-5, -1, -10, 7, 20, 11]}
        segment = {'support_solids': [0, 1]}
        self.assertTrue(Q.support_fits(row, [[-5, -64, -10, 7, 0, 11]], segment))
        self.assertFalse(Q.support_fits(row, [[-5, -64, -10, 6, 0, 11]], segment))

    def test_missing_one_original_triangle_or_support_record_is_rejected(self):
        case = {'frames': 2, 'source_loop_mode': 0, 'duration_q16': 65536}
        recipe = {'rise_u': 128}
        bad = {'clear': True, 'unresolved': [], 'root_contract': Q.A.ROOT_CONTRACT, 'exact_yaw': 0,
               'fixture_boxes_u': Q.T.fixture_boxes(128), 'rendered_edges': [(0, 1)], 'parts': [{'triangles': 1}]}
        with self.assertRaisesRegex(ValueError, 'SEQUENCE_BASE_PROOF'):
            Q.retained_supports(bad, case, recipe, [[np.zeros((2, 3), dtype=int)]])


if __name__ == '__main__':
    unittest.main()
