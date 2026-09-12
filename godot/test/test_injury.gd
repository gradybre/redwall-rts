extends "res://test/framework/test_case.gd"
## Coverage for the aggregate Injury owner: GDD §4.2's Injury row, REQ-SET-172/173/174 and
## SET-MOVE-ECON-001 HAZ-001/002/004 (with HAZ-003's incident and fall arithmetic, whose
## movement half belongs to EH-05).
##
## THE LOAD-BEARING TESTS HERE ARE THE ORDERING ONES. A merge rule that is approximately right
## still looks correct on one incident; what breaks is the second one, the one that arrives
## after care work has been paid, and the treatment that arrives after death. So the suite
## drives real sequences through `needs.gd` rather than asserting a single call, and every
## refusal is checked by comparing BYTE IMAGES of both stores before and after -- decision
## 0059's allocate-before-consume rule is not something you can confirm by looking.
##
## `InjuryKind` is NOT re-derived here. Its six numbers are asserted literally against GDD §4.3
## line 215, because the failure this guards against is a renumbering that every other test in
## the repository would survive.

const InjuryScript := preload("res://scripts/core/injury.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## One game hour, in ticks (REQ-SET-006).
const HOUR: int = 750

var _injury: InjuryScript = null
var _needs: NeedsScript = null
var _directory: EntityDirectoryScript = null


func before_each() -> void:
	"""Fresh injury, needs and directory stores with no residents."""
	_injury = InjuryScript.new()
	_needs = NeedsScript.new()
	_directory = EntityDirectoryScript.new()


func _spawn(slot: int) -> void:
	"""Spawn one resident in both stores at the same RESIDENT typed row."""
	assert_true(_needs.spawn(slot, NeedsScript.SIZE_SMALL).ok, "needs.spawn(%d)" % slot)
	assert_true(_injury.spawn(slot).ok, "injury.spawn(%d)" % slot)


func _rescuer_ref(patient_slot: int) -> Vector2i:
	"""Allocate a RESIDENT directory reference whose typed row is NOT the patient's.

	This store indexes by the directory's RESIDENT typed row, and the directory hands those
	out from 0 upwards, so a test that spawns its patient at row 0 and then asks for "a
	rescuer" would get row 0 back and hit the self-rescue refusal instead of the rule under
	test. The assertion makes that collision impossible to miss.
	"""
	var ref: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_true(ref.x >= 0, "the directory allocated a resident reference")
	assert_true(_directory.get_typed_row(ref) != patient_slot, "and it is not the patient's row")
	return ref


func _health(slot: int) -> int:
	"""Read health, asserting the read was not refused."""
	var result: IntMath.IntResult = _needs.health_of(slot)
	assert_true(result.ok, "health_of(%d) succeeds" % slot)
	return result.value


func _value(result: IntMath.IntResult, label: String) -> int:
	"""Unwrap a reader result, asserting it succeeded."""
	assert_true(result.ok, "%s succeeds" % label)
	return result.value


func _needs_image(slot: int) -> PackedByteArray:
	"""Byte image of everything this suite can change in `needs.gd` for one resident.

	`needs.gd` publishes no `state_bytes()` of its own, so the comparison image is built from
	its public readers. It covers health, status and both health-rate inputs this module
	writes, which is exactly the surface a refused injury operation must leave untouched.
	"""
	var fields: PackedInt64Array = PackedInt64Array()
	fields.append(_health(slot))
	fields.append(_value(_needs.status_of(slot), "status_of"))
	fields.append(_value(_needs.injury_state_of(slot), "injury_state_of"))
	fields.append(_value(_needs.airless_of(slot), "airless_of"))
	for need: int in NeedsScript.NEED_COUNT:
		fields.append(_value(_needs.need_of(slot, need), "need_of"))
	return var_to_bytes(fields)


func _both_images(slot: int) -> PackedByteArray:
	"""One image spanning both collaborating stores, for a refusal's byte comparison."""
	var image: PackedByteArray = _injury.state_bytes()
	image.append_array(_needs_image(slot))
	return image


func _tick(slot: int, count: int) -> void:
	"""Advance both stores by `count` fixed ticks, in the order a scheduler phase would."""
	for _i: int in count:
		_injury.tick_all(_needs)
		_needs.tick_all()


# --- the enum domain ------------------------------------------------------------------------

func test_injury_kind_matches_gdd_section_4_3() -> void:
	"""GDD §4.3: NONE=0, CUT=1, BITE=2, FALL=3, EXPOSURE=4, EXHAUSTION=5, and no seventh."""
	assert_equal(InjuryScript.KIND_NONE, 0, "InjuryKind.NONE is 0")
	assert_equal(InjuryScript.KIND_CUT, 1, "InjuryKind.CUT is 1")
	assert_equal(InjuryScript.KIND_BITE, 2, "InjuryKind.BITE is 2")
	assert_equal(InjuryScript.KIND_FALL, 3, "InjuryKind.FALL is 3")
	assert_equal(InjuryScript.KIND_EXPOSURE, 4, "InjuryKind.EXPOSURE is 4")
	assert_equal(InjuryScript.KIND_EXHAUSTION, 5, "InjuryKind.EXHAUSTION is 5")
	assert_equal(InjuryScript.KIND_COUNT, 6, "the domain has exactly six members")


func test_published_care_and_rescue_costs() -> void:
	"""REQ-SET-173/174 and HAZ-004's rescue handling prices, in milli units."""
	assert_equal(InjuryScript.CARE_WORK_MWU, 60000, "60 WU of treatment")
	assert_equal(InjuryScript.SELF_CARE_WORK_MWU, 120000, "120 WU of self-treatment")
	assert_equal(InjuryScript.CARE_HERB_MILLI, 1000, "herb 1 U")
	assert_equal(InjuryScript.CARE_CLOTH_MILLI, 500, "cloth 0.5 U")
	assert_equal(InjuryScript.CARE_HEALTH_RESTORE, 10, "treatment restores 10 health")
	assert_equal(InjuryScript.RESCUE_PICKUP_WORK_MWU, 8000, "pickup is 8000 milli-WU HAUL")
	assert_equal(InjuryScript.RESCUE_SETDOWN_WORK_MWU, 4000, "set-down is 4000 milli-WU HAUL")
	assert_equal(InjuryScript.PATIENTS_PER_RESCUER, 1, "REQ-SET-171 carries one casualty")
	assert_equal(_value(IntMath.ceil_div(InjuryScript.RESCUE_PICKUP_WORK_MWU, 80), "pickup"),
		100, "pickup is 100 ticks at factor 1000 (80 milli-WU/tick)")
	assert_equal(_value(IntMath.ceil_div(InjuryScript.RESCUE_SETDOWN_WORK_MWU, 80), "setdown"),
		50, "set-down is 50 ticks at factor 1000")


func test_needs_injury_state_mapping() -> void:
	"""Severity 1 maps to INJURY_ACTIVE, severity 2 to INJURY_UNTREATED_SERIOUS."""
	assert_equal(InjuryScript.needs_injury_state_for(InjuryScript.SEVERITY_NONE),
		NeedsScript.INJURY_NONE, "no severity is no injury input")
	assert_equal(InjuryScript.needs_injury_state_for(InjuryScript.SEVERITY_MINOR),
		NeedsScript.INJURY_ACTIVE, "severity 1 is an active injury")
	assert_equal(InjuryScript.needs_injury_state_for(InjuryScript.SEVERITY_SERIOUS),
		NeedsScript.INJURY_UNTREATED_SERIOUS, "severity 2 bars REQ-SET-017 recovery")


# --- lifecycle ------------------------------------------------------------------------------

func test_spawned_row_carries_no_injury() -> void:
	"""A freshly spawned resident has no kind, no severity, no care work and no rescuer."""
	_spawn(0)
	assert_equal(_value(_injury.kind_of(0), "kind_of"), InjuryScript.KIND_NONE, "no kind")
	assert_equal(_value(_injury.severity_of(0), "severity_of"), 0, "no severity")
	assert_equal(_value(_injury.care_progress_mwu_of(0), "care"), 0, "no care work")
	assert_equal(_value(_injury.untreated_ticks_of(0), "ticks"), 0, "no untreated time")
	assert_false(_injury.has_rescuer(0), "no rescuer")
	assert_false(_injury.has_untreated_injury(0), "nothing bars HAZ-001 dangerous entry")
	assert_equal(_injury.present_count(), 1, "one row is spawned")


func test_unknown_and_absent_rows_refuse_rather_than_answer() -> void:
	"""Every reader and mutator refuses an out-of-range or unspawned row."""
	assert_false(_injury.kind_of(-1).ok, "a negative slot refuses")
	assert_false(_injury.kind_of(InjuryScript.RESIDENT_CAPACITY).ok, "an over-range slot refuses")
	assert_false(_injury.severity_of(3).ok, "an unspawned row refuses")
	assert_false(_injury.spawn(-1).ok, "spawn refuses an invalid slot")
	_spawn(0)
	assert_false(_injury.spawn(0).ok, "a second spawn of the same row refuses")
	assert_true(_injury.despawn(0).ok, "despawn releases the row")
	assert_false(_injury.despawn(0).ok, "despawning twice refuses")
	assert_equal(_injury.present_count(), 0, "the row is gone")


# --- the merge rule -------------------------------------------------------------------------

func test_worse_severity_replaces_and_lower_severity_does_not() -> void:
	"""GDD §4.2: at most one aggregate injury, worse severity replaces."""
	_spawn(0)
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 20, 1, _needs).ok,
		"a severity 1 cut applies")
	assert_equal(_value(_injury.kind_of(0), "kind"), InjuryScript.KIND_CUT, "the cut is aggregate")
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_EXPOSURE, 2, 0, 2, _needs).ok,
		"a severity 2 exposure applies")
	assert_equal(_value(_injury.severity_of(0), "severity"), 2, "severity escalates to 2")
	assert_equal(_value(_injury.kind_of(0), "kind"), InjuryScript.KIND_EXPOSURE, "kind follows")
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_BITE, 1, 0, 3, _needs).ok,
		"a later severity 1 bite applies its own damage")
	assert_equal(_value(_injury.severity_of(0), "severity"), 2, "but does not lower severity")
	assert_equal(_value(_injury.kind_of(0), "kind"), InjuryScript.KIND_EXPOSURE,
		"and does not replace the worse kind")


