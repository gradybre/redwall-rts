#!/usr/bin/env python3
"""Negative source-only accounting boundaries, separate from actual future runtime allocation."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location("short_step_census", Path(__file__).with_name("census.py"))
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


class CensusTests(unittest.TestCase):
    def setUp(self):
        self.report = json.loads(M.REPORT.read_text())
        self.joint = json.loads((M.ROOT / "docs/planning/underground_memory_pack.json").read_text())["source_approach_reservation"]["joint"]

    def test_complete_paired_current_owners_are_counted_once(self):
        result = M.build(self.report, self.joint)
        self.assertEqual(result["prospective_configuration"], {"profiles": 28, "boxes": 264, "sources": 1})
        self.assertEqual(result["paired_delta"], 1176)
        self.assertEqual(result["before_new_controls"], 248044)
        self.assertEqual(result["remaining_before_new_controls"], 14100)
        self.assertFalse(result["proposal_admitted"])

    def test_independent_profile_maxima_do_not_become_a_joint_configuration(self):
        for field, value in (("profiles", 256), ("boxes", 3072), ("source_count", 2)):
            joint = copy.deepcopy(self.joint); joint[field] = value
            with self.assertRaises(ValueError): M.build(self.report, joint)

    def test_missing_existing_owner_or_duplicate_reserve_is_not_hidden(self):
        for field in self.joint["terms"]:
            joint = copy.deepcopy(self.joint); del joint["terms"][field]
            with self.assertRaises(ValueError): M.build(self.report, joint)
        joint = copy.deepcopy(self.joint); joint["terms"]["second_profile_controls"] = 32768
        with self.assertRaises(ValueError): M.build(self.report, joint)

    def test_added_actor_column_or_second_content_source_refuses(self):
        for field in ("new_actor_sources", "actor_image_delta", "new_resident_columns"):
            report = copy.deepcopy(self.report); report["storage"][field] = 1
            with self.assertRaises(ValueError): M.build(report, self.joint)

    def test_omitting_any_mandatory_role_or_positive_box_refuses(self):
        for role in self.report["rows"][0]["roles"]:
            report = copy.deepcopy(self.report); report["rows"][0]["roles"][role].pop()
            with self.assertRaises(ValueError): M.build(report, self.joint)
        report = copy.deepcopy(self.report); report["rows"][0]["roles"]["STANCE_SUPPORT"][0][4] = -1
        with self.assertRaises(ValueError): M.build(report, self.joint)

    def test_adding_direction_or_profile_rows_requires_a_new_reviewed_census(self):
        report = copy.deepcopy(self.report); report["rows"].append(copy.deepcopy(report["rows"][0]))
        with self.assertRaises(ValueError): M.build(report, self.joint)

    def test_source_proof_does_not_mint_policy_flags_or_native_qualification(self):
        for field, value in (("certificate_bits_written", 15), ("production_qualified", True), ("native_replay", True)):
            report = copy.deepcopy(self.report); report[field] = value
            with self.assertRaises(ValueError): M.build(report, self.joint)
        for field in ("runtime_profile_id", "runtime_policy"):
            report = copy.deepcopy(self.report); report["rows"][0][field] = 4
            with self.assertRaises(ValueError): M.build(report, self.joint)


if __name__ == "__main__":
    unittest.main()
