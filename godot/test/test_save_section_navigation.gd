extends "res://test/framework/test_case.gd"
## Adversarial suite for ARCH-SAVE-002 section 9 NAVIGATION.
##
## Section 9 carries state no other section can reconstruct: a partial A* search that must resume
## on the tick it was interrupted on, a bounded route cache whose eviction order is observable, and
## a pending queue whose ORDER decides which resident is served first. Round-trip equality is the
## FLOOR here, not the test. The cases that matter are the ones where a wrong load still looks
## entirely plausible:
##
##   * arena garbage past the used prefix persisted -- two observationally identical worlds produce
##     different bytes and different CRCs, which is decision 0103's argument about the directory's
##     free heaps applied to `_arena` and `_heap`;
##   * the two owner blocks emitted out of ASCII key order -- a reader that trusts position rather
##     than the key reads `movement`'s cursors as `navigation`'s scalars;
##   * a route generation read from the WRONG NAMESPACE -- `_r_route_generation` is a route
##     DESCRIPTOR generation and `_r_job_generation` is a DIRECTORY slot generation, and a
##     validator that compared the hold against the latter accepts a stale hold whose two unrelated
##     integers happen to match;
##   * commit-then-validate -- a FULL-LENGTH section that is invalid must leave the caller's Record
##     byte-identical, which only a full-length fixture can prove;
##   * `payload_byte_length` disagreeing with the body it describes.
##
## GENERATION NAMESPACE: ROUTE DESCRIPTOR. Four exist in this codebase (directory slot, inventory
## container, inventory lot, navigation route descriptor). `_d_generation`, `_r_route_generation`
## and `movement.gd`'s `_cursor_route_generation` are route-descriptor generations;
## `_r_job_generation` and the two contact owner generations are DIRECTORY generations and are
## never compared against a descriptor.
##
## THE INT32 SIGN TRAP IS EXERCISED, NOT ASSUMED. GDScript ints are 64-bit, so `0x80000000` is a
## POSITIVE 2147483648 and `-2147483648` is the same four bytes read as int32. Route generations
## retire at 2147483647 rather than wrapping, so the boundary is live state; the case below builds
## its value through `SaveCodec.u32_bits_to_int32()` and asserts the pair agrees.
##
## THE LIVE-CAPTURE CASES READ `navigation.gd`'s PRIVATE COLUMNS THROUGH `Object.get()`, AND ONLY
## HERE. That is BLOCKER N1 made visible: the module publishes no bulk column reader, so no
## production code can capture it and `save_section_navigation.gd` deliberately has no
## `capture_into(store)`. A test may stand in for the missing reader to prove the validator accepts
## a real serviced navigator -- which hand-built fixtures cannot prove -- and the field keys it
## indexes by are the declared canonical keys, so a mistyped key fails here rather than on disk.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SaveSectionNavigation := preload("res://scripts/core/save_section_navigation.gd")
const NavigationScript := preload("res://scripts/core/navigation.gd")
const MovementScript := preload("res://scripts/core/movement.gd")
const SpatialWorldScript := preload("res://scripts/core/spatial_world.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")

## A macro corner well inside the authored land, reused from `test_navigation.gd`: cell (192,288).
const ANCHOR_CELL: int = 288 * 512 + 192
const NEAR_GOAL_CELL: int = 290 * 512 + 196
## A search long enough that one tick of the 2048-expansion quota provably cannot finish it.
const LONG_START_CELL: int = 128 * 512 + 128
const LONG_GOAL_CELL: int = 300 * 512 + 200

## Reused shared map: `SpatialWorld.new()` rebuilds the whole authored surface and no case here
## carves it, so one instance serves every live-capture test.
static var _shared_world: SpatialWorldScript = null

var _record: SaveSectionNavigation.Record = null


func before_each() -> void:
	"""Build one empty-navigator Record per test."""
	_record = SaveSectionNavigation.Record.new()


func after_each() -> void:
	"""Drop the Record; each holds roughly ten megabytes of packed columns."""
	_record = null


# --- fixtures ------------------------------------------------------------------------------------

func _encode(record: SaveSectionNavigation.Record) -> PackedByteArray:
	"""Encode a Record and assert it succeeded, returning the section bytes."""
	var out: SaveSectionNavigation.EncodeResult = SaveSectionNavigation.EncodeResult.new()
	assert_true(SaveSectionNavigation.encode_record(record, out),
		"encode_record succeeds: %s %s" % [out.refusal, out.detail])
	return out.bytes


func _decode(bytes: PackedByteArray,
		out: SaveSectionNavigation.Record) -> SaveHeader.Refusal:
	"""Decode at offset 0 and return the refusal, without asserting either way."""
	return SaveSectionNavigation.decode_into(bytes, 0, out)


func _hex(bytes: PackedByteArray) -> String:
	"""Lowercase hex of a byte run, for pinned vectors."""
	var text: String = ""
	for value: int in bytes:
		text += "%02x" % value
	return text


func _patch(bytes: PackedByteArray, offset: int, value: int, width: int) -> PackedByteArray:
	"""Overwrite one little-endian field in a copy of an encoded section."""
	var patched: PackedByteArray = bytes.duplicate()
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if width == SaveCodec.U64_BYTES:
		assert_true(SaveCodec.write_u64_into(patched, offset, value, scalar), "u64 patch fits")
	elif value < 0:
		assert_true(SaveCodec.write_i32_into(patched, offset, value, scalar), "i32 patch fits")
	else:
		assert_true(SaveCodec.write_u32_into(patched, offset, value, scalar), "u32 patch fits")
	return patched


func _store_route(record: SaveSectionNavigation.Record, descriptor: int, generation: int,
		offset: int, count: int) -> void:
	"""Put one stored route in a descriptor, with its cells already written into the arena."""
	record.set_descriptor(SaveSectionNavigation.DESC_FLAGS, descriptor,
		NavigationScript.FLAG_IN_USE)
	record.set_descriptor(SaveSectionNavigation.DESC_GENERATION, descriptor, generation)
	record.set_descriptor(SaveSectionNavigation.DESC_START_MACRO, descriptor,
		SpatialWorldScript.macro_of(ANCHOR_CELL))
	record.set_descriptor(SaveSectionNavigation.DESC_GOAL_CELL, descriptor, NEAR_GOAL_CELL)
	record.set_descriptor(SaveSectionNavigation.DESC_CLEARANCE, descriptor, 1)
	record.set_descriptor(SaveSectionNavigation.DESC_MAP_REVISION, descriptor,
		SpatialWorldScript.FIRST_MAP_REVISION)
	record.set_descriptor(SaveSectionNavigation.DESC_VARIANT_START, descriptor, -1)
	record.set_descriptor(SaveSectionNavigation.DESC_ANCHOR, descriptor, ANCHOR_CELL)
	record.set_descriptor(SaveSectionNavigation.DESC_OFFSET, descriptor, offset)
	record.set_descriptor(SaveSectionNavigation.DESC_COUNT, descriptor, count)
	record.set_descriptor(SaveSectionNavigation.DESC_USE_LOW, descriptor, 30)
	for index: int in count:
		record.arena[offset + index] = ANCHOR_CELL + index
	record.set_scalar(SaveSectionNavigation.SCALAR_ARENA_USED, offset + count)


func _fill_request(record: SaveSectionNavigation.Record, row: int, phase: int,
		persistent_id: int) -> void:
	"""Write one allocated request row, as `_fill_request()` leaves a submitted request."""
	record.set_request(SaveSectionNavigation.REQ_PHASE, row, phase)
	record.set_request(SaveSectionNavigation.REQ_JOB_SLOT, row, row + 1)
	record.set_request(SaveSectionNavigation.REQ_JOB_GENERATION, row, 1)
	record.set_request(SaveSectionNavigation.REQ_START_CELL, row, ANCHOR_CELL)
	record.set_request(SaveSectionNavigation.REQ_EXACT_START, row, ANCHOR_CELL)
	record.set_request(SaveSectionNavigation.REQ_GOAL_CELL, row, NEAR_GOAL_CELL)
	record.set_request(SaveSectionNavigation.REQ_CLEARANCE, row, 1)
	record.set_request(SaveSectionNavigation.REQ_START_MACRO, row,
		SpatialWorldScript.macro_of(ANCHOR_CELL))
	record.set_request(SaveSectionNavigation.REQ_MAP_REVISION, row,
		SpatialWorldScript.FIRST_MAP_REVISION)
	record.set_request(SaveSectionNavigation.REQ_ANCHOR, row, ANCHOR_CELL)
	record.set_request(SaveSectionNavigation.REQ_NEXT_QUEUE, row, -1)
	record.set_request(SaveSectionNavigation.REQ_REQUESTER_PERSISTENT_ID, row, persistent_id)


