extends "res://test/framework/test_case.gd"
const Injury := preload("res://scripts/core/injury.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Bridge := preload("res://scripts/core/save_owner_injury.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const MAX_I64: int = 9223372036854775807
const MIN_I64: int = -9223372036854775807 - 1
const KEYS: Array[String] = ["_present","_kind","_airless_episode","_exhaustion_latch",
	"_care_context_blocked","_severity","_rescuer_slot","_rescuer_generation",
	"_untreated_ticks","_care_progress_mwu","_last_incident_ordinal"]
const CODES: Array[StringName] = [&"COLUMN_FLAGS",&"COLUMN_KIND",&"COLUMN_FLAGS",&"COLUMN_FLAGS",
	&"COLUMN_FLAGS",&"COLUMN_SEVERITY",&"COLUMN_RESCUER_REF",&"COLUMN_RESCUER_REF",
	&"COLUMN_UNTREATED_TICKS",&"COLUMN_CARE_PROGRESS",&"COLUMN_INCIDENT_ORDINAL"]

func _empty() -> Array:
	"""Cleared source-owned defaults include a null rescuer slot rather than raw zero."""
	var c: Array = []
	for field: int in 11:
		var values: Variant = PackedByteArray() if field < 5 else (PackedInt32Array() if field < 8 else PackedInt64Array())
		values.resize(512)
		if field == 6: values.fill(-1)
		c.append(values)
	return c

func _copy(c: Array) -> Array:
	"""Duplicate every packed buffer, not merely the enclosing Array."""
	var copied: Array = []
	for values: Variant in c: copied.append(values.duplicate())
	return copied

func _put(c: Array, field: int, row: int, value: int) -> void:
	"""Explicit packed writeback for fixtures."""
	var values: Variant = c[field]
	values[row] = value
	c[field] = values

func _injured(c: Array, row: int) -> void:
	"""A valid minor incident with a positive ordinal and no assigned rescuer."""
	_put(c,0,row,1)
	_put(c,1,row,1)
	_put(c,5,row,1)
	_put(c,10,row,1)

func _bound(c: Array, row: int, slot: int = 0, generation: int = 1) -> void:
	"""Healthy present rows may bind a global Directory ref."""
	_put(c,0,row,1)
	_put(c,6,row,slot)
	_put(c,7,row,generation)

func _predicate(c: Array) -> StringName:
	"""All eleven canonical typed arguments, without diagnostic-order assumptions."""
	return Injury.columns_refusal(c[0],c[1],c[2],c[3],c[4],c[5],c[6],c[7],c[8],c[9],c[10])

func _frame(c: Array) -> Section.FramedOwner:
	"""All setters are asserted, including the three independent i64 columns."""
	var frame: Section.FramedOwner = Section.FramedOwner.new(6)
	for field: int in 11:
		var ok: bool
		if field < 5: ok = frame.set_u8(field,c[field])
		elif field < 8: ok = frame.set_i32(field,c[field])
		else: ok = frame.set_i64(field,c[field])
		assert_true(ok,"fixture setter%d" % field)
	return frame

func _held(frame: Section.FramedOwner, field: int) -> Variant:
	"""Read the right typed bucket for equality checks."""
	if field < 5: return frame.u8_column(field)
	if field < 8: return frame.i32_column(field)
	return frame.i64_column(field)

func _expect(c: Array, code: StringName) -> void:
	"""Exact result and every caller/frame buffer are checked for both validation paths."""
	var before: Array = _copy(c)
	var frame: Section.FramedOwner = _frame(c)
	assert_equal(_predicate(c),code,"static exact code")
	var result: Variant = Bridge.framed_refusal(frame)
	assert_equal(result.code,code,"bridge exact code")
	assert_equal(result.is_ok(),code == &"","success channel")
	if code == &"": assert_equal(result.detail,"","success detail")
	else:
		assert_true(result.detail.contains("Injury owner 6 "),"owner identity")
		assert_true(result.detail.contains(String(code)),"raw code")
	for field: int in 11:
		assert_true(c[field] == before[field],"caller unchanged")
		assert_true(_held(frame,field) == before[field],"frame unchanged")

func _from_owner(owner: Injury) -> Array:
	"""Public variant diagnostic remapped explicitly; absent rows use source-owned defaults."""
	var image: PackedInt64Array = bytes_to_var(owner.state_bytes())
	assert_equal(image.size(),1+image[0]*11,"public diagnostic extent")
	var c: Array = _empty()
	var mapping: Array[int] = [0,1,8,9,10,2,6,7,3,4,5]
	for i: int in image[0]:
		var cursor: int = 1+i*11
		var row: int = image[cursor]
		_put(c,0,row,1)
		for field: int in range(1,11): _put(c,field,row,image[cursor+mapping[field]])
	return c

func test_layout_cleared_defaults_and_full_i64_endpoints() -> void:
	"""No recipe ceiling, float narrowing or population-prefix restriction."""
	assert_equal(Schema.owner_version(6),1,"existing schema")
	for field: int in 11:
		assert_equal(Schema.field_key(6,field),KEYS[field],"key")
		assert_equal(Schema.field_type(6,field),0 if field < 5 else (2 if field < 8 else 4),"type")
		assert_equal(Schema.element_count(6,field),512,"extent")
	_expect(_empty(),&"")
	assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(6)).code,&"COLUMN_RESCUER_REF","raw zeros invalid")
	var c: Array = _empty()
	_injured(c,511)
	for field: int in [8,9,10]: _put(c,field,511,MAX_I64)
	_put(c,1,511,5)
	_put(c,5,511,2)
	_bound(c,511,352417,2147483647)
	_expect(c,&"")
	_put(c,9,511,9007199254740993)
	_expect(c,&"")

