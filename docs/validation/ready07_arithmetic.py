from pathlib import Path
import argparse,hashlib,importlib.util,json,re,struct
r=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description='Reproduce READY_07 static review arithmetic; not game tests.')
parser.add_argument('--output',type=Path)
args=parser.parse_args()
sched=(r/'godot/scripts/core/scheduler_events.gd').read_text()
def gd_const(name,source=sched):
 m=re.search(r'^const %s: int = (\d+)$'%name,source,re.M)
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
# +1 row for decision 0531's InventoryContainer.anchor_tile (405504 B, I32 x CONTAINER_CAPACITY).
assert len(fields)==145 and sum(fields)==25444194
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
# decision 0104: sim_clock.gd's load barrier -- one 8-byte object reference plus the 1-byte
# RefCounted token it points at. Counted at its maximum of one token, since a second concurrent
# acquire refuses and mints none. scheduler_events.gd adds no field.
DECISION_0104_ADDED=8+1
assert DECISION_0104_ADDED==9
# decision 0109: injury.gd's aggregate store (5 B8 + 3 I32 + 3 I64 over RESIDENT_CAPACITY) plus
# needs.gd's one _airless input byte. 2560 + 6144 + 12288 + 512 = 21504 GROSS. The Injury
# component already held two rows in 2.2 (5 I32 = 10240 and 1 I64 = 4096) budgeting kind,
# severity, rescuer_slot, rescuer_generation and care_progress_mwu under their planned widths.
# Those 14336 bytes were replaced by the implemented layout, not added to it, so the NET
# allocation is 7168. The 2.2 rows now carry injury.gd's actual widths; this term is the
# difference. Counting the gross here is exactly the double-count merge_gate.py's cross-form
# check exists to catch, and is how it was found.
DECISION_0109_ADDED=(5*1*512)+(3*4*512)+(3*8*512)+(1*1*512)-(10240+4096)
assert DECISION_0109_ADDED==7168
# decision 0110: work.gd's per-contributor tool settlement, 5 I32 + 1 B8 over RESIDENT_CAPACITY
# (10240 + 512), MINUS the 4096 that ResidentRuntime's I64 group budgeted for wear_remainder.
# That store does not exist and this one does; one field budgeted twice at two widths is how a
# ledger drifts, so the field moved rather than being counted again.
DECISION_0110_ADDED=(5*4*512)+(1*1*512)-(8*1*512)
assert DECISION_0110_ADDED==6656
# decision 0114: ui_manager.gd's three roster identity columns at ROSTER_POOL = 12. A FULL 144,
# not a net 96 against the _roster_slots array it replaces -- that array was never ledgered, so
# removing it frees no counted byte. state_registry_coverage.py globs godot/scripts/core only.
DECISION_0114_ADDED=3*4*12
assert DECISION_0114_ADDED==144
# decision 0127: canonical_state_hash.gd's resident declaration table, built once from the
# checked-in registry. 800 + 1770 + 4720 + 2360 fixed, plus 8734 bytes of key text.
# decision 0127, CORRECTED by decision 0142. The row read 50 owners and 590 fields from the day
# it was written and was never re-derived as owners and fields were added, so it under-budgeted by
# 441 bytes. These terms are now the registry's actual census -- 52 owners, 604 fields, 8933 bytes
# of key text across the two PackedStringArrays -- computed from canonical_state_registry.json
# rather than adjusted to match the old total. A row that names its own arithmetic and is never
# re-run is a row that silently decays.
# Decision0167: derive the current census, so unledgered future growth fails loudly.
registry=json.loads((r/'docs/planning/canonical_state_registry.json').read_text())
registry_owners=registry['owners']
registry_fields=[f for owner in registry_owners for f in owner['fields']]
registry_key_bytes=sum(len(owner['owner_key'].encode('utf-8')) for owner in registry_owners)+sum(len(f['field_key'].encode('utf-8')) for f in registry_fields)
# Decision 0531 appended `_c_anchor_tile`: 52 owners, 612 fields and 9065 key bytes.
# Decisions 1053/1060 add one RoomProjects owner and eleven fields: +16 owner bytes,
# +165 field bytes and +171 UTF-8 key bytes. Decision 1062 reconciles the actual buffers.
assert (len(registry_owners),len(registry_fields),registry_key_bytes)==(61,764,11137)
assert (registry['record_count'],registry['packed_source_field_count'])==(756,671)
assert sum(bool(field['hash']) for field in registry_fields)==756
DECISION_0127_ADDED=len(registry_owners)*16+len(registry_fields)*15+registry_key_bytes
assert DECISION_0127_ADDED==23573 and DECISION_0127_ADDED-21185==2388
# RoomProjects is additional mutable state, not a replacement for Construction's paid ledger.
# Read all eleven source declarations and allocation expressions, then require exact agreement
# with both the canonical owner's widths/capacities and the three printed auxiliary rows.
room_source=(r/'godot/scripts/core/room_projects.gd').read_text()
construction_source=(r/'godot/scripts/core/construction.gd').read_text()
jobs_source=(r/'godot/scripts/core/jobs.gd').read_text()
assert 'const PROJECT_CAPACITY: int = Construction.CONSTRUCTION_CAPACITY' in room_source
assert 'const JOB_CAPACITY: int = Jobs.JOB_CAPACITY' in room_source
room_capacities={'PROJECT_CAPACITY':gd_const('CONSTRUCTION_CAPACITY',construction_source),
                 'JOB_CAPACITY':gd_const('JOB_CAPACITY',jobs_source)}
