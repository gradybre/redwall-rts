extends RefCounted
## The HarvestZone store, its tile-membership links, and the ForagePatch stocks those zones
## harvest from: GDD §4.2's two rows and §5.5's forage rules (REQ-SET-066 to REQ-SET-069).
##
## SCHEMA, restated from the documents rather than summarised.
##   * GDD §4.2: "HarvestZone | type: enum, tiles: packed int32[], danger: int32,
##     quota_milli: int64, protected: bool, enabled: bool | Up to 128; tile membership max 16384
##     total zone links". systems_architecture.md §2.2 splits that row into `type, danger` (I32,
##     128 rows), `quota_milli` (I64, 128), `protected, enabled` (B8, 128) and
##     `HarvestZone.tiles | tile_id` (I32, 16384). entity_directory.gd reserves
##     KIND_HARVEST_ZONE at 128. All three agree and _init() asserts it.
##   * GDD §4.2: "ForagePatch | zone: EntityRef, item_id: int32, stock_milli: int64,
##     capacity_milli: int64, harvested_year_milli: int64 | 5 patches/forest zone".
##     systems_architecture.md §2.2 gives ForagePatch 640 rows, which is exactly 5 x 128, so the
##     patch block is OWNER-MAJOR: `patch_row = zone_slot * 5 + kind`. That formula is forced by
##     the two stated numbers; nothing is invented to obtain it.
##   * The five kinds are §5.5's five table rows, in the document's own order:
##     berries, nuts, mushrooms, herb, roots. The kind IS the row's index inside its owner block,
##     so the §5.5 table is addressable without a sixth column.
##
## ZoneType comes from catalog.gd's protected §4.3 table (decision 0018), never mirrored here.
## SET-AMEND-001 §3 retires `HUNT=1` to `RESERVED_1=1` and orders "reject creation";
## REQ-SET-060 repeats it, so create_zone() refuses that type before allocating anything.
##
## ---------------------------------------------------------------------------------------
## THE SHARING RULE, WHICH IS THE WHOLE POINT OF THE BASIN REFERENCE. GDD §5.1: "There is one
## stock basin of each habitat type; dividing a player zone never creates extra ecology stock"
## and "Player harvest zones reference basin IDs; all intersecting zones share its quotas and do
## not multiply capacity."
##
## So stock is a property of the BASIN, and a player zone is a designation that points at one.
## This store implements that literally:
##   * Every zone carries a basin reference. A freshly created zone is its OWN basin, so there
##     is no null case and no "unbound" state to forget about.
##   * set_basin() re-points a player zone at the basin zone whose stock it draws from. Chains
##     are refused, so basin_of(basin_of(z)) can never disagree with basin_of(z).
##   * Patches live on the basin zone. harvest() resolves zone -> basin -> patch row, so two
##     zones sharing a basin debit ONE stock column and accumulate ONE harvested_year_milli.
##   * A zone that already owns patches cannot be bound to another basin, and a zone bound to
##     another basin cannot be given patches. Those two refusals are what make "drawn twice"
##     unprofitable: the second designation cannot conjure a second stock to draw from.
##   * The quota applied to a harvest is `min(basin quota, harvesting zone quota)`. §5.1 says
##     intersecting zones share the BASIN's quota; §4.2 also gives every zone its own
##     `quota_milli`. Taking the minimum honours both fields and can only ever be stricter.
##
## ---------------------------------------------------------------------------------------
## RNG. ARCH-RNG-002 fixes the FORAGE stream's discipline exactly: "One hazard roll after each
## completed 60 WU exposure segment in natural danger>=1", ordered by "Worker ID, segment
## sequence". roll_exposure_injuries() therefore performs exactly one draw_below(FORAGE, 10000)
## per completed 60 WU segment and NONE at all at natural danger 0. Worker ordering belongs to
## the caller that walks its workers; this store rolls for one worker's segment run at a time.
## REQ-SET-068 gives the chance as `max(1, 8*danger - FORAGE_level)` per 10000, so a draw in
## [0, 10000) injures when it is strictly below that chance -- the only mapping that yields
## exactly `chance` outcomes in 10000.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS STORE DELIBERATELY DOES NOT DO.
##   * It CREATES NO JOB. No requirement in the document set states what creates a FORAGE job;
##     REQ-SET-073 makes FarmPlot the only automatic job-creation site. Inventing a trigger here
##     would be inventing a contract (docs/tasks/03_ecology_crops_weather.md).
##   * It does no world generation and no player-command designation. REQ-SET-009 is
##     unimplemented and there is no command path (blocker U2), so zones and patches are created
##     by an explicit caller.
##   * It does not apply REQ-SET-068's "10 health loss and severity 1 injury". Health lives in
##     needs.gd and the Injury row of §4.2 has no store yet. roll_exposure_injuries() reports how
##     many injuries were rolled; INJURY_HEALTH_LOSS and INJURY_SEVERITY are compiled here so the
##     store that lands them does not restate the numbers.
##   * It does not stop RESERVATIONS. REQ-SET-069's "stop new reservations and retain already
##     collected cargo for hauling" spans reservations.gd and jobs.gd. What is owned here is the
##     truthful limit: remaining_quota_milli(), is_quota_reached() and a harvest that refuses
##     past the quota. Storage limits are inventory.gd's half of that requirement.
##   * It does not run §5.9's midnight wildlife-pressure roll. That is an ECOLOGY-stream draw
##     owned by ARCH-SYS-005, and its "complete enclosing fence/wall boundary" halving reads a
##     building store that does not exist.
##
## ---------------------------------------------------------------------------------------
## GAPS -- named, not invented (AGENTS.md: "do not invent a constant"):
##   * `quota_milli` HAS NO STATED PERIOD. §4.2 types it and REQ-SET-069 says a reached quota
##     stops reservations, but no clause says whether it is a daily, seasonal or annual budget.
##     The only accumulator in the forage schema is ForagePatch.harvested_year_milli, so the
##     quota is enforced against that year-to-date total; reset_harvested_year() is the caller's
##     year boundary. If the intended period is daily, this schema has nowhere to keep the
##     counter -- §5.4's FishStock has `harvested_today_milli` and ForagePatch pointedly does not.
##   * `quota_milli == 0` PERMITS NOTHING. The document states no "unlimited" encoding, and §4.2
##     says empty counters are 0. Reading 0 as unlimited would make the default state of a field
##     the most permissive one, so it is read as a zero budget and refuses every harvest.
##   * ONE `danger` COLUMN, TWO STATED QUANTITIES. §5.5 defines natural danger ("the basin
##     center's distance category before lookout reductions, fixed at generation") for the
##     work-per-U formula, and separately says "Actual hazard danger still uses staffed lookouts
##     and resident consent". §4.2 gives HarvestZone exactly one `danger` field. Here the basin
##     zone's danger is the natural danger (nothing reduces it, because no lookout/building store
##     exists), and the harvesting zone's own danger is the hazard danger REQ-SET-067 gates on.
##     When staffed lookouts land, the reduced value needs its own field or a stated derivation.
##   * REQ-SET-067's "show an exposure warning" IS NOT IMPLEMENTED. Notices are §4.2's Notice
##     row with no store yet. check_worker_permitted() supplies the consent half only.
##   * THE REGROWTH FORMULA HAS NO STATED CAP. §5.5: "Daily regrowth=floor((K-P)*r*season/1000000)
##     plus a minimum 1 U when season>0 and P<K", with no `min(K, ...)` -- unlike §5.4's fish
##     formula, which writes its cap explicitly. The minimum-1-U term can exceed K-P when a patch
##     is within 1 U of full, so the increment is clamped to K-P. Growing a patch above its own
##     capacity is the only alternative reading and it contradicts the capacity column.
##   * "5 patches/FOREST ZONE" IS READ AS ZoneType.FORAGE. §5.1 calls the ecology partitions
##     "forest ecology basins" and §4.3 has no FOREST zone type; FORESTRY is the wood-cutting
##     zone. Patch creation is therefore restricted to FORAGE zones.
##   * BASIN BINDING IS NOT DERIVED FROM GEOMETRY. §5.1 says intersecting zones share the basin,
##     but no store owns a tile -> basin mask (WorldTileMaps has building_slot, room_slot,
##     zone_link_head and resource_slot, and no basin column), and registering both shipping-map
##     forest basins tile by tile would consume most of the 16384 link budget. set_basin() is
##     therefore explicit and zones_intersect() is exposed so the eventual designation command
##     can require the intersection §5.1 describes.
##   * `item_id`'s DOMAIN IS THE CALLER'S. §4.2 types it int32 and never says which catalog.
##     PATCH_KEYS holds §5.5's five item keys so a caller can compile them through
##     item_definitions.gd; this store validates the range only.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Rng := preload("res://scripts/core/rng.gd")

# --- capacities (GDD §4.2, systems_architecture.md §2.2, entity_directory.gd) ---------------------

