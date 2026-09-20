extends "res://test/framework/test_case.gd"
const Owner := preload("res://scripts/core/field_policy.gd")
const Bridge := preload("res://scripts/core/save_owner_field_policy.gd")
const Section := preload("res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const FIELDS: Array[String] = ["field_present", "zone_slot", "zone_generation", "rotation_ids", "rotation_cursor", "auto_rotation", "seed_reserve", "cycle_ordinal", "participants", "resolved", "withdrawn", "completed_cycles", "cancelled_cycles", "requested_crop", "cycle_state", "close_reason", "request_state", "plot_field_slot", "plot_cycle", "plot_outcome"]
const TYPES: Array[int] = [0, 2, 2, 2, 2, 0, 0, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 2, 2, 0]
const FIXTURES: Dictionary = {
 "clear": {},
 "idle": {
  "field_present": 1,
  "zone_slot": 352417,
  "zone_generation": 2147483647,
  "cycle_ordinal": 2
 },
 "open_empty": {
  "field_present": 1,
  "zone_slot": 352417,
  "zone_generation": 2147483647,
  "cycle_ordinal": 2,
  "cycle_state": 1
 },
 "open": {
  "field_present": 1,
  "zone_slot": 352417,
  "zone_generation": 2147483647,
  "cycle_ordinal": 2,
  "cycle_state": 1,
  "participants": 3,
  "resolved": 1,
  "withdrawn": 1
 },
 "completed": {
  "field_present": 1,
  "zone_slot": 352417,
  "zone_generation": 2147483647,
  "cycle_ordinal": 4,
  "participants": 2,
  "resolved": 2,
  "withdrawn": 1,
  "completed_cycles": 1,
  "cycle_state": 2,
  "close_reason": 1
 },
 "cancelled": {
  "field_present": 1,
  "zone_slot": 352417,
  "zone_generation": 2147483647,
  "cycle_ordinal": 4,
  "participants": 2,
  "resolved": 1,
  "withdrawn": 1,
  "cancelled_cycles": 1,
  "cycle_state": 2,
  "close_reason": 2
 },
 "cancelled_empty": {
  "field_present": 1,
  "zone_slot": 352417,
  "zone_generation": 2147483647,
  "cycle_ordinal": 1,
  "cancelled_cycles": 1,
  "cycle_state": 2,
  "close_reason": 2
 },
 "abandoned": {
  "field_present": 1,
  "zone_slot": 352417,
  "zone_generation": 2147483647,
  "cycle_ordinal": 1,
  "withdrawn": 1,
  "cycle_state": 2,
  "close_reason": 3
 },
 "inactive_completed": {
  "cycle_ordinal": 4,
  "completed_cycles": 1,
  "withdrawn": 1,
  "close_reason": 1
 },
 "inactive_cancelled": {
  "cycle_ordinal": 4,
  "cancelled_cycles": 1,
  "withdrawn": 1,
  "close_reason": 2
 },
 "inactive_abandoned": {
  "cycle_ordinal": 4,
  "withdrawn": 1,
  "close_reason": 3
 },
 "request": {
  "field_present": 1,
  "zone_slot": 352417,
  "zone_generation": 2147483647,
  "cycle_ordinal": 4,
  "participants": 2,
  "resolved": 2,
  "withdrawn": 1,
  "completed_cycles": 1,
  "cycle_state": 2,
  "close_reason": 1,
  "requested_crop": 4,
  "request_state": 1
 }
}
const CASES: Array = [
	["accept-clear", "clear", [], ""],
	["accept-idle", "idle", [], ""],
	["accept-open_empty", "open_empty", [], ""],
	["accept-open", "open", [], ""],
	["accept-completed", "completed", [], ""],
	["accept-cancelled", "cancelled", [], ""],
	["accept-cancelled_empty", "cancelled_empty", [], ""],
	["accept-abandoned", "abandoned", [], ""],
	["accept-inactive_completed", "inactive_completed", [], ""],
	["accept-inactive_cancelled", "inactive_cancelled", [], ""],
	["accept-inactive_abandoned", "inactive_abandoned", [], ""],
	["accept-request", "request", [], ""],
	["projection-field_present", "clear", [[0, 127, 2]], "COLUMN_FLAGS"],
	["projection-zone_slot", "clear", [[1, 127, -2]], "COLUMN_ZONE_REF"],
	["projection-zone_generation", "clear", [[2, 127, -1]], "COLUMN_ZONE_REF"],
	["projection-rotation_ids", "clear", [[3, 381, -2]], "COLUMN_ROTATION"],
	["projection-rotation_cursor", "clear", [[4, 127, 3]], "COLUMN_ROTATION"],
	["projection-auto_rotation", "clear", [[5, 127, 2]], "COLUMN_FLAGS"],
	["projection-seed_reserve", "clear", [[6, 127, 2]], "COLUMN_FLAGS"],
	["projection-cycle_ordinal", "clear", [[7, 127, -1]], "COLUMN_COUNTERS"],
	["projection-participants", "clear", [[8, 127, -1]], "COLUMN_COUNTERS"],
	["projection-resolved", "clear", [[9, 127, -1]], "COLUMN_COUNTERS"],
	["projection-withdrawn", "clear", [[10, 127, -1]], "COLUMN_COUNTERS"],
	["projection-completed_cycles", "clear", [[11, 127, -1]], "COLUMN_COUNTERS"],
	["projection-cancelled_cycles", "clear", [[12, 127, -1]], "COLUMN_COUNTERS"],
	["projection-requested_crop", "clear", [[13, 127, -2]], "COLUMN_ROTATION"],
	["projection-cycle_state", "clear", [[14, 127, 3]], "COLUMN_FLAGS"],
	["projection-close_reason", "clear", [[15, 127, 4]], "COLUMN_FLAGS"],
	["projection-request_state", "clear", [[16, 127, 6]], "COLUMN_FLAGS"],
	["projection-plot_field_slot", "clear", [[17, 4095, -2]], "COLUMN_PLOT_LEDGER"],
	["projection-plot_cycle", "clear", [[18, 4095, -1]], "COLUMN_PLOT_LEDGER"],
	["projection-plot_outcome", "clear", [[19, 4095, 4]], "COLUMN_FLAGS"],
	["byte-field_present", "clear", [[0, 127, 2]], "COLUMN_FLAGS"],
	["byte-auto_rotation", "clear", [[5, 127, 2]], "COLUMN_FLAGS"],
	["byte-seed_reserve", "clear", [[6, 127, 2]], "COLUMN_FLAGS"],
	["byte-cycle_state", "clear", [[14, 127, 3]], "COLUMN_FLAGS"],
	["byte-close_reason", "clear", [[15, 127, 4]], "COLUMN_FLAGS"],
	["byte-request_state", "clear", [[16, 127, 6]], "COLUMN_FLAGS"],
	["byte-plot_outcome", "clear", [[19, 4095, 4]], "COLUMN_FLAGS"],
	["rotation-3--2", "clear", [[3, 383, -2]], "COLUMN_ROTATION"],
	["rotation-3-5", "clear", [[3, 383, 5]], "COLUMN_ROTATION"],
	["rotation-4--1", "clear", [[4, 127, -1]], "COLUMN_ROTATION"],
	["rotation-4-3", "clear", [[4, 127, 3]], "COLUMN_ROTATION"],
	["rotation-13--2", "clear", [[13, 127, -2]], "COLUMN_ROTATION"],
	["rotation-13-5", "clear", [[13, 127, 5]], "COLUMN_ROTATION"],
	["zone-idle-1--1", "idle", [[1, 127, -1]], "COLUMN_ZONE_REF"],
	["zone-idle-1-352418", "idle", [[1, 127, 352418]], "COLUMN_ZONE_REF"],
	["zone-idle-2-0", "idle", [[2, 127, 0]], "COLUMN_ZONE_REF"],
	["zone-idle-2--1", "idle", [[2, 127, -1]], "COLUMN_ZONE_REF"],
	["zone-clear-1-0", "clear", [[1, 127, 0]], "COLUMN_ZONE_REF"],
	["zone-clear-2-1", "clear", [[2, 127, 1]], "COLUMN_ZONE_REF"],
	["negative-counter-cycle_ordinal", "clear", [[7, 127, -1]], "COLUMN_COUNTERS"],
	["negative-counter-participants", "clear", [[8, 127, -1]], "COLUMN_COUNTERS"],
	["negative-counter-resolved", "clear", [[9, 127, -1]], "COLUMN_COUNTERS"],
	["negative-counter-withdrawn", "clear", [[10, 127, -1]], "COLUMN_COUNTERS"],
	["negative-counter-completed_cycles", "clear", [[11, 127, -1]], "COLUMN_COUNTERS"],
	["negative-counter-cancelled_cycles", "clear", [[12, 127, -1]], "COLUMN_COUNTERS"],
	["oversize-counter-participants", "clear", [[8, 127, 4097]], "COLUMN_COUNTERS"],
	["oversize-counter-resolved", "clear", [[9, 127, 4097]], "COLUMN_COUNTERS"],
	["oversize-counter-withdrawn", "clear", [[10, 127, 4097]], "COLUMN_COUNTERS"],
	["resolved-over-participants", "completed", [[9, 127, 3]], "COLUMN_COUNTERS"],
	["participants-plus-withdrawn", "completed", [[8, 127, 4096], [9, 127, 4096]], "COLUMN_COUNTERS"],
	["history-sum-over-ordinal", "inactive_completed", [[11, 127, 3], [12, 127, 2]], "COLUMN_COUNTERS"],
	["history-sum-no-i32-wrap", "inactive_completed", [[7, 127, 2147483647], [11, 127, 2147483647], [12, 127, 2147483647]], "COLUMN_COUNTERS"],
	["accept-max-history", "inactive_completed", [[7, 127, 2147483647], [11, 127, 2147483647], [10, 127, 4096]], ""],
	["inactive-state", "clear", [[14, 127, 1]], "COLUMN_STATE"],
	["inactive-participants", "clear", [[8, 127, 1]], "COLUMN_STATE"],
	["inactive-resolved", "clear", [[8, 127, 1], [9, 127, 1]], "COLUMN_STATE"],
	["idle-participants", "idle", [[8, 127, 1]], "COLUMN_STATE"],
	["idle-resolved", "idle", [[8, 127, 1], [9, 127, 1]], "COLUMN_STATE"],
	["idle-withdrawn", "idle", [[10, 127, 1]], "COLUMN_STATE"],
	["idle-completed", "idle", [[11, 127, 1]], "COLUMN_STATE"],
	["idle-cancelled", "idle", [[12, 127, 1]], "COLUMN_STATE"],
	["idle-close", "idle", [[15, 127, 3], [10, 127, 1]], "COLUMN_STATE"],
	["open-zero-ordinal", "open_empty", [[7, 127, 0]], "COLUMN_STATE"],
	["open-close", "open_empty", [[15, 127, 3], [10, 127, 1]], "COLUMN_STATE"],
	["open-empty-withdrawn", "open_empty", [[10, 127, 1]], "COLUMN_STATE"],
	["open-all-resolved", "open", [[9, 127, 3]], "COLUMN_STATE"],
	["closed-zero-ordinal", "abandoned", [[7, 127, 0]], "COLUMN_STATE"],
	["closed-no-reason", "completed", [[15, 127, 0]], "COLUMN_STATE"],
	["completed-empty", "completed", [[8, 127, 0], [9, 127, 0]], "COLUMN_STATE"],
	["completed-unresolved", "completed", [[9, 127, 1]], "COLUMN_STATE"],
	["cancelled-all-resolved", "cancelled", [[9, 127, 2]], "COLUMN_STATE"],
	["cancelled-empty-withdrawn", "cancelled_empty", [[10, 127, 1]], "COLUMN_STATE"],
	["abandoned-participants", "abandoned", [[8, 127, 1]], "COLUMN_STATE"],
	["history-close-zero-ordinal", "clear", [[15, 127, 3], [10, 127, 1]], "COLUMN_STATE"],
	["history-completed-zero-count", "inactive_completed", [[11, 127, 0]], "COLUMN_STATE"],
	["history-cancelled-zero-count", "inactive_cancelled", [[12, 127, 0]], "COLUMN_STATE"],
	["history-abandoned-zero-withdrawn", "inactive_abandoned", [[10, 127, 0]], "COLUMN_STATE"],
	["withdrawn-zero-ordinal", "clear", [[10, 127, 1]], "COLUMN_STATE"],
	["request-none-crop", "completed", [[13, 127, 0]], "COLUMN_REQUEST"],
	["inactive-request", "inactive_completed", [[16, 127, 4]], "COLUMN_REQUEST"],
	["idle-request", "idle", [[16, 127, 4]], "COLUMN_REQUEST"],
	["open-request", "open_empty", [[16, 127, 4]], "COLUMN_REQUEST"],
	["request-not-completed", "cancelled", [[16, 127, 4]], "COLUMN_REQUEST"],
	["request-crop-mismatch", "request", [[13, 127, 3]], "COLUMN_REQUEST"],
	["request-empty-wrong-state", "completed", [[16, 127, 1]], "COLUMN_REQUEST"],
	["request-configured-empty-state", "request", [[16, 127, 4]], "COLUMN_REQUEST"],
	["accept-request-state-1", "request", [[16, 127, 1]], ""],
	["accept-request-state-2", "request", [[16, 127, 2]], ""],
	["accept-request-state-3", "request", [[16, 127, 3]], ""],
	["accept-request-state-5", "request", [[16, 127, 5]], ""],
	["accept-empty-request", "completed", [[16, 127, 4]], ""],
	["accept-request-auto-off", "request", [[5, 127, 0]], ""],
	["accept-request-auto-on", "request", [[5, 127, 1]], ""],
	["plot-field-negative", "idle", [[17, 4095, -2]], "COLUMN_PLOT_LEDGER"],
	["plot-field-over-cap", "idle", [[17, 4095, 128]], "COLUMN_PLOT_LEDGER"],
	["null-plot-cycle", "idle", [[18, 4095, 1]], "COLUMN_PLOT_LEDGER"],
	["null-plot-outcome", "idle", [[19, 4095, 1]], "COLUMN_PLOT_LEDGER"],
	["linked-cycle-zero", "idle", [[17, 4095, 127]], "COLUMN_PLOT_LEDGER"],
	["linked-cycle-negative", "idle", [[17, 4095, 127], [18, 4095, -1]], "COLUMN_PLOT_LEDGER"],
	["linked-cycle-future", "idle", [[17, 4095, 127], [18, 4095, 3]], "COLUMN_PLOT_LEDGER"],
	["accept-stale-idle-0", "idle", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 0]], ""],
	["accept-stale-idle-1", "idle", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 1]], ""],
	["accept-stale-idle-2", "idle", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 2]], ""],
	["accept-stale-idle-3", "idle", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 3]], ""],
	["accept-stale-completed-0", "completed", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 0]], ""],
	["accept-stale-completed-1", "completed", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 1]], ""],
	["accept-stale-completed-2", "completed", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 2]], ""],
	["accept-stale-completed-3", "completed", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 3]], ""],
	["accept-stale-inactive_completed-0", "inactive_completed", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 0]], ""],
	["accept-stale-inactive_completed-1", "inactive_completed", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 1]], ""],
	["accept-stale-inactive_completed-2", "inactive_completed", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 2]], ""],
	["accept-stale-inactive_completed-3", "inactive_completed", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 3]], ""],
	["accept-stale-open_empty-0", "open_empty", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 0]], ""],
	["accept-stale-open_empty-1", "open_empty", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 1]], ""],
	["accept-stale-open_empty-2", "open_empty", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 2]], ""],
	["accept-stale-open_empty-3", "open_empty", [[17, 4095, 127], [18, 4095, 1], [19, 4095, 3]], ""],
	["open-participant-mismatch", "open", [[8, 127, 4]], "COLUMN_OPEN_COUNTS"],
	["open-resolved-mismatch", "open", [[9, 127, 2]], "COLUMN_OPEN_COUNTS"],
	["open-withdrawn-mismatch", "open", [[10, 127, 2]], "COLUMN_OPEN_COUNTS"],
	["open-unresolved-contribution", "open", [[19, 4092, 1]], "COLUMN_OPEN_COUNTS"],
	["open-cleared-contribution", "open", [[19, 4094, 2]], ""],
	["accept-closed-ledger-not-reconstructed-completed", "completed", [[17, 4095, 127], [18, 4095, 4], [19, 4095, 0]], ""],
	["accept-closed-ledger-not-reconstructed-inactive_completed", "inactive_completed", [[17, 4095, 127], [18, 4095, 4], [19, 4095, 0]], ""],
	["accept-open-older-stamp-ignored", "open", [[17, 4091, 127], [18, 4091, 1], [19, 4091, 3]], ""],
	["priority-field-row-zone-before-later-counter", "idle", [[1, 0, 0], [7, 127, -1]], "COLUMN_ZONE_REF"],
	["priority-global-flags", "idle", [[1, 0, 0], [6, 127, 2]], "COLUMN_FLAGS"]
]

