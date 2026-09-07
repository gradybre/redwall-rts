extends "res://test/framework/test_case.gd"
## Coverage for the Priorities component: the GDD §5.1 initial values, REQ-SET-026's 0-4 scale,
## the reserved-index refusal, the owner-major 12-wide stride, and REQ-SET-028/029's fallback
## priority-and-flag test.

const IntMath := preload("res://scripts/core/int_math.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")

## GDD §5.1: "Initial priorities are HAUL=2, RESERVED_3=0 and all other active jobs=3".
## Written out per kind, in JobKind index order, so a single changed value fails a named
## assertion instead of hiding inside a loop over a formula.
const EXPECTED_INITIAL_PRIORITY: Array[int] = [
	2,  # HAUL=0
	3,  # BUILD=1
	3,  # FISH=2
	0,  # RESERVED_3=3
	3,  # FORAGE=4
	3,  # FARM=5
	3,  # COOK=6
	3,  # PRESERVE=7
	3,  # CRAFT=8
	3,  # TEND=9
	3,  # KEEP=10
	3,  # HEAL=11
]

var _priorities: PrioritiesScript = null


func before_each() -> void:
	"""Fresh, empty priorities store for every test."""
	_priorities = PrioritiesScript.new()


func after_each() -> void:
	"""Drop the store so no test inherits another's rows."""
	_priorities = null


# --- GDD §5.1 initial values -------------------------------------------------------------------

func test_spawn_writes_the_gdd_5_1_initial_priority_for_every_job_kind() -> void:
	"""HAUL=2, RESERVED_3=0, all ten other active kinds=3, asserted one kind at a time."""
	assert_true(_priorities.spawn(0).ok, "spawn succeeds")
	for kind: int in PrioritiesScript.JOB_KIND_COUNT:
		var read: IntMath.IntResult = _priorities.priority_of(0, kind)
		assert_true(read.ok, "priority_of(%d) reads (error: %s)" % [kind, read.error])
		assert_equal(read.value, EXPECTED_INITIAL_PRIORITY[kind],
			"§5.1 initial priority for JobKind %d" % kind)


func test_initial_haul_priority_is_high_not_normal() -> void:
	"""§5.1 singles HAUL out at 2; if it silently became 3 the whole cohort would haul last."""
	assert_true(_priorities.spawn(3).ok, "spawn succeeds")
	var haul: IntMath.IntResult = _priorities.priority_of(3, PrioritiesScript.JOB_KIND_HAUL)
	assert_equal(haul.value, 2, "HAUL starts at 2 (high)")
	assert_equal(PrioritiesScript.INITIAL_HAUL_PRIORITY, 2, "the published constant is 2")
	assert_equal(PrioritiesScript.INITIAL_ACTIVE_PRIORITY, 3, "every other active kind starts at 3")


func test_initial_reserved_index_priority_is_zero() -> void:
	"""setting_rules_amendment.md: RESERVED_3's priority initialises to 0, assignment prohibited."""
	assert_true(_priorities.spawn(1).ok, "spawn succeeds")
	var reserved: IntMath.IntResult = _priorities.priority_of(1, PrioritiesScript.JOB_KIND_RESERVED_INDEX)
	assert_true(reserved.ok, "the reserved byte is still readable")
	assert_equal(reserved.value, 0, "RESERVED_3 priority is 0")
	assert_equal(PrioritiesScript.JOB_KIND_RESERVED_INDEX, 3, "the reserved index is 3")


func test_spawn_writes_the_gdd_5_1_initial_flags() -> void:
	"""§5.1: auto_fallback=true, dangerous_work=false; §4.2 restates "default dangerous=false"."""
	assert_true(_priorities.spawn(2).ok, "spawn succeeds")
	assert_equal(_priorities.auto_fallback_of(2).value, 1, "auto_fallback starts enabled")
	assert_equal(_priorities.dangerous_work_of(2).value, 0, "dangerous_work starts disabled")


func test_the_priority_scale_matches_req_set_026() -> void:
	""""accept 0=forbidden,1=highest,2=high,3=normal,4=low" -- five values, nothing beyond."""
	assert_equal(PrioritiesScript.PRIORITY_FORBIDDEN, 0, "0=forbidden")
	assert_equal(PrioritiesScript.PRIORITY_HIGHEST, 1, "1=highest")
	assert_equal(PrioritiesScript.PRIORITY_HIGH, 2, "2=high")
	assert_equal(PrioritiesScript.PRIORITY_NORMAL, 3, "3=normal")
	assert_equal(PrioritiesScript.PRIORITY_LOW, 4, "4=low")
	assert_equal(PrioritiesScript.PRIORITY_MAX, 4, "4 is the largest accepted priority")