func _attach(record: SaveSectionNavigation.Record, row: int, descriptor: int,
		generation: int) -> void:
	"""Make one request READY on a stored route, taking the reference `_hold_route()` takes."""
	record.set_request(SaveSectionNavigation.REQ_PHASE, row, NavigationScript.PHASE_READY)
	record.set_request(SaveSectionNavigation.REQ_ROUTE_ID, row, descriptor)
	record.set_request(SaveSectionNavigation.REQ_ROUTE_GENERATION, row, generation)
	record.set_descriptor(SaveSectionNavigation.DESC_REFCOUNT, descriptor,
		record.descriptor(SaveSectionNavigation.DESC_REFCOUNT, descriptor) + 1)


func _attach_cursor(record: SaveSectionNavigation.Record, motion_row: int, request: int,
		generation: int) -> void:
	"""Attach one movement route cursor, as `movement.gd::_attach_route()` leaves it."""
	record.set_cursor(SaveSectionNavigation.MOV_REQUEST, motion_row, request)
	record.set_cursor(SaveSectionNavigation.MOV_ROUTE_GENERATION, motion_row, generation)
	record.set_cursor(SaveSectionNavigation.MOV_INDEX, motion_row, 0)
	record.set_cursor(SaveSectionNavigation.MOV_OWNER_ID, motion_row, 12)
	record.set_cursor(SaveSectionNavigation.MOV_PROFILE_ID, motion_row, 0)
	record.set_cursor(SaveSectionNavigation.MOV_PROFILE_REVISION, motion_row,
		MovementScript.PROFILE_FIRST_REVISION)
	record.set_cursor(SaveSectionNavigation.MOV_MODE, motion_row, MovementScript.MODE_GROUND_WALK)
	record.set_cursor(SaveSectionNavigation.MOV_LOAD_G, motion_row, 250)
	record.set_cursor(SaveSectionNavigation.MOV_DESTINATION_REVISION, motion_row,
		SpatialWorldScript.FIRST_DESTINATION_REVISION)


func _populate(record: SaveSectionNavigation.Record) -> void:
	"""The shared fixture: one READY request on a stored route, one queued request, one cursor.

	Route descriptor generation is deliberately 5 while the requester's DIRECTORY generation is 1,
	so a validator that confused the two namespaces cannot pass by coincidence.
	"""
	_store_route(record, 0, 5, 0, 3)
	_fill_request(record, 0, NavigationScript.PHASE_READY, 4)
	_attach(record, 0, 0, 5)
	_fill_request(record, 1, NavigationScript.PHASE_QUEUED, 9)
	record.set_scalar(SaveSectionNavigation.SCALAR_QUEUE_HEAD, 1)
	record.set_scalar(SaveSectionNavigation.SCALAR_FREE_REQUEST_HEAD, 2)
	record.set_scalar(SaveSectionNavigation.SCALAR_EXPANSIONS_TOTAL, 118)
	record.set_scalar(SaveSectionNavigation.SCALAR_EXPANSIONS_REMAINING, 1930)
	_attach_cursor(record, 0, 0, 5)


func _world() -> SpatialWorldScript:
	"""The shared authored ground map, built once for the whole suite."""
	if _shared_world == null:
		_shared_world = SpatialWorldScript.new()
	return _shared_world


func _serviced_navigator() -> NavigationScript:
	"""A navigator holding a READY request, an interrupted search and a queued request at once."""
	var world: SpatialWorldScript = _world()
	var directory: EntityDirectoryScript = EntityDirectoryScript.new()
	var navigation: NavigationScript = NavigationScript.new(directory, world)
	_submit(navigation, directory, world, ANCHOR_CELL, NEAR_GOAL_CELL)
	_submit(navigation, directory, world, LONG_START_CELL, LONG_GOAL_CELL)
	_submit(navigation, directory, world, ANCHOR_CELL + 1, NEAR_GOAL_CELL + 1)
	navigation.service(1)
	return navigation


func _submit(navigation: NavigationScript, directory: EntityDirectoryScript,
		world: SpatialWorldScript, start_cell: int, goal_cell: int) -> void:
	"""Submit one request between two freshly owned ground contacts."""
	var start: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	var goal: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	assert_true(world.bind_ground_location(start, start_cell,
		directory.create(EntityDirectoryScript.KIND_RESOURCE_NODE)), "start binds")
	assert_true(world.bind_ground_location(goal, goal_cell,
		directory.create(EntityDirectoryScript.KIND_RESOURCE_NODE)), "goal binds")
	var result: IntMathScript.IntResult = IntMathScript.IntResult.new()
	assert_true(navigation.submit_request_into(
		directory.create(EntityDirectoryScript.KIND_JOB), start, goal, 1, 0, result),
		"submission accepted (refusal was %s)" % navigation.last_refusal())


func _capture_live(navigation: NavigationScript,
		record: SaveSectionNavigation.Record) -> SaveHeader.Refusal:
	"""Fill a Record from a live navigator's private columns. TEST-ONLY; see BLOCKER N1 above.

	Indexed by the DECLARED canonical field keys, which are also the member names, so this doubles
	as a check that `NAV_FIELD_KEYS` names columns that really exist.
	"""
	for field: int in SaveSectionNavigation.NAV_FIELD_COUNT:
		var key: String = String(SaveSectionNavigation.NAV_FIELD_KEYS[field])
		var group: int = SaveSectionNavigation.NAV_FIELD_GROUP[field]
		var values: Variant = navigation.get(key)
		assert_not_null(values, "navigation.gd publishes a member named %s" % key)
		var refusal: SaveHeader.Refusal = _install_live(record, field, group, values, navigation)
		if not refusal.is_ok():
			return refusal
	return SaveHeader.Refusal.new(SaveSectionNavigation.REFUSE_NONE, "")


func _install_live(record: SaveSectionNavigation.Record, field: int, group: int,
		values: Variant, navigation: NavigationScript) -> SaveHeader.Refusal:
	"""Route one captured live column into the Record through its own declared setter."""
	if group == SaveSectionNavigation.GROUP_SCALAR:
		record.set_scalar(SaveSectionNavigation.NAV_FIELD_SLOT[field], int(values))
		return SaveHeader.Refusal.new(SaveSectionNavigation.REFUSE_NONE, "")
	if group == SaveSectionNavigation.GROUP_STATE:
		return SaveSectionNavigation.set_navigation_state_column(record, values)
	if group == SaveSectionNavigation.GROUP_HEAP:
		return SaveSectionNavigation.set_navigation_prefix_column(record, field, values,
			int(navigation.get("_heap_size")))
	if group == SaveSectionNavigation.GROUP_ARENA:
		return SaveSectionNavigation.set_navigation_prefix_column(record, field, values,
			navigation.arena_used())
	return SaveSectionNavigation.set_navigation_column(record, field, values)


# --- declared identity and field order -----------------------------------------------------------

