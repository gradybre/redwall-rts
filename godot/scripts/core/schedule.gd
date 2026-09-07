extends RefCounted
## The Schedule component: 24 hourly activity slots per resident, the GDD §5.3 templates, and
## the resolved `current_activity` those slots produce once needs are taken into account.
##
## GDD §4.2 fixes the row shape this module owns and nothing else:
##   Schedule: hourly_activity: byte[24], template: enum, current_activity: enum
## `systems_architecture.md` §2.2 fixes the packed layout: `hourly_activity[owner*24+hour]` as a
## B8 column of 12288 bytes (512 owners x 24 hours), and `template`/`current_activity` as two
## I32 columns of 512. Rows are indexed by the RESIDENT typed row `entity_directory.gd`
## allocates; this module never allocates slots and never writes another module's state.
##
## ---------------------------------------------------------------------------------------
## THE TWO ACTIVITY VALUES ARE NOT THE SAME THING. GDD §4.3's `Activity` enum
## (SLEEP=0, ANYTHING=1, WORK=2, SOCIAL=3) is what a schedule slot holds and what this module
## resolves. `needs.gd`'s ACTIVITY_AWAKE / ACTIVITY_SLEEP_BED / ACTIVITY_SLEEP_FLOOR is a
## different, unnumbered enum: it selects the §5.2 rest RESTORATION RATE by sleep location.
## Mapping Activity.SLEEP onto one of those two needs values requires knowing whether the
## resident reached a bed, and no Building/Room/Furniture store exists in this milestone, so
## that mapping is NOT made here and this module never calls `needs.set_activity()`. REQ-SET-015
## states the collapse case explicitly ("place the resident in floor sleep" = ACTIVITY_SLEEP_FLOOR);
## whichever module owns bed assignment must perform the write.
##
## ---------------------------------------------------------------------------------------
## THE TEMPLATE ENUM IS COMPILED, NOT HAND NUMBERED. GDD §4.3 numbers `Activity` explicitly, so
## its values come from `catalog.gd`'s protected table (decision 0018) and are read here as
## constant expressions -- one copy of each specified number, nothing to drift. §4.3 does NOT
## number the schedule templates, so per GDD §4.2's closing paragraph and BAL-CAT-001 they are a
## compiled domain: their IDs are assigned from ascending ASCII key order by `catalog.gd`, never
## from the order §5.3 happens to mention them in.
##
## ---------------------------------------------------------------------------------------
## RESOLUTION (`resolve_into`) IS THE POINT OF THIS MODULE. `current_activity` is NOT
## `hourly_activity[hour]`. It is that value after the §5.3 sleep exception and the §5.2
## needs-driven interrupts, applied in this precedence:
##
##   1. REQ-SET-015, rest<=500: "cancel ordinary work, place the resident in floor sleep".
##      Resolves to SLEEP whatever the hour says, and clears the sleep-satisfied latch so a
##      collapse restarts the sleep rather than inheriting an earlier window's satisfaction.
##   2. §5.3 sleep exception, scheduled SLEEP: "Sleep only continues until rest>=9000; a
##      resident then uses ANYTHING until the scheduled sleep window ends." That trailing clause
##      makes this LATCHED, not a live comparison: rest decays 375/hour while awake (§5.2), so a
##      live comparison would drop the resident back into bed 2.7 hours later, in the middle of
##      the same window, which is exactly what the sentence forbids. The latch is set when rest
##      reaches 9000 during a scheduled SLEEP hour and cleared at the first hour the schedule
##      does not say SLEEP -- i.e. when the window ends.
##   3. REQ-SET-012, hunger<=3500 with a prepared meal reachable: "start a 12-WU eating task
##      before ordinary work". A scheduled WORK hour resolves to ANYTHING; eating is a personal
##      need task (§5.2, "Personal eating/restoring uses unmodified 60 WU/game hour") and §4.3's
##      Activity enum has no EAT value, so ANYTHING is the activity under which it happens.
##   4. REQ-SET-013, no prepared meal reachable: raw-edible food is permitted only at
##      hunger<=1500, so between 1501 and 3500 with nothing prepared there is no permitted meal
##      to interrupt for and the scheduled work stands.
##
## A resolved value is stored in `current_activity` and returned. Until the first resolve() a
## row has no resolved activity, and `current_activity_of()` REFUSES rather than handing back a
## plausible-looking ANYTHING: the codebase has been bitten three times by sentinels.
##
## ---------------------------------------------------------------------------------------
## ALLOCATION. `resolve_into()` allocates nothing of its own. The three `needs.gd` readers it
## calls (`status_of`, two `need_of`) each allocate one IntResult inside that module, which is
## `needs.gd`'s published contract and not this module's to change. §5.3 reevaluates an idle
## resident every 30 ticks staggered by ID, so this is not a per-tick-per-resident path.
## Every column is a packed array sized once in _init(); clear() refills the existing buffers.
##
## ---------------------------------------------------------------------------------------
## GAPS -- named, not invented (AGENTS.md "do not invent a constant"):
##   * REQ-SET-012's "and the resident can interrupt safely" qualifier and REQ-SET-034's "finish
##     at most the current 30-WU safe work segment before changing activity" are both stated in
##     WU, and the WU model is task 2.11 item 6. This module answers what the schedule and the
##     needs WANT for an hour; the job layer owns how long a committed work segment may defer
##     that. Nothing here invents a safe-interrupt boundary.
##   * REQ-SET-015's second half -- "prevent hazardous work until rest>=4000" -- is job
##     ELIGIBILITY (task 2.11 item 4), not activity resolution. It needs its own latch, set at
##     rest<=500 and cleared at rest>=4000, because 500 and 4000 are different thresholds; it is
##     deliberately not added here so item 4 owns one hazard gate rather than two.
##   * ManualTask's "work here" preference (§5.3, 6 game hours) is blocked by U6: no owner-major
##     index formula exists for the 8-per-resident child store. Not implemented.
##   * §5.1 does not state a starting schedule template for the initial cohort. spawn() takes an
##     explicit template ID rather than guessing; `default_template_id()` names the §5.3 default
##     for a caller that wants it. Note that the registry zero default and the compiled ID of
##     &"default" coincidentally agree at 0, which is why this is spelled out rather than relied on.
##   * SCHEDULE LEDGER GAP: architecture §2.2's Schedule row provides hourly_activity, template
##     and current_activity only. The §5.3 sleep exception is latched window state and the
##     no-sentinel rule needs a resolved flag, so two extra 512-byte B8 columns (1024 bytes
##     total) exist here that the §2.3 ledger does not budget. Report it; do not delete the
##     latch to match the table, because the table cannot express the sentence.