# --- REQ-SET-026 writes ------------------------------------------------------------------------

func test_set_priority_accepts_every_value_zero_through_four() -> void:
	"""Each of the five documented values round-trips on an ordinary job kind."""
	assert_true(_priorities.spawn(0).ok, "spawn succeeds")
	for priority: int in 5:
		var write: PrioritiesScript.OpResult = _priorities.set_priority(
			0, PrioritiesScript.JOB_KIND_KEEP, priority)
		assert_true(write.ok, "priority %d is accepted (error: %s)" % [priority, write.error])
		assert_equal(_priorities.priority_of(0, PrioritiesScript.JOB_KIND_KEEP).value, priority,
			"priority %d reads back" % priority)


func test_set_priority_refuses_five_and_negative_without_writing() -> void:
	"""Out-of-scale values refuse rather than clamp: a clamped 7 would silently become "low"."""
	assert_true(_priorities.spawn(0).ok, "spawn succeeds")
	var too_high: PrioritiesScript.OpResult = _priorities.set_priority(0, 1, 5)
	assert_false(too_high.ok, "priority 5 must refuse")
	assert_equal(too_high.error, PrioritiesScript.REFUSE_INVALID_PRIORITY, "explicit refusal code")
	assert_equal(too_high.value, 0, "a refusal carries no number")
	var negative: PrioritiesScript.OpResult = _priorities.set_priority(0, 1, -1)
	assert_false(negative.ok, "priority -1 must refuse")
	assert_equal(_priorities.priority_of(0, 1).value, 3, "the refused writes left BUILD at 3")


func test_set_priority_refuses_the_reserved_job_kind() -> void:
	"""Assignment to RESERVED_3 is prohibited, exactly as residents.gd refuses reserved-index XP."""
	assert_true(_priorities.spawn(0).ok, "spawn succeeds")
	var write: PrioritiesScript.OpResult = _priorities.set_priority(
		0, PrioritiesScript.JOB_KIND_RESERVED_INDEX, 4)
	assert_false(write.ok, "writing the reserved index must refuse")
	assert_equal(write.error, PrioritiesScript.REFUSE_RESERVED_JOB_KIND, "explicit refusal code")
	assert_equal(_priorities.priority_of(0, PrioritiesScript.JOB_KIND_RESERVED_INDEX).value, 0,
		"the reserved byte is still 0 after the refused write")


func test_set_priority_refuses_an_out_of_range_job_kind() -> void:
	"""The stride is 12 wide; kind 12 and kind -1 name no column."""
	assert_true(_priorities.spawn(0).ok, "spawn succeeds")
	assert_false(_priorities.set_priority(0, 12, 1).ok, "kind 12 must refuse")
	assert_false(_priorities.set_priority(0, -1, 1).ok, "kind -1 must refuse")
	assert_equal(_priorities.priority_of(0, 12).error, "INVALID_JOB_KIND", "reader refuses too")


# --- the owner-major 12-wide stride --------------------------------------------------------------

func test_the_stride_is_slot_times_twelve_plus_kind() -> void:
	"""Every (slot, kind) cell is independent. A wrong multiplier aliases one row onto another.

	Four rows are filled with a distinct value per cell and read back; with a stride of 11 or 13
	the writes would overlap and the read-back would disagree."""
	var slots: Array[int] = [0, 1, 5, 511]
	for slot: int in slots:
		assert_true(_priorities.spawn(slot).ok, "spawn %d" % slot)
	for index: int in slots.size():
		for kind: int in PrioritiesScript.JOB_KIND_COUNT:
			if kind == PrioritiesScript.JOB_KIND_RESERVED_INDEX:
				continue
			var value: int = (index + kind) % 5
			assert_true(_priorities.set_priority(slots[index], kind, value).ok, "write")
	for index: int in slots.size():
		for kind: int in PrioritiesScript.JOB_KIND_COUNT:
			if kind == PrioritiesScript.JOB_KIND_RESERVED_INDEX:
				continue
			assert_equal(_priorities.priority_of(slots[index], kind).value, (index + kind) % 5,
				"slot %d kind %d survives its neighbours" % [slots[index], kind])


