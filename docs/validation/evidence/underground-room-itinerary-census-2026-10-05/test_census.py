#!/usr/bin/env python3
"""Meaningful rejected-source mutations of the independent 1165 census."""
import importlib.util
import argparse
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location('itinerary_census', HERE/'census.py')
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)


class CensusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.actual = C.Audit()
        for module in (C.I,C.W,C.R,C.P,C.F,'source_program'):
            cls.actual.load(module)
        cls.source = cls.actual.sources

    def reject(self, module, before, after, reason):
        self.assertTrue(before in self.source[module], 'mutant anchor absent: '+before)
        mutant=self.source[module].replace(before,after,1)
        with self.assertRaisesRegex(ValueError,reason):
            C.build({module:mutant})

    def test_current_exact_lifetimes(self):
        result=C.build()
        self.assertEqual(result['itinerary']['inclusive_peak'],432)
        self.assertEqual(result['itinerary']['reachable_functions'],61)
        self.assertEqual(result['world_routes_controls']['logical_subtotal'],2094)
        self.assertEqual(result['provider']['accounted'],986)
        self.assertEqual(result['frontier']['accounted'],1966)
        self.assertEqual(result['callers'][C.P]['complete_itinerary_declared_bytes'],553)
        self.assertEqual(result['callers'][C.F]['complete_itinerary_declared_bytes'],456)
        self.assertEqual(result['nonoverlapping_existing_helpers']['single_profile_search']['bytes'],336)
        self.assertEqual(result['nonoverlapping_existing_helpers']['turns']['observed_cargo']['bytes'],464)

    def test_itinerary_may_not_add_retained_reference_or_bank(self):
        for field in ('var hidden: RefCounted\n','var hidden: PackedInt32Array\n','var hidden := []\n'):
            with self.subTest(field=field):
                self.reject(C.I,'extends RefCounted\n','extends RefCounted\n'+field,'retained itinerary')

    def test_itinerary_may_not_hide_inherited_storage(self):
        self.reject(C.I,'extends RefCounted\n','extends "res://scripts/core/underground_routes.gd"\n','inherited state')

    def test_itinerary_may_not_allocate_temporary_array(self):
        self.reject(C.I,'var graph: Routes = actual._routes_ref.get_ref() as Routes\n',
            'var hidden: PackedInt32Array = PackedInt32Array()\n\tvar graph: Routes = actual._routes_ref.get_ref() as Routes\n',
            'unresolved source call|itinerary allocation')

    def test_extra_itinerary_frame_exhausts_original_helper(self):
        added=''.join('\tvar added_%d: int = 0\n'%i for i in range(17))
        self.reject(C.I,'var stride: int = profiles._profile_capacity',
            '\n'+added+'\tvar stride: int = profiles._profile_capacity','helper reservation')

    def test_transitive_source_frame_growth_is_counted(self):
        added=''.join('\tvar added_%d: int = 0\n'%i for i in range(17))
        self.reject('source_program','var policy: int = Profiles.selection_policy_leaf',
            '\n'+added+'\tvar policy: int = Profiles.selection_policy_leaf','helper reservation')

    def test_shared_source_constant_growth_is_not_free(self):
        self.reject('source_program','const VERSION:','const HIDDEN: int = 1\nconst VERSION:',
            'shared SourceProgram payload drift')

    def test_unknown_transitive_callback_refuses(self):
        self.reject(C.I,'var stride: int = profiles._profile_capacity',
            'profiles.hidden_allocation()\n\tvar stride: int = profiles._profile_capacity','unresolved source call')

    def test_untyped_or_floating_helper_value_is_not_free(self):
        for declaration in ('var hidden := 1','var hidden: float = 1.0'):
            with self.subTest(declaration=declaration):
                self.reject(C.I,'var stride: int = profiles._profile_capacity',
                    declaration+'\n\tvar stride: int = profiles._profile_capacity','untyped helper|unaccounted helper')

    def test_added_constant_payload_is_not_free(self):
        self.reject(C.I,'const NULL_REF:', 'const HIDDEN: int = 1\nconst NULL_REF:', 'constant topology')

    def test_directory_callback_guard_is_part_of_proof(self):
        self.reject(C.I,'locations._ids.get_script() != Directory','false','concrete final Directory guard')

    def test_removed_mutual_exclusion_refuses(self):
        before,body=self.source[C.W].split('static func _reach_entry_refusal',1)
        mutant=before+'static func _reach_entry_refusal'+body.replace('graph._occupancy_reading','false',1)
        with self.assertRaisesRegex(ValueError,'lost sequential lifetime guard'):
            C.build({C.W:mutant})

    def test_mixed_query_must_invalidate_single_profile_witness(self):
        self.reject(C.I,'actual._witness_serial = 0','actual._witness_serial = 1','stale search witness')

    def test_lost_certificate_argument_cannot_prune_dynamic_branch(self):
        self.reject(C.W,'actual._descriptor.posture, null, actual)',
            'actual._descriptor.posture, null, null)','static certificate propagation')

    def test_changed_certificate_branch_cannot_prune_dynamic_branch(self):
        self.reject(C.R,'if certificate != null:\n\t\treturn _committed_mask_refusal',
            'if false:\n\t\treturn _committed_mask_refusal','certificate branch ordering')

    def test_dijkstra_storage_may_not_grow(self):
        self.reject(C.R,'_distance.resize(_location_capacity)',
            '_distance.resize(2 * _location_capacity)','route scratch allocation')

    def test_extra_world_routes_reference_is_not_free(self):
        self.reject(C.W,'const Routes :=','var hidden: RefCounted\nconst Routes :=','retained reference/bank topology')

    def test_duplicate_scratch_resize_is_not_deduplicated(self):
        self.reject(C.W,'_bounds.resize(6)','_bounds.resize(6)\n\t_bounds.resize(6)','fixed WorldRoutes scratch changed')

    def test_nested_route_packet_field_is_not_free(self):
        self.reject(C.R,'class Edge extends RefCounted:\n',
            'class Edge extends RefCounted:\n\tvar hidden: RefCounted\n','retained reference/bank topology')

    def test_provider_field_is_not_a_second_packet(self):
        self.reject(C.P,'var _ordinary_routes:', 'var hidden: RefCounted\nvar _ordinary_routes:', 'caller retained member drift')

    def test_frontier_packet_field_is_counted(self):
        self.reject(C.F,'class Query extends RefCounted:\n','class Query extends RefCounted:\n\tvar hidden: int = 0\n','frontier packet drift')

    def test_caller_changes_outside_dispatch_need_review(self):
        self.reject(C.P,'func _ordinary_selected_leaf() -> StringName:',
            'func _ordinary_selected_leaf() -> StringName:\n\tvar hidden: int = 0','unreviewed caller function change')

    def test_current_integrated_caller_cannot_become_its_own_predecessor(self):
        original=C.path
        def guarded(module):
            self.assertNotIn(module,(C.P,C.F),'baseline must come from immutable predecessor witness')
            return original(module)
        with patch.object(C,'path',guarded):
            self.assertEqual(C.build()['provider']['accounted'],986)

    def witness_directory(self, which, mutate, bless=False):
        pins=json.loads((HERE/'predecessor-sha256.json').read_text())
        pin=pins[which]
        data=mutate((HERE/pin['snapshot']).read_bytes())
        if bless:
            pin['sha256']=hashlib.sha256(data).hexdigest()
            pin['imports']=sorted(set(pin['imports']+['operator']))
        temporary=tempfile.TemporaryDirectory(dir=HERE,prefix='mutation-')
        base=Path(temporary.name)
        target=base/pin['snapshot'];target.parent.mkdir(parents=True)
        target.write_bytes(data)
        (base/'predecessor-sha256.json').write_text(json.dumps(pins))
        return temporary,base

    def test_caller_predecessor_bytes_are_pinned(self):
        temporary,base=self.witness_directory(C.P,lambda data:data+b'\n')
        with temporary,patch.object(C,'E',base):
            with self.assertRaisesRegex(ValueError,'caller predecessor witness changed'):
                C.predecessor(C.P)

    def test_turn_producer_is_pinned_before_import(self):
        temporary,base=self.witness_directory('turn_paths',lambda data:data+b'\n')
        with temporary,patch.object(C,'E',base):
            with self.assertRaisesRegex(ValueError,'reviewed predecessor witness changed'):
                C.load_paths('underground-ground-turn-2026-10-04/census.py')

    def test_rehashed_turn_import_expansion_still_needs_review(self):
        temporary,base=self.witness_directory('turn_paths',lambda data:data+b'\nimport operator\n',True)
        with temporary,patch.object(C,'E',base):
            with self.assertRaisesRegex(ValueError,'unreviewed predecessor import closure'):
                C.load_paths('underground-ground-turn-2026-10-04/census.py')


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--runtime-root',type=Path)
    args,remaining=parser.parse_known_args()
    if args.runtime_root is not None:
        C.ROOT=args.runtime_root.resolve()
    unittest.main(argv=[sys.argv[0],*remaining],verbosity=2)
