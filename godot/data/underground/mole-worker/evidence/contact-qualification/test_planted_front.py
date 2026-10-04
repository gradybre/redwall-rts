"""Finite local-rig authoring invariants; synthetic poses never establish actual model clearance."""
from fractions import Fraction
import importlib.util
from pathlib import Path
import unittest

import numpy as np

SPEC = importlib.util.spec_from_file_location("planted_source", Path(__file__).with_name("author_planted_front.py"))
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)


def rig():
    parents = [-1, 0, 1, 2, 3, 0, 5, 6, 7, 0, 9, 10, 11, 12, 13, 14, 11, 16, 17, 18, 11, 20, 21, 21]
    names = {0: "Hips", 8: "RightToeBase", 9: "Spine02", 16: "RightShoulder", 17: "RightArm"}
    inverse = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]
    return {"rig_binding": {"right_hand": 19, "bones": [{"bone": at, "bind": at, "parent": parent,
              "name": names.get(at, "joint"), "inverse_bind": inverse} for at, parent in enumerate(parents)]},
            "pick_binding": {"prop_local_grip_m": [0, 0, 0]}}


def case(count):
    matrices = np.zeros((count, 25, 12), dtype=np.float32)
    matrices[:, :, [0, 4, 8]] = 1
    matrices[:, :24, 9:] = np.arange(72).reshape(24, 3) / 100
    matrices[:, 24] = matrices[:, 19]
    return {"frames": count, "matrices": matrices, "grounding": np.full(count, .015, dtype=np.float32),
            "source_loop_mode": 1, "source_duration_s": Fraction(count - 1, 30)}


class PlantedSource(unittest.TestCase):
    def test_ready_hips_legs_and_grounding_survive_every_work_pose_without_source_mutation(self):
        ready, work, native = case(11), case(5), rig()
        work["matrices"][:, :9, 10] += .5  # Original work had a different stance/root.
        work["grounding"][:] = .7
        before = work["matrices"].copy()
        result = A.plant_work(ready, work, native)
        np.testing.assert_array_equal(work["matrices"], before)
        for frame in range(5):
            np.testing.assert_array_equal(result["matrices"][frame, :9], ready["matrices"][8, :9])
            self.assertEqual(result["grounding"][frame], ready["grounding"][8])
        parents, _, inverse_inverse = A.hierarchy(native)
        _, wanted_translations, _ = A.joints(ready, 8, parents, inverse_inverse)
        for frame in range(5):
            _, actual, _ = A.joints(result, frame, parents, inverse_inverse)
            _, source, _ = A.joints(work, frame, parents, inverse_inverse)
            for bone in range(9, 24):
                np.testing.assert_allclose(actual[bone][:3, 3], wanted_translations[bone][:3, 3], rtol=0, atol=1e-7)
                np.testing.assert_allclose(actual[bone][:3, :3], source[bone][:3, :3], rtol=0, atol=1e-7)

    def test_connected_arm_and_pick_rotation_keeps_grip_pivot_and_bone_lengths(self):
        native = rig()
        work = A.plant_work(case(11), case(5), native)
        before = work["matrices"].copy()
        moved = A.depress_upper_arm(work, native, 20)
        np.testing.assert_array_equal(work["matrices"], before)
        untouched = [bone for bone in range(25) if bone not in (17, 18, 19, 24)]
        np.testing.assert_array_equal(moved["matrices"][:, untouched], before[:, untouched])
        np.testing.assert_array_equal(moved["grounding"], work["grounding"])
        np.testing.assert_allclose(moved["matrices"][:, 17, 9:], before[:, 17, 9:], rtol=0, atol=1e-7)
        for first, last in ((17, 18), (18, 19), (19, 24)):
            expected = np.linalg.norm(before[:, first, 9:] - before[:, last, 9:], axis=1)
            actual = np.linalg.norm(moved["matrices"][:, first, 9:] - moved["matrices"][:, last, 9:], axis=1)
            np.testing.assert_allclose(actual, expected, rtol=2e-6, atol=1e-7)
        for bad in (-1, 46, True):
            with self.assertRaises(A.P.envelope.Refused):
                A.depress_upper_arm(work, native, bad)

    def test_local_entry_preserves_fixed_feet_and_exact_endpoint_source_equations(self):
        ready, native = case(11), rig()
        work = A.depress_upper_arm(A.plant_work(ready, case(5), native), native, 20)
        entry = A.planted_entry(ready, work, native, 7)
        np.testing.assert_array_equal(entry["matrices"][0], ready["matrices"][8])
        np.testing.assert_array_equal(entry["matrices"][-1], work["matrices"][0])
        for frame in range(7):
            np.testing.assert_array_equal(entry["matrices"][frame, :9], ready["matrices"][8, :9])
            self.assertEqual(entry["grounding"][frame], ready["grounding"][8])
        self.assertEqual(entry["source_loop_mode"], 0)
        for bad in (2, 122, False):
            with self.assertRaises(A.P.envelope.Refused):
                A.planted_entry(ready, work, native, bad)

    def test_compact_carry_rotates_only_connected_shoulder_and_held_tool_around_actual_pivot(self):
        original, native = case(11), rig()
        before = original["matrices"].copy()
        moved = A.compact_carry(original, native, -45)
        np.testing.assert_array_equal(original["matrices"], before)
        unchanged = [bone for bone in range(25) if bone not in (16, 17, 18, 19, 24)]
        np.testing.assert_array_equal(moved["matrices"][:, unchanged], before[:, unchanged])
        np.testing.assert_array_equal(moved["grounding"], original["grounding"])
        np.testing.assert_allclose(moved["matrices"][:, 16, 9:], before[:, 16, 9:], rtol=0, atol=1e-7)
        for first, last in ((16, 17), (17, 18), (18, 19), (19, 24)):
            expected = np.linalg.norm(before[:, first, 9:] - before[:, last, 9:], axis=1)
            actual = np.linalg.norm(moved["matrices"][:, first, 9:] - moved["matrices"][:, last, 9:], axis=1)
            np.testing.assert_allclose(actual, expected, rtol=2e-6, atol=1e-7)
        for bad in (-61, 61, True):
            with self.assertRaises(A.P.envelope.Refused):
                A.compact_carry(original, native, bad)

    def test_other_hierarchy_or_missing_source_cannot_silently_inherit_mole_authoring(self):
        native = rig()
        native["rig_binding"]["bones"][9]["parent"] = 2
        with self.assertRaisesRegex(A.P.envelope.Refused, "LOWER_BODY"):
            A.plant_work(case(11), case(5), native)
        with self.assertRaisesRegex(A.P.envelope.Refused, "SOURCE"):
            A.plant_work(case(8), case(5), rig())


if __name__ == "__main__":
    unittest.main()