func test_equal_severity_retains_the_lower_injury_kind_id() -> void:
	"""HAZ-004: "If equal-severity incoming kinds conflict, retain the lower InjuryKind ID"."""
	_spawn(0)
	_spawn(1)
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_FALL, 1, 0, 1, _needs).ok, "fall")
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 0, 2, _needs).ok, "then cut")
	assert_equal(_value(_injury.kind_of(0), "kind"), InjuryScript.KIND_CUT,
		"CUT=1 is lower than FALL=3 and wins the tie")
	assert_true(_injury.apply_incident(1, InjuryScript.KIND_CUT, 1, 0, 1, _needs).ok, "cut")
	assert_true(_injury.apply_incident(1, InjuryScript.KIND_FALL, 1, 0, 2, _needs).ok, "then fall")
	assert_equal(_value(_injury.kind_of(1), "kind"), InjuryScript.KIND_CUT,
		"the same answer in the opposite order, so the rule is order-independent")


func test_a_new_incident_erases_neither_untreated_time_nor_care_work() -> void:
	"""HAZ-004: a new incident keeps elapsed untreated time and already paid care work."""
	_spawn(0)
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 0, 1, _needs).ok, "cut")
	_tick(0, 2 * HOUR)
	assert_true(_injury.add_care_work(0, 25000, _needs).ok, "25 WU of care is paid")
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_EXPOSURE, 2, 0, 2, _needs).ok,
		"a worse incident arrives")
	assert_equal(_value(_injury.untreated_ticks_of(0), "ticks"), 2 * HOUR,
		"the untreated clock is not reset")
	assert_equal(_value(_injury.untreated_hours_of(0), "hours"), 2, "two whole untreated hours")
	assert_equal(_value(_injury.care_progress_mwu_of(0), "care"), 25000,
		"already paid care work survives the new incident")


