extends "res://test/framework/test_case.gd"
const Owner := preload("res://scripts/core/movement.gd")
const Bridge := preload("res://scripts/core/save_owner_movement.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const FIELDS: Array[String] = ["vx", "vz", "remainder_x", "remainder_z", "next_x", "next_z", "correction_x", "correction_z", "radius_u", "desired_yaw", "next_yaw", "grid_next", "grid_cell", "speed_u_per_s", "movement_phase", "blocked_ticks"]
const CASES: Array = [
	["accept-clear", "clear", [], ""],
	["accept-stopped", "stopped", [], ""],
	["accept-travel", "travel", [], ""],
	["accept-arrived", "arrived", [], ""],
	["accept-one-cell-arrived", "one-cell-arrived", [], ""],
	["accept-lost", "lost", [], ""],
	["accept-profile-stale", "profile-stale", [], ""],
	["accept-contact-stale", "contact-stale", [], ""],
	["phase--1", "travel", [["movement_phase", 511, -1]], "COLUMN_PHASE"],
	["phase-6", "travel", [["movement_phase", 511, 6]], "COLUMN_PHASE"],
	["phase-2147483647", "travel", [["movement_phase", 511, 2147483647]], "COLUMN_PHASE"],
	["correction_x--1", "travel", [["correction_x", 511, -1]], "COLUMN_RESERVED"],
	["correction_x-1", "travel", [["correction_x", 511, 1]], "COLUMN_RESERVED"],
	["correction_x-2147483647", "travel", [["correction_x", 511, 2147483647]], "COLUMN_RESERVED"],
	["correction_z--1", "travel", [["correction_z", 511, -1]], "COLUMN_RESERVED"],
	["correction_z-1", "travel", [["correction_z", 511, 1]], "COLUMN_RESERVED"],
	["correction_z-2147483647", "travel", [["correction_z", 511, 2147483647]], "COLUMN_RESERVED"],
	["radius_u--1", "travel", [["radius_u", 511, -1]], "COLUMN_RESERVED"],
	["radius_u-1", "travel", [["radius_u", 511, 1]], "COLUMN_RESERVED"],
	["radius_u-2147483647", "travel", [["radius_u", 511, 2147483647]], "COLUMN_RESERVED"],
	["desired_yaw--1", "travel", [["desired_yaw", 511, -1]], "COLUMN_RESERVED"],
	["desired_yaw-1", "travel", [["desired_yaw", 511, 1]], "COLUMN_RESERVED"],
	["desired_yaw-2147483647", "travel", [["desired_yaw", 511, 2147483647]], "COLUMN_RESERVED"],
	["next_yaw--1", "travel", [["next_yaw", 511, -1]], "COLUMN_RESERVED"],
	["next_yaw-1", "travel", [["next_yaw", 511, 1]], "COLUMN_RESERVED"],
	["next_yaw-2147483647", "travel", [["next_yaw", 511, 2147483647]], "COLUMN_RESERVED"],
	["blocked_ticks--1", "travel", [["blocked_ticks", 511, -1]], "COLUMN_RESERVED"],
	["blocked_ticks-1", "travel", [["blocked_ticks", 511, 1]], "COLUMN_RESERVED"],
	["blocked_ticks-2147483647", "travel", [["blocked_ticks", 511, 2147483647]], "COLUMN_RESERVED"],
	["remainder_x--1", "travel", [["remainder_x", 511, -1]], "COLUMN_REMAINDER"],
	["remainder_x-420", "travel", [["remainder_x", 511, 420]], "COLUMN_REMAINDER"],
	["remainder_x-2147483647", "travel", [["remainder_x", 511, 2147483647]], "COLUMN_REMAINDER"],
	["remainder_x-accepted-0", "travel", [["remainder_x", 511, 0]], ""],
	["remainder_x-accepted-419", "travel", [["remainder_x", 511, 419]], ""],
	["remainder_z--1", "travel", [["remainder_z", 511, -1]], "COLUMN_REMAINDER"],
	["remainder_z-420", "travel", [["remainder_z", 511, 420]], "COLUMN_REMAINDER"],
	["remainder_z-2147483647", "travel", [["remainder_z", 511, 2147483647]], "COLUMN_REMAINDER"],
	["remainder_z-accepted-0", "travel", [["remainder_z", 511, 0]], ""],
	["remainder_z-accepted-419", "travel", [["remainder_z", 511, 419]], ""],
	["speed--1", "travel", [["speed_u_per_s", 511, -1]], "COLUMN_SPEED"],
	["speed-1", "travel", [["speed_u_per_s", 511, 1]], "COLUMN_SPEED"],
	["speed-3071", "travel", [["speed_u_per_s", 511, 3071]], "COLUMN_SPEED"],
	["speed-3073", "travel", [["speed_u_per_s", 511, 3073]], "COLUMN_SPEED"],
	["speed-3276", "travel", [["speed_u_per_s", 511, 3276]], "COLUMN_SPEED"],
	["speed-3278", "travel", [["speed_u_per_s", 511, 3278]], "COLUMN_SPEED"],
	["speed-4095", "travel", [["speed_u_per_s", 511, 4095]], "COLUMN_SPEED"],
	["speed-4097", "travel", [["speed_u_per_s", 511, 4097]], "COLUMN_SPEED"],
	["speed-2147483647", "travel", [["speed_u_per_s", 511, 2147483647]], "COLUMN_SPEED"],
	["3277-vx--111", "travel", [["speed_u_per_s", 511, 3277], ["vx", 511, -111]], "COLUMN_VELOCITY"],
	["3277-vx--110", "travel", [["speed_u_per_s", 511, 3277], ["vx", 511, -110]], ""],
	["3277-vx-110", "travel", [["speed_u_per_s", 511, 3277], ["vx", 511, 110]], ""],
	["3277-vx-111", "travel", [["speed_u_per_s", 511, 3277], ["vx", 511, 111]], "COLUMN_VELOCITY"],
	["3277-vx--2147483648", "travel", [["speed_u_per_s", 511, 3277], ["vx", 511, -2147483648]], "COLUMN_VELOCITY"],
	["3277-vx-2147483647", "travel", [["speed_u_per_s", 511, 3277], ["vx", 511, 2147483647]], "COLUMN_VELOCITY"],
	["3277-vz--111", "travel", [["speed_u_per_s", 511, 3277], ["vz", 511, -111]], "COLUMN_VELOCITY"],
	["3277-vz--110", "travel", [["speed_u_per_s", 511, 3277], ["vz", 511, -110]], ""],
	["3277-vz-110", "travel", [["speed_u_per_s", 511, 3277], ["vz", 511, 110]], ""],
	["3277-vz-111", "travel", [["speed_u_per_s", 511, 3277], ["vz", 511, 111]], "COLUMN_VELOCITY"],
	["3277-vz--2147483648", "travel", [["speed_u_per_s", 511, 3277], ["vz", 511, -2147483648]], "COLUMN_VELOCITY"],
	["3277-vz-2147483647", "travel", [["speed_u_per_s", 511, 3277], ["vz", 511, 2147483647]], "COLUMN_VELOCITY"],
	["4096-vx--138", "travel", [["speed_u_per_s", 511, 4096], ["vx", 511, -138]], "COLUMN_VELOCITY"],
	["4096-vx--137", "travel", [["speed_u_per_s", 511, 4096], ["vx", 511, -137]], ""],
	["4096-vx-137", "travel", [["speed_u_per_s", 511, 4096], ["vx", 511, 137]], ""],
	["4096-vx-138", "travel", [["speed_u_per_s", 511, 4096], ["vx", 511, 138]], "COLUMN_VELOCITY"],
	["4096-vx--2147483648", "travel", [["speed_u_per_s", 511, 4096], ["vx", 511, -2147483648]], "COLUMN_VELOCITY"],
	["4096-vx-2147483647", "travel", [["speed_u_per_s", 511, 4096], ["vx", 511, 2147483647]], "COLUMN_VELOCITY"],
	["4096-vz--138", "travel", [["speed_u_per_s", 511, 4096], ["vz", 511, -138]], "COLUMN_VELOCITY"],
	["4096-vz--137", "travel", [["speed_u_per_s", 511, 4096], ["vz", 511, -137]], ""],
	["4096-vz-137", "travel", [["speed_u_per_s", 511, 4096], ["vz", 511, 137]], ""],
	["4096-vz-138", "travel", [["speed_u_per_s", 511, 4096], ["vz", 511, 138]], "COLUMN_VELOCITY"],
	["4096-vz--2147483648", "travel", [["speed_u_per_s", 511, 4096], ["vz", 511, -2147483648]], "COLUMN_VELOCITY"],
	["4096-vz-2147483647", "travel", [["speed_u_per_s", 511, 4096], ["vz", 511, 2147483647]], "COLUMN_VELOCITY"],
	["3072-vx--104", "travel", [["speed_u_per_s", 511, 3072], ["vx", 511, -104]], "COLUMN_VELOCITY"],
	["3072-vx--103", "travel", [["speed_u_per_s", 511, 3072], ["vx", 511, -103]], ""],
	["3072-vx-103", "travel", [["speed_u_per_s", 511, 3072], ["vx", 511, 103]], ""],
	["3072-vx-104", "travel", [["speed_u_per_s", 511, 3072], ["vx", 511, 104]], "COLUMN_VELOCITY"],
	["3072-vx--2147483648", "travel", [["speed_u_per_s", 511, 3072], ["vx", 511, -2147483648]], "COLUMN_VELOCITY"],
	["3072-vx-2147483647", "travel", [["speed_u_per_s", 511, 3072], ["vx", 511, 2147483647]], "COLUMN_VELOCITY"],
	["3072-vz--104", "travel", [["speed_u_per_s", 511, 3072], ["vz", 511, -104]], "COLUMN_VELOCITY"],
	["3072-vz--103", "travel", [["speed_u_per_s", 511, 3072], ["vz", 511, -103]], ""],
	["3072-vz-103", "travel", [["speed_u_per_s", 511, 3072], ["vz", 511, 103]], ""],
	["3072-vz-104", "travel", [["speed_u_per_s", 511, 3072], ["vz", 511, 104]], "COLUMN_VELOCITY"],
	["3072-vz--2147483648", "travel", [["speed_u_per_s", 511, 3072], ["vz", 511, -2147483648]], "COLUMN_VELOCITY"],
	["3072-vz-2147483647", "travel", [["speed_u_per_s", 511, 3072], ["vz", 511, 2147483647]], "COLUMN_VELOCITY"],
	["grid_next--2", "travel", [["grid_next", 511, -2]], "COLUMN_CELL"],
	["grid_next-262144", "travel", [["grid_next", 511, 262144]], "COLUMN_CELL"],
	["grid_next-2147483647", "travel", [["grid_next", 511, 2147483647]], "COLUMN_CELL"],
	["grid_next--2147483648", "travel", [["grid_next", 511, -2147483648]], "COLUMN_CELL"],
	["grid_cell--2", "travel", [["grid_cell", 511, -2]], "COLUMN_CELL"],
	["grid_cell-262144", "travel", [["grid_cell", 511, 262144]], "COLUMN_CELL"],
	["grid_cell-2147483647", "travel", [["grid_cell", 511, 2147483647]], "COLUMN_CELL"],
	["grid_cell--2147483648", "travel", [["grid_cell", 511, -2147483648]], "COLUMN_CELL"],
	["next_x--1", "travel", [["next_x", 511, -1]], "COLUMN_TARGET"],
	["next_x-1", "travel", [["next_x", 511, 1]], "COLUMN_TARGET"],
	["next_x-255", "travel", [["next_x", 511, 255]], "COLUMN_TARGET"],
	["next_x-257", "travel", [["next_x", 511, 257]], "COLUMN_TARGET"],
	["next_x-262144", "travel", [["next_x", 511, 262144]], "COLUMN_TARGET"],
	["next_x-2147483647", "travel", [["next_x", 511, 2147483647]], "COLUMN_TARGET"],
	["next_x--2147483648", "travel", [["next_x", 511, -2147483648]], "COLUMN_TARGET"],
	["next_x-0", "travel", [["next_x", 511, 0]], "COLUMN_TARGET"],
	["next_z--1", "travel", [["next_z", 511, -1]], "COLUMN_TARGET"],
	["next_z-1", "travel", [["next_z", 511, 1]], "COLUMN_TARGET"],
	["next_z-255", "travel", [["next_z", 511, 255]], "COLUMN_TARGET"],
	["next_z-257", "travel", [["next_z", 511, 257]], "COLUMN_TARGET"],
	["next_z-262144", "travel", [["next_z", 511, 262144]], "COLUMN_TARGET"],
	["next_z-2147483647", "travel", [["next_z", 511, 2147483647]], "COLUMN_TARGET"],
	["next_z--2147483648", "travel", [["next_z", 511, -2147483648]], "COLUMN_TARGET"],
	["next_z-0", "travel", [["next_z", 511, 0]], "COLUMN_TARGET"],
	["map-last-cell", "travel", [["grid_next", 511, 262143], ["grid_cell", 511, 262143], ["next_x", 511, 261888], ["next_z", 511, 261888]], ""],
	["target-zero-travel", "travel", [["next_x", 511, 0], ["next_z", 511, 0]], "COLUMN_STATE"],
	["wrong-waypoint-centre", "travel", [["next_x", 511, 256]], "COLUMN_STATE"],
	["idle-vx", "stopped", [["vx", 511, 1]], "COLUMN_STATE"],
	["idle-vz", "stopped", [["vz", 511, 1]], "COLUMN_STATE"],
	["idle-remainder_x", "stopped", [["remainder_x", 511, 1]], "COLUMN_STATE"],
	["idle-remainder_z", "stopped", [["remainder_z", 511, 1]], "COLUMN_STATE"],
	["idle-grid_next", "stopped", [["grid_next", 511, 0]], "COLUMN_STATE"],
	["idle-valid-nonzero-target", "stopped", [["next_x", 511, 256], ["next_z", 511, 256]], "COLUMN_STATE"],
	["travel-state-speed_u_per_s", "travel", [["speed_u_per_s", 511, 0]], "COLUMN_STATE"],
	["travel-state-grid_cell", "travel", [["grid_cell", 511, -1]], "COLUMN_STATE"],
	["travel-state-grid_next", "travel", [["grid_next", 511, -1]], "COLUMN_STATE"],
	["arrived-state-speed_u_per_s", "one-cell-arrived", [["speed_u_per_s", 511, 0]], "COLUMN_STATE"],
	["arrived-state-grid_cell", "one-cell-arrived", [["grid_cell", 511, -1]], "COLUMN_STATE"],
	["arrived-state-grid_next", "one-cell-arrived", [["grid_next", 511, 0]], "COLUMN_STATE"],
	["arrived-wrong-retained-centre", "arrived", [["next_x", 511, 768]], "COLUMN_STATE"],
	["arrived-retained-fractions", "arrived", [["remainder_x", 511, 419], ["remainder_z", 511, 419]], ""],
	["lost-retained-fractions", "lost", [["remainder_x", 511, 419], ["remainder_z", 511, 419]], ""],
	["lost-bad-speed_u_per_s", "lost", [["speed_u_per_s", 511, 0]], "COLUMN_STATE"],
	["lost-bad-grid_cell", "lost", [["grid_cell", 511, -1]], "COLUMN_STATE"],
	["lost-bad-grid_next", "lost", [["grid_next", 511, 0]], "COLUMN_STATE"],
	["lost-bad-vx", "lost", [["vx", 511, 1]], "COLUMN_STATE"],
	["lost-bad-vz", "lost", [["vz", 511, -1]], "COLUMN_STATE"],
	["lost-zero-retained-target", "lost", [["next_x", 511, 0], ["next_z", 511, 0]], ""],
	["profile-stale-retained-fractions", "profile-stale", [["remainder_x", 511, 419], ["remainder_z", 511, 419]], ""],
	["profile-stale-bad-speed_u_per_s", "profile-stale", [["speed_u_per_s", 511, 0]], "COLUMN_STATE"],
	["profile-stale-bad-grid_cell", "profile-stale", [["grid_cell", 511, -1]], "COLUMN_STATE"],
	["profile-stale-bad-grid_next", "profile-stale", [["grid_next", 511, 0]], "COLUMN_STATE"],
	["profile-stale-bad-vx", "profile-stale", [["vx", 511, 1]], "COLUMN_STATE"],
	["profile-stale-bad-vz", "profile-stale", [["vz", 511, -1]], "COLUMN_STATE"],
	["profile-stale-zero-retained-target", "profile-stale", [["next_x", 511, 0], ["next_z", 511, 0]], ""],
	["contact-stale-retained-fractions", "contact-stale", [["remainder_x", 511, 419], ["remainder_z", 511, 419]], ""],
	["contact-stale-bad-speed_u_per_s", "contact-stale", [["speed_u_per_s", 511, 0]], "COLUMN_STATE"],
	["contact-stale-bad-grid_cell", "contact-stale", [["grid_cell", 511, -1]], "COLUMN_STATE"],
	["contact-stale-bad-grid_next", "contact-stale", [["grid_next", 511, 0]], "COLUMN_STATE"],
	["contact-stale-bad-vx", "contact-stale", [["vx", 511, 1]], "COLUMN_STATE"],
	["contact-stale-bad-vz", "contact-stale", [["vz", 511, -1]], "COLUMN_STATE"],
	["contact-stale-zero-retained-target", "contact-stale", [["next_x", 511, 0], ["next_z", 511, 0]], ""],
	["arrived-retains-final-displacement", "arrived", [["vx", 511, 110], ["vz", 511, -110], ["remainder_x", 511, 419]], ""],
	["earlier-reserved-before-later-phase", "clear", [["correction_x", 0, 1], ["movement_phase", 511, 6]], "COLUMN_RESERVED"],
	["phase-before-reserved", "travel", [["movement_phase", 511, 6], ["correction_x", 511, 1]], "COLUMN_PHASE"],
	["reserved-before-remainder", "travel", [["radius_u", 511, 1], ["remainder_x", 511, 420]], "COLUMN_RESERVED"],
	["remainder-before-speed", "travel", [["remainder_x", 511, 420], ["speed_u_per_s", 511, 1]], "COLUMN_REMAINDER"],
	["speed-before-velocity", "travel", [["speed_u_per_s", 511, 1], ["vx", 511, 2147483647]], "COLUMN_SPEED"],
	["velocity-before-cell", "travel", [["vx", 511, 111], ["grid_next", 511, 262144]], "COLUMN_VELOCITY"],
	["cell-before-target", "travel", [["grid_next", 511, 262144], ["next_x", 511, 257]], "COLUMN_CELL"],
	["zero-speed-vx-nonzero", "clear", [["vx", 511, 1]], "COLUMN_VELOCITY"],
	["zero-speed-vz-nonzero", "clear", [["vz", 511, 1]], "COLUMN_VELOCITY"]
]

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