const IntMath := preload("res://scripts/core/int_math.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")

## Rows, one per RESIDENT typed row. _init() asserts this equals needs.gd's own capacity rather
## than restating an independent number.
const SCHEDULE_CAPACITY: int = 512
const HOURS_PER_DAY: int = 24

# --- GDD §4.3 Activity, read from catalog.gd's protected table (decision 0018) ---------------

const ACTIVITY_SLEEP: int = Catalog.ACTIVITY["SLEEP"]
const ACTIVITY_ANYTHING: int = Catalog.ACTIVITY["ANYTHING"]
const ACTIVITY_WORK: int = Catalog.ACTIVITY["WORK"]
const ACTIVITY_SOCIAL: int = Catalog.ACTIVITY["SOCIAL"]
## Activity is contiguous 0..3, which _init() proves before any range check relies on it.
const ACTIVITY_COUNT: int = 4

# --- GDD §5.3 schedule templates -------------------------------------------------------------

const TEMPLATE_DOMAIN: String = "ScheduleTemplate"
## §5.3 names three: the default schedule, "Night shift is the same pattern offset 12 hours",
## and "Flexible is all ANYTHING". Declared in ascending ASCII order for readability only --
## catalog.gd sorts them itself, so this order cannot influence the compiled IDs.
const TEMPLATE_DEFAULT_KEY: StringName = &"default"
const TEMPLATE_FLEXIBLE_KEY: StringName = &"flexible"
const TEMPLATE_NIGHT_SHIFT_KEY: StringName = &"night_shift"
const TEMPLATE_KEYS: Array[StringName] = [
	TEMPLATE_DEFAULT_KEY, TEMPLATE_FLEXIBLE_KEY, TEMPLATE_NIGHT_SHIFT_KEY,
]
const TEMPLATE_COUNT: int = 3

