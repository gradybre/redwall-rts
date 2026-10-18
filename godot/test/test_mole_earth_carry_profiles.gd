extends "res://test/framework/test_case.gd"
## Decision 2042: the content-13 publication (`qualified-earth-carry-v14`) loads through the actual Profiles loader and
## validator, and its grip-certificate successor certifies the earth family. Data only: not the active catalog.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Earth := preload("res://data/underground/mole-worker/qualified-earth-carry-v14/catalog_source.gd")
const Cert := preload("res://data/underground/mole-worker/qualified-earth-carry-v14/grip_certificate.gd")
const Carry := preload("res://data/underground/mole-worker/qualified-stair-carry-v13/catalog_source.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-stairs-v11/catalog_source.gd")
const Previous := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/grip_certificate.gd")
const CLAW_WIRE: String = "res://data/underground/mole-worker/qualified-claw-stairs-v11/mole-worker.ugprof"
const CLAW_COUNTS: Vector3i = Vector3i(67, 547, 6)
const EARTH_WIRE: String = "res://data/underground/mole-worker/qualified-earth-carry-v14/mole-worker.ugprof"
const CARRY_WIRE: String = "res://data/underground/mole-worker/qualified-stair-carry-v13/mole-worker.ugprof"
const ITEMS: String = "res://data/item_definitions.json"
const TEMP_PATH: String = "user://earth-carry-negative.ugprof"
const EARTH_COUNTS: Vector3i = Vector3i(96, 698, 10)
const CARRY_COUNTS: Vector3i = Vector3i(85, 637, 8)
const Q_MIN_AT: int = 72 + 8 * Profiles.L_QUANTITY_MIN
const Q_MAX_AT: int = 72 + 8 * Profiles.L_QUANTITY_MAX
var _earth: Profiles = null
var _carry: Profiles = null
var _last_load: StringName = &""


func before_each() -> void:
	"""Both publications through the actual loader."""
	_earth = _loaded(EARTH_WIRE, Earth.WIRE_SHA, 13, EARTH_COUNTS)
	_carry = _loaded(CARRY_WIRE, Carry.WIRE_SHA, 12, CARRY_COUNTS)


func after_each() -> void:
	"""Drop both stores and the negative wire."""
	_earth = null
	_carry = null
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(TEMP_PATH)


func _store(counts: Vector3i) -> Profiles:
	"""One store sized for a publication."""
	var store: Profiles = Profiles.new()
	var packed: int = 2 * (counts.x * Profiles.PROFILE_WIRE_BYTES + counts.y * 28 + counts.z * 32 + 32)
	assert_equal(store.configure(counts.x, counts.y, counts.z, packed + Profiles.CONTROL_RESERVE), &"", "capacity")
	return store


func _loaded(path: String, digest: String, revision: int, counts: Vector3i) -> Profiles:
	"""One configured store with the publication loaded and validated."""
	var store: Profiles = _store(counts)
	assert_equal(store.load_file(path, digest, revision), &"", "actual loader and validator")
	return store


func _field(store: Profiles, field: int, row: int) -> int:
	"""One stored descriptor word."""
	return store._live.fields[field * store._profile_capacity + row]


func _long(store: Profiles, field: int, row: int) -> int:
	"""One stored int64 word."""
	return store._live.quantities[field * store._profile_capacity + row]


func _boxes(store: Profiles, row: int) -> Array[int]:
	"""Every box word of one row."""
	var result: Array[int] = []
	var first: int = _field(store, Profiles.F_FIRST_BOX, row)
	for box: int in range(first, first + _field(store, Profiles.F_BOX_COUNT, row)):
		for word: int in 7:
			result.append(store._live.boxes[word * store._box_capacity + box])
	return result


func _loaded_copy(row: int, edits: Array[Vector2i]) -> Profiles:
	"""A copy of the content-13 wire with int32 words or int64 quantities of `row` edited ((offset, value) each),
	loaded (it must still load)."""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(EARTH_WIRE)
	for edit: Vector2i in edits:
		var at: int = 32 + 32 * EARTH_COUNTS.z + Profiles.PROFILE_WIRE_BYTES * row + edit.x
		if edit.x >= 72:
			bytes.encode_s64(at, edit.y)
		else:
			bytes.encode_s32(at, edit.y)
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var store: Profiles = _store(EARTH_COUNTS)
	_last_load = store.load_file(TEMP_PATH, FileAccess.get_sha256(TEMP_PATH), 13)
	return store


