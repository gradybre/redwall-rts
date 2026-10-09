#!/usr/bin/env python3
"""Output/provenance/report guards; no engine or mocked-success qualification."""
import importlib.util
from pathlib import Path
import tempfile
import subprocess
import sys
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("input_capture", Path(__file__).with_name("capture_inputs.py"))
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)


def report():
    return {"error": "", "failures": [], "assertions": 8, "surfaces": 2, "vertices": 18348,
            "content_sha256": C.CONTENT_SHA, "spec_sha256": "f" * 64, "qualified_profiles": 0,
            "meshes": [{"part": 0, "vertices": 17172, "surfaces": 1, "shadow_of": -1},
                       {"part": 1, "vertices": 1176, "surfaces": 1, "shadow_of": -1}],
            "rows": [{}, {}], "gpu_arithmetic_qualified": False, "world_qualified": False, "driver": "metal",
            "method": "forward_plus", "display": "macOS", "engine": {"hash": "ed1daf0bf001b61586d9930840f2f1394092c079"}}


class CaptureTests(unittest.TestCase):
    def test_existing_bundle_or_dangling_output_refuses_before_any_source_work(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)/"evidence"
            output.mkdir(); (output/"report.json").write_text("retained")
            with patch.object(C, "source_pins", side_effect=AssertionError("must not read")):
                with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"): C.capture(output)
                alias = Path(temporary)/"dangling"; alias.symlink_to(Path(temporary)/"missing")
                with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"): C.capture(alias)
            self.assertEqual((output/"report.json").read_text(), "retained")

    def test_external_names_map_only_the_exact_read_only_library_to_own_clone(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(C, "ROOT", Path(temporary).resolve()):
            expected = Path(temporary).resolve()/"assets/library/creature/mole/a.glb"
            expected.parent.mkdir(parents=True); expected.write_bytes(b"input")
            self.assertEqual(C.actual("/Users/brendan/Developer/redwall-rts/assets/library/creature/mole/a.glb"), expected)
            with self.assertRaisesRegex(ValueError, "SOURCE_PATH"): C.actual("/tmp/arbitrary-source.glb")
            link = expected.with_name("link.glb"); link.symlink_to(expected)
            with self.assertRaisesRegex(ValueError, "SOURCE_PATH"): C.actual(str(link))

    def test_positive_complete_report_still_declares_no_gpu_or_world_permission(self):
        C.report_refusal(report(), "f" * 64, "native complete")
        for field, value in (("assertions", 0), ("vertices", 17172), ("surfaces", 1),
                             ("failures", ["bad"]), ("world_qualified", True),
                             ("gpu_arithmetic_qualified", True), ("spec_sha256", "0"*64)):
            row = report(); row[field] = value
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "REPORT"):
                C.report_refusal(row, "f"*64, "")

    def test_auxiliary_mesh_changes_require_complete_positive_census(self):
        row = report()
        row["meshes"].append({"part": 2, "vertices": 100, "surfaces": 1, "shadow_of": 1})
        row["rows"].append({}); row["surfaces"] = 3; row["vertices"] = 18448
        C.report_refusal(row, "f"*64, "")
        row["vertices"] -= 1
        with self.assertRaisesRegex(ValueError, "REPORT"): C.report_refusal(row, "f"*64, "")
        row = report(); row["meshes"][0]["vertices"] = 1
        with self.assertRaisesRegex(ValueError, "REPORT"): C.report_refusal(row, "f"*64, "")

    def test_zero_exit_never_hides_raw_warning_error_or_leak(self):
        for raw in ("WARNING: unsupported", "ERROR: wrong", "SCRIPT ERROR: stopped", "1 ObjectDB instance was leaked"):
            with self.subTest(raw=raw), self.assertRaisesRegex(ValueError, "DIAGNOSTICS"):
                C.report_refusal(report(), "f"*64, raw)

    def test_wrong_backend_or_engine_refuses(self):
        for field, value in (("driver", "opengl3"), ("display", "headless"), ("engine", {"hash": "0"*40})):
            row = report(); row[field] = value
            with self.assertRaisesRegex(ValueError, "BACKEND"): C.report_refusal(row, "f"*64, "")

    def test_strict_wrapper_refuses_dangling_output_before_cache_or_engine(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary)/"missing"
            output = Path(temporary)/"alias"; output.symlink_to(target)
            result = subprocess.run([sys.executable, str(C.HERE/"run_checks.py"), str(output)],
                                    capture_output=True, text=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("METAL_INPUT_CHECK_OUTPUT_EXISTS", result.stderr)
            self.assertFalse(target.exists())
            self.assertTrue(output.is_symlink())

    def test_input_drift_refuses_before_assets_or_native_commands(self):
        with patch.object(C, "sha", return_value="0"*64), patch.object(C, "actual", side_effect=AssertionError("no asset read")):
            with self.assertRaisesRegex(ValueError, "IMMUTABLE_SOURCE"): C.source_pins()


if __name__ == "__main__":
    unittest.main()