func _put(c: Owner.Columns, field: int, row: int, value: int) -> void:
	var values: Variant = c.get(FIELDS[field])
	values[row] = value
	c.set(FIELDS[field],values)

func _snapshot(c: Owner.Columns) -> Array:
	var out: Array = []
	for key: String in FIELDS: out.append(c.get(key).duplicate())
	return out

func _frame(c: Owner.Columns) -> Section.FramedOwner:
	var f: Section.FramedOwner = Section.FramedOwner.new(3)
	for field: int in 20:
		var ok: bool = f.set_u8(field,c.get(FIELDS[field])) if TYPES[field] == 0 else f.set_i32(field,c.get(FIELDS[field]))
		assert_true(ok,"typed canonical setter")
	return f

func _image(name: String) -> Owner.Columns:
	var c: Owner.Columns = Owner.Columns.new()
	var values: Dictionary = FIXTURES[name]
	for key: String in values:
		_put(c,FIELDS.find(key),127,int(values[key]))
	if name == "request": c.rotation_ids[381] = 4
	if name == "open":
		for index: int in 4:
			c.plot_field_slot[4092+index] = 127
			c.plot_cycle[4092+index] = 2
			c.plot_outcome[4092+index] = [0,0,1,3][index]
	return c

func _expect(c: Owner.Columns, code: StringName, label: String) -> void:
	var before: Array = _snapshot(c)
	var f: Section.FramedOwner = _frame(c)
	assert_equal(Owner.columns_refusal(c),code,label+" pure")
	var result: Variant = Bridge.framed_refusal(f)
	assert_equal(result.code,code,label+" bridge")
	assert_equal(result.is_ok(),code == &"",label+" success")
	if code == &"": assert_equal(result.detail,"",label+" empty success detail")
	else:
		assert_true(result.detail.contains("FieldPolicy owner 3 "),label+" owner detail")
		assert_true(result.detail.contains(String(code)),label+" raw code")
	for field: int in 20:
		assert_true(c.get(FIELDS[field]) == before[field],label+" original unchanged")
		var held: Variant = f.u8_column(field) if TYPES[field] == 0 else f.i32_column(field)
		assert_true(held == before[field],label+" framed unchanged")

