#!/usr/bin/env python3
"""Source/lifetime mutants must refuse rather than hide an additional cold image or packet."""
import unittest
import census


class CensusTests(unittest.TestCase):
    def setUp(self):
        self.source = (census.ROOT / census.FILE).read_text()

    def test_all_sequential_peaks_and_complete_fixed_packets(self):
        report = census.build()
        self.assertEqual(report['maximum_peak'], 938368)
        self.assertEqual(report['new_witness_and_request_fixed'] + report['retained_face_fixed'], 2651)
        self.assertEqual(report['peaks']['after_sites_and_final_publication'], 675840)
        self.assertEqual(report['terrain_helper_counted'], 384)
        self.assertEqual(report['terrain_added_retained'], 0)
        self.assertEqual(report['own_helper_counted'], 3756)
        self.assertLessEqual(report['own_helper_counted'], report['own_helper_allowance'])

    def reject(self, old, new):
        self.assertIn(old, self.source)
        with self.assertRaises((ValueError, AssertionError)):
            census.build(self.source.replace(old, new, 1))

    def test_retained_full_proof_refuses(self):
        self.reject('face.proof = null', 'face.proof = face.proof')

    def test_removed_companion_fragment_charge_refuses(self):
        self.reject('24 * Budget.PHASE_VOLUME_CAPACITY', '0 * Budget.PHASE_VOLUME_CAPACITY')

    def test_new_retained_numeric_field_refuses(self):
        self.reject('var token: int = 0', 'var extra_counter: int = 0\n\tvar token: int = 0')

    def test_new_retained_object_refuses(self):
        self.reject('var binding: WorldRoutes = null', 'var new_image: Space.Snapshot = null\n\tvar binding: WorldRoutes = null')

    def test_unbounded_path_or_missing_face_charge_refuses(self):
        self.reject('path.resize(config.routes._edge_capacity * 2)', 'path.resize(config.routes._edge_capacity * 4)')
        self.reject('384 + Face.CONTROL_BYTES + PATH_BYTES', '384 + PATH_BYTES')


    def test_new_terrain_retained_state_refuses(self):
        terrain = (census.ROOT / census.TERRAIN).read_text()
        with self.assertRaisesRegex(ValueError, 'no retained'):
            census.build(terrain=terrain.replace('var _ready: bool = false', 'var _late: int = 0\nvar _ready: bool = false'))

    def test_virtual_final_reader_refuses(self):
        terrain = (census.ROOT / census.TERRAIN).read_text()
        with self.assertRaisesRegex(ValueError, 'dynamic final observer'):
            census.build(terrain=terrain.replace('world._published and', 'world.is_published() and'))

    def test_instance_helper_dispatch_refuses(self):
        terrain = (census.ROOT / census.TERRAIN).read_text()
        with self.assertRaisesRegex(ValueError, 'static dispatch'):
            census.build(terrain=terrain.replace('static func _final_local_tile(', 'func _final_local_tile('))

    def test_transitive_numeric_growth_refuses(self):
        terrain = (census.ROOT / census.TERRAIN).read_text()
        padding = ', '.join('extra_' + str(i) + ': Vector3i' for i in range(30))
        with self.assertRaisesRegex(ValueError, 'witness plus'):
            census.build(terrain=terrain.replace('static func _final_conflict(actual: RefCounted,',
                                               'static func _final_conflict(' + padding + ', actual: RefCounted,'))


if __name__ == '__main__':
    unittest.main()
