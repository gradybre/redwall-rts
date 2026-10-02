extends RefCounted
## The water gameplay's numbers, part A (movement: wading, swimming, diving, rescue, bridges), and the
## pure integer arithmetic over them. Decision 0196 (live demo). Presentation around integer state:
## air, stamina, work units, stock and experience are integers; only where a body is drawn is float.
##
## ---------------------------------------------------------------------------------------
## CITED (used as written):
##   * HAZ-002 `air_standard_v1` (docs/underground_economy_hazard_amendment.md, SET-MOVE-ECON-001):
##     full air 1200 units; 1 unit per submerged fixed tick; recovery 4 per tick at breathable support,
##     capped at 1200; admission requires air >= T + 300 where T is every submerged tick of the plan
##     (MOVE-REQ-009); return is triggered when remaining air <= B + 300, B the ticks back to air;
##     the low-air advisory at <= 450.
##   * HAZ-001: new deliberate entry to dangerous travel (SWIM_SURFACE, DIVE) needs rest >= 4000 and
##     the resident's consent; ford and bridge walking add no hazard.
##   * HAZ-003: a dangerous crossing requests the safe return at rest <= 1500; at rest 0 in the water
##     the resident stops self-propelled swimming (EXHAUSTION) -- in difficulty; the latch re-arms once
##     rest is back to 4000 at safe support.
##   * AGENTS.md: needs are integers 0..10000; 30 fixed ticks a second; quantities are milli-U.
##   * GDD §5.3 (via forest_rules.gd, called, never retyped): 10 XP per WU, the level curve, and the
##     skill factor 1000 + 50 x level dividing the work's time.
##   * TRV-W01 / water_rules.gd: wading is ground movement; the WADE / SWIM / DIVE zones by body height.
##
## DEMO VALUES (no document settles them -- SET-MOVE-001 §4: "New production speeds, depths, oxygen
## values ... None originated by this amendment"; each is named here and nowhere else):
##   * Who swims (MOVE-REQ-005 capability, per resident, seeded from the species here): otters, the
##     beaver, mice, squirrels and moles swim; only the otters dive (theirs are the only dive clips);
##     THE BADGER WADES ONLY -- it has a swim clip, but the demo gives the heavy quarryman no swimming,
##     so the ford and the bridges are its way over. Swim speeds: otter 1.10 m/s, beaver 0.90, mouse
##     0.60, squirrel 0.55, mole 0.50 (every one faster than the stream's 0.40 m/s flow).
##   * Wading pace: 55% of the walk. Stamina (the resident's rest, 0..10000): swimming, treading and
##     diving spend 3 a tick; cold water (air below 10.0 C) doubles it; flowing water adds its speed's
##     share of the swimmer's (a mouse in the 0.4 m/s stream spends 1.67x). On land rest comes back 6 a
##     tick, three times that while resting after a rescue.
##   * A flood (demo/events/) speeds the stream by up to its full rise: twice the flow in full flood.
##   * Diving: 0.5 m/s down and up, 8 s searching the bed, never deeper than DIVE_FLOOR_CLEAR_M above it.
##   * The low-air advisory re-arms once a resident is back at the surface with air >= 600 (a 150-unit
##     band over HAZ-002's 450, about 1.3 s of breathing), so one dive raises it once (decision 0231).
##   * Rescue: a thrown line reaches 8 m and hauls at 0.5 m/s; towing is at 60% of the rescuer's swim;
##     a rescued resident rests 20 s where it was brought ashore.
##   * Bridges: a plank footbridge takes 1.0 U of planks a metre of deck and 1.0 U of wood a pier; a
##     pier stands every started 2.5 m of a water span over 3.5 m; its deck reaches 0.6 m past each
##     waterline onto the bank; at most 8 m of deck. A log bridge is one 6 U log (a felled trunk's, or
##     the log stack's) of at most 5.5 m -- the felled trunk's drawn length. Work: 40 WU a pier, 25 WU
##     a metre of beams, 20 WU a metre of decking (a log: 30 WU to shape it, 20 WU a metre to set it,
##     10 WU a metre to hew its top flat), at forestry's 0.1 s a WU.
##   * Bridge building is a demo skill (like felling: §4.3 names none); the beaver bridgewright starts
##     at level 6 (180000 XP), everyone else at 0, and anybeast learns (LORE-P12, DEC-041).

const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")

# --- cited ---------------------------------------------------------------------------------------

