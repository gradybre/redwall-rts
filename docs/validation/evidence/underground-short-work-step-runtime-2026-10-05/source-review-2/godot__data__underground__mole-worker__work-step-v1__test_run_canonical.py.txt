#!/usr/bin/env python3
"""Adversarial replay audit against actual retained native output; never launch an engine."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("short_step_native_audit", HERE / "run_canonical.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
REPLAY = M.ROOT / "docs/validation/evidence/underground-short-work-step-runtime-2026-10-05/native-3"


class NativeAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.out = Path(self.temp.name)
        for path in REPLAY.iterdir():
            if path.name in ("report.json", "spec.json", "native.bin") or path.suffix == ".png":
                os.link(path, self.out / path.name)

    def tearDown(self):
        self.temp.cleanup()

    def replace(self, name, raw):
        path = self.out / name
        path.unlink()
        path.write_bytes(raw)

    def mutate(self, action, refusal):
        report = json.loads((self.out / "report.json").read_text())
        action(report)
        self.replace("report.json", (json.dumps(report) + "\n").encode())
        with self.assertRaisesRegex(ValueError, refusal):
            M.validate(self.out)

    def test_actual_complete_sequence(self):
        result = M.validate(self.out)
        self.assertEqual(result["exact_native_scalar_comparisons"], 144144)
        self.assertEqual(result["screenshots"], 46)
        self.assertFalse(result["production_qualified"])

    def test_exact_short_root_ticks_and_fades(self):
        for tick, distance in ((60, 0), (61, 109), (62, 218), (63, 232), (71, 232)):
            self.assertEqual(M.expected(tick, "tick")[2][0], M.FRONT[0] + distance)
        self.assertEqual(M.expected(63, "tick")[1], [3, 0, 3 * M.ONE, 0])
        self.assertEqual(M.expected(71, "tick")[1], [0, 0, 0, 0])

    def test_every_actual_pose_is_required(self):
        self.mutate(lambda r: r["events"].pop(), "CANONICAL_EVENTS")

    def test_ground_heading_is_not_selected_heading(self):
        self.mutate(lambda r: r["events"][4].update(yaw=49152), "CANONICAL_EVENTS")

    def test_backward_body_does_not_turn_with_path(self):
        self.mutate(lambda r: r["events"][166].update(yaw=16384), "CANONICAL_EVENTS")

    def test_short_source_cannot_repeat_from_zero(self):
        self.mutate(lambda r: r["events"][63]["state"].__setitem__(1, 0), "CANONICAL_EVENTS")

    def test_recovery_must_finish_before_turn(self):
        self.mutate(lambda r: r["events"][27]["state"].__setitem__(0, 3), "CANONICAL_EVENTS")

    def test_root_cannot_teleport_to_short_endpoint(self):
        self.mutate(lambda r: r["events"][61]["point"].__setitem__(0, M.HIGH[0]), "CANONICAL_EVENTS")

    def test_native_tool_matrix_cannot_be_relabelled(self):
        raw = bytearray((self.out / "native.bin").read_bytes())
        raw[8 + 24 * 12 * 4] ^= 1
        self.replace("native.bin", raw)
        self.mutate(lambda r: r.update(native_sha256=hashlib.sha256(raw).hexdigest()), "NATIVE_MATRIX")

    def test_exact_native_length_precedes_array_materialization(self):
        raw = (self.out / "native.bin").read_bytes() + b"\0\0\0\0"
        self.replace("native.bin", raw)
        self.mutate(lambda r: r.update(native_sha256=hashlib.sha256(raw).hexdigest()), "NATIVE_BYTES")

    def test_duplicate_frame_cannot_replace_turn_coverage(self):
        self.mutate(lambda r: r["screenshots"].__setitem__(0, r["screenshots"][1]), "SCREEN_CENSUS")

    def test_source_phase_and_visual_frame_stay_paired(self):
        self.mutate(lambda r: r["events"][120]["frames"].__setitem__(0, 0), "CANONICAL_EVENTS")

    def test_diagnostic_scope_cannot_be_upgraded(self):
        self.mutate(lambda r: r.update(production_qualified=True), "NATIVE_REPORT")

    def test_exact_input_relocates_without_historical_checkout(self):
        spec = json.loads((self.out / "spec.json").read_text())
        spec["content"] = "/unavailable/original-checkout/godot/" + M.IMAGE_RELATIVE
        self.replace("spec.json", json.dumps(spec).encode())
        self.assertEqual(M.validate(self.out)["poses"], 462)

    def test_foreign_image_locator_or_digest_cannot_reuse_evidence(self):
        for change in ({"content": "/arbitrary/mole-worker.ugactor"}, {"content_sha256": "0"*64}):
            with self.subTest(change=change):
                spec = json.loads((REPLAY / "spec.json").read_text())
                spec.update(change)
                self.replace("spec.json", json.dumps(spec).encode())
                with self.assertRaisesRegex(ValueError, "IMAGE_LOCATOR"):
                    M.validate(self.out)


if __name__ == "__main__":
    unittest.main()
