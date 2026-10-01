extends "res://test/framework/test_case.gd"
## PC-04 households and daily care (FAMILY-STATE-R01, DEC-044, decision 0521).
##
## Every expectation is restated from the specification rather than read back from the module:
## the care rates, thresholds and turn bound are Brendan's confirmed values in DEC-044, the byte
## total is FAMILY-STATE-R01's 46352, and the 6000 -> 8750 -> 8740 -> 9000 walk is the execution
## package's own version-2 worked example.

const Households := preload("res://scripts/core/households.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")

## Non-resident directory rows created first, so a resident's directory SLOT never equals its
## typed ROW: a store that confused the two would pass a fixture where they coincide.
const FILLER_ROWS: int = 5

const ADULT: int = 0
const CHILD: int = 1
const ELDER: int = 2
const I32_MAX: int = 2147483647

var _residents: ResidentsScript = null
var _store: Households = null
var _out: IntMath.IntResult = null


func before_each() -> void:
	"""A fresh Residents store with its household owner."""
	_residents = ResidentsScript.new()
	for filler: int in FILLER_ROWS:
		_residents.directory().create(EntityDirectory.KIND_RESOURCE_NODE)
	_store = Households.new(_residents)
	_out = IntMath.IntResult.new()


func after_each() -> void:
	"""Drop the fixtures."""
	_store = null
	_residents = null


func _spawn(key: StringName, stage: int, bind: bool = true) -> Vector2i:
	"""Spawn one resident at a stage, bind its dependent row, and return its directory ref."""
	var made: ResidentsScript.OpResult = _residents.spawn_with_stage(key, stage)
	assert_true(made.ok, "spawn %s at stage %d" % [key, stage])
	if bind:
		assert_true(_store.bind_resident_into(made.ref, _out), "bind %s" % key)
	return made.ref


func _row(ref: Vector2i) -> int:
	"""Typed resident row of a ref."""
	return _residents.slot_of_ref(ref).value


func _pid(ref: Vector2i) -> int:
	"""Persistent ID of a ref."""
	return _residents.directory().get_persistent_id(ref)


func _refs(list: Array) -> Array[Vector2i]:
	"""A typed ref list for the store's APIs."""
	var typed: Array[Vector2i] = []
	for ref: Vector2i in list:
		typed.append(ref)
	return typed


func _paired(rows: Array) -> PackedByteArray:
	"""A 512-row paired column with 1 at each listed row."""
	var column: PackedByteArray = PackedByteArray()
	column.resize(Households.RESIDENT_CAPACITY)
	for row: int in rows:
		column[row] = 1
	return column


func _advance(ticks: int, paired: PackedByteArray) -> void:
	"""Run `ticks` care ticks, asserting each one accepts."""
	for tick: int in ticks:
		if not _store.advance_care_into(paired, _out):
			assert_true(false, "care tick %d refused: %s" % [tick, _out.error])
			return
	assert_true(true, "%d care ticks ran" % ticks)


# --- layout -------------------------------------------------------------------------------------

func test_the_owner_payload_is_the_specified_46352_bytes() -> void:
	"""19720 household bytes + 26632 dependent bytes, re-derived from the live columns."""
	assert_equal(_store.payload_bytes(), 46352, "FAMILY-STATE-R01 combined owner payload")
	assert_equal(Households.MEMBER_CAPACITY, 2048, "256 households x 8 members")
	assert_equal(Households.OWNER_SCHEMA_VERSION, 1, "a new owner starts at schema 1")


# --- pure care arithmetic -----------------------------------------------------------------------

func _step(care: int, remainder: int, served: bool, ticks: int) -> PackedInt64Array:
	"""Apply the pure care step `ticks` times."""
	var state: PackedInt64Array = PackedInt64Array([care, remainder])
	for tick: int in ticks:
		assert(Households.care_after_tick(state[0], state[1], served, state))
	return state


func test_care_decays_250_per_hour_with_a_signed_remainder() -> void:
	"""One idle tick keeps -250000 milli; three release exactly one point; an hour releases 250."""
	assert_equal(_step(6500, 0, false, 1), PackedInt64Array([6500, -250000]), "one tick")
	assert_equal(_step(6500, 0, false, 3), PackedInt64Array([6499, 0]), "three ticks")
	assert_equal(_step(6500, 0, false, 750), PackedInt64Array([6250, 0]), "one hour")


func test_the_package_worked_example_reaches_9000_in_more_than_one_turn() -> void:
	"""6000 -> 8750 in 750 served ticks, 30 idle -> 8740, 71 served -> 9000 (EP version 2)."""
	var state: PackedInt64Array = _step(6000, 0, true, 750)
	assert_equal(state, PackedInt64Array([8750, 0]), "a full turn nets +2750")
	state = _step(state[0], state[1], false, 30)
	assert_equal(state, PackedInt64Array([8740, 0]), "thirty idle ticks")
	state = _step(state[0], state[1], true, 71)
	assert_equal(state[0], 9000, "seventy-one served ticks reach completion")


func test_1500_served_ticks_a_day_exactly_balance_a_days_decay() -> void:
	"""The review's equilibrium: 1500 paired ticks supply 6000 gross, matching 24 hours of decay."""
	var state: PackedInt64Array = PackedInt64Array([6000, 0])
	for half: int in 2:
		state = _step(state[0], state[1], true, 750)
		state = _step(state[0], state[1], false, 8250)
	assert_equal(state, PackedInt64Array([6000, 0]), "net zero over one day")


func test_care_clamps_and_discards_only_the_outward_remainder() -> void:
	"""At 10000 a served tick discards its positive remainder; at 0 an idle one its negative."""
	assert_equal(_step(10000, 0, true, 1), PackedInt64Array([10000, 0]), "top bound")
	assert_equal(_step(9999, 700000, true, 1), PackedInt64Array([10000, 0]), "overflow lost")
	assert_equal(_step(0, 0, false, 1), PackedInt64Array([0, 0]), "bottom bound")
	assert_equal(_step(0, 500000, false, 1), PackedInt64Array([0, 250000]),
		"an inward remainder survives at the bound")


func test_a_bad_care_input_refuses_and_writes_nothing() -> void:
	"""Out-of-domain care or remainder, or a wrong-sized output, refuses without writing."""
	var out: PackedInt64Array = PackedInt64Array([42, 43])
	for bad: Array in [[-1, 0], [10001, 0], [5000, 750000], [5000, -750000]]:
		assert_false(Households.care_after_tick(bad[0], bad[1], true, out), "%s refuses" % [bad])
	assert_equal(out, PackedInt64Array([42, 43]), "the output is untouched")
	assert_false(Households.care_after_tick(5000, 0, true, PackedInt64Array([0, 0, 0])), "shape")