assert room_capacities=={'PROJECT_CAPACITY':82944,'JOB_CAPACITY':8192}
packed_widths={'PackedByteArray':1,'PackedInt32Array':4,'PackedInt64Array':8}
room_columns=re.findall(r'^var (_\w+): (Packed\w+Array) =',room_source,re.M)
room_resizes=re.findall(r'^\t(_\w+)\.resize\((\w+)\)$',room_source,re.M)
assert len(room_columns)==len(room_resizes)==11
assert len(dict(room_columns))==len(dict(room_resizes))==11
room_shapes={name:(packed_widths[kind],room_capacities[dict(room_resizes)[name]])
             for name,kind in room_columns}
room_owner=next(owner for owner in registry_owners if owner['owner_key']=='room_projects')
assert room_owner['section_id']==6 and room_owner['owner_schema_version']==1
assert len(room_owner['fields'])==len(room_shapes)
assert {field['source_member'] for field in room_owner['fields']}==set(room_shapes)
for field in room_owner['fields']:
 name=field['source_member']; capacity_name=dict(room_resizes)[name]
 assert field['hash'] and field['source_module']=='room_projects'
 assert room_shapes[name]==({'u8':1,'i32':4}[field['type']],room_capacities[capacity_name])
 assert field['shape']['declared_capacity']==f'`{capacity_name}` = {room_capacities[capacity_name]}'
for width,capacity,kind in [(1,82944,'B8'),(4,82944,'I32'),(4,8192,'I32')]:
 names=[name for name,shape in room_shapes.items() if shape==(width,capacity)]
 row=f'| RoomProjects | {", ".join(names)} | {kind} | {width} | {len(names)} | {capacity} | {width*len(names)*capacity} |'
 assert row in s,row
DECISION_1053_ADDED=sum(width*capacity for width,capacity in room_shapes.values())
assert DECISION_1053_ADDED==(3+4*4)*82944+4*4*8192==1707008
# Decision1066: account for every actual packed column of both excavation owners,
# including derived indexes and transaction scratch. The unchanged source-proof grammar
# supplies bounds; literal independent totals and exact member sets catch missing columns.
audit_spec=importlib.util.spec_from_file_location('capacity_source_proof',r/'tools/audit_registry_capacities.py')
audit_module=importlib.util.module_from_spec(audit_spec);audit_spec.loader.exec_module(audit_module)
source_index=audit_module.load_source_index()
excavation_shapes={}
for module,expected_columns,expected_bytes in [('excavation_inventory',26,5220352),('excavation_sites',24,8388597)]:
 source=source_index[module].text
 columns=dict(re.findall(r'^var (_\w+): (Packed\w+Array) =',source,re.M))
 assert len(columns)==expected_columns,(module,len(columns))
 shapes={}
 for name,kind in columns.items():
  binding=audit_module.resize_binding(source_index,module,name)
  assert isinstance(binding,audit_module.Binding),(module,name,binding)
  relation,bound=audit_module.classify_from_source(source_index,module,binding.expression)
  assert isinstance(bound,audit_module.Proved),(module,name,bound)
  shapes[name]=(packed_widths[kind],bound.value)
 assert sum(width*capacity for width,capacity in shapes.values())==expected_bytes,module
 excavation_shapes[module]=shapes
