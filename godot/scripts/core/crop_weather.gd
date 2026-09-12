extends RefCounted
## ARCH-SYS-006 CropWeather: the TWO-CADENCE orchestrator for the crop and weather stores.
##
## Task 03 increment 10, the last of the group. `farming.gd`, `weather.gd` and `orchard_hive.gd`
## all existed and NOTHING ADVANCED ANY CROP OR ANY DAY OF WEATHER: `farming.gd` says in its own
## header that it reads no weather and creates no job, `weather.gd` says "ARCH-SYS-006 owns the
## ordering -- season advance, schedule, disclose, refresh, end -- and this module wires no tick",
## and `orchard_hive.gd` says `apply_orchard_day()` needs the day's temperature, which is
## weather's. This file is that owner. It creates no simulation column of its own: it composes
## `farming.gd` and `weather.gd`, borrows `ecology.gd`'s `orchard_hive.gd` and the ARCH-RNG-002
## stream set, and holds two idempotence latches plus per-cadence scratch.
##
## ---------------------------------------------------------------------------------------
## ARCH-SYS-006 HAS TWO CADENCES AND THEY ARE NOT THE SAME STAGE. Its §5 row reads "Hourly crop
## integration; midnight after Ecology". Both halves are here and both are separately callable,
## separately latched and separately tested:
##   * `run_hour_into(tick, out)` -- gated on `is_hour_boundary()`, `(tick + 4500) mod 750 == 0`.
##   * `run_day_into(boundary_tick, crossings, out)` -- gated on `sim_clock.gd`'s OWN
##     `is_day_boundary()`, which stays the single definition of a midnight crossing.
## A midnight tick IS an hour boundary (18000 = 24 x 750), so BOTH run at it, in that order:
## `settlement_system.gd` calls the hourly leg inside `run_tick()` and the daily leg from the
## clock's day-boundary callback, which fires after the tick completes. That order is
## ARCH-TICK-003's: "crop hourly growth uses the elapsed hour's climate, followed by new-day
## weather/moisture/service reset". ARCH-TICK-002's "never perform a second pass just because the
## same tick is both hourly and daily" is satisfied because the two legs share no step: growth,
## frost and ripe expiry are hourly ONLY; season, event, forecast, moisture, blight, the orchard
## day and the service reset are daily ONLY.
##
## ---------------------------------------------------------------------------------------
## THIS IS ONE LEG OF REQ-SET-007, AND IT RUNS AFTER ECOLOGY'S. REQ-SET-007 is "age stocks,
## update ecology, advance crops/weather, process immigration/departures, then evaluate
## progression IN THAT ORDER". This module implements the THIRD leg only:
##   * AGE STOCKS (ARCH-SYS-004) has no owner; nothing here touches an InventoryLot or a lot age.
##   * UPDATE ECOLOGY is `ecology.gd`'s (ARCH-SYS-005, decision 0046) and ALREADY RUNS. This
##     module never calls it, never re-runs a fish, forage, hive or resource-node leg, and reads
##     the ecology only for `orchard_hive.gd` and §5.1's tile geometry.
##   * IMMIGRATION/DEPARTURES and PROGRESSION have no store at all.
## `settlement_system.gd` sequences the legs and publishes which ones actually ran through
## `daily_leg_at()`/`daily_leg_count()`; this stage is appended to the SAME log increment 9 built,
## after ecology's, so a reordering is a failing test rather than a comment.
##
## ---------------------------------------------------------------------------------------
## THE DAY'S ORDER, AND WHY EACH STEP SITS WHERE IT DOES.
##   0. THE PRECEDING INTERVAL'S ELAPSED HOURS are already integrated when the daily leg runs.
##      A midnight tick IS an hour crossing, `settlement_system.gd` calls `run_hour_into()` from
##      `run_tick()` and this leg from the clock's day-boundary callback, which fires AFTER that
##      tick completes -- so the 00:00 hour of the crossing has been grown at the OLD day's
##      climate before any step below touches the row. Ruling §4.3's "the preceding hour still
##      uses summer climate" at the autumn-day-1 crossing IS that ordering. It is REPORTED rather
##      than assumed: `DayResult.elapsed_hour_tick` publishes the hour this stage had consumed
##      when the boundary opened, so a wiring that ran the legs the other way round is a failing
##      assertion and not a comment. No refusal is added, because the standalone daily fixture and
##      `prime_day()` legitimately open a day no hour has been simulated for.
##   1. COMPLETED-DAY BLIGHT (REQ-SET-087). 400 health/day, 200 while tended. It settles the day
##      that ENDED, with that day's tending flags still standing and the completed day's event
##      window -- exactly as `ecology.gd` settles a hive's COMPLETED day (decision 0046 §2).
##      Applying it to the day now beginning would read a tending flag nobody has had a chance to
##      set, so the stated 200 would be unreachable and every blighted plot would always take 400.
##   2. ORCHARD DAY (§5.6). `apply_orchard_day(ref, absolute_day - 1, temperature_tenths)`, again
##      the COMPLETED day, at the temperature the row still holds for it -- the winter chill
##      counter counts days at or below 5 C, and the day it must judge is the one that ended.
##      It therefore runs BEFORE the new day's `refresh_daily()` overwrites the temperature.
##   3. NEW-DAY WEATHER (§5.10, REQ-SET-141/142/145). End an event whose window has passed,
##      schedule this season's event if it has not been scheduled, disclose a due forecast, then
##      write the day's baseline temperature and rain.
##   4. THE MUSSEL EVENT CLOSURE (ruling 2026-09-11 §4.1). Every PRESENT mussel stock's
##      `FishStock.closed` event bit is set to `new_season == SUMMER && active_new_day_event ==
##      BLIGHT` and to FALSE otherwise -- including autumn blight and the day after expiry. It
##      runs immediately after step 3 because it reads the new day's weather, and well before
##      `settlement_system.gd` reaches `_run_planner_day()`, which is ruling §4.1's "before later
##      job planning". See the ownership note below.
##   5. NEW-DAY MOISTURE (§5.10, REQ-SET-086). ARCH-TICK-003 names it "new-day ... moisture", so
##      it uses the weather step 3 just wrote.
##   6. SERVICE RESET. `clear_tended_today()` over the whole TileHistory ledger, AFTER step 1 has
##      spent the completed day's flags. ARCH-TICK-003's "service reset".
##   7. THE FARM SIDE OF THE POLLINATION REFRESH (decision 0044). See below.
## Steps 1 and 2 are the completed day; steps 3-6 are the day that began. Step 7 is neither -- it
## is the continuation of a change ARCH-SYS-005 committed one call earlier.
##
## ---------------------------------------------------------------------------------------
## NOTHING PARTIALLY ADVANCES: THE BOUNDARY IS PREFLIGHTED (ruling §4.1). Season identity, the
## WEATHER stream and the two catalogs this boundary reads are checked BEFORE the day latch is
## consumed and before any step commits. A scheduling refusal is a failure carrying a diagnostic
## -- `DayResult.error` and `last_refusal()` -- and is explicitly NOT permission to clear some
## state and publish an apparently completed tick: `run_day_into()` returns false with a cleared
## result and the day is not marked run, so the caller sees a refusal rather than a quiet day.
##   * SEASON IDENTITY. `absolute_season = floor((absolute_day-1)/12)` must decode, and
##     `absolute_season % 4` must equal the season the clock decoded for the same tick. A
##     disagreement refuses SEASON_IDENTITY_MISMATCH rather than running one leg per opinion.
##   * RNG. Only when this boundary would actually draw -- a season not yet scheduled that is not
##     the forced first spring -- the stream must be bound AND seeded. The forced first spring
##     still opens on an unseeded world, because it takes no Rng at all.
##   * CATALOGS. `weather.catalog_is_verified()` and `fishing.catalog_is_verified()` prove
##     §4.3's EventDefinition and HabitatType ids are still what the compiled tables assume.
##
## ---------------------------------------------------------------------------------------
## THE PIECE INCREMENT 9 LEFT HERE: THE FarmPlot SIDE OF DECISION 0044's REFRESH.
## `orchard_hive.gd` refreshes every ORCHARD recipient itself on any hive change, and states that
## it CANNOT refresh farm recipients: a FarmPlot's tile lives in `farming.gd`, which that store
## deliberately never reads, so the owning join must pass `(farm_row, tile_x, tile_z)` to
## `refresh_farm_links()`. This module is the only place both stores are visible, so it makes the
## join, and it makes it in the two places a committed change demands:
##   * `create_plot_at_tile()` and `destroy_plot()` -- the FarmPlot lifecycle. Ruling §3 requires
##     the owner lifecycle to clear its slice "including on typed-slot reuse"; `clear_farm_links()`
##     before `farming.destroy()` is that obligation discharged, and a new plot's slice is
##     computed before the row is handed back, so no read can ever see an unrefreshed one.
##   * `run_day_into(..., hive_eligibility_crossings, ...)` -- when ARCH-SYS-005's hive leg moved
##     a hive across the 5000 line ONE CALL EARLIER in the same boundary. Nothing runs between the
##     two legs, so the refresh is still synchronous with the committed change in the only sense
##     that matters: no dependent simulation read can be interleaved. `ecology.gd` already
##     refreshed the ORCHARD recipients of that same change inside `orchard_hive.gd`.
## THE COUNT IS A PARAMETER, NOT A GUESS. It is the number ARCH-SYS-005's own DayResult reports.
## `ecology.gd` publishes no reader for it and this module does not reach into that file to add
## one, so the orchestrator that owns both stages hands it over explicitly. Zero means "the hive
## leg changed nobody's eligibility", and then NOTHING is refreshed -- a blanket daily refresh
## would turn a synchronous discipline into a periodic repair and would hide a missing one.
## NO READ EVER REPAIRS. `check_farm_links_of()` is the pure comparison that proves the discipline
## was honoured, and `orchard_hive.gd`'s yield readers refuse `POLLINATION_LINKS_STALE` rather
## than recomputing. Neither is called to fix anything here.
##
## ---------------------------------------------------------------------------------------
## THE WEATHER DRAW: ONE PER SEASON, ZERO FOR THE FORCED FIRST SPRING, AND ONE LATCH TO PROVE IT.
## ARCH-RNG-002 gives WEATHER "one weighted event-selection roll per new season after the forced
## first spring". THE LATCH MOVED (ruling §4.2, decision 0055). This file used to keep a private
## `_last_scheduled_season`, because §4.2's row carried no season column; the ruled amendment adds
## `Weather.scheduled_absolute_season` as an I64 column and requires ONE owner -- "the existing
## CropWeather latch must agree with it on load, or be replaced by this single owner in one
## migration. No independent extra latch allocation is implied." THE SECOND OPTION WAS TAKEN: the
## private field is GONE, `last_scheduled_season()` reads the Weather column, and `weather.gd`
## itself refuses a second schedule for a season it has already scheduled, before touching the
## stream. There is therefore no pair of latches that can disagree, on load or otherwise.
## The absolute season is still computed by `farming.gd`'s `absolute_season_of_day_into()` at the
## boundary; `weather.gd` publishes the identical `floor((absolute_day-1)/12)` for its own column,
## and `test_weather.gd` asserts the two agree across four years rather than assuming it.
##
## SPRING DAY 1 HAS NO MIDNIGHT, so the season is scheduled at the FIRST BOUNDARY THE SEASON SEES
## rather than on its day 1. The offset calendar opens at 06:00 of day 1 and its first crossing is
## day 2 (tick 13500), so year 1's spring is scheduled at spring day 2 -- four days before the
## forced ideal spell's stated day-6 start and one day before its day-3 forecast, so nothing is
## missed. `prime_day()` is the world generator's entry point for writing day 1's own baseline
## before that first midnight; without it a fresh store reports 0.0 C for the opening 18 hours,
## which is the cleared row rather than spring.
##
## ---------------------------------------------------------------------------------------
## DEPENDENCIES THIS MODULE REFUSES TO INVENT AROUND -- named, not worked around.
##   * IDEAL SPELL'S "crop growth x1.20" IS NOT APPLIED, AND THAT IS A REPORTED GAP, NOT AN
##     OVERSIGHT. `weather.gd` publishes it as `crop_growth_factor_per_1000_of()` and says "the
##     join owns it". The join cannot apply it: REQ-SET-072 requires the fractional progress be
##     RETAINED, `farming.gd` retains it inside `_release_growth_milli_hours()` under a single
##     floor, and `advance_growth_hour_into()` accepts no growth factor. Multiplying its returned
##     total afterwards would floor twice and discard the remainder the requirement says to keep
##     -- BAL-WORK-001 forbids exactly that shape ("one final floor and retained remainder"). It
##     is exact ONLY because every §5.6 factor happens to be a multiple of 100, which decision
##     0032 already flagged as a coincidence rather than a contract. The fix is one per-1000
##     parameter on `farming.advance_growth_hour_into()`, in a file this increment does not own.
##   * DROUGHT'S "water 2 U/day" ORCHARD CARE IS NOT CHARGED. `weather.needs_orchard_water()`
##     reports the condition and `apply_orchard_day()` takes no water argument; the cost is an
##     `inventory.gd` lot and a care job, and neither store is joined here.
##   * MUSSEL'S SUMMER BLIGHT CLOSURE IS NOW WRITTEN HERE, AND THE CONTRADICTION IS RESOLVED.
##     `fishing.gd` said in one comment that joining weather to the fishery is "ARCH-SYS-006's job
##     (increment 10)" and in another, on `set_closed()`, that "ARCH-SYS-005 owns any daily
##     orchestration that would write the bit". Ruling 2026-09-11 §4.1 settles it: "ARCH-SYS-006
##     owns the weather-to-fishery join and writes the existing `FishStock.closed` event bit."
##     BOTH comments were amended and ARCH-SYS-006's §5 Reads/Writes row now names the column.
##     SYS-005 keeps fish stock and quota recovery on the NEW day's season, closed stocks
##     included, and copies no event state: `ecology.gd` writes no `closed` bit at all, which
##     `test_ecology.gd` asserts against a stock it closed beforehand.
##     THE EVENT BIT HAS EXACTLY ONE CAUSE. §5.4's calendar closures stay a separate derived
##     predicate -- `is_harvest_closed()` is `calendar_closed || event_closed` -- and nothing else
##     may reuse the bit. A second cause would need a typed reason mask, and ruling §4.1 says
##     adding that mask now is unnecessary, so none is added and none is implied.
##   * NO JOB IS CREATED OR ADVANCED. `job_planner.gd` is not called from here, no Job row is
##     written, and JOB_STATE_WORK is NEVER set. REQ-SET-073's priority-2 harvest job and
##     REQ-SET-085's 10-WU clearing job are state transitions here and producers elsewhere: this
##     stage marks a plot RIPE and marks a plot WITHERED, and creates no work for either.
##   * FieldPolicy's CYCLE IS NOT DRIVEN. `field_policy.gd` is not composed here. Its
##     `record_plot_resolved()` accepts only OUTCOME_HARVESTED or OUTCOME_CLEARED, and both are
##     the completion of a JOB -- `farming.harvest()` and `farming.clear_withered()` -- not a
##     state this stage can observe. A crop reaching RIPE is not a harvest and a crop withering
##     is not a clearing. Resolving a cycle from crop state alone would fabricate the completion
##     the ruling explicitly forbids fabricating, so nothing is half-wired: it needs R06-JOB-005's
##     producer plus the RESERVED -> TRAVEL -> WORK transition of ARCH-SYS-011/012.
##   * NO WORLD SEED EXISTS. `rng.gd` needs `seed_world()` and REQ-SET-009's world generation does
##     not exist, so a settlement whose Rng is unseeded REFUSES the season draw with the stream's
##     own `RNG_NOT_SEEDED` on the first midnight of its second season. It is not defaulted to a
##     number this file invented, and the forced first spring needs no seed at all.
##   * NO SAVE OR CHECKPOINT. ARCH-SYS-022 has no save stream, so neither latch and neither the
##     season nor the hour they hold has a persisted form: idempotence is tested WITHIN one
##     process and a cross-process round trip is BLOCKED on the save module.
##   * A FRESH SETTLEMENT HAS NO PLOTS AND NO ORCHARDS, so both cadences honestly do nothing.
##     World generation places the starter fields (REQ-SET-009) and no world generator exists.
##     Creating a plot here to make the hour look busy would measure a fiction.
##
## ---------------------------------------------------------------------------------------
## ALLOCATION. The HOURLY leg is the hot one, and it allocates NOTHING on an ordinary hour: the
## sweep is a presence scan over `farming.gd`'s 4096-row capacity (its `live_slot_at()` has no
## `_into` form, so the scan is used instead of it), `advance_growth_hour_into()` is
## non-allocating, `is_ripe()`/`is_withered()`/`is_ripe_expired()` are non-allocating bools, and
## the frost branch is skipped for the WHOLE HOUR unless the day's temperature is below 0 C. What
## does allocate, each named rather than claimed away, all inside stores this task does not own:
##   * `farming.apply_frost_hour()`   one OpResult per live plot, ONLY on a subzero day.
##   * `farming.apply_ripe_expiry()`  one OpResult per plot that ACTUALLY withers.
##   * `farming.apply_blight_day()`   one OpResult per live plot, ONLY on a blighted day.
##   * `farming.apply_moisture_delta()` one OpResult per live plot per DAY.
##   * `orchard_hive.apply_orchard_day()` one OpResult per live orchard per DAY.
##   * `farming.tile_of()` and `resource_nodes.tile_x_of()/tile_z_of()` three IntResults per plot
##     whose slice is refreshed -- a lifecycle event, or a day on which a hive crossed the
##     eligibility line. Neither store publishes an `_into` form of them; reported, and not fixed
##     by editing a file this task does not own.
## This module's own Calendar, IntResult, HourResult and DayResult are instance scratch.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Rng := preload("res://scripts/core/rng.gd")
const EcologyScript := preload("res://scripts/core/ecology.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")
const ResourceNodesScript := preload("res://scripts/core/resource_nodes.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"
const REFUSE_INVALID_DAY: StringName = &"INVALID_ABSOLUTE_DAY"
const REFUSE_NOT_DAY_BOUNDARY: StringName = &"NOT_A_DAY_BOUNDARY"
const REFUSE_NOT_HOUR_BOUNDARY: StringName = &"NOT_AN_HOUR_BOUNDARY"
const REFUSE_DAY_ALREADY_RUN: StringName = &"CROP_WEATHER_DAY_ALREADY_RUN"
const REFUSE_HOUR_ALREADY_RUN: StringName = &"CROP_WEATHER_HOUR_ALREADY_RUN"
const REFUSE_INVALID_CROSSINGS: StringName = &"INVALID_ELIGIBILITY_CROSSINGS"
const REFUSE_NO_RNG: StringName = &"WEATHER_STREAM_NOT_BOUND"
const REFUSE_NOT_PRESENT: StringName = &"FARM_PLOT_NOT_PRESENT"
const REFUSE_INVALID_TILE: StringName = &"INVALID_TILE"
## Ruling §4.1's preflight refusals. Each names a required input this boundary could not prove,
## and each is raised BEFORE the day latch is consumed and before any step commits.
const REFUSE_SEASON_IDENTITY_MISMATCH: StringName = &"SEASON_IDENTITY_MISMATCH"
## `rng.gd`'s OWN code, not a local restatement: a preflight that refuses an unseeded stream must
## report exactly what the stream itself would have reported had the draw been attempted.
const REFUSE_RNG_NOT_SEEDED: StringName = Rng.REFUSE_NOT_SEEDED
const REFUSE_EVENT_CATALOG_UNVERIFIED: StringName = &"EVENT_CATALOG_UNVERIFIED"
const REFUSE_FISH_CATALOG_UNVERIFIED: StringName = &"FISH_CATALOG_UNVERIFIED"

## Day numbering starts at 1, so 0 names no day and is what the latch holds before the first one.
const NO_DAY_RUN: int = 0
## Tick 0 is 06:00 of day 1 and no hour crossing, so -1 names no tick the hourly leg could run at.
const NO_HOUR_RUN: int = -1
## "No season yet scheduled", read from `weather.gd`'s own empty value rather than restated here,
## so this file cannot hold a second opinion about what an unscheduled latch looks like.
const NO_SEASON_SCHEDULED: int = WeatherScript.ABSOLUTE_SEASON_NONE
## GDD §5.1 counts calendar days from 1; day 1 has no completed day before it.
const MIN_CALENDAR_DAY: int = 1


class HourResult:
	"""One completed hourly crop integration: which hour it was, and what it changed.

	`.ok` MUST be inspected before any count is read. A refusal clears every field, so an
	unchecked result cannot surface a previous hour's numbers as if they were this hour's.
	"""
	var ok: bool
	var error: StringName
	var tick: int
	var absolute_day: int
	var hour: int
	var temperature_tenths: int
	var plots_grown: int
	var plots_ripened: int
	var plots_frosted: int
	var plots_expired: int
	var plots_withered: int

	func _init() -> void:
		"""Start cleared; every field is written by the hour step before it returns."""
		clear()

	func clear() -> void:
		"""Return every field to its empty value, so nothing survives from a previous hour."""
		ok = false
		error = REFUSE_NONE
		tick = 0
		absolute_day = 0
		hour = 0
		temperature_tenths = 0
		plots_grown = 0
		plots_ripened = 0
		plots_frosted = 0
		plots_expired = 0
		plots_withered = 0

	func refuse(code: StringName) -> bool:
		"""Record a refusal that carries no counts. Always returns false."""
		clear()
		error = code
		return false


class DayResult:
	"""One completed crop/weather day: which day it was, and what each step actually changed.

	`.ok` MUST be inspected before any field is read. A refusal clears every field, so an
	unchecked result cannot surface a previous day's numbers as if they were this day's.
	"""
	var ok: bool
	var error: StringName
	var boundary_tick: int
	var absolute_day: int
	var absolute_season: int
	var completed_absolute_season: int
	var season: int
	var season_day: int
	var completed_day: int
	var elapsed_hour_tick: int
	var blight_active: bool
	var mussel_event_closed: bool
	var mussel_stocks_written: int
	var plots_blighted: int
	var plots_withered: int
	var orchards_advanced: int
	var event_ended: int
	var event_scheduled: int
	var weather_draws: int
	var forecast_event: int
	var forecast_absolute_season: int
	var temperature_tenths: int
	var rain: int
	var moisture_delta: int
	var plots_moistened: int
	var service_counters_reset: bool
	var farm_links_refreshed: int

	func _init() -> void:
		"""Start cleared; every field is written by the day step before it returns."""
		clear()

	func clear() -> void:
		"""Return every field to its empty value, so nothing survives from a previous day."""
		ok = false
		error = REFUSE_NONE
		boundary_tick = 0
		absolute_day = 0
		absolute_season = WeatherScript.ABSOLUTE_SEASON_NONE
		completed_absolute_season = WeatherScript.ABSOLUTE_SEASON_NONE
		season = 0
		season_day = 0
		completed_day = 0
		elapsed_hour_tick = NO_HOUR_RUN
		blight_active = false
		mussel_event_closed = false
		mussel_stocks_written = 0
		plots_blighted = 0
		plots_withered = 0
		orchards_advanced = 0
		event_ended = WeatherScript.EVENT_NONE
		event_scheduled = WeatherScript.EVENT_NONE
		weather_draws = 0
		forecast_event = WeatherScript.EVENT_NONE
		forecast_absolute_season = WeatherScript.ABSOLUTE_SEASON_NONE
		temperature_tenths = 0
		rain = 0
		moisture_delta = 0
		plots_moistened = 0
		service_counters_reset = false
		farm_links_refreshed = 0

	func refuse(code: StringName) -> bool:
		"""Record a refusal that carries no counts. Always returns false."""
		clear()
		error = code
		return false


# --- the stores: two composed here, three borrowed --------------------------------------------

var _ecology: EcologyScript = null
var _directory: EntityDirectory = null
var _farming: FarmingScript = null
var _weather: WeatherScript = null
var _orchard_hive: OrchardHiveScript = null
var _nodes: ResourceNodesScript = null
var _fishing: FishingScript = null
var _rng: Rng = null

# --- the idempotence latches ------------------------------------------------------------------
#
# THERE IS NO `_last_scheduled_season` HERE ANY MORE. Ruling §4.2 made
# `Weather.scheduled_absolute_season` the single owner of §5.10's scheduled-once latch, and
# decision 0055 migrated this file onto it rather than keeping a second copy that could disagree
# on load. `last_scheduled_season()` reads that column.

var _last_day: int = NO_DAY_RUN
var _last_hour_tick: int = NO_HOUR_RUN

# --- scratch (not simulation state) -----------------------------------------------------------

var _calendar: SimClock.Calendar = SimClock.Calendar.new(0)
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _tile_x: int = 0
var _tile_z: int = 0
var _last_refusal: StringName = REFUSE_NONE


func _init(p_ecology: EcologyScript = null, p_rng: Rng = null) -> void:
	"""Compose the crop and weather stores over the ecology's one directory, and borrow its hives.

	The ecology is BORROWED, never advanced: this stage reads `orchard_hive.gd` for §5.6's orchard
	day and decision 0044's links, and `resource_nodes.gd` for §5.1's one tile-geometry primitive,
	and calls no ecology leg. Passing no ecology builds a private one, which is what a standalone
	fixture wants; passing no Rng leaves the WEATHER stream unbound and the season draw refusing.
	"""
	_ecology = p_ecology if p_ecology != null else EcologyScript.new()
	_directory = _ecology.directory()
	_orchard_hive = _ecology.orchard_hive()
	_nodes = _ecology.resource_nodes()
	_fishing = _ecology.fishing()
	_farming = FarmingScript.new(_directory)
	_weather = WeatherScript.new()
	_rng = p_rng
	_assert_shared_contracts()


func _assert_shared_contracts() -> void:
	"""Prove the cadence and capacity facts this file reads out of other modules."""
	assert(SimClock.TICKS_PER_DAY % SimClock.TICKS_PER_HOUR == 0,
		"a day must be a whole number of hours, or a midnight is not an hour boundary")
	assert(is_hour_boundary(SimClock.FIRST_MIDNIGHT_TICK),
		"the first midnight must also be an hour crossing, because both legs run at it")
	assert(FarmingScript.TILE_COUNT == ResourceNodesScript.TILE_COUNT,
		"the crop ledger and the tile geometry owner must describe one 128x128 grid")
	assert(FarmingScript.FARM_PLOT_CAPACITY
			== EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_FARM_PLOT],
		"the plot sweep must cover exactly the directory's FarmPlot rows")
	assert(_farming.directory() == _directory,
		"the crop store must validate references through the ecology's one directory")
	assert(_fishing == _ecology.fishing(),
		"ruling §4.1's closure must be written into ARCH-SYS-005's own fishery, not a copy")
	assert(WeatherScript.DAYS_PER_SEASON == SimClock.DAYS_PER_SEASON,
		"the absolute-season identity and the clock must agree on a season's length")


