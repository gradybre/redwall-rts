#!/usr/bin/env python3
"""The renewed Clock keeps its exact digest-only delta and existing shared slices."""
import unittest

import audit_registry_capacities as audit
import underground_motion_clock_memory as clock
import underground_motion_memory as motion


class CurrentClockTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.index = audit.load_source_index()
        path = 'godot/data/underground/mole-worker/mole_profile_catalog.gd'
        cls.index['mole_profile_catalog'] = audit.parse_module('mole_profile_catalog', path,
                                                             (motion.ROOT / path).read_text())
        cls.baseline = motion.build(cls.index)

    def refused(self, before, after):
        old = self.index['underground_motion_clock']
        self.assertIn(before, old.text)
        current = old._replace(text=old.text.replace(before, after, 1))
        with self.assertRaisesRegex(ValueError, 'complete Clock executable changed'):
            clock.build(dict(self.index, underground_motion_clock=current), self.baseline)

    def test_digest_only_delta_preserves_clock_helper_and_caller_lifetimes(self):
        result = clock.build(self.index, self.baseline)
        old = (motion.ROOT / 'docs/validation/evidence/underground-short-step-publication-2026-10-05/baseline/underground_motion_clock.gd.txt').read_text()
        source = self.index['underground_motion_clock'].text
        before = '2f44037e5e4eed0b4e2966cd1ac1881bdf4481dd083a26b11d8eea0c5ca0f986'
        after = 'be301fdbbd6c6718a880058cfe79eae9519f49d347f713863c5cae1eddea13d6' # ADR1217 step 5: content 9
        self.assertEqual(old.count(before), 1)
        self.assertEqual(source, old.replace(before, after))
        self.assertEqual((result['combined_logical_counted'], result['shared_logical_helper_reservation']), (1298, 4096))
        self.assertEqual((result['clock_caller_bytes'], result['shared_caller_reservation']), (44, 176))
        self.assertEqual(result['retained_fields_or_banks'], 0)
        self.assertFalse(result['native_measured'])

    def test_old_wire_cannot_be_reported_as_current(self):
        for old in ('69fd9011da9b9c1d85e206401ef287943381a24d19322946287234b2dc66850c',
                    '2f44037e5e4eed0b4e2966cd1ac1881bdf4481dd083a26b11d8eea0c5ca0f986',
                    '3024e922f8959f0c386ba9c5d136cdc2a96c35c9de5c860dec03030a9b4d292c'):
            self.refused('be301fdbbd6c6718a880058cfe79eae9519f49d347f713863c5cae1eddea13d6', old)

    def test_same_frame_algorithm_change_requires_review(self):
        self.refused('TREAD_TICKS: int = 30', 'TREAD_TICKS: int = 31')

    def test_hidden_static_array_and_range_are_not_metadata(self):
        for extra in ('static var hidden: Array[int] = [1, 2, 3]\n',
                      'static var hidden: Array = range(1000000)\n'):
            with self.subTest(extra=extra): self.refused('const TREAD_TICKS', extra+'const TREAD_TICKS')

    def test_extra_caller_storage_is_not_covered_by_same_helper(self):
        self.refused('intervals_out.size() != 2', 'intervals_out.size() != 3')


if __name__ == '__main__': unittest.main(verbosity=2)