func test_warning_latches_follow_their_hysteresis() -> void:
	"""Critical <=1500 set, >2000 clear; low <=3500 set, >4000 clear; critical forces low."""
	var cases: Array = [[1500, 0, 3], [1501, 0, 1], [2000, 3, 3], [2001, 3, 1], [3500, 0, 1],
		[3501, 0, 0], [4000, 1, 1], [4001, 1, 0], [5000, 3, 0], [1800, 1, 1], [0, 0, 3]]
	for row: Array in cases:
		assert_equal(Households.warning_bits_after(row[0], row[1]), row[2],
			"care %d from bits %d" % [row[0], row[1]])


func test_eligibility_sets_at_6000_and_clears_at_9000() -> void:
	"""Set at <=6000, cleared at >=9000, retained between."""
	var cases: Array = [[6000, 0, 1], [6001, 0, 0], [7000, 1, 1], [8999, 1, 1], [9000, 1, 0],
		[7000, 0, 0], [0, 0, 1], [10000, 1, 0]]
	for row: Array in cases:
		assert_equal(Households.eligibility_after(row[0], row[1]), row[2],
			"care %d from %d" % [row[0], row[1]])


func _key(critical: bool, care: int, pid: int) -> int:
	"""The sort key, asserting it was accepted."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(Households.child_sort_key_into(critical, care, pid, out), "key accepted")
	return out.value


func test_the_child_sort_key_orders_critical_then_care_then_id() -> void:
	"""(ordinary << 45) | (care << 31) | id; every valid key is below 2^46."""
	assert_true(_key(true, 10000, I32_MAX) < _key(false, 0, 1),
		"any critical child precedes any ordinary one")
	assert_true(_key(false, 10, 99) < _key(false, 11, 1), "lower care first")
	assert_true(_key(false, 10, I32_MAX) < _key(false, 11, 1), "whatever the persistent id")
	assert_equal(_key(false, 1, 1), (1 << 45) | (1 << 31) | 1, "the literal layout")
	assert_true(_key(true, 10, 5) < _key(true, 10, 6), "persistent id breaks the tie")
	assert_equal(_key(true, 0, 1), 1, "the smallest key")
	assert_true(_key(false, 10000, I32_MAX) < (1 << 46), "below 2^46")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	for bad: Array in [[-1, 1], [10001, 1], [0, 0], [0, I32_MAX + 1]]:
		assert_true(Households.child_sort_key_into(false, 5, 5, out), "prior success")
		assert_false(Households.child_sort_key_into(false, bad[0], bad[1], out), "%s" % [bad])
		assert_equal(out.value, 0, "no sentinel key survives a refusal")
		assert_equal(out.error, Households.REFUSE_CARE_DOMAIN, "named")


# --- binding ------------------------------------------------------------------------------------

func test_binding_writes_each_stages_defaults() -> void:
	"""CHILD: care 6500, unwilling. ADULT and ELDER: willing by default, care canonical zero."""
	var child: Vector2i = _spawn(&"mouse", CHILD)
	var adult: Vector2i = _spawn(&"otter", ADULT)
	var elder: Vector2i = _spawn(&"badger", ELDER)
	assert_equal(_store.care_of(_row(child)), 6500, "child care starts at 6500")
	assert_false(_store.is_willing(_row(child)), "a child is never a provider")
	assert_false(_store.is_care_eligible(_row(child)), "6500 is above the 6000 eligibility line")
	assert_equal(_store.warning_bits_of(_row(child)), 0, "no warning")
	for ref: Vector2i in [adult, elder]:
		assert_true(_store.is_willing(_row(ref)), "willing defaults on")
		assert_equal(_store.care_of(_row(ref)), 0, "no care state")
	assert_equal(_store.household_row_of(_row(child)), Households.NULL_ROW, "no household implied")


func test_binding_refuses_a_stale_ref_or_an_already_bound_resident() -> void:
	"""Each refusal names its cause and changes nothing; a resident who died unbound can bind."""
	var ref: Vector2i = _spawn(&"mouse", ADULT)
	var before: PackedByteArray = _store.state_bytes()
	assert_false(_store.bind_resident_into(ref, _out), "double bind")
	assert_equal(_out.error, Households.REFUSE_ALREADY_BOUND, "already bound")
	assert_false(_store.bind_resident_into(Vector2i(ref.x, ref.y + 1), _out), "stale")
	assert_equal(_out.error, Households.REFUSE_RESIDENT_INVALID, "stale ref")
	assert_equal(_store.state_bytes(), before, "nothing changed")
	var dead: Vector2i = _spawn(&"mole", ADULT, false)
	_residents.needs().apply_health_event(_row(dead), -100)
	assert_true(_store.bind_resident_into(dead, _out), "every present row must be bindable")
	var image: Households.Columns = Households.Columns.new()
	assert_true(_store.copy_columns_into(image), "captured")
	assert_equal(Households.columns_refusal(image, _residents, 1), "",
		"so a world holding a corpse stays saveable")


# --- households ---------------------------------------------------------------------------------

func test_a_household_holds_at_most_eight_living_members() -> void:
	"""Zero and nine refuse; exactly eight, of mixed species and stages, is accepted."""
	var keys: Array[StringName] = [&"mouse", &"otter", &"badger", &"hare", &"mole", &"fox",
		&"shrew", &"hedgehog", &"kestrel"]
	var refs: Array = []
	for index: int in keys.size():
		refs.append(_spawn(keys[index], [ADULT, CHILD, ELDER][index % 3]))
	var before: PackedByteArray = _store.state_bytes()
	assert_false(_store.create_household_into(_refs([]), _out), "empty")
	assert_equal(_out.error, Households.REFUSE_MEMBER_COUNT, "zero members")
	assert_false(_store.create_household_into(_refs(refs), _out), "nine")
	assert_equal(_out.error, Households.REFUSE_MEMBER_COUNT, "nine members")
	assert_equal(_store.state_bytes(), before, "refusals changed nothing")
	assert_true(_store.create_household_into(_refs(refs.slice(0, 8)), _out), "eight accepted")
	assert_equal(_store.member_count_of(_out.value), 8, "eight members")


func test_members_are_stored_in_persistent_id_order_whatever_the_input_order() -> void:
	"""Canonical order is persistent ID ascending, and both sides of the membership agree."""
	var a: Vector2i = _spawn(&"mouse", ADULT)
	var b: Vector2i = _spawn(&"otter", CHILD)
	var c: Vector2i = _spawn(&"wildcat", ELDER)
	assert_true(_store.create_household_into(_refs([c, a, b]), _out), "created")
	var household: int = _out.value
	assert_equal(_store.member_ref_of(household, 0), a, "lowest id first")
	assert_equal(_store.member_ref_of(household, 1), b, "then the next")
	assert_equal(_store.member_ref_of(household, 2), c, "then the highest")
	assert_equal(_store.member_ref_of(household, 3), Households.NULL_REF, "null tail")
	for ref: Vector2i in [a, b, c]:
		assert_equal(_store.household_row_of(_row(ref)), household, "member points back")


func test_a_household_refuses_duplicates_housed_unbound_and_dead_members() -> void:
	"""Every member is preflighted before the first write."""
	var a: Vector2i = _spawn(&"mouse", ADULT)
	var b: Vector2i = _spawn(&"mouse", ADULT)
	var unbound: Vector2i = _spawn(&"mole", ADULT, false)
	var dead: Vector2i = _spawn(&"hare", ADULT)
	_residents.needs().apply_health_event(_row(dead), -100)
	var before: PackedByteArray = _store.state_bytes()
	var cases: Array = [[[a, a], Households.REFUSE_MEMBER_DUPLICATE],
		[[a, unbound], Households.REFUSE_NOT_BOUND],
		[[a, dead], Households.REFUSE_RESIDENT_NOT_LIVING]]
	for case: Array in cases:
		assert_false(_store.create_household_into(_refs(case[0]), _out), "refused")
		assert_equal(_out.error, case[1], "named cause")
	assert_equal(_store.state_bytes(), before, "nothing was written")
	assert_true(_store.create_household_into(_refs([a]), _out), "a alone")
	assert_false(_store.create_household_into(_refs([b, a]), _out), "a is housed")
	assert_equal(_out.error, Households.REFUSE_MEMBER_HOUSED, "one household per resident")
	assert_equal(_store.household_row_of(_row(b)), Households.NULL_ROW, "b was not half-housed")


func test_a_shared_surname_implies_no_membership() -> void:
	"""Two residents named alike stay independent: nothing infers kinship from a name."""
	var first: Vector2i = _spawn(&"mouse", ADULT)
	var second: Vector2i = _spawn(&"mouse", CHILD)
	assert_true(_residents.set_name(_row(first), &"Tansy Bramble").ok, "first name")
	assert_true(_residents.set_name(_row(second), &"Rue Bramble").ok, "second name")
	assert_true(_store.create_household_into(_refs([first]), _out), "first housed alone")
	assert_equal(_store.household_row_of(_row(second)), Households.NULL_ROW, "second unhoused")
	assert_equal(_store.member_count_of(_out.value), 1, "a household of one")
	assert_equal(_store.preferred_caregiver_ids_of(_row(second)), Vector2i.ZERO,
		"and no caregiver preference was inferred either")


func test_household_ids_are_monotonic_and_a_reused_row_is_a_new_identity() -> void:
	"""Retiring keeps the generation; the lowest free row is reused with generation + 1."""
	var a: Vector2i = _spawn(&"mouse", ADULT)
	var b: Vector2i = _spawn(&"otter", ADULT)
	assert_true(_store.create_household_into(_refs([a]), _out), "first")
	assert_equal(_store.household_ref(0), Vector2i(0, 1), "row 0 generation 1")
	assert_equal(_store.household_id_of(0), 1, "id 1")
	assert_true(_store.detach_resident_into(a, _out), "the only member leaves")
	assert_equal(_store.household_ref(0), Vector2i(Households.NULL_ROW, 0), "row 0 retired")
	assert_true(_store.create_household_into(_refs([b]), _out), "second")
	assert_equal(_out.value, 0, "the lowest free row is reused")
	assert_equal(_store.household_ref(0), Vector2i(0, 2), "with a new generation")
	assert_equal(_store.household_id_of(0), 2, "and a new id; 1 is never reissued")
	assert_equal(_store.next_household_id(), 3, "the cursor only advances")


func test_detaching_one_member_keeps_the_survivors_and_their_links() -> void:
	"""A departure removes only that member; the household and other links survive."""
	var a: Vector2i = _spawn(&"mouse", ADULT)
	var b: Vector2i = _spawn(&"otter", ELDER)
	var child: Vector2i = _spawn(&"hare", CHILD)
	assert_true(_store.create_household_into(_refs([a, b, child]), _out), "household")
	var household: int = _out.value
	assert_true(_store.set_preferred_caregivers_into(child, _refs([a, b]), _out), "prefs")
	assert_true(_store.detach_resident_into(a, _out), "a departs")
	assert_equal(_store.member_count_of(household), 2, "two survivors")
	assert_equal(_store.member_ref_of(household, 0), b, "compacted")
	assert_equal(_store.member_ref_of(household, 1), child, "in order")
	assert_equal(_store.household_id_of(household), 1, "same household identity")
	assert_equal(_store.preferred_caregiver_ids_of(_row(child)), Vector2i(_pid(b), 0),
		"the surviving preference moved to the front")
	assert_equal(_store.household_row_of(_row(a)), Households.NULL_ROW, "a is unhoused")


# --- preferences and willingness ----------------------------------------------------------------

func test_preferences_are_ascending_bounded_and_adult_or_elder_only() -> void:
	"""Stored ascending whatever the input order; three, duplicates and child carers refuse."""
	var child: Vector2i = _spawn(&"mouse", CHILD)
	var a: Vector2i = _spawn(&"otter", ADULT)
	var b: Vector2i = _spawn(&"badger", ELDER)
	var c: Vector2i = _spawn(&"hare", ADULT)
	var other_child: Vector2i = _spawn(&"mole", CHILD)
	assert_true(_store.set_preferred_caregivers_into(child, _refs([b, a]), _out), "two")
	assert_equal(_store.preferred_caregiver_ids_of(_row(child)), Vector2i(_pid(a), _pid(b)),
		"ascending")
	var before: PackedByteArray = _store.state_bytes()
	var cases: Array = [[child, [a, b, c], Households.REFUSE_PREFERENCE_COUNT],
		[child, [a, a], Households.REFUSE_CAREGIVER_DUPLICATE],
		[child, [other_child], Households.REFUSE_TARGET_NOT_PROVIDER_STAGE],
		[a, [b], Households.REFUSE_TARGET_NOT_CHILD]]
	for case: Array in cases:
		assert_false(_store.set_preferred_caregivers_into(case[0], _refs(case[1]), _out), "refused")
		assert_equal(_out.error, case[2], "named cause")
	assert_equal(_store.state_bytes(), before, "refusals changed nothing")
	assert_true(_store.set_preferred_caregivers_into(child, _refs([]), _out), "empty is legal")
	assert_equal(_store.preferred_caregiver_ids_of(_row(child)), Vector2i.ZERO, "cleared")


func test_willingness_is_an_adult_or_elder_switch() -> void:
	"""A child target refuses; an adult toggles."""
	var child: Vector2i = _spawn(&"mouse", CHILD)
	var adult: Vector2i = _spawn(&"otter", ADULT)
	assert_false(_store.set_willing_into(child, true, _out), "child refuses")
	assert_equal(_out.error, Households.REFUSE_TARGET_NOT_PROVIDER_STAGE, "named")
	assert_true(_store.set_willing_into(adult, false, _out), "off")
	assert_false(_store.is_willing(_row(adult)), "now unwilling")
	assert_true(_store.set_willing_into(adult, true, _out), "on")
	assert_true(_store.is_willing(_row(adult)), "willing again")


# --- service and care integration ---------------------------------------------------------------

func _eligible_child_and_provider() -> Array[Vector2i]:
	"""A child decayed to exactly 6000 (eligible) and a willing adult."""
	var child: Vector2i = _spawn(&"mouse", CHILD)
	var adult: Vector2i = _spawn(&"otter", ADULT)
	_advance(1500, _paired([]))
	return [child, adult]


func test_two_idle_hours_bring_a_new_child_to_eligibility() -> void:
	"""6500 - 2 x 250 = 6000, the eligibility line; the latch sets."""
	var pair: Array[Vector2i] = _eligible_child_and_provider()
	assert_equal(_store.care_of(_row(pair[0])), 6000, "6000")
	assert_true(_store.is_care_eligible(_row(pair[0])), "eligible")


func test_a_turn_ends_at_750_paired_ticks_and_completion_ends_at_9000() -> void:
	"""The package walk through the live store, with the provider's daily share counted."""
	var pair: Array[Vector2i] = _eligible_child_and_provider()
	var child: int = _row(pair[0])
	var adult: int = _row(pair[1])
	assert_true(_store.assign_provider_into(pair[0], pair[1], _out), "assigned")
	_advance(749, _paired([child]))
	assert_equal(_store.service_paired_ticks_of(child), 749, "a stable turn holds 0..749")
	_advance(1, _paired([child]))
	assert_equal(_store.care_of(child), 8750, "a full turn")
	assert_equal(_store.provider_of(child), Households.NULL_REF, "the turn limit ended it")
	assert_equal(_store.service_paired_ticks_of(child), 0, "session cleared")
	assert_true(_store.is_care_eligible(child), "still eligible below 9000")
	assert_equal(_store.provider_served_ticks_today_of(adult), 750, "daily share kept")
	assert_true(_store.assign_provider_into(pair[0], pair[1], _out), "reassigned")
	_advance(30, _paired([]))
	assert_equal(_store.care_of(child), 8740, "travel earns nothing")
	_advance(71, _paired([child]))
	assert_equal(_store.care_of(child), 9000, "completion")
	assert_false(_store.is_care_eligible(child), "eligibility cleared")
	assert_equal(_store.provider_of(child), Households.NULL_REF, "completion ended the service")
	assert_equal(_store.provider_served_ticks_today_of(adult), 821, "750 + 71 paired ticks")