const AIR_FULL: int = 1200
const AIR_PER_SUBMERGED_TICK: int = 1
const AIR_RECOVERY_PER_TICK: int = 4
const AIR_CONTINGENCY_TICKS: int = 300
const AIR_LOW_ADVISORY: int = 450
const REST_MAX: int = 10000
const REST_ENTRY_MIN: int = 4000
const REST_RETURN: int = 1500
const REST_REARM: int = 4000
const TICKS_PER_SECOND: int = 30
const USEC_PER_SECOND: int = 1000000
const PERMILLE: int = 1000
const UNITS_PER_M: int = 1024

# --- demo: who swims -----------------------------------------------------------------------------

const SPECIES: Array[String] = ["mouse", "squirrel", "mole", "otter", "beaver", "badger"]
## Raised with the walking pace in the playtest fix pass (decision 0205): the part A table (600, 550,
## 500, 1100, 900) times 1.4, the otter and the beaver a little more, so an otter swims about as fast as
## the quicker otter walks and a mouse still swims slower than it walks.
const SWIM_MM_S: Array[int] = [840, 770, 700, 1900, 1400, 0]
## The swim speed at which each species' stroke clip reads right at rate 1.0 (part A's table, where it
## was looked at); the stroke plays at its swim speed over this (swim_motion.gd stroke_rate).
const STROKE_MM_S: Array[int] = [600, 550, 500, 1100, 900, 0]
const DIVES: Array[bool] = [false, false, false, true, false, false]
const SWIM_WORDS: Array[String] = ["swims", "swims", "swims", "swims fast, dives", "swims strongly", "wades only"]

# --- demo: pace, stamina, cold, flood ------------------------------------------------------------

const WADE_PERMILLE: int = 550
const REST_SWIM_PER_TICK: int = 3
const REST_LAND_PER_TICK: int = 6
const REST_RESTING_FACTOR: int = 3
const COLD_WATER_TENTHS: int = 100
const COLD_FACTOR: int = 2
const FLOOD_FLOW_PERMILLE: int = 1000

# --- demo: diving --------------------------------------------------------------------------------

const DIVE_VERTICAL_MM_S: int = 500
const DIVE_SEARCH_TICKS: int = 240
const DIVE_FLOOR_CLEAR_M: float = 0.35
const AIR_LOW_REARM: int = 600

# --- demo: rescue --------------------------------------------------------------------------------

const LINE_REACH_M: float = 8.0
const LINE_PULL_M_S: float = 0.5
const TOW_PERMILLE: int = 600
const REST_AFTER_RESCUE_TICKS: int = 600

# --- demo: bridges -------------------------------------------------------------------------------

const KIND_PLANK: int = 0
const KIND_LOG: int = 1
const KIND_NAMES: Array[String] = ["plank footbridge", "log bridge"]
const PLANK_MILLI_PER_M: int = 1000
const PIER_WOOD_MILLI: int = 1000
const PIER_FREE_SPAN_U: int = 3584
const PIER_GAP_U: int = 2560
const DECK_OVERHANG_U: int = 614
const PLANK_MAX_DECK_U: int = 8192
const LOG_WOOD_MILLI: int = 6000
const LOG_MAX_DECK_U: int = 5632
const PIER_WU: int = 40
const BEAM_WU_PER_M: int = 25
const DECK_WU_PER_M: int = 20
const LOG_SHAPE_WU: int = 30
const LOG_SET_WU_PER_M: int = 20
const LOG_HEW_WU_PER_M: int = 10
const USEC_PER_WU: int = ForestRules.USEC_PER_WU
const BRIDGEWRIGHT_KEY: StringName = &"beaver_bridgewright"
const BRIDGEWRIGHT_XP: int = 180000

## Stages of a build, in order (a log bridge has no piers).
const STAGE_PIERS: int = 0
const STAGE_BEAMS: int = 1
const STAGE_DECK: int = 2
const STAGE_COUNT: int = 3
const STAGE_NAMES: Array[String] = ["piers", "beams", "deck"]
const LOG_STAGE_NAMES: Array[String] = ["piers", "log", "deck"]

## Why an entry or a plan is refused (MOVE-REQ-005/009: the failed condition is named).
const REFUSE_NONE: StringName = &""
const REFUSE_CANNOT_SWIM: StringName = &"CANNOT_SWIM"
const REFUSE_CANNOT_DIVE: StringName = &"CANNOT_DIVE"
const REFUSE_TIRED: StringName = &"TIRED"
const REFUSE_NO_CONSENT: StringName = &"NO_CONSENT"
const REFUSE_LOADED: StringName = &"LOADED"
const REFUSE_FLOW: StringName = &"FLOW_TOO_STRONG"
const REFUSE_AIR: StringName = &"AIR_BUDGET"
const REFUSE_TOO_SHALLOW: StringName = &"TOO_SHALLOW_TO_DIVE"
## Ice covers the water (water part B, decision 0433): nobody swims or dives under it.
const REFUSE_ICE: StringName = &"ICE_COVERS_THE_WATER"
## Hurt or not well enough (HAZ-001's entry test, decision 1045): health under ENTRY_HEALTH, or an untreated injury.
const REFUSE_HURT: StringName = &"HURT"
## HAZ-001: "New deliberate entry to dangerous travel requires health >=70 ... no active untreated injury".
const ENTRY_HEALTH: int = 70


