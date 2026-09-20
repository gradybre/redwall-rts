extends "res://test/framework/test_case.gd"
const Nodes := preload("res://scripts/core/resource_nodes.gd")
const Bridge := preload("res://scripts/core/save_owner_resource_nodes.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const I64_MAX: int = 9223372036854775807
const I64_MIN: int = -9223372036854775807 - 1
const WIDE: int = 9007199254740993
const KEYS: Array[String] = ["_present","_resource_id","_quantity_milli","_capacity_milli",
	"_regrow_days","_planted_day","_exhausted","_tile","_ref_slot","_ref_generation"]
const CODES: Array[StringName] = [&"COLUMN_PRESENT_FLAG",&"COLUMN_RESOURCE_ID",&"COLUMN_QUANTITY",
	&"COLUMN_CAPACITY",&"COLUMN_REGROW_DAYS",&"COLUMN_PLANTED_DAY",&"COLUMN_EXHAUSTED_FLAG",
	&"COLUMN_TILE",&"COLUMN_REF",&"COLUMN_REF"]

func _empty() -> Array:
	"""A source-owned cleared image; raw framing zeros are not semantic defaults."""
	var c: Array = []
	for field: int in 10:
		var values: Variant = PackedByteArray() if field == 0 or field == 6 else (PackedInt64Array() if field == 2 or field == 3 else PackedInt32Array())
		values.resize(4096)
		if field == 7 or field == 8: values.fill(-1)
		c.append(values)
	return c

func _copy(c: Array) -> Array:
	"""Duplicate each packed buffer: copying the outer Array alone shares packed elements."""
	var copied: Array = []
	for values: Variant in c: copied.append(values.duplicate())
	return copied

func _put(c: Array, field: int, row: int, value: int) -> void:
	"""Packed column writeback is explicit."""
	var values: Variant = c[field]
	values[row] = value
	c[field] = values

func _present(c: Array, row: int) -> void:
	"""One scalar-valid row; catalog identity is deliberately not asserted here."""
	_put(c,0,row,1)
	_put(c,2,row,9)
	_put(c,3,row,9)
	_put(c,5,row,1)
	_put(c,7,row,0)
	_put(c,8,row,0)
	_put(c,9,row,1)

func _predicate(c: Array) -> StringName:
	"""Ten canonical typed fields, including both true i64 quantities."""
	return Nodes.columns_refusal(c[0],c[1],c[2],c[3],c[4],c[5],c[6],c[7],c[8],c[9])

func _frame(c: Array) -> Section.FramedOwner:
	"""Do not ignore any fixture setter failure."""
	var frame: Section.FramedOwner = Section.FramedOwner.new(13)
	for field: int in 10:
		var ok: bool
		if field == 0 or field == 6: ok = frame.set_u8(field,c[field])
		elif field == 2 or field == 3: ok = frame.set_i64(field,c[field])
		else: ok = frame.set_i32(field,c[field])
		assert_true(ok,"fixture setter %d" % field)
	return frame

func _held(frame: Section.FramedOwner, field: int) -> Variant:
	"""Read the canonical typed bucket for equality evidence."""
	if field == 0 or field == 6: return frame.u8_column(field)
	if field == 2 or field == 3: return frame.i64_column(field)
	return frame.i32_column(field)

func _expect(c: Array, code: StringName) -> void:
	"""Exact refusal channels and every caller/frame packed value are preserved."""
	var before: Array = []
	for values: Variant in c: before.append(values.duplicate())
	var frame: Section.FramedOwner = _frame(c)
	assert_equal(_predicate(c),code,"static exact code")
	var result: Variant = Bridge.framed_refusal(frame)
	assert_equal(result.code,code,"framed exact code")
	assert_equal(result.is_ok(),code == &"","success channel")
	if code == &"": assert_equal(result.detail,"","empty success detail")
	else:
		assert_true(result.detail.contains("ResourceNodes owner 13 "),"owner identity")
		assert_true(result.detail.contains(String(code)),"raw code")
	for field: int in 10:
		assert_true(c[field] == before[field],"caller unchanged")
		assert_true(_held(frame,field) == before[field],"framed values unchanged")

func test_layout_defaults_and_full_integer_endpoints() -> void:
	"""Owner13 version1 differs from its separately versioned section1 owner."""
	assert_equal(Schema.owner_version(13),1,"section4 version")
	assert_equal(Schema.primary_count(13),4096,"physical rows")
	for field: int in 10:
		assert_equal(Schema.field_key(13,field),KEYS[field],"key")
		assert_equal(Schema.field_type(13,field),0 if field == 0 or field == 6 else (4 if field == 2 or field == 3 else 2),"type")
		assert_equal(Schema.element_count(13,field),4096,"extent")
	_expect(_empty(),&"")
	assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(13)).code,&"COLUMN_TILE","raw zero frame")
	var c: Array = _empty()
	_present(c,4095)
	for field: int in [1,4,5,9]: _put(c,field,4095,2147483647)
	_put(c,2,4095,I64_MAX)
	_put(c,3,4095,I64_MAX)
	_put(c,7,4095,16383)
	_put(c,8,4095,352417)
	_expect(c,&"")
	_put(c,2,4095,I64_MAX-1)
	_expect(c,&"")
	_put(c,2,4095,0)
	_put(c,6,4095,1)
	_expect(c,&"")

