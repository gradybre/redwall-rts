extends RefCounted
## ARCH-SYS-005 Ecology: the daily orchestrator for the four ecology stores, and nothing else.
##
## Task 03 increment 9. Every ecology store already existed and NOTHING ADVANCED ANY OF THEM:
## `resource_nodes.gd`, `forage.gd`, `fishing.gd` and `orchard_hive.gd` each publish a daily
## operation and each says in its own header that ARCH-SYS-005 owns the midnight call. This file
## is that owner. It creates no state of its own beyond a day guard and per-day scratch.
##
## ---------------------------------------------------------------------------------------
## THIS IS ONE LEG OF REQ-SET-007, NOT THE BOUNDARY. REQ-SET-007 reads "age stocks, update
## ecology, advance crops/weather, process immigration/departures, then evaluate progression IN
## THAT ORDER". This module implements the SECOND leg only:
##   * AGE STOCKS is the inventory group's (ARCH-SYS-004). Nothing here touches an InventoryLot,
##     a lot age or a spoilage intent.
##   * ADVANCE CROPS/WEATHER is ARCH-SYS-006, task 03 increment 10. `farming.gd` and `weather.gd`
##     are NOT composed here, `apply_orchard_day()` is NOT called here (it needs the day's
##     temperature, which is weather's), and no crop, moisture or forecast value is read.
##   * IMMIGRATION/DEPARTURES and PROGRESSION have no store at all.
## `settlement_system.gd` sequences the five legs and publishes which of them actually ran; this
## module is called from exactly one place in it and never re-orders anything.
##
## ---------------------------------------------------------------------------------------
## THE BOUNDARY IS THE OFFSET CALENDAR'S, AND IS NEVER RE-DERIVED. `run_day_into()` takes a TICK
## and gates it on `sim_clock.gd`'s own `is_day_boundary()`, which stays the single definition of
## a crossing: tick 13500 is the first midnight and tick 18000 is 06:00 of day 2 and is refused.
## Every calendar field the legs need -- absolute day, season, season-day -- is then decoded from
## that one tick by `SimClock.calendar_at_into()`, so no leg can run on a season one caller
## believed and another computed. `midnight_tick_of_day_into()` is the inverse, and it is CHECKED
## against `is_day_boundary()` before it is returned rather than trusted.
##
## IDEMPOTENCE IS A LATCH, NOT A HOPE. `_last_day` records the last absolute day consumed and a
## day at or before it is REFUSED with `ECOLOGY_DAY_ALREADY_RUN`. Without it, a second call for
## one day would charge a hive two days of missed service, recover every fish stock twice and
## reset the forage day's collected totals under a claim that had already collected against them.
## The latch is raised BEFORE the legs run, deliberately: a leg that refuses half way leaves the
## legs before it already committed, and re-running the day would apply those twice. A refusal is
## therefore reported and the day is still consumed; `last_day_run()` reports the day either way.
##
## ---------------------------------------------------------------------------------------
## LEG ORDER, and why it is the order it is. ARCH-SYS-005's §5 row writes "Stock growth, quotas,
## migration, resource regrowth, ecology events", and that is the order below.
##   1. §5.4 FISH. `reset_harvested_today()` zeroes the daily quota accumulator, then
##      `recover_daily()` applies `P'=min(K,P+floor(r*P*(K-P)/(1000*K))+floor(K/200))` to EVERY
##      stock. A CLOSED species still recovers -- §5.4 says "closed means no harvest job, not zero
##      population" -- and salmon's autumn day-1 restock and decision 0037's 30/40 restocking
##      latch are inside that sweep, where `fishing.gd` owns them.
##   2. §5.5 FORAGE. Decision 0036's ADDITIVE regrowth first (`regrow_daily`), then decision 0030
##      §4.4's ruled quota order (`run_midnight`): reset collected totals, PRESERVE outstanding
##      claims, apply the seasonal/automatic quota change, release closure-invalidated claims and
##      reconcile the excess. Both halves are `forage.gd`'s; the ORDER OF THE TWO CALLS is this
##      module's, and it is stock-before-quota because §4.4's reconciliation measures claims
##      against the new day's allowance and a caller admits or collects only after it.
##   3. §5.6 HIVES. One completed hive day each: REQ-SET-083's 200-strength unserved loss, the
##      winter feed draw and its 500-strength unfed loss, spring's tended gain, and abandonment.
##      Decision 0044's per-recipient pollination links refresh SYNCHRONOUSLY inside
##      `orchard_hive.gd` whenever a committed strength change crosses the 5000 eligibility line;
##      nothing here repairs a link, and no yield read is used to repair one.
##   4. §5.9 RESOURCE NODES. Every exhausted renewable node whose `planted_day + regrow_days` has
##      arrived is restored to capacity.
##   5. ANNUAL COUNTERS, at the YEAR boundary only (decision 0030 §4.4: "annual patch counters
##      reset only at the existing year boundary"). They are NOT reset at an ordinary midnight.
## Legs 1-4 touch disjoint stores and disjoint columns, so no leg can observe another's result;
## the order is fixed for determinism and for the record, not because a value depends on it.
##
## ---------------------------------------------------------------------------------------
## THE HIVE DAY IS THE COMPLETED DAY, EVERY OTHER LEG IS THE NEW DAY. ARCH-TICK-002 puts
## accumulated boundary effects at the crossing and ARCH-TICK-003 says "ecology uses the new
## calendar day's season", which is what legs 1, 2, 4 and 5 do. A hive is different in kind: its
## day is JUDGED ON THE SERVICE IT RECEIVED, `record_hive_service()` stamps the day the work
## happened, and `apply_hive_day_into()` is documented as "one COMPLETED day". Passing the day now
## beginning would find every hive unserviced and charge 200 strength every single day forever, so
## the hive leg passes `absolute_day - 1`. `orchard_hive.gd`'s own `apply_orchard_day()` reads the
## same way, which is the second witness for it.
##
## ---------------------------------------------------------------------------------------
## DEPENDENCIES THIS MODULE REFUSES TO INVENT AROUND -- named, not worked around.
##   * REQ-SET-138's "no building occupies the tile" CANNOT BE EVALUATED. `resource_nodes.gd`
##     records that it reads `WorldTileMaps.building_slot`, which no store owns, and that the
##     ecology system must apply the occupancy condition before calling `regrow()`. NO STORE CAN
##     ANSWER IT TODAY, so leg 4 applies the DAY CONDITION ALONE, exactly as the store computes
##     it. Fabricating an occupancy test here would be inventing the building layer.
##   * THE FARM SIDE OF THE POLLINATION REFRESH IS NOT DONE HERE. `orchard_hive.gd` refreshes
##     every ORCHARD recipient itself on an eligibility crossing, but a FarmPlot's tile lives in
##     `farming.gd` and that store is deliberately not visible from here; decision 0044 gives the
##     `(farm_row, tile_x, tile_z)` join to the owner of the crop layer, which is ARCH-SYS-006,
##     task 03 increment 10. This module does not reach into `farming.gd` to do it early.
##   * NO JOB IS CREATED OR ADVANCED. `job_planner.gd` is not called from here, no Job row is
##     written, and JOB_STATE_WORK is never set. R06-JOB-001/002/003/006's producers are their
##     own layer; a forage claim released by leg 2 is released by `forage.gd`'s ruled order and
##     generates no work, cargo or refund.
##   * NO WILDLIFE-PRESSURE EVENT IS ROLLED. §8's ECOLOGY RNG stream asks for "one
##     wildlife-pressure roll per eligible summer/autumn basin/apiary at midnight". No store
##     models wildlife pressure, no eligibility predicate exists for it and no magnitude is
##     stated anywhere, so no draw is taken -- taking one would consume a deterministic stream
##     for an effect that does not exist.
##   * NO SAVE OR CHECKPOINT. ARCH-SYS-022 has no save stream, so `_last_day` -- the idempotence
##     latch -- has no persisted form and a CROSS-PROCESS round trip of the ecology day cannot be
##     verified. Within one process it is tested; across two it is blocked on the save module.
##
## ---------------------------------------------------------------------------------------
## ALLOCATION. `run_day_into()` is called once per SIMULATED DAY, never per tick, and the tick
## path only calls `SimClock.is_day_boundary()` inside `settlement_system.gd`. This module's own
## per-day cost is zero: the Calendar, the IntResult and the HiveDayResult are instance scratch,
## and `_read` is consumed before the next call that writes it. It calls four functions that
## allocate INSIDE stores this task does not own, each their published contract, and each named
## here rather than claimed away:
##   * `fishing.recover_daily()`   one OpResult per day.
##   * `forage.regrow_daily()` and `forage.run_midnight()` one OpResult each per day, plus the
##     OpResults `run_midnight()` builds internally for its reconciliation.
##   * `resource_nodes.regrow()`   ONE OpResult PER NODE ACTUALLY REGROWN. `resource_nodes.gd`
##     publishes no `_into` form of it; the ready TEST is allocation-free
##     (`is_regrow_ready_into`), so a day on which nothing regrows costs nothing. Reported, and
##     not fixed by editing a file this task does not own.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const ResourceNodesScript := preload("res://scripts/core/resource_nodes.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"
const REFUSE_INVALID_DAY: StringName = &"INVALID_ABSOLUTE_DAY"
const REFUSE_NOT_DAY_BOUNDARY: StringName = &"NOT_A_DAY_BOUNDARY"
const REFUSE_DAY_ALREADY_RUN: StringName = &"ECOLOGY_DAY_ALREADY_RUN"