fund_shapes=excavation_shapes['excavation_inventory'];site_shapes=excavation_shapes['excavation_sites']
fund_scratch={'_s_item','_s_quality','_s_provenance','_s_recipe','_s_quantity','_s_age','_s_remainder','_s_totals','_s_returned','_s_carry'}
site_derived={'_ordered_key','_ordered_row','_job_site'}
site_scratch={'_delivery_totals'}
for module,shapes,excluded,expected_scalars in [
 ('excavation_inventory',fund_shapes,fund_scratch,2),
 ('excavation_sites',site_shapes,site_derived|site_scratch,20)]:
 owner=next(o for o in registry_owners if o['owner_key']==module)
 packed=[f for f in owner['fields'] if 'source_contract' in f]
 assert owner['section_id']==6 and owner['owner_schema_version']==(3 if module=='excavation_inventory' else 1)
 assert {f['source_member'] for f in packed}==shapes.keys()-excluded
 assert sum(bool(f.get('scalar')) for f in owner['fields'])==expected_scalars
 for field in packed:
  assert field['hash'] and field['source_module']==module
  assert {'u8':1,'i32':4,'i64':8}[field['type']]==shapes[field['source_member']][0]
site_source=source_index['excavation_sites'].text
fund_source=source_index['excavation_inventory'].text
assert gd_const('MAX_SITE_CAPACITY',site_source)==73909
assert gd_const('MAX_SITE_ARENA_BYTES',site_source)==8388608
assert gd_const('SITE_RECORD_BYTES',site_source)==113
assert 'const MAX_RECEIPT_CAPACITY: int = Reservations.ROW_CAPACITY' in fund_source
assert 'const MAX_EARNED_CAPACITY: int = MAX_SITE_CAPACITY * Contract.OP_COUNT' in site_source
assert 'var earned_request: int = _capacity * OP_COUNT' in site_source
assert '_earned_capacity = clampi(earned_request, 0, MAX_EARNED_CAPACITY)' in site_source
assert gd_const('OP_COUNT',(r/'godot/scripts/core/excavation_contract.gd').read_text())==5
assert site_shapes['_earned_mwu']==(8,73909*5)
assert 113*73909+36880==8388597<=8388608<113*73910+36880
assert fund_shapes['_free']==(4,32768)
# Numeric control widths come from declarations, not the canonical wire's narrower
# bounded-capacity encodings. Any new member forces a fresh ledger decision.
site_ints={'_capacity','_earned_capacity','_count','_domain_capacity','_initial_earth_milli',
           '_virgin_sourced_milli','_funded_braces','_completed_braces','_salvaged_braces',
           '_returned_brace_milli','_permit_action','_candidate_row','_candidate_stage'}
assert set(re.findall(r'^var (_\w+): int\b',site_source,re.M))==site_ints
assert set(re.findall(r'^var (_\w+): int\b',fund_source,re.M))=={'_capacity','_free_count','_s_count'}
assert set(re.findall(r'^var (_\w+): Vector2i\b',site_source,re.M))=={'_permit_project'}
assert len(re.findall(r'^var (_\w+): IntMath.IntResult\b',site_source,re.M))==2
assert len(re.findall(r'^var (_\w+): IntMath.IntResult\b',fund_source,re.M))==1
domain_source=(r/'godot/scripts/core/excavation_contract.gd').read_text().split('class Domain extends RefCounted:',1)[1].split('\nclass ',1)[0]
assert re.findall(r'var (\w+): Vector2i\b',domain_source)==['world_ref']
assert re.findall(r'var (\w+): Vector3i\b',domain_source)==['datum_u','minimum_quantum','size_quanta']
assert 'var _publishing_excavation_job: Vector2i' in (r/'godot/scripts/core/work.gd').read_text()
# Scalar numeric payload is additional to packed storage, not hidden in the reserve:
# Sites nine int64 controls +11 int32 domain components; Funding two int64 controls;
# one derived int64 earned-capacity bound. Native object/Variant/String headers remain
# unmeasured. Synchronous permits32, three IntResults27, staged-count8 and Work ref8
# add75 numeric scratch bytes; local test state_bytes images are not a release codec.
DECISION_1066_CONTROLS=9*8+11*4+2*8+8
DECISION_1066_TRANSIENTS=32+3*(8+1)+8+8
assert (DECISION_1066_CONTROLS,DECISION_1066_TRANSIENTS)==(140,75)
# Keep1066 historical;1072 adds two loss domains and1102 adds a fourth.
# Their live growth is already in the current packed census; subtract it once here.
CURRENT_EXCAVATION_PACKED=sum(w*c for shapes in excavation_shapes.values() for w,c in shapes.values())
CURRENT_FUNDING_LOSS_GROWTH=fund_shapes['_lost_milli'][0]*fund_shapes['_lost_milli'][1]-256*8
assert CURRENT_FUNDING_LOSS_GROWTH==6144
DECISION_1066_PACKED=CURRENT_EXCAVATION_PACKED-CURRENT_FUNDING_LOSS_GROWTH
DECISION_1066_SCRATCH=sum(w*c for name,(w,c) in fund_shapes.items() if name in fund_scratch)+16+DECISION_1066_TRANSIENTS
DECISION_1066_ADDED=DECISION_1066_PACKED+DECISION_1066_CONTROLS+DECISION_1066_TRANSIENTS
assert (DECISION_1066_PACKED,DECISION_1066_SCRATCH,DECISION_1066_ADDED)==(13602805,1316955,13603020)
assert '| Excavation transaction scratch | 1 | 1316955 | 1316955 |' in s
for module,label,shapes,scratch in [('excavation_inventory','ExcavationFunding',fund_shapes,fund_scratch),
                                 ('excavation_sites','ExcavationSites',site_shapes,site_scratch)]:
 for name,(width,capacity) in shapes.items():
  if name in scratch: continue
  matches=[line for line in s.splitlines() if line.startswith('| '+label)
           and name in [n.strip() for n in line.split('|')[2].split(',')]]
  assert len(matches)==1,(module,name,matches)
  cells=[v.strip() for v in matches[0].split('|')]
  assert (int(cells[4]),int(cells[6]))==(width,capacity),(module,name,cells)
