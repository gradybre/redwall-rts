extends "res://test/framework/test_case.gd"
const WorldInit := preload("res://scripts/core/world_init.gd")
const Bridge := preload("res://scripts/core/save_owner_world_init.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const KEYS: Array[String] = ["_fauna_zone_slot","_fauna_zone_generation","_fauna_species_id",
	"_fauna_population","_fauna_capacity","_fauna_tracks","_fauna_harvest_today",
	"_fauna_migration_link","_fauna_birth_remainder"]
const I64_MIN: int = -9223372036854775807-1
const I64_MAX: int = 9223372036854775807

func _empty() -> Array:
	"""Independent canonical constants; these are not a capture of private owner columns."""
	var columns: Array = []
	for field: int in 9:
		var values: Variant = (PackedInt64Array() as Variant) if field == 8 else (PackedInt32Array() as Variant)
		values.resize(384)
		if field == 0: values.fill(-1)
		columns.append(values)
	return columns

func _put(c: Array, field: int, row: int, value: int) -> void:
	"""Write packed values back explicitly into the outer fixture array."""
	var values: Variant = c[field]
	values[row] = value
	c[field] = values

func _predicate(c: Array) -> StringName:
	"""The eight i32 columns followed by one i64 column in canonical order."""
	return WorldInit.fauna_columns_refusal(c[0],c[1],c[2],c[3],c[4],c[5],c[6],c[7],c[8])

func _frame(c: Array) -> Section.FramedOwner:
	"""Copy every field and check each fixture assignment succeeds."""
	var frame: Section.FramedOwner = Section.FramedOwner.new(17)
	for field: int in 9:
		var copied: bool = frame.set_i64(field,c[field]) if field == 8 else frame.set_i32(field,c[field])
		assert_true(copied,"fixture setter%d" % field)
	return frame

func _expect(c: Array, code: StringName) -> void:
	"""Exact static/framed codes and complete input preservation on every result path."""
	var before: Array = []
	for values: Variant in c: before.append(values.duplicate())
	var frame: Section.FramedOwner = _frame(c)
	assert_equal(_predicate(c),code,"static exact code")
	var result: Variant = Bridge.framed_refusal(frame)
	assert_equal(result.code,code,"framed exact code")
	assert_equal(result.is_ok(),code == &"","success channel")
	if code == &"": assert_equal(result.detail,"","empty success detail")
	else:
		assert_true(result.detail.contains("WorldInit owner 17 "),"owner identity")
		assert_true(result.detail.contains(String(code)),"raw column code")
	for field: int in 9:
		assert_true(c[field] == before[field],"caller input unchanged")
		var held: Variant = (frame.i64_column(field) as Variant) if field == 8 else (frame.i32_column(field) as Variant)
		assert_true(held == before[field],"frame input unchanged")

func test_exact_layout_and_only_canonical_empty_image() -> void:
	"""The reserved image has null zone slots, not allzero wire defaults."""
	for field: int in 9:
		assert_equal(Schema.field_key(17,field),KEYS[field],"canonical field key")
		assert_equal(Schema.field_type(17,field),4 if field == 8 else 2,"canonical type")
		assert_equal(Schema.element_count(17,field),384,"physical reserved extent")
	_expect(_empty(),&"")
	assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(17)).code,&"COLUMN_FAUNA_RESERVED","zero frame is not canonical empty")

func test_each_argument_and_default_check_has_an_independent_witness() -> void:
	"""Each single-field defect distinguishes an omitted check or zero-default argument."""
	for field: int in 9:
		var c: Array = _empty()
		_put(c,field,0,0 if field == 0 else 1)
		_expect(c,&"COLUMN_FAUNA_RESERVED")
	_expect(_empty(),&"")

func test_every_reserved_row_in_every_field_is_checked() -> void:
	"""All 3456 positions are checked; no active-prefix or physical-tail shortcut is valid."""
	var c: Array = _empty()
	for field: int in 9:
		for row: int in 384:
			_put(c,field,row,0 if field == 0 else 1)
			assert_equal(_predicate(c),&"COLUMN_FAUNA_RESERVED","field%d row%d" % [field,row])
			_put(c,field,row,-1 if field == 0 else 0)
		_put(c,field,383,0 if field == 0 else 1)
		_expect(c,&"COLUMN_FAUNA_RESERVED")
		_put(c,field,383,-1 if field == 0 else 0)
	_expect(c,&"")