func test_every_physical_position_and_each_zero_accessor_witness() -> void:
	"""Each of eleven fields has its own malformed-value witness, including context2."""
	var c: Array = _empty()
	for row: int in 512:
		for field: int in 11:
			var bad: int = 6 if field == 1 else (2 if field < 5 else (-2 if field == 6 else -1))
			_put(c,field,row,bad)
			var before: Array = _copy(c)
			assert_equal(_predicate(c),CODES[field],"row%d field%d" % [row,field])
			assert_true(c == before,"all fields preserved")
			_put(c,field,row,-1 if field == 6 else 0)
	for field: int in 11:
		var one: Array = _empty()
		_put(one,field,511,6 if field == 1 else (2 if field < 5 else (-2 if field == 6 else -1)))
		_expect(one,CODES[field])
	_expect(_empty(),&"")

func test_severity_signs_references_and_accumulator_extrema() -> void:
	"""All signed lower bounds and exact global slot/null halves are covered."""
	for field: int in range(5,11):
		var c: Array = _empty()
		_put(c,field,511,MIN_I64 if field >= 8 else -2147483648)
		_expect(c,CODES[field])
	for value: int in [3,2147483647]:
		var c: Array = _empty()
		_put(c,5,511,value)
		_expect(c,&"COLUMN_SEVERITY")
	for ref: Vector2i in [Vector2i(-2,0),Vector2i(-1,1),Vector2i(0,0),Vector2i(352418,1),Vector2i(0,-1),Vector2i(2147483647,1)]:
		var c: Array = _empty()
		_put(c,0,511,1)
		_put(c,6,511,ref.x)
		_put(c,7,511,ref.y)
		_expect(c,&"COLUMN_RESCUER_REF")