func test_an_incident_ordinal_is_charged_once() -> void:
	"""HAZ-004 deduplication: a replayed one-shot event refuses and changes nothing."""
	_spawn(0)
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_BITE, 1, 20, 7, _needs).ok,
		"the fishing incident applies 20 health loss")
	assert_equal(_health(0), 80, "REQ-SET-053's 20 health is removed once")
	var before: PackedByteArray = _both_images(0)
	var replay: NeedsScript.OpResult = _injury.apply_incident(0, InjuryScript.KIND_BITE, 1, 20,
		7, _needs)
	assert_false(replay.ok, "the same ordinal refuses")
	assert_equal(replay.error, InjuryScript.REFUSE_DUPLICATE_INCIDENT, "named as a duplicate")
	assert_equal(_both_images(0), before, "and both stores are byte-identical")
	assert_false(_injury.apply_incident(0, InjuryScript.KIND_BITE, 1, 20, 6, _needs).ok,
		"an older ordinal refuses too")
	assert_equal(_health(0), 80, "so the damage is never charged twice")


func test_incident_arguments_are_validated_before_anything_is_written() -> void:
	"""Every out-of-domain argument refuses, leaving both stores byte-identical."""
	_spawn(0)
	var before: PackedByteArray = _both_images(0)
	assert_false(_injury.apply_incident(0, InjuryScript.KIND_NONE, 1, 0, 1, _needs).ok,
		"KIND_NONE is not an incident")
	assert_false(_injury.apply_incident(0, InjuryScript.KIND_COUNT, 1, 0, 1, _needs).ok,
		"a kind outside the domain refuses")
	assert_false(_injury.apply_incident(0, InjuryScript.KIND_CUT, 0, 0, 1, _needs).ok,
		"severity 0 is not an injury")
	assert_false(_injury.apply_incident(0, InjuryScript.KIND_CUT, 3, 0, 1, _needs).ok,
		"severity 3 is outside REQ-SET-172's two bands")
	assert_false(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, -1, 1, _needs).ok,
		"a negative health loss refuses rather than healing")
	assert_false(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 101, 1, _needs).ok,
		"a loss above the health range refuses")
	assert_false(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 0, 0, _needs).ok,
		"ordinal 0 means no incident identity")
	assert_equal(_both_images(0), before, "nothing was written by any of them")