func test_retained_inactive_history_and_local_duplicate_scope() -> void:
	"""Retained tuples are domain-valid; duplicates require saved-world binding later."""
	var c: Array = _empty()
	for field: int in [1,4,5]: _put(c,field,4095,2147483647)
	_put(c,3,4095,I64_MAX)
	_expect(c,&"")
	for field: int in [1,3,4,5]:
		_put(c,field,4095,0)
		_expect(c,&"")
	_present(c,0)
	_present(c,4095)
	_expect(c,&"")

func test_every_physical_position_has_a_value_witness() -> void:
	"""All4096 positions in every field, with full caller equality after each call."""
	var c: Array = _empty()
	for row: int in 4096:
		for field: int in 10:
			var bad: int = 2 if field == 0 or field == 6 else (-2 if field == 7 or field == 8 else -1)
			_put(c,field,row,bad)
			var before: Array = _copy(c)
			assert_equal(_predicate(c),CODES[field],"physical row%d field%d" % [row,field])
			assert_true(c == before,"all caller fields unchanged")
			_put(c,field,row,-1 if field == 7 or field == 8 else 0)
	_expect(c,&"")

func test_scalar_extrema_and_all_seventeen_clause_witnesses() -> void:
	"""Exact codes detect omitted early clauses even when a later gate also refuses."""
	for field: int in [1,2,3,4,5]:
		for value: int in [-1,I64_MIN if field == 2 or field == 3 else -2147483648]:
			var c: Array = _empty()
			_put(c,field,4095,value)
			_expect(c,CODES[field])
	for field: int in [0,6]:
		for value: int in [2,255]:
			var c: Array = _empty()
			_put(c,field,4095,value)
			_expect(c,CODES[field])
	var c: Array = _empty()
	_present(c,4095)
	_put(c,2,4095,-1)
	_expect(c,&"COLUMN_QUANTITY")
	_put(c,2,4095,9)
	_put(c,6,4095,2)
	_expect(c,&"COLUMN_EXHAUSTED_FLAG")
	_put(c,6,4095,0)
	_put(c,2,4095,10)
	_expect(c,&"COLUMN_STOCK")
	_put(c,2,4095,0)
	_put(c,3,4095,0)
	_put(c,6,4095,1)
	_expect(c,&"COLUMN_STOCK")
	_put(c,3,4095,9)
	_put(c,5,4095,0)
	_expect(c,&"COLUMN_PRESENT_DAY")
	_put(c,5,4095,1)
	_put(c,6,4095,0)
	_expect(c,&"COLUMN_EXHAUSTION")
	_put(c,2,4095,1)
	_put(c,6,4095,1)
	_expect(c,&"COLUMN_EXHAUSTION")
	c = _empty()
	_put(c,3,4095,1)
	_put(c,2,4095,1)
	_expect(c,&"COLUMN_INACTIVE")
	_put(c,2,4095,0)
	_put(c,6,4095,1)
	_expect(c,&"COLUMN_INACTIVE")