## The §5.3 default schedule verbatim, as (start_hour, end_hour_exclusive, activity) triples:
## "22:00-06:00 SLEEP, 06:00-07:00 ANYTHING, 07:00-12:00 WORK, 12:00-13:00 ANYTHING,
##  13:00-18:00 WORK, 18:00-20:00 SOCIAL, 20:00-22:00 ANYTHING."
## Hour slot h covers [h:00, h+1:00). The first segment wraps midnight; _fill_default_hours()
## walks modulo 24 and proves the seven segments tile all 24 hours exactly once.
const SEGMENT_STRIDE: int = 3
const DEFAULT_SEGMENTS: Array[int] = [
	22, 6, ACTIVITY_SLEEP,
	6, 7, ACTIVITY_ANYTHING,
	7, 12, ACTIVITY_WORK,
	12, 13, ACTIVITY_ANYTHING,
	13, 18, ACTIVITY_WORK,
	18, 20, ACTIVITY_SOCIAL,
	20, 22, ACTIVITY_ANYTHING,
]
## "Night shift is the same pattern offset 12 hours."
const NIGHT_SHIFT_OFFSET_HOURS: int = 12

# --- thresholds ------------------------------------------------------------------------------

## §5.3: "Sleep only continues until rest>=9000". This threshold appears nowhere else in the
## codebase; §5.2's rest thresholds (2500 seek, 500 collapse, 4000 hazard clear) are separate.
const REST_SLEEP_SATISFIED_THRESHOLD: int = 9000

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_SLOT: StringName = &"INVALID_SLOT"
const REFUSE_NOT_PRESENT: StringName = &"SCHEDULE_NOT_PRESENT"
const REFUSE_ALREADY_PRESENT: StringName = &"SCHEDULE_ALREADY_PRESENT"
const REFUSE_INVALID_HOUR: StringName = &"INVALID_HOUR"
const REFUSE_INVALID_ACTIVITY: StringName = &"INVALID_ACTIVITY"
const REFUSE_INVALID_TEMPLATE: StringName = &"INVALID_TEMPLATE"
const REFUSE_UNKNOWN_TEMPLATE_KEY: StringName = &"UNKNOWN_TEMPLATE_KEY"
const REFUSE_NOT_RESOLVED: StringName = &"ACTIVITY_NOT_RESOLVED"
const REFUSE_RESIDENT_DEAD: StringName = &"RESIDENT_DEAD"
const REFUSE_INCAPACITATED: StringName = &"RESIDENT_INCAPACITATED"
const REFUSE_NEEDS_UNAVAILABLE: StringName = &"NEEDS_ROW_UNAVAILABLE"
const REFUSE_TEMPLATE_CATALOG: StringName = &"TEMPLATE_CATALOG_INVALID"


class OpResult:
	"""Outcome of one schedule operation: success flag, refusal code, produced value.

	`.ok` MUST be inspected before `.value` is used. A refusal carries 0 and never a partially
	applied effect: every mutator validates completely before it writes a byte.
	"""
	var ok: bool
	var error: StringName
	var value: int

	func _init(p_ok: bool, p_error: StringName, p_value: int) -> void:
		"""Store the outcome fields for this operation."""
		ok = p_ok
		error = p_error
		value = p_value


# --- collaborators ---------------------------------------------------------------------------

var _needs: NeedsScript = null

# --- compiled template catalog ---------------------------------------------------------------

var _template_ids: Dictionary = {}
## Immutable expanded templates, template-major: `_template_hours[template_id*24 + hour]`.
var _template_hours: PackedByteArray = PackedByteArray()
var _catalog_error: String = ""

# --- authoritative columns (ARCH-MEM-001: packed, allocated once) -----------------------------

## Schedule.hourly_activity, owner-major: `_hourly_activity[slot*24 + hour]` (§2.2).
var _hourly_activity: PackedByteArray = PackedByteArray()
var _template: PackedInt32Array = PackedInt32Array()
var _current_activity: PackedInt32Array = PackedInt32Array()