func test_section_identity_matches_the_ruling() -> void:
	"""Section 9, schema 2, two owners in ASCII key order, at REG-R01's declared versions."""
	assert_equal(SaveSectionNavigation.SECTION_ID, 9, "ARCH-SAVE-002 numbers NAVIGATION 9")
	assert_equal(SaveSectionNavigation.SECTION_SCHEMA_VERSION, 2,
		"REG-R01's baseline vector [2,2,1,2,1,1,2,1,2,1,1,2,1,2,1] gives section 9 version 2")
	assert_equal(SaveSectionNavigation.STORE_COUNT, 2, "§9 has two owners")
	assert_true(SaveSectionNavigation.OWNER_KEY_MOVEMENT
		< SaveSectionNavigation.OWNER_KEY_NAVIGATION, "'movement' sorts before 'navigation'")
	assert_equal(SaveSectionNavigation.OWNER_SCHEMA_VERSION_MOVEMENT, 1, "movement is schema 1")
	assert_equal(SaveSectionNavigation.OWNER_SCHEMA_VERSION_NAVIGATION, 2,
		"navigation is schema 2: exact-start navigation semantics")


func test_owner_schema_version_is_the_route_semantics_gate() -> void:
	"""PATH-R02's published route semantics version and this owner's schema version are one number."""
	assert_equal(SaveSectionNavigation.OWNER_SCHEMA_VERSION_NAVIGATION,
		NavigationScript.route_semantics_version(),
		"the schema version IS navigation.gd's route semantics version")
	assert_equal(NavigationScript.refuse_route_semantics(
		SaveSectionNavigation.OWNER_SCHEMA_VERSION_NAVIGATION), NavigationScript.REFUSE_NONE,
		"navigation.gd accepts this schema's semantics")
	assert_equal(NavigationScript.refuse_route_semantics(
		NavigationScript.ROUTE_SEMANTICS_VERSION_ANCHOR_COMPOSITION),
		NavigationScript.REFUSE_ROUTE_SEMANTICS, "version 1 anchor composition is refused")


func test_field_tables_are_the_declared_registry_order() -> void:
	"""57 navigation fields and 9 movement fields, at the ordinals the registry declares."""
	assert_equal(SaveSectionNavigation.NAV_FIELD_KEYS.size(), 57, "57 navigation fields")
	assert_equal(SaveSectionNavigation.NAV_FIELD_GROUP.size(), 57, "a group per field")
	assert_equal(SaveSectionNavigation.NAV_FIELD_SLOT.size(), 57, "a slot per field")
	assert_equal(SaveSectionNavigation.MOVEMENT_FIELD_KEYS.size(), 9, "9 movement fields")
	assert_equal(String(SaveSectionNavigation.NAV_FIELD_KEYS[0]), "_search_serial", "ordinal 0")
	assert_equal(String(SaveSectionNavigation.NAV_FIELD_KEYS[13]), "_stamp", "ordinal 13")
	assert_equal(String(SaveSectionNavigation.NAV_FIELD_KEYS[19]), "_heap", "ordinal 19")
	assert_equal(String(SaveSectionNavigation.NAV_FIELD_KEYS[22]), "_arena", "ordinal 22")
	assert_equal(String(SaveSectionNavigation.NAV_FIELD_KEYS[56]),
		"_c_requester_persistent_id", "ordinal 56")


func test_declared_ordinal_is_not_gdscript_declaration_order() -> void:
	"""The two orders differ in both blocks, which is why the registry is transcribed not derived."""
	assert_equal(String(SaveSectionNavigation.MOVEMENT_FIELD_KEYS[0]), "_cursor_owner_id",
		"movement ordinal 0 is _cursor_owner_id, which movement.gd declares FOURTH")
	assert_equal(String(SaveSectionNavigation.MOVEMENT_FIELD_KEYS[1]), "_cursor_request",
		"movement ordinal 1 is _cursor_request, which movement.gd declares FIRST")
	assert_equal(String(SaveSectionNavigation.NAV_FIELD_KEYS[13]), "_stamp",
		"navigation ordinal 13 is _stamp, which navigation.gd declares FIFTH of the builder")
	assert_equal(String(SaveSectionNavigation.NAV_FIELD_KEYS[17]), "_g",
		"navigation ordinal 17 is _g, which navigation.gd declares FIRST")


func test_every_group_slot_is_used_exactly_once() -> void:
	"""Each group's slots run 0..n-1 with no gap and no duplicate, so no column is aliased."""
	var seen: Dictionary = {}
	for field: int in SaveSectionNavigation.NAV_FIELD_COUNT:
		var key: String = "%d:%d" % [SaveSectionNavigation.NAV_FIELD_GROUP[field],
			SaveSectionNavigation.NAV_FIELD_SLOT[field]]
		assert_false(seen.has(key), "group/slot %s is claimed once" % key)
		seen[key] = field
	assert_equal(seen.size(), 57, "57 distinct group/slot pairs")
	var counts: Array[int] = [13, 4, 1, 16, 21, 1, 1]
	for group: int in counts.size():
		for slot: int in counts[group]:
			assert_true(seen.has("%d:%d" % [group, slot]),
				"group %d slot %d exists" % [group, slot])


func test_canonical_type_codes() -> void:
	"""SAVE-R09 type codes: `_state` is the only u8 column in section 9."""
	var state_wire: int = SaveSectionNavigation.MOVEMENT_FIELD_COUNT + 21
	assert_equal(SaveSectionNavigation.canonical_type_of(state_wire), 0, "_state is type 0 (u8)")
	assert_equal(SaveSectionNavigation.wire_field_width(state_wire), 1, "_state is one byte wide")
	assert_equal(SaveSectionNavigation.canonical_type_of(0), 2, "_cursor_owner_id is type 2 (i32)")
	assert_equal(SaveSectionNavigation.canonical_type_of(
		SaveSectionNavigation.MOVEMENT_FIELD_COUNT + 22), 2, "_arena is type 2 (i32)")


func test_byte_order_is_little_endian_on_this_build() -> void:
	"""The bulk packed-array conversions inherit host byte order, so it is probed, not assumed."""
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.byte_order_refusal()
	assert_true(refusal.is_ok(), "this build is little-endian: %s" % refusal.detail)


# --- byte arithmetic ------------------------------------------------------------------------------

func test_block_and_section_byte_arithmetic() -> void:
	"""Every declared length, computed from the compiled extents rather than restated."""
	assert_equal(SaveSectionNavigation.MOVEMENT_PAYLOAD_BYTES, 18504,
		"9 columns x (8 + 512*4)")
	assert_equal(SaveSectionNavigation.NAVIGATION_PAYLOAD_FIXED_BYTES, 5161468,
		"13*12 + 4*(8+1048576) + (8+262144) + 16*(8+1024) + 21*(8+32768) + 2*8")
	assert_equal(SaveSectionNavigation.OFFSET_MOVEMENT_PAYLOAD, 36,
		"store_count(4) + the 32-byte movement wrapper")
	assert_equal(SaveSectionNavigation.OFFSET_NAVIGATION_WRAPPER, 18540, "36 + 18504")
	assert_equal(SaveSectionNavigation.OFFSET_NAVIGATION_PAYLOAD, 18574,
		"18540 + the 34-byte navigation wrapper")
	assert_equal(SaveSectionNavigation.SECTION_FIXED_BYTES, 5180042,
		"an empty navigator: 18574 + 5161468")
	assert_equal(SaveSectionNavigation.SECTION_MAX_BYTES, 10422922,
		"a full heap and a full arena add 4*(262144 + 1048576)")


func test_section_bytes_track_the_two_used_prefixes() -> void:
	"""Section length is a function of `_heap_size` and `_arena_used`, not a constant."""
	assert_equal(SaveSectionNavigation.section_bytes_of(_record), 5180042, "empty prefixes")
	_record.set_scalar(SaveSectionNavigation.SCALAR_HEAP_SIZE, 7)
	_record.set_scalar(SaveSectionNavigation.SCALAR_ARENA_USED, 11)
	assert_equal(SaveSectionNavigation.section_bytes_of(_record), 5180042 + 4 * 18,
		"eighteen more elements is seventy-two more bytes")
	assert_equal(SaveSectionNavigation.navigation_payload_bytes(7, 11), 5161468 + 72,
		"the navigation block's declared payload length grows with them")