## §4.3 Season, read from the compiled catalog rather than restated as a literal.
const SEASON_SPRING: int = Catalog.SEASON["SPRING"]
## First day of a season (GDD §5.1 counts season days from 1), so spring day 1 opens a year.
const FIRST_SEASON_DAY: int = 1
## Day 1 is the first calendar day; a hive has no completed day before it.
const MIN_CALENDAR_DAY: int = 1
## `_last_day` before any day has been consumed. Day numbering starts at 1, so 0 names no day.
const NO_DAY_RUN: int = 0


class DayResult:
	"""One completed ecology day: which day it was, and what each leg actually changed.

	`.ok` MUST be inspected before any count is read. A refusal clears every field, so an
	unchecked result cannot surface a previous day's numbers as if they were this day's.
	"""
	var ok: bool
	var error: StringName
	var boundary_tick: int
	var absolute_day: int
	var season: int
	var season_day: int
	var fish_stocks_recovered: int
	var forage_patches_grown: int
	var forage_claims_released: int
	var hives_advanced: int
	var hives_abandoned: int
	var hive_eligibility_crossings: int
	var nodes_regrown: int
	var annual_counters_reset: bool

	func _init() -> void:
		"""Start cleared; every field is written by the day step before it returns."""
		clear()

	func clear() -> void:
		"""Return every field to its empty value, so nothing survives from a previous day."""
		ok = false
		error = REFUSE_NONE
		boundary_tick = 0
		absolute_day = 0
		season = 0
		season_day = 0
		fish_stocks_recovered = 0
		forage_patches_grown = 0
		forage_claims_released = 0
		hives_advanced = 0
		hives_abandoned = 0
		hive_eligibility_crossings = 0
		nodes_regrown = 0
		annual_counters_reset = false

	func refuse(code: StringName) -> bool:
		"""Record a refusal that carries no counts. Always returns false."""
		clear()
		error = code
		return false