var _present: PackedByteArray = PackedByteArray()
## §5.3 sleep-exception latch: 1 once rest reached 9000 inside the current scheduled SLEEP
## window, cleared at the first hour the schedule does not say SLEEP. See the header.
var _sleep_satisfied: PackedByteArray = PackedByteArray()
## 1 once resolve() has produced a `current_activity` for this row. Guards the reader against
## returning an unresolved placeholder as if it were an answer.
var _resolved: PackedByteArray = PackedByteArray()

var _present_count: int = 0

# --- scratch (not simulation state) ----------------------------------------------------------

## The two need values one resolve() pass reads, fetched by _check_resolvable() and consumed by
## _resolve_activity() before that call returns. Nothing here invokes a callback or signal, so
## no public operation can re-enter while they hold a live value.
var _hunger_scratch: int = 0
var _rest_scratch: int = 0


func _init(p_needs: NeedsScript = null) -> void:
	"""Compile the template domain, expand the §5.3 tables, and allocate every column once.

	Passing an existing needs store shares it; passing nothing creates a private one, which is
	what a test or a standalone settlement wants.
	"""
	assert(SCHEDULE_CAPACITY == NeedsScript.RESIDENT_CAPACITY,
		"schedule columns must match the needs store's resident capacity")
	assert(Catalog.ACTIVITY.size() == ACTIVITY_COUNT,
		"GDD §4.3 Activity has exactly four values")
	_assert_activity_is_contiguous()
	_needs = p_needs if p_needs != null else NeedsScript.new()
	_compile_templates()
	_allocate_columns()
	clear()


func _assert_activity_is_contiguous() -> void:
	"""Prove Activity occupies 0..ACTIVITY_COUNT-1, which every range check here relies on.

	JobKind and ZoneType have reserved gaps; Activity does not, so `0 <= a < 4` is a sound
	membership test only while that stays true of catalog.gd's table.
	"""
	var seen: Array[bool] = []
	for index: int in ACTIVITY_COUNT:
		seen.append(false)
	for key: String in Catalog.ACTIVITY:
		var value: int = int(Catalog.ACTIVITY[key])
		assert(value >= 0 and value < ACTIVITY_COUNT, "Activity value out of 0..3")
		assert(not seen[value], "duplicate Activity value")
		seen[value] = true


func _compile_templates() -> void:
	"""Assign template IDs from ascending ASCII key order and expand their 24-hour tables.

	A refusal is recorded in `_catalog_error` rather than thrown; every operation that needs a
	template ID checks it, so a broken catalog refuses instead of indexing garbage.
	"""
	var result: Catalog.DomainResult = Catalog.compile_domain(TEMPLATE_DOMAIN, TEMPLATE_KEYS)
	if not result.ok:
		_catalog_error = result.error
		return
	_template_ids = result.ids
	_template_hours.resize(TEMPLATE_COUNT * HOURS_PER_DAY)
	_template_hours.fill(ACTIVITY_ANYTHING)
	_catalog_error = _expand_templates()


func _expand_templates() -> String:
	"""Write each template's 24 hour bytes. Returns "" on success or the failed check."""
	var default_error: String = _fill_default_hours(
		int(_template_ids[TEMPLATE_DEFAULT_KEY]) * HOURS_PER_DAY, 0)
	if default_error != "":
		return default_error
	var night_error: String = _fill_default_hours(
		int(_template_ids[TEMPLATE_NIGHT_SHIFT_KEY]) * HOURS_PER_DAY, NIGHT_SHIFT_OFFSET_HOURS)
	if night_error != "":
		return night_error
	var flexible_base: int = int(_template_ids[TEMPLATE_FLEXIBLE_KEY]) * HOURS_PER_DAY
	for hour: int in HOURS_PER_DAY:
		_template_hours[flexible_base + hour] = ACTIVITY_ANYTHING
	return ""