## GDD §4.2: "Up to 128".
const HARVEST_ZONE_CAPACITY: int = 128
## GDD §4.2: "tile membership max 16384 total zone links".
const ZONE_LINK_CAPACITY: int = 16384
## GDD §4.2: "5 patches/forest zone".
const PATCHES_PER_ZONE: int = 5
## systems_architecture.md §2.2 ForagePatch length: 640 == 128 * 5.
const FORAGE_PATCH_CAPACITY: int = HARVEST_ZONE_CAPACITY * PATCHES_PER_ZONE

## GDD §5.1 exterior grid: index `z*128+x`, 16384 tiles, matching WorldTileMaps' row count.
const MAP_TILES_X: int = 128
const MAP_TILES_Z: int = 128
const TILE_COUNT: int = MAP_TILES_X * MAP_TILES_Z

# --- GDD §4.3 ZoneType, read from catalog.gd's protected table (decision 0018) --------------------

const ZONE_TYPE_FISH: int = Catalog.ZONE_TYPE["FISH"]
## SET-AMEND-001 §3: the retired hunting zone. Creation is rejected, the value is never reused.
const ZONE_TYPE_RESERVED_1: int = Catalog.ZONE_TYPE["RESERVED_1"]
const ZONE_TYPE_FORAGE: int = Catalog.ZONE_TYPE["FORAGE"]
const ZONE_TYPE_FARM: int = Catalog.ZONE_TYPE["FARM"]
const ZONE_TYPE_ORCHARD: int = Catalog.ZONE_TYPE["ORCHARD"]
const ZONE_TYPE_FORESTRY: int = Catalog.ZONE_TYPE["FORESTRY"]
const ZONE_TYPE_QUARRY: int = Catalog.ZONE_TYPE["QUARRY"]
const ZONE_TYPE_STOCKPILE: int = Catalog.ZONE_TYPE["STOCKPILE"]
const ZONE_TYPE_CONSERVATION: int = Catalog.ZONE_TYPE["CONSERVATION"]
const ZONE_TYPE_COUNT: int = 9

# --- GDD §4.3 Season, likewise from the protected table ------------------------------------------

const SEASON_SPRING: int = Catalog.SEASON["SPRING"]
const SEASON_SUMMER: int = Catalog.SEASON["SUMMER"]
const SEASON_AUTUMN: int = Catalog.SEASON["AUTUMN"]
const SEASON_WINTER: int = Catalog.SEASON["WINTER"]
const SEASON_COUNT: int = 4

# --- GDD §5.5 forage table, row for row ----------------------------------------------------------

const PATCH_BERRIES: int = 0
const PATCH_NUTS: int = 1
const PATCH_MUSHROOMS: int = 2
const PATCH_HERB: int = 3
const PATCH_ROOTS: int = 4

## §5.5's five "Forage item" rows in the document's own order. Item ids are compiled elsewhere;
## these keys exist so a caller can resolve them through item_definitions.gd.
const PATCH_KEYS: Array[StringName] = [&"berries", &"nuts", &"mushrooms", &"herb", &"roots"]

## §5.5 "Patch capacity U" column, whole units.
const PATCH_CAPACITY_U: Array[int] = [300, 240, 180, 160, 300]
## §5.5 "Base work WU/U" column.
const PATCH_BASE_WORK_WU: Array[int] = [4, 5, 5, 8, 6]
## §5.5 "Daily regrowth fraction/1000" column, the `r` of the regrowth formula.
const PATCH_REGROWTH_PER_1000: Array[int] = [120, 60, 100, 80, 70]
## §5.5's Spring/Summer/Autumn/Winter availability columns, flattened as `kind*4 + season`.
## Zeroes are §5.5's dormant seasons: "unavailable patches become dormant, not destroyed".
const PATCH_AVAILABILITY_PER_1000: Array[int] = [
	0, 1000, 400, 0,
	0, 200, 1200, 300,
	500, 300, 1200, 0,
	1000, 1200, 600, 200,
	800, 1000, 1200, 400,
]

## AGENTS.md: "Quantities are quantity_milli:int64 (1000 = one unit)."
const MILLI_PER_UNIT: int = 1000

## GDD §5.1: "forage stocks are floor(0.8xcapacity), including dormant stocks."
const INITIAL_STOCK_NUMERATOR: int = 8
const INITIAL_STOCK_DENOMINATOR: int = 10

## §5.5: "Sustainable floor 20%K; intensive floor 5%K."
const SUSTAINABLE_FLOOR_PERCENT: int = 20
const INTENSIVE_FLOOR_PERCENT: int = 5
const PERCENT_DENOMINATOR: int = 100

## §5.5: "Daily regrowth=floor((K-P)*r*season/1000000) plus a minimum 1 U when season>0 and P<K."
const REGROWTH_DENOMINATOR: int = 1000000
const REGROWTH_MINIMUM_MILLI: int = MILLI_PER_UNIT

## §5.5: "Work per U=ceil(base_work*1000000/((1000+40*FORAGE_level)*(1000+100*natural_danger)))".
const WORK_NUMERATOR_SCALE: int = 1000000
const WORK_BASE_TERM: int = 1000
const WORK_SKILL_TERM: int = 40
const WORK_DANGER_TERM: int = 100

## §5.5: "Danger zones:0 inside 32 m of any staffed lookout;1 remaining land within 64 m of the
## central hall;2 at 64-96 m;3 beyond 96 m."
const DANGER_MIN: int = 0
const DANGER_MAX: int = 3
## REQ-SET-067: "While a forage zone has danger 2 or 3".
const DANGEROUS_WORK_DANGER: int = 2
## ARCH-RNG-002: rolls happen only "in natural danger>=1".
const INJURY_ROLL_MIN_DANGER: int = 1

## REQ-SET-068: "When a forager completes 60 WU in danger>=1, the system shall roll injury chance
## `max(1,8*danger-FORAGE_level)` per 10000, causing 10 health loss and severity 1 injury".
const EXPOSURE_SEGMENT_WU: int = 60
const INJURY_ROLL_DENOMINATOR: int = 10000
const INJURY_DANGER_FACTOR: int = 8
const INJURY_CHANCE_MINIMUM: int = 1
const INJURY_HEALTH_LOSS: int = 10
const INJURY_SEVERITY: int = 1

## Empty value of `WorldTileMaps.zone_link_head` and of every link cursor.
const NO_LINK: int = -1
const NULL_REF: Vector2i = EntityDirectory.NULL_REF

# --- refusal codes -------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_ZONE_NOT_PRESENT: StringName = &"ZONE_NOT_PRESENT"
const REFUSE_INVALID_ZONE_TYPE: StringName = &"INVALID_ZONE_TYPE"
const REFUSE_RESERVED_ZONE_TYPE: StringName = &"RESERVED_ZONE_TYPE"
const REFUSE_ZONE_TYPE_MISMATCH: StringName = &"ZONE_TYPE_MISMATCH"
const REFUSE_INVALID_DANGER: StringName = &"INVALID_DANGER"
const REFUSE_INVALID_QUOTA: StringName = &"INVALID_QUOTA"
const REFUSE_INVALID_TILE: StringName = &"INVALID_TILE"
const REFUSE_INVALID_TILE_COORDINATE: StringName = &"INVALID_TILE_COORDINATE"
const REFUSE_TILE_ALREADY_LINKED: StringName = &"TILE_ALREADY_LINKED"
const REFUSE_TILE_NOT_LINKED: StringName = &"TILE_NOT_LINKED"
const REFUSE_ZONE_LINK_CAPACITY: StringName = &"CAPACITY_ZONE_LINK"
const REFUSE_INVALID_PATCH_KIND: StringName = &"INVALID_PATCH_KIND"
const REFUSE_INVALID_ITEM_ID: StringName = &"INVALID_ITEM_ID"
const REFUSE_PATCH_PRESENT: StringName = &"PATCH_ALREADY_PRESENT"
const REFUSE_PATCH_NOT_PRESENT: StringName = &"PATCH_NOT_PRESENT"
const REFUSE_PATCH_SET_SIZE: StringName = &"PATCH_SET_SIZE"
const REFUSE_PATCH_DORMANT: StringName = &"PATCH_DORMANT"
const REFUSE_INVALID_SEASON: StringName = &"INVALID_SEASON"
const REFUSE_INVALID_AMOUNT: StringName = &"INVALID_AMOUNT"
const REFUSE_BELOW_HARVEST_FLOOR: StringName = &"BELOW_HARVEST_FLOOR"
const REFUSE_QUOTA_REACHED: StringName = &"QUOTA_REACHED"
const REFUSE_ZONE_DISABLED: StringName = &"ZONE_DISABLED"
const REFUSE_ZONE_PROTECTED: StringName = &"ZONE_PROTECTED"
const REFUSE_DANGEROUS_WORK_REFUSED: StringName = &"DANGEROUS_WORK_REFUSED"
const REFUSE_BASIN_CHAIN: StringName = &"BASIN_CHAIN"
const REFUSE_BASIN_HAS_OWN_PATCHES: StringName = &"BASIN_HAS_OWN_PATCHES"
const REFUSE_ZONE_IS_BOUND: StringName = &"ZONE_IS_BOUND"
const REFUSE_INVALID_SKILL_LEVEL: StringName = &"INVALID_SKILL_LEVEL"
const REFUSE_INVALID_WORK: StringName = &"INVALID_WORK"
const REFUSE_NO_RNG: StringName = &"NO_RNG"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"


