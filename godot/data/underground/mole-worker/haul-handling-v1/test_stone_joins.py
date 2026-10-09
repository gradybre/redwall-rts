#!/usr/bin/env python3
"""The stone stand joins (ADR 1206). Run with --palette/--grip-palette (all-cast-v9, mole-grip-v3)."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
import unittest

import numpy as np

import author_handling as A
import author_empty_walk as E
import author_stone_joins as J

HERE = Path(__file__).resolve().parent
OUT = HERE / "evidence/stone-joins-v1"
ARGS = None


class StoneJoinTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        _, cls.body, _, _, cls.topology, _, _, _ = A.I.current_inputs(ARGS.palette, ARGS.grip_palette)

    def load(self, path: Path) -> np.ndarray:
        with np.load(path, allow_pickle=False) as image:
            return image["matrices"].copy()

    def test_rebuild_is_byte_identical(self):
        clips, _ = J.author(self.body, self.topology)
        for name, case in clips.items():
            stored = np.load(OUT / (name + ".npz"), allow_pickle=False)
            self.assertEqual(case["matrices"].tobytes(), stored["matrices"].tobytes(), name)
            self.assertEqual(case["grounding"].tobytes(), stored["grounding"].tobytes(), name)

    def test_endpoints_join_the_stand_and_the_stone_program_exactly(self):
        enter, leave = self.load(OUT / "enter_haul_stone.npz"), self.load(OUT / "leave_haul_stone.npz")
        stand = self.load(J.STAND)
        approach, recovery = self.load(J.PROGRAM / "approach.npz"), self.load(J.PROGRAM / "recovery.npz")
        self.assertEqual(enter[0, :24].tobytes(), stand[E.READY_FRAME].tobytes())
        self.assertEqual(enter[-1].tobytes(), approach[0].tobytes())
        self.assertEqual(leave[0].tobytes(), recovery[-1].tobytes())
        self.assertEqual(leave.tobytes(), enter[::-1].tobytes())
        self.assertTrue(np.all(enter[:, 24] == approach[0, 24]))

    def test_stored_proof_passes(self):
        self.assertTrue(json.loads((OUT / "joins-proof.json").read_text())["passes"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    ARGS, rest = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0]] + rest)
