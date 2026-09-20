extends "res://test/framework/test_case.gd"
const Residents := preload("res://scripts/core/residents.gd")
const Bridge := preload("res://scripts/core/save_owner_residents.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const MAX_I64: int = 9223372036854775807
const MIN_I64: int = -9223372036854775807 - 1
const FIELDS: Array[String] = ["present","species","size_class","named","life_stage","arrival_tick","role","home_slot","home_generation","bed_slot","bed_generation","ref_slot","ref_generation","equip_tool_item_id","equip_tool_durability","equip_satchel_slot","equip_satchel_generation","skill_xp","skill_level"]
const TYPES: Array[int] = [0,2,0,0,0,4,0,2,2,2,2,2,2,2,2,2,2,4,2]
const CODES: Array[StringName] = [&"COLUMN_PRESENT_BYTE",&"COLUMN_SPECIES",&"COLUMN_ENUM_BYTE",&"COLUMN_NAMED_BYTE",&"COLUMN_ENUM_BYTE",&"COLUMN_ARRIVAL_TICK",&"COLUMN_ENUM_BYTE",&"COLUMN_REF_SHAPE",&"COLUMN_REF_SHAPE",&"COLUMN_REF_SHAPE",&"COLUMN_REF_SHAPE",&"COLUMN_REF_SHAPE",&"COLUMN_REF_SHAPE",&"COLUMN_EQUIPMENT",&"COLUMN_EQUIPMENT",&"COLUMN_REF_SHAPE",&"COLUMN_REF_SHAPE",&"COLUMN_SKILL_XP",&"COLUMN_SKILL_LEVEL"]

func _put(c: Residents.Columns, field: int, row: int, value: int) -> void:
	var values: Variant = c.get(FIELDS[field])
	values[row] = value
	c.set(FIELDS[field],values)

func _copy(c: Residents.Columns) -> Residents.Columns:
	var out: Residents.Columns = Residents.Columns.new()
	for key: String in FIELDS: out.set(key,c.get(key).duplicate())
	return out

func _frame(c: Residents.Columns) -> Section.FramedOwner:
	var frame: Section.FramedOwner = Section.FramedOwner.new(12)
	for field: int in 19:
		var ok: bool
		if TYPES[field] == 0: ok = frame.set_u8(field,c.get(FIELDS[field]))
		elif TYPES[field] == 2: ok = frame.set_i32(field,c.get(FIELDS[field]))
		else: ok = frame.set_i64(field,c.get(FIELDS[field]))
		assert_true(ok,"canonical setter%d" % field)
	return frame

func _expect(c: Residents.Columns, code: StringName) -> void:
	var before: Residents.Columns = _copy(c)
	var frame: Section.FramedOwner = _frame(c)
	assert_equal(Residents.columns_refusal(c),code,"static exactcode")
	var result: Variant = Bridge.framed_refusal(frame)
	assert_equal(result.code,code,"bridge exactcode")
	assert_equal(result.is_ok(),code == &"","success channel")
	if code == &"": assert_equal(result.detail,"","success detail")
	else:
		assert_true(result.detail.contains("Residents owner 12 "),"owner detail")
		assert_true(result.detail.contains(String(code)),"raw code detail")
	assert_true(c.equals(before),"all nineteen input buffers unchanged")
	for field: int in 19:
		var held: Variant
		if TYPES[field] == 0: held = frame.u8_column(field)
		elif TYPES[field] == 2: held = frame.i32_column(field)
		else: held = frame.i64_column(field)
		assert_true(held == before.get(FIELDS[field]),"frame unchanged")

func _bad_value(field: int) -> int:
	if field == 0 or field == 3: return 2
	if field in [2,4,6]: return 3
	if field in [7,9,11,13,15]: return -2
	if field == 18: return 1
	return -1

func test_layout_defaults_and_every_projection_omission_witness() -> void:
	var c: Residents.Columns = Residents.Columns.new()
	_expect(c,&"")
	assert_equal(Schema.owner_version(12),2,"existing version")
	for field: int in 19:
		assert_equal(Schema.field_key(12,field),"_"+FIELDS[field],"canonical key")
		assert_equal(Schema.field_type(12,field),TYPES[field],"canonical type")
		assert_equal(Schema.element_count(12,field),6144 if field >= 17 else 512,"extent")
		c = Residents.Columns.new()
		c.present[511] = 1
		_put(c,field,6143 if field >= 17 else 511,_bad_value(field))
		_expect(c,CODES[field])
	# A valid tail resident exercises nondefault values, including all pair halves and skill data.
	c = Residents.Columns.new()
	c.present[511] = 1
	c.species[511] = 15
	c.size_class[511] = 2
	c.named[511] = 1
	c.life_stage[511] = 2
	c.arrival_tick[511] = MAX_I64
	c.role[511] = 2
	for field: int in [7,9,11,15]:
		_put(c,field,511,2147483647)
		_put(c,field+1,511,2147483647)
	c.equip_tool_item_id[511] = 2147483647
	c.equip_tool_durability[511] = 2147483647
	c.skill_xp[6143] = MAX_I64
	c.skill_level[6143] = 10
	_expect(c,&"")

func test_every_physical_scalar_and_skill_address() -> void:
	var c: Residents.Columns = Residents.Columns.new()
	for field: int in 19:
		var extent: int = 6144 if field >= 17 else 512
		for index: int in extent:
			var row: int = index / 12 if field >= 17 else index
			c.present[row] = 1
			var original: int = c.get(FIELDS[field])[index]
			_put(c,field,index,_bad_value(field))
			assert_equal(Residents.columns_refusal(c),CODES[field],"field%d address%d" % [field,index])
			assert_equal(c.get(FIELDS[field])[index],_bad_value(field),"predicate retains malformed value")
			_put(c,field,index,original)
			c.present[row] = 0
	_expect(c,&"")

func test_full_signed_inactive_history_and_present_species_arrival_domains() -> void:
	var c: Residents.Columns = Residents.Columns.new()
	c.species[0] = -2147483648
	c.species[511] = 2147483647
	c.arrival_tick[0] = MIN_I64
	c.arrival_tick[511] = MAX_I64
	c.size_class[511] = 2
	c.home_slot[511] = 2147483647
	c.home_generation[511] = 2147483647
	c.bed_slot[511] = 2147483647
	c.bed_generation[511] = 2147483647
	c.skill_xp[6143] = MAX_I64
	c.skill_level[6143] = 10
	_expect(c,&"")
	c = Residents.Columns.new()
	c.present[511] = 1
	for species: int in 16:
		c.species[511] = species
		_expect(c,&"")
	c.species[511] = 16
	_expect(c,&"COLUMN_SPECIES")
	c.species[511] = 0
	for tick: int in [MIN_I64,-1]:
		c.arrival_tick[511] = tick
		_expect(c,&"COLUMN_ARRIVAL_TICK")
	for tick: int in [0,MAX_I64]:
		c.arrival_tick[511] = tick
		_expect(c,&"")

func test_curve_boundaries_reserved_skills_and_present_cap() -> void:
	var store: Residents = Residents.new()
	var c: Residents.Columns = Residents.Columns.new()
	var xps: Array[int] = [0,4999,5000,19999,20000,499999,500000,MAX_I64]
	var levels: Array[int] = [0,0,1,1,2,9,10,10]
	for i: int in xps.size():
		assert_equal(store.skill_level_for_xp(xps[i]),levels[i],"existing public curve")
		c.skill_xp[6143] = xps[i]
		c.skill_level[6143] = levels[i]
		_expect(c,&"")
	c.skill_level[6143] = 11
	_expect(c,&"COLUMN_SKILL_LEVEL")
	c = Residents.Columns.new()
	c.skill_xp[511*12+3] = 5000
	c.skill_level[511*12+3] = 1
	_expect(c,&"COLUMN_RESERVED_SKILL")
	c = Residents.Columns.new()
	for row: int in 256: c.present[row] = 1
	_expect(c,&"")
	c.present[511] = 1
	_expect(c,&"COLUMN_LIVING_CAP")

func test_reference_shapes_equipment_and_each_free_row_rule() -> void:
	for field: int in [7,9,11,15]:
		for pair: Vector2i in [Vector2i(-2,0),Vector2i(-1,1),Vector2i(0,0),Vector2i(0,-1)]:
			var c: Residents.Columns = Residents.Columns.new()
			c.present[511] = 1
			_put(c,field,511,pair.x)
			_put(c,field+1,511,pair.y)
			_expect(c,&"COLUMN_REF_SHAPE")
	for pair: Vector2i in [Vector2i(-2,0),Vector2i(0,-1),Vector2i(-1,1)]:
		var c: Residents.Columns = Residents.Columns.new()
		c.present[511] = 1
		c.equip_tool_item_id[511] = pair.x
		c.equip_tool_durability[511] = pair.y
		_expect(c,&"COLUMN_EQUIPMENT")
	for field: int in [3,4,6,11,13,15]:
		var c: Residents.Columns = Residents.Columns.new()
		_put(c,field,511,0 if field in [11,13,15] else 1)
		if field == 11 or field == 15: _put(c,field+1,511,1)
		_expect(c,&"COLUMN_FREE_ROW")

func test_shapes_null_records_and_typed_bucket_counts() -> void:
	assert_equal(Residents.columns_refusal(null),&"COLUMN_SHAPE","null columns")
	assert_equal(Bridge.framed_refusal(null).code,&"SAVE_COMPONENT_SHAPE","null record")
	for owner: int in [-1,11,13,18]:
		assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(owner)).code,&"SAVE_COMPONENT_OWNER","wrongowner")
	for field: int in 19:
		var extent: int = 6144 if field >= 17 else 512
		for size: int in [0,extent-1,extent+1]:
			var c: Residents.Columns = Residents.Columns.new()
			c.present[0] = 2
			var values: Variant = c.get(FIELDS[field])
			values.resize(size)
			c.set(FIELDS[field],values)
			assert_equal(Residents.columns_refusal(c),&"COLUMN_SHAPE","shape before values")
			var frame: Section.FramedOwner = _frame(Residents.Columns.new())
			var index: int = Schema.storage_index(12,field)
			if TYPES[field] == 0: frame.u8_columns[index] = values
			elif TYPES[field] == 2: frame.i32_columns[index] = values
			else: frame.i64_columns[index] = values
			assert_equal(Bridge.framed_refusal(frame).code,&"SAVE_COMPONENT_SHAPE","framed shape first")
	for kind: int in 3:
		for extra: bool in [false,true]:
			var frame: Section.FramedOwner = _frame(Residents.Columns.new())
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