func test_wire_offsets_walk_the_declared_layout() -> void:
	"""Field offsets accumulate every preceding count word and value run, in wire order."""
	assert_equal(SaveSectionNavigation.wire_count_offset(_record, 0), 36,
		"the first movement column begins right after its wrapper")
	assert_equal(SaveSectionNavigation.wire_value_offset(_record, 0), 44, "36 + 8")
	assert_equal(SaveSectionNavigation.wire_count_offset(_record, 1), 44 + 2048,
		"a 512-row i32 column is 2048 bytes")
	assert_equal(SaveSectionNavigation.wire_count_offset(_record,
		SaveSectionNavigation.MOVEMENT_FIELD_COUNT), 18574,
		"the first navigation column begins right after the navigation wrapper")
	assert_equal(SaveSectionNavigation.wire_value_offset(_record,
		SaveSectionNavigation.MOVEMENT_FIELD_COUNT + 12), 18574 + 12 * 12 + 8,
		"the thirteenth scalar sits after twelve count-plus-value pairs")


func test_pinned_framing_vector() -> void:
	"""The real first 36 bytes and the real navigation wrapper of an empty navigator."""
	var bytes: PackedByteArray = _encode(_record)
	assert_equal(_hex(bytes.slice(0, 36)),
		"02000000" + "08000000" + "6d6f76656d656e74" + "01000000"
			+ "0002000000000000" + "4848000000000000",
		"store_count 2, 'movement', schema 1, primary 512, payload 18504")
	assert_equal(_hex(bytes.slice(18540, 18574)),
		"0a000000" + "6e617669676174696f6e" + "02000000"
			+ "0020000000000000" + "fcc14e0000000000",
		"'navigation', schema 2, primary 8192, payload 0x004ec1fc = 5161468")
	assert_equal(bytes.size(), 5180042, "an empty navigator encodes to the fixed floor")


func test_blocks_tile_the_section_with_no_gaps() -> void:
	"""Each block's payload ends exactly where the next block's wrapper begins."""
	var bytes: PackedByteArray = _encode(_record)
	assert_equal(SaveSectionNavigation.OFFSET_MOVEMENT_PAYLOAD
		+ SaveSectionNavigation.MOVEMENT_PAYLOAD_BYTES,
		SaveSectionNavigation.OFFSET_NAVIGATION_WRAPPER, "no gap between the two blocks")
	assert_equal(SaveSectionNavigation.OFFSET_NAVIGATION_PAYLOAD
		+ SaveSectionNavigation.navigation_payload_bytes(0, 0), bytes.size(),
		"the navigation payload ends at the section end")


