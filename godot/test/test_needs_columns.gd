extends "res://test/framework/test_case.gd"
## `needs.gd`'s ARCH-SAVE-002 section 4 bulk column API (decision 0132).
##
## Kept in its own file rather than appended to `test_needs.gd`: that suite covers the §5.2
## integrator and this one covers a capture/apply contract, and several lanes are editing the
## store suites in parallel.
##
## What this suite is actually for, in order of how much it would cost to get wrong:
##   1. A FREE row's retained bytes survive a round trip. That is the whole reason the API
##      exists -- `size_class_of()` and every other reader refuse a released row, so nothing
##      else in the codebase can see or restore what one carries.
##   2. A refused restore leaves the store BYTE-IDENTICAL, compared through `state_bytes()`
##      rather than by eye.
##   3. The published column order is the registry artifact's ordinal order, re-read from
##      `docs/planning/canonical_state_registry.json` rather than transcribed here a second time.
##   4. The refusal namespace is separate from the OpResult channel every mutator uses.

const NeedsScript := preload("res://scripts/core/needs.gd")

const REGISTRY_PATH: String = "res://../docs/planning/canonical_state_registry.json"
const SECTION_ID: int = 4
const OWNER_KEY: String = "needs"

var _store: NeedsScript = null
var _columns: NeedsScript.Columns = null


func before_each() -> void:
	"""A fresh store and a fresh caller-owned column image for every test."""
	_store = NeedsScript.new()
	_columns = NeedsScript.Columns.new()


func _populate() -> void:
	"""Two living residents, one dead-but-present row, and one released row with residue.

	Slot 9 is the interesting one: it is spawned LARGE with a tier-2 garment and then released,
	so its `_size_class` and `_clothing_tier` are values `despawn()` does not clear and no public
	reader will answer for.
	"""
	_store.spawn(1, NeedsScript.SIZE_SMALL)
	_store.spawn(4, NeedsScript.SIZE_MEDIUM)
	_store.spawn(6, NeedsScript.SIZE_SMALL)
	_store.spawn(9, NeedsScript.SIZE_LARGE)
	_store.set_clothing_tier(9, NeedsScript.CLOTHING_TIER_MAX)
	_store.set_activity(4, NeedsScript.ACTIVITY_SLEEP_BED)
	_store.set_injury_state(1, NeedsScript.INJURY_UNTREATED_SERIOUS)
	_store.apply_health_event(6, -NeedsScript.INITIAL_HEALTH)
	_store.despawn(9)
	for _tick: int in 40:
		_store.tick_all()


func _restored_copy() -> NeedsScript:
	"""A DIFFERENT store instance carrying this store's captured columns."""
	var target: NeedsScript = NeedsScript.new()
	_store.copy_columns_into(_columns)
	target.restore_columns(_columns)
	return target


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
	assert_equal(fields.size(), NeedsScript.COLUMN_COUNT, "needs publishes 20 section 4 columns")
	for entry: Variant in fields:
		var field: Dictionary = entry as Dictionary
		var ordinal: int = int(field["ordinal"])
		assert_equal(String(field["field_key"]), String(NeedsScript.COLUMN_KEYS[ordinal]),
			"ordinal %d key" % ordinal)
		assert_equal(int(field["type_code"]), NeedsScript.COLUMN_TYPE_CODES[ordinal],
			"ordinal %d type code" % ordinal)
		var shape: Dictionary = field["shape"] as Dictionary
		assert_true(String(shape["declared_capacity"]).contains(
			str(NeedsScript.COLUMN_EXTENTS[ordinal])), "ordinal %d declared extent" % ordinal)


func test_the_three_order_tables_are_the_same_length() -> void:
	"""A column added to one table and not the others would ship a silently short walk."""
	assert_equal(NeedsScript.COLUMN_KEYS.size(), NeedsScript.COLUMN_COUNT, "key table length")
	assert_equal(NeedsScript.COLUMN_TYPE_CODES.size(), NeedsScript.COLUMN_COUNT, "type length")
	assert_equal(NeedsScript.COLUMN_EXTENTS.size(), NeedsScript.COLUMN_COUNT, "extent length")


# --- round trip -----------------------------------------------------------------------------------

func test_a_populated_store_round_trips_into_a_different_instance() -> void:
	"""Capture, restore into a second store, and compare the whole diagnostic image."""
	_populate()
	var target: NeedsScript = _restored_copy()
	assert_equal(target.last_column_refusal(), NeedsScript.REFUSE_NONE, "restore was accepted")
	assert_true(_store.state_bytes() == target.state_bytes(), "the two stores agree byte for byte")
	assert_equal(target.present_count(), _store.present_count(), "present rows recounted")
	assert_equal(target.living_count(), _store.living_count(), "living rows recounted")