func test_canonical_layout_and_clear_defaults() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	_expect(c,&"","clear")
	assert_equal(Schema.owner_version(3),1,"version")
	assert_equal(Schema.primary_count(3),128,"primary")
	assert_equal(Schema.child_extent_count(3),1,"child count")
	assert_equal(Schema.child_extent(3,0),4096,"plot extent")
	assert_equal(Schema.field_count(3),20,"fields")
	var bytes: int = 0
	for field: int in 20:
		var extent: int = 384 if field == 3 else 4096 if field >= 17 else 128
		assert_equal(Schema.field_key(3,field),"_"+FIELDS[field],"canonical key")
		assert_equal(Schema.field_type(3,field),TYPES[field],"canonical type")
		assert_equal(Schema.element_count(3,field),extent,"canonical extent")
		var expected: int = -1 if field in [1,3,13,17] else 1 if field == 6 else 0
		assert_equal(c.get(FIELDS[field]).count(expected),extent,"clear default")
		bytes += extent * (1 if TYPES[field] == 0 else 4)
	assert_equal(bytes,44288,"value bytes")
	assert_equal(bytes*2+3*128*4,90112,"conservative packed budget")

func test_frozen_state_history_request_and_projection_witnesses() -> void:
	for item: Array in CASES:
		var c: Owner.Columns = _image(item[1])
		for change: Array in item[2]: _put(c,int(change[0]),int(change[1]),int(change[2]))
		_expect(c,StringName(item[3]),item[0])

