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
# Field rows: 135 at decision 0050, +5 for decision 0051's hive-service slice (35840 B).
# +1 row for decision 0055's Weather absolute-season columns (16 B). Decision 0054's scheduler
# queue is an allocation row only: a control block, not per-entity columns, so no field row moves.
# +1 row for decision 0095's Resident life_stage column (512 B, B8 x RESIDENT_CAPACITY).
assert len(fields)==142 and sum(fields)==25029474
# §3's printed rows must sum to the "Auxiliary payload" allocation row.
#
# THE HOLE THIS CLOSES. `fields` above slices on the '## 2.3' boundary, so it covers §2.2 ONLY --
# §3 is invisible to it, and "Auxiliary payload" is a single §2.3 row maintained by hand. Three
# decisions in a row (0080, 0083, 0085) advanced that total without printing their §3 rows, and
# nothing caught it: every identity still balanced, because the hand-written total was on both
# sides of every check. 0080 was found by an agent grepping for a column name; 0083 and 0085 were
# found only when their combined 1024096 bytes turned up as the difference between this sum and
# that row. Tying the two together is what makes a total impossible to advance without its rows.
i3=s.index('\n## 3'); j3=s.index('\n## 4', i3)
section3=[]
for line in s[i3:j3].splitlines():
 if not line.startswith('|'): continue
 cells=[x.strip() for x in line.strip('|').split('|')]
 if len(cells)>=7 and all(re.fullmatch(r'\d+',cells[k]) for k in range(3,7)):
  assert int(cells[3])*int(cells[4])*int(cells[5])==int(cells[6]),cells[:7]
  section3.append(int(cells[6]))
auxiliary=int(re.search(r'\| Auxiliary payload \| (\d+) \|',s).group(1))
assert sum(section3)==auxiliary, (sum(section3), auxiliary, len(section3))
# Decision 0050's reconciliation, reproduced from its own two constants. It is NOT re-applied to
# the live payload: doing that a second time would double count 437632 bytes already in the rows.
DECISION_0050_CARRIED_BEFORE=59819174
DECISION_0050_ROW_SUM=60256806
assert DECISION_0050_ROW_SUM-DECISION_0050_CARRIED_BEFORE==131072+306304+256
# Decision 0051, hive service: five field rows on a third owner class.
DECISION_0051_ADDED=35840
# Decision 0053, movement ground slice: TransformBinding 350208 + PathRequestContact 163840 +
# ResidentRouteCursor 6144. Advanced deliberately; raise these with the next allocation, never relax.
DECISION_0053_ADDED=350208+163840+6144
assert DECISION_0053_ADDED==520192
# Decision 0055, Weather absolute-season identity: two I64 columns.
DECISION_0055_ADDED=16
# Decision 0054, R07-SCHED-001's scheduler queue: a 24th allocation row, read out of the GDScript
# so a capacity change that never reaches the ledger fails here instead of drifting silently.
DECISION_0054_ADDED=SCHEDULER_TOTAL
# Decision 0066, the route cursor's owner-persistent-id column: 512 rows x 4 bytes. It is a FOURTH
# column on decision 0053's existing ResidentRouteCursor row, so it lands inside the Auxiliary
# payload allocation, not as a new allocation row -- the row count stays 24.
DECISION_0066_ADDED=512*4
assert DECISION_0066_ADDED==2048
# Decision 0080, the packed Building/Room/Furniture index tables plus the per-tile furniture
# occupant. Eight §3 rows; they roll into the Auxiliary payload allocation, so the row count
# stays 24. Written as the products rather than one literal so a capacity change is visible.
DECISION_0080_ADDED=(1*1*1024)+(4*4*1024)+(1*1*16384)+(4*6*16384) \
	+(1*1*81920)+(4*4*81920)+(4*1*16384)+(4*1*9)
assert DECISION_0080_ADDED==1885220
# Decision 0083, travel admission and the starter ground profile catalog. The route cursor's
# owner column is NOT here: decision 0066 already added it and the ledger already carries it at
# four columns. Counting it twice is the exact double-count this trail has suffered before.
DECISION_0083_ADDED=(5*4*512)+(6*4*4)
assert DECISION_0083_ADDED==10336
# Decision 0085, StockAge's container declarations and its sweep order. Four columns over
# inventory's CONTAINER_CAPACITY. `_declared_slots` is NOT a rebuilt index: withdrawal
# swap-removes, so its order is not recoverable, and it is the sweep order that decides which
# freed lot slot the next create_lot() receives.
DECISION_0085_ADDED=(1+1+4+4)*101376
assert DECISION_0085_ADDED==1013760
# decision 0092: game_manager.gd's pre-load rollback checkpoint, _checkpoint: PackedInt64Array,
# CHECKPOINT_FIELDS(10) * 8 bytes. Allocated once in _init() and overwritten in place; it holds
# the clock's ten runtime scalars in restore_runtime() argument order and is never serialized.
DECISION_0092_ADDED=10*8
assert DECISION_0092_ADDED==80
# decision 0095: residents.gd's _life_stage, a B8 column over RESIDENT_CAPACITY. It is a §2.2
# field row, so it enters the payload through the "Fixed registry payload" allocation row rather
# than as an allocation row of its own -- the allocation count does not move for it.
DECISION_0095_ADDED=1*512
assert DECISION_0095_ADDED==512
assert len(allocations)==25 and sum(allocations)==DECISION_0050_ROW_SUM+DECISION_0051_ADDED+DECISION_0053_ADDED+DECISION_0055_ADDED+DECISION_0054_ADDED+DECISION_0066_ADDED+DECISION_0080_ADDED+DECISION_0083_ADDED+DECISION_0085_ADDED+DECISION_0092_ADDED+DECISION_0095_ADDED
payload=sum(allocations);reserve=8388608;candidate=payload-6215584;live=payload+reserve
assert payload==63733034
assert live==72121642 and candidate==57517450 and live+candidate==129639092
# The cursor row is four I32 columns over 512 rows; a fifth column or a capacity change fails here.
assert '| ResidentRouteCursor | request_row, route_generation, route_cell_index, owner_persistent_id | I32 | 4 | 4 | 512 | 8192 |' in s
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
installed=['docs/systems_architecture.md', 'docs/decisions/0016-needs-tick-consumes-most-of-the-budget.md', 'docs/decisions/0048-world-generation-anchors-and-what-it-refuses-to-invent.md', 'docs/planning/README.md', 'docs/STATUS.md', 'docs/decisions/0050-ready07-source-audit-and-ledger-reconciliation.md', 'docs/decisions/0053-movement-ground-slice-identity-and-storage.md', 'docs/decisions/0054-the-scheduler-event-queue-drains-before-every-tick.md', 'docs/planning/ready07_scheduler_contract.md', 'docs/planning/movement_ground_slice_entry.md', 'docs/rulings/2026-09-11_ready07_open_item_answers.md', 'docs/rulings/2026-09-11_ready07_executor_brief.md', 'docs/rulings/2026-09-11_ready07_memory_audit.md'];links=0;errors=[]
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
