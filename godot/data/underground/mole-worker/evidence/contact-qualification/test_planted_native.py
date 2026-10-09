"""Actual retained source target checks and adversarial body/entry/support refusals; no gameplay permission."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("planted_native", HERE / "verify_planted_native.py")
V = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V)


class PlantedTarget(unittest.TestCase):
    def setUp(self):
        self.candidate = json.loads((HERE / "planted-front-source-v4/candidate.json").read_text())

    def test_actual_complete_forward_geometry_and_full_foot_projection_fit_fixture(self):
        V.target_refusal(self.candidate)
        self.assertEqual(self.candidate["foot_support"]["work"]["support_u"], [-274, -1, -169, 299, 0, 174])
        self.assertEqual(self.candidate["plane_portions"]["work"][1]["forward"], [-129, 189, -814, 15, 717, -768])

    def test_body_or_entry_penetration_refuses_even_when_tip_and_stroke_are_valid(self):
        for phase, part in (("work", 0), ("entry", 0), ("entry", 1)):
            changed = copy.deepcopy(self.candidate)
            changed["plane_portions"][phase][part]["forward"] = [0, 700, -770, 1, 701, -768]
            with self.assertRaisesRegex(V.P.envelope.Refused, "BODY_OR_ENTRY"):
                V.target_refusal(changed)

    def test_tool_reaching_above_target_or_missing_positive_stroke_refuses(self):
        for value in (None, [-129, 189, -814, 15, 769, -768], [-513, 189, -814, 15, 717, -768]):
            changed = copy.deepcopy(self.candidate)
            changed["plane_portions"]["work"][1]["forward"] = value
            with self.assertRaisesRegex(V.P.envelope.Refused, "TARGET_STROKE"):
                V.target_refusal(changed)

    def test_full_stance_cannot_extend_off_tread_or_use_inverted_or_boolean_coordinates(self):
        for phase in ("work", "entry"):
            changed = copy.deepcopy(self.candidate)
            changed["foot_support"][phase]["support_u"][5] = 257
            with self.assertRaisesRegex(V.P.envelope.Refused, "TARGET_SUPPORT"):
                V.target_refusal(changed)
        self.assertFalse(V.in_box([0, 0, 1, 1, 1, 0], [-1, -1, -1, 2, 2, 2]))
        self.assertFalse(V.in_box([False, 0, 0, 1, 1, 1], [-1, -1, -1, 2, 2, 2]))

    def test_changed_target_metadata_cannot_borrow_an_unchanged_image_and_source_proof(self):
        source = HERE / "planted-front-source-v4"
        expected = json.loads((source / "compilation.json").read_text())["content_sha256"]
        V.bound_metadata_refusal(source / "mole-worker.ugactor", expected, source / "candidate.json", source / "plan.json")
        with tempfile.TemporaryDirectory() as directory:
            candidate, plan = Path(directory) / "candidate.json", Path(directory) / "plan.json"
            candidate.write_bytes((source / "candidate.json").read_bytes())
            plan.write_bytes((source / "plan.json").read_bytes())
            for target in (candidate, plan):
                prior = target.read_bytes()
                target.write_bytes(prior + b" ")
                with self.assertRaisesRegex(V.P.envelope.Refused, "METADATA_BINDING"):
                    V.bound_metadata_refusal(source / "mole-worker.ugactor", expected, candidate, plan)
                target.write_bytes(prior)
        with self.assertRaisesRegex(V.P.envelope.Refused, "IMAGE_SOURCE"):
            V.bound_metadata_refusal(source / "mole-worker.ugactor", "0" * 64, source / "candidate.json", source / "plan.json")

    def test_exact_native_point_guard_rejects_drift_and_partial_timeline(self):
        report = json.loads((HERE / "native-planted-front-v1/report.json").read_text())
        witness = json.loads((HERE / "planted-native-proof-v2.json").read_text())["witness"]
        V.W.native_tip_refusal(report, witness)
        changed = copy.deepcopy(report)
        changed["native_tip"][4]["local_point_u"][0] += 3
        with self.assertRaisesRegex(V.P.envelope.Refused, "SOURCE_ENCLOSURE"):
            V.W.native_tip_refusal(changed, witness)
        with self.assertRaisesRegex(V.P.envelope.Refused, "CENSUS"):
            V.W.native_tip_refusal(dict(report, native_tip=report["native_tip"][:-1]), witness)


if __name__ == "__main__":
    unittest.main()