# --- the four ecology stores, composed once and never reallocated -----------------------------

var _directory: EntityDirectory = null
var _nodes: ResourceNodesScript = null
var _forage: ForageScript = null
var _fishing: FishingScript = null
var _orchard_hive: OrchardHiveScript = null

# --- the idempotence latch --------------------------------------------------------------------

var _last_day: int = NO_DAY_RUN

# --- per-day scratch (not simulation state) ---------------------------------------------------

var _calendar: SimClock.Calendar = SimClock.Calendar.new(0)
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _hive_day: OrchardHiveScript.HiveDayResult = OrchardHiveScript.HiveDayResult.new()


func _init(p_directory: EntityDirectory = null, p_jobs: JobsScript = null) -> void:
	"""Compose the four ecology stores over one directory so every reference validates once.

	A Job store may be supplied; `forage.gd` needs it to own forage claims and adopts its
	directory, and `fishing.gd` takes the same pair. Passing neither builds a private directory,
	which is what a standalone fixture wants.
	"""
	_assert_calendar_contracts()
	_directory = _adopt_directory(p_directory, p_jobs)
	_nodes = ResourceNodesScript.new(_directory)
	_forage = ForageScript.new(_directory, p_jobs)
	_fishing = FishingScript.new(_directory, _forage, p_jobs)
	_orchard_hive = OrchardHiveScript.new(_directory)


func _adopt_directory(p_directory: EntityDirectory, p_jobs: JobsScript) -> EntityDirectory:
	"""Adopt the caller's directory, else the Job store's, else build a private one."""
	if p_directory != null:
		return p_directory
	if p_jobs != null:
		return p_jobs.directory()
	return EntityDirectory.new()