func test_writing_one_row_leaves_the_next_rows_initial_values_intact() -> void:
	"""A stride that overran by one cell would corrupt the neighbouring resident's HAUL byte."""
	assert_true(_priorities.spawn(0).ok, "spawn 0")
	assert_true(_priorities.spawn(1).ok, "spawn 1")
	for kind: int in PrioritiesScript.JOB_KIND_COUNT:
		if kind == PrioritiesScript.JOB_KIND_RESERVED_INDEX:
			continue
		assert_true(_priorities.set_priority(0, kind, 1).ok, "fill slot 0")
	for kind: int in PrioritiesScript.JOB_KIND_COUNT:
		assert_equal(_priorities.priority_of(1, kind).value, EXPECTED_INITIAL_PRIORITY[kind],
			"slot 1 kind %d is untouched" % kind)


# --- REQ-SET-028 / 029 automatic fallback --------------------------------------------------------

func test_fallback_allows_only_haul_keep_and_forage_by_default() -> void:
	"""REQ-SET-028 names HAUL, KEEP and low-risk FORAGE; no other kind is a fallback candidate."""
	assert_true(_priorities.spawn(0).ok, "spawn succeeds")
	for kind: int in PrioritiesScript.JOB_KIND_COUNT:
		var expected: int = 1 if PrioritiesScript.is_fallback_kind(kind) else 0
		assert_equal(_priorities.fallback_priority_allows(0, kind).value, expected,
			"fallback candidacy of JobKind %d" % kind)


func test_fallback_is_refused_when_the_configured_priority_is_zero() -> void:
	""""only when their configured priority is nonzero" -- forbidding HAUL removes it entirely."""
	assert_true(_priorities.spawn(0).ok, "spawn succeeds")
	assert_true(_priorities.set_priority(0, PrioritiesScript.JOB_KIND_HAUL, 0).ok, "forbid HAUL")
	assert_equal(_priorities.fallback_priority_allows(0, PrioritiesScript.JOB_KIND_HAUL).value, 0,
		"a forbidden kind is never offered as fallback")
	assert_equal(_priorities.fallback_priority_allows(0, PrioritiesScript.JOB_KIND_KEEP).value, 1,
		"forbidding HAUL does not affect KEEP")


func test_disabling_auto_fallback_removes_every_candidate() -> void:
	"""REQ-SET-029: with fallback off the resident is left free to meet needs, not reassigned."""
	assert_true(_priorities.spawn(0).ok, "spawn succeeds")
	assert_true(_priorities.set_auto_fallback(0, false).ok, "disable fallback")
	assert_equal(_priorities.auto_fallback_of(0).value, 0, "flag is off")
	for kind: int in PrioritiesScript.JOB_KIND_COUNT:
		assert_equal(_priorities.fallback_priority_allows(0, kind).value, 0,
			"JobKind %d is not a fallback candidate while fallback is disabled" % kind)


func test_fallback_kind_set_and_priority_match_req_set_028() -> void:
	"""The published set and the "at priority 4" figure are the requirement's own values."""
	assert_equal(PrioritiesScript.FALLBACK_JOB_KINDS.size(), 3, "exactly three fallback kinds")
	assert_true(PrioritiesScript.is_fallback_kind(PrioritiesScript.JOB_KIND_HAUL), "HAUL")
	assert_true(PrioritiesScript.is_fallback_kind(PrioritiesScript.JOB_KIND_KEEP), "KEEP")
	assert_true(PrioritiesScript.is_fallback_kind(PrioritiesScript.JOB_KIND_FORAGE), "FORAGE")
	assert_false(PrioritiesScript.is_fallback_kind(PrioritiesScript.JOB_KIND_RESERVED_INDEX),
		"RESERVED_3 is never a fallback kind")
	assert_equal(PrioritiesScript.FALLBACK_PRIORITY, 4, "fallback work runs at priority 4")


# --- flags ---------------------------------------------------------------------------------------

func test_dangerous_work_round_trips_and_defaults_false() -> void:
	"""§4.2 "default dangerous=false"; the consent check itself belongs to job selection."""
	assert_true(_priorities.spawn(0).ok, "spawn succeeds")
	assert_equal(_priorities.dangerous_work_of(0).value, 0, "default false")
	assert_true(_priorities.set_dangerous_work(0, true).ok, "grant consent")
	assert_equal(_priorities.dangerous_work_of(0).value, 1, "consent recorded")
	assert_true(_priorities.set_dangerous_work(0, false).ok, "withdraw consent")
	assert_equal(_priorities.dangerous_work_of(0).value, 0, "consent withdrawn")


# --- lifecycle and refusal -------------------------------------------------------------------------

