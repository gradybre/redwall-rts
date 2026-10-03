extends "res://test/framework/test_case.gd"
## GDD facts and approved purpose semantics, without constructing a fake service-ready world.

const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")

var _catalog: RoomCatalog = RoomCatalog.new()


func test_all_eight_protected_purposes_keep_ids_and_independent_labels() -> void:
	"""Bedroom is the private-room label, while Dormitory remains a distinct sleeping purpose."""
	var keys: PackedStringArray = PackedStringArray(["DORMITORY", "PRIVATE_ROOM", "KITCHEN", "DINING",
		"COMMON", "INFIRMARY", "PANTRY", "CORRIDOR"])
	var labels: PackedStringArray = PackedStringArray(["Dormitory", "Bedroom", "Kitchen", "Dining room",
		"Common room", "Infirmary", "Pantry", "Corridor"])
	assert_equal(RoomCatalog.room_types(), PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7]), "protected order")
	for type_id: int in range(8):
		var info: RoomCatalog.RoomPurpose = _catalog.purpose(type_id)
		assert_true(info.ok and RoomCatalog.is_room_type(type_id), "existing purpose resolves")
		assert_equal(info.type_id, type_id, "no new or reordered ordinal")
		assert_equal(info.key, StringName(keys[type_id]), "existing key")
		assert_equal(info.label, labels[type_id], "display wording stays separate")
	for invalid: int in [-1, 8, 2147483647]:
		assert_false(RoomCatalog.is_room_type(invalid), "unknown room id refuses")
		assert_equal(_catalog.purpose(invalid).error, RoomCatalog.REFUSE_ROOM, "specific refusal")
		assert_equal(_catalog.allowed_types_mask(invalid), -1, "unknown palette is not every item")


func test_room_presets_are_aliases_and_ambiguous_building_or_style_names_refuse() -> void:
	"""Neither root-cellar styling nor a tunnel label invents a gameplay room or building."""
	var aliases: Dictionary = {"Bedroom": 1, "Dormitory": 0, "Kitchen": 2, "Dining room": 3,
		"Common room": 4, "Infirmary": 5, "Pantry": 6, "Corridor": 7, "Tunnel": 7, "Root cellar": 6}
	for alias: String in aliases:
		var info: RoomCatalog.RoomPurpose = _catalog.resolve_preset(StringName(alias))
		assert_true(info.ok, "explicit display alias resolves")
		assert_equal(info.type_id, int(aliases[alias]), "alias retains existing purpose")
	for key: String in Catalog.ROOM_TYPE:
		assert_equal(_catalog.resolve_preset(StringName(key)).type_id, int(Catalog.ROOM_TYPE[key]), "canonical key")
	for unknown: StringName in [&"Burrow", &"Cellar", &"cellar", &"Bedroom ", &"Oven room", &""]:
		assert_equal(_catalog.resolve_preset(unknown).error, RoomCatalog.REFUSE_PRESET, "ambiguous name cannot adopt rules")
	assert_equal(Catalog.ROOM_TYPE.size(), 8, "aliases add no catalog identity")
	assert_equal(Catalog.FURNITURE_DEFINITION.size(), 9, "no theme creates equipment")


func test_complete_compatibility_matrix_specializes_equipment_and_keeps_shared_fittings() -> void:
	"""All 72 combinations are explicit; service-only furniture prerequisites are not placement bans."""
	var expected_masks: PackedInt32Array = PackedInt32Array([415, 415, 446, 414, 414, 478, 414, 414])
	for room: int in range(8):
		assert_equal(_catalog.allowed_types_mask(room), expected_masks[room], "independent palette oracle")
		assert_equal(_catalog.purpose(room).allowed_types_mask, expected_masks[room], "snapshot-facing palette")
		for furniture: int in range(9):
			var expected: bool = (expected_masks[room] & (1 << furniture)) != 0
			assert_equal(_catalog.compatibility_error(room, furniture) == &"", expected, "exact pair compatibility")
	assert_equal(_catalog.compatibility_error(-1, 0), RoomCatalog.REFUSE_ROOM, "unknown room")
	assert_equal(_catalog.compatibility_error(0, 9), RoomCatalog.REFUSE_FURNITURE, "unknown item")
	assert_equal(_catalog.compatibility_error(2, 0), RoomCatalog.REFUSE_PURPOSE, "empty kitchen still refuses sleeping bed")
	assert_equal(_catalog.compatibility_error(1, 5), RoomCatalog.REFUSE_PURPOSE, "bedroom refuses cooking equipment")


