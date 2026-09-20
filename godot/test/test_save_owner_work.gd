extends "res://test/framework/test_case.gd"
const Work := preload("res://scripts/core/work.gd")
const Bridge := preload("res://scripts/core/save_owner_work.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const Fixture := preload("res://test/test_work.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const KEYS: Array[String] = ["_potential_remainder","_xp_remainder","_memory_total",
	"_wear_remainder","_tool_lot_slot","_tool_lot_generation","_tool_job_slot",
	"_tool_job_generation","_tool_broken"]

func _empty() -> Array:
	"""Canonical null refs differ from a constructor's raw allzero wire image."""
	var c: Array = []
	for field: int in 9:
		var values: Variant = PackedByteArray() if field == 8 else PackedInt32Array()
		values.resize(6144 if field == 1 else 512)
		if field == 4 or field == 6: values.fill(-1)
		c.append(values)
	return c

func _put(c: Array, field: int, row: int, value: int) -> void:
	"""Explicit packed writeback avoids outer-container copy ambiguity."""
	var values: Variant = c[field]
	values[row] = value
	c[field] = values

func _bound(c: Array, row: int) -> void:
	"""Both full typed-store references, not Directory identities."""
	_put(c,4,row,0)
	_put(c,5,row,1)
	_put(c,6,row,0)
	_put(c,7,row,1)

func _predicate(c: Array) -> StringName:
	"""Canonical XP precedes memory, unlike state_bytes diagnostics."""
	return Work.columns_refusal(c[0],c[1],c[2],c[3],c[4],c[5],c[6],c[7],c[8])

func _frame(c: Array) -> Section.FramedOwner:
	"""Assign every canonical typed field; no ignored fixture setter failures."""
	var frame: Section.FramedOwner = Section.FramedOwner.new(16)
	for field: int in 9:
		var copied: bool = frame.set_u8(field,c[field]) if field == 8 else frame.set_i32(field,c[field])
		assert_true(copied,"fixture setter%d" % field)
	return frame

func _expect(c: Array, code: StringName) -> void:
	"""Both refusal channels and every caller/frame buffer remain exact."""
	var before: Array = []
	for values: Variant in c: before.append(values.duplicate())
	var frame: Section.FramedOwner = _frame(c)
	assert_equal(_predicate(c),code,"static exact code")
	var result: Variant = Bridge.framed_refusal(frame)
	assert_equal(result.code,code,"framed exact code")
	assert_equal(result.is_ok(),code == &"","success channel")
	if code == &"": assert_equal(result.detail,"","empty success detail")
	else:
		assert_true(result.detail.contains("Work owner 16 "),"owner identity")
		assert_true(result.detail.contains(String(code)),"raw code")
	for field: int in 9:
		assert_true(c[field] == before[field],"caller preserved")
		var held: Variant = frame.u8_column(field) if field == 8 else frame.i32_column(field)
		assert_true(held == before[field],"frame preserved")

func _dispose_fixture(f: Fixture) -> void:
	"""After assertions, release the test's Inventory/Gear ownership cycle via public APIs."""
	f._inventory.clear()
	assert_true(f._inventory.set_equipment_authority(null).ok,"fixture unbinds equipment authority")
	f.after_each()

func _from_owner(owner: Work) -> Array:
	"""Public equality diagnostic, explicitly remapped; this is not a save decoder."""
	var bytes: PackedByteArray = owner.state_bytes()
	assert_equal(bytes.size(),39424,"actual diagnostic byte extent")
	var c: Array = _empty()
	c[0] = bytes.slice(0,2048).to_int32_array()
	c[1] = bytes.slice(4096,28672).to_int32_array()
	c[2] = bytes.slice(2048,4096).to_int32_array()
	for field: int in range(3,8):
		var start: int = 28672+(field-3)*2048
		c[field] = bytes.slice(start,start+2048).to_int32_array()
	c[8] = bytes.slice(38912,39424)
	return c

