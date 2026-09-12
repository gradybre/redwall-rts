extends "res://test/framework/test_case.gd"
## NEED-RATE-R01's selected-resident snapshot: one validated identity, five rows, no formulas.
##
## Everything here runs against the REAL `needs.gd`. There is no rate double, because there is
## nothing left to double: the four public readers NEED-RATE-R01 specified are implemented, and
## the ruling forbids the UI from recreating their formulas, so a stub that returned the fixture
## values would be testing the stub.
##
## Every rate condition is therefore set through the store's OWN setters -- `set_activity()`,
## `set_comfort_environment()`, `set_social_paired()`, `set_purpose_source()`, `set_winter()` --
## and the expected number is the ruling's published fixture, written here as a literal. That is
## what makes a test fail when the selector changes rather than when the snapshot changes.
##
## The identity cases are about the directory rather than the rates: a stale generation, a reused
## slot, a reference of the wrong kind, a dead row. Those must refuse whatever the readers say.

const UiResidentSnapshot := preload("res://scripts/ui/ui_resident_snapshot.gd")
const UiNeedRate := preload("res://scripts/ui/ui_need_rate.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")

## GDD §5.1: every need starts at 7500 and health at 100.
const SPAWN_NEED: int = 7500
## GDD §5.2's small-size nonwinter hunger decay, as a POSITIVE published magnitude.
const SMALL_HUNGER_MAGNITUDE: int = 250000

## The ruling's inherited fixtures for the four readers, at interior need values.
const REST_AWAKE: int = -375000
const COMFORT_MILD_OUTDOORS: int = 0
const SOCIAL_PAIRED: int = 1100000
const PURPOSE_USEFUL_LABOR: int = 245000


var _directory: EntityDirectoryScript = null
var _residents: ResidentsScript = null
var _needs: NeedsScript = null
var _snapshot: UiResidentSnapshot = null


func before_each() -> void:
	"""A real directory and resident store over the REAL needs store, and a snapshot over them."""
	_directory = EntityDirectoryScript.new()
	_needs = NeedsScript.new()
	_residents = ResidentsScript.new(_directory, _needs)
	_snapshot = UiResidentSnapshot.new()


func after_each() -> void:
	"""Drop the stores; they are plain RefCounted and own no node."""
	_snapshot = null
	_residents = null
	_needs = null
	_directory = null


func _set_context(slot: int, activity: int, environment: int, paired: bool,
		purpose: int) -> void:
	"""Put one resident into a named model condition through the store's own setters."""
	assert_true(_needs.set_activity(slot, activity).ok, "the activity is set")
	assert_true(_needs.set_comfort_environment(slot, environment).ok, "the environment is set")
	assert_true(_needs.set_social_paired(slot, paired).ok, "the pairing is set")
	assert_true(_needs.set_purpose_source(slot, purpose).ok, "the purpose source is set")


func _spawn(species_key: StringName) -> int:
	"""Spawn one resident and return its slot, asserting the spawn succeeded."""
	var made: ResidentsScript.OpResult = _residents.spawn(species_key)
	assert_true(made.ok, "a %s is spawned (error: %s)" % [species_key, made.error])
	return made.value


# --- the identity half: validate the reference BEFORE reading anything ----------------------

func test_a_valid_reference_resolves_its_resident_row_and_fills_five_rows() -> void:
	"""The whole point: validate the ref, resolve the typed row from it, then copy."""
	var slot: int = _spawn(&"mouse")
	var ref: Vector2i = _residents.ref_of(slot)
	assert_true(_snapshot.capture(_directory, _residents, _needs, ref),
		"the snapshot captures a live resident")
	assert_equal(_snapshot.resident_row(), slot, "and resolved the store row from the reference")
	assert_equal(_snapshot.selected_ref(), ref, "recording the identity it belongs to")
	assert_equal(_snapshot.row_count(), 5, "GDD §4.2's five needs are all present")
	for need: int in NeedsScript.NEED_COUNT:
		assert_equal(_snapshot.row(need).basis_points, SPAWN_NEED,
			"need %d carries §5.1's spawn value" % need)


