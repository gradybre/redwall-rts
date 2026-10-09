#!/usr/bin/env python3
"""Exact source/packing and explicit old-row-preservation checks, without engine permission."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("assembly_diagnostic", HERE / "assemble_diagnostic.py")
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)


class Diagnostic(unittest.TestCase):
    def setUp(self):
        self.old = C.OLD.read_bytes()
        self.wire = C.encode(self.old)

    def test_exact_reviewed_source_admission(self):
        C.input_admission()

    def test_actual_install_and_handling_ready_palettes_and_grounding_are_byte_identical(self):
        self.assertEqual(C.ready_join_admission(), C.READY_SHA)
        parent = (C.HERE.parent / "evidence/contact-qualification/install-program-compile-v3/result/mole-worker.ugactor").read_bytes()
        handling = bytearray((C.HERE / "compiled-3/mole-worker.ugactor").read_bytes())
        for at in (472, len(handling) - 12):
            changed = handling.copy()
            changed[at] ^= 1
            with self.assertRaisesRegex(ValueError, "ASSEMBLY_READY_IMAGE"):
                C.ready_join_admission(parent, changed)

    def test_every_original_row_box_and_digest_is_preserved(self):
        before = 64 + 29 * C.ROW.size
        after = 96 + 30 * C.ROW.size
        self.assertEqual(self.old[64:before], self.wire[96:96 + 29 * C.ROW.size])
        self.assertEqual(self.old[before:-8], self.wire[after:after + 271 * C.BOX.size])
        self.assertEqual(self.old[32:64], self.wire[32:64])
        self.assertEqual(self.wire[64:96].hex(), C.ACTOR_SHA)

    def test_exact_explicit_role_partition_retains_foot_residual(self):
        row = C.ROW.unpack_from(self.wire, 96 + 29 * C.ROW.size)
        self.assertEqual(row[0:4], (1, 6, 0, 6))
        self.assertEqual(row[14:18], (271, 10, 1, 3))
        self.assertEqual(row[18:], (1, 0, 0, 15, 7))
        at = 96 + 30 * C.ROW.size + 271 * C.BOX.size
        boxes = [C.BOX.unpack_from(self.wire, at + i * C.BOX.size) for i in range(10)]
        self.assertEqual([b[6] for b in boxes], [0, 0, 0, 2, 2, 2, 3, 3, 3, 1])
        for i in (1, 4, 7, 9): self.assertEqual(boxes[i][:6], C.FOOT)
        self.assertEqual(len(self.wire), 10912)
        self.assertEqual(2 * (len(self.wire) - 8) - 20988, 820)

    def test_old_wire_rehash_or_geometry_mutation_cannot_relabel_provenance(self):
        for index in (12, 32, 64, 4000, len(self.old) - 9):
            changed = bytearray(self.old)
            changed[index] ^= 1
            with self.assertRaisesRegex(ValueError, "ASSEMBLY_OLD_SHA"): C.encode(changed)

    def test_output_is_create_only_and_limited_to_owned_subtree(self):
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder)
            with self.assertRaisesRegex(ValueError, "ASSEMBLY_OUTPUT_EXISTS"): C.write_candidate(out)
            with self.assertRaisesRegex(ValueError, "ASSEMBLY_DIAGNOSTIC_OUTPUT_ONLY"):
                C.write_candidate(out / "new")

    def test_actual_workpieces_turn_three_matches_both_complete_source_prisms(self):
        # This is Workpieces' exact _coordinate convention, not the authoring tool's turn label.
        for original, offset, expected in (
            ((-896, -192, -2048, -768, -64, 0), (1024, 192, -768), (-1024, 0, 0, 1024, 128, 128)),
            ((-896, -320, -2560, -768, -192, -2048), (2304, 320, -2816), (-256, 0, -2048, 256, 128, -1920))):
            transformed = [(z + offset[0], y + offset[1], -x + offset[2])
                           for x in (original[0], original[3]) for y in (original[1], original[4])
                           for z in (original[2], original[5])]
            bounds = tuple(min(p[a] for p in transformed) for a in range(3))
            bounds += tuple(max(p[a] for p in transformed) for a in range(3))
            self.assertEqual(bounds, expected)
        workpieces = (C.ROOT / "godot/scripts/core/underground_connector_workpieces.gd").read_text()
        self.assertTrue("var sx: int = x if rotation == 0 else -z if rotation == 1 else -x if rotation == 2 else z" in workpieces)
        self.assertTrue("var sz: int = z if rotation == 0 else x if rotation == 1 else -z if rotation == 2 else -x" in workpieces)


if __name__ == "__main__": unittest.main()