func test_signed_i32_and_i64_extrema_and_wide_values_refuse_unchanged() -> void:
	"""No retired value is interpreted or rounded, including values beyond float precision."""
	for field: int in 8:
		for value: int in [-2147483648,2147483647]:
			var c: Array = _empty()
			_put(c,field,383,value)
			_expect(c,&"COLUMN_FAUNA_RESERVED")
	for value: int in [I64_MIN,I64_MAX,-9007199254740993,9007199254740993,-1,1]:
		var c: Array = _empty()
		_put(c,8,383,value)
		_expect(c,&"COLUMN_FAUNA_RESERVED")

func test_reference_pair_and_numeric_defaults_remain_distinct() -> void:
	"""(-1,0) alone is the null reference; migration and every ordinary number stay zero."""
	for value: int in [-2,0,1]:
		var c: Array = _empty()
		_put(c,0,191,value)
		_expect(c,&"COLUMN_FAUNA_RESERVED")
	for field: int in range(1,9):
		var c: Array = _empty()
		_put(c,field,191,-1)
		_expect(c,&"COLUMN_FAUNA_RESERVED")

func test_all_nine_shapes_precede_reserved_value_checks() -> void:
	"""Every empty, short or long column refuses before a separate value defect."""
	for field: int in 9:
		for size: int in [0,383,385]:
			var c: Array = _empty()
			_put(c,0,0,0)
			var values: Variant = c[field]
			values.resize(size)
			c[field] = values
			assert_equal(_predicate(c),&"COLUMN_FAUNA_SHAPE","static extent before values")
			var frame: Section.FramedOwner = _frame(_empty())
			var index: int = Schema.storage_index(17,field)
			if field == 8: frame.i64_columns[index] = values
			else: frame.i32_columns[index] = values
			assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","framed extent")
	var short_birth: Array = _empty()
	var birth: PackedInt64Array = short_birth[8]
	birth.resize(383)
	short_birth[8] = birth
	assert_equal(_predicate(short_birth),&"COLUMN_FAUNA_SHAPE","i64 shape omission oracle with no other fault")

func test_null_owner_and_typed_bucket_guards() -> void:
	"""No malformed frame can enter the owner predicate."""
	assert_equal(Bridge.framed_refusal(null).code,&"SAVE_COMPONENT_SHAPE","null frame")
	for owner: int in [-1,16,18]:
		assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(owner)).code,&"SAVE_COMPONENT_OWNER","wrong owner")
	for variant: int in 5:
		var frame: Section.FramedOwner = _frame(_empty())
		if variant == 0: frame.i32_columns.pop_back()
		elif variant == 1: frame.i64_columns.pop_back()
		elif variant == 2: frame.i32_columns.append(PackedInt32Array())
		elif variant == 3: frame.i64_columns.append(PackedInt64Array())
		else: frame.u8_columns.append(PackedByteArray())
		assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","bucket mismatch")

func test_actual_owner_readers_and_section1_diagnostics_are_preserved() -> void:
	"""Allocation-only fixture; real generation preservation also runs in test_world_init.gd."""
	var owner: WorldInit = WorldInit.new(null,null,null,null,null)
	assert_equal(owner.fauna_row_capacity(),384,"actual reserved rows")
	assert_equal(owner.fauna_reserved_bytes(),15360,"actual reserved packed bytes")
	assert_true(owner.fauna_is_canonically_empty(),"actual shared empty reader")
	for row: int in 384: assert_equal(owner.fauna_zone_ref_of(row),Vector2i(-1,0),"actual null ref")
	assert_equal(owner.fauna_zone_ref_of(-1),Vector2i(-1,0),"negative reader address")
	assert_equal(owner.fauna_zone_ref_of(384),Vector2i(-1,0),"high reader address")
	var map: WorldInit.SavedMap = WorldInit.SavedMap.new()
	assert_equal(owner.section_1_local_refusal(2,0,map),WorldInit.COLUMN_REFUSE_PUBLISHED_FLAG,"establish real section1 refusal")
	var code: StringName = owner.section_1_code()
	var detail: String = owner.section_1_detail()
	var published: bool = owner.section_1_is_published()
	var seed_value: int = owner.section_1_published_seed()
	_expect(_empty(),&"")
	var invalid: Array = _empty()
	_put(invalid,8,0,I64_MAX)
	_expect(invalid,&"COLUMN_FAUNA_RESERVED")
	assert_true(owner.fauna_is_canonically_empty(),"shared reader still empty")
	assert_equal(owner.section_1_code(),code,"no section1 code write")
	assert_equal(owner.section_1_detail(),detail,"no section1 detail write")
	assert_equal(owner.section_1_is_published(),published,"no publication")
	assert_equal(owner.section_1_published_seed(),seed_value,"no seed mutation")