func test_layout_version_and_null_defaults() -> void:
	"""Owner16 was already version2; raw zeros are not well-formed refs."""
	assert_equal(Schema.owner_version(16),2,"existing version TWO")
	for field: int in 9:
		assert_equal(Schema.field_key(16,field),KEYS[field],"canonical key")
		assert_equal(Schema.field_type(16,field),0 if field == 8 else 2,"canonical type")
		assert_equal(Schema.element_count(16,field),6144 if field == 1 else 512,"physical extent")
	_expect(_empty(),&"")
	assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(16)).code,&"COLUMN_TOOL_LOT_REF","raw zero frame refuses")

func test_endpoints_memory_and_retained_unbound_carries() -> void:
	"""Carry endpoints survive without bindings and memory keeps its full signed range."""
	var c: Array = _empty()
	_put(c,0,511,999)
	_put(c,1,6143,999)
	_put(c,3,511,9999)
	_put(c,2,510,2147483647)
	_put(c,2,511,-2147483648)
	_expect(c,&"")
	_bound(c,511)
	_put(c,4,511,16383)
	_put(c,5,511,2147483647)
	_put(c,6,511,8191)
	_put(c,7,511,2147483647)
	_put(c,8,511,1)
	_expect(c,&"")
	for row: int in 512:
		_put(c,2,row,-2147483648 if row % 2 == 0 else 2147483647)
		assert_equal(_predicate(c),&"","every physical memory row remains unrestricted")
	_expect(c,&"")

func test_every_physical_domain_and_reserved_skill_position() -> void:
	"""No population-prefix shortcut: all512 rows and all6144 XP entries are checked."""
	var c: Array = _empty()
	for row: int in 512:
		for field: int in [0,3,4,5,6,7,8]:
			var bad: int = 2 if field == 8 else (-2 if field == 4 or field == 6 else -1)
			var code: StringName = &"COLUMN_POTENTIAL_REMAINDER"
			if field == 3: code = &"COLUMN_WEAR_REMAINDER"
			elif field == 4 or field == 5: code = &"COLUMN_TOOL_LOT_REF"
			elif field == 6 or field == 7: code = &"COLUMN_TOOL_JOB_REF"
			elif field == 8: code = &"COLUMN_BROKEN_FLAG"
			_put(c,field,row,bad)
			assert_equal(_predicate(c),code,"full row%d field%d" % [row,field])
			_put(c,field,row,-1 if field == 4 or field == 6 else 0)
		_put(c,1,row*12+3,1)
		assert_equal(_predicate(c),&"COLUMN_RESERVED_XP","each retired skill")
		_put(c,1,row*12+3,0)
	for index: int in 6144:
		_put(c,1,index,1000)
		assert_equal(_predicate(c),&"COLUMN_XP_REMAINDER","every XP entry")
		_put(c,1,index,0)
	_expect(c,&"")

func test_eight_zero_argument_and_nine_value_clause_witnesses() -> void:
	"""Memory is deliberately excluded: zero substitution is semantically equivalent."""
	var c: Array
	for field: int in [0,1,3,5,7,8]:
		c = _empty()
		_put(c,field,0,2 if field == 8 else -1)
		var code: StringName = &"COLUMN_POTENTIAL_REMAINDER"
		if field == 1: code = &"COLUMN_XP_REMAINDER"
		elif field == 3: code = &"COLUMN_WEAR_REMAINDER"
		elif field == 5: code = &"COLUMN_TOOL_LOT_REF"
		elif field == 7: code = &"COLUMN_TOOL_JOB_REF"
		elif field == 8: code = &"COLUMN_BROKEN_FLAG"
		_expect(c,code)
	# Replacing either canonical null-slot accessor with zeros breaks this accepted image.
	_expect(_empty(),&"")
	c = _empty()
	_put(c,1,3,1)
	_expect(c,&"COLUMN_RESERVED_XP")
	c = _empty()
	_put(c,4,511,1)
	_put(c,5,511,1)
	_expect(c,&"COLUMN_TOOL_BINDING")
	c = _empty()
	_put(c,6,0,1)
	_put(c,7,0,1)
	_expect(c,&"COLUMN_TOOL_BINDING")
	c = _empty()
	_put(c,8,511,1)
	_expect(c,&"COLUMN_TOOL_BINDING")

