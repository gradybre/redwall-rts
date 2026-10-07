extends RefCounted
## THE HEARTHS' FUEL: which hearths burn, the wood they take from the village stores each game hour, and how warm each
## room is. Decision 0571 (Brendan's ruling 2: "Hearths follow the GDD's continuous demand"). Pure logic over packed
## columns -- no nodes -- so the suite drives it hour by hour; demo_winter.gd calls `pass_hour` once for every game
## hour the one calendar crosses, in order. Integer throughout; presentation only (the settlement is not written).
##
## THE SOURCES. One row per burrow home (underground_rooms.gd row r, 0..MAX_ROOMS-1), one more, HALL, for the
## village hall -- GDD §5.8's "residence/hall hearth" and REQ-SET-133's "heated hall" the bedless sleep in -- and one
## more, INFIRMARY, for the infirmary building (decision 0995; Brendan's ruling on the review's R03, 2026-10-02: "the
## infirmary is its own heated interior with its own hearth and fuel, under the same rules as homes"). A home's hearth
## is its INSTALLED fit-out hearth (room_fixtures.gd); the hall's is the hall's own; the infirmary's stands once it is
## built (GDD §5.9's room validity: an infirmary is "heated"; its 6×6 interior is within one hearth's 120 tiles, so it
## burns as one normal hearth, §5.8).
##
## EACH HOUR (`pass_hour`), for each source in row order -- the homes, then the hall, then the infirmary -- its STATE:
##   NONE     no hearth: nothing burns; the room drifts toward the outside air.
##   BANKED   the player let it go out (the fuel panel's emergency choice): no demand, no heat.
##   IDLE     a hearth, but no heat is demanded today (summer; a mild spring or autumn day): nothing burns.
##   HEATED   demanded, and the hour's wood was taken: the room holds 18 °C (20 °C at tier 2).
##   OUT      demanded, and the stores could not give the hour's wood: OUT OF FUEL -- the room converges halfway toward
##            the outside air each hour (REQ-SET-131) until wood comes in; the next hour it is taken again.
## THE ACCUMULATOR (ruling 2: "Take the wood hourly through a milli-U accumulator; integer state only"). Each demanded
## hour adds the day's rate (milli-U a day) to the hearth's `burn_acc`; the hour takes `burn_acc / 24` whole milli-U
## from the stores -- all of it, or (OUT) none, the hour's share then given back to the accumulator -- and keeps the
## rest. Over a day exactly the day's rate is taken, never a milli-U more or less however the hours fall.
##
## THE TIER (decision 1652; Brendan's batch-7 ruling 5, decision 0902: "a per-source tier factor"). Each source carries
## its building's tier (`tier`, `set_tier`; tier 1 unless told). A tier-2 source burns at x0.75 (§5.9, REQ-SET-136) --
## `rate_of(s)` is today's demand at its tier, and every figure that sums the hearths (`heating_day_milli`,
## `winter_day_milli`, so the fuel-days, the last heated hour and the projection) sums the per-source rates -- and its
## room holds 20 °C when heated (REQ-SET-130). The demo's homes and the infirmary are tier 1; the hall is tier 2 once
## raised (demo_winter.gd reads it each hour). `day_rate_milli` stays the tier-1 rate.
## THE GLOW (`hearth_lit`): HEATED -- fuelled AND demanded. The day/night look over that is the lighting's (it reads
## this query). COMFORT (room_fixtures.gd `hearth_cold`): a hearth counts while it is not OUT or BANKED. WARM BEDS
## (night_routine.gd): a home is WARM while it is HEATED or no heat is demanded at all.
##
## COOKING (§5.8: fuel-days include "this last-three-days mean cooking use"): `note_cooking` is handed the kitchen's
## running wood total each hour; at each midnight the day's use goes into a ring of COOK_MEAN_DAYS days.
##
## THE METRICS the balance sim reads (decision 0571): `burned_milli` (all wood burned in hearths), `heated_hours` and
## `cold_hours` (source-hours HEATED and OUT), `fuel_days_hundredths()`, `heating_day_milli()`, `cook_mean_milli()`,
## `last_heated_hour()`, `projection_milli()`. Nothing per hour allocates.