func clear() -> void:
	"""Empty the crop and weather stores and drop both latches, without reallocating a column.

	The borrowed ecology is NOT cleared here: `ecology.gd` owns its own reset and clearing it from
	this stage would empty four stores this stage does not own on behalf of a caller that asked
	for neither.
	"""
	_farming.clear()
	_weather.clear()
	_last_day = NO_DAY_RUN
	_last_hour_tick = NO_HOUR_RUN
	_last_refusal = REFUSE_NONE


# --- the hourly cadence -------------------------------------------------------------------------

static func is_hour_boundary(tick: int) -> bool:
	"""True when `tick` is the first tick of a new game hour under the offset calendar.

	ARCH-TICK-002: "Hour boundaries satisfy `(k+4500) mod 750=0`". Read as the same crossing
	convention `sim_clock.gd` uses for a day -- tick 0 is 06:00 of day 1 and starts no new hour --
	so tick 750 is the first crossing and every midnight is one of these too.
	"""
	return tick > 0 and (tick + SimClock.CALENDAR_OFFSET_TICKS) % SimClock.TICKS_PER_HOUR == 0


func run_hour(tick: int) -> HourResult:
	"""Run one hourly crop integration. See run_hour_into(); this form allocates one result."""
	var out: HourResult = HourResult.new()
	run_hour_into(tick, out)
	return out