func test_all_five_rows_come_from_one_snapshot_identity() -> void:
	""""All five rows use the same snapshot identity" -- not five independent lookups."""
	var first: int = _spawn(&"mouse")
	var second: int = _spawn(&"otter")
	assert_true(_needs.apply_need_event(second, NeedsScript.NEED_REST, -1000).ok,
		"the second resident's rest is moved away from the first's")
	assert_true(_snapshot.capture(_directory, _residents, _needs,
		_residents.ref_of(first)), "the first resident is captured")
	assert_equal(_snapshot.resident_row(), first, "the snapshot holds the first row")
	assert_equal(_snapshot.row(NeedsScript.NEED_REST).basis_points, SPAWN_NEED,
		"and row rest is the FIRST resident's value, not the second's")


func test_a_stale_generation_refuses_rather_than_reading_the_replacement() -> void:
	"""A reused slot is a different resident. The generation check is what says so."""
	var slot: int = _spawn(&"mouse")
	var stale: Vector2i = _residents.ref_of(slot)
	assert_true(_residents.despawn(stale).ok, "the resident is despawned")
	var reborn: int = _spawn(&"otter")
	assert_equal(reborn, slot, "and the store reuses the same row")
	assert_false(_snapshot.capture(_directory, _residents, _needs, stale),
		"the old reference refuses")
	assert_equal(_snapshot.last_refusal(), UiResidentSnapshot.REFUSE_STALE_SELECTION,
		"by name, rather than reading the replacement")
	assert_equal(_snapshot.resident_row(), -1, "and the snapshot holds no row")


func test_a_refused_capture_clears_every_row_it_previously_held() -> void:
	"""A refusal must not leave the previous resident's percentages under a new heading."""
	var slot: int = _spawn(&"mouse")
	assert_true(_snapshot.capture(_directory, _residents, _needs, _residents.ref_of(slot)),
		"a real resident is captured first")
	assert_false(_snapshot.capture(_directory, _residents, _needs,
		EntityDirectoryScript.NULL_REF), "then the null reference refuses")
	for need: int in NeedsScript.NEED_COUNT:
		assert_equal(_snapshot.row(need).basis_points, 0, "row %d is emptied" % need)
		assert_equal(_snapshot.row(need).value_text, "", "and prints nothing")
		assert_false(_snapshot.row(need).has_rate, "and claims no rate")
	assert_equal(_snapshot.selected_ref(), EntityDirectoryScript.NULL_REF,
		"and the snapshot names no resident")


func test_a_reference_of_another_kind_refuses_by_name() -> void:
	"""A global entity slot is "not interchangeable" with a resident's typed row."""
	var room: Vector2i = _directory.create(EntityDirectoryScript.KIND_ROOM)
	assert_true(_directory.is_valid(room), "a real non-resident reference exists")
	assert_false(_snapshot.capture(_directory, _residents, _needs, room),
		"the snapshot refuses it")
	assert_equal(_snapshot.last_refusal(), UiResidentSnapshot.REFUSE_NOT_A_RESIDENT,
		"because it is not a RESIDENT row")


func test_a_missing_store_refuses_rather_than_printing_an_empty_card() -> void:
	"""Three stores are required; none of them is optional and none is defaulted."""
	assert_false(_snapshot.capture(null, _residents, _needs, EntityDirectoryScript.NULL_REF),
		"no directory refuses")
	assert_equal(_snapshot.last_refusal(), UiResidentSnapshot.REFUSE_NO_STORES, "by name")
	assert_false(_snapshot.capture(_directory, null, _needs, EntityDirectoryScript.NULL_REF),
		"and so does no resident store")
	assert_false(_snapshot.capture(_directory, _residents, null, EntityDirectoryScript.NULL_REF),
		"and no needs store")


func test_capturing_changes_no_byte_of_the_store() -> void:
	"""Asking for a rate applies no event: "No event is applied by asking for a rate"."""
	var slot: int = _spawn(&"mouse")
	var before: PackedInt32Array = PackedInt32Array()
	var reader: IntMath.IntResult = IntMath.IntResult.new()
	for need: int in NeedsScript.NEED_COUNT:
		assert_true(_needs.need_into(slot, need, reader), "need %d reads" % need)
		before.append(reader.value)
	for repeat: int in 4:
		assert_true(_snapshot.capture(_directory, _residents, _needs,
			_residents.ref_of(slot)), "capture %d succeeds" % repeat)
	for need: int in NeedsScript.NEED_COUNT:
		assert_true(_needs.need_into(slot, need, reader), "need %d still reads" % need)
		assert_equal(reader.value, before[need], "and need %d is unchanged" % need)
	assert_equal(_needs.health_of(slot).value, 100, "health is untouched too")


# --- hunger: the one reader that already exists, and its sign -------------------------------

