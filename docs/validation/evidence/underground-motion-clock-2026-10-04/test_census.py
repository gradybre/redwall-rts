#!/usr/bin/env python3
"""Reject hidden clock storage, lost numeric guards and unaccounted helper growth."""
import unittest
import census


class CensusTests(unittest.TestCase):
    def setUp(self):
        self.source = (census.ROOT / census.FILE).read_text()

    def test_current_joint_admission(self):
        result = census.build(self.source)
        self.assertEqual(result['retained_fields_or_banks'], 0)
        self.assertEqual(result['clock_caller_bytes'], 44)
        self.assertEqual(result['additional_logical_counted'], 208)
        self.assertEqual(result['combined_logical_counted'], 1298)
        self.assertEqual(result['joint']['total'], 232436)
        self.assertFalse(result['native_measured'])

    def test_retained_clock_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'retained'):
            census.build(self.source + '\nvar _tick: int = 0\n')

    def test_allocated_scratch_is_rejected(self):
        changed = self.source.replace('var ticks: int', 'var extra: PackedInt32Array = PackedInt32Array()\n\tvar ticks: int')
        with self.assertRaisesRegex(ValueError, 'allocation'):
            census.build(changed)

    def test_lost_integer_boundary_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'integer boundary'):
            census.build(self.source.replace('typeof(from_tick) != TYPE_INT', 'false'))

    def test_helper_growth_is_rejected(self):
        extra = ''.join(f'\tvar extra_{i}: int = {i}\n' for i in range(8))
        with self.assertRaises(ValueError):
            census.build(self.source.replace('\tif program == 0 or program == 1:', extra + '\tif program == 0 or program == 1:'))

    def test_changed_caller_shape_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'caller shape'):
            census.build(self.source.replace('intervals_out.size() != 2', 'intervals_out.size() != 3'))


if __name__ == '__main__':
    unittest.main()