# --- the untreated clock --------------------------------------------------------------------

func test_untreated_hours_are_the_floor_of_the_tick_counter() -> void:
	"""750 ticks is one untreated hour; 749 is none, and an uninjured row never advances."""
	_spawn(0)
	_spawn(1)
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 0, 1, _needs).ok, "injured")
	_tick(0, HOUR - 1)
	assert_equal(_value(_injury.untreated_ticks_of(0), "ticks"), HOUR - 1, "749 ticks elapsed")
	assert_equal(_value(_injury.untreated_hours_of(0), "hours"), 0, "which is no whole hour")
	_tick(0, 1)
	assert_equal(_value(_injury.untreated_hours_of(0), "hours"), 1, "the 750th tick makes one")
	assert_equal(_value(_injury.untreated_ticks_of(1), "ticks"), 0,
		"the uninjured resident's clock never started")


func test_the_tick_sweep_counts_only_living_injured_rows() -> void:
	"""`tick_all()` advances injured, living rows and refuses without a needs store."""
	_spawn(0)
	_spawn(1)
	assert_equal(_injury.tick_all(_needs).value, 0, "nobody is injured yet")
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 0, 1, _needs).ok, "injured")
	assert_equal(_injury.tick_all(_needs).value, 1, "one injured row advances")
	assert_true(_needs.apply_health_event(0, -100).ok, "the resident dies")
	assert_equal(_injury.tick_all(_needs).value, 0, "a dead resident's clock stops")
	assert_false(_injury.tick_all(null).ok, "and the sweep refuses without a needs store")


# --- care ------------------------------------------------------------------------------------

func test_treatment_clears_the_injury_and_restores_ten_health() -> void:
	"""REQ-SET-173, and the drain stops because the needs input returns to INJURY_NONE."""
	_spawn(0)
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_EXPOSURE, 2, 35, 1, _needs).ok,
		"REQ-SET-053's boat hazard: severity 2 exposure, 35 health")
	assert_equal(_health(0), 65, "35 health is removed")
	assert_equal(_value(_needs.injury_state_of(0), "state"), NeedsScript.INJURY_UNTREATED_SERIOUS,
		"which bars REQ-SET-017 recovery")
	assert_true(_injury.add_care_work(0, InjuryScript.CARE_WORK_MWU, _needs).ok, "60 WU is paid")
	var treated: NeedsScript.OpResult = _injury.complete_treatment(0,
		InjuryScript.CARE_WORK_MWU, _needs)
	assert_true(treated.ok, "treatment completes")
	assert_equal(_health(0), 75, "and restores exactly 10 health")
	assert_equal(_value(_injury.kind_of(0), "kind"), InjuryScript.KIND_NONE, "the injury is gone")
	assert_equal(_value(_injury.care_progress_mwu_of(0), "care"), 0, "care progress is consumed")
	assert_equal(_value(_injury.untreated_ticks_of(0), "ticks"), 0, "the untreated clock resets")
	assert_equal(_value(_needs.injury_state_of(0), "state"), NeedsScript.INJURY_NONE,
		"and the health rate loses its untreated term")


func test_treatment_caps_restored_health_at_one_hundred() -> void:
	"""REQ-SET-173's "capped 100" -- the +10 is absorbed, not overshot."""
	_spawn(0)
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 5, 1, _needs).ok, "5 health")
	assert_true(_injury.add_care_work(0, InjuryScript.CARE_WORK_MWU, _needs).ok, "60 WU")
	var treated: NeedsScript.OpResult = _injury.complete_treatment(0,
		InjuryScript.CARE_WORK_MWU, _needs)
	assert_true(treated.ok, "treatment completes")
	assert_equal(_health(0), 100, "health caps at 100")
	assert_equal(treated.value, 5, "and reports the 5 points actually absorbed, not 10")


