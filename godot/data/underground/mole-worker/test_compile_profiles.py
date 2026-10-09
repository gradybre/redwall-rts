"""Adversarial exact primitive/state proof tests; synthetic geometry grants no production flag."""
from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np

SPEC = importlib.util.spec_from_file_location("mole_profiles", Path(__file__).with_name("compile_profiles.py"))
P = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(P)


def part(points, skinned=False):
    points = np.array(points, dtype=np.float32)
    stride = 4 if skinned else 0
    ids = np.zeros((len(points), stride), dtype=np.uint32)
    weights = np.zeros((len(points), stride), dtype=np.float32)
    if skinned:
        weights[:, 0] = 1
    return {"kind": "body" if skinned else "attachment", "name": "synthetic", "binds": int(skinned),
            "geometry": [{"points": points, "ids": ids, "weights": weights}],
            "surface_formats": [(3 << 10) if skinned else 1], "mesh_aabb": [0, 0, 0, 1, 1, 1]}


def matrices(count=2):
    result = np.zeros((count, 1, 12), dtype=np.float32)
    result[:, 0, [0, 4, 8]] = 1
    return result


class PrimitiveProof(unittest.TestCase):
    def test_renderer_loop_skips_stored_last_and_pingpong_reuses_forward_edge_hulls(self):
        case = {"frames": 4, "source_loop_mode": 1, "source_duration_s": P.Fraction(5, 60)}
        self.assertEqual(P.rendered_timing(case), (1, 163840))
        self.assertEqual(P.rendered_intervals(case), [(0, 1), (1, 2), (2, 0)])
        for loop in (0, 2):
            case["source_loop_mode"] = loop
            self.assertEqual(P.rendered_intervals(case), [(0, 1), (1, 2), (2, 3)])
        case.update(frames=2, source_loop_mode=1, source_duration_s=P.Fraction(1, 60))
        self.assertEqual(P.rendered_intervals(case), [(0, 0)])

    def test_wire_duration_metadata_cannot_be_omitted_rounded_or_relabelled(self):
        case = {"frames": 4, "source_loop_mode": 1, "source_duration_s": P.Fraction(5, 60), "duration_q16": 163840}
        for change in ({"duration_q16": 163841}, {"source_duration_s": P.Fraction(2, 30)},
                       {"source_duration_s": P.Fraction(4, 30)}, {"source_loop_mode": 3}, {"frames": True}):
            with self.assertRaises(P.envelope.Refused):
                P.rendered_intervals(dict(case, **change))
        del case["source_duration_s"]
        with self.assertRaises(P.envelope.Refused):
            P.rendered_intervals(case)

    def test_closing_edge_keeps_below_floor_geometry_missing_from_stored_adjacencies(self):
        geometry = part([[0, 0, 0], [0, .01, 0], [0, 0, .01]])
        source = matrices(4)
        source[:, 0, 9:] = [[10, 1, 0], [0, 1, 0], [0, -1, 0], [0, -1, 0]]
        case = {"frames": 4, "source_loop_mode": 0, "source_duration_s": P.Fraction(3, 30),
                "matrices": source, "grounding": np.zeros(4, dtype=np.float32), "geometry": [geometry]}
        topology = [[np.array([[0, 1, 2]], dtype=np.int64)]]
        roots = [0, -32256, 0, 262144, 16896, 262144]
        stored = P.continuous_floor(case, topology, roots)[0]
        rendered = P.continuous_floor(dict(case, source_loop_mode=1), topology, roots)[0]
        self.assertLess(stored["floor_intersection_u"][3], 16)
        self.assertGreaterEqual(rendered["floor_intersection_u"][3], 5120)
        self.assertEqual(rendered["rendered_edges"][-1], (2, 0))
        self.assertEqual(rendered["duration_q16"], 196608)

    def test_crossing_triangle_keeps_all_vertices_including_upper_lateral_extent(self):
        low = np.array([[0, -1, 0], [10, 100, 10], [-10, 100, -10]], dtype=np.int64) * P.SCALE
        result = P.partition_primitives([(low, low.copy())], [np.array([[0, 1, 2]], dtype=np.int64)])
        self.assertEqual(result["boxes_u"]["floor_crossing"], [-10240, -1024, -10240, 10240, 102400, 10240])
        self.assertIsNone(result["boxes_u"]["above_floor"])
        self.assertEqual(sum(result["triangle_counts"].values()), 1)

    def test_shared_vertices_never_omit_or_double_count_a_primitive(self):
        points = np.array([[0, -1, 0], [1, 2, 0], [0, 2, 1], [1, 3, 1]], dtype=np.int64) * P.SCALE
        result = P.partition_primitives([(points, points.copy())], [np.array([[0, 1, 2], [1, 2, 3]])])
        self.assertEqual(result["triangle_counts"], {"floor_crossing": 1, "above_floor": 1})
        self.assertEqual(result["boxes_u"]["above_floor"][1], 2048)

    def test_outward_integer_bounds_preserve_negative_fraction(self):
        low = np.array([-1, 0, P.SCALE + 1], dtype=np.int64)
        self.assertEqual(P.outward_units(low, low + 1), [-1, 0, 1024, 0, 1, 1025])

    def test_static_endpoint_hull_contains_positive_intermediate_matrices(self):
        geometry = part([[0, 1, 0], [1, 0, 0], [0, 0, 1]])
        source = matrices()
        source[1, 0, 9:] = [2, -3, 4]
        low, high = P._vertex_hulls(geometry, source, np.array([0, 1], dtype=np.float32))[0]
        for blend in [0, .25, .5, .75, 1]:
            real = (geometry["geometry"][0]["points"] + blend * np.array([2, -3, 4]))
            real[:, 1] += blend
            self.assertTrue(np.all(real * P.SCALE >= low))
            self.assertTrue(np.all(real * P.SCALE <= high))

    def test_grounding_is_after_skin_and_non_unit_weights_are_not_normalized(self):
        geometry = part([[0, 1, 0], [1, 0, 0], [0, 0, 1]], True)
        geometry["geometry"][0]["weights"][:, 1] = 1
        low, high = P._vertex_hulls(geometry, matrices(), np.array([.5, .5], dtype=np.float32))[0]
        expected = geometry["geometry"][0]["points"].astype(np.float64) * 2
        expected[:, 1] += .5
        np.testing.assert_array_equal(low, expected * P.SCALE)
        np.testing.assert_array_equal(high, low)

    def test_world_and_local_residual_are_retained_at_the_floor(self):
        geometry = part([[0, 0, 0], [1, 0, 0], [0, 0, 1]], True)
        hulls, errors = P.vertex_hulls(geometry, matrices(), np.zeros(2, dtype=np.float32),
                                     [0, -32256, 0, 262144, 16896, 262144])
        self.assertTrue(np.all(hulls[0][0][:, 1] < 0))
        self.assertTrue(all(row["numerator"] > 0 for row in errors))
        proof = P.partition_primitives(hulls, [np.array([[0, 1, 2]])])
        self.assertEqual(proof["boxes_u"]["floor_crossing"][1], -1)

    def test_invalid_primitive_index_refuses(self):
        points = np.zeros((3, 3), dtype=np.int64)
        with self.assertRaises(P.envelope.Refused):
            P.partition_primitives([(points, points)], [np.array([[0, 1, 3]])])

    def test_source_index_retrace_is_explicit_and_does_not_edit_original(self):
        case = {"frames": 3, "matrices": matrices(3), "grounding": np.array([0, 1, 2], dtype=np.float32)}
        derived = P.indexed_sequence(case, [0, 1, 2, 1, 0], "candidate", True)
        self.assertEqual(derived["source_frame_indices"], [0, 1, 2, 1, 0])
        self.assertEqual(derived["source_duration_s"], P.Fraction(4, 30))
        derived["matrices"][0, 0, 9] = 77
        self.assertEqual(case["matrices"][0, 0, 9], 0)
        np.testing.assert_array_equal(derived["grounding"], [0, 1, 2, 1, 0])

    def test_invalid_or_omitted_frame_never_clamps_to_available_state(self):
        case = {"frames": 2, "matrices": matrices(), "grounding": np.zeros(2, dtype=np.float32)}
        for frame_list in [[], [0], [0, 2], [0, -1], [0, True], list(range(2049))]:
            with self.assertRaises(P.envelope.Refused):
                P.indexed_sequence(case, frame_list, "candidate", True)

    def test_authored_float_rounds_exact_halfway_and_tiny_above_halfway(self):
        midpoint = P.Fraction(1) + P.Fraction(1, 1 << 24)
        self.assertEqual(P.authored_f32(midpoint), np.float32(1))
        self.assertEqual(P.authored_f32(midpoint + P.Fraction(1, 1 << 80)), np.nextafter(np.float32(1), np.float32(2)))
        self.assertEqual(P.authored_f32(-midpoint), np.float32(-1))

    def test_work_recipe_preserves_pivot_and_body_and_original_arrays(self):
        source = np.repeat(matrices(), 2, axis=1)
        source[:, 1, 9:] = [1, 2, 3]
        case = {"clip": "heavy_hammer_swing", "cast": "mole_digger", "attachments": ["mole_pick"], "frames": 2,
                "matrices": source, "geometry": [part([[0, 0, 0]], True), part([[0, 0, 0]])]}
        case["geometry"][1]["name"] = "mole_pick"
        corrected = P.correct_work_pick(case, {"key": "mole_pick", "prop_local_grip_m": [.5, .25, 0]})
        np.testing.assert_array_equal(corrected["matrices"][:, 0], source[:, 0])
        np.testing.assert_array_equal(source[:, 1, :9], matrices()[:, 0, :9])
        pivot = np.array([.5, .25, 0])
        fixed = corrected["matrices"][0, 1]
        np.testing.assert_array_equal(pivot @ fixed[:9].reshape(3, 3) + fixed[9:], pivot + [1, 2, 3])
        case["clip"] = "walk"
        with self.assertRaises(P.envelope.Refused):
            P.correct_work_pick(case, {"key": "mole_pick", "prop_local_grip_m": [.5, .25, 0]})


