extends "res://test/framework/test_case.gd"
## `residents.gd`'s ARCH-SAVE-002 section 4 bulk column API (decision 0132).
##
## The two properties this suite exists for:
##   1. A RELEASED row's retained species, arrival tick and skills survive a round trip. Nothing
##      else can see them: `despawn()` leaves them at the last tenant's values and every public
##      reader refuses the row.
##   2. `_name_key` is NOT in this API. §4 carries the `_named` flag, §14 carries the string, and
##      the handoff runs through decision 0112's `restore_name()` and no second path. The suite
##      asserts the in-between state is COUNTED rather than silent.
##
## Section 3 must be restored first, so the round trip here restores the directory through its own
## decision 0105 API and then restores this store against it -- which is also the only way to
## prove the "the directory must honour the reference" rule is really being applied.

const ResidentsScript := preload("res://scripts/core/residents.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")

const REGISTRY_PATH: String = "res://../docs/planning/canonical_state_registry.json"
const SECTION_ID: int = 4
const OWNER_KEY: String = "residents"

var _store: ResidentsScript = null
var _columns: ResidentsScript.Columns = null


func before_each() -> void:
	"""A fresh store and a fresh caller-owned column image for every test."""
	_store = ResidentsScript.new()
	_columns = ResidentsScript.Columns.new()


func _populate() -> int:
	"""The §5.1 cohort plus one otter that is spawned, given skills, and then released.

	Returns the released row. That row keeps its species, arrival tick and XP, which is exactly
	the state no reader can reach and the registry requires to survive verbatim.
	"""
	_store.spawn_initial_settlement()
	var extra: ResidentsScript.OpResult = _store.spawn_with_stage(&"otter",
		ResidentsScript.LIFE_STAGE_ELDER)
	var slot: int = extra.value
	_store.set_arrival_tick(slot, 4242)
	_store.set_skill_xp(slot, ResidentsScript.SKILL_KEEP, 45000)
	_store.set_equipped_tool(slot, 7, 900)
	_store.despawn(_store.ref_of(slot))
	_store.set_home(0, Vector2i(31, 2))
	_store.set_bed(1, Vector2i(64, 5))
	_store.set_satchel(2, Vector2i(12, 3))
	_store.set_skill_xp(3, ResidentsScript.SKILL_KEEP, 20000)
	return slot


func _restored_copy() -> ResidentsScript:
	"""A DIFFERENT store over a DIFFERENT directory carrying the same section 3 image."""
	var target_directory: EntityDirectory = EntityDirectory.new()
	_copy_directory_into(target_directory)
	var target: ResidentsScript = ResidentsScript.new(target_directory, null)
	_store.copy_columns_into(_columns)
	target.restore_columns(_columns)
	return target


func _copy_directory_into(target: EntityDirectory) -> void:
	"""Move section 3 across through `entity_directory.gd`'s own bulk column API."""
	var active: PackedByteArray = PackedByteArray()
	var retired: PackedByteArray = PackedByteArray()
	var generation: PackedInt32Array = PackedInt32Array()
	var persistent_id: PackedInt32Array = PackedInt32Array()
	var kind: PackedInt32Array = PackedInt32Array()
	var typed_row: PackedInt32Array = PackedInt32Array()
	active.resize(EntityDirectory.DIRECTORY_CAPACITY)
	retired.resize(EntityDirectory.DIRECTORY_CAPACITY)
	generation.resize(EntityDirectory.DIRECTORY_CAPACITY)
	persistent_id.resize(EntityDirectory.DIRECTORY_CAPACITY)
	kind.resize(EntityDirectory.DIRECTORY_CAPACITY)
	typed_row.resize(EntityDirectory.DIRECTORY_CAPACITY)
	_store.directory().copy_columns_into(active, generation, retired, persistent_id, kind,
		typed_row)
	target.restore_columns(active, generation, retired, persistent_id, kind, typed_row)


# --- the published order is the registry's ------------------------------------------------------