func test_tile_and_global_directory_reference_boundaries() -> void:
	"""Different global/typed bounds and exact null halves are independently observable."""
	for value: int in [-2147483648,-1,16384,2147483647]:
		var c: Array = _empty()
		_present(c,4095)
		_put(c,7,4095,value)
		_expect(c,&"COLUMN_TILE")
	for value: int in [-2,0,16383,2147483647]:
		var c: Array = _empty()
		_put(c,7,4095,value)
		_expect(c,&"COLUMN_TILE")
	for ref: Vector2i in [Vector2i(-1,0),Vector2i(-1,1),Vector2i(0,0),Vector2i(352418,1),Vector2i(0,-1),Vector2i(-2147483648,1),Vector2i(2147483647,1)]:
		var c: Array = _empty()
		_present(c,4095)
		_put(c,8,4095,ref.x)
		_put(c,9,4095,ref.y)
		_expect(c,&"COLUMN_REF")
	for ref: Vector2i in [Vector2i(-2,0),Vector2i(-1,1),Vector2i(0,0),Vector2i(0,1),Vector2i(-1,-2147483648)]:
		var c: Array = _empty()
		_put(c,8,4095,ref.x)
		_put(c,9,4095,ref.y)
		_expect(c,&"COLUMN_REF")
	var c: Array = _empty()
	_present(c,4095)
	_put(c,8,4095,87552)
	_expect(c,&"")

func _fault(c: Array, gate: int, row: int) -> StringName:
	"""Each global gate has an isolated earlier-gate-valid witness."""
	var fields: Array[int] = [0,6,1,2,3,4,5]
	if gate < 7:
		var field: int = fields[gate]
		_put(c,field,row,2 if field == 0 or field == 6 else -1)
		return CODES[field]
	if gate < 10:
		_present(c,row)
		if gate == 7: _put(c,2,row,10)
		elif gate == 8: _put(c,5,row,0)
		else: _put(c,6,row,1)
		return &"COLUMN_STOCK" if gate == 7 else (&"COLUMN_PRESENT_DAY" if gate == 8 else &"COLUMN_EXHAUSTION")
	if gate == 10: _put(c,7,row,0)
	elif gate == 11: _put(c,8,row,0)
	else: _put(c,6,row,1)
	return &"COLUMN_TILE" if gate == 10 else (&"COLUMN_REF" if gate == 11 else &"COLUMN_INACTIVE")

func test_global_gate_priority_at_opposite_rows() -> void:
	"""Earlier gate on row4095 must win over next gate on row0."""
	for gate: int in 12:
		var c: Array = _empty()
		var code: StringName = _fault(c,gate,4095)
		_fault(c,gate+1,0)
		_expect(c,code)

func test_every_shape_precedes_values_and_typed_bucket_shapes() -> void:
	"""All ten empty/short/long extents refuse before unsafe indexing or value gates."""
	for field: int in 10:
		for size: int in [0,4095,4097]:
			var c: Array = _empty()
			_put(c,0,0,2)
			var values: Variant = c[field]
			values.resize(size)
			c[field] = values
			var before: Array = _copy(c)
			assert_equal(_predicate(c),&"COLUMN_SHAPE","allshape beforevalue")
			assert_true(c == before,"badshape inputs preserved")
			var frame: Section.FramedOwner = _frame(_empty())
			var index: int = Schema.storage_index(13,field)
			if field == 0 or field == 6: frame.u8_columns[index] = values
			elif field == 2 or field == 3: frame.i64_columns[index] = values
			else: frame.i32_columns[index] = values
			assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","framed shape")
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
			assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","bucket cardinality")
	assert_equal(Bridge.framed_refusal(null).code,&"SAVE_COMPONENT_SHAPE","null")
	for owner: int in [-1,12,14,18]:
		assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(owner)).code,&"SAVE_COMPONENT_OWNER","wrong owner")