func test_readers_refuse_an_unspawned_row_instead_of_answering_zero() -> void:
	"""Priority 0 means "forbidden", so an absent row must NOT read as 0 (finding: no sentinels)."""
	var read: IntMath.IntResult = _priorities.priority_of(4, PrioritiesScript.JOB_KIND_HAUL)
	assert_false(read.ok, "an unspawned row refuses")
	assert_equal(read.error, "PRIORITIES_NOT_PRESENT", "explicit refusal code")
	assert_false(_priorities.auto_fallback_of(4).ok, "auto_fallback refuses too")
	assert_false(_priorities.dangerous_work_of(4).ok, "dangerous_work refuses too")


func test_spawn_refuses_an_occupied_row_and_an_out_of_range_slot() -> void:
	"""512 rows exist (architecture §2.2); 512 is past the end, and a row spawns once."""
	assert_true(_priorities.spawn(511).ok, "slot 511 is the last row")
	assert_false(_priorities.spawn(511).ok, "respawning an occupied row refuses")
	assert_false(_priorities.spawn(512).ok, "slot 512 is out of range")
	assert_false(_priorities.spawn(-1).ok, "a negative slot is out of range")
	assert_equal(_priorities.present_count(), 1, "only the one row exists")


func test_despawn_clears_the_row_and_further_reads_refuse() -> void:
	"""A released row keeps no residue of the previous resident's configuration."""
	assert_true(_priorities.spawn(7).ok, "spawn succeeds")
	assert_true(_priorities.set_priority(7, PrioritiesScript.JOB_KIND_COOK, 1).ok, "customize")
	assert_true(_priorities.despawn(7).ok, "despawn succeeds")
	assert_false(_priorities.is_present(7), "row is gone")
	assert_false(_priorities.priority_of(7, PrioritiesScript.JOB_KIND_COOK).ok, "reads refuse")
	assert_false(_priorities.despawn(7).ok, "double despawn refuses")
	assert_true(_priorities.spawn(7).ok, "the slot is reusable")
	assert_equal(_priorities.priority_of(7, PrioritiesScript.JOB_KIND_COOK).value, 3,
		"the reused row is back at the §5.1 initial value, not the previous custom one")


func test_despawn_leaves_no_residue_in_the_inactive_row() -> void:
	"""Two logically identical worlds must serialize to identical columns, so a released row is
	returned to exactly the state clear() produces -- not left holding the last resident's
	priorities and consent flags in an inactive row."""
	assert_true(_priorities.spawn(9).ok, "spawn succeeds")
	assert_true(_priorities.set_priority(9, PrioritiesScript.JOB_KIND_CRAFT, 1).ok, "customize")
	assert_true(_priorities.set_dangerous_work(9, true).ok, "grant consent")
	assert_false(_priorities.inactive_row_is_clear(9), "a present row is never reported clear")
	assert_true(_priorities.despawn(9).ok, "despawn succeeds")
	assert_true(_priorities.inactive_row_is_clear(9), "the released row holds no residue")
	assert_true(_priorities.inactive_row_is_clear(8), "a never-used row is clear too")


func test_clear_empties_every_row() -> void:
	"""clear() refills the existing buffers; it does not reallocate and it leaves no row present.
	The empty state it produces is the one despawn() must reproduce, so both use one predicate."""
	for slot: int in 8:
		assert_true(_priorities.spawn(slot).ok, "spawn %d" % slot)
	assert_equal(_priorities.present_count(), 8, "eight rows")
	_priorities.clear()
	assert_equal(_priorities.present_count(), 0, "no rows survive clear()")
	assert_false(_priorities.is_present(0), "slot 0 is empty")
	for slot: int in 8:
		assert_true(_priorities.inactive_row_is_clear(slot), "row %d holds no residue" % slot)


func test_job_kind_constants_come_from_the_protected_catalog_table() -> void:
	"""Decision 0018: there is one copy of every §4.3 number, and it lives in catalog.gd."""
	var job_kind: Dictionary = CatalogScript.fixed_enum("JobKind")
	assert_equal(PrioritiesScript.JOB_KIND_HAUL, job_kind["HAUL"], "HAUL")
	assert_equal(PrioritiesScript.JOB_KIND_FORAGE, job_kind["FORAGE"], "FORAGE")
	assert_equal(PrioritiesScript.JOB_KIND_KEEP, job_kind["KEEP"], "KEEP")
	assert_equal(PrioritiesScript.JOB_KIND_RESERVED_INDEX, job_kind["RESERVED_3"], "RESERVED_3")
	assert_equal(PrioritiesScript.JOB_KIND_COUNT, job_kind.size(), "the 12-column stride")
