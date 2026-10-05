#!/usr/bin/env python3
"""Actual-source adversaries for complete assembly geometry, input closure and finite image compilation."""
import copy
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import numpy as np

import compile_assembly as C

B, I = C.B, C.I
HERE = Path(__file__).resolve().parent
CANDIDATE = HERE/"candidate-8"


class SourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report, cls.clips = B.sources(CANDIDATE)
        cls.cases, cls.parts, cls.rig, cls.topology, cls.roots, _, _, _, cls.pins = I.source_inputs()
        with (I.ROOT/"godot/demo/assets/underground-matrices/world-yaw-v1.ugyaw").open("rb") as stream:
            cls.basis = B.N.CardinalBasis(stream, I.M.BASIS_SHA, I.M.BASIS_PRODUCER)
        cls.terrain = json.loads((CANDIDATE/"proof-1.json").read_text())
        cls.tool = json.loads((CANDIDATE/"tool-body-1.json").read_text())
        cls.images = B.candidate_pins(CANDIDATE)

    def interval(self):
        original = self.clips[1]
        return dict(original, frames=2, matrices=original["matrices"][:2].copy(),
                    grounding=original["grounding"][:2].copy())

    def prove(self, clip):
        return B.prove_clip("seat", clip, [0, 0], self.parts, self.topology,
                            self.rig, self.roots, self.basis, 14014)

    def test_full_candidate_and_exact_source_admission(self):
        C.proof_inputs(self.terrain, self.images, self.pins)
        C.proof_inputs(self.tool, self.images, self.pins)
        C.proof_census(self.terrain, self.tool)
        self.assertEqual(sum(row["intervals"] for row in self.terrain["clips"]), 109)
        self.assertEqual([row["intervals"] for row in self.tool["results"]], [54, 1, 54])
        self.assertEqual([row["source_part_id"] for row in I.targets()], [1, 8])

    def test_actual_stationary_seat_interval_passes_without_geometry_reduction(self):
        result = self.prove(self.interval())
        self.assertTrue(result["clear"], result["failures"])
        self.assertEqual([v["triangles"] for v in result["parts"]], [10209, 1150])
        self.assertEqual(len(result["hand_contact"]), 2)

    def test_actual_palm_penetration_refuses_even_with_intentional_contact_role(self):
        clip = self.interval()
        clip["matrices"][:, 15, 10] -= np.float32(32/1024)
        result = self.prove(clip)
        self.assertFalse(result["clear"])
        self.assertTrue(any(v["kind"] in ("CONTACT", "BEARER") for v in result["failures"]))

    def test_unplanted_original_right_foot_cannot_claim_both_supports(self):
        clip = self.interval()
        clip["matrices"][:, :9] = self.cases[0]["matrices"][8, :9]
        result = self.prove(clip)
        self.assertFalse(result["clear"])
        self.assertTrue(any(v["kind"] == "FOOT" and v["foot"] == 1 for v in result["failures"]))

    def test_disjoint_endpoint_images_do_not_waive_complete_swept_body(self):
        clip = self.interval()
        clip["matrices"][0, :, 9] -= np.float32(4096/1024)
        clip["matrices"][1, :, 9] += np.float32(4096/1024)
        for at in range(2):
            for part in range(2):
                points = B.A.G.source_positions(self.parts[0], clip["matrices"][at], clip["grounding"][at]) if part == 0 else I.M.I.I.prop_points(clip, at, self.parts[1])
                self.assertTrue(points[:, 0].max() < -256 if at == 0 else points[:, 0].min() > 1856)
        result = self.prove(clip)
        self.assertFalse(result["clear"])
        self.assertTrue(any(v["kind"] == "BEARER" for v in result["failures"]))

    def test_foreign_candidate_digest_refuses(self):
        wrong = dict(self.images, **{"seat.npz": "0"*64})
        with self.assertRaisesRegex(ValueError, "PROOF_IDENTITY"):
            C.proof_inputs(self.terrain, wrong, self.pins)

    def test_foreign_source_or_self_labelled_qualification_refuses(self):
        for mutation in ("source_inputs", "production_qualified", "all_clear"):
            packet = copy.deepcopy(self.terrain)
            packet[mutation] = {} if mutation == "source_inputs" else mutation == "production_qualified"
            with self.subTest(mutation=mutation), self.assertRaisesRegex(ValueError, "PROOF_IDENTITY"):
                C.proof_inputs(packet, self.images, self.pins)

    def test_omitted_support_interval_and_complete_part_refuse(self):
        for mutation in ("support", "part", "interval", "contact"):
            packet = copy.deepcopy(self.terrain)
            if mutation == "support": packet["clips"][0]["full_foot_support"].pop()
            elif mutation == "part": packet["clips"][1]["parts"][0]["triangles"] -= 1
            elif mutation == "interval": packet["clips"][0]["intervals"] -= 1
            else: packet["clips"][1]["hand_contact"].pop()
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                C.proof_census(packet, self.tool)

    def test_removed_tool_triangle_or_interval_refuses(self):
        for mutation in ("tool_triangles", "rendered_edges", "intentional_grip_triangles"):
            packet = copy.deepcopy(self.tool)
            if mutation == "rendered_edges": packet["results"][0][mutation].pop()
            else: packet["results"][0][mutation] -= 1
            with self.subTest(mutation=mutation), self.assertRaisesRegex(ValueError, "FULL_TOOL_BODY"):
                C.proof_census(self.terrain, packet)

    def test_npz_huge_shape_refuses_before_numpy_materialization(self):
        with tempfile.TemporaryDirectory(prefix="assembly-loader-") as folder:
            path = Path(folder)/"bad.npz"
            payload = io.BytesIO()
            np.lib.format.write_array_header_1_0(payload, {"descr": "<f4", "fortran_order": False,
                                                        "shape": (2147483647, 25, 12)})
            with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as stream:
                stream.writestr("matrices.npy", payload.getvalue())
                stream.writestr("grounding.npy", payload.getvalue())
            with patch.object(B.L.np, "frombuffer", side_effect=AssertionError("materialized")):
                with self.assertRaises(ValueError): B.L.load_case(path, 0)


if __name__ == "__main__":
    unittest.main()