func test_numeric_upper_limits_and_typed_reference_halves() -> void:
	"""Both signed ends and exact typed-store bounds differ from Directory capacity."""
	for field: int in [0,1,3]:
		for value: int in [-2147483648,2147483647,10000 if field == 3 else 1000]:
			var c: Array = _empty()
			_put(c,field,511,value)
			_expect(c,&"COLUMN_POTENTIAL_REMAINDER" if field == 0 else (&"COLUMN_XP_REMAINDER" if field == 1 else &"COLUMN_WEAR_REMAINDER"))
	for pair: int in 2:
		var slot_field: int = 4+pair*2
		var limit: int = 16384 if pair == 0 else 8192
		for ref: Vector2i in [Vector2i(-2,0),Vector2i(-1,1),Vector2i(0,0),Vector2i(limit,1),Vector2i(0,-1),Vector2i(-2147483648,1),Vector2i(2147483647,1)]:
			var c: Array = _empty()
			_bound(c,511)
			_put(c,slot_field,511,ref.x)
			_put(c,slot_field+1,511,ref.y)
			_expect(c,&"COLUMN_TOOL_LOT_REF" if pair == 0 else &"COLUMN_TOOL_JOB_REF")

func test_global_gate_precedence_at_opposite_rows() -> void:
	"""A later-row earlier gate wins over an earlier-row later gate."""
	var c: Array = _empty()
	_put(c,0,511,-1)
	_put(c,1,0,1000)
	_expect(c,&"COLUMN_POTENTIAL_REMAINDER")
	c = _empty()
	_put(c,1,6143,1000)
	_put(c,1,3,1)
	_expect(c,&"COLUMN_XP_REMAINDER")
	c = _empty()
	_put(c,1,511*12+3,1)
	_put(c,3,0,-1)
	_expect(c,&"COLUMN_RESERVED_XP")
	c = _empty()
	_put(c,3,511,-1)
	_put(c,8,0,2)
	_expect(c,&"COLUMN_WEAR_REMAINDER")
	c = _empty()
	_put(c,8,511,2)
	_put(c,4,0,-2)
	_expect(c,&"COLUMN_BROKEN_FLAG")
	c = _empty()
	_put(c,4,511,-2)
	_put(c,6,0,-2)
	_expect(c,&"COLUMN_TOOL_LOT_REF")
	c = _empty()
	_put(c,6,511,-2)
	_put(c,4,0,0)
	_put(c,5,0,1)
	_expect(c,&"COLUMN_TOOL_JOB_REF")

func test_all_shapes_and_direct_memory_extent_before_values() -> void:
	"""Memory-shape omission must be observed directly, before framed shape rejects it."""
	for field: int in 9:
		var extent: int = 6144 if field == 1 else 512
		for size: int in [0,extent-1,extent+1]:
			var c: Array = _empty()
			_put(c,0,0,-1)
			var values: Variant = c[field]
			values.resize(size)
			c[field] = values
			assert_equal(_predicate(c),&"COLUMN_SHAPE","static allshapes beforevalues")
			var frame: Section.FramedOwner = _frame(_empty())
			var index: int = Schema.storage_index(16,field)
			if field == 8: frame.u8_columns[index] = values
			else: frame.i32_columns[index] = values
			assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","framed shape")
	var memory_only: Array = _empty()
	var memory: PackedInt32Array = memory_only[2]
	memory.resize(511)
	memory_only[2] = memory
	assert_equal(_predicate(memory_only),&"COLUMN_SHAPE","direct memory omission witness otherwise valid")

