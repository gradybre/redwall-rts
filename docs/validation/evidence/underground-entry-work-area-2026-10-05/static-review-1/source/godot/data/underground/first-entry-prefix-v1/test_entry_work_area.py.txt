"""Full-source geometric and selector regressions for the diagnostic work-area successor."""
import importlib.util
import json
from pathlib import Path
import struct
import unittest

HERE = Path(__file__).resolve().parent
LOADER = importlib.util.spec_from_file_location("work_area", HERE / "compile_entry_work_area.py")
C = importlib.util.module_from_spec(LOADER)
LOADER.loader.exec_module(C)


class WorkAreaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile = (C.S.ROOT / "docs/validation/evidence/underground-entry-source-phases-2026-10-05/handling-diagnostic-1/mole-worker.ugprof").read_bytes()
        cls.spec = json.loads(C.S.read(C.S.ROOT, C.S.SPEC, C.S.SPEC_SHA, 131072))

    def test_exact_successor_header_counts_size_and_reader_allocation(self):
        packet = C.build(self.profile)
        raw = packet["frontier.ugfront"]
        self.assertEqual(struct.unpack_from("<8sI6q2i6I", raw),
                         (b"UGFRNT01", 1, 2, 1, 1, 1, 1, 4, 0, 0, 2, 8, 2, 10, 12, 6))
        self.assertEqual(len(raw), 2292)
        self.assertEqual(raw[-8:], b"UGFEND01")
        self.assertEqual(json.loads(packet["manifest.json"])["reader_bank_bytes"], 4112)
        self.assertFalse(json.loads(packet["manifest.json"])["paid_execution_qualified"])

    def test_complete_handling_and_backward_sources_fit_but_all_yaw_does_not(self):
        for row in [2, 6, 16, 29]:
            self.assertTrue(C.endpoint_contains(C.profile_boxes(self.profile, row), C.H_AIR, C.H_FOOT))
        self.assertFalse(C.endpoint_contains(C.profile_boxes(self.profile, 12), C.H_AIR, C.H_FOOT))

    def test_held_pick_not_just_low_body_blocks_near_storage(self):
        table, travel = C.tables(self.spec)
        for i in [2, 11]:
            table[4][i][6] = 866
        with self.assertRaisesRegex(ValueError, "STORAGE_BLOCKED"):
            C.validate(table, travel, self.profile)

    def test_missing_alias_and_wrong_direction_refuse(self):
        table, travel = C.tables(self.spec)
        table[4][10][4] += 1
        with self.assertRaisesRegex(ValueError, "STORAGE_ALIASES"):
            C.validate(table, travel, self.profile)
        table, travel = C.tables(self.spec)
        travel[2] = 2
        with self.assertRaisesRegex(ValueError, "TRAVEL_SELECTION"):
            C.validate(table, travel, self.profile)

    def test_excavation_preserves_distinct_all_yaw_path_selectors(self):
        table, travel = C.tables(self.spec)
        table[5][0][15] = 1
        with self.assertRaisesRegex(ValueError, "CUT_IDENTITY"):
            C.validate(table, travel, self.profile)

    def test_paths_are_reversible_axial_and_all_feet_clear_all_six_cuts(self):
        table, travel = C.tables(self.spec)
        result = C.validate(table, travel, self.profile)
        self.assertEqual(len(result["perimeter_paths"]), 12)
        for path in result["perimeter_paths"]:
            for first, last in zip(path["points"], path["points"][1:]):
                for box in C.profile_boxes(self.profile, 12):
                    if box[1] >= 0:
                        continue
                    self.assertEqual(C.sweep(box, first, last), C.sweep(box, last, first))
                    self.assertFalse(any(C.F.overlaps(C.sweep(box, first, last), C.F.cube(i)) for i in range(6)))
        self.assertEqual(result["retire_after_completed_cut_selectors"], [4, 5])

    def test_a_changed_complete_source_never_generates_a_packet(self):
        raw = bytearray(self.profile)
        raw[-10] ^= 1
        with self.assertRaisesRegex(ValueError, "PROFILE_SHA"):
            C.build(bytes(raw))

    def test_no_successor_generation_changes_a_predecessor(self):
        inputs = [C.S.ROOT / C.F.OUTPUT / name for name in ["frontier.ugfront", "manifest.json"]]
        before = [p.read_bytes() for p in inputs]
        a, b = C.build(self.profile), C.build(self.profile)
        self.assertEqual(a, b)
        self.assertEqual(before, [p.read_bytes() for p in inputs])


if __name__ == "__main__":
    unittest.main()
