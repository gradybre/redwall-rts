from pathlib import Path
import json
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');e=r/'docs/validation/evidence/movement-validation-planning-2026-09-20';j=json.loads((e/'frozen-witnesses.json').read_text())
s='''extends "res://test/framework/test_case.gd"
const Owner := preload("res://scripts/core/movement.gd")
const Bridge := preload("res://scripts/core/save_owner_movement.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
'''
s+='const FIELDS: Array[String] = '+json.dumps(j['fields'])+'\nconst CASES: Array = [\n'+',\n'.join('\t'+json.dumps([c['name'],c['base'],c['changes'],c['code']]) for c in j['cases'])+'\n]\n'
s+='''
func _put(c: Owner.Columns, field: int, row: int, value: int) -> void:
	var held: PackedInt32Array = c.get(FIELDS[field])
	held[row] = value
	c.set(FIELDS[field],held)
func _snapshot(c: Owner.Columns) -> Array:
	var out: Array = []
	for key: String in FIELDS: out.append(c.get(key).duplicate())
	return out
func _frame(c: Owner.Columns) -> Section.FramedOwner:
	var f: Section.FramedOwner = Section.FramedOwner.new(8)
	for field: int in 16: assert(f.set_i32(field,c.get(FIELDS[field]).duplicate()))
	return f
func _fill(c: Owner.Columns, row: int, name: String) -> void:
	if name == "clear": return
	c.speed_u_per_s[row] = 3277
	c.grid_cell[row] = 0
	if name == "stopped": return
	c.movement_phase[row] = {"travel":1,"arrived":2,"one-cell-arrived":2,"lost":3,"profile-stale":4,"contact-stale":5}[name]
	c.grid_next[row] = 1 if name == "travel" else -1
	if name == "one-cell-arrived": return
	c.next_x[row] = 256 if name == "arrived" else 768
	c.next_z[row] = 256
func _image(name: String) -> Owner.Columns:
	var c: Owner.Columns = Owner.Columns.new()
	_fill(c,511,name)
	return c
func _expect(c: Owner.Columns, code: StringName, label: String) -> void:
	var before: Array = _snapshot(c)
	var f: Section.FramedOwner = _frame(c)
	assert_equal(Owner.columns_refusal(c),code,label+" pure")
	var actual: Variant = Bridge.framed_refusal(f)
	assert_equal(actual.code,code,label+" bridge")
	assert_equal(actual.is_ok(),code == &"",label+" success")
	if code == &"": assert_equal(actual.detail,"",label+" empty success detail")
	else:
		assert_true(actual.detail.contains("Movement owner 8 "),label+" owner detail")
		assert_true(actual.detail.contains(String(code)),label+" raw code detail")
	for field: int in 16:
		assert_true(c.get(FIELDS[field]) == before[field],label+" input unchanged")
		assert_true(f.i32_column(field) == before[field],label+" frame unchanged")
func test_layout_defaults_and_conditional_memory() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	_expect(c,&"","clear")
	assert_equal(Schema.owner_version(8),1,"section4 version")
	assert_equal(Schema.primary_count(8),512,"primary")
	assert_equal(Schema.child_extent_count(8),0,"child count")
	assert_equal(Schema.field_count(8),16,"fields")
	var payload: int = 0
	for field: int in 16:
		assert_equal(Schema.field_key(8,field),"_"+FIELDS[field],"key")
		assert_equal(Schema.field_type(8,field),2,"i32 type")
		assert_equal(Schema.element_count(8,field),512,"extent")
		assert_equal(c.get(FIELDS[field]).count(-1 if field in [11,12] else 0),512,"clear default")
		payload += 512*4
	assert_equal(payload,32768,"value bytes")
	assert_equal(2*payload,65536,"conservative packed arithmetic, not RSS")
func test_frozen_domains_terminal_history_and_projection_witnesses() -> void:
	for item: Array in CASES:
		var c: Owner.Columns = _image(item[1])
		for change: Array in item[2]: _put(c,FIELDS.find(change[0]),int(change[1]),int(change[2]))
		_expect(c,StringName(item[3]),item[0])
func test_null_all_extents_and_bucket_shapes() -> void:
	assert_equal(Owner.columns_refusal(null),&"COLUMN_SHAPE","pure null")
	assert_equal(Bridge.framed_refusal(null).code,Section.REFUSE_SHAPE,"bridge null")
	assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(7)).code,Section.REFUSE_OWNER,"wrong owner")
	for field: int in 16:
		for count: int in [0,511,513]:
			var c: Owner.Columns = Owner.Columns.new()
			var values: PackedInt32Array = c.get(FIELDS[field]).duplicate()
			values.resize(count)
			c.set(FIELDS[field],values)
			if field == 14 and count == 0: c.correction_x[0] = 1
			else: c.movement_phase[0] = 6
			var before: Array = _snapshot(c)
			assert_equal(Owner.columns_refusal(c),&"COLUMN_SHAPE","shape before malformed row")
			for key: int in 16: assert_true(c.get(FIELDS[key]) == before[key],"shape input unchanged")
	for bucket: int in 3:
		for delta: int in [-1,1]:
			if bucket != 1 and delta == -1: continue
			var f: Section.FramedOwner = _frame(Owner.Columns.new())
			if bucket == 0: f.u8_columns.resize(f.u8_columns.size()+delta)
			elif bucket == 1: f.i32_columns.resize(f.i32_columns.size()+delta)
			else: f.i64_columns.resize(f.i64_columns.size()+delta)
			var expected: Variant = Section.owner_shape_refusal(f)
			var actual: Variant = Bridge.framed_refusal(f)
			assert_equal(actual.code,expected.code,"shape forwarded")
			assert_equal(actual.detail,expected.detail,"shape detail forwarded")
			assert_false(actual.is_ok(),"malformed bucket")
func test_every_field_at_every_physical_row() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	var before: Array = _snapshot(c)
	var bad: Array[int] = [1,1,420,420,1,1,1,1,1,1,1,-2,-2,1,6,1]
	var codes: Array[StringName] = [&"COLUMN_VELOCITY",&"COLUMN_VELOCITY",&"COLUMN_REMAINDER",&"COLUMN_REMAINDER",&"COLUMN_TARGET",&"COLUMN_TARGET",&"COLUMN_RESERVED",&"COLUMN_RESERVED",&"COLUMN_RESERVED",&"COLUMN_RESERVED",&"COLUMN_RESERVED",&"COLUMN_CELL",&"COLUMN_CELL",&"COLUMN_SPEED",&"COLUMN_PHASE",&"COLUMN_RESERVED"]
	for field: int in 16:
		for row: int in 512:
			_put(c,field,row,bad[field])
			assert_equal(Owner.columns_refusal(c),codes[field],"physical field%d row%d" % [field,row])
			assert_equal(int(c.get(FIELDS[field])[row]),bad[field],"fault preserved")
			if row == 0 or row == 511: _expect(c,codes[field],"bridge edges")
			_put(c,field,row,-1 if field in [11,12] else 0)
	for field: int in 16: assert_true(c.get(FIELDS[field]) == before[field],"all bytes restored")
	_expect(c,&"","restored clear")
func test_full_capacity_mixed_phase_and_retained_history() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	var kinds: Array[String] = ["clear","stopped","travel","arrived","one-cell-arrived","lost","profile-stale","contact-stale"]
	for row: int in 512:
		_fill(c,row,kinds[row%8])
		if c.movement_phase[row] != 0:
			c.remainder_x[row] = 419
			c.remainder_z[row] = 419
		if c.movement_phase[row] == 2:
			c.vx[row] = 110
			c.vz[row] = -110
	_expect(c,&"","512 mixed rows, with terminal history")
func test_row_priority_and_target_before_state() -> void:
	var c: Owner.Columns = _image("stopped")
	c.next_x[511] = 257
	c.next_z[511] = 256
	c.grid_next[511] = 0
	_expect(c,&"COLUMN_TARGET","malformed target before idle relation")
	c = _image("clear")
	c.remainder_x[0] = 420
	c.correction_z[511] = 1
	_expect(c,&"COLUMN_REMAINDER","earlier row before later reserved")
'''
(e/'parent-test-draft.gd').write_text(s)
reg=(e/'readmission-regression-probe.gd').read_text()
reg+='''
func test_replacement_preserves_other_travellers_and_first_admission() -> void:
	var cell: int = _cell(ANCHOR_X,ANCHOR_Z)
	var goal: int = _cell(ANCHOR_X+20,ANCHOR_Z)
	var first: Vector2i = _spawn_at(&"mouse",cell)
	var second: Vector2i = _spawn_at(&"mouse",cell)
	var request: int = _route_between(cell,goal)
	assert_true(_begin(first,request,goal,&"mouse"),"first row admission")
	assert_equal(_movement.travelling_count(),1,"nontravelling admission adds one")
	assert_true(_begin(second,request,goal,&"mouse"),"second row admission")
	assert_equal(_movement.travelling_count(),2,"two travelling rows")
	assert_true(_begin(first,request,goal,&"mouse"),"replace first")
	assert_equal(_movement.travelling_count(),2,"replacement preserves other contribution")
	assert_true(_movement.stop(first),"stop first")
	assert_equal(_movement.travelling_count(),1,"second remains")
	assert_equal(_movement.motion_phase(second),MovementScript.MOTION_TRAVELLING,"second still travels")
	assert_true(_movement.stop(second),"stop second")
	assert_equal(_movement.travelling_count(),0,"all stopped")
func test_rejected_replacement_preserves_cursor_fraction_and_count() -> void:
	var cell: int = _cell(ANCHOR_X,ANCHOR_Z)
	var goal: int = _cell(ANCHOR_X+20,ANCHOR_Z)
	var mouse: Vector2i = _spawn_at(&"mouse",cell)
	var request: int = _route_between(cell,goal)
	assert_true(_begin(mouse,request,goal,&"mouse"),"first admission")
	_movement.advance_tick(1)
	var old_cursor: int = _movement.route_index_of(mouse)
	var old_x: int = _movement.remainder_x_of(mouse)
	var old_z: int = _movement.remainder_z_of(mouse)
	var old_pose: int = _x_of(mouse)
	assert_true(old_x != 0,"fraction witness nonzero")
	assert_false(_begin(mouse,-1,goal,&"mouse"),"invalid replacement refuses")
	assert_equal(_movement.travelling_count(),1,"refusal count unchanged")
	assert_equal(_movement.motion_phase(mouse),MovementScript.MOTION_TRAVELLING,"refusal phase unchanged")
	assert_equal(_movement.route_index_of(mouse),old_cursor,"refusal cursor unchanged")
	assert_equal(_movement.remainder_x_of(mouse),old_x,"refusal X fraction unchanged")
	assert_equal(_movement.remainder_z_of(mouse),old_z,"refusal Z fraction unchanged")
	assert_equal(_x_of(mouse),old_pose,"refusal pose unchanged")
	assert_true(_movement.stop(mouse),"original journey still stops")
	assert_equal(_movement.travelling_count(),0,"stop removes original contribution")
'''
# Use the actual existing public accessor and tick signature, checked separately before execution.
(e/'parent-regression-draft.gd').write_text(reg)
print('Movement drafts:6 pure tests,5 public regressions. Runtime unverified.')
