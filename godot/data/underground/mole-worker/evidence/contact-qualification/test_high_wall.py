"""Independent synthetic source-motion/contact witnesses; fixtures never grant gameplay geometry."""
import copy
from fractions import Fraction
import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import numpy as np

SPEC = importlib.util.spec_from_file_location("wall_proof", Path(__file__).with_name("prove_high_wall.py"))
W = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(W)
H, P = W.H, W.P
RUN_SPEC = importlib.util.spec_from_file_location("wall_capture", Path(__file__).with_name("run_high_wall.py"))
RUN = importlib.util.module_from_spec(RUN_SPEC)
RUN_SPEC.loader.exec_module(RUN)


class WallSource(unittest.TestCase):
    def test_retraction_preserves_every_unowned_bone_both_endpoints_and_actual_segment_lengths(self):
        matrices = np.zeros((5, 25, 12), dtype=np.float32)
        matrices[:, :, [0, 4, 8]] = 1
        matrices[:, :, 9:] = np.arange(75, dtype=np.float32).reshape(25, 3) / 100
        source = {"frames": 5, "matrices": matrices, "grounding": np.zeros(5, dtype=np.float32)}
        inverse = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]
        rig = {"bones": [{"name": "RightShoulder", "inverse_bind": inverse} for _ in range(24)]}
        before = matrices.copy()
        result = H.retract_entry(source, rig, 15)
        np.testing.assert_array_equal(matrices, before)
        np.testing.assert_array_equal(result["matrices"][[0, -1]], before[[0, -1]])
        unchanged = [bone for bone in range(25) if bone not in (16, 17, 18, 19, 24)]
        np.testing.assert_array_equal(result["matrices"][:, unchanged], before[:, unchanged])
        np.testing.assert_array_equal(result["grounding"], source["grounding"])
        for a, b in ((16, 17), (17, 18), (18, 19), (19, 24)):
            np.testing.assert_allclose(np.linalg.norm(result["matrices"][:, a, 9:] - result["matrices"][:, b, 9:], axis=1),
                                       np.linalg.norm(before[:, a, 9:] - before[:, b, 9:], axis=1), rtol=2e-6, atol=0)
        for degrees in (-1, 31, True):
            with self.assertRaises(P.envelope.Refused):
                H.retract_entry(source, rig, degrees)

    def test_native_point_evidence_must_follow_every_axis_of_exact_source_equation(self):
        fraction = lambda value: {"numerator": Fraction(value).numerator, "denominator": Fraction(value).denominator}
        witness = {"endpoint_ideal_m": [[fraction(v) for v in row] for row in ((0, 1, 0), (1, 2, -1))],
                   "residual_m": [fraction(Fraction(1, 1024))] * 3}
        report = {"native_tip": [{"share_q16": step * 8192, "local_point_u": [128 * step, 1024 + 128 * step, -128 * step]}
                                 for step in range(9)]}
        W.native_tip_refusal(report, witness)
        for axis in range(3):
            wrong = copy.deepcopy(report)
            wrong["native_tip"][4]["local_point_u"][axis] += 2
            with self.assertRaisesRegex(P.envelope.Refused, "SOURCE_ENCLOSURE"):
                W.native_tip_refusal(wrong, witness)
        with self.assertRaisesRegex(P.envelope.Refused, "CENSUS"):
            W.native_tip_refusal({"native_tip": report["native_tip"][:-1]}, witness)
        wrong = copy.deepcopy(report)
        wrong["native_tip"][0]["local_point_u"][0] = float("nan")
        with self.assertRaisesRegex(P.envelope.Refused, "FINITE"):
            W.native_tip_refusal(wrong, witness)

    def test_entire_candidate_is_rederived_and_rejects_unowned_motion_or_timing_drift(self):
        parent = []
        for clip in range(9):
            count = 37 if clip == 6 else (31 if clip in (7, 8) else 4)
            matrices = np.zeros((count, 25, 12), dtype=np.float32)
            matrices[:, :, [0, 4, 8]] = 1
            parent.append({"frames": count, "matrices": matrices, "grounding": np.zeros(count, dtype=np.float32),
                           "source_loop_mode": 1 if clip <= 6 else 0,
                           "source_duration_s": Fraction(count - 1, 30), "duration_q16": (count - 1) * 65536})
        inverse = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]
        rig = {"bones": [{"name": "RightShoulder", "inverse_bind": inverse} for _ in range(24)]}
        cases = copy.deepcopy(parent)
        cases[6] = P.indexed_sequence(parent[6], list(range(14)) + list(range(12, -1, -1)), "test", True)
        cases[7] = H.retract_entry(parent[7], rig, 15)
        cases[8] = P.indexed_sequence(cases[7], list(range(30, -1, -1)), "reverse", False)
        recipe = cases[7]["entry_recipe"]
        W.source_cases_refusal(cases, parent, rig, recipe)
        for clip in (0, 6, 7, 8):
            wrong = copy.deepcopy(cases)
            wrong[clip]["matrices"][1, 20, 9] = 1  # A plausible but unowned head translation.
            with self.assertRaisesRegex(P.envelope.Refused, "MOTION_DRIFT"):
                W.source_cases_refusal(wrong, parent, rig, recipe)
        wrong = copy.deepcopy(cases)
        wrong[0]["source_loop_mode"] = 0
        with self.assertRaisesRegex(P.envelope.Refused, "MOTION_DRIFT"):
            W.source_cases_refusal(wrong, parent, rig, recipe)
        with self.assertRaisesRegex(P.envelope.Refused, "RECIPE"):
            W.source_cases_refusal(cases, parent, rig, dict(recipe, maximum_yaw_degrees=10))

    def test_evidence_json_is_bounded_before_decode(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "report.json"
            path.write_text('{"ok": true}')
            self.assertEqual(W.read_record(path), {"ok": True})
            with self.assertRaisesRegex(P.envelope.Refused, "CAPACITY"):
                W.read_record(path, 1)
            path.write_text('[]')
            with self.assertRaisesRegex(P.envelope.Refused, "FORMAT"):
                W.read_record(path)

    def test_capture_requires_complete_positive_source_bound_evidence(self):
        table = [(0, 2, 1, 65536)] * 9
        table[6] = (10, 27, 1, 26 * 65536)
        table[7] = (37, 31, 0, 30 * 65536)
        table[8] = (68, 31, 0, 30 * 65536)
        spec = {"content_sha256": "a" * 64, "source_frame_indices": list(range(27))}
        report = {"content_sha256": spec["content_sha256"], "source_frame_indices": spec["source_frame_indices"],
                  "production_qualified": False, "failures": [], "poses": 537, "assertions": 1283,
                  "screenshots": ["actual.png"], "native_tip": [{"share_q16": step * 8192,
                    "local_point_u": [1, 2, 3]} for step in range(9)]}
        self.assertEqual(RUN.validate_report(report, spec, table)["poses"], 537)
        for key, value in (("poses", 1), ("assertions", 0), ("failures", ["failed"]),
                           ("production_qualified", True), ("content_sha256", "b" * 64),
                           ("native_tip", report["native_tip"][:-1]), ("screenshots", [])):
            with self.assertRaises(ValueError):
                RUN.validate_report(dict(report, **{key: value}), spec, table)

    def test_import_restoration_is_hash_bound_cache_only_and_preflights_every_entry(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            directory = root / "godot/.godot/imported"
            directory.mkdir(parents=True)
            archive = root / "archive"
            archive.mkdir()
            digest = hashlib.sha256(b"accepted cache").hexdigest()
            (archive / (digest + ".input")).write_bytes(b"accepted cache")
            target = directory / "body.scn"
            target.write_bytes(b"new import UID")
            spec = root / "spec.json"
            rows = [{"path": "res://.godot/imported/body.scn", "sha256": digest},
                    {"path": "res://.godot/imported/second.scn", "sha256": "0" * 64}]
            spec.write_text(json.dumps({"sources": rows}))
            with self.assertRaisesRegex(ValueError, "ARCHIVE"):
                RUN.restore_pinned_imports(spec, archive, root)
            self.assertEqual(target.read_bytes(), b"new import UID")
            rows.pop()
            spec.write_text(json.dumps({"sources": rows}))
            self.assertEqual(len(RUN.restore_pinned_imports(spec, archive, root)), 1)
            self.assertEqual(target.read_bytes(), b"accepted cache")
            rows[0]["path"] = "res://.godot/imported/../../../scripts/actor.scn"
            spec.write_text(json.dumps({"sources": rows}))
            with self.assertRaisesRegex(ValueError, "PATH"):
                RUN.restore_pinned_imports(spec, archive, root)

    def test_historical_snapshot_is_one_pinned_script_and_other_drift_still_refuses(self):
        self.assertEqual(hashlib.sha256(W.historical_profile_bytes(W.HISTORICAL_PROFILE)).hexdigest(), W.HISTORICAL_PROFILE)
        with self.assertRaisesRegex(P.envelope.Refused, "SOURCE_PIN"):
            W.historical_profile_bytes("0" * 64)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            (root / "godot/scripts/core").mkdir(parents=True)
            profile = root / "godot/scripts/core/underground_profiles.gd"
            profile.write_bytes(b"current accepted API")
            asset = root / "godot/asset.bin"
            asset.write_bytes(b"exact mesh")
            manifest = root / "godot/manifest.json"
            manifest.write_bytes(b"{}")
            historical = b"exact prior API"
            row = lambda name, data: {"path": name, "sha256": hashlib.sha256(data).hexdigest()}
            metadata = {"manifest": row("res://manifest.json", b"{}"), "sources": [
                row("res://scripts/core/underground_profiles.gd", historical), row("res://asset.bin", b"exact mesh")]}
            snapshot = root / "view"
            snapshot.mkdir()
            with patch.object(P, "ROOT", root), patch.object(W, "historical_profile_bytes", return_value=historical):
                restored = W.snapshot_sources(metadata, snapshot)
            self.assertEqual(list(restored), ["res://scripts/core/underground_profiles.gd"])
            self.assertEqual(P.envelope.verify_palette_sources(metadata, project_root=snapshot), 3)
            self.assertEqual(profile.read_bytes(), b"current accepted API")
            asset.write_bytes(b"drifted mesh")
            with self.assertRaisesRegex(P.envelope.Refused, "SOURCE_DRIFT"):
                P.envelope.verify_palette_sources(metadata, project_root=snapshot)
            metadata["sources"][1]["path"] = "res://../../escape.bin"
            with patch.object(P, "ROOT", root), patch.object(W, "historical_profile_bytes", return_value=historical):
                with self.assertRaisesRegex(P.envelope.Refused, "SNAPSHOT_PATH"):
                    W.snapshot_sources(metadata, snapshot)


if __name__ == "__main__":
    unittest.main()
