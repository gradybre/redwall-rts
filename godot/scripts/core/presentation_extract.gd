extends RefCounted
## ARCH-SYS-023 PresentationExtract: the one read-only snapshot of committed state, and the ONE
## PLACE IN THIS CODEBASE WHERE A `float` IS LEGAL.
##
## AGENTS.md: "Integer arithmetic for all authoritative state. `float` is presentation and import
## only; it never decides a gameplay outcome." This module is the presentation side of that
## boundary. Every value it holds is an INTEGER copied out of a committed store; the only floats
## it produces are `interpolate_into()`'s, and nothing in the simulation reads them back. A render
## frame between tick k and tick k+1 asks for a field at an alpha and gets a float built from the
## two committed integers on either side of it. The integers are the truth; the float is a
## drawing instruction.
##
## ---------------------------------------------------------------------------------------
## WHAT "READ-ONLY" MEANS HERE, STRUCTURALLY RATHER THAN BY CONVENTION.
##
##   * NO MUTABLE HANDLE ESCAPES. This module publishes no store, no packed column and no
##     reference to anything it read from. `value_into()` and `interpolate_into()` fill a record
##     the CALLER owns. A presentation layer that holds this object holds fourteen numbers.
##   * NO READER CAN REPAIR OR ALTER WHAT IT OBSERVES. There is no setter for any captured field.
##     The only two mutators are `capture()`, which copies FROM the simulation and writes to
##     nothing else, and `set_layer_visible()`, which touches one visibility byte and no value.
##     A UI that dislikes what it sees can only submit a command, exactly as ARCH-CMD-001 intends.
##   * HIDING A LAYER CHANGES WHAT IS REPORTED, NEVER WHAT IS TRUE. `set_layer_visible(l, false)`
##     makes every field on that layer REFUSE `PRESENTATION_LAYER_HIDDEN`. It does not zero the
##     column, does not stop the next `capture()` recording the real value, and cannot reach the
##     store the value came from. Unhiding shows the same number that was there all along.
##
## ---------------------------------------------------------------------------------------
## THE CAPTURE IS LATCHED ON ITS TICK, for the same reason `ecology.gd` latches its day. The
## snapshot holds the PREVIOUS and the CURRENT capture, and interpolation is between them; a
## second `capture()` of one tick would roll a genuine previous frame out of the buffer and make
## the renderer interpolate from a frame to itself. `capture()` therefore refuses a tick at or
## before the last captured one. That also means a presentation layer calling `capture()` cannot
## disturb the baseline: the settlement's own stage has already taken this tick.
##
## ---------------------------------------------------------------------------------------
## AN UNBOUND SOURCE REFUSES, IT DOES NOT READ ZERO. A settlement that composes no planner has no
## standing-demand count, and reporting 0 would be indistinguishable from a settlement with a
## planner and no demand. Fields whose source is not bound are marked unavailable at construction
## and refuse `PRESENTATION_SOURCE_NOT_BOUND` for the life of the object.
##
## ---------------------------------------------------------------------------------------
## WHAT IS DELIBERATELY NOT SNAPSHOTTED. §5's ARCH-SYS-023 row reads "Completed immutable
## snapshot, dirty pages -> Render buffers, UI snapshots only". There are NO DIRTY PAGES here and
## no render buffer: this milestone has no Transform store (ARCH-SYS-001), no per-resident
## position, no MultiMesh and no camera, so there is nothing to page and nothing to interpolate
## SPATIALLY. The fourteen fields below are the committed scalars that exist today, and each names
## the store it is read from. Adding a field is a change to FIELD_COUNT and to the two tables
## under it, and to nothing else.

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const CommandDispatchScript := preload("res://scripts/core/command_dispatch.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")

# --- the six presentation layers (UI §3's grouping, one visibility byte each) -------------------

const LAYER_CLOCK: int = 0
const LAYER_POPULATION: int = 1
const LAYER_JOBS: int = 2
const LAYER_COMMANDS: int = 3
const LAYER_ECOLOGY: int = 4
const LAYER_WEATHER: int = 5
const LAYER_COUNT: int = 6

const LAYER_KEYS: Array[StringName] = [
	&"clock", &"population", &"jobs", &"commands", &"ecology", &"weather",
]

# --- the fourteen captured fields --------------------------------------------------------------

