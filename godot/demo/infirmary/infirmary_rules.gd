extends RefCounted
## THE INFIRMARY BUILDING'S NUMBERS (decision 0623; Brendan's ruling on 0622, 2026-10-01: "The infirmary should be its
## own place and that's where residents go to rest and heal"). Every figure is read from the settlement's own tables,
## never restated: GDD §5.9's Infirmary row as `gameplay_balance.md` §4.1/§4.2 normalise it and `scripts/core/` compiles
## it -- `building_definitions.gd` (footprint 8 x 8 tiles, 1000000 milli-WU, 2 operational slots "Healer 2", unlock
## M1, at most 4 builders) and `construction.gd BUILD_MATERIALS` (wood 40000, stone 30000, cloth 12000 milli-U). The
## 8 patient beds are GDD §5.9's capacity column ("Interior 6×6;8 patient beds"), which no compiled table carries.
## Presentation only.
##
## THE UNLOCK: available from the start (Brendan's ruling, as for the cellar building, decision 0612 P1); the GDD's M1
## needs 12 residents, which the nine-resident demo never reaches.
##
## BUILDING IT (REQ-SET-124/125/126, the cellar building's flow, decision 0612): placing it deducts nothing; residents
## fetch each material -- wood and stone from the village stores at the open stockpile, CLOTH from the care shelf at the
## hall's steps (the village stores' one cloth: §5.1's starting 24 U, decision 0993) -- reserved as they set off, taken only
## when lifted, at most their §5.2 carry over the material's §5.5 mass; once everything is delivered they build it,
## their work summed, a WU being decision 0210's 0.15 s of one builder's demo time. Cancelled before work begins, 100%
## of what was delivered goes back; after, 80%, floored to the milli-U.

const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Construction := preload("res://scripts/core/construction.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")

const KEY: String = "infirmary"
const MILLI_PER_U: int = 1000
const MWU_PER_WU: int = 1000
const MAT_WOOD: int = 0
const MAT_STONE: int = 1
const MAT_CLOTH: int = 2
const MAT_COUNT: int = 3
const MAT_KEYS: Array[String] = ["wood", "stone", "cloth"]
const MAT_WORDS: Array[String] = ["wood", "stone", "cloth"]
## §5.5: "Material masses: wood 5000g, stone 5000g ... cloth 250g".
const MAT_G_PER_U: Array[int] = [5000, 5000, 250]
## GDD §5.9: "Interior 6×6;8 patient beds".
const PATIENT_BEDS: int = 8
## A WU of one builder's demo time (decision 0210's install rate; the hall's and the cellar's).
const USEC_PER_WU: int = FixturesScript.INSTALL_USEC_PER_WU
const REFUND_BEFORE_PERMILLE: int = 1000
const REFUND_AFTER_PERMILLE: int = 800
const LABEL: String = "Infirmary"

static var _defs: BuildingDefinitions = null


static func defs() -> BuildingDefinitions:
	"""The settlement's building facts (built once; immutable)."""
	if _defs == null:
		_defs = BuildingDefinitions.new()
	return _defs


static func type_id() -> int:
	"""The Infirmary's BuildingDefinition id."""
	return int(Catalog.BUILDING_DEFINITION[KEY])


static func work_wu() -> int:
	"""The WU an infirmary takes to build (1000)."""
	@warning_ignore("integer_division")  # whole WU by intent: 1000000 milli-WU
	var wu: int = defs().work_mwu_of(type_id()) / MWU_PER_WU
	return wu


static func work_usec() -> int:
	"""The demo time one builder takes to build a whole infirmary."""
	return work_wu() * USEC_PER_WU


static func max_builders() -> int:
	"""§5.9's builders a project at most (4)."""
	return defs().max_builders_of(type_id())


static func healer_slots() -> int:
	"""Its operational slots, "Healer 2": healers treating inside it at once."""
	return defs().worker_slots_of(type_id())


static func footprint_tiles() -> Vector2i:
	"""Its §5.9 footprint in 2 m tiles (8 x 8)."""
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
