from pathlib import Path
import argparse,hashlib,json,re,struct
r=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description='Reproduce READY_07 static review arithmetic; not game tests.')
parser.add_argument('--output',type=Path)
args=parser.parse_args()
sched=(r/'godot/scripts/core/scheduler_events.gd').read_text()
def gd_const(name):
 m=re.search(r'^const %s: int = (\d+)$'%name,sched,re.M)
 assert m,name
 return int(m.group(1))
SCHEDULER_CAPACITY=gd_const('QUEUE_CAPACITY');SCHEDULER_RECORD=gd_const('RECORD_BYTES')
SCHEDULER_CONTROL=gd_const('CONTROL_BYTES');SCHEDULER_NORMAL=gd_const('NORMAL_CAPACITY')
SCHEDULER_TOTAL=SCHEDULER_CAPACITY*SCHEDULER_RECORD+SCHEDULER_CONTROL
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
assert len(fields)==135 and sum(fields)==24993106
# ADR0054 advanced this pin deliberately: R07-SCHED-001's scheduler queue is a 24th allocation row.
assert len(allocations)==24 and sum(allocations)==60265030
payload=sum(allocations);reserve=8388608;candidate=payload-6215584;live=payload+reserve
assert live==68653638 and candidate==54049446 and live+candidate==122703084
# ADR0050's 437632 reconciliation is REPRODUCED, not reapplied: subtract only the new queue.
assert payload-SCHEDULER_TOTAL-59819174==131072+306304+256
assert f'| Scheduler event queue and control header | 1 | {SCHEDULER_TOTAL} | {SCHEDULER_TOTAL} |' in s
for label,value in [('Planned allocated payload',payload),('One live world plus reserve',live),('Headroom below decimal 100 MB',100000000-live),('Additional candidate mutable state',candidate),('Transactional peak plus same reserve',live+candidate),('Transactional headroom',100000000-live-candidate)]:
 assert f'| {label} | {value} |' in s,label
catalog=json.loads((r/'godot/data/catalog_ids.json').read_text())['domains']['ItemDefinition']
bindings={'resource': ['wood','stone','iron'],'forage':['berries','nuts','mushrooms','herb','roots'],'fish':['trout','dace','salmon','perch','carp','whitefish','herring','mackerel','mussel']}
actual={k:[catalog[n] for n in names] for k,names in bindings.items()}
assert actual=={'resource':[59,52,19],'forage':[1,35,32,15,39],'fish':[55,8,41,37,5,58,16,20,33]}
ticks={f'{season}:{day}':((season*12+day-1)*18000-4500) for season,day in [(1,3),(1,6),(1,8),(1,9),(2,1),(2,3),(2,6)]}
assert list(ticks.values())==[247500,301500,337500,355500,427500,463500,517500]
assert struct.calcsize('<qIIiiiI')==32 and struct.calcsize('<iiIIqII')==32
assert SCHEDULER_CAPACITY*SCHEDULER_RECORD+SCHEDULER_CONTROL==SCHEDULER_TOTAL==8224
assert (SCHEDULER_CAPACITY,SCHEDULER_RECORD,SCHEDULER_CONTROL,SCHEDULER_NORMAL)==(256,32,32,250)
assert SCHEDULER_CAPACITY-SCHEDULER_NORMAL==6 and 48+32*SCHEDULER_CAPACITY==8240
installed=['docs/systems_architecture.md', 'docs/decisions/0016-needs-tick-consumes-most-of-the-budget.md', 'docs/decisions/0048-world-generation-anchors-and-what-it-refuses-to-invent.md', 'docs/planning/README.md', 'docs/STATUS.md', 'docs/decisions/0050-ready07-source-audit-and-ledger-reconciliation.md', 'docs/decisions/0054-the-scheduler-event-queue-drains-before-every-tick.md', 'docs/planning/ready07_scheduler_contract.md', 'docs/rulings/2026-09-11_ready07_open_item_answers.md', 'docs/rulings/2026-09-11_ready07_executor_brief.md', 'docs/rulings/2026-09-11_ready07_memory_audit.md'];links=0;errors=[]
for name in installed:
 f=r/name
 for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)',f.read_text()):
  path=target.strip('<>').split('#')[0]
  if not path or '://' in path or path.startswith('mailto:'):continue
  links+=1
  if not (f.parent/path).resolve().exists():errors.append(f'{name}: {path}')
assert not errors,errors
report={'scope':'STATIC_SOURCE_ARITHMETIC_AND_DOCUMENT_LINK_REVIEW_NOT_RUNTIME_TESTS','status':'PASS','revision_reviewed':'16e1efc','field_rows':len(fields),'field_bytes':sum(fields),'allocation_rows':len(allocations),'payload_bytes':payload,'live_with_reserve_bytes':live,'two_world_peak_bytes':live+candidate,'catalog_bindings':actual,'synthetic_weather_boundary_ticks':ticks,'scheduler_status':'IMPLEMENTED_AND_LEDGERED_ADR0054','scheduler_record_bytes':SCHEDULER_RECORD,'scheduler_control_bytes':SCHEDULER_CONTROL,'scheduler_total_bytes':SCHEDULER_TOTAL,'scheduler_capacity':SCHEDULER_CAPACITY,'scheduler_normal_capacity':SCHEDULER_NORMAL,'checked_local_links':links,'files_reviewed':installed,'runtime_tests':'NOT_RUN','runtime_code_changed':True,'remaining_proposed_fields_in_existing_ledger':False,'source_sha256':{n:hashlib.sha256((r/n).read_bytes()).hexdigest() for n in ['docs/game_gdd.md','docs/systems_architecture.md','godot/data/catalog_ids.json','docs/movement_direction_amendment.md','godot/scripts/core/scheduler_events.gd']}}
if args.output:
 args.output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['status','field_rows','allocation_rows','scheduler_total_bytes','checked_local_links','runtime_tests']}))