func test_hunger_negates_the_published_magnitude_exactly_once() -> void:
	"""`hunger_rate_milli_per_hour()` stays a POSITIVE decay magnitude; the adapter uses -it."""
	var slot: int = _spawn(&"mouse")
	var magnitude: IntMath.IntResult = _needs.hunger_rate_milli_per_hour(
		_needs.size_class_of(slot).value)
	assert_true(magnitude.ok, "the store publishes hunger's magnitude")
	assert_equal(magnitude.value, SMALL_HUNGER_MAGNITUDE, "as a positive 250000 for a mouse")
	assert_true(_snapshot.capture(_directory, _residents, _needs, _residents.ref_of(slot)),
		"the resident is captured")
	var row: UiResidentSnapshot.NeedRow = _snapshot.row(NeedsScript.NEED_HUNGER)
	assert_true(row.has_rate, "hunger's rate binds")
	assert_equal(row.rate_milli, -SMALL_HUNGER_MAGNITUDE, "and is negated exactly once")
	assert_equal(row.rate_text, "-2.50 pp/h", "so the row reads as a fall")


func test_the_hunger_row_follows_the_size_class_the_store_verified() -> void:
	"""The magnitude carries the size multiplier; the adapter must not apply a second one."""
	var otter: int = _spawn(&"otter")
	var magnitude: int = _needs.hunger_rate_milli_per_hour(
		_needs.size_class_of(otter).value).value
	assert_true(_snapshot.capture(_directory, _residents, _needs, _residents.ref_of(otter)),
		"the otter is captured")
	assert_equal(_snapshot.row(NeedsScript.NEED_HUNGER).rate_milli, -magnitude,
		"the row is exactly the negated published magnitude for this size")


# --- the four published readers ---------------------------------------------------------------

func test_all_five_rows_bind_a_published_rate() -> void:
	"""UXV-020 passes only at five. Every row's condition is set through the store's own setters."""
	var slot: int = _spawn(&"mouse")
	_set_context(slot, NeedsScript.ACTIVITY_AWAKE, NeedsScript.COMFORT_ENV_MILD_OUTDOORS,
		true, NeedsScript.PURPOSE_SOURCE_LABOR)
	assert_true(_snapshot.capture(_directory, _residents, _needs, _residents.ref_of(slot)),
		"the capture succeeds")
	assert_equal(_snapshot.bound_rate_count(), 5, "all five rows carry a published rate")
	assert_equal(_snapshot.row(NeedsScript.NEED_HUNGER).rate_text, "-2.50 pp/h", "small, nonwinter")
	assert_equal(_snapshot.row(NeedsScript.NEED_REST).rate_text, "-3.75 pp/h", "rest awake")
	assert_equal(_snapshot.row(NeedsScript.NEED_COMFORT).rate_text, "0.00 pp/h",
		"mild outdoors is a legitimate zero, not a missing rate")
	assert_true(_snapshot.row(NeedsScript.NEED_COMFORT).has_rate, "and it is marked bound")
	assert_equal(_snapshot.row(NeedsScript.NEED_SOCIAL).rate_text, "+11.00 pp/h", "paired")
	assert_equal(_snapshot.row(NeedsScript.NEED_PURPOSE).rate_text, "+2.45 pp/h", "useful labor")


func test_a_signed_net_rate_is_passed_through_and_never_negated_again() -> void:
	""""The four new readers are signed net rates: do not negate them again"."""
	var slot: int = _spawn(&"mouse")
	_set_context(slot, NeedsScript.ACTIVITY_AWAKE, NeedsScript.COMFORT_ENV_MILD_OUTDOORS,
		true, NeedsScript.PURPOSE_SOURCE_LABOR)
	assert_true(_snapshot.capture(_directory, _residents, _needs, _residents.ref_of(slot)),
		"the capture succeeds")
	assert_equal(_snapshot.row(NeedsScript.NEED_REST).rate_milli, REST_AWAKE,
		"a falling rest rate stays negative")
	assert_equal(_snapshot.row(NeedsScript.NEED_SOCIAL).rate_milli, SOCIAL_PAIRED,
		"and a rising social rate stays positive")
	assert_equal(_snapshot.row(NeedsScript.NEED_PURPOSE).rate_milli, PURPOSE_USEFUL_LABOR,
		"with no baseline subtracted a second time")
	assert_equal(_snapshot.row(NeedsScript.NEED_COMFORT).rate_milli, COMFORT_MILD_OUTDOORS,
		"and an exact zero survives the round trip")