func test_content_twelve_rows_are_unchanged() -> void:
	"""Rows 0-84 keep every word, box and policy byte; sources 8 and 9 are content 12's 3 and 7."""
	for row: int in CARRY_COUNTS.x:
		for field: int in Profiles.I32_FIELDS:
			assert_equal(_field(_earth, field, row), _field(_carry, field, row), "row %d field %d" % [row, field])
		assert_equal(_boxes(_earth, row), _boxes(_carry, row), "row %d boxes" % row)
	assert_equal(_earth._live.sources.slice(8 * 32, 9 * 32), _earth._live.sources.slice(3 * 32, 4 * 32), "src 8")
	assert_equal(_earth._live.sources.slice(9 * 32, 10 * 32), _earth._live.sources.slice(7 * 32, 8 * 32), "src 9")


func test_earth_rows_repeat_the_stone_rows_with_earth_and_five_kilos() -> void:
	"""85-89 are 37-41 on source 8, 90-95 are 79-84 on source 9; carried units are item 11 at 5,000 milli-U."""
	var templates: Array[int] = [37, 38, 39, 40, 41, 79, 80, 81, 82, 83, 84]
	for at: int in templates.size():
		var row: int = 85 + at
		var template: int = templates[at]
		for field: int in Profiles.I32_FIELDS:
			if field in [Profiles.F_SOURCE, Profiles.F_CARGO, Profiles.F_FIRST_BOX]: continue
			assert_equal(_field(_earth, field, row), _field(_earth, field, template), "row %d field %d" % [row, field])
		assert_equal(_boxes(_earth, row), _boxes(_earth, template), "row %d boxes" % row)
		assert_equal(_field(_earth, Profiles.F_SOURCE, row), 8 if row < 90 else 9, "row %d source" % row)
		var carries: bool = _field(_earth, Profiles.F_CARGO, template) != -1
		assert_equal(_field(_earth, Profiles.F_CARGO, row), Earth.EARTH_ITEM if carries else -1, "row %d cargo" % row)
		var quantity: int = Earth.EARTH_QUANTITY_MILLI if carries else 0
		assert_equal([_long(_earth, Profiles.L_QUANTITY_MIN, row), _long(_earth, Profiles.L_QUANTITY_MAX, row)],
			[quantity, quantity], "row %d trip" % row)
		assert_equal(_earth._live.flags[_earth._profile_capacity + row],
			_earth._live.flags[_earth._profile_capacity + template], "row %d policy" % row)


func test_the_earth_item_is_excavated_earth() -> void:
	"""Item 11 is `excavated_earth` in ascending-ASCII order; it weighs 1,000 g/U, so a trip is stone's 5,000 g."""
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS))
	var items: Array = data if data is Array else data["items"]
	var keys: Array[String] = []
	var mass: Dictionary = {}
	for item: Dictionary in items:
		keys.append(String(item["id"]))
		mass[String(item["id"])] = int(item["mass_g"])
	keys.sort()
	assert_equal([keys.find("excavated_earth"), keys.find("stone")], [Earth.EARTH_ITEM, 53], "ids")
	assert_equal(Earth.EARTH_QUANTITY_MILLI * mass["excavated_earth"] / 1000, 1000 * mass["stone"] / 1000, "5 kg")
	assert_equal([Earth.EARTH_LEVEL_ROWS, Earth.EARTH_STAIR_ROWS],
		[PackedInt32Array([85, 86, 87, 88, 89]), PackedInt32Array([90, 91, 92, 93, 94, 95])], "row ids")


func test_rooted_earth_rows_select_as_their_stone_templates() -> void:
	"""Since content 12's activation (#272) Profiles selects the rooted words: each earth stair row selects exactly as
	its stone template, and a stale content revision selects nothing."""
	for row: int in Earth.EARTH_STAIR_ROWS:
		var leaf: int = Profiles.selection_policy_leaf(_earth, row, 1, 13)
		assert_equal(leaf, Profiles.selection_policy_leaf(_earth, row - 11, 1, 13), "row %d as row %d" % [row, row - 11])
		assert_true(Profiles.is_rooted_policy(leaf), "row %d rooted" % row)
		assert_equal(Profiles.selection_policy_leaf(_earth, row, 1, 12), -1, "row %d, stale revision" % row)


