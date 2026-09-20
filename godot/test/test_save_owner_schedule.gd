extends "res://test/framework/test_case.gd"
const Schedule := preload("res://scripts/core/schedule.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Bridge := preload("res://scripts/core/save_owner_schedule.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const COUNTS: Array[int] = [512,12288,512,512,512,512]
const TYPES: Array[int] = [0,0,2,2,0,0]
const KEYS: Array[String] = ["_present","_hourly_activity","_template","_current_activity","_sleep_satisfied","_resolved"]
const BAD: Array[int] = [2,4,3,4,2,2]
const CODES: Array[StringName] = [&"COLUMN_PRESENT_BYTE",&"COLUMN_HOURLY_ACTIVITY",
	&"COLUMN_TEMPLATE_ID",&"COLUMN_CURRENT_ACTIVITY",&"COLUMN_SLEEP_SATISFIED_BYTE",&"COLUMN_RESOLVED_BYTE"]

func _empty() -> Array:
	"""Independent exact-size fixture, with ANYTHING1 in both activity columns."""
	var image: Array = []
	for field: int in 6:
		var values: Variant = PackedInt32Array() if TYPES[field] == 2 else PackedByteArray()
		values.resize(COUNTS[field])
		if field == 1 or field == 3: values.fill(1)
		image.append(values)
	return image

func _put(image: Array, field: int, index: int, value: int) -> void:
	"""Write packed fixture changes back explicitly through the outer Array."""
	var values: Variant = image[field]
	values[index] = value
	image[field] = values

func _base() -> Array:
	"""A resolved nondefault present row distinguishes missing presence or resolution."""
	var image: Array = _empty()
	_put(image,0,0,1)
	_put(image,3,0,2)
	_put(image,5,0,1)
	return image

func _predicate(image: Array) -> StringName:
	"""Invoke all six arguments in the independently pinned canonical order."""
	return Schedule.columns_refusal(image[0],image[1],image[2],image[3],image[4],image[5])

func _frame(image: Array) -> Section.FramedOwner:
	"""Construct a copied frame and verify every typed fixture assignment succeeds."""
	var frame: Section.FramedOwner = Section.FramedOwner.new(14)
	for field: int in 6:
		var copied: bool = frame.set_i32(field,image[field]) if TYPES[field] == 2 else frame.set_u8(field,image[field])
		assert_true(copied,"fixture field%d" % field)
	return frame

func _expect(image: Array, code: StringName) -> void:
	"""Static and framed refusal channels agree and preserve every input value."""
	var before: Array = []
	for values: Variant in image: before.append(values.duplicate())
	var frame: Section.FramedOwner = _frame(image)
	assert_equal(_predicate(image),code,"static exact code")
	var refusal: Variant = Bridge.framed_refusal(frame)
	assert_equal(refusal.code,code,"framed exact code")
	assert_equal(refusal.is_ok(),code == &"","success channel")
	if code == &"": assert_equal(refusal.detail,"","success diagnostic empty")
	else:
		assert_true(refusal.detail.contains("Schedule owner 14 "),"owner identity")
		assert_true(refusal.detail.contains(String(code)),"column identity")
	for field: int in 6:
		assert_true(image[field] == before[field],"static input unchanged")
		var held: Variant = frame.i32_column(field) if TYPES[field] == 2 else frame.u8_column(field)
		assert_true(held == before[field],"framed input unchanged")

func _from_owner(owner: Schedule) -> Array:
	"""Use public readers, asserting inactive defaults and unresolved-reader refusals."""
	var image: Array = _empty()
	for slot: int in 512:
		if not owner.is_present(slot):
			assert_true(owner.inactive_row_is_clear(slot),"actual inactive row is clear")
			continue
		_put(image,0,slot,1)
		var template: Variant = owner.template_of(slot)
		var sleep: Variant = owner.sleep_satisfied_of(slot)
		assert_true(template.ok and sleep.ok,"public template/latch readers")
		_put(image,2,slot,template.value)
		_put(image,4,slot,sleep.value)
		var current: Variant = owner.current_activity_of(slot)
		if current.ok:
			_put(image,3,slot,current.value)
			_put(image,5,slot,1)
		else: assert_equal(current.error,String(Schedule.REFUSE_NOT_RESOLVED),"only unresolved refusal is expected")
		for hour: int in 24:
			var activity: Variant = owner.hour_activity_of(slot,hour)
			assert_true(activity.ok,"public hourly reader")
			_put(image,1,slot*24+hour,activity.value)
	return image

func test_exact_field_layout_and_nonzero_empty_defaults() -> void:
	"""The declared empty state differs from arbitrary allzero wire data."""
	for field: int in 6:
		assert_equal(Schema.field_key(14,field),KEYS[field],"field key")
		assert_equal(Schema.field_type(14,field),TYPES[field],"field type")
		assert_equal(Schema.element_count(14,field),COUNTS[field],"field extent")
	_expect(_empty(),&"")
	assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(14)).code,&"COLUMN_FREE_ROW","zero frame must not be normalized")

