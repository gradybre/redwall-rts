#!/usr/bin/env python3
"""Source/capacity/lifetime mutations for the actual1167 census."""
import json
from pathlib import Path
import unittest
from unittest.mock import patch
import census as C


class CensusTests(unittest.TestCase):
    def source(self,name):return (C.ROOT/C.FILES[name]).read_text()

    def refuses(self,name,old,new):
        text=self.source(name);self.assertIn(old,text)
        with self.assertRaises(ValueError):C.build({name:text.replace(old,new,1)})

    def test_actual_composed_peak(self):
        result=C.build();self.assertEqual(result['retained_numeric_delta'],0)
        self.assertLessEqual(result['accounting']['controls'],6144)
        self.assertLessEqual(result['accounting']['helpers'],2048)
        self.assertLessEqual(result['constructor_exclusive_reuse']['simultaneous_total'],8192)
        self.assertFalse(result['native_measured']);self.assertFalse(result['runtime_qualified'])

    def test_added_session_field_refuses(self):
        self.refuses('Session','var _ready: bool = false','var extra: int = 0\nvar _ready: bool = false')

    def test_added_scope_field_refuses(self):
        self.refuses('Retirement','var _stage: int = 0','var extra: int = 0\n\tvar _stage: int = 0')

    def test_second_owner_packet_refuses(self):
        self.refuses('Session','_retirement_owners = Retirement.Owners.new()',
          '_retirement_owners = Retirement.Owners.new()\n\t_retirement_owners = Retirement.Owners.new()')

    def test_second_movement_refuses(self):
        self.refuses('RouteComposition','config.movement = Movement.new(',
          'config.movement = Movement.new(o.directory, null, null, o.transforms, o.residents)\n\tconfig.movement = Movement.new(')

    def test_larger_graph_capacity_refuses(self):
        self.refuses('RouteComposition','Routes.MAX_LINKS, Budget.LOCATION_AND_TOPOLOGY_BYTES)',
          'Routes.MAX_LINKS + 1, Budget.LOCATION_AND_TOPOLOGY_BYTES)')

    def test_new_helper_buffer_refuses(self):
        self.refuses('RouteComposition','var o: Retirement.Owners = session._retirement_owners',
          'var scratch: PackedByteArray = PackedByteArray()\n\tvar o: Retirement.Owners = session._retirement_owners')

    def test_configuration_lifetime_overlap_refuses(self):
        self.refuses('RouteComposition','_prepare_candidate(session)','_bind_graph(session)')

    def test_publish_before_configuration_refuses(self):
        self.refuses('RouteComposition','code = candidate.configure(config)',
          'session._retirement_owners.world_routes = candidate\n\tcode = candidate.configure(config)')

    def test_source_revision_is_not_latest(self):
        self.refuses('RouteComposition','const PROFILE_CONTENT_REVISION: int = 2','const PROFILE_CONTENT_REVISION: int = 3')

    def test_catalog_digest_word_drift_refuses(self):
        self.refuses('RouteComposition','const CATALOG_DIGEST_0: int = 4793882819857776664',
          'const CATALOG_DIGEST_0: int = 4793882819857776665')

    def test_inherited_manifest_is_fixed_before_reading_producer(self):
        original=Path.read_bytes
        def read(path):
            data=original(path)
            return data+b' ' if path==C.HERE/'inherited-sha256.json' else data
        with patch.object(Path,'read_bytes',read),self.assertRaises(ValueError):C.build()

    def test_foreign_constructor_source_drift_refuses(self):
        original=Path.read_bytes
        def read(path):
            data=original(path)
            return data+b'\n' if path==C.ROOT/'godot/scripts/core/movement.gd' else data
        with patch.object(Path,'read_bytes',read),self.assertRaises(ValueError):C.build()

    def test_additional_constructor_reference_exceeds_exact_remaining_margin(self):
        self.refuses('RouteComposition','var config: WorldRoutes.Configuration = _configuration(session._retirement_owners)',
          'var spare: RefCounted = null\n\tvar config: WorldRoutes.Configuration = _configuration(session._retirement_owners)')

    def test_extra_source_constant_is_counted(self):
        self.refuses('RouteComposition','const CATALOG_REVISION: int = 1',
          'const EXTRA: int = 1\nconst CATALOG_REVISION: int = 1')

    def test_level_identity_and_foreign_lifetime_sources_remain_current(self):
        original=Path.read_bytes
        for name in ('godot/scripts/core/underground_level_catalog.gd','godot/scripts/core/buildings.gd',
          'godot/scripts/systems/ui_manager.gd'):
            with self.subTest(name=name):
                def read(path):
                    data=original(path)
                    return data+b'\n' if path==C.ROOT/name else data
                with patch.object(Path,'read_bytes',read),self.assertRaises(ValueError):C.build()

    def test_engine_lifetime_rule_drift_refuses(self):
        original=Path.read_bytes
        target=C.HERE/'engine-lifetime/gdscript_function.h.txt'
        def read(path):
            data=original(path)
            return data.replace(b'return true;',b'return false;',1) if path==target else data
        with patch.object(Path,'read_bytes',read),self.assertRaises(ValueError):C.build()


if __name__=='__main__':unittest.main()
