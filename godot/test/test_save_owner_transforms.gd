extends "res://test/framework/test_case.gd"
const Transforms := preload("res://scripts/core/transforms.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Bridge := preload("res://scripts/core/save_owner_transforms.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const COUNT: int = 87552
const KEYS: Array[String] = ["_bound_persistent_id","_x","_y","_z","_yaw","_prev_x","_prev_y","_prev_z","_prev_yaw"]
const BOUNDARIES: Array[int] = [0,1023,1024,82943,82944,83455,83456,87551]

func _empty() -> Array[PackedInt32Array]:
	"""Independent exact zero fixture for all nine canonical fields."""
	var columns: Array[PackedInt32Array] = []
	for field: int in 9:
		var values: PackedInt32Array = PackedInt32Array()
		values.resize(COUNT)
		columns.append(values)
	return columns

func _put(columns: Array[PackedInt32Array], field: int, row: int, value: int) -> void:
	"""Explicit writeback avoids fixture assumptions about packed Array subscript copies."""
	var values: PackedInt32Array = columns[field]
	values[row] = value
	columns[field] = values

func _predicate(c: Array[PackedInt32Array]) -> StringName:
	"""Canonical binding-first order, independent of the diagnostic byte order."""
	return Transforms.columns_refusal(c[0],c[1],c[2],c[3],c[4],c[5],c[6],c[7],c[8])

func _frame(c: Array[PackedInt32Array]) -> Section.FramedOwner:
	"""Construct a frame with all nine successful typed assignments."""
	var frame: Section.FramedOwner = Section.FramedOwner.new(15)
	for field: int in 9: assert_true(frame.set_i32(field,c[field]),"fixture setter%d" % field)
	return frame

func _expect(c: Array[PackedInt32Array], code: StringName) -> void:
	"""Exact codes and nonmutation on static and framed paths, including sort-copy safety."""
	var before: Array[PackedInt32Array] = []
	for values: PackedInt32Array in c: before.append(values.duplicate())
	var frame: Section.FramedOwner = _frame(c)
	assert_equal(_predicate(c),code,"static exactcode")
	var result: Variant = Bridge.framed_refusal(frame)
	assert_equal(result.code,code,"framed exactcode")
	assert_equal(result.is_ok(),code == &"","success channel")
	if code == &"": assert_equal(result.detail,"","empty success detail")
	else:
		assert_true(result.detail.contains("Transforms owner 15 "),"owner identity")
		assert_true(result.detail.contains(String(code)),"raw column code")
	for field: int in 9:
		assert_true(c[field] == before[field],"caller column unchanged%d" % field)
		assert_true(frame.i32_column(field) == before[field],"framed column unchanged%d" % field)

func _from_owner(owner: Transforms) -> Array[PackedInt32Array]:
	"""Explicitly remap public diagnostic poses-first/binding-last into binding-first schema."""
	var bytes: PackedByteArray = owner.state_bytes()
	assert_equal(bytes.size(),3151872,"public diagnostic extent")
	var c: Array[PackedInt32Array] = _empty()
	for field: int in 9:
		var diagnostic: int = 8 if field == 0 else field-1
		c[field] = bytes.slice(diagnostic*COUNT*4,(diagnostic+1)*COUNT*4).to_int32_array()
	return c

func test_exact_canonical_layout_and_empty_frame() -> void:
	"""Allzero is a valid empty Transform, with nine separately pinned i32 fields."""
	for field: int in 9:
		assert_equal(Schema.field_key(15,field),KEYS[field],"canonical field key")
		assert_equal(Schema.field_type(15,field),2,"canonical signed type")
		assert_equal(Schema.element_count(15,field),COUNT,"full physical extent")
	_expect(_empty(),&"")
	assert_true(Bridge.framed_refusal(Section.FramedOwner.new(15)).is_ok(),"zero frame accepted")

func test_nine_independent_argument_omission_witnesses() -> void:
	"""Allzero replacement of each argument changes its exact expected result."""
	var c: Array[PackedInt32Array] = _empty()
	_put(c,0,0,-1)
	_expect(c,&"COLUMN_BINDING_ID")
	for field: int in range(1,9):
		c = _empty()
		_put(c,field,0,1)
		_expect(c,&"COLUMN_FREE_ROW")
	c = _empty()
	_put(c,0,0,1)
	_put(c,1,0,17)
	_expect(c,&"")

func test_full_signed_pose_domain_and_independent_previous_history() -> void:
	"""Neither signed extrema nor yaw outside one turn may be normalized or rejected."""
	var c: Array[PackedInt32Array] = _empty()
	_put(c,0,0,2147483647)
	for field: int in range(1,9): _put(c,field,0,-2147483648 if field%2 == 1 else 2147483647)
	_expect(c,&"")
	for field: int in range(1,9): _put(c,field,0,2147483647 if field%2 == 1 else -2147483648)
	_expect(c,&"")
	_put(c,1,0,11)
	_put(c,5,0,23)
	_put(c,4,0,-65537)
	_put(c,8,0,131073)
	_expect(c,&"")

func test_all_pose_fields_at_physical_and_kind_boundaries() -> void:
	"""Every free-pose field is checked across the entire positioned arena, not residents only."""
	for row: int in BOUNDARIES:
		for field: int in range(1,9):
			var c: Array[PackedInt32Array] = _empty()
			_put(c,field,row,1 if field%2 == 0 else -1)
			_expect(c,&"COLUMN_FREE_ROW")

func test_binding_sign_uniqueness_and_repeated_zero_rules() -> void:
	"""Negative IDs refuse globally; duplicate positives refuse; any number of zeros is legal."""
	for value: int in [-1,-2147483648]:
		var c: Array[PackedInt32Array] = _empty()
		_put(c,0,COUNT-1,value)
		_expect(c,&"COLUMN_BINDING_ID")
	for value: int in [1,17,2147483647]:
		var c: Array[PackedInt32Array] = _empty()
		_put(c,0,0,value)
		_put(c,0,COUNT-1,value)
		_expect(c,&"COLUMN_BINDING_DUPLICATE")
		_put(c,0,0,0)
		_expect(c,&"")

func test_unsorted_unique_stamps_preserve_order_and_all87552rows_accept() -> void:
	"""Sorting must touch only a private duplicate, and no living-population cap applies."""
	var c: Array[PackedInt32Array] = _empty()
	var ids: PackedInt32Array = c[0]
	for row: int in COUNT: ids[row] = COUNT-row
	c[0] = ids
	_put(c,1,COUNT-1,-2147483648)
	_put(c,8,COUNT-1,2147483647)
	_expect(c,&"")
	assert_equal(c[0][0],COUNT,"descending first stamp retained")
	assert_equal(c[0][COUNT-1],1,"descending last stamp retained")

func test_global_refusal_order_with_paired_distinct_faults() -> void:
	"""Later-row earlier gates win, including the two non-equivalent order-mutant witnesses."""
	var c: Array[PackedInt32Array] = _empty()
	_put(c,1,0,1)
	_expect(c,&"COLUMN_FREE_ROW")
	_put(c,0,1,17)
	_put(c,0,COUNT-1,17)
	_expect(c,&"COLUMN_BINDING_DUPLICATE")
	_put(c,0,1024,-1)
	_expect(c,&"COLUMN_BINDING_ID")

func test_public_history_retained_stamps_and_diagnostic_order() -> void:
	"""Use actual owner APIs; stale stamps, poses and refusal diagnostics survive validation."""
	var directory: Directory = Directory.new()
	var owner: Transforms = Transforms.new(directory)
	var first: Vector2i = directory.create(Directory.KIND_RESIDENT)
	var row: int = 82944+directory.get_typed_row(first)
	var pid: int = directory.get_persistent_id(first)
	assert_true(owner.place(first,11,22,33,44),"place")
	assert_true(owner.advance(first,55,66,77),"advance")
	assert_true(owner.set_yaw(first,88),"set yaw")
	var c: Array[PackedInt32Array] = _from_owner(owner)
	var expected: Array[int] = [pid,55,66,77,88,11,22,33,44]
	for field: int in 9: assert_equal(c[field][row],expected[field],"explicit diagnostic remap%d" % field)
	_expect(c,&"")
	var before: PackedByteArray = owner.state_bytes()
	var pose: Transforms.PresentationPose = Transforms.PresentationPose.new()
	assert_true(owner.presentation_interpolate_into(first,1,2,pose),"presentation interpolation")
	assert_true(owner.state_bytes() == before,"presentation leaves canonical history")
	assert_true(directory.destroy(first),"destroy through Directory")
	var second: Vector2i = directory.create(Directory.KIND_RESIDENT)
	assert_false(owner.is_bound(second),"successor is unplaced")
	assert_false(owner.place(first,1,2,3,4),"stale placement refuses")
	var refusal: StringName = owner.last_refusal()
	var digest: int = owner.authoritative_digest()
	_expect(_from_owner(owner),&"")
	assert_equal(owner.last_refusal(),refusal,"validation leaves last live refusal")
	assert_equal(owner.bound_count(),1,"retained stamp remains counted")
	assert_equal(owner.authoritative_digest(),digest,"validation leaves owner digest")
	assert_true(owner.state_bytes() == before,"all stale bytes preserved")
	assert_true(owner.place(second,-1,-2,-3,-4),"replace predecessor")
	assert_equal(owner.bound_count(),1,"replacement no doublecount")
	_expect(_from_owner(owner),&"")
	assert_true(owner.unbind(second),"unbind")
	assert_equal(owner.bound_count(),0,"zero stored stamps")
	_expect(_from_owner(owner),&"")

func test_every_shape_before_values_and_bucket_guards() -> void:
	"""All nine extents and typed bucket cardinalities refuse before indexing."""
	for field: int in 9:
		for size: int in [0,COUNT-1,COUNT+1]:
			var c: Array[PackedInt32Array] = _empty()
			_put(c,0,0,-1)
			var values: PackedInt32Array = c[field]
			values.resize(size)
			c[field] = values
			assert_equal(_predicate(c),&"COLUMN_SHAPE","static field extent")
			var frame: Section.FramedOwner = Section.FramedOwner.new(15)
			frame.i32_columns[field] = values
			assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","frame field extent")
	assert_equal(Bridge.framed_refusal(null).code,&"SAVE_COMPONENT_SHAPE","null")
	for owner: int in [-1,14,18]: assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(owner)).code,&"SAVE_COMPONENT_OWNER","wrong owner")
	for variant: int in 4:
		var frame: Section.FramedOwner = Section.FramedOwner.new(15)
		if variant == 0: frame.i32_columns.pop_back()
		elif variant == 1: frame.i32_columns.append(PackedInt32Array())
		elif variant == 2: frame.u8_columns.append(PackedByteArray())
		else: frame.i64_columns.append(PackedInt64Array())
		assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","bucket mismatch")