func run_hour_into(tick: int, out: HourResult) -> bool:
	"""ARCH-SYS-006's HOURLY half at one hour crossing, into caller-owned `out`.

	`tick` is the tick being committed. The climate read is the ELAPSED hour's (ARCH-TICK-003):
	at a midnight tick the row still holds the day that just ended, because the daily leg has not
	run yet. The hour is consumed before the plots are swept, so a replay refuses rather than
	integrating a second hour of growth into the same 60 minutes.
	"""
	out.clear()
	if tick < 0:
		return out.refuse(REFUSE_INVALID_TICK)
	if not is_hour_boundary(tick):
		return out.refuse(REFUSE_NOT_HOUR_BOUNDARY)
	if tick <= _last_hour_tick:
		return out.refuse(REFUSE_HOUR_ALREADY_RUN)
	_last_hour_tick = tick
	SimClock.calendar_at_into(tick, _calendar)
	out.tick = tick
	out.absolute_day = _calendar.absolute_day
	out.hour = _calendar.hour
	out.temperature_tenths = _weather.temperature_tenths()
	_integrate_plots(out)
	out.ok = true
	return true


func _integrate_plots(out: HourResult) -> void:
	"""One hour of REQ-SET-072 growth, REQ-SET-084 frost and REQ-SET-075 expiry, per live plot.

	The frost branch is decided ONCE for the whole hour, not per plot: REQ-SET-084 applies "while
	temperature<0 C" and the temperature is a per-day value, so a temperate day costs no work and
	no allocation at all. The sweep is a presence scan because `farming.gd` publishes
	`live_slot_at()` only in an allocating form (header).
	"""
	var freezing: bool = out.temperature_tenths < FarmingScript.FROST_TEMPERATURE_TENTHS
	for slot: int in FarmingScript.FARM_PLOT_CAPACITY:
		if not _farming.is_present(slot):
			continue
		_grow_one_plot(slot, out)
		if freezing:
			_freeze_one_plot(slot, out)
		_expire_one_ripe_plot(slot, out)


