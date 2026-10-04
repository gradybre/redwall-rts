#!/usr/bin/env python3
"""Small source-target checks; no authored motion or BUILD activation."""
import copy
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import numpy as np

SPEC = importlib.util.spec_from_file_location("install_source", Path(__file__).with_name("author_install_source.py"))
I = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(I)
CAPTURE_SPEC = importlib.util.spec_from_file_location("install_native_checker", Path(__file__).with_name("run_install_capture.py"))
N = importlib.util.module_from_spec(CAPTURE_SPEC)
CAPTURE_SPEC.loader.exec_module(N)
PROOF_SPEC = importlib.util.spec_from_file_location("install_contact_proof", Path(__file__).parent/"install-source-proof-v4/prove_candidate.py")
Q = importlib.util.module_from_spec(PROOF_SPEC)
PROOF_SPEC.loader.exec_module(Q)


class InstallSourceTests(unittest.TestCase):
    @staticmethod
    def source_fixture():
        """Synthetic fixed-link rig exercises authoring refusals; it cannot establish actual source qualification."""
        identity = np.array([1,0,0,0,1,0,0,0,1,0,0,0],dtype=np.float32)
        bones=[{'bone':at,'bind':at,'parent':0 if at else -1,'name':'bone'+str(at),'inverse_bind':identity.tolist()}
               for at in range(24)]
        for at,name in [(0,'Hips'),(8,'RightToeBase'),(9,'Spine02'),(17,'RightArm')]: bones[at]['name']=name
        for at,parent in [(10,9),(11,10),(16,11),(17,16),(18,17),(19,18)]: bones[at]['parent']=parent
        palette=np.tile(identity,(25,1))
        for at,point in [(0,[0,.35,0]),(9,[0,.4,0]),(10,[0,.5,0]),(11,[0,.55,0]),(16,[0,.6,-.08]),
                         (17,[.13,.55,-.04]),(18,[.20,.42,-.15]),(19,[.28,.435,-.25])]: palette[at,9:]=point
        fit=np.array([[0,0,.2892,-.0390625],[-.2892,0,0,.27612117],[0,-.2892,0,.06122806],[0,0,0,1]])
        tool=I.P._affine64(palette[19])@fit
        palette[24,:9]=tool[:3,:3].T.reshape(-1);palette[24,9:]=tool[:3,3]
        ready={'frames':9,'matrices':np.tile(palette,(9,1,1)),'grounding':np.zeros(9,dtype=np.float32)}
        points=np.zeros((653,3),dtype=np.float32);points[I.POLL_VERTEX]=[-.5544813,.12698026,.73966086]
        part={'geometry':[{'points':points}]}
        rig={'rig_binding':{'bones':bones,'right_hand':19},'pick_binding':{'prop_local_grip_m':[.6846347,.1948317,0]}}
        return ready,part,rig

    @staticmethod
    def packet():
        return {'schema': 1, 'engineering_only': True, 'fastening_candidates': [
            {'assembly': 0, 'existing_target_kind': 'retained_natural', 'face': 'positive_y', 'yaw_u16': 0,
             'target_bounds_u': [-1024, -128, 0, -512, 0, 128], 'station_root_u': [-832, 0, 512]},
            {'assembly': 1, 'existing_target_kind': 'installed_part', 'face': 'positive_y', 'yaw_u16': 0,
             'target_bounds_u': [-256, -64, -2048, 256, 0, -1920], 'station_root_u': [0, 0, -1536]}]}

    def test_actual_targets_preserve_different_existing_owners_and_shared_local_face(self):
        packet = self.packet(); before = copy.deepcopy(packet)
        result = I.target_faces(packet)
        self.assertEqual(result[0]['local_patch_limits_u'], [-192, 0, -512, 320, 0, -384])
        self.assertEqual(result[1]['local_patch_limits_u'], [-256, 0, -512, 256, 0, -384])
        self.assertNotEqual(result[0]['existing_target_kind'], result[1]['existing_target_kind'])
        self.assertEqual(packet, before)

    def test_billed_bearer_pose_is_exact_and_never_worker_support(self):
        packet=self.packet()
        packet['parts']=[{'id':at} for at in range(14)]
        packet['parts'][1]={'id':1,'assembly':0,'name':'L0_left_bearer','bounds_u':[-896,-192,-2048,-768,-64,0]}
        packet['parts'][8]={'id':8,'assembly':1,'name':'T0_left_bearer','bounds_u':[-896,-320,-2560,-768,-192,-2048]}
        before=copy.deepcopy(packet)
        rows=I.workpiece_targets(packet)
        self.assertEqual([r['target_bounds_u'] for r in rows],[[-1024,0,0,1024,128,128],[-256,0,-2048,256,128,-1920]])
        self.assertEqual([r['station_root_u'] for r in rows],[[-832,0,512],[0,0,-1536]])
        self.assertTrue(all(r['worker_support'] is False for r in rows))
        self.assertEqual(packet,before)
        packet['parts'][8]['bounds_u'][0]-=1
        with self.assertRaisesRegex(ValueError,'INSTALL_BILLED_PART_IDENTITY'):I.workpiece_targets(packet)

    def test_wrong_face_height_yaw_and_overflow_refuse(self):
        for field, value in [('face', 'negative_z'), ('yaw_u16', 16384), ('station_root_u', [0, 1, 0]),
                             ('station_root_u', [1 << 31, 0, 0]), ('target_bounds_u', [0, 0, 0, 1, 0, 1])]:
            packet = self.packet(); packet['fastening_candidates'][0][field] = value
            with self.assertRaises(ValueError): I.target_faces(packet)

    def test_original_lower_body_grip_lengths_and_tool_scale_survive_the_authored_pose(self):
        ready,part,rig=self.source_fixture();before=copy.deepcopy(ready)
        pose,facts=I.poll_pose(ready,part,rig,[128,126,-448],35,30)
        np.testing.assert_array_equal(ready['matrices'],before['matrices'])
        np.testing.assert_array_equal(pose['matrices'][0,:9],ready['matrices'][8,:9])
        self.assertLess(facts['maximum_link_length_error_m'],1e-10)
        np.testing.assert_allclose(facts['poll_u'],[128,126,-448],atol=1e-3)
        original=I.P._affine64(ready['matrices'][8,24])[:3,:3]
        altered=I.P._affine64(pose['matrices'][0,24])[:3,:3]
        np.testing.assert_allclose(altered.T@altered,original.T@original,atol=1e-7)

    def test_unreachable_hand_nonfinite_and_unapproved_lean_refuse(self):
        ready,part,rig=self.source_fixture()
        for point,lean in [([128,-2,-448],24),([128,-2,-448],51),([np.nan,0,0],35),
                           ([0,0,-3000],35),([0,0,-2048],35)]:
            with self.assertRaises(ValueError): I.poll_pose(ready,part,rig,point,lean)

    def test_outward_source_orientation_requires_exact_finite_authoring_input(self):
        ready,part,rig=self.source_fixture()
        for value in (14,46,30.0,True):
            with self.assertRaisesRegex(ValueError,'INSTALL_POSE_INPUT'):
                I.poll_pose(ready,part,rig,[128,126,-448],35,value)

    def test_motion_has_actual_finite_edges_exact_retrace_and_unchanged_feet(self):
        ready,part,rig=self.source_fixture()
        work,entry,recovery,_=I.source_motion(ready,part,rig)
        self.assertEqual([work['frames'],entry['frames'],recovery['frames']],[33,31,31])
        self.assertEqual(work['source_loop_mode'],0)
        self.assertEqual(len(I.P.rendered_intervals(work)),32)
        np.testing.assert_array_equal(work['matrices'][0],work['matrices'][-1])
        np.testing.assert_array_equal(entry['matrices'][0],ready['matrices'][8])
        np.testing.assert_array_equal(entry['matrices'][-1],work['matrices'][0])
        np.testing.assert_array_equal(recovery['matrices'],entry['matrices'][::-1])
        for case in [work,entry,recovery]:
            np.testing.assert_array_equal(case['matrices'][:,:9],np.tile(ready['matrices'][8,:9],(case['frames'],1,1)))

    def test_containment_includes_complete_planar_patch_and_rejects_wrong_face_edge(self):
        target=[-192,128,-512,256,128,-384]
        self.assertTrue(Q.contained([127,128,-449,129,128,-447],target))
        self.assertFalse(Q.contained([127,128,-513,129,128,-447],target))
        self.assertFalse(Q.contained([127,127,-449,129,128,-447],target))
        self.assertFalse(Q.contained(None,target))

    def test_exact_crossing_encloses_interpolated_point_and_preserves_uncertainty(self):
        ready,part,_=self.source_fixture()
        case=dict(ready,frames=2,source_loop_mode=0,duration_q16=65536,source_duration_s=I.Fraction(1,30),
                  matrices=ready['matrices'][:2].copy(),grounding=ready['grounding'][:2].copy())
        part['geometry'][0]['points'][478]=0
        case['matrices'][0,24,9:]=[.125,.145,-.45]
        case['matrices'][1,24,9:]=[.145,.105,-.45]
        with patch.object(Q.P,'_vertex_hulls',return_value=[]), patch.object(Q.P,'_residual_padding',return_value=(np.array([16,16,16]),[])):
            result=Q.crossing_patch(case,part,[0]*6,478)
            self.assertEqual(result[0]['rendered_edge'],[0,1])
            self.assertEqual(result[0]['anchor_u'][1],128)
            self.assertLess(result[0]['patch_u'][0],.135*1024)
            self.assertGreater(result[0]['patch_u'][3],.135*1024)
            case['matrices'][0,24,10]=.125
            with self.assertRaisesRegex(ValueError,'INSTALL_NO_GENUINE_CROSSING'):
                Q.crossing_patch(case,part,[0]*6,478)

    def test_workpiece_is_not_a_body_or_recovery_collision_exception(self):
        scale=Q.P.SCALE
        body=np.array([[0,0,0],[.1,0,0],[0,0,.1], [.10,.14,-.44],[.15,.14,-.44],[.10,.14,-.40]],dtype=np.float32)
        tool=np.array([[.12,.126,-.44],[.13,.126,-.44],[.12,.124,-.45]],dtype=np.float32)
        ids=np.zeros((6,1),dtype=np.int32);weights=np.ones((6,1),dtype=np.float32)
        parts=[{'binds':24,'geometry':[{'points':body,'ids':ids,'weights':weights}]},
               {'binds':0,'geometry':[{'points':tool}]}]
        tri=[ [np.array([[0,1,2],[3,4,5]],dtype=np.int32)], [np.array([[0,1,2]],dtype=np.int32)] ]
        identity=np.array([1,0,0,0,1,0,0,0,1,0,0,0],dtype=np.float32)
        case={'frames':2,'source_loop_mode':0,'duration_q16':65536,'source_duration_s':I.Fraction(1,30),
              'matrices':np.tile(identity,(2,25,1)),'grounding':np.zeros(2,dtype=np.float32)}
        fixture={'assembly':0,'solids_u':[[-1024,-64,-512,1024,0,1024],[-256,0,-512,256,128,-384]],
                 'support_solid':0,'workpiece_solid':1,'workpiece_support':False}
        below={'bounds_u':[122,126,-461,134,128,-449]}
        def hull(part,matrices,ground):
            points=part['geometry'][0]['points'].astype(np.float64)*scale
            return [(np.floor(points).astype(np.int64),np.ceil(points).astype(np.int64))]
        masks=[np.array([True,False]),np.array([True,False])]
        with patch.object(Q.P,'_vertex_hulls',side_effect=hull),patch.object(Q.P,'_residual_padding',return_value=(np.zeros(3,dtype=np.int64),[])), \
             patch.object(Q.T,'foot_membership',return_value=masks):
            safe=Q.world_proof(case,parts,tri,[0]*6,fixture,True,below)
            self.assertTrue(safe['clear'])
            self.assertGreater(safe['intentional_active_adze_target_pairs'],0)
            recovery=Q.world_proof(case,parts,tri,[0]*6,fixture,False,below)
            self.assertFalse(recovery['clear'])
            body[3:,1]=.124
            penetrated=Q.world_proof(case,parts,tri,[0]*6,fixture,True,below)
            self.assertFalse(penetrated['clear'])
            self.assertTrue(any(r.get('part')==0 and r.get('solid')==1 for r in penetrated['unresolved']))
            body[:3,1]=-.001
            unsupported=Q.world_proof(case,parts,tri,[0]*6,fixture,True,below)
            self.assertFalse(unsupported['clear'])
            fixture['workpiece_support']=True
            with self.assertRaisesRegex(ValueError,'INSTALL_SOLID_CENSUS'):
                Q.world_proof(case,parts,tri,[0]*6,fixture,True,below)

    @staticmethod
    def report_fixture():
        spec={'duration_q16':[32*65536,30*65536,30*65536],'content_sha256':'a'*64,
              'targets':[],'user_directory_name':'isolated-install-fixture','contact_plane_y_u':128}
        report={'poses':1131,'assertions':2581,'failures':[],'production_qualified':False,'content_sha256':'a'*64,
                'targets':[],'user_directory':'/tmp/isolated-install-fixture',
                'native_poll':[{'share_q16':i*8192,'local_point_u':[128,132-i,-448]} for i in range(9)],
                'screenshots':[{'path':str(i)+'.png'} for i in range(132)]}
        return report,spec

    def test_outer_native_report_requires_complete_positive_census_and_crossing(self):
        report,spec=self.report_fixture()
        self.assertEqual(N.validate_report(report,spec)['poses'],1131)
        for key,value in [('poses',1130),('assertions',0),('failures',['failed']),('screenshots',[]),
                          ('native_poll',[]),('production_qualified',True),('user_directory','/tmp/shared')]:
            changed=copy.deepcopy(report);changed[key]=value
            with self.assertRaises(ValueError): N.validate_report(changed,spec)
        for value in [float('nan'),129]:
            changed=copy.deepcopy(report);changed['native_poll'][-1]['local_point_u'][1]=value
            with self.assertRaises(ValueError): N.validate_report(changed,spec)


if __name__ == '__main__':
    unittest.main()