func _value_at(bytes: PackedByteArray, wire: int, index: int) -> int:
	"""The `index`-th i32 of one wire field, read straight out of the encoded section."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	var offset: int = SaveSectionNavigation.wire_value_offset(_record, wire) + index * 4
	assert_true(SaveCodec.read_i32_at(bytes, offset, scalar), "the field is inside the section")
	return scalar.value


func test_each_declared_ordinal_lands_on_its_own_column() -> void:
	"""Pinned ordinal-to-wire identity: the bytes at a field's offset hold THAT field's values.

	A round trip cannot catch a swapped pair of ordinals, because encode and decode would swap
	them together and agree. Reading the encoded bytes at the declared offset and comparing with
	the named column can, which is why the expected values below name the column and not the
	ordinal.
	"""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var first: int = SaveSectionNavigation.MOVEMENT_FIELD_COUNT
	assert_equal(_value_at(bytes, first + 15, 0), 5, "ordinal 15 is _d_generation, descriptor 0")
	assert_equal(_value_at(bytes, first + 38, 0), 1, "ordinal 38 is _r_job_generation, row 0")
	assert_equal(_value_at(bytes, first + 40, 0), NEAR_GOAL_CELL,
		"ordinal 40 is _r_goal_cell, row 0")
	assert_equal(_value_at(bytes, first + 41, 0), 1, "ordinal 41 is _r_clearance, row 0")
	assert_equal(_value_at(bytes, first + 45, 0), 5, "ordinal 45 is _r_route_generation, row 0")
	assert_equal(_value_at(bytes, first + 56, 0), 4,
		"ordinal 56 is _c_requester_persistent_id, row 0")
	assert_equal(_value_at(bytes, 0, 0), 12, "movement ordinal 0 is _cursor_owner_id, row 0")
	assert_equal(_value_at(bytes, 1, 0), 0, "movement ordinal 1 is _cursor_request, row 0")
	assert_equal(_value_at(bytes, 7, 0), 250, "movement ordinal 7 is _cursor_load_g, row 0")


# --- round trip ------------------------------------------------------------------------------------

func test_empty_navigator_round_trip() -> void:
	"""`clear()` is the state `navigation.gd::_init()` leaves, and it survives a round trip."""
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_true(refusal.is_ok(), "a freshly built navigator validates: %s" % refusal.detail)
	var bytes: PackedByteArray = _encode(_record)
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	var decoded: SaveHeader.Refusal = _decode(bytes, back)
	assert_true(decoded.is_ok(), "decode succeeds: %s %s" % [decoded.code, decoded.detail])
	assert_true(back.equals(_record), "every column survives the round trip")
	assert_equal(_hex(_encode(back).slice(0, 64)), _hex(bytes.slice(0, 64)),
		"re-encoding the decoded Record reproduces the same bytes")


func test_populated_round_trip_is_byte_identical() -> void:
	"""A stored route, a READY holder, a queued request and an attached cursor all survive."""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	assert_equal(bytes.size(), 5180042 + 4 * 3, "three arena cells lengthen the section")
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	var decoded: SaveHeader.Refusal = _decode(bytes, back)
	assert_true(decoded.is_ok(), "decode succeeds: %s %s" % [decoded.code, decoded.detail])
	assert_true(back.equals(_record), "every column survives the round trip")
	assert_true(_encode(back) == bytes, "re-encode is byte-identical")


func test_round_trip_preserves_the_route_generation_namespace() -> void:
	"""Descriptor generation 5 and requester directory generation 1 come back as themselves."""
	_populate(_record)
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	assert_true(_decode(_encode(_record), back).is_ok(), "decode succeeds")
	assert_equal(back.descriptor(SaveSectionNavigation.DESC_GENERATION, 0), 5,
		"the ROUTE descriptor generation")
	assert_equal(back.request(SaveSectionNavigation.REQ_ROUTE_GENERATION, 0), 5,
		"the holder carries the same ROUTE generation")
	assert_equal(back.request(SaveSectionNavigation.REQ_JOB_GENERATION, 0), 1,
		"the requester's DIRECTORY generation is a different number in a different space")
	assert_equal(back.cursor(SaveSectionNavigation.MOV_ROUTE_GENERATION, 0), 5,
		"the movement cursor carries the ROUTE generation too")


func test_decode_at_a_nonzero_offset() -> void:
	"""A section decodes from inside a larger buffer, as it does inside a save file."""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var padded: PackedByteArray = PackedByteArray()
	padded.resize(1216)
	padded.append_array(bytes)
	padded.append_array(PackedByteArray([1, 2, 3]))
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	var decoded: SaveHeader.Refusal = SaveSectionNavigation.decode_into(padded, 1216, back)
	assert_true(decoded.is_ok(), "decode at 1216 succeeds: %s" % decoded.detail)
	assert_true(back.equals(_record), "and reads the same state")


# --- the used prefix, and the tail that must not be persisted --------------------------------------

func test_arena_tail_garbage_is_dropped_at_capture() -> void:
	"""Two worlds differing ONLY past `_arena_used` capture and encode to identical bytes.

	This is the whole point of a used prefix. `_compact_arena()` leaves the old copy of every moved
	block behind, so the tail genuinely differs between worlds that are observationally identical;
	persisting it would give them different bytes and different CRCs.
	"""
	var live: PackedInt32Array = PackedInt32Array()
	live.resize(NavigationScript.ROUTE_CELL_CAPACITY)
	for index: int in 6:
		live[index] = ANCHOR_CELL + index
	var other: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	assert_true(SaveSectionNavigation.set_navigation_prefix_column(_record, 22, live, 4).is_ok(),
		"the clean column is captured")
	live[9] = 999
	live[4000] = 12345
	assert_true(SaveSectionNavigation.set_navigation_prefix_column(other, 22, live, 4).is_ok(),
		"the column with tail garbage is captured")
	assert_true(_record.arena == other.arena, "both keep only the four used cells")
	assert_equal(_record.arena[4], 0, "the first tail cell is zeroed, not the live residue")
	assert_true(_encode(_record) == _encode(other), "and both encode to identical bytes")


func test_heap_tail_garbage_is_dropped_at_capture() -> void:
	"""`_heap_pop()` leaves the popped entry at `_heap[_heap_size]`; it is not persisted."""
	var live: PackedInt32Array = PackedInt32Array()
	live.resize(SpatialWorldScript.CELL_COUNT)
	live[0] = ANCHOR_CELL
	live[1] = ANCHOR_CELL + 1
	assert_true(SaveSectionNavigation.set_navigation_prefix_column(_record, 19, live, 1).is_ok(),
		"one heap entry is captured")
	assert_equal(_record.scalar(SaveSectionNavigation.SCALAR_HEAP_SIZE), 1,
		"the count scalar is set by the same call, so the two cannot disagree")
	assert_equal(_record.heap[1], 0, "the popped residue is gone")
	assert_equal(SaveSectionNavigation.wire_field_count(_record,
		SaveSectionNavigation.MOVEMENT_FIELD_COUNT + 19), 1, "one element goes on the wire")


func test_a_record_carrying_tail_residue_is_refused() -> void:
	"""A Record built by hand with a nonzero tail cannot be encoded: the bytes would not be canonical."""
	_populate(_record)
	_record.arena[900] = ANCHOR_CELL
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_PREFIX_TAIL,
		"arena residue is refused: %s" % refusal.detail)
	var out: SaveSectionNavigation.EncodeResult = SaveSectionNavigation.EncodeResult.new()
	assert_false(SaveSectionNavigation.encode_record(_record, out), "and encode refuses too")
	assert_equal(out.bytes.size(), 0, "a refusing encode produces no bytes")


func test_decode_restores_a_zero_tail() -> void:
	"""The wire carries the prefix only, so a decoded tail is zero and re-encoding is stable."""
	_populate(_record)
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	back.arena[5000] = 77
	back.heap[77] = 5000
	assert_true(_decode(_encode(_record), back).is_ok(), "decode succeeds")
	assert_equal(back.arena[5000], 0, "the caller's stale tail is replaced, not merged")
	assert_equal(back.heap[77], 0, "and so is the heap's")
	assert_equal(back.arena.size(), NavigationScript.ROUTE_CELL_CAPACITY,
		"the column is padded back to full capacity")


func test_prefix_count_beyond_capacity_is_refused() -> void:
	"""A used prefix larger than the column cannot be captured or validated."""
	var live: PackedInt32Array = PackedInt32Array()
	live.resize(NavigationScript.ROUTE_CELL_CAPACITY)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.set_navigation_prefix_column(
		_record, 22, live, NavigationScript.ROUTE_CELL_CAPACITY + 1)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_PREFIX_COUNT,
		"an oversized prefix is refused: %s" % refusal.detail)
	_record.set_scalar(SaveSectionNavigation.SCALAR_HEAP_SIZE, -1)
	assert_equal(SaveSectionNavigation.record_refusal(_record).code,
		SaveSectionNavigation.REFUSE_PREFIX_COUNT, "a negative heap size is refused")


# --- framing refusals ------------------------------------------------------------------------------

func test_wrong_store_count_is_refused() -> void:
	"""§9 declares exactly two owners."""
	var bytes: PackedByteArray = _patch(_encode(_record), 0, 1, SaveCodec.U32_BYTES)
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	var refusal: SaveHeader.Refusal = _decode(bytes, back)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_STORE_COUNT,
		"one store is refused: %s" % refusal.detail)


func test_blocks_out_of_ascii_order_are_refused() -> void:
	"""Swapping the two owner keys is refused by key, not accepted by position.

	A reader that trusted position would then read `movement`'s 512-row cursor columns as
	`navigation`'s scalars and every subsequent offset would be wrong while every length still fit.
	"""
	var bytes: PackedByteArray = _encode(_record)
	var swapped: PackedByteArray = bytes.duplicate()
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_true(SaveCodec.write_u32_into(swapped, 4, 10, scalar), "the key length is widened")
	assert_true(SaveCodec.write_bytes_into(swapped, 8, "navigation".to_utf8_buffer(), scalar),
		"'navigation' is written into the first block")
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	var refusal: SaveHeader.Refusal = _decode(swapped, back)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_BLOCK_ORDER,
		"the first block must be 'movement': %s" % refusal.detail)
	assert_true(back.equals(SaveSectionNavigation.Record.new()), "and nothing was written")


func test_wrong_owner_schema_versions_are_refused() -> void:
	"""Version 1 navigation state is ARCH-PATH-003 anchor composition and has no migration."""
	var bytes: PackedByteArray = _encode(_record)
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	var movement: SaveHeader.Refusal = _decode(_patch(bytes, 16, 2, SaveCodec.U32_BYTES), back)
	assert_equal(movement.code, SaveSectionNavigation.REFUSE_OWNER_SCHEMA_VERSION,
		"movement schema 2 is refused: %s" % movement.detail)
	var navigation: SaveHeader.Refusal = _decode(_patch(bytes, 18554, 1, SaveCodec.U32_BYTES),
		back)
	assert_equal(navigation.code, SaveSectionNavigation.REFUSE_OWNER_SCHEMA_VERSION,
		"navigation schema 1 is refused: %s" % navigation.detail)


func test_wrong_primary_counts_are_refused() -> void:
	"""Each block's declared primary count is the owner's, validated rather than trusted."""
	var bytes: PackedByteArray = _encode(_record)
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	var movement: SaveHeader.Refusal = _decode(_patch(bytes, 20, 511, SaveCodec.U64_BYTES), back)
	assert_equal(movement.code, SaveSectionNavigation.REFUSE_PRIMARY_COUNT,
		"movement primary 511 is refused: %s" % movement.detail)
	var navigation: SaveHeader.Refusal = _decode(_patch(bytes, 18558, 256, SaveCodec.U64_BYTES),
		back)
	assert_equal(navigation.code, SaveSectionNavigation.REFUSE_PRIMARY_COUNT,
		"navigation primary 256 is refused: %s" % navigation.detail)


func test_payload_length_disagreeing_with_the_body_is_refused() -> void:
	"""`payload_byte_length` is recomputed from the decoded prefix counts, never believed."""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	var movement: SaveHeader.Refusal = _decode(_patch(bytes, 28, 18500, SaveCodec.U64_BYTES),
		back)
	assert_equal(movement.code, SaveSectionNavigation.REFUSE_PAYLOAD_LENGTH,
		"a short movement payload length is refused: %s" % movement.detail)
	var navigation: SaveHeader.Refusal = _decode(
		_patch(bytes, 18566, 5161468 + 4 * 2, SaveCodec.U64_BYTES), back)
	assert_equal(navigation.code, SaveSectionNavigation.REFUSE_PAYLOAD_LENGTH,
		("a length claiming two arena cells over a three-cell body is refused, and the body is "
			+ "what settles it: %s") % navigation.detail)
	var long_claim: SaveHeader.Refusal = _decode(
		_patch(bytes, 18566, 5161468 + 4 * 4, SaveCodec.U64_BYTES), back)
	assert_equal(long_claim.code, SaveSectionNavigation.REFUSE_TRUNCATED,
		"claiming four cells runs off the end of the buffer: %s" % long_claim.detail)
	assert_true(back.equals(SaveSectionNavigation.Record.new()), "and nothing was written")


func test_payload_length_outside_the_compiled_bounds_is_refused_before_reading() -> void:
	"""The extent gate bounds the declared length against the compiled capacities first."""
	var bytes: PackedByteArray = _encode(_record)
	var low: SaveHeader.Refusal = SaveSectionNavigation.extent_refusal(
		_patch(bytes, 18566, 12, SaveCodec.U64_BYTES), 0)
	assert_equal(low.code, SaveSectionNavigation.REFUSE_PAYLOAD_LENGTH,
		"a payload below the fixed floor is refused: %s" % low.detail)
	var high: SaveHeader.Refusal = SaveSectionNavigation.extent_refusal(
		_patch(bytes, 18566, SaveSectionNavigation.NAVIGATION_PAYLOAD_MAX_BYTES + 1,
			SaveCodec.U64_BYTES), 0)
	assert_equal(high.code, SaveSectionNavigation.REFUSE_PAYLOAD_LENGTH,
		"a payload above the ceiling is refused: %s" % high.detail)


func test_wrong_element_count_is_refused() -> void:
	"""A prefix column declaring its full capacity instead of its used prefix is refused."""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = SaveSectionNavigation.wire_count_offset(_record,
		SaveSectionNavigation.MOVEMENT_FIELD_COUNT + 22)
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	var refusal: SaveHeader.Refusal = _decode(
		_patch(bytes, offset, NavigationScript.ROUTE_CELL_CAPACITY, SaveCodec.U64_BYTES), back)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_ELEMENT_COUNT,
		"the arena column must declare `_arena_used` elements: %s" % refusal.detail)


func test_extent_and_truncation_gates() -> void:
	"""A negative offset, a short buffer and a section one byte short are all refused."""
	var bytes: PackedByteArray = _encode(_record)
	assert_equal(SaveSectionNavigation.extent_refusal(bytes, -1).code,
		SaveSectionNavigation.REFUSE_NEGATIVE_OFFSET, "a negative offset is refused")
	assert_equal(SaveSectionNavigation.extent_refusal(PackedByteArray(), 0).code,
		SaveSectionNavigation.REFUSE_TRUNCATED, "an empty buffer is refused")
	assert_true(SaveSectionNavigation.extent_refusal(bytes, 0).is_ok(), "a whole section fits")
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	var refusal: SaveHeader.Refusal = _decode(bytes.slice(0, bytes.size() - 1), back)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_TRUNCATED,
		"one byte short is refused: %s" % refusal.detail)


func test_section_length_refusal_compares_against_this_state() -> void:
	"""A descriptor's declared section length is checked against what the state encodes to."""
	_populate(_record)
	assert_true(SaveSectionNavigation.section_length_refusal(5180042 + 12, _record).is_ok(),
		"the true length is accepted")
	assert_equal(SaveSectionNavigation.section_length_refusal(5180042, _record).code,
		SaveSectionNavigation.REFUSE_LENGTH, "the empty-navigator length is refused for this state")