const FIELD_TICK: int = 0
const FIELD_ABSOLUTE_DAY: int = 1
const FIELD_HOUR: int = 2
const FIELD_SEASON: int = 3
const FIELD_POPULATION: int = 4
const FIELD_LIVING: int = 5
const FIELD_JOB_COUNT: int = 6
const FIELD_PENDING_COMMANDS: int = 7
const FIELD_COMMANDS_COMMITTED: int = 8
const FIELD_COMMANDS_REFUSED: int = 9
const FIELD_HARVEST_ZONES: int = 10
const FIELD_STANDING_DEMANDS: int = 11
const FIELD_SOURCE_INTENTS: int = 12
const FIELD_TEMPERATURE_TENTHS: int = 13
const FIELD_COUNT: int = 14

## Which layer each field belongs to. `_assert_contracts()` proves every entry names a real layer.
const FIELD_LAYER: Array[int] = [
	LAYER_CLOCK, LAYER_CLOCK, LAYER_CLOCK, LAYER_CLOCK,
	LAYER_POPULATION, LAYER_POPULATION,
	LAYER_JOBS,
	LAYER_COMMANDS, LAYER_COMMANDS, LAYER_COMMANDS,
	LAYER_ECOLOGY, LAYER_ECOLOGY, LAYER_ECOLOGY,
	LAYER_WEATHER,
]

## Which collaborator each field is read from. SOURCE_CLOCK needs none: it is decoded from the
## captured tick through `sim_clock.gd`'s static offset calendar.
const SOURCE_CLOCK: int = 0
const SOURCE_RESIDENTS: int = 1
const SOURCE_JOBS: int = 2
const SOURCE_DISPATCH: int = 3
const SOURCE_FORAGE: int = 4
const SOURCE_PLANNER: int = 5
const SOURCE_WEATHER: int = 6
const SOURCE_COUNT: int = 7

const FIELD_SOURCE: Array[int] = [
	SOURCE_CLOCK, SOURCE_CLOCK, SOURCE_CLOCK, SOURCE_CLOCK,
	SOURCE_RESIDENTS, SOURCE_RESIDENTS,
	SOURCE_JOBS,
	SOURCE_DISPATCH, SOURCE_DISPATCH, SOURCE_DISPATCH,
	SOURCE_FORAGE, SOURCE_PLANNER, SOURCE_DISPATCH,
	SOURCE_WEATHER,
]

const FIELD_KEYS: Array[StringName] = [
	&"tick", &"absolute_day", &"hour", &"season",
	&"population", &"living",
	&"job_count",
	&"pending_commands", &"commands_committed", &"commands_refused",
	&"harvest_zones", &"standing_demands", &"source_intents",
	&"temperature_tenths",
]

## The renderer's sub-tick position, in thousandths of one fixed tick. An integer, because the
## CALLER's fraction is not authoritative state either and a float parameter here would invite
## one to be stored.
const ALPHA_MIN: int = 0
const ALPHA_MAX: int = 1000

## No capture has been taken. Distinct from tick 0, which is a real captured tick.
const NO_CAPTURE_TICK: int = -1

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_TICK: StringName = &"PRESENTATION_INVALID_TICK"
const REFUSE_TICK_ALREADY_CAPTURED: StringName = &"PRESENTATION_TICK_ALREADY_CAPTURED"
const REFUSE_INVALID_FIELD: StringName = &"PRESENTATION_INVALID_FIELD"
const REFUSE_INVALID_LAYER: StringName = &"PRESENTATION_INVALID_LAYER"
const REFUSE_INVALID_ALPHA: StringName = &"PRESENTATION_INVALID_ALPHA"
const REFUSE_LAYER_HIDDEN: StringName = &"PRESENTATION_LAYER_HIDDEN"
const REFUSE_SOURCE_NOT_BOUND: StringName = &"PRESENTATION_SOURCE_NOT_BOUND"
const REFUSE_NO_CAPTURE: StringName = &"PRESENTATION_NO_CAPTURE"
const REFUSE_NO_PREVIOUS_CAPTURE: StringName = &"PRESENTATION_NO_PREVIOUS_CAPTURE"