func test_service_assignment_refuses_each_structural_violation() -> void:
	"""Not eligible, already served, unwilling, busy and wrong-stage targets all refuse."""
	var pair: Array[Vector2i] = _eligible_child_and_provider()
	var fresh: Vector2i = _spawn(&"hare", CHILD)
	var second: Vector2i = _spawn(&"mole", CHILD)
	_advance(1, _paired([]))
	var unwilling: Vector2i = _spawn(&"badger", ELDER)
	assert_true(_store.set_willing_into(unwilling, false, _out), "unwilling")
	assert_false(_store.assign_provider_into(fresh, pair[1], _out), "6000 not reached yet")
	assert_equal(_out.error, Households.REFUSE_CHILD_NOT_ELIGIBLE, "not eligible")
	assert_false(_store.assign_provider_into(pair[0], unwilling, _out), "unwilling")
	assert_equal(_out.error, Households.REFUSE_PROVIDER_UNWILLING, "named")
	assert_false(_store.assign_provider_into(pair[1], pair[1], _out), "adult as child")
	assert_equal(_out.error, Households.REFUSE_TARGET_NOT_CHILD, "named")
	assert_true(_store.assign_provider_into(pair[0], pair[1], _out), "assigned")
	assert_false(_store.assign_provider_into(pair[0], pair[1], _out), "child served")
	assert_equal(_out.error, Households.REFUSE_CHILD_SERVED, "named")
	_advance(1500, _paired([]))
	assert_false(_store.assign_provider_into(second, pair[1], _out), "provider busy")
	assert_equal(_out.error, Households.REFUSE_PROVIDER_BUSY, "one child per provider")