class OpResult:
	"""Outcome of one forage operation: success flag, refusal code, value and reference.

	`.ok` MUST be inspected before `.value` or `.ref` is used. A refusal always carries value 0
	and the null reference, and never a partially applied effect.
	"""
	var ok: bool
	var error: StringName
	var value: int
	var ref: Vector2i

	func _init(p_ok: bool, p_error: StringName, p_value: int, p_ref: Vector2i) -> void:
		"""Store the outcome fields for this operation."""
		ok = p_ok
		error = p_error
		value = p_value
		ref = p_ref


# --- collaborators -------------------------------------------------------------------------------

var _directory: EntityDirectory = null
var _owns_directory: bool = false

# --- HarvestZone columns (ARCH-MEM-001: packed, allocated once) -----------------------------------

var _zone_present: PackedByteArray = PackedByteArray()
var _zone_type: PackedInt32Array = PackedInt32Array()
var _zone_danger: PackedInt32Array = PackedInt32Array()
var _zone_quota_milli: PackedInt64Array = PackedInt64Array()
var _zone_protected: PackedByteArray = PackedByteArray()
var _zone_enabled: PackedByteArray = PackedByteArray()

## The directory reference owning each zone row, so a row can hand back a validatable ref.
var _zone_ref_slot: PackedInt32Array = PackedInt32Array()
var _zone_ref_generation: PackedInt32Array = PackedInt32Array()

## GDD §5.1's "Player harvest zones reference basin IDs". A new zone is its own basin.
var _zone_basin_slot: PackedInt32Array = PackedInt32Array()
var _zone_basin_generation: PackedInt32Array = PackedInt32Array()

## Head of each zone's own tile-link list, and the length of that list.
var _zone_link_head: PackedInt32Array = PackedInt32Array()
var _zone_tile_count: PackedInt32Array = PackedInt32Array()
## Number of live ForagePatch rows in this zone's five-row block.
var _zone_patch_count: PackedInt32Array = PackedInt32Array()

## Ascending list of live zone rows, so a daily sweep iterates zones and not all 128 slots.
var _live_zone_slots: PackedInt32Array = PackedInt32Array()
var _live_zone_count: int = 0

# --- HarvestZone.tiles: the 16384-link arena, threaded into two lists per link --------------------

var _link_tile: PackedInt32Array = PackedInt32Array()
var _link_zone: PackedInt32Array = PackedInt32Array()
var _link_tile_next: PackedInt32Array = PackedInt32Array()
var _link_zone_next: PackedInt32Array = PackedInt32Array()

## `WorldTileMaps.zone_link_head` (systems_architecture.md §2): one int32 per exterior tile.
## A tile carries a LIST, not a slot, because §5.1's overlapping zones must all reach it.
var _tile_link_head: PackedInt32Array = PackedInt32Array()

## Bump allocator plus free list: `_link_bump` links have ever been handed out, and released
## links are recycled through `_link_free_head`. Neither ever resizes a column.
var _link_bump: int = 0
var _link_free_head: int = NO_LINK
var _link_used: int = 0

# --- ForagePatch columns, owner-major at `zone_slot * 5 + kind` -----------------------------------

var _patch_present: PackedByteArray = PackedByteArray()
var _patch_item_id: PackedInt32Array = PackedInt32Array()
var _patch_zone_slot: PackedInt32Array = PackedInt32Array()
var _patch_zone_generation: PackedInt32Array = PackedInt32Array()
var _patch_stock_milli: PackedInt64Array = PackedInt64Array()
var _patch_capacity_milli: PackedInt64Array = PackedInt64Array()
var _patch_harvested_year_milli: PackedInt64Array = PackedInt64Array()

# --- scratch (not simulation state) ---------------------------------------------------------------

## Checked-arithmetic scratch for int_math's `_into` forms. Nothing here invokes a callback or a
## signal, so no public operation can re-enter while it holds a live value.
var _math: IntMath.IntResult = IntMath.IntResult.new()
## A second scratch for the two places that need a live value while computing another.
var _math_b: IntMath.IntResult = IntMath.IntResult.new()


func _init(p_directory: EntityDirectory = null) -> void:
	"""Allocate every column once and adopt or build the directory behind every zone reference."""
	assert(HARVEST_ZONE_CAPACITY
			== EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_HARVEST_ZONE],
		"harvest-zone columns must match the directory's HARVEST_ZONE row capacity")
	assert(PATCH_KEYS.size() == PATCHES_PER_ZONE, "GDD §5.5 lists exactly five forage items")
	assert(PATCH_CAPACITY_U.size() == PATCHES_PER_ZONE, "one capacity per §5.5 forage row")
	assert(PATCH_BASE_WORK_WU.size() == PATCHES_PER_ZONE, "one base work per §5.5 forage row")
	assert(PATCH_REGROWTH_PER_1000.size() == PATCHES_PER_ZONE, "one r per §5.5 forage row")
	assert(PATCH_AVAILABILITY_PER_1000.size() == PATCHES_PER_ZONE * SEASON_COUNT,
		"§5.5 gives four seasonal availabilities for each of the five forage rows")
	_owns_directory = p_directory == null
	_directory = p_directory if p_directory != null else EntityDirectory.new()
	_allocate_columns()
	clear()


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
	_allocate_zone_columns()
	_allocate_link_columns()
	_allocate_patch_columns()


func _allocate_zone_columns() -> void:
	"""Size the twelve HarvestZone columns and the live-zone index at 128 rows."""
	_zone_present.resize(HARVEST_ZONE_CAPACITY)
	_zone_type.resize(HARVEST_ZONE_CAPACITY)
	_zone_danger.resize(HARVEST_ZONE_CAPACITY)
	_zone_quota_milli.resize(HARVEST_ZONE_CAPACITY)
	_zone_protected.resize(HARVEST_ZONE_CAPACITY)
	_zone_enabled.resize(HARVEST_ZONE_CAPACITY)
	_zone_ref_slot.resize(HARVEST_ZONE_CAPACITY)
	_zone_ref_generation.resize(HARVEST_ZONE_CAPACITY)
	_zone_basin_slot.resize(HARVEST_ZONE_CAPACITY)
	_zone_basin_generation.resize(HARVEST_ZONE_CAPACITY)
	_zone_link_head.resize(HARVEST_ZONE_CAPACITY)
	_zone_tile_count.resize(HARVEST_ZONE_CAPACITY)
	_zone_patch_count.resize(HARVEST_ZONE_CAPACITY)
	_live_zone_slots.resize(HARVEST_ZONE_CAPACITY)


func _allocate_link_columns() -> void:
	"""Size the 16384-entry link arena and the per-tile head column."""
	_link_tile.resize(ZONE_LINK_CAPACITY)
	_link_zone.resize(ZONE_LINK_CAPACITY)
	_link_tile_next.resize(ZONE_LINK_CAPACITY)
	_link_zone_next.resize(ZONE_LINK_CAPACITY)
	_tile_link_head.resize(TILE_COUNT)


func _allocate_patch_columns() -> void:
	"""Size the seven ForagePatch columns at 640 rows (128 zones x 5 patches)."""
	_patch_present.resize(FORAGE_PATCH_CAPACITY)
	_patch_item_id.resize(FORAGE_PATCH_CAPACITY)
	_patch_zone_slot.resize(FORAGE_PATCH_CAPACITY)
	_patch_zone_generation.resize(FORAGE_PATCH_CAPACITY)
	_patch_stock_milli.resize(FORAGE_PATCH_CAPACITY)
	_patch_capacity_milli.resize(FORAGE_PATCH_CAPACITY)
	_patch_harvested_year_milli.resize(FORAGE_PATCH_CAPACITY)


func clear() -> void:
	"""Return every column to its empty state without reallocating one of them.

	Every live zone's directory slot is released first, so dropping this store cannot strand
	allocated slots in a directory it does not own.
	"""
	_release_live_zones()
	_clear_zone_columns()
	_clear_link_columns()
	_clear_patch_columns()
	if _owns_directory:
		_directory.clear()


func _release_live_zones() -> void:
	"""Destroy the directory slot of every live zone, so a clear leaks no allocation."""
	for index: int in _live_zone_count:
		var slot: int = _live_zone_slots[index]
		if slot < 0 or slot >= HARVEST_ZONE_CAPACITY or _zone_present[slot] != 1:
			continue
		_directory.destroy(Vector2i(_zone_ref_slot[slot], _zone_ref_generation[slot]))