const Rules := preload("res://demo/winter/winter_rules.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")

const STATE_NONE: int = 0
const STATE_BANKED: int = 1
const STATE_IDLE: int = 2
const STATE_HEATED: int = 3
const STATE_OUT: int = 4
const STATE_WORDS: Array[String] = ["no hearth", "let go out", "not needed today", "heated", "out of fuel"]
const ROOMS: int = RoomsScript.MAX_ROOMS
## The hall's row, after the homes', and the infirmary's after it (see THE SOURCES).
const HALL: int = RoomsScript.MAX_ROOMS
const INFIRMARY: int = RoomsScript.MAX_ROOMS + 1
const SOURCES: int = RoomsScript.MAX_ROOMS + 2
## A room's temperature before its first hour: unknown, set from the air at the first pass.
const UNSET_TENTHS: int = -100000

## Per source (see THE SOURCES): an installed hearth (1), banked by the player (1), this hour's STATE, the room's
## temperature (tenths of a degree), the burn accumulator (milli-U x hours, see THE ACCUMULATOR), and the hour index it
## last ran out (-1: never).
var hearth: PackedByteArray = PackedByteArray()
var banked: PackedByteArray = PackedByteArray()
var state: PackedByteArray = PackedByteArray()
var room_tenths: PackedInt32Array = PackedInt32Array()
var burn_acc: PackedInt64Array = PackedInt64Array()
var out_since: PackedInt32Array = PackedInt32Array()
## Per source, its building's tier (winter_rules.gd TIER_1 / TIER_2; see THE TIER).
var tier: PackedByteArray = PackedByteArray()
## Today's demand a tier-1 hearth (milli-U a day), the day's mean and the hour's air (tenths), as the last pass read them.
var day_rate_milli: int = 0
var day_mean_tenths: int = 0
var air_tenths: int = 0
var season: int = 0
## The last hour passed (-1: none yet).
var hour_index: int = -1
## THE METRICS (see the header).
var burned_milli: int = 0
var heated_hours: int = 0
var cold_hours: int = 0
## Bumped whenever a source's state, a hearth or a choice changes.
var revision: int = 0

var _stores: StoresScript = null
var _cook_days: PackedInt64Array = PackedInt64Array()
var _cook_filled: int = 0
var _cook_day_start: int = -1
var _cook_total: int = 0
var _cook_day: int = -1


func _init() -> void:
	"""Size every column once."""
	hearth.resize(SOURCES)
	banked.resize(SOURCES)
	state.resize(SOURCES)
	room_tenths.resize(SOURCES)
	room_tenths.fill(UNSET_TENTHS)
	burn_acc.resize(SOURCES)
	out_since.resize(SOURCES)
	out_since.fill(-1)
	tier.resize(SOURCES)
	tier.fill(Rules.TIER_1)
	_cook_days.resize(Rules.COOK_MEAN_DAYS)


func bind_stores(stores: StoresScript) -> void:
	"""Burn from these stores' wood (the village's one stores)."""
	_stores = stores


func set_hearth(source: int, on: bool) -> void:
	"""Whether `source` has an installed hearth (a home's fit-out; the hall's own; the infirmary's once built)."""
	var value: int = 1 if on else 0
	if hearth[source] != value:
		hearth[source] = value
		revision += 1


func set_banked(source: int, on: bool) -> void:
	"""The player lets `source`'s hearth go out (on), or lights it again (off). Takes effect at the next hour."""
	var value: int = 1 if on else 0
	if banked[source] != value:
		banked[source] = value
		revision += 1


func set_tier(source: int, p_tier: int) -> void:
	"""`source`'s building tier (see THE TIER): its rate and its heated room follow from the next hour, its share of
	today's figures at once."""
	var value: int = clampi(p_tier, Rules.TIER_1, Rules.TIER_2)
	if tier[source] != value:
		tier[source] = value
		revision += 1