func test_a_paired_flag_without_service_refuses_the_whole_tick() -> void:
	"""Every flag is validated before any row moves."""
	var pair: Array[Vector2i] = _eligible_child_and_provider()
	var before: PackedByteArray = _store.state_bytes()
	assert_false(_store.advance_care_into(_paired([_row(pair[0])]), _out), "no provider")
	assert_equal(_out.error, Households.REFUSE_PAIRED_WITHOUT_SERVICE, "named")
	var short: PackedByteArray = PackedByteArray()
	short.resize(10)
	assert_false(_store.advance_care_into(short, _out), "shape")
	assert_equal(_out.error, Households.REFUSE_PAIRED_SHAPE, "named")
	var two: PackedByteArray = _paired([])
	two[_row(pair[0])] = 2
	assert_false(_store.advance_care_into(two, _out), "a non-boolean flag")
	assert_equal(_store.state_bytes(), before, "no row moved")


func test_zero_care_raises_warnings_but_never_touches_health() -> void:
	"""A child left 26 hours reaches 0 care with both latches set and health still 100."""
	var child: Vector2i = _spawn(&"mouse", CHILD)
	var none: PackedByteArray = _paired([])
	for tick: int in 750 * 26:
		_store.advance_care_into(none, _out)
		_residents.tick_needs_all()
	var row: int = _row(child)
	assert_equal(_store.care_of(row), 0, "care bottoms out")
	assert_equal(_store.warning_bits_of(row), 3, "low and critical")
	assert_equal(_residents.needs().health_of(row).value, 100, "no neglect damage")


func test_the_midnight_reset_zeroes_daily_shares_and_keeps_the_turn() -> void:
	"""begin_day zeroes provider totals and preserves the active assignment and its session."""
	var pair: Array[Vector2i] = _eligible_child_and_provider()
	assert_true(_store.assign_provider_into(pair[0], pair[1], _out), "assigned")
	_advance(100, _paired([_row(pair[0])]))
	assert_false(_store.begin_day_into(1, _out), "the same day does not advance")
	assert_equal(_out.error, Households.REFUSE_DAY_NOT_ADVANCING, "named")
	assert_true(_store.begin_day_into(2, _out), "day 2")
	assert_equal(_store.served_day(), 2, "served day moved")
	assert_equal(_store.provider_served_ticks_today_of(_row(pair[1])), 0, "share reset")
	assert_equal(_store.service_paired_ticks_of(_row(pair[0])), 100, "session kept")
	assert_equal(_store.provider_of(_row(pair[0])), pair[1], "assignment kept")


func test_a_dead_providers_detach_ends_its_service_and_a_dead_child_stops_integrating() -> void:
	"""Death cleanup clears only the invalid links; a dead child's care is frozen."""
	var pair: Array[Vector2i] = _eligible_child_and_provider()
	assert_true(_store.assign_provider_into(pair[0], pair[1], _out), "assigned")
	_residents.needs().apply_health_event(_row(pair[1]), -100)
	assert_true(_store.detach_resident_into(pair[1], _out), "provider detached")
	assert_equal(_store.provider_of(_row(pair[0])), Households.NULL_REF, "service ended")
	assert_true(_store.is_bound(_row(pair[1])), "the corpse row stays bound")
	_residents.needs().apply_health_event(_row(pair[0]), -100)
	var frozen: int = _store.care_of(_row(pair[0]))
	_advance(750, _paired([]))
	assert_equal(_store.care_of(_row(pair[0])), frozen, "a dead child's care does not move")
	assert_equal(_out.value, 0, "no living child was integrated")


