extends RefCounted
## The demo farm's model: six beds as REAL FarmPlot rows, advanced by the REAL crop arithmetic on the
## demo's one calendar. Decision 0196. Presentation-only as a whole -- nothing here writes into the
## running settlement -- but every crop number is the settlement's own.
##
## ---------------------------------------------------------------------------------------
## HOW THE REAL SIM IS DRIVEN. The farm owns one `crop_weather.gd` stage over its own ecology and a
## seeded Rng (WEATHER_SEED), so it cannot disturb the game's world; `prime_day(1)` writes spring's
## opening weather as the world generator would. Each bed is one plot created through the stage's
## `create_plot_at_tile()` join on its own exterior tile. Then, on the demo's one calendar
## (demo/demo_calendar.gd -- this module is the one thing that ADVANCES it, `advance_usec`; the weather
## and the HUD's date only read it), at every HOUR CROSSING this module runs the stage's hourly leg
## ITSELF, per bed, calling exactly the three farming.gd entry points `crop_weather._integrate_plots()` calls --
## `advance_growth_hour_into()` (REQ-SET-072/073), `apply_frost_hour()` (REQ-SET-084) and
## `apply_ripe_expiry()` (REQ-SET-075) -- because a bed's temperature for the hour differs from the
## air's when it is covered or raised, and the stage reads one temperature for every plot. At every
## MIDNIGHT it runs the stage's own `run_day_into()` unchanged: completed-day weather blight, §5.10's
## new-day weather and forecast, the new-day moisture and the service reset. After it, per bed:
## REQ-SET-078's `apply_fallow_day()` on empty beds and the season's compost-mirror refresh, then the
## demo additions below. No arithmetic is re-implemented: every growth step, factor, loss, yield and
## clamp is a farming.gd call.
##
## THE DEMO ADDITIONS, each a demo value, each applied through a farming.gd entry point:
##   * the frost nights and blight outbreaks of farm_weather.gd; blight damage is
##     `apply_blight_day()` for each blighted growing bed at midnight (the COMPLETED day, before the
##     stage resets the tending flags, so watering that day halves it -- §5.6's own rule); an
##     outbreak spreads to the neighbours of a bed blighted since the previous midnight;
##   * per-bed moisture on top of the weather's, through `apply_moisture_delta()`: a DRAINED bed
##     (a tunnel under it) sheds up to DRAIN_PER_DAY toward its crop's low side, an IRRIGATED bed (a
##     tunnel from the pond under it) is pulled up to IRRIGATE_PER_DAY toward its band's middle, a
##     RAISED bed (tunnel earth) sheds RAISED_DRAIN_PER_DAY and is warmer at night, a BANKED bed
##     keeps half of each day's weather loss, a DITCHED bed (the Drain job) sheds up to
##     DITCH_DRAIN_PER_DAY toward its crop's low side as a tunnel drain does; and EVERY bed above its
##     crop's high side sheds up to NATURAL_DRAIN_PER_DAY back toward it (the village loam drains);
##   * THE GARDEN LEAT (decision 0441): a bed the weir's sluice serves (water/weir_sluice.gd: wet, normal or dry)
##     takes its water from the leat instead of a tunnel: NORMAL is moved up to LEAT_PER_DAY toward its band's
##     middle (as a tunnel irrigates), WET is raised up to LEAT_PER_DAY toward WET_ABOVE_TOP over its band's top
##     and never lowered, DRY adds nothing (the leat runs empty: the tunnels, ditch and raising act as before). The
##     leat's share is worked out on the bed's moisture as the day left it, BEFORE the night's weather (`leat_delta`
##     on `_day_start`), so the sluice's preview -- read during the day -- is exactly the leat's own share; the
##     weather and the natural drainage above the band's top come on top of it. A watered bed is not drained by a tunnel, a raised bed or a ditch the same day, as a
##     tunnel-irrigated one is not. A FLOOD that passes while the leat runs (`apply_flood_surge`) lifts a WET bed
##     past its WET band (waterlogged) and a NORMAL one into it, at once;
##   * DRAINING a Wet or Waterlogged bed (`drain_bed()`, the Drain job): its moisture drops at once
##     to the top of its crop's band, and the ditch dug round it keeps shedding (above) for good;
##   * CLEARING a blighted, still-growing crop is uprooting it: `apply_health_loss()` of its whole
##     health withers it and `clear_withered()` clears it, returning REQ-SET-085's 0.5 U compost.
## COMPOST IS PLANT WASTE (decision 0401). The compost store (`compost_milli`) is filled only by plant waste -- a cleared
## crop's 0.5 U here, and the Pantry's spoiled food at §5.7's 4 : 2 (demo_farm.gd `compost_spoiled`) -- and `compost()`
## always pays its 2 U from it. Tunnel earth never composts and never adds fertility: raising and banking a bed only set
## its flag.
## Seed is not stocked (the demo has unlimited seed); REQ-SET-071's 250 milli-U is reported only.

