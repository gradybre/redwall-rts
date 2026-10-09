#!/usr/bin/env python3
"""Memory-lifetime and exit-zero import mutants for the ADR1143 evidence tools."""
from pathlib import Path
import unittest

import census
import reproduce


HERE = Path(__file__).resolve().parent
SOURCE = (census.ROOT / census.FILE).read_text()


class EvidenceTests(unittest.TestCase):
    def test_chunk_frame_closes_before_next_read(self):
        result = census.decoder_lifetime(SOURCE)
        self.assertEqual(result['maximum_requested_bytes'], 4096)
        self.assertEqual(result['maximum_simultaneous_payload_windows'], 1)

    def test_original_reviewed_loop_lifetime_is_rejected(self):
        old = (HERE / 'source-review-1/underground_motion_catalog.gd.snapshot').read_text()
        with self.assertRaisesRegex(ValueError, 'scoped decoder chunk required'):
            census.decoder_lifetime(old)

    def test_loop_owned_payload_is_rejected(self):
        needle = '\t\tvar code: StringName = _decode_payload('
        changed = SOURCE.replace(needle, '\t\tvar retained: PackedByteArray = _read(file, hashing, 4096)\n' + needle)
        self.assertNotEqual(changed, SOURCE)
        with self.assertRaisesRegex(ValueError, 'chunk loop'):
            census.decoder_lifetime(changed)

    def test_packed_result_or_retained_alias_cannot_escape_chunk_frame(self):
        for before, after in (
            ('span: int, width: int) -> StringName:', 'span: int, width: int) -> PackedByteArray:'),
            ('\tvar bytes: PackedByteArray = _read(file, hashing, span * width)',
             '\tvar bytes: PackedByteArray = _read(file, hashing, span * width)\n\t_digest = bytes'),
        ):
            with self.subTest(after=after):
                changed = SOURCE.replace(before, after)
                self.assertNotEqual(changed, SOURCE)
                with self.assertRaisesRegex(ValueError, 'payload frame'):
                    census.decoder_lifetime(changed)

    def test_read_copy_and_larger_window_are_rejected(self):
        for before, after in (
            ('file.get_buffer(count)', 'file.get_buffer(count).duplicate()'),
            ('const DECODE_BYTES: int = 4096', 'const DECODE_BYTES: int = 8192'),
        ):
            with self.subTest(after=after):
                changed = SOURCE.replace(before, after)
                self.assertNotEqual(changed, SOURCE)
                with self.assertRaises(ValueError):
                    census.decoder_lifetime(changed)

    def test_clean_import_is_accepted(self):
        reproduce.validate_import_log('Godot Engine v4.7.2\n[ DONE ] import\n')
        reproduce.validate_import_log((HERE / 'candidate-4/clean-import.log').read_text())

    def test_exit_zero_cannot_hide_raw_import_diagnostics(self):
        for line in ('ERROR: failure', 'USER ERROR: failure', 'SCRIPT ERROR: abort',
                     'USER SCRIPT ERROR: abort', 'WARNING: warning', 'USER WARNING: warning',
                     'Parse Error: abort', 'Parser Error: abort',
                     '1 ObjectDB instance was leaked at exit',
                     '2 ObjectDB instances were leaked at exit',
                     'ObjectDB instances leaked at exit', '1 resources still in use at exit'):
            with self.subTest(line=line):
                with self.assertRaisesRegex(RuntimeError, 'raw diagnostic or leak'):
                    reproduce.validate_import_log('Godot Engine v4.7.2\n' + line + '\n')


if __name__ == '__main__':
    unittest.main()
