#!/usr/bin/env python3
"""SET-MOVE-ECON-001 arithmetic/conservation oracles; not Godot runtime tests."""
from pathlib import Path
import copy
import hashlib
import json
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
VALUES = ROOT / 'docs/planning/underground_economy_hazard_values.json'
V = json.loads(VALUES.read_text())
E, A, F = V['excavation'], V['air'], V['fall']
REPORT = ROOT / 'docs/validation/underground_economy_hazard_results.json'

def ceildiv(n, d):
    assert n >= 0 and d > 0
    return (n + d - 1) // d

def truncdiv(n, d):
    return n // d if n >= 0 else -((-n) // d)

def health_interval(health, remainder, rate):
    if health == 0:
        return 0, 0
    total = remainder + rate
    delta = truncdiv(total, 750)
    rem = total - delta * 750
    value = max(0, min(100, health + delta))
    if (value == 0 and rem < 0) or (value == 100 and rem > 0):
        rem = 0
    return value, rem

def health_after(initial, intervals, rate, remainder=0):
    for _ in range(intervals):
        initial, remainder = health_interval(initial, remainder, rate)
    return initial, remainder

def air_interval(air, starts_submerged):
    airless = starts_submerged and air == 0
    updated = max(0, air - A['per_submerged_tick']) if starts_submerged else min(A['full'], air + A['per_breathable_tick_recovery'])
    return updated, airless

def fall(drop):
    if drop <= 0:
        raise ValueError('A declared fall has a positive drop')
    return (min(F['max_damage'], ceildiv(drop * F['damage_per_meter'], 1024)),
            1 if drop <= F['severity_one_max_drop_u'] else 2,
            max(F['minimum_ticks'], ceildiv(drop * 30, F['duration_speed_u_per_second'])))

class Ledger:
    """Small independent account oracle; not a proposed runtime storage layout."""
    def __init__(self):
        self.wood = self.stone = 100000
        self.wood_loss = self.stone_loss = 0
        self.installed = False
        self.earth = self.embedded = self.tip = self.virgin = 0
        self.phase = 'VIRGIN_SOLID'
        self.events = set()

    def audit(self):
        installed = 250 if self.installed else 0
        assert self.wood + installed + self.wood_loss == 100000
        assert self.stone + installed + self.stone_loss == 100000
        assert self.earth + self.embedded + self.tip == self.virgin
        assert min(self.wood, self.stone, self.earth, self.embedded, self.tip) >= 0

    def brace(self):
        assert self.phase in ('VIRGIN_SOLID', 'BACKFILLED') and not self.installed
        self.wood -= 250
        self.stone -= 250
        self.installed = True
        self.audit()

    def cut_commit(self, event, free_g=2000):
        if event in self.events:
            return True
        if free_g < 2000 or not self.installed or self.phase == 'VOID':
            return False
        if self.phase == 'VIRGIN_SOLID':
            self.virgin += 2000
        else:
            assert self.embedded == 2000
            self.embedded -= 2000
        self.earth += 2000
        self.phase = 'VOID'
        self.events.add(event)
        self.audit()
        return True

    def backfill(self, event, occupied=False, output_free_g=1250):
        if event in self.events:
            return True
        if occupied or output_free_g < 1250 or self.earth < 2000 or self.phase != 'VOID':
            return False
        self.earth -= 2000
        self.embedded += 2000
        self.wood += 125
        self.stone += 125
        self.wood_loss += 125
        self.stone_loss += 125
        self.installed = False
        self.phase = 'BACKFILLED'
        self.events.add(event)
        self.audit()
        return True

    def close_uncut(self, event, output_free_g=1250, support_needed=False):
        if event in self.events:
            return True
        if not self.installed or self.phase == 'VOID' or output_free_g < 1250 or support_needed:
            return False
        self.wood += 125
        self.stone += 125
        self.wood_loss += 125
        self.stone_loss += 125
        self.installed = False
        self.events.add(event)
        self.audit()
        return True

    def compact(self, q):
        if q <= 0 or q > self.earth or self.tip + q > V['tip']['capacity_g']:
            return False
        self.earth -= q
        self.tip += q
        self.audit()
        return True

    def reclaim(self, q, output_free_g):
        if q <= 0 or q > self.tip or output_free_g < q:
            return False
        self.tip -= q
        self.earth += q
        self.audit()
        return True