func test_a_released_rows_retained_bytes_survive_and_no_reader_can_see_them() -> void:
	"""The point of the API: slot 9's size class and garment are unreachable any other way."""
	_populate()
	assert_false(_store.is_present(9), "slot 9 was released")
	assert_false(_store.size_class_of(9).ok, "no public reader answers for a released row")
	_store.copy_columns_into(_columns)
	assert_equal(_columns.size_class[9], NeedsScript.SIZE_LARGE, "captured size class of a free row")
	assert_equal(_columns.clothing_tier[9], NeedsScript.CLOTHING_TIER_MAX, "captured garment tier")
	var target: NeedsScript = NeedsScript.new()
	assert_true(target.restore_columns(_columns), "the capture restores")
	var read_back: NeedsScript.Columns = NeedsScript.Columns.new()
	target.copy_columns_into(read_back)
	assert_equal(read_back.size_class[9], NeedsScript.SIZE_LARGE, "restored size class of a free row")
	assert_equal(read_back.clothing_tier[9], NeedsScript.CLOTHING_TIER_MAX, "restored garment tier")


func test_a_dead_but_present_row_survives_as_present_and_not_living() -> void:
	"""ARCH-SAVE-006's dying resident: the row stays occupied and stops counting as living."""
	_populate()
	var target: NeedsScript = _restored_copy()
	assert_true(target.is_present(6), "the dead resident's row is still occupied")
	assert_false(target.is_alive(6), "and is not alive")
	assert_equal(target.status_of(6).value, NeedsScript.STATUS_DEAD, "status survived")


func test_an_empty_columns_object_matches_a_cleared_store() -> void:
	"""`Columns.clear()` reproduces the store's own empty state, DEAD status and tier 1 included."""
	_populate()
	_store.clear()
	_store.copy_columns_into(_columns)
	var empty: NeedsScript.Columns = NeedsScript.Columns.new()
	assert_true(_columns.equals(empty), "a cleared store captures the declared unused values")
	assert_equal(empty.status[0], NeedsScript.STATUS_DEAD, "the unused status is DEAD, not zero")
	assert_equal(empty.clothing_tier[0], NeedsScript.CLOTHING_TIER_MIN, "the unused tier is 1")


# --- refusals leave the store byte-identical ------------------------------------------------------

func _refuses_without_writing(mutate: Callable, expected: StringName, message: String) -> void:
	"""Apply `mutate` to a valid capture, restore it, and require a refusal that wrote nothing."""
	var target: NeedsScript = _restored_copy()
	var before: PackedByteArray = target.state_bytes()
	mutate.call(_columns)
	assert_false(target.restore_columns(_columns), message)
	assert_equal(target.last_column_refusal(), expected, message + " refusal code")
	assert_true(target.state_bytes() == before, message + " left the store byte-identical")


func test_a_short_column_refuses_on_shape() -> void:
	"""A buffer of the wrong length is the wrong buffer and is never silently resized."""
	_populate()
	_refuses_without_writing(func(columns: NeedsScript.Columns) -> void:
		columns.health.remove_at(0),
		NeedsScript.REFUSE_COLUMN_SHAPE, "a short health column")


func test_an_out_of_domain_status_byte_refuses() -> void:
	"""ARCH-SAVE-005 bounds each byte against its own COUNT.

	Written on a LIVE row deliberately. On a released row the free-row rule would refuse it first
	with its own code, and the byte-domain rule would never be the thing under test.
	"""
	_populate()
	_refuses_without_writing(func(columns: NeedsScript.Columns) -> void:
		columns.status[4] = NeedsScript.STATUS_COUNT,
		NeedsScript.REFUSE_COLUMN_ENUM_BYTE, "a status byte one past the enumeration")


func test_a_need_above_ten_thousand_refuses() -> void:
	"""Needs are integers 0-10000 and a value outside that is refused, never clamped."""
	_populate()
	_refuses_without_writing(func(columns: NeedsScript.Columns) -> void:
		columns.need_value[1 * NeedsScript.NEED_COUNT] = NeedsScript.NEED_MAX + 1,
		NeedsScript.REFUSE_COLUMN_NEED_RANGE, "a hunger value above the bound")


func test_a_negative_health_refuses_and_the_test_proves_it_is_negative() -> void:
	"""THE INT32 SIGN TRAP, kept out of the test itself.

	`0x80000000` is a POSITIVE 2147483648 to a 64-bit GDScript int and -2147483648 read as int32.
	A test that wrote the unsigned spelling would be asserting about a number the column cannot
	hold. The value is asserted negative here before it is ever handed to the store.
	"""
	_populate()
	var trap: int = -2147483648
	assert_true(trap < 0, "the int32 reading of 0x80000000 is negative")
	assert_equal(trap, -2147483647 - 1, "and it is the int32 minimum")
	_refuses_without_writing(func(columns: NeedsScript.Columns) -> void:
		columns.health[4] = trap,
		NeedsScript.REFUSE_COLUMN_HEALTH_RANGE, "the int32 minimum as a health value")