static func segment_coverage_error(segments: Array[int], offset_hours: int) -> String:
	"""Prove a (start, stop, activity) triple list tiles all 24 hours exactly once.

	Returns "" when it does, or the specific transcription fault otherwise: a ragged list, an
	hour outside 0-23, an empty or whole-day segment, a doubly covered hour, or a gap. Static and
	side-effect free so the guard can be exercised on a deliberately broken list -- a validation
	clause that only ever runs against correct data is indistinguishable from `return ""`.
	"""
	if segments.size() % SEGMENT_STRIDE != 0 or segments.is_empty():
		return "segment list of %d values is not whole (start, stop, activity) triples" % segments.size()
	var coverage: PackedByteArray = PackedByteArray()
	coverage.resize(HOURS_PER_DAY)
	coverage.fill(0)
	var index: int = 0
	while index < segments.size():
		var error: String = _mark_segment(segments, index, offset_hours, coverage)
		if error != "":
			return error
		index += SEGMENT_STRIDE
	if coverage.count(0) != 0:
		return "%d hour(s) left uncovered by the segment list" % coverage.count(0)
	return ""


static func _mark_segment(segments: Array[int], index: int, offset_hours: int,
		coverage: PackedByteArray) -> String:
	"""Mark one segment's hours in `coverage`, returning "" or the fault it found."""
	var start: int = segments[index]
	var stop: int = segments[index + 1]
	if start < 0 or start >= HOURS_PER_DAY or stop < 0 or stop >= HOURS_PER_DAY:
		return "segment at %d names an hour outside 0-23" % index
	if segments[index + 2] < 0 or segments[index + 2] >= ACTIVITY_COUNT:
		return "segment at %d names an activity outside the §4.3 enum" % index
	if start == stop:
		return "segment at %d is empty or a full day" % index
	var hour: int = start
	while hour != stop:
		var shifted: int = (hour + offset_hours) % HOURS_PER_DAY
		if coverage[shifted] != 0:
			return "hour %d is covered by two segments" % shifted
		coverage[shifted] = 1
		hour = (hour + 1) % HOURS_PER_DAY
	return ""


func _fill_default_hours(base: int, offset_hours: int) -> String:
	"""Expand DEFAULT_SEGMENTS into 24 bytes at `base`, each hour shifted by `offset_hours`.

	The tiling is proved before a single byte is written, so a transcription error in the §5.3
	segment list refuses the whole compile instead of leaving some hours at whatever the buffer
	last held.
	"""
	var error: String = segment_coverage_error(DEFAULT_SEGMENTS, offset_hours)
	if error != "":
		return error
	var index: int = 0
	while index < DEFAULT_SEGMENTS.size():
		var stop: int = DEFAULT_SEGMENTS[index + 1]
		var activity: int = DEFAULT_SEGMENTS[index + 2]
		var hour: int = DEFAULT_SEGMENTS[index]
		while hour != stop:
			_template_hours[base + (hour + offset_hours) % HOURS_PER_DAY] = activity
			hour = (hour + 1) % HOURS_PER_DAY
		index += SEGMENT_STRIDE
	return ""


func _allocate_columns() -> void:
	"""Size every packed column exactly once, per ARCH-MEM-001. Never called again."""
	_hourly_activity.resize(SCHEDULE_CAPACITY * HOURS_PER_DAY)
	_template.resize(SCHEDULE_CAPACITY)
	_current_activity.resize(SCHEDULE_CAPACITY)
	_present.resize(SCHEDULE_CAPACITY)
	_sleep_satisfied.resize(SCHEDULE_CAPACITY)
	_resolved.resize(SCHEDULE_CAPACITY)


func clear() -> void:
	"""Return every row to the empty state, refilling the existing buffers without reallocating."""
	_hourly_activity.fill(ACTIVITY_ANYTHING)
	_template.fill(0)
	_current_activity.fill(ACTIVITY_ANYTHING)
	_present.fill(0)
	_sleep_satisfied.fill(0)
	_resolved.fill(0)
	_present_count = 0


# --- results -----------------------------------------------------------------------------------

func _result(code: StringName, value: int) -> OpResult:
	"""Build one OpResult. A refusal always carries 0, so an ignored refusal reveals no number."""
	if code != REFUSE_NONE:
		return OpResult.new(false, code, 0)
	return OpResult.new(true, REFUSE_NONE, value)


