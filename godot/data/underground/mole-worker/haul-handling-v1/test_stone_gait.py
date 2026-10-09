#!/usr/bin/env python3
"""The stone's exact-one-unit loaded gait: hold, enter, carry loop, exit (ADR 1206).

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
import author_stone_gait as SG
import prove_stone_gait as PSG

HERE = Path(__file__).resolve().parent
OUT = HERE / "evidence/stone-gait-v1"
ARGS = None


class StoneGaitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = A.I.current_inputs(ARGS.palette, ARGS.grip_palette)
        cls.result = SG.author(cls.inputs, 60)

    def load(self, name: str):
        return np.load(OUT / (name + ".npz"), allow_pickle=False)

    def test_rebuild_is_byte_identical(self):
        for name, case in self.result["clips"].items():
            stored = self.load(name)
            self.assertEqual(case["matrices"].tobytes(), stored["matrices"].tobytes(), name)
            self.assertEqual(case["grounding"].tobytes(), stored["grounding"].tobytes(), name)

    def test_joins_are_exact(self):
        lift = self.load("../stone-program-v1/lift")["matrices"]
        hold, enter = self.load("hold")["matrices"], self.load("enter")["matrices"]
        carry, exit_ = self.load("carry")["matrices"], self.load("exit")["matrices"]
        self.assertEqual(hold[0].tobytes(), lift[-1].tobytes())
        self.assertEqual(enter[0].tobytes(), hold[0].tobytes())
        self.assertEqual(enter[-1].tobytes(), carry[0].tobytes())
        self.assertEqual(carry[0].tobytes(), carry[-1].tobytes())
        self.assertEqual(exit_.tobytes(), enter[::-1].tobytes())
        self.assertEqual((len(hold), len(enter), len(carry), len(exit_)), (2, 65, 219, 65))

    def test_every_stored_proof_passes(self):
        for name in ("hold", "enter", "carry", "exit"):
            proof = json.loads((OUT / (name + "-proof.json")).read_text())
            self.assertTrue(proof["source_proof"]["passes"], name)
            self.assertEqual(proof["loop"], 1 if name == "carry" else 0)

    def test_a_stone_pushed_into_the_chest_refuses(self):
        case = {**self.result["clips"]["hold"]}
        case["matrices"] = case["matrices"].copy()
        case["matrices"][:, 24, 11] += np.float32(160 / 1024)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "hold.npz"
            AP.write_case(path, case)
            result = PSG.prove_clip(self.inputs, path, 0)
        self.assertFalse(result["passes"])
        self.assertFalse(result["non_grip_separation"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    ARGS, rest = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0]] + rest)