func rate_of(source: int) -> int:
	"""`source`'s fuel today (milli-U a day): today's demand at its tier (see THE TIER) -- `day_demand_milli`'s own
	scaling of the tier-1 rate the last pass read (0 before the first)."""
	return Rules.div(day_rate_milli * Rules.tier_fuel_permille(tier[source]), Rules.FULL_PERMILLE)


func winter_rate_of(source: int) -> int:
	"""`source`'s fuel on a WINTER day at its tier (milli-U): 4 U, 3 U at tier 2."""
	return Rules.day_demand_milli(WeatherScript.SEASON_WINTER, 0, Rules.tier_fuel_permille(tier[source]))


func pass_hour(p_hour_index: int, p_season: int, mean_tenths: int, air: int) -> void:
	"""One game hour (see EACH HOUR): today's demand from the season and the day's mean, the hour's air for the
	cooling rooms. Call once per hour crossed, in order."""
	hour_index = p_hour_index
	season = p_season
	day_mean_tenths = mean_tenths
	air_tenths = air
	day_rate_milli = Rules.day_demand_milli(p_season, mean_tenths)
	for s: int in SOURCES:
		var was: int = state[s]
		state[s] = _state_for(s)
		if state[s] == STATE_OUT and was != STATE_OUT:
			out_since[s] = p_hour_index
		_warm_room(s)
		if state[s] != was:
			revision += 1


func _state_for(s: int) -> int:
	"""Source `s`'s state this hour, burning its wood when it is demanded (see THE ACCUMULATOR)."""
	if hearth[s] == 0:
		return STATE_NONE
	if banked[s] == 1:
		return STATE_BANKED
	var rate: int = rate_of(s)
	if rate <= 0:
		return STATE_IDLE
	burn_acc[s] += rate
	var take: int = Rules.div(burn_acc[s], Rules.HOURS_PER_DAY)
	if take > 0 and (_stores == null or not _stores.take_wood(take)):
		burn_acc[s] -= rate
		cold_hours += 1
		return STATE_OUT
	burn_acc[s] -= take * Rules.HOURS_PER_DAY
	burned_milli += take
	heated_hours += 1
	return STATE_HEATED


func _warm_room(s: int) -> void:
	"""The room's temperature for the hour: 18 °C heated (20 °C at tier 2), else halfway toward the air (the first hour:
	the air)."""
	if state[s] == STATE_HEATED:
		room_tenths[s] = Rules.heated_tenths(tier[s])
	elif room_tenths[s] == UNSET_TENTHS:
		room_tenths[s] = air_tenths
	else:
		room_tenths[s] = Rules.converge_tenths(room_tenths[s], air_tenths)


# --- cooking (see COOKING) -------------------------------------------------------------------------------

func note_cooking(total_milli: int, day: int) -> void:
	"""The kitchen's running wood total at day `day` (demo days from spring 1): at each new day the last day's use goes
	into the ring."""
	if _cook_day < 0:
		_cook_day = day
		_cook_day_start = total_milli
	while _cook_day < day:
		_cook_days[_cook_filled % Rules.COOK_MEAN_DAYS] = total_milli - _cook_day_start if _cook_day == day - 1 else 0
		_cook_filled += 1
		_cook_day += 1
		_cook_day_start = total_milli
	_cook_total = total_milli


func rebase_cooking(total_milli: int, day: int) -> void:
	"""After a season skip: the kitchen did not cook through it, so the skipped days are NOT pushed into the ring as days
	of no cooking (review M2) -- the count simply starts again at `day` from `total_milli`."""
	_cook_day = day
	_cook_day_start = total_milli
	_cook_total = total_milli


func cook_mean_milli() -> int:
	"""The last COOK_MEAN_DAYS whole days' mean cooking wood (milli-U a day); 0 before a whole day has passed."""
	var days: int = mini(_cook_filled, Rules.COOK_MEAN_DAYS)
	if days == 0:
		return 0
	var total: int = 0
	for k: int in days:
		total += _cook_days[k]
	return Rules.div(total, days)


