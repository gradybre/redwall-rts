#!/usr/bin/env python3
"""Tests for the claw-stroke packet (ADR 1217 step 1).

The derivation tests and the stored-evidence tests need only committed files. The rebuild test needs the staged
`all-cast-v9.ugpal` (gitignored demo assets) and skips without it.

    $PY .../test_claw_stroke.py -v
"""
from __future__ import annotations

import json
from pathlib import Path
import unittest

import numpy as np

import author_claw_stroke as W

SRC = W.SRC
EVIDENCE = SRC.HERE / "evidence"
CANDIDATES = EVIDENCE / "claw-stroke-v1"
RECIPE = {"x_u": 128, "anchor_z_u": -608, "rake_u": 32, "lean_degrees": 60, "drop_u": 96, "tilt_degrees": 60,
          "roll_degrees": 90, "station_inset_u": 106}


def proof(name: str) -> dict:
    """A stored candidate's proof record."""
    return json.loads((CANDIDATES / ("candidate-" + name) / "proof.json").read_text())


class ClawStrokeDerivation(unittest.TestCase):
    """Numbers derived from published data."""

    def test_target_is_the_first_episode_cube_seen_from_station_4(self) -> None:
        """Cube 0 from station 4 (yaw 49152, row 25), turned into the yaw-0 frame by the published convention."""
        target = SRC.first_target()
        self.assertEqual(target["station_root_u"], [-1536, 0, -512])
        self.assertEqual(target["replaced_profile"], 25)
        self.assertEqual(target["cube_local_u"], [-512, -1024, -1536, 512, 0, -512])
        self.assertEqual(target["accepted_pick_anchor_local_u"], [42, 0, -673])

    def test_station_may_move_in_by_the_tool_free_stance_margin(self) -> None:
        """Rows 30/31 stance half-width 406 leaves 512 - 406 = 106 u between the station and the pocket."""
        self.assertEqual(SRC.stance_inset_limit(), 106)
        moved = W.target_cube({"target": SRC.first_target()}, RECIPE)
        self.assertEqual(moved[5], -406)
        self.assertEqual(moved[2], -1430)

    def test_loop_crosses_the_face_exactly_at_the_anchor_and_the_exit(self) -> None:
        """The ellipse's descending and ascending face crossings are the anchor and anchor + rake."""
        targets = W.loop_targets(RECIPE)
        self.assertEqual(len(targets), W.WORK_KEYS)
        np.testing.assert_allclose(targets[0], targets[-1])
        self.assertAlmostEqual(targets[0][1], W.TOP_U)
        self.assertAlmostEqual(min(t[1] for t in targets), -W.DEPTH_U)
        centre_y, radius_y = (W.TOP_U - W.DEPTH_U) / 2, (W.TOP_U + W.DEPTH_U) / 2
        sine = -centre_y / radius_y
        cosine = np.sqrt(1 - sine * sine)
        radius_z = RECIPE["rake_u"] / 2 / cosine
        centre_z = RECIPE["anchor_z_u"] + RECIPE["rake_u"] / 2
        self.assertAlmostEqual(centre_z - radius_z * cosine, RECIPE["anchor_z_u"])
        self.assertAlmostEqual(centre_z + radius_z * cosine, RECIPE["anchor_z_u"] + RECIPE["rake_u"])

    def test_hand_rotation_is_a_proper_left_rotation(self) -> None:
        """The new hand frame differs from the old one by a proper rotation, so its Gram matrix is kept."""
        old = np.eye(4)
        old[:3, :3] = np.array([[0.6, -0.8, 0.0], [0.8, 0.6, 0.0], [0.0, 0.0, 1.0]]) * 1.0000002
        new = W.hand_rotation(old, 60, 90)
        turn = new @ np.linalg.inv(old[:3, :3])
        np.testing.assert_allclose(turn.T @ turn, np.eye(3), atol=1e-12)
        self.assertAlmostEqual(float(np.linalg.det(turn)), 1.0, places=12)
        np.testing.assert_allclose(new.T @ new, old[:3, :3].T @ old[:3, :3], atol=1e-12)

    def test_recipe_outside_its_domain_or_off_the_face_refuses(self) -> None:
        """A station inset beyond 106 u, or an anchor behind the cube's near face, refuses before any solve."""
        src = {"target": SRC.first_target()}
        with self.assertRaisesRegex(ValueError, "CLAW_RECIPE_STATION_INSET_U"):
            W.author(src, dict(RECIPE, station_inset_u=107))
        with self.assertRaisesRegex(ValueError, "CLAW_TARGET_OFF_FACE"):
            W.author(src, dict(RECIPE, station_inset_u=0, anchor_z_u=-520, rake_u=32))