func test_null_wrong_owner_and_bucket_cardinality() -> void:
	"""No malformed caller bucket bypasses the physical framing guard."""
	assert_equal(Bridge.framed_refusal(null).code,&"SAVE_COMPONENT_SHAPE","null")
	for owner: int in [-1,15,17,18]:
		assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(owner)).code,&"SAVE_COMPONENT_OWNER","owner")
	for variant: int in 5:
		var frame: Section.FramedOwner = _frame(_empty())
		if variant == 0: frame.i32_columns.pop_back()
		elif variant == 1: frame.u8_columns.pop_back()
		elif variant == 2: frame.i32_columns.append(PackedInt32Array())
		elif variant == 3: frame.u8_columns.append(PackedByteArray())
		else: frame.i64_columns.append(PackedInt64Array())
		assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","bucket mismatch")

func test_public_fractional_release_and_stale_job_history() -> void:
	"""Real owner bytes, carries, bound count and stale refusal survive pure validation."""
	var f: Fixture = Fixture.new()
	f.before_each()
	f._use_gear()
	var row: int = f._fractional_rate_worker()
	var first: int = f._worked_job(row,1000000)
	var lot: Vector2i = f._claimed_tool(row)
	assert_true(f._work.tick_solo(first).ok,"real fractional work")
	assert_true(f._work.set_memory_total(511,-2147483648).ok,"idle physical-tail memory")
	var c: Array = _from_owner(f._work)
	assert_equal(c[0][row],800,"work carry")
	assert_equal(c[1][row*12+Jobs.JOB_KIND_KEEP],40,"canonical XP remap")
	assert_equal(c[2][511],-2147483648,"canonical memory remap")
	assert_equal(c[3][row],40,"wear carry")
	var before: PackedByteArray = f._work.state_bytes()
	_expect(c,&"")
	assert_equal(f._work.state_bytes(),before,"live Work not touched")
	assert_equal(f._work.bound_tool_count(),1,"derived count untouched")
	assert_true(f._work.release_tool_claim(row).ok,"release")
	_expect(_from_owner(f._work),&"")
	assert_equal(f._work.wear_remainder_of(row).value,40,"unbound carry persists")
	assert_equal(f._work.bound_tool_count(),0,"release count correct")
	assert_true(f._work.claim_tool_for_work(row,lot).ok,"reclaim")
	assert_true(f._jobs.release_worker(row).ok,"change current job")
	var next: int = f._worked_job(row,1000000)
	var outcome: Work.TickResult = f._work.tick_solo(next)
	assert_equal(outcome.error,Work.REFUSE_TOOL_CLAIM_STALE,"real stale history")
	before = f._work.state_bytes()
	_expect(_from_owner(f._work),&"")
	assert_equal(f._work.state_bytes(),before,"stale history preserved")
	assert_equal(f._work.bound_tool_count(),1,"stale binding counted")
	assert_equal(outcome.error,Work.REFUSE_TOOL_CLAIM_STALE,"retained result diagnostic unchanged")
	var invalid: Array = _from_owner(f._work)
	_put(invalid,0,511,-1)
	_expect(invalid,&"COLUMN_POTENTIAL_REMAINDER")
	assert_equal(f._work.state_bytes(),before,"refusal does not write live owner")
	assert_true(f.failures.is_empty(),"all supporting real fixture assertions pass: %s" % f.failures)
	_dispose_fixture(f)

func test_public_broken_tool_binding_remains_valid_history() -> void:
	"""The existing public break fixture leaves a real broken claimed tool."""
	var f: Fixture = Fixture.new()
	f.before_each()
	f.test_a_broken_tool_stops_the_contributor_rather_than_working_for_free()
	assert_true(f.failures.is_empty(),"all existing break fixture assertions pass: %s" % f.failures)
	assert_true(f._work.tool_is_broken(0),"actual broken flag")
	var before: PackedByteArray = f._work.state_bytes()
	_expect(_from_owner(f._work),&"")
	assert_equal(f._work.state_bytes(),before,"broken history unchanged")
	assert_equal(f._work.bound_tool_count(),1,"broken binding count unchanged")
	_dispose_fixture(f)