func test_permanent_type_rule_is_independent_of_furniture_and_service_state() -> void:
	"""Every same-identity retype refuses; emptying a room supplies no conversion path."""
	for built: int in range(8):
		for requested: int in range(8):
			var expected: StringName = &"" if built == requested else RoomCatalog.REFUSE_RETYPE
			assert_equal(RoomCatalog.retained_type_error(built, requested), expected, "purpose persists for identity")
	assert_equal(RoomCatalog.retained_type_error(-1, 1), RoomCatalog.REFUSE_ROOM, "unknown old purpose cannot be adopted")
	assert_equal(RoomCatalog.retained_type_error(2, 8), RoomCatalog.REFUSE_ROOM, "no ninth purpose")
	var empty: PackedInt32Array = _counts({})
	assert_equal(_catalog.countable_error(2, _area(6), empty), RoomCatalog.REFUSE_REQUIRED, "empty kitchen loses count prerequisite")
	assert_equal(RoomCatalog.retained_type_error(2, 1), RoomCatalog.REFUSE_RETYPE, "loss of service is not a retype")


func test_all_nine_furniture_facts_match_exact_gdd_footprints_work_and_materials() -> void:
	"""Independent golden values catch shrinking a 2m tile or copying a demo recipe."""
	_assert_fact("bed", Vector2i(2048, 2048), 20000, 1, ["wood", 2000, "cloth", 1000])
	_assert_fact("decoration", Vector2i(2048, 2048), 12000, 0, ["wood", 1000, "wax", 250])
	_assert_fact("hearth", Vector2i(4096, 2048), 60000, 0, ["stone", 6000])
	_assert_fact("interior_door", Vector2i.ZERO, 12000, 0, ["wood", 2000])
	_assert_fact("interior_partition", Vector2i.ZERO, 8000, 0, ["wood", 1000])
	_assert_fact("kitchen_bench", Vector2i(4096, 2048), 60000, 1, ["wood", 4000, "stone", 4000, "iron", 1000])
	_assert_fact("patient_bed", Vector2i(2048, 2048), 24000, 1, ["wood", 2000, "cloth", 2000])
	_assert_fact("seat", Vector2i(2048, 2048), 10000, 1, ["wood", 1000])
	_assert_fact("shelf", Vector2i(2048, 2048), 16000, 0, ["wood", 2000])


func test_quarter_turns_preserve_physical_size_and_exact_recipe() -> void:
	"""Rotation swaps axes only; a finer placement grid cannot shrink a four-metre bench."""
	for type_id: int in range(9):
		var base: RoomCatalog.FurnitureFacts = _catalog.furniture(type_id)
		for rotation: int in range(4):
			var turned: RoomCatalog.FurnitureFacts = _catalog.furniture(type_id, rotation)
			var expected: Vector2i = base.footprint_units
			if rotation % 2 == 1:
				expected = Vector2i(expected.y, expected.x)
			assert_equal(turned.footprint_units, expected, "quarter-turn floor dimensions")
			assert_equal(turned.work_mwu, base.work_mwu, "rotation adds no recipe")
			assert_equal(turned.quantity_milli, base.quantity_milli, "unchanged paid bill")
	assert_equal(_catalog.furniture_by_key(&"kitchen_bench").footprint_units, Vector2i(16, 8) * 256, "explicit fine-grid subdivision")


func test_unknown_equipment_and_bad_rotations_have_no_valid_looking_facts() -> void:
	"""An oven example is not a new authored production definition or silent bench alias."""
	for key: StringName in [&"oven", &"stove", &"cooking_bench", &"Bed", &""]:
		var info: RoomCatalog.FurnitureFacts = _catalog.furniture_by_key(key)
		assert_false(info.ok, "undefined equipment refuses")
		assert_equal(info.error, RoomCatalog.REFUSE_FURNITURE, "specific unknown-equipment refusal")
		assert_true(info.material_keys.is_empty(), "failure supplies no free bill")
	for invalid: int in [-1, 9, 2147483647]:
		assert_false(_catalog.furniture(invalid).ok, "unknown id cannot become floor furniture")
	for rotation: int in [-1, 4, 9223372036854775807]:
		var info: RoomCatalog.FurnitureFacts = _catalog.furniture(0, rotation)
		assert_equal(info.error, RoomCatalog.REFUSE_ROTATION, "rotation never wraps an invalid request")
		assert_equal(info.type_id, -1, "failure has no usable definition")