# --- validate then commit ---------------------------------------------------------------------------

func test_full_length_invalid_section_leaves_the_record_untouched() -> void:
	"""Decision 0059 on a FULL-LENGTH payload: a retired phase is refused after the last byte is read.

	A truncation refusal proves nothing about commit ordering, because the copy never had the bytes
	to make. This fixture is complete, well-framed and semantically impossible.
	"""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = SaveSectionNavigation.wire_value_offset(_record,
		SaveSectionNavigation.MOVEMENT_FIELD_COUNT + 16)
	var broken: PackedByteArray = _patch(bytes, offset + 4,
		NavigationScript.PHASE_SEARCHING_LOCAL, SaveCodec.U32_BYTES)
	assert_equal(broken.size(), bytes.size(), "the fixture is still full length")
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	_populate(back)
	var refusal: SaveHeader.Refusal = _decode(broken, back)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_RETIRED_PHASE,
		"PHASE_SEARCHING_LOCAL is retired by PATH-R02: %s" % refusal.detail)
	assert_true(back.equals(_record), "and the caller's Record is byte-identical")


func test_full_length_invalid_arena_window_leaves_the_record_untouched() -> void:
	"""A descriptor whose window runs past the arena used prefix is refused after a full read."""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = SaveSectionNavigation.wire_value_offset(_record,
		SaveSectionNavigation.MOVEMENT_FIELD_COUNT + 31)
	var broken: PackedByteArray = _patch(bytes, offset, 4, SaveCodec.U32_BYTES)
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	var refusal: SaveHeader.Refusal = _decode(broken, back)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_DESCRIPTOR_WINDOW,
		"a four-cell route in a three-cell prefix is refused: %s" % refusal.detail)
	assert_true(back.equals(SaveSectionNavigation.Record.new()),
		"the caller's Record is still the empty navigator")


func test_the_int32_sign_trap_on_a_route_generation() -> void:
	"""Bytes `00 00 00 80` are read SIGNED as -2147483648 and refused, not taken as 2147483648."""
	assert_equal(SaveCodec.u32_bits_to_int32(0x80000000), -2147483648,
		"the same four bytes read as int32")
	assert_equal(SaveCodec.int32_bits_to_u32(-2147483648), 0x80000000, "and back again")
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = SaveSectionNavigation.wire_value_offset(_record,
		SaveSectionNavigation.MOVEMENT_FIELD_COUNT + 15)
	var broken: PackedByteArray = _patch(bytes, offset, -2147483648, SaveCodec.I32_BYTES)
	assert_equal(_hex(broken.slice(offset, offset + 4)), "00000080", "the pinned trap bytes")
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	var refusal: SaveHeader.Refusal = _decode(broken, back)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_DESCRIPTOR_GENERATION,
		"a negative route generation is refused: %s" % refusal.detail)


# --- semantics: PATH-R02 and the generation namespaces ---------------------------------------------

func test_start_cell_must_equal_exact_start() -> void:
	"""PATH-R02 retains `_r_start_cell` and makes it equal `_r_exact_start`; §9 proves it."""
	_populate(_record)
	_record.set_request(SaveSectionNavigation.REQ_START_CELL, 0, ANCHOR_CELL + 1)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_EXACT_START,
		"an anchor-rewritten origin is version 1 state: %s" % refusal.detail)
	_record.set_request(SaveSectionNavigation.REQ_START_CELL, 0, ANCHOR_CELL)
	assert_true(SaveSectionNavigation.record_refusal(_record).is_ok(),
		"and the two agreeing again is accepted")


func test_a_route_hold_is_checked_against_the_descriptor_generation() -> void:
	"""The hold is compared with `_d_generation` -- the ROUTE space -- and nothing else.

	The fixture's requester carries DIRECTORY generation 1 while the descriptor is at ROUTE
	generation 5, so a validator reading the hold from the wrong namespace would accept the 1 below
	and would also refuse the correct 5 in every other case here.
	"""
	_populate(_record)
	_record.set_request(SaveSectionNavigation.REQ_ROUTE_GENERATION, 0,
		_record.request(SaveSectionNavigation.REQ_JOB_GENERATION, 0))
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_ROUTE_GENERATION,
		"the requester's directory generation is not a route generation: %s" % refusal.detail)
	_record.set_request(SaveSectionNavigation.REQ_ROUTE_GENERATION, 0, 5)
	assert_true(SaveSectionNavigation.record_refusal(_record).is_ok(),
		"the descriptor's own generation is accepted")


func test_a_route_hold_outside_ready_is_refused() -> void:
	"""`_settle_request()` drops the reference exactly once, so only a READY request holds one."""
	_populate(_record)
	_record.set_request(SaveSectionNavigation.REQ_PHASE, 0, NavigationScript.PHASE_CANCELLED)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_ROUTE_HOLD,
		"a cancelled request still holding a route is refused: %s" % refusal.detail)


func test_descriptor_refcounts_must_match_their_holders() -> void:
	"""A refcount too high pins a route forever; too low evicts it under a live holder."""
	_populate(_record)
	_record.set_descriptor(SaveSectionNavigation.DESC_REFCOUNT, 0, 2)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_DESCRIPTOR_REFCOUNT,
		"two references against one holder is refused: %s" % refusal.detail)
	_record.set_descriptor(SaveSectionNavigation.DESC_REFCOUNT, 0, 1)
	assert_true(SaveSectionNavigation.record_refusal(_record).is_ok(), "one holder, one reference")


