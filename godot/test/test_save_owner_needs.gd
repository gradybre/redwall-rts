extends "res://test/framework/test_case.gd"
const Needs := preload("res://scripts/core/needs.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Bridge := preload("res://scripts/core/save_owner_needs.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const FIELDS: Array[StringName] = [&"present", &"need_value", &"need_remainder", &"health",
	&"health_remainder", &"cold_milli_hours", &"cold_remainder", &"starving_ticks", &"departure_days",
	&"status", &"size_class", &"activity", &"comfort_environment", &"social_paired", &"purpose_source",
	&"cold_environment", &"clothing_tier", &"infirmary", &"injury_state", &"airless"]
const BAD: Array[int] = [2,-1,750000,-1,750,-1,750,-1,-1,7,3,3,3,2,3,3,0,2,3,2]
const CODES: Array[StringName] = [&"COLUMN_PRESENT_BYTE",&"COLUMN_NEED_RANGE",&"COLUMN_REMAINDER",
	&"COLUMN_HEALTH_RANGE",&"COLUMN_REMAINDER",&"COLUMN_NEGATIVE_COUNTER",&"COLUMN_REMAINDER",
	&"COLUMN_NEGATIVE_COUNTER",&"COLUMN_NEGATIVE_COUNTER",&"COLUMN_ENUM_BYTE",&"COLUMN_ENUM_BYTE",
	&"COLUMN_ENUM_BYTE",&"COLUMN_ENUM_BYTE",&"COLUMN_FLAG_BYTE",&"COLUMN_ENUM_BYTE",&"COLUMN_ENUM_BYTE",
	&"COLUMN_CLOTHING_TIER",&"COLUMN_FLAG_BYTE",&"COLUMN_ENUM_BYTE",&"COLUMN_FLAG_BYTE"]

func _base() -> Needs.Columns:
	"""One ordinary living row; all other rows hold the actual declared inactive values."""
	var columns: Needs.Columns = Needs.Columns.new()
	columns.present[0] = 1
	columns.health[0] = 100
	columns.status[0] = Needs.STATUS_ACTIVE
	return columns

func _copy(columns: Needs.Columns) -> Needs.Columns:
	"""Independent snapshots for input nonmutation assertions; reflection is test-only."""
	var result: Needs.Columns = Needs.Columns.new()
	for key: StringName in FIELDS:
		var values: Variant = columns.get(key)
		result.set(key,values.duplicate())
	return result

func _set_first(columns: Needs.Columns, field: int, value: int) -> void:
	"""Modify a named fixture column and explicitly write back its packed value."""
	var values: Variant = columns.get(FIELDS[field])
	values[0] = value
	columns.set(FIELDS[field],values)

func _frame(columns: Needs.Columns) -> Section.FramedOwner:
	"""Test-side mapping is independent of the production bridge's explicit assignments."""
	var result: Section.FramedOwner = Section.FramedOwner.new(9)
	for field: int in FIELDS.size():
		var values: Variant = columns.get(FIELDS[field])
		var code: int = Schema.field_type(9,field)
		var accepted: bool = false
		if code == 0: accepted = result.set_u8(field,values)
		elif code == 2: accepted = result.set_i32(field,values)
		else: accepted = result.set_i64(field,values)
		assert_true(accepted,"fixture field%d copied" % field)
	return result

func _frame_equals(frame: Section.FramedOwner, columns: Needs.Columns) -> void:
	"""Check every caller-owned packed value after validation, without dumping large arrays."""
	for field: int in FIELDS.size():
		var values: Variant = columns.get(FIELDS[field])
		var kind: int = Schema.field_type(9,field)
		if kind == 0: assert_true(frame.u8_column(field) == values,"u8 unchanged field%d" % field)
		elif kind == 2: assert_true(frame.i32_column(field) == values,"i32 unchanged field%d" % field)
		else: assert_true(frame.i64_column(field) == values,"i64 unchanged field%d" % field)