func test_returned_facts_and_requirements_do_not_mutate_source_tables() -> void:
	"""A UI edit to a query result cannot rewrite another room's costs, counts or eligibility."""
	var fact: RoomCatalog.FurnitureFacts = _catalog.furniture(0)
	fact.material_keys[0] = "stone"
	fact.quantity_milli[0] = 1
	fact.work_mwu = 0
	var fresh: RoomCatalog.FurnitureFacts = _catalog.furniture(0)
	assert_equal(fresh.material_keys[0], "wood", "source key unchanged")
	assert_equal(fresh.quantity_milli[0], 2000, "source quantity unchanged")
	assert_equal(fresh.work_mwu, 20000, "source work unchanged")
	var requirements: RoomCatalog.ServiceRequirements = _catalog.service_requirements(1)
	requirements.minimum_counts[0] = 0
	requirements.owner_gates.clear()
	assert_equal(_catalog.service_requirements(1).minimum_counts[0], 1, "fresh private-room prerequisite")
	assert_true(_catalog.service_requirements(1).owner_gates.has("PARTITIONED_ENCLOSURE"), "spatial gate retained")
	var purpose: RoomCatalog.RoomPurpose = _catalog.purpose(2)
	purpose.allowed_types_mask = 511
	assert_equal(_catalog.purpose(2).allowed_types_mask, 446, "type-specific equipment cannot be enabled through a copy")


func test_shared_shelves_and_hearths_do_not_gain_unrelated_service_capacity() -> void:
	"""R-BUILD-DOM-004 permits the kitchen shelf, but counts capacity only in a valid Pantry."""
	for room: int in range(8):
		var shelf: RoomCatalog.ScopedServiceFacts = _catalog.scoped_service_facts(room, 8)
		assert_true(shelf.ok, "shelf remains a shared furnishing")
		assert_equal(shelf.pantry_capacity_g, 50000 if room == 6 else 0, "catalog pantry contribution has exact scope")
		assert_equal(shelf.kitchen_worker_slots, 0, "shelf is not cooking equipment")
		var hearth: RoomCatalog.ScopedServiceFacts = _catalog.scoped_service_facts(room, 2)
		assert_true(hearth.ok, "hearth is shared heating equipment")
		assert_equal(hearth.kitchen_station_id, -1, "hearth alone is never a cooking station")
		assert_equal(hearth.kitchen_worker_slots, 0, "no invented hearth cooking slot")
	var bench: RoomCatalog.ScopedServiceFacts = _catalog.scoped_service_facts(2, 5)
	assert_true(bench.ok, "bench belongs to Kitchen")
	assert_equal(bench.kitchen_station_id, int(Catalog.STATION["kitchen"]), "station domain, not exterior building id")
	assert_equal(bench.kitchen_worker_slots, 1, "one bench, one cooking slot")
	assert_equal(_catalog.scoped_service_facts(1, 5).error, RoomCatalog.REFUSE_PURPOSE, "no Bedroom cooking grant")
	assert_false(_catalog.scoped_service_facts(8, 8).ok, "unknown room supplies no capacity")


func test_every_room_keeps_required_live_owner_gates() -> void:
	"""Countable prerequisites never stand in for completion, support, actual access or live service state."""
	for room: int in range(8):
		var requirements: RoomCatalog.ServiceRequirements = _catalog.service_requirements(room)
		assert_true(requirements.ok, "all existing purposes have prerequisites")
		assert_true(requirements.owner_gates.has("COMPLETED_ROOM_SHELL"), "no furnishing during excavation")
		assert_true(requirements.owner_gates.has("INSTALLED_SERVICE_ELIGIBLE_FURNITURE"), "previews and unfinished orders grant nothing")
		assert_true(requirements.owner_gates.has("CONNECTED_FURNITURE_ACCESS"), "mask cannot prove access")
		assert_true(requirements.owner_gates.has("OWNING_SERVICE_OPERATIONAL_GATES"), "catalog slots are not ready work")
	assert_true(_catalog.service_requirements(0).owner_gates.has("BED_ACCESS_CONNECTED_TO_EXTERIOR"), "dormitory access")
	assert_true(_catalog.service_requirements(1).owner_gates.has("PARTITIONED_ENCLOSURE"), "private enclosure")
	assert_true(_catalog.service_requirements(5).owner_gates.has("HEATED_COMPONENT"), "infirmary warmth")
	assert_equal(_catalog.service_requirements(7).minimum_corridor_width_units, 2048, "one GDD tile width")
	assert_true(_catalog.service_requirements(7).owner_gates.has("CORRIDOR_WIDTH_AND_EXTERIOR_LINK"), "real corridor geometry")
	assert_equal(_catalog.service_requirements(-1).error, RoomCatalog.REFUSE_ROOM, "no fallback requirements")
	for type_id: int in range(9):
		assert_true(_catalog.furniture(type_id).geometry_profile_required, "known footprint is not an equipment height/contact profile")


