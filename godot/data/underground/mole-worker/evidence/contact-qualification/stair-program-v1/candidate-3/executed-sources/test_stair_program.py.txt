#!/usr/bin/env python3
"""Adversarial offline stair schema tests; synthetic rows never grant motion or support."""
import copy
from fractions import Fraction
from contextlib import contextmanager
from types import SimpleNamespace
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest import mock

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("stair_program_under_test", HERE / "compile_stair_program.py")
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)


def fixture():
    """Synthetic serialization data only; no certificate, source or actual world assertion."""
    programs = []
    for rise in (128, -128):
        roots = [[0, 0, 0] for _ in range(C.FRAME_COUNT)]
        roots[-1] = [0, rise, -512]
        supports = [{"interval": i, "foot": 0, "primitive": 0, "plane_u": 0,
                     "full_foot_enclosure_u": [-2, -1, -2, 2, 1, 2], "witness_vertex": 3}
                    for i in range(C.INTERVALS)]
        programs.append({"root_u": roots, "body_tool_boxes_u": [[[-4, -1, -4, 4, 9, 4], [-1, 3, -9, 1, 7, 3]]
                         for _ in range(C.INTERVALS)], "planted_masks": [1]*C.FRAME_COUNT, "supports": supports,
                         "fixture_prisms_program_local_u": [[-20, -4, -20, 20, 0, 20] for _ in range(22)],
                         "duration_q16": C.INTERVALS*C.ONE})
    return programs