func test_retired_descriptor_rules() -> void:
	"""FLAG_RETIRED means the route generation is spent, exactly as §3's slot retirement does."""
	_record.set_descriptor(SaveSectionNavigation.DESC_FLAGS, 3, NavigationScript.FLAG_RETIRED)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_DESCRIPTOR_GENERATION,
		"a retired descriptor at generation 1 is refused: %s" % refusal.detail)
	_record.set_descriptor(SaveSectionNavigation.DESC_GENERATION, 3, IntMathScript.INT32_MAX - 1)
	assert_true(SaveSectionNavigation.record_refusal(_record).is_ok(),
		"retired at the spent generation is accepted")
	_record.set_descriptor(SaveSectionNavigation.DESC_ROUTE_ID, 3, 4)
	assert_equal(SaveSectionNavigation.record_refusal(_record).code,
		SaveSectionNavigation.REFUSE_DESCRIPTOR_IDENTITY, "a descriptor's route id is its own row")


func test_overlapping_route_blocks_are_refused() -> void:
	"""`_acquire_arena()` hands out disjoint runs; two blocks sharing a cell is corruption."""
	_populate(_record)
	_store_route(_record, 1, 1, 2, 3)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_DESCRIPTOR_OVERLAP,
		"[0,3) and [2,5) overlap: %s" % refusal.detail)


# --- queue progress ---------------------------------------------------------------------------------

func test_the_free_list_threads_exactly_the_free_rows() -> void:
	"""A free list that skips a FREE row, or revisits one, is refused."""
	_populate(_record)
	_record.set_scalar(SaveSectionNavigation.SCALAR_FREE_REQUEST_HEAD, 3)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_FREE_LIST,
		"skipping row 2 leaves one FREE row off the list: %s" % refusal.detail)
	_record.set_scalar(SaveSectionNavigation.SCALAR_FREE_REQUEST_HEAD, 2)
	_record.set_request(SaveSectionNavigation.REQ_NEXT_QUEUE, 5, 2)
	assert_equal(SaveSectionNavigation.record_refusal(_record).code,
		SaveSectionNavigation.REFUSE_FREE_LIST, "a cycle is refused, not walked forever")


func test_the_pending_queue_holds_exactly_the_queued_rows() -> void:
	"""A QUEUED request that is not on the queue would never be serviced again."""
	_populate(_record)
	_record.set_scalar(SaveSectionNavigation.SCALAR_QUEUE_HEAD, -1)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_QUEUE_LIST,
		"an empty queue with a QUEUED request is refused: %s" % refusal.detail)


func test_queue_order_is_state() -> void:
	"""`_enqueue()` keeps the queue sorted, so a queue restored out of order services the wrong job.

	Persistent id 9 must not precede persistent id 4: `_queue_precedes()` orders by requester
	persistent id first, and the service loop never re-sorts.
	"""
	_store_route(_record, 0, 5, 0, 3)
	_fill_request(_record, 0, NavigationScript.PHASE_QUEUED, 9)
	_fill_request(_record, 1, NavigationScript.PHASE_QUEUED, 4)
	_record.set_request(SaveSectionNavigation.REQ_NEXT_QUEUE, 0, 1)
	_record.set_scalar(SaveSectionNavigation.SCALAR_QUEUE_HEAD, 0)
	_record.set_scalar(SaveSectionNavigation.SCALAR_FREE_REQUEST_HEAD, 2)
	_record.set_descriptor(SaveSectionNavigation.DESC_REFCOUNT, 0, 0)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_QUEUE_ORDER,
		"id 9 before id 4 is not _enqueue()'s order: %s" % refusal.detail)
	_fill_request(_record, 0, NavigationScript.PHASE_QUEUED, 2)
	_record.set_request(SaveSectionNavigation.REQ_NEXT_QUEUE, 0, 1)
	assert_true(SaveSectionNavigation.record_refusal(_record).is_ok(),
		"id 2 before id 4 is the order the navigator would service")


func test_one_request_holds_the_builder() -> void:
	"""`_active_request` names the single mid-search request, and an idle builder has no heap."""
	_populate(_record)
	_record.set_request(SaveSectionNavigation.REQ_PHASE, 1,
		NavigationScript.PHASE_SEARCHING_FULL)
	_record.set_scalar(SaveSectionNavigation.SCALAR_QUEUE_HEAD, -1)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_ACTIVE_REQUEST,
		"a mid-search request with no active scalar is refused: %s" % refusal.detail)
	_record.set_scalar(SaveSectionNavigation.SCALAR_ACTIVE_REQUEST, 1)
	assert_true(SaveSectionNavigation.record_refusal(_record).is_ok(),
		"naming it as the active request is accepted")
	_record.set_scalar(SaveSectionNavigation.SCALAR_ACTIVE_REQUEST, -1)
	_record.set_request(SaveSectionNavigation.REQ_PHASE, 1, NavigationScript.PHASE_UNREACHABLE)
	_record.set_scalar(SaveSectionNavigation.SCALAR_HEAP_SIZE, 3)
	assert_equal(SaveSectionNavigation.record_refusal(_record).code,
		SaveSectionNavigation.REFUSE_ACTIVE_REQUEST, "an idle builder holding a heap is refused")


func test_heap_positions_must_agree_with_the_heap() -> void:
	"""`_heap_position[_heap[i]] == i` is what makes the min-heap indexed; a load must preserve it."""
	_record.set_scalar(SaveSectionNavigation.SCALAR_SEARCH_SERIAL, 4)
	_record.set_scalar(SaveSectionNavigation.SCALAR_ACTIVE_REQUEST, 0)
	_fill_request(_record, 0, NavigationScript.PHASE_SEARCHING_FULL, 1)
	_record.set_scalar(SaveSectionNavigation.SCALAR_FREE_REQUEST_HEAD, 1)
	_record.heap[0] = ANCHOR_CELL
	_record.set_scalar(SaveSectionNavigation.SCALAR_HEAP_SIZE, 1)
	_record.set_cell(SaveSectionNavigation.CELL_STAMP, ANCHOR_CELL, 4)
	_record.state[ANCHOR_CELL] = NavigationScript.STATE_OPEN
	_record.set_cell(SaveSectionNavigation.CELL_HEAP_POSITION, ANCHOR_CELL, 1)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_HEAP_POSITION,
		"a cell at slot 0 recording position 1 is refused: %s" % refusal.detail)
	_record.set_cell(SaveSectionNavigation.CELL_HEAP_POSITION, ANCHOR_CELL, 0)
	assert_true(SaveSectionNavigation.record_refusal(_record).is_ok(),
		"the agreeing pair is accepted")


func test_a_stamp_above_the_search_serial_is_refused() -> void:
	"""Stamps are written AT the current serial, so none can exceed it."""
	_record.set_cell(SaveSectionNavigation.CELL_STAMP, ANCHOR_CELL, 1)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_STAMP_RANGE,
		"stamp 1 against serial 0 is refused: %s" % refusal.detail)
	_record.set_scalar(SaveSectionNavigation.SCALAR_SEARCH_SERIAL, 1)
	assert_true(SaveSectionNavigation.record_refusal(_record).is_ok(),
		"raising the serial to 1 accepts it")


func test_a_state_byte_outside_the_enum_is_refused() -> void:
	"""`_state` is UNTOUCHED, OPEN or CLOSED and nothing else."""
	_record.state[7] = 3
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_STATE_BYTE,
		"state 3 is refused: %s" % refusal.detail)


# --- movement cursors ---------------------------------------------------------------------------

func test_a_detached_cursor_carries_the_whole_null_tuple() -> void:
	"""`stop()` writes all nine columns; a row that kept one of them is corruption, not residue."""
	_record.set_cursor(SaveSectionNavigation.MOV_ROUTE_GENERATION, 3, 5)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_CURSOR_IDLE,
		"a detached row holding a route generation is refused: %s" % refusal.detail)
	_record.set_cursor(SaveSectionNavigation.MOV_ROUTE_GENERATION, 3, 0)
	_record.set_cursor(SaveSectionNavigation.MOV_LOAD_G, 3, 250)
	assert_equal(SaveSectionNavigation.record_refusal(_record).code,
		SaveSectionNavigation.REFUSE_CURSOR_IDLE, "and so is one holding a committed load")


