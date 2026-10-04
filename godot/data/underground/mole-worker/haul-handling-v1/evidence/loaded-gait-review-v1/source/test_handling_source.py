#!/usr/bin/env python3
"""Independent arithmetic/mesh regressions for the static authoring packet; no production qualification."""
from __future__ import annotations

import argparse
from fractions import Fraction as F
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np

import author_handling as A
import prove_static_contact as C
import render_candidate as R

INPUTS = None
CANDIDATE = A.I.HERE / "evidence/contact-source-v8"
WOOD = A.I.HERE / "evidence/wood-topology-v1.json"


class ContactMathTests(unittest.TestCase):
    def test_exact_segment_crossing_proves_contact(self):
        first = [(F(1, 4), F(1, 4), F(-1)), (F(1, 4), F(1, 4), F(1)), (F(2), F(2), F(1))]
        plane = [(F(0), F(0), F(0)), (F(1), F(0), F(0)), (F(0), F(1), F(0))]
        witness = C.edge_witness(first, plane)
        self.assertEqual(witness["share"], [1, 2])
        self.assertEqual(witness["point_u"], [[1, 4], [1, 4], [0, 1]])

    def test_crossing_plane_outside_triangle_refuses(self):
        first = [(F(2), F(2), F(-1)), (F(2), F(2), F(1)), (F(3), F(3), F(1))]
        plane = [(F(0), F(0), F(0)), (F(1), F(0), F(0)), (F(0), F(1), F(0))]
        self.assertIsNone(C.edge_witness(first, plane))
        self.assertIsNone(C.edge_witness(first, [plane[0]] * 3))


class ActualSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows, cls.body, cls.wood, _, cls.topology, cls.compact, _, _ = A.I.current_inputs(*INPUTS)
        cls.body_tri = np.asarray(cls.topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
        cls.wood_tri = R.wood_topology(WOOD, cls.wood)
        source = np.load(CANDIDATE / "poses.npz", allow_pickle=False)
        cls.case = {"frames": 1, "matrices": source["matrices"][1:2], "grounding": source["grounding"][1:2]}
        cls.report = C.prove(cls.case, cls.body, cls.wood, cls.body_tri, cls.wood_tri, cls.topology["rig_binding"])

    def test_current_body_and_complete_native_stock_are_unchanged(self):
        self.assertEqual(A.I.CONTENT.geometry_fingerprint(self.body).hex(), A.I.BODY)
        self.assertEqual(A.I.CONTENT.geometry_fingerprint(self.wood).hex(), A.I.LOG)
        self.assertEqual((len(self.body_tri), len(self.wood_tri)), (10209, 768))
        self.assertFalse(np.array_equal(self.body["geometry"][0]["points"], self.rows[A.I.CASE_IDS[0]]["geometry"][0]["geometry"][0]["points"]))

    def test_anatomical_partition_keeps_mixed_boundaries_and_full_world_mesh(self):
        solid, hands = C.hand_partition(self.body, self.body_tri, self.topology["rig_binding"])
        all_indices = np.concatenate([solid] + hands)
        self.assertEqual(sorted(all_indices.tolist()), list(range(10209)))
        self.assertEqual(len(set(all_indices)), 10209)
        self.assertEqual([len(solid)] + [len(rows) for rows in hands], [9283, 478, 448])
        self.assertIn(280, solid.tolist())  # The previous right-wrist collision remains a solid.
        self.assertIn(10108, hands[0].tolist())  # Actual distal finger retains its tiny imported forearm weights.

    def test_all_non_grip_triangles_and_both_actual_contacts_pass(self):
        self.assertTrue(self.report["completed"])
        self.assertTrue(self.report["non_grip_separation"])
        self.assertEqual(self.report["non_grip_vertices_inside_stock"], [])
        self.assertTrue(self.report["source_contact_exists"])
        self.assertEqual([w["hand"] for w in self.report["hand_contact_witnesses"]], [15, 19])

    def test_whole_source_has_three_real_floor_contacts(self):
        floor = self.report["floor"]
        self.assertTrue(floor["source_not_below_floor"])
        self.assertTrue(floor["three_contacts_present"])
        self.assertEqual([row["role"] for row in floor["contacts"]], ["left_foot", "right_foot", "stock"])
        for row in floor["contacts"]:
            self.assertGreaterEqual(F(*row["source_gap_u"]), 0)
            self.assertLessEqual(F(*row["source_gap_u"]), 1)

    def test_every_rig_link_retains_its_original_length(self):
        parents, _, inverse_inverse = A.hierarchy(self.topology)
        before = A.globals_at(self.compact[0], 8, inverse_inverse)
        after = A.globals_at(self.case, 0, inverse_inverse)
        for at, parent in enumerate(parents):
            if parent >= 0:
                old_length = np.linalg.norm(before[at][:3, 3] - before[parent][:3, 3])
                new_length = np.linalg.norm(after[at][:3, 3] - after[parent][:3, 3])
                self.assertLess(abs(old_length - new_length), 1e-6, str(at))

    def test_translated_stock_does_not_inherit_hand_contact(self):
        moved = {key: value.copy() if isinstance(value, np.ndarray) else value for key, value in self.case.items()}
        moved["matrices"][0, 24, 9] += 2
        report = C.prove(moved, self.body, self.wood, self.body_tri, self.wood_tri, self.topology["rig_binding"])
        self.assertTrue(report["non_grip_separation"])
        self.assertFalse(report["source_contact_exists"])
        self.assertEqual(report["hand_contact_witnesses"], [None, None])

    def test_closed_stock_containment_refuses_without_surface_crossing(self):
        case = {key: value.copy() if isinstance(value, np.ndarray) else value for key, value in self.case.items()}
        case["matrices"][0, 0] = A.packed(np.eye(4))
        center = np.array([0., 50.689953, -576.]) / 1024
        center[1] -= float(case["grounding"][0])
        points = center + np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0]]) / 1024
        part = {"binds": 0, "geometry": [{"points": points.astype(np.float32), "ids": np.empty((3, 0), dtype=np.int32),
                                            "weights": np.empty((3, 0), dtype=np.float32)}]}
        raw = C.bounds(case, part, self.wood)
        contained = C.solid_containment(case, part, self.wood, np.array([0]), np.array([[0, 1, 2]]),
                                        self.wood_tri, raw[0], raw[1])
        self.assertEqual(contained, [0, 1, 2])

    def test_complete_stock_overhang_hits_wall_that_misses_hands(self):
        points = A.I.points_at(self.case, self.wood, 0, 24)
        wall = np.array([400, 0, -650, 450, 150, -500])
        inside = np.all(points > wall[:3], axis=1) & np.all(points < wall[3:], axis=1)
        self.assertGreater(int(inside.sum()), 0)
        for row in self.report["hand_contact_witnesses"]:
            point = np.array([float(F(*value)) for value in row["point_u"]])
            self.assertFalse(np.all(point > wall[:3]) and np.all(point < wall[3:]))

    def test_actual_wrist_penetration_is_retained_as_refusal(self):
        source = np.load(A.I.HERE / "evidence/contact-source-v4/poses.npz", allow_pickle=False)
        case = {"frames": 1, "matrices": source["matrices"][1:2], "grounding": source["grounding"][1:2]}
        report = C.prove(case, self.body, self.wood, self.body_tri, self.wood_tri, self.topology["rig_binding"])
        self.assertFalse(report["non_grip_separation"])
        self.assertTrue(any(row["body_triangle"] == 280 for row in report["unresolved"]))

    def test_unreachable_pose_refuses_without_mutating_original_rig(self):
        hub, inverse, stock, _ = A.planted_carry(self.compact[0], self.rows[A.I.CASE_IDS[2]], self.topology)
        before = [value.copy() for value in hub]
        with self.assertRaises(A.I.ENVELOPE.Refused):
            A.contact_pose(hub, stock, inverse, float(self.compact[0]["grounding"][8]), 30, 896, self.wood)
        for original, now in zip(before, hub):
            np.testing.assert_array_equal(original, now)

    def test_changed_native_stock_topology_input_refuses(self):
        record = json.loads(WOOD.read_text())
        record["points"][0][0] += 1 / 1024
        with tempfile.TemporaryDirectory(prefix="haul-source-negative-") as folder:
            path = Path(folder) / "changed.json"
            path.write_text(json.dumps(record))
            with self.assertRaisesRegex(ValueError, "HANDLING_WOOD_SOURCE"):
                R.wood_topology(path, self.wood)

    def test_unchanged_vertices_with_changed_triangle_indices_refuse(self):
        record = json.loads(WOOD.read_text())
        record["indices"][0] = record["indices"][1]
        with tempfile.TemporaryDirectory(prefix="haul-source-negative-") as folder:
            path = Path(folder) / "changed.json"
            path.write_text(json.dumps(record))
            with self.assertRaisesRegex(ValueError, "HANDLING_WOOD_SOURCE"):
                R.wood_topology(path, self.wood)


def main() -> None:
    global INPUTS, CANDIDATE, WOOD
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, default=CANDIDATE)
    parser.add_argument("--wood-topology", type=Path, default=WOOD)
    args = parser.parse_args()
    INPUTS = (args.palette, args.grip_palette)
    CANDIDATE, WOOD = args.candidate, args.wood_topology
    suite = unittest.TestSuite([unittest.defaultTestLoader.loadTestsFromTestCase(kind)
                               for kind in (ContactMathTests, ActualSourceTests)])
    outcome = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if outcome.wasSuccessful() else 1)


if __name__ == "__main__":
    main()