func _parity(columns: Needs.Columns, expected: StringName) -> void:
	"""The same image must have one answer in static, framed and owner validation."""
	var before: Needs.Columns = _copy(columns)
	var frame: Section.FramedOwner = _frame(columns)
	assert_equal(Needs.columns_refusal(columns),expected,"pure owner predicate")
	assert_true(columns.equals(before),"static validation preserves input")
	var result: Variant = Bridge.framed_refusal(frame)
	assert_equal(result.code,expected,"framed predicate exact code")
	assert_equal(result.is_ok(),expected == &"","success channel agrees")
	if expected == &"": assert_equal(result.detail,"","success clears diagnostics")
	else: assert_false(result.detail.is_empty(),"refusal has detail")
	_frame_equals(frame,before)
	var target: Needs = Needs.new()
	target.spawn(8,Needs.SIZE_LARGE)
	var world_before: PackedByteArray = target.state_bytes()
	assert_equal(target.restore_columns(columns),expected == &"","owner restore answer")
	assert_equal(target.last_column_refusal(),expected,"owner diagnostic parity")
	assert_true(columns.equals(before),"owner restore preserves caller image")
	if expected != &"": assert_true(target.state_bytes() == world_before,"refused target unchanged")

func test_test_mapping_names_match_all_twenty_declared_fields() -> void:
	"""Pin the independent fixture mapping to both published field orders."""
	assert_equal(FIELDS.size(),20,"fixture covers every field")
	for field: int in FIELDS.size():
		assert_equal("_" + String(FIELDS[field]),Schema.field_key(9,field),"independent field identity")
		assert_equal("_" + String(FIELDS[field]),String(Needs.COLUMN_KEYS[field]),"published owner identity")

func test_every_field_has_an_independent_invalid_value_witness() -> void:
	"""An omitted assignment must change this field-specific refusal code."""
	for field: int in FIELDS.size():
		var columns: Needs.Columns = _base()
		_set_first(columns,field,BAD[field])
		_parity(columns,CODES[field])

func test_actual_declared_defaults_pass_but_arbitrary_zero_frame_does_not() -> void:
	"""Semantic defaults differ from an arbitrary all-zero wire image."""
	_parity(Needs.Columns.new(),&"")
	var frame: Section.FramedOwner = Section.FramedOwner.new(9)
	assert_equal(Bridge.framed_refusal(frame).code,&"COLUMN_CLOTHING_TIER","zero wire is not a valid default world")

func test_death_equivalence_refuses_all_non_dead_statuses_at_zero_health() -> void:
	"""Reject both directions of the health/death contradiction."""
	for status: int in Needs.STATUS_COUNT:
		if status == Needs.STATUS_DEAD: continue
		var columns: Needs.Columns = _base()
		columns.health[0] = 0
		columns.status[0] = status
		_parity(columns,&"COLUMN_HEALTH_STATUS")
	for health: int in [1,100]:
		var columns: Needs.Columns = _base()
		columns.health[0] = health
		columns.status[0] = Needs.STATUS_DEAD
		_parity(columns,&"COLUMN_HEALTH_STATUS")

func test_valid_dead_row_does_not_consume_living_capacity() -> void:
	"""A dead present row stays excluded from living count after a tick."""
	var columns: Needs.Columns = _base()
	columns.health[0] = 0
	columns.status[0] = Needs.STATUS_DEAD
	_parity(columns,&"")
	var target: Needs = Needs.new()
	assert_true(target.restore_columns(columns),"valid dying resident restored")
	assert_equal(target.living_count(),0,"dead present row is not living")
	target.tick_all()
	assert_equal(target.living_count(),0,"tick cannot drift the restored count")
	assert_equal(target.status_of(0).value,Needs.STATUS_DEAD,"dead status preserved")

func test_normal_injury_activity_and_starvation_history_remain_legal() -> void:
	"""Preserve the accepted injury combinations and historic starvation counter."""
	var columns: Needs.Columns = _base()
	columns.injury_state[0] = Needs.INJURY_ACTIVE
	_parity(columns,&"")
	columns.health[0] = 50
	columns.activity[0] = Needs.ACTIVITY_SLEEP_BED
	columns.status[0] = Needs.STATUS_INJURED
	columns.need_value[0] = 5000
	columns.starving_ticks[0] = 9000
	_parity(columns,&"")