class StairProgramTests(unittest.TestCase):
    def test_phase_keeps_stationary_intervals_and_exact_terminal(self):
        self.assertEqual(C.phase_keys(0), (0, 1, 0))
        self.assertEqual(C.phase_keys(C.ONE), (1, 2, 0))
        self.assertEqual(C.phase_keys(90*C.ONE), (90, 90, 0))
        for bad in (-1, 90*C.ONE+1, True, 1.5):
            with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_PHASE"):
                C.phase_keys(bad)
        raw, tables, _ = C.pack_tables(fixture())
        self.assertEqual(len(tables["STEP"]), 180)
        self.assertEqual(len(tables["ROOT"]), 182)
        self.assertEqual(C.decode_tables(raw, hashlib.sha256(raw).hexdigest()), tables)

    def test_signed_ceil_precedes_orientation_and_root_is_not_doubled(self):
        roots = [[0, 0, 0] for _ in range(91)]
        roots[1] = [-1, 1, -1]
        self.assertEqual(C.local_root(roots, C.ONE//2), [0, 1, 0])
        rotated_after = C.Q.turn(C.local_root(roots, C.ONE//2), 2)
        rotated_roots = [list(C.Q.turn(row, 2)) for row in roots]
        self.assertNotEqual(list(rotated_after), C.local_root(rotated_roots, C.ONE//2))
        roots[1] = [-(1 << 31), 0, 0]
        with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_ROOTS"):
            C.local_root(roots, 1)

    def test_missing_duplicate_or_wrong_planted_support_refuses(self):
        recipe = {"planted_mask": [1]*91}
        base = {"supports": [{"interval": i, "foot": 0} for i in range(90)]}
        self.assertEqual(len(C.support_rows(base, recipe)), 90)
        for rows in (base["supports"][:-1], base["supports"]+[base["supports"][0]],
                     [dict(row, foot=1) for row in base["supports"]]):
            with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_.*SUPPORT"):
                C.support_rows({"supports": rows}, recipe)

    def test_exact_dedup_retains_phase_and_primitive_identity(self):
        programs = fixture()
        raw, tables, widths = C.pack_tables(programs)
        self.assertEqual(len(tables["BOXE"]), 2)
        self.assertEqual(len(tables["SUPP"]), 2)  # distinct program-local physical primitive IDs
        self.assertEqual(len(tables["SIDX"]), 180)
        self.assertEqual(sum(len(rows)*widths[name]*4 for name, rows in tables.items())+48+7*12+8, len(raw))
        programs[1]["body_tool_boxes_u"][89][1][5] += 1
        _, altered, _ = C.pack_tables(programs)
        self.assertEqual(len(altered["BOXE"]), 3)
        self.assertNotEqual(tables["STEP"][-1][1], altered["STEP"][-1][1])

    def test_body_or_tool_omission_cannot_be_serialized(self):
        programs = fixture()
        programs[0]["body_tool_boxes_u"][27].pop()
        with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_ROLE_COVERAGE"):
            C.pack_tables(programs)
        programs = fixture()
        programs[0]["body_tool_boxes_u"][27][1] = [0]*6
        with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_ROLE_COVERAGE"):
            C.pack_tables(programs)

    def test_missing_physical_primitive_and_wrong_plane_refuse(self):
        programs = fixture()
        programs[0]["fixture_prisms_program_local_u"].pop()
        with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_TABLE_CENSUS"):
            C.pack_tables(programs)
        _, tables, _ = C.pack_tables(fixture())
        tables["SUPP"][0][2] = 128
        with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_WIRE_SUPPORT"):
            C.check_table_references(tables)

    def test_wire_flags_hash_footer_and_counts_fail_closed(self):
        raw, _, _ = C.pack_tables(fixture())
        mutations = [raw[:-1], raw+b"x", raw[:12]+struct.pack("<I", 1)+raw[16:],
                     raw[:56]+struct.pack("<I", 2**32-1)+raw[60:]]
        for changed in mutations:
            with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_WIRE_"):
                C.decode_tables(changed, hashlib.sha256(changed).hexdigest())
        with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_WIRE_IDENTITY"):
            C.decode_tables(raw, "0"*64)
        with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_WIRE_CAPACITY"):
            C.decode_tables(b"0"*(C.MAX_WIRE+1), "0"*64)

    def test_cross_program_support_and_prefix_gaps_are_rejected(self):
        _, original, _ = C.pack_tables(fixture())
        tables = copy.deepcopy(original)
        tables["SUPP"][0][1] = 22
        with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_WIRE_SUPPORT"):
            C.check_table_references(tables)
        tables = copy.deepcopy(original)
        tables["STEP"][9][2] += 1
        with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_WIRE_PREFIX"):
            C.check_table_references(tables)

    def test_contact_requires_the_same_real_vertex_and_no_source_penetration(self):
        u = C.P.SCALE//1024
        low = np.array([[[0, 0, 0], [u, 0, 0], [0, u, u]]]*2, dtype=np.int64)
        high = low.copy()
        row = {"interval": 0, "foot": 0, "deck": 0, "full_foot_enclosure_u": [0, 0, 0, 1, 1, 1],
               "continuous_contact_vertex": 0, "exact_source_gap_u": [[0, 1], [0, 1]]}
        recipe = {"rise_u": 128, "planted_mask": [1, 1], "ankle_translation_u": [[[0, 0, 0]]*2]*2}
        exact = lambda frame, vertex: Fraction(1 if vertex == 2 else 0)
        result = C.check_support(row, low, high, low, high, np.arange(3), recipe, exact, [-2, -4, -2, 2, 0, 2], 0)
        self.assertEqual(result["witness_vertex"], 0)
        bad = dict(row, continuous_contact_vertex=7)
        with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_CONTACT_VERTEX"):
            C.check_support(bad, low, high, low, high, np.arange(3), recipe, exact, [-2, -4, -2, 2, 0, 2], 0)
        low[:, 0, 1] = -u
        high[:, 0, 1] = -u
        bad = dict(row, full_foot_enclosure_u=[0, -1, 0, 1, 1, 1])
        with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_SOURCE_PENETRATION"):
            C.check_support(bad, low, high, low, high, np.arange(3), recipe, lambda f, v: Fraction(-1), [-2, -4, -2, 2, 0, 2], 0)

    def test_duplicate_json_and_changed_digest_are_not_accepted(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/"source.json"
            path.write_text('{"x":1,"x":2}')
            with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_DUPLICATE_KEY"):
                C.read_json(path, C.sha(path))
            path.write_text('{"x":1}')
            with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_SOURCE_DRIFT"):
                C.read_json(path, "0"*64)

    def test_existing_bundle_and_dangling_output_are_preserved_before_source_reads(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            output = root/"accepted"
            output.mkdir()
            report = output/"program.json"
            report.write_bytes(b"prior bytes")
            dangling = root/"dangling"
            dangling.symlink_to(root/"absent")
            for path in (output, dangling):
                with mock.patch.object(sys, "argv", ["compile_stair_program.py", str(path)]), \
                     mock.patch.object(C, "load_inputs", side_effect=AssertionError("must not read sources")):
                    with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_OUTPUT_EXISTS"):
                        C.main()
            self.assertEqual(report.read_bytes(), b"prior bytes")
            self.assertTrue(dangling.is_symlink())

    def test_adapter_requires_the_exact_reviewed_source_before_loading(self):
        path = C.HERE / "source-gates-v3/renew_source_closure.py"
        key = str(path.relative_to(C.ROOT))
        with mock.patch.object(C, "sha", return_value="0"*64), \
             mock.patch.object(C.importlib.util, "spec_from_file_location", side_effect=AssertionError("must not import")):
            with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_ADAPTER_SOURCE"):
                C.accepted_adapter({key: "0"*64})

    def test_source_reconstruction_restores_hooks_and_rejects_current_drift(self):
        before = C.M.W.read_record, C.M.W.snapshot_sources
        rows = {"res://a.gd": {"original_sha256": "1"*64, "current_sha256": "2"*64}}
        @contextmanager
        def scoped(reader):
            try:
                reader.read_record, reader.snapshot_sources = object(), object()
                yield
            finally:
                reader.read_record, reader.snapshot_sources = before
        adapter = SimpleNamespace(same_source_inputs=scoped)
        with mock.patch.object(C, "accepted_adapter", return_value=adapter), \
             mock.patch.object(C, "observed_current_sources", side_effect=[rows, {}]), \
             mock.patch.object(C.M, "read_actual_source", return_value=(1, {"res://a.gd": {"sha256": "1"*64}})):
            with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_CURRENT_SOURCE_CHANGED"):
                C.actual_source({})
        self.assertEqual((C.M.W.read_record, C.M.W.snapshot_sources), before)
        with mock.patch.object(C, "accepted_adapter", return_value=adapter), \
             mock.patch.object(C, "observed_current_sources", return_value=rows), \
             mock.patch.object(C.M, "read_actual_source", side_effect=ValueError("raw refusal")):
            with self.assertRaisesRegex(ValueError, "raw refusal"):
                C.actual_source({})
        self.assertEqual((C.M.W.read_record, C.M.W.snapshot_sources), before)

    def test_observed_live_bytes_must_stay_unchanged_until_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/"source.gd"
            path.write_bytes(b"observed current source")
            boundary = {"current_sources": {"res://source.gd": {"current_bytes": path.stat().st_size,
                                                                 "current_sha256": C.sha(path)}}}
            with mock.patch.object(C, "source_path", return_value=path):
                C.check_current_sources(boundary)
                path.write_bytes(b"observed currenT source")
                with self.assertRaisesRegex(ValueError, "STAIR_PROGRAM_CURRENT_SOURCE_CHANGED"):
                    C.check_current_sources(boundary)

    def test_dense_dedup_and_replacement_census_never_admit_runtime(self):
        raw, tables, widths = C.pack_tables(fixture())
        with mock.patch.object(C, "presentation_census", return_value={}):
            report = C.memory_census(raw, tables, widths, fixture())
        self.assertEqual(report["dense_column_bytes"]["BOXE"], 360*24)
        self.assertEqual(report["dense_column_bytes"]["SUPP"], 180*32)
        self.assertEqual(report["exact_dedup_saved_bytes_per_bank"], (360-2)*24+(180-2)*32)
        self.assertEqual(report["proposed_numeric_coexistence"], 2*report["packed_with_source_digest"]+4096+160)
        self.assertEqual(report["actual_runtime_allocation_bytes"], 0)
        self.assertFalse(report["runtime_admitted"])
        self.assertIsNone(report["approved_reservation_reuse"])

    def test_intern_capacity_and_i32_refuse_before_mutation(self):
        rows, indexes = [[1]], {(1,): 0}
        for row, limit in [([2], 1), ([1 << 31], 2), ([True], 2)]:
            with self.assertRaises(ValueError):
                C.intern(rows, indexes, row, limit)
            self.assertEqual(rows, [[1]])
            self.assertEqual(indexes, {(1,): 0})


if __name__ == "__main__":
    unittest.main()