static func has_species(species: String) -> bool:
	"""Whether the table lists a species ("Otter" or "otter"); the lookups below answer for an unlisted
	one as a non-swimmer rather than index with a missing row."""
	return SPECIES.has(species.to_lower())


static func species_row(species: String) -> int:
	"""The row of a species the table lists (`has_species` first: an unlisted one is refused)."""
	assert(has_species(species), "species_row of an unlisted species")
	return SPECIES.find(species.to_lower())


static func swim_mm_s_of(species: String) -> int:
	"""A species' demo swim speed, mm/s (0: it does not swim; an unlisted species does not)."""
	return SWIM_MM_S[species_row(species)] if has_species(species) else 0


static func stroke_mm_s_of(species: String) -> int:
	"""The swim speed a species' stroke clip reads right at rate 1.0, mm/s (0 for a non-swimmer)."""
	return STROKE_MM_S[species_row(species)] if has_species(species) else 0


static func stroke_rate(swim_now_mm_s: int, stroke_mm_s: int) -> float:
	"""The stroke clip's rate swimming at `swim_now_mm_s`: that over the stroke's own speed (1 when the
	species has none), so a faster swimmer strokes faster rather than gliding."""
	if stroke_mm_s <= 0:
		return 1.0
	return float(swim_now_mm_s) / float(stroke_mm_s)


static func dives_of(species: String) -> bool:
	"""Whether a species dives (demo: the otters)."""
	return has_species(species) and DIVES[species_row(species)]


static func swim_words(species: String) -> String:
	"""The capability in words for the panels."""
	return SWIM_WORDS[species_row(species)] if has_species(species) else "wades only"


static func ticks_for_usec(usec: int, carry: PackedInt64Array) -> int:
	"""Whole fixed ticks in `usec` demo microseconds, keeping the remainder in `carry[0]` (in
	tick-microseconds: usec x 30), so no microsecond is lost or counted twice."""
	carry[0] += usec * TICKS_PER_SECOND
	@warning_ignore("integer_division") var ticks: int = carry[0] / USEC_PER_SECOND
	carry[0] -= ticks * USEC_PER_SECOND
	return ticks


static func cold_water(air_tenths: int) -> bool:
	"""Whether the water counts as cold today (demo: air below 10.0 C)."""
	return air_tenths < COLD_WATER_TENTHS


static func flow_mm_s(flow_u_s: int, flood_permille: int) -> int:
	"""A flow's speed in mm/s, sped by a flood (`flood_permille` of full flood, 0..1000)."""
	@warning_ignore("integer_division") var base: int = flow_u_s * PERMILLE / UNITS_PER_M
	@warning_ignore("integer_division") return base * (PERMILLE + FLOOD_FLOW_PERMILLE * clampi(flood_permille, 0, PERMILLE) / PERMILLE) / PERMILLE


static func rest_drain_per_tick(swim_mm_s: int, flow_speed_mm_s: int, cold: bool) -> int:
	"""Stamina a swimmer spends a tick: the base, times two in cold water, plus the flow's share of the
	swimmer's own speed (integer, rounded up so a drain is never lost)."""
	var base: int = REST_SWIM_PER_TICK * (COLD_FACTOR if cold else 1)
	if swim_mm_s <= 0 or flow_speed_mm_s <= 0:
		return base
	return WaterRules.ceil_div(base * (swim_mm_s + flow_speed_mm_s), swim_mm_s)


static func ground_speed_mm_s(swim_mm_s: int, flow_across_mm_s: int, flow_along_mm_s: int) -> int:
	"""How fast a swimmer holding a straight line makes good along it (mm/s): it angles into the flow's
	across component, `sqrt(s^2 - across^2)`, and the along component adds. 0: the flow across is at
	least its speed -- it cannot hold the line."""
	var across: int = absi(flow_across_mm_s)
	if swim_mm_s <= across:
		return 0
	return maxi(WaterRules.isqrt(swim_mm_s * swim_mm_s - across * across) + flow_along_mm_s, 0)