func _public_image(nodes: Nodes) -> Array:
	"""Capture only public present-row values; absent history is not observable here."""
	var c: Array = _empty()
	for index: int in nodes.count():
		var live: Variant = nodes.live_slot_at(index)
		assert_true(live.ok,"live row reader")
		var row: int = live.value
		_put(c,0,row,1)
		var reads: Array = [nodes.resource_id_of(row),nodes.quantity_milli_of(row),nodes.capacity_milli_of(row),nodes.regrow_days_of(row),nodes.planted_day_of(row)]
		for field: int in 5:
			assert_true(reads[field].ok,"public scalar reader")
			_put(c,field+1,row,reads[field].value)
		_put(c,6,row,1 if nodes.is_exhausted(row) else 0)
		var tile: Variant = nodes.tile_of(row)
		assert_true(tile.ok,"public tile reader")
		_put(c,7,row,tile.value)
		_put(c,8,row,nodes.ref_of(row).x)
		_put(c,9,row,nodes.ref_of(row).y)
	return c

func test_public_wide_harvest_overflow_regrow_and_destroy_history() -> void:
	"""Real producer history remains scalar-valid, without a private owner getter."""
	var nodes: Nodes = Nodes.new()
	var first: Nodes.OpResult = nodes.create_at_tile(0,2147483647,I64_MAX,2147483647,2147483647)
	assert_true(first.ok,"generic API extrema, not published catalog identity")
	_expect(_public_image(nodes),&"")
	assert_true(nodes.harvest(first.value,1,2147483647).ok,"partial debit")
	assert_equal(nodes.quantity_milli_of(first.value).value,I64_MAX-1,"exact int64 debit")
	_expect(_public_image(nodes),&"")
	assert_true(nodes.harvest_all(first.value,2147483647).ok,"exhaustion")
	_expect(_public_image(nodes),&"")
	var due: Variant = nodes.regrow_ready_day_of(first.value)
	assert_false(due.ok,"sum overflow is later runtime refusal")
	assert_equal(String(due.error),"OVERFLOW","overflow diagnostic")
	var before: Array = _public_image(nodes)
	var detail: String = nodes.section_1_detail()
	_expect(before,&"")
	var bad: Array = _copy(before)
	_put(bad,1,4095,-1)
	_expect(bad,&"COLUMN_RESOURCE_ID")
	assert_true(_public_image(nodes) == before,"pure success/refusal preserve live readers")
	assert_equal(nodes.section_1_detail(),detail,"diagnostic unchanged")
	assert_equal(nodes.count(),1,"derived live count unchanged")
	assert_equal(nodes.section_1_cross_check_refusal(),&"","live inverse/Directory remains valid")
	assert_true(nodes.destroy(first.ref).ok,"destroy")
	assert_false(nodes.is_present(first.value),"inactive")
	assert_equal(nodes.ref_of(first.value),Vector2i(-1,0),"public null ref")
	assert_false(nodes.capacity_milli_of(first.value).ok,"inactive private history not exposed")
	# Source-owned expected tuple after destroy; not a claim to have captured private columns.
	for field: int in [0,2,6,9]: _put(before,field,first.value,0)
	for field: int in [7,8]: _put(before,field,first.value,-1)
	_expect(before,&"")
	var second: Nodes.OpResult = nodes.create_at_tile(1,0,WIDE,48,1)
	assert_true(second.ok,"wide fixture creates")
	assert_true(nodes.harvest(second.value,1,2).ok,"wide partial debit")
	assert_equal(nodes.quantity_milli_of(second.value).value,WIDE-1,"one unit exact above2^53")
	_expect(_public_image(nodes),&"")
	assert_true(nodes.harvest_all(second.value,3).ok,"dated stump")
	_expect(_public_image(nodes),&"")
	assert_true(nodes.regrow(second.value,51).ok,"regrows when due")
	assert_equal(nodes.quantity_milli_of(second.value).value,WIDE,"exact restored capacity")
	assert_equal(nodes.planted_day_of(second.value).value,3,"stump history retained")
	_expect(_public_image(nodes),&"")
	assert_true(nodes.destroy(second.ref).ok,"cleanup")