func _clear_zone_columns() -> void:
	"""Refill every HarvestZone column with its empty value."""
	_zone_present.fill(0)
	_zone_type.fill(0)
	_zone_danger.fill(0)
	_zone_quota_milli.fill(0)
	_zone_protected.fill(0)
	_zone_enabled.fill(0)
	_zone_ref_slot.fill(EntityDirectory.NULL_SLOT)
	_zone_ref_generation.fill(EntityDirectory.NULL_GENERATION)
	_zone_basin_slot.fill(EntityDirectory.NULL_SLOT)
	_zone_basin_generation.fill(EntityDirectory.NULL_GENERATION)
	_zone_link_head.fill(NO_LINK)
	_zone_tile_count.fill(0)
	_zone_patch_count.fill(0)
	_live_zone_slots.fill(EntityDirectory.NULL_SLOT)
	_live_zone_count = 0


func _clear_link_columns() -> void:
	"""Empty the link arena. The bump allocator makes this O(columns), not O(16384) writes."""
	_link_tile.fill(NO_LINK)
	_link_zone.fill(EntityDirectory.NULL_SLOT)
	_link_tile_next.fill(NO_LINK)
	_link_zone_next.fill(NO_LINK)
	_tile_link_head.fill(NO_LINK)
	_link_bump = 0
	_link_free_head = NO_LINK
	_link_used = 0


func _clear_patch_columns() -> void:
	"""Refill every ForagePatch column with its empty value."""
	_patch_present.fill(0)
	_patch_item_id.fill(-1)
	_patch_zone_slot.fill(EntityDirectory.NULL_SLOT)
	_patch_zone_generation.fill(EntityDirectory.NULL_GENERATION)
	_patch_stock_milli.fill(0)
	_patch_capacity_milli.fill(0)
	_patch_harvested_year_milli.fill(0)


func directory() -> EntityDirectory:
	"""The allocator behind every harvest-zone reference."""
	return _directory


# --- GDD §5.1 exterior tile geometry ---------------------------------------------------------------

func is_tile_index(tile: int) -> bool:
	"""True when `tile` addresses one of the 16384 exterior tiles."""
	return tile >= 0 and tile < TILE_COUNT


func tile_index(x: int, z: int) -> IntMath.IntResult:
	"""GDD §5.1 exterior tile index `z*128+x`, or an explicit refusal off the 128x128 grid."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	tile_index_into(x, z, out)
	return out


func tile_index_into(x: int, z: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating tile_index(): write `z*128+x` into caller-owned `out`, return out.ok."""
	if x < 0 or x >= MAP_TILES_X or z < 0 or z >= MAP_TILES_Z:
		return out.refuse(String(REFUSE_INVALID_TILE_COORDINATE))
	return out.succeed(z * MAP_TILES_X + x)


# --- zone lifecycle ---------------------------------------------------------------------------------

func create_zone(zone_type: int, danger: int, quota_milli: int, is_protected: bool,
		is_enabled: bool) -> OpResult:
	"""Designate one HarvestZone with no tiles and no patches, owning itself as its basin.

	REQ-SET-060 and SET-AMEND-001 §3: a RESERVED_1 zone is refused "before allocating a job or
	changing the world", so the type is checked before the directory is touched. Refuses -- and
	allocates nothing -- on an unknown type, a danger outside §5.5's 0..3 bands, or a negative
	quota.
	"""
	var code: StringName = _refuse_create_zone(zone_type, danger, quota_milli)
	if code != REFUSE_NONE:
		return _refuse(code)
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_HARVEST_ZONE)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var slot: int = _directory.get_typed_row(ref)
	_write_created_zone(slot, ref, zone_type, danger, quota_milli, is_protected, is_enabled)
	return _succeed(slot, ref)


func _refuse_create_zone(zone_type: int, danger: int, quota_milli: int) -> StringName:
	"""The code blocking a zone creation, or REFUSE_NONE when every argument is storable."""
	if zone_type == ZONE_TYPE_RESERVED_1:
		return REFUSE_RESERVED_ZONE_TYPE
	if zone_type < 0 or zone_type >= ZONE_TYPE_COUNT:
		return REFUSE_INVALID_ZONE_TYPE
	if danger < DANGER_MIN or danger > DANGER_MAX:
		return REFUSE_INVALID_DANGER
	if quota_milli < 0:
		return REFUSE_INVALID_QUOTA
	return REFUSE_NONE


func _write_created_zone(slot: int, ref: Vector2i, zone_type: int, danger: int, quota_milli: int,
		is_protected: bool, is_enabled: bool) -> void:
	"""Write every §4.2 column of a freshly designated zone and make it its own basin."""
	_zone_present[slot] = 1
	_zone_type[slot] = zone_type
	_zone_danger[slot] = danger
	_zone_quota_milli[slot] = quota_milli
	_zone_protected[slot] = 1 if is_protected else 0
	_zone_enabled[slot] = 1 if is_enabled else 0
	_zone_ref_slot[slot] = ref.x
	_zone_ref_generation[slot] = ref.y
	_zone_basin_slot[slot] = ref.x
	_zone_basin_generation[slot] = ref.y
	_zone_link_head[slot] = NO_LINK
	_zone_tile_count[slot] = 0
	_zone_patch_count[slot] = 0
	_insert_live_zone(slot)


func destroy_zone(ref: Vector2i) -> OpResult:
	"""Remove one zone, release every tile link and patch it owns, and free its directory slot.

	Returns the number of tile links released. Refuses a stale or wrong-kind reference rather
	than clearing whatever row it points at, which is what makes a reused slot safe.
	"""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_HARVEST_ZONE):
		return _refuse(REFUSE_ZONE_NOT_PRESENT)
	var slot: int = _directory.get_typed_row(ref)
	if not is_zone_present(slot):
		return _refuse(REFUSE_ZONE_NOT_PRESENT)
	var released: int = _release_zone_links(slot)
	_release_zone_patches(slot)
	_zone_present[slot] = 0
	_zone_ref_slot[slot] = EntityDirectory.NULL_SLOT
	_zone_ref_generation[slot] = EntityDirectory.NULL_GENERATION
	_zone_basin_slot[slot] = EntityDirectory.NULL_SLOT
	_zone_basin_generation[slot] = EntityDirectory.NULL_GENERATION
	_remove_live_zone(slot)
	_directory.destroy(ref)
	return _succeed(released, NULL_REF)


func _release_zone_links(zone_slot: int) -> int:
	"""Unlink and recycle every tile link of a zone. Returns how many were released."""
	var released: int = 0
	var link: int = _zone_link_head[zone_slot]
	while link != NO_LINK:
		var next_link: int = _link_zone_next[link]
		_unlink_from_tile(_link_tile[link], link)
		_free_link(link)
		released += 1
		link = next_link
	_zone_link_head[zone_slot] = NO_LINK
	_zone_tile_count[zone_slot] = 0
	return released


func _release_zone_patches(zone_slot: int) -> void:
	"""Empty the five-row ForagePatch block a destroyed zone owns."""
	var base: int = zone_slot * PATCHES_PER_ZONE
	for kind: int in PATCHES_PER_ZONE:
		var row: int = base + kind
		_patch_present[row] = 0
		_patch_item_id[row] = -1
		_patch_zone_slot[row] = EntityDirectory.NULL_SLOT
		_patch_zone_generation[row] = EntityDirectory.NULL_GENERATION
		_patch_stock_milli[row] = 0
		_patch_capacity_milli[row] = 0
		_patch_harvested_year_milli[row] = 0
	_zone_patch_count[zone_slot] = 0


func _insert_live_zone(slot: int) -> void:
	"""Insert a created zone into the ascending live list, keeping iteration order stable."""
	var index: int = _live_zone_count
	while index > 0 and _live_zone_slots[index - 1] > slot:
		_live_zone_slots[index] = _live_zone_slots[index - 1]
		index -= 1
	_live_zone_slots[index] = slot
	_live_zone_count += 1


func _remove_live_zone(slot: int) -> void:
	"""Remove a zone from the ascending live list, closing the gap behind it."""
	var index: int = 0
	while index < _live_zone_count and _live_zone_slots[index] != slot:
		index += 1
	if index >= _live_zone_count:
		return
	while index + 1 < _live_zone_count:
		_live_zone_slots[index] = _live_zone_slots[index + 1]
		index += 1
	_live_zone_count -= 1
	_live_zone_slots[_live_zone_count] = EntityDirectory.NULL_SLOT


# --- zone readers -------------------------------------------------------------------------------------

func is_zone_present(slot: int) -> bool:
	"""True when `slot` is in range and holds a designated harvest zone."""
	return slot >= 0 and slot < HARVEST_ZONE_CAPACITY and _zone_present[slot] == 1


func zone_count() -> int:
	"""Number of live harvest zones."""
	return _live_zone_count


func live_zone_slot_at(index: int) -> IntMath.IntResult:
	"""The `index`-th live zone in ascending slot order, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if index < 0 or index >= _live_zone_count:
		out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
		return out
	out.succeed(_live_zone_slots[index])
	return out


func zone_ref_of(slot: int) -> Vector2i:
	"""The directory reference owning a zone row, or the §4.1 null reference `(-1, 0)`."""
	if not is_zone_present(slot):
		return NULL_REF
	return Vector2i(_zone_ref_slot[slot], _zone_ref_generation[slot])


func zone_slot_of(ref: Vector2i) -> IntMath.IntResult:
	"""The row a live harvest-zone reference addresses, or an explicit refusal when it is stale."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	zone_slot_of_into(ref, out)
	return out