func test_a_remainder_at_its_denominator_refuses() -> void:
	"""The integrator's overflow proof needs |remainder| < denominator, so the bound is enforced."""
	_populate()
	_refuses_without_writing(func(columns: NeedsScript.Columns) -> void:
		columns.need_remainder[4 * NeedsScript.NEED_COUNT] = NeedsScript.NEED_DENOMINATOR,
		NeedsScript.REFUSE_COLUMN_REMAINDER, "a remainder at the denominator")


func test_the_remainder_bound_is_exclusive_on_both_ends() -> void:
	"""The rule is |remainder| < denominator, so BOTH edges are pinned.

	One-sided coverage is how an off-by-one on the negative bound would ship: decay leaves a
	NEGATIVE retained remainder and is the common case, so the side that matters most in practice
	is the one a positive-only test never touches.
	"""
	_populate()
	var target: NeedsScript = _restored_copy()
	var hunger: int = 4 * NeedsScript.NEED_COUNT
	_columns.need_remainder[hunger] = -(NeedsScript.NEED_DENOMINATOR - 1)
	_columns.health_remainder[4] = NeedsScript.HEALTH_DENOMINATOR - 1
	assert_true(target.restore_columns(_columns), "the largest legal magnitudes are accepted")
	var accepted: PackedByteArray = target.state_bytes()
	_columns.need_remainder[hunger] = -NeedsScript.NEED_DENOMINATOR
	assert_false(target.restore_columns(_columns), "one past the negative bound refuses")
	assert_equal(target.last_column_refusal(), NeedsScript.REFUSE_COLUMN_REMAINDER, "code")
	assert_true(target.state_bytes() == accepted, "and the refusal wrote nothing")
	_columns.need_remainder[hunger] = 0
	_columns.health_remainder[4] = NeedsScript.HEALTH_DENOMINATOR
	assert_false(target.restore_columns(_columns), "one past the positive health bound refuses")
	assert_equal(target.last_column_refusal(), NeedsScript.REFUSE_COLUMN_REMAINDER, "code")


func test_a_negative_starvation_clock_refuses() -> void:
	"""An absolute tick count cannot run backwards; a negative one is corrupt, not early."""
	_populate()
	_refuses_without_writing(func(columns: NeedsScript.Columns) -> void:
		columns.starving_ticks[4] = -1,
		NeedsScript.REFUSE_COLUMN_NEGATIVE_COUNTER, "a negative starvation clock")


func test_an_occupancy_byte_that_is_neither_zero_nor_one_refuses() -> void:
	"""`_present` is an occupancy byte, deliberately not a packed bitset, and 2 is not a value."""
	_populate()
	_refuses_without_writing(func(columns: NeedsScript.Columns) -> void:
		columns.present[20] = 2,
		NeedsScript.REFUSE_COLUMN_PRESENT_BYTE, "an occupancy byte of 2")


func test_a_boolean_input_column_holding_two_refuses() -> void:
	"""The paired/infirmary/airless inputs are flags; anything but 0 or 1 is corruption."""
	_populate()
	_refuses_without_writing(func(columns: NeedsScript.Columns) -> void:
		columns.social_paired[4] = 2,
		NeedsScript.REFUSE_COLUMN_FLAG_BYTE, "a social-pairing flag of 2")


func test_a_clothing_tier_of_zero_refuses() -> void:
	"""GDD §5.1 spawns at tier 1: a zero here is an unwritten column, not an unclothed mouse."""
	_populate()
	_refuses_without_writing(func(columns: NeedsScript.Columns) -> void:
		columns.clothing_tier[4] = 0,
		NeedsScript.REFUSE_COLUMN_CLOTHING_TIER, "a garment tier of 0")


func test_a_free_row_carrying_a_live_value_refuses() -> void:
	"""A released row holds what `despawn()` leaves; residue in a zeroed column is corruption."""
	_populate()
	_refuses_without_writing(func(columns: NeedsScript.Columns) -> void:
		columns.health[9] = 50,
		NeedsScript.REFUSE_COLUMN_FREE_ROW, "health left on a released row")


func test_a_free_row_that_is_not_dead_refuses() -> void:
	"""`despawn()` and `clear()` both write DEAD; a live status on a free row is unreachable."""
	_populate()
	_refuses_without_writing(func(columns: NeedsScript.Columns) -> void:
		columns.status[9] = NeedsScript.STATUS_ACTIVE,
		NeedsScript.REFUSE_COLUMN_FREE_ROW, "an ACTIVE status on a released row")