func test_every_inherited_fixture_condition_reaches_the_row_intact() -> void:
	"""The ruling's table, condition by condition, through the store's setters and the snapshot."""
	var slot: int = _spawn(&"mouse")
	var ref: Vector2i = _residents.ref_of(slot)
	_set_context(slot, NeedsScript.ACTIVITY_SLEEP_BED, NeedsScript.COMFORT_ENV_HEATED_ROOM,
		false, NeedsScript.PURPOSE_SOURCE_MENTORING)
	assert_true(_snapshot.capture(_directory, _residents, _needs, ref), "a sleeping capture")
	assert_equal(_snapshot.row(NeedsScript.NEED_REST).rate_text, "+12.00 pp/h", "sleeping in a bed")
	assert_equal(_snapshot.row(NeedsScript.NEED_COMFORT).rate_text, "+2.00 pp/h", "a heated room")
	assert_equal(_snapshot.row(NeedsScript.NEED_SOCIAL).rate_text, "-1.00 pp/h", "unpaired")
	assert_equal(_snapshot.row(NeedsScript.NEED_PURPOSE).rate_text, "+3.25 pp/h", "mentoring")
	_set_context(slot, NeedsScript.ACTIVITY_SLEEP_FLOOR, NeedsScript.COMFORT_ENV_NONE,
		false, NeedsScript.PURPOSE_SOURCE_NONE)
	assert_true(_snapshot.capture(_directory, _residents, _needs, ref), "and a barer one")
	assert_equal(_snapshot.row(NeedsScript.NEED_REST).rate_text, "+7.50 pp/h", "sleeping on a floor")
	assert_equal(_snapshot.row(NeedsScript.NEED_COMFORT).rate_text, "-1.00 pp/h", "no restoration")
	assert_equal(_snapshot.row(NeedsScript.NEED_PURPOSE).rate_text, "-0.75 pp/h", "and no purpose")


func test_winter_reaches_the_hunger_row_through_the_published_magnitude() -> void:
	"""REQ-SET-143's winter multiplier is already in the magnitude; the row must not re-apply it."""
	var slot: int = _spawn(&"mouse")
	assert_true(_needs.set_winter(true).ok, "winter is in force")
	assert_true(_snapshot.capture(_directory, _residents, _needs, _residents.ref_of(slot)),
		"the resident is captured in winter")
	assert_equal(_snapshot.row(NeedsScript.NEED_HUNGER).rate_text, "-3.00 pp/h",
		"a small resident's winter hunger is 300000 milli/hour")


func test_an_immediate_context_change_is_read_with_no_cached_lag() -> void:
	"""The snapshot caches no rate: a changed condition shows on the very next capture."""
	var slot: int = _spawn(&"mouse")
	var ref: Vector2i = _residents.ref_of(slot)
	assert_true(_snapshot.capture(_directory, _residents, _needs, ref), "awake to begin with")
	assert_equal(_snapshot.row(NeedsScript.NEED_REST).rate_text, "-3.75 pp/h", "awake")
	assert_true(_needs.set_activity(slot, NeedsScript.ACTIVITY_SLEEP_BED).ok, "and put to bed")
	assert_true(_snapshot.capture(_directory, _residents, _needs, ref), "captured again")
	assert_equal(_snapshot.row(NeedsScript.NEED_REST).rate_text, "+12.00 pp/h",
		"the bed rate shows immediately, with no tick in between")


func test_a_reader_that_refuses_leaves_no_zero_behind() -> void:
	"""A refusal writes `out.ok=false` and a cleared value; the caller must not print that zero."""
	var slot: int = _spawn(&"mouse")
	var ref: Vector2i = _residents.ref_of(slot)
	assert_true(_snapshot.capture(_directory, _residents, _needs, ref), "a living capture")
	assert_true(_snapshot.row(NeedsScript.NEED_REST).has_rate, "binds rest")
	assert_true(_residents.despawn(ref).ok, "the resident is despawned")
	assert_false(_snapshot.capture(_directory, _residents, _needs, ref),
		"and the stale reference refuses the whole card")
	assert_false(_snapshot.row(NeedsScript.NEED_REST).has_rate, "leaving no rate behind")
	assert_equal(_snapshot.row(NeedsScript.NEED_REST).rate_milli, 0,
		"and no number that could be read as a balanced resident")


# --- Capped, at the bounds, through the real store --------------------------------------------