func _read(code: StringName, value: int) -> IntMath.IntResult:
	"""Build a reader's IntResult: the value on success, an explicit refusal otherwise."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if code != REFUSE_NONE:
		out.refuse(String(code))
	else:
		out.succeed(value)
	return out


# --- address checks ----------------------------------------------------------------------------

func _check_present_slot(slot: int) -> StringName:
	"""REFUSE_NONE when `slot` is in range and holds a spawned schedule row."""
	if slot < 0 or slot >= SCHEDULE_CAPACITY:
		return REFUSE_INVALID_SLOT
	if _present[slot] == 0:
		return REFUSE_NOT_PRESENT
	return REFUSE_NONE


func _check_hour_address(slot: int, hour: int) -> StringName:
	"""REFUSE_NONE when (slot, hour) names a real hour slot of a spawned schedule row."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return code
	if hour < 0 or hour >= HOURS_PER_DAY:
		return REFUSE_INVALID_HOUR
	return REFUSE_NONE


func _check_template(template_id: int) -> StringName:
	"""REFUSE_NONE when `template_id` is a compiled schedule template ID."""
	if _catalog_error != "":
		return REFUSE_TEMPLATE_CATALOG
	if template_id < 0 or template_id >= TEMPLATE_COUNT:
		return REFUSE_INVALID_TEMPLATE
	return REFUSE_NONE


# --- compiled template catalog -------------------------------------------------------------------

func catalog_error() -> String:
	"""Empty while the template domain compiled and its 24-hour tables validated."""
	return _catalog_error


func template_ids() -> Dictionary:
	"""Copy of the compiled key -> int32 template ID table. Empty if compilation refused."""
	return _template_ids.duplicate()


func template_id_of(key: StringName) -> IntMath.IntResult:
	"""Compiled ID of one schedule template key, or an explicit refusal for an unknown key."""
	if _catalog_error != "":
		return _read(REFUSE_TEMPLATE_CATALOG, 0)
	if not _template_ids.has(key):
		return _read(REFUSE_UNKNOWN_TEMPLATE_KEY, 0)
	return _read(REFUSE_NONE, int(_template_ids[key]))


func default_template_id() -> IntMath.IntResult:
	"""Compiled ID of the §5.3 default schedule. §5.1 states no starting template; see header."""
	return template_id_of(TEMPLATE_DEFAULT_KEY)


func template_activity_at(template_id: int, hour: int) -> IntMath.IntResult:
	"""The immutable §5.3 activity a template prescribes for one hour, before any resolution."""
	var code: StringName = _check_template(template_id)
	if code != REFUSE_NONE:
		return _read(code, 0)
	if hour < 0 or hour >= HOURS_PER_DAY:
		return _read(REFUSE_INVALID_HOUR, 0)
	return _read(REFUSE_NONE, _template_hours[template_id * HOURS_PER_DAY + hour])


# --- lifecycle -----------------------------------------------------------------------------------

func spawn(slot: int, template_id: int) -> OpResult:
	"""Initialize one schedule row from a template's 24 hours. Refuses an occupied row.

	`slot` is the RESIDENT typed row entity_directory.gd allocated. The row has no resolved
	current_activity until resolve() runs, so current_activity_of() refuses until then.
	"""
	if slot < 0 or slot >= SCHEDULE_CAPACITY:
		return _result(REFUSE_INVALID_SLOT, 0)
	if _present[slot] != 0:
		return _result(REFUSE_ALREADY_PRESENT, 0)
	var code: StringName = _check_template(template_id)
	if code != REFUSE_NONE:
		return _result(code, 0)
	_present[slot] = 1
	_present_count += 1
	_write_template_hours(slot, template_id)
	_current_activity[slot] = ACTIVITY_ANYTHING
	_resolved[slot] = 0
	return _result(REFUSE_NONE, template_id)