func test_retained_inactive_environment_and_departure_counter_are_not_zeroed() -> void:
	"""Retained inactive input columns remain valid and unchanged."""
	var columns: Needs.Columns = Needs.Columns.new()
	columns.size_class[0] = Needs.SIZE_LARGE
	columns.activity[0] = Needs.ACTIVITY_SLEEP_FLOOR
	columns.cold_environment[0] = Needs.COLD_ENV_EXPOSED
	columns.injury_state[0] = Needs.INJURY_UNTREATED_SERIOUS
	columns.clothing_tier[0] = 2
	columns.infirmary[0] = 1
	columns.airless[0] = 1
	columns.departure_days[0] = 2147483647
	_parity(columns,&"")

func test_signed_extrema_and_both_remainder_edges() -> void:
	"""Exercise signed lower limits and strict integration remainder bounds."""
	for field: int in [1,3,8]:
		var columns: Needs.Columns = _base()
		_set_first(columns,field,-2147483648)
		_parity(columns,CODES[field])
	for field: int in [2,4,6]:
		var denominator: int = 750000 if field == 2 else 750
		for sign_value: int in [-1,1]:
			var columns: Needs.Columns = _base()
			_set_first(columns,field,sign_value * (denominator-1))
			_parity(columns,&"")
			_set_first(columns,field,sign_value * denominator)
			_parity(columns,&"COLUMN_REMAINDER")
	var columns: Needs.Columns = _base()
	columns.departure_days[0] = 2147483647
	columns.cold_milli_hours[0] = 9223372036854775807
	columns.starving_ticks[0] = 9223372036854775807
	_parity(columns,&"")

func test_null_inputs_are_total_and_refused_owner_is_unchanged() -> void:
	"""Null references safely refuse without changing the target simulation."""
	assert_equal(Needs.columns_refusal(null),&"COLUMN_SHAPE","pure null refusal")
	assert_equal(Bridge.framed_refusal(null).code,&"SAVE_COMPONENT_SHAPE","null framed refusal")
	var target: Needs = Needs.new()
	target.spawn(2,Needs.SIZE_SMALL)
	var before: PackedByteArray = target.state_bytes()
	assert_false(target.restore_columns(null),"null restore safely refuses")
	assert_equal(target.last_column_refusal(),&"COLUMN_SHAPE","null restore code")
	assert_false(target.copy_columns_into(null),"null output safely refuses")
	assert_equal(target.last_column_refusal(),&"COLUMN_SHAPE","null capture output code")
	assert_true(target.state_bytes() == before,"null failures preserve owner")

func test_bridge_owner_and_shape_preflight() -> void:
	"""Wrong owner and malformed extents refuse before semantic projection."""
	for owner: int in [-1,4,18]:
		var frame: Section.FramedOwner = Section.FramedOwner.new(owner)
		assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_OWNER","Needs bridge rejects another owner")
	for size: int in [0,511,513]:
		var frame: Section.FramedOwner = _frame(_base())
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(size)
		frame.u8_columns[0] = bytes
		assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","wrong physical extent refuses")

func _population(count: int) -> Needs.Columns:
	"""Construct an exact living boundary with valid health/status for every present row."""
	var columns: Needs.Columns = Needs.Columns.new()
	for slot: int in count:
		columns.present[slot] = 1
		columns.health[slot] = 100
		columns.status[slot] = Needs.STATUS_ACTIVE
	return columns