# Decision1068 adds a derived live index and a separate cold restore index.
# Resolve the actual source allocation; neither buffer adds canonical fields.
gear_source=source_index['gear'].text
gear_index_binding=audit_module.resize_binding(source_index,'gear','_lot_row')
assert isinstance(gear_index_binding,audit_module.Binding)
gear_index_relation,gear_index_bound=audit_module.classify_from_source(source_index,'gear',gear_index_binding.expression)
assert isinstance(gear_index_bound,audit_module.Proved)
assert gear_index_bound.value==16384 and gear_index_binding.expression=='LOT_CAPACITY'
assert 'lot_rows.resize(LOT_CAPACITY)' in gear_source
assert 'var _lot_row: PackedInt32Array' in gear_source
assert '| GearInstanceIndex | lot_row | I32 | 4 | 1 | 16384 | 65536 |' in s
assert '| Gear restore index staging | 16384 | 4 | 65536 |' in s
assert not any(f.get('source_module')=='gear' and f.get('source_member')=='_lot_row' for f in registry_fields)
DECISION_1068_ADDED=2*4*gear_index_bound.value
assert DECISION_1068_ADDED==131072
# Decision1071 registers mandatory Room/Furniture extension flags and counts both
# actual live bytes and the conservative cold image. The Sites publication bool
# is transient, not a new hashed field. No legacy section4 layout is weakened.
buildings_source=source_index['buildings'].text
spatial_flag_shapes={}
for name,expected in [('_r_spatial_kind',16384),('_f_installed',81920)]:
 assert f'var {name}: PackedByteArray' in buildings_source
 binding=audit_module.resize_binding(source_index,'buildings',name)
 assert isinstance(binding,audit_module.Binding)
 relation,bound=audit_module.classify_from_source(source_index,'buildings',binding.expression)
 assert relation=='eq' and isinstance(bound,audit_module.Proved) and bound.value==expected
 spatial_flag_shapes[name]=bound.value
 extension=next(o for o in registry_owners if (o['section_id'],o['owner_key'])==(6,'buildings'))
 assert [(f['field_key'],f['type']) for f in extension['fields']]==[('_r_spatial_kind','u8'),('_f_installed','u8')]
assert set(re.findall(r'^var (_\w+): bool\b',site_source,re.M))=={
 '_publishing_spatial','_starting','_start_poisoned','_settling','_settlement_poisoned'}
