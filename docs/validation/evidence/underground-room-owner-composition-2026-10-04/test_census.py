#!/usr/bin/env python3
"""Meaningful current-source/lifetime/borrowed-bank negatives; no engine or foreign writes."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import census as C
import constructor_census as K


class CensusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources={name:(C.ROOT/path).read_text() for name,path in C.FILES.items()}

    def changed(self,module,old,new):
        self.assertIn(old,self.sources[module])
        return {module:self.sources[module].replace(old,new,1)}

    def rejects(self,replacements,pattern):
        with self.assertRaisesRegex(ValueError,pattern): C.build(replacements)

    def test_complete_current_reset_and_constructor_lifetimes(self):
        result=C.build()
        self.assertEqual(result['accounting']['controls'],6019)
        self.assertEqual(result['accounting']['helpers'],1903)
        self.assertEqual(result['constructor_exclusive_reuse']['absent_total'],2065)
        self.assertEqual(result['constructor_exclusive_reuse']['simultaneous_total'],7493)
        self.assertEqual(result['constructor']['maximum_case'],'location_domain')
        self.assertFalse(result['native_measured'])
        self.assertEqual(result['additional_packed_bytes'],0)

    def test_extra_retained_field_is_not_hidden_in_old_control_allowance(self):
        self.rejects({'Session':self.sources['Session']+'\nvar _extra: int = 0\n'},'exact retained')

    def test_second_persistent_owner_packet_refuses(self):
        self.rejects(self.changed('Session','Retirement.Owners.new()',
          'Retirement.Owners.new() # Retirement.Owners.new()'),'one permanent packet')

    def test_mutated_scope_field_width_refuses(self):
        self.rejects(self.changed('Retirement','_constructor_prefix: int','_constructor_prefix: float'),'fixed private')

    def test_composer_field_or_extra_owner_refuses(self):
        self.rejects({'Composition':self.sources['Composition']+'\nvar retained: RefCounted = null\n'},'stateless')
        self.rejects(self.changed('Composition','o.authority = Authority.new()',
          'o.authority = Authority.new()\n\tvar duplicate: Authority = Authority.new()'),'owner multiplicity')

    def test_constructor_capacity_growth_refuses(self):
        self.rejects(self.changed('Composition','Budget.PROOF_CAPACITY)',
          'Budget.PROOF_CAPACITY * 2)'),'admitted constructor capacities')

    def test_catalog_cannot_eagerly_allocate_an_unaccounted_second_bank(self):
        self.rejects(self.changed('RoomCatalog','_definitions: BuildingDefinitions = null',
          '_definitions: BuildingDefinitions = BuildingDefinitions.new()'),'no eager duplicate')

    def test_composer_cannot_drop_original_catalog_borrow(self):
        self.rejects(self.changed('Composition','RoomCatalog.new(o.buildings._definitions)',
          'RoomCatalog.new()'),'borrow original catalog')

    def test_missing_original_facts_cannot_fall_back_to_new_catalog(self):
        self.rejects(self.changed('Composition','code == &"" and o.buildings._definitions == null',
          'false and o.buildings._definitions == null'),'null source cannot trigger')

    def test_catalog_normal_and_prefix_identity_both_remain_required(self):
        self.rejects(self.changed('Composition','Retirement.constructor_catalog_refusal(o)',
          'Retirement._owners_refusal(o)'),'full and prefix catalog identity')
        self.rejects(self.changed('Retirement','o.rooms != null and constructor_catalog_refusal(o)',
          'false and constructor_catalog_refusal(o)'),'full and prefix catalog identity')

    def test_existing_scope_cannot_coexist_with_constructor_scratch(self):
        self.rejects(self.changed('Session','if _retirement_scope != null:\n\t\treturn &"UNDERGROUND_SESSION_RETIRING"',
          'if false:\n\t\treturn &"UNDERGROUND_SESSION_RETIRING"'),'no existing Scope')

    def test_reentrant_scope_creation_refuses_new_reuse_claim(self):
        self.rejects(self.changed('Session','if _busy or not _ready:\n\t\treturn &"UNDERGROUND_SESSION_UNAVAILABLE"',
          'if not _ready:\n\t\treturn &"UNDERGROUND_SESSION_UNAVAILABLE"'),'no reentrant Scope')

    def test_clearing_busy_before_construct_refuses(self):
        self.rejects(self.changed('Session','code = Composition.construct(self)',
          '_busy = false\n\tcode = Composition.construct(self)'),'exclusive constructor')

    def test_helper_growth_exceeds_reset_envelope(self):
        additions=''.join('\tvar extra_%d: int = 0\n'%i for i in range(64))
        self.rejects(self.changed('Retirement','static func _owners_refusal(o: Owners, constructor_prefix: int = -1) -> StringName:\n',
          'static func _owners_refusal(o: Owners, constructor_prefix: int = -1) -> StringName:\n'+additions),'reset/UI envelope')

    def test_source_counted_domain_constructor_drift_refuses(self):
        path='godot/scripts/core/room_space.gd'; source=(C.ROOT/path).read_text()
        with self.assertRaisesRegex(ValueError,'constructor source drift'):
            C.build(constructor_replacements={path:source.replace('"max_cells": _cells',
              '"extra_key": 0, "max_cells": _cells',1)})

    def test_packed_allocation_alias_copy_cannot_hide_under_same_capacity(self):
        path='godot/scripts/core/excavation_sites.gd';source=(C.ROOT/path).read_text()
        with self.assertRaisesRegex(ValueError,'constructor source drift'):
            C.build(constructor_replacements={path:source.replace('column.resize(_capacity)',
              'column = column.duplicate()\n\t\tcolumn.resize(_capacity)',1)})

    def test_coordinated_constructor_manifest_rewrite_refuses(self):
        with tempfile.TemporaryDirectory() as directory:
            original=(K.HERE/'constructor-source-sha256.json').read_bytes()
            rows=json.loads(original);key=next(iter(rows))
            rows[key]['sha256']=hashlib.sha256(b'mutated producer').hexdigest()
            (Path(directory)/'constructor-source-sha256.json').write_text(json.dumps(rows))
            with patch.object(K,'HERE',Path(directory)):
                with self.assertRaisesRegex(ValueError,'constructor manifest drift'): C.build()

    def test_predecessor_manifest_rewrite_refuses_before_using_old_accounting(self):
        with tempfile.TemporaryDirectory() as directory:
            target=Path(directory)/'predecessor';target.mkdir()
            rows=json.loads((C.HERE/'predecessor/manifest.json').read_text())
            rows[next(iter(rows))]['sha256']='0'*64
            (target/'manifest.json').write_text(json.dumps(rows))
            with patch.object(C,'HERE',Path(directory)):
                with self.assertRaisesRegex(ValueError,'predecessor manifest drift'): C.build()

    def test_constructor_stack_or_heap_growth_exceeds_exclusive_slice(self):
        original=K.build
        def grown(*args,**kwargs):
            result=copy.deepcopy(original(*args,**kwargs))
            result['maximum_provisional_bytes']+=1024
            return result
        with patch.object(K,'build',grown):
            with self.assertRaisesRegex(ValueError,'constructor simultaneous peak'): C.build()


if __name__=='__main__': unittest.main()
