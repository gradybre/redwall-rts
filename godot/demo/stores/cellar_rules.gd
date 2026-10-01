extends RefCounted
## THE CELLAR BUILDING'S NUMBERS (decision 0612; Brendan's "Build both cellars", 2026-10-01). Every figure comes from
## the settlement's own tables, never restated: GDD §5.9's Cellar row as `gameplay_balance.md` §4.1/§4.2 normalise it
## and `scripts/core/` compiles it -- `building_definitions.gd` (footprint 6 x 6 tiles, 900000 milli-WU, 2 operational
## slots "Hauler 2", unlock M1, base store 1000000 g, at most 4 builders) and `construction.gd BUILD_MATERIALS`
## (wood 20000, stone 60000 milli-U). Presentation only.
##
## CAPACITY IN U. The demo counts stores in U, the GDD a cellar in grams. GRAMS_PER_U is 500: GDD §5.8's winter stock
## fixture sizes cellars at "500g/U ... 5 cellars of 1,000,000g each", the GDD's own reading of a cellar's capacity.
## (§5.5 weighs RAW food at 250 g a unit and prepared food and rations at 500; the demo's stores hold raw food, so by
## mass a cellar would hold 4000 U of it. Decision 0612 P2 puts that to Brendan.) 1000000 / 500 = 2000 U.
##
## WHY IT KEEPS FOOD LONGER: it is §5.8's CELLAR class (350 per mille), like a cool root cellar, but built, not dug.
##
## THE UNLOCK (decision 0612 P1, a PROPOSAL): UNLOCK is the one data constant. The GDD's M1 needs 12 residents, which
## the nine-resident demo can never reach, so the options are: UNLOCK_START, available from the start (built and
## recommended); UNLOCK_M1_SCALED, M1 with its resident count scaled to the demo's cast (day 4 or later, every resident
## of the cast, 200 portions); UNLOCK_PORTIONS_AND_DAY, M1 without the resident count (200 portions and day 4).
##
## BUILDING IT (REQ-SET-124/125/126, matching the hall's flow, decision 0771): placing it deducts nothing; residents
## fetch each material from the village stores (reserved as they set off, taken from the stores only when lifted), at
## most their §5.2 carry of §5.5's 5000 g a unit; once everything is delivered they build it, their work summed, a WU
## being decision 0210's 0.15 s of one builder's demo time. Cancelled before work begins, 100% of what was delivered
## goes back into the stores; after, 80%, floored to the milli-U.

const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Construction := preload("res://scripts/core/construction.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")

const KEY: String = "cellar"
const GRAMS_PER_U: int = 500
const MILLI_PER_U: int = 1000
const MWU_PER_WU: int = 1000
## The materials, in the order the stores hold them (tunnel_stores.gd: wood, stone).
const MAT_WOOD: int = 0
const MAT_STONE: int = 1
const MAT_COUNT: int = 2
const MAT_KEYS: Array[String] = ["wood", "stone"]
const MAT_WORDS: Array[String] = ["wood", "stone"]
## §5.5: "Material masses: wood 5000g, stone 5000g".
const MAT_G_PER_U: Array[int] = [5000, 5000]
## A WU of one builder's demo time (decision 0210's install rate; the hall's ruled P6).
const USEC_PER_WU: int = FixturesScript.INSTALL_USEC_PER_WU
## REQ-SET-126: the share of what was delivered a cancel returns, before and after work begins.
const REFUND_BEFORE_PERMILLE: int = 1000
const REFUND_AFTER_PERMILLE: int = 800
const STORE_CLASS: int = StockAge.STORAGE_CELLAR
const LABEL: String = "Cellar %d"
const WHY: String = "a large store above ground"
## The unlock (see THE UNLOCK): the options, and the one constant that picks.
const UNLOCK_START: int = 0
const UNLOCK_M1_SCALED: int = 1
const UNLOCK_PORTIONS_AND_DAY: int = 2
const UNLOCK: int = UNLOCK_START
## M1's figures (GDD §5.11: "Day≥4 AND at least 12 residents AND prepared 200 portions cumulatively").
const M1_DAY: int = 4
const M1_PORTIONS: int = 200
const LOCKED_WORDS: Array[String] = ["", "it opens at M1: day %d, all %d residents and %d portions cooked",
	"it opens on day %d once %d portions are cooked"]

