#!/usr/bin/env python3
"""Adversarial coupled-heading proof tests; all fixtures are synthetic and grant no source permission."""
from fractions import Fraction
import copy
import importlib.util
from pathlib import Path
import unittest

import numpy as np

SPEC = importlib.util.spec_from_file_location("handoff_proof", Path(__file__).with_name("prove_stair_handoffs.py"))
P = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(P)
SPEC = importlib.util.spec_from_file_location("handoff_columns", Path(__file__).parent/"stair-handoffs-v1/summarize_program.py")
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)


class HandoffProofTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        angles = np.arange(65536)*np.pi/32768
        table = np.stack((np.cos(angles), np.sin(angles)), axis=1).astype(np.float32)
        cls.coefficients = (np.floor(table.astype(np.float64)*P.COEFFICIENT).astype(np.int64),
                            np.ceil(table.astype(np.float64)*P.COEFFICIENT).astype(np.int64))
        cls.table = table

    def test_rotating_midpoint_is_not_enclosed_by_linear_world_endpoints(self):
        points = np.array([[[1024, 0, 0]], [[1024, 0, 0]]], dtype=np.int64)*P.UNIT
        rows = [{"root_u": [0, 0, 0], "yaw": yaw} for yaw in (0, 32768)]
        low, high = P.span_bounds(points, points, rows, (0, P.ONE), self.coefficients, 0, np.zeros(3, dtype=np.int64))
        self.assertLessEqual(int(low[0, 2]), -1024*P.UNIT)
        self.assertGreaterEqual(int(high[0, 2]), 0)
        middle = P.A.program_points(np.array([[1024., 0., 0.]]), [0, 0, 0], 16384, self.table)
        self.assertLess(float(middle[0, 2]), -1000)

    def test_exact_q_samples_are_inside_coupled_source_root_heading_hull(self):
        values = np.array([[[15, 12, -70], [17, -3, 4]], [[-100, 14, 150], [80, 19, -14]]], dtype=np.int64)*P.UNIT
        rows = [{"root_u": [13, -128, -2391], "yaw": 0}, {"root_u": [-4, -128, -2353], "yaw": 5461}]
        for start, end in ((0, P.ONE), (193, 42761), (49991, 49992), (P.ONE, P.ONE)):
            low, high = P.span_bounds(values, values, rows, (start, end), self.coefficients, 0, np.zeros(3, dtype=np.int64))
            for share in sorted({start, end, (start+end)//2}):
                root, yaw = P.A.phase_root_heading([r['root_u'] for r in rows], [r['yaw'] for r in rows], share)
                local = ((P.ONE-share)*values[0]+share*values[1])/(P.ONE*P.UNIT)
                sample = P.A.program_points(local, root, yaw, self.table)*P.UNIT
                self.assertTrue(np.all(sample >= low) and np.all(sample <= high))

    def test_closed_box_collision_is_not_rescued_by_subdivision(self):
        points = np.array([[[-10, 0, 0], [10, 0, 0], [0, 20, 0]]]*2, dtype=np.int64)*P.UNIT
        rows = [{"root_u": [0, 0, 0], "yaw": 0}]*2
        box = np.array([-1, -1, -1, 1, 1, 1], dtype=np.int64)*P.UNIT
        self.assertFalse(P.triangle_clear(points, points, rows, box, False, self.coefficients, 0,
                                         np.zeros(3, dtype=np.int64), [0]))

    def test_separated_complete_triangle_passes_without_contact_exception(self):
        points = np.array([[[-10, 10, 0], [10, 10, 0], [0, 20, 0]]]*2, dtype=np.int64)*P.UNIT
        rows = [{"root_u": [0, 0, 0], "yaw": 0}]*2
        box = np.array([-20, -10, -10, 20, 0, 10], dtype=np.int64)*P.UNIT
        self.assertTrue(P.triangle_clear(points, points, rows, box, False, self.coefficients, 0,
                                        np.zeros(3, dtype=np.int64), [0]))

    def test_actual_positive_source_penetration_cannot_be_a_numerical_contact(self):
        low = np.array([[[0, -1, 0]]]*2, dtype=np.int64)
        high = np.array([[[0, 1, 0]]]*2, dtype=np.int64)
        self.assertFalse(P.T.source_above_plane(low, high, [0], (0, 1), 0, lambda *_: Fraction(-1, 100000)))
        self.assertTrue(P.T.source_above_plane(low, high, [0], (0, 1), 0, lambda *_: Fraction(0)))

    def test_different_endpoint_minima_are_not_a_continuous_support_witness(self):
        values = {(0, 0): 0, (1, 0): 2, (0, 1): 2, (1, 1): 0}
        vertex, _ = P.T.contact_witness([0, 1], (0, 1), 0, lambda a, b: Fraction(values[a, b]))
        self.assertEqual(vertex, -1)

    def test_bounds_and_work_exhaustion_refuse(self):
        counter = [P.MAX_CHECKS]
        with self.assertRaisesRegex(ValueError, 'CHECK_CAPACITY'):
            P.spend(counter)
        with self.assertRaisesRegex(ValueError, 'PRODUCT_CAPACITY'):
            P.multiply_bounds(np.array([P.LIMIT], dtype=np.int64), np.array([P.LIMIT], dtype=np.int64), 0, 1)
        with self.assertRaisesRegex(ValueError, 'BLEND_CAPACITY'):
            P.mix_endpoints(np.zeros((2, 1, 3), dtype=np.int64), P.ONE+1, False)

    def test_missing_body_tool_or_one_triangle_cannot_form_a_certificate(self):
        parts = [{"geometry": [{}]}, {"geometry": [{}]}]
        topology = [[np.zeros((10209, 3), dtype=np.int64)], [np.zeros((1150, 3), dtype=np.int64)]]
        fixture = {"solids_u": [[0, 0, 0, 1, 1, 1]]*22}
        P.validate_geometry(parts, topology, fixture)
        for incomplete in (topology[:1], [[topology[0][0][:-1]], topology[1]],
                           [topology[0], [topology[1][0][:-1]]]):
            with self.assertRaisesRegex(ValueError, "HANDOFF_PROOF_PARTS"):
                P.validate_geometry(parts, incomplete, fixture)
        with self.assertRaisesRegex(ValueError, "HANDOFF_PROOF_PARTS"):
            P.validate_geometry(parts, topology, {"solids_u": fixture["solids_u"][:-1]})

    def test_foot_projection_and_positive_prisms_are_independent_requirements(self):
        point = np.array([[[2, 0, 0]]]*2, dtype=np.int64)*P.UNIT
        rows = [{"root_u": [0, 0, 0], "yaw": 0}]*2
        box = np.array([-1, -1, -1, 1, 0, 1], dtype=np.int64)*P.UNIT
        covered, _, _ = P.support_cover(point, point, rows, box, self.coefficients, 0, np.zeros(3, dtype=np.int64), [0])
        self.assertFalse(covered)
        parts = [{"geometry": [{}]}, {"geometry": [{}]}]
        topology = [[np.zeros((10209, 3), dtype=np.int64)], [np.zeros((1150, 3), dtype=np.int64)]]
        with self.assertRaisesRegex(ValueError, "HANDOFF_PROOF_PARTS"):
            P.validate_geometry(parts, topology, {"solids_u": [[0, 0, 0, 1, 0, 1]]*22})

    def columns_fixture(self):
        recipes, reports = [], []
        for count in (90, 270, 90):
            recipes.append({"keys": [{"root_u": [0, 0, -i], "yaw": 0, "planted_mask": 1,
                                      "support_primitive": 0} for i in range(count+1)]})
            support = [{"interval": i, "foot": 0, "projection_inside": True, "source_above_plane": True,
                        "vertex": 1, "primitive": 0, "plane_u": 0, "full_foot_u": [-1, 0, -1, 1, 2, 1]} for i in range(count)]
            parts = [{"triangles": n, "full_interval_boxes_program_u": [[-1, 0, -1, 1, 2, 1]]*count} for n in (10209, 1150)]
            reports.append([{"clear": True, "unresolved": [], "intervals": count, "solids": 22,
                             "parts": parts, "supports": support}, {"clear": True, "intervals": count}])
        return recipes, reports, [[-1, -1, -1, 1, 0, 1]]*22

    def test_column_census_retains_every_interval_and_exact_dedup_reference(self):
        tables = C.columns(*self.columns_fixture())
        self.assertEqual(len(tables["KEY"]), 453)
        self.assertEqual(len(tables["INTERVAL"]), 450)
        self.assertEqual(len(tables["BOX"]), 1)
        self.assertEqual(len(tables["SUPPORT_REF"]), 450)
        self.assertEqual(len(tables["SUPPORT"]), 1)
        self.assertEqual([r[3] for r in tables["PROGRAM"]], [90, 270, 90])

    def test_one_missing_support_or_primitive_proof_refuses_column_publication(self):
        recipes, reports, solids = self.columns_fixture()
        for change in (lambda r: r[0][0]["supports"].pop(), lambda r: r[0][0]["parts"].pop(),
                       lambda r: r[0][0].update(clear=False), lambda r: r[0][1].update(intervals=89)):
            changed = copy.deepcopy(reports); change(changed)
            with self.assertRaisesRegex(ValueError, "HANDOFF_COLUMNS_"):
                C.columns(recipes, changed, solids)

    def test_join_rejects_rebase_heading_snap_or_only_visually_close_pose(self):
        recipes = []
        for name in ("approach", "turn", "retreat"):
            roots, yaw, _ = P.A.episode_controls(name)
            recipes.append({"name": name, "keys": [{"root_u": roots[i], "yaw": yaw[i]} for i in (0, -1)],
                            "endpoint_pose_sha256": "a"*64})
        state = lambda i, end: [recipes[i]["keys"][end]["root_u"], recipes[i]["keys"][end]["yaw"], "a"*64]
        old = {"descent": {"entry": state(0, -1), "exit": state(1, 0)},
               "ascent": {"entry": state(1, -1), "exit": state(2, 0)}}
        self.assertEqual(len(C.joins(recipes, old)["joins"]), 4)
        for index, value in ((0, [0, -128, -2216]), (1, 0), (2, "b"*64)):
            changed = copy.deepcopy(old); changed["ascent"]["entry"][index] = value
            with self.assertRaisesRegex(ValueError, "HANDOFF_ENDPOINT_JOIN"):
                C.joins(recipes, changed)

    def test_two_banks_decode_and_caller_are_charged_without_runtime_admission(self):
        tables = C.columns(*self.columns_fixture())
        memory = C.memory(tables, {"native_peak_measured": False})
        self.assertEqual(memory["numeric_peak_proposal_before_native"], 2*memory["one_numeric_bank"]+4096+176)
        self.assertEqual(memory["runtime_allocation_bytes"], 0)
        self.assertFalse(memory["native_peak_measured"])
        tables["BOX"].append([0]*6)
        self.assertEqual(C.memory(tables, {})["numeric_peak_proposal_before_native"]-memory["numeric_peak_proposal_before_native"], 48)


if __name__ == "__main__":
    unittest.main()