func test_the_certificate_certifies_all_three_families() -> void:
	"""Wood, stone and earth: every row exact; items to CARRY rows; 1,000 / 1,000 / 5,000 milli-U a trip."""
	assert_true(Cert.uses(_earth), "content 13, fifteen rows")
	for family: int in 3:
		for offset: int in 5:
			assert_equal(Cert.profile_refusal(_earth, Cert.carry_of(family) + offset), &"", "family %d" % family)
	assert_equal([Cert.carry_row_for(60), Cert.carry_row_for(53), Cert.carry_row_for(11), Cert.carry_row_for(12)],
		[32, 37, 85, -1], "carry rows")
	assert_equal([Cert.quantity_of(60), Cert.quantity_of(53), Cert.quantity_of(11), Cert.quantity_of(0)],
		[1000, 1000, 5000, -1], "trips")
	assert_equal([Cert.family_of(31), Cert.family_of(32), Cert.family_of(41), Cert.family_of(84), Cert.family_of(85),
		Cert.family_of(89), Cert.family_of(90)], [-1, 0, 1, -1, 2, 2, -1], "families")
	assert_equal([Cert.item_of(36), Cert.item_of(41), Cert.item_of(89), Cert.item_of(90)], [60, 53, 11, -1], "items")
	assert_equal([Cert.carry_of(3), Cert.template_of(87), Cert.template_of(40)], [-1, 39, 40], "templates")
	assert_equal([Cert.is_grip(85), Cert.is_grip(86), Cert.is_load(87), Cert.is_load(88), Cert.yaw_of(87),
		Cert.yaw_of(88), Cert.yaw_of(89)], [false, true, true, false, Cert.QUARTER, 0, Cert.QUARTER], "grip rows")


func test_the_certificate_refuses_other_content_and_edited_rows() -> void:
	"""Content 12 is the previous certificate's (it certifies content 12 since #272); edited earth rows are refused."""
	assert_equal(Cert.uses(_carry), Previous.uses(_carry), "content 12 follows the previous certificate")
	assert_true(Cert.uses(_carry), "which certifies content 12's wood and stone since #272")
	assert_equal(Cert.profile_refusal(_carry, 37), Previous.profile_refusal(_carry, 37), "content 12's stone row")
	assert_equal(Cert.profile_refusal(_carry, 85), Cert.REFUSE_PROFILE, "content 12 has no earth family")
	assert_equal(Cert.profile_refusal(_earth, 90), Cert.REFUSE_PROFILE, "a stair row is not a grip row")
	assert_equal(Cert.profile_refusal(null, 85), Cert.REFUSE_PROFILE, "no store")
	var light: Profiles = _loaded_copy(85, [Vector2i(Q_MIN_AT, 1000), Vector2i(Q_MAX_AT, 1000)])
	assert_equal(_last_load, &"", "a 1,000 milli-U earth trip loads")
	assert_equal(Cert.profile_refusal(light, 85), Cert.REFUSE_PROFILE, "but is not certified")
	var revised: Profiles = _loaded_copy(86, [Vector2i(72 + 8 * Profiles.L_REVISION, 2)])
	assert_equal(_last_load, &"", "a revised earth row loads")
	assert_equal(Cert.profile_refusal(revised, 86), Cert.REFUSE_PROFILE, "but is not certified")
	assert_false(Cert.uses(revised), "and the family is not in use")
	var heavy: Profiles = _loaded_copy(85, [Vector2i(Q_MAX_AT, 6000)])
	assert_equal(_last_load, &"", "a 5,000-6,000 milli-U earth trip loads")
	assert_equal(Cert.profile_refusal(heavy, 85), Cert.REFUSE_PROFILE, "but is not certified")
	var elsewhere: Profiles = _loaded_copy(86, [Vector2i(Profiles.F_SOURCE * 4, 6)])
	assert_equal(_last_load, &"", "an earth load row on the wood stair source loads")
	assert_equal(Cert.profile_refusal(elsewhere, 86), Cert.REFUSE_PROFILE, "but is not certified")
	var boxes: PackedByteArray = FileAccess.get_file_as_bytes(EARTH_WIRE)
	var box_at: int = 32 + 32 * EARTH_COUNTS.z + Profiles.PROFILE_WIRE_BYTES * EARTH_COUNTS.x + 28 * Cert.EARTH_FIRST_BOX[0]
	boxes.encode_s32(box_at, boxes.decode_s32(box_at) - 1)
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_buffer(boxes)
	file.close()
	var widened: Profiles = _store(EARTH_COUNTS)
	assert_equal(widened.load_file(TEMP_PATH, FileAccess.get_sha256(TEMP_PATH), 13), &"", "a widened earth box loads")
	assert_equal(Cert.profile_refusal(widened, 85), Cert.REFUSE_PROFILE, "but is not certified")