class FloatRead:
	"""One interpolated presentation value, caller-owned and reused.

	`.ok` MUST be inspected before `.value`. THIS CLASS IS THE FLOAT BOUNDARY: it is the only
	type in `scripts/core/` that carries a `float`, and nothing in the simulation reads one.
	A refusal leaves `value` at 0.0, which is why `.ok` is not optional -- 0.0 is a plausible
	temperature and would be a sentinel if it were returned on its own.
	"""
	var ok: bool = false
	var error: StringName = REFUSE_NONE
	var value: float = 0.0

	func succeed(p_value: float) -> bool:
		"""Record one interpolated value. Always returns true."""
		ok = true
		error = REFUSE_NONE
		value = p_value
		return true

	func refuse(code: StringName) -> bool:
		"""Record a refusal and discard any previous value. Always returns false."""
		ok = false
		error = code
		value = 0.0
		return false


# --- collaborators: every one optional, and an absent one refuses rather than reading zero -----

var _residents: ResidentsScript = null
var _jobs: JobsScript = null
var _dispatch: CommandDispatchScript = null
var _forage: ForageScript = null
var _planner: JobPlannerScript = null
var _weather: WeatherScript = null

# --- the snapshot: two committed frames, allocated once (ARCH-MEM-001) -------------------------

var _current: PackedInt64Array = PackedInt64Array()
var _previous: PackedInt64Array = PackedInt64Array()
var _available: PackedByteArray = PackedByteArray()
var _layer_visible: PackedByteArray = PackedByteArray()

var _current_tick: int = NO_CAPTURE_TICK
var _previous_tick: int = NO_CAPTURE_TICK
var _capture_count: int = 0
var _last_refusal: StringName = REFUSE_NONE

# --- scratch (not simulation state, and never published) ---------------------------------------

var _calendar: SimClock.Calendar = SimClock.Calendar.new(0)


func _init(p_residents: ResidentsScript = null, p_jobs: JobsScript = null,
		p_dispatch: CommandDispatchScript = null, p_forage: ForageScript = null,
		p_planner: JobPlannerScript = null, p_weather: WeatherScript = null) -> void:
	"""Adopt whichever committed stores this composition owns and size both frames exactly once.

	Every collaborator is optional so a partial settlement can still extract what it does have.
	Which fields that leaves unavailable is decided HERE, once, and never re-decided per read.
	"""
	_residents = p_residents
	_jobs = p_jobs
	_dispatch = p_dispatch
	_forage = p_forage
	_planner = p_planner
	_weather = p_weather
	_assert_contracts()
	_allocate_columns()
	_mark_availability()
	clear()


func _assert_contracts() -> void:
	"""Prove the two field tables and the key tables describe exactly FIELD_COUNT fields."""
	assert(FIELD_LAYER.size() == FIELD_COUNT, "every field must name the layer it draws on")
	assert(FIELD_SOURCE.size() == FIELD_COUNT, "every field must name the store it is read from")
	assert(FIELD_KEYS.size() == FIELD_COUNT, "every field must have one stable key")
	assert(LAYER_KEYS.size() == LAYER_COUNT, "every layer must have one stable key")
	for field: int in FIELD_COUNT:
		assert(FIELD_LAYER[field] >= 0 and FIELD_LAYER[field] < LAYER_COUNT,
			"a field cannot draw on a layer that does not exist")
		assert(FIELD_SOURCE[field] >= 0 and FIELD_SOURCE[field] < SOURCE_COUNT,
			"a field cannot be read from a source that does not exist")


func _allocate_columns() -> void:
	"""The only place that sizes an array here; `clear()` refills without reallocating."""
	_current.resize(FIELD_COUNT)
	_previous.resize(FIELD_COUNT)
	_available.resize(FIELD_COUNT)
	_layer_visible.resize(LAYER_COUNT)


func _mark_availability() -> void:
	"""Decide once, at construction, which fields have a bound source behind them."""
	for field: int in FIELD_COUNT:
		_available[field] = 1 if _source_is_bound(FIELD_SOURCE[field]) else 0


func _source_is_bound(source: int) -> bool:
	"""True when the collaborator a field is read from was supplied to `_init()`."""
	if source == SOURCE_CLOCK:
		return true
	if source == SOURCE_RESIDENTS:
		return _residents != null
	if source == SOURCE_JOBS:
		return _jobs != null
	if source == SOURCE_DISPATCH:
		return _dispatch != null
	if source == SOURCE_FORAGE:
		return _forage != null
	if source == SOURCE_PLANNER:
		return _planner != null
	return _weather != null


func clear() -> void:
	"""Drop both captured frames and show every layer again, without reallocating a column."""
	_current.fill(0)
	_previous.fill(0)
	_layer_visible.fill(1)
	_current_tick = NO_CAPTURE_TICK
	_previous_tick = NO_CAPTURE_TICK
	_capture_count = 0
	_last_refusal = REFUSE_NONE