func test_no_injury_history_free_rows_and_exact_pair_uniqueness() -> void:
	"""Healthy/stale bindings survive; no inactive residue or exact duplicate pair survives."""
	var c: Array = _empty()
	_bound(c,511,87552,7)
	for field: int in [2,3,4]: _put(c,field,511,1)
	_put(c,10,511,MAX_I64)
	_expect(c,&"")
	_bound(c,0,87552,8)
	_expect(c,&"")
	_put(c,7,0,7)
	_expect(c,&"COLUMN_RESCUER_DUPLICATE")
	for field: int in [1,5]:
		c = _empty()
		_put(c,0,511,1)
		_put(c,field,511,1)
		_expect(c,&"COLUMN_KIND_SEVERITY")
	for field: int in [8,9]:
		c = _empty()
		_put(c,0,511,1)
		_put(c,field,511,1)
		_expect(c,&"COLUMN_NO_INJURY")
	c = _empty()
	_injured(c,511)
	_put(c,10,511,0)
	_expect(c,&"COLUMN_INCIDENT_HISTORY")
	for field: int in [2,3]:
		c = _empty()
		_put(c,0,511,1)
		_put(c,field,511,1)
		_expect(c,&"COLUMN_INCIDENT_HISTORY")
	c = _empty()
	_put(c,0,511,1)
	_put(c,4,511,1)
	_expect(c,&"")
	for field: int in [1,2,3,4,5,6,7,8,9,10]:
		c = _empty()
		if field == 1 or field == 5 or field == 8 or field == 9:
			_injured(c,511)
			_put(c,0,511,0)
		elif field == 2 or field == 3: _put(c,10,511,1)
		elif field == 6 or field == 7:
			_put(c,6,511,0)
			_put(c,7,511,1)
		if field != 6: _put(c,field,511,1)
		# Each nondefault column is witnessed with only the supporting relationships it needs.
		_expect(c,&"COLUMN_INACTIVE")

func _fault(c: Array, gate: int, row: int) -> StringName:
	"""Earlier-gate-valid witnesses for each global gate."""
	var fields: Array[int] = [0,1,5,6,8,9,10]
	if gate < 7:
		var field: int = fields[gate]
		_put(c,field,row,2 if field == 0 else (6 if field == 1 else -2))
		return CODES[field]
	_put(c,0,row,1)
	if gate == 7:
		_put(c,1,row,1)
		return &"COLUMN_KIND_SEVERITY"
	if gate == 8:
		_put(c,8,row,1)
		return &"COLUMN_NO_INJURY"
	if gate == 9:
		_put(c,2,row,1)
		return &"COLUMN_INCIDENT_HISTORY"
	_put(c,0,row,0)
	_put(c,4,row,1)
	return &"COLUMN_INACTIVE"

func test_global_gate_priority_and_inactive_before_duplicate() -> void:
	"""Earlier gate on the tail wins; duplicate ordering uses separate present rows."""
	for gate: int in 10:
		var c: Array = _empty()
		var code: StringName = _fault(c,gate,511)
		_fault(c,gate+1,0)
		_expect(c,code)
	var c: Array = _empty()
	_bound(c,0,0,1)
	_bound(c,1,0,1)
	_put(c,4,511,1)
	_expect(c,&"COLUMN_INACTIVE")

func test_shapes_before_values_null_owner_and_typed_buckets() -> void:
	"""All11 shapes before indexing and every physical bucket cardinality."""
	for field: int in 11:
		for size: int in [0,511,513]:
			var c: Array = _empty()
			_put(c,0,0,2)
			var values: Variant = c[field]
			values.resize(size)
			c[field] = values
			var before: Array = _copy(c)
			assert_equal(_predicate(c),&"COLUMN_SHAPE","allshapes first")
			assert_true(c == before,"shape inputs unchanged")
			var frame: Section.FramedOwner = _frame(_empty())
			var index: int = Schema.storage_index(6,field)
			if field < 5: frame.u8_columns[index] = values
			elif field < 8: frame.i32_columns[index] = values
			else: frame.i64_columns[index] = values
			assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","framed shape")
	assert_equal(Bridge.framed_refusal(null).code,&"SAVE_COMPONENT_SHAPE","null")
	for owner: int in [-1,5,7,18]:
		assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(owner)).code,&"SAVE_COMPONENT_OWNER","wrong owner")
	for kind: int in 3:
		for extra: bool in [false,true]:
			var frame: Section.FramedOwner = _frame(_empty())
			if kind == 0:
				if extra: frame.u8_columns.append(PackedByteArray())
				else: frame.u8_columns.pop_back()
			elif kind == 1:
				if extra: frame.i32_columns.append(PackedInt32Array())
				else: frame.i32_columns.pop_back()
			else:
				if extra: frame.i64_columns.append(PackedInt64Array())
				else: frame.i64_columns.pop_back()
			assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","bucket count")