func test_incomplete_or_mispriced_care_refuses_without_touching_either_store() -> void:
	"""Treatment below the required work, or against an unpublished requirement, refuses."""
	_spawn(0)
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 10, 1, _needs).ok, "injured")
	assert_true(_injury.add_care_work(0, InjuryScript.CARE_WORK_MWU - 1, _needs).ok, "one short")
	var before: PackedByteArray = _both_images(0)
	var short: NeedsScript.OpResult = _injury.complete_treatment(0,
		InjuryScript.CARE_WORK_MWU, _needs)
	assert_false(short.ok, "one milli-WU short refuses")
	assert_equal(short.error, InjuryScript.REFUSE_CARE_INCOMPLETE, "named as incomplete work")
	assert_false(_injury.complete_treatment(0, 59999, _needs).ok,
		"an invented requirement refuses even though the work would cover it")
	assert_false(_injury.complete_treatment(0, InjuryScript.SELF_CARE_WORK_MWU, _needs).ok,
		"REQ-SET-174's self-treatment needs its own 120 WU")
	assert_equal(_both_images(0), before, "and nothing was written by any of them")


func test_self_treatment_requires_the_doubled_work() -> void:
	"""REQ-SET-174: the conscious last resident treats itself at 120 WU, not 60."""
	_spawn(0)
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 10, 1, _needs).ok, "injured")
	assert_true(_injury.add_care_work(0, InjuryScript.SELF_CARE_WORK_MWU, _needs).ok, "120 WU")
	assert_true(_injury.complete_treatment(0, InjuryScript.SELF_CARE_WORK_MWU, _needs).ok,
		"self-treatment completes at 120 WU")
	assert_equal(_value(_injury.kind_of(0), "kind"), InjuryScript.KIND_NONE, "the injury is gone")


func test_care_work_needs_an_injury_and_a_permitted_context() -> void:
	"""HAZ-004: no treatment work in a blocked movement context, and none without an injury."""
	_spawn(0)
	assert_false(_injury.add_care_work(0, 1000, _needs).ok, "an uninjured resident refuses care")
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 10, 1, _needs).ok, "injured")
	assert_false(_injury.add_care_work(0, 0, _needs).ok, "zero work refuses")
	assert_false(_injury.add_care_work(0, -1000, _needs).ok, "negative work refuses")
	assert_true(_injury.set_care_context_blocked(0, true).ok, "the movement owner blocks care")
	var blocked: NeedsScript.OpResult = _injury.add_care_work(0, 60000, _needs)
	assert_false(blocked.ok, "care work refuses in active water, a fall or a carry")
	assert_equal(blocked.error, InjuryScript.REFUSE_CARE_BLOCKED, "named as a blocked context")
	assert_true(_injury.set_care_context_blocked(0, false).ok, "the context clears")
	assert_true(_injury.add_care_work(0, 60000, _needs).ok, "and the same work is accepted")


func test_care_work_in_progress_survives_a_change_of_helper() -> void:
	"""HAZ-004: "Changing helpers retains WIP" -- progress belongs to the patient."""
	_spawn(0)
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 10, 1, _needs).ok, "injured")
	assert_true(_injury.add_care_work(0, 20000, _needs).ok, "the first helper pays 20 WU")
	assert_true(_injury.add_care_work(0, 40000, _needs).ok, "a second helper pays 40 WU")
	assert_equal(_value(_injury.care_progress_mwu_of(0), "care"), 60000, "which totals 60 WU")
	assert_true(_injury.complete_treatment(0, InjuryScript.CARE_WORK_MWU, _needs).ok,
		"and completes the treatment with no work lost in the handover")


# --- death is final ---------------------------------------------------------------------------

func test_a_dead_resident_cannot_be_healed_by_a_completed_treatment() -> void:
	"""HAZ-004: "a completed treatment cannot undo it." The care work is already paid here."""
	_spawn(0)
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 10, 1, _needs).ok, "injured")
	assert_true(_injury.add_care_work(0, InjuryScript.CARE_WORK_MWU, _needs).ok, "60 WU is paid")
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_FALL, 2, 90, 2, _needs).ok,
		"then a lethal fall lands")
	assert_equal(_health(0), 0, "health reaches 0")
	assert_equal(_value(_needs.status_of(0), "status"), NeedsScript.STATUS_DEAD, "and death is committed")
	var before: PackedByteArray = _both_images(0)
	var revive: NeedsScript.OpResult = _injury.complete_treatment(0,
		InjuryScript.CARE_WORK_MWU, _needs)
	assert_false(revive.ok, "the fully paid treatment refuses")
	assert_equal(revive.error, InjuryScript.REFUSE_RESIDENT_DEAD, "because the patient is dead")
	assert_equal(_health(0), 0, "health is still 0")
	assert_equal(_both_images(0), before, "and neither store moved")


