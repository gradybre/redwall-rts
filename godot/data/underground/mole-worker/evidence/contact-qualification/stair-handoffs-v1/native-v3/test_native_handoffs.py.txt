#!/usr/bin/env python3
"""Adversarial native report/source guards; no engine, cache or accepted source writes."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("native_handoff_runner_test", HERE / "run_native_handoffs.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)


class NativeHandoffTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec, cls.pins = R.build_spec("test-native-handoffs")
        cls.events = R.expected_events(cls.spec)
        cls.report = dict(scope="source_only_stair_handoffs_gl", production_qualified=False,
            gameplay_rate_adopted=False, actual_world_playback=False, metal_qualified=False,
            renderer="gl_compatibility", failures=[], user_directory="/tmp/test-native-handoffs",
            poses=3795, assertions=200000, bone_checks=3795 * 24, world_checks=3795 * 2, fixture_parts=22,
            program_content_sha256=cls.spec["program_content_sha256"], basis_sha256=cls.spec["basis_sha256"],
            events=cls.events, joins=R.expected_joins(cls.spec),
            screenshots=[dict(path=p, clip=c, half_tick=t, sha256="0" * 64) for p, c, t in R.expected_shots(cls.spec)])

    def refused(self, report, code):
        with self.assertRaisesRegex(ValueError, code):
            R.validate_report(report, self.spec)

    def test_complete_real_source_oracle_and_exact_joins(self):
        result = R.validate_report(self.report, self.spec)
        self.assertEqual((result["poses"], result["joins"], result["screenshots"]), (3795, 12, 93))
        self.assertGreater(len(self.pins), 300)
        self.assertEqual([p["name"] for p in self.spec["programs"]], list(R.ORDER))
        self.assertEqual(self.events[0]["root_u"], [0, 0, -1536])
        self.assertEqual(self.events[-1]["root_u"], [0, 0, -1536])
        self.assertEqual(self.events[-1]["yaw"], 32768)
        for event in self.events:
            p = next(p for p in self.spec["programs"] if p["name"] == event["program"])
            if event["half_tick"] in (0, p["intervals"] * 2):
                self.assertEqual(event["palette_sha256"], R.READY)

    def test_signed_local_ceil_precedes_sign_changing_orientation(self):
        program = dict(intervals=1, keys=[[0, 0, -1, 32768, 1], [0, 0, 0, 32768, 1]],
            root_frame="local_then_fixed_quarter_turn", quarter_turn=2, origin_u=[0, -128, -2217])
        self.assertEqual(R.phase_state(program, 32768), [0, -128, -2217, 32768])
        # Incorrectly rotating before ceil would move the root one extra positive unit.
        self.assertNotEqual(R.phase_state(program, 32768)[2], -2216)

    def test_moving_heading_does_not_rotate_fixed_root(self):
        turn = self.spec["programs"][2]
        state = R.phase_state(turn, 90 * R.ONE + R.ONE // 2)
        self.assertNotIn(state[3], (0, 32768))
        self.assertEqual(state[0], 0)
        self.assertLess(state[2], -2200)

    def test_terminal_is_last_last_zero(self):
        for p in self.spec["programs"]:
            last = next(e for e in self.events if e["view"] == "side" and e["program"] == p["name"]
                        and e["half_tick"] == p["intervals"] * 2)
            self.assertEqual(last["frames"], [p["first_frame"] + p["intervals"]] * 2 + [0])
        with self.assertRaisesRegex(ValueError, "PHASE"):
            R.phase_state(self.spec["programs"][0], -1)

    def test_partial_or_empty_native_census_refuses(self):
        for field, value in (("poses", 0), ("bone_checks", 3795 * 24 - 1), ("world_checks", 0),
                             ("fixture_parts", 21), ("assertions", 0)):
            bad = copy.deepcopy(self.report)
            bad[field] = value
            self.refused(bad, "CENSUS")

    def test_deleted_stationary_phase_and_bad_midpoint_refuse(self):
        bad = copy.deepcopy(self.report)
        bad["events"][1] = copy.deepcopy(bad["events"][0])
        self.refused(bad, "EXACT_EVENTS")
        bad = copy.deepcopy(self.report)
        bad["events"][1]["frames"][2] = 0
        self.refused(bad, "EXACT_EVENTS")

    def test_wrong_root_or_source_matrix_digest_refuses(self):
        for field, value in (("root_u", [1, 0, -1536]), ("palette_sha256", "f" * 64), ("yaw", 32768)):
            bad = copy.deepcopy(self.report)
            bad["events"][0][field] = value
            self.refused(bad, "EXACT_EVENTS")

    def test_missing_or_reordered_join_refuses(self):
        bad = copy.deepcopy(self.report)
        bad["joins"].pop()
        self.refused(bad, "EXACT_JOINS")
        bad = copy.deepcopy(self.report)
        bad["joins"][0]["to"] = "ascent"
        self.refused(bad, "EXACT_JOINS")

    def test_bad_backend_permission_or_failures_refuse(self):
        for field, value in (("renderer", "forward_plus"), ("production_qualified", True),
                             ("actual_world_playback", True), ("gameplay_rate_adopted", True),
                             ("metal_qualified", True), ("failures", ["native failure"])):
            bad = copy.deepcopy(self.report)
            bad[field] = value
            self.refused(bad, "SCOPE")

    def test_missing_images_wrong_name_or_wrong_content_refuse(self):
        bad = copy.deepcopy(self.report)
        bad["screenshots"].pop()
        self.refused(bad, "IMAGES")
        bad = copy.deepcopy(self.report)
        bad["screenshots"][0]["path"] = "../unrelated.png"
        self.refused(bad, "IMAGES")
        bad = copy.deepcopy(self.report)
        bad["program_content_sha256"][1] = "0" * 64
        self.refused(bad, "SOURCE_IDENTITY")

    def test_existing_output_and_dangling_link_preserve_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp) / "run"
            out.mkdir()
            witness = out / "report.json"
            witness.write_bytes(b"retained")
            with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
                R.run(out)
            self.assertEqual(witness.read_bytes(), b"retained")
            link = Path(temp) / "dangling"
            link.symlink_to(Path(temp) / "absent")
            with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
                R.run(link)
            self.assertTrue(link.is_symlink())

    def test_actual_spec_fits_native_predecode_limit_and_is_create_only(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "spec.json"
            R.write_json(path, self.spec, compact=True)
            self.assertLess(path.stat().st_size, 65536)
            self.assertEqual(R.bounded_json(path, 65536), self.spec)
            before = path.read_bytes()
            with self.assertRaises(FileExistsError):
                R.write_json(path, {})
            self.assertEqual(path.read_bytes(), before)

    def test_runtime_spec_drift_never_refreshes_hashes(self):
        original = R.digest
        with patch.object(R, "digest", side_effect=lambda p: "0" * 64 if p.name == "bake-spec.json" else original(p)):
            with self.assertRaisesRegex(ValueError, "RUNTIME_PINS"):
                R.runtime_bake()
        self.assertEqual(R.digest(R.runtime_bake()), R.BAKE_SHA)

    def test_accepted_manifest_drift_refuses_before_native(self):
        original = R.digest
        with patch.object(R, "digest", side_effect=lambda p: "0" * 64 if p.name == "source-sha256.json" else original(p)):
            with self.assertRaisesRegex(ValueError, "REVIEW_MANIFEST"):
                R.reviewed_pins()

    def test_original_obsolete_execution_bake_stays_refused(self):
        with self.assertRaisesRegex(ValueError, "HIGH_WALL_PREIMPORT_SOURCE"):
            R.H.pre_import_pins(HERE / "capture_stair_handoffs.gd", R.P / "high-wall-runtime-sources-v1/bake-spec.json")


if __name__ == "__main__":
    unittest.main()