func test_sleeping_room_count_rules_and_exact_area_thresholds() -> void:
	"""Private room is exactly one bed; Dormitory scales area with actual bed count."""
	assert_equal(_catalog.countable_error(0, _area(6), _counts({"bed": 2})), &"", "two dormitory beds need six tiles")
	assert_equal(_catalog.countable_error(0, _area(6) - 1, _counts({"bed": 2})), RoomCatalog.REFUSE_AREA, "no rounded-up tile")
	assert_equal(_catalog.countable_error(0, _area(6), _counts({})), RoomCatalog.REFUSE_REQUIRED, "dormitory needs a bed")
	assert_equal(_catalog.countable_error(1, _area(6), _counts({"bed": 1})), &"", "private one-bed prerequisite")
	assert_equal(_catalog.countable_error(1, _area(6) - 1, _counts({"bed": 1})), RoomCatalog.REFUSE_AREA, "private area exact")
	assert_equal(_catalog.countable_error(1, _area(8), _counts({"bed": 2})), RoomCatalog.REFUSE_EXCESS, "two beds do not make a private room")
	assert_equal(_catalog.countable_error(1, _area(8), _counts({"bed": 1, "seat": 1, "shelf": 1})), &"", "domestic common fittings are not prohibited")


func test_kitchen_dining_and_common_count_rules_remain_distinct() -> void:
	"""One bench and a hearth differ from seats; Common has a fixed minimum, not Dining's ratio."""
	assert_equal(_catalog.countable_error(2, _area(6), _counts({"kitchen_bench": 1, "hearth": 1})), &"", "kitchen counts")
	assert_equal(_catalog.countable_error(2, _area(6) - 1, _counts({"kitchen_bench": 1, "hearth": 1})), RoomCatalog.REFUSE_AREA, "kitchen area")
	assert_equal(_catalog.countable_error(2, _area(6), _counts({"kitchen_bench": 1})), RoomCatalog.REFUSE_REQUIRED, "kitchen needs hearth")
	assert_equal(_catalog.countable_error(2, _area(6), _counts({"hearth": 1})), RoomCatalog.REFUSE_REQUIRED, "heating is not cooking")
	assert_equal(_catalog.countable_error(3, _area(8), _counts({"seat": 4})), &"", "four dining places")
	assert_equal(_catalog.countable_error(3, _area(8), _counts({"seat": 5})), RoomCatalog.REFUSE_AREA, "two tiles per diner")
	assert_equal(_catalog.countable_error(3, _area(8), _counts({"seat": 3})), RoomCatalog.REFUSE_REQUIRED, "four minimum dining seats")
	assert_equal(_catalog.countable_error(4, _area(8), _counts({"seat": 4})), &"", "common room minimum")
	assert_equal(_catalog.countable_error(4, _area(8) - 1, _counts({"seat": 4})), RoomCatalog.REFUSE_AREA, "common area exact")
	assert_equal(_catalog.countable_error(4, _area(8), _counts({"seat": 3})), RoomCatalog.REFUSE_REQUIRED, "common seats")
	assert_equal(_catalog.countable_error(4, _area(8), _counts({"seat": 10})), &"", "count prerequisite alone cannot prove physical fit")