func test_a_capped_row_keeps_its_rate_and_is_marked() -> void:
	"""At need 0 with a negative R: KEEP R and mark Capped. Never report 0."""
	var slot: int = _spawn(&"mouse")
	assert_true(_needs.apply_need_event(slot, NeedsScript.NEED_HUNGER, -SPAWN_NEED).ok,
		"the resident's fullness is driven to the floor")
	assert_equal(_needs.need_of(slot, NeedsScript.NEED_HUNGER).value, 0, "and sits at 0")
	assert_true(_snapshot.capture(_directory, _residents, _needs, _residents.ref_of(slot)),
		"the resident is captured")
	var row: UiResidentSnapshot.NeedRow = _snapshot.row(NeedsScript.NEED_HUNGER)
	assert_true(row.capped, "the row is capped")
	assert_equal(row.rate_milli, -SMALL_HUNGER_MAGNITUDE, "and keeps the model's own rate")
	assert_true(row.rate_text.contains("-2.50 pp/h"), "which it still prints: '%s'" % row.rate_text)
	assert_false(row.rate_text.contains("0.00"), "and never replaces with a zero")
	assert_true(row.rate_text.contains(UiNeedRate.CAPPED_LABEL), "marked Capped")


func test_an_interior_value_is_not_marked_capped() -> void:
	"""The spawn value is 7500, which is neither bound, so nothing is being discarded."""
	var slot: int = _spawn(&"mouse")
	assert_true(_snapshot.capture(_directory, _residents, _needs, _residents.ref_of(slot)),
		"the resident is captured at 7500")
	assert_false(_snapshot.row(NeedsScript.NEED_HUNGER).capped, "and the row is not capped")
	assert_equal(_snapshot.row(NeedsScript.NEED_HUNGER).rate_text, "-2.50 pp/h",
		"and carries no Capped mark")


func test_an_inward_rate_at_the_ceiling_is_not_capped() -> void:
	"""A rest rate of +12.00 at 10000 IS capped; a falling one at 10000 is not."""
	var slot: int = _spawn(&"mouse")
	var ref: Vector2i = _residents.ref_of(slot)
	assert_true(_needs.apply_need_event(slot, NeedsScript.NEED_REST,
		NeedsScript.NEED_MAX - SPAWN_NEED).ok, "rest is driven to the ceiling")
	assert_true(_needs.set_activity(slot, NeedsScript.ACTIVITY_SLEEP_BED).ok, "and it sleeps")
	assert_true(_snapshot.capture(_directory, _residents, _needs, ref), "the resident is captured")
	assert_true(_snapshot.row(NeedsScript.NEED_REST).capped, "a rising rate at 10000 is capped")
	assert_equal(_snapshot.row(NeedsScript.NEED_REST).rate_milli, 1200000,
		"and the capped row keeps the bed rate rather than reporting zero")
	assert_true(_needs.set_activity(slot, NeedsScript.ACTIVITY_AWAKE).ok, "it wakes")
	assert_true(_snapshot.capture(_directory, _residents, _needs, ref), "and is captured again")
	assert_false(_snapshot.row(NeedsScript.NEED_REST).capped,
		"a falling rate at the ceiling is inward, and inward rates are never capped")


# --- speed and pause --------------------------------------------------------------------------

func test_elapsed_simulation_does_not_change_a_per_hour_rate() -> void:
	""""Pause and speeds 0/1/2/4 do not scale these per-simulated-hour rates."

	Ticking the store is the only way simulated time passes in this fixture. The need VALUES
	move and the rate does not, because the rate is a property of the current conditions and
	not of how much time has gone by or how fast it went by.
	"""
	var slot: int = _spawn(&"mouse")
	assert_true(_snapshot.capture(_directory, _residents, _needs, _residents.ref_of(slot)),
		"the resident is captured before any tick")
	var before: String = _snapshot.row(NeedsScript.NEED_HUNGER).rate_text
	var value_before: int = _snapshot.row(NeedsScript.NEED_HUNGER).basis_points
	for step: int in 750:
		assert_true(_needs.tick(slot).ok, "tick %d applies" % step)
	assert_true(_snapshot.capture(_directory, _residents, _needs, _residents.ref_of(slot)),
		"and captured again a simulated hour later")
	assert_equal(_snapshot.row(NeedsScript.NEED_HUNGER).rate_text, before,
		"the displayed rate is identical")
	assert_true(_snapshot.row(NeedsScript.NEED_HUNGER).basis_points < value_before,
		"while the value it describes has actually fallen")