func test_an_attached_cursor_names_a_real_request_and_admission() -> void:
	"""The terms one journey was admitted under are bounded; a cursor may still be stale."""
	_populate(_record)
	_record.set_cursor(SaveSectionNavigation.MOV_REQUEST, 0,
		NavigationScript.PATH_REQUEST_CAPACITY)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionNavigation.REFUSE_CURSOR_FIELD,
		"a request row past capacity is refused: %s" % refusal.detail)
	_record.set_cursor(SaveSectionNavigation.MOV_REQUEST, 0, 0)
	_record.set_cursor(SaveSectionNavigation.MOV_PROFILE_ID, 0, MovementScript.PROFILE_COUNT)
	assert_equal(SaveSectionNavigation.record_refusal(_record).code,
		SaveSectionNavigation.REFUSE_CURSOR_FIELD, "an unpublished profile id is refused")


func test_a_stale_cursor_is_legal_state() -> void:
	"""`_settle()` leaves a cursor in place on arrival; `_route_still_valid()` is what compares it.

	So a cursor whose route generation no longer matches the descriptor must SURVIVE a save, not be
	refused or quietly repaired -- otherwise an arrived body comes back attached to a live route.
	"""
	_populate(_record)
	_record.set_cursor(SaveSectionNavigation.MOV_ROUTE_GENERATION, 0, 4)
	assert_true(SaveSectionNavigation.record_refusal(_record).is_ok(),
		"a stale cursor generation is accepted")
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	assert_true(_decode(_encode(_record), back).is_ok(), "and round trips")
	assert_equal(back.cursor(SaveSectionNavigation.MOV_ROUTE_GENERATION, 0), 4,
		"coming back stale, not repaired to the descriptor's 5")


func test_movement_columns_are_installed_in_declared_ordinal_order() -> void:
	"""The bulk cursor setter takes ordinal-major values, refusing any other length."""
	var values: PackedInt32Array = PackedInt32Array()
	values.resize(SaveSectionNavigation.MOVEMENT_FIELD_COUNT * MovementScript.MOTION_CAPACITY)
	values[SaveSectionNavigation.MOV_OWNER_ID * MovementScript.MOTION_CAPACITY + 2] = 77
	assert_true(SaveSectionNavigation.set_movement_columns(_record, values).is_ok(),
		"a full-length ordinal-major block is accepted")
	assert_equal(_record.cursor(SaveSectionNavigation.MOV_OWNER_ID, 2), 77,
		"ordinal 0 is _cursor_owner_id, row 2")
	assert_equal(SaveSectionNavigation.set_movement_columns(_record,
		PackedInt32Array([1, 2, 3])).code, SaveSectionNavigation.REFUSE_COLUMN_LENGTH,
		"a short block is refused")


# --- against a live navigator --------------------------------------------------------------------

func test_a_serviced_navigator_captures_encodes_and_decodes() -> void:
	"""Real state: a READY request, a quota-interrupted search and a queued request at once.

	Hand-built fixtures prove the validator refuses what it should; only a serviced navigator
	proves it ACCEPTS what a real world holds.
	"""
	var navigation: NavigationScript = _serviced_navigator()
	assert_true(navigation.has_active_search(), "one search is mid-flight at the save boundary")
	var captured: SaveHeader.Refusal = _capture_live(navigation, _record)
	assert_true(captured.is_ok(), "the live columns are captured: %s" % captured.detail)
	var refusal: SaveHeader.Refusal = SaveSectionNavigation.record_refusal(_record)
	assert_true(refusal.is_ok(), "a real navigator validates: %s %s"
		% [refusal.code, refusal.detail])
	var bytes: PackedByteArray = _encode(_record)
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	var decoded: SaveHeader.Refusal = _decode(bytes, back)
	assert_true(decoded.is_ok(), "and decodes: %s %s" % [decoded.code, decoded.detail])
	assert_true(_encode(back) == bytes, "and re-encodes byte-identically")


func test_a_captured_navigator_agrees_with_the_live_store() -> void:
	"""Every scalar, descriptor and phase the navigator publishes matches the decoded Record."""
	var navigation: NavigationScript = _serviced_navigator()
	assert_true(_capture_live(navigation, _record).is_ok(), "the live columns are captured")
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	assert_true(_decode(_encode(_record), back).is_ok(), "the section round trips")
	var agrees: SaveHeader.Refusal = SaveSectionNavigation.agrees_with_navigation(back, navigation)
	assert_true(agrees.is_ok(), "the decoded record agrees with the navigator: %s %s"
		% [agrees.code, agrees.detail])
	assert_equal(back.scalar(SaveSectionNavigation.SCALAR_ARENA_USED), navigation.arena_used(),
		"including the arena used prefix")


func test_a_captured_partial_search_keeps_its_heap_and_progress() -> void:
	"""The interrupted search's heap, expansion spend and active request all survive the section."""
	var navigation: NavigationScript = _serviced_navigator()
	assert_true(_capture_live(navigation, _record).is_ok(), "the live columns are captured")
	var heap_size: int = _record.scalar(SaveSectionNavigation.SCALAR_HEAP_SIZE)
	assert_true(heap_size > 0, "the interrupted search left an open set of %d cells" % heap_size)
	var back: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	assert_true(_decode(_encode(_record), back).is_ok(), "the section round trips")
	assert_equal(back.scalar(SaveSectionNavigation.SCALAR_HEAP_SIZE), heap_size,
		"the whole open set comes back")
	assert_equal(back.scalar(SaveSectionNavigation.SCALAR_ACTIVE_REQUEST),
		navigation.active_request_row(), "and the request that owns it")
	assert_equal(back.scalar(SaveSectionNavigation.SCALAR_EXPANSIONS_TOTAL),
		navigation.total_expansions(), "with the expansions it has already spent")


func test_a_disagreeing_store_is_reported() -> void:
	"""`agrees_with_navigation()` is a real cross-check, not a formality."""
	var navigation: NavigationScript = _serviced_navigator()
	assert_true(_capture_live(navigation, _record).is_ok(), "the live columns are captured")
	_record.set_scalar(SaveSectionNavigation.SCALAR_EXPANSIONS_TOTAL,
		navigation.total_expansions() + 1)
	var agrees: SaveHeader.Refusal = SaveSectionNavigation.agrees_with_navigation(_record,
		navigation)
	assert_equal(agrees.code, SaveSectionNavigation.REFUSE_STORE_MISMATCH,
		"one expansion of drift is reported: %s" % agrees.detail)


# --- house rules -----------------------------------------------------------------------------------

func test_the_source_holds_no_float() -> void:
	"""ARCH-AUTH-002: authoritative state is integer, and section 9 is authoritative state."""
	var file: FileAccess = FileAccess.open(
		"res://scripts/core/save_section_navigation.gd", FileAccess.READ)
	assert_not_null(file, "the section 9 source is readable")
	var source: String = file.get_as_text()
	assert_false(source.contains(": float"), "no float-typed declaration")
	assert_false(source.contains("-> float"), "no float return")
	assert_false(source.contains("PackedFloat"), "no float column")


func test_record_copy_and_equality_cover_every_block() -> void:
	"""`equals()` is what proves a refusal changed nothing, so it must see all eight blocks."""
	_populate(_record)
	var other: SaveSectionNavigation.Record = SaveSectionNavigation.Record.new()
	assert_false(other.equals(_record), "an empty Record differs from a populated one")
	other.copy_from(_record)
	assert_true(other.equals(_record), "copy_from reproduces every block")
	other.arena[0] = 0
	assert_false(other.equals(_record), "one arena cell is enough to differ")
	other.copy_from(_record)
	other.set_cursor(SaveSectionNavigation.MOV_LOAD_G, 0, 251)
	assert_false(other.equals(_record), "and so is one movement cursor value")
