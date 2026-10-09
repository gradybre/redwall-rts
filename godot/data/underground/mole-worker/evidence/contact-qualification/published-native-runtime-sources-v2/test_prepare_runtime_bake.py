#!/usr/bin/env python3
"""Adversarial native-input derivation; no native renderer or profile qualification."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("renewed_native_inputs", HERE / "prepare_runtime_bake.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)


class RuntimeInputTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.prior = json.loads(R.PRIOR.read_text())

    def test_exact_previous_packet_and_three_immutable_current_blobs(self):
        self.assertEqual(R.digest(R.PRIOR), R.PRIOR_SHA)
        for name, (_, expected) in R.CHANGES.items():
            raw = subprocess.check_output(["git", "cat-file", "blob",
                R.SOURCE_COMMIT + ":godot/" + name[6:]], cwd=R.ROOT)
            self.assertEqual(hashlib.sha256(raw).hexdigest(), expected)

    def test_exact_closed_derivation_preserves_every_other_fact(self):
        before = copy.deepcopy(self.prior)
        with patch.object(R, "verify_row", return_value=1) as verify:
            after = R.renew_record(self.prior, R.ROOT)
        self.assertEqual(self.prior, before)
        self.assertEqual(verify.call_count, 537)
        self.assertEqual({k: v for k, v in before.items() if k not in ("sources", "runtime_closure_refresh")},
                         {k: v for k, v in after.items() if k not in ("sources", "runtime_closure_refresh")})
        for old, new in zip(before["sources"], after["sources"], strict=True):
            expected = dict(old)
            if old["path"] in R.CHANGES:
                expected["sha256"] = R.CHANGES[old["path"]][1]
            if old["path"].startswith(str(R.OLD_ROOT) + "/"):
                expected["path"] = str(R.ROOT / Path(old["path"]).relative_to(R.OLD_ROOT))
            self.assertEqual(new, expected)
        self.assertFalse(after["production_qualified"])
        self.assertEqual(after["qualified_profile_count"], 0)

    def test_missing_or_duplicate_source_refuses(self):
        for which in ("missing", "duplicate"):
            record = copy.deepcopy(self.prior)
            if which == "missing":
                record["sources"].pop()
            else:
                record["sources"][1] = record["sources"][0]
            with patch.object(R, "verify_row", return_value=1), self.assertRaises(ValueError):
                R.renew_record(record, R.ROOT)

    def test_wrong_prior_digest_is_not_approved_current_source(self):
        record = copy.deepcopy(self.prior)
        next(row for row in record["sources"] if row["path"] in R.CHANGES)["sha256"] = "0" * 64
        with patch.object(R, "verify_row", return_value=1), self.assertRaisesRegex(ValueError, "PRIOR_SOURCE"):
            R.renew_record(record, R.ROOT)

    def test_missing_known_location_and_capacity_refuse(self):
        record = copy.deepcopy(self.prior)
        next(row for row in record["sources"] if row["path"].startswith(str(R.OLD_ROOT)))["path"] = "/missing/file"
        with patch.object(R, "verify_row", return_value=1), self.assertRaisesRegex(ValueError, "CHANGE_CENSUS"):
            R.renew_record(record, R.ROOT)
        with patch.object(R, "verify_row", return_value=R.MAX_TOTAL_BYTES), self.assertRaisesRegex(ValueError, "TOTAL_CAPACITY"):
            R.renew_record(self.prior, R.ROOT)

    def test_unlisted_raw_source_drift_and_symlink_refuse(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "source"
            path.write_bytes(b"actual")
            good = {"path": str(path), "sha256": hashlib.sha256(b"actual").hexdigest()}
            self.assertEqual(R.verify_row(good, R.ROOT), 6)
            with self.assertRaisesRegex(ValueError, "SOURCE_DRIFT"):
                R.verify_row({**good, "sha256": "0" * 64}, R.ROOT)
            link = Path(temp) / "link"
            link.symlink_to(path)
            with self.assertRaisesRegex(ValueError, "INPUT_FILE"):
                R.verify_row({**good, "path": str(link)}, R.ROOT)

    def test_imported_scene_uses_exact_archive_instead_of_current_cache(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            sha = hashlib.sha256(b"scene").hexdigest()
            file = root / R.ARCHIVE / (sha + ".input")
            file.parent.mkdir(parents=True)
            file.write_bytes(b"scene")
            self.assertEqual(R.verify_row({"path": "res://.godot/imported/a.scn", "sha256": sha}, root), 5)
            file.write_bytes(b"changed")
            with self.assertRaisesRegex(ValueError, "SOURCE_DRIFT"):
                R.verify_row({"path": "res://.godot/imported/a.scn", "sha256": sha}, root)

    def test_existing_output_or_dangling_symlink_refuses_before_input(self):
        with tempfile.TemporaryDirectory() as temp:
            path, link = Path(temp) / "old", Path(temp) / "link"
            path.mkdir()
            (path / "evidence").write_bytes(b"unchanged")
            link.symlink_to(Path(temp) / "missing")
            with patch.object(R, "digest", side_effect=AssertionError("must refuse first")):
                for out in (path, link):
                    with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
                        R.execute(out)
            self.assertEqual((path / "evidence").read_bytes(), b"unchanged")


if __name__ == "__main__":
    unittest.main()
