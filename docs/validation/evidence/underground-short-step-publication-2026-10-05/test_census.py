#!/usr/bin/env python3
"""Reject added storage/calls despite equal advertised row counts or unchanged source hash literals."""
import importlib.util
from pathlib import Path
import unittest

SPEC=importlib.util.spec_from_file_location('publication_census',Path(__file__).with_name('census.py'))
M=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(M)

class CensusTests(unittest.TestCase):
    def test_actual_joint(self):
        report=M.build()
        self.assertEqual(report['joint'],248632)
        self.assertEqual(report['remaining'],13512)
        self.assertEqual(report['catalog']['cached_consumers'],10)
        self.assertEqual(report['retained_owner_fields_delta'],0)
        self.assertEqual(report['runtime_bank_count_delta'],0)

    def mutate(self,name,before,after):
        source=(M.ROOT/name).read_text()
        self.assertEqual(source.count(before),1)
        with self.assertRaises(ValueError): M.build({name:source.replace(before,after)})

    def test_new_retained_field(self):
        self.mutate(M.CATALOG,'extends RefCounted','extends RefCounted\nvar hidden: PackedInt32Array = PackedInt32Array([0])')

    def test_unadvertised_local_literal(self):
        self.mutate(M.CATALOG,'\treturn 12','\tvar hidden: Array = [0,0,0]\n\treturn 12')

    def test_added_observer_call(self):
        self.mutate(M.CATALOG,'\treturn 12','\truntime_sources_refusal()\n\treturn 12')

    def test_missing_tenth_consumer(self):
        self.mutate(M.CATALOG,'for index: int in 10:','for index: int in 9:')

    def test_larger_hash_chunk(self):
        self.mutate(M.CATALOG,'HASH_CHARS: int = 1024','HASH_CHARS: int = 65536')

    def test_motion_third_bank(self):
        self.mutate(M.MOTION,'var _live: Bank = Bank.new()','var hidden: Bank = Bank.new()\nvar _live: Bank = Bank.new()')

    def test_decode_window_growth(self):
        self.mutate(M.MOTION,'DECODE_BYTES: int = 4096','DECODE_BYTES: int = 8192')

    def test_clock_algorithm_drift(self):
        self.mutate(M.CLOCK,'TREAD_TICKS: int = 30','TREAD_TICKS: int = 31')

    def test_composer_extra_owner(self):
        self.mutate(M.COMPOSITION,'extends RefCounted','extends RefCounted\nvar second: Movement = Movement.new()')

    def test_composer_invented_pace(self):
        self.mutate(M.COMPOSITION,'catalog._live.header[7] != 12','catalog._live.header[7] != 13')

if __name__=='__main__':unittest.main()