func test_more_than_the_cap_of_living_residents_refuses() -> void:
	"""The living cap is checked against the RECOUNTED number, before anything is installed."""
	_store.copy_columns_into(_columns)
	for slot: int in NeedsScript.RESIDENT_LIVING_CAP + 1:
		_columns.present[slot] = 1
		_columns.status[slot] = NeedsScript.STATUS_ACTIVE
		_columns.health[slot] = NeedsScript.INITIAL_HEALTH
	var target: NeedsScript = NeedsScript.new()
	var before: PackedByteArray = target.state_bytes()
	assert_false(target.restore_columns(_columns), "257 living residents is refused")
	assert_equal(target.last_column_refusal(), NeedsScript.REFUSE_COLUMN_LIVING_CAP, "cap code")
	assert_true(target.state_bytes() == before, "the refusal installed nothing")


func test_exactly_the_cap_of_living_residents_is_accepted() -> void:
	"""The cap is 256 and not 255: the boundary is asserted from both sides."""
	_store.copy_columns_into(_columns)
	for slot: int in NeedsScript.RESIDENT_LIVING_CAP:
		_columns.present[slot] = 1
		_columns.status[slot] = NeedsScript.STATUS_ACTIVE
		_columns.health[slot] = NeedsScript.INITIAL_HEALTH
	var target: NeedsScript = NeedsScript.new()
	assert_true(target.restore_columns(_columns), "256 living residents is accepted")
	assert_equal(target.living_count(), NeedsScript.RESIDENT_LIVING_CAP, "and is recounted")


# --- the refusal namespace is separate ------------------------------------------------------------

func test_a_column_refusal_does_not_touch_the_operation_channel() -> void:
	"""A load must not be able to answer for an operation the caller has not read yet."""
	_populate()
	var refused: NeedsScript.OpResult = _store.spawn(1, NeedsScript.SIZE_SMALL)
	assert_false(refused.ok, "spawning onto an occupied row refuses")
	assert_equal(refused.error, NeedsScript.REFUSE_ALREADY_PRESENT, "with its own code")
	_store.copy_columns_into(_columns)
	_columns.health[4] = -1
	assert_false(_store.restore_columns(_columns), "and the bad restore refuses")
	assert_equal(refused.error, NeedsScript.REFUSE_ALREADY_PRESENT,
		"the operation's own result is untouched by the load")
	assert_true(String(_store.last_column_refusal()).begins_with("COLUMN_"),
		"every bulk column code is prefixed COLUMN_")


func test_every_published_column_refusal_code_is_prefixed() -> void:
	"""The namespaces cannot collide, because one of them is entirely prefixed."""
	var codes: Array[StringName] = [NeedsScript.REFUSE_COLUMN_SHAPE,
		NeedsScript.REFUSE_COLUMN_PRESENT_BYTE, NeedsScript.REFUSE_COLUMN_FLAG_BYTE,
		NeedsScript.REFUSE_COLUMN_ENUM_BYTE, NeedsScript.REFUSE_COLUMN_CLOTHING_TIER,
		NeedsScript.REFUSE_COLUMN_NEED_RANGE, NeedsScript.REFUSE_COLUMN_HEALTH_RANGE,
		NeedsScript.REFUSE_COLUMN_NEGATIVE_COUNTER, NeedsScript.REFUSE_COLUMN_REMAINDER,
		NeedsScript.REFUSE_COLUMN_FREE_ROW, NeedsScript.REFUSE_COLUMN_LIVING_CAP]
	for code: StringName in codes:
		assert_true(String(code).begins_with("COLUMN_"), "%s is prefixed" % code)


func test_a_successful_restore_clears_the_column_refusal() -> void:
	"""A stale code must not survive a success and be read as this call's answer."""
	_populate()
	_store.copy_columns_into(_columns)
	_columns.health[4] = -1
	assert_false(_store.restore_columns(_columns), "the bad restore refuses")
	_store.copy_columns_into(_columns)
	assert_true(_store.restore_columns(_columns), "a valid restore is accepted")
	assert_equal(_store.last_column_refusal(), NeedsScript.REFUSE_NONE, "and clears the code")


# --- the restored store still ticks ---------------------------------------------------------------

func test_a_restored_store_integrates_exactly_as_the_source_does() -> void:
	"""A restore that lost a remainder would drift a fraction of a need point per tick."""
	_populate()
	var target: NeedsScript = _restored_copy()
	for _tick: int in 800:
		_store.tick_all()
		target.tick_all()
	assert_true(_store.state_bytes() == target.state_bytes(),
		"800 ticks on each store leave them identical")
	assert_equal(target.need_of(4, NeedsScript.NEED_HUNGER).value,
		_store.need_of(4, NeedsScript.NEED_HUNGER).value, "hunger agrees after the run")