assert 'var out: PackedByteArray = _r_spatial_kind.duplicate()' in buildings_source
assert 'out.append_array(_f_installed)' in buildings_source
DECISION_1071_MUTABLE=2*sum(spatial_flag_shapes.values())+1
assert DECISION_1071_MUTABLE==196609
assert '| Spatial Room/Furniture flag image | 98304 | 1 | 98304 |' in s
assert '| Sites spatial publication guard | 1 | 1 | 1 |' in s
# Decision1072: the selected joint source-derived pack and outstanding finite envelopes.
# Module import shares the strict source-proof grammar; this does not prove runtime RAM.
import sys
sys.path.insert(0,str(r/'tools'))
import underground_memory_budget
underground_pack=underground_memory_budget.build()
CURRENT_UNDERGROUND_MUTABLE=underground_pack['new_mutable_and_reserved_bytes']
# Preserve1072's trail;1102 adds256 I64 cells in both live and conservative cold state.
DECISION_1102_MUTABLE=2*(fund_shapes['_lost_milli'][0]*fund_shapes['_lost_milli'][1]-3*256*8)
assert DECISION_1102_MUTABLE==4096 and CURRENT_UNDERGROUND_MUTABLE==4966873
# Decisions1117/1120 add two synchronous guard bytes each. Decision1122's
# full fixed/helper reservation is additional to the already assigned binding
# reserve. Keep1072's historical amount unchanged and add each increment once.
DECISION_1117_MUTABLE=2
DECISION_1120_MUTABLE=2
DECISION_1122_MUTABLE=underground_pack['contributions']['entry_structure_bindings']
assert DECISION_1122_MUTABLE==384
assert underground_pack['contributions']['excavation_start_controls']==DECISION_1117_MUTABLE+DECISION_1120_MUTABLE
assert '| Sites START transaction guards | 2 | 1 | 2 |' in s
assert '| Sites settlement transaction guards | 2 | 1 | 2 |' in s
assert '| Entry structure controls and helper allowance | 1 | 384 | 384 |' in s
LATER_UNDERGROUND_MUTABLE=DECISION_1117_MUTABLE+DECISION_1120_MUTABLE+DECISION_1122_MUTABLE
DECISION_1072_MUTABLE=CURRENT_UNDERGROUND_MUTABLE-DECISION_1102_MUTABLE-LATER_UNDERGROUND_MUTABLE
assert DECISION_1072_MUTABLE==4962389
assert underground_pack['declaration_bytes']==DECISION_0127_ADDED
assert not underground_pack['runtime_qualified']
assert '| Joint underground pack and remaining envelopes | 1 | 4960341 | 4960341 |' in s
assert fund_shapes['_lost_milli']==(8,1024)
# 179 prior omitted bytes plus44 new field metadata enter the term above ONCE.
DECISION_0167_CLAIM_SLOT=512*4
assert DECISION_0167_CLAIM_SLOT==2048
# Decision 0531: DEMO-CONTAIN-R01's InventoryContainer.anchor_tile, one I32 per container row at
# ARCH-MEM-002's 101376. Its 29 bytes of declaration metadata enter DECISION_0127_ADDED above.
DECISION_0531_ANCHOR=101376*4
assert DECISION_0531_ANCHOR==405504
# Decision 0532: DEMO-CONTAIN-R01 #9's ground piles. Four §2.3 allocation rows, no §2.2 field row
# (the derived tile map is unsaved): inventory.gd's tile -> pile map, one i32 per GDD §5.1 tile;
# its reclaim candidates, one i32 per undo-journal entry; ground_piles.gd's breadth-first visit
# byte and queue i32 per tile; and its refund-ring sort keys (2*(128+128) i64, DEC-043's doorless
# ring rule) plus one i32 start tile. Raise this with the next allocation; never relax it.
DECISION_0532_TILE_MAP=16384*4
DECISION_0532_CANDIDATES=4096*4
DECISION_0532_SPILL=16384*(1+4)
DECISION_0532_RING=2*(128+128)*8+4
DECISION_0532_ADDED=DECISION_0532_TILE_MAP+DECISION_0532_CANDIDATES+DECISION_0532_SPILL+DECISION_0532_RING
assert DECISION_0532_ADDED==167940
# decision 0130: the resident render path. 512*100 instance buffer (48 B of PackedFloat32Array
# transform, 4 B of owner slot and the RenderingServer's own 48 B TRANSFORM_3D instance, counted
# rather than assumed free) plus 87552*36 for a SECOND transforms.gd instance. That second store
# is a scaffold, not a design: settlement_system.gd composes no Transform store and GDD 5.1
# authors no resident spawn coordinates, so the renderer borrows a presentation-private one. It
# is 98% of this delta and the row is deleted WHOLE when movement composes ARCH-SYS-001.
DECISION_0130_ADDED=(512*100)+(87552*36)
assert DECISION_0130_ADDED==3203072
# decision 0131: construction.gd's project lifecycle. Two B8 and seven I32 columns over
# PROJECT_CAPACITY = 82944, plus a four-slot I64 material ledger at 82944*4 = 331776. §2.2's
# existing Construction columns are NOT re-added: this is the index and ledger the store owns
# on top of them. The bill tables are 3828 bytes of immutable catalog inside §2.3's existing
# 2097152-byte arena and owe no row.
DECISION_0131_ADDED=(2*1*82944)+(7*4*82944)+(1*8*331776)
assert DECISION_0131_ADDED==5142528
# decision 0138: INIT-POSE-R01 composes ONE transforms.gd in settlement_system.gd and the
# renderer borrows it, so the presentation-private scaffold is deleted WHOLE. This is the first
# NEGATIVE term in this ledger. The bytes are not moved anywhere: §2.2's Transform rows
# (2801664) plus §3's TransformBinding (350208) already budget 3151872 for the one real store,
# which is exactly what the scaffold duplicated. Decision 0130's +3203072 stays; only its second
# row is removed, and the 51200 instance-buffer row it also added remains.
DECISION_0138_REMOVED=-(87552*9*4)
assert DECISION_0138_REMOVED==-3151872
# decision 0145: the demolition owner scan. Three cold-path buffers in settlement_system.gd,
# sized once in _init() and written only by request_demolition(), never by a tick. The scan
# pairs are inventory.owner_query_cells() = 101376 x 2; the seen bitmap is one byte per
# container cell; the report holds generation-checked lot identity rather than bare slots.
# godot/scripts/systems is outside state_registry_coverage.py's glob, so these owe no registry
# row -- which is exactly why they need a ledger row instead of being invisible.
DECISION_0145_ADDED=(202752*4)+(101376*1)+(2*16384*4)
assert DECISION_0145_ADDED==1043456
# Decision0169: count actual immutable const Array tables, independently of the generator.
# Logical int64/key-byte payload; Variant/container/scalar/native overhead is not RSS-qualified.
import ast
schema_source=(r/'godot/scripts/core/save_component_columns_schema.gd').read_text()
schema_arrays=[ast.literal_eval(body) for body in re.findall(r'^const [A-Z_]+: Array = (\[[\s\S]*?\])',schema_source,re.M)]
schema_ints=sum(isinstance(value,int) for array in schema_arrays for value in array)
schema_key_bytes=sum(len(value.encode('utf-8')) for array in schema_arrays for value in array if isinstance(value,str))
assert (len(schema_arrays),schema_ints,schema_key_bytes)==(15,781,4288)
DECISION_0169_ADDED=schema_ints*8+schema_key_bytes
assert DECISION_0169_ADDED==10536
# decision 0521: households.gd, PC-04's household and dependent-care owner (FAMILY-STATE-R01).
# Eight §3 rows rolling into the Auxiliary payload allocation, so it adds no row:
# households B8[256] + 3 I32[256] + member arena 2 I32[2048] + i64 cursor, and dependents
# 4 B8[512] + 10 I32[512] + 1 I64[512] + i64 served day. The 5632-byte selection scratch is NOT
# here: the selection pass is held at gate 6 and allocates nothing yet.
DECISION_0521_ADDED=(1*256)+(3*4*256)+(2*4*2048)+8+(4*1*512)+(10*4*512)+(8*512)+8
assert DECISION_0521_ADDED==46352
# Decision 0534: DEMO-CONTAIN-R01 D4's admit. demolition_admissions.gd's record, five I32 and one
# I64 per Building row (1024), folds into the Auxiliary payload row; the admit scratch is one new
# allocation row: two 16384-byte tile masks, 512 i32 refund seeds, the coordinator's and
# construction.gd's 4-line manifests (4 i32 + 4 i64 each) and at most 4 x 7 i64 spec rows.
DECISION_0534_RECORD=(5*4+8)*1024
DECISION_0534_SCRATCH=2*16384+512*4+2*(4*4+4*8)+4*7*8
assert (DECISION_0534_RECORD,DECISION_0534_SCRATCH)==(28672,35136)
DECISION_0534_ADDED=DECISION_0534_RECORD+DECISION_0534_SCRATCH
# Decision 0536: the admitted return's charge (one I64 per Building row) folds into the Auxiliary
# payload row; the return scratch widens from 4 to RETURN_LINE_CAPACITY = 6 lines in the
# coordinator (keys, milli and spec rows) and construction.gd gains its own 6-line halved return.
DECISION_0536_RECORD=8*1024
DECISION_0536_SCRATCH=(2*4+2*8)+2*7*8+(6*4+6*8)
assert (DECISION_0536_RECORD,DECISION_0536_SCRATCH)==(8192,208)
assert DECISION_0534_SCRATCH+DECISION_0536_SCRATCH==2*16384+512*4+(6*4+6*8)+6*7*8+(4*4+4*8)+(6*4+6*8)
DECISION_0536_ADDED=DECISION_0536_RECORD+DECISION_0536_SCRATCH
# Decision 0537: DEMO-CONTAIN-R01 D6. demolition_work.gd's four I32 columns per Building row (the
# evacuation order's building ref and the removal work Job's ref) fold into the Auxiliary payload
# row and add no allocation row. Its scratch is borrowed: the hourly source check reuses the
# coordinator's decision 0534 footprint mask, seed buffer and decision 0145 pair buffer.
DECISION_0537_ADDED=4*4*1024
assert DECISION_0537_ADDED==16384
# Decision 1031: store_policy.gd implements §3's already-budgeted BuildingItemAllow (262144 B) and
# BuildingItemMinimum (2097152 B) and adds one I32 binding stamp per Building row (1024), folded
# into the Auxiliary payload row: no new allocation row.
DECISION_1031_ADDED=4*1024
assert DECISION_1031_ADDED==4096
# Decision 0996 (review R04, Brendan's 2026-10-02 ruling): households.gd binds each dependent row
# to the resident's WHOLE directory EntityRef, so it gains one I32[512] `resident_slot` column
# beside `resident_generation`. It folds into the same §3 DependentCare row and the Auxiliary
# payload allocation; no allocation row is added. The owner becomes 46352+2048=48400 bytes.
DECISION_0996_ADDED=4*512
assert DECISION_0996_ADDED==2048 and DECISION_0521_ADDED+DECISION_0996_ADDED==48400
# Decisions 1022/1023: task 06.4 H1/H2's haul slices. haul_planner.gd's admission record, four
# I32 and one I64 per reservation-pool Job key (8192), folds into the Auxiliary payload row; the
# cold-path scratch is one new allocation row: two 16384-byte tile masks, 512 i32 refund seeds,
# one 7 x i64 placement spec, one 5 x i64 claim record and a one-cell i32 seed in the planner,
# and haul_carry.gd's one 5 x i64 re-claim record.
DECISION_1023_RECORD=(4*4+8)*8192
DECISION_1023_SCRATCH=2*16384+512*4+7*8+5*8+1*4+5*8
assert (DECISION_1023_RECORD,DECISION_1023_SCRATCH)==(196608,34956)
DECISION_1023_ADDED=DECISION_1023_RECORD+DECISION_1023_SCRATCH
# Decision 0532 adds four allocation rows (34 -> 38); decision 0521 folds into the existing
# Auxiliary payload row and adds none; decision 0534 adds one (38 -> 39); decisions 0536, 0537, 1031 and 0996 add none;
# decision 1023 adds one (39 -> 40); decision 1053 folds into Auxiliary payload and adds none.
assert len(allocations)==48 and sum(allocations)==DECISION_0050_ROW_SUM+DECISION_0051_ADDED+DECISION_0053_ADDED+DECISION_0055_ADDED+DECISION_0054_ADDED+DECISION_0066_ADDED+DECISION_0080_ADDED+DECISION_0083_ADDED+DECISION_0085_ADDED+DECISION_0092_ADDED+DECISION_0095_ADDED+DECISION_0104_ADDED+DECISION_0109_ADDED+DECISION_0110_ADDED+DECISION_0114_ADDED+DECISION_0127_ADDED+DECISION_0130_ADDED+DECISION_0131_ADDED+DECISION_0138_REMOVED+DECISION_0145_ADDED+DECISION_0167_CLAIM_SLOT+DECISION_0169_ADDED+DECISION_0531_ANCHOR+DECISION_0532_ADDED+DECISION_0521_ADDED+DECISION_0534_ADDED+DECISION_0536_ADDED+DECISION_0537_ADDED+DECISION_1031_ADDED+DECISION_0996_ADDED+DECISION_1023_ADDED+DECISION_1053_ADDED+DECISION_1066_ADDED+DECISION_1068_ADDED+DECISION_1071_MUTABLE+DECISION_1072_MUTABLE+DECISION_1102_MUTABLE+LATER_UNDERGROUND_MUTABLE
payload=sum(allocations);reserve=8388608;candidate=payload-(3670016+2097152+262144+131072+55200+DECISION_0127_ADDED+DECISION_0169_ADDED);live=payload+reserve
assert payload==91571030
assert live==99959638 and candidate==85321337 and live+candidate==185280975
assert live==underground_pack['live_with_reserve_bytes']
assert f'Auxiliary payload sum = **{auxiliary} bytes**' in s
# A valid internal trail can still omit its final step. Require its endpoint to reach the
# independently summed allocation table; merge_gate.py separately checks every intervening row.
trail=s.split('| Step | Governing record |',1)[1].split('\n\n',1)[0]
trail_rows=[line.split('|') for line in trail.splitlines() if line.startswith('|')]
assert tuple(int(cell.strip()) for cell in trail_rows[-1][-3:-1])==(payload,live)
# The cursor row is four I32 columns over 512 rows; a fifth column or a capacity change fails here.
assert '| ResidentRouteCursor | request_row, route_generation, route_cell_index, owner_persistent_id | I32 | 4 | 4 | 512 | 8192 |' in s
assert f'| Scheduler event queue and control header | 1 | {SCHEDULER_TOTAL} | {SCHEDULER_TOTAL} |' in s
for label,value in [('Planned allocated payload',payload),('One live world plus reserve',live),('Headroom below decimal 100 MB',100000000-live),('Additional candidate mutable state',candidate),('Transactional peak plus same reserve',live+candidate),('Transactional headroom',100000000-live-candidate)]:
 assert f'| {label} | {value} |' in s,label
