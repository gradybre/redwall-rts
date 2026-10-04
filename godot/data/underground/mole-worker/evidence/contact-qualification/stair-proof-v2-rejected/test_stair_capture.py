#!/usr/bin/env python3
"""Small source/metadata/census checks for the native stair study; no renderer is invoked."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("stair_capture", Path(__file__).with_name("run_stair_capture.py"))
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)


class StairCaptureTests(unittest.TestCase):
    def fixture(self, directory):
        candidate = {"attempts": [{"status": "SOURCE_CANDIDATE_ONLY", "rise_u": 128, "run_u": 512,
                                  "phase_frames": 30, "edge_z_u": -169}], "production_qualified": False}
        raw = json.dumps(candidate).encode()
        plan = b'{}'
        image = bytearray(184)
        image[:8] = b"UGACNT01"
        image[120:152], image[152:184] = hashlib.sha256(raw).digest(), hashlib.sha256(plan).digest()
        for name, value in (("mole-worker.ugactor", image), ("candidate.json", raw), ("plan.json", plan)):
            (directory/name).write_bytes(value)
        (directory/"compilation.json").write_text(json.dumps({"content_sha256": hashlib.sha256(image).hexdigest()}))
        return candidate

    def test_same_bytes_bind_source_metadata(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.fixture(root)
            _, cases = A.source_metadata(root)
            self.assertEqual(cases, [{"rise_u": 128, "run_u": 512, "phase_frames": 30, "edge_z_u": -169}])
            (root/"candidate.json").write_text('{}')
            with self.assertRaisesRegex(ValueError, "STEP_NATIVE_METADATA"):
                A.source_metadata(root)

    def test_replaced_image_refuses(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.fixture(root)
            (root/"mole-worker.ugactor").write_bytes(b"replaced")
            with self.assertRaisesRegex(ValueError, "STEP_NATIVE_IMAGE"):
                A.source_metadata(root)

    def test_partial_or_claimed_qualification_report_refuses(self):
        spec = {"content_sha256": "a"*64, "stair_cases": [{"rise_u": 128}]}
        report = {**spec, "poses": 543, "assertions": 1100, "failures": [], "production_qualified": False,
                  "screenshots": [{} for _ in range(30)]}
        self.assertEqual(A.validate_report(report, spec)["poses"], 543)
        for field, value in (("poses", 542), ("assertions", 0), ("failures", ["failure"]),
                             ("production_qualified", True), ("screenshots", []), ("stair_cases", [])):
            changed = copy.deepcopy(report)
            changed[field] = value
            with self.assertRaisesRegex(ValueError, "STEP_NATIVE_REPORT"):
                A.validate_report(changed, spec)


if __name__ == "__main__":
    unittest.main()
