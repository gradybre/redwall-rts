"""Synthetic measurements test the checker only; never used as game evidence."""
from copy import deepcopy
from pathlib import Path
import tempfile
import unittest
from qualify import capture,FEATURES,SCENES,percentile,parity,suite,integer,checked_file
from arithmetic import fixtures,demand,route_bound

def synthetic(speed=1):
    meta=dict(profile='W-N',os='Windows 11',cpu='AMD Ryzen 5 3600',gpu='NVIDIA GeForce GTX 1660 SUPER',
              ram_bytes=17179869184,driver='vulkan',driver_version='UNIT_TEST_NOT_HARDWARE',
              engine='4.7.2.stable.official.ed1daf0bf',build_mode='export_release',renderer='forward_plus',
              resolution=[1920,1080],scale_per_mille=1000,viewports=1,vsync=False,frame_limit=0,
              speed=speed,warmup_us=60000000,features=sorted(FEATURES),exercised_scenes=sorted(SCENES),
              allocated_payload_bytes=57713254,dropped_ticks=0,speed_fallbacks=0,kind='throughput',repeat=1)
    frames=[];ticks=[];last=0
    for frame in range(1,18001):
        count=frame*3*speed//10-last
        frames.append(dict(frame_id=frame,elapsed_us=frame*10000,frame_us=10000,
                           sim_cpu_us=count*1000+200,ui_cpu_us=500,sim_ram_bytes=66101862,
                           process_ram_bytes=128000000,skeletal_count=24,living=256,ticks_executed=count))
        for _ in range(count):
            last+=1;ticks.append(dict(tick=last,frame_id=frame,tick_cpu_us=1000))
    return meta,frames,ticks,[dict(request_id=1,request_us=0,ready_us=250000)]

class QualificationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.data=synthetic()

    def test_nearest_rank_not_interpolated(self):
        self.assertEqual(percentile(list(range(1,257)),95),244)
        self.assertEqual(percentile([1,2,3],99),3)
        with self.assertRaises(ValueError):percentile([],95)

    def test_synthetic_pass_is_capture_only(self):
        result=capture(*self.data)
        self.assertEqual(result['status'],'PASS_CAPTURE_ONLY')
        self.assertEqual(result['metrics']['tick_samples'],5400)

    def test_mac_cannot_qualify_windows(self):
        m,f,t,r=self.data;m=dict(m,os='macOS')
        with self.assertRaisesRegex(ValueError,'Windows 11'):capture(m,f,t,r)

    def test_missing_runtime_feature_rejected(self):
        m,f,t,r=self.data;m=dict(m,features=['packed_stores'])
        with self.assertRaisesRegex(ValueError,'coverage'):capture(m,f,t,r)

    def test_missing_tick_sample_is_not_averaged_away(self):
        m,f,t,r=self.data
        with self.assertRaisesRegex(ValueError,'tick sample'):capture(m,f,t[1:100]+t[101:],r)

    def test_frame_tick_aggregate_mismatch_rejected(self):
        m,f,t,r=deepcopy(self.data);f[3]['sim_cpu_us']=0
        with self.assertRaisesRegex(ValueError,'omits'):capture(m,f,t,r)

    def test_memory_peak_not_percentile(self):
        m,f,t,r=deepcopy(self.data);f[0]['sim_ram_bytes']=100000001
        result=capture(m,f,t,r)
        self.assertEqual(result['status'],'FAIL')
        self.assertIn('simulation_peak_bytes',result['failures'][0])

    def test_route_deadline_is_inclusive(self):
        m,f,t,r=deepcopy(self.data)
        self.assertEqual(capture(m,f,t,r)['status'],'PASS_CAPTURE_ONLY')
        r[0]['ready_us']+=1
        self.assertEqual(capture(m,f,t,r)['status'],'FAIL')

    def test_unfinished_route_rejected(self):
        m,f,t,r=deepcopy(self.data);r[0].update(request_us=1,ready_us=0)
        with self.assertRaisesRegex(ValueError,'never completed'):capture(m,f,t,r)

    def test_four_speed_aggregate_has_separate_gate(self):
        m,f,t,r=synthetic(4)
        for row in f:row['sim_cpu_us']=6001
        result=capture(m,f,t,r)
        self.assertEqual(result['status'],'FAIL')
        self.assertTrue(any('simulation_frame_p95_us' in x for x in result['failures']))

    def test_missing_manifest_is_blocked(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(suite(Path(d)/'missing.json')['status'],'BLOCKED')

    def test_integer_measurements_reject_decimal_nan_and_negative(self):
        for value in ('1.5','NaN','-1','',None,'01'):
            with self.subTest(value=value),self.assertRaises(ValueError):integer(value)

    def test_parity_requires_every_tick_and_identical_hashes(self):
        with tempfile.TemporaryDirectory() as d:
            a=Path(d)/'a.csv';b=Path(d)/'b.csv'
            header='tick,state_sha256\n'
            data=header+'0,'+'a'*64+'\n1,'+'b'*64+'\n'
            a.write_text(data);b.write_text(data)
            self.assertEqual(parity(a,b),2)
            b.write_text(data.replace('b'*64,'c'*64))
            with self.assertRaisesRegex(ValueError,'divergence'):parity(a,b)
            b.write_text(data.replace('1,','2,'))
            with self.assertRaisesRegex(ValueError,'tick mismatch'):parity(a,b)

    def test_evidence_path_cannot_escape_root(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaisesRegex(ValueError,'escapes'):
                checked_file(Path(d),dict(path='../outside.csv',sha256='0'*64))

class ArithmeticTests(unittest.TestCase):
    def test_inherited_fixture_values(self):
        result=fixtures()
        self.assertEqual(result['field']['crop_work_mwu'],1152000)
        self.assertEqual(result['winter_stock']['work_mwu'],66240000)
        self.assertEqual(result['winter_stock']['cellars'],5)
        self.assertEqual(result['memory']['two_world_over_budget'],17599532)

    def test_living_cap_is_enforced(self):
        self.assertEqual(demand(153,76,27,True),2069280)
        with self.assertRaises(ValueError):demand(257,0,0)

    def test_path_queue_bound(self):
        self.assertEqual(route_bound(256,256)['p95_ready_tick'],31)
        self.assertTrue(route_bound(58,256)['within_250000_us'])
        self.assertFalse(route_bound(59,256)['within_250000_us'])

if __name__=='__main__':unittest.main()