func _grow_one_plot(slot: int, out: HourResult) -> void:
	"""REQ-SET-072's hourly step. A plot that is not GROWING refuses inside the store and is skipped.

	`advance_growth_hour_into()` retains the sub-milli-hour fraction in TileHistory and marks the
	plot RIPE at the crop's stated duration, dating `ripe_tick` with this tick (REQ-SET-073). The
	priority-2 harvest job REQ-SET-073 also asks for is a producer's, and is not created here.
	"""
	if not _farming.advance_growth_hour_into(slot, out.temperature_tenths, out.tick, _read):
		return
	out.plots_grown += 1
	if _farming.is_ripe(slot):
		out.plots_ripened += 1


func _freeze_one_plot(slot: int, out: HourResult) -> void:
	"""REQ-SET-084's frost damage for one hour below 0 C, halved for cabbage in a tended plot.

	A plot that is not GROWING -- ripe, withered, empty or still sowing -- refuses inside the
	store and is skipped, which is ordinary and not a fault. Health reaching 0 withers the plot
	(REQ-SET-085); the 10-WU clearing job that requirement also asks for is a producer's.
	"""
	if not _farming.apply_frost_hour(slot, out.temperature_tenths).ok:
		return
	out.plots_frosted += 1
	if _farming.is_withered(slot):
		out.plots_withered += 1