func _assert_calendar_contracts() -> void:
	"""Prove the two calendar facts the year-boundary test hangs off, rather than trusting them."""
	assert(SimClock.SEASON_NAMES[SEASON_SPRING] == "spring",
		"SEASON_SPRING must index the calendar's spring, which opens a year")
	assert(SimClock.calendar_at(SimClock.FIRST_MIDNIGHT_TICK).absolute_day == 2,
		"the first offset-calendar midnight must open absolute day 2")
	assert(SimClock.DAYS_PER_YEAR == SimClock.DAYS_PER_SEASON * SimClock.SEASONS_PER_YEAR,
		"a year must be exactly its four seasons, or the year boundary is not spring day 1")


func clear() -> void:
	"""Empty every ecology store and drop the day latch, without reallocating a column."""
	_nodes.clear()
	_forage.clear()
	_fishing.clear()
	_orchard_hive.clear()
	_last_day = NO_DAY_RUN


# --- the daily stage ---------------------------------------------------------------------------

func run_day(boundary_tick: int) -> DayResult:
	"""Run one ecology day. See run_day_into(); this form allocates one result."""
	var out: DayResult = DayResult.new()
	run_day_into(boundary_tick, out)
	return out


func run_day_into(boundary_tick: int, out: DayResult) -> bool:
	"""ARCH-SYS-005's whole daily stage at one offset-calendar midnight, into caller-owned `out`.

	`boundary_tick` must be a real crossing of `(tick + 4500) mod 18000`, taken from the clock:
	`tick % 18000 == 0` names 06:00 and is refused here. The day is consumed before the legs run,
	so a refused leg cannot be replayed on top of the legs that already committed.
	"""
	out.clear()
	if boundary_tick < 0:
		return out.refuse(REFUSE_INVALID_TICK)
	if not SimClock.is_day_boundary(boundary_tick):
		return out.refuse(REFUSE_NOT_DAY_BOUNDARY)
	SimClock.calendar_at_into(boundary_tick, _calendar)
	if _calendar.absolute_day <= _last_day:
		return out.refuse(REFUSE_DAY_ALREADY_RUN)
	_last_day = _calendar.absolute_day
	out.boundary_tick = boundary_tick
	out.absolute_day = _calendar.absolute_day
	out.season = _calendar.season
	out.season_day = _calendar.season_day
	if not _run_legs(out):
		return false
	out.ok = true
	return true


func _run_legs(out: DayResult) -> bool:
	"""The five ecology legs in ARCH-SYS-005's stated write order. See the header for why."""
	if not _recover_fish(out):
		return false
	if not _grow_forage(out):
		return false
	if not _advance_hives(out):
		return false
	if not _regrow_resource_nodes(out):
		return false
	_reset_annual_counters(out)
	return true


func _recover_fish(out: DayResult) -> bool:
	"""§5.4 midnight: zero the daily quota accumulator, then recover EVERY stock, closed included.

	The reset is first for the same reason decision 0030 §4.4 puts it first for forage: the
	quota a caller admits against today is measured on a total that must not still hold
	yesterday's catch. Recovery reads no quota, so the two cannot fight.
	"""
	_fishing.reset_harvested_today()
	var recovered: FishingScript.OpResult = _fishing.recover_daily(
		_calendar.season, _calendar.season_day)
	if not recovered.ok:
		return out.refuse(recovered.error)
	out.fish_stocks_recovered = recovered.value
	return true


func _grow_forage(out: DayResult) -> bool:
	"""§5.5 midnight: decision 0036's additive regrowth, then decision 0030 §4.4's quota order.

	`run_midnight()` receives the SAME tick this stage was gated on, so it re-checks the identical
	boundary rather than a second opinion about which tick midnight is.
	"""
	var grown: ForageScript.OpResult = _forage.regrow_daily(_calendar.season)
	if not grown.ok:
		return out.refuse(grown.error)
	out.forage_patches_grown = grown.value
	var midnight: ForageScript.OpResult = _forage.run_midnight(_calendar.tick, _calendar.season)
	if not midnight.ok:
		return out.refuse(midnight.error)
	out.forage_claims_released = midnight.value
	return true


func _advance_hives(out: DayResult) -> bool:
	"""§5.6/REQ-SET-083: settle the COMPLETED day for every live hive, in ascending slot order.

	`absolute_day - 1` is the day being settled -- see the header. Day 1 has no completed day
	before it, and the clock raises no boundary for it either, so the guard is belt and braces.
	An eligibility crossing is COUNTED here and REFRESHED inside `orchard_hive.gd`; this loop
	never touches a pollination link.
	"""
	var completed_day: int = _calendar.absolute_day - 1
	if completed_day < MIN_CALENDAR_DAY:
		return true
	for slot: int in OrchardHiveScript.HIVE_CAPACITY:
		if not _orchard_hive.is_hive_present(slot):
			continue
		if not _orchard_hive.apply_hive_day_into(
				_orchard_hive.hive_ref_of(slot), completed_day, _hive_day):
			return out.refuse(_hive_day.error)
		out.hives_advanced += 1
		if _hive_day.abandoned:
			out.hives_abandoned += 1
		if _crossed_eligibility(_hive_day):
			out.hive_eligibility_crossings += 1
	return true