func test_null_shapes_and_bucket_cardinalities_precede_values() -> void:
	assert_equal(Owner.columns_refusal(null),&"COLUMN_SHAPE","static null")
	assert_equal(Bridge.framed_refusal(null).code,Section.REFUSE_SHAPE,"bridge null")
	assert_equal(Bridge.framed_refusal(Section.FramedOwner.new(2)).code,Section.REFUSE_OWNER,"wrong owner")
	for field: int in 20:
		var extent: int = 384 if field == 3 else 4096 if field >= 17 else 128
		for size: int in [0,extent-1,extent+1]:
			var c: Owner.Columns = Owner.Columns.new()
			var values: Variant = c.get(FIELDS[field]).duplicate()
			values.resize(size)
			c.set(FIELDS[field],values)
			if field != 0: c.field_present[0] = 2
			else: c.auto_rotation[0] = 2
			var before: Array = _snapshot(c)
			assert_equal(Owner.columns_refusal(c),&"COLUMN_SHAPE","all extents before domains")
			for key: int in 20: assert_true(c.get(FIELDS[key]) == before[key],"shape refusal unchanged")
	for bucket: int in 3:
		for delta: int in [-1,1]:
			if bucket == 2 and delta == -1: continue
			var f: Section.FramedOwner = _frame(Owner.Columns.new())
			if bucket == 0: f.u8_columns.resize(f.u8_columns.size()+delta)
			elif bucket == 1: f.i32_columns.resize(f.i32_columns.size()+delta)
			else: f.i64_columns.resize(1)
			var shape: Variant = Section.owner_shape_refusal(f)
			var result: Variant = Bridge.framed_refusal(f)
			assert_equal(result.code,shape.code,"shape code forwarded")
			assert_equal(result.detail,shape.detail,"shape detail forwarded")
			assert_false(result.is_ok(),"malformed bucket refused")