func test_a_dead_resident_takes_no_further_incident_or_care() -> void:
	"""HAZ-004: later care or damage calls cannot resurrect or kill a body again."""
	_spawn(0)
	assert_true(_needs.apply_health_event(0, -100).ok, "the resident dies of something else")
	assert_equal(_needs.death_count(), 1, "exactly one death is recorded")
	var before: PackedByteArray = _both_images(0)
	assert_false(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 10, 1, _needs).ok,
		"a corpse takes no new injury")
	assert_false(_injury.add_care_work(0, 60000, _needs).ok, "and no care work")
	assert_false(_injury.begin_airless_episode(0, 1, _needs).ok, "and no airless episode")
	assert_equal(_needs.death_count(), 1, "so it is never killed a second time")
	assert_equal(_both_images(0), before, "and nothing was written")


# --- HAZ-002 airless episodes -------------------------------------------------------------------

func test_one_airless_episode_creates_exactly_one_exposure_incident() -> void:
	"""HAZ-002: one EXPOSURE severity 2 incident per continuous episode, not one per tick."""
	_spawn(0)
	assert_true(_injury.begin_airless_episode(0, 1, _needs).ok, "air runs out")
	assert_equal(_value(_injury.kind_of(0), "kind"), InjuryScript.KIND_EXPOSURE, "EXPOSURE")
	assert_equal(_value(_injury.severity_of(0), "severity"), 2, "at severity 2")
	assert_equal(_health(0), 100, "with no immediate health loss")
	assert_true(_injury.airless_episode_active(0), "the episode is latched")
	var second: NeedsScript.OpResult = _injury.begin_airless_episode(0, 2, _needs)
	assert_false(second.ok, "a second call inside the same episode refuses")
	assert_equal(second.error, InjuryScript.REFUSE_AIRLESS_ACTIVE, "as an active episode")


func test_a_later_airless_episode_is_a_distinct_incident_not_a_reset() -> void:
	"""HAZ-002: reaching air ends the episode; the injury and its elapsed time remain."""
	_spawn(0)
	assert_true(_injury.begin_airless_episode(0, 1, _needs).ok, "the first episode")
	_tick(0, HOUR)
	assert_true(_injury.end_airless_episode(0).ok, "breathable support is reached")
	assert_false(_injury.airless_episode_active(0), "the latch clears")
	assert_equal(_value(_injury.kind_of(0), "kind"), InjuryScript.KIND_EXPOSURE,
		"but the injury remains until treatment")
	assert_false(_injury.end_airless_episode(0).ok, "ending a closed episode refuses")
	assert_true(_injury.begin_airless_episode(0, 2, _needs).ok, "a later episode re-arms")
	assert_equal(_value(_injury.untreated_ticks_of(0), "ticks"), HOUR,
		"and does not reset the untreated clock")


# --- HAZ-003 exhaustion and falls ---------------------------------------------------------------

func test_exhaustion_fires_once_and_re_arms_only_at_rest_four_thousand() -> void:
	"""HAZ-003: EXHAUSTION severity 1, no health loss, re-armed only once rest reaches 4000."""
	_spawn(0)
	assert_true(_needs.apply_need_event(0, NeedsScript.NEED_REST, -7500).ok, "rest reaches 0")
	assert_true(_injury.apply_exhaustion_incident(0, 1, _needs).ok, "exhaustion fires")
	assert_equal(_value(_injury.kind_of(0), "kind"), InjuryScript.KIND_EXHAUSTION, "EXHAUSTION")
	assert_equal(_value(_injury.severity_of(0), "severity"), 1, "at severity 1")
	assert_equal(_health(0), 100, "with zero immediate health loss")
	assert_false(_injury.apply_exhaustion_incident(0, 2, _needs).ok, "it cannot fire again")
	assert_true(_needs.apply_need_event(0, NeedsScript.NEED_REST, 3999).ok, "rest recovers to 3999")
	var early: NeedsScript.OpResult = _injury.rearm_exhaustion(0, _needs)
	assert_false(early.ok, "which is one point short of the re-arm threshold")
	assert_equal(early.error, InjuryScript.REFUSE_EXHAUSTION_REARM_REST, "named as the rest gate")
	assert_true(_needs.apply_need_event(0, NeedsScript.NEED_REST, 1).ok, "rest reaches 4000")
	assert_true(_injury.rearm_exhaustion(0, _needs).ok, "and the incident re-arms")
	assert_false(_injury.exhaustion_latched(0), "the latch is clear")