func zone_slot_of_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating zone_slot_of(): write the validated row into caller-owned `out`."""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_HARVEST_ZONE):
		return out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
	var slot: int = _directory.get_typed_row(ref)
	if not is_zone_present(slot):
		return out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
	return out.succeed(slot)


func zone_type_of(slot: int) -> IntMath.IntResult:
	"""The zone's §4.3 ZoneType, or an explicit refusal."""
	return _read_zone(slot, _zone_type)


func zone_danger_of(slot: int) -> IntMath.IntResult:
	"""The zone's own §5.5 danger band, 0..3 -- the hazard danger REQ-SET-067 gates on."""
	return _read_zone(slot, _zone_danger)


func zone_quota_milli_of(slot: int) -> IntMath.IntResult:
	"""The zone's §4.2 `quota_milli`, or an explicit refusal. See the header on its period."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_zone_present(slot):
		out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
		return out
	out.succeed(_zone_quota_milli[slot])
	return out


func is_zone_protected(slot: int) -> bool:
	"""True when §5.5's "Protected tiles are never automatically harvested" applies to this zone."""
	return is_zone_present(slot) and _zone_protected[slot] == 1


func is_zone_enabled(slot: int) -> bool:
	"""True when the zone's §4.2 `enabled` flag is set."""
	return is_zone_present(slot) and _zone_enabled[slot] == 1


func set_zone_enabled(ref: Vector2i, is_enabled: bool) -> OpResult:
	"""Set the zone's `enabled` flag. Refuses a stale reference rather than writing a dead row."""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	_zone_enabled[_math.value] = 1 if is_enabled else 0
	return _succeed(_math.value, ref)


func set_zone_protected(ref: Vector2i, is_protected: bool) -> OpResult:
	"""Set the zone's `protected` flag. Refuses a stale reference rather than writing a dead row."""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	_zone_protected[_math.value] = 1 if is_protected else 0
	return _succeed(_math.value, ref)


func _read_zone(slot: int, column: PackedInt32Array) -> IntMath.IntResult:
	"""Read one int32 zone column of a live row, refusing rather than returning a default."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_zone_present(slot):
		out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
		return out
	out.succeed(column[slot])
	return out


# --- HarvestZone.tiles: membership links ------------------------------------------------------------

func add_tile(ref: Vector2i, tile: int) -> OpResult:
	"""Link one exterior tile into a zone. Returns the zone's tile count after the link.

	Refuses at GDD §4.2's 16384 total-link ceiling, off the grid, and on a tile this zone already
	covers -- a duplicate link would spend the shared budget on nothing. A tile covered by
	ANOTHER zone is accepted: §5.1's overlapping designations are the case the per-tile list
	exists for, and sharing is settled by the basin reference, not by refusing the overlap.
	"""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	if not is_tile_index(tile):
		return _refuse(REFUSE_INVALID_TILE)
	if _find_link(slot, tile) != NO_LINK:
		return _refuse(REFUSE_TILE_ALREADY_LINKED)
	if _link_used >= ZONE_LINK_CAPACITY:
		return _refuse(REFUSE_ZONE_LINK_CAPACITY)
	var link: int = _take_link()
	_link_tile[link] = tile
	_link_zone[link] = slot
	_link_tile_next[link] = _tile_link_head[tile]
	_tile_link_head[tile] = link
	_link_zone_next[link] = _zone_link_head[slot]
	_zone_link_head[slot] = link
	_zone_tile_count[slot] += 1
	return _succeed(_zone_tile_count[slot], ref)


func remove_tile(ref: Vector2i, tile: int) -> OpResult:
	"""Unlink one tile from a zone and recycle its link. Returns the zone's remaining tile count."""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	if not is_tile_index(tile):
		return _refuse(REFUSE_INVALID_TILE)
	var link: int = _find_link(slot, tile)
	if link == NO_LINK:
		return _refuse(REFUSE_TILE_NOT_LINKED)
	_unlink_from_tile(tile, link)
	_unlink_from_zone(slot, link)
	_free_link(link)
	_zone_tile_count[slot] -= 1
	return _succeed(_zone_tile_count[slot], ref)


func _take_link() -> int:
	"""Hand out one link from the free list, or from the never-used bump region."""
	var link: int = _link_free_head
	if link != NO_LINK:
		_link_free_head = _link_tile_next[link]
	else:
		link = _link_bump
		_link_bump += 1
	_link_used += 1
	return link


func _free_link(link: int) -> void:
	"""Return one link to the free list, clearing every field it carried."""
	_link_tile[link] = NO_LINK
	_link_zone[link] = EntityDirectory.NULL_SLOT
	_link_zone_next[link] = NO_LINK
	_link_tile_next[link] = _link_free_head
	_link_free_head = link
	_link_used -= 1


func _find_link(zone_slot: int, tile: int) -> int:
	"""The link joining a zone to a tile, or NO_LINK. Walks the tile's list, which is the short one."""
	var link: int = _tile_link_head[tile]
	while link != NO_LINK:
		if _link_zone[link] == zone_slot:
			return link
		link = _link_tile_next[link]
	return NO_LINK


func _unlink_from_tile(tile: int, link: int) -> void:
	"""Splice one link out of its tile's list, updating `WorldTileMaps.zone_link_head` if it led."""
	var cursor: int = _tile_link_head[tile]
	if cursor == link:
		_tile_link_head[tile] = _link_tile_next[link]
		return
	while cursor != NO_LINK and _link_tile_next[cursor] != link:
		cursor = _link_tile_next[cursor]
	if cursor != NO_LINK:
		_link_tile_next[cursor] = _link_tile_next[link]


func _unlink_from_zone(zone_slot: int, link: int) -> void:
	"""Splice one link out of its zone's list, updating the zone's head if it led."""
	var cursor: int = _zone_link_head[zone_slot]
	if cursor == link:
		_zone_link_head[zone_slot] = _link_zone_next[link]
		return
	while cursor != NO_LINK and _link_zone_next[cursor] != link:
		cursor = _link_zone_next[cursor]
	if cursor != NO_LINK:
		_link_zone_next[cursor] = _link_zone_next[link]


func zone_covers_tile(ref: Vector2i, tile: int) -> bool:
	"""True when a live zone has this exterior tile in its membership list."""
	if not zone_slot_of_into(ref, _math_b):
		return false
	return is_tile_index(tile) and _find_link(_math_b.value, tile) != NO_LINK


func tile_count_of(slot: int) -> IntMath.IntResult:
	"""The number of tiles a live zone covers, or an explicit refusal."""
	return _read_zone(slot, _zone_tile_count)


func link_count() -> int:
	"""Total live tile links across every zone, against GDD §4.2's 16384 ceiling."""
	return _link_used


func tile_link_head_of(tile: int) -> IntMath.IntResult:
	"""`WorldTileMaps.zone_link_head` for one tile: its first link, or NO_LINK when uncovered."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tile_index(tile):
		out.refuse(String(REFUSE_INVALID_TILE))
		return out
	out.succeed(_tile_link_head[tile])
	return out


func next_tile_link(link: int) -> IntMath.IntResult:
	"""The next link in a tile's list, or an explicit refusal for a cursor off the arena."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if link < 0 or link >= ZONE_LINK_CAPACITY:
		out.refuse(String(REFUSE_ZONE_LINK_CAPACITY))
		return out
	out.succeed(_link_tile_next[link])
	return out