catalog=json.loads((r/'godot/data/catalog_ids.json').read_text())['domains']['ItemDefinition']
bindings={'resource': ['wood','stone','iron'],'forage':['berries','nuts','mushrooms','herb','roots'],'fish':['trout','dace','salmon','perch','carp','whitefish','herring','mackerel','mussel']}
actual={k:[catalog[n] for n in names] for k,names in bindings.items()}
# ECON-002's `excavated_earth` sorts between `dried_fruit` and `flax` and takes id 11, so EVERY
# item at id >= 11 shifted up by exactly one. berries(1), carp(5) and dace(8) are below it and did
# not move, which is the check that the shift is the ASCII sort and not a reshuffle. Previous pins,
# kept so the move is legible: resource [59,52,19] forage [1,35,32,15,39] fish [55,8,41,37,5,58,16,20,33].
# This is why ARCH-CAT-004 resolves items BY KEY at the binding boundary: a save carrying compiled
# ids as numbers would have been invalidated by adding one catalog row in the middle of the alphabet.
assert actual=={'resource':[60,53,20],'forage':[1,36,33,16,40],'fish':[56,8,42,38,5,59,17,21,34]}
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
report={'scope':'STATIC_SOURCE_ARITHMETIC_AND_DOCUMENT_LINK_REVIEW_NOT_RUNTIME_TESTS','status':'PASS','historical_ready07_revision':'16e1efc','field_rows':len(fields),'field_bytes':sum(fields),'allocation_rows':len(allocations),'payload_bytes':payload,'live_with_reserve_bytes':live,'two_world_peak_bytes':live+candidate,'catalog_bindings':actual,'synthetic_weather_boundary_ticks':ticks,'scheduler_status':'IMPLEMENTED_AND_LEDGERED_ADR0054','scheduler_record_bytes':SCHEDULER_RECORD,'scheduler_control_bytes':SCHEDULER_CONTROL,'scheduler_total_bytes':SCHEDULER_TOTAL,'scheduler_capacity':SCHEDULER_CAPACITY,'scheduler_normal_capacity':SCHEDULER_NORMAL,'checked_local_links':links,'files_reviewed':installed,'runtime_tests':'NOT_RUN','runtime_code_changed_by_this_check':False,'remaining_proposed_fields_in_existing_ledger':False,'source_sha256':{n:hashlib.sha256((r/n).read_bytes()).hexdigest() for n in ['docs/game_gdd.md','docs/systems_architecture.md','godot/data/catalog_ids.json','docs/movement_direction_amendment.md','godot/scripts/core/scheduler_events.gd']}}
report['room_projects_packed_bytes']=DECISION_1053_ADDED
report['canonical_declaration_bytes']=DECISION_0127_ADDED
report['excavation_packed_bytes']=CURRENT_EXCAVATION_PACKED
report['joint_underground_pack_bytes']=CURRENT_UNDERGROUND_MUTABLE
report['underground_pack_runtime_qualified']=underground_pack['runtime_qualified']
report['excavation_numeric_controls_and_transients']=DECISION_1066_CONTROLS+DECISION_1066_TRANSIENTS
report['gear_lot_index_and_restore_bytes']=DECISION_1068_ADDED
report['canonical_census']={'owners':len(registry_owners),'declared_fields':len(registry_fields),
                          'hashed_records':registry['record_count'],
                          'persisted_packed_fields':registry['packed_source_field_count'],
                          'key_utf8_bytes':registry_key_bytes}
for name in ['godot/scripts/core/room_projects.gd','godot/scripts/core/construction.gd',
             'godot/scripts/core/jobs.gd','godot/scripts/core/canonical_state_hash.gd',
             'godot/scripts/core/excavation_inventory.gd','godot/scripts/core/excavation_sites.gd',
             'godot/scripts/core/excavation_contract.gd','godot/scripts/core/gear.gd','tools/audit_registry_capacities.py',
             'docs/planning/canonical_state_registry.json','docs/validation/ready07_arithmetic.py']:
 report['source_sha256'][name]=hashlib.sha256((r/name).read_bytes()).hexdigest()
if args.output:
 args.output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['status','field_rows','allocation_rows','scheduler_total_bytes','checked_local_links','runtime_tests','payload_bytes','room_projects_packed_bytes','excavation_packed_bytes','canonical_declaration_bytes']}))