func test_a_reused_slot_inherits_nothing() -> void:
	"""Unbind then despawn; the next resident in that slot starts unbound with fresh defaults."""
	var adult: Vector2i = _spawn(&"mouse", ADULT)
	assert_true(_store.create_household_into(_refs([adult]), _out), "housed")
	var row: int = _row(adult)
	assert_true(_store.unbind_resident_into(adult, _out), "unbound")
	assert_true(_residents.despawn(adult).ok, "despawned")
	var child: Vector2i = _spawn(&"mouse", CHILD, false)
	assert_equal(_row(child), row, "the slot was reused")
	assert_false(_store.is_bound(row), "the new tenant is not bound")
	assert_false(_store.bind_resident_into(adult, _out), "the old ref is stale")
	assert_true(_store.bind_resident_into(child, _out), "bind the new tenant")
	assert_equal(_store.household_row_of(row), Households.NULL_ROW, "no inherited household")
	assert_equal(_store.care_of(row), 6500, "fresh child care")


# --- columns: capture, refusal of other schema versions, hostile images ------------------------

func _rich_store() -> Dictionary:
	"""A store holding a mixed household, preferences, a mid-turn service and latched warnings."""
	var adult: Vector2i = _spawn(&"otter", ADULT)
	var elder: Vector2i = _spawn(&"badger", ELDER)
	var child: Vector2i = _spawn(&"mouse", CHILD)
	var lonely: Vector2i = _spawn(&"hare", CHILD)
	var spare: Vector2i = _spawn(&"hedgehog", ELDER)
	assert_true(_store.create_household_into(_refs([child, adult, elder]), _out), "household")
	assert_true(_store.set_preferred_caregivers_into(child, _refs([elder]), _out), "pref")
	_advance(1500, _paired([]))
	assert_true(_store.assign_provider_into(child, adult, _out), "service")
	_advance(200, _paired([_row(child)]))
	return {"adult": adult, "elder": elder, "child": child, "lonely": lonely, "spare": spare}


func _held_clock() -> SimClockScript:
	"""A clock at completed tick 0 (day 1) holding its load barrier."""
	var clock: SimClockScript = SimClockScript.new()
	assert_true(clock.acquire_load_barrier().is_ok(), "barrier held")
	return clock


func test_a_captured_image_restores_byte_identically() -> void:
	"""copy -> restore into a fresh owner over the same Residents reproduces every byte."""
	_rich_store()
	var image: Households.Columns = Households.Columns.new()
	assert_true(_store.copy_columns_into(image), "captured")
	assert_equal(Households.columns_refusal(image, _residents, 1), "", "the live image is valid")
	var target: Households = Households.new(_residents)
	assert_true(target.restore_columns_into(image, _held_clock(), _out), _out.error)
	assert_equal(_out.value, 1, "one household restored")
	assert_equal(target.state_bytes(), _store.state_bytes(), "byte-identical")


func test_restore_needs_the_held_load_barrier() -> void:
	"""Without the barrier nothing is validated or written."""
	_rich_store()
	var image: Households.Columns = Households.Columns.new()
	_store.copy_columns_into(image)
	var target: Households = Households.new(_residents)
	var before: PackedByteArray = target.state_bytes()
	assert_false(target.restore_columns_into(image, SimClockScript.new(), _out), "no barrier")
	assert_equal(_out.error, Households.REFUSE_LOAD_BARRIER, "named")
	assert_equal(target.state_bytes(), before, "unchanged")


func test_an_older_or_newer_owner_schema_is_refused_not_migrated() -> void:
	"""A pre-family (0) or future (2) image refuses; nothing infers a default child."""
	_rich_store()
	var image: Households.Columns = Households.Columns.new()
	_store.copy_columns_into(image)
	var target: Households = Households.new(_residents)
	var before: PackedByteArray = target.state_bytes()
	for version: int in [0, 2]:
		image.schema_version = version
		assert_false(target.restore_columns_into(image, _held_clock(), _out), "v%d" % version)
		assert_equal(_out.error, Households.REFUSE_COLUMN_SCHEMA, "schema refusal")
	assert_equal(target.state_bytes(), before, "nothing installed")


func test_a_misshaped_capture_buffer_is_refused_and_left_alone() -> void:
	"""copy_columns_into never resizes a caller's buffer."""
	var image: Households.Columns = Households.Columns.new()
	image.d_care.resize(511)
	image.d_care.fill(77)
	assert_false(_store.copy_columns_into(image), "shape refuses")
	assert_equal(image.d_care[0], 77, "untouched")
	assert_equal(image.d_care.size(), 511, "not resized")


func _expect_refused(image: Households.Columns, code: String, label: String) -> void:
	"""Assert the image refuses with `code`, and that a restore of it installs nothing."""
	assert_equal(Households.columns_refusal(image, _residents, 1), code, label)
	var target: Households = Households.new(_residents)
	var before: PackedByteArray = target.state_bytes()
	assert_false(target.restore_columns_into(image, _held_clock(), _out), label + " restores")
	assert_equal(target.state_bytes(), before, label + " installs nothing")


func _fresh_image() -> Households.Columns:
	"""A valid capture of the rich store."""
	var image: Households.Columns = Households.Columns.new()
	assert_true(_store.copy_columns_into(image), "capture")
	return image


func test_hostile_household_images_refuse() -> void:
	"""Cursor, IDs, member order/tail, reciprocity and the free-row rule."""
	var refs: Dictionary = _rich_store()
	var child: int = _row(refs["child"])
	var lonely: int = _row(refs["lonely"])
	var image: Households.Columns = _fresh_image()
	image.next_household_id = 0
	_expect_refused(image, Households.REFUSE_COLUMN_NEXT_ID, "cursor 0")
	image = _fresh_image()
	image.h_persistent_id[0] = 2
	_expect_refused(image, Households.REFUSE_COLUMN_HOUSEHOLD_ID, "id not below the cursor")
	image = _fresh_image()
	image.h_member_slot[3] = 0
	_expect_refused(image, Households.REFUSE_COLUMN_UNUSED, "dirty member tail")
	image = _fresh_image()
	var first: int = image.h_member_slot[0]
	image.h_member_slot[0] = image.h_member_slot[1]
	image.h_member_slot[1] = first
	var gen: int = image.h_member_generation[0]
	image.h_member_generation[0] = image.h_member_generation[1]
	image.h_member_generation[1] = gen
	_expect_refused(image, Households.REFUSE_COLUMN_MEMBER, "members out of id order")
	image = _fresh_image()
	image.d_household_row[child] = Households.NULL_ROW
	image.d_household_generation[child] = 0
	_expect_refused(image, Households.REFUSE_COLUMN_RECIPROCITY, "member does not point back")
	image = _fresh_image()
	image.d_household_row[lonely] = 0
	image.d_household_generation[lonely] = 1
	_expect_refused(image, Households.REFUSE_COLUMN_RECIPROCITY, "row claims an unlisted home")
	image = _fresh_image()
	image.h_present[5] = 0
	image.h_persistent_id[5] = 9
	_expect_refused(image, Households.REFUSE_COLUMN_UNUSED, "free row with an id")