func test_six_independent_mapping_witnesses() -> void:
	"""Each incorrectly substituted packed argument changes the exact returned code."""
	for field: int in 6:
		var image: Array = _base()
		_put(image,field,0,BAD[field])
		_expect(image,CODES[field])
	_expect(_base(),&"")

func test_every_hourly_byte_and_each_i32_row_is_checked() -> void:
	"""No physical tail or inactive row escapes whole-column domain validation."""
	var image: Array = _empty()
	for index: int in 12288:
		_put(image,1,index,4)
		assert_equal(_predicate(image),&"COLUMN_HOURLY_ACTIVITY","hourly index%d" % index)
		_put(image,1,index,1)
	for field: int in [2,3]:
		for slot: int in 512:
			_put(image,field,slot,BAD[field])
			assert_equal(_predicate(image),CODES[field],"signed domain across every row")
			_put(image,field,slot,0 if field == 2 else 1)
	_put(image,1,12287,255)
	_expect(image,&"COLUMN_HOURLY_ACTIVITY")

func test_all_local_template_and_activity_values_and_signed_extrema() -> void:
	"""All numeric choices remain legal while out-of-domain signed values refuse."""
	for template: int in 3:
		for activity: int in 4:
			var image: Array = _base()
			_put(image,2,0,template)
			_put(image,1,0,activity)
			_put(image,3,0,activity)
			_expect(image,&"")
	for field: int in [2,3]:
		for value: int in [-2147483648,-1,2147483647]:
			var image: Array = _base()
			_put(image,field,0,value)
			_expect(image,CODES[field])
	for field: int in [0,4,5]:
		var image: Array = _base()
		_put(image,field,0,255)
		_expect(image,CODES[field])

func test_unresolved_and_latched_state_implications() -> void:
	"""Only local saved-state implications are checked, never current timetable agreement."""
	var image: Array = _base()
	_put(image,5,0,0)
	_expect(image,&"COLUMN_UNRESOLVED_STATE")
	_put(image,3,0,1)
	_expect(image,&"")
	_put(image,4,0,1)
	_expect(image,&"COLUMN_UNRESOLVED_STATE")
	_put(image,5,0,1)
	_expect(image,&"")
	for activity: int in [0,2,3]:
		_put(image,3,0,activity)
		_expect(image,&"COLUMN_SLEEP_STATE")
	_put(image,3,0,1)
	_put(image,1,0,2)
	_expect(image,&"")

func test_free_rows_require_exact_anything_defaults_at_both_ends() -> void:
	"""Free row values are explicit, including nonzero hourly/current ANYTHING bytes."""
	for slot: int in [0,511]:
		for field: int in [1,2,3,4,5]:
			var image: Array = _empty()
			var index: int = slot*24+23 if field == 1 else slot
			_put(image,field,index,0 if field == 1 or field == 3 else 1)
			_expect(image,&"COLUMN_FREE_ROW")

func test_refusal_precedence_is_global_across_distinct_rows() -> void:
	"""A later row's earlier gate wins over a lower-priority fault at row0."""
	var image: Array = _base()
	_put(image,4,0,1)
	_expect(image,&"COLUMN_SLEEP_STATE")
	_put(image,0,1,1)
	_put(image,3,1,2)
	_expect(image,&"COLUMN_UNRESOLVED_STATE")
	_put(image,1,2*24,0)
	_expect(image,&"COLUMN_FREE_ROW")
	_put(image,3,10,4)
	_expect(image,&"COLUMN_CURRENT_ACTIVITY")
	_put(image,2,15,3)
	_expect(image,&"COLUMN_TEMPLATE_ID")
	_put(image,1,20*24,4)
	_expect(image,&"COLUMN_HOURLY_ACTIVITY")
	_put(image,5,25,2)
	_expect(image,&"COLUMN_RESOLVED_BYTE")
	_put(image,4,30,2)
	_expect(image,&"COLUMN_SLEEP_SATISFIED_BYTE")
	_put(image,0,35,2)
	_expect(image,&"COLUMN_PRESENT_BYTE")