func _spawn(injury: Injury, needs: Needs, row: int, injured: bool = true) -> void:
	"""Public production lifecycle for boundary fixtures."""
	assert_true(needs.spawn(row,Needs.SIZE_SMALL).ok,"needs spawn")
	assert_true(injury.spawn(row).ok,"injury row spawn")
	if injured: assert_true(injury.apply_incident(row,1,1,0,1,needs).ok,"incident")

func _seed_ticks(injury: Injury, low: int, high: int) -> void:
	"""Test-only single-column fault injection; never claim public history or bulk restore."""
	var ticks: PackedInt64Array = PackedInt64Array()
	ticks.resize(512)
	ticks[0] = low
	ticks[511] = high
	injury.set("_untreated_ticks",ticks)
	assert_equal(injury.untreated_ticks_of(0).value,low,"seed verified by public reader")
	assert_equal(injury.untreated_ticks_of(511).value,high,"tail seed verified publicly")

func test_actual_overflow_refuses_the_entire_sweep_and_reports_first_row() -> void:
	"""No earlier patient or Needs field changes when a later living patient overflows."""
	for first: int in [0,511]:
		var injury: Injury = Injury.new()
		var needs: Needs = Needs.new()
		_spawn(injury,needs,0)
		_spawn(injury,needs,511)
		_seed_ticks(injury,MAX_I64 if first == 0 else 7,MAX_I64)
		_expect(_from_owner(injury),&"")
		var before: PackedByteArray = injury.state_bytes()
		var needs_before: PackedByteArray = needs.state_bytes()
		var result: Needs.OpResult = injury.tick_all(needs)
		assert_false(result.ok,"whole sweep refuses")
		assert_equal(result.error,&"OVERFLOW","exact code")
		assert_equal(result.value,0,"refused progress")
		assert_equal(injury.last_refused_slot(),first,"first ascending blocked row")
		assert_equal(injury.state_bytes(),before,"all Injury data unchanged")
		assert_equal(needs.state_bytes(),needs_before,"all Needs data unchanged")
		result = injury.tick_all(null)
		assert_equal(result.error,&"NEEDS_REFUSED","null collaborator")
		assert_equal(injury.last_refused_slot(),-1,"null path clears refusal diagnostic")
		assert_equal(injury.state_bytes(),before,"null refusal unchanged")

