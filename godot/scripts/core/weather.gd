extends RefCounted
## The Weather store of GDD §4.2 and the part of §5.10 the document set fully specifies: the
## four-row season baseline table, the seven-row event table, the season-eligible weighted draw,
## the forecast disclosure, the moisture arithmetic, and the daylight/hunger/darkness readers of
## REQ-SET-141, 142, 143, 145 and 148.
##
## SCHEMA, restated from the documents rather than summarised.
##   * GDD §4.2: "Weather | event: enum, start_day: int32, duration_days: int32,
##     temperature_tenths: int32, rain: int32, forecast: int32[3] | One active major event/world;
##     daily baseline independently". systems_architecture.md §2.2 flattens the same row to
##     "event, start_day, duration_days, temperature_tenths, rain, forecast_0, forecast_1,
##     forecast_2 | I32 | 4 | 8 | 1 | 32" -- eight int32 columns, ONE row, 32 bytes. The two agree
##     column for column and _init() asserts the width.
##   * With one row, structure-of-arrays degenerates: the store IS the row. It is held as a single
##     eight-entry PackedInt32Array indexed by the COL_* constants below, which is exactly §2.2's
##     32 bytes, allocated once in _init() and never resized (ARCH-MEM-001/005). NO COLUMN IS
##     ADDED to §4.2's eight; see "THE SEASON IS NOT IN THE ROW" below for what that costs.
##   * There is no EntityDirectory reference here. §4.2 gives Weather no owner and no `EntityRef`
##     field, and one global row needs no slot/generation validation, so this module allocates
##     nothing from the shared directory.
##
## ---------------------------------------------------------------------------------------
## THE SELECTION ALGORITHM, AS RULED. §5.10 says only "Weights are normalized within the season's
## eligible rows", which fixes no scan order, no tie rule and no rounding -- the gap
## docs/tasks/03_ecology_crops_weather.md recorded as blocking this increment. The ruling that
## unblocked it is transcribed here in full, because the code below is meaningless without it:
##
##     Use the event order printed in §5.10: 1 Ideal spell, 2 Heavy rain/storm, 3 Drought,
##     4 Blight, 5 Early frost, 6 Hard freeze, 7 Calm days. Filter that sequence to rows eligible
##     in the selected season. Retain raw integer weights; do not convert to rounded percentages.
##
##         eligible_rows = season-eligible rows in the fixed order above
##         weight_sum    = sum(row.weight for row in eligible_rows)
##         roll          = uint32_draw mod weight_sum
##         cumulative    = 0
##         for row in eligible_rows:
##             cumulative += row.weight
##             if roll < cumulative:
##                 select row; stop
##
##     "Normalized" means relative probability within the eligible set. No numeric percentage
##     normalization is performed.
##
## The comparison is STRICTLY `roll < cumulative` and the weights stay raw integers, so no
## rounding step exists to disagree about. The resulting map, all intervals inclusive:
##
##     Spring  85 | Ideal 0-29   | Heavy rain 30-64 | Calm 65-84
##     Summer 120 | Ideal 0-29   | Drought 30-79    | Blight 80-99   | Calm 100-119
##     Autumn 135 | Ideal 0-29   | Heavy rain 30-64 | Blight 65-84   | Early frost 85-114
##                | Calm 115-134
##     Winter 110 | Ideal 0-29   | Hard freeze 30-89| Calm 90-109
##
## test_weather.gd encodes that table as its own independent data and asserts this module
## reproduces it row by row and on both sides of every boundary, rather than re-deriving it from
## the constants below -- a re-derivation would prove only that the module agrees with itself.
##
## ---------------------------------------------------------------------------------------
## MODULO BIAS IS DISCLOSED, NOT REMOVED. ARCH-RNG-002: "Bounded selections use modulo with the
## same disclosed small bias as the crowd document; no rejection sampling changes unspecified
## draw counts." draw_below_into() performs exactly one draw and one `%`, so the residues below
## `2^32 mod weight_sum` are over-represented by one part in 2^32: that is 1 residue in spring
## (2^32 mod 85 == 1), 16 in summer (mod 120), 76 in autumn (mod 135) and 26 in winter (mod 110).
## The largest of those biases the autumn ideal-spell interval upward by 76/2^32, about 1.8e-8
## relative. NO REJECTION SAMPLING IS ADDED HERE: a rejection loop consumes a variable number of
## draws, which is exactly what ARCH-RNG-002's fixed "one weighted event-selection roll per new
## season" forbids, and it would desynchronise every later replay of the WEATHER stream.
##
## ---------------------------------------------------------------------------------------
## DRAW DISCIPLINE. ARCH-RNG-002: "WEATHER | One weighted event-selection roll per new season
## after the forced first spring | Season index; forced onboarding event consumes zero draws".
##   * schedule_season_event() takes exactly one draw, after validating the season and (inside
##     draw_below_into) the bound, so a refused call consumes none.
##   * schedule_first_spring_event() TAKES NO Rng PARAMETER AT ALL. §5.10's "First spring is
##     forced Ideal spell on day 6 as onboarding" consumes zero draws, and that is enforced
##     structurally rather than by convention -- the forced path has no stream to draw from, in
##     the manner fishing.gd's harvest() takes no `intensive` argument.
##   * The season index ORDERS the event; it never reseeds. Nothing in this module calls
##     seed_world(), restore_stream() or clear() on an Rng, so WEATHER state continues across
##     every season boundary exactly as ARCH-RNG-002 initialised it.
##   * BAL-SAFE-017 ("opening forecasts, saving, loading, or changing speed SHALL consume no
##     event roll") holds by construction: disclose_forecast(), refresh_daily(), end_event() and
##     every reader here take no Rng.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS MODULE DELIBERATELY DOES NOT DO. None of it is stubbed; the numbers are simply not
## compiled in, so nothing here can drift from a contract that does not exist yet.
##   * REQ-SET-144's CLOTHING/EXPOSURE ACCUMULATION. "Tier 2 clothing removes baseline cold
##     exposure at-5°C, but hard freeze adds 1/hour even with that clothing" needs per-resident
##     clothing tier and an exposure accumulator, neither of which this store owns. The event
##     table's stated "outdoor exposure accumulation×2" is transcribed and reported by
##     exposure_multiplier_per_1000_of(); nothing is accumulated here.
##   * REQ-SET-146/147's FOOD-DAYS AND FUEL-DAYS ALERTS. Both are stock projections over
##     inventory and heating demand (§5.8), plus a Notice store; this module owns neither. The
##     forecast temperature REQ-SET-147 tests against is available from the readers below.
##   * CROP GROWTH AND BLIGHT DAMAGE. §5.6's FarmPlot is increment 6. The stated numbers --
##     crop growth×1.20 and 400 damage/day -- are transcribed and reported as pure per-1000 and
##     per-day readers, and NO plot state is written here; moisture_after_day_into() likewise
##     answers a question about a caller-supplied moisture and stores nothing.
##   * MUSSEL'S SUMMER BLIGHT CLOSURE. fishing.gd records "summer mussel harvest closes" as a
##     weather-dependent condition it will not evaluate. closes_mussel_harvest_on() is the reader
##     that answers it; this module does NOT reach into fishing.gd, because ruling 2026-09-11
##     §4.1 gives the weather-to-fishery join and the `FishStock.closed` event bit to
##     ARCH-SYS-006, which is `crop_weather.gd`.
##   * BOAT DISABLING AND LAKE-ICE ACCESS. REQ-SET-051/052 need the gear and expedition stores,
##     still blocked by U5. disables_boats() and lake_ice_access_only() report the event table's
##     own flags; no departure is prevented here because no departure exists to prevent.
##   * TORCH AND CANDLE CONSUMPTION. "one candle lasts 12 game hours, one torch consumes wood
##     0.25 U/6h" and the 12 m radius are inventory and spatial contracts. REQ-SET-148's 0.75
##     darkness factor is supplied; whether a station is lit is the caller's input.
##   * THE DAILY ORCHESTRATION. ARCH-SYS-006 (increment 10) owns the ordering -- season advance,
##     schedule, disclose, refresh, end -- and ARCH-TICK-003 fixes where it sits at midnight.
##     This module provides the operations and wires no tick.
##
## ---------------------------------------------------------------------------------------
## GAPS -- named, not invented (AGENTS.md: "do not invent a constant"):
##   * `Weather.event` IS AN `EventDefinition` ID, AND THIS MODULE PREVIOUSLY GOT IT WRONG. An
##     earlier header here claimed §4.3 numbers no weather-event enum and concluded a ruling was
##     needed. The rule was already stated and was missed: GDD §4.2's closing paragraph numbers
##     every gameplay enum it does not individually list from the ascending ASCII keys of its own
##     domain, `EventDefinition` is one of §4.3's own catalog rows, and BAL-CAT-001 repeats the
##     rule. The ids are therefore blight=0, calm_days=1, drought=2, early_frost=3,
##     hard_freeze=4, heavy_rain=5, ideal_spell=6 -- agreeing with §5.10's printed table order on
##     drought alone. They live in catalog.gd's COMPILED_ENUM_DOMAINS and are read from there,
##     never mirrored, and stay OUT of PROTECTED_ENUM_DOMAINS, which means "§4.3 stated this
##     number" and applies to none of them (decision 0018).
##     SELECTION ORDER IS NOT ID ORDER, and conflating them was the actual defect. The ruled
##     traversal above is unchanged and lives in EVENT_SELECTION_ORDER; the scan picks a row in
##     that sequence and then stores that row's compiled id, so every draw count and every
##     interval boundary is byte-identical to before and only the stored number differs. Every
##     EVENT_* table is reindexed to the compiled ids, so no array is written in one order and
##     read in another. `event` is persisted state: the old ordinals are NOT interchangeable with
##     these, so any retained snapshot is translated through Catalog.convert_legacy_id()
##     (EventDefinition map [6,5,2,0,3,4,1]) or refused.
##   * `EventDefinition.modifiers` IS "a fixed int32 vector" WITH NO STATED WIDTH OR FIELD ORDER.
##     §4.3 names the field and nothing anywhere says what its slots mean. No modifier vector is
##     emitted here; the effects column is compiled as one named constant table per stated
##     quantity, so every number has a name and none depends on a slot index nobody defined.
##     `season_mask` follows BAL-CROP-001's stated `1<<enum` convention for `allowed_soils`,
##     which is an ANALOGY to a different field and is labelled as one.
##   * WHAT `forecast: int32[3]` HOLDS WAS NOT STATED, AND IS NOW RULED. REQ-SET-142 requires
##     disclosing "its start, duration, and affected systems" and §4.2 gives exactly three int32
##     slots, so the obvious pairing is (start, duration, affected-systems mask). THAT READING IS
##     REJECTED, and ruling 2026-09-11 §4.2 adopted the rejection: "keep the eight existing
##     Weather I32 fields, including the current interpretation of `forecast[3]` as
##     `(event_id,start_season_day,duration_days)`". The affected systems ARE a function of the
##     event -- effect_mask_for() derives them from the effects column, so nothing is lost -- and
##     `event` is documented as the world's ONE active event, leaving the forecast as the only
##     place a disclosed schedule can be retained after the event ends. The derived mask is NEVER
##     STORED, so no save carries a guess about a taxonomy.
##   * THE SEASON WAS NOT IN THE ROW, AND NOW IS (ruling 2026-09-11 §4.2, decision 0055).
##     §4.2's `start_day` is §5.10's season-local day 6 (or 10), and the eight I32 columns name no
##     season, so that row alone did not identify a point in time -- the gap this header used to
##     record as NEEDS A RULING. The ruled amendment adds TWO I64 columns and nothing else:
##     `scheduled_absolute_season` and `forecast_absolute_season`, both empty at -1, where
##     `absolute_season = floor((absolute_day-1)/12)` and the matching §4.3 Season ordinal is
##     `absolute_season % 4`. That is +16 payload bytes, taking Weather from 32 to 48.
##     EVERY ROW OPERATION NOW TAKES THE ABSOLUTE SEASON, not a repeating 0-3 ordinal, so a
##     caller cannot hand one leg summer and another autumn on a season crossing and be believed:
##     the ordinal is DERIVED here by season_of_absolute_season() and never supplied twice.
##     A SCHEDULED EVENT IS NOT AUTOMATICALLY ACTIVE: activity requires the stored
##     `scheduled_absolute_season` to equal the absolute season asked about AND the half-open day
##     interval `[start, start+duration)`. The old partial REFUSE_EVENT_NOT_ELIGIBLE guard
##     survives only on the pure table readers, where a season ordinal really is the whole input.
##   * "ONE EVENT PER SEASON" IS NOW THIS STORE'S LATCH, NOT THE CALLER'S DISCIPLINE. §5.10:
##     "Exactly one major event occurs per season". `scheduled_absolute_season` IS the
##     scheduled-once latch ARCH-SYS-006 previously kept privately in `crop_weather.gd`; ruling
##     §4.2 requires ONE owner ("no independent extra latch allocation is implied"), so that
##     field was migrated here and `crop_weather.last_scheduled_season()` now reads this column.
##     schedule_season_event() REFUSES a second call for a season it has already scheduled, and
##     refuses BEFORE touching the stream, so the refusal consumes no draw. The latch is kept
##     through event expiry and changes only on a successfully scheduled next season.
##   * INTERPRETATION -- THE BARE TEMPERATURE FORM IS ABSOLUTE. §5.10's effects column writes
##     heavy rain as "Temperature-3°C from baseline" and early frost as "Temperature-3°C", with
##     ideal spell "Temperature 18°C", drought "Temperature 30°C" and hard freeze
##     "Temperature-12°C". "from baseline" appears exactly ONCE in the table, so the bare form is
##     read as an absolute temperature and only heavy rain is a delta. The reading is corroborated
##     mechanically: BAL-CROP-001 makes `frost_tolerance` "damage per subzero hour", so early
##     frost's "frost effects" has a mechanism only if its temperature is below zero -- the
##     relative reading gives autumn 10°C - 3 = +7°C and no frost at all, which would make the
##     event's own name inert. Labelled an interpretation in the manner resource_nodes.gd
##     labelled `regrow_days == 0`; the alternative is one constant away in EVENT_TEMPERATURE_MODE.
##   * INTERPRETATION -- THE DAYLIGHT WINDOW IS HALF-OPEN. §5.10 gives "06:00-19:00" and never
##     says whether the 19th hour is lit. is_daylight_hour() reads the window as [start, end),
##     so spring has 13 lit hours and darkness begins AT 19:00; the alternative closed reading
##     would light 19:00-19:59 as well. Labelled, not silently chosen.
##   * INTERPRETATION -- THE SUMMER MULTIPLIER SCOPES TO THE BASELINE. §5.10: "Plots lose 600
##     moisture/day baseline, multiplied 1500/1000 in summer". The word "baseline" scopes the
##     multiplier to the 600, so drought's separately stated "extra moisture-1500/day" is added
##     after it rather than multiplied by it. Summer drought therefore evaporates 900+1500=2400.
##   * "THREE DAYS IN ADVANCE" IS READ AS `start_day - 3`. REQ-SET-142 and §5.10's "announced
##     three days before its start" put the disclosure on season day 3 for a day-6 event and day
##     7 for early frost's day 10. The alternative -- three CLEAR days before, i.e. day 2 -- is
##     not taken; FORECAST_DAYS is the one constant either reading turns on.
##   * COMBINED WORK FACTORS ARE DELIBERATELY ABSENT. BAL-WORK-001: "Apply weather, darkness, and
##     workshop factors as additional rational factors with one final floor and retained
##     remainder." Multiplying the 750 darkness factor by heavy rain's 800 here would floor twice
##     and lose the remainder the work site must retain, so this module exposes each factor
##     separately and combines none of them.