func _expire_one_ripe_plot(slot: int, out: HourResult) -> void:
	"""REQ-SET-075: wither a RIPE plot at the exact hour it completes its 5 unharvested days.

	Hourly rather than at midnight because the threshold is stated in HOURS from a tick-dated
	ripening, and ripening itself lands on an hour crossing -- so 120 hours later is another hour
	crossing and this is exact. A midnight-only check would wither up to 23 hours late. The 10%
	per-day yield decay §5.6 states between hour 48 and hour 120 needs no step at all: it is a
	pure function of `ripe_tick`, which `farming.gd` reads at harvest.
	"""
	if not _farming.is_ripe_expired(slot, out.tick):
		return
	if not _farming.apply_ripe_expiry(slot, out.tick).ok:
		return
	out.plots_expired += 1
	out.plots_withered += 1


# --- the daily cadence --------------------------------------------------------------------------

func run_day(boundary_tick: int, hive_eligibility_crossings: int = 0) -> DayResult:
	"""Run one crop/weather day. See run_day_into(); this form allocates one result."""
	var out: DayResult = DayResult.new()
	run_day_into(boundary_tick, hive_eligibility_crossings, out)
	return out


func run_day_into(boundary_tick: int, hive_eligibility_crossings: int, out: DayResult) -> bool:
	"""ARCH-SYS-006's MIDNIGHT half at one offset-calendar crossing, into caller-owned `out`.

	`boundary_tick` must be a real crossing taken from the clock: `tick % 18000 == 0` names 06:00
	and is refused. `hive_eligibility_crossings` is ARCH-SYS-005's own count from the ecology leg
	that ran immediately before this one (header). The day is consumed BEFORE the steps run, so a
	step that refuses half way cannot be replayed on top of the steps that already committed.
	"""
	out.clear()
	if boundary_tick < 0:
		return out.refuse(REFUSE_INVALID_TICK)
	if hive_eligibility_crossings < 0:
		return out.refuse(REFUSE_INVALID_CROSSINGS)
	if not SimClock.is_day_boundary(boundary_tick):
		return out.refuse(REFUSE_NOT_DAY_BOUNDARY)
	SimClock.calendar_at_into(boundary_tick, _calendar)
	if _calendar.absolute_day <= _last_day:
		return out.refuse(REFUSE_DAY_ALREADY_RUN)
	if not _preflight_day(_calendar.absolute_day, _calendar.season, out):
		return false
	_last_day = _calendar.absolute_day
	_write_day_header(boundary_tick, out)
	if not _run_steps(hive_eligibility_crossings, out):
		return false
	out.ok = true
	return true


func preflight_refusal_for(absolute_day: int, season: int) -> StringName:
	"""Ruling §4.1's preflight as a PURE READER: the code this boundary would refuse with, or empty.

	Runs exactly the checks `run_day_into()` runs before it consumes the day, and writes nothing
	at all -- no latch, no store, no column. It is the entry point a caller uses to ask "would this
	boundary advance?" without advancing it, and it is what makes the season-identity check
	reachable from a test: `run_day_into()` derives both sides of that comparison from one tick and
	so can never disagree with itself, while this form takes the season as an argument.
	The DayResult it fills is local, because a reader must not disturb the stage's own scratch.
	"""
	var probe: DayResult = DayResult.new()
	if _preflight_day(absolute_day, season, probe):
		return REFUSE_NONE
	return probe.error