func test_max_minus_one_advances_once_and_dead_or_uninjured_rows_are_skipped() -> void:
	"""Boundary refusal occurs on the next eligible tick, with original skip semantics."""
	var injury: Injury = Injury.new()
	var needs: Needs = Needs.new()
	_spawn(injury,needs,0)
	_spawn(injury,needs,511)
	_seed_ticks(injury,7,MAX_I64-1)
	var needs_before: PackedByteArray = needs.state_bytes()
	var result: Needs.OpResult = injury.tick_all(needs)
	assert_true(result.ok,"last valid increment")
	assert_equal(result.value,2,"two advanced patients")
	assert_equal(injury.untreated_ticks_of(0).value,8,"earlier patient advances")
	assert_equal(injury.untreated_ticks_of(511).value,MAX_I64,"maximum retained exactly")
	assert_equal(needs.state_bytes(),needs_before,"no second health rate")
	var before: PackedByteArray = injury.state_bytes()
	assert_equal(injury.tick_all(needs).error,&"OVERFLOW","next tick refuses")
	assert_equal(injury.state_bytes(),before,"no partial next tick")
	assert_true(needs.apply_health_event(511,-100).ok,"tail patient dies")
	assert_true(injury.tick_all(needs).ok,"dead maximum skipped")
	assert_equal(injury.untreated_ticks_of(511).value,MAX_I64,"dead retained time")
	assert_equal(injury.untreated_ticks_of(0).value,9,"living patient continues")
	assert_equal(injury.last_refused_slot(),-1,"success resets diagnostic")
	var healthy: Injury = Injury.new()
	var healthy_needs: Needs = Needs.new()
	_spawn(healthy,healthy_needs,0)
	_spawn(healthy,healthy_needs,511,false)
	# This deliberately noncanonical no-injury MAX fixture tests only the runtime skip filter.
	_seed_ticks(healthy,0,MAX_I64)
	assert_true(healthy.tick_all(healthy_needs).ok,"no-injury counter skipped")
	assert_equal(healthy.untreated_ticks_of(511).value,MAX_I64,"skip does not repair counter")

func test_public_care_treatment_latches_and_stale_healthy_rescuer_history() -> void:
	"""Public producer history and diagnostic remap, with no private capture."""
	var injury: Injury = Injury.new()
	var needs: Needs = Needs.new()
	var directory: Directory = Directory.new()
	_spawn(injury,needs,511,false)
	var rescuer: Vector2i = directory.create(Directory.KIND_RESIDENT)
	assert_true(injury.set_rescuer(511,rescuer,directory,needs).ok,"healthy rescue binding")
	_expect(_from_owner(injury),&"")
	assert_true(directory.destroy(rescuer),"rescuer leaves")
	assert_true(injury.has_rescuer(511),"stale history retained")
	assert_false(injury.rescuer_is_live(511,directory),"stale liveness fails")
	_expect(_from_owner(injury),&"")
	assert_true(injury.begin_airless_episode(511,1,needs).ok,"airless incident")
	assert_true(injury.apply_exhaustion_incident(511,2,needs).ok,"exhaustion incident")
	assert_true(injury.add_care_work(511,MAX_I64,needs).ok,"full care domain")
	var before: PackedByteArray = injury.state_bytes()
	assert_equal(injury.add_care_work(511,1,needs).error,&"OVERFLOW","existing care overflow")
	assert_equal(injury.state_bytes(),before,"care overflow preserves state")
	_expect(_from_owner(injury),&"")
	assert_true(injury.complete_treatment(511,60000,needs).ok,"treatment")
	assert_equal(injury.last_incident_ordinal_of(511).value,2,"ordinal retained")
	assert_true(injury.airless_episode_active(511),"airless retained")
	assert_true(injury.exhaustion_latched(511),"exhaustion retained")
	assert_equal(injury.care_progress_mwu_of(511).value,0,"care cleared")
	assert_true(injury.set_care_context_blocked(511,true).ok,"healthy blocked context")
	_expect(_from_owner(injury),&"")
	assert_true(injury.apply_incident(511,1,1,0,MAX_I64,needs).ok,"max ordinal")
	before = injury.state_bytes()
	var needs_before: PackedByteArray = needs.state_bytes()
	_expect(_from_owner(injury),&"")
	var bad: Array = _from_owner(injury)
	_put(bad,9,511,-1)
	_expect(bad,&"COLUMN_CARE_PROGRESS")
	assert_equal(injury.state_bytes(),before,"static/bridge never touch owner")
	assert_equal(needs.state_bytes(),needs_before,"static/bridge never touch Needs")
	assert_equal(injury.present_count(),1,"present count preserved")
	assert_equal(injury.injured_count(),1,"injured count preserved")
	assert_true(injury.despawn(511).ok,"despawn")
	_expect(_from_owner(injury),&"")
