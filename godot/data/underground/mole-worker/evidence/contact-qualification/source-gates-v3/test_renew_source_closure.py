#!/usr/bin/env python3
"""Input location changes cannot replace an accepted source, digest or prior output."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("renewed_input_locations", HERE / "renew_source_closure.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


class InputLocationTests(unittest.TestCase):
    def setUp(self):
        self.raw = M.INVOCATION.read_bytes()
        self.record = json.loads(self.raw)

    def test_exact_local_bytes_preserve_all_nonlocation_arguments_and_original_record(self):
        self.assertEqual(hashlib.sha256(self.raw).hexdigest(), M.INVOCATION_SHA)
        original = copy.deepcopy(self.record)
        result = M.localize_record(self.record, M.ROOT)
        changed = [i for i, (a, b) in enumerate(zip(original["command"], result["command"])) if a != b]
        wanted = [M.argument(original["command"], key) for key in (*M.INPUTS, "import-archive")]
        self.assertEqual(sorted(changed), sorted(wanted))
        self.assertEqual(self.record, original)
        self.assertEqual(M.INVOCATION.read_bytes(), self.raw)
        for at in changed:
            self.assertTrue(Path(result["command"][at]).is_relative_to(M.ROOT))

    def test_wrong_historical_name_or_authored_digest_refuses(self):
        for key in ("source", "proof", "plan", "topology", "world-basis"):
            bad = copy.deepcopy(self.record)
            bad["command"][M.argument(bad["command"], key)] += ".replaced"
            with self.assertRaisesRegex(ValueError, "HISTORICAL_INPUT"):
                M.localize_record(bad, M.ROOT)
        bad = copy.deepcopy(self.record)
        bad["command"][M.argument(bad["command"], "source-sha256")] = "0" * 64
        with self.assertRaisesRegex(ValueError, "AUTHORED_HASH"):
            M.localize_record(bad, M.ROOT)

    def test_duplicate_missing_or_truncated_argument_refuses(self):
        for command in (["--source", "x", "--source", "y"], [], ["--source"]):
            with self.assertRaisesRegex(ValueError, "INPUT_ARGUMENT"):
                M.argument(command, "source")

    def test_same_name_wrong_bytes_or_oversized_file_refuses(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "source"
            path.write_bytes(b"original")
            wanted = hashlib.sha256(path.read_bytes()).hexdigest()
            path.write_bytes(b"tampered")
            with self.assertRaisesRegex(ValueError, "INPUT_HASH"):
                M.exact_file(path, wanted)
            with patch.object(M, "MAX_FILE_BYTES", 1):
                with self.assertRaisesRegex(ValueError, "INPUT_FILE"):
                    M.exact_file(path, wanted)

    def test_existing_and_dangling_outputs_refuse_before_any_input_observer(self):
        with tempfile.TemporaryDirectory() as folder:
            existing = Path(folder) / "existing"
            existing.mkdir()
            original = existing / "result.json"
            original.write_bytes(b"keep")
            dangling = Path(folder) / "alias"
            dangling.symlink_to(Path(folder) / "absent")
            with patch.object(M, "exact_file", side_effect=AssertionError("late output guard")):
                for out in (existing, dangling):
                    with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
                        M.execute(out, "0" * 40)
            self.assertEqual(original.read_bytes(), b"keep")

    def test_reader_and_argv_are_restored_after_original_proof_refuses(self):
        import sys
        reader = M.G.M.I.M.W
        original_reader = reader.read_record
        original_snapshot = reader.snapshot_sources
        original_argv = sys.argv
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "new"
            with patch.object(M.G, "main", side_effect=ValueError("ORIGINAL_PROOF_REFUSED")):
                with self.assertRaisesRegex(ValueError, "ORIGINAL_PROOF_REFUSED"):
                    M.execute(out, "0" * 40)
            self.assertFalse(out.exists())
        self.assertIs(reader.read_record, original_reader)
        self.assertIs(reader.snapshot_sources, original_snapshot)
        self.assertIs(sys.argv, original_argv)


class HistoricalSnapshotTests(unittest.TestCase):
    def test_all_eleven_actual_historical_objects_match_the_pinned_closed_list(self):
        rows = M.historical_locators()
        self.assertEqual(len(rows), 11)
        for row in rows:
            self.assertEqual(hashlib.sha256(M.historical_blob(row)).hexdigest(), row["sha256"])

    def test_wrong_object_size_refuses_before_blob_read_and_wrong_bytes_refuse(self):
        row = M.historical_locators()[0]
        with patch.object(M.subprocess, "check_output", return_value=b"300000") as call:
            with self.assertRaisesRegex(ValueError, "HISTORICAL_CAPACITY"):
                M.historical_blob(row)
            self.assertEqual(call.call_count, 1)
        with patch.object(M.subprocess, "check_output", side_effect=[str(row["bytes"]).encode(), b"wrong"]):
            with self.assertRaisesRegex(ValueError, "HISTORICAL_HASH"):
                M.historical_blob(row)

    def test_missing_or_conflicting_historical_metadata_refuses_before_any_snapshot_write(self):
        row = M.historical_locators()[0]
        for metadata in ({"manifest": {"path": "res://absent", "sha256": row["sha256"]}, "sources": []},
                         {"manifest": row, "sources": [{**row, "sha256": "0" * 64}]}):
            with patch.object(M, "historical_locators", return_value=[row]), \
                    patch.object(M, "historical_blob", side_effect=AssertionError("late guard")):
                with self.assertRaisesRegex(ValueError, "HISTORICAL_METADATA"):
                    M.historical_snapshot(metadata, Path("unused"), lambda *_: self.fail("snapshot ran"))

    def test_historical_materialization_never_writes_through_current_source_hardlinks(self):
        old = b"accepted old source"
        row = {"path": "res://scripts/source.gd", "sha256": hashlib.sha256(old).hexdigest(),
               "git_object": "fixture:godot/scripts/source.gd"}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            current = root / "current.gd"
            current.write_bytes(b"live reviewed current consumer")
            unlisted = root / "unlisted.gd"
            unlisted.write_bytes(b"unlisted changed source")
            snapshot = root / "snapshot"
            snapshot.mkdir()

            def original(_metadata, destination):
                (destination / "scripts").mkdir()
                os.link(current, destination / "scripts/source.gd")
                os.link(unlisted, destination / "unlisted.gd")
                return {"inherited": "untouched"}

            metadata = {"manifest": row, "sources": [{"path": "res://unlisted.gd", "sha256": "0" * 64}]}
            with patch.object(M, "historical_locators", return_value=[row]), \
                    patch.object(M, "historical_blob", return_value=old):
                result = M.historical_snapshot(metadata, snapshot, original)
            self.assertEqual(current.read_bytes(), b"live reviewed current consumer")
            self.assertEqual((snapshot / "scripts/source.gd").read_bytes(), old)
            self.assertNotEqual(current.stat().st_ino, (snapshot / "scripts/source.gd").stat().st_ino)
            self.assertEqual(unlisted.stat().st_ino, (snapshot / "unlisted.gd").stat().st_ino)
            self.assertNotEqual(hashlib.sha256((snapshot / "unlisted.gd").read_bytes()).hexdigest(), "0" * 64)
            self.assertEqual(set(result), {"inherited", row["path"]})


if __name__ == "__main__":
    unittest.main()