func zone_slot_of_link(link: int) -> IntMath.IntResult:
	"""The zone row a link belongs to, or an explicit refusal for a cursor off the arena."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if link < 0 or link >= ZONE_LINK_CAPACITY:
		out.refuse(String(REFUSE_ZONE_LINK_CAPACITY))
		return out
	out.succeed(_link_zone[link])
	return out


func zones_intersect(a_ref: Vector2i, b_ref: Vector2i) -> bool:
	"""True when two live zones share at least one exterior tile.

	§5.1 describes the basin as shared by "all intersecting zones". Nothing here derives the
	basin from this test -- see the header -- but the designation command will need it.
	"""
	if not zone_slot_of_into(a_ref, _math) or not zone_slot_of_into(b_ref, _math_b):
		return false
	var a_slot: int = _math.value
	var b_slot: int = _math_b.value
	var link: int = _zone_link_head[a_slot]
	while link != NO_LINK:
		if _find_link(b_slot, _link_tile[link]) != NO_LINK:
			return true
		link = _link_zone_next[link]
	return false


# --- GDD §5.1 basin references ------------------------------------------------------------------------

func set_basin(ref: Vector2i, basin_ref: Vector2i) -> OpResult:
	"""Point a zone at the basin zone whose forage stock it draws from (GDD §5.1).

	This is the anti-multiplication gate. Refuses a zone that already owns patches (its stock
	would be stranded), a basin that is itself bound elsewhere (a chain would give two answers
	for one zone), and a basin of a different ZoneType.
	"""
	if not zone_slot_of_into(ref, _math) or not zone_slot_of_into(basin_ref, _math_b):
		return _refuse(REFUSE_ZONE_NOT_PRESENT)
	var slot: int = _math.value
	var basin_slot: int = _math_b.value
	if _zone_patch_count[slot] > 0:
		return _refuse(REFUSE_BASIN_HAS_OWN_PATCHES)
	if _zone_type[slot] != _zone_type[basin_slot]:
		return _refuse(REFUSE_ZONE_TYPE_MISMATCH)
	if basin_slot != slot and _zone_basin_slot[basin_slot] != basin_ref.x:
		return _refuse(REFUSE_BASIN_CHAIN)
	_zone_basin_slot[slot] = basin_ref.x
	_zone_basin_generation[slot] = basin_ref.y
	return _succeed(basin_slot, basin_ref)


func basin_ref_of(slot: int) -> Vector2i:
	"""The basin reference a live zone draws from, or the §4.1 null reference `(-1, 0)`."""
	if not is_zone_present(slot):
		return NULL_REF
	return Vector2i(_zone_basin_slot[slot], _zone_basin_generation[slot])


func basin_slot_of(ref: Vector2i) -> IntMath.IntResult:
	"""The zone row holding the forage stock this zone harvests, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	basin_slot_of_into(ref, out)
	return out


func basin_slot_of_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating basin_slot_of(): resolve zone -> basin row into caller-owned `out`.

	The basin reference is validated on the way through, so a basin destroyed under a live zone
	refuses here instead of resolving to whatever row later reused its slot.
	"""
	if not zone_slot_of_into(ref, out):
		return false
	var slot: int = out.value
	var basin: Vector2i = Vector2i(_zone_basin_slot[slot], _zone_basin_generation[slot])
	return zone_slot_of_into(basin, out)


func zones_share_basin(a_ref: Vector2i, b_ref: Vector2i) -> bool:
	"""True when two live zones resolve to the same basin row, and so to the same forage stock."""
	if not basin_slot_of_into(a_ref, _math):
		return false
	var a_basin: int = _math.value
	if not basin_slot_of_into(b_ref, _math_b):
		return false
	return a_basin == _math_b.value


# --- ForagePatch lifecycle ----------------------------------------------------------------------------

func create_patch(ref: Vector2i, kind: int, item_id: int) -> OpResult:
	"""Create one of a forage basin's five §5.5 patches, full to GDD §5.1's 80% of capacity.

	Returns the patch row. Capacity and kind come from §5.5's table, never from the caller.
	Refuses a non-FORAGE zone, a zone bound to another basin, a kind outside 0..4, a negative
	item id, and a second patch of the same kind.
	"""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	var code: StringName = _refuse_create_patch(slot, kind, item_id)
	if code != REFUSE_NONE:
		return _refuse(code)
	var row: int = slot * PATCHES_PER_ZONE + kind
	var capacity: int = PATCH_CAPACITY_U[kind] * MILLI_PER_UNIT
	_patch_present[row] = 1
	_patch_item_id[row] = item_id
	_patch_zone_slot[row] = ref.x
	_patch_zone_generation[row] = ref.y
	_patch_capacity_milli[row] = capacity
	_patch_stock_milli[row] = capacity * INITIAL_STOCK_NUMERATOR / INITIAL_STOCK_DENOMINATOR
	_patch_harvested_year_milli[row] = 0
	_zone_patch_count[slot] += 1
	return _succeed(row, ref)


func _refuse_create_patch(zone_slot: int, kind: int, item_id: int) -> StringName:
	"""The code blocking a patch creation, or REFUSE_NONE when the basin can hold it."""
	if _zone_type[zone_slot] != ZONE_TYPE_FORAGE:
		return REFUSE_ZONE_TYPE_MISMATCH
	if _zone_basin_slot[zone_slot] != _zone_ref_slot[zone_slot]:
		return REFUSE_ZONE_IS_BOUND
	if not is_patch_kind(kind):
		return REFUSE_INVALID_PATCH_KIND
	if item_id < 0 or not IntMath.fits_int32(item_id):
		return REFUSE_INVALID_ITEM_ID
	if _patch_present[zone_slot * PATCHES_PER_ZONE + kind] == 1:
		return REFUSE_PATCH_PRESENT
	return REFUSE_NONE


func create_patch_set(ref: Vector2i, item_ids: PackedInt32Array) -> OpResult:
	"""Create all five §5.5 patches of a forage basin at once, in PATCH_KEYS order.

	All or nothing: every kind is validated before the first is written, so a refusal leaves the
	basin with the patches it already had. Returns the number of patches created.
	"""
	if item_ids.size() != PATCHES_PER_ZONE:
		return _refuse(REFUSE_PATCH_SET_SIZE)
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	for kind: int in PATCHES_PER_ZONE:
		var code: StringName = _refuse_create_patch(slot, kind, item_ids[kind])
		if code != REFUSE_NONE:
			return _refuse(code)
	for kind: int in PATCHES_PER_ZONE:
		var created: OpResult = create_patch(ref, kind, item_ids[kind])
		if not created.ok:
			return created
	return _succeed(PATCHES_PER_ZONE, ref)


func is_patch_kind(kind: int) -> bool:
	"""True when `kind` names one of §5.5's five forage rows."""
	return kind >= 0 and kind < PATCHES_PER_ZONE


func is_patch_present(row: int) -> bool:
	"""True when `row` is in range and holds a live forage patch."""
	return row >= 0 and row < FORAGE_PATCH_CAPACITY and _patch_present[row] == 1


func patch_count_of(slot: int) -> IntMath.IntResult:
	"""How many of a live zone's five patch rows exist, or an explicit refusal."""
	return _read_zone(slot, _zone_patch_count)


func patch_row_for_zone(ref: Vector2i, kind: int) -> IntMath.IntResult:
	"""The patch row a zone harvests for one kind, resolved through its basin (GDD §5.1)."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	patch_row_for_zone_into(ref, kind, out)
	return out


func patch_row_for_zone_into(ref: Vector2i, kind: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating patch_row_for_zone(): write `basin_slot*5 + kind` into caller-owned `out`.

	Two zones sharing a basin resolve to the SAME row here, which is the whole mechanism behind
	§5.1's "all intersecting zones share its quotas and do not multiply capacity".
	"""
	if not is_patch_kind(kind):
		return out.refuse(String(REFUSE_INVALID_PATCH_KIND))
	if not basin_slot_of_into(ref, out):
		return false
	var row: int = out.value * PATCHES_PER_ZONE + kind
	if _patch_present[row] != 1:
		return out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
	return out.succeed(row)


func patch_item_id_of(row: int) -> IntMath.IntResult:
	"""The patch's `item_id`, or an explicit refusal. See the header on its unstated domain."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_patch_present(row):
		out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
		return out
	out.succeed(_patch_item_id[row])
	return out


func patch_zone_ref_of(row: int) -> Vector2i:
	"""The basin zone a live patch belongs to, or the §4.1 null reference `(-1, 0)`."""
	if not is_patch_present(row):
		return NULL_REF
	return Vector2i(_patch_zone_slot[row], _patch_zone_generation[row])


func patch_kind_of_row(row: int) -> IntMath.IntResult:
	"""Which of §5.5's five rows a patch row is, from the owner-major index."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_patch_present(row):
		out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
		return out
	out.succeed(row % PATCHES_PER_ZONE)
	return out


func stock_milli_of(row: int) -> IntMath.IntResult:
	"""The patch's remaining stock in milli-units, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	stock_milli_into(row, out)
	return out


func stock_milli_into(row: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating stock_milli_of(): write the stock into caller-owned `out`."""
	if not is_patch_present(row):
		return out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
	return out.succeed(_patch_stock_milli[row])


func patch_capacity_milli_of(row: int) -> IntMath.IntResult:
	"""The patch's §5.5 capacity in milli-units, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_patch_present(row):
		out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
		return out
	out.succeed(_patch_capacity_milli[row])
	return out


func harvested_year_milli_of(row: int) -> IntMath.IntResult:
	"""The patch's year-to-date harvested total, the accumulator the quota is measured against."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_patch_present(row):
		out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
		return out
	out.succeed(_patch_harvested_year_milli[row])
	return out


func reset_harvested_year() -> void:
	"""Zero every patch's year-to-date total. The caller owns the year boundary (48 days, §5.1)."""
	_patch_harvested_year_milli.fill(0)


# --- §5.5 seasonal availability ------------------------------------------------------------------------

func is_season(season: int) -> bool:
	"""True when `season` is one of §4.3's four Season values."""
	return season >= 0 and season < SEASON_COUNT


