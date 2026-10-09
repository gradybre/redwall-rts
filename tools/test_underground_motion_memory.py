#!/usr/bin/env python3
"""Current29-row arithmetic and malformed joint storage must not reuse old allowances."""
import unittest

import audit_registry_capacities as audit
import underground_motion_memory as motion


class CurrentMotionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.index = audit.load_source_index()
        path = 'godot/data/underground/mole-worker/mole_profile_catalog.gd'
        cls.index['mole_profile_catalog'] = audit.parse_module('mole_profile_catalog', path,
                                                             (motion.ROOT / path).read_text())

    def changed(self, name, before, after):
        original = self.index[name]
        self.assertIn(before, original.text)
        return dict(self.index, **{name: audit.parse_module(name, original.relative_path,
                                  original.text.replace(before, after, 1))})

    def test_actual_current_dimensions_and_joint_are_derived_once(self):
        result = motion.build(self.index)
        self.assertEqual(result['profile_configuration'], dict(profiles=67, boxes=547, sources=6)) # ADR1229: content 10
        self.assertEqual(result['joint']['profiles'], 2 * (67*98 + 547*28 + 6*32 + 32) + 32768)
        self.assertEqual(result['joint']['total'], 262128)
        self.assertEqual(result['joint']['total'] + 1536 + 8192, 271856) # inside the raised PROFILE_BYTES 278,528
        self.assertEqual(result['paired_bank_bytes'], 2*70860)
        self.assertEqual(result['joint']['independent_maxima_total_refuses'], 444284)
        self.assertFalse(result['native_measured'])

    def test_old_or_mixed_profile_dimensions_are_not_current(self):
        for before, after in (('PROFILE_COUNT: int = 67', 'PROFILE_COUNT: int = 60'),
                              ('BOX_COUNT: int = 547', 'BOX_COUNT: int = 517')):
            with self.subTest(field=before), self.assertRaisesRegex(ValueError, 'current accepted publication'):
                motion.build(self.changed('mole_profile_catalog', before, after))

    def test_new_profile_width_cannot_hide_behind_same_table_count(self):
        with self.assertRaises((ValueError, AssertionError)):
            motion.build(self.changed('underground_profiles', 'I32_FIELDS: int = 18', 'I32_FIELDS: int = 19'))

    def test_one_bank_cannot_be_charged_for_two_retained_images(self):
        with self.assertRaisesRegex(ValueError, 'actual runtime joint formula'):
            motion.build(self.changed('underground_motion_catalog', '+ 2 * BANK_BYTES + DECODE_BYTES',
                                      '+ BANK_BYTES + DECODE_BYTES'))

    def test_declared_native_or_profile_reserve_cannot_grow(self):
        for owner, before, after in (
            ('underground_motion_catalog', 'NATIVE_RESERVE: int = 32768', 'NATIVE_RESERVE: int = 65536'),
            ('underground_profiles', 'CONTROL_RESERVE: int = 32768', 'CONTROL_RESERVE: int = 65536')):
            with self.subTest(owner=owner), self.assertRaises((ValueError, AssertionError)):
                motion.build(self.changed(owner, before, after))


if __name__ == '__main__': unittest.main(verbosity=2)