func test_column_order_matches_the_canonical_registry_artifact() -> void:
	"""Keys, type codes and extents are ordinal-for-ordinal the artifact's, re-read from disk."""
	var text: String = FileAccess.get_file_as_string(REGISTRY_PATH)
	assert_true(text.length() > 0, "the canonical registry artifact is readable")
	var owners: Array = (JSON.parse_string(text) as Dictionary)["owners"] as Array
	var fields: Array = []
	for owner: Variant in owners:
		var group: Dictionary = owner as Dictionary
		if int(group["section_id"]) == SECTION_ID and String(group["owner_key"]) == OWNER_KEY:
			fields = group["fields"] as Array
	assert_equal(fields.size(), ResidentsScript.COLUMN_COUNT, "residents publishes 19 columns")
	for entry: Variant in fields:
		var field: Dictionary = entry as Dictionary
		var ordinal: int = int(field["ordinal"])
		assert_equal(String(field["field_key"]), String(ResidentsScript.COLUMN_KEYS[ordinal]),
			"ordinal %d key" % ordinal)
		assert_equal(int(field["type_code"]), ResidentsScript.COLUMN_TYPE_CODES[ordinal],
			"ordinal %d type code" % ordinal)
		var shape: Dictionary = field["shape"] as Dictionary
		assert_true(String(shape["declared_capacity"]).contains(
			str(ResidentsScript.COLUMN_EXTENTS[ordinal])), "ordinal %d declared extent" % ordinal)


func test_the_name_column_is_not_one_of_the_section_four_columns() -> void:
	"""`_name_key` belongs to §14 and publishing it here would create a second name path."""
	assert_false(ResidentsScript.COLUMN_KEYS.has(&"_name_key"), "no name column in section 4")
	assert_true(ResidentsScript.COLUMN_KEYS.has(&"_named"), "but the flag beside it is here")
	assert_false(ResidentsScript.COLUMN_KEYS.has(&"_selected"), "selection is category 3")


# --- round trip -----------------------------------------------------------------------------------

func test_a_populated_store_round_trips_into_a_different_instance() -> void:
	"""Capture, restore over a separately restored directory, and compare the whole image."""
	_populate()
	var target: ResidentsScript = _restored_copy()
	assert_equal(target.last_column_refusal(), ResidentsScript.REFUSE_NONE, "restore accepted")
	assert_equal(target.population(), _store.population(), "the population came across")
	assert_equal(target.species_of(0).value, _store.species_of(0).value, "species survived")
	assert_equal(target.skill_level_of(0, ResidentsScript.SKILL_KEEP).value,
		_store.skill_level_of(0, ResidentsScript.SKILL_KEEP).value, "the Warden's KEEP level")
	assert_equal(target.life_stage_of(0).value, _store.life_stage_of(0).value, "life stage")


func test_a_released_rows_retained_bytes_survive_and_no_reader_can_see_them() -> void:
	"""The released otter's species, arrival tick and XP are reachable only through this API."""
	var slot: int = _populate()
	assert_false(_store.is_present(slot), "the otter's row was released")
	assert_false(_store.species_of(slot).ok, "no public reader answers for a released row")
	_store.copy_columns_into(_columns)
	var species: int = _columns.species[slot]
	assert_equal(_columns.arrival_tick[slot], 4242, "the released row kept its arrival tick")
	assert_equal(_columns.skill_xp[slot * ResidentsScript.SKILL_COUNT
		+ ResidentsScript.SKILL_KEEP], 45000, "and its KEEP experience")
	var target: ResidentsScript = _restored_copy()
	var read_back: ResidentsScript.Columns = ResidentsScript.Columns.new()
	target.copy_columns_into(read_back)
	assert_equal(read_back.species[slot], species, "the retained species survived the round trip")
	assert_equal(read_back.arrival_tick[slot], 4242, "so did the arrival tick")
	assert_equal(read_back.equip_tool_item_id[slot], ResidentsScript.NO_TOOL_ITEM,
		"while the Equipment mirror was cleared by despawn, as it is on the live store")


func test_the_live_list_is_rebuilt_ascending_and_not_carried() -> void:
	"""`_live_slots` is category 2: the restored order is the SET's ascending order.

	The whole image is compared only AFTER section 14 has been replayed, because
	`state_bytes()` includes `_name_key` and a section-4-only restore deliberately leaves every
	name empty. Comparing before that would be comparing two different load stages.
	"""
	_populate()
	var target: ResidentsScript = _restored_copy()
	assert_equal(target.population(), _store.population(), "the live count was recounted")
	_complete_names(target)
	assert_true(target.state_bytes() == _store.state_bytes(), "including the live prefix")


