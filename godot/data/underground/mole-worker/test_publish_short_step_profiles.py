#!/usr/bin/env python3
"""Actual source reconstruction plus bounded admission/atomic-output adversaries; no engine replay.

qualified-step-v4 is a historical content-3 publication (ADR 1200): tracked pins
resolve at CONSUMER_COMMIT. Its reconstruction also reads inputs git never held
(153 gitignored godot/demo/assets files), which ADR 1192 section 2 does not admit as
evidence, so that replay runs only where those files exist and is skipped otherwise.
"""
from __future__ import annotations
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('short_step_publisher', Path(__file__).with_name('publish_short_step_profiles.py'))
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


def untracked_inputs():
    """Pinned inputs of the committed publication that no commit tracks and this checkout lacks."""
    pins = json.loads((M.ROOT / (M.OUTPUT + 'manifest.json')).read_text())['prerequisite_pins']
    listed = subprocess.run(['git', '-C', str(M.ROOT), 'ls-files', '-z'], capture_output=True, check=True)
    tracked = set(listed.stdout.decode().split('\0'))
    return sorted(name for name in pins if name not in tracked and not (M.ROOT / name).is_file())


ABSENT = untracked_inputs()


@unittest.skipIf(ABSENT, f'historical replay needs {len(ABSENT)} untracked godot/demo/assets inputs, first {ABSENT[:1]}')
class PublicationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files, cls.pins = M.inputs()
        cls.manifest = json.loads(cls.files['manifest.json'])

    def test_actual_full_source_and_native_admission(self):
        self.assertEqual(self.manifest['source_reconstruction_files'], 537)
        self.assertEqual(self.manifest['native_input_files'], 402)
        self.assertEqual(tuple(self.manifest['consumers']), M.CONSUMERS)
        self.assertEqual(len(self.manifest['native_executed_consumers']), 8)
        self.assertEqual(self.manifest['unchanged_prior_qualified_consumers'], list(M.CONSUMERS[1:3]))
        for key in ('world_activation_qualified', 'native_memory_qualified', 'performance_qualified'):
            self.assertIs(self.manifest[key], False)
        self.assertEqual(self.manifest['source_review_sha256'], M.REVIEW_SHA)

    def test_exact_old_geometry_and_new_row_map(self):
        old = (M.ROOT / (M.OLD + 'mole-worker.ugprof')).read_bytes()
        new = self.files['mole-worker.ugprof']
        self.assertEqual(M.digest(new), M.WIRE_SHA)
        self.assertEqual(struct.unpack_from('<IqIII', new, 8), (2, 3, 29, 271, 1))
        # Row metadata changes only box offsets and the WORK row ID implicit in ordering.
        for before, after in [*( (i, i) for i in range(10)), *((i, i + 3) for i in range(10, 26))]:
            a, b = old[64 + before*98:64 + (before+1)*98], new[64 + after*98:64 + (after+1)*98]
            self.assertEqual(a[:56], b[:56]); self.assertEqual(a[60:], b[60:])
            first_a, count_a = struct.unpack_from('<2i', a, 56)
            first_b, count_b = struct.unpack_from('<2i', b, 56)
            self.assertEqual(count_a, count_b)
            self.assertEqual(old[64+26*98+28*first_a:64+26*98+28*(first_a+count_a)],
                             new[64+29*98+28*first_b:64+29*98+28*(first_b+count_b)])
        self.assertEqual([new[64+i*98+97] for i in range(10, 13)], [4, 5, 6])

    def test_actual_ground_pace_names_twelve_exact_walk_rows(self):
        raw = self.files['ground-pace.ugconn']
        record = json.loads(self.files['ground-manifest.json'])
        self.assertEqual(M.digest(raw), M.GROUND_SHA)
        self.assertEqual(len(raw), 576)
        self.assertEqual(record['counts'], dict(variants=0, points=0, regions=0, parts=0, vertices=0, materials=0, paces=12))
        self.assertEqual([row['profile_id'] for row in record['rows']], list(range(1, 13)))
        for index in range(12):
            row = struct.unpack_from('<7iq', raw, 136 + index * 36)
            self.assertEqual(row[:3], (index+1, -1, 0))
            self.assertEqual(row[5:7], (0, 0))  # Existing cap rate, no new speed or duty.
        self.assertFalse(record['runtime_activation_qualified'])

    def test_motion_all_geometry_and_independent_rates_are_preserved(self):
        old = (M.ROOT / (M.OLD_MOTION + 'motion.ugmotion')).read_bytes()
        new = self.files['motion.ugmotion']
        record = json.loads(self.files['motion-manifest.json'])
        self.assertEqual(new[44:M.I64_AT-12], old[44:M.I64_AT-12])
        self.assertEqual(new[M.I64_AT+24:M.BYTE_AT-12], old[M.I64_AT+24:M.BYTE_AT-12])
        self.assertEqual(struct.unpack_from('<3q', new, M.I64_AT), (1, 3, 3))
        ranges = record['permitted_changed_byte_ranges']
        for i, (a, b) in enumerate(zip(old, new)):
            self.assertTrue(a == b or any(lo <= i < hi for lo, hi in ranges))
        for program in range(5):
            for field in (9, 10):
                self.assertEqual(struct.unpack_from('<i', new, 44+(16903+field*5+program)*4)[0], -1)
        self.assertFalse(record['runtime_activation'])
        self.assertFalse(record['pace_adopted'])

    def test_motion_rebind_rejects_stripped_or_self_declared_publication(self):
        for change in ('stripped', 'flag', 'missing_consumer', 'revision'):
            with self.subTest(change=change):
                record = json.loads(self.files['manifest.json'])
                if change == 'stripped': record['prerequisite_pins'] = {}
                if change == 'flag': record['world_activation_qualified'] = True
                if change == 'missing_consumer': record['consumers'].pop(M.CONSUMERS[-1])
                if change == 'revision': record['content_revision'] = 2
                with self.assertRaisesRegex(ValueError, 'MOTION_PROFILE_PUBLICATION'):
                    M.motion_rebind(json.dumps(record).encode(), self.manifest['prerequisite_pins'].copy())

    def test_motion_corrupt_original_cannot_be_rehashed_by_caller(self):
        original_read = M.read
        for offset in (44, M.I64_AT + 32*8, M.BYTE_AT):
            with self.subTest(offset=offset):
                def changed(name, expected, pins):
                    raw = original_read(name, expected, pins)
                    if name == M.OLD_MOTION + 'motion.ugmotion':
                        raw = bytearray(raw); raw[offset] ^= 1; raw = bytes(raw)
                    return raw
                # Simulate a bad low-level reader: the rebind must still attest the exact full original.
                with patch.object(M, 'read', changed), self.assertRaisesRegex(ValueError, 'MOTION_PROVENANCE'):
                    M.motion_rebind(self.files['manifest.json'], self.manifest['prerequisite_pins'].copy())

    def test_successful_publication_is_create_only(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve(); (root/'source').write_bytes(b'original'); target = root/M.OUTPUT
            with patch.object(M,'ROOT',root), patch.object(M,'inputs', return_value=(self.files,{'source':M.digest(b'original')})):
                result = M.publish(target)
                self.assertEqual(result,{name:M.digest(raw) for name,raw in self.files.items()})
                with self.assertRaisesRegex(ValueError,'OUTPUT'): M.publish(target)
                self.assertEqual({p.name:p.read_bytes() for p in target.iterdir()},self.files)


class AdmissionTests(unittest.TestCase):
    def test_fixed_review_hash_rejects_relabelled_acceptance(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(M, 'ROOT', Path(temporary).resolve()):
            path = M.ROOT / M.REVIEW; path.parent.mkdir(parents=True)
            path.write_text(json.dumps({'accepted':True, 'source_runtime_accepted':True}))
            with self.assertRaisesRegex(ValueError, 'HASH:'):
                M.inputs()

    def test_current_consumer_manifest_cannot_omit_tenth_program(self):
        current = json.loads((M.ROOT / (M.E+'current-consumers.json')).read_text())
        current['consumers'].pop(M.CONSUMERS[-1])
        with tempfile.TemporaryDirectory() as temporary, patch.object(M, 'ROOT', Path(temporary).resolve()):
            path = M.ROOT / (M.E+'current-consumers.json'); path.parent.mkdir(parents=True)
            path.write_text(json.dumps(current))
            with self.assertRaisesRegex(ValueError, 'HASH:'):
                M.current_consumers({})

    def test_consumer_pin_is_the_named_commit_never_the_live_script(self):
        current = json.loads((M.ROOT / (M.E+'current-consumers.json')).read_bytes())
        self.assertEqual(current['commit'], M.CONSUMER_COMMIT)
        self.assertEqual(M.digest(M.historical(M.CONSUMERS[0])), current['consumers'][M.CONSUMERS[0]])
        self.assertIsNone(M.historical(M.OUTPUT + 'manifest.json'))  # created after CONSUMER_COMMIT
        original = M.historical
        forged = lambda name, commit=M.CONSUMER_COMMIT: (b'extends RefCounted\n' if name == M.CONSUMERS[0]
                                                        else original(name, commit))
        with patch.object(M, 'historical', forged), self.assertRaisesRegex(ValueError, 'HASH:.*underground_profiles'):
            M.current_consumers({})

    def test_outside_a_checkout_a_mutated_script_cannot_borrow_the_pin(self):
        current_raw = (M.ROOT / (M.E+'current-consumers.json')).read_bytes()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            metadata = root / (M.E+'current-consumers.json'); metadata.parent.mkdir(parents=True); metadata.write_bytes(current_raw)
            original = root / M.CONSUMERS[0]; original.parent.mkdir(parents=True); original.write_text('extends RefCounted\n')
            with patch.object(M, 'ROOT', root), self.assertRaisesRegex(ValueError, 'HASH:.*underground_profiles'):
                M.current_consumers({})

    def test_lfs_pointer_admits_only_the_bytes_it_names(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve(); (root/'shot.png').write_bytes(b'actual')
            pointer = M.LFS + b'oid sha256:' + M.digest(b'other').encode() + b'\nsize 5\n'
            with patch.object(M, 'ROOT', root), patch.object(M, 'historical', return_value=pointer):
                with self.assertRaisesRegex(ValueError, 'HISTORICAL_LFS'): M.check('shot.png', M.digest(b'actual'), {})
            pointer = M.LFS + b'oid sha256:' + M.digest(b'actual').encode() + b'\nsize 6\n'
            with patch.object(M, 'ROOT', root), patch.object(M, 'historical', return_value=pointer):
                self.assertEqual(M.read('shot.png', M.digest(b'actual'), {}), b'actual')

    def test_hash_paths_are_bounded_and_cannot_escape(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            target = root / 'data'; target.write_bytes(b'abc')
            (root/'link').symlink_to(target)
            with patch.object(M, 'ROOT', root):
                for path in ('../data', '/data', './data', 'link', 'absent'):
                    with self.subTest(path=path), self.assertRaises(ValueError): M.canonical(path)
                with self.assertRaisesRegex(ValueError, 'FILE:'): M.canonical('data', 2)
                with self.assertRaisesRegex(ValueError, 'DIGEST'): M.check('data', 'z'*64, {})

    def test_existing_output_and_wrong_destination_refuse_before_admission(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            target = root / M.OUTPUT; target.mkdir(parents=True)
            (target/'sentinel').write_bytes(b'old')
            with patch.object(M, 'ROOT', root), patch.object(M, 'inputs', side_effect=AssertionError('admission must not run')):
                for path in (target, root/'other'):
                    with self.subTest(path=path), self.assertRaisesRegex(ValueError, 'OUTPUT'): M.publish(path)
            self.assertEqual((target/'sentinel').read_bytes(), b'old')

    def test_final_input_mutation_refuses_before_first_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve(); source = root/'source'; source.write_bytes(b'changed')
            target = root/M.OUTPUT
            with patch.object(M,'ROOT',root), patch.object(M,'inputs', return_value=({'file':b'bytes'},{'source':M.digest(b'original')})):
                with self.assertRaisesRegex(ValueError,'HASH:source'): M.publish(target)
            self.assertFalse(target.exists())


if __name__ == '__main__': unittest.main()