func test_hostile_dependent_images_refuse() -> void:
	"""Binding, stage restrictions, care, latches, preferences, providers and served day."""
	var refs: Dictionary = _rich_store()
	var child: int = _row(refs["child"])
	var adult: int = _row(refs["adult"])
	var lonely: int = _row(refs["lonely"])
	var cases: Array = [
		["d_resident_generation", child, 99, Households.REFUSE_COLUMN_BINDING, "wrong generation"],
		["d_present", 300, 1, Households.REFUSE_COLUMN_BINDING, "bound row with no resident"],
		["d_willing", child, 1, Households.REFUSE_COLUMN_STAGE, "a willing child"],
		["d_care", adult, 5, Households.REFUSE_COLUMN_STAGE, "an adult with care"],
		["d_provider_served_ticks_today", adult, 18001, Households.REFUSE_COLUMN_PROVIDER,
			"a share beyond one day"],
		["d_warning_bits", lonely, 2, Households.REFUSE_COLUMN_LATCH, "critical without low"],
		["d_care_eligible", lonely, 0, Households.REFUSE_COLUMN_LATCH, "6000 not eligible"],
		["d_care", lonely, 10001, Households.REFUSE_COLUMN_CARE, "care above 10000"],
		["d_service_paired_ticks", child, 750, Households.REFUSE_COLUMN_PROVIDER,
			"a saved turn at the limit"],
		["d_preferred_1", child, 1, Households.REFUSE_COLUMN_PREFERENCE, "descending pair"],
		["d_preferred_0", lonely, 999, Households.REFUSE_COLUMN_PREFERENCE, "unknown id"],
		["d_care_remainder", lonely, 750000, Households.REFUSE_COLUMN_CARE, "remainder bound"],
	]
	for case: Array in cases:
		var image: Households.Columns = _fresh_image()
		var column: Variant = image.get(case[0])
		column[case[1]] = case[2]
		image.set(case[0], column)
		_expect_refused(image, case[3], case[4])


func test_cross_row_and_scalar_images_refuse() -> void:
	"""A shared provider, a child preference naming a child, and a stale served day."""
	var refs: Dictionary = _rich_store()
	var lonely: int = _row(refs["lonely"])
	var child: int = _row(refs["child"])
	var image: Households.Columns = _fresh_image()
	image.d_provider_slot[lonely] = image.d_provider_slot[child]
	image.d_provider_generation[lonely] = image.d_provider_generation[child]
	image.d_care_eligible[lonely] = 1
	_expect_refused(image, Households.REFUSE_COLUMN_PROVIDER, "one provider, two children")
	image = _fresh_image()
	image.d_preferred_0[lonely] = _pid(refs["child"])
	_expect_refused(image, Households.REFUSE_COLUMN_PREFERENCE, "a child named as carer")
	image = _fresh_image()
	image.served_day = 2
	_expect_refused(image, Households.REFUSE_COLUMN_SERVED_DAY, "served day is not today")


func test_exhausted_generations_and_ids_refuse_creation() -> void:
	"""Every row at I32_MAX generation is CAPACITY; a spent cursor is ID_EXHAUSTED; no reset."""
	var a: Vector2i = _spawn(&"mouse", ADULT)
	var image: Households.Columns = _fresh_image()
	image.h_generation.fill(I32_MAX)
	assert_true(_store.restore_columns_into(image, _held_clock(), _out), _out.error)
	assert_false(_store.create_household_into(_refs([a]), _out), "no row can advance")
	assert_equal(_out.error, Households.REFUSE_CAPACITY, "capacity")
	image = _fresh_image()
	image.h_generation.fill(0)
	image.next_household_id = Households.NEXT_HOUSEHOLD_ID_TERMINAL
	assert_true(_store.restore_columns_into(image, _held_clock(), _out), _out.error)
	assert_false(_store.create_household_into(_refs([a]), _out), "every id issued")
	assert_equal(_out.error, Households.REFUSE_ID_EXHAUSTED, "exhausted")
	assert_equal(_store.next_household_id(), Households.NEXT_HOUSEHOLD_ID_TERMINAL, "no reset")


func test_images_that_only_a_strict_or_bound_rule_catches_refuse() -> void:
	"""A repeated member, an equal preference pair and an outward remainder at the top bound."""
	var refs: Dictionary = _rich_store()
	var lonely: int = _row(refs["lonely"])
	var image: Households.Columns = _fresh_image()
	image.h_member_slot[1] = image.h_member_slot[0]
	image.h_member_generation[1] = image.h_member_generation[0]
	_expect_refused(image, Households.REFUSE_COLUMN_MEMBER, "one resident listed twice")
	image = _fresh_image()
	image.d_preferred_1[_row(refs["child"])] = image.d_preferred_0[_row(refs["child"])]
	_expect_refused(image, Households.REFUSE_COLUMN_PREFERENCE, "the same caregiver twice")
	image = _fresh_image()
	image.d_care[lonely] = 10000
	image.d_care_remainder[lonely] = 1
	image.d_care_eligible[lonely] = 0
	image.d_warning_bits[lonely] = 0
	_expect_refused(image, Households.REFUSE_COLUMN_CARE, "outward remainder kept at 10000")
	image.d_care_remainder[lonely] = -1
	assert_equal(Households.columns_refusal(image, _residents, 1), "",
		"an inward remainder at 10000 is legal")


# --- review follow-up: one hostile image per validator rule -------------------------------------

func _set_child_care(image: Households.Columns, row: int, care: int, bits: int,
		eligible: int) -> void:
	"""Write one child row's care, zero remainder, warning bits and eligibility."""
	image.d_care[row] = care
	image.d_care_remainder[row] = 0
	image.d_warning_bits[row] = bits
	image.d_care_eligible[row] = eligible