const FarmingScript := preload("res://scripts/core/farming.gd")
const CropWeatherScript := preload("res://scripts/core/crop_weather.gd")
const EcologyScript := preload("res://scripts/core/ecology.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const Weather := preload("res://demo/farm/farm_weather.gd")
const Sluice := preload("res://demo/water/weir_sluice.gd")

## The WEATHER stream's world seed (demo value).
const WEATHER_SEED: int = 196
const OPENING_DAY: int = 1
const NO_ITEM: int = Catalog.NO_ITEM

## What a bed shows. SPROUTING is the first SPROUT_PERMILLE of growth (presentation).
const STAGE_EMPTY: int = 0
const STAGE_SOWN: int = 1
const STAGE_SPROUTING: int = 2
const STAGE_GROWING: int = 3
const STAGE_RIPE: int = 4
const STAGE_WITHERED: int = 5
const STAGE_BLIGHTED: int = 6
const STAGE_NAMES: Array[String] = ["empty", "sown", "sprouting", "growing", "ripe", "withered", "blighted"]
const SPROUT_PERMILLE: int = 200

## A bed's moisture against its crop's §5.6 band: DRY and WATERLOGGED are the moisture factor's 0
## (more than 2000 outside), LOW and WET its 500, GOOD its 1000.
const BAND_DRY: int = 0
const BAND_LOW: int = 1
const BAND_GOOD: int = 2
const BAND_WET: int = 3
const BAND_WATERLOGGED: int = 4
const BAND_NAMES: Array[String] = ["dry", "low", "good", "wet", "waterlogged"]

## Demo moisture rules, per farm day (see the header).
const DRAIN_PER_DAY: int = 1500
const DRAIN_MARGIN: int = 500
const IRRIGATE_PER_DAY: int = 1500
const RAISED_DRAIN_PER_DAY: int = 800
## A ditch round a bed sheds less than a tunnel under it (1500) and more than earth lifting it (800):
## a round demo value between the two.
const DITCH_DRAIN_PER_DAY: int = 1000
## What any bed sheds above its crop's high side, per day (well-drained village loam). Spring's +600
## a day then only creeps a bed past its band (+100 a day net) and only the first spring's Ideal
## spell (+1200 a day, days 6-8) waterlogs the opening radish -- at the midnight opening spring 8,
## not spring 6 as with none (playtest 2026-09-29; farm_weather.gd spaces the threats round it).
const NATURAL_DRAIN_PER_DAY: int = 500
## The garden leat (see THE GARDEN LEAT; decision 0441, demo values): a day's most, as a tunnel irrigates; how far
## over its band's top a WET bed is raised (the middle of the WET band, MOISTURE_NEAR_MARGIN wide); how far past the
## WET band a flood down an open leat lifts a WET bed (into WATERLOGGED).
const LEAT_PER_DAY: int = IRRIGATE_PER_DAY
const WET_ABOVE_TOP: int = 1000
const FLOOD_OVER_WET: int = 500
## The band an empty bed with nothing chosen is judged against (demo: the beans/cabbage span).
const EMPTY_BAND_MIN: int = 4000
const EMPTY_BAND_MAX: int = 8000
## The farm's compost store at opening (demo value), in milli-U.
const START_COMPOST_MILLI: int = 4000
## A covered bed's straw comes off at this hour, the morning after.
const COVER_OFF_HOUR: int = 6

## Events for the alerts, logged as (kind, bed) pairs.
const EVENT_RIPENED: int = 1
const EVENT_WITHERED: int = 2
const EVENT_BLIGHT: int = 3
const EVENT_BLIGHT_SPREAD: int = 4

const REFUSE_NONE: StringName = &""
const REFUSE_NOT_A_BED: StringName = &"NOT_A_BED"
const REFUSE_NOT_AN_ITEM: StringName = &"NOT_AN_ITEM"
const REFUSE_NO_ITEM: StringName = &"NO_ITEM_CHOSEN"
const REFUSE_FALLOW: StringName = &"BED_RESTING_FALLOW"
const REFUSE_NO_COMPOST: StringName = &"NOT_ENOUGH_COMPOST"
const REFUSE_NOTHING_TO_CLEAR: StringName = &"NOTHING_TO_CLEAR"
const REFUSE_ALREADY: StringName = &"ALREADY_DONE"
const REFUSE_NO_CROP: StringName = &"NO_CROP_STANDING"
const REFUSE_STALLED: StringName = &"GROWTH_STALLED"
const REFUSE_CALENDAR_STARTED: StringName = &"CALENDAR_ALREADY_RUNNING"
const REFUSE_NOT_TOO_WET: StringName = &"NOT_TOO_WET"

var calendar: CalendarScript = CalendarScript.new()
var compost_milli: int = START_COMPOST_MILLI
var hours_run: int = 0
var days_run: int = 0
## Bumped by every change a reader could see (an hour, a day, a verb that took), so the view and
## the panels redraw only when something changed.
var revision: int = 0

var _crop_weather: CropWeatherScript = null
var _farming: FarmingScript = null
var _day: CropWeatherScript.DayResult = CropWeatherScript.DayResult.new()
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _slot: PackedInt32Array = PackedInt32Array()
var _tile: PackedInt32Array = PackedInt32Array()
var _item: PackedInt32Array = PackedInt32Array()
var _chosen: PackedInt32Array = PackedInt32Array()
var _covered: PackedByteArray = PackedByteArray()
var _raised: PackedByteArray = PackedByteArray()
var _banked: PackedByteArray = PackedByteArray()
var _fallow: PackedByteArray = PackedByteArray()
var _blighted: PackedByteArray = PackedByteArray()
var _drained: PackedByteArray = PackedByteArray()
var _irrigated: PackedByteArray = PackedByteArray()
var _ditched: PackedByteArray = PackedByteArray()
## Per bed, the garden leat's service (weir_sluice.gd SERVICE_*; decision 0441), and its moisture as the day left it
## (before the midnight's weather: the leat's basis).
var _service: PackedByteArray = PackedByteArray()
var _day_start: PackedInt32Array = PackedInt32Array()
var _blight_days: PackedInt32Array = PackedInt32Array()
var _neighbours: Array[PackedInt32Array] = []
var _events: PackedInt32Array = PackedInt32Array()
var _season: int = 0
var _season_day: int = 1
var _absolute_day: int = OPENING_DAY


func _init() -> void:
	"""Compose the real crop/weather stage, prime day 1, and lay out the six beds."""
	var rng: RngScript = RngScript.new()
	var seeded: bool = rng.seed_world(WEATHER_SEED).ok
	assert(seeded, "the farm's weather stream must seed")
	_crop_weather = CropWeatherScript.new(EcologyScript.new(), rng)
	_farming = _crop_weather.farming()
	_allocate()
	var primed: bool = _crop_weather.prime_day(OPENING_DAY)
	assert(primed, "the farm's opening weather must prime")
	for bed: int in Catalog.BED_COUNT:
		_create_bed(bed)
	for bed: int in Catalog.BED_COUNT:
		_neighbours.append(Catalog.neighbours_of(bed))


func _allocate() -> void:
	"""Size every per-bed column once."""
	for column: PackedInt32Array in [_slot, _tile, _item, _chosen, _blight_days, _day_start]:
		column.resize(Catalog.BED_COUNT)
	for column: PackedByteArray in [_covered, _raised, _banked, _fallow, _blighted, _drained, _irrigated, _ditched, _service]:
		column.resize(Catalog.BED_COUNT)
	_item.fill(NO_ITEM)
	_chosen.fill(NO_ITEM)


func _create_bed(bed: int) -> void:
	"""One bed: a FarmPlot on the bed's tile, with its opening crop if it has one."""
	var at: Vector2 = Catalog.bed_centre_m(bed)
	var nodes := _crop_weather.ecology().resource_nodes()
	var tiled: bool = nodes.tile_index_into(64 + floori(at.x / 2.0), 64 + floori(at.y / 2.0), _read)
	assert(tiled, "a farm bed must stand on the exterior grid")
	_tile[bed] = _read.value
	var made: FarmingScript.OpResult = _crop_weather.create_plot_at_tile(_tile[bed], Catalog.BED_SOILS[bed], OPENING_DAY)
	assert(made.ok, "a farm bed's plot must be created")
	_slot[bed] = made.value
	var item: int = Catalog.BED_START_ITEM[bed]
	if item != NO_ITEM:
		_grow_opening_crop(bed, item, Catalog.BED_START_HOURS[bed])


func _grow_opening_crop(bed: int, item: int, hours: int) -> void:
	"""Sow `item` on day 1 and grow it `hours` at the opening weather (the demo's history)."""
	_chosen[bed] = item
	var sown: bool = sow_start(bed).ok and sow_finish(bed).ok
	assert(sown, "an opening crop must be sowable on spring day 1")
	var tenths: int = _crop_weather.weather().temperature_tenths()
	for hour: int in hours:
		_farming.advance_growth_hour_into(_slot[bed], tenths, 0, _read)


# --- time -----------------------------------------------------------------------------------

func share_calendar(shared: CalendarScript) -> FarmingScript.OpResult:
	"""Advance `shared` -- the demo's one calendar (demo_services.gd) -- instead of a calendar of the
	farm's own. Refuses CALENDAR_ALREADY_RUNNING unless both still stand at tick 0 with nothing carried,
	so adopting it can neither lose nor repeat an hour."""
	if shared == null or calendar.tick != 0 or calendar.remainder() != 0 or shared.tick != 0 \
			or shared.remainder() != 0 or hours_run != 0:
		return _refuse(REFUSE_CALENDAR_STARTED)
	calendar = shared
	return _succeed(1)


func advance_usec(usec: int) -> int:
	"""Run the farm forward by `usec` demo microseconds: every hour crossing (and midnight) passed,
	in order. Returns how many hour crossings ran."""
	var target: int = calendar.tick + calendar.ticks_for_usec(usec)
	var crossings: int = 0
	var next: int = CalendarScript.next_hour_crossing(calendar.tick)
	while next <= target:
		calendar.tick = next
		run_hour(next)
		if CalendarScript.is_day_boundary(next):
			run_day(next)
		crossings += 1
		next += SimClock.TICKS_PER_HOUR
	calendar.tick = target
	return crossings


func run_hour(tick: int) -> void:
	"""One hour crossing: grow, freeze and expire every bed at its own temperature (see the header)."""
	var elapsed: SimClock.Calendar = calendar.calendar_at(tick - 1)
	var frost: bool = Weather.is_frost_hour(elapsed.season, elapsed.season_day, elapsed.hour)
	var air: int = Weather.air_tenths(_crop_weather.weather().temperature_tenths(), frost)
	for bed: int in Catalog.BED_COUNT:
		_hour_bed(bed, tick, air)
	_sync_blight()
	if calendar.calendar_at(tick).hour == COVER_OFF_HOUR:
		_covered.fill(0)
	hours_run += 1
	revision += 1


func _hour_bed(bed: int, tick: int, air: int) -> void:
	"""REQ-SET-072 growth, REQ-SET-084 frost and REQ-SET-075 expiry for one bed and one hour."""
	var slot: int = _slot[bed]
	var tenths: int = Weather.bed_tenths(air, _covered[bed] == 1, _raised[bed] == 1)
	if _farming.advance_growth_hour_into(slot, tenths, tick, _read) and _farming.is_ripe(slot):
		_note(EVENT_RIPENED, bed)
	if tenths < FarmingScript.FROST_TEMPERATURE_TENTHS and _is_growing(slot):
		if _farming.apply_frost_hour(slot, tenths).ok and _farming.is_withered(slot):
			_note(EVENT_WITHERED, bed)
	if _farming.is_ripe_expired(slot, tick) and _farming.apply_ripe_expiry(slot, tick).ok:
		_note(EVENT_WITHERED, bed)


func run_day(boundary_tick: int) -> void:
	"""One midnight: demo blight for the completed day, the stage's real day, then the beds' own."""
	_blight_completed_day()
	for bed: int in Catalog.BED_COUNT:
		_day_start[bed] = moisture_of(bed)
	var ran: bool = _crop_weather.run_day_into(boundary_tick, 0, _day)
	if not ran:
		push_warning("farm day refused: %s" % _day.error)
		return
	_absolute_day = _day.absolute_day
	_season = _day.season
	_season_day = _day.season_day
	for bed: int in Catalog.BED_COUNT:
		_moisture_day(bed, _day.moisture_delta)
		if _farming.state_of(_slot[bed]).value == FarmingScript.STATE_EMPTY:
			_farming.apply_fallow_day(_tile[bed], _absolute_day)
	_farming.refresh_compost_mirrors_into(_absolute_day, _read)
	_spread_blight()
	if Weather.is_blight_outbreak(_season, _season_day):
		_start_outbreak()
	days_run += 1
	revision += 1


# --- moisture -------------------------------------------------------------------------------

func _moisture_day(bed: int, weather_delta: int) -> void:
	"""A bed's own moisture change after the weather's (`day_delta`), applied."""
	var delta: int = day_delta(bed, weather_delta, _service[bed], _day_start[bed])
	if delta != 0:
		_farming.apply_moisture_delta(_slot[bed], delta)


func day_delta(bed: int, weather_delta: int, service: int, before: int) -> int:
	"""What a midnight does to a bed's moisture after the weather's `weather_delta`, with the leat's `service` worked
	on `before` (the bed's moisture before the weather; THE GARDEN LEAT): banked, then the leat or a tunnel watering
	it (or a tunnel draining it), raised, ditched, then the natural drainage of a bed above its band. A read."""
	var moisture: int = moisture_of(bed)
	var delta: int = 0
	if _banked[bed] == 1 and weather_delta < 0:
		@warning_ignore("integer_division") delta += (-weather_delta) / 2
	var low: int = band_min_of(bed)
	var high: int = band_max_of(bed)
	var watered: bool = _irrigated[bed] == 1 or Sluice.is_watering(service)
	if Sluice.is_watering(service):
		delta += leat_delta(service, before, low, high)
	elif _irrigated[bed] == 1:
		@warning_ignore("integer_division") delta += clampi((low + high) / 2 - (moisture + delta), -IRRIGATE_PER_DAY, IRRIGATE_PER_DAY)
	elif _drained[bed] == 1:
		delta -= clampi(moisture + delta - (low + DRAIN_MARGIN), 0, DRAIN_PER_DAY)
	if _raised[bed] == 1 and not watered:
		delta -= clampi(moisture + delta - (low + DRAIN_MARGIN), 0, RAISED_DRAIN_PER_DAY)
	if _ditched[bed] == 1 and not watered:
		delta -= clampi(moisture + delta - (low + DRAIN_MARGIN), 0, DITCH_DRAIN_PER_DAY)
	delta -= clampi(moisture + delta - high, 0, NATURAL_DRAIN_PER_DAY)
	return delta


static func leat_delta(service: int, moisture: int, low: int, high: int) -> int:
	"""The leat's own nudge to a bed at `moisture` with band [low, high] (see THE GARDEN LEAT): NORMAL toward the
	middle either way, WET up toward the WET band's middle only, DRY and NONE nothing."""
	if service == Sluice.SERVICE_NORMAL:
		return clampi((low + high) / 2 - moisture, -LEAT_PER_DAY, LEAT_PER_DAY)
	if service == Sluice.SERVICE_WET:
		return clampi(high + WET_ABOVE_TOP - moisture, 0, LEAT_PER_DAY)
	return 0


func flood_surge(bed: int, service: int) -> int:
	"""How much a flood passing down the leat would raise bed `bed` now with `service` (see THE GARDEN LEAT): a WET
	bed to FLOOD_OVER_WET past its WET band, a NORMAL one to WET_ABOVE_TOP over its band; never lowered, never past
	the moisture scale's top."""
	var target: int = 0
	if service == Sluice.SERVICE_WET:
		target = band_max_of(bed) + FarmingScript.MOISTURE_NEAR_MARGIN + FLOOD_OVER_WET
	elif service == Sluice.SERVICE_NORMAL:
		target = band_max_of(bed) + WET_ABOVE_TOP
	return clampi(mini(target, FarmingScript.MOISTURE_MAX) - moisture_of(bed), 0, FarmingScript.MOISTURE_MAX)


func apply_flood_surge(bed: int) -> int:
	"""A flood has passed down the leat: raise bed `bed` by `flood_surge` for its service now (through
	`apply_moisture_delta()`). Returns the rise applied."""
	if not Catalog.is_bed(bed):
		return 0
	var surge: int = flood_surge(bed, _service[bed])
	if surge == 0:
		return 0
	var before: int = moisture_of(bed)
	_farming.apply_moisture_delta(_slot[bed], surge)
	revision += 1
	return moisture_of(bed) - before


func _band_crop(bed: int) -> int:
	"""The §5.6 crop row a bed's moisture is judged by: its standing crop, else its chosen one."""
	if _item[bed] != NO_ITEM:
		return Catalog.crop_of(_item[bed])
	if _chosen[bed] != NO_ITEM:
		return Catalog.crop_of(_chosen[bed])
	return FarmingScript.CROP_NONE


func band_min_of(bed: int) -> int:
	"""The low side of a bed's moisture band (§5.6's crop minimum; EMPTY_BAND_MIN for no crop)."""
	var crop: int = _band_crop(bed)
	return EMPTY_BAND_MIN if crop == FarmingScript.CROP_NONE else FarmingScript.CROP_MOISTURE_MIN[crop]


func band_max_of(bed: int) -> int:
	"""The high side of a bed's moisture band (§5.6's crop maximum; EMPTY_BAND_MAX for no crop)."""
	var crop: int = _band_crop(bed)
	return EMPTY_BAND_MAX if crop == FarmingScript.CROP_NONE else FarmingScript.CROP_MOISTURE_MAX[crop]


func band_of(bed: int) -> int:
	"""BAND_*: the bed's moisture against its band, split where §5.6's moisture factor changes."""
	return band_at(bed, moisture_of(bed))


func band_at(bed: int, moisture: int) -> int:
	"""BAND_*: where `moisture` would stand against the bed's band (the sluice's flood preview asks)."""
	var low: int = band_min_of(bed)
	var high: int = band_max_of(bed)
	if moisture < low - FarmingScript.MOISTURE_NEAR_MARGIN:
		return BAND_DRY
	if moisture < low:
		return BAND_LOW
	if moisture <= high:
		return BAND_GOOD
	if moisture <= high + FarmingScript.MOISTURE_NEAR_MARGIN:
		return BAND_WET
	return BAND_WATERLOGGED


# --- blight (demo outbreaks; §5.6 damage) ---------------------------------------------------

func _blight_completed_day() -> void:
	"""REQ-SET-087's day of damage on every blighted growing bed, before the tending flags reset."""
	for bed: int in Catalog.BED_COUNT:
		if _blighted[bed] == 1 and _is_growing(_slot[bed]):
			if _farming.apply_blight_day(_slot[bed]).ok and _farming.is_withered(_slot[bed]):
				_note(EVENT_WITHERED, bed)
	_sync_blight()


func _spread_blight() -> void:
	"""Each bed blighted since the previous midnight infects its growing neighbours; ages the rest."""
	var spreading := PackedInt32Array()
	for bed: int in Catalog.BED_COUNT:
		if _blighted[bed] == 1 and _blight_days[bed] >= 1:
			spreading.append(bed)
		if _blighted[bed] == 1:
			_blight_days[bed] += 1
	for bed: int in spreading:
		for other: int in _neighbours[bed]:
			if _blighted[other] == 0 and _is_growing(_slot[other]):
				_infect(other)
				_note(EVENT_BLIGHT_SPREAD, other)


func _start_outbreak() -> void:
	"""A scheduled outbreak takes one growing, unblighted bed, chosen by the day (deterministic)."""
	var candidates := PackedInt32Array()
	for bed: int in Catalog.BED_COUNT:
		if _blighted[bed] == 0 and _is_growing(_slot[bed]):
			candidates.append(bed)
	if candidates.is_empty():
		return
	var bed: int = candidates[_absolute_day % candidates.size()]
	_infect(bed)
	_note(EVENT_BLIGHT, bed)


func _infect(bed: int) -> void:
	"""Mark a bed blighted as of now."""
	_blighted[bed] = 1
	_blight_days[bed] = 0


func _sync_blight() -> void:
	"""Blight lives only on a growing crop: a harvested, ripened, withered or cleared bed is clean."""
	for bed: int in Catalog.BED_COUNT:
		if _blighted[bed] == 1 and not _is_growing(_slot[bed]):
			_blighted[bed] = 0
			_blight_days[bed] = 0


func infect_for_test(bed: int) -> void:
	"""Blight a bed now (fixtures and the scripted check only)."""
	_infect(bed)
	revision += 1


# --- the player's verbs -----------------------------------------------------------------------

func choose(bed: int, item: int) -> FarmingScript.OpResult:
	"""Pick what the bed grows next (the picker). Sowing is a separate job."""
	if not Catalog.is_bed(bed):
		return _refuse(REFUSE_NOT_A_BED)
	if not Catalog.is_item(item):
		return _refuse(REFUSE_NOT_AN_ITEM)
	_chosen[bed] = item
	revision += 1
	return _succeed(item)


func sow_refusal(bed: int, item: int) -> StringName:
	"""Why `item` cannot be sown in `bed` right now, or REFUSE_NONE: fallow, occupied, soil, window."""
	if not Catalog.is_bed(bed):
		return REFUSE_NOT_A_BED
	if not Catalog.is_item(item):
		return REFUSE_NOT_AN_ITEM
	if _fallow[bed] == 1:
		return REFUSE_FALLOW
	if _farming.state_of(_slot[bed]).value != FarmingScript.STATE_EMPTY:
		return FarmingScript.REFUSE_NOT_EMPTY
	if not _farming.is_soil_compatible(Catalog.crop_of(item), Catalog.BED_SOILS[bed]):
		return FarmingScript.REFUSE_SOIL_INCOMPATIBLE
	if not _farming.is_plant_window(Catalog.crop_of(item), _season, _season_day):
		return FarmingScript.REFUSE_OUTSIDE_PLANT_WINDOW
	return REFUSE_NONE


func sow_start(bed: int) -> FarmingScript.OpResult:
	"""Productive start of sowing the chosen item: `plant()` commits its seed (the plot is SOWN)."""
	if not Catalog.is_bed(bed):
		return _refuse(REFUSE_NOT_A_BED)
	if _chosen[bed] == NO_ITEM:
		return _refuse(REFUSE_NO_ITEM)
	var code: StringName = sow_refusal(bed, _chosen[bed])
	if code != REFUSE_NONE:
		return _refuse(code)
	var sown: FarmingScript.OpResult = _farming.plant(_slot[bed], Catalog.crop_of(_chosen[bed]),
		_absolute_day, _season, _season_day)
	if sown.ok:
		_item[bed] = _chosen[bed]
	return _changed(sown)


func sow_finish(bed: int) -> FarmingScript.OpResult:
	"""Sowing completed: `begin_growing()`."""
	if not Catalog.is_bed(bed):
		return _refuse(REFUSE_NOT_A_BED)
	return _changed(_farming.begin_growing(_slot[bed]))


func water(bed: int) -> FarmingScript.OpResult:
	"""§5.6 tending: `tend()` -- restores 1000 moisture below the minimum, marks the bed tended."""
	if not Catalog.is_bed(bed):
		return _refuse(REFUSE_NOT_A_BED)
	return _changed(_farming.tend(_slot[bed]))


func harvest(bed: int) -> FarmingScript.OpResult:
	"""REQ-SET-074: `harvest()` at the neutral pollination factor (the demo has no hives). The value
	is the yield in milli-U of the bed's item, which the caller reads with item_of() BEFORE this."""
	if not Catalog.is_bed(bed):
		return _refuse(REFUSE_NOT_A_BED)
	var cut: FarmingScript.OpResult = _farming.harvest(_slot[bed], _absolute_day, calendar.tick,
		_farming.neutral_pollination_factor())
	if cut.ok:
		_item[bed] = NO_ITEM
		_chosen[bed] = NO_ITEM
		_sync_blight()
	return _changed(cut)


func clear_refusal(bed: int) -> StringName:
	"""Why a bed has nothing to clear (not withered, not blighted), or REFUSE_NONE."""
	if not Catalog.is_bed(bed):
		return REFUSE_NOT_A_BED
	if _farming.is_withered(_slot[bed]):
		return REFUSE_NONE
	if _blighted[bed] == 1 and _is_growing(_slot[bed]):
		return REFUSE_NONE
	return REFUSE_NOTHING_TO_CLEAR


func clear(bed: int) -> FarmingScript.OpResult:
	"""Clear a withered crop (`clear_withered()`), or uproot a blighted one first (see the header).
	The 0.5 U of compost REQ-SET-085 returns goes into the farm's compost store."""
	var code: StringName = clear_refusal(bed)
	if code != REFUSE_NONE:
		return _refuse(code)
	var slot: int = _slot[bed]
	if not _farming.is_withered(slot):
		_farming.apply_health_loss(slot, _farming.health_of(slot).value)
	var cleared: FarmingScript.OpResult = _farming.clear_withered(slot)
	if cleared.ok:
		compost_milli += cleared.value
		_item[bed] = NO_ITEM
		_chosen[bed] = NO_ITEM
		_sync_blight()
	return _changed(cleared)


func compost_refusal(bed: int) -> StringName:
	"""Why compost cannot go on a bed now: once a season per tile (REQ-SET-076), or a short store."""
	if not Catalog.is_bed(bed):
		return REFUSE_NOT_A_BED
	if not _farming.is_compost_eligible(_tile[bed], _absolute_day):
		return FarmingScript.REFUSE_COMPOST_NOT_ELIGIBLE
	if compost_milli < _farming.compost_milli_per_tile():
		return REFUSE_NO_COMPOST
	return REFUSE_NONE


func compost(bed: int) -> FarmingScript.OpResult:
	"""REQ-SET-076 `apply_compost()`: +1500 fertility, paid with the 2 U it returns from the compost store (see COMPOST
	IS PLANT WASTE)."""
	var code: StringName = compost_refusal(bed)
	if code != REFUSE_NONE:
		return _refuse(code)
	var applied: FarmingScript.OpResult = _farming.apply_compost(_slot[bed], _absolute_day)
	if applied.ok:
		compost_milli -= applied.value
	return _changed(applied)


func cover(bed: int) -> FarmingScript.OpResult:
	"""Straw over a bed until COVER_OFF_HOUR: COVER_WARMTH_TENTHS warmer through a frost night."""
	return _set_flag(_covered, bed)


func raise_bed(bed: int) -> FarmingScript.OpResult:
	"""Tunnel earth raises a bed: it drains, and is RAISED_WARMTH_TENTHS warmer. Permanent. No fertility (decision 0401)."""
	return _set_flag(_raised, bed)


func bank_bed(bed: int) -> FarmingScript.OpResult:
	"""Tunnel earth banks a bed: it keeps half of each day's weather loss. Permanent. No fertility (decision 0401)."""
	return _set_flag(_banked, bed)


func drain_refusal(bed: int) -> StringName:
	"""Why a bed needs no draining (its moisture at or under its band's top), or REFUSE_NONE."""
	if not Catalog.is_bed(bed):
		return REFUSE_NOT_A_BED
	return REFUSE_NONE if band_of(bed) >= BAND_WET else REFUSE_NOT_TOO_WET


func drain_bed(bed: int) -> FarmingScript.OpResult:
	"""The Drain job done: a ditch dug round a Wet or Waterlogged bed. Its moisture drops at once to
	its band's top (`apply_moisture_delta()`), and the bed is ditched for good (_moisture_day). The
	value is the moisture shed."""
	var code: StringName = drain_refusal(bed)
	if code != REFUSE_NONE:
		return _refuse(code)
	var shed: int = moisture_of(bed) - band_max_of(bed)
	var applied: FarmingScript.OpResult = _farming.apply_moisture_delta(_slot[bed], -shed)
	if not applied.ok:
		return applied
	_ditched[bed] = 1
	revision += 1
	return _succeed(shed)


func set_fallow(bed: int, resting: bool) -> FarmingScript.OpResult:
	"""Rest a bed (no sowing while fallow; an empty bed regains fertility daily either way)."""
	if not Catalog.is_bed(bed):
		return _refuse(REFUSE_NOT_A_BED)
	_fallow[bed] = 1 if resting else 0
	revision += 1
	return _succeed(_fallow[bed])


func set_tunnel_water(bed: int, drained: bool, irrigated: bool) -> void:
	"""What the tunnels under a bed do to it (farm_tunnels.gd decides; farm_sim applies it daily)."""
	var drained_now: int = 1 if drained else 0
	var irrigated_now: int = 1 if irrigated else 0
	if drained_now == _drained[bed] and irrigated_now == _irrigated[bed]:
		return
	_drained[bed] = drained_now
	_irrigated[bed] = irrigated_now
	revision += 1


func set_leat_service(bed: int, service: int) -> void:
	"""What the garden leat does for a bed (weir_sluice.gd SERVICE_*; farm_leat.gd decides, the midnight applies it).
	An unknown bed or service is ignored."""
	if not Catalog.is_bed(bed) or service < Sluice.SERVICE_NONE or service > Sluice.SERVICE_WET:
		return
	if _service[bed] == service:
		return
	_service[bed] = service
	revision += 1


func leat_service_of(bed: int) -> int:
	"""The garden leat's service to a bed (weir_sluice.gd SERVICE_*)."""
	return _service[bed]


func _set_flag(column: PackedByteArray, bed: int) -> FarmingScript.OpResult:
	"""Set a once-only bed flag, refusing an unknown bed or a flag already set."""
	if not Catalog.is_bed(bed):
		return _refuse(REFUSE_NOT_A_BED)
	if column[bed] == 1:
		return _refuse(REFUSE_ALREADY)
	column[bed] = 1
	revision += 1
	return _succeed(1)


# --- readouts -------------------------------------------------------------------------------

func stage_of(bed: int) -> int:
	"""STAGE_*: what a bed shows."""
	var slot: int = _slot[bed]
	var state: int = _farming.state_of(slot).value
	if state == FarmingScript.STATE_SOWN:
		return STAGE_SOWN
	if state == FarmingScript.STATE_RIPE:
		return STAGE_RIPE
	if state == FarmingScript.STATE_WITHERED:
		return STAGE_WITHERED
	if state != FarmingScript.STATE_GROWING:
		return STAGE_EMPTY
	if _blighted[bed] == 1:
		return STAGE_BLIGHTED
	return STAGE_SPROUTING if growth_permille(bed) < SPROUT_PERMILLE else STAGE_GROWING


func growth_permille(bed: int) -> int:
	"""Growth toward ripeness, 0..1000 (1000 once ripe; 0 with nothing growing)."""
	var slot: int = _slot[bed]
	var target: IntMath.IntResult = _farming.growth_target_milli_hours_of(slot)
	if not target.ok:
		return 0
	var grown: int = _farming.growth_milli_hours_of(slot).value
	@warning_ignore("integer_division") return mini(grown * 1000 / target.value, 1000)


func hours_to_ripe_into(bed: int, out: IntMath.IntResult) -> bool:
	"""Game hours left to ripeness at this hour's growth rate; refuses STALLED at a zero rate, or a
	bed that is not growing."""
	var slot: int = _slot[bed]
	if not _is_growing(slot):
		return out.refuse(String(FarmingScript.REFUSE_NOT_GROWING))
	var temperature: int = Weather.bed_tenths(_crop_weather.weather().temperature_tenths(), _covered[bed] == 1,
		_raised[bed] == 1)
	if not _farming.moisture_factor_into(_farming.crop_id_of(slot).value, moisture_of(bed), out):
		return false
	if not _farming.growth_step_milli_hours_into(FarmingScript.temperature_factor_of(temperature), out.value, out):
		return false
	if out.value <= 0:
		return out.refuse(String(REFUSE_STALLED))
	var left: int = _farming.growth_target_milli_hours_of(slot).value - _farming.growth_milli_hours_of(slot).value
	@warning_ignore("integer_division") return out.succeed((left + out.value - 1) / out.value)


func ripe_hours_into(bed: int, out: IntMath.IntResult) -> bool:
	"""Whole game hours since a ripe bed ripened (the grace ends at 48, it withers at 120)."""
	if not _farming.is_ripe(_slot[bed]):
		return out.refuse(String(FarmingScript.REFUSE_NOT_RIPE))
	return _farming.ripe_elapsed_hours_into(_slot[bed], calendar.tick, out)


func expected_yield_into(bed: int, out: IntMath.IntResult) -> bool:
	"""What a harvest would bring now, milli-U: REQ-SET-074 after REQ-SET-075's decay when ripe,
	the formula at today's health and fertility while growing."""
	var slot: int = _slot[bed]
	var pollination: int = _farming.neutral_pollination_factor()
	if _farming.is_ripe(slot):
		return _farming.harvest_yield_milli_into(slot, pollination, calendar.tick, out)
	return _farming.formula_yield_milli_into(slot, pollination, out)


func rotation_preview(bed: int, item: int) -> int:
	"""§5.6's rotation factor (per 1000) `item` would harvest at in this bed, from the tile's banked
	history. Calls farming.gd's own static rule (test_demo_farm.gd proves it equals
	`rotation_factor_of()` once sown) rather than restating it."""
	var slot: int = _slot[bed]
	return FarmingScript._rotation_factor(Catalog.family_of(item), _farming.last_family_of(slot).value,
		_farming.family_streak_of(slot).value)


func fertility_factor_of(bed: int) -> int:
	"""§5.6's fertility factor (500..1000) at the bed's fertility now."""
	return _farming.fertility_factor_of(_slot[bed]).value


func item_of(bed: int) -> int:
	"""The ingredient standing in a bed (sown, growing, ripe or withered), or NO_ITEM."""
	return _item[bed]


func chosen_of(bed: int) -> int:
	"""The ingredient picked for a bed's next sowing, or NO_ITEM."""
	return _chosen[bed]


func moisture_of(bed: int) -> int:
	"""A bed's moisture, 0..10000."""
	return _farming.moisture_of(_slot[bed]).value


func health_of(bed: int) -> int:
	"""A bed's crop health, 0..10000."""
	return _farming.health_of(_slot[bed]).value


func fertility_of(bed: int) -> int:
	"""A bed's fertility, 0..10000 (the tile's)."""
	return _farming.fertility_of(_slot[bed]).value


func is_covered(bed: int) -> bool:
	"""Whether straw covers the bed tonight."""
	return _covered[bed] == 1


func is_raised(bed: int) -> bool:
	"""Whether earth has raised the bed."""
	return _raised[bed] == 1


func is_banked(bed: int) -> bool:
	"""Whether earth banks the bed."""
	return _banked[bed] == 1


func is_fallow(bed: int) -> bool:
	"""Whether the bed is resting."""
	return _fallow[bed] == 1


func is_blighted(bed: int) -> bool:
	"""Whether blight is on the bed's crop."""
	return _blighted[bed] == 1


func is_drained(bed: int) -> bool:
	"""Whether a tunnel drains the bed."""
	return _drained[bed] == 1


func is_irrigated(bed: int) -> bool:
	"""Whether a tunnel from the pond waters the bed."""
	return _irrigated[bed] == 1


func is_ditched(bed: int) -> bool:
	"""Whether a drainage ditch has been dug round the bed (the Drain job)."""
	return _ditched[bed] == 1


func is_tended_today(bed: int) -> bool:
	"""Whether the bed was tended (watered) today -- halves blight, and cabbage frost."""
	return _farming.is_tile_tended_today(_tile[bed])


func season() -> int:
	"""The farm's season (0 spring .. 3 winter)."""
	return _season


func season_day() -> int:
	"""The farm's season-local day, 1..12."""
	return _season_day


func absolute_day() -> int:
	"""The farm's calendar day, from 1."""
	return _absolute_day


func air_tenths() -> int:
	"""Today's air temperature from the real weather, in tenths of a degree."""
	return _crop_weather.weather().temperature_tenths()


func forecast_event() -> int:
	"""The real weather's disclosed forecast event (weather.gd EVENT_*; EVENT_NONE for none)."""
	return _crop_weather.weather().forecast_event()


func active_event() -> int:
	"""The real weather's event active today (EVENT_NONE for none)."""
	@warning_ignore("integer_division") var absolute_season: int = (_absolute_day - 1) / SimClock.DAYS_PER_SEASON
	return _crop_weather.weather().active_event_on(absolute_season, _season_day)


func last_weather_delta() -> int:
	"""The real weather's moisture change at the last midnight (before the beds' own)."""
	return _day.moisture_delta if _day.ok else 0


func farming() -> FarmingScript:
	"""The real crop store (for readers and tests)."""
	return _farming


func crop_weather() -> CropWeatherScript:
	"""The real crop/weather stage (for tests)."""
	return _crop_weather


func slot_of(bed: int) -> int:
	"""A bed's FarmPlot row."""
	return _slot[bed]


func take_events_into(out: PackedInt32Array) -> int:
	"""Move the logged (kind, bed) pairs into `out` (appended) and forget them; returns the pairs."""
	@warning_ignore("integer_division") var pairs: int = _events.size() / 2
	out.append_array(_events)
	_events.clear()
	return pairs


func _is_growing(slot: int) -> bool:
	"""Whether a plot's crop is GROWING (the only state growth, frost and blight act on)."""
	return _farming.state_of(slot).value == FarmingScript.STATE_GROWING


func _note(kind: int, bed: int) -> void:
	"""Log one event for the alerts."""
	_events.append(kind)
	_events.append(bed)


func _changed(result: FarmingScript.OpResult) -> FarmingScript.OpResult:
	"""Pass a farming.gd result through, noting a change when it took."""
	if result.ok:
		revision += 1
	return result


func _succeed(value: int) -> FarmingScript.OpResult:
	"""A successful demo operation."""
	return FarmingScript.OpResult.new(true, REFUSE_NONE, value, FarmingScript.NULL_REF)


func _refuse(code: StringName) -> FarmingScript.OpResult:
	"""A refused demo operation: value 0, nothing changed."""
	return FarmingScript.OpResult.new(false, code, 0, FarmingScript.NULL_REF)