func _preflight_day(absolute_day: int, season: int, out: DayResult) -> bool:
	"""Ruling §4.1: prove season identity, RNG and catalogs BEFORE the boundary can advance at all.

	Writes `out.absolute_season` on success and nothing at all on refusal, and is called before
	the day latch is consumed -- so a refused boundary leaves the day unrun and every store
	untouched, instead of clearing some state and publishing an apparently completed tick.
	"""
	if not _weather.absolute_season_of_day_into(absolute_day, _read):
		return out.refuse(StringName(_read.error))
	var absolute_season: int = _read.value
	if WeatherScript.season_of_absolute_season(absolute_season) != season:
		return out.refuse(REFUSE_SEASON_IDENTITY_MISMATCH)
	if not _weather.catalog_is_verified():
		return out.refuse(REFUSE_EVENT_CATALOG_UNVERIFIED)
	if not _fishing.catalog_is_verified():
		return out.refuse(REFUSE_FISH_CATALOG_UNVERIFIED)
	if not _preflight_weather_stream(absolute_day, absolute_season, season, out):
		return false
	out.absolute_season = absolute_season
	return true


func _preflight_weather_stream(absolute_day: int, absolute_season: int, season: int,
		out: DayResult) -> bool:
	"""Require a bound, seeded WEATHER stream only on a boundary that would actually draw.

	A season already scheduled draws nothing, and §5.10's forced first spring takes no Rng at all,
	so neither needs a stream: an unseeded world still opens with its onboarding ideal spell. Any
	other new season without a seeded stream refuses HERE, before the completed day's blight and
	orchard steps commit, rather than half way through the boundary.
	"""
	if _weather.is_season_scheduled(absolute_season):
		return true
	if _weather.is_forced_first_spring(OrchardHiveScript.year_of_day(absolute_day), season):
		return true
	if _rng == null:
		return out.refuse(REFUSE_NO_RNG)
	if not _rng.is_seeded():
		return out.refuse(REFUSE_RNG_NOT_SEEDED)
	return true


func _write_day_header(boundary_tick: int, out: DayResult) -> void:
	"""Copy the decoded calendar instant of this boundary onto the result before any step runs.

	`absolute_season` is already on the result from the preflight and is NOT rewritten here.
	`completed_absolute_season` is ruling §4.3's ELAPSED calendar, derived from `completed_day`
	and not from the day now opening, so the two visibly differ on a season crossing.
	`elapsed_hour_tick` records the hour this stage had already integrated when the boundary
	opened, which is the preceding interval's -- see step 0 of the header.
	"""
	out.boundary_tick = boundary_tick
	out.absolute_day = _calendar.absolute_day
	out.season = _calendar.season
	out.season_day = _calendar.season_day
	out.completed_day = _calendar.absolute_day - 1
	out.elapsed_hour_tick = _last_hour_tick
	if _weather.absolute_season_of_day_into(out.completed_day, _read):
		out.completed_absolute_season = _read.value


func _run_steps(hive_eligibility_crossings: int, out: DayResult) -> bool:
	"""The seven daily steps in the order the header sets out. See there for why each sits where it does."""
	_apply_completed_day_blight(out)
	if not _advance_orchards(out):
		return false
	if not _advance_weather_day(out):
		return false
	if not _apply_mussel_event_closure(out):
		return false
	if not _apply_daily_moisture(out):
		return false
	_reset_service_counters(out)
	return _refresh_farm_links_after_hive_changes(hive_eligibility_crossings, out)


func _apply_mussel_event_closure(out: DayResult) -> bool:
	"""Ruling §4.1's ONE writer of `FishStock.closed`: the new day's summer-blight mussel closure.

	The bit is `new_season == SUMMER && active_new_day_event == BLIGHT` and FALSE otherwise --
	including autumn blight, whose ruled effect mask has AFFECTS_MUSSEL_HARVEST stripped, and the
	day after expiry, whose active event is EVENT_NONE. It is written UNCONDITIONALLY every day,
	not only when closing, so a stock cannot stay shut because nobody reopened it.
	It runs after the new day's weather and long before `settlement_system.gd` plans jobs.
	"""
	out.mussel_event_closed = _weather.closes_mussel_harvest_on(
		out.absolute_season, out.season_day)
	if not _fishing.apply_mussel_event_closure_into(out.mussel_event_closed, _read):
		return out.refuse(StringName(_read.error))
	out.mussel_stocks_written = _read.value
	return true


func _apply_completed_day_blight(out: DayResult) -> void:
	"""REQ-SET-087 for the day that ENDED, with that day's tending flags still standing.

	400 health/day, 200 while tended, and only while §5.10's blight window covers the completed
	day of the COMPLETED DAY'S OWN ABSOLUTE SEASON -- ruling §4.3's elapsed calendar, derived from
	`completed_day` and never from the new day's season, so a season crossing does not settle
	summer's blight as an autumn one. "Stop damage when the event ends" needs nothing: outside the
	window `is_blight_active()` is false and the call is simply not made.
	"""
	if out.completed_day < MIN_CALENDAR_DAY:
		return
	var season_day: int = OrchardHiveScript.season_day_of_day(out.completed_day)
	if not _weather.is_blight_active(out.completed_absolute_season, season_day):
		return
	out.blight_active = true
	for slot: int in FarmingScript.FARM_PLOT_CAPACITY:
		if not _farming.is_present(slot):
			continue
		if not _farming.apply_blight_day(slot).ok:
			continue
		out.plots_blighted += 1
		if _farming.is_withered(slot):
			out.plots_withered += 1


func _advance_orchards(out: DayResult) -> bool:
	"""§5.6's orchard day for the day that ENDED, at the temperature that day still holds.

	`apply_orchard_day()` clears the year's harvested flag at a year boundary, advances age,
	applies the spring/summer untended -100 or tended +50, advances the winter chill counter and
	clears the day's tending flag. It runs BEFORE the new day's `refresh_daily()` precisely
	because the chill counter must judge the completed day's temperature, not tomorrow's.
	"""
	if out.completed_day < MIN_CALENDAR_DAY:
		return true
	var temperature: int = _weather.temperature_tenths()
	for slot: int in OrchardHiveScript.ORCHARD_CAPACITY:
		if not _orchard_hive.is_orchard_present(slot):
			continue
		var day: OrchardHiveScript.OpResult = _orchard_hive.apply_orchard_day(
			_orchard_hive.orchard_ref_of(slot), out.completed_day, temperature)
		if not day.ok:
			return out.refuse(day.error)
		out.orchards_advanced += 1
	return true


func _advance_weather_day(out: DayResult) -> bool:
	"""§5.10's new-day weather: end, schedule, disclose, then write the day's baseline.

	The order is `weather.gd`'s own stated ordering for ARCH-SYS-006 -- "season advance, schedule,
	disclose, refresh, end" -- with the end brought to the front of the day it applies to: an
	event whose window closed yesterday must not still be modifying the row this day's
	`refresh_daily()` writes.
	"""
	if not _end_expired_event(out):
		return false
	if not _schedule_season_event(out):
		return false
	if not _disclose_due_forecast(out):
		return false
	var refreshed: WeatherScript.OpResult = _weather.refresh_daily(
		out.absolute_season, out.season_day)
	if not refreshed.ok:
		return out.refuse(refreshed.error)
	out.temperature_tenths = _weather.temperature_tenths()
	out.rain = _weather.rain()
	return true


