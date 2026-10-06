#!/usr/bin/env python3
"""The captured procedural stone lump (ADR 1206): exact pins and a closed, finite, indexed topology.

Optional `--godot <binary>` re-runs the native capture into a temporary file and requires identical bytes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
EVIDENCE = HERE / "evidence/stone-source-v1"
CAPTURE = "res://data/underground/mole-worker/haul-handling-v1/native_capture_stone/capture_stone.gd"
ARGS = None


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class StoneSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pins = json.loads((EVIDENCE / "source-sha256.json").read_text())
        cls.stone = json.loads((EVIDENCE / "native-stone.json").read_text())

    def test_every_pinned_source_and_output_is_unchanged(self):
        for name, expected in self.pins.items():
            self.assertEqual(digest(ROOT / name), expected, name)

    def test_factory_digest_matches_the_live_dressing_source(self):
        self.assertEqual(self.stone["factory_sha256"], digest(ROOT / "godot/demo/tunnel/bore_dressing.gd"))

    def test_topology_is_indexed_triangles_over_every_vertex(self):
        points, indices = self.stone["points"], self.stone["indices"]
        self.assertEqual((self.stone["vertex_count"], len(points), len(indices)), (70, 70, 324))
        self.assertEqual(self.stone["primitive"], 3)
        self.assertTrue(all(0 <= i < len(points) for i in indices))
        self.assertEqual(set(indices), set(range(len(points))))

    def test_unit_lump_bounds_contain_every_point(self):
        bounds = self.stone["bounds"]
        for axis in range(3):
            values = [p[axis] for p in self.stone["points"]]
            # Godot's AABB is float32 position + size; its far corner may round by one ulp.
            self.assertEqual(min(values), bounds[axis])
            self.assertAlmostEqual(max(values), bounds[axis] + bounds[axis + 3], delta=1e-6)
        self.assertTrue(1.9 < min(bounds[3:]) and max(bounds[3:]) < 2.5)

    def test_native_capture_is_reproducible(self):
        if ARGS is None or ARGS.godot is None:
            self.skipTest("pass --godot to re-run the native capture")
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "native-stone.json"
            subprocess.run([ARGS.godot, "--headless", "--path", str(ROOT / "godot"), "--script", CAPTURE, "--",
                            str(out)], check=True, capture_output=True)
            self.assertEqual(out.read_bytes(), (EVIDENCE / "native-stone.json").read_bytes())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot")
    ARGS, rest = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0]] + rest)
