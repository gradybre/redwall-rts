extends RefCounted
## The forestry demo's numbers and the pure arithmetic over them. Decision 0196 (live demo).
##
## CITED (GDD rev 1.1, used as written):
##   §5.1   "Each mature node contains 12 wood U"; the exterior tile is 2048 u (2 m) and a tile index
##          is `z*128+x` -- resource_nodes.gd owns that formula, this only maps a demo point onto it.
##   §5.9   "tree 12 wood/120 WU"; "Trees regrow after 48 days when their stumps remain and no
##          building occupies the tile; planting a cleared forestry tile costs compost 0.25 U and
##          4 WU, also maturing after 48 days. A forestry zone retains at least 20% mature trees by
##          default; intensive override retains 10%."
##   §5.3   "Skill factor=1000+50*level" and "XP is 10 per completed productive WU"; the level curve is
##          residents.gd's own (`_skill_level_curve`), called, never retyped.
##   §5.10  Heavy rain/storm: "outdoor work x0.80".
##
## DEMO VALUES (no document states them; each is named here and nowhere else):
##   * USEC_PER_WU: a WU is "one game minute of base-speed productive labor" (§4.1). When the demo
##     calendar ran a day a minute a game minute was 42 ms, too quick to see an axe swing; the farm's
##     1.5 s a WU would make one 120-WU felling three minutes. Forestry shows a WU as 0.1 s of demo
##     time: a felling is 12 s at 1x. Decision 0421 made a game minute 0.42 s and kept this rate in
##     real seconds (a felling is now about 29 game minutes). MIN_WORK_USEC keeps a 4-WU planting on
##     screen long enough to read.
##   * WINTER_WORK_PERMILLE: winter felling goes quicker (no sap) -- the time is 80% of the rest.
##   * CARRY_LOAD_MILLI: a hauler carries 6 U of logs a trip (two trips a tree; the carry walk is slow).
##   * Deadfall: a pile is 1.0..2.0 U, gathered at 20 WU a U (a felled tree is 10 WU a U).
##   * Sawing: 2 U of logs make 2 U of planks for 40 WU (planks are the demo's own stock; no plank item
##     exists in the GDD catalog).
##   * Grubbing out a stump: 30 WU.
##   * REACH_M: residents work trees whose trunk stands within this Chebyshev distance of the square,
##     and walk up to WORK_MARGIN_M beyond it to haul what fell outward.
##   * The tile origin: the demo square's centre is exterior tile (64, 64).
##   * Storm blow-downs: one mature tree per storm day; deadfall: one pile a day, three more on a
##     storm day, never more than DEADFALL_MAX lying.