func test_every_household_rule_refuses_its_own_hostile_image() -> void:
	"""Each image breaks exactly one rule, so deleting that rule changes the refusal."""
	var refs: Dictionary = _rich_store()
	var lonely: int = _row(refs["lonely"])
	var image: Households.Columns = _fresh_image()
	image.h_present[1] = 1
	image.h_generation[1] = 1
	image.h_persistent_id[1] = 1
	image.h_member_count[1] = 1
	image.h_member_slot[8] = refs["lonely"].x
	image.h_member_generation[8] = refs["lonely"].y
	image.d_household_row[lonely] = 1
	image.d_household_generation[lonely] = 1
	_expect_refused(image, Households.REFUSE_COLUMN_HOUSEHOLD_ID, "two households share id 1")
	image = _fresh_image()
	image.h_generation[0] = 0
	_expect_refused(image, Households.REFUSE_COLUMN_HOUSEHOLD_ROW, "a present row at generation 0")
	image = _fresh_image()
	image.h_member_count[0] = 0
	_expect_refused(image, Households.REFUSE_COLUMN_MEMBER, "a present household of nobody")
	image = _fresh_image()
	image.h_member_slot[5 * 8] = 0
	_expect_refused(image, Households.REFUSE_COLUMN_UNUSED, "a free row with a member tail")
	image = _fresh_image()
	image.next_household_id = Households.NEXT_HOUSEHOLD_ID_TERMINAL + 1
	_expect_refused(image, Households.REFUSE_COLUMN_NEXT_ID, "cursor past the terminal value")
	image = _fresh_image()
	image.d_household_row[lonely] = 7
	image.d_household_generation[lonely] = 1
	_expect_refused(image, Households.REFUSE_COLUMN_RECIPROCITY, "a home that is not present")
	image = _fresh_image()
	image.d_care[300] = 5
	_expect_refused(image, Households.REFUSE_COLUMN_UNUSED, "an unbound row holding care")
	image = _fresh_image()
	image.d_household_generation[_row(refs["child"])] = 5
	_expect_refused(image, Households.REFUSE_COLUMN_RECIPROCITY, "a stale household generation")
	image = _fresh_image()
	image.d_preferred_0[lonely] = 0
	image.d_preferred_1[lonely] = _pid(refs["spare"])
	_expect_refused(image, Households.REFUSE_COLUMN_PREFERENCE, "a second preference with no first")


func test_every_latch_and_care_rule_refuses_its_own_hostile_image() -> void:
	"""Care values chosen inside one band, so only the rule under test can catch each image."""
	var refs: Dictionary = _rich_store()
	var lonely: int = _row(refs["lonely"])
	var cases: Array = [[3000, 3, 1, Households.REFUSE_COLUMN_LATCH, "critical kept above 2000"],
		[1000, 1, 1, Households.REFUSE_COLUMN_LATCH, "critical missing at 1000"],
		[5000, 1, 1, Households.REFUSE_COLUMN_LATCH, "low kept above 4000"],
		[3000, 0, 1, Households.REFUSE_COLUMN_LATCH, "low missing at 3000"],
		[9500, 0, 1, Households.REFUSE_COLUMN_LATCH, "eligible kept at 9500"],
		[5000, 0, 2, Households.REFUSE_COLUMN_LATCH, "eligibility byte 2"]]
	for case: Array in cases:
		var image: Households.Columns = _fresh_image()
		_set_child_care(image, lonely, case[0], case[1], case[2])
		_expect_refused(image, case[3], case[4])
	var image: Households.Columns = _fresh_image()
	_set_child_care(image, lonely, 0, 3, 1)
	image.d_care_remainder[lonely] = -1
	_expect_refused(image, Households.REFUSE_COLUMN_CARE, "outward remainder kept at 0")
	image.d_care_remainder[lonely] = 1
	assert_equal(Households.columns_refusal(image, _residents, 1), "", "inward at 0 is legal")


func test_every_stage_rule_refuses_its_own_hostile_image() -> void:
	"""Each ADULT-only and CHILD-only field, one image each."""
	var refs: Dictionary = _rich_store()
	var adult: int = _row(refs["adult"])
	var child: int = _row(refs["child"])
	var lonely: int = _row(refs["lonely"])
	var cases: Array = [["d_care_remainder", adult, 5, Households.REFUSE_COLUMN_STAGE],
		["d_care_eligible", adult, 1, Households.REFUSE_COLUMN_STAGE],
		["d_warning_bits", adult, 1, Households.REFUSE_COLUMN_STAGE],
		["d_preferred_0", adult, 1, Households.REFUSE_COLUMN_STAGE],
		["d_preferred_1", adult, 1, Households.REFUSE_COLUMN_STAGE],
		["d_provider_slot", adult, 0, Households.REFUSE_COLUMN_STAGE],
		["d_provider_generation", adult, 1, Households.REFUSE_COLUMN_STAGE],
		["d_service_paired_ticks", adult, 1, Households.REFUSE_COLUMN_STAGE],
		["d_provider_served_ticks_today", adult, -1, Households.REFUSE_COLUMN_PROVIDER],
		["d_provider_served_ticks_today", child, 3, Households.REFUSE_COLUMN_STAGE],
		["d_service_paired_ticks", lonely, 5, Households.REFUSE_COLUMN_PROVIDER],
		["d_care_eligible", child, 0, Households.REFUSE_COLUMN_PROVIDER]]
	for case: Array in cases:
		var image: Households.Columns = _fresh_image()
		var column: Variant = image.get(case[0])
		column[case[1]] = case[2]
		image.set(case[0], column)
		_expect_refused(image, case[3], "%s on row %d" % [case[0], case[1]])


func test_provider_and_preference_references_refuse_dead_and_wrong_stage_targets() -> void:
	"""A child provider, a dead provider, a dead named carer and a dead child with preferences."""
	var refs: Dictionary = _rich_store()
	var child: int = _row(refs["child"])
	var lonely: int = _row(refs["lonely"])
	var image: Households.Columns = _fresh_image()
	image.d_provider_slot[child] = refs["lonely"].x
	image.d_provider_generation[child] = refs["lonely"].y
	_expect_refused(image, Households.REFUSE_COLUMN_PROVIDER, "a child as provider")
	var spare_named: Households.Columns = _fresh_image()
	spare_named.d_preferred_0[lonely] = _pid(refs["spare"])
	var spare_serves: Households.Columns = _fresh_image()
	spare_serves.d_provider_slot[child] = refs["spare"].x
	spare_serves.d_provider_generation[child] = refs["spare"].y
	assert_equal(Households.columns_refusal(spare_named, _residents, 1), "", "spare named: legal")
	assert_equal(Households.columns_refusal(spare_serves, _residents, 1), "", "spare serves: legal")
	var lonely_prefers: Households.Columns = _fresh_image()
	lonely_prefers.d_preferred_0[lonely] = _pid(refs["adult"])
	_residents.needs().apply_health_event(_row(refs["spare"]), -100)
	_expect_refused(spare_named, Households.REFUSE_COLUMN_PREFERENCE, "a dead named carer")
	_expect_refused(spare_serves, Households.REFUSE_COLUMN_PROVIDER, "a dead provider")
	_residents.needs().apply_health_event(lonely, -100)
	_expect_refused(lonely_prefers, Households.REFUSE_COLUMN_PREFERENCE,
		"a dead child keeping preferences")


