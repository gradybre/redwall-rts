#!/usr/bin/env python3
"""Exact curved-grip counterexamples and complete current-mesh loaded-gait source checks."""
from __future__ import annotations

import argparse
from fractions import Fraction as F
import hashlib
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest import mock
import warnings
import zipfile

import numpy as np

import author_handling as A
import author_loaded_gait as AUTHOR
import prove_carried_grip as GRIP
import prove_loaded_gait as P
import prove_program as PROGRAM
import prove_static_contact as S
import render_candidate as R

INPUTS = None
CANDIDATE = A.I.HERE / "evidence/loaded-gait-v2"
WOOD = A.I.HERE / "evidence/wood-topology-v1.json"


def case_slice(case: dict, first: int, last: int) -> dict:
    return {**case, "frames": 2, "source_loop_mode": 0, "source_duration_s": F(1, 30),
            "matrices": case["matrices"][[first, last]].copy(),
            "grounding": case["grounding"][[first, last]].copy()}


class LoaderCapacityTests(unittest.TestCase):
    @staticmethod
    def npy(shape, *, descr="<f4", order=False, payload=b"", version=1):
        header = repr({"descr": descr, "fortran_order": order, "shape": shape}).encode("ascii") + b"\n"
        size = struct.pack("<H" if version == 1 else "<I", len(header))
        return b"\x93NUMPY" + bytes((version, 0)) + size + header + payload

    def archive(self, path, members):
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)  # Intentional duplicate-name negative.
            with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as image:
                for name, payload in members:
                    image.writestr(name, payload)

    def refuses_before_materializing(self, path):
        with mock.patch.object(np.lib.format, "read_array", side_effect=AssertionError("NPY materialization reached")) as old:
            with mock.patch.object(np, "frombuffer", side_effect=AssertionError("buffer materialization reached")) as new:
                with self.assertRaisesRegex(ValueError, "HAUL_GAIT_"):
                    P.load_case(path, 0)
                old.assert_not_called()
                new.assert_not_called()

    def test_compressed_expanded_capacity_refuses_before_array_decode(self):
        with tempfile.TemporaryDirectory(prefix="haul-gait-capacity-") as directory:
            path = Path(directory) / "compressed.npz"
            np.savez_compressed(path, matrices=np.zeros((4096, 25, 12), dtype=np.float32),
                                grounding=np.zeros(4096, dtype=np.float32))
            self.assertLess(path.stat().st_size, 4 * P.MAX_KEYS * 301 + 4096)
            self.refuses_before_materializing(path)

    def test_huge_declared_shape_short_payload_refuses_before_array_decode(self):
        with tempfile.TemporaryDirectory(prefix="haul-gait-declared-") as directory:
            path = Path(directory) / "short.npz"
            self.archive(path, [("matrices.npy", self.npy((10**9, 25, 12), payload=b"\0" * 4)),
                                ("grounding.npy", self.npy((2,), payload=b"\0" * 8))])
            self.refuses_before_materializing(path)

    def test_second_member_is_preflighted_before_first_array_materializes(self):
        with tempfile.TemporaryDirectory(prefix="haul-gait-second-") as directory:
            path = Path(directory) / "second.npz"
            self.archive(path, [("matrices.npy", self.npy((2, 25, 12), payload=b"\0" * 2400)),
                                ("grounding.npy", self.npy((3,), payload=b"\0" * 12))])
            self.refuses_before_materializing(path)

    def test_duplicate_missing_or_additional_zip_members_refuse_before_decode(self):
        matrix = ("matrices.npy", self.npy((2, 25, 12), payload=b"\0" * 2400))
        ground = ("grounding.npy", self.npy((2,), payload=b"\0" * 8))
        with tempfile.TemporaryDirectory(prefix="haul-gait-members-") as directory:
            path = Path(directory) / "members.npz"
            for members in ([matrix, ground, ground], [matrix], [matrix, ground, ("other.npy", b"x")],
                            [matrix, ("matrices.npy", ground[1])]):
                with self.subTest(names=[row[0] for row in members]):
                    self.archive(path, members)
                    self.refuses_before_materializing(path)

    def test_dtype_order_shape_header_and_payload_are_exact_before_decode(self):
        ground = ("grounding.npy", self.npy((2,), payload=b"\0" * 8))
        cases = [self.npy((2, 25, 12), descr="<f8", payload=b"\0" * 4800),
                 self.npy((2, 25, 12), descr="|O", payload=b"pickle is never read"),
                 self.npy((2, 25, 12), order=True, payload=b"\0" * 2400),
                 self.npy((True, 25, 12), payload=b"\0" * 1200),
                 self.npy((2, 25, 12), payload=b"\0" * 2396),
                 self.npy((2, 25, 12), payload=b"\0" * 2404),
                 b"\x93NUMPY\x01\x00" + struct.pack("<H", 513) + b" " * 513]
        with tempfile.TemporaryDirectory(prefix="haul-gait-npy-") as directory:
            path = Path(directory) / "header.npz"
            for at, payload in enumerate(cases):
                with self.subTest(case=at):
                    self.archive(path, [("matrices.npy", payload), ground])
                    self.refuses_before_materializing(path)

    def test_zip_directory_capacity_precedes_zipfile_allocation(self):
        with tempfile.TemporaryDirectory(prefix="haul-gait-directory-") as directory:
            path = Path(directory) / "directory.npz"
            path.write_bytes(struct.pack("<4s4H2IH", b"PK\x05\x06", 0, 0, 65535, 65535, 0, 0, 0))
            with mock.patch.object(zipfile, "ZipFile", side_effect=AssertionError("ZIP directory allocation reached")) as decoder:
                with self.assertRaisesRegex(ValueError, "HAUL_GAIT_"):
                    P.load_case(path, 0)
                decoder.assert_not_called()

    def test_valid_stored_compressed_and_npy_v2_match_exact_payload(self):
        matrix = np.arange(P.MAX_KEYS * 300, dtype=np.float32).reshape(P.MAX_KEYS, 25, 12)
        ground = np.arange(P.MAX_KEYS, dtype=np.float32)
        with tempfile.TemporaryDirectory(prefix="haul-gait-valid-") as directory:
            path = Path(directory) / "valid.npz"
            for writer in (np.savez, np.savez_compressed):
                writer(path, matrices=matrix, grounding=ground)
                actual = P.load_case(path, 1)
                np.testing.assert_array_equal(actual["matrices"], matrix)
                np.testing.assert_array_equal(actual["grounding"], ground)
            self.archive(path, [("matrices.npy", self.npy(matrix.shape, payload=matrix.tobytes(), version=2)),
                                ("grounding.npy", self.npy(ground.shape, payload=ground.tobytes(), version=2))])
            actual = P.load_case(path, 1)
            self.assertEqual(actual["matrices"].tobytes(), matrix.tobytes())
            self.assertEqual(actual["grounding"].tobytes(), ground.tobytes())