func despawn(slot: int) -> OpResult:
	"""Release one schedule row back to the empty state. Refuses a row that is not present."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code, 0)
	_present[slot] = 0
	_present_count -= 1
	_template[slot] = 0
	_current_activity[slot] = ACTIVITY_ANYTHING
	_resolved[slot] = 0
	_sleep_satisfied[slot] = 0
	var base: int = slot * HOURS_PER_DAY
	for hour: int in HOURS_PER_DAY:
		_hourly_activity[base + hour] = ACTIVITY_ANYTHING
	return _result(REFUSE_NONE, slot)


func _write_template_hours(slot: int, template_id: int) -> void:
	"""Copy a template's 24 bytes into one row and reset its sleep-exception latch."""
	var base: int = slot * HOURS_PER_DAY
	var source: int = template_id * HOURS_PER_DAY
	for hour: int in HOURS_PER_DAY:
		_hourly_activity[base + hour] = _template_hours[source + hour]
	_template[slot] = template_id
	_sleep_satisfied[slot] = 0


func assign_template(slot: int, template_id: int) -> OpResult:
	"""Overwrite one row's 24 hours with a template, discarding any per-hour customization.

	The sleep-exception latch resets: the scheduled sleep window itself has changed, so an
	earlier window's satisfaction says nothing about the new one.
	"""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _result(code, 0)
	code = _check_template(template_id)
	if code != REFUSE_NONE:
		return _result(code, 0)
	_write_template_hours(slot, template_id)
	return _result(REFUSE_NONE, template_id)


func set_hour_activity(slot: int, hour: int, activity: int) -> OpResult:
	"""Write one hour slot directly, for a player-customized schedule.

	The row keeps whatever `template` it was last assigned; §4.2 stores the template and the 24
	slots as independent fields, so a customized row is not silently re-labelled.
	"""
	var code: StringName = _check_hour_address(slot, hour)
	if code != REFUSE_NONE:
		return _result(code, 0)
	if activity < 0 or activity >= ACTIVITY_COUNT:
		return _result(REFUSE_INVALID_ACTIVITY, 0)
	_hourly_activity[slot * HOURS_PER_DAY + hour] = activity
	return _result(REFUSE_NONE, activity)


# --- readers ---------------------------------------------------------------------------------

func is_present(slot: int) -> bool:
	"""True when `slot` is in range and holds a spawned schedule row."""
	return slot >= 0 and slot < SCHEDULE_CAPACITY and _present[slot] == 1


func present_count() -> int:
	"""Number of spawned schedule rows."""
	return _present_count


func hour_activity_of(slot: int, hour: int) -> IntMath.IntResult:
	"""Schedule.hourly_activity[hour]: what the schedule ALONE says, with no needs applied."""
	var code: StringName = _check_hour_address(slot, hour)
	return _read(code, _hourly_activity[slot * HOURS_PER_DAY + hour] if code == REFUSE_NONE else 0)


func template_of(slot: int) -> IntMath.IntResult:
	"""Schedule.template: the last template assigned to this row."""
	var code: StringName = _check_present_slot(slot)
	return _read(code, _template[slot] if code == REFUSE_NONE else 0)


func current_activity_of(slot: int) -> IntMath.IntResult:
	"""Schedule.current_activity: the last RESOLVED activity, refusing before the first resolve."""
	var code: StringName = _check_present_slot(slot)
	if code != REFUSE_NONE:
		return _read(code, 0)
	if _resolved[slot] == 0:
		return _read(REFUSE_NOT_RESOLVED, 0)
	return _read(REFUSE_NONE, _current_activity[slot])


func inactive_row_is_clear(slot: int) -> bool:
	"""True when an absent row holds no residue of the resident who last occupied it.

	Two logically identical worlds must serialize to identical columns, so despawn() returns a
	row to exactly the state clear() produces rather than leaving the departed resident's
	schedule in an inactive row where it would change the canonical hash. A save or validation
	pass checks this; readers of an active row never need it. Always false for a present row.
	"""
	if slot < 0 or slot >= SCHEDULE_CAPACITY or _present[slot] != 0:
		return false
	if _template[slot] != 0 or _current_activity[slot] != ACTIVITY_ANYTHING:
		return false
	if _resolved[slot] != 0 or _sleep_satisfied[slot] != 0:
		return false
	var base: int = slot * HOURS_PER_DAY
	for hour: int in HOURS_PER_DAY:
		if _hourly_activity[base + hour] != ACTIVITY_ANYTHING:
			return false
	return true