class TopologyIdentity(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.path = Path(self.directory.name) / "native.json"
        self.geometry = part([[0, 0, 0], [1, 0, 0], [0, 0, 1]])
        self.value = {"schema": 1, "content_sha256": "1" * 64, "parts": [{"part": 0,
            "mesh_sha256": P.content.geometry_fingerprint(self.geometry).hex(), "surfaces": [
            {"surface": 0, "vertex_count": 3, "native_index_count": 3, "primitive": 3, "indices": [0, 1, 2]}]}]}

    def tearDown(self):
        self.directory.cleanup()

    def load(self):
        self.path.write_text(json.dumps(self.value))
        return P.read_topology(self.path, hashlib.sha256(self.path.read_bytes()).hexdigest(), "1" * 64, [self.geometry])

    def test_exact_source_census_loads(self):
        np.testing.assert_array_equal(self.load()[0][0], [[0, 1, 2]])

    def test_wrong_source_or_modified_bytes_refuse(self):
        self.value["content_sha256"] = "2" * 64
        with self.assertRaises(P.envelope.Refused):
            self.load()
        self.path.write_text("{}")
        with self.assertRaises(P.envelope.Refused):
            P.read_topology(self.path, "0" * 64, "1" * 64, [self.geometry])

    def test_omitted_or_nontriangle_primitive_refuses(self):
        for patch in [{"indices": []}, {"native_index_count": 6}, {"primitive": 1}, {"indices": [0, 1, 3]},
                      {"indices": [0, 1, True]}]:
            prior = copy.deepcopy(self.value)
            self.value["parts"][0]["surfaces"][0].update(patch)
            with self.assertRaises(P.envelope.Refused):
                self.load()
            self.value = prior

    def test_unindexed_triangle_cannot_be_arbitrarily_reordered(self):
        self.value["parts"][0]["surfaces"][0]["native_index_count"] = 0
        self.load()
        self.value["parts"][0]["surfaces"][0]["indices"] = [2, 1, 0]
        with self.assertRaises(P.envelope.Refused):
            self.load()


class LocalRigAuthoring(unittest.TestCase):
    def rig_fixture(self):
        body, tool = part([[0, 0, 0], [1, 0, 0], [0, 1, 0]], True), part([[0, 0, 0]])
        body["binds"] = 24
        tool["name"] = "mole_pick"
        source = np.repeat(matrices(), 25, axis=1)
        first = {"cast": "mole_digger", "id": "idle", "attachments": ["mole_pick"], "frames": 2,
                 "matrices": source, "grounding": np.zeros(2, dtype=np.float32), "geometry": [body, tool]}
        last = copy.deepcopy(first)
        last["id"] = "ready"
        rotated = matrices()[0, 0].copy()
        rotated[:9] = [0, 1, 0, -1, 0, 0, 0, 0, 1]
        rotated[9:] = [0, 1, 0]
        last["matrices"][:, 19] = rotated
        last["matrices"][:, 24] = rotated
        bones = [{"bind": i, "bone": i, "parent": -1, "name": str(i), "inverse_bind": matrices()[0, 0].tolist()}
                 for i in range(24)]
        native = {"rig_binding": {"bones": bones, "right_hand": 19},
                  "pick_binding": {"key": "mole_pick", "prop_local_grip_m": [0, 0, 0]}}
        return first, last, native

    def test_full_local_rig_transition_preserves_source_endpoints_and_actual_hand_contact(self):
        first, last, native = self.rig_fixture()
        saved = first["matrices"].copy()
        derived = P.rig_transition(first, 0, last, 0, native, 5)
        np.testing.assert_array_equal(first["matrices"], saved)
        np.testing.assert_array_equal(derived["matrices"][0], first["matrices"][0])
        np.testing.assert_array_equal(derived["matrices"][-1], last["matrices"][0])
        for frame in derived["matrices"]:
            np.testing.assert_allclose(frame[19, 9:], frame[24, 9:], atol=1e-6)
            self.assertAlmostEqual(np.linalg.det(frame[19, :9].reshape(3, 3)), 1, places=6)
        native["rig_binding"]["bones"][19]["parent"] = 19
        with self.assertRaises(P.envelope.Refused):
            P.rig_transition(first, 0, last, 0, native, 5)

    def test_large_local_rotation_preserves_length_instead_of_collapsing(self):
        first = np.eye(4)
        last = np.diag([-1., -1., 1., 1.])
        middle = P._interpolate_local(first, last, .5)
        np.testing.assert_allclose(middle[:3, :3].T @ middle[:3, :3], np.eye(3), atol=1e-14)
        self.assertAlmostEqual(np.linalg.det(middle[:3, :3]), 1)
        np.testing.assert_array_equal(P._interpolate_local(first, last, 0), first)
        np.testing.assert_array_equal(P._interpolate_local(first, last, 1), last)

    def test_reflected_singular_and_nan_authoring_refuse(self):
        for matrix in [np.diag([-1., 1., 1.]), np.zeros((3, 3)), np.full((3, 3), np.nan)]:
            with self.assertRaises(P.envelope.Refused):
                P._polar(matrix)

    def test_quaternion_roundtrip_all_largest_components(self):
        for q in [np.array([1., .1, .2, .3]), np.array([.1, 1., .2, .3]), np.array([.1, .2, 1., .3]), np.array([.1, .2, .3, 1.])]:
            matrix = P._rotation(q)
            np.testing.assert_allclose(P._rotation(P._quaternion(matrix)), matrix, atol=1e-14)

    def carry_fixture(self):
        first, work, native = self.rig_fixture()
        first["clip"], work["clip"] = "walk", "heavy_hammer_swing"
        work["work_recipe"] = {"id": "mole_pick_overhead_z_halfturn_v1"}
        for bone, name in ((17, "RightArm"), (18, "RightForeArm"), (19, "RightHand")):
            native["rig_binding"]["bones"][bone].update(parent=bone - 1, name=name)
        for case in (first, work):
            for frame in range(2):
                parent = np.eye(4)
                for bone in (17, 18, 19):
                    local = np.eye(4)
                    local[2, 3] = .125
                    if case is work:
                        local[:3, :3] = P._rotation(np.array([.9, .1, .2, .1]))
                    parent = parent @ local
                    case["matrices"][frame, bone, :9] = parent[:3, :3].T.reshape(-1)
                    case["matrices"][frame, bone, 9:] = parent[:3, 3]
                case["matrices"][frame, 24] = case["matrices"][frame, 19]
        return first, work, native

    def test_carry_arm_preserves_unaffected_source_and_bone_lengths_with_exact_grip(self):
        first, work, native = self.carry_fixture()
        saved = first["matrices"].copy()
        candidate = P.correct_carry_arm(first, work, 1, native)
        np.testing.assert_array_equal(first["matrices"], saved)
        untouched = list(range(17)) + list(range(20, 24))
        np.testing.assert_array_equal(candidate["matrices"][:, untouched], saved[:, untouched])
        for frame in range(2):
            for bone in (17, 18, 19):
                parent = P._affine64(candidate["matrices"][frame, bone - 1])
                child = P._affine64(candidate["matrices"][frame, bone])
                local = np.linalg.inv(parent) @ child
                np.testing.assert_allclose(local[:3, 3], [0, 0, .125], atol=1e-7)
            np.testing.assert_allclose(candidate["matrices"][frame, 19], candidate["matrices"][frame, 24], atol=1e-7, rtol=0)
        self.assertFalse(np.array_equal(candidate["matrices"][:, 17:20], saved[:, 17:20]))

    def test_carry_arm_rejects_foreign_pose_and_changed_hierarchy(self):
        first, work, native = self.carry_fixture()
        for changes in ({"cast": "mouse_keeper"}, {"clip": "heavy_hammer_swing"}, {"attachments": []}):
            altered = dict(first, **changes)
            with self.assertRaises(P.envelope.Refused):
                P.correct_carry_arm(altered, work, 0, native)
        native["rig_binding"]["bones"][18]["name"] = "LeftForeArm"
        with self.assertRaises(P.envelope.Refused):
            P.correct_carry_arm(first, work, 0, native)

    def test_carry_arm_refuses_missing_reversed_tool_source_or_displaced_grip(self):
        first, work, native = self.carry_fixture()
        work["work_recipe"] = {}
        with self.assertRaises(P.envelope.Refused):
            P.correct_carry_arm(first, work, 0, native)
        work["work_recipe"] = {"id": "mole_pick_overhead_z_halfturn_v1"}
        work["matrices"][:, 24, 9] += 1
        with self.assertRaises(P.envelope.Refused):
            P.correct_carry_arm(first, work, 0, native)


class ContinuousPrimitiveClipping(unittest.TestCase):
    def test_high_lateral_triangle_vertex_does_not_become_floor_contact(self):
        points = np.array([[0, -1, 0], [100, 99, 100], [-100, 99, -100]], dtype=np.int64)
        low = np.stack([points, points])
        result = P.clipped_triangle_floor(low, low, np.array([[0, 1, 2]]))
        self.assertEqual(result, [-1, -1, -1, 1, 0, 1])

    def test_moving_triangle_can_cross_between_distinct_endpoint_vertices(self):
        first = np.array([[0, -10, 0], [0, 10, 0], [0, 10, 1]])
        last = np.array([[100, 10, 0], [100, 30, 0], [100, 30, 1]])
        low = np.stack([first, last])
        result = P.clipped_triangle_floor(low, low, np.array([[0, 1, 2]]))
        self.assertEqual(result[:3], [0, -10, 0])
        self.assertEqual(result[3:], [50, 0, 1])

    def test_all_positive_triangle_refuses_contact_and_real_negative_is_kept(self):
        points = np.array([[0, 2, 0], [3, 2, 0], [0, 2, 4]])
        low = np.stack([points, points])
        self.assertIsNone(P.clipped_triangle_floor(low, low, np.array([[0, 1, 2]])))
        low[:, 0, 1] = -123
        self.assertEqual(P.clipped_triangle_floor(low, low, np.array([[0, 1, 2]]))[1], -123)

    def test_residual_intervals_enclose_a_real_blend_and_triangle_interiors(self):
        raw = np.array([[[0, 1, 0], [5, 8, -2], [-4, 6, 3]], [[2, -2, -1], [7, 5, 0], [-2, 3, 5]]])
        low, high = raw - 1, raw + 1
        box = P.clipped_triangle_floor(low, high, np.array([[0, 1, 2]]))
        for tick in range(11):
            moved = raw[0] * (1 - tick / 10) + raw[1] * tick / 10
            for a in range(11):
                for b in range(11 - a):
                    point = moved[0] * a / 10 + moved[1] * b / 10 + moved[2] * (10 - a - b) / 10
                    if point[1] <= 0:
                        self.assertTrue(np.all(point >= box[:3]) and np.all(point <= box[3:]))

    def test_product_bound_refuses_before_int64_overflow(self):
        low = np.full((2, 3, 3), 1 << 30, dtype=np.int64)
        with self.assertRaises(P.envelope.Refused):
            P.clipped_triangle_floor(low, low, np.array([[0, 1, 2]]))


if __name__ == "__main__":
    unittest.main()
