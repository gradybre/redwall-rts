#!/usr/bin/env python3
"""Strict integer-source and create-only level compilation; no engine or gameplay permission."""
from pathlib import Path
import copy
import importlib.util
import json
import sys
import tempfile
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location("level_compiler", Path(__file__).with_name("compile_initial_levels.py"))
COMPILER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMPILER)


class LevelSource(unittest.TestCase):
    def setUp(self):
        self.source = json.loads((COMPILER.ROOT / "initial_level_pack.json").read_text())

    def test_reviewed_pack_reproduces_exact_wire_bytes(self):
        data = COMPILER.encode(self.source)
        self.assertEqual(data, (COMPILER.ROOT / "initial_level_pack.uglvl").read_bytes())
        self.assertEqual(len(data), 108)

    def test_schema_and_revision_reject_bool_float_and_overflow(self):
        for key, values in (("schema", [True, 1.0, "1", 0, 2]),
                            ("content_revision", [True, 1.0, "1", 0, -1, 1 << 63])):
            for value in values:
                with self.subTest(key=key, value=value), self.assertRaisesRegex(ValueError, "SOURCE_SCHEMA"):
                    COMPILER.encode(dict(self.source, **{key: value}))

    def test_every_integer_field_refuses_narrowing_or_float_coercion(self):
        for value in (True, 1024.0, "1024", 1 << 31, -(1 << 31) - 1):
            for field in ("level_spacing_u", "clear_height_u", "protected_roof_band_u", "required_footing_u"):
                with self.subTest(field=field, value=value), self.assertRaisesRegex(ValueError, "SOURCE_INTEGER"):
                    COMPILER.encode(dict(self.source, **{field: value}))
            for field in ("datum_u", "min_quantum", "size_quanta"):
                source = copy.deepcopy(self.source)
                source["domain"][field][1] = value
                with self.subTest(field=field, value=value), self.assertRaisesRegex(ValueError, "SOURCE_INTEGER"):
                    COMPILER.encode(source)

    def test_finite_menus_refuse_empty_and_excess_input_before_encoding(self):
        for field, count in (("section_offsets_u", 10), ("short_stair_rises_u", 9)):
            for values in ([], [0] * count, "0"):
                with self.subTest(field=field, values=values), self.assertRaisesRegex(ValueError, "SOURCE_CAPACITY"):
                    COMPILER.encode(dict(self.source, **{field: values}))

    def test_repeated_json_keys_never_silently_select_a_different_value(self):
        with self.assertRaisesRegex(ValueError, "DUPLICATE_KEY"):
            json.loads('{"schema":1,"schema":2}', object_pairs_hook=COMPILER.unique_object)

    def test_existing_output_is_preserved_and_check_mode_detects_drift(self):
        with tempfile.TemporaryDirectory() as temporary:
            source, output = Path(temporary) / "source.json", Path(temporary) / "result.bin"
            source.write_text(json.dumps(self.source))
            output.write_bytes(b"preserved output")
            arguments = ["compile", "--source", str(source), "--out", str(output)]
            with mock.patch.object(sys, "argv", arguments), self.assertRaises(FileExistsError):
                COMPILER.main()
            self.assertEqual(output.read_bytes(), b"preserved output")
            with mock.patch.object(sys, "argv", [*arguments, "--check"]), self.assertRaisesRegex(ValueError, "COMPILED_DRIFT"):
                COMPILER.main()
            self.assertEqual(output.read_bytes(), b"preserved output")
            self.assertEqual(json.loads(source.read_text()), self.source)


if __name__ == "__main__":
    unittest.main()