class ClawStrokeEvidence(unittest.TestCase):
    """The stored candidates and their exact proofs."""

    def test_published_station_refuses_the_paw_breaks_into_retained_earth(self) -> None:
        """Candidate p (station 1536): the paw's below-face hull reaches past the cube's near face."""
        result = proof("p")
        self.assertFalse(result["clear"])
        below = result["stroke"]["below_face"]["bounds_u"]
        self.assertGreater(below[5], -512)
        self.assertTrue(all(u["kind"] == "SOLID" for u in result["stroke"]["world"]["unresolved"]))

    def test_moved_in_candidates_clear_every_proof(self) -> None:
        """Candidates a, b and c (station 1430) clear contact, below-face, world and self-clearance proofs."""
        for name in "abc":
            result = proof(name)
            stroke, entry = result["stroke"], result["entry"]
            self.assertTrue(result["clear"], name)
            self.assertTrue(stroke["patch_inside_cube_face"] and stroke["below_face"]["only_paw"], name)
            self.assertLess(stroke["below_face"]["bounds_u"][5], -406, name)
            self.assertTrue(entry["nothing_below_face"], name)
            self.assertEqual(stroke["world"]["unresolved"] + entry["world"]["unresolved"], [], name)

    def test_candidate_a_is_candidate_p_moved_in(self) -> None:
        """a and p share every clip byte; only the station differs, so the comparison isolates the reach."""
        a = json.loads((CANDIDATES / "candidate-a/candidate.json").read_text())
        p = json.loads((CANDIDATES / "candidate-p/candidate.json").read_text())
        self.assertEqual(a["clips"], p["clips"])
        self.assertEqual({k: v for k, v in a["recipe"].items() if k != "station_inset_u"},
                         {k: v for k, v in p["recipe"].items() if k != "station_inset_u"})

    def test_probe_record_counts(self) -> None:
        """The bounded search found no clear recipe at the published station."""
        probe = json.loads((EVIDENCE / "claw-stroke-probe-v1.json").read_text())
        clear = [r for r in probe["rows"] if r["solvable"] and r["lowest_non_paw_u"] >= 0 and
                 r["paw_vertices_below_face_outside_cube"] == 0]
        self.assertEqual(probe["sampled_clear"], len(clear))
        self.assertEqual({r["recipe"]["station_inset_u"] for r in clear}, {106})


@unittest.skipUnless(SRC.PALETTE.is_file(), "needs the staged all-cast-v9.ugpal")
class ClawStrokeRebuild(unittest.TestCase):
    """Byte-identical rebuild of the stored clips from their recipes."""

    def test_rebuild_matches_every_stored_clip(self) -> None:
        """Each candidate's three clips rebuild byte for byte."""
        src = SRC.read_claw_source()
        for name in "pabc":
            folder = CANDIDATES / ("candidate-" + name)
            record = json.loads((folder / "candidate.json").read_text())
            cases, _ = W.author(src, record["recipe"])
            for clip, case in zip(("stroke", "entry", "recovery"), cases):
                with np.load(folder / (clip + ".npz"), allow_pickle=False) as image:
                    self.assertEqual(image["matrices"].tobytes(), case["matrices"].tobytes(), (name, clip))
                    self.assertEqual(image["grounding"].tobytes(), case["grounding"].tobytes(), (name, clip))


if __name__ == "__main__":
    unittest.main()