func test_every_physical_address_has_domain_checks() -> void:
	var c: Owner.Columns = Owner.Columns.new()
	var original: Array = _snapshot(c)
	var bad: Array[int] = [2,-2,-1,-2,3,2,2,-1,-1,-1,-1,-1,-1,-2,3,4,6,-2,-1,4]
	var codes: Array[StringName] = [&"COLUMN_FLAGS",&"COLUMN_ZONE_REF",&"COLUMN_ZONE_REF",&"COLUMN_ROTATION",&"COLUMN_ROTATION",&"COLUMN_FLAGS",&"COLUMN_FLAGS",&"COLUMN_COUNTERS",&"COLUMN_COUNTERS",&"COLUMN_COUNTERS",&"COLUMN_COUNTERS",&"COLUMN_COUNTERS",&"COLUMN_COUNTERS",&"COLUMN_ROTATION",&"COLUMN_FLAGS",&"COLUMN_FLAGS",&"COLUMN_FLAGS",&"COLUMN_PLOT_LEDGER",&"COLUMN_PLOT_LEDGER",&"COLUMN_FLAGS"]
	for field: int in 20:
		var extent: int = 384 if field == 3 else 4096 if field >= 17 else 128
		var default_value: int = -1 if field in [1,3,13,17] else 1 if field == 6 else 0
		for row: int in extent:
			_put(c,field,row,bad[field])
			assert_equal(Owner.columns_refusal(c),codes[field],"physical%d:%d" % [field,row])
			assert_equal(int(c.get(FIELDS[field])[row]),bad[field],"fault not normalized")
			_put(c,field,row,default_value)
		for key: int in 20: assert_true(c.get(FIELDS[key]) == original[key],"all other buffers preserved")
	assert_equal(Owner.columns_refusal(c),&"","restored clear")

