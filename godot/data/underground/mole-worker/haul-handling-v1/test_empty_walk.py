#!/usr/bin/env python3
"""Pins, byte-identical reproduction, exact joins, sampled-vertex containment and sweep containment
for the tool-free stand/walk packet (ADR 1198 step 1)."""
from __future__ import annotations

import argparse
from fractions import Fraction as F
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import numpy as np

import author_empty_walk as E
import author_handling as A
import prove_empty_walk as P

PACKET = A.I.HERE / "evidence/empty-walk-v1"
INPUTS = None
BASIS = None
CANDIDATE = PACKET / "candidate"
PROOF = PACKET / "empty-walk.json"
YAWS = (0, 1, 4096, 8192, 12345, 16384, 20000, 24576, 32768, 40000, 49152, 57000, 65535)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inside(point_box: list, outer: list) -> bool:
    return all(outer[a] <= point_box[a] and point_box[a + 3] <= outer[a + 3] for a in range(3))


class EmptyWalkTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows, cls.body, cls.wood, _, cls.topology, _, _, _ = A.I.current_inputs(*INPUTS)
        cls.body_tri = np.asarray(cls.topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)
        cls.clips = P.load_clips(CANDIDATE)
        cls.metadata = json.loads((CANDIDATE / "candidate.json").read_text())
        cls.report = json.loads(PROOF.read_text())
        cls.geometry = cls.report["profile_geometry"]
        cls.roles = cls.geometry["rows"][0]["roles"]

    # --- pins -------------------------------------------------------------------------------------
    def test_candidate_and_proof_pins_match_files(self):
        for name, row in self.metadata["clips"].items():
            self.assertEqual(digest(CANDIDATE / (name + ".npz")), row["sha256"], name)
        for relative, expected in self.report["candidate_sha256"].items():
            self.assertEqual(digest(CANDIDATE.parent / relative), expected, relative)
        for relative, expected in self.report["producer_sha256"].items():
            self.assertEqual(digest(A.I.ROOT / relative), expected, relative)
        self.assertEqual(self.metadata["producer_sha256"], digest(Path(E.__file__)))
        self.assertEqual(self.metadata["source_palette_sha256"], A.I.PALETTE_SHA)
        self.assertEqual(self.metadata["current_mesh_palette_sha256"], A.I.GRIP_SHA)
        self.assertEqual(self.metadata["source_body_sha256"], A.I.BODY)
        self.assertEqual(digest(E.PROGRAM / "approach.npz"), E.APPROACH_SHA)
        self.assertEqual(digest(E.PROGRAM / "recovery.npz"), E.RECOVERY_SHA)
        self.assertEqual(digest(BASIS), P.BASIS_SHA)

    def test_basis_and_root_pins_are_the_published_rows_own(self):
        publication = (A.I.ROOT / "godot/data/underground/mole-worker/compile_profile_publication.py").read_text()
        self.assertIn('BASIS_SHA = "' + P.BASIS_SHA + '"', publication)
        self.assertIn('BASIS_PRODUCER = "' + P.BASIS_PRODUCER + '"', publication)
        publisher = (A.I.ROOT / "godot/data/underground/mole-worker/publish_mole_profiles.py").read_text()
        self.assertIn("ROOT_BOUNDS = " + json.dumps(P.ROOT_BOUNDS), publisher)
        self.assertEqual(self.geometry["world_basis_sha256"], P.BASIS_SHA)

    def test_reviewed_program_sources_are_unchanged(self):
        for name in ("static-contact-review-v1", "program-review-v1"):
            manifest = json.loads((A.I.HERE / "evidence" / name / "source-sha256.json").read_text())
            for relative, expected in manifest.get("source_sha256", manifest).items():
                self.assertEqual(digest(A.I.ROOT / relative), expected, relative)

    # --- byte-identical reproduction -----------------------------------------------------------
    def test_author_reproduces_every_candidate_byte(self):
        with tempfile.TemporaryDirectory(prefix="empty-walk-author-") as directory:
            out = Path(directory) / "candidate"
            subprocess.run([sys.executable, "-B", str(Path(E.__file__)), "--palette", str(INPUTS[0]),
                            "--grip-palette", str(INPUTS[1]), "--out", str(out)], check=True, capture_output=True)
            names = sorted(path.name for path in CANDIDATE.iterdir())
            self.assertEqual(sorted(path.name for path in out.iterdir()), names)
            for name in names:
                self.assertEqual((out / name).read_bytes(), (CANDIDATE / name).read_bytes(), name)

    def test_proof_reproduces_every_byte(self):
        with tempfile.TemporaryDirectory(prefix="empty-walk-proof-") as directory:
            out = Path(directory) / "empty-walk.json"
            subprocess.run([sys.executable, "-B", str(Path(P.__file__)), "--palette", str(INPUTS[0]),
                            "--grip-palette", str(INPUTS[1]), "--candidate", str(CANDIDATE),
                            "--world-basis", str(BASIS), "--out", str(out)], check=True, capture_output=True)
            self.assertEqual(out.read_bytes(), PROOF.read_bytes())

    # --- exact source and joins -------------------------------------------------------------------
    def test_stand_keeps_every_supplied_matrix_and_closes_on_key_zero(self):
        original, stand = self.rows[E.STAND_ID], self.clips["stand"]
        self.assertEqual(stand["frames"], original["frames"])
        np.testing.assert_array_equal(stand["matrices"][:-1], original["matrices"][:-1])
        np.testing.assert_array_equal(stand["matrices"][-1], stand["matrices"][0])
        self.assertEqual(stand["grounding"][-1], stand["grounding"][0])

    def test_walk_keeps_every_supplied_matrix_between_transfer_keys(self):
        original, walk = self.rows[E.WALK_ID], self.clips["walk"]
        frames = []
        for at, key in enumerate(self.metadata["authoring"]["walk"]["support_transfer_keys"]):
            if "original_frame" in key:
                frame = key["original_frame"] % (original["frames"] - 1)
                frames.append(key["original_frame"])
                np.testing.assert_array_equal(walk["matrices"][at], original["matrices"][frame])
        self.assertEqual(frames, list(range(original["frames"])))
        np.testing.assert_array_equal(walk["matrices"][-1], walk["matrices"][0])

    def test_joins_meet_stand_ready_key_and_program_hub_exactly(self):
        stand, enter, leave = self.clips["stand"], self.clips["enter_haul"], self.clips["leave_haul"]
        approach, recovery = E.read_program("approach", E.APPROACH_SHA), E.read_program("recovery", E.RECOVERY_SHA)
        np.testing.assert_array_equal(enter["matrices"][0, :24], stand["matrices"][E.READY_FRAME])
        self.assertEqual(enter["grounding"][0], stand["grounding"][E.READY_FRAME])
        np.testing.assert_array_equal(enter["matrices"][-1], approach["matrices"][0])
        self.assertEqual(enter["grounding"][-1], approach["grounding"][0])
        np.testing.assert_array_equal(leave["matrices"][0], recovery["matrices"][-1])
        self.assertEqual(leave["grounding"][0], recovery["grounding"][-1])
        for column in ("matrices", "grounding"):
            np.testing.assert_array_equal(leave[column], enter[column][::-1])
        np.testing.assert_array_equal(enter["matrices"][:, 24], np.broadcast_to(approach["matrices"][0, 24], (enter["frames"], 12)))

    def test_tool_free_scope(self):
        self.assertIsNone(self.metadata["tool"])
        self.assertIsNone(self.metadata["cargo"])
        self.assertEqual([row["kind"] for row in self.rows[E.STAND_ID]["geometry"]], ["body"])
        for record in self.geometry["rows"]:
            self.assertEqual((record["tool"], record["tool_variant"], record["cargo"], record["cargo_variant"]), (-1, -1, -1, -1))
            self.assertEqual(record["quantity_milli"], [0, 0])
            self.assertEqual(record["yaw_kind"], "YAW_ALL")
            self.assertEqual(record["yaw"], 0)
        self.assertEqual([r["mode"] for r in self.geometry["rows"]], [0, 1])

    # --- source proofs ----------------------------------------------------------------------------
    def test_every_clip_is_floor_clear_and_supported(self):
        for name, proof in self.report["source_proof"].items():
            self.assertEqual(proof["floor_penetrations"], [], name)
            self.assertTrue(proof["supported_feet"], name)
            self.assertEqual(len(proof["intervals"]), self.clips[name]["frames"] - 1, name)
        self.assertEqual(self.report["source_proof"]["walk"]["intervals"][-1]["interval"][1], 0)
        for name in ("enter_haul", "leave_haul"):
            separation = self.report["source_proof"][name]["stock_separation"]
            self.assertTrue(separation["all_intervals_complete"] and separation["non_grip_separation"])
            self.assertEqual(separation["floor_penetrations"], [])

    def test_lowered_grounding_exposes_penetration(self):
        changed = dict(self.clips["walk"], grounding=self.clips["walk"]["grounding"].copy())
        changed["grounding"][5] -= np.float32(1 / 1024)
        result = P.support_proof(changed, self.body, self.body_tri)
        self.assertTrue(result["floor_penetrations"])

    def test_original_walk_without_transfer_keys_refuses_support(self):
        original, _ = E.closed_loop(self.rows[E.WALK_ID], self.body)
        result = P.support_proof(original, self.body, self.body_tri)
        self.assertEqual(result["floor_penetrations"], [])
        self.assertFalse(result["supported_feet"])

    # --- boxes contain sampled vertices ------------------------------------------------------------
    def sampled(self, name: str):
        case = self.clips[name]
        for frame in range(case["frames"]):
            yield A.I.points_at(case, self.body, frame)

    def test_source_boxes_contain_every_sampled_vertex(self):
        enclosure = self.geometry["ground_enclosure"]
        feet = np.unique(np.concatenate(P.foot_vertices(self.body, self.body_tri)))
        for name in ("stand", "walk"):
            for points in self.sampled(name):
                self.assertTrue(inside([*points.min(axis=0), *points.max(axis=0)], enclosure["source_full_u"]), name)
                low = points[points[:, 1] <= 0]
                if len(low):
                    self.assertTrue(inside([*low.min(axis=0), *low.max(axis=0)], enclosure["source_floor_u"]), name)
                foot = points[feet]
                support = enclosure["stance"]["support_u"]
                self.assertTrue(support[0] <= foot[:, 0].min() and foot[:, 0].max() <= support[3])
                self.assertTrue(support[2] <= foot[:, 2].min() and foot[:, 2].max() <= support[5])

    def test_role_boxes_contain_sampled_vertices_at_every_sampled_heading(self):
        full, floor = self.roles["BODY_HELD_LOAD"]
        support = self.roles["STANCE_SUPPORT"][0]
        feet = np.unique(np.concatenate(P.foot_vertices(self.body, self.body_tri)))
        for name in ("stand", "walk"):
            for points in self.sampled(name):
                for yaw in YAWS:
                    turned = P.rotated_points(points, yaw)
                    above, below = turned[turned[:, 1] >= 0], turned[turned[:, 1] < 0]
                    self.assertTrue(inside([*above.min(axis=0), *above.max(axis=0)], full), (name, yaw))
                    if len(below):
                        self.assertTrue(inside([*below.min(axis=0), *below.max(axis=0)], floor), (name, yaw))
                    foot = turned[feet]
                    self.assertTrue(support[0] <= foot[:, 0].min() and foot[:, 0].max() <= support[3], (name, yaw))
                    self.assertTrue(support[2] <= foot[:, 2].min() and foot[:, 2].max() <= support[5], (name, yaw))

    # --- sweep containment ------------------------------------------------------------------------
    def test_swept_boxes_contain_every_rotated_source_corner(self):
        enclosure = self.geometry["ground_enclosure"]
        angles = 2 * np.pi * np.arange(65536) / 65536
        c, s = np.cos(angles), np.sin(angles)
        for source, swept in ((enclosure["source_full_u"], enclosure["full_u"]),
                              (enclosure["source_floor_u"], enclosure["floor_u"]),
                              (enclosure["stance"]["support_u"], enclosure["support_u"])):
            for x in (source[0], source[3]):
                for z in (source[2], source[5]):
                    rx, rz = c * x + s * z, -s * x + c * z
                    self.assertTrue(swept[0] <= rx.min() and rx.max() <= swept[3])
                    self.assertTrue(swept[2] <= rz.min() and rz.max() <= swept[5])
            self.assertEqual((swept[1], swept[4]), (source[1], source[4]))

    def test_sweep_radius_is_the_exact_ceiling_without_invented_margin(self):
        enclosure = self.geometry["ground_enclosure"]
        norm = F(self.geometry["world_basis_norm_squared"]["numerator"], self.geometry["world_basis_norm_squared"]["denominator"])
        for source, swept in ((enclosure["source_full_u"], enclosure["full_u"]),
                              (enclosure["source_floor_u"], enclosure["floor_u"]),
                              (enclosure["stance"]["support_u"], enclosure["support_u"])):
            xx, zz = max(abs(source[0]), abs(source[3])), max(abs(source[2]), abs(source[5]))
            square = (xx * xx + zz * zz) * norm
            radius = swept[3]
            self.assertEqual(swept, [-radius, source[1], -radius, radius, source[4], radius])
            self.assertGreaterEqual(radius * radius, square)
            self.assertLess((radius - 1) * (radius - 1), square)

    def test_roles_follow_published_ground_row_assembly(self):
        enclosure = self.geometry["ground_enclosure"]
        full = enclosure["full_u"]
        self.assertEqual(self.roles["BODY_HELD_LOAD"], [[full[0], 0, full[2], *full[3:]], enclosure["floor_u"]])
        self.assertEqual(self.roles["TURN_RECOVERY"], self.roles["BODY_HELD_LOAD"])
        self.assertEqual(self.roles["STANCE_SUPPORT"], [enclosure["support_u"]])
        self.assertEqual(self.roles["STANCE_SUPPORT"][0][4], 0)
        self.assertEqual(self.geometry["rows"][0]["roles"], self.geometry["rows"][1]["roles"])
        self.assertEqual(self.geometry["rows"][0]["box_count"], 5)
        self.assertTrue(self.geometry["join_enclosure"]["within_row_roles"])


def main() -> None:
    global INPUTS, BASIS, CANDIDATE, PROOF
    parser = argparse.ArgumentParser(__doc__)
    for name in ("palette", "grip-palette", "world-basis"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--candidate", type=Path, default=CANDIDATE)
    parser.add_argument("--proof", type=Path, default=PROOF)
    args = parser.parse_args()
    INPUTS, BASIS, CANDIDATE, PROOF = (args.palette, args.grip_palette), args.world_basis, args.candidate, args.proof
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(EmptyWalkTests)
    outcome = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if outcome.wasSuccessful() else 1)


if __name__ == "__main__":
    main()