func test_living_cap_and_first_refusal_across_distinct_rows() -> void:
	"""Multiple errors across distinct rows preserve the specified refusal order."""
	_parity(_population(256),&"")
	var columns: Needs.Columns = _population(257)
	_parity(columns,&"COLUMN_LIVING_CAP")
	columns.health[0] = 0
	_parity(columns,&"COLUMN_HEALTH_STATUS")
	columns.health[300] = 1
	_parity(columns,&"COLUMN_FREE_ROW")
	columns.need_remainder[0] = 750000
	_parity(columns,&"COLUMN_REMAINDER")
	columns.departure_days[0] = -1
	_parity(columns,&"COLUMN_NEGATIVE_COUNTER")
	columns.health[0] = 101
	_parity(columns,&"COLUMN_HEALTH_RANGE")
	columns.need_value[0] = 10001
	_parity(columns,&"COLUMN_NEED_RANGE")
	columns.status[0] = 7
	_parity(columns,&"COLUMN_ENUM_BYTE")
	columns.clothing_tier[0] = 0
	_parity(columns,&"COLUMN_CLOTHING_TIER")
	columns.social_paired[0] = 2
	_parity(columns,&"COLUMN_FLAG_BYTE")
	columns.present[0] = 2
	_parity(columns,&"COLUMN_PRESENT_BYTE")
	columns.health.resize(511)
	assert_equal(Needs.columns_refusal(columns),&"COLUMN_SHAPE","shape before indexed domain checks")

func test_every_byte_domain_upper_edge_and_large_byte() -> void:
	"""Flags, clothing and enum domains retain their exact upper boundaries."""
	for field: int in [0,9,10,11,12,13,14,15,16,17,18,19]:
		var columns: Needs.Columns = _base()
		_set_first(columns,field,255)
		_parity(columns,CODES[field])
	for field: int in [10,11,12,14,15,18]:
		for value: int in 3:
			var columns: Needs.Columns = _base()
			_set_first(columns,field,value)
			_parity(columns,&"")
	for field: int in [13,17,19]:
		var columns: Needs.Columns = _base()
		_set_first(columns,field,1)
		_parity(columns,&"")
	for value: int in [1,2]:
		var columns: Needs.Columns = _base()
		columns.clothing_tier[0] = value
		_parity(columns,&"")

func test_positive_range_limits_and_negative_i64_extrema() -> void:
	"""Signed storage extrema cannot evade semantic range checks."""
	var columns: Needs.Columns = _base()
	columns.need_value[0] = 10000
	_parity(columns,&"")
	columns.need_value[0] = 10001
	_parity(columns,&"COLUMN_NEED_RANGE")
	columns.need_value[0] = 2147483647
	_parity(columns,&"COLUMN_NEED_RANGE")
	columns = _base()
	columns.health[0] = 101
	_parity(columns,&"COLUMN_HEALTH_RANGE")
	columns.health[0] = 2147483647
	_parity(columns,&"COLUMN_HEALTH_RANGE")
	for field: int in [2,4,5,6,7]:
		columns = _base()
		_set_first(columns,field,-9223372036854775807 - 1)
		_parity(columns,CODES[field])

func test_all_column_shapes_and_bucket_counts_refuse_before_projection() -> void:
	"""Every ordinal requires its exact physical extent before projection."""
	for field: int in FIELDS.size():
		for adjustment: int in [-1,1]:
			var columns: Needs.Columns = _base()
			var values: Variant = columns.get(FIELDS[field])
			values.resize(values.size()+adjustment)
			columns.set(FIELDS[field],values)
			assert_equal(Needs.columns_refusal(columns),&"COLUMN_SHAPE","every column extent checked")
			var frame: Section.FramedOwner = _frame(_base())
			var index: int = Schema.storage_index(9,field)
			var kind: int = Schema.field_type(9,field)
			if kind == 0: frame.u8_columns[index] = values
			elif kind == 2: frame.i32_columns[index] = values
			else: frame.i64_columns[index] = values
			assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","framed extent before projection")

func test_each_typed_bucket_requires_its_exact_column_count() -> void:
	"""Missing and additional typed columns both refuse."""
	for kind: int in [0,2,4]:
		for extra: bool in [false,true]:
			var frame: Section.FramedOwner = _frame(_base())
			if kind == 0:
				if extra: frame.u8_columns.append(PackedByteArray())
				else: frame.u8_columns.pop_back()
			elif kind == 2:
				if extra: frame.i32_columns.append(PackedInt32Array())
				else: frame.i32_columns.pop_back()
			else:
				if extra: frame.i64_columns.append(PackedInt64Array())
				else: frame.i64_columns.pop_back()
			assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","exact typed bucket count")
