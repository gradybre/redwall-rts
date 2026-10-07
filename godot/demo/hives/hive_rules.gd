extends RefCounted
## THE APIARY'S NUMBERS (decision 1601; review group Y's ECO-011 and ECO-012, GDD §5.6's hive rows). Presentation only:
## nothing here is the settlement's simulation. Every number is a document's -- named where it is used -- or a DEMO VALUE
## named below and nowhere else.
##
## THE DOCUMENTS' RULES, used as written (scripts/core/orchard_hive.gd carries §5.6's hive arithmetic and is called, never
## retyped): strength starts 8000, healthy at 5000 or more; spring to autumn a hive serviced that day makes honey 2 U and
## wax 0.25 U x strength/10000, for 20 WU of service a day; a missed service day there costs 200 strength and makes
## nothing; a tended spring day restores 300 after production; winter makes nothing, needs no tending and eats honey 0.5 U
## a day from the hive's feed, a day without it costing 500; at 0 the hive is abandoned and can be recolonised in spring
## with honey 4 U, wood 2 U, 60 WU and a 3-day wait. REQ-SET-082: a healthy hive within 12 m of beans or an orchard tree
## gives x1100 (x1150 with two). §5.8's wildlife pressure: at midnight in summer and autumn, a 200/10000 roll per apiary
## (halved to 100 by a closed fence) takes min(2 U, the apiary's honey). §5.9's Apiary: 3x3 tiles, one hive.
##
## DEMO VALUES (PROPOSALS in decision 1601):
##   * THE APIARY: one, inherited with the village (as the old orchard is: decision 0672), on tiles 55..57 x 73..75 west of
##     the old orchard -- within 12 m of both old trees and of the four northern field beds, so beans sown there are
##     pollinated and the cabbage beds' row is not.
##   * THE WINTER FEED (ECO-012's "winter feed protected first"): the honey a collection brings is first put by in the
##     hive's feed until it holds a whole winter's (12 days x 0.5 U = 6 U); only the rest is carried to the baskets.
##   * WHERE THE HONEY GOES: the old orchard's basket stand (decision 0674's gathering point), from which the Haulers send
##     it on as they send the fruit.
##   * A WINTER FEEDING (REQ-SET-083 made actionable): when the hive's feed will not last the winter, a keeper carries the
##     shortfall from the pantry's free honey -- a handling's 1 WU (meal_rules.gd HANDLE_MWU), since §5.6 says winter
##     "needs feed but no tending labor".
##   * WAX is a material (pitfalls: "honey is food (pantry); wax is a material (stores)"); until the village stores keep
##     it, the apiary keeps what it collects on its own shelf (WAX_SHELF_U), shown in its readout.

const Hive := preload("res://scripts/core/orchard_hive.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")

const NONE: int = -1
const TILE_M: float = 2.0

# --- the apiaries -----------------------------------------------------------------------------------------------------
## Each apiary's footprint (inclusive tiles, min then max), its name and the basket stand (orchard_rules.gd group) its
## honey is carried to.
const APIARY_MIN: Array[Vector2i] = [Vector2i(55, 73)]
const APIARY_MAX: Array[Vector2i] = [Vector2i(57, 75)]
const APIARY_NAMES: Array[String] = ["the apiary"]
const APIARY_STAND_GROUP: PackedInt32Array = [0]
const APIARY_COUNT: int = 1
## Whether an apiary's footprint is enclosed by a closed fence (§5.8: halves the wildlife roll). The demo builds none.
const APIARY_FENCED: PackedByteArray = [0]
## Where a keeper stands to work the skep: this far south of it (m), toward the village.
const KEEPER_OFFSET_M: Vector2 = Vector2(0.0, -1.1)
## The skep's ground circle the cast walks round (m).
const SKEP_RADIUS_M: float = 0.4

