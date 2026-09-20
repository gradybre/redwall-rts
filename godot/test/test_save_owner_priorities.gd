extends "res://test/framework/test_case.gd"
const Priorities := preload("res://scripts/core/priorities.gd")
const Bridge := preload("res://scripts/core/save_owner_priorities.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const COUNTS: Array[int] = [512,6144,512,512]
const KEYS: Array[String] = ["_present","_job_priority","_auto_fallback","_dangerous_work"]
const CODES: Array[StringName] = [&"COLUMN_PRESENT_BYTE",&"COLUMN_PRIORITY_RANGE",
	&"COLUMN_AUTO_FALLBACK_BYTE",&"COLUMN_DANGEROUS_WORK_BYTE"]

func _empty() -> Array[PackedByteArray]:
	"""Independent physical fixture sizes, not values read from production metadata."""
	var image: Array[PackedByteArray] = []
	for count: int in COUNTS:
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(count)
		image.append(bytes)
	return image

func _put(image: Array[PackedByteArray], field: int, index: int, value: int) -> void:
	"""Write a packed fixture value back explicitly through its outer array."""
	var bytes: PackedByteArray = image[field]
	bytes[index] = value
	image[field] = bytes

func _base() -> Array[PackedByteArray]:
	"""A present row with nondefault policy distinguishes lost presence from empty state."""
	var image: Array[PackedByteArray] = _empty()
	_put(image,0,0,1)
	_put(image,1,1,2)
	return image

func _predicate(image: Array[PackedByteArray]) -> StringName:
	"""Invoke the owner API in independently pinned canonical field order."""
	return Priorities.columns_refusal(image[0],image[1],image[2],image[3])

func _frame(image: Array[PackedByteArray]) -> Section.FramedOwner:
	"""Copy the four caller columns into an owner11 fixture, asserting every setter."""
	var frame: Section.FramedOwner = Section.FramedOwner.new(11)
	for field: int in 4:
		assert_true(frame.set_u8(field,image[field]),"fixture field%d" % field)
	return frame

func _expect(image: Array[PackedByteArray], code: StringName) -> void:
	"""Static/framed answers agree and every caller-owned byte remains unchanged."""
	var before: Array[PackedByteArray] = []
	for bytes: PackedByteArray in image:
		before.append(bytes.duplicate())
	var frame: Section.FramedOwner = _frame(image)
	assert_equal(_predicate(image),code,"static exact code")
	var refusal: Variant = Bridge.framed_refusal(frame)
	assert_equal(refusal.code,code,"framed exact code")
	assert_equal(refusal.is_ok(),code == &"","success channel")
	if code == &"": assert_equal(refusal.detail,"","success has no detail")
	else:
		assert_true(refusal.detail.contains("Priorities owner 11 "),"failure identifies owner")
		assert_true(refusal.detail.contains(String(code)),"failure identifies exact code")
	for field: int in 4:
		assert_true(image[field] == before[field],"static input unchanged")
		assert_true(frame.u8_column(field) == before[field],"framed input unchanged")

func _from_owner(owner: Priorities) -> Array[PackedByteArray]:
	"""Use public readers to sample real lifecycle output; inactive bytes are specified zeros."""
	var image: Array[PackedByteArray] = _empty()
	for slot: int in 512:
		if not owner.is_present(slot): continue
		_put(image,0,slot,1)
		for kind: int in 12:
			var priority: Variant = owner.priority_of(slot,kind)
			assert_true(priority.ok,"public priority read succeeds")
			_put(image,1,slot*12+kind,priority.value)
		var fallback: Variant = owner.auto_fallback_of(slot)
		var dangerous: Variant = owner.dangerous_work_of(slot)
		assert_true(fallback.ok and dangerous.ok,"public policy reads succeed")
		_put(image,2,slot,fallback.value)
		_put(image,3,slot,dangerous.value)
	return image

func test_field_identity_and_all_zero_empty_frame() -> void:
	"""Pin the fixture identities independently and accept the genuine empty image."""
	for field: int in 4:
		assert_equal(Schema.field_key(11,field),KEYS[field],"field identity")
		assert_equal(Schema.field_type(11,field),0,"all columns are bytes")
		assert_equal(Schema.element_count(11,field),COUNTS[field],"physical extent")
	_expect(_empty(),&"")
	assert_true(Bridge.framed_refusal(Section.FramedOwner.new(11)).is_ok(),"zero frame is a valid empty owner")

func test_independent_projection_witnesses_and_asymmetric_flags() -> void:
	"""Exact codes kill each zero-substitution and the two swapped policy arguments."""
	for field: int in 4:
		var image: Array[PackedByteArray] = _base()
		_put(image,field,0,5 if field == 1 else 2)
		_expect(image,CODES[field])
	_expect(_base(),&"")
	var image: Array[PackedByteArray] = _base()
	_put(image,2,0,2)
	_put(image,3,0,255)
	_expect(image,&"COLUMN_AUTO_FALLBACK_BYTE")
	_put(image,2,0,0)
	_expect(image,&"COLUMN_DANGEROUS_WORK_BYTE")

func test_every_physical_priority_byte_is_checked() -> void:
	"""An invalid value in any of6144bytes must be found, including inactive rows."""
	var image: Array[PackedByteArray] = _empty()
	for index: int in 6144:
		_put(image,1,index,5)
		assert_equal(_predicate(image),&"COLUMN_PRIORITY_RANGE","range gate at physical byte%d" % index)
		_put(image,1,index,0)
	_put(image,1,6143,255)
	_expect(image,&"COLUMN_PRIORITY_RANGE")

func test_active_priority_values_and_policy_flags_are_mutable_domains() -> void:
	"""Spawn defaults cannot replace the full accepted player-choice domains."""
	for value: int in 5:
		var image: Array[PackedByteArray] = _base()
		for kind: int in 12:
			if kind != 3: _put(image,1,kind,value)
		_put(image,2,0,value%2)
		_put(image,3,0,1-value%2)
		_expect(image,&"")
	for field: int in [0,2,3]:
		var image: Array[PackedByteArray] = _base()
		_put(image,field,0,255)
		_expect(image,CODES[field])

func test_reserved_first_and_last_rows_precede_inactive_residue() -> void:
	"""Reserved storage is zero at all physical rows, whether present or inactive."""
	for slot: int in [0,511]:
		for present: int in [0,1]:
			var image: Array[PackedByteArray] = _empty()
			_put(image,0,slot,present)
			_put(image,1,slot*12+3,3)
			_expect(image,&"COLUMN_RESERVED_PRIORITY")
			_put(image,1,slot*12+3,7)
			_expect(image,&"COLUMN_PRIORITY_RANGE")

func test_free_rows_require_every_policy_and_active_kind_to_be_zero() -> void:
	"""Each retained flag or active-kind priority on an inactive row refuses."""
	for slot: int in [0,511]:
		for kind: int in 12:
			if kind == 3: continue
			var image: Array[PackedByteArray] = _empty()
			_put(image,1,slot*12+kind,1)
			_expect(image,&"COLUMN_FREE_ROW")
		for field: int in [2,3]:
			var image: Array[PackedByteArray] = _empty()
			_put(image,field,slot,1)
			_expect(image,&"COLUMN_FREE_ROW")

func test_refusal_order_across_distinct_rows() -> void:
	"""Several simultaneous problems resolve by the declared domain order."""
	var image: Array[PackedByteArray] = _empty()
	_put(image,2,511,1)
	_expect(image,&"COLUMN_FREE_ROW")
	_put(image,1,3,3)
	_expect(image,&"COLUMN_RESERVED_PRIORITY")
	_put(image,1,6143,5)
	_expect(image,&"COLUMN_PRIORITY_RANGE")
	_put(image,3,20,2)
	_expect(image,&"COLUMN_DANGEROUS_WORK_BYTE")
	_put(image,2,25,2)
	_expect(image,&"COLUMN_AUTO_FALLBACK_BYTE")
	_put(image,0,30,2)
	_expect(image,&"COLUMN_PRESENT_BYTE")
	var short: PackedByteArray = image[0]
	short.resize(511)
	image[0] = short
	assert_equal(_predicate(image),&"COLUMN_SHAPE","shape precedes every indexed read")

func test_all512_present_rows_are_legal_for_policy_storage() -> void:
	"""This owner has no living-health state and must not impose a256row cap."""
	var image: Array[PackedByteArray] = _empty()
	var present: PackedByteArray = image[0]
	present.fill(1)
	image[0] = present
	_put(image,1,511*12+11,4)
	_put(image,3,511,1)
	_expect(image,&"")

func test_public_lifecycle_and_shared_free_row_reader() -> void:
	"""Public policy changes and released rows retain the existing reader contract."""
	var owner: Priorities = Priorities.new()
	assert_false(owner.inactive_row_is_clear(-1),"negative slot refused")
	assert_false(owner.inactive_row_is_clear(512),"high slot refused")
	for slot: int in [0,511]:
		assert_true(owner.inactive_row_is_clear(slot),"new row clear")
		assert_true(owner.spawn(slot).ok,"spawn")
		assert_false(owner.inactive_row_is_clear(slot),"present row is never inactive")
		assert_true(owner.set_priority(slot,1,4).ok,"player priority")
		assert_true(owner.set_auto_fallback(slot,false).ok,"player fallback")
		assert_true(owner.set_dangerous_work(slot,true).ok,"player consent")
	_expect(_from_owner(owner),&"")
	assert_equal(owner.present_count(),2,"validation cannot alter owner count")
	for slot: int in [0,511]:
		assert_true(owner.despawn(slot).ok,"release")
		assert_true(owner.inactive_row_is_clear(slot),"all released bytes clear")
	_expect(_from_owner(owner),&"")

func test_all_column_shapes_refuse_before_semantic_access() -> void:
	"""Each ordinal requires its exact extent in both static and framed validation."""
	for field: int in 4:
		for size: int in [0,COUNTS[field]-1,COUNTS[field]+1]:
			var image: Array[PackedByteArray] = _base()
			var bytes: PackedByteArray = image[field]
			bytes.resize(size)
			image[field] = bytes
			assert_equal(_predicate(image),&"COLUMN_SHAPE","static extent")
			var frame: Section.FramedOwner = _frame(_base())
			frame.u8_columns[field] = bytes
			assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","framed extent")

func test_null_wrong_owner_and_bucket_counts_refuse() -> void:
	"""Malformed framing stops before typed accessor arguments are evaluated."""
	assert_equal(Bridge.framed_refusal(null).code,&"SAVE_COMPONENT_SHAPE","null record")
	for owner: int in [-1,9,18]:
		assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(owner)).code,&"SAVE_COMPONENT_OWNER","wrong owner")
	for variant: int in 4:
		var frame: Section.FramedOwner = _frame(_base())
		if variant == 0: frame.u8_columns.pop_back()
		elif variant == 1: frame.u8_columns.append(PackedByteArray())
		elif variant == 2: frame.i32_columns.append(PackedInt32Array())
		else: frame.i64_columns.append(PackedInt64Array())
		assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","exact typed buckets")