static var _defs: BuildingDefinitions = null


static func defs() -> BuildingDefinitions:
	"""The settlement's building facts (built once; immutable)."""
	if _defs == null:
		_defs = BuildingDefinitions.new()
	return _defs


static func type_id() -> int:
	"""The Cellar's BuildingDefinition id."""
	return int(Catalog.BUILDING_DEFINITION[KEY])


static func work_wu() -> int:
	"""The WU a cellar takes to build (900)."""
	@warning_ignore("integer_division")  # whole WU by intent: 900000 milli-WU
	var wu: int = defs().work_mwu_of(type_id()) / MWU_PER_WU
	return wu


static func work_usec() -> int:
	"""The demo time one builder takes to build a whole cellar."""
	return work_wu() * USEC_PER_WU


static func max_builders() -> int:
	"""§5.9's builders a project at most (4)."""
	return defs().max_builders_of(type_id())


static func hauler_slots() -> int:
	"""Its operational slots, "Hauler 2" (decision 0612 P3: the demo has no job slots)."""
	return defs().worker_slots_of(type_id())


static func capacity_u() -> int:
	"""How many U it holds (see CAPACITY IN U)."""
	@warning_ignore("integer_division")  # whole U by intent: 1000000 / 500 is exact
	var units: int = defs().base_store_g_of(type_id()) / GRAMS_PER_U
	return units


static func footprint_tiles() -> Vector2i:
	"""Its §5.9 footprint in 2 m tiles (6 x 6)."""
	return Vector2i(defs().footprint_x_of(type_id()), defs().footprint_z_of(type_id()))


static func cost_milli(mat: int) -> int:
	"""How much of a material (MAT_*) it costs, milli-U (construction.gd BUILD_MATERIALS)."""
	var bill: Array = Construction.BUILD_MATERIALS[KEY]
	for k: int in range(0, bill.size(), 2):
		if String(bill[k]) == MAT_KEYS[mat]:
			return int(bill[k + 1])
	return 0


static func carry_milli(size_class: int, mat: int) -> int:
	"""How much of a material one carrier of §5.2 size `size_class` lifts at once, milli-U (its carry over the mass)."""
	@warning_ignore("integer_division")  # whole milli-U by intent
	var milli: int = MealRules.CARRY_G[size_class] * MILLI_PER_U / MAT_G_PER_U[mat]
	return milli


static func refund_milli(delivered_milli: int, work_begun: bool) -> int:
	"""REQ-SET-126: what a cancel returns of `delivered_milli`: all of it before work begins, 80% floored after."""
	@warning_ignore("integer_division")  # floored to the milli-U by intent
	var share: int = delivered_milli * (REFUND_AFTER_PERMILLE if work_begun else REFUND_BEFORE_PERMILLE) / 1000
	return share


static func unlocked(condition: int, day: int, residents: int, cast_size: int, portions: int) -> bool:
	"""Whether `condition` (UNLOCK_*) is met on calendar `day` with `residents` living of a cast of `cast_size` and
	`portions` cooked so far."""
	match condition:
		UNLOCK_M1_SCALED:
			return day >= M1_DAY and residents >= cast_size and portions >= M1_PORTIONS
		UNLOCK_PORTIONS_AND_DAY:
			return day >= M1_DAY and portions >= M1_PORTIONS
	return true


static func locked_words(condition: int, cast_size: int) -> String:
	"""Why it is not open yet, for `condition` ("" when it opens at once)."""
	match condition:
		UNLOCK_M1_SCALED:
			return LOCKED_WORDS[condition] % [M1_DAY, cast_size, M1_PORTIONS]
		UNLOCK_PORTIONS_AND_DAY:
			return LOCKED_WORDS[condition] % [M1_DAY, M1_PORTIONS]
	return ""