# --- §5.6's hive day and the demo's feed policy ------------------------------------------------------------------------
## A whole winter's feed: §5.6's 0.5 U a day for the season's 12 days.
const WINTER_FEED_MILLI: int = Hive.HIVE_WINTER_FEED_MILLI_PER_DAY * SimClock.DAYS_PER_SEASON
const SERVICE_MWU: int = Hive.HIVE_SERVICE_WORK_MILLI_WU
const RECOLONIZE_MWU: int = Hive.HIVE_RECOLONIZE_WORK_MILLI_WU
const FEED_MWU: int = MealRules.HANDLE_MWU
const RECOLONIZE_HONEY_MILLI: int = Hive.HIVE_RECOLONIZE_HONEY_MILLI
const RECOLONIZE_WOOD_MILLI: int = Hive.HIVE_RECOLONIZE_WOOD_MILLI
const RECOLONIZE_WAIT_DAYS: int = Hive.HIVE_RECOLONIZE_WAIT_DAYS

# --- §5.8's wildlife pressure ------------------------------------------------------------------------------------------
const WILDLIFE_CHANCE: int = 200
const WILDLIFE_CHANCE_FENCED: int = 100
const WILDLIFE_DENOMINATOR: int = 10000
const WILDLIFE_TAKE_MILLI: int = 2000
## The roll's seed (rng.gd `hash_pair(day, WILDLIFE_SEED + apiary)`): a demo value, so a run is repeatable.
const WILDLIFE_SEED: int = 1601

## The apiary's wax shelf (DEMO): what it can hold before the village stores keep wax.
const WAX_SHELF_U: int = 40
const PERMILLE: int = 1000


static func is_apiary(apiary: int) -> bool:
	"""Whether `apiary` names one of the apiaries."""
	return apiary >= 0 and apiary < APIARY_COUNT


static func centre_m(apiary: int) -> Vector2:
	"""Where apiary `apiary`'s skep stands: its footprint's centre (x, z metres; tile 64's west edge is x 0)."""
	var lo: Vector2i = APIARY_MIN[apiary]
	var hi: Vector2i = APIARY_MAX[apiary]
	var x: float = (float(lo.x + hi.x + 1) * 0.5 - float(ForestRules.TILE_ORIGIN)) * TILE_M
	var z: float = (float(lo.y + hi.y + 1) * 0.5 - float(ForestRules.TILE_ORIGIN)) * TILE_M
	return Vector2(x, z)


static func keeper_spot(apiary: int) -> Vector2:
	"""Where a keeper stands to work apiary `apiary`'s skep."""
	return centre_m(apiary) + KEEPER_OFFSET_M


static func tile_of_m(at: Vector2) -> Vector2i:
	"""The exterior tile a ground point stands on (farm_sim.gd's own rule: 64 + floor(x / 2))."""
	return Vector2i(ForestRules.TILE_ORIGIN + floori(at.x / TILE_M), ForestRules.TILE_ORIGIN + floori(at.y / TILE_M))


static func wildlife_chance(apiary: int) -> int:
	"""§5.8's roll for apiary `apiary`, per 10000: halved by a closed fence."""
	return WILDLIFE_CHANCE_FENCED if APIARY_FENCED[apiary] == 1 else WILDLIFE_CHANCE


static func is_wildlife_season(season: int) -> bool:
	"""§5.8: the roll is made in summer and autumn only."""
	return season == Hive.SEASON_SUMMER or season == Hive.SEASON_AUTUMN


static func winter_days_left(day: int) -> int:
	"""Winter days still to feed from `day` on, `day` itself included (a whole winter before it starts)."""
	if Hive.season_of_day(day) != Hive.SEASON_WINTER:
		return SimClock.DAYS_PER_SEASON
	return SimClock.DAYS_PER_SEASON - Hive.season_day_of_day(day) + 1


static func feed_need_milli(day: int) -> int:
	"""The honey a hive's feed should hold on `day`: the rest of this winter's (or a whole winter's before it)."""
	return Hive.HIVE_WINTER_FEED_MILLI_PER_DAY * winter_days_left(day)


static func recolonize_ends_in_spring(day: int) -> bool:
	"""Whether a recolonisation started on `day` ends its 3-day wait still in spring (§5.6: "recolonized in spring")."""
	return Hive.season_of_day(day) == Hive.SEASON_SPRING \
		and Hive.season_of_day(day + RECOLONIZE_WAIT_DAYS) == Hive.SEASON_SPRING


static func units(milli: int) -> String:
	"""'6.0 U'."""
	return ForestRules.units_text(milli)