func test_open_ledger_filters_and_multiple_fields() -> void:
	var c: Owner.Columns = _image("open")
	# A second OPEN cycle has one unresolved and one cleared participant.
	c.field_present[0] = 1
	c.zone_slot[0] = 0
	c.zone_generation[0] = 1
	c.cycle_state[0] = 1
	c.cycle_ordinal[0] = 1
	c.participants[0] = 2
	c.resolved[0] = 1
	for row: int in 2:
		c.plot_field_slot[row] = 0
		c.plot_cycle[row] = 1
	c.plot_outcome[1] = 2
	_expect(c,&"","two open fields")
	# Closed field history is not reconstructible; its current stamp must not count as open.
	c.field_present[1] = 1
	c.zone_slot[1] = 1
	c.zone_generation[1] = 1
	c.cycle_ordinal[1] = 1
	c.cycle_state[1] = 2
	c.close_reason[1] = 2
	c.cancelled_cycles[1] = 1
	c.plot_field_slot[2] = 1
	c.plot_cycle[2] = 1
	c.plot_outcome[2] = 3
	_expect(c,&"","closed ledger ignored alongside open")
	c.field_present[1] = 0
	c.zone_slot[1] = -1
	c.zone_generation[1] = 0
	c.cycle_state[1] = 0
	_expect(c,&"","inactive ledger ignored alongside open")
	c.plot_field_slot[3] = 127
	c.plot_cycle[3] = 1
	c.plot_outcome[3] = 3
	_expect(c,&"","older stamp ignored alongside current open")
	# Bypassing equality for each field must be detected, not masked by correct neighbor counts.
	c.participants[0] = 3
	_expect(c,&"COLUMN_OPEN_COUNTS","first field mismatch")
	c.participants[0] = 2
	c.withdrawn[127] = 2
	_expect(c,&"COLUMN_OPEN_COUNTS","last field mismatch")