func test_saved_per_row_priority_and_prefix_refusal_order() -> void:
	var c: Residents.Columns = Residents.Columns.new()
	c.present[0] = 1
	c.present[511] = 1
	c.arrival_tick[0] = -1
	c.species[511] = -1
	_expect(c,&"COLUMN_ARRIVAL_TICK")
	c.species[0] = -1
	_expect(c,&"COLUMN_SPECIES")
	c = Residents.Columns.new()
	c.present[511] = 2
	c.named[0] = 2
	_expect(c,&"COLUMN_PRESENT_BYTE")
	c = Residents.Columns.new()
	c.named[511] = 2
	c.size_class[0] = 3
	_expect(c,&"COLUMN_NAMED_BYTE")
	c = Residents.Columns.new()
	c.home_slot[511] = -2
	c.skill_xp[0] = -1
	_expect(c,&"COLUMN_SKILL_XP")
	c = Residents.Columns.new()
	c.equip_tool_item_id[0] = -2
	c.home_slot[511] = -2
	_expect(c,&"COLUMN_EQUIPMENT")
	c = Residents.Columns.new()
	c.named[511] = 1
	for row: int in 257: c.present[row] = 1
	_expect(c,&"COLUMN_FREE_ROW")

func test_public_arrival_refusals_null_safety_and_capture_restore() -> void:
	var store: Residents = Residents.new()
	var created: Residents.OpResult = store.spawn(&"mouse")
	assert_true(created.ok,"real public resident")
	var row: int = created.value
	for tick: int in [0,MAX_I64]:
		assert_true(store.set_arrival_tick(row,tick).ok,"public legal arrival")
	for tick: int in [-1,MIN_I64]:
		var before: PackedByteArray = store.state_bytes()
		var result: Residents.OpResult = store.set_arrival_tick(row,tick)
		assert_false(result.ok,"public negative refuses")
		assert_equal(result.error,&"INVALID_ARRIVAL_TICK","producer namespace")
		assert_equal(store.state_bytes(),before,"producer refusal atomic")
	assert_equal(store.set_arrival_tick(511,-1).error,&"RESIDENT_NOT_PRESENT","presence first")
	var before: PackedByteArray = store.state_bytes()
	assert_false(store.copy_columns_into(null),"null capture")
	assert_equal(store.last_column_refusal(),&"COLUMN_SHAPE","capture diagnostic")
	assert_false(store.restore_columns(null),"null restore")
	assert_equal(store.last_column_refusal(),&"COLUMN_SHAPE","restore diagnostic")
	assert_equal(store.state_bytes(),before,"null operations atomic")
	var c: Residents.Columns = Residents.Columns.new()
	assert_true(store.copy_columns_into(c),"actual public capture")
	_expect(c,&"")
	assert_true(store.restore_columns(c),"existing restore agrees")
	assert_true(store.despawn(store.ref_of(row)).ok,"release")
	assert_true(store.copy_columns_into(c),"free history capture")
	# Explicit saved history fixture, not newly produced by the repaired setter.
	c.arrival_tick[row] = MIN_I64
	assert_true(store.restore_columns(c),"legacy inactive negative history remains legal")
	var restored: Residents.Columns = Residents.Columns.new()
	assert_true(store.copy_columns_into(restored),"capture retained history")
	assert_true(c.equals(restored),"all nineteen fields preserved")
	_expect(restored,&"")