func _complete_names(target: ResidentsScript) -> void:
	"""Replay section 14 onto a restored store through the one decision 0112 name entry point."""
	for slot: int in ResidentsScript.RESIDENT_CAPACITY:
		if not _store.is_present(slot):
			continue
		target.restore_name(slot, _store.is_named(slot), _store.name_key_of(slot))


func test_an_empty_columns_object_matches_a_cleared_store() -> void:
	"""`Columns.clear()` reproduces the store's empty state: null pairs, not zeros."""
	_populate()
	_store.clear()
	_store.copy_columns_into(_columns)
	var empty: ResidentsScript.Columns = ResidentsScript.Columns.new()
	assert_true(_columns.equals(empty), "a cleared store captures the declared unused values")
	assert_equal(empty.home_slot[0], EntityDirectory.NULL_SLOT, "the unused home slot is -1")
	assert_equal(empty.equip_tool_item_id[0], ResidentsScript.NO_TOOL_ITEM, "no tool is -1")


# --- the section 14 handoff -----------------------------------------------------------------------

func test_a_restored_named_row_is_counted_until_section_fourteen_completes_it() -> void:
	"""§4 carries the flag, §14 carries the string, and the gap between them is visible."""
	_populate()
	assert_true(_store.is_named(0), "the Warden is named on the source store")
	assert_equal(_store.unresolved_name_row_count(), 0, "and the source owes no name")
	var target: ResidentsScript = _restored_copy()
	assert_true(target.is_named(0), "the flag came across with section 4")
	assert_equal(target.name_key_of(0), ResidentsScript.NO_NAME_KEY, "the string did not")
	assert_equal(target.unresolved_name_row_count(), 1, "and the row is counted as owed")
	assert_equal(target.row_name_refusal(0), ResidentsScript.REFUSE_NAMED_ROW_EMPTY,
		"the shared NAME-R02 table reports the incomplete pair")
	var restored: ResidentsScript.OpResult = target.restore_name(0, true,
		ResidentsScript.WARDEN_NAME)
	assert_true(restored.ok, "section 14 completes the pair through the one name entry point")
	assert_equal(target.unresolved_name_row_count(), 0, "and nothing is owed afterwards")


func test_a_restore_empties_a_name_left_by_the_previous_world() -> void:
	"""A string surviving into a different world is the concealed corruption NAME-R02 forbids."""
	_populate()
	var target: ResidentsScript = _restored_copy()
	target.restore_name(0, true, &"Someone Else")
	assert_equal(target.name_key_of(0), &"Someone Else", "the stale name is installed")
	_store.copy_columns_into(_columns)
	assert_true(target.restore_columns(_columns), "a second restore is accepted")
	assert_equal(target.name_key_of(0), ResidentsScript.NO_NAME_KEY, "and empties every name")


func test_a_named_free_row_refuses_through_the_shared_validator() -> void:
	"""NAME-R02's table says a free row is never named, and the free-row rule asks that table."""
	var slot: int = _populate()
	var target: ResidentsScript = _restored_copy()
	var before: PackedByteArray = target.state_bytes()
	_columns.named[slot] = 1
	assert_false(target.restore_columns(_columns), "a named free row refuses")
	assert_equal(target.last_column_refusal(), ResidentsScript.REFUSE_COLUMN_FREE_ROW, "code")
	assert_true(target.state_bytes() == before, "and installed nothing")


# --- refusals leave the store byte-identical ------------------------------------------------------

func _refuses_without_writing(mutate: Callable, expected: StringName, message: String) -> void:
	"""Apply `mutate` to a valid capture, restore it, and require a refusal that wrote nothing."""
	var target: ResidentsScript = _restored_copy()
	var before: PackedByteArray = target.state_bytes()
	mutate.call(_columns)
	assert_false(target.restore_columns(_columns), message)
	assert_equal(target.last_column_refusal(), expected, message + " refusal code")
	assert_true(target.state_bytes() == before, message + " left the store byte-identical")