func _end_expired_event(out: DayResult) -> bool:
	"""REQ-SET-145: drop the scheduled event's modifiers on the first day after its window closes.

	"Without restoring crop health, consumed stocks, or injuries already incurred" is structural
	in `weather.gd`: that store holds none of them. The disclosed forecast is retained WITH its
	absolute-season identity, because REQ-SET-142 requires the calendar to keep it, and so is the
	scheduled-once latch. A SEASON CROSSING EXPIRES THE EVENT TOO: an event scheduled for another
	absolute season covers no day of this one, whatever its season-local start day was, so the
	row's modifiers are dropped before this season's own event is drawn.
	"""
	if not _weather.is_event_scheduled():
		return true
	if _weather.is_season_scheduled(out.absolute_season) \
			and out.season_day <= _weather.last_day():
		return true
	var ended: WeatherScript.OpResult = _weather.end_event(out.absolute_season)
	if not ended.ok:
		return out.refuse(ended.error)
	out.event_ended = ended.value
	return true


func _schedule_season_event(out: DayResult) -> bool:
	"""§5.10's one event per season: the forced first spring draws ZERO, every other draws ONE.

	The latch is `Weather.scheduled_absolute_season`, so a season already scheduled schedules
	nothing again however many midnights it sees. The absolute season is the one the PREFLIGHT
	established and is not recomputed here: `farming.gd` derives the same
	`floor((absolute_day-1)/12)` for its own tables, and a duplicate comparison at this point is a
	branch no test can ever enter, so the agreement of the two derivations is asserted directly by
	`test_the_two_stores_derive_the_same_absolute_season` across four years instead.
	"""
	if _weather.is_season_scheduled(out.absolute_season):
		return true
	if _weather.is_forced_first_spring(
			OrchardHiveScript.year_of_day(out.absolute_day), out.season):
		return _apply_forced_first_spring(out)
	if _rng == null:
		return out.refuse(REFUSE_NO_RNG)
	var drawn: WeatherScript.OpResult = _weather.schedule_season_event(out.absolute_season, _rng)
	if not drawn.ok:
		return out.refuse(drawn.error)
	out.event_scheduled = drawn.value
	out.weather_draws = 1
	return true


func _apply_forced_first_spring(out: DayResult) -> bool:
	"""§5.10's onboarding event: forced ideal spell on day 6, and ZERO WEATHER draws.

	`schedule_first_spring_event()` takes no Rng at all, so the zero-draw rule is structural
	rather than a convention this function could break -- an unseeded settlement still gets its
	first spring. It refuses any absolute season but 0, which is exactly year 1's spring.
	"""
	var forced: WeatherScript.OpResult = _weather.schedule_first_spring_event(out.absolute_season)
	if not forced.ok:
		return out.refuse(forced.error)
	out.event_scheduled = forced.value
	out.weather_draws = 0
	return true


func _disclose_due_forecast(out: DayResult) -> bool:
	"""REQ-SET-142: disclose the scheduled event three days before it starts, consuming no draw.

	Idempotent in the store, so a caller that discloses on every day from the due day onward
	writes the same values every time; BAL-SAFE-017's "opening forecasts ... SHALL consume no event
	roll" holds because `disclose_forecast()` takes no Rng. The disclosure carries the day's
	absolute season, so the retained calendar entry can be placed in a year after the event ends.
	"""
	if not _weather.is_forecast_due(out.absolute_season, out.season_day):
		return true
	var disclosed: WeatherScript.OpResult = _weather.disclose_forecast(
		out.absolute_season, out.season_day)
	if not disclosed.ok:
		return out.refuse(disclosed.error)
	out.forecast_event = _weather.forecast_event()
	out.forecast_absolute_season = _weather.forecast_absolute_season()
	return true


func _apply_daily_moisture(out: DayResult) -> bool:
	"""§5.10's new-day moisture: EVAPORATE FIRST, then add rain, as ONE change against ONE clamp.

	"Plots lose 600 moisture/day baseline, multiplied 1500/1000 in summer; rain adds after
	evaporation." The order is observable at the bounds and is not a formality: a plot at 10000 in
	spring heavy rain keeps 10000 under this order and would lose 600 under the other, because
	rain applied first would be clamped away before the evaporation was taken off it.
	"""
	var event: int = _weather.active_event_on(out.absolute_season, out.season_day)
	if not _weather.moisture_delta_for_into(out.season, event, _read):
		return out.refuse(StringName(_read.error))
	out.moisture_delta = _read.value
	for slot: int in FarmingScript.FARM_PLOT_CAPACITY:
		if not _farming.is_present(slot):
			continue
		var moved: FarmingScript.OpResult = _farming.apply_moisture_delta(slot, out.moisture_delta)
		if not moved.ok:
			return out.refuse(moved.error)
		out.plots_moistened += 1
	return true


func _reset_service_counters(out: DayResult) -> void:
	"""ARCH-TICK-003's service reset: every tile's tending flag, AFTER the completed day spent it.

	One fill over TileHistory's 16384 bytes, allocating nothing. The ORCHARD tending flag is not
	cleared here: `apply_orchard_day()` clears its own as the last thing it does, and clearing it
	twice would be a second reset of a flag the store already owns.
	"""
	_farming.clear_tended_today()
	out.service_counters_reset = true


func _refresh_farm_links_after_hive_changes(crossings: int, out: DayResult) -> bool:
	"""Decision 0044's FARM half of a hive change ARCH-SYS-005 committed one call earlier.

	Zero crossings refreshes NOTHING. A blanket daily refresh would replace a synchronous
	discipline with a periodic repair, and would hide a caller that skipped one.
	"""
	if crossings == 0:
		return true
	if not refresh_all_farm_links_into(_read):
		return out.refuse(StringName(_read.error))
	out.farm_links_refreshed = _read.value
	return true


# --- the world generator's opening day ----------------------------------------------------------

func prime_day(absolute_day: int) -> bool:
	"""Write the opening day's §5.10 weather without running a crop day. The world's first entry.

	The offset calendar starts at 06:00 of day 1 and its first crossing is day 2, so day 1 never
	reaches `run_day_into()` and a fresh store would report the cleared row -- 0.0 C, no rain --
	for the opening 18 hours. This writes that day's season baseline, schedules its season's event
	and discloses a due forecast, using exactly the same three steps the daily leg uses, and marks
	the day consumed so the boundary of the SAME day cannot run them twice.

	Ruling §4.3: "First-day priming supplies spring's actual baseline at tick 0; zero-filled
	weather is not valid opening weather." The same preflight the daily leg uses runs first, so a
	world whose season identity or catalogs do not check out refuses to open at all.
	"""
	if absolute_day < MIN_CALENDAR_DAY:
		return _refuse(REFUSE_INVALID_DAY)
	if absolute_day <= _last_day:
		return _refuse(REFUSE_DAY_ALREADY_RUN)
	var out: DayResult = DayResult.new()
	out.absolute_day = absolute_day
	out.season = OrchardHiveScript.season_of_day(absolute_day)
	out.season_day = OrchardHiveScript.season_day_of_day(absolute_day)
	if not _preflight_day(absolute_day, out.season, out):
		return _refuse(out.error)
	if not _advance_weather_day(out):
		return _refuse(out.error)
	_last_day = absolute_day
	_last_refusal = REFUSE_NONE
	return true


