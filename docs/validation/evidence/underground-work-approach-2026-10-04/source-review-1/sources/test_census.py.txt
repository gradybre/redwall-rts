#!/usr/bin/env python3
"""Read-only source mutants: retained bytes, inherited state, cold copies and exact helper ceilings."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


C = module("work_approach_census_under_test", HERE / "census.py")
R = module("work_approach_runner_under_test", HERE / "reproduce.py")


class CensusTests(unittest.TestCase):
    def report(self):
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            C.main()
        return json.loads(stream.getvalue())

    def mutant(self, owner, before, after):
        original = C.source
        self.assertIn(before, original(owner))

        def changed(name, old=False):
            value = original(name, old)
            return value.replace(before, after, 1) if name == owner and not old else value

        with mock.patch.object(C, "source", side_effect=changed), self.assertRaises(AssertionError):
            self.report()

    def test_actual_source_reproduces_complete_numeric_census(self):
        result = self.report()
        self.assertEqual(result, json.loads((HERE / "census.json").read_text()))
        self.assertEqual(result["new_actor_columns"], 0)
        self.assertEqual(result["joint"]["total"], 246868)
        self.assertEqual(result["profile_control"]["counted_subtotal"], 3183)
        self.assertFalse(result["runtime_native_qualified"])

    def test_added_routes_field_refuses(self):
        self.mutant("underground_routes", "extends RefCounted", "extends RefCounted\nvar extra: int = 0")

    def test_untyped_retained_field_refuses(self):
        self.mutant("underground_profiles", "extends RefCounted", "extends RefCounted\nvar hidden = 0")

    def test_duplicate_nested_field_refuses(self):
        self.mutant("underground_profiles", "var profile_id: int = -1", "var profile_id: int = -1\n\tvar profile_id: int = 0")

    def test_changed_inherited_packet_refuses(self):
        self.mutant("underground_profiles", "class Selection extends RefCounted:", "class Selection extends ForeignPacket:")

    def test_duplicate_existing_resize_refuses(self):
        self.mutant("underground_profiles", "_identity.resize(3)", "_identity.resize(3)\n\t_identity.resize(3)")

    def test_route_width_change_refuses(self):
        self.mutant("underground_routes", "const RESIDENT_LONGS: int = 6", "const RESIDENT_LONGS: int = 7")

    def test_source_program_state_and_inheritance_refuse(self):
        self.mutant("source_program", "extends RefCounted", "extends RefCounted\nvar cached: int = 0")
        self.mutant("source_program", "extends RefCounted", "extends ForeignClock")

    def test_source_program_cannot_hide_an_array_constant_or_decode_copy(self):
        self.mutant("source_program", "extends RefCounted", "extends RefCounted\nconst EXTRA: Array[int] = [1]")
        self.mutant("source_program", "var policy: int =", "ACTOR_SHA.hex_decode()\n\tvar policy: int =")

    def test_source_constant_payload_overflow_refuses(self):
        self.mutant("source_program", "extends RefCounted", 'extends RefCounted\nconst EXTRA: String = "' + "x" * 1024 + '"')

    def test_unaccounted_cold_child_refuses(self):
        self.mutant("underground_profiles", "var next_box: int = 0", "_new_cold_child()\n\tvar next_box: int = 0")

    def test_larger_decoder_read_refuses(self):
        self.mutant("underground_profiles", "_read(file, digest_context, PROFILE_WIRE_BYTES)",
                    "_read(file, digest_context, PROFILE_WIRE_BYTES + 1)")

    def test_extra_source_leaf_numeric_frame_refuses(self):
        self.mutant("source_program", "var policy: int =", "\n".join("var frame_%d: int = 0\n\t" % i for i in range(100)) + "var policy: int =")


class RunnerTests(unittest.TestCase):
    def test_failed_restoration_cannot_delete_original_parked_assets(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "project"
            root.mkdir()
            with mock.patch.object(R, "ROOT", root):
                with self.assertRaisesRegex(RuntimeError, "refused restoration"):
                    with R.retained_assets_directory() as parked:
                        assets = parked / "assets"
                        assets.mkdir()
                        (assets / "exact-source.bin").write_bytes(b"original bytes")
                        raise RuntimeError("refused restoration")
                self.assertEqual((assets / "exact-source.bin").read_bytes(), b"original bytes")

    def test_successful_restore_cleans_only_empty_temporary(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "project"
            root.mkdir()
            with mock.patch.object(R, "ROOT", root):
                with R.retained_assets_directory() as parked:
                    pass
                self.assertFalse(parked.exists())

    def test_clean_import_exit_zero_still_rejects_raw_diagnostics(self):
        for text in ("SCRIPT ERROR: sample", "WARNING: sample", "ERROR: sample", "ObjectDB instances leaked", "resources still in use at exit"):
            with self.subTest(text=text), self.assertRaises(RuntimeError):
                R.validate_import_log(text)
        R.validate_import_log("Godot Engine clean import\n")


if __name__ == "__main__":
    unittest.main()