# --- ADR 1222 step 2: bulk capture and apply ------------------------------------------------------

func _live_owner() -> WorldInit:
	"""A freshly allocated store: REQ-SET-059 has no mutator, so this is its only reachable image."""
	return WorldInit.new(null,null,null,null,null)


func _image(owner: WorldInit) -> WorldInit.FaunaColumns:
	"""The owner's nine reserved fauna columns through the bulk reader."""
	var columns: WorldInit.FaunaColumns = WorldInit.FaunaColumns.new()
	assert_true(owner.copy_fauna_columns_into(columns),"bulk copy succeeds")
	return columns


func test_capture_then_apply_into_a_fresh_store_is_exact_and_continues_identically() -> void:
	"""The restored store holds the same nine columns, and answers the next reads the same way."""
	var source: WorldInit = _live_owner()
	var frame: Section.FramedOwner = Section.FramedOwner.new(17)
	assert_true(Bridge.capture_into(source,frame).is_ok(),"capture succeeds")
	var target: WorldInit = WorldInit.new(null,null,null,null,null)
	assert_true(Bridge.apply(frame,target).is_ok(),"apply succeeds")
	assert_true(_image(target).equals(_image(source)),"columns are byte-identical")
	for store: WorldInit in [source,target]:
		assert_true(store.fauna_is_canonically_empty(),"still canonically empty")
		assert_equal(store.fauna_zone_ref_of(0),Vector2i(-1,0),"a later read agrees")
	assert_true(_image(target).equals(_image(source)),"both stores stayed identical")


func test_capture_matches_the_public_reader_projection() -> void:
	"""The captured record equals the projection built only from the public per-row reader."""
	var source: WorldInit = _live_owner()
	var frame: Section.FramedOwner = Section.FramedOwner.new(17)
	assert_true(Bridge.capture_into(source,frame).is_ok(),"capture succeeds")
	var witness: Array = _empty()
	for field: int in 9:
		var held: Variant = (frame.i64_column(field) as Variant) if field == 8 \
			else (frame.i32_column(field) as Variant)
		assert_true(held == witness[field],"field %d matches the canonical empty image" % field)


func test_every_column_refusal_leaves_the_target_byte_identical() -> void:
	"""Each column code refuses through apply with the exact code and writes nothing."""
	var target: WorldInit = _live_owner()
	var before: WorldInit.FaunaColumns = _image(target)
	for field: int in 9:
		var image: Array = _empty()
		_put(image,field,0,0 if field == 0 else 1)
		assert_equal(Bridge.apply(_frame(image),target).code,&"COLUMN_FAUNA_RESERVED",
			"exact code for field %d" % field)
	assert_true(_image(target).equals(before),"no refusal wrote a column")


func test_null_and_misshaped_inputs_refuse_without_writing() -> void:
	"""Null stores, null records, a wrong owner and a short bulk buffer all refuse."""
	var target: WorldInit = _live_owner()
	var before: WorldInit.FaunaColumns = _image(target)
	assert_equal(Bridge.apply(_frame(_empty()),null).code,Bridge.REFUSE_NULL_STORE,"null store")
	assert_equal(Bridge.capture_into(null,Section.FramedOwner.new(17)).code,
		Bridge.REFUSE_NULL_STORE,"capture from no store")
	assert_equal(Bridge.capture_into(target,null).code,&"SAVE_COMPONENT_SHAPE","null record")
	assert_equal(Bridge.capture_into(target,Section.FramedOwner.new(16)).code,
		&"SAVE_COMPONENT_OWNER","wrong owner")
	var short: WorldInit.FaunaColumns = WorldInit.FaunaColumns.new()
	short.zone_slot.resize(3)
	assert_false(target.restore_fauna_columns(short),"a short column refuses")
	assert_equal(target.last_fauna_column_refusal(),WorldInit.REFUSE_COLUMN_FAUNA_SHAPE,"shape code")
	assert_false(target.copy_fauna_columns_into(short),"a short output buffer refuses")
	assert_false(target.restore_fauna_columns(null),"null columns refuse")
	assert_true(_image(target).equals(before),"nothing was written")
