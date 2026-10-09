#!/usr/bin/env python3
"""Mutation checks for the complete 1184 initial-lifecycle logical census."""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('entry_census', HERE / 'census.py')
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)


class CensusTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = {name: (C.ROOT / path).read_text() for name, path in C.FILES.items()}
        cls.result = C.build()

    def mutate(self, name, before, after, reason=None):
        self.assertIn(before, self.source[name])
        changed = self.source[name].replace(before, after, 1)
        with self.assertRaisesRegex(ValueError, reason or '.'):
            C.build({C.FILES[name]: changed})

    def test_current_complete_lifetime_and_partitions(self):
        self.assertEqual(self.result['accounting']['controls'], 6195)
        self.assertEqual(self.result['accounting']['helpers'], 1919)
        self.assertEqual(self.result['constructor_exclusive_reuse']['simultaneous_total'], 8186)
        self.assertEqual(self.result['constructor_exclusive_reuse']['remaining'], 6)
        self.assertEqual(self.result['route_constructor']['maximum_case'], 'provider_level_identity')
        self.assertEqual(self.result['accounting']['additional_global_reserved_bytes'], 0)
        self.assertFalse(self.result['native_measured'])
        self.assertFalse(self.result['runtime_qualified'])

    def test_all_reset_failure_abandon_and_cold_phases_remain_counted(self):
        phases = self.result['phases']
        self.assertEqual(len(phases), 5)
        all_frames = set().union(*(row['frames'] for row in phases.values()))
        self.assertTrue({'Host.abandon_world_reset', 'Host._clear_stores', 'Planner.clear',
                         'Policy.clear', 'Retirement.release_preflighted', 'UI._cleanup_failed_create',
                         'SurfaceAnchor.world_retirement_release_preflighted_in'} <= all_frames)
        self.assertTrue(all(row['provisional_bytes'] <= 1984 for row in phases.values()))
        self.assertLessEqual(self.result['existing_owners']['initialization_provisional_peak'], 1984)

    def test_extra_host_reference_refuses(self):
        self.mutate('Host', 'var _store_policy: StorePolicyScript = null',
                    'var _store_policy: StorePolicyScript = null\nvar _hidden: RefCounted = null',
                    'member/constant')

    def test_member_packed_initializer_growth_refuses(self):
        self.mutate('Host', 'var _store_policy: StorePolicyScript = null',
                    'var _store_policy: StorePolicyScript = null\nvar _hidden: PackedInt32Array = [0, 0]',
                    'member/constant')

    def test_retained_scope_growth_refuses(self):
        self.mutate('Retirement', 'class Scope extends RefCounted:\n',
                    'class Scope extends RefCounted:\n\tvar hidden: RefCounted = null\n', 'unchanged original Scope')

    def test_local_packed_constructor_refuses(self):
        self.mutate('Host', 'func _haul_owners_refusal() -> StringName:\n',
                    'func _haul_owners_refusal() -> StringName:\n\tvar hidden: PackedInt32Array = PackedInt32Array([0, 0])\n',
                    'collection allocation')

    def test_literal_payload_cannot_hide_in_declared_numeric_slot(self):
        self.mutate('Retirement', 'static func _catalog_refusal(o: Owners, binding: WorldRoutes) -> StringName:\n',
                    'static func _catalog_refusal(o: Owners, binding: WorldRoutes) -> StringName:\n\tvar hidden: int = [0, 0].size()\n',
                    'collection allocation')

    def test_foreign_allocating_call_cannot_hide_in_leaf(self):
        self.mutate('Host', 'func _haul_owners_refusal() -> StringName:\n',
                    'func _haul_owners_refusal() -> StringName:\n\t_inventory.state_bytes()\n', 'transitive call')

    def test_constructor_reference_growth_is_counted(self):
        self.mutate('RouteComposition', 'static func construct(session: RefCounted) -> StringName:\n',
                    'static func construct(session: RefCounted) -> StringName:\n\tvar hidden: RefCounted = null\n',
                    'constructor coexistence')

    def test_helper_numeric_growth_is_counted(self):
        line = 'static func _catalog_refusal(o: Owners, binding: WorldRoutes) -> StringName:\n'
        extra = ''.join('\tvar hidden%d: int = 0\n' % n for n in range(32))
        self.mutate('Retirement', line, line + extra, 'controls/helpers')

    def test_no_late_configuration_lifetime(self):
        self.mutate('RouteComposition', 'config = null # The temporary', 'config = config # The temporary')

    def test_no_extra_prepare_frame_or_owner_argument(self):
        self.mutate('RouteComposition', 'static func _prepare_catalog(config: WorldRoutes.Configuration) -> StringName:',
                    'static func _prepare_catalog(config: WorldRoutes.Configuration, o: Retirement.Owners) -> StringName:',
                    'duplicate Owners')

    def test_no_second_planner(self):
        self.mutate('Host', '_haul_planner = HaulPlannerScript.new()',
                    '_haul_planner = HaulPlannerScript.new()\n\t_haul_planner = HaulPlannerScript.new()',
                    'allocation phase')

    def test_no_skipped_reset(self):
        self.mutate('Host', '\t_store_policy.clear()\n', '\t# no policy clear\n', 'transitive call')

    def test_exact_initial_entry_subtype(self):
        self.mutate('Composition', 'core/underground_entry_bindings.gd',
                    'core/underground_room_bindings.gd', 'EntryBindings')

    def test_foreign_capacity_drift_refuses_before_import(self):
        path = 'godot/scripts/core/haul_planner.gd'
        source = (C.ROOT / path).read_text()
        with patch.object(C.importlib.util, 'spec_from_file_location', side_effect=AssertionError('imported')):
            with self.assertRaisesRegex(ValueError, 'unchanged concrete'):
                C.build({path: source + '\nvar hidden: PackedInt32Array = [0, 0]\n'})

    def test_captured_producer_drift_refuses_before_import(self):
        path = C.PRODUCERS['ctor']
        with patch.object(C.importlib.util, 'spec_from_file_location', side_effect=AssertionError('imported')):
            with self.assertRaisesRegex(ValueError, 'immutable input/producer'):
                C.build(captured={path: (C.ROOT / path).read_bytes() + b'\nraise RuntimeError()\n'})

    def test_coordinated_producer_manifest_rewrite_refuses(self):
        path = C.PRODUCERS['base']
        raw = (C.ROOT / path).read_bytes() + b'\nraise RuntimeError()\n'
        manifest = json.loads((HERE / 'baseline/manifest.json').read_text())
        manifest[path]['sha256'] = hashlib.sha256(raw).hexdigest()
        with patch.object(C.importlib.util, 'spec_from_file_location', side_effect=AssertionError('imported')):
            with self.assertRaisesRegex(ValueError, 'immutable baseline manifest'):
                C.build(captured={path: raw, 'baseline/manifest.json': json.dumps(manifest).encode()})

    def test_captured_pack_drift_refuses(self):
        path = str((HERE / 'baseline/underground_memory_pack.json.txt').relative_to(C.ROOT))
        raw = (C.ROOT / path).read_bytes().replace(b'"controls": 6131', b'"controls": 1')
        self.assertNotEqual(raw, (C.ROOT / path).read_bytes())
        with self.assertRaisesRegex(ValueError, 'immutable input/producer'):
            C.build(captured={path: raw})

    def test_each_limit_remains_exact(self):
        for name in ('CONTROL_CEILING', 'HELPER_CEILING', 'RESERVED_BYTES'):
            with self.subTest(name=name), patch.object(C, name, getattr(C, name) + 64):
                with self.assertRaisesRegex(ValueError, 'no enlarged envelope'):
                    C.build()

    def test_unknown_injected_source_is_never_ignored(self):
        with self.assertRaisesRegex(ValueError, 'unknown current'):
            C.build({'unknown.gd': 'var x = 1'})

    def test_serialization_reproduces_all_source_and_lifetime_rows(self):
        actual = json.dumps(C.build(), indent=2) + '\n'
        self.assertEqual(actual, (HERE / 'census.json').read_text())


if __name__ == '__main__':
    unittest.main(verbosity=2)
