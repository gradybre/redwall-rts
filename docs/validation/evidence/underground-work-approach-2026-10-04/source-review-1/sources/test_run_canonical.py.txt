#!/usr/bin/env python3
"""Bounded native-audit mutants against the retained actual successful replay; never rerun the engine."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("canonical_audit_under_test", HERE / "run_canonical.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
EVIDENCE = M.ROOT / "docs/validation/evidence/underground-work-approach-2026-10-04"
REPLAY = EVIDENCE / "native-2"


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
        path.unlink()  # Break the read-only input alias before writing a mutant.
        path.write_bytes(raw)

    def report_mutant(self, mutate, code):
        report = json.loads((self.out / "report.json").read_text())
        mutate(report)
        self.replace("report.json", (json.dumps(report) + "\n").encode())
        with self.assertRaisesRegex(ValueError, code):
            M.validate(self.out)

    def test_actual_complete_replay(self):
        result = M.validate(self.out)
        self.assertEqual(result["exact_native_scalar_comparisons"], 469248)
        self.assertFalse(result["production_qualified"])

    def test_wire_independently_matches_root_diagnostic(self):
        proof = M.json_read(EVIDENCE / "source-4/approach-program.json", 4194304)
        wire = M.diagnostic_wire(proof)
        self.assertEqual(hashlib.sha256(wire).hexdigest(),
                         "a581f90aa0db07187a1dfc1f0836bd7f3de39d401ff944db07a3958649b1c204")
        wrong = copy.deepcopy(proof)
        wrong["rows"][0]["roles"]["BODY_HELD_LOAD"].pop()
        with self.assertRaisesRegex(ValueError, "WHOLE_BOXES"):
            M.diagnostic_wire(wrong)

    def test_every_pose_is_required(self):
        self.report_mutant(lambda r: r["events"].pop(), "EVENT_COUNT")

    def test_backward_body_heading_cannot_follow_path(self):
        self.report_mutant(lambda r: r["events"][150].update(yaw=32768), "EVENT")

    def test_phase_and_render_source_must_match(self):
        self.report_mutant(lambda r: r["events"][93]["frames"].__setitem__(0, 0), "EVENT")

    def test_root_cannot_teleport(self):
        self.report_mutant(lambda r: r["events"][100]["point"].__setitem__(0, 1537), "EVENT")

    def test_native_corruption_refuses_even_after_rehash(self):
        raw = bytearray((self.out / "native.bin").read_bytes())
        raw[8] ^= 1
        self.replace("native.bin", raw)
        self.report_mutant(lambda r: r.update(native_sha256=hashlib.sha256(raw).hexdigest()), "NATIVE_MATRIX")

    def test_source_phase_cannot_be_relabelled_productive(self):
        self.report_mutant(lambda r: r["events"][0]["state"].__setitem__(0, 6), "EVENT")

    def test_duplicate_screen_is_not_full_coverage(self):
        self.report_mutant(lambda r: r["screenshots"].__setitem__(0, r["screenshots"][1]), "SCREEN_NAMES")

    def test_native_scope_stays_unqualified(self):
        self.report_mutant(lambda r: r.update(production_qualified=True), "REPORT")

    def test_import_restoration_preserves_original_and_removes_only_new_metadata(self):
        project = self.out / "project"
        project.mkdir()
        original = project / "original.glb.import"
        original.write_bytes(b"original exact import identity")
        keep = project / "source.gd"
        keep.write_bytes(b"unchanged source")
        snapshot = {original: original.read_bytes()}
        original.write_bytes(b"engine replacement")
        generated = project / "new.png.import"
        generated.write_bytes(b"new importer output")
        removed = M.restore_sidecars(project, snapshot)
        self.assertEqual(original.read_bytes(), snapshot[original])
        self.assertEqual(keep.read_bytes(), b"unchanged source")
        self.assertFalse(generated.exists())
        self.assertEqual(removed, {"new.png.import": hashlib.sha256(b"new importer output").hexdigest()})


if __name__ == "__main__":
    unittest.main()
