#!/usr/bin/env python3
"""Validate resident UI specification arithmetic/source bindings, not live rendering."""
from pathlib import Path
import csv,datetime,json,re,subprocess
R=Path(__file__).resolve().parents[2]
checks=[]
def check(name,ok,detail=None):
    checks.append({'name':name,'passed':bool(ok),'detail':detail})
    if not ok:raise AssertionError(name)
f=json.loads((R/'docs/planning/resident_ui_contract_fixtures.json').read_text())
for name,p in f['profiles'].items():
    allocated=p['panel']-2*p['inset']-p['medallion']-2*p['gap']-p['close']
    check('Exact heading width '+name,allocated==p['heading'])
    check('Old minimum cannot fit '+name,allocated<280,{'over_by':280-allocated})
source=(R/'godot/scripts/core/needs.gd').read_text()
constants={k:int(n)*1000 for k,n in re.findall(r'const ([A-Z0-9_]+MILLI_PER_HOUR): int = (\d+) \* MILLI_PER_POINT',source)}
check('MILLI_PER_POINT convention','const MILLI_PER_POINT: int = 1000' in source)
c=constants
expected={
 'rest_awake':-c['REST_DECAY_MILLI_PER_HOUR'],
 'rest_bed':c['REST_RESTORE_BED_MILLI_PER_HOUR'],
 'rest_floor':c['REST_RESTORE_FLOOR_MILLI_PER_HOUR'],
 'comfort_none':-c['COMFORT_DECAY_MILLI_PER_HOUR'],
 'comfort_heated':c['COMFORT_RESTORE_HEATED_ROOM_MILLI_PER_HOUR']-c['COMFORT_DECAY_MILLI_PER_HOUR'],
 'comfort_mild':c['COMFORT_RESTORE_MILD_OUTDOORS_MILLI_PER_HOUR']-c['COMFORT_DECAY_MILLI_PER_HOUR'],
 'social_unpaired':-c['SOCIAL_DECAY_MILLI_PER_HOUR'],
 'social_paired':c['SOCIAL_RESTORE_PAIRED_MILLI_PER_HOUR']-c['SOCIAL_DECAY_MILLI_PER_HOUR'],
 'purpose_none':-c['PURPOSE_DECAY_MILLI_PER_HOUR'],
 'purpose_labor':c['PURPOSE_RESTORE_LABOR_MILLI_PER_HOUR']-c['PURPOSE_DECAY_MILLI_PER_HOUR'],
 'purpose_mentoring':c['PURPOSE_RESTORE_MENTORING_MILLI_PER_HOUR']-c['PURPOSE_DECAY_MILLI_PER_HOUR']}
def trunc(n,d):return (abs(n)//d)*(1 if n>=0 else -1)
for key,value in expected.items():
    check('Published rate fixture '+key,f['rates_milli_per_hour'][key]==value)
    for remainder in [0,345678,-345678]:
        acc=remainder; released=0
        for _ in range(750):
            acc+=value;whole=trunc(acc,750000);released+=whole;acc-=whole*750000
        check('Independent constant-rate carry '+key+' '+str(remainder),released==trunc(remainder+750*value,750000) and abs(acc)<750000)
def format_rate(r):
    cents=(abs(r)+500)//1000
    sign='' if cents==0 else '-' if r<0 else '+'
    return sign+str(cents//100)+'.'+str(cents%100).zfill(2)
for r,want in [(250000,'+2.50'),(245000,'+2.45'),(250500,'+2.51'),(-250500,'-2.51'),(499,'0.00'),(-499,'0.00'),(500,'+0.01'),(-500,'-0.01')]:
    check('Display rounding '+str(r),format_rate(r)==want)
rows=list(csv.DictReader((R/'docs/design/ui_refinement/requirements.csv').open(newline='')))
rate_row=next(row for row in rows if 'UXV-020' in row.values())
check('Requirement CSV records capped continuous-rate semantics','Capped' in ' '.join(rate_row.values()) and 'continuous' in ' '.join(rate_row.values()))
doc=R/'docs/rulings/2026-09-12_resident_header_and_need_rates.md'
for target in re.findall(r'\]\(([^)]+)\)',doc.read_text()):
    if target.endswith('2026-09-12_resident_ui_validation.json'):continue
    if target.startswith(('http:','https:','#')):continue
    check('Ruling link '+target,(doc.parent/target.split('#')[0]).exists())
reg=subprocess.run(['python3','docs/validation/state_registry_coverage.py'],cwd=R,capture_output=True,text=True)
checks.append({'name':'Current registry coverage','passed':reg.returncode==0,'detail':reg.stdout.strip()+reg.stderr.strip()})
diff=subprocess.run(['git','-c','filter.lfs.required=false','-c','filter.lfs.smudge=','-c','filter.lfs.process=','diff','--check','--','docs'],cwd=R,capture_output=True,text=True)
checks.append({'name':'Documentation whitespace','passed':diff.returncode==0,'detail':diff.stdout.strip()+diff.stderr.strip()})
report={'result':'PASS' if all(c['passed'] for c in checks) else 'FAIL','checked_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Documentation/source, reference arithmetic, registry coverage. No Godot runtime or visual acceptance.','checks':checks,'not_verified':['New public rate-reader implementation','Snapshot wiring and identity guards','Actual font wrap/geometry/render captures','UI rate/cap display','Per-frame or hot-path performance']}
(R/'docs/rulings/2026-09-12_resident_ui_validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'result':report['result'],'checks':len(checks),'registry':reg.stdout.strip(),'failures':[c for c in checks if not c['passed']]},indent=2))
raise SystemExit(0 if report['result']=='PASS' else 1)