func sleep_satisfied_of(slot: int) -> IntMath.IntResult:
	"""1 while the §5.3 rest>=9000 exception is latched for the current scheduled sleep window."""
	var code: StringName = _check_present_slot(slot)
	return _read(code, _sleep_satisfied[slot] if code == REFUSE_NONE else 0)


# --- resolution (§5.3 sleep exception + REQ-SET-012/013/015) ------------------------------------

func resolve(slot: int, hour: int, prepared_meal_reachable: bool) -> IntMath.IntResult:
	"""Resolve and store this hour's current_activity. Allocating wrapper over resolve_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	resolve_into(slot, hour, prepared_meal_reachable, out)
	return out


func resolve_into(slot: int, hour: int, prepared_meal_reachable: bool,
		out: IntMath.IntResult) -> bool:
	"""Resolve this hour's activity into `out`, storing it as the row's current_activity.

	`prepared_meal_reachable` is the caller's answer to REQ-SET-012's "reserve a permitted
	meal": true when a prepared portion is reachable and unreserved, false when only the
	REQ-SET-013 raw-edible fallback could apply. No inventory or reachability is consulted here.

	Refuses a dead or incapacitated resident rather than inventing an Activity for them: §4.3
	numbers no unconscious activity and REQ-SET-023 replaces their schedule with a rescue job.
	"""
	var code: StringName = _check_hour_address(slot, hour)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	code = _check_resolvable(slot)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	var scheduled: int = _hourly_activity[slot * HOURS_PER_DAY + hour]
	var resolved: int = _resolve_activity(slot, scheduled, prepared_meal_reachable)
	_current_activity[slot] = resolved
	_resolved[slot] = 1
	return out.succeed(resolved)


func _check_resolvable(slot: int) -> StringName:
	"""Refuse unless the needs row exists and is conscious; cache this pass's hunger and rest."""
	var status: IntMath.IntResult = _needs.status_of(slot)
	if not status.ok:
		return REFUSE_NEEDS_UNAVAILABLE
	if status.value == NeedsScript.STATUS_DEAD:
		return REFUSE_RESIDENT_DEAD
	if status.value == NeedsScript.STATUS_INCAPACITATED:
		return REFUSE_INCAPACITATED
	var hunger: IntMath.IntResult = _needs.need_of(slot, NeedsScript.NEED_HUNGER)
	var rest: IntMath.IntResult = _needs.need_of(slot, NeedsScript.NEED_REST)
	if not hunger.ok or not rest.ok:
		return REFUSE_NEEDS_UNAVAILABLE
	_hunger_scratch = hunger.value
	_rest_scratch = rest.value
	return REFUSE_NONE


func _resolve_activity(slot: int, scheduled: int, prepared_meal_reachable: bool) -> int:
	"""Apply the header's four-step precedence to one scheduled activity. Updates the latch."""
	if _rest_scratch <= NeedsScript.REST_COLLAPSE_THRESHOLD:
		_sleep_satisfied[slot] = 0
		return ACTIVITY_SLEEP
	if scheduled == ACTIVITY_SLEEP:
		if _rest_scratch >= REST_SLEEP_SATISFIED_THRESHOLD:
			_sleep_satisfied[slot] = 1
		return ACTIVITY_ANYTHING if _sleep_satisfied[slot] == 1 else ACTIVITY_SLEEP
	_sleep_satisfied[slot] = 0
	if scheduled == ACTIVITY_WORK and _eat_interrupts(prepared_meal_reachable):
		return ACTIVITY_ANYTHING
	return scheduled


func _eat_interrupts(prepared_meal_reachable: bool) -> bool:
	"""Does hunger displace this hour's scheduled work with an eating task?

	REQ-SET-012 at hunger<=3500 when a prepared meal is reachable; REQ-SET-013's raw-edible
	fallback only at hunger<=1500, so an unreachable meal between 1501 and 3500 interrupts
	nothing -- there is no permitted meal to eat.
	"""
	if prepared_meal_reachable:
		return _hunger_scratch <= NeedsScript.HUNGER_EAT_THRESHOLD
	return _hunger_scratch <= NeedsScript.HUNGER_URGENT_THRESHOLD
