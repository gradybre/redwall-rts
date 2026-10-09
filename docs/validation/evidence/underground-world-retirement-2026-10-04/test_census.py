#!/usr/bin/env python3
"""Meaningful refusal mutants for tuple, ownership, allocation and complete static-chain accounting."""
import unittest
import census as C


class CensusTests(unittest.TestCase):
    def mutate(self, module, old, new):
        source = (C.ROOT / C.FILES[module]).read_text()
        self.assertIn(old, source)
        with self.assertRaises(ValueError):
            C.build(replacements={module: source.replace(old, new, 1)})

    def test_current_complete_chain_and_joint_counts(self):
        row = C.build()
        self.assertEqual(row['joint_member_reference_slots'], 109)
        self.assertEqual(row['joint_member_numeric_bytes'], 76)
        self.assertEqual(row['additional_numeric_constant_bytes'], 16)
        self.assertEqual(row['maximum_numeric_chain_bytes'], 141)
        self.assertEqual(row['maximum_reference_chain_values'], 18)
        self.assertEqual(row['proposal']['proposed_profile_joint_bytes'], 246868)
        self.assertFalse(row['native_measured'])
        self.assertFalse(row['proposal']['adopted'])

    def test_added_owner_field_requires_census(self):
        self.mutate('Retirement', 'var content: RefCounted = null',
                    'var content: RefCounted = null\n\tvar replacement: RefCounted = null')

    def test_missing_original_owner_copy_refuses(self):
        self.mutate('Retirement', 'target.work = source.work', 'target.work = null')

    def test_optional_identity_comparison_cannot_disappear(self):
        self.mutate('Retirement', 'and first.locations == second.locations', 'and true')

    def test_retained_bank_refuses(self):
        self.mutate('Retirement', 'var _stage: int = 0', 'var _stage: PackedInt32Array = PackedInt32Array() #')

    def test_late_allocation_refuses(self):
        self.mutate('Work', 'actual._spatial_delivery = null',
                    'var late: RefCounted = RefCounted.new()\n\tactual._spatial_delivery = late')

    def test_transitive_observer_refuses(self):
        self.mutate('Buildings', 'if actual == null or actual._directory != ids:',
                    'actual.audit()\n\tif actual == null or actual._directory != ids:')

    def test_nonstatic_owner_release_refuses(self):
        self.mutate('Inventory', 'static func world_retirement_release_preflighted_in',
                    'func world_retirement_release_preflighted_in')

    def test_kernel_foreign_field_write_refuses(self):
        self.mutate('Retirement', 'var o: Owners = scope._owners\n\tcode = Buildings.',
                    'var o: Owners = scope._owners\n\to.buildings._spatial_authority = null\n\tcode = Buildings.')

    def test_missing_joint_preflight_refuses(self):
        self.mutate('Retirement', 'var code: StringName = cleared_refusal(scope, original_host, original_session)',
                    'var code: StringName = &""')

    def test_reuse_cannot_resize_existing_arena(self):
        self.mutate('Inventory', 'if _spatial_container_slot.is_empty():\n\t\t_allocate_spatial_arena(capacity)',
                    '_allocate_spatial_arena(capacity)')

    def test_existing_session_reserve_cannot_expand(self):
        self.mutate('Session', 'const CONTROL_BYTES: int = 1024', 'const CONTROL_BYTES: int = 8192')

    def test_retirement_carve_out_cannot_expand(self):
        self.mutate('Retirement', 'const RETIREMENT_RESERVED_BYTES: int = 8192',
                    'const RETIREMENT_RESERVED_BYTES: int = 16384')


if __name__ == '__main__':
    unittest.main()
