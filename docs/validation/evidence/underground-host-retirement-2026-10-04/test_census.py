#!/usr/bin/env python3
"""Source-lifetime/width/order mutants for the actual Session and host retirement composition."""
import unittest
import census as C


class CensusTests(unittest.TestCase):
    def mutate(self, module, old, new):
        source = (C.ROOT / C.FILES[module]).read_text()
        self.assertIn(old, source)
        with self.assertRaises(ValueError):
            C.build(replacements={module: source.replace(old, new, 1)})

    def test_exact_joint_controls_and_complete_chain(self):
        row = C.build()
        self.assertEqual(row['joint_numeric_bytes'], 84)
        self.assertEqual(row['joint_reference_slots'], 111)
        self.assertEqual(row['maximum_numeric_bytes'], 170)
        self.assertEqual(row['maximum_reference_values'], 23)
        self.assertEqual(row['accounting']['control_provisional_bytes'], 5673)
        self.assertEqual(row['accounting']['helper_provisional_bytes'], 1162)
        self.assertEqual(row['accounting']['joint_with_retirement'], 246868)
        self.assertIn('Buildings.whole_world_retirement_refusal_in', row['frames'])
        self.assertIn('Session._retirement_packet_refusal', row['frames'])
        self.assertFalse(row['native_measured'])
        self.assertFalse(row['runtime_qualified'])

    def test_new_session_field_cannot_hide_in_original_reserve(self):
        self.mutate('Session', 'var _retirement_scope: Retirement.Scope = null',
                    'var _retirement_scope: Retirement.Scope = null\nvar _extra: RefCounted = null')

    def test_two_reference_fields_cannot_become_banks(self):
        self.mutate('Session', 'var _retirement_scope: Retirement.Scope',
                    'var _retirement_scope: PackedInt32Array')

    def test_boolean_cannot_represent_four_host_phases(self):
        self.mutate('Host', 'var _underground_reset_phase: int', 'var _underground_reset_phase: bool')

    def test_original_session_reserve_cannot_grow(self):
        self.mutate('Session', 'const CONTROL_BYTES: int = 1024', 'const CONTROL_BYTES: int = 8192')

    def test_retirement_reserve_cannot_grow(self):
        self.mutate('Retirement', 'const RETIREMENT_RESERVED_BYTES: int = 8192',
                    'const RETIREMENT_RESERVED_BYTES: int = 16384')

    def test_repeated_prepare_cannot_allocate_new_scope(self):
        self.mutate('Session', 'if _retirement_scope == null:\n\t\t_retirement_scope = Retirement.Scope.new()',
                    '_retirement_scope = Retirement.Scope.new()')

    def test_clear_requires_distinct_stop_before_first_write(self):
        self.mutate('Host', '_underground_reset_phase = 3\n\t_clear_stores()', '_clear_stores()\n\t_underground_reset_phase = 3')

    def test_no_abandon_after_clear(self):
        self.mutate('Host', 'if _underground_reset_phase != 2 or _underground_session == null:',
                    'if _underground_session == null:')

    def test_post_observer_mount_leaf_cannot_be_removed(self):
        self.mutate('Host', 'if code == &"": code = _mounted_underground_refusal(original)',
                    'if code == &"": code = &""')

    def test_scope_cycle_dropped_before_packet(self):
        self.mutate('Session', '_retirement_scope = null\n\t_retirement_owners = null',
                    '_retirement_owners = null\n\t_retirement_scope = null')

    def test_fixed_tick_guard_cannot_be_moved_after_dispatch(self):
        source = (C.ROOT / C.FILES['Host']).read_text()
        prefix = source.index('func run_tick(')
        start = source.index('if _underground_reset_phase != 0:', prefix)
        modified = source[:start] + source[start:].replace('if _underground_reset_phase != 0:', 'if false:', 1)
        with self.assertRaises(ValueError):
            C.build(replacements={'Host': modified})

    def test_variable_caller_scratch_refuses(self):
        self.mutate('Host', 'var original: UndergroundSession = _underground_session',
                    'var scratch: PackedByteArray = PackedByteArray()\n\tvar original: UndergroundSession = _underground_session')

    def test_transitive_new_helper_stack_growth_is_counted(self):
        source = (C.ROOT / C.FILES['Session']).read_text()
        source = source.replace('var o: Retirement.Owners = _retirement_owners',
                                '_extra_retirement_check()\n\tvar o: Retirement.Owners = _retirement_owners', 1)
        source += '\n\nfunc _extra_retirement_check() -> void:\n'
        source += ''.join(f'\tvar padding_{i}: int = 0\n' for i in range(300))
        with self.assertRaises(ValueError):
            C.build(replacements={'Session': source})

    def test_reference_returns_and_implicit_receivers_counted(self):
        rows = C.parse('func example(input: Object) -> Object:\n\treturn input\n', 'Session')
        self.assertEqual(rows['Session.example']['reference_values'], 3)

    def test_inherited_static_owner_observer_remains_rejected(self):
        self.mutate('Buildings', 'if actual == null or actual._directory != ids:',
                    'actual.audit()\n\tif actual == null or actual._directory != ids:')


if __name__ == '__main__':
    unittest.main()