# --- the stage ---------------------------------------------------------------------------------

func capture(tick: int) -> bool:
	"""ARCH-SYS-023: copy this tick's committed state into the snapshot. Writes NO store.

	Called once per completed tick, after every stage that can still change a value. The current
	frame becomes the previous one and the new reading replaces it, so the two frames a render
	interpolates between are always consecutive captures.
	"""
	if tick < 0:
		return _refuse(REFUSE_INVALID_TICK)
	if _current_tick != NO_CAPTURE_TICK and tick <= _current_tick:
		return _refuse(REFUSE_TICK_ALREADY_CAPTURED)
	_roll_frame()
	_current_tick = tick
	_read_clock(tick)
	_read_population()
	_read_jobs()
	_read_commands()
	_read_ecology()
	_read_weather()
	_capture_count += 1
	_last_refusal = REFUSE_NONE
	return true


func _roll_frame() -> void:
	"""Move the current frame into the previous one, field by field, allocating nothing."""
	for field: int in FIELD_COUNT:
		_previous[field] = _current[field]
	_previous_tick = _current_tick


func _read_clock(tick: int) -> void:
	"""Decode the captured tick through `sim_clock.gd`'s offset calendar into four fields."""
	SimClock.calendar_at_into(tick, _calendar)
	_current[FIELD_TICK] = tick
	_current[FIELD_ABSOLUTE_DAY] = _calendar.absolute_day
	_current[FIELD_HOUR] = _calendar.hour
	_current[FIELD_SEASON] = _calendar.season


func _read_population() -> void:
	"""Copy the resident store's two committed counts."""
	if _residents == null:
		return
	_current[FIELD_POPULATION] = _residents.population()
	_current[FIELD_LIVING] = _residents.living_count()


func _read_jobs() -> void:
	"""Copy the live Job row count. Zero is a real answer here, not an absent one."""
	if _jobs == null:
		return
	_current[FIELD_JOB_COUNT] = _jobs.job_count()


func _read_commands() -> void:
	"""Copy ARCH-CMD-001's pending depth and ARCH-SYS-002's two running outcome totals."""
	if _dispatch == null:
		return
	_current[FIELD_PENDING_COMMANDS] = _dispatch.pending_count()
	_current[FIELD_COMMANDS_COMMITTED] = _dispatch.committed_count()
	_current[FIELD_COMMANDS_REFUSED] = _dispatch.refused_count()
	_current[FIELD_SOURCE_INTENTS] = _dispatch.source_intent_count()


func _read_ecology() -> void:
	"""Copy the HarvestZone count and ARCH-SYS-009's enabled standing-demand count."""
	if _forage != null:
		_current[FIELD_HARVEST_ZONES] = _forage.zone_count()
	if _planner != null:
		_current[FIELD_STANDING_DEMANDS] = _planner.forage_demand_enabled_count()


func _read_weather() -> void:
	"""Copy §5.10's committed temperature in tenths of a degree. Integer, as the store holds it."""
	if _weather == null:
		return
	_current[FIELD_TEMPERATURE_TENTHS] = _weather.temperature_tenths()


# --- integer reads: the committed truth, copied ------------------------------------------------

func value_of(field: int) -> IntMath.IntResult:
	"""One captured field's committed integer. See `value_into()`; this form allocates one result."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	value_into(field, out)
	return out


func value_into(field: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating `value_of()`. Refuses an invalid field, an unbound source or a hidden layer.

	The value handed back is a COPY of a captured integer. Nothing the caller does to `out` can
	reach this snapshot, and nothing in this snapshot can reach the store it was read from.
	"""
	var refusal: StringName = _read_refusal(field)
	if refusal != REFUSE_NONE:
		return out.refuse(String(refusal))
	return out.succeed(_current[field])


func previous_value_into(field: int, out: IntMath.IntResult) -> bool:
	"""The same field as of the PREVIOUS capture, which interpolation starts from."""
	var refusal: StringName = _read_refusal(field)
	if refusal != REFUSE_NONE:
		return out.refuse(String(refusal))
	if _previous_tick == NO_CAPTURE_TICK:
		return out.refuse(String(REFUSE_NO_PREVIOUS_CAPTURE))
	return out.succeed(_previous[field])