func test_legacy_live_row_priority_remains_species_size_arrival_directory() -> void:
	var store: Residents = Residents.new()
	assert_true(store.spawn(&"mouse").ok,"first real resident")
	assert_true(store.spawn(&"mouse").ok,"second real resident")
	var base: Residents.Columns = Residents.Columns.new()
	assert_true(store.copy_columns_into(base),"real columns")
	var before: PackedByteArray = store.state_bytes()
	var c: Residents.Columns = _copy(base)
	c.size_class[0] = 1
	c.arrival_tick[1] = -1
	assert_false(store.restore_columns(c),"first row catalog size wins")
	assert_equal(store.last_column_refusal(),&"COLUMN_SIZE_CLASS_MISMATCH","legacy size priority")
	c = _copy(base)
	c.ref_slot[0] = 2147483647
	c.ref_generation[0] = 1
	c.species[1] = -1
	assert_false(store.restore_columns(c),"first row Directory wins")
	assert_equal(store.last_column_refusal(),&"COLUMN_DIRECTORY_REF","legacy directory priority")
	c = _copy(base)
	c.species[0] = -1
	c.size_class[0] = 1
	c.arrival_tick[0] = -1
	c.ref_slot[0] = 2147483647
	assert_false(store.restore_columns(c),"same row species first")
	assert_equal(store.last_column_refusal(),&"COLUMN_SPECIES","species priority")
	c.species[0] = base.species[0]
	assert_false(store.restore_columns(c),"same row size before arrival")
	assert_equal(store.last_column_refusal(),&"COLUMN_SIZE_CLASS_MISMATCH","size priority")
	c.size_class[0] = base.size_class[0]
	assert_false(store.restore_columns(c),"same row arrival before Directory")
	assert_equal(store.last_column_refusal(),&"COLUMN_ARRIVAL_TICK","arrival priority")
	assert_equal(store.state_bytes(),before,"all refused live attempts preserve state")