static func dive_ticks(depth_down_mm: int) -> int:
	"""HAZ-002's T for a planned dive `depth_down_mm` below the surface: down, the search, and up."""
	var one_way: int = WaterRules.ceil_div(depth_down_mm * TICKS_PER_SECOND, DIVE_VERTICAL_MM_S)
	return 2 * one_way + DIVE_SEARCH_TICKS


static func fetch_ticks(depth_down_mm: int) -> int:
	"""HAZ-002's T for a rescuer fetching a resident held `depth_down_mm` below: down to it and back up
	with it (no search). Admitted, like a dive, with air >= T + 300 (`admits_dive`)."""
	return 2 * WaterRules.ceil_div(maxi(depth_down_mm, 0) * TICKS_PER_SECOND, DIVE_VERTICAL_MM_S)


static func admits_fetch(air: int, depth_down_mm: int) -> bool:
	"""Whether `air` covers fetching a resident held `depth_down_mm` below: `fetch_ticks` and HAZ-002's
	300 reserve (`admits_dive`). False for one not below (no plan)."""
	return admits_dive(air, fetch_ticks(depth_down_mm))


static func admits_dive(air: int, planned_ticks: int) -> bool:
	"""MOVE-REQ-009 / HAZ-002: entry only with air >= T + 300 (T > 0; a zero plan is invalid)."""
	return planned_ticks > 0 and air >= planned_ticks + AIR_CONTINGENCY_TICKS


static func must_return(air: int, back_ticks: int) -> bool:
	"""HAZ-002: turn back when remaining air <= B + 300 (equality triggers)."""
	return air <= back_ticks + AIR_CONTINGENCY_TICKS


static func admits_swim(rest: int) -> bool:
	"""HAZ-001: new entry to a dangerous swim needs rest >= 4000."""
	return rest >= REST_ENTRY_MIN


static func admits_health(health: int, untreated_injury: bool) -> bool:
	"""HAZ-001: new entry to a dangerous swim needs health >= 70 and no active untreated injury (decision 1045)."""
	return health >= ENTRY_HEALTH and not untreated_injury


# --- bridges -------------------------------------------------------------------------------------

static func deck_u(span_u: int) -> int:
	"""A bridge's deck length for a water span: past each waterline by DECK_OVERHANG_U."""
	return span_u + 2 * DECK_OVERHANG_U


static func piers_for(kind: int, span_u: int) -> int:
	"""Piers a span needs: none for a log or a span of at most PIER_FREE_SPAN_U (3.5 m: the neck's
	3.4 m needs none), else one for every started PIER_GAP_U beyond the first."""
	if kind == KIND_LOG or span_u <= PIER_FREE_SPAN_U:
		return 0
	return WaterRules.ceil_div(span_u, PIER_GAP_U) - 1


static func plank_milli(deck_length_u: int) -> int:
	"""Planks for a deck, milli-U: PLANK_MILLI_PER_M a metre, rounded up to the tenth of a unit."""
	var milli: int = WaterRules.ceil_div(deck_length_u * PLANK_MILLI_PER_M, UNITS_PER_M)
	return WaterRules.ceil_div(milli, 100) * 100


static func max_deck_u(kind: int) -> int:
	"""The longest deck a kind of bridge may have."""
	return LOG_MAX_DECK_U if kind == KIND_LOG else PLANK_MAX_DECK_U


static func stage_wu(kind: int, stage: int, deck_length_u: int, piers: int) -> int:
	"""WU of one stage of a build (per metre of deck rounded up)."""
	match stage:
		STAGE_PIERS:
			return PIER_WU * piers
		STAGE_BEAMS:
			if kind == KIND_LOG:
				return LOG_SHAPE_WU + WaterRules.ceil_div(LOG_SET_WU_PER_M * deck_length_u, UNITS_PER_M)
			return WaterRules.ceil_div(BEAM_WU_PER_M * deck_length_u, UNITS_PER_M)
	var per_m: int = LOG_HEW_WU_PER_M if kind == KIND_LOG else DECK_WU_PER_M
	return WaterRules.ceil_div(per_m * deck_length_u, UNITS_PER_M)


static func work_usec(wu: int, level: int) -> int:
	"""Demo microseconds `wu` WU take at a skill level: WU x USEC_PER_WU / the §5.3 skill factor."""
	@warning_ignore("integer_division") return wu * USEC_PER_WU * PERMILLE / ForestRules.skill_factor_permille(level)


static func units_text(milli: int) -> String:
	"""Milli-U as the panels show it ("4.7 U")."""
	return ForestRules.units_text(milli)