const IntMath := preload("res://scripts/core/int_math.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Rng := preload("res://scripts/core/rng.gd")

# --- GDD §4.3 Season, read from catalog.gd's protected table (decision 0018) ----------------------

const SEASON_SPRING: int = Catalog.SEASON["SPRING"]
const SEASON_SUMMER: int = Catalog.SEASON["SUMMER"]
const SEASON_AUTUMN: int = Catalog.SEASON["AUTUMN"]
const SEASON_WINTER: int = Catalog.SEASON["WINTER"]
const SEASON_COUNT: int = 4

## REQ-SET-006's "one season as 12 days", via sim_clock.gd's own constant rather than a mirror.
## §5.10's start days are days WITHIN a season, which is what `SimClock.Calendar.season_day`
## reports, numbered from 1.
const DAYS_PER_SEASON: int = SimClock.DAYS_PER_SEASON
const FIRST_SEASON_DAY: int = 1
## `SimClock.Calendar.year` counts from 1, so "first spring" is year 1's spring.
const FIRST_YEAR: int = 1
## Hours in a day, from sim_clock.gd rather than a local 24.
const HOURS_PER_DAY: int = SimClock.HOURS_PER_DAY

# --- ARCH-RNG-002 stream, read from rng.gd rather than mirrored ------------------------------------

const STREAM_WEATHER: int = Rng.STREAM_WEATHER

# --- §4.2 / systems_architecture.md §2.2 row layout -------------------------------------------------

const COL_EVENT: int = 0
const COL_START_DAY: int = 1
const COL_DURATION_DAYS: int = 2
const COL_TEMPERATURE_TENTHS: int = 3
const COL_RAIN: int = 4
const COL_FORECAST_0: int = 5
const COL_FORECAST_1: int = 6
const COL_FORECAST_2: int = 7
const ROW_COLUMN_COUNT: int = 8
## §4.2: "One active major event/world".
const ROW_COUNT: int = 1

# --- ruling 2026-09-11 §4.2's two I64 columns: the row's temporal identity (decision 0055) -------

## The absolute season whose §5.10 event the I32 row currently holds. ALSO the scheduled-once
## latch: it survives event expiry and moves only on a successfully scheduled next season.
const COL64_SCHEDULED_ABSOLUTE_SEASON: int = 0
## The absolute season the disclosed `forecast[3]` tuple belongs to. Retained after expiry, so a
## calendar entry REQ-SET-142 kept can still be placed in a year rather than merely in a season.
const COL64_FORECAST_ABSOLUTE_SEASON: int = 1
const ROW64_COLUMN_COUNT: int = 2
## "both empty at -1", following §4.2's own "empty catalog IDs are -1" convention. This is a
## STATE, never a refusal channel: every operation that can fail carries an OpResult code.
const ABSOLUTE_SEASON_NONE: int = -1
## `absolute_season = floor((absolute_day-1)/12)`, so year 1's spring is 0 and nothing is lower.
const FIRST_ABSOLUTE_SEASON: int = 0
## GDD §5.1 counts calendar days from 1, which is what the floor division above subtracts.
const MIN_CALENDAR_DAY: int = 1

## Payload version of the §4.2 Weather row as this module writes it: eight I32 plus two I64.
const SCHEMA_VERSION: int = 2
## The pre-ruling payload: the same eight I32 columns and NO temporal identity at all.
const SCHEMA_VERSION_NO_SEASON_IDENTITY: int = 1
## Version of the twelve-bit `AFFECTS_*` effect mask below. Bumped when a bit's meaning moves.
const EFFECT_MASK_VERSION: int = 1
const EFFECT_MASK_BIT_COUNT: int = 12

# --- §5.10 event table: catalog.gd's compiled EventDefinition ids, see the header -------------------

## Read from catalog.gd, never mirrored: `Catalog.EVENT_DEFINITION[...]` is a constant expression,
## so there is exactly one copy of each id. EVERY EVENT_* TABLE BELOW IS INDEXED BY THESE IDS, in
## their ascending order blight, calm_days, drought, early_frost, hard_freeze, heavy_rain,
## ideal_spell -- NOT by §5.10's printed row order, which now survives only in
## EVENT_SELECTION_ORDER, where the ruled weighted scan needs it.
const EVENT_DEFINITION_DOMAIN: String = Catalog.EVENT_DEFINITION_DOMAIN
const EVENT_BLIGHT: int = Catalog.EVENT_DEFINITION["blight"]
const EVENT_CALM_DAYS: int = Catalog.EVENT_DEFINITION["calm_days"]
const EVENT_DROUGHT: int = Catalog.EVENT_DEFINITION["drought"]
const EVENT_EARLY_FROST: int = Catalog.EVENT_DEFINITION["early_frost"]
const EVENT_HARD_FREEZE: int = Catalog.EVENT_DEFINITION["hard_freeze"]
const EVENT_HEAVY_RAIN: int = Catalog.EVENT_DEFINITION["heavy_rain"]
const EVENT_IDEAL_SPELL: int = Catalog.EVENT_DEFINITION["ideal_spell"]
const EVENT_COUNT: int = 7
## "No event scheduled", following §4.2's "empty catalog IDs are -1". This is a STATE, never a
## refusal channel: every operation that can fail returns an OpResult or writes an IntResult, and
## is_event_scheduled() answers the same question as a bool.
const EVENT_NONE: int = Catalog.EMPTY_CATALOG_ID

## §4.3's EventDefinition catalog keys, in the compiled id order these tables are indexed by.
const EVENT_KEYS: Array[StringName] = [
	&"blight", &"calm_days", &"drought", &"early_frost",
	&"hard_freeze", &"heavy_rain", &"ideal_spell",
]

## DECISION 0028's RULED SELECTION TRAVERSAL, unchanged: §5.10's printed row order. Selection
## order and stored id are two different things (see the header). The scan visits these seven ids
## in this sequence; the id it lands on is what gets stored, so every draw count and every
## interval boundary is exactly what it was before the ids were corrected.
const EVENT_SELECTION_ORDER: Array[int] = [
	EVENT_IDEAL_SPELL, EVENT_HEAVY_RAIN, EVENT_DROUGHT, EVENT_BLIGHT,
	EVENT_EARLY_FROST, EVENT_HARD_FREEZE, EVENT_CALM_DAYS,
]

## `1<<Season` per BAL-CROP-001's stated convention for `allowed_soils` (an analogy; see header).
const SEASON_MASK_SPRING: int = 1 << SEASON_SPRING
const SEASON_MASK_SUMMER: int = 1 << SEASON_SUMMER
const SEASON_MASK_AUTUMN: int = 1 << SEASON_AUTUMN
const SEASON_MASK_WINTER: int = 1 << SEASON_WINTER
const SEASON_MASK_ANY: int = SEASON_MASK_SPRING | SEASON_MASK_SUMMER \
		| SEASON_MASK_AUTUMN | SEASON_MASK_WINTER

## §5.10's "Eligible season" column, by compiled id: blight summer/autumn, calm days any, drought
## summer, early frost autumn, hard freeze winter, heavy rain spring/autumn, ideal spell any.
const EVENT_SEASON_MASK: Array[int] = [
	SEASON_MASK_SUMMER | SEASON_MASK_AUTUMN,
	SEASON_MASK_ANY,
	SEASON_MASK_SUMMER,
	SEASON_MASK_AUTUMN,
	SEASON_MASK_WINTER,
	SEASON_MASK_SPRING | SEASON_MASK_AUTUMN,
	SEASON_MASK_ANY,
]

## §5.10's "Weight" column by compiled id, RAW integers -- never converted to percentages.
## blight 20, calm days 20, drought 50, early frost 30, hard freeze 60, heavy rain 35, ideal 30.
const EVENT_WEIGHT: Array[int] = [20, 20, 50, 30, 60, 35, 30]

## §5.10's "Duration" column by compiled id, in days.
const EVENT_DURATION_DAYS: Array[int] = [3, 2, 4, 2, 3, 2, 3]

## §5.10: "start day is 6, except early frost day 10", the latter restated in its effects column.
const DEFAULT_START_DAY: int = 6
const EARLY_FROST_START_DAY: int = 10
const EVENT_START_DAY: Array[int] = [
	DEFAULT_START_DAY, DEFAULT_START_DAY, DEFAULT_START_DAY, EARLY_FROST_START_DAY,
	DEFAULT_START_DAY, DEFAULT_START_DAY, DEFAULT_START_DAY,
]

## REQ-SET-142 / §5.10: "announced three days before its start".
const FORECAST_DAYS: int = 3

# --- §5.10 season baseline table, row for row -------------------------------------------------------

## "Daylight" column: 06:00-19:00, 05:00-21:00, 07:00-18:00, 08:00-16:00. Half-open (see header).
const SEASON_DAYLIGHT_START_HOUR: Array[int] = [6, 5, 7, 8]
const SEASON_DAYLIGHT_END_HOUR: Array[int] = [19, 21, 18, 16]

## "Baseline temperature" column, in tenths of a degree: 12°C, 22°C, 10°C, -5°C.
const SEASON_TEMPERATURE_TENTHS: Array[int] = [120, 220, 100, -50]

## "Rain/moisture per day" column: +1200, +300, +700, +0.
const SEASON_RAIN: Array[int] = [1200, 300, 700, 0]

# --- §5.10 effects column, one named table per stated quantity --------------------------------------

## How an event's temperature relates to its season baseline. See the header: "from baseline"
## appears exactly once in §5.10's table, so only heavy rain is a delta.
const TEMPERATURE_BASELINE: int = 0
const TEMPERATURE_ABSOLUTE: int = 1
const TEMPERATURE_DELTA: int = 2
## By compiled id: blight --, calm days --, drought absolute, early frost absolute, hard freeze
## absolute, heavy rain delta, ideal spell absolute.
const EVENT_TEMPERATURE_MODE: Array[int] = [
	TEMPERATURE_BASELINE, TEMPERATURE_BASELINE, TEMPERATURE_ABSOLUTE, TEMPERATURE_ABSOLUTE,
	TEMPERATURE_ABSOLUTE, TEMPERATURE_DELTA, TEMPERATURE_ABSOLUTE,
]
## By compiled id: --, --, 30°C, -3°C, -12°C, -3°C from baseline, 18°C; all in tenths.
const EVENT_TEMPERATURE_TENTHS: Array[int] = [0, 0, 300, -30, -120, -30, 180]
## "Temperature 18°C except winter 2°C" -- the only season-conditional value in the table.
const IDEAL_SPELL_WINTER_TEMPERATURE_TENTHS: int = 20

## How an event's rain relates to its season baseline: drought states an absolute "rain 0", ideal
## spell and heavy rain state additions.
const RAIN_BASELINE: int = 0
const RAIN_ABSOLUTE: int = 1
const RAIN_DELTA: int = 2
## By compiled id: blight --, calm days --, drought absolute, early frost --, hard freeze --,
## heavy rain delta, ideal spell delta.
const EVENT_RAIN_MODE: Array[int] = [
	RAIN_BASELINE, RAIN_BASELINE, RAIN_ABSOLUTE, RAIN_BASELINE,
	RAIN_BASELINE, RAIN_DELTA, RAIN_DELTA,
]
## By compiled id: drought's "rain 0", heavy rain's "+2000/day", ideal spell's "+600/day", and
## four rows that state none.
const EVENT_RAIN: Array[int] = [0, 0, 0, 0, 0, 2000, 600]

## Drought's "extra moisture-1500/day", applied as extra evaporation (see the header).
const DROUGHT_EXTRA_EVAPORATION: int = 1500
const EVENT_EXTRA_EVAPORATION: Array[int] = [0, 0, DROUGHT_EXTRA_EVAPORATION, 0, 0, 0, 0]

## Ideal spell's "crop growth×1.20", per 1000, at compiled id 6. Reported only -- increment 6
## owns FarmPlot.
const EVENT_CROP_GROWTH_PER_1000: Array[int] = [1000, 1000, 1000, 1000, 1000, 1000, 1200]
## Blight's "Crop damage 400/day", at compiled id 0. Reported only.
const EVENT_CROP_DAMAGE_PER_DAY: Array[int] = [400, 0, 0, 0, 0, 0, 0]
## Heavy rain's "outdoor work×0.80", per 1000, at compiled id 5.
const EVENT_OUTDOOR_WORK_PER_1000: Array[int] = [1000, 1000, 1000, 1000, 1000, 800, 1000]
## Hard freeze's "outdoor exposure accumulation×2", per 1000, at compiled id 4. REQ-SET-144
## accumulates nothing here.
const EVENT_EXPOSURE_PER_1000: Array[int] = [1000, 1000, 1000, 1000, 2000, 1000, 1000]

## REQ-SET-142's "affected systems" as ruling 2026-09-11 §4.2's VERSIONED EFFECT MASK: one bit
## per stated phrase of §5.10's effects column, in the ruled bit order 0-11 -- temperature, rain,
## moisture, crop growth, crop damage, outdoor work, boats, exposure, lake ice, mussel harvest,
## orchard water, frost. It is NOT a "system enum": it is DERIVED from the event id, the season
## and the typed tables above by effect_mask_for(), and is never a second independently writable
## truth. Nothing stores it, so no save carries this taxonomy (see the header).
## A COARSE READING IS WRONG. AFFECTS_TEMPERATURE and AFFECTS_RAIN reach orchards, storage aging
## and heating/exposure as well as crops, so no consumer may collapse a mask carrying them into
## "crops only"; the bits are published individually for exactly that reason.
const AFFECTS_TEMPERATURE: int = 1 << 0
const AFFECTS_RAIN: int = 1 << 1
const AFFECTS_MOISTURE: int = 1 << 2
const AFFECTS_CROP_GROWTH: int = 1 << 3
const AFFECTS_CROP_DAMAGE: int = 1 << 4
const AFFECTS_OUTDOOR_WORK: int = 1 << 5
const AFFECTS_BOATS: int = 1 << 6
const AFFECTS_EXPOSURE: int = 1 << 7
const AFFECTS_LAKE_ICE: int = 1 << 8
const AFFECTS_MUSSEL_HARVEST: int = 1 << 9
const AFFECTS_ORCHARD_WATER: int = 1 << 10
const AFFECTS_FROST: int = 1 << 11
## By compiled id: blight, calm days, drought, early frost, hard freeze, heavy rain, ideal spell.
const EVENT_AFFECTED_SYSTEMS: Array[int] = [
	AFFECTS_CROP_DAMAGE | AFFECTS_MUSSEL_HARVEST,
	0,
	AFFECTS_TEMPERATURE | AFFECTS_RAIN | AFFECTS_MOISTURE | AFFECTS_ORCHARD_WATER,
	AFFECTS_TEMPERATURE | AFFECTS_FROST,
	AFFECTS_TEMPERATURE | AFFECTS_EXPOSURE | AFFECTS_LAKE_ICE,
	AFFECTS_TEMPERATURE | AFFECTS_RAIN | AFFECTS_OUTDOOR_WORK | AFFECTS_BOATS,
	AFFECTS_TEMPERATURE | AFFECTS_RAIN | AFFECTS_CROP_GROWTH,
]

# --- §5.10 moisture arithmetic ----------------------------------------------------------------------

## "Plots lose 600 moisture/day baseline, multiplied 1500/1000 in summer".
const MOISTURE_EVAPORATION_PER_DAY: int = 600
const SUMMER_EVAPORATION_NUMERATOR: int = 1500
const EVAPORATION_DENOMINATOR: int = 1000
## REQ-SET-086: "clamp moisture 0-10000".
const MOISTURE_MIN: int = 0
const MOISTURE_MAX: int = 10000

# --- §5.10 work and hunger factors ------------------------------------------------------------------

## Factors are per 1000: this module contains no floats (ARCH-AUTH-002).
const FACTOR_DENOMINATOR: int = 1000
const NEUTRAL_FACTOR_PER_1000: int = 1000
## REQ-SET-148 / §5.10: "unlit outdoor productive work×0.75 in darkness".
const DARKNESS_WORK_FACTOR_PER_1000: int = 750
## REQ-SET-143: "While winter is active, the system shall multiply hunger demand by 1.20".
const WINTER_HUNGER_MULTIPLIER_PER_1000: int = 1200

# --- refusal codes ------------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_SEASON: StringName = &"INVALID_SEASON"
const REFUSE_INVALID_SEASON_DAY: StringName = &"INVALID_SEASON_DAY"
const REFUSE_INVALID_EVENT: StringName = &"INVALID_EVENT"
const REFUSE_INVALID_HOUR: StringName = &"INVALID_HOUR"
const REFUSE_INVALID_ROLL: StringName = &"INVALID_ROLL"
const REFUSE_INVALID_MOISTURE: StringName = &"INVALID_MOISTURE"
const REFUSE_INVALID_YEAR: StringName = &"INVALID_YEAR"
const REFUSE_EVENT_NOT_ELIGIBLE: StringName = &"EVENT_NOT_ELIGIBLE"
const REFUSE_NO_EVENT_SCHEDULED: StringName = &"NO_EVENT_SCHEDULED"
const REFUSE_FORECAST_NOT_DUE: StringName = &"FORECAST_NOT_DUE"
const REFUSE_NO_RNG: StringName = &"NO_RNG"
const REFUSE_SELECTION_FAILED: StringName = &"SELECTION_FAILED"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"
const REFUSE_INVALID_ABSOLUTE_SEASON: StringName = &"INVALID_ABSOLUTE_SEASON"
const REFUSE_SEASON_IDENTITY_MISMATCH: StringName = &"SEASON_IDENTITY_MISMATCH"
const REFUSE_SEASON_ALREADY_SCHEDULED: StringName = &"SEASON_ALREADY_SCHEDULED"
const REFUSE_NOT_FIRST_ABSOLUTE_SEASON: StringName = &"NOT_FIRST_ABSOLUTE_SEASON"
const REFUSE_UNKNOWN_SCHEMA_VERSION: StringName = &"UNKNOWN_WEATHER_SCHEMA_VERSION"
const REFUSE_AMBIGUOUS_SNAPSHOT_SEASON: StringName = &"AMBIGUOUS_SNAPSHOT_SEASON"


class OpResult:
	"""Outcome of one weather operation: success flag, refusal code, value.

	`.ok` MUST be inspected before `.value` is used. A refusal always carries value 0 and never a
	partially applied effect.
	"""
	var ok: bool
	var error: StringName
	var value: int

	func _init(p_ok: bool, p_error: StringName, p_value: int) -> void:
		"""Store the outcome fields for this operation."""
		ok = p_ok
		error = p_error
		value = p_value


# --- state (ARCH-MEM-001: packed, allocated once) ------------------------------------------------------

## §4.2's single Weather row, eight int32 columns indexed by the COL_* constants.
var _row: PackedInt32Array = PackedInt32Array()
## Ruling §4.2's two int64 columns, indexed by the COL64_* constants: the row's temporal identity
## and the scheduled-once latch. Allocated once beside `_row` and never resized.
var _row64: PackedInt64Array = PackedInt64Array()

# --- scratch (not simulation state) --------------------------------------------------------------------

## Checked-arithmetic scratch for int_math's `_into` forms. Nothing here invokes a callback or a
## signal, so no public operation can re-enter while it holds a live value.
var _math: IntMath.IntResult = IntMath.IntResult.new()
## Calendar scratch for the REQ-SET-141 boundary reader, so it allocates nothing per call.
var _calendar: SimClock.Calendar = SimClock.Calendar.new()


func _init() -> void:
	"""Allocate the single §4.2 row once and assert every §5.10 table has its stated width."""
	assert(Catalog.SEASON.size() == SEASON_COUNT, "GDD §4.3 Season has exactly four values")
	assert(EVENT_KEYS.size() == EVENT_COUNT, "§5.10 lists exactly seven event rows")
	assert(EVENT_SEASON_MASK.size() == EVENT_COUNT, "one eligible-season mask per §5.10 row")
	assert(EVENT_WEIGHT.size() == EVENT_COUNT, "one weight per §5.10 row")
	assert(EVENT_DURATION_DAYS.size() == EVENT_COUNT, "one duration per §5.10 row")
	assert(EVENT_START_DAY.size() == EVENT_COUNT, "one start day per §5.10 row")
	assert(EVENT_TEMPERATURE_MODE.size() == EVENT_COUNT, "one temperature mode per §5.10 row")
	assert(EVENT_TEMPERATURE_TENTHS.size() == EVENT_COUNT, "one temperature per §5.10 row")
	assert(EVENT_RAIN_MODE.size() == EVENT_COUNT, "one rain mode per §5.10 row")
	assert(EVENT_RAIN.size() == EVENT_COUNT, "one rain value per §5.10 row")
	assert(EVENT_EXTRA_EVAPORATION.size() == EVENT_COUNT, "one extra evaporation per §5.10 row")
	assert(EVENT_CROP_GROWTH_PER_1000.size() == EVENT_COUNT, "one growth factor per §5.10 row")
	assert(EVENT_CROP_DAMAGE_PER_DAY.size() == EVENT_COUNT, "one crop damage per §5.10 row")
	assert(EVENT_OUTDOOR_WORK_PER_1000.size() == EVENT_COUNT, "one work factor per §5.10 row")
	assert(EVENT_EXPOSURE_PER_1000.size() == EVENT_COUNT, "one exposure factor per §5.10 row")
	assert(EVENT_AFFECTED_SYSTEMS.size() == EVENT_COUNT, "one affected-system mask per §5.10 row")
	_assert_effect_mask_bits()
	_assert_event_ids()
	_assert_season_tables()
	_allocate_columns()
	clear()


func _assert_effect_mask_bits() -> void:
	"""Assert ruling §4.2's twelve effect bits are the twelve consecutive positions 0-11.

	The ruling fixes the ORDER as well as the count, so a later edit that inserts a bit in the
	middle -- silently renumbering every position above it -- fails here rather than in a save.
	"""
	var bits: Array[int] = [
		AFFECTS_TEMPERATURE, AFFECTS_RAIN, AFFECTS_MOISTURE, AFFECTS_CROP_GROWTH,
		AFFECTS_CROP_DAMAGE, AFFECTS_OUTDOOR_WORK, AFFECTS_BOATS, AFFECTS_EXPOSURE,
		AFFECTS_LAKE_ICE, AFFECTS_MUSSEL_HARVEST, AFFECTS_ORCHARD_WATER, AFFECTS_FROST,
	]
	assert(bits.size() == EFFECT_MASK_BIT_COUNT, "ruling §4.2 names exactly twelve effect bits")
	for position: int in EFFECT_MASK_BIT_COUNT:
		assert(bits[position] == 1 << position, "effect bit order 0-11 is ruled, not incidental")
	for event: int in EVENT_COUNT:
		assert(EVENT_AFFECTED_SYSTEMS[event] >= 0
				and EVENT_AFFECTED_SYSTEMS[event] < (1 << EFFECT_MASK_BIT_COUNT),
			"no §5.10 row may set a bit outside the twelve ruled positions")


func _assert_event_ids() -> void:
	"""Assert the compiled EventDefinition ids, and that selection order is a permutation of them.

	The traversal order and the stored ids are separate contracts, so both are checked: every id
	appears in EVENT_SELECTION_ORDER exactly once (nothing can be dropped or visited twice), and
	EVENT_KEYS is in compiled-id order, which is what every EVENT_* table above is indexed by.
	"""
	assert(Catalog.verify_compiled_enum(EVENT_DEFINITION_DOMAIN).ok,
		"EventDefinition ids must be what ascending ASCII order generates")
	assert(Catalog.EVENT_DEFINITION.size() == EVENT_COUNT, "§5.10 lists exactly seven events")
	assert(EVENT_SELECTION_ORDER.size() == EVENT_COUNT, "the ruled traversal visits all seven")
	var seen: int = 0
	for event: int in EVENT_SELECTION_ORDER:
		assert(event >= 0 and event < EVENT_COUNT, "the traversal names only compiled ids")
		assert((seen & (1 << event)) == 0, "the ruled traversal visits each event exactly once")
		seen |= 1 << event
	for event: int in EVENT_COUNT:
		assert(Catalog.EVENT_DEFINITION[String(EVENT_KEYS[event])] == event,
			"EVENT_KEYS must be in compiled id order, which indexes every §5.10 table")


func _assert_season_tables() -> void:
	"""Assert the four-season tables and that every §5.10 event fits inside a 12-day season."""
	assert(SEASON_DAYLIGHT_START_HOUR.size() == SEASON_COUNT, "one daylight start per season")
	assert(SEASON_DAYLIGHT_END_HOUR.size() == SEASON_COUNT, "one daylight end per season")
	assert(SEASON_TEMPERATURE_TENTHS.size() == SEASON_COUNT, "one baseline temperature per season")
	assert(SEASON_RAIN.size() == SEASON_COUNT, "one baseline rain per season")
	assert(DAYS_PER_SEASON * SEASON_COUNT == SimClock.DAYS_PER_YEAR,
		"absolute_season % 4 is the §4.3 ordinal only if a year is exactly four 12-day seasons")
	for event: int in EVENT_COUNT:
		assert(EVENT_START_DAY[event] - FORECAST_DAYS >= FIRST_SEASON_DAY,
			"a forecast three days before the start must fall inside the same season")
		assert(EVENT_START_DAY[event] + EVENT_DURATION_DAYS[event] - 1 <= DAYS_PER_SEASON,
			"a §5.10 event must end inside its own season")


func _allocate_columns() -> void:
	"""The only place that sizes the packed rows (ARCH-MEM-005: allocate once)."""
	_row.resize(ROW_COLUMN_COUNT)
	_row64.resize(ROW64_COLUMN_COUNT)


func clear() -> void:
	"""Return both rows to their empty state without reallocating them.

	No event, no forecast, and NO TEMPORAL IDENTITY: both I64 columns go to ABSOLUTE_SEASON_NONE
	rather than 0, because 0 is year 1's spring and a cleared store has not scheduled it. That
	distinction is what makes a freshly cleared store schedule its first season instead of
	believing spring is already done -- ruling §4.3's "zero-filled weather is not valid opening
	weather", enforced on the latch as well as on the baseline.
	"""
	_row.fill(0)
	_row[COL_EVENT] = EVENT_NONE
	_row[COL_FORECAST_0] = EVENT_NONE
	_row64.fill(ABSOLUTE_SEASON_NONE)


# --- §4.3 / §5.10 argument validation ------------------------------------------------------------

func is_season(season: int) -> bool:
	"""True when `season` is one of §4.3's four Season values."""
	return season >= 0 and season < SEASON_COUNT


func is_season_day(season_day: int) -> bool:
	"""True when `season_day` is a day within a season, 1..12 (REQ-SET-006, via sim_clock.gd).

	§5.10's start days count inside their season, which is exactly what
	`SimClock.Calendar.season_day` reports; nothing here reads a clock, so the caller passes it.
	"""
	return season_day >= FIRST_SEASON_DAY and season_day <= DAYS_PER_SEASON


func is_absolute_season(absolute_season: int) -> bool:
	"""True when `absolute_season` names a real season of the world's history, 0 upward.

	Year 1's spring is 0 and nothing precedes it, so ABSOLUTE_SEASON_NONE (-1) is deliberately
	NOT one of these: it is the empty state of the two I64 columns, not a season.
	"""
	return absolute_season >= FIRST_ABSOLUTE_SEASON


static func season_of_absolute_season(absolute_season: int) -> int:
	"""Ruling §4.2's "a matching current season is `absolute_season % 4`": the §4.3 Season ordinal.

	THE ONLY PLACE THIS MODULE TURNS AN ABSOLUTE SEASON INTO AN ORDINAL. Every row operation
	derives the ordinal here instead of accepting a second argument that could disagree with the
	first, which is what ruling §4.3's "never pass one season argument to every leg on a season
	crossing" costs a caller that gets it wrong. Callers validate the absolute season first.
	"""
	return absolute_season % SEASON_COUNT


func absolute_season_of_day(absolute_day: int) -> IntMath.IntResult:
	"""Ruling §4.2's `floor((absolute_day-1)/12)`. See absolute_season_of_day_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	absolute_season_of_day_into(absolute_day, out)
	return out


func absolute_season_of_day_into(absolute_day: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating absolute_season_of_day(): the absolute season index of a calendar day.

	Day 1 of year 1 gives 0. A day before the calendar's first is refused rather than floored
	into a negative season, which would name a season that never happened.
	"""
	if absolute_day < MIN_CALENDAR_DAY:
		return out.refuse(String(REFUSE_INVALID_SEASON_DAY))
	return IntMath.floor_div_into(absolute_day - MIN_CALENDAR_DAY, DAYS_PER_SEASON, out)


func is_event(event: int) -> bool:
	"""True when `event` names one of §5.10's seven table rows. EVENT_NONE is not one of them."""
	return event >= 0 and event < EVENT_COUNT


func is_hour(hour: int) -> bool:
	"""True when `hour` is an hour of the day, 0..23, as `SimClock.Calendar.hour` reports it."""
	return hour >= 0 and hour < HOURS_PER_DAY


# --- §5.10 event table -----------------------------------------------------------------------------

func season_mask_of(event: int) -> IntMath.IntResult:
	"""§5.10's "Eligible season" column as a `1<<Season` mask (see the header on the convention)."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_event(event):
		out.refuse(String(REFUSE_INVALID_EVENT))
		return out
	out.succeed(EVENT_SEASON_MASK[event])
	return out


func is_eligible(event: int, season: int) -> bool:
	"""True when §5.10's "Eligible season" column admits this event in this season.

	An out-of-range argument reports false, because it names no eligible row at all;
	season_mask_of() is the form that refuses those with a reason.
	"""
	if not is_event(event) or not is_season(season):
		return false
	return _is_eligible(event, season)


static func _is_eligible(event: int, season: int) -> bool:
	"""§5.10's eligibility for validated arguments: is this season's bit set in the row's mask?"""
	return (EVENT_SEASON_MASK[event] & (1 << season)) != 0


func weight_of(event: int) -> IntMath.IntResult:
	"""§5.10's "Weight" column, as the raw integer the ruling requires (never a percentage)."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_event(event):
		out.refuse(String(REFUSE_INVALID_EVENT))
		return out
	out.succeed(EVENT_WEIGHT[event])
	return out


func duration_days_of(event: int) -> IntMath.IntResult:
	"""§5.10's "Duration" column, in days."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_event(event):
		out.refuse(String(REFUSE_INVALID_EVENT))
		return out
	out.succeed(EVENT_DURATION_DAYS[event])
	return out


func start_day_of(event: int) -> IntMath.IntResult:
	"""§5.10's start day for an event: 6 for every row except early frost, which is 10."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_event(event):
		out.refuse(String(REFUSE_INVALID_EVENT))
		return out
	out.succeed(EVENT_START_DAY[event])
	return out


func forecast_day_of(event: int) -> IntMath.IntResult:
	"""The season day REQ-SET-142's disclosure falls due: three days before the event's start."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_event(event):
		out.refuse(String(REFUSE_INVALID_EVENT))
		return out
	out.succeed(EVENT_START_DAY[event] - FORECAST_DAYS)
	return out


func affected_systems_mask_of(event: int) -> IntMath.IntResult:
	"""§5.10's effects column for one event, BEFORE any season-conditional bit is stripped.

	The raw typed table row. effect_mask_for() is the ruled, season-aware mask a consumer should
	read; this form exists because the table itself is an independently checkable fact.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_event(event):
		out.refuse(String(REFUSE_INVALID_EVENT))
		return out
	out.succeed(EVENT_AFFECTED_SYSTEMS[event])
	return out


func effect_mask_for(event: int, season: int) -> IntMath.IntResult:
	"""Ruling §4.2's versioned effect mask. See effect_mask_for_into() for the contract."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	effect_mask_for_into(event, season, out)
	return out


func effect_mask_for_into(event: int, season: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating effect_mask_for(): the twelve `AFFECTS_*` bits for an event IN A SEASON.

	Ruling §4.2: "Strip MUSSEL_HARVEST for non-summer blight." §5.10 states the closure as
	"summer mussel harvest closes", so blight's mussel bit is a SUMMER effect and autumn blight
	-- which §5.10's eligibility column permits -- damages crops without closing a fishery.
	EVENT_NONE reports an empty mask: no event, no modifiers. The mask is derived here every time
	and stored nowhere, so it cannot become a second writable truth.
	"""
	if event == EVENT_NONE:
		return out.succeed(0)
	if not is_event(event):
		return out.refuse(String(REFUSE_INVALID_EVENT))
	if not is_season(season):
		return out.refuse(String(REFUSE_INVALID_SEASON))
	return out.succeed(_effect_mask_for(event, season))


static func _effect_mask_for(event: int, season: int) -> int:
	"""The ruled effect mask for validated arguments: the table row, less non-summer blight's
	mussel bit."""
	var mask: int = EVENT_AFFECTED_SYSTEMS[event]
	if event == EVENT_BLIGHT and season != SEASON_SUMMER:
		mask &= ~AFFECTS_MUSSEL_HARVEST
	return mask


func is_multi_season_event(event: int) -> bool:
	"""True when §5.10's eligibility column admits this event in more than one season.

	Ruling §4.2 forbids inferring a snapshot's absolute season "solely from an event eligible in
	multiple seasons"; this is the predicate that names those rows. Ideal spell and calm days are
	eligible everywhere, heavy rain and blight in two seasons each.
	"""
	if not is_event(event):
		return false
	var mask: int = EVENT_SEASON_MASK[event]
	var seasons: int = 0
	for season: int in SEASON_COUNT:
		if (mask & (1 << season)) != 0:
			seasons += 1
	return seasons > 1


func weight_sum_of(season: int) -> IntMath.IntResult:
	"""The summed raw weight of every §5.10 row eligible in this season: the modulo bound."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	weight_sum_of_into(season, out)
	return out


func weight_sum_of_into(season: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating weight_sum_of(): write the eligible weight sum into caller-owned `out`."""
	if not is_season(season):
		return out.refuse(String(REFUSE_INVALID_SEASON))
	return out.succeed(_weight_sum_of(season))


static func _weight_sum_of(season: int) -> int:
	"""Sum §5.10's weights over the season's eligible rows, in the ruled traversal order.

	The seven weights are compiled constants of at most 60, so this sum is at most 215 and cannot
	overflow; no caller-supplied number reaches it. Addition is commutative, so the order does not
	change the sum -- it is the ruled one anyway, so the bound and the scan below read one list.
	"""
	var total: int = 0
	for event: int in EVENT_SELECTION_ORDER:
		if _is_eligible(event, season):
			total += EVENT_WEIGHT[event]
	return total


func eligible_count_of(season: int) -> IntMath.IntResult:
	"""How many of §5.10's seven rows this season admits."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_season(season):
		out.refuse(String(REFUSE_INVALID_SEASON))
		return out
	var total: int = 0
	for event: int in EVENT_COUNT:
		if _is_eligible(event, season):
			total += 1
	out.succeed(total)
	return out


# --- the ruled selection algorithm -----------------------------------------------------------------

func event_for_roll(season: int, roll: int) -> IntMath.IntResult:
	"""The §5.10 row a validated roll selects. See event_for_roll_into() for the contract."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	event_for_roll_into(season, roll, out)
	return out


func event_for_roll_into(season: int, roll: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating event_for_roll(): apply the ruled cumulative scan to a roll in `[0, sum)`.

	The scan visits §5.10's rows in the document's printed order (EVENT_SELECTION_ORDER, which is
	decision 0028's ruled traversal and is NOT the stored id order), skips the rows this season
	does not admit, accumulates RAW weights, and stops at the first row where `roll < cumulative`
	-- strictly less than, so an interval's upper endpoint belongs to that interval and its
	successor starts at the next integer. The value written out is that row's compiled
	EventDefinition id. A roll outside `[0, weight_sum)` is refused rather than folded back into
	range, because folding would silently bias the first row.
	"""
	if not is_season(season):
		return out.refuse(String(REFUSE_INVALID_SEASON))
	if roll < 0 or roll >= _weight_sum_of(season):
		return out.refuse(String(REFUSE_INVALID_ROLL))
	var selected: int = _event_for_roll(season, roll)
	if selected == EVENT_NONE:
		return out.refuse(String(REFUSE_SELECTION_FAILED))
	return out.succeed(selected)


static func _event_for_roll(season: int, roll: int) -> int:
	"""The ruled cumulative scan for arguments the caller has already validated.

	Returns EVENT_NONE only if the scan runs off the end, which a roll below the eligible weight
	sum cannot do; the caller refuses that outcome rather than storing it.
	"""
	var cumulative: int = 0
	for event: int in EVENT_SELECTION_ORDER:
		if not _is_eligible(event, season):
			continue
		cumulative += EVENT_WEIGHT[event]
		if roll < cumulative:
			return event
	return EVENT_NONE


func draw_event(season: int, rng: Rng) -> IntMath.IntResult:
	"""One WEATHER draw mapped to a §5.10 row. See draw_event_into() for the draw contract."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	draw_event_into(season, rng, out)
	return out


func draw_event_into(season: int, rng: Rng, out: IntMath.IntResult) -> bool:
	"""Non-allocating draw_event(): consume EXACTLY ONE WEATHER draw and apply the ruled mapping.

	ARCH-RNG-002 fixes the count at one roll per new season. The season is validated first and
	draw_below_into() validates its own bound before advancing, so a refusal consumes no draw and
	cannot desynchronise the stream. The bound is the season's raw eligible weight sum; the
	disclosed modulo bias is the header's, and no rejection sampling is performed.
	"""
	if rng == null:
		return out.refuse(String(REFUSE_NO_RNG))
	if not is_season(season):
		return out.refuse(String(REFUSE_INVALID_SEASON))
	if not rng.draw_below_into(STREAM_WEATHER, _weight_sum_of(season), out):
		return false
	var selected: int = _event_for_roll(season, out.value)
	if selected == EVENT_NONE:
		return out.refuse(String(REFUSE_SELECTION_FAILED))
	return out.succeed(selected)


# --- §5.10 season baseline table -------------------------------------------------------------------

func daylight_start_hour_of(season: int) -> IntMath.IntResult:
	"""§5.10's "Daylight" column, first lit hour: spring 6, summer 5, autumn 7, winter 8."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_season(season):
		out.refuse(String(REFUSE_INVALID_SEASON))
		return out
	out.succeed(SEASON_DAYLIGHT_START_HOUR[season])
	return out


func daylight_end_hour_of(season: int) -> IntMath.IntResult:
	"""§5.10's "Daylight" column, the hour darkness begins: spring 19, summer 21, autumn 18,
	winter 16. The window is half-open, so this hour is already dark (see the header)."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_season(season):
		out.refuse(String(REFUSE_INVALID_SEASON))
		return out
	out.succeed(SEASON_DAYLIGHT_END_HOUR[season])
	return out


func daylight_hours_of(season: int) -> IntMath.IntResult:
	"""How many whole hours §5.10's daylight window covers: 13, 16, 11, 8."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_season(season):
		out.refuse(String(REFUSE_INVALID_SEASON))
		return out
	out.succeed(SEASON_DAYLIGHT_END_HOUR[season] - SEASON_DAYLIGHT_START_HOUR[season])
	return out


func is_daylight_hour(season: int, hour: int) -> bool:
	"""True while §5.10's daylight window covers this hour, read as `[start, end)`.

	An out-of-range argument reports false, because it names no lit hour at all;
	daylight_start_hour_of() is the form that refuses those with a reason.
	"""
	if not is_season(season) or not is_hour(hour):
		return false
	return hour >= SEASON_DAYLIGHT_START_HOUR[season] and hour < SEASON_DAYLIGHT_END_HOUR[season]


func baseline_temperature_tenths_of(season: int) -> IntMath.IntResult:
	"""§5.10's "Baseline temperature" column in tenths: 120, 220, 100, -50."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_season(season):
		out.refuse(String(REFUSE_INVALID_SEASON))
		return out
	out.succeed(SEASON_TEMPERATURE_TENTHS[season])
	return out


func baseline_rain_of(season: int) -> IntMath.IntResult:
	"""§5.10's "Rain/moisture per day" column: +1200, +300, +700, +0."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_season(season):
		out.refuse(String(REFUSE_INVALID_SEASON))
		return out
	out.succeed(SEASON_RAIN[season])
	return out


func hunger_multiplier_per_1000_of(season: int) -> IntMath.IntResult:
	"""REQ-SET-143's winter hunger demand multiplier, per 1000: 1200 in winter, 1000 otherwise.

	The requirement's "×1.20" is expressed per 1000 because authoritative state is integer only;
	nothing here multiplies a demand -- §5.2's needs system does, at its own single floor.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_season(season):
		out.refuse(String(REFUSE_INVALID_SEASON))
		return out
	var factor: int = WINTER_HUNGER_MULTIPLIER_PER_1000 if season == SEASON_WINTER \
			else NEUTRAL_FACTOR_PER_1000
	out.succeed(factor)
	return out


func darkness_work_factor_per_1000() -> int:
	"""REQ-SET-148's unlit-outdoor work factor, per 1000: 0.75 expressed as 750.

	Whether a station is outdoors, dark and unlit is the caller's determination -- this module
	owns no station and no torch. BAL-WORK-001 requires weather, darkness and workshop factors to
	be applied as separate rational factors with ONE final floor, so this is never combined with
	the event factor here.
	"""
	return DARKNESS_WORK_FACTOR_PER_1000


# --- §5.10 effects column, as pure readers ------------------------------------------------------------

func temperature_tenths_for(season: int, event: int) -> IntMath.IntResult:
	"""The day's temperature in tenths for a season and an active event (EVENT_NONE for none)."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	temperature_tenths_for_into(season, event, out)
	return out


func temperature_tenths_for_into(season: int, event: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating temperature_tenths_for(): baseline, absolute or delta per §5.10's table.

	Only heavy rain states "from baseline"; every other stated temperature is absolute, and ideal
	spell alone is season-conditional ("18°C except winter 2°C"). See the header on that reading.
	"""
	if not is_season(season):
		return out.refuse(String(REFUSE_INVALID_SEASON))
	if event == EVENT_NONE:
		return out.succeed(SEASON_TEMPERATURE_TENTHS[season])
	if not is_event(event):
		return out.refuse(String(REFUSE_INVALID_EVENT))
	if not _is_eligible(event, season):
		return out.refuse(String(REFUSE_EVENT_NOT_ELIGIBLE))
	return out.succeed(_temperature_tenths_for(season, event))


static func _temperature_tenths_for(season: int, event: int) -> int:
	"""§5.10's temperature for validated, eligible arguments, in tenths of a degree.

	Every term is a compiled constant of at most 300 in absolute value, so the delta sum cannot
	overflow; no caller-supplied number reaches it.
	"""
	if event == EVENT_IDEAL_SPELL and season == SEASON_WINTER:
		return IDEAL_SPELL_WINTER_TEMPERATURE_TENTHS
	var mode: int = EVENT_TEMPERATURE_MODE[event]
	if mode == TEMPERATURE_ABSOLUTE:
		return EVENT_TEMPERATURE_TENTHS[event]
	if mode == TEMPERATURE_DELTA:
		return SEASON_TEMPERATURE_TENTHS[season] + EVENT_TEMPERATURE_TENTHS[event]
	return SEASON_TEMPERATURE_TENTHS[season]


func rain_for(season: int, event: int) -> IntMath.IntResult:
	"""The day's rain/moisture for a season and an active event (EVENT_NONE for none)."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	rain_for_into(season, event, out)
	return out


func rain_for_into(season: int, event: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating rain_for(): §5.10's baseline rain, plus the event's stated addition.

	Drought states an absolute "rain 0" rather than a reduction, so its mode is absolute; ideal
	spell's "+600/day" and heavy rain's "+2000/day" add to the season baseline.
	"""
	if not is_season(season):
		return out.refuse(String(REFUSE_INVALID_SEASON))
	if event == EVENT_NONE:
		return out.succeed(SEASON_RAIN[season])
	if not is_event(event):
		return out.refuse(String(REFUSE_INVALID_EVENT))
	if not _is_eligible(event, season):
		return out.refuse(String(REFUSE_EVENT_NOT_ELIGIBLE))
	return out.succeed(_rain_for(season, event))


static func _rain_for(season: int, event: int) -> int:
	"""§5.10's rain for validated, eligible arguments.

	Every term is a compiled constant of at most 2000, so the sum cannot overflow; no
	caller-supplied number reaches it.
	"""
	var mode: int = EVENT_RAIN_MODE[event]
	if mode == RAIN_ABSOLUTE:
		return EVENT_RAIN[event]
	if mode == RAIN_DELTA:
		return SEASON_RAIN[season] + EVENT_RAIN[event]
	return SEASON_RAIN[season]


func crop_growth_factor_per_1000_of(event: int) -> IntMath.IntResult:
	"""Ideal spell's "crop growth×1.20" as 1200 per 1000; every other row states none.

	Reported only: §5.6's FarmPlot integration is increment 6 and no plot state is written here.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if event == EVENT_NONE:
		out.succeed(NEUTRAL_FACTOR_PER_1000)
		return out
	if not is_event(event):
		out.refuse(String(REFUSE_INVALID_EVENT))
		return out
	out.succeed(EVENT_CROP_GROWTH_PER_1000[event])
	return out


func crop_damage_per_day_of(event: int) -> IntMath.IntResult:
	"""Blight's "Crop damage 400/day"; every other row states none.

	Reported only: applying it to plot health is increment 6's FarmPlot work.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if event == EVENT_NONE:
		out.succeed(0)
		return out
	if not is_event(event):
		out.refuse(String(REFUSE_INVALID_EVENT))
		return out
	out.succeed(EVENT_CROP_DAMAGE_PER_DAY[event])
	return out


func outdoor_work_factor_per_1000_of(event: int) -> IntMath.IntResult:
	"""Heavy rain's "outdoor work×0.80" as 800 per 1000; every other row states none.

	Never combined with darkness_work_factor_per_1000() here -- BAL-WORK-001 requires one final
	floor at the work site, and multiplying the two factors here would floor twice.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if event == EVENT_NONE:
		out.succeed(NEUTRAL_FACTOR_PER_1000)
		return out
	if not is_event(event):
		out.refuse(String(REFUSE_INVALID_EVENT))
		return out
	out.succeed(EVENT_OUTDOOR_WORK_PER_1000[event])
	return out


func exposure_multiplier_per_1000_of(event: int) -> IntMath.IntResult:
	"""Hard freeze's "outdoor exposure accumulation×2" as 2000 per 1000; others state none.

	Reported only. REQ-SET-144's clothing rules need per-resident clothing tier and an exposure
	accumulator this store does not own, so nothing is accumulated here.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if event == EVENT_NONE:
		out.succeed(NEUTRAL_FACTOR_PER_1000)
		return out
	if not is_event(event):
		out.refuse(String(REFUSE_INVALID_EVENT))
		return out
	out.succeed(EVENT_EXPOSURE_PER_1000[event])
	return out


func disables_boats(event: int) -> bool:
	"""§5.10's "boats disabled", stated for heavy rain/storm alone.

	Reported, not enforced: REQ-SET-052's departure gate needs the Expedition store, which does
	not exist. GearInstance is no longer the blocker -- decision 0038 built its allocator -- but
	boats are INSTALLED gear whose owner discriminator the installed-gear contract still owes.
	"""
	return is_event(event) and (EVENT_AFFECTED_SYSTEMS[event] & AFFECTS_BOATS) != 0


func lake_ice_access_only(event: int) -> bool:
	"""§5.10's "lake ice access only", stated for hard freeze alone.

	Reported, not enforced: REQ-SET-051's ice-access station waits on the same installed-gear
	contract as boats. The ice kit itself is portable and its instance path exists (0038).
	"""
	return is_event(event) and (EVENT_AFFECTED_SYSTEMS[event] & AFFECTS_LAKE_ICE) != 0


func closes_mussel_harvest(event: int, season: int) -> bool:
	"""§5.10's "SUMMER mussel harvest closes", stated for blight alone and stripped elsewhere.

	fishing.gd records this as the one weather-dependent closure it will not evaluate. This is the
	table-level reader; closes_mussel_harvest_on() is the one ARCH-SYS-006 writes the bit from.
	Nothing here reaches into fishing.gd: ruling §4.1 gives that join to ARCH-SYS-006.
	"""
	if not is_event(event) or not is_season(season):
		return false
	return (_effect_mask_for(event, season) & AFFECTS_MUSSEL_HARVEST) != 0


func needs_orchard_water(event: int) -> bool:
	"""§5.10's "orchard water needed", stated for drought alone. Reported; §5.6 owns orchards."""
	return is_event(event) and (EVENT_AFFECTED_SYSTEMS[event] & AFFECTS_ORCHARD_WATER) != 0


# --- §5.10 moisture arithmetic --------------------------------------------------------------------

func evaporation_for(season: int, event: int) -> IntMath.IntResult:
	"""One day's moisture loss before rain. See evaporation_for_into() for the contract."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	evaporation_for_into(season, event, out)
	return out


func evaporation_for_into(season: int, event: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating evaporation_for(): §5.10's 600/day, ×1500/1000 in summer, plus drought's extra.

	"Plots lose 600 moisture/day baseline, multiplied 1500/1000 in summer" scopes the multiplier to
	the baseline, so drought's separately stated "extra moisture-1500/day" is added after it (see
	the header): summer drought loses 900+1500 = 2400.
	"""
	if not is_season(season):
		return out.refuse(String(REFUSE_INVALID_SEASON))
	if event != EVENT_NONE and not is_event(event):
		return out.refuse(String(REFUSE_INVALID_EVENT))
	if event != EVENT_NONE and not _is_eligible(event, season):
		return out.refuse(String(REFUSE_EVENT_NOT_ELIGIBLE))
	return out.succeed(_evaporation_for(season, event))


static func _evaporation_for(season: int, event: int) -> int:
	"""§5.10's daily evaporation for validated, eligible arguments.

	Every term is a compiled constant -- 600 scaled by 1500/1000, plus at most 1500 -- so the sum
	is at most 2400 and cannot overflow; no caller-supplied number reaches it.
	"""
	var loss: int = MOISTURE_EVAPORATION_PER_DAY
	if season == SEASON_SUMMER:
		loss = loss * SUMMER_EVAPORATION_NUMERATOR / EVAPORATION_DENOMINATOR
	if event != EVENT_NONE:
		loss += EVENT_EXTRA_EVAPORATION[event]
	return loss


func moisture_delta_for(season: int, event: int) -> IntMath.IntResult:
	"""One day's net moisture change before clamping. See moisture_delta_for_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	moisture_delta_for_into(season, event, out)
	return out


func moisture_delta_for_into(season: int, event: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating moisture_delta_for(): evaporate FIRST, then add the day's rain.

	§5.10: "rain adds after evaporation". The order is retained even though this reader returns a
	net figure, because moisture_after_day_into() applies the two in that order against the 0-10000
	clamp, and BAL-CONFLICT-005 checks the result ("Spring baseline moisture changes by
	+1200-600=+600/day").
	"""
	if not evaporation_for_into(season, event, out):
		return false
	var evaporation: int = out.value
	if not rain_for_into(season, event, out):
		return false
	return out.succeed(out.value - evaporation)


func moisture_after_day(current_moisture: int, season: int, event: int) -> IntMath.IntResult:
	"""A plot's moisture after one day of this weather. See moisture_after_day_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	moisture_after_day_into(current_moisture, season, event, out)
	return out


func moisture_after_day_into(current_moisture: int, season: int, event: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating moisture_after_day(): evaporate, add rain, clamp to REQ-SET-086's 0..10000.

	A PURE READER over a caller-supplied moisture: no plot state is written, because §4.2's
	FarmPlot belongs to increment 6. A moisture outside REQ-SET-086's own 0..10000 range is
	refused rather than clamped into a plausible answer, which also puts the checked addition
	below out of any reach of overflow.
	"""
	if current_moisture < MOISTURE_MIN or current_moisture > MOISTURE_MAX:
		return out.refuse(String(REFUSE_INVALID_MOISTURE))
	if not moisture_delta_for_into(season, event, out):
		return false
	if not IntMath.checked_add_into(current_moisture, out.value, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return out.succeed(clampi(out.value, MOISTURE_MIN, MOISTURE_MAX))


# --- REQ-SET-141 season boundary ------------------------------------------------------------------

func is_season_first_day(season_day: int) -> bool:
	"""True on the first local day of a season, the boundary REQ-SET-141 acts at."""
	return season_day == FIRST_SEASON_DAY


func is_season_boundary_tick(tick: int) -> bool:
	"""True when this tick is the exact midnight that starts a new season (REQ-SET-141).

	Reads sim_clock.gd's own day-boundary test and calendar decode rather than mirroring the
	offset formula, so the boundary here cannot drift from the clock's. The decode uses a scratch
	Calendar this store owns, so the call allocates nothing.
	"""
	if not SimClock.is_day_boundary(tick):
		return false
	SimClock.calendar_at_into(tick, _calendar)
	return _calendar.season_day == FIRST_SEASON_DAY


func is_forced_first_spring(year: int, season: int) -> bool:
	"""True for §5.10's onboarding season: year 1's spring, whose event is forced and undrawn.

	`SimClock.Calendar.year` counts from 1, so "first spring" is year 1. The caller uses this to
	choose between schedule_first_spring_event() and schedule_season_event(); this store cannot
	tell the two apart on its own, because §4.2 gives the row no calendar column.
	"""
	return year == FIRST_YEAR and season == SEASON_SPRING


# --- the §4.2 row: schedule, forecast, daily baseline ------------------------------------------------

func schedule_first_spring_event(absolute_season: int) -> OpResult:
	"""§5.10's forced onboarding event: ideal spell, spring, start day 6, and ZERO WEATHER draws.

	This function takes no Rng at all, so the zero-draw rule of ARCH-RNG-002's "forced onboarding
	event consumes zero draws" is structural rather than a convention a later edit could break.
	The onset and effects are the table's own: nothing about ideal spell is special-cased for the
	first spring, which is what "with the same visible rules" requires.
	`absolute_season` MUST be FIRST_ABSOLUTE_SEASON: `floor((absolute_day-1)/12)` is 0 for exactly
	the twelve days of year 1's spring, so a forced first spring at any other index is a caller
	that lost the season crossing, and it is REFUSED rather than quietly written under a 0.
	"""
	if absolute_season != FIRST_ABSOLUTE_SEASON:
		return _refuse(REFUSE_NOT_FIRST_ABSOLUTE_SEASON)
	if is_season_scheduled(absolute_season):
		return _refuse(REFUSE_SEASON_ALREADY_SCHEDULED)
	_write_schedule(EVENT_IDEAL_SPELL, absolute_season)
	return _succeed(EVENT_IDEAL_SPELL)


func schedule_season_event(absolute_season: int, rng: Rng) -> OpResult:
	"""§5.10's per-season draw: consume exactly one WEATHER roll and store the selected row.

	The season ordinal is DERIVED from `absolute_season`; it orders the eligible rows and never
	reseeds the stream. A refusal -- a bad index, a season already scheduled, a null Rng, or any
	refusal from the stream itself -- consumes no draw and writes no column, so the row and the
	stream cannot disagree about what happened. The already-scheduled check comes FIRST, which is
	what makes §5.10's "exactly one major event occurs per season" an enforced latch here rather
	than a discipline this store asks its caller to remember (ruling §4.2).
	"""
	if not is_absolute_season(absolute_season):
		return _refuse(REFUSE_INVALID_ABSOLUTE_SEASON)
	if is_season_scheduled(absolute_season):
		return _refuse(REFUSE_SEASON_ALREADY_SCHEDULED)
	if not draw_event_into(season_of_absolute_season(absolute_season), rng, _math):
		return _refuse(_math.error as StringName)
	var event: int = _math.value
	_write_schedule(event, absolute_season)
	return _succeed(event)


func _write_schedule(event: int, absolute_season: int) -> void:
	"""Store one selected event with §5.10's start day and duration, and clear its old forecast.

	The forecast slots are emptied rather than carried over: REQ-SET-142 retains the forecast OF
	THE SCHEDULED EVENT, and a new schedule has not been disclosed yet -- so its absolute-season
	identity is emptied with it. `scheduled_absolute_season` moves HERE and nowhere else, which is
	what makes it the scheduled-once latch: expiry does not touch it.
	"""
	_row[COL_EVENT] = event
	_row[COL_START_DAY] = EVENT_START_DAY[event]
	_row[COL_DURATION_DAYS] = EVENT_DURATION_DAYS[event]
	_row[COL_FORECAST_0] = EVENT_NONE
	_row[COL_FORECAST_1] = 0
	_row[COL_FORECAST_2] = 0
	_row64[COL64_SCHEDULED_ABSOLUTE_SEASON] = absolute_season
	_row64[COL64_FORECAST_ABSOLUTE_SEASON] = ABSOLUTE_SEASON_NONE


func disclose_forecast(absolute_season: int, season_day: int) -> OpResult:
	"""REQ-SET-142's disclosure: retain the scheduled event, start and duration from day start-3.

	Consumes no draw (BAL-SAFE-017: "opening forecasts ... SHALL consume no event roll") and is
	idempotent, so a caller that discloses on every day from the due day onward writes the same
	four values every time. The affected systems REQ-SET-142 also requires are derived from the
	disclosed event by forecast_effect_mask(); see the header on why they are not stored.
	A season that is not the SCHEDULED one is refused: disclosing summer's event as autumn's
	would publish a calendar entry three months from where it happens.
	"""
	if not is_absolute_season(absolute_season):
		return _refuse(REFUSE_INVALID_ABSOLUTE_SEASON)
	if not is_season_day(season_day):
		return _refuse(REFUSE_INVALID_SEASON_DAY)
	if not is_event_scheduled():
		return _refuse(REFUSE_NO_EVENT_SCHEDULED)
	if not is_season_scheduled(absolute_season):
		return _refuse(REFUSE_SEASON_IDENTITY_MISMATCH)
	if season_day < _row[COL_START_DAY] - FORECAST_DAYS:
		return _refuse(REFUSE_FORECAST_NOT_DUE)
	_row[COL_FORECAST_0] = _row[COL_EVENT]
	_row[COL_FORECAST_1] = _row[COL_START_DAY]
	_row[COL_FORECAST_2] = _row[COL_DURATION_DAYS]
	_row64[COL64_FORECAST_ABSOLUTE_SEASON] = absolute_season
	return _succeed(_row[COL_FORECAST_0])


func is_forecast_due(absolute_season: int, season_day: int) -> bool:
	"""True from the day REQ-SET-142's disclosure falls due, three days before the event starts.

	False for any season other than the scheduled one, for the same reason disclose_forecast()
	refuses it: a forecast belongs to the season whose event it describes.
	"""
	if not is_absolute_season(absolute_season) or not is_season_day(season_day):
		return false
	if not is_event_scheduled() or not is_season_scheduled(absolute_season):
		return false
	return season_day >= _row[COL_START_DAY] - FORECAST_DAYS


func refresh_daily(absolute_season: int, season_day: int) -> OpResult:
	"""Write §4.2's daily `temperature_tenths` and `rain` for one day, per "daily baseline
	independently".

	The day's active event supplies the modifiers; outside its window -- INCLUDING a day in a
	season the scheduled event does not belong to -- the row records the plain season baseline.
	The §4.3 ordinal is derived from `absolute_season`, so the baseline table and the active-event
	test cannot be read for two different seasons. Consumes no draw; nothing here advances a day.
	"""
	if not is_absolute_season(absolute_season):
		return _refuse(REFUSE_INVALID_ABSOLUTE_SEASON)
	if not is_season_day(season_day):
		return _refuse(REFUSE_INVALID_SEASON_DAY)
	var season: int = season_of_absolute_season(absolute_season)
	var event: int = _active_event_on(absolute_season, season_day)
	if not temperature_tenths_for_into(season, event, _math):
		return _refuse(_math.error as StringName)
	var temperature: int = _math.value
	if not rain_for_into(season, event, _math):
		return _refuse(_math.error as StringName)
	_row[COL_TEMPERATURE_TENTHS] = temperature
	_row[COL_RAIN] = _math.value
	return _succeed(temperature)


func end_event(absolute_season: int) -> OpResult:
	"""REQ-SET-145: remove the event's temporary modifiers and nothing else.

	The schedule is cleared and the stored daily baseline returns to the named season's own
	temperature and rain. Crop health, consumed stocks and injuries are NOT restored --
	structurally, not by convention: this store holds none of them and reaches into no store that
	does. The disclosed forecast is retained WITH its absolute-season identity, because
	REQ-SET-142 requires the calendar to keep it and ruling §4.2 requires it to stay placeable in
	a year. `scheduled_absolute_season` is also retained: it is the scheduled-once latch, and
	clearing it here would let the season that just expired be drawn for a second time.
	"""
	if not is_absolute_season(absolute_season):
		return _refuse(REFUSE_INVALID_ABSOLUTE_SEASON)
	if not is_event_scheduled():
		return _refuse(REFUSE_NO_EVENT_SCHEDULED)
	var season: int = season_of_absolute_season(absolute_season)
	var removed: int = _row[COL_EVENT]
	_row[COL_EVENT] = EVENT_NONE
	_row[COL_START_DAY] = 0
	_row[COL_DURATION_DAYS] = 0
	_row[COL_TEMPERATURE_TENTHS] = SEASON_TEMPERATURE_TENTHS[season]
	_row[COL_RAIN] = SEASON_RAIN[season]
	return _succeed(removed)


func adopt_snapshot_identity(version: int, scheduled_absolute_season: int,
		forecast_absolute_season: int) -> OpResult:
	"""Ruling §4.2's codec rule: accept a snapshot's temporal identity, or REFUSE the snapshot.

	The codec itself does not exist (ARCH-SYS-022 has no save stream), so this is the rule alone,
	written where the columns live rather than left for a future save module to guess at.
	A SCHEMA_VERSION_NO_SEASON_IDENTITY payload is refused UNCONDITIONALLY. Its eight I32 columns
	carry no year at all, so even an event eligible in exactly one season fixes only the 0-3
	ordinal -- "never infer it solely from an event eligible in multiple seasons" is the weaker
	half of a rule this store can satisfy completely by proving nothing is provable.
	"""
	if version != SCHEMA_VERSION:
		if version == SCHEMA_VERSION_NO_SEASON_IDENTITY:
			return _refuse(REFUSE_AMBIGUOUS_SNAPSHOT_SEASON)
		return _refuse(REFUSE_UNKNOWN_SCHEMA_VERSION)
	if not _is_storable_identity(scheduled_absolute_season):
		return _refuse(REFUSE_INVALID_ABSOLUTE_SEASON)
	if not _is_storable_identity(forecast_absolute_season):
		return _refuse(REFUSE_INVALID_ABSOLUTE_SEASON)
	if is_event_scheduled() and scheduled_absolute_season == ABSOLUTE_SEASON_NONE:
		return _refuse(REFUSE_AMBIGUOUS_SNAPSHOT_SEASON)
	if is_forecast_disclosed() and forecast_absolute_season == ABSOLUTE_SEASON_NONE:
		return _refuse(REFUSE_AMBIGUOUS_SNAPSHOT_SEASON)
	if not _snapshot_seasons_admit_their_events(scheduled_absolute_season,
			forecast_absolute_season):
		return _refuse(REFUSE_EVENT_NOT_ELIGIBLE)
	_row64[COL64_SCHEDULED_ABSOLUTE_SEASON] = scheduled_absolute_season
	_row64[COL64_FORECAST_ABSOLUTE_SEASON] = forecast_absolute_season
	return _succeed(scheduled_absolute_season)


func _is_storable_identity(absolute_season: int) -> bool:
	"""True when a value may be written to an I64 identity column: a real season, or empty."""
	return absolute_season == ABSOLUTE_SEASON_NONE or is_absolute_season(absolute_season)


func _snapshot_seasons_admit_their_events(scheduled: int, forecast: int) -> bool:
	"""True when each stored event is eligible in the season the snapshot claims for it.

	A cross-check, not an inference: the identity is read from the payload and this only proves
	§5.10's eligibility column does not contradict it. A snapshot claiming hard freeze in a summer
	is refused; a snapshot claiming calm days anywhere passes, which is exactly why the identity
	must be STORED rather than derived.
	"""
	if is_event_scheduled() and not _is_eligible(_row[COL_EVENT],
			season_of_absolute_season(scheduled)):
		return false
	if is_forecast_disclosed() and not _is_eligible(_row[COL_FORECAST_0],
			season_of_absolute_season(forecast)):
		return false
	return true


# --- §4.2 row readers ---------------------------------------------------------------------------

func event_of() -> int:
	"""§4.2's `event` column: the world's one scheduled major event, or EVENT_NONE for none.

	EVENT_NONE is a STATE, not a refusal: is_event_scheduled() answers the same question as a
	bool, and every operation that can fail carries its reason on an OpResult instead.
	"""
	return _row[COL_EVENT]


func is_event_scheduled() -> bool:
	"""True while §4.2's row names an event, whether or not its window has begun."""
	return _row[COL_EVENT] != EVENT_NONE


func start_day() -> int:
	"""§4.2's `start_day` column, as §5.10's season-local day (6, or 10 for early frost)."""
	return _row[COL_START_DAY]


func duration_days() -> int:
	"""§4.2's `duration_days` column, §5.10's stated duration of the scheduled event."""
	return _row[COL_DURATION_DAYS]


func last_day() -> int:
	"""The final season day the scheduled event covers: `start_day + duration_days - 1`.

	Both terms are §5.10 constants written by _write_schedule(), so no caller-supplied number
	reaches this sum. With no event scheduled both are 0 and this reports -1, which names no day.
	"""
	return _row[COL_START_DAY] + _row[COL_DURATION_DAYS] - 1


func temperature_tenths() -> int:
	"""§4.2's `temperature_tenths` column, as refresh_daily() last wrote it."""
	return _row[COL_TEMPERATURE_TENTHS]


func rain() -> int:
	"""§4.2's `rain` column, as refresh_daily() last wrote it."""
	return _row[COL_RAIN]


func forecast_event() -> int:
	"""§4.2's `forecast[0]`: the disclosed event, or EVENT_NONE while nothing is disclosed."""
	return _row[COL_FORECAST_0]


func forecast_start_day() -> int:
	"""§4.2's `forecast[1]`: REQ-SET-142's disclosed start day, retained after the event ends."""
	return _row[COL_FORECAST_1]


func forecast_duration_days() -> int:
	"""§4.2's `forecast[2]`: REQ-SET-142's disclosed duration, retained after the event ends."""
	return _row[COL_FORECAST_2]


func is_forecast_disclosed() -> bool:
	"""True once disclose_forecast() has written REQ-SET-142's retained values."""
	return _row[COL_FORECAST_0] != EVENT_NONE


func scheduled_absolute_season() -> int:
	"""The I64 `scheduled_absolute_season` column: which season's event the row holds.

	ABSOLUTE_SEASON_NONE while no season has ever been scheduled. Retained through expiry, so
	this doubles as §5.10's scheduled-once latch (see the header).
	"""
	return _row64[COL64_SCHEDULED_ABSOLUTE_SEASON]


func forecast_absolute_season() -> int:
	"""The I64 `forecast_absolute_season` column: which season the disclosed forecast belongs to.

	Retained after the event expires, so a calendar entry REQ-SET-142 keeps can still be placed
	in a year and not merely in one of four repeating seasons.
	"""
	return _row64[COL64_FORECAST_ABSOLUTE_SEASON]


func is_season_scheduled(absolute_season: int) -> bool:
	"""True when this exact absolute season's §5.10 event has already been scheduled.

	The scheduled-once test. A repeating 0-3 ordinal cannot answer it -- summer of year 1 and
	summer of year 2 would look identical -- which is the whole reason the I64 column exists.
	"""
	return _row64[COL64_SCHEDULED_ABSOLUTE_SEASON] == absolute_season


func forecast_effect_mask() -> IntMath.IntResult:
	"""REQ-SET-142's third disclosure: the disclosed event's ruled effect mask, in ITS season.

	Read at the forecast's own stored absolute season, so an autumn blight forecast does not
	report a mussel closure it will never cause. Refuses while nothing is disclosed.
	"""
	if not is_forecast_disclosed():
		var out: IntMath.IntResult = IntMath.IntResult.new()
		out.refuse(String(REFUSE_NO_EVENT_SCHEDULED))
		return out
	var identity: int = _row64[COL64_FORECAST_ABSOLUTE_SEASON]
	if not is_absolute_season(identity):
		var missing: IntMath.IntResult = IntMath.IntResult.new()
		missing.refuse(String(REFUSE_INVALID_ABSOLUTE_SEASON))
		return missing
	return effect_mask_for(_row[COL_FORECAST_0], season_of_absolute_season(identity))


func is_event_active(absolute_season: int, season_day: int) -> bool:
	"""True while the scheduled event's window covers this day OF THIS ABSOLUTE SEASON.

	Ruling §4.2: "The scheduled event is not automatically active: activity requires matching
	absolute season and the half-open day interval `[start,start+duration)`." Both halves are
	here, and the interval is written as `< start + duration` rather than `<= last_day()` so the
	half-open reading is the literal code. An out-of-range day or a season the row was not
	scheduled for reports false -- neither names a day this event covers.
	"""
	if not is_absolute_season(absolute_season) or not is_season_day(season_day):
		return false
	if not is_event_scheduled() or not is_season_scheduled(absolute_season):
		return false
	return season_day >= _row[COL_START_DAY] \
			and season_day < _row[COL_START_DAY] + _row[COL_DURATION_DAYS]


func active_event_on(absolute_season: int, season_day: int) -> int:
	"""The event modifying this day, or EVENT_NONE outside the scheduled window or season."""
	return _active_event_on(absolute_season, season_day)


func _active_event_on(absolute_season: int, season_day: int) -> int:
	"""The active event for a day, without re-validating what is_event_active() already checks."""
	return _row[COL_EVENT] if is_event_active(absolute_season, season_day) else EVENT_NONE


func is_blight_active(absolute_season: int, season_day: int) -> bool:
	"""True while §5.10's blight covers this day of this absolute season.

	It answers about weather only, and in BOTH seasons §5.10 makes blight eligible: an autumn
	blight is active and damages crops. Whether a mussel stock closes is a narrower question --
	closes_mussel_harvest_on() -- and writing that bit is ARCH-SYS-006's join, so no fish store is
	touched here.
	"""
	if not is_absolute_season(absolute_season) or not is_season_day(season_day):
		return false
	var event: int = _active_event_on(absolute_season, season_day)
	return event == EVENT_BLIGHT \
			and _is_eligible(EVENT_BLIGHT, season_of_absolute_season(absolute_season))


func closes_mussel_harvest_on(absolute_season: int, season_day: int) -> bool:
	"""Ruling §4.1's predicate: `new_season == SUMMER && active_new_day_event == BLIGHT`.

	THE ONE EXPRESSION ARCH-SYS-006 WRITES `FishStock.closed` FROM. It reads the ruled effect mask
	of the day's ACTIVE event at the day's own absolute season, so autumn blight -- whose mask has
	AFFECTS_MUSSEL_HARVEST stripped -- reports false, and so does the day after expiry, whose
	active event is EVENT_NONE. No other cause may be folded in here: ruling §4.1 reserves the
	event bit for this one, and a second cause needs a typed reason mask that is not added now.
	"""
	if not is_absolute_season(absolute_season) or not is_season_day(season_day):
		return false
	var event: int = _active_event_on(absolute_season, season_day)
	if event == EVENT_NONE:
		return false
	var season: int = season_of_absolute_season(absolute_season)
	return (_effect_mask_for(event, season) & AFFECTS_MUSSEL_HARVEST) != 0


func catalog_is_verified() -> bool:
	"""True when catalog.gd still compiles §4.3's EventDefinition ids this module's tables assume.

	ARCH-SYS-006's boundary preflight (ruling §4.1) calls this BEFORE any day step commits, so a
	catalog that no longer generates the ids every EVENT_* table is subscripted by refuses the
	whole boundary instead of scheduling an event under someone else's number. One OpResult per
	call, which is once per simulated day and never on the tick path.
	"""
	return Catalog.verify_compiled_enum(EVENT_DEFINITION_DOMAIN).ok


# --- result helpers ------------------------------------------------------------------------------

func _succeed(value: int) -> OpResult:
	"""Build a successful OpResult carrying a value."""
	return OpResult.new(true, REFUSE_NONE, value)


func _refuse(code: StringName) -> OpResult:
	"""Build a refused OpResult. The value is always empty on a refusal.

	This is not a sentinel scheme: the code travels on its own channel and a refusal never carries
	a usable number, so an ignored refusal cannot surface a plausible answer.
	"""
	return OpResult.new(false, code, 0)