class Fixtures(unittest.TestCase):
    def test_01_unit_and_example(self):
        self.assertEqual(E['quantum_side_u'] ** 3, 1073741824)
        self.assertEqual((2048 // 1024) * (2048 // 1024) * (3072 // 1024), 12)
        self.assertEqual(sum(E[k] for k in ['brace_work_mwu', 'cut_work_mwu', 'finish_work_mwu']), 9000)
        self.assertEqual(12 * 9000, 108000)
        self.assertEqual(12 * E['cut_earth_milli'], 24000)
        self.assertEqual(12 * E['brace_inputs_milli']['wood'], 3000)

    def test_02_per_phase_tick_caps(self):
        ticks = [ceildiv(E[k], 80) for k in ['brace_work_mwu', 'cut_work_mwu', 'finish_work_mwu']]
        self.assertEqual(ticks, [25, 50, 38])
        self.assertEqual(12 * sum(ticks), 1356)
        self.assertEqual(ceildiv(1250,80) + ceildiv(3000,80), 54)

    def test_03_mass_and_payloads(self):
        self.assertEqual(ceildiv(24000 * V['earth']['mass_g_per_u'],1000),24000)
        self.assertEqual(ceildiv(24000,12000),2)
        self.assertEqual(ceildiv(24000,11999),3)
        self.assertEqual(ceildiv(1 * 1000,1000),1)

    def test_04_haul_time(self):
        leg=ceildiv(16384*30,3277)
        self.assertEqual(leg,150)
        self.assertEqual(2*(leg*2+ceildiv(4000,80)),700)

    def test_05_capacity_is_atomic(self):
        l=Ledger();l.brace()
        before=copy.deepcopy(l.__dict__)
        self.assertFalse(l.cut_commit('one',1999));self.assertEqual(l.__dict__,before)
        self.assertTrue(l.cut_commit('one',2000))

    def test_06_cut_commit_retry(self):
        l=Ledger();l.brace();l.cut_commit('one')
        before=copy.deepcopy(l.__dict__)
        for _ in range(20): self.assertTrue(l.cut_commit('one'))
        self.assertEqual(l.__dict__,before)

    def test_07_refunds_and_redelivery(self):
        returned=250*E['started_phase_refund_num']//E['started_phase_refund_den']
        self.assertEqual((returned,250-returned),(200,50))
        inventory=1000-250+returned-250
        self.assertEqual(inventory,700)
        self.assertEqual(inventory+250+50,1000)
        for q in [1,2,3,4,249,250,251,1000]:
            refund=q*800//1000
            self.assertEqual(refund+(q-refund),q)

    def test_08_backfill_atomicity_and_salvage(self):
        l=Ledger();l.brace();l.cut_commit('one')
        before=copy.deepcopy(l.__dict__)
        self.assertFalse(l.backfill('close',occupied=True));self.assertEqual(l.__dict__,before)
        self.assertFalse(l.backfill('close',output_free_g=1249));self.assertEqual(l.__dict__,before)
        self.assertTrue(l.backfill('close'))
        self.assertEqual((l.embedded,l.wood,l.wood_loss),(2000,99875,125))
        again=copy.deepcopy(l.__dict__);l.backfill('close');self.assertEqual(l.__dict__,again)

    def test_09_repeated_cycles_conserve(self):
        l=Ledger()
        for i in range(50):
            l.brace();self.assertTrue(l.cut_commit(f'dig{i}'))
            self.assertEqual(l.virgin,2000)
            self.assertTrue(l.backfill(f'fill{i}'))
        self.assertEqual((l.earth,l.embedded,l.virgin,l.wood_loss),(0,2000,2000,6250))

    def test_10_tip_reclaim_and_cancellation(self):
        l=Ledger();l.brace();l.cut_commit('one');l.compact(2000)
        before=copy.deepcopy(l.__dict__)
        self.assertFalse(l.reclaim(2000,1999));self.assertEqual(l.__dict__,before)
        # Source-lock cancellation itself still needs a runtime transaction fixture.
        self.assertTrue(l.reclaim(2000,2000));l.audit()
        l.earth=400000;l.virgin=400000;self.assertTrue(l.compact(400000))
        before=copy.deepcopy(l.__dict__)
        self.assertFalse(l.compact(1));self.assertEqual(l.__dict__,before)

    def test_11_tip_work_rounding(self):
        self.assertEqual((ceildiv(8000,4),ceildiv(8000,2)),(2000,4000))
        for q in range(1,100):
            for cut in range(1,q):
                self.assertGreaterEqual(ceildiv(cut,4)+ceildiv(q-cut,4),ceildiv(q,4))

    def test_12_wear_belongs_to_contributor(self):
        remainder={'A':0,'B':0};wear={'A':0,'B':0}
        for owner,q in [('A',6000),('B',4000),('A',4000)]:
            total=remainder[owner]+q
            wear[owner]+=total//10000;remainder[owner]=total%10000
        self.assertEqual(wear,{'A':1,'B':0});self.assertEqual(remainder,{'A':0,'B':4000})

    def test_13_air_admission_and_return(self):
        self.assertTrue(1200>=900+A['contingency_ticks'])
        self.assertFalse(1200>=901+A['contingency_ticks'])
        self.assertFalse(1199>=900+A['contingency_ticks'])
        self.assertTrue(600<=300+A['contingency_ticks'])

    def test_14_air_interval_boundaries(self):
        air=1200;airless_count=0
        for _ in range(1200):
            air,airless=air_interval(air,True);airless_count+=airless
        self.assertEqual((air,airless_count),(0,0))
        air,airless=air_interval(air,True) # ends at air: same starting-state rule
        self.assertEqual((air,airless),(0,True))
        air,airless=air_interval(air,False)
        self.assertEqual((air,airless),(4,False))
        for _ in range(299): air,_=air_interval(air,False)
        self.assertEqual(air,1200);self.assertEqual(air_interval(1199,False),(1200,False))

    def test_15_health_fixtures(self):
        rate=-(A['airless_health_drain_per_game_hour']+4)
        self.assertEqual(rate,-129)
        for ticks,expected in [(6,99),(495,15),(582,0)]:
            self.assertEqual(health_after(100,ticks,rate)[0],expected)
        self.assertEqual(health_after(15,88,rate)[0],0)
        self.assertEqual(health_after(100,1,rate,-700)[0],99)
        self.assertEqual(health_after(100,125,rate)[0],79)
        self.assertEqual(health_after(100,125,rate-3)[0],78)

    def test_16_death_cannot_be_healed(self):
        h,r=health_interval(1,-749,-129)
        self.assertEqual((h,r),(0,0))
        def care(value): return min(100,value+10) if value>0 else 0
        self.assertEqual(care(h),0)
        self.assertEqual(care(max(0,20-fall(4096)[0])),0)
        self.assertEqual(health_interval(0,0,4),(0,0))

    def test_17_falls(self):
        for drop,expected in [(1024,(8,1,8)),(2048,(16,1,15)),(4096,(32,2,30)),(8192,(40,2,60))]:
            self.assertEqual(fall(drop),expected)
        self.assertRaises(ValueError,fall,0)
        self.assertEqual(F['triggers'],['INCAPACITY','REST_ZERO'])

    def test_18_assistance_and_rescue(self):
        for length,modules in [(4096,1),(4097,2)]:
            n=ceildiv(length,V['assistance']['arc_module_u'])
            self.assertEqual(n,modules)
            self.assertEqual(n*V['assistance']['work_mwu_per_module'],modules*40000)
        self.assertEqual(ceildiv(V['rescue']['pickup_work_mwu'],80),100)
        self.assertEqual(ceildiv(V['rescue']['setdown_work_mwu'],80),50)
        speed_sum=0;remainder=0
        for _ in range(60):
            total=remainder+3277;speed_sum+=total//60;remainder=total%60
        self.assertEqual((speed_sum,remainder),(3277,0))

    def test_19_warning_order_and_clock_units(self):
        d,r=V['dangerous_entry'],V['recovery']
        self.assertEqual((d['min_rest'],r['return_rest_at_or_below'],r['distress_rest_at_or_below'],r['exhaustion_at_rest']),(4000,1500,500,0))
        self.assertTrue(d['min_rest']>r['return_rest_at_or_below']>r['distress_rest_at_or_below']>r['exhaustion_at_rest'])
        self.assertEqual(d['hunger_must_exceed'],3500)
        self.assertEqual(A['full']//V['units']['ticks_per_second_1x'],40)
        self.assertEqual(A['full']//(4*V['units']['ticks_per_second_1x']),10)
        self.assertEqual(A['full']*10//V['units']['ticks_per_game_hour'],16)
        self.assertEqual(A['planned_underwater_wait_ticks'],0)

    def test_20_scope_and_source_anchors(self):
        self.assertFalse(V['full_move_g01_closed'])
        self.assertEqual(V['depth']['status'],'CANDIDATE_NOT_ADOPTED')
        self.assertEqual(V['rescue']['new_autopause_triggers'],[])
        self.assertFalse(V['tip']['irreversible_discard_allowed'])
        gdd=(ROOT/'docs/game_gdd.md').read_text()
        self.assertIn('NONE=0, CUT=1, BITE=2, FALL=3, EXPOSURE=4, EXHAUSTION=5',gdd)
        self.assertIn('400000 g',gdd)
        self.assertTrue('handling a haul payload 2000 milli-WU to load plus 2000 to unload' in (ROOT/'docs/gameplay_balance.md').read_text(), 'BAL-CAT-010 must still own 2000+2000 milli-WU handling')
        self.assertFalse(V['earth']['raw_edible']);self.assertFalse(V['earth']['seed'])
        self.assertEqual(V['earth']['nutrition_per_u'],0)

    def test_21_never_cut_brace_closure(self):
        l=Ledger();l.brace()
        before=copy.deepcopy(l.__dict__)
        self.assertFalse(l.close_uncut('close',support_needed=True));self.assertEqual(l.__dict__,before)
        self.assertFalse(l.close_uncut('close',output_free_g=1249));self.assertEqual(l.__dict__,before)
        self.assertTrue(l.close_uncut('close'))
        self.assertEqual((l.phase,l.earth,l.embedded,l.virgin,l.wood),('VIRGIN_SOLID',0,0,0,99875))
        after=copy.deepcopy(l.__dict__);self.assertTrue(l.close_uncut('close'));self.assertEqual(l.__dict__,after)
        self.assertEqual(ceildiv(E['remove_support_work_mwu'],80),16)

if __name__=='__main__':

    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Fixtures))
    doc=ROOT/'docs/underground_economy_hazard_amendment.md'
    missing=[]
    for link in re.findall(r'\]\(([^)]+)\)',doc.read_text()):
        if not link.startswith(('https:','http:','#')) and not (doc.parent/link.split('#')[0]).exists(): missing.append(link)
    whitespace=subprocess.run(['git','-c','filter.lfs.required=false','-c','filter.lfs.smudge=','-c','filter.lfs.process=','diff','--check','--','docs'],cwd=ROOT,text=True,capture_output=True)
    report={
        'package':V['package'],'result':'PASS' if result.wasSuccessful() and not missing and whitespace.returncode==0 else 'FAIL',
        'tests_run':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),
        'missing_links':missing,'documentation_whitespace_pass':whitespace.returncode==0,
        'values_sha256':hashlib.sha256(VALUES.read_bytes()).hexdigest(),
        'specification_sha256':hashlib.sha256(doc.read_bytes()).hexdigest(),
        'checker_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'scope':'Independent arithmetic and small account oracles, not runtime implementation or qualification',
        'authoring_history':['Initial run: 19 passed, one source-anchor assertion failed because it searched for 2 WU instead of the source wording 2000 milli-WU. Corrected the assertion; no arithmetic or balance value changed.'],
        'not_verified':['Godot implementation','actual profile/body clearance','full MOVE-G01–05','binary save parity','UI captures','simulation performance','survival balance'],
        'failure_details':[str(e) for _,e in result.failures+result.errors],
    }
    if whitespace.returncode: report['whitespace_output']=whitespace.stdout+whitespace.stderr
    REPORT.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['result','tests_run','failures','errors','missing_links','documentation_whitespace_pass']},indent=2))
    raise SystemExit(0 if report['result']=='PASS' else 1)
