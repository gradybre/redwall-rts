#!/usr/bin/env python3
"""Regression and counterexample tests for the static stone grip candidates (ADR 1206).

Run with --palette/--grip-palette (all-cast-v9 and mole-grip-v3, pinned by SHA-256 in inspect_source.py).
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np

import author_handling as A
import author_stone_grip as G
import prove_static_contact as PS
import prove_stone_contact as P

HERE = Path(__file__).resolve().parent
ARGS = None
RECIPES = {1: {"ahead": 576, "raise": 128, "in": [200, 200]}, 2: {"ahead": 576, "raise": 112, "in": [208, 200]},
           3: {"ahead": 576, "raise": 128, "in": [216, 200]}, 4: {"ahead": 640, "raise": 128, "in": [200, 200]},
           5: {"ahead": 640, "raise": 128, "in": [192, 200]}}


def recipe(**changes) -> dict:
    base = {"lean": 95, "ahead": 576, "drop": 96, "raise": 128, "back": [192, 160], "in": [200, 200]}
    base.update(changes)
    return base


class StoneGripTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = A.I.current_inputs(ARGS.palette, ARGS.grip_palette)
        _, cls.body, _, _, cls.topology, _, _, _ = cls.inputs
        cls.stone, cls.stone_tri = G.stone_part()
        cls.body_tri = np.asarray(cls.topology["parts"][0]["surfaces"][0]["indices"], dtype=np.int32).reshape(-1, 3)

    def prove(self, cases: list) -> dict:
        case = {"frames": 1, "matrices": cases[1]["matrices"], "grounding": cases[1]["grounding"]}
        return PS.prove(case, self.body, self.stone, self.body_tri, self.stone_tri, self.topology["rig_binding"])

    def test_every_committed_candidate_rebuilds_byte_identically(self):
        for version, values in RECIPES.items():
            cases, _ = G.author(self.inputs, recipe(**values), True)
            poses = np.load(HERE / f"evidence/stone-contact-v{version}/poses.npz", allow_pickle=False)
            self.assertEqual(np.concatenate([c["matrices"] for c in cases]).tobytes(), poses["matrices"].tobytes())
            self.assertEqual(np.concatenate([c["grounding"] for c in cases]).tobytes(), poses["grounding"].tobytes())

    def test_every_committed_candidate_passes_the_exact_static_rules(self):
        for version in RECIPES:
            folder = HERE / f"evidence/stone-contact-v{version}"
            proof = P.prove_candidate(self.inputs, folder)
            stored = json.loads((folder / "static-contact.json").read_text())
            self.assertTrue(stored["passes_static_rules"])
            self.assertEqual(proof["hand_contact_witnesses"], stored["static_source"]["hand_contact_witnesses"])
            self.assertEqual(proof["floor"], stored["static_source"]["floor"])

    def test_stone_scale_and_capture_are_the_adopted_ones(self):
        self.assertEqual(hashlib.sha256(G.STONE.read_bytes()).hexdigest(), G.STONE_SHA)
        self.assertEqual(json.loads(G.SCALE.read_text())["adopted_scale_m"], [0.15, 0.12, 0.15])

    def test_hands_held_short_of_the_stone_have_no_witness(self):
        cases, _ = G.author(self.inputs, recipe(**{"in": [128, 128]}), True)
        proof = self.prove(cases)
        self.assertFalse(proof["source_contact_exists"])

    def test_hands_driven_through_the_stone_lose_solid_separation(self):
        cases, _ = G.author(self.inputs, recipe(**{"in": [320, 320]}), True)
        self.assertFalse(self.prove(cases)["non_grip_separation"])

    def test_a_stone_lifted_off_the_floor_loses_its_floor_contact(self):
        cases, _ = G.author(self.inputs, recipe(), True)
        cases[1]["matrices"] = cases[1]["matrices"].copy()
        cases[1]["matrices"][0, 24, 10] += np.float32(4 / 1024)
        floor = self.prove(cases)["floor"]
        self.assertFalse(floor["three_contacts_present"])

    def test_inward_shift_beyond_the_authoring_bound_is_refused(self):
        with self.assertRaises(ValueError):
            G.author(self.inputs, recipe(**{"in": [400, 400]}), True)

    def test_an_unplanted_pose_has_no_sole_contacts(self):
        cases, _ = G.author(self.inputs, recipe(), False)
        self.assertFalse(self.prove(cases)["floor"]["three_contacts_present"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    ARGS, rest = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0]] + rest)
