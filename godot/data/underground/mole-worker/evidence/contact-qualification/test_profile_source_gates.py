#!/usr/bin/env python3
"""Small adversarial source/phase/role checks; fixtures never substitute for actual native geometry."""
import copy
from fractions import Fraction
import importlib.util
from pathlib import Path
import types
import unittest

import numpy as np

SPEC = importlib.util.spec_from_file_location("source_gates", Path(__file__).with_name("close_profile_source_gates.py"))
G = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(G)


class SourceGates(unittest.TestCase):
    def cases(self):
        return [{"frames": n, "source_loop_mode": 1, "source_duration_s": Fraction(n-1,30),
                 "matrices": np.zeros((n, 1, 12), dtype=np.float32), "grounding": np.zeros(n, dtype=np.float32)}
                for n in (10, 3)]

    def proof(self):
        cases = self.cases()
        basis = types.SimpleNamespace(digest="a"*64, inverse_norm=Fraction(3, 2))
        checked = [dict(row, checks=1) for row in G.C.H.handoff_sets(cases)]
        record = {"schema": 2, "content_sha256": G.GROUND_SOURCE_SHA, "source_rederived": True,
                  "production_qualified": False, "world_basis_sha256": basis.digest,
                  "inverse_heading_norm": G.P.envelope.fraction_record(basis.inverse_norm),
                  "carry_handoffs": {"clear": True, "unresolved": [], "checked": checked, "checks": len(checked),
                                     "body_triangles": 3, "tool_triangles": 2, "intentional_grip_triangles": 1}}
        return record, cases, basis

    def test_exact_finite_proof_fixture(self):
        proof, cases, basis = self.proof()
        G.handoff_refusal(proof, cases, basis, (3, 2, 1))
        G.same_ground_sources(cases, copy.deepcopy(cases))

    def test_loop_closing_or_missing_edge_refuses(self):
        proof, cases, basis = self.proof()
        for mutate in (lambda rows: rows.pop(), lambda rows: rows[-1].update(interval=[1, 2])):
            bad = copy.deepcopy(proof)
            mutate(bad["carry_handoffs"]["checked"])
            with self.assertRaises(ValueError): G.handoff_refusal(bad, cases, basis, (3, 2, 1))

    def test_nominal_success_with_missing_checks_or_primitives_refuses(self):
        proof, cases, basis = self.proof()
        for field, value in (("checks", 0), ("body_triangles", 2), ("intentional_grip_triangles", 2), ("unresolved", [{}])):
            bad = copy.deepcopy(proof)
            bad["carry_handoffs"][field] = value
            with self.assertRaises(ValueError): G.handoff_refusal(bad, cases, basis, (3, 2, 1))

    def test_basis_or_source_identity_refuses(self):
        proof, cases, basis = self.proof()
        for field, value in (("content_sha256", "b"*64), ("world_basis_sha256", "b"*64),
                             ("inverse_heading_norm", {"numerator": 1, "denominator": 1})):
            bad = copy.deepcopy(proof)
            bad[field] = value
            with self.assertRaises(ValueError): G.handoff_refusal(bad, cases, basis, (3, 2, 1))

    def test_changed_timing_or_native_pose_refuses(self):
        cases = self.cases()
        for field in ("source_duration_s", "source_loop_mode", "matrices", "grounding"):
            bad = copy.deepcopy(cases)
            if field in ("matrices", "grounding"): bad[0][field].flat[0] = 1
            else: bad[0][field] -= 1
            with self.assertRaises(ValueError): G.same_ground_sources(cases, bad)

    def carry(self):
        return [{"kind": "body", "full_u": [-10, -1, -10, 10, 20, 10], "floor_u": [-2,-1,-2,2,0,2],
                 "support_u": [-3,-1,-3,3,0,3]},
                {"kind": "attachment", "full_u": [-20,4,-20,20,30,20], "floor_u": None, "support_u": None}]

    def test_ground_contains_full_tool_in_both_roles(self):
        roles = G.compile_ground(self.carry())
        self.assertIn(self.carry()[1]["full_u"], roles["BODY_HELD_LOAD"])
        self.assertEqual(roles["BODY_HELD_LOAD"], roles["TURN_RECOVERY"])

    def test_missing_body_tool_cannot_borrow_recovery(self):
        roles = G.compile_ground(self.carry())
        original = copy.deepcopy(roles["BODY_HELD_LOAD"])
        roles["BODY_HELD_LOAD"] = roles["BODY_HELD_LOAD"][:2]
        with self.assertRaises(ValueError): G.ground_coverage(original, self.carry()[0]["support_u"], roles)

    def test_tool_floor_and_undersized_stance_refuse(self):
        for tool in (True, False):
            carry = self.carry()
            if tool: carry[1]["floor_u"] = [-1,-1,-1,1,0,1]
            else: carry[0]["support_u"] = [-1,-1,-1,1,0,1]
            with self.assertRaises(ValueError): G.compile_ground(carry)


if __name__ == "__main__":
    unittest.main()