class ExactPolynomialTests(unittest.TestCase):
    def test_positive_endpoints_do_not_prove_the_interior(self):
        self.assertFalse(GRIP.nonnegative((F(3, 16), F(-1), F(1))))
        self.assertTrue(GRIP.nonnegative((F(1, 3), F(-1), F(1))))
        self.assertTrue(GRIP.nonnegative((F(1, 4), F(-1), F(1))))
        self.assertFalse(GRIP.nonnegative((F(1, 4), F(-1), F(1)), strict=True))
        # A small off-centre negative pocket also refuses; endpoint sampling cannot prove it.
        self.assertFalse(GRIP.nonnegative((F(9, 64) - F(1, 2**22), -F(3, 4), F(1))))

    def test_rotating_affine_stock_keeps_the_real_edge_intersection(self):
        stock = [(F(0), F(0), F(0)), (F(2), F(0), F(0)), (F(0), F(2), F(0))]
        hand = [(F(1, 2), F(1, 2), F(1)), (F(1, 2), F(1, 2), F(-1)), (F(0), F(0), F(2))]
        turn = lambda rows: [(x + 4, -z - 3, y + 7) for x, y, z in rows]
        self.assertIsNotNone(S.edge_witness(hand, stock))
        self.assertIsNotNone(S.edge_witness(turn(hand), turn(stock)))
        self.assertTrue(GRIP.interval_contact(hand, turn(hand), stock, turn(stock), (0, 1))["contact"])
        self.assertTrue(GRIP.interval_contact(turn(hand), hand, turn(stock), stock, (1, 0))["contact"])

    def test_real_endpoint_contacts_can_leave_triangle_between_keys(self):
        stock = [(F(0), F(0), F(0)), (F(2), F(0), F(0)), (F(0), F(2), F(0))]
        first = [(F(0), F(1, 4), F(1)), (F(6), F(1, 4), F(-4)), (F(-1), F(1, 4), F(2))]
        last = [(F(6), F(1, 4), F(4)), (F(0), F(1, 4), F(-1)), (F(-1), F(1, 4), F(2))]
        self.assertIsNotNone(S.edge_witness(first, stock))
        self.assertIsNotNone(S.edge_witness(last, stock))
        result = GRIP.interval_contact(first, last, stock, stock, (0, 1))
        self.assertFalse(result["contact"])
        self.assertEqual(result["reason"], "triangle_interior")

    def test_interior_stock_degeneracy_and_detached_hand_refuse(self):
        stock = [(F(0), F(0), F(0)), (F(2), F(0), F(0)), (F(0), F(2), F(0))]
        hand = [(F(1, 2), F(1, 2), F(1)), (F(1, 2), F(1, 2), F(-1)), (F(0), F(0), F(2))]
        turn = lambda rows: [(-x, -y, z) for x, y, z in rows]
        self.assertIsNotNone(S.edge_witness(turn(hand), turn(stock)))
        self.assertFalse(GRIP.interval_contact(hand, turn(hand), stock, turn(stock), (0, 1))["contact"])
        detached = [(x + 4, y, z) for x, y, z in hand]
        self.assertFalse(GRIP.interval_contact(hand, detached, stock, stock, (0, 1))["contact"])
        self.assertFalse(GRIP.interval_contact(hand, hand, [stock[0]] * 3, [stock[0]] * 3, (0, 1))["contact"])

    def test_exact_proof_capacity_exhaustion_refuses(self):
        with self.assertRaisesRegex(ValueError, "HAUL_GRIP_POLYNOMIAL_CAPACITY"):
            GRIP.nonnegative((F(1),) * 9)
        with self.assertRaisesRegex(ValueError, "HAUL_GRIP_PROOF_CAPACITY"):
            GRIP.nonnegative((F(1),), counter=[GRIP.MAX_NODES])


class ActualGaitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows, cls.body, cls.wood, _, cls.topology, _, _, _ = A.I.current_inputs(*INPUTS)
        cls.body_tri = np.asarray(cls.topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
        cls.wood_tri = R.wood_topology(WOOD, cls.wood)
        accepted = A.I.HERE / "evidence/static-contact-review-v1/static-contact.json"
        cls.pairs = json.loads(accepted.read_text())["static_source"]["hand_contact_witnesses"]
        cls.cases = {name: P.load_case(CANDIDATE / (name + ".npz"), int(name == "carry"))
                     for name in ("hold", "enter", "carry", "exit")}
        cls.metadata = json.loads((CANDIDATE / "candidate.json").read_text())
        cls.reports = {name: cls.prove(case) for name, case in cls.cases.items()}

    @classmethod
    def prove(cls, case: dict) -> dict:
        return P.prove(case, cls.body, cls.wood, cls.body_tri, cls.wood_tri,
                       cls.topology["rig_binding"], cls.pairs)

    def test_complete_loaded_motion_keeps_every_primitive_and_supported_contact(self):
        for name, result in self.reports.items():
            self.assertTrue(result["all_intervals_complete"], name)
            self.assertTrue(result["non_grip_separation"], name)
            self.assertTrue(result["continuous_two_hand_contact"], name)
            self.assertTrue(result["supported_feet"], name)
            self.assertEqual(result["floor_penetrations"], [], name)
            self.assertEqual(result["initial_contained_vertices"], [], name)
            self.assertEqual(result["body_triangles"], 10209)
            self.assertEqual(result["non_grip_triangles"], 9283)
            self.assertEqual(result["intentional_grip_triangles"], [478, 448])
            self.assertEqual(result["stock_triangles"], 768)
        self.assertEqual(len(self.reports["carry"]["intervals"]), 218)
        self.assertEqual(self.reports["carry"]["intervals"][-1]["interval"], [217, 0])
        self.assertEqual(self.reports["carry"]["stock_union_u"], [-425, 473, -503, 504, 704, -217])

    def test_lift_hold_gait_recovery_place_and_repost_share_exact_hub(self):
        with np.load(AUTHOR.HUB, allow_pickle=False) as lift:
            hub_matrix, hub_ground = lift["matrices"][-1], lift["grounding"][-1]
        for name, at in (("hold", 0), ("hold", -1), ("enter", 0), ("exit", -1)):
            np.testing.assert_array_equal(self.cases[name]["matrices"][at], hub_matrix)
            self.assertEqual(self.cases[name]["grounding"][at], hub_ground)
        for left, right in (("enter", "carry"), ("carry", "exit")):
            np.testing.assert_array_equal(self.cases[left]["matrices"][-1], self.cases[right]["matrices"][0])
            self.assertEqual(self.cases[left]["grounding"][-1], self.cases[right]["grounding"][0])
        for column in ("matrices", "grounding"):
            np.testing.assert_array_equal(self.cases["exit"][column], self.cases["enter"][column][::-1])
            np.testing.assert_array_equal(self.cases["carry"][column][-1], self.cases["carry"][column][0])
        # Exact reversal provides supported stop-to-hub recovery; no interrupted root movement is inferred.

    def test_rejected_original_sole_transfer_still_refuses_without_added_key(self):
        original = P.load_case(A.I.HERE / "evidence/loaded-gait-v1/carry.npz", 1)
        result = self.prove(case_slice(original, 20, 21))
        self.assertEqual(result["floor_penetrations"], [])
        self.assertTrue(result["continuous_two_hand_contact"])
        self.assertTrue(result["non_grip_separation"])
        self.assertFalse(result["supported_feet"])
        self.assertEqual(result["support_failures"], [{"interval": [0, 1]}])

    def test_current_source_legs_and_whole_stock_survive_every_original_key(self):
        parents, inverse, inv_inverse = A.hierarchy(self.topology)
        hub = self.cases["hold"]
        held = A.globals_at(hub, 0, inv_inverse)
        original = AUTHOR.carry_keys(self.rows[A.I.CASE_IDS[2]], held, A.I.affine(hub["matrices"][0, 24]),
                                     parents, inverse, inv_inverse, self.body)
        original_frames = []
        for at, key in enumerate(self.metadata["support_transfer_keys"]["carry"]):
            if "original_frame" in key:
                frame = key["original_frame"]
                original_frames.append(frame)
                np.testing.assert_array_equal(self.cases["carry"]["matrices"][at], original["matrices"][frame])
                self.assertEqual(self.cases["carry"]["grounding"][at], original["grounding"][frame])
        self.assertEqual(original_frames, list(range(197)))
        self.assertEqual(self.metadata["variant"]["quantity_milli"], 1000)
        self.assertEqual(self.metadata["variant"]["mass_g"], 5000)
        self.assertFalse(self.metadata["runtime_carry_rate_adopted"])
        self.assertFalse(self.metadata["production_qualified"])

    def test_late_hand_departure_cannot_inherit_a_frozen_contact(self):
        changed = case_slice(self.cases["carry"], 30, 31)
        changed["matrices"][1, 15, 9] += 1 / 4
        result = GRIP.actual_contact(changed, self.body, self.wood, self.body_tri, self.wood_tri, self.pairs[0], 0, 1)
        self.assertFalse(result["contact"])
        unchanged = GRIP.actual_contact(self.cases["carry"], self.body, self.wood, self.body_tri, self.wood_tri,
                                        self.pairs[0], 30, 31)
        self.assertTrue(unchanged["contact"])

    def test_grounding_change_cannot_hide_full_mesh_floor_penetration(self):
        changed = case_slice(self.cases["carry"], 30, 31)
        changed["grounding"][1] -= 1 / 1024
        result = self.prove(changed)
        self.assertTrue(result["floor_penetrations"])
        self.assertFalse(result["supported_feet"])

    def test_complete_stock_crossing_body_between_clear_keys_refuses(self):
        changed = case_slice(self.cases["hold"], 0, 1)
        changed["matrices"][:, 24, 11] = [-1., 1.]
        for at in (0, 1):
            result = S.prove(PROGRAM.at_frame(changed, at), self.body, self.wood, self.body_tri, self.wood_tri,
                             self.topology["rig_binding"])
            self.assertTrue(result["non_grip_separation"])
        result = self.prove(changed)
        self.assertFalse(result["non_grip_separation"])
        self.assertTrue(result["unresolved"])

    def test_wrong_key_shape_nan_or_excess_capacity_refuses(self):
        with tempfile.TemporaryDirectory(prefix="haul-gait-negative-") as directory:
            path = Path(directory) / "bad.npz"
            original = self.cases["hold"]
            for matrix, grounding in (
                    (original["matrices"][:, :24], original["grounding"]),
                    (original["matrices"], np.full(2, np.nan, dtype=np.float32)),
                    (np.repeat(original["matrices"][:1], P.MAX_KEYS + 1, axis=0),
                     np.repeat(original["grounding"][:1], P.MAX_KEYS + 1))):
                np.savez(path, matrices=matrix, grounding=grounding)
                with self.assertRaisesRegex(ValueError, "HAUL_GAIT_(KEYS|IMAGE_CAPACITY)"):
                    P.load_case(path, 0)

    def test_reviewed_static_and_four_phase_sources_are_unchanged(self):
        for name in ("static-contact-review-v1", "program-review-v1"):
            manifest = json.loads((A.I.HERE / "evidence" / name / "source-sha256.json").read_text())
            for relative, expected in manifest.get("source_sha256", manifest).items():
                self.assertEqual(hashlib.sha256((A.I.ROOT / relative).read_bytes()).hexdigest(), expected, relative)

    def test_one_unit_variant_reuses_the_actual_catalog_mass(self):
        definitions = json.loads((A.I.ROOT / "godot/data/item_definitions.json").read_text())
        wood = [row for row in definitions["items"] if row["id"] == "wood"]
        self.assertEqual(len(wood), 1)
        self.assertEqual(self.metadata["variant"]["quantity_milli"], 1000)
        self.assertEqual(self.metadata["variant"]["mass_g"], wood[0]["mass_g"])
        self.assertEqual(wood[0]["mass_g"], 5000)


def main() -> None:
    global INPUTS, CANDIDATE, WOOD
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, default=CANDIDATE)
    parser.add_argument("--wood-topology", type=Path, default=WOOD)
    args = parser.parse_args()
    INPUTS, CANDIDATE, WOOD = (args.palette, args.grip_palette), args.candidate, args.wood_topology
    suite = unittest.TestSuite([unittest.defaultTestLoader.loadTestsFromTestCase(kind)
                               for kind in (LoaderCapacityTests, ExactPolynomialTests, ActualGaitTests)])
    outcome = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if outcome.wasSuccessful() else 1)


if __name__ == "__main__":
    main()