# --- the queries ---------------------------------------------------------------------------------------

func hearth_lit(source: int) -> bool:
	"""THE GLOW'S QUERY: whether `source`'s hearth burns now -- fuelled AND demanded (see THE GLOW)."""
	return _valid(source) and state[source] == STATE_HEATED


func is_heated(source: int) -> bool:
	"""Whether `source`'s room is held at 18 °C (20 °C at tier 2) this hour."""
	return hearth_lit(source)


func is_out(source: int) -> bool:
	"""Whether `source`'s hearth is out of fuel while heat is demanded (REQ-SET-131)."""
	return _valid(source) and state[source] == STATE_OUT


func hearth_cold(source: int) -> bool:
	"""Whether `source`'s hearth gives no comfort now: out of fuel, or let go out (see THE GLOW)."""
	return _valid(source) and (state[source] == STATE_OUT or state[source] == STATE_BANKED)


func is_warm(source: int) -> bool:
	"""Whether a bed in `source` is a WARM bed now: its room heated, or no heat demanded at all."""
	return _valid(source) and (state[source] == STATE_HEATED or day_rate_milli <= 0)


func demanded() -> bool:
	"""Whether heat is demanded today."""
	return day_rate_milli > 0


func temperature_of(source: int) -> int:
	"""`source`'s room temperature (tenths of a degree); the air's before its first hour."""
	if not _valid(source) or room_tenths[source] == UNSET_TENTHS:
		return air_tenths
	return room_tenths[source]


func burning_count() -> int:
	"""Hearths installed and not let go out: what today's demand is counted on."""
	var n: int = 0
	for s: int in SOURCES:
		n += 1 if hearth[s] == 1 and banked[s] == 0 else 0
	return n


func out_count() -> int:
	"""Hearths out of fuel this hour."""
	var n: int = 0
	for s: int in SOURCES:
		n += 1 if state[s] == STATE_OUT else 0
	return n


func heating_day_milli() -> int:
	"""Today's heating demand: every burning hearth at today's rate for its tier (milli-U a day)."""
	var total: int = 0
	for s: int in SOURCES:
		total += rate_of(s) if hearth[s] == 1 and banked[s] == 0 else 0
	return total


func winter_day_milli() -> int:
	"""A WINTER day's heating demand: every burning hearth at 4 U, or 3 U at tier 2 (milli-U a day)."""
	var total: int = 0
	for s: int in SOURCES:
		total += winter_rate_of(s) if hearth[s] == 1 and banked[s] == 0 else 0
	return total


func reduced_count() -> int:
	"""Burning hearths at a reduced (tier-2) rate."""
	var n: int = 0
	for s: int in SOURCES:
		n += 1 if hearth[s] == 1 and banked[s] == 0 and tier[s] >= Rules.TIER_2 else 0
	return n


func wood_milli() -> int:
	"""The wood the hearths draw on (the stores'; 0 without)."""
	return _stores.wood_milli_u if _stores != null else 0


func fuel_days_hundredths() -> int:
	"""§5.8's fuel-days now, in hundredths; Rules.NO_DEMAND with no heating demand."""
	return Rules.fuel_days_hundredths(wood_milli(), heating_day_milli(), cook_mean_milli())


func last_heated_hour() -> int:
	"""REQ-SET-147's estimated last heated hour (a calendar hour index); -1 with no demand."""
	if heating_day_milli() <= 0:
		return -1
	return maxi(hour_index, 0) + Rules.hours_of_fuel(wood_milli(), heating_day_milli(), cook_mean_milli())


func projection_milli() -> int:
	"""REQ-SET-114 / ruling 6: twelve winter days of demand at the hearths burning now (each at its tier's rate), plus
	the cooking mean."""
	return Rules.projection_of_milli(winter_day_milli(), cook_mean_milli())


func _valid(source: int) -> bool:
	"""Whether `source` names a row."""
	return source >= 0 and source < SOURCES
