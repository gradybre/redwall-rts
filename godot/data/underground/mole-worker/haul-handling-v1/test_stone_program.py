#!/usr/bin/env python3
"""The stone's four-phase approach/lift/place/recovery program (ADR 1206).

Run with --palette/--grip-palette (all-cast-v9, mole-grip-v3).
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np

import author_handling as A
import author_program as AP
import author_stone_program as SPR
import prove_stone_program as PSP

HERE = Path(__file__).resolve().parent
OUT = HERE / "evidence/stone-program-v1"
RECIPE = (15, 448, 384, 60, (8, 16, 2, 12, 48))
ARGS = None


class StoneProgramTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = A.I.current_inputs(ARGS.palette, ARGS.grip_palette)
        cls.case, _ = SPR.author(cls.inputs, *RECIPE)

    def load(self, name: str) -> np.lib.npyio.NpzFile:
        return np.load(OUT / (name + ".npz"), allow_pickle=False)

    def test_rebuild_is_byte_identical(self):
        stored = self.load("lift")
        self.assertEqual(self.case["matrices"].tobytes(), stored["matrices"].tobytes())
        self.assertEqual(self.case["grounding"].tobytes(), stored["grounding"].tobytes())

    def test_pickup_key_is_the_approved_grip_byte_for_byte(self):
        approved = np.load(HERE / "evidence/stone-contact-v1/poses.npz", allow_pickle=False)
        self.assertEqual(self.load("lift")["matrices"][0].tobytes(), approved["matrices"][1].tobytes())

    def test_phases_are_exact_reversals_and_the_floor_stone_stays_put(self):
        lift, place = self.load("lift")["matrices"], self.load("place")["matrices"]
        approach, recovery = self.load("approach")["matrices"], self.load("recovery")["matrices"]
        self.assertEqual(place.tobytes(), lift[::-1].tobytes())
        self.assertEqual(recovery.tobytes(), approach[::-1].tobytes())
        self.assertEqual(approach[:, :24].tobytes(), lift[::-1, :24].tobytes())
        self.assertTrue(np.all(approach[:, 24] == lift[0, 24]))
        self.assertEqual(approach[-1].tobytes(), lift[0].tobytes())

    def test_every_stored_proof_passes(self):
        for name, grip in (("approach", False), ("lift", True), ("place", True), ("recovery", False)):
            proof = json.loads((OUT / (name + "-proof.json")).read_text())
            self.assertTrue(proof["source_proof"]["passes"], name)
            self.assertEqual(proof["grip_required"], grip)

    def test_wood_unstaged_path_buries_the_snout(self):
        case, _ = SPR.author(self.inputs, 15, 448, 384, 16, (0, 16, 0, 16, 0))
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "lift.npz"
            AP.write_case(path, case)
            result = PSP.prove_clip(self.inputs, path, True)
        self.assertFalse(result["non_grip_separation"])
        self.assertFalse(result["passes"])

    def test_staging_bounds_are_refused(self):
        for stage in ((0, 16, 0, 16, 48), (8, 8, 0, 16, 0), (8, 16, 2, 12, 300)):
            with self.assertRaises(ValueError):
                SPR.author(self.inputs, 15, 448, 384, 4, stage)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    ARGS, rest = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0]] + rest)