func test_a_short_column_refuses_on_shape() -> void:
	"""A buffer of the wrong length is the wrong buffer and is never silently resized."""
	_populate()
	_refuses_without_writing(func(columns: ResidentsScript.Columns) -> void:
		columns.skill_xp.remove_at(0),
		ResidentsScript.REFUSE_COLUMN_SHAPE, "a short skill column")


func test_a_named_byte_that_is_neither_zero_nor_one_refuses() -> void:
	"""`_named` is half of NAME-R02's pair and carries no third state."""
	_populate()
	_refuses_without_writing(func(columns: ResidentsScript.Columns) -> void:
		columns.named[0] = 2,
		ResidentsScript.REFUSE_COLUMN_NAMED_BYTE, "a named byte of 2")


func test_a_size_class_disagreeing_with_the_species_refuses() -> void:
	"""The size class is re-derived from the catalog, so a save whose two halves differ is corrupt."""
	_populate()
	_refuses_without_writing(func(columns: ResidentsScript.Columns) -> void:
		columns.size_class[0] = ResidentsScript.SIZE_LARGE,
		ResidentsScript.REFUSE_COLUMN_SIZE_CLASS, "a mouse marked large")


func test_a_skill_level_that_is_not_the_curves_answer_refuses() -> void:
	"""Both halves are written and cross-checked; the level is re-derived, never trusted."""
	_populate()
	_refuses_without_writing(func(columns: ResidentsScript.Columns) -> void:
		columns.skill_level[ResidentsScript.SKILL_KEEP] = 9,
		ResidentsScript.REFUSE_COLUMN_SKILL_LEVEL, "a level the XP does not support")


func test_experience_on_the_reserved_skill_index_refuses() -> void:
	"""§5.1 fixes JobKind.RESERVED_3 at XP and level 0, and `set_skill_xp()` refuses it too."""
	_populate()
	_refuses_without_writing(_write_reserved_skill,
		ResidentsScript.REFUSE_COLUMN_RESERVED_SKILL, "XP on the reserved index")


func _write_reserved_skill(columns: ResidentsScript.Columns) -> void:
	"""Put a CURVE-CONSISTENT level-1 XP on the reserved index, so only its own rule can fire."""
	columns.skill_xp[ResidentsScript.SKILL_RESERVED_INDEX] = 5000
	columns.skill_level[ResidentsScript.SKILL_RESERVED_INDEX] = 1


func test_a_reference_pair_with_a_zero_generation_refuses() -> void:
	"""GDD §4.1's null reference is `(-1, 0)`; a slot with generation 0 is neither null nor live."""
	_populate()
	_refuses_without_writing(func(columns: ResidentsScript.Columns) -> void:
		columns.home_generation[0] = 0,
		ResidentsScript.REFUSE_COLUMN_REF_SHAPE, "a home slot with a null generation")


func test_a_self_reference_the_directory_does_not_honour_refuses() -> void:
	"""The section 3 dependency, enforced: a stale pair is refused, never repaired."""
	_populate()
	_refuses_without_writing(func(columns: ResidentsScript.Columns) -> void:
		columns.ref_generation[0] = columns.ref_generation[0] + 1,
		ResidentsScript.REFUSE_COLUMN_DIRECTORY_REF, "a generation the directory has not issued")


func test_two_rows_claiming_one_directory_slot_refuse() -> void:
	"""The resolution IS the duplicate check: a directory slot owns exactly one typed row."""
	_populate()
	_refuses_without_writing(func(columns: ResidentsScript.Columns) -> void:
		_alias_row_one_onto_row_zero(columns),
		ResidentsScript.REFUSE_COLUMN_DIRECTORY_REF, "two residents on one directory slot")


func _alias_row_one_onto_row_zero(columns: ResidentsScript.Columns) -> void:
	"""Point row 1's self-reference at row 0's directory slot."""
	columns.ref_slot[1] = columns.ref_slot[0]
	columns.ref_generation[1] = columns.ref_generation[0]


func test_a_tool_durability_without_a_tool_refuses() -> void:
	"""The Equipment mirror's unused value is `(-1, 0)` and a lone durability is residue."""
	_populate()
	_refuses_without_writing(func(columns: ResidentsScript.Columns) -> void:
		columns.equip_tool_durability[4] = 500,
		ResidentsScript.REFUSE_COLUMN_EQUIPMENT, "durability with no equipped tool")


