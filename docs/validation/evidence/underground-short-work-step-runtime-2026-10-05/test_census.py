#!/usr/bin/env python3
"""Executable storage/lifetime counterexamples against the current parsed modules."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("short_step_census", HERE / "census.py")
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)


class CensusTests(unittest.TestCase):
    def mutate(self, module, before, after, refusal):
        source = C.path(module).read_text()
        self.assertIn(before, source)
        with self.assertRaisesRegex(ValueError, refusal):
            C.build({module: source.replace(before, after, 1)})

    def test_complete_joint_has_one_source_payload_and_one_composition_reserve(self):
        result = C.build()
        self.assertEqual(result["joint"]["total"], 248632)
        self.assertEqual(result["joint"]["remaining"], 13512)
        self.assertEqual(result["profile_control"]["counted_logical"], 3571)
        self.assertEqual(result["profile_control"]["complete_hot_numeric_peak"], 877)
        self.assertEqual(result["paired_profiles"]["delta"], 1764)
        self.assertEqual(result["joint"]["terms"]["retirement_and_composition"], 8192)

    def test_output_is_reproduced_exactly(self):
        self.assertEqual(json.loads(json.dumps(C.build())), json.loads((HERE / "census.json").read_text()))

    def test_no_git_or_other_subprocess_is_needed(self):
        with mock.patch("subprocess.check_output", side_effect=AssertionError("Git forbidden")), \
                mock.patch("subprocess.run", side_effect=AssertionError("subprocess forbidden")):
            self.assertEqual(C.build()["base"], "116f2f2e7b6c5334af7e18a34457fd3c6cc1a34d")

    def test_two_identically_named_source_modules_remain_distinct(self):
        result = C.build()
        self.assertEqual(result["source_programs_counted_once"]["source_program"]["numeric_payload"], 648)
        self.assertEqual(result["source_programs_counted_once"]["short_program"]["numeric_payload"], 348)
        edges = result["static_call_edges"]
        self.assertIn("source_program:profile_refusal", edges)
        self.assertIn("short_program:profile_refusal", edges)
        self.assertNotEqual(result["source_sha256"][C.NONCORE["source_program"]],
                            result["source_sha256"][C.NONCORE[C.S]])

    def test_added_retained_scalar_refuses(self):
        self.mutate(C.R, "extends RefCounted", "extends RefCounted\nvar _extra: int = 0", "retained field topology")

    def test_added_retained_bank_refuses(self):
        self.mutate(C.W, "extends RefCounted", "extends RefCounted\nvar _extra: PackedInt32Array", "retained field topology")

    def test_inherited_storage_refuses(self):
        self.mutate(C.D, "extends RefCounted", "extends Node", "inherited storage")

    def test_duplicate_same_expression_resize_is_counted(self):
        source = C.path(C.P).read_text()
        import re
        line = re.search(r"^\s*\w+\.resize\([^\n]+", source, re.M)[0]
        self.mutate(C.P, line, line + "\n" + line, "packed resize topology")

    def test_temporary_array_without_field_or_resize_refuses(self):
        self.mutate(C.R, "func advance_tick(tick: int) -> int:",
                    "func advance_tick(tick: int) -> int:\n\tvar scratch: Array = Array()", "temporary allocation topology")

    def test_short_source_must_remain_stateless(self):
        self.mutate(C.S, "extends RefCounted", "extends RefCounted\nvar _clock: int = 0", "SourceProgram retained state")

    def test_source_temporary_copy_refuses(self):
        self.mutate(C.S, "static func uses(actual: Profiles) -> bool:",
                    "static func uses(actual: Profiles) -> bool:\n\tvar extra: PackedInt32Array = PackedInt32Array()",
                    "SourceProgram allocation")

    def test_source_constant_payload_growth_refuses(self):
        self.mutate(C.S, "extends RefCounted", "extends RefCounted\nconst EXTRA: int = 1", "constant capacity")

    def test_utf32_payload_growth_refuses(self):
        self.mutate(C.S, 'fff35c8c2ead2f43a68a242ca3ac156f9348af1880a00dd7ebbb16aaa1f476a0',
                    'x'*65, "constant capacity")

    def test_profile_record_width_change_refuses(self):
        self.mutate(C.P, "const PROFILE_WIRE_BYTES: int = 98", "const PROFILE_WIRE_BYTES: int = 102", "packed field width")

    def test_actor_record_width_change_refuses(self):
        self.mutate(C.R, "const RESIDENT_FIELDS: int = 27", "const RESIDENT_FIELDS: int = 28", "packed field width")

    def test_new_same_size_call_needs_a_new_review(self):
        self.mutate(C.S, "static func uses(actual: Profiles) -> bool:",
                    "static func uses(actual: Profiles) -> bool:\n\tactual.content_revision()",
                    "unreviewed numeric frame or nested call")

    def test_new_numeric_local_needs_a_new_review(self):
        self.mutate(C.S, "static func uses(actual: Profiles) -> bool:",
                    "static func uses(actual: Profiles) -> bool:\n\tvar extra: int = 0",
                    "unreviewed numeric frame or nested call")

    def test_known_transitive_call_cannot_be_added_twice(self):
        self.mutate(C.S, "static func uses(actual: Profiles) -> bool:",
                    "static func uses(actual: Profiles) -> bool:\n\tis_short(10)\n\tis_short(10)",
                    "unreviewed numeric frame or nested call")

    def test_old_source_program_is_immutable(self):
        self.mutate("source_program", "extends RefCounted", "extends RefCounted\n# changed", "unchanged programme5")

    def test_immutable_call_manifest_cannot_self_rehash(self):
        original = Path.read_bytes
        def read(path):
            raw = original(path)
            return raw + b" " if path == HERE / "supporting/call-contract.json" else raw
        with mock.patch.object(Path, "read_bytes", read), self.assertRaisesRegex(ValueError, "immutable call contract changed"):
            C.build()

    def test_predecessor_manifest_cannot_follow_current_sources(self):
        original = Path.read_bytes
        def read(path):
            raw = original(path)
            return raw + b" " if path == HERE / "supporting/predecessors.json" else raw
        with mock.patch.object(Path, "read_bytes", read), self.assertRaisesRegex(ValueError, "predecessor manifest changed"):
            C.build()

    def test_reviewer_short_source_array_literal_refuses(self):
        literal = ",".join("0" for _ in range(4096))
        self.mutate(C.S, "static func uses(actual: Profiles) -> bool:",
                    "static func uses(actual: Profiles) -> bool:\n\tvar _scratch: Array = ["+literal+"]",
                    "SourceProgram collection allocation")

    def test_reviewer_tick_array_literal_refuses(self):
        literal = ",".join("0" for _ in range(4096))
        self.mutate(C.R, "func advance_tick(tick: int) -> int:",
                    "func advance_tick(tick: int) -> int:\n\tvar _scratch: Array = ["+literal+"]",
                    "collection literal allocation topology")

    def test_dictionary_literal_refuses(self):
        self.mutate(C.S, "static func uses(actual: Profiles) -> bool:",
                    'static func uses(actual: Profiles) -> bool:\n\tvar _scratch: Dictionary = {"k": 0}',
                    "SourceProgram collection allocation")

    def test_untyped_nested_literal_refuses(self):
        self.mutate(C.R, "func advance_tick(tick: int) -> int:",
                    "func advance_tick(tick: int) -> int:\n\tvar _scratch := [[0]]",
                    "collection literal allocation topology")

    def test_growth_of_existing_packed_initializer_refuses(self):
        source = C.path(C.D).read_text()
        import re
        original = re.search(r'^var _pose: PackedInt32Array = PackedInt32Array\(\[[^\n]*\]\)', source, re.M)[0]
        self.mutate(C.D, original, "var _pose: PackedInt32Array = PackedInt32Array(["+",".join("0" for _ in range(65536))+"])",
                    "collection literal allocation topology")

    def test_growth_of_existing_profile_header_initializer_refuses(self):
        source = C.path(C.P).read_text()
        import re
        original = re.search(r'var header: PackedInt64Array = PackedInt64Array\(\[[^\n]*\]\)', source)[0]
        self.mutate(C.P, original, "var header: PackedInt64Array = PackedInt64Array(["+",".join("0" for _ in range(4096))+"])",
                    "collection literal allocation topology")

    def test_empty_typed_constructor_without_literal_refuses(self):
        self.mutate(C.S, "static func uses(actual: Profiles) -> bool:",
                    "static func uses(actual: Profiles) -> bool:\n\tvar _scratch := Array[int]()",
                    "unreviewed numeric frame or nested call")

    def test_alias_constructor_without_new_numerics_refuses(self):
        self.mutate(C.D, "extends RefCounted", "extends RefCounted\nconst Hidden = Array[int]()",
                    "unreviewed numeric frame or nested call")

    def test_lexer_keeps_hash_inside_string_and_ignores_real_comment(self):
        self.assertEqual(C.tokens('return "#first" # real comment'), ["return", '"#first"'])
        self.assertNotEqual(C.tokens('return "#first"'), C.tokens('return "#second"'))
        self.assertEqual(C.collection_literals('return value[0] # [ignored]'), [])
        self.assertEqual(C.collection_literals('return ["#not-a-comment", [0]]'),
                         [['[', '"#not-a-comment"', ',', '[', '0', ']', ']'], ['[', '0', ']']])


if __name__ == "__main__":
    unittest.main()