func test_the_earth_source_must_be_the_stone_image() -> void:
	"""Source 8 carrying the wood haul image's digest still loads, but no earth row is certified on it."""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(EARTH_WIRE)
	for byte: int in 32:
		bytes[32 + 8 * 32 + byte] = bytes[32 + 2 * 32 + byte]
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var swapped: Profiles = _store(EARTH_COUNTS)
	assert_equal(swapped.load_file(TEMP_PATH, FileAccess.get_sha256(TEMP_PATH), 13), &"", "the swapped image loads")
	for row: int in Earth.EARTH_LEVEL_ROWS:
		assert_equal(Cert.profile_refusal(swapped, row), Cert.REFUSE_PROFILE, "row %d on the wood image" % row)
	assert_equal(Cert.profile_refusal(swapped, 37), &"", "stone keeps its own source")
	assert_false(Cert.uses(swapped), "the earth family is not in use")


func test_another_content_is_the_previous_certificate_s() -> void:
	"""Content 10's bank: wood and stone answer as `qualified-claw-runtime-v1` does; earth rows do not exist there."""
	var claw: Profiles = _loaded(CLAW_WIRE, Claw.WIRE_SHA, 10, CLAW_COUNTS)
	assert_true(Previous.uses(claw), "the previous certificate certifies content 10")
	assert_equal(Cert.uses(claw), Previous.uses(claw), "uses follows the loaded content")
	for row: int in range(32, 42):
		assert_equal(Cert.profile_refusal(claw, row), Previous.profile_refusal(claw, row), "row %d" % row)
	assert_equal(Cert.profile_refusal(claw, 85), Cert.REFUSE_PROFILE, "no earth family in content 10")
	var root: Vector3i = Vector3i(4096, 512, -8192)
	assert_equal(Cert.station_refusal(claw, 38, root, 0, root + Vector3i(0, 0, -576)),
		Previous.station_refusal(claw, 38, root, 0, root + Vector3i(0, 0, -576)), "stations too")
	assert_equal(Cert.station_refusal(claw, 86, root, 0, root + Vector3i(0, 0, -576)), Cert.REFUSE_PROFILE, "earth")
	assert_equal([Cert.QUANTITY_MILLI, Cert.stock_offset(0), Cert.stock_offset(Cert.QUARTER),
		Cert.turn(Vector3i(1, 2, 3), Cert.QUARTER)], [Previous.QUANTITY_MILLI, Previous.stock_offset(0),
		Previous.stock_offset(Cert.QUARTER), Vector3i(3, 2, -1)], "the predecessors' names, unchanged")


func test_earth_rows_cannot_share_the_stone_sources() -> void:
	"""Why sources 8 and 9 exist: an earth row moved onto stone's source, or named stone, breaks its source's key
	order (item 11 sorts before 53), and the loader refuses it."""
	_loaded_copy(86, [Vector2i(Profiles.F_SOURCE * 4, 3)])
	assert_equal(_last_load, &"PROFILE_KEY_ORDER", "an earth row on stone's source")
	_loaded_copy(88, [Vector2i(Profiles.F_CARGO * 4, 53)])
	assert_equal(_last_load, &"PROFILE_KEY_ORDER", "an earth unload naming stone after earth rows")


func test_an_earth_station_is_the_stone_station() -> void:
	"""S = R + (0, 0, -576) at yaw 0, (-576, 0, 0) at the quarter turn; any other stock point refuses."""
	var root: Vector3i = Vector3i(4096, 512, -8192)
	assert_equal(Cert.station_refusal(_earth, 86, root, 0, root + Vector3i(0, 0, -576)), &"", "load at yaw 0")
	assert_equal(Cert.station_refusal(_earth, 89, root, Cert.QUARTER, root + Vector3i(-576, 0, 0)), &"", "unload")
	assert_equal(Cert.station_refusal(_earth, 86, root, 0, root + Vector3i(0, 0, -575)), Cert.REFUSE_STATION, "1 u off")
	assert_equal(Cert.station_refusal(_earth, 86, root, Cert.QUARTER, root + Vector3i(0, 0, -576)),
		Cert.REFUSE_STATION, "wrong heading")
	assert_equal(Cert.station_refusal(_earth, 86, root, Cert.QUARTER, root + Vector3i(-576, 0, 0)),
		Cert.REFUSE_STATION, "a yaw-0 row at the quarter turn's own transform")
	assert_equal(Cert.station_refusal(_earth, 85, root, 0, root + Vector3i(0, 0, -576)), Cert.REFUSE_PROFILE,
		"the CARRY row has no station")
	assert_equal(Cert.station_refusal(_earth, 38, root, 0, root + Vector3i(0, 0, -576)), &"", "stone's own, unchanged")
