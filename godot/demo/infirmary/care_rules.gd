extends RefCounted
## THE CARE NUMBERS: injuries, treatment, recovery and herbs in the live demo. Decisions 0621 (findings) and 0622
## (the build). Presentation only: nothing here writes into the settlement simulation. Integer throughout.
##
## CITED, never retyped -- each constant below reads the core module that already carries the GDD's number:
##   * REQ-SET-173 (scripts/core/injury.gd): treatment is herb 1000 + cloth 500 milli-U and 60000 milli-WU of HEAL, then
##     the aggregate injury clears and 10 health returns, capped 100.
##   * REQ-SET-017/172 and §5.2 (scripts/core/needs.gd): recovery +2 an hour, +4 in an infirmary; untreated drain −1
##     (severity 1) or −4 (severity 2) an hour; the health factor 600 / 850 / 1000 below 40 / below 70 / from 70.
##   * §5.2 (scripts/core/work.gd): a work tick produces 80 milli-WU x factor / 1000; §5.3: 10 XP a WU.
##   * §5.4 (the hazard paragraph): a net/trap hazard removes 20 and gives a severity 1 bite; a boat/ice hazard removes
##     35 and gives severity 2 exposure. Used only by the Demo Lab's test triggers (the fishery's own roll is not wired).
##   * §5.5 (scripts/core/forage.gd): the herb patch -- capacity 160 U, base work 8 WU a U, regrowth 80 per mille, the
##     four seasons' availability, initial stock 0.8 K, the sustainable floor 20% K -- and REQ-SET-068's foraging hazard:
##     per completed 60 WU at natural danger >= 1, `max(1, 8 x danger − FORAGE level)` in 10000, −10 health, severity 1.
##   * §5.1's initial inventory: herb 12 U, cloth 24 U -- the care supplies the demo starts with.
##
## DEMO VALUES (decision 0622 PROPOSALS; each is named here and nowhere else):
##   * P1 HEALTH_FLOOR 16: the demo never lets health fall below the INJURED band (REQ-SET-016's death at 0 and §5.2's
##     incapacitation at 1..15 are not reached; the demo is non-fatal, as its water is: decisions 0196, 0231).
##   * P3 the herbalist: the squirrel gatherer starts with HEAL level 2 (the GDD's starting level for active skills);
##     everyone else 0, and anybeast learns by treating (LORE-P12).
##   * P4 UP_HEALTH 70: a patient rests in bed until treated AND back at 70 health -- the health factor's full band.
##   * P5 the herb patch: one patch of §5.5's herb row, at natural danger 1 (§5.5's zones: within 64 m of the hall,
##     no staffed lookout), beside the south road into the woods; HERB_TRIP_MILLI a gathering trip.
##   * P6 the herbalist keeps the shelf at HERB_TARGET_MILLI (the GDD's own starting 12 U) when free by day.
##   * P7 forage cuts are CUT: REQ-SET-068 names no kind; brambles and thorns cut.