func test_a_dead_household_member_refuses_the_image() -> void:
	"""Members must be living; a corpse left listed is caught at the household, not later."""
	var refs: Dictionary = _rich_store()
	var image: Households.Columns = _fresh_image()
	_residents.needs().apply_health_event(_row(refs["elder"]), -100)
	_expect_refused(image, Households.REFUSE_COLUMN_MEMBER, "a dead member still listed")


func test_a_fresh_store_captures_a_valid_day_one_image() -> void:
	"""A new store's served day is the clock's first day, so its own capture validates."""
	_spawn(&"mouse", ADULT)
	var image: Households.Columns = _fresh_image()
	assert_equal(image.served_day, 1, "day 1")
	assert_equal(Households.columns_refusal(image, _residents, 1), "", "valid without begin_day")


# --- review follow-up: runtime refusals and stale bindings --------------------------------------

func test_a_full_daily_share_refuses_assignment_and_the_paired_tick() -> void:
	"""A provider who has served all 18000 ticks today is refused, and so is a tick pairing them."""
	var refs: Dictionary = _rich_store()
	var image: Households.Columns = _fresh_image()
	image.d_provider_served_ticks_today[_row(refs["adult"])] = 18000
	image.d_provider_served_ticks_today[_row(refs["spare"])] = 18000
	assert_true(_store.restore_columns_into(image, _held_clock(), _out), _out.error)
	var before: PackedByteArray = _store.state_bytes()
	assert_false(_store.advance_care_into(_paired([_row(refs["child"])]), _out), "day full")
	assert_equal(_out.error, Households.REFUSE_PROVIDER_DAY_FULL, "named")
	assert_equal(_store.state_bytes(), before, "no row moved")
	_advance(1500, _paired([]))
	assert_false(_store.assign_provider_into(refs["lonely"], refs["spare"], _out), "assign")
	assert_equal(_out.error, Households.REFUSE_PROVIDER_DAY_FULL, "a full provider is not staged")


func test_a_dead_provider_or_a_dead_child_cannot_be_paired() -> void:
	"""Pairing either corpse refuses the whole tick."""
	var refs: Dictionary = _rich_store()
	var paired: PackedByteArray = _paired([_row(refs["child"])])
	_residents.needs().apply_health_event(_row(refs["adult"]), -100)
	assert_false(_store.advance_care_into(paired, _out), "dead provider")
	assert_equal(_out.error, Households.REFUSE_PAIRED_WITHOUT_SERVICE, "named")
	var others: Dictionary = {}
	before_each()
	others = _rich_store()
	_residents.needs().apply_health_event(_row(others["child"]), -100)
	assert_false(_store.advance_care_into(_paired([_row(others["child"])]), _out), "dead child")
	assert_equal(_out.error, Households.REFUSE_PAIRED_WITHOUT_SERVICE, "named")


func test_detaching_a_served_child_ends_its_own_service() -> void:
	"""A child's departure or death clears the service it receives, freeing the provider."""
	var refs: Dictionary = _rich_store()
	assert_true(_store.detach_resident_into(refs["child"], _out), "child detached")
	assert_equal(_store.provider_of(_row(refs["child"])), Households.NULL_REF, "service ended")
	assert_equal(_store.household_row_of(_row(refs["child"])), Households.NULL_ROW, "unhoused")
	assert_equal(_store.preferred_caregiver_ids_of(_row(refs["child"])), Vector2i.ZERO,
		"and its own preferences cleared")


func test_end_service_keeps_received_care_and_the_daily_share() -> void:
	"""An interruption ends the turn only; care, remainder and the provider's share stay."""
	var refs: Dictionary = _rich_store()
	var child: int = _row(refs["child"])
	var care: int = _store.care_of(child)
	var remainder: int = _store.care_remainder_of(child)
	assert_true(_store.end_service_into(refs["child"], _out), "ended")
	assert_equal(_store.provider_of(child), Households.NULL_REF, "no provider")
	assert_equal(_store.service_paired_ticks_of(child), 0, "session cleared")
	assert_equal(_store.care_of(child), care, "care kept")
	assert_equal(_store.care_remainder_of(child), remainder, "remainder kept")
	assert_equal(_store.provider_served_ticks_today_of(_row(refs["adult"])), 200, "share kept")
	assert_false(_store.end_service_into(refs["child"], _out), "nothing left to end")
	assert_equal(_out.error, Households.REFUSE_NO_SERVICE, "named")


func test_a_slot_reused_without_unbind_inherits_nothing_and_can_be_released() -> void:
	"""The review's reproduction: despawn while bound, then a new tenant in the same row."""
	var a: Vector2i = _spawn(&"mouse", ADULT)
	var b: Vector2i = _spawn(&"otter", ADULT)
	var child: Vector2i = _spawn(&"hare", CHILD)
	assert_true(_store.create_household_into(_refs([a, b]), _out), "household")
	assert_true(_store.set_preferred_caregivers_into(child, _refs([a, b]), _out), "prefs")
	_advance(1500, _paired([]))
	assert_true(_store.assign_provider_into(child, a, _out), "a serves the child")
	var row: int = _row(a)
	assert_true(_residents.despawn(a).ok, "despawned while still bound")
	var fresh: Vector2i = _spawn(&"mouse", CHILD, false)
	assert_equal(_row(fresh), row, "same typed row")
	assert_false(_store.is_bound(row), "the new tenant is not treated as bound")
	assert_equal(_store.household_row_of(row), Households.NULL_ROW, "and inherits no household")
	assert_false(_store.bind_resident_into(fresh, _out), "binding refuses")
	assert_equal(_out.error, Households.REFUSE_STALE_BINDING, "as stale")
	assert_false(_store.advance_care_into(_paired([]), _out), "the care tick refuses too")
	assert_false(_store.detach_resident_into(fresh, _out), "no mutator reads the stale row")
	assert_equal(_out.error, Households.REFUSE_STALE_BINDING, "detach names it")
	assert_false(_store.set_willing_into(fresh, true, _out), "nor does a setter")
	assert_equal(_out.error, Households.REFUSE_STALE_BINDING, "setter names it")
	assert_false(_store.release_stale_row_into(_row(b), _out), "a current binding is not stale")
	assert_equal(_out.error, Households.REFUSE_NOT_STALE, "named")
	assert_true(_store.release_stale_row_into(row, _out), "released")
	assert_equal(_store.member_count_of(0), 1, "b survives alone")
	assert_equal(_store.member_ref_of(0, 0), b, "b is the member")
	assert_equal(_store.provider_of(_row(child)), Households.NULL_REF,
		"the gone provider's service ended")
	assert_equal(_store.preferred_caregiver_ids_of(_row(child)), Vector2i(_pid(b), 0),
		"the gone carer's id was removed and b moved to the front")
	assert_true(_store.bind_resident_into(fresh, _out), "the new tenant binds")
	assert_equal(_store.care_of(row), 6500, "with fresh child defaults")
	assert_equal(Households.columns_refusal(_fresh_image(), _residents, 1), "", "saveable again")

