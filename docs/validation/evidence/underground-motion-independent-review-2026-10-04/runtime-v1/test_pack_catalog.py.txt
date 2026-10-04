#!/usr/bin/env python3
"""Exact accepted artifacts and adversarial bounded input checks, with no runtime mutation."""
import copy
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ROOT = next(parent for parent in HERE.parents if (parent / 'AGENTS.md').is_file())
spec = importlib.util.spec_from_file_location('motion_packer', HERE / 'pack_catalog.py')
PACK = importlib.util.module_from_spec(spec)
spec.loader.exec_module(PACK)


class CatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw, cls.manifest = PACK.compile_image(ROOT)
        cls.gait = json.loads((ROOT / PACK.P / 'stair-program-v1/candidate-4/result/program.json').read_bytes())
        cls.handoff = json.loads((ROOT / PACK.P / 'stair-handoffs-v1/column-proposal-v2/result/program.json').read_bytes())
        cls.recipes = json.loads((ROOT / PACK.P / 'stair-handoffs-v1/candidate-6/result/candidate.json').read_bytes())['attempts']
        cls.fixture = json.loads((ROOT / PACK.FIXTURE).read_bytes())
        cls.gt = PACK.decode_gait((ROOT / PACK.P / 'stair-program-v1/candidate-4/result/stair-program.ugstep').read_bytes())

    def test_exact_byte_reproduction_and_source_pins(self):
        self.assertEqual(self.raw, (HERE / 'candidate-2/motion.ugmotion').read_bytes())
        self.assertEqual(self.manifest, json.loads((HERE / 'candidate-2/manifest.json').read_bytes()))
        self.assertEqual(len(self.manifest['source_pins']), 10)
        self.assertFalse(self.manifest['runtime_activation'])
        self.assertFalse(self.manifest['pace_adopted'])

    def test_packed_columns_and_identity_no_extra_or_missing_bytes(self):
        self.assertEqual(len(self.raw), 70936)
        at = 32
        for tag, width, count in ((b'I032', 4, 17421), (b'I064', 8, 67), (b'BYTE', 1, 640)):
            self.assertEqual(self.raw[at:at+4], tag)
            self.assertEqual(struct.unpack_from('<II', self.raw, at+4), (width, count))
            at += 12 + width*count
        self.assertEqual(self.raw[at:], b'UGMEND01')
        self.assertEqual(17421*4 + 67*8 + 640, self.manifest['bank_bytes'])

    def test_source_bound_all_630_intervals_and_635_keys(self):
        self.assertEqual(len(self.gt['ROOT']) + len(self.handoff['tables']['KEY']), 635)
        self.assertEqual(len(self.gt['STEP']) + len(self.handoff['tables']['INTERVAL']), 630)
        for table, names in ((self.gt, ('BOXE', 'SUPP', 'SOLI')), (self.handoff['tables'], ('BOX', 'SUPPORT', 'SOLID'))):
            for name in names:
                self.assertGreater(len(table[name]), 0)
        PACK.validate_tables(self.gait, self.handoff, self.recipes, self.fixture, self.gt, self.handoff['tables'])

    def test_coherent_heading_reset_still_breaks_actual_join(self):
        changed = copy.deepcopy(self.handoff)
        changed['source_joins']['terminal'][1] = 0
        with self.assertRaisesRegex(ValueError, 'episode endpoints'):
            PACK.validate_tables(self.gait, changed, self.recipes, self.fixture, self.gt, changed['tables'])

    def test_body_primitive_substitution_refuses(self):
        changed = copy.deepcopy(self.gt)
        changed['SOLI'][0][0] -= 1
        with self.assertRaisesRegex(ValueError, 'complete transformed gait solids'):
            PACK.validate_tables(self.gait, self.handoff, self.recipes, self.fixture, changed, self.handoff['tables'])

    def test_stationary_interval_cannot_be_dropped(self):
        changed = copy.deepcopy(self.gait)
        changed['programs'][0]['stationary_intervals'].remove(0)
        with self.assertRaisesRegex(ValueError, 'stationary phase keys'):
            PACK.validate_tables(changed, self.handoff, self.recipes, self.fixture, self.gt, self.handoff['tables'])

    def test_phase_key_payload_substitution_refuses(self):
        changed = copy.deepcopy(self.handoff['tables'])
        changed['KEY'][100][3] += 1
        with self.assertRaisesRegex(ValueError, 'complete handoff root and heading keys'):
            PACK.validate_tables(self.gait, self.handoff, self.recipes, self.fixture, self.gt, changed)

    def test_i32_rows_reject_boolean_float_width_and_overflow(self):
        for values in ([True], [1.0], [2147483648], [-2147483649], [0, 0]):
            with self.assertRaises(ValueError):
                PACK.field_major([values], 1)

    def test_source_drift_refuses_and_same_bytes_retry(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            path = root / 'source'
            path.write_bytes(b'original')
            expected = PACK.digest(b'original')
            self.assertEqual(PACK.load(root, 'source', expected), b'original')
            path.write_bytes(b'replacement')
            with self.assertRaisesRegex(ValueError, 'source drift'):
                PACK.load(root, 'source', expected)
            path.write_bytes(b'original')
            self.assertEqual(PACK.load(root, 'source', expected), b'original')

    def test_source_size_and_symlink_refuse_before_parse(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            path = root / 'source'
            path.write_bytes(b'x' * 1048577)
            with self.assertRaisesRegex(ValueError, 'bounded offline source'):
                PACK.load(root, 'source')
            path.unlink()
            path.symlink_to(HERE / 'candidate-2/motion.ugmotion')
            with self.assertRaisesRegex(ValueError, 'ordinary contained source'):
                PACK.load(root, 'source')

    def test_cli_refuses_prior_output_and_dangling_output(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp) / 'out'
            out.mkdir()
            marker = out / 'preserved'
            marker.write_text('keep')
            command = [sys.executable, '-B', str(HERE / 'pack_catalog.py'), '--root', str(ROOT), '--out', str(out)]
            completed = subprocess.run(command, capture_output=True)
            self.assertNotEqual(completed.returncode, 0)
            self.assertEqual(marker.read_text(), 'keep')
            marker.unlink(); out.rmdir(); out.symlink_to(Path(temp) / 'absent')
            completed = subprocess.run(command, capture_output=True)
            self.assertNotEqual(completed.returncode, 0)
            self.assertTrue(out.is_symlink())


if __name__ == '__main__':
    unittest.main()