func test_a_negative_species_id_refuses_and_the_test_proves_it_is_negative() -> void:
	"""THE INT32 SIGN TRAP: `0x80000000` is 2147483648 to a 64-bit int and -2147483648 as int32."""
	_populate()
	var trap: int = -2147483648
	assert_true(trap < 0, "the int32 reading of 0x80000000 is negative")
	assert_equal(trap, -2147483647 - 1, "and it is the int32 minimum")
	_refuses_without_writing(func(columns: ResidentsScript.Columns) -> void:
		columns.species[0] = trap,
		ResidentsScript.REFUSE_COLUMN_SPECIES, "the int32 minimum as a species id")


func test_an_out_of_domain_life_stage_refuses_rather_than_defaulting_to_adult() -> void:
	"""MOVE-DEP-R02: COUNT is a bound, never a stored stage, and nothing is inferred."""
	_populate()
	_refuses_without_writing(func(columns: ResidentsScript.Columns) -> void:
		columns.life_stage[0] = ResidentsScript.LIFE_STAGE_COUNT,
		ResidentsScript.REFUSE_COLUMN_ENUM_BYTE, "a stage past the bounded domain")


func test_more_than_the_cap_of_residents_refuses() -> void:
	"""ARCH-SAVE-005 caps living residents at 256 and the cap is checked before any write."""
	_populate()
	var target: ResidentsScript = _restored_copy()
	var before: PackedByteArray = target.state_bytes()
	for slot: int in ResidentsScript.RESIDENT_LIVING_CAP + 1:
		_columns.present[slot] = 1
	assert_false(target.restore_columns(_columns), "257 present rows is refused")
	assert_equal(target.last_column_refusal(), ResidentsScript.REFUSE_COLUMN_LIVING_CAP, "code")
	assert_true(target.state_bytes() == before, "the refusal installed nothing")


# --- the refusal namespace is separate ------------------------------------------------------------

func test_a_column_refusal_does_not_touch_the_operation_channel() -> void:
	"""A load must not answer for an operation whose result the caller has not read yet."""
	_populate()
	var refused: ResidentsScript.OpResult = _store.spawn(&"badgerr")
	assert_false(refused.ok, "an unknown species refuses")
	assert_equal(refused.error, ResidentsScript.REFUSE_UNKNOWN_SPECIES, "with its own code")
	_store.copy_columns_into(_columns)
	_columns.size_class[0] = ResidentsScript.SIZE_LARGE
	assert_false(_store.restore_columns(_columns), "and the bad restore refuses")
	assert_equal(refused.error, ResidentsScript.REFUSE_UNKNOWN_SPECIES,
		"the operation's own result is untouched by the load")
	assert_true(String(_store.last_column_refusal()).begins_with("COLUMN_"), "prefixed code")


func test_every_published_column_refusal_code_is_prefixed() -> void:
	"""The namespaces cannot collide, because one of them is entirely prefixed."""
	var codes: Array[StringName] = [ResidentsScript.REFUSE_COLUMN_SHAPE,
		ResidentsScript.REFUSE_COLUMN_CATALOG, ResidentsScript.REFUSE_COLUMN_PRESENT_BYTE,
		ResidentsScript.REFUSE_COLUMN_NAMED_BYTE, ResidentsScript.REFUSE_COLUMN_ENUM_BYTE,
		ResidentsScript.REFUSE_COLUMN_SPECIES, ResidentsScript.REFUSE_COLUMN_SIZE_CLASS,
		ResidentsScript.REFUSE_COLUMN_ARRIVAL_TICK, ResidentsScript.REFUSE_COLUMN_REF_SHAPE,
		ResidentsScript.REFUSE_COLUMN_DIRECTORY_REF, ResidentsScript.REFUSE_COLUMN_EQUIPMENT,
		ResidentsScript.REFUSE_COLUMN_SKILL_XP, ResidentsScript.REFUSE_COLUMN_SKILL_LEVEL,
		ResidentsScript.REFUSE_COLUMN_RESERVED_SKILL, ResidentsScript.REFUSE_COLUMN_FREE_ROW,
		ResidentsScript.REFUSE_COLUMN_LIVING_CAP]
	for code: StringName in codes:
		assert_true(String(code).begins_with("COLUMN_"), "%s is prefixed" % code)