func _crossed_eligibility(day: OrchardHiveScript.HiveDayResult) -> bool:
	"""True when this hive day moved its strength across decision 0044's 5000 eligibility line."""
	var was_eligible: bool = day.strength_before >= OrchardHiveScript.HIVE_HEALTHY_STRENGTH
	var is_eligible: bool = day.strength_after >= OrchardHiveScript.HIVE_HEALTHY_STRENGTH
	return was_eligible != is_eligible


func _regrow_resource_nodes(out: DayResult) -> bool:
	"""§5.9/REQ-SET-138: restore every exhausted node whose regrowth date has arrived.

	The DAY condition only. REQ-SET-138 also requires that no building occupies the tile, and no
	store can answer that -- see the header. A node that is not exhausted, that never regrows
	(`regrow_days == 0`) or whose date has not arrived is skipped, and none of those is an error.
	"""
	for slot: int in ResourceNodesScript.RESOURCE_NODE_CAPACITY:
		if not _nodes.is_present(slot):
			continue
		if not _nodes.is_regrow_ready_into(slot, _calendar.absolute_day, _read):
			continue
		if _read.value != 1:
			continue
		var regrown: ResourceNodesScript.OpResult = _nodes.regrow(slot, _calendar.absolute_day)
		if not regrown.ok:
			return out.refuse(regrown.error)
		out.nodes_regrown += 1
	return true


func _reset_annual_counters(out: DayResult) -> void:
	"""Decision 0030 §4.4: annual patch counters reset at the YEAR boundary, never at a midnight.

	A year opens on spring day 1, which the offset calendar decodes for us; day 1 of year 1 is
	06:00 and raises no boundary, so the first reset is the midnight opening absolute day 49.
	`orchard_hive.gd` clears its own annual harvest flag inside `apply_orchard_day()`, which is
	ARCH-SYS-006's call and not this one's -- it is not reset here.
	"""
	if _calendar.season != SEASON_SPRING or _calendar.season_day != FIRST_SEASON_DAY:
		return
	_forage.reset_harvested_year()
	out.annual_counters_reset = true


# --- the boundary inverse ----------------------------------------------------------------------

static func midnight_tick_of_day_into(absolute_day: int, out: IntMath.IntResult) -> bool:
	"""The tick at which `absolute_day` opens: `(day-1)*18000 - 4500`, checked and then GATED.

	The result is passed through `sim_clock.gd`'s own `is_day_boundary()` before it is returned,
	so this inverse can never disagree with the single definition of a crossing -- a wrong answer
	refuses instead of travelling. Day 1 opens at tick -4500 under the offset calendar, which is
	06:00 of day 1 and no crossing at all, so day 1 and earlier are refused: the clock's first
	boundary is day 2 at tick 13500.
	"""
	if absolute_day <= 0:
		return out.refuse(String(REFUSE_INVALID_DAY))
	if not IntMath.checked_mul_into(absolute_day - 1, SimClock.TICKS_PER_DAY, out):
		return false
	if not IntMath.checked_add_into(out.value, -SimClock.CALENDAR_OFFSET_TICKS, out):
		return false
	if not SimClock.is_day_boundary(out.value):
		return out.refuse(String(REFUSE_NOT_DAY_BOUNDARY))
	return true


# --- readers ------------------------------------------------------------------------------------

func last_day_run() -> int:
	"""Absolute day this stage last CONSUMED, refused legs included; 0 before the first day."""
	return _last_day


func directory() -> EntityDirectory:
	"""The allocator behind every ecology reference."""
	return _directory


func resource_nodes() -> ResourceNodesScript:
	"""The §5.9 tree, stone and iron node store."""
	return _nodes


func forage() -> ForageScript:
	"""The §5.5 HarvestZone, ForagePatch and forage-claim store."""
	return _forage


func fishing() -> FishingScript:
	"""The §5.4 FishHabitat, stock and effort-claim store."""
	return _fishing


func orchard_hive() -> OrchardHiveScript:
	"""The §5.6 OrchardPlot, Hive and pollination-link store. ARCH-SYS-006 borrows this."""
	return _orchard_hive