func test_full_plot_capacity_and_counter_boundary() -> void:
	var c: Owner.Columns = _image("open_empty")
	c.cycle_ordinal[127] = 2147483647
	c.participants[127] = 4096
	c.plot_field_slot.fill(127)
	c.plot_cycle.fill(2147483647)
	_expect(c,&"","full unresolved ledger at max stamp")
	c.plot_outcome[4095] = 2
	c.resolved[127] = 1
	_expect(c,&"","cleared tail counts once")
	c.plot_outcome[0] = 3
	c.participants[127] = 4095
	c.withdrawn[127] = 1
	_expect(c,&"","withdrawn head excluded from participants")
	c.plot_cycle[4095] = 2147483646
	_expect(c,&"COLUMN_OPEN_COUNTS","stale tail cannot satisfy current count")

func test_accepted_scalar_endpoints_do_not_normalize_history() -> void:
	for crop: int in range(-1,5):
		for cursor: int in 3:
			var c: Owner.Columns = _image("idle")
			c.rotation_ids.fill(crop)
			c.rotation_cursor[127] = cursor
			c.auto_rotation[127] = 1
			c.seed_reserve[127] = 0
			_expect(c,&"","crop/cursor and flag endpoints")
	var c: Owner.Columns = _image("inactive_cancelled")
	c.cycle_ordinal[127] = 2147483647
	c.cancelled_cycles[127] = 2147483647
	_expect(c,&"","max cancellation history")
	c.cancelled_cycles[127] = 1
	c.completed_cycles[127] = 2147483646
	_expect(c,&"","history sum at max")
	c.completed_cycles[127] = 2147483647
	_expect(c,&"COLUMN_COUNTERS","history sum just over max ordinal")

func test_closed_reason_gate_has_an_independent_abandoned_shape_witness() -> void:
	var c: Owner.Columns = _image("abandoned")
	c.close_reason[127] = 0
	_expect(c,&"COLUMN_STATE","closed NONE cannot fall through as abandoned")