func test_all512_present_rows_remain_valid() -> void:
	"""Schedule storage is not a living-population counter."""
	var image: Array = _empty()
	var present: PackedByteArray = image[0]
	present.fill(1)
	image[0] = present
	_put(image,2,511,2)
	_put(image,3,511,3)
	_put(image,5,511,1)
	_expect(image,&"")

func test_public_edits_reassignment_and_failed_resolution_preserve_history() -> void:
	"""Replay the reviewed public history witnesses through the actual owner API."""
	var needs: Needs = Needs.new()
	assert_true(needs.spawn(0,Needs.SIZE_MEDIUM).ok,"needs spawn")
	var columns: Needs.Columns = Needs.Columns.new()
	assert_true(needs.copy_columns_into(columns),"capture needs")
	columns.need_value[Needs.NEED_REST] = 9500
	columns.need_value[Needs.NEED_HUNGER] = 8000
	assert_true(needs.restore_columns(columns),"rested fed fixture")
	var owner: Schedule = Schedule.new(needs)
	assert_true(owner.spawn(0,owner.default_template_id().value).ok,"schedule spawn")
	_expect(_from_owner(owner),&"")
	assert_true(owner.resolve(0,22,false).ok,"resolve satisfied sleep")
	assert_true(owner.set_hour_activity(0,22,Schedule.ACTIVITY_WORK).ok,"edit current hour")
	_expect(_from_owner(owner),&"")
	assert_equal(owner.sleep_satisfied_of(0).value,1,"edit preserves latch")
	assert_equal(owner.resolve(0,18,false).value,Schedule.ACTIVITY_SOCIAL,"resolve social")
	assert_true(owner.assign_template(0,owner.template_id_of(&"flexible").value).ok,"reassign")
	assert_false(owner.resolve(0,24,false).ok,"invalid hour refuses")
	_expect(_from_owner(owner),&"")
	assert_equal(owner.current_activity_of(0).value,Schedule.ACTIVITY_SOCIAL,"old resolved activity preserved")
	assert_equal(owner.hour_activity_of(0,18).value,Schedule.ACTIVITY_ANYTHING,"new timetable differs")
	assert_equal(owner.present_count(),1,"validation preserves owner count")

func test_shared_inactive_reader_preserves_address_and_presence_guards() -> void:
	"""The shared free-row predicate cannot change the old reader's public answers."""
	var owner: Schedule = Schedule.new()
	assert_false(owner.inactive_row_is_clear(-1),"negative slot")
	assert_false(owner.inactive_row_is_clear(512),"past capacity")
	assert_true(owner.inactive_row_is_clear(511),"initial last row clear")
	assert_true(owner.spawn(511,owner.default_template_id().value).ok,"spawn last row")
	assert_false(owner.inactive_row_is_clear(511),"present is never inactive")
	assert_true(owner.set_hour_activity(511,23,Schedule.ACTIVITY_SOCIAL).ok,"customize")
	assert_true(owner.despawn(511).ok,"despawn")
	assert_true(owner.inactive_row_is_clear(511),"released row restores ANYTHING defaults")
	_expect(_from_owner(owner),&"")

func test_every_extent_is_checked_before_domains() -> void:
	"""Empty, short and oversized typed columns refuse before index access."""
	for field: int in 6:
		for size: int in [0,COUNTS[field]-1,COUNTS[field]+1]:
			var image: Array = _base()
			var values: Variant = image[field]
			values.resize(size)
			image[field] = values
			assert_equal(_predicate(image),&"COLUMN_SHAPE","owner extent")
			var frame: Section.FramedOwner = _frame(_base())
			var index: int = Schema.storage_index(14,field)
			if TYPES[field] == 2: frame.i32_columns[index] = values
			else: frame.u8_columns[index] = values
			assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","framed extent")

func test_null_wrong_owner_and_typed_bucket_shapes() -> void:
	"""Framing guards reject malformed buckets before evaluating any column argument."""
	assert_equal(Bridge.framed_refusal(null).code,&"SAVE_COMPONENT_SHAPE","null frame")
	for owner: int in [-1,11,18]:
		assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(owner)).code,&"SAVE_COMPONENT_OWNER","wrong owner")
	for variant: int in 5:
		var frame: Section.FramedOwner = _frame(_base())
		if variant == 0: frame.u8_columns.pop_back()
		elif variant == 1: frame.i32_columns.pop_back()
		elif variant == 2: frame.u8_columns.append(PackedByteArray())
		elif variant == 3: frame.i32_columns.append(PackedInt32Array())
		else: frame.i64_columns.append(PackedInt64Array())
		assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","typed bucket count")
