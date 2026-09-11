from pathlib import Path
import argparse,hashlib,json,re,struct
r=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description='Reproduce READY_07 static review arithmetic; not game tests.')
parser.add_argument('--output',type=Path)
args=parser.parse_args()
s=(r/'docs/systems_architecture.md').read_text();a=s.index('## 2.3');b=s.index('**ARCH-MEM-010',a)
fields=[];allocations=[]
for l in s[:a].splitlines():
 c=[x.strip() for x in l.strip('|').split('|')]
 if l.startswith('|') and len(c)==8 and all(c[i].isdigit() for i in [3,4,5,6]):
  assert int(c[3])*int(c[4])*int(c[5])==int(c[6]),c
  fields.append(int(c[6]))
for l in s[a:b].splitlines():
 c=[x.strip() for x in l.strip('|').split('|')]
 if l.startswith('|') and len(c)==6 and c[3].isdigit():allocations.append(int(c[3]))
# Advanced 2026-09-11 for decision 0051's hive-service slice: five new field rows
# totalling 35840 bytes, and the same amount in one ARCH-MEM-009 step. The planner's
# own instruction is to review changed expectations rather than treat the inspected
# snapshot's counts as permanent limits. Row identity and the five metric identities
# below are unchanged; only these two pinned baselines advance.
# Advanced 2026-09-11 for decision 0055's Weather absolute-season identity: ONE new
# field row of 8*2*1=16 bytes, taking the Weather row from 32 to 48. No new §2.3
# allocation row -- the Fixed registry payload row IS the §2.2 sum and moves with it.
# Expectations are advanced deliberately, not loosened: every identity below still
# holds exactly, and the row/allocation COUNTS are still pinned.
assert len(fields)==141 and sum(fields)==25028962
assert len(allocations)==23 and sum(allocations)==60292662
payload=sum(allocations);reserve=8388608;candidate=payload-6215584;live=payload+reserve
assert live==68681270 and candidate==54077078 and live+candidate==122758348
# Carried total advanced by decision 0051's +35840 (59819174 -> 59855014) and then by
# decision 0055's +16 (-> 59855030). Both halves move together, so the 437632 gap is
# reproduced a fourth time rather than absorbed or re-applied.
assert payload-59855030==131072+306304+256
# Decision 0055's two Weather rows, pinned as printed so a silent revert fails here.
assert '| Weather | scheduled_absolute_season, forecast_absolute_season | I64 | 8 | 2 | 1 | 16 |' in s
assert 4*8*1+8*2*1==48 and 4*8*1==32
# Carried-basis figures of the same +16, checked as identities rather than restated.
assert 59855030+reserve==68243638 and 100000000-68243638==31756362
assert 68243638+(59855030-6215584)==121883084
for label,value in [('Planned allocated payload',payload),('One live world plus reserve',live),('Headroom below decimal 100 MB',100000000-live),('Additional candidate mutable state',candidate),('Transactional peak plus same reserve',live+candidate),('Transactional headroom',100000000-live-candidate)]:
 assert f'| {label} | {value} |' in s,label
catalog=json.loads((r/'godot/data/catalog_ids.json').read_text())['domains']['ItemDefinition']
bindings={'resource': ['wood','stone','iron'],'forage':['berries','nuts','mushrooms','herb','roots'],'fish':['trout','dace','salmon','perch','carp','whitefish','herring','mackerel','mussel']}
actual={k:[catalog[n] for n in names] for k,names in bindings.items()}
assert actual=={'resource':[59,52,19],'forage':[1,35,32,15,39],'fish':[55,8,41,37,5,58,16,20,33]}
ticks={f'{season}:{day}':((season*12+day-1)*18000-4500) for season,day in [(1,3),(1,6),(1,8),(1,9),(2,1),(2,3),(2,6)]}
assert list(ticks.values())==[247500,301500,337500,355500,427500,463500,517500]
assert struct.calcsize('<qIIiiiI')==32 and struct.calcsize('<iiIIqII')==32
assert 256*32+32==8224
installed=['docs/systems_architecture.md', 'docs/decisions/0016-needs-tick-consumes-most-of-the-budget.md', 'docs/decisions/0048-world-generation-anchors-and-what-it-refuses-to-invent.md', 'docs/planning/README.md', 'docs/STATUS.md', 'docs/decisions/0050-ready07-source-audit-and-ledger-reconciliation.md', 'docs/planning/ready07_scheduler_contract.md', 'docs/rulings/2026-09-11_ready07_open_item_answers.md', 'docs/rulings/2026-09-11_ready07_executor_brief.md', 'docs/rulings/2026-09-11_ready07_memory_audit.md'];links=0;errors=[]
for name in installed:
 f=r/name
 for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)',f.read_text()):
  path=target.strip('<>').split('#')[0]
  if not path or '://' in path or path.startswith('mailto:'):continue
  links+=1
  if not (f.parent/path).resolve().exists():errors.append(f'{name}: {path}')
assert not errors,errors
report={'scope':'STATIC_SOURCE_ARITHMETIC_AND_DOCUMENT_LINK_REVIEW_NOT_RUNTIME_TESTS','status':'PASS','revision_reviewed':'16e1efc','field_rows':len(fields),'field_bytes':sum(fields),'allocation_rows':len(allocations),'payload_bytes':payload,'live_with_reserve_bytes':live,'two_world_peak_bytes':live+candidate,'catalog_bindings':actual,'synthetic_weather_boundary_ticks':ticks,'proposed_scheduler_record_bytes':32,'proposed_scheduler_control_bytes':32,'proposed_scheduler_total_bytes':8224,'checked_local_links':links,'files_reviewed':installed,'runtime_tests':'NOT_RUN','runtime_code_changed':False,'proposed_fields_in_existing_ledger':False,'source_sha256':{n:hashlib.sha256((r/n).read_bytes()).hexdigest() for n in ['docs/game_gdd.md','docs/systems_architecture.md','godot/data/catalog_ids.json','docs/movement_direction_amendment.md']}}
if args.output:
 args.output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['status','field_rows','allocation_rows','checked_local_links','runtime_tests']}))