func test_infirmary_pantry_and_corridor_count_rules_do_not_attest_heat_or_routes() -> void:
	"""The numeric half deliberately leaves the geometric/operational half to its actual owner."""
	assert_equal(_catalog.countable_error(5, _area(6), _counts({"patient_bed": 2, "shelf": 1})), &"", "infirmary counts only")
	assert_equal(_catalog.countable_error(5, _area(6) - 1, _counts({"patient_bed": 2, "shelf": 1})), RoomCatalog.REFUSE_AREA, "three tiles per patient")
	assert_equal(_catalog.countable_error(5, _area(6), _counts({"patient_bed": 2})), RoomCatalog.REFUSE_REQUIRED, "infirmary shelf")
	assert_equal(_catalog.countable_error(5, _area(6), _counts({"shelf": 1})), RoomCatalog.REFUSE_REQUIRED, "patient bed needed")
	assert_equal(_catalog.countable_error(6, _area(4), _counts({"shelf": 1})), &"", "pantry counts")
	assert_equal(_catalog.countable_error(6, _area(4) - 1, _counts({"shelf": 1})), RoomCatalog.REFUSE_AREA, "pantry area")
	assert_equal(_catalog.countable_error(6, _area(4), _counts({})), RoomCatalog.REFUSE_REQUIRED, "empty pantry has no storage")
	assert_equal(_catalog.countable_error(7, _area(1), _counts({})), &"", "corridor needs no fictional fixture")
	assert_true(_catalog.service_requirements(7).owner_gates.has("CORRIDOR_WIDTH_AND_EXTERIOR_LINK"), "counts cannot establish corridor legality")


func test_bad_count_input_and_overflow_values_refuse_without_mutation() -> void:
	"""Counts are complete typed catalog columns, bounded by the existing furniture store arena."""
	var invalid: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array([1]),
		_counts({"bed": -1}), _counts({"bed": 2147483647}),
		_counts({"bed": Buildings.FURNITURE_CAPACITY, "shelf": 1})]
	for counts: PackedInt32Array in invalid:
		var before: PackedInt32Array = counts.duplicate()
		assert_equal(_catalog.countable_error(0, 9223372036854775807, counts), RoomCatalog.REFUSE_COUNTS, "malformed census refuses")
		assert_equal(counts, before, "refusal does not normalize caller data")
	assert_equal(_catalog.countable_error(0, -1, _counts({"bed": 1})), RoomCatalog.REFUSE_AREA_INPUT, "negative area is invalid")
	assert_equal(_catalog.countable_error(99, _area(6), _counts({"bed": 1})), RoomCatalog.REFUSE_ROOM, "unknown purpose")
	assert_equal(_catalog.countable_error(2, _area(8), _counts({"bed": 1, "kitchen_bench": 1, "hearth": 1})),
		RoomCatalog.REFUSE_PURPOSE, "count success cannot conceal incompatible specialization")


func _assert_fact(key: String, footprint: Vector2i, work: int, slots: int, materials: Array) -> void:
	"""Compare every furniture row with an independent source-table transcription in this test."""
	var info: RoomCatalog.FurnitureFacts = _catalog.furniture_by_key(StringName(key))
	assert_true(info.ok, "known definition " + key)
	assert_equal(info.type_id, int(Catalog.FURNITURE_DEFINITION[key]), "compiled furniture identity")
	assert_equal(info.key, StringName(key), "stable key")
	assert_equal(info.footprint_units, footprint, "physical two-metre footprint")
	assert_equal(info.edge_placement, footprint == Vector2i.ZERO, "edge pieces need their own geometry owner")
	assert_equal(info.work_mwu, work, "exact milli-work")
	assert_equal(info.user_slots, slots, "catalog capacity only")
	var copied: Array = []
	for at: int in range(info.material_keys.size()):
		copied.append(info.material_keys[at])
		copied.append(info.quantity_milli[at])
	assert_equal(copied, materials, "exact material keys and milli quantities")
	assert_equal(copied, Construction.FURNITURE_MATERIALS[key], "same bill as actual project owner")


func _counts(by_key: Dictionary) -> PackedInt32Array:
	"""Produce a complete synthetic installed-count column in real FurnitureDefinition id order."""
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(9)
	for key: String in by_key:
		result[int(Catalog.FURNITURE_DEFINITION[key])] = int(by_key[key])
	return result


static func _area(tiles: int) -> int:
	"""One GDD 2m square tile has 4194304 square fixed units; no float geometry in test arithmetic."""
	return tiles * 4194304