func test_fall_arithmetic_matches_the_authored_fixtures() -> void:
	"""HAZ-003: D 1024/2048/4096/8192 give (8,1,8), (16,1,15), (32,2,30) and (40,2,60)."""
	var drops: PackedInt32Array = PackedInt32Array([1024, 2048, 4096, 8192])
	var damages: PackedInt32Array = PackedInt32Array([8, 16, 32, 40])
	var severities: PackedInt32Array = PackedInt32Array([1, 1, 2, 2])
	var ticks: PackedInt32Array = PackedInt32Array([8, 15, 30, 60])
	for index: int in drops.size():
		var drop: int = drops[index]
		assert_equal(_value(InjuryScript.fall_damage(drop), "damage"), damages[index],
			"drop %d removes %d health" % [drop, damages[index]])
		assert_equal(_value(InjuryScript.fall_severity(drop), "severity"), severities[index],
			"drop %d is severity %d" % [drop, severities[index]])
		assert_equal(_value(InjuryScript.fall_recovery_ticks(drop), "ticks"), ticks[index],
			"drop %d recovers over %d ticks" % [drop, ticks[index]])


func test_a_fall_needs_a_positive_declared_drop() -> void:
	"""HAZ-003: a declared fall has a positive drop, so 0 refuses instead of costing nothing."""
	_spawn(0)
	assert_false(InjuryScript.fall_damage(0).ok, "a zero drop refuses")
	assert_false(InjuryScript.fall_severity(0).ok, "and has no severity")
	assert_false(InjuryScript.fall_recovery_ticks(-1).ok, "and no recovery duration")
	var before: PackedByteArray = _both_images(0)
	assert_false(_injury.apply_fall_injury(0, 0, 1, _needs).ok, "the touchdown call refuses too")
	assert_equal(_both_images(0), before, "leaving both stores byte-identical")


func test_touchdown_applies_the_fall_once() -> void:
	"""The one-shot touchdown consequence: FALL, the computed loss, the computed severity."""
	_spawn(0)
	assert_true(_injury.apply_fall_injury(0, 4096, 1, _needs).ok, "a 4 m fall lands")
	assert_equal(_health(0), 68, "32 health is removed once")
	assert_equal(_value(_injury.kind_of(0), "kind"), InjuryScript.KIND_FALL, "as a FALL injury")
	assert_equal(_value(_injury.severity_of(0), "severity"), 2, "at severity 2")
	assert_false(_injury.apply_fall_injury(0, 4096, 1, _needs).ok, "the same ordinal refuses")
	assert_equal(_health(0), 68, "so the descent cannot be charged twice")


# --- HAZ-004 rescue ---------------------------------------------------------------------------

func test_a_rescue_does_not_clear_the_injury() -> void:
	"""GDD §5.2: "a rescue does not clear an injury until treatment completes"."""
	_spawn(1)
	var rescuer: Vector2i = _rescuer_ref(1)
	assert_true(_injury.apply_incident(1, InjuryScript.KIND_EXPOSURE, 2, 35, 1, _needs).ok,
		"the patient is seriously injured")
	assert_true(_injury.add_care_work(1, 10000, _needs).ok, "with some care already paid")
	_tick(1, HOUR)
	assert_true(_injury.set_rescuer(1, rescuer, _directory, _needs).ok, "a rescuer is assigned")
	assert_true(_injury.has_rescuer(1), "the relationship is recorded")
	assert_equal(_value(_injury.rescuer_slot_of(1), "slot"), rescuer.x, "with the right slot")
	assert_equal(_value(_injury.rescuer_generation_of(1), "gen"), rescuer.y, "and generation")
	assert_equal(_value(_injury.kind_of(1), "kind"), InjuryScript.KIND_EXPOSURE, "injury remains")
	assert_equal(_value(_injury.severity_of(1), "severity"), 2, "at the same severity")
	assert_equal(_value(_injury.untreated_ticks_of(1), "ticks"), HOUR, "still untreated")
	assert_equal(_value(_injury.care_progress_mwu_of(1), "care"), 10000, "care work untouched")
	assert_equal(_value(_needs.injury_state_of(1), "state"), NeedsScript.INJURY_UNTREATED_SERIOUS,
		"and the health drain is still running")


func test_the_untreated_drain_continues_while_being_carried() -> void:
	"""A rescue buys time, it does not stop REQ-SET-172's clock or its damage."""
	_spawn(1)
	var rescuer: Vector2i = _rescuer_ref(1)
	assert_true(_injury.apply_incident(1, InjuryScript.KIND_EXPOSURE, 2, 0, 1, _needs).ok,
		"severity 2, no immediate loss")
	assert_true(_injury.set_rescuer(1, rescuer, _directory, _needs).ok, "carried")
	_tick(1, HOUR)
	assert_equal(_health(1), 96, "4 health/hour still goes while in the rescuer's arms")
	assert_equal(_value(_injury.untreated_hours_of(1), "hours"), 1, "and the hour counted")