func _read_refusal(field: int) -> StringName:
	"""Every gate a captured read passes, in the order a caller can act on them."""
	if field < 0 or field >= FIELD_COUNT:
		return REFUSE_INVALID_FIELD
	if _current_tick == NO_CAPTURE_TICK:
		return REFUSE_NO_CAPTURE
	if _available[field] == 0:
		return REFUSE_SOURCE_NOT_BOUND
	if _layer_visible[FIELD_LAYER[field]] == 0:
		return REFUSE_LAYER_HIDDEN
	return REFUSE_NONE


# --- the float boundary ------------------------------------------------------------------------

func interpolate_into(field: int, alpha_milli: int, out: FloatRead) -> bool:
	"""Interpolate one field between the two committed captures. THE ONLY FLOAT THIS CODEBASE MAKES.

	`alpha_milli` is the renderer's position between the previous and current capture, 0..1000.
	Both endpoints are committed integers; the float is computed here and stored nowhere, so no
	gameplay outcome can depend on it. A field with only one capture behind it refuses rather
	than extrapolating, because a frame drawn from a guess is a frame that shows a lie.
	"""
	var refusal: StringName = _read_refusal(field)
	if refusal != REFUSE_NONE:
		return out.refuse(refusal)
	if alpha_milli < ALPHA_MIN or alpha_milli > ALPHA_MAX:
		return out.refuse(REFUSE_INVALID_ALPHA)
	if _previous_tick == NO_CAPTURE_TICK:
		return out.refuse(REFUSE_NO_PREVIOUS_CAPTURE)
	var from: float = float(_previous[field])
	var to: float = float(_current[field])
	return out.succeed(from + (to - from) * (float(alpha_milli) / float(ALPHA_MAX)))


# --- layer visibility: presentation filtering, and nothing else --------------------------------

func set_layer_visible(layer: int, visible: bool) -> bool:
	"""Show or hide one presentation layer. Touches ONE byte in this object and no store at all.

	Hiding is a filter on what this snapshot will REPORT. The captured value stays exactly where
	it was, the next `capture()` still records the true one, and no authoritative column is
	reachable from here to be changed.
	"""
	if not is_layer(layer):
		return _refuse(REFUSE_INVALID_LAYER)
	_layer_visible[layer] = 1 if visible else 0
	_last_refusal = REFUSE_NONE
	return true


func is_layer(layer: int) -> bool:
	"""True when this index names one of the six presentation layers."""
	return layer >= 0 and layer < LAYER_COUNT


func is_field(field: int) -> bool:
	"""True when this index names one of the fourteen captured fields."""
	return field >= 0 and field < FIELD_COUNT


func is_layer_visible(layer: int) -> bool:
	"""True while this layer's fields are reported. False for a hidden or unknown layer."""
	return is_layer(layer) and _layer_visible[layer] == 1


func is_field_available(field: int) -> bool:
	"""True when this field's source was bound at construction."""
	return is_field(field) and _available[field] == 1


func layer_of(field: int) -> IntMath.IntResult:
	"""The layer a field draws on, or a refusal for an index that names no field."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_field(field):
		out.refuse(String(REFUSE_INVALID_FIELD))
		return out
	out.succeed(FIELD_LAYER[field])
	return out


# --- readers -----------------------------------------------------------------------------------

func captured_tick() -> IntMath.IntResult:
	"""The tick the current frame was captured at. REFUSES before the first capture.

	A refusal rather than 0: tick 0 is a real tick and returning it would be a sentinel.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if _current_tick == NO_CAPTURE_TICK:
		out.refuse(String(REFUSE_NO_CAPTURE))
		return out
	out.succeed(_current_tick)
	return out


func previous_captured_tick() -> IntMath.IntResult:
	"""The tick the previous frame was captured at, or a refusal when there is only one."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if _previous_tick == NO_CAPTURE_TICK:
		out.refuse(String(REFUSE_NO_PREVIOUS_CAPTURE))
		return out
	out.succeed(_previous_tick)
	return out


func capture_count() -> int:
	"""Frames captured since the last `clear()`. Zero before the first."""
	return _capture_count


func snapshot_bytes() -> int:
	"""Exact mutable bytes this snapshot owns, for the ARCH-MEM ledger it is budgeted in."""
	return FIELD_COUNT * 8 * 2 + FIELD_COUNT + LAYER_COUNT


func last_refusal() -> StringName:
	"""Reason the most recent refused operation was refused; empty after a successful one."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record a refusal code and return false, so callers can `return _refuse(...)`."""
	_last_refusal = code
	return false