# --- the FarmPlot lifecycle join (decision 0044) -------------------------------------------------

func create_plot_at_tile(tile: int, soil: int, day: int) -> FarmingScript.OpResult:
	"""Create a FarmPlot AND compute its pollination slice before the row is handed back.

	Ruling §3's synchronous refresh, on the one lifecycle event `orchard_hive.gd` cannot see. A
	refused refresh DESTROYS the row again rather than publishing a plot whose slice nobody
	computed: a half-created plot would read a slice left over from the previous owner of the row.
	"""
	var made: FarmingScript.OpResult = _farming.create_plot_at_tile(tile, soil, day)
	if not made.ok:
		_last_refusal = made.error
		return made
	if refresh_farm_links_of(made.value):
		_last_refusal = REFUSE_NONE
		return made
	var code: StringName = _last_refusal
	_farming.destroy(made.ref)
	_last_refusal = code
	return FarmingScript.OpResult.new(false, code, 0, EntityDirectory.NULL_REF)


func destroy_plot(ref: Vector2i) -> FarmingScript.OpResult:
	"""Null a FarmPlot's pollination slice AND destroy the row, in that order.

	Ruling §3 requires the owner lifecycle to clear its slice "including on typed-slot reuse", and
	`orchard_hive.gd` names this join as the only place a FarmPlot's can be cleared. Clearing
	FIRST is deliberate: after `destroy()` the reference is stale and the typed row is free to be
	handed to the next plot, which would then inherit six live links it never earned.
	"""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_FARM_PLOT):
		_last_refusal = REFUSE_NOT_PRESENT
		return FarmingScript.OpResult.new(false, REFUSE_NOT_PRESENT, 0, EntityDirectory.NULL_REF)
	var slot: int = _directory.get_typed_row(ref)
	var cleared: OrchardHiveScript.OpResult = _orchard_hive.clear_farm_links(slot)
	if not cleared.ok:
		_last_refusal = cleared.error
		return FarmingScript.OpResult.new(false, cleared.error, 0, EntityDirectory.NULL_REF)
	var removed: FarmingScript.OpResult = _farming.destroy(ref)
	_last_refusal = removed.error
	return removed


func refresh_farm_links_of(slot: int) -> bool:
	"""Recompute one live plot's six-entry pollination slice from its tile (decision 0044)."""
	if not _decode_plot_tile(slot):
		return false
	var done: OrchardHiveScript.OpResult = _orchard_hive.refresh_farm_links(
		slot, _tile_x, _tile_z)
	if not done.ok:
		return _refuse(done.error)
	_last_refusal = REFUSE_NONE
	return true


func refresh_all_farm_links() -> IntMath.IntResult:
	"""Refresh every live plot's slice. See refresh_all_farm_links_into(); allocates one result."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	refresh_all_farm_links_into(out)
	return out


func refresh_all_farm_links_into(out: IntMath.IntResult) -> bool:
	"""Recompute every live plot's slice; returns how many were refreshed.

	The entry point a future hive create/destroy/footprint command must call, because ruling §3
	budgets no reverse index from a hive back to the farm rows it can reach.
	"""
	var refreshed: int = 0
	for slot: int in FarmingScript.FARM_PLOT_CAPACITY:
		if not _farming.is_present(slot):
			continue
		if not refresh_farm_links_of(slot):
			return out.refuse(String(_last_refusal))
		refreshed += 1
	return out.succeed(refreshed)


func check_farm_links_of(slot: int) -> bool:
	"""True when a live plot's stored slice already IS the canonical selection. Repairs NOTHING.

	Ruling §3's reader: a comparison against a freshly computed selection that writes only the
	candidate scratch. This is what proves a caller honoured the synchronous refresh discipline,
	and it is deliberately not consulted by any operation above.
	"""
	if not _decode_plot_tile(slot):
		return false
	return _orchard_hive.check_farm_links(slot, _tile_x, _tile_z)


func _decode_plot_tile(slot: int) -> bool:
	"""Decode a live plot's tile into `_tile_x`/`_tile_z` through §5.1's ONE geometry owner.

	`resource_nodes.gd` owns `z*128+x` and its inverse, so this file compiles no second copy of
	that formula and cannot disagree with it. Three IntResults per call, named in the header;
	neither store publishes an `_into` form of these readers.
	"""
	var tile: IntMath.IntResult = _farming.tile_of(slot)
	if not tile.ok:
		return _refuse(StringName(tile.error))
	var x: IntMath.IntResult = _nodes.tile_x_of(tile.value)
	var z: IntMath.IntResult = _nodes.tile_z_of(tile.value)
	if not x.ok or not z.ok:
		return _refuse(REFUSE_INVALID_TILE)
	_tile_x = x.value
	_tile_z = z.value
	return true


# --- readers --------------------------------------------------------------------------------------

func farming() -> FarmingScript:
	"""The §4.2 FarmPlot store and §2's TileHistory ledger this stage advances."""
	return _farming


func weather() -> WeatherScript:
	"""The §4.2 single Weather row this stage schedules, discloses and refreshes."""
	return _weather


func ecology() -> EcologyScript:
	"""ARCH-SYS-005's stores, borrowed and never advanced from here."""
	return _ecology


func orchard_hive() -> OrchardHiveScript:
	"""The §5.6 OrchardPlot, Hive and pollination-link store, borrowed from the ecology."""
	return _orchard_hive


func directory() -> EntityDirectory:
	"""The allocator behind every crop and orchard reference."""
	return _directory


func rng() -> Rng:
	"""The ARCH-RNG-002 stream set the WEATHER draw consumes, or null while none is bound."""
	return _rng


func last_day_run() -> int:
	"""Absolute day the daily leg last CONSUMED, refused steps included; 0 before the first."""
	return _last_day


func last_hour_tick() -> int:
	"""Tick the hourly leg last CONSUMED; -1 before the first hour crossing it saw."""
	return _last_hour_tick


func last_scheduled_season() -> int:
	"""Absolute season index `(day-1)/12` whose §5.10 event is already scheduled; -1 before any.

	READS `Weather.scheduled_absolute_season` AND HOLDS NOTHING. Ruling §4.2 made that column the
	single owner of the scheduled-once latch and forbids an independent second copy, so this is a
	delegation and cannot drift from the store it describes (decision 0055).
	"""
	return _weather.scheduled_absolute_season()


func fishing() -> FishingScript:
	"""The §5.4 fishery whose `FishStock.closed` event bit ruling §4.1 gives this stage to write.

	Borrowed from the ecology, exactly as `orchard_hive()` is: ARCH-SYS-005 still owns stock and
	quota recovery, and this stage writes the event closure column and nothing else in it.
	"""
	return _fishing


func last_refusal() -> StringName:
	"""Reason the most recent refused bool-returning operation was refused; empty after a success."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record a refusal code and return false, so callers can `return _refuse(...)`."""
	_last_refusal = code
	return false