func availability_per_1000(kind: int, season: int) -> IntMath.IntResult:
	"""§5.5's seasonal availability multiplier for one forage kind, per 1000."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	availability_per_1000_into(kind, season, out)
	return out


func availability_per_1000_into(kind: int, season: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating availability_per_1000(): write the multiplier into caller-owned `out`."""
	if not is_patch_kind(kind):
		return out.refuse(String(REFUSE_INVALID_PATCH_KIND))
	if not is_season(season):
		return out.refuse(String(REFUSE_INVALID_SEASON))
	return out.succeed(PATCH_AVAILABILITY_PER_1000[kind * SEASON_COUNT + season])


func is_dormant(kind: int, season: int) -> bool:
	"""True when §5.5 makes this kind unavailable this season: "dormant, not destroyed".

	A dormant patch keeps its stock and its capacity; it neither regrows nor yields a harvest.
	An out-of-range kind or season is reported as NOT dormant, because it names no patch at all;
	availability_per_1000() is the form that refuses those with a reason.
	"""
	if not availability_per_1000_into(kind, season, _math_b):
		return false
	return _math_b.value == 0


# --- §5.5 regrowth ---------------------------------------------------------------------------------------

func daily_regrowth_milli(row: int, season: int) -> IntMath.IntResult:
	"""§5.5's daily regrowth for one patch, already clamped to the room left below capacity."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	daily_regrowth_milli_into(row, season, out)
	return out


func daily_regrowth_milli_into(row: int, season: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating daily_regrowth_milli(): `floor((K-P)*r*season/1000000)`, min 1 U, into `out`.

	The "+1 U when season>0 and P<K" floor and the clamp to K-P are both applied here; the clamp
	is this store's reading of a formula the document leaves uncapped (see the header).
	"""
	if not is_patch_present(row):
		return out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
	var kind: int = row % PATCHES_PER_ZONE
	if not availability_per_1000_into(kind, season, out):
		return false
	var availability: int = out.value
	var room: int = _patch_capacity_milli[row] - _patch_stock_milli[row]
	if availability == 0 or room <= 0:
		return out.succeed(0)
	if not IntMath.checked_mul_into(room, PATCH_REGROWTH_PER_1000[kind], out):
		return out.refuse(String(REFUSE_OVERFLOW))
	if not IntMath.checked_mul_into(out.value, availability, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	if not IntMath.floor_div_into(out.value, REGROWTH_DENOMINATOR, out):
		return false
	var grown: int = maxi(out.value, REGROWTH_MINIMUM_MILLI)
	return out.succeed(mini(grown, room))


func regrow_patch(row: int, season: int) -> OpResult:
	"""Apply one day of §5.5 regrowth to a patch. Returns the stock after growing.

	A dormant patch grows nothing (§5.5 conditions the minimum on season>0) and is not an error:
	"unavailable patches become dormant, not destroyed".
	"""
	if not daily_regrowth_milli_into(row, season, _math):
		return _refuse(StringName(_math.error))
	_patch_stock_milli[row] += _math.value
	return _succeed(_patch_stock_milli[row], patch_zone_ref_of(row))


func regrow_daily(season: int) -> OpResult:
	"""Apply one day of regrowth to every live patch. Returns how many patches grew.

	Iterates the ascending live-zone list, so the order is the slot order and not a hash order.
	ARCH-SYS-005 owns the midnight call; this is the sweep it needs, and nothing else here reads
	a clock.
	"""
	if not is_season(season):
		return _refuse(REFUSE_INVALID_SEASON)
	var grown: int = 0
	for index: int in _live_zone_count:
		var base: int = _live_zone_slots[index] * PATCHES_PER_ZONE
		for kind: int in PATCHES_PER_ZONE:
			var row: int = base + kind
			if _patch_present[row] != 1:
				continue
			if not daily_regrowth_milli_into(row, season, _math):
				return _refuse(StringName(_math.error))
			if _math.value > 0:
				_patch_stock_milli[row] += _math.value
				grown += 1
	return _succeed(grown, NULL_REF)


# --- §5.5 protection floors and quotas -------------------------------------------------------------------

func harvest_floor_milli(row: int, intensive: bool) -> IntMath.IntResult:
	"""§5.5's protection floor for a patch: 20% of K, or 5% of K under intensive harvest."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	harvest_floor_milli_into(row, intensive, out)
	return out


func harvest_floor_milli_into(row: int, intensive: bool, out: IntMath.IntResult) -> bool:
	"""Non-allocating harvest_floor_milli(): write the floor into caller-owned `out`."""
	if not is_patch_present(row):
		return out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
	var percent: int = INTENSIVE_FLOOR_PERCENT if intensive else SUSTAINABLE_FLOOR_PERCENT
	if not IntMath.checked_mul_into(_patch_capacity_milli[row], percent, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return IntMath.floor_div_into(out.value, PERCENT_DENOMINATOR, out)


func effective_quota_milli(ref: Vector2i) -> IntMath.IntResult:
	"""The quota binding a harvest through this zone: `min(basin quota, this zone's quota)`.

	§5.1 gives the quota to the basin and §4.2 gives every zone one of its own; the stricter of
	the two applies, so a second designation over the same basin can never raise the ceiling.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	effective_quota_milli_into(ref, out)
	return out


func effective_quota_milli_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating effective_quota_milli(): write the binding quota into caller-owned `out`."""
	if not zone_slot_of_into(ref, out):
		return false
	var own_quota: int = _zone_quota_milli[out.value]
	if not basin_slot_of_into(ref, out):
		return false
	return out.succeed(mini(own_quota, _zone_quota_milli[out.value]))


func remaining_quota_milli(ref: Vector2i, kind: int) -> IntMath.IntResult:
	"""How much of the shared quota is left for one kind this year, never below 0.

	REQ-SET-069's stop condition. The accumulator is the BASIN's harvested_year_milli, so a
	second zone over the same basin inherits the total the first one already took.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	remaining_quota_milli_into(ref, kind, out)
	return out


func remaining_quota_milli_into(ref: Vector2i, kind: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating remaining_quota_milli(): write the remaining quota into caller-owned `out`."""
	if not patch_row_for_zone_into(ref, kind, out):
		return false
	var taken: int = _patch_harvested_year_milli[out.value]
	if not effective_quota_milli_into(ref, out):
		return false
	return out.succeed(maxi(out.value - taken, 0))


func is_quota_reached(ref: Vector2i, kind: int) -> bool:
	"""True when REQ-SET-069's quota condition holds and no new reservation may be made."""
	if not remaining_quota_milli_into(ref, kind, _math_b):
		return true
	return _math_b.value <= 0


func harvestable_milli(ref: Vector2i, kind: int, season: int, intensive: bool)\
		-> IntMath.IntResult:
	"""The largest harvest this zone could take right now: stock above the floor, capped by quota.

	0 is a truthful answer here, not a sentinel: a dormant, floored or quota-stopped patch really
	does offer nothing. harvest() is the form that refuses with the reason.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not patch_row_for_zone_into(ref, kind, out):
		return out
	var row: int = out.value
	if not availability_per_1000_into(kind, season, out):
		return out
	if out.value == 0:
		out.succeed(0)
		return out
	if not harvest_floor_milli_into(row, intensive, out):
		return out
	var above_floor: int = maxi(_patch_stock_milli[row] - out.value, 0)
	if not remaining_quota_milli_into(ref, kind, out):
		return out
	out.succeed(mini(above_floor, out.value))
	return out


# --- harvest -----------------------------------------------------------------------------------------------

func harvest(ref: Vector2i, kind: int, amount_milli: int, season: int, intensive: bool)\
		-> OpResult:
	"""Take `amount_milli` of one forage kind through a zone. Returns the stock left after it.

	Refuses rather than clamping when the patch cannot give up exactly that much: a silent short
	delivery would let a job book more cargo than the basin released. The debit lands on the
	BASIN's row, so overlapping zones draw down one shared stock and one shared year total.
	"""
	if not patch_row_for_zone_into(ref, kind, _math):
		return _refuse(StringName(_math.error))
	var row: int = _math.value
	if not harvest_into(ref, kind, amount_milli, season, intensive, _math):
		return _refuse(StringName(_math.error))
	return _succeed(_math.value, patch_zone_ref_of(row))


func harvest_into(ref: Vector2i, kind: int, amount_milli: int, season: int, intensive: bool,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating harvest(): write the stock remaining after the debit into caller-owned `out`.

	`out` doubles as this call's scratch, so it must not be a result the caller still needs. A
	refusal debits nothing: neither the shared stock nor the shared year total is touched.
	"""
	if not patch_row_for_zone_into(ref, kind, out):
		return false
	var row: int = out.value
	var code: StringName = _check_harvest(ref, row, kind, amount_milli, season, intensive)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	_patch_stock_milli[row] -= amount_milli
	_patch_harvested_year_milli[row] += amount_milli
	return out.succeed(_patch_stock_milli[row])


func _check_harvest(ref: Vector2i, row: int, kind: int, amount_milli: int, season: int,
		intensive: bool) -> StringName:
	"""REFUSE_NONE when this zone may take exactly `amount_milli` from `row` this season."""
	var zone_code: StringName = _check_harvest_zone(ref)
	if zone_code != REFUSE_NONE:
		return zone_code
	if not availability_per_1000_into(kind, season, _math):
		return StringName(_math.error)
	if _math.value == 0:
		return REFUSE_PATCH_DORMANT
	if amount_milli <= 0:
		return REFUSE_INVALID_AMOUNT
	if not harvest_floor_milli_into(row, intensive, _math):
		return StringName(_math.error)
	if _patch_stock_milli[row] - amount_milli < _math.value:
		return REFUSE_BELOW_HARVEST_FLOOR
	if not remaining_quota_milli_into(ref, kind, _math):
		return StringName(_math.error)
	if amount_milli > _math.value:
		return REFUSE_QUOTA_REACHED
	return REFUSE_NONE


func _check_harvest_zone(ref: Vector2i) -> StringName:
	"""REFUSE_NONE when the designation itself permits an automatic harvest.

	§5.5: "Protected tiles are never automatically harvested." This store owns no manual harvest
	path -- none is specified -- so a protected zone refuses outright.
	"""
	if not zone_slot_of_into(ref, _math_b):
		return StringName(_math_b.error)
	var slot: int = _math_b.value
	if _zone_type[slot] != ZONE_TYPE_FORAGE:
		return REFUSE_ZONE_TYPE_MISMATCH
	if _zone_enabled[slot] != 1:
		return REFUSE_ZONE_DISABLED
	if _zone_protected[slot] == 1:
		return REFUSE_ZONE_PROTECTED
	return REFUSE_NONE


# --- §5.5 work, REQ-SET-067 consent, REQ-SET-068 injury ------------------------------------------------------

func natural_danger_of(ref: Vector2i) -> IntMath.IntResult:
	"""§5.5's natural danger: the BASIN's band, "fixed at generation", before lookout reductions."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	natural_danger_of_into(ref, out)
	return out


func natural_danger_of_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating natural_danger_of(): write the basin's danger band into caller-owned `out`."""
	if not basin_slot_of_into(ref, out):
		return false
	return out.succeed(_zone_danger[out.value])


func work_per_u(kind: int, forage_level: int, natural_danger: int) -> IntMath.IntResult:
	"""§5.5: `ceil(base_work*1000000/((1000+40*FORAGE_level)*(1000+100*natural_danger)))` WU/U."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	work_per_u_into(kind, forage_level, natural_danger, out)
	return out


func work_per_u_into(kind: int, forage_level: int, natural_danger: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating work_per_u(): write the whole-WU cost of one unit into caller-owned `out`."""
	if not is_patch_kind(kind):
		return out.refuse(String(REFUSE_INVALID_PATCH_KIND))
	if forage_level < 0 or not IntMath.fits_int32(forage_level):
		return out.refuse(String(REFUSE_INVALID_SKILL_LEVEL))
	if natural_danger < DANGER_MIN or natural_danger > DANGER_MAX:
		return out.refuse(String(REFUSE_INVALID_DANGER))
	var skill_term: int = WORK_BASE_TERM + WORK_SKILL_TERM * forage_level
	var danger_term: int = WORK_BASE_TERM + WORK_DANGER_TERM * natural_danger
	if not IntMath.checked_mul_into(PATCH_BASE_WORK_WU[kind], WORK_NUMERATOR_SCALE, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	var numerator: int = out.value
	if not IntMath.checked_mul_into(skill_term, danger_term, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return IntMath.ceil_div_into(numerator, out.value, out)


func requires_dangerous_work(ref: Vector2i) -> bool:
	"""REQ-SET-067: true while this zone's own danger band is 2 or 3."""
	if not zone_slot_of_into(ref, _math_b):
		return false
	return _zone_danger[_math_b.value] >= DANGEROUS_WORK_DANGER


func check_worker_permitted(ref: Vector2i, dangerous_work_consent: bool) -> OpResult:
	"""REQ-SET-067's consent half: refuse a danger 2/3 zone without the resident's permission.

	The requirement's "show an exposure warning" is the Notice store's half and is not done here.
	Returns the zone's danger band on success.
	"""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var danger: int = _zone_danger[_math.value]
	if danger >= DANGEROUS_WORK_DANGER and not dangerous_work_consent:
		return _refuse(REFUSE_DANGEROUS_WORK_REFUSED)
	return _succeed(danger, ref)


func injury_chance_per_10000(natural_danger: int, forage_level: int) -> IntMath.IntResult:
	"""REQ-SET-068's `max(1, 8*danger - FORAGE_level)` per 10000."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	injury_chance_per_10000_into(natural_danger, forage_level, out)
	return out


func injury_chance_per_10000_into(natural_danger: int, forage_level: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating injury_chance_per_10000(): write the per-10000 chance into `out`."""
	if natural_danger < DANGER_MIN or natural_danger > DANGER_MAX:
		return out.refuse(String(REFUSE_INVALID_DANGER))
	if forage_level < 0 or not IntMath.fits_int32(forage_level):
		return out.refuse(String(REFUSE_INVALID_SKILL_LEVEL))
	var chance: int = INJURY_DANGER_FACTOR * natural_danger - forage_level
	return out.succeed(maxi(INJURY_CHANCE_MINIMUM, chance))


func completed_exposure_segments(before_wu: int, after_wu: int) -> IntMath.IntResult:
	"""How many whole 60 WU exposure segments a worker crossed between two work totals.

	ARCH-RNG-002 orders the FORAGE stream by "Worker ID, segment sequence", so the accumulated
	work total belongs to the worker and is passed in; this store keeps no per-worker column,
	because GDD §4.2 gives exposure work no field on any row.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	completed_exposure_segments_into(before_wu, after_wu, out)
	return out


func completed_exposure_segments_into(before_wu: int, after_wu: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating completed_exposure_segments(): write the segment count into `out`."""
	if before_wu < 0 or after_wu < before_wu:
		return out.refuse(String(REFUSE_INVALID_WORK))
	if not IntMath.fits_int32(after_wu):
		return out.refuse(String(REFUSE_INVALID_WORK))
	return out.succeed(after_wu / EXPOSURE_SEGMENT_WU - before_wu / EXPOSURE_SEGMENT_WU)


func roll_injury_into(rng: Rng, natural_danger: int, forage_level: int,
		out: IntMath.IntResult) -> bool:
	"""One FORAGE hazard roll: exactly one draw, 1 when it injures and 0 when it does not.

	REQ-SET-068 states the chance "per 10000", so a draw in [0, 10000) injures when it is
	strictly below the chance -- exactly `chance` of the 10000 outcomes. Refuses at natural
	danger 0 without drawing, because ARCH-RNG-002 rolls only "in natural danger>=1" and a
	consumed draw there would desynchronise every later replay.
	"""
	if rng == null:
		return out.refuse(String(REFUSE_NO_RNG))
	if natural_danger < INJURY_ROLL_MIN_DANGER:
		return out.refuse(String(REFUSE_INVALID_DANGER))
	if not injury_chance_per_10000_into(natural_danger, forage_level, out):
		return false
	var chance: int = out.value
	if not rng.draw_below_into(Rng.STREAM_FORAGE, INJURY_ROLL_DENOMINATOR, out):
		return false
	return out.succeed(1 if out.value < chance else 0)


func roll_exposure_injuries(rng: Rng, ref: Vector2i, forage_level: int, before_wu: int,
		after_wu: int) -> OpResult:
	"""ARCH-RNG-002's FORAGE discipline for one worker's run of work. Returns injuries rolled.

	Exactly one draw per completed 60 WU segment, in segment order, and NO draws at all when the
	basin's natural danger is 0. Applying REQ-SET-068's "10 health loss and severity 1 injury" is
	the injury store's job; INJURY_HEALTH_LOSS and INJURY_SEVERITY carry the numbers.
	"""
	if not natural_danger_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var danger: int = _math.value
	if not completed_exposure_segments_into(before_wu, after_wu, _math):
		return _refuse(StringName(_math.error))
	var segments: int = _math.value
	if danger < INJURY_ROLL_MIN_DANGER:
		return _succeed(0, ref)
	var injuries: int = 0
	for _segment: int in segments:
		if not roll_injury_into(rng, danger, forage_level, _math):
			return _refuse(StringName(_math.error))
		injuries += _math.value
	return _succeed(injuries, ref)


# --- result helpers -----------------------------------------------------------------------------------------

func _succeed(value: int, ref: Vector2i) -> OpResult:
	"""Build a successful OpResult carrying a value and a reference."""
	return OpResult.new(true, REFUSE_NONE, value, ref)


func _refuse(code: StringName) -> OpResult:
	"""Build a refused OpResult. The value and reference are always empty on a refusal.

	This is not a sentinel scheme: the code travels on its own channel and a refusal never
	carries a usable number, so an ignored refusal cannot surface a plausible answer.
	"""
	return OpResult.new(false, code, 0, NULL_REF)
