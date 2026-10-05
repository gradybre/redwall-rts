#!/usr/bin/env python3
"""Current-source, caller-override, shallow-checkout and complete coexistence regressions."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools"))
import audit_registry_capacities as audit
import underground_approach_memory as approach

CATALOG_SHA = "d5f28ac82d76a97ad3f11763b36e0d7e42ce286624bf2c968511662b1a3aaa9e"
JOINT = {
    "profiles": 51992, "levels": 2292, "paired_motion": 141720, "decode": 4096,
    "caller": 176, "logical_helper": 4096, "native": 32768, "total": 237140,
    "reservation": 262144, "headroom": 25004, "independent_maxima_total_refuses": 444284,
}


def fixture_index():
    index = audit.load_source_index(ROOT / "godot/scripts/core")
    # The branch intentionally predates root's v3 publication. Borrow the exact
    # reviewed v3 Catalog text as a census fixture, never as production approval.
    for name, relative in approach.NONCORE.items():
        text = (ROOT / relative).read_text()
        if name == "mole_profile_catalog":
            text = (HERE / "fixtures/catalog-v3.gd.txt").read_text()
            if hashlib.sha256(text.encode()).hexdigest() != CATALOG_SHA:
                raise ValueError("fixture Catalog changed")
        index[name] = audit.parse_module(name, relative, text)
    return index


class WrapperTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.index = fixture_index()

    def mutant(self, name, before, after, message=None):
        changed = dict(self.index)
        original = changed[name]
        self.assertIn(before, original.text)
        # Deliberately preserve stale cached consts and sha256, as an injected
        # caller can do. Only the changed text is authoritative to this wrapper.
        changed[name] = original._replace(text=original.text.replace(before, after, 1))
        with self.assertRaisesRegex(ValueError, message or "approach memory"):
            approach.build(changed, JOINT)

    def test_complete_reviewed_census_and_current_hashes(self):
        before = dict(self.index)
        result = approach.build(self.index, JOINT)
        accepted = json.loads((ROOT / approach.LEGACY / "census.json").read_text())
        self.assertEqual({k: v for k, v in result.items() if k in accepted and k != "source_sha256"},
                         {k: v for k, v in accepted.items() if k != "source_sha256"})
        self.assertEqual(result["profile_control"]["counted_subtotal"], 3183)
        self.assertEqual(result["source_program"]["shared_counted_once"], 640)
        self.assertEqual(result["joint"]["total"], 246868)
        self.assertEqual(result["joint"]["remaining"], 15276)
        self.assertEqual(result["additional_reserved_bytes"], 0)
        self.assertEqual(result["portable_enforcement"]["motion_joint_before_session_and_retirement"], JOINT)
        self.assertFalse(result["runtime_native_qualified"])
        for name in approach.CURRENT:
            self.assertEqual(result["source_sha256"][self.index[name].relative_path],
                             hashlib.sha256(self.index[name].text.encode()).hexdigest())
        self.assertEqual(self.index, before)

    def test_added_retained_bank_refuses(self):
        self.mutant("underground_routes", "extends RefCounted", "extends RefCounted\nvar extra: PackedInt32Array = PackedInt32Array()")

    def test_untyped_or_duplicate_nested_storage_refuses(self):
        self.mutant("underground_profiles", "extends RefCounted", "extends RefCounted\nvar hidden = 0")
        self.mutant("underground_profiles", "var profile_id: int = -1", "var profile_id: int = -1\n\tvar profile_id: int = 0")

    def test_inherited_packet_storage_refuses(self):
        self.mutant("underground_profiles", "class Selection extends RefCounted:", "class Selection extends ForeignPacket:")

    def test_duplicate_identical_resize_refuses(self):
        self.mutant("underground_profiles", "_identity.resize(3)", "_identity.resize(3)\n\t_identity.resize(3)")

    def test_actor_column_width_growth_refuses(self):
        self.mutant("underground_routes", "const RESIDENT_LONGS: int = 6", "const RESIDENT_LONGS: int = 7")

    def test_source_program_state_base_and_array_constant_refuse(self):
        self.mutant("source_program", "extends RefCounted", "extends RefCounted\nvar cached: int = 0")
        self.mutant("source_program", "extends RefCounted", "extends ForeignClock")
        self.mutant("source_program", "extends RefCounted", "extends RefCounted\nconst HIDDEN: Array[int] = [1]")

    def test_even_under_budget_source_constant_growth_refuses(self):
        self.mutant("source_program", "extends RefCounted", 'extends RefCounted\nconst EXTRA: String = "x"', "numeric/retained/lifetime")
        self.mutant("source_program", "extends RefCounted", "extends RefCounted\nconst EXTRA: int = 0", "numeric/retained/lifetime")

    def test_source_decode_allocation_refuses(self):
        self.mutant("source_program", "var policy: int =", "ACTOR_SHA.hex_decode()\n\tvar policy: int =")

    def test_unaccounted_cold_child_and_larger_buffer_refuse(self):
        self.mutant("underground_profiles", "var next_box: int = 0", "_new_cold_child()\n\tvar next_box: int = 0")
        self.mutant("underground_profiles", "_read(file, digest_context, PROFILE_WIRE_BYTES)",
                    "_read(file, digest_context, PROFILE_WIRE_BYTES + 1)")

    def test_call_change_without_numeric_growth_refuses(self):
        self.mutant("source_program", "return (old << 32) | time", "word(0, 0)\n\treturn (old << 32) | time", "call/allocation")

    def test_foreign_frame_call_change_without_numeric_growth_refuses(self):
        self.mutant("inventory", "return is_container_valid(container_ref) and _c_policy[container_ref.x] == POLICY_SATCHEL",
                    "_hidden_allocating_call()\n\treturn is_container_valid(container_ref) and _c_policy[container_ref.x] == POLICY_SATCHEL", "foreign call/allocation")

    def test_foreign_frame_numeric_growth_refuses(self):
        self.mutant("inventory", "return is_container_valid(container_ref) and _c_policy[container_ref.x] == POLICY_SATCHEL",
                    "var extra: int = 0\n\treturn is_container_valid(container_ref) and _c_policy[container_ref.x] == POLICY_SATCHEL")

    def test_unrelated_foreign_change_is_reported_not_replaced_from_disk(self):
        changed = dict(self.index)
        old = changed["inventory"]
        changed["inventory"] = old._replace(text=old.text + "\n# unrelated foreign-owner review note\n")
        result = approach.build(changed, JOINT)
        self.assertEqual(result["source_sha256"][old.relative_path], hashlib.sha256(changed["inventory"].text.encode()).hexdigest())
        self.assertNotEqual(result["source_sha256"][old.relative_path], old.sha256)

    def test_driver_override_is_used_even_when_current_file_is_unchanged(self):
        self.mutant("mole_profile_driver", "extends RefCounted", "extends RefCounted\nvar retained: int = 0")

    def test_missing_core_source_and_substituted_path_refuse(self):
        changed = dict(self.index)
        del changed["underground_routes"]
        with self.assertRaisesRegex(ValueError, "missing current module"):
            approach.build(changed, JOINT)
        changed = dict(self.index)
        changed["source_program"] = changed["source_program"]._replace(relative_path="elsewhere/source_program.gd")
        with self.assertRaisesRegex(ValueError, "module identity"):
            approach.build(changed, JOINT)

    def test_current_catalog_count_or_pair_mutation_refuses(self):
        for before, after in (("PROFILE_COUNT: int = 26", "PROFILE_COUNT: int = 27"),
                              ("BOX_COUNT: int = 250", "BOX_COUNT: int = 251"),
                              ("PAIRED_BANK_BYTES: int = 19224", "PAIRED_BANK_BYTES: int = 19225"),
                              ("CONTROL_RESERVE: int = 32768", "CONTROL_RESERVE: int = 32769")):
            with self.subTest(before=before):
                self.mutant("mole_profile_catalog", before, after)

    def test_joint_source_terms_and_budget_cannot_grow(self):
        for name, before, after in (
            ("underground_session", "PROFILE_SOURCE_COUNT: int = 1", "PROFILE_SOURCE_COUNT: int = 2"),
            ("underground_session", "HELPER_BYTES: int = 512", "HELPER_BYTES: int = 513"),
            ("underground_world_retirement", "RETIREMENT_RESERVED_BYTES: int = 8192", "RETIREMENT_RESERVED_BYTES: int = 8193"),
            ("underground_level_catalog", "CONTROL_RESERVE: int = 2048", "CONTROL_RESERVE: int = 2049"),
            ("underground_motion_catalog", "CALLER_BYTES: int = 176", "CALLER_BYTES: int = 177"),
            ("underground_budget", "PROFILE_BYTES: int = 262144", "PROFILE_BYTES: int = 524288"),
        ):
            with self.subTest(module=name):
                self.mutant(name, before, after)

    def test_stale_double_charged_missing_extra_or_noninteger_joint_refuses(self):
        cases = [dict(JOINT, profiles=47288), dict(JOINT, total=JOINT["total"] + 1536),
                 dict(JOINT, logical_helper=True), dict(JOINT, new_slice=0)]
        missing = dict(JOINT)
        del missing["headroom"]
        cases.append(missing)
        for joint in cases:
            with self.subTest(joint=joint), self.assertRaisesRegex(ValueError, "actual Motion joint"):
                approach.build(self.index, joint)

    def portable_tree(self, directory):
        target = Path(directory)
        for relative in approach.PINS:
            path = target / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, path)
        return target

    def test_no_git_checkout_or_subprocess_is_required(self):
        with tempfile.TemporaryDirectory() as directory:
            target = self.portable_tree(directory)
            self.assertFalse((target / ".git").exists())
            with mock.patch.object(approach, "ROOT", target), mock.patch.object(subprocess, "check_output", side_effect=AssertionError("Git forbidden")), mock.patch.object(subprocess, "run", side_effect=AssertionError("process forbidden")):
                result = approach.build(self.index, JOINT)
            self.assertEqual(result["joint"]["total"], 246868)

    def test_noncore_fallback_is_current_tree_and_does_not_mutate_input(self):
        with tempfile.TemporaryDirectory() as directory:
            target = self.portable_tree(directory)
            changed = dict(self.index)
            for name, relative in approach.NONCORE.items():
                path = target / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(changed.pop(name).text)
            with mock.patch.object(approach, "ROOT", target):
                result = approach.build(changed, JOINT)
            self.assertEqual(result["portable_enforcement"]["current_joint_source_sha256"][approach.NONCORE["mole_profile_catalog"]], CATALOG_SHA)
            self.assertFalse(set(approach.NONCORE) & changed.keys())

    def test_every_immutable_witness_is_enforced(self):
        for relative in approach.PINS:
            with self.subTest(path=relative), tempfile.TemporaryDirectory() as directory:
                target = self.portable_tree(directory)
                path = target / relative
                path.write_bytes(path.read_bytes() + b"\n")
                with mock.patch.object(approach, "ROOT", target), self.assertRaisesRegex(ValueError, "immutable witness changed"):
                    approach.build(self.index, JOINT)


if __name__ == "__main__":
    unittest.main()