const Injury := preload("res://scripts/core/injury.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Forage := preload("res://scripts/core/forage.gd")
const Work := preload("res://scripts/core/work.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const PERMILLE: int = 1000
const MILLI: int = 1000

# --- cited: treatment (REQ-SET-173) -------------------------------------------------------------------------------
const CARE_WORK_MWU: int = Injury.CARE_WORK_MWU
const CARE_HERB_MILLI: int = Injury.CARE_HERB_MILLI
const CARE_CLOTH_MILLI: int = Injury.CARE_CLOTH_MILLI
const CARE_HEALTH_RESTORE: int = Injury.CARE_HEALTH_RESTORE

# --- cited: health (§5.2) -----------------------------------------------------------------------------------------
const HEALTH_MAX: int = Needs.HEALTH_MAX
const RECOVERY_PER_HOUR: int = Needs.HEALTH_RECOVERY_PER_HOUR
const RECOVERY_INFIRMARY_PER_HOUR: int = Needs.HEALTH_RECOVERY_INFIRMARY_PER_HOUR
const RECOVERY_NEED_FLOOR: int = Needs.HEALTH_RECOVERY_NEED_FLOOR
const UNTREATED_DRAIN_PER_HOUR: Array[int] = Needs.HEALTH_UNTREATED_INJURY_DRAIN_PER_HOUR
const AIRLESS_DRAIN_PER_HOUR: int = Needs.HEALTH_AIRLESS_DRAIN_PER_HOUR
const STARVATION_DRAIN_PER_HOUR: int = Needs.HEALTH_STARVATION_DRAIN_PER_HOUR
## REQ-SET-012: a resident eats when hunger is 3500 or lower.
const EAT_AT_HUNGER: int = Needs.HUNGER_EAT_THRESHOLD

# --- cited: work (§5.2, §5.3) -------------------------------------------------------------------------------------
const MWU_PER_TICK: int = Work.BASE_MWU_PER_TICK
const XP_PER_WU: int = ForestRules.XP_PER_WU
const WORK_FACTOR_MIN: int = Needs.WORK_FACTOR_MIN
const WORK_FACTOR_MAX: int = Needs.WORK_FACTOR_MAX

# --- cited: §5.4's hazard injuries (the Lab's test triggers) ---------------------------------------------------------
const NET_HAZARD_KIND: int = Injury.KIND_BITE
const NET_HAZARD_SEVERITY: int = Injury.SEVERITY_MINOR
const NET_HAZARD_LOSS: int = 20
const BOAT_HAZARD_KIND: int = Injury.KIND_EXPOSURE
const BOAT_HAZARD_SEVERITY: int = Injury.SEVERITY_SERIOUS
const BOAT_HAZARD_LOSS: int = 35

# --- cited: the herb patch and the foraging hazard (§5.5, REQ-SET-068) -----------------------------------------------
const HERB_KIND: int = Forage.PATCH_HERB
const HERB_CAPACITY_MILLI: int = Forage.PATCH_CAPACITY_U[HERB_KIND] * Forage.MILLI_PER_UNIT
@warning_ignore("integer_division")
const HERB_START_MILLI: int = HERB_CAPACITY_MILLI * Forage.INITIAL_STOCK_NUMERATOR / Forage.INITIAL_STOCK_DENOMINATOR
@warning_ignore("integer_division")
const HERB_FLOOR_MILLI: int = HERB_CAPACITY_MILLI * Forage.SUSTAINABLE_FLOOR_PERCENT / Forage.PERCENT_DENOMINATOR
const FORAGE_SEGMENT_WU: int = Forage.EXPOSURE_SEGMENT_WU
const FORAGE_INJURY_KIND: int = Injury.KIND_CUT
const FORAGE_INJURY_SEVERITY: int = Forage.INJURY_SEVERITY
const FORAGE_INJURY_LOSS: int = Forage.INJURY_HEALTH_LOSS
const ROLL_DENOMINATOR: int = Forage.INJURY_ROLL_DENOMINATOR

# --- cited: §5.1's starting stocks ----------------------------------------------------------------------------------
const START_HERB_MILLI: int = 12000
const START_CLOTH_MILLI: int = 24000

# --- demo values (decision 0622) ------------------------------------------------------------------------------------
## P1: the lowest health the demo lets anyone reach (the INJURED band's foot).
const HEALTH_FLOOR: int = Needs.HEALTH_INCAPACITATED_MAX + 1
## P4: a patient is up again once treated and at the health factor's full band.
const UP_HEALTH: int = Needs.HEALTH_FACTOR_BAND_FLOOR[1]
## P3: the herbalist and its starting HEAL level (the GDD's level 2 for active skills).
const HERBALIST_KEY: StringName = &"squirrel_gatherer"
const HERBALIST_LEVEL: int = 2
## P5: the herb patch's natural danger (§5.5 zone 1) and a gathering trip's load.
const PATCH_DANGER: int = 1
const HERB_TRIP_MILLI: int = 4000
## P5: the patch's place: the woods' floor east of the south road (world_layout.gd's "south road, on into the woods").
const HERB_PATCH_AT: Vector2 = Vector2(4.2, 24.5)
## P6: the shelf stock the herbalist gathers back up to.
const HERB_TARGET_MILLI: int = START_HERB_MILLI
## How often patients, healers and gatherers are looked at (cast time): the work board's own claim period.
const DISPATCH_USEC: int = 500000
## The most moving ticks integrated one by one a frame; the rest of a jump is taken in closed form (care_state.gd A
## JUMP). About 4 ms at worst on the development machine under load (a moving tick ~130 us; 4x play needs 2 a frame).
const MAX_TICKS_PER_FRAME: int = 30
## The demo world's seed for the core RNG's FORAGE stream (decision 0622).
const WORLD_SEED: int = 26026
## FORAGE skill: the demo keeps none (every forager at level 0).
const FORAGE_LEVEL: int = 0


static func health_factor(health: int) -> int:
	"""§5.2's health factor over 1000: below 40 600, below 70 850, else 1000."""
	for band: int in Needs.HEALTH_FACTOR_BAND_FLOOR.size():
		if health < Needs.HEALTH_FACTOR_BAND_FLOOR[band]:
			return Needs.HEALTH_FACTOR_VALUE[band]
	return Needs.HEALTH_FACTOR_VALUE[Needs.HEALTH_FACTOR_VALUE.size() - 1]


static func care_factor(level: int, pace_permille: int) -> int:
	"""A healer's work factor: §5.3's skill factor `1000 + 50 x level` times the resident's work pace (its health
	factor and any other owner's, demo/work/work_pace.gd), clamped to §5.2's 300..1800. The demo has no mood, so the
	mood factor is 1000."""
	var skill: int = ForestRules.skill_factor_permille(clampi(level, 0, ForestRules.SKILL_LEVEL_MAX))
	@warning_ignore("integer_division")
	return clampi(skill * pace_permille / PERMILLE, WORK_FACTOR_MIN, WORK_FACTOR_MAX)


static func level_of(xp: int) -> int:
	"""§5.3's level for this XP."""
	return ForestRules.level_of(xp)


static func xp_of_level(level: int) -> int:
	"""§5.3's cumulative XP at `level`."""
	return ForestRules.xp_of_level(level)


static func herb_work_mwu(forage_level: int, danger: int) -> int:
	"""§5.5's work for one U of herb: `ceil(base x 10^6 / ((1000 + 40 L)(1000 + 100 d)))` WU, in milli-WU."""
	var skill: int = Forage.WORK_BASE_TERM + Forage.WORK_SKILL_TERM * maxi(forage_level, 0)
	var place: int = Forage.WORK_BASE_TERM + Forage.WORK_DANGER_TERM * clampi(danger, Forage.DANGER_MIN, Forage.DANGER_MAX)
	var numerator: int = Forage.PATCH_BASE_WORK_WU[HERB_KIND] * Forage.WORK_NUMERATOR_SCALE
	return IntMath.ceil_div(numerator, skill * place).value * MILLI


static func herb_regrowth_milli(stock_milli: int, season: int) -> int:
	"""§5.5's daily regrowth as ruled (decision 0036): 0 when dormant or full, else
	`min(K − P, floor((K − P) x r x S / 10^6) + 1000)`."""
	var room: int = HERB_CAPACITY_MILLI - stock_milli
	var availability: int = Forage.PATCH_AVAILABILITY_PER_1000[HERB_KIND * 4 + clampi(season, 0, 3)]
	if room <= 0 or availability == 0:
		return 0
	@warning_ignore("integer_division")
	var grown: int = room * Forage.PATCH_REGROWTH_PER_1000[HERB_KIND] * availability / Forage.REGROWTH_DENOMINATOR
	return mini(room, grown + Forage.REGROWTH_MINIMUM_MILLI)


static func forage_injury_chance(danger: int, forage_level: int) -> int:
	"""REQ-SET-068's chance in 10000: `max(1, 8 x danger − FORAGE level)`."""
	return maxi(Forage.INJURY_CHANCE_MINIMUM, Forage.INJURY_DANGER_FACTOR * danger - forage_level)
