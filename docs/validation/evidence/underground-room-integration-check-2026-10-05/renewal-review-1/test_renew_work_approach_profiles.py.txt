#!/usr/bin/env python3
"""Source-only renewal rejects drift without replacing geometry or enabling work."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("frontier_renewal",
    ROOT / "godot/data/underground/mole-worker/renew_work_approach_profiles.py")
renew = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(renew)


class RenewalTests(unittest.TestCase):
    def test_exact_geometry_and_only_reviewed_source_constants_change(self):
        wire, constants, result = renew.inputs()
        old = json.loads((ROOT / renew.OLD / "manifest.json").read_bytes())
        self.assertEqual(wire, (ROOT / renew.OLD / "mole-worker.ugprof").read_bytes())
        for key in ("wire_sha256", "wire_version", "content_revision", "profile_revision",
                    "certificate_flags", "profile_count", "box_count", "wire_bytes",
                    "paired_bank_bytes", "actor_sha256", "source_program", "mapping",
                    "world_root_bounds_u", "remaining", "world_activation_qualified"):
            self.assertEqual(result[key], old[key], key)
        self.assertFalse(result["world_activation_qualified"])
        self.assertEqual(result["constants_sha256"], renew.digest(constants))
        self.assertEqual(sum(result["consumers"][name] != sha for name, sha in old["consumers"].items()), 3)

    def refuses_mutation(self, path):
        original = Path.read_bytes

        def changed(candidate):
            raw = original(candidate)
            return raw + b"\n" if candidate == path else raw

        with mock.patch.object(Path, "read_bytes", changed):
            with self.assertRaisesRegex(ValueError, "FRONTIER_RENEWAL_HASH"):
                renew.inputs()

    def test_each_current_consumer_is_checked(self):
        review = json.loads((ROOT / renew.REVIEW).read_bytes())
        for name in review["consumer_sources"]:
            with self.subTest(name=name):
                self.refuses_mutation(ROOT / name)

    def test_each_changed_historical_consumer_is_checked(self):
        review = json.loads((ROOT / renew.REVIEW).read_bytes())
        for row in review["changed_consumers"].values():
            with self.subTest(name=row["historical_locator"]):
                self.refuses_mutation(ROOT / row["historical_locator"])

    def test_each_native_proof_byte_is_checked(self):
        review = json.loads((ROOT / renew.REVIEW).read_bytes())
        for name in review["native_report"]:
            with self.subTest(name=name):
                self.refuses_mutation(ROOT / renew.E / "native-1" / name)

    def test_old_proof_and_new_review_cannot_be_rewritten(self):
        for name in (renew.REVIEW, renew.OLD + "manifest.json", renew.OLD + "catalog_source.gd",
                     renew.OLD + "mole-worker.ugprof",
                     "docs/validation/evidence/underground-work-approach-2026-10-04/source-4/approach-program.json"):
            with self.subTest(name=name):
                self.refuses_mutation(ROOT / name)

    def test_current_commit_must_match_review(self):
        with mock.patch.object(renew.subprocess, "check_output", return_value=b"changed source\n"):
            with self.assertRaisesRegex(ValueError, "FRONTIER_RENEWAL_REVIEWED_COMMIT"):
                renew.inputs()

    def test_rejects_output_overwrite_and_escape(self):
        for path in (ROOT / renew.OLD, ROOT / "outside-frontier-publication"):
            with self.subTest(path=path), mock.patch.object(renew, "inputs") as inputs:
                with self.assertRaisesRegex(ValueError, "FRONTIER_RENEWAL_OUTPUT"):
                    renew.publish(path)
                inputs.assert_not_called()

    def test_reader_rejects_escape_alias_and_symlink(self):
        for name in ("../outside", "/tmp/outside", "godot//project.godot", "godot/./project.godot"):
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "FRONTIER_RENEWAL_PATH"):
                renew.read(name, "0" * 64)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "target").write_bytes(b"checked")
            (root / "link").symlink_to(root / "target")
            with mock.patch.object(renew, "ROOT", root), self.assertRaisesRegex(ValueError, "FRONTIER_RENEWAL_FILE"):
                renew.read("link", renew.digest(b"checked"))


if __name__ == "__main__":
    unittest.main()