func test_one_rescuer_carries_one_patient() -> void:
	"""REQ-SET-171 and HAZ-004: the same helper cannot be assigned to two casualties."""
	_spawn(1)
	_spawn(2)
	var rescuer: Vector2i = _rescuer_ref(1)
	assert_true(_injury.set_rescuer(1, rescuer, _directory, _needs).ok, "the first patient")
	var second: NeedsScript.OpResult = _injury.set_rescuer(2, rescuer, _directory, _needs)
	assert_false(second.ok, "a second patient for the same rescuer refuses")
	assert_equal(second.error, InjuryScript.REFUSE_RESCUER_BUSY, "named as already assigned")
	assert_false(_injury.has_rescuer(2), "and the second patient has no rescuer")
	assert_true(_injury.set_rescuer(1, rescuer, _directory, _needs).ok,
		"re-confirming the same pairing is not a second patient")
	assert_true(_injury.clear_rescuer(1).ok, "releasing the first")
	assert_true(_injury.set_rescuer(2, rescuer, _directory, _needs).ok, "frees the rescuer")


func test_a_rescuer_reference_is_generation_checked() -> void:
	"""An unvalidatable, self-referencing or stale rescuer reference refuses or reads dead."""
	_spawn(1)
	var rescuer: Vector2i = _rescuer_ref(1)
	var patient_ref: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_equal(_directory.get_typed_row(patient_ref), 1, "the second directory row is row 1")
	assert_false(_injury.set_rescuer(1, rescuer, null, _needs).ok,
		"without a directory there is nothing to validate the reference against")
	assert_false(_injury.set_rescuer(1, Vector2i(rescuer.x, rescuer.y + 1), _directory, _needs).ok,
		"a wrong generation refuses")
	assert_false(_injury.set_rescuer(1, EntityDirectoryScript.NULL_REF, _directory, _needs).ok,
		"the null reference refuses")
	assert_false(_injury.set_rescuer(1, patient_ref, _directory, _needs).ok,
		"a resident cannot rescue itself")
	assert_true(_injury.set_rescuer(1, rescuer, _directory, _needs).ok, "a live reference is kept")
	assert_true(_injury.rescuer_is_live(1, _directory), "and reads live")
	assert_true(_directory.destroy(rescuer), "the rescuer leaves the settlement")
	assert_true(_injury.has_rescuer(1), "the stored reference is not swept")
	assert_false(_injury.rescuer_is_live(1, _directory), "but generation validation rejects it")


func test_treatment_releases_the_rescue_relationship() -> void:
	"""The carry ends when the care it was for completes, not before."""
	_spawn(1)
	var rescuer: Vector2i = _rescuer_ref(1)
	assert_true(_injury.apply_incident(1, InjuryScript.KIND_CUT, 1, 10, 1, _needs).ok, "injured")
	assert_true(_injury.set_rescuer(1, rescuer, _directory, _needs).ok, "carried")
	assert_true(_injury.add_care_work(1, InjuryScript.CARE_WORK_MWU, _needs).ok, "60 WU")
	assert_true(_injury.complete_treatment(1, InjuryScript.CARE_WORK_MWU, _needs).ok, "treated")
	assert_false(_injury.has_rescuer(1), "and the rescue relationship is released")


# --- serialization -----------------------------------------------------------------------------

func test_state_bytes_is_deterministic_and_sees_every_column() -> void:
	"""Two identical worlds agree; every column this store owns moves the image."""
	_spawn(0)
	var twin: InjuryScript = InjuryScript.new()
	var twin_needs: NeedsScript = NeedsScript.new()
	assert_true(twin_needs.spawn(0, NeedsScript.SIZE_SMALL).ok, "the twin world's resident")
	assert_true(twin.spawn(0).ok, "and its injury row")
	assert_equal(twin.state_bytes(), _injury.state_bytes(), "identical worlds agree")
	assert_true(_injury.apply_incident(0, InjuryScript.KIND_CUT, 1, 0, 1, _needs).ok, "injured")
	assert_true(_injury.state_bytes() != twin.state_bytes(), "an injury changes the image")
	assert_true(twin.apply_incident(0, InjuryScript.KIND_CUT, 1, 0, 1, twin_needs).ok, "same there")
	assert_equal(twin.state_bytes(), _injury.state_bytes(), "and they agree again")
	assert_true(_injury.set_care_context_blocked(0, true).ok, "an input column changes")
	assert_true(_injury.state_bytes() != twin.state_bytes(), "and the image follows it")
	assert_true(_injury.despawn(0).ok, "despawning empties the row")
	assert_true(_injury.state_bytes() != twin.state_bytes(), "which the image shows")