const IntMath := preload("res://scripts/core/int_math.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const ResourceNodes := preload("res://scripts/core/resource_nodes.gd")

# --- cited --------------------------------------------------------------------------------------

const TREE_WOOD_MILLI: int = 12000
const FELL_WU: int = 120
const REGROW_DAYS: int = 48
const PLANT_COMPOST_MILLI: int = 250
const PLANT_WU: int = 4
const RETAIN_PERCENT: int = 20
const INTENSIVE_RETAIN_PERCENT: int = 10
const XP_PER_WU: int = 10
const SKILL_FACTOR_BASE: int = 1000
const SKILL_FACTOR_PER_LEVEL: int = 50
const SKILL_LEVEL_MAX: int = ResidentsScript.SKILL_LEVEL_MAX
const PERMILLE: int = 1000
const STORM_WORK_PERMILLE: int = 800
const UNITS_PER_M: int = 1024

# --- demo ---------------------------------------------------------------------------------------

const USEC_PER_WU: int = 100000
const MIN_WORK_USEC: int = 2500000
const WINTER_WORK_PERMILLE: int = 800
const CARRY_LOAD_MILLI: int = 6000
const DEADFALL_MIN_MILLI: int = 1000
const DEADFALL_MAX_MILLI: int = 2000
const DEADFALL_STEP_MILLI: int = 250
const DEADFALL_WU_PER_U: int = 20
const DEADFALL_PER_DAY: int = 1
const DEADFALL_PER_STORM: int = 3
const DEADFALL_MAX: int = 10
const SAW_BATCH_MILLI: int = 2000
const SAW_WU: int = 40
const GRUB_WU: int = 30
const LOAD_WU: int = 6
const DROP_WU: int = 4
const REACH_M: float = 30.0
## Residents may walk this much further out than the reach: a tree at its edge falls away from the
## village, and its trunk must still be hauled (the mound and a trunk's length, forest_roots.gd).
const WORK_MARGIN_M: float = 11.0
const TILE_ORIGIN: int = 64
const BLOWDOWNS_PER_STORM: int = 1

const SKILL_FELLING: int = 0
const SKILL_SAWING: int = 1
const SKILL_COUNT: int = 2
const SKILL_NAMES: Array[String] = ["Felling", "Sawing"]

const REFUSE_OFF_GRID: String = "OFF_THE_GRID"


static func tile_of_into(at: Vector2, out: IntMath.IntResult) -> bool:
	"""The GDD §5.1 exterior tile index a demo point stands on: the square's centre is tile (64, 64)
	and a tile is 2048 u (2 m). The point is rounded to whole 1/1024 m units first (the presentation
	-> integer boundary), then floored per axis. Refuses OFF_THE_GRID outside the 128 x 128 grid."""
	var x_u: int = roundi(at.x * UNITS_PER_M)
	var z_u: int = roundi(at.y * UNITS_PER_M)
	var size: int = ResourceNodes.TILE_SIZE_UNITS
	@warning_ignore("integer_division") var tile_x: int = TILE_ORIGIN + (x_u - posmod(x_u, size)) / size
	@warning_ignore("integer_division") var tile_z: int = TILE_ORIGIN + (z_u - posmod(z_u, size)) / size
	if tile_x < 0 or tile_z < 0 or tile_x >= ResourceNodes.MAP_TILES_X or tile_z >= ResourceNodes.MAP_TILES_Z:
		return out.refuse(REFUSE_OFF_GRID)
	return out.succeed(tile_z * ResourceNodes.MAP_TILES_X + tile_x)


static func tile_centre_m(tile: int) -> Vector2:
	"""A tile's centre as a demo point (presentation)."""
	var x: int = tile % ResourceNodes.MAP_TILES_X - TILE_ORIGIN
	@warning_ignore("integer_division") var z: int = tile / ResourceNodes.MAP_TILES_X - TILE_ORIGIN
	var half: float = float(ResourceNodes.TILE_CENTER_OFFSET_UNITS) / float(UNITS_PER_M)
	var size: float = float(ResourceNodes.TILE_SIZE_UNITS) / float(UNITS_PER_M)
	return Vector2(x * size + half, z * size + half)


static func level_of(xp: int) -> int:
	"""GDD §5.3's skill level for an XP total: residents.gd's own curve."""
	return ResidentsScript._skill_level_curve(xp)


static func xp_of_level(level: int) -> int:
	"""The XP a level starts at (5000 x level x level, §5.3's table)."""
	return ResidentsScript.SKILL_XP_PER_LEVEL_SQUARE * level * level


static func skill_factor_permille(level: int) -> int:
	"""GDD §5.3: skill factor = 1000 + 50 x level (mood and health are not modelled in the demo)."""
	return SKILL_FACTOR_BASE + SKILL_FACTOR_PER_LEVEL * level


static func season_permille(season: int, felling: bool) -> int:
	"""How long outdoor wood work takes in a season, per mille: felling in winter is quicker."""
	return WINTER_WORK_PERMILLE if felling and season == WeatherScript.SEASON_WINTER else PERMILLE


static func weather_permille(event: int) -> int:
	"""§5.10: a heavy rain/storm day slows outdoor work to 80%, so the work takes 1000/800 as long."""
	return STORM_WORK_PERMILLE if event == WeatherScript.EVENT_HEAVY_RAIN else PERMILLE


static func work_usec(wu: int, level: int, season_pm: int, speed_pm: int) -> int:
	"""Demo microseconds a job of `wu` WU takes: WU x USEC_PER_WU, divided by the skill factor and by
	the weather's speed, times the season's share -- integer, never below MIN_WORK_USEC."""
	@warning_ignore("integer_division") var base: int = wu * USEC_PER_WU * season_pm / PERMILLE
	@warning_ignore("integer_division") var usec: int = base * PERMILLE / skill_factor_permille(level) * PERMILLE / maxi(speed_pm, 1)
	return maxi(usec, MIN_WORK_USEC)


static func floor_mature(total: int, percent: int) -> int:
	"""The fewest mature trees a zone of `total` trees keeps at `percent`: ceil(total x percent / 100)."""
	@warning_ignore("integer_division") return (total * percent + 99) / 100


static func retention_allows(mature_after: int, total: int, percent: int) -> bool:
	"""Whether a zone of `total` trees keeping `mature_after` mature still keeps `percent` of them."""
	return mature_after >= 0 and mature_after * 100 >= total * percent


static func deadfall_wu(milli: int) -> int:
	"""WU to gather a deadfall pile of `milli`: DEADFALL_WU_PER_U a U, rounded up."""
	@warning_ignore("integer_division") return (milli * DEADFALL_WU_PER_U + 999) / 1000
