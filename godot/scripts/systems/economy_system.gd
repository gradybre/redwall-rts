extends Node
## The settlement's authoritative stores: integer item lots inside mass-bounded containers.
##
## ARCH-MIG-006 step 5. This replaces the prototype's float stockpile model, whose three
## divergences are recorded in `docs/decisions/0006-prototype-diverges-from-gdd.md`:
##   * Quantities are `quantity_milli:int64` in `scripts/core/inventory.gd`, never floats, so
##     the SPEND_TOLERANCE workaround and the epsilon dead band have no analogue (BAL-NUM-001).
##   * Items are the 60 authoritative catalog rows loaded through
##     `scripts/core/item_definitions.gd`, not four invented keys. Food is NOT one of them:
##     GDD §5.8 derives food-days from nutrition points across lots, so this system publishes
##     ready nutrition points and never stores a "food" resource.
##   * Capacity is container mass in grams with a per-lot `ceil_div` debit, not a flat cap of
##     500. Exceeding it is REFUSED with a diagnostic (REQ-SET-110/120); the prototype silently
##     clamped, which destroyed goods.
##
## The prototype's per-second production rates and its `MAX_TICKS_PER_FRAME` catch-up are gone
## rather than ported. Both modelled work that does not exist yet: production comes from jobs
## and recipes, which are not in this milestone, and inventing rates here would fabricate a
## survival trajectory. There is deliberately no tick: nothing in an implemented specification
## changes stock on its own. Spoilage/aging (GDD §5.8) needs store and temperature factors that
## no implemented system supplies, so lot ages stay at 0 and no lot expires.
##
## REQ-SET-119 asks for a recompute "every game hour and on committed stock/policy changes".
## Only the second half is implemented: the summary is recomputed synchronously at the end of
## every committed operation. The hourly recompute has nothing to change while nothing ages.
##
## Blocked by U4 (docs/tasks/02_settlement_foundation.md): reservations are honoured when
## computing available quantity, but nothing here allocates them.
##
## FOOD-DAYS (task 2.10). `ready_nutrition_points()` was always the GDD §5.8 NUMERATOR; the
## denominator now exists. Binding a `residents.gd` store supplies daily demand from each living
## resident's size and today's season multiplier, so `food_days_centi()` completes the figure
##     food_days = floor(100 * ready_unreserved_NP / daily_demand_NP) / 100
## exactly as §5.8 writes it, in integers, displayed to two decimals.
##
## FUEL-DAYS REMAINS UNPOPULATED, and is deliberately not approximated here. §5.8 defines it as
## `available_wood_equivalent / daily_heating_demand`, and the denominator needs the count of
## active hearths, the interior tiles each covers, and the daily mean temperature that decides
## whether a hearth burns 4, 2 or 0 wood per day. Building, Room and Weather stores do not exist
## in this milestone, so the heating demand has no input at all. Wood stock alone is a numerator
## with nothing to divide by.
##
## THE STORES ARE OWNED AND PLACED (DEMO-CONTAIN-R01 step D3, decision 0533). Answer #7 retired
## the two ownerless containers this system used to open in `reset()`. Nothing is opened until
## `open_starter_stores()` is handed a `StarterColony.StoreBinding` read back from a live
## settlement's buildings: the pantry is then owned by the GDD §5.9 hall and anchored at the
## hall's origin tile, and the material store is FOUR containers of 400000 g, each owned by one
## open stockpile and anchored at its origin tile (#3a; decision 0531's anchor column). Pantry
## shelves are NOT containers (#3b): the hall-owned pantry holds the four shelves' 200000 g.
## `inventory.gd` now refuses an ownerless container outright, so there is no fallback store.
##
## §5.9's FILL ORDER IS NOW OBSERVABLE, so it is implemented rather than argued away: "all initial
## items are assigned to legal containers by food first, then item ID, filling container IDs
## ascending". A deposit fills its legal containers in ascending container order, splitting a
## lot at the largest quantity whose per-lot ceiling charge still fits, and
## `seed_initial_inventory()` deposits §5.1's list food first and then by compiled item id.
##
## THE STORES LIVE IN THE SETTLEMENT'S `inventory.gd` (decision 0534, closing decision 0087's
## two-inventory split). `bind_inventory()` ADOPTS a borrowed store -- the settlement's -- before
## the stores open, so the demolition gate, section 7 and the ground-pile composer see the very
## lots this system deposits, and one inventory transaction can cover a demolition. The private
## store remains the default, so a test-built instance touches no autoload state. `reset()` DROPS
## a borrowed store rather than clearing it: the settlement owns those rows and clears them itself.
## A store is adopted only when its item registry agrees, id for id, with this system's catalog.

const InventoryScript := preload("res://scripts/core/inventory.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const StarterColonyScript := preload("res://scripts/core/starter_colony.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const PerfTimerScript := preload("res://scripts/utils/perf_timer.gd")

## GDD §5.9 starter fixture: "Four pantry shelves supply 200000g storage" and "Four stockpiles
## provide 1600000g material storage; starting food fits the pantry." The material store is four
## containers of BAL-CAT-006's 400000 g `base_store_g`, one per open stockpile.
const PANTRY_MAX_MASS_G: int = 200000
const STOCKPILE_COUNT: int = StarterColonyScript.STOCKPILE_COUNT
const STOCKPILE_MAX_MASS_G: int = 400000
const MATERIAL_STORE_MAX_MASS_G: int = STOCKPILE_MAX_MASS_G * STOCKPILE_COUNT

## Store index 0 is the pantry; 1..STOCKPILE_COUNT are the stockpiles in plan order, which is the
## order they are created in and therefore ascending container order.
const PANTRY_STORE: int = 0
const FIRST_STOCKPILE_STORE: int = 1
const STORE_COUNT: int = FIRST_STOCKPILE_STORE + STOCKPILE_COUNT

## GDD §5.1 initial inventory, in whole catalog units, copied verbatim from the specification line
## "Initial inventory U: wood 180, stone 100, ...". Moved here from `main.gd` so boot and Create
## seed one list; `seed_initial_inventory()` deposits it in §5.9's fill order, not in this order.
const INITIAL_INVENTORY_U: Dictionary = {
	&"wood": 180, &"stone": 100, &"iron": 20, &"rope": 20, &"tool": 24, &"cloth": 24,
	&"water": 60, &"grain": 80, &"roots": 80, &"berries": 40, &"nuts": 40, &"dried_fish": 60,
	&"ration": 60, &"seed_grain": 32, &"seed_roots": 32, &"seed_beans": 16,
	&"seed_cabbage": 16, &"seed_flax": 16, &"herb": 12, &"compost": 32,
}

## Category routing. Food, drink and seed stock go to the pantry; everything else to the
## material store. The filters are installed on the containers themselves, so the routing is
## enforced by the inventory and a misrouted lot is refused rather than silently accepted.
const PANTRY_CATEGORIES: Array[StringName] = [
	&"RAW_FOOD", &"RAW_FISH", &"PREPARED", &"PRESERVED", &"SEED", &"LIQUID", &"FEAST",
]
const MATERIAL_CATEGORIES: Array[StringName] = [&"MATERIAL", &"GEAR", &"SAPLING", &"WASTE"]

## Attribute defaults for a lot introduced by a bare deposit. The quality model (GDD §5.7) and
## the provenance/recipe catalogs are not implemented in this milestone, so these are the
## inventory's own unset values rather than invented catalog numbers.
const UNSET_QUALITY: int = 0
const UNSET_PROVENANCE: int = 0
const NO_RECIPE: int = 0
const FRESH_AGE_MILLI_HOURS: int = 0
const FRESH_AGE_REMAINDER: int = 0

const REFUSE_NONE: StringName = &""
const REFUSE_CATALOG_UNAVAILABLE: StringName = &"CATALOG_UNAVAILABLE"
const REFUSE_NO_ELIGIBLE_STORE: StringName = &"NO_ELIGIBLE_STORE"
const REFUSE_NO_RESIDENT_STORE: StringName = &"NO_RESIDENT_STORE"
const REFUSE_STORES_NOT_OPEN: StringName = &"STORES_NOT_OPEN"
const REFUSE_STORES_ALREADY_OPEN: StringName = &"STORES_ALREADY_OPEN"
const REFUSE_INVALID_STORE_BINDING: StringName = &"INVALID_STORE_BINDING"
const REFUSE_INVALID_INVENTORY: StringName = &"INVALID_INVENTORY_BINDING"
const REFUSE_INVENTORY_CATALOG_MISMATCH: StringName = &"INVENTORY_CATALOG_MISMATCH"

## GDD §5.8 displays food-days to two decimals, so the integer figure is carried in hundredths.
const FOOD_DAYS_SCALE: int = 100

## Rendered in place of a counter with no computable value. Matches hud.gd's UNPOPULATED marker
## so an unpopulated figure never reaches the screen as a zero or an invented number.
const UNPOPULATED_TEXT: String = "--"

## What is missing before fuel-days can be computed, named rather than approximated.
const FUEL_DAYS_MISSING_INPUT: String = (
	"daily heating demand: no hearth, interior-tile or daily-mean-temperature input exists")

## UI-only notifications. Game logic calls the accessors below directly instead.
signal stocks_changed()
signal stock_depleted(item_key: StringName)

## The private store, and the one in use: `_inventory` is either this or a borrowed store.
var _own_inventory: InventoryScript = InventoryScript.new()
var _inventory: InventoryScript = _own_inventory
var _borrowed: bool = false
var _definitions: ItemDefinitionsScript = ItemDefinitionsScript.new()
## The open stores as slot/generation columns, sized STORE_COUNT once; `_store_count` is 0 while
## closed and STORE_COUNT once `open_starter_stores()` has succeeded.
var _store_slot: PackedInt32Array = PackedInt32Array()
var _store_generation: PackedInt32Array = PackedInt32Array()
var _store_count: int = 0
var _pantry_filters: int = 0
var _material_filters: int = 0
var _ready_nutrition_points: int = 0
var _residents: ResidentsScript = null
var _food_days_timer: PerfTimerScript = PerfTimerScript.new()
var _catalog_error: String = ""
var _last_refusal: StringName = REFUSE_NONE
var _timer: PerfTimerScript = PerfTimerScript.new()


func _init() -> void:
	"""Size the store columns and load the catalog; the stores stay closed until bound."""
	_store_slot.resize(STORE_COUNT)
	_store_generation.resize(STORE_COUNT)
	reset()


func _ready() -> void:
	"""Report readiness, or the catalog failure that left the stores closed."""
	if _catalog_error != "":
		push_error("EconomySystem: catalog unavailable: %s" % _catalog_error)
	print("[EconomySystem] ready")


func reset(catalog_path: String = ItemDefinitionsScript.DEFAULT_JSON_PATH) -> void:
	"""Empty every store, reload the catalog, and leave the stores CLOSED until rebound.

	The residents binding is dropped too. It is a borrowed store belonging to the scene that
	supplied it, and a reset that kept it would divide the reloaded (empty) stores by the
	previous run's population and put a stale food-days figure on screen.

	`catalog_path` exists so a test can open the stores against a fixture catalog; production
	callers pass nothing and get the authoritative res://data/item_definitions.json.

	THE STORES ARE NOT REOPENED. Their owners are the previous settlement's buildings, so a reset
	that reopened them would mint containers for rows that may no longer exist; the next
	`open_starter_stores()` binds them to whichever settlement the caller composes next.

	A BORROWED STORE IS DROPPED, NEVER CLEARED (decision 0087): the private store is reloaded.
	"""
	_inventory = _own_inventory
	_borrowed = false
	_inventory.clear()
	_definitions = ItemDefinitionsScript.new()
	_close_stores()
	_last_refusal = REFUSE_NONE
	_residents = null
	var load_result: ItemDefinitionsScript.LoadResult = _definitions.load_from_file(
		catalog_path, _inventory)
	_catalog_error = load_result.error
	if load_result.ok:
		_compose_filters()
	_recompute_summary()


func bind_inventory(store: InventoryScript) -> bool:
	"""Adopt `store` -- the settlement's -- as the lot store, before the stores open (decision 0534).

	Refuses STORES_ALREADY_OPEN once opened (call `reset()` first), INVALID_INVENTORY_BINDING for
	null, CATALOG_UNAVAILABLE without a routable catalog, and INVENTORY_CATALOG_MISMATCH unless
	every item id registers identically -- presence, mass and category -- in both stores, so a
	compiled id here always names the same item there. Binding the private store unbinds.
	"""
	if _store_count != 0:
		return _refuse(REFUSE_STORES_ALREADY_OPEN)
	if store == null:
		return _refuse(REFUSE_INVALID_INVENTORY)
	if _catalog_error != "":
		return _refuse(REFUSE_CATALOG_UNAVAILABLE)
	if not _registry_agrees(store):
		return _refuse(REFUSE_INVENTORY_CATALOG_MISMATCH)
	_inventory = store
	_borrowed = store != _own_inventory
	_last_refusal = REFUSE_NONE
	_recompute_summary()
	return true


func _registry_agrees(store: InventoryScript) -> bool:
	"""True when every item id registers identically in `store` and in the private store."""
	for item_id: int in InventoryScript.ITEM_CAPACITY:
		var registered: bool = _own_inventory.is_item_registered(item_id)
		if store.is_item_registered(item_id) != registered:
			return false
		if registered and (store.item_mass_g(item_id) != _own_inventory.item_mass_g(item_id)
				or store.item_category(item_id) != _own_inventory.item_category(item_id)):
			return false
	return true


func is_inventory_borrowed() -> bool:
	"""True while a borrowed store -- the settlement's -- is adopted."""
	return _borrowed


func _close_stores() -> void:
	"""Forget every store ref. The rows themselves went with `inventory.clear()`."""
	_store_slot.fill(InventoryScript.NULL_SLOT)
	_store_generation.fill(InventoryScript.NULL_GENERATION)
	_store_count = 0


func _compose_filters() -> void:
	"""Compile the two category filters, or record why the catalog cannot route stock."""
	_pantry_filters = _filters_for(PANTRY_CATEGORIES)
	_material_filters = _filters_for(MATERIAL_CATEGORIES)
	if _pantry_filters == 0 or _material_filters == 0:
		_catalog_error = "category domain missing a routed category"


func _filters_for(category_names: Array[StringName]) -> int:
	"""Compose a 64-bit container filter from compiled category ids. 0 when any is unknown."""
	var mask: int = 0
	for category_name: StringName in category_names:
		var category: int = _definitions.category_compiled_id(category_name)
		if category < 0:
			return 0
		mask |= _inventory.category_mask(category)
	return mask


func open_starter_stores(binding: StarterColonyScript.StoreBinding) -> bool:
	"""Open the GDD §5.9 pantry and four stockpiles, owned and anchored as `binding` says.

	All five containers are created in ONE inventory transaction -- the pantry first, then the
	stockpiles in the binding's (plan) order -- so a refusal leaves the stores closed and the
	inventory byte-identical. Refuses CATALOG_UNAVAILABLE without a routable catalog,
	STORES_ALREADY_OPEN when bound already (call `reset()` first), and INVALID_STORE_BINDING for a
	null or incomplete binding; Inventory's own refusals pass through, NESTED_TRANSACTION among
	them when a caller holds a transaction open on `inventory()`.
	"""
	if _catalog_error != "":
		return _refuse(REFUSE_CATALOG_UNAVAILABLE)
	if _store_count != 0:
		return _refuse(REFUSE_STORES_ALREADY_OPEN)
	if binding == null or not binding.is_complete():
		return _refuse(REFUSE_INVALID_STORE_BINDING)
	var opened: InventoryScript.OpResult = _inventory.begin()
	if not opened.ok:
		return _refuse(opened.error)
	var code: StringName = _create_store(PANTRY_STORE, binding.pantry_owner, PANTRY_MAX_MASS_G,
		_pantry_filters, binding.pantry_anchor_tile)
	for index: int in STOCKPILE_COUNT:
		if code == REFUSE_NONE:
			code = _create_store(FIRST_STOCKPILE_STORE + index, binding.stockpile_owner(index),
				STOCKPILE_MAX_MASS_G, _material_filters, binding.stockpile_anchor_tile[index])
	if code != REFUSE_NONE:
		_inventory.abort()
		_close_stores()
		return _refuse(code)
	var commit: InventoryScript.OpResult = _inventory.commit()
	if not commit.ok:
		_close_stores()
		return _refuse(commit.error)
	_store_count = STORE_COUNT
	_last_refusal = REFUSE_NONE
	_recompute_summary()
	return true


func _create_store(index: int, owner_ref: Vector2i, max_mass_g: int, filters: int,
		anchor_tile: int) -> StringName:
	"""Create one owned, anchored, reachable store into column `index`; its refusal or none."""
	var made: InventoryScript.OpResult = _inventory.create_container(owner_ref, max_mass_g,
		filters, InventoryScript.UNSET_POLICY, true, anchor_tile)
	if not made.ok:
		return made.error
	_store_slot[index] = made.ref.x
	_store_generation[index] = made.ref.y
	return REFUSE_NONE


func open_and_seed_starter_stores(binding: StarterColonyScript.StoreBinding) -> bool:
	"""Boot's and Create's one entry: open the stores on `binding`, then seed §5.1's inventory.

	False, with the refusal in `last_refusal()`, when either step refuses.
	"""
	return open_starter_stores(binding) and seed_initial_inventory()


func seed_initial_inventory() -> bool:
	"""Deposit GDD §5.1's initial inventory in §5.9's order: food first, then item ID.

	Each deposit then fills its legal containers in ascending container order. Stops at the first
	refusal and returns false with that refusal in `last_refusal()`; the deposits before it stay,
	exactly as a caller depositing them one by one would see.
	"""
	var keys: Array[StringName] = []
	keys.assign(INITIAL_INVENTORY_U.keys())
	keys.sort_custom(_fills_before)
	for item_key: StringName in keys:
		if not deposit(item_key, int(INITIAL_INVENTORY_U[item_key]) * InventoryScript.MILLI_PER_UNIT):
			return false
	return true


func _fills_before(a: StringName, b: StringName) -> bool:
	"""§5.9's "food first, then item ID": pantry-routed items first, then ascending compiled id.

	"Food" is read as the pantry's routing -- food, drink and seed stock alike -- because that is
	the store §5.9 fills first. It does not make seed stock food (REQ-SET-013); nutrition never
	reads this order. Pantry and material routes are disjoint today, so this clause cannot move a
	lot yet; the item-id clause decides which stockpile each material fills.
	"""
	var a_id: int = _definitions.compiled_id(a)
	var b_id: int = _definitions.compiled_id(b)
	var a_food: bool = _routes_to_pantry(a_id)
	if a_food != _routes_to_pantry(b_id):
		return a_food
	return a_id < b_id


func _routes_to_pantry(item_id: int) -> bool:
	"""True when the item's category routes it to the pantry. Ordering only; not "is food"."""
	var category: int = _inventory.item_category(item_id) if item_id >= 0 else -1
	return category >= 0 and (_pantry_filters >> category) & 1 == 1


func deposit(item_key: StringName, quantity_milli: int) -> bool:
	"""Introduce quantity of a catalog item into its stores. All-or-nothing; false on refusal.

	GDD §5.9's fill order: the item's legal containers are filled in ascending container order,
	each taking the largest part whose per-lot ceiling charge still fits, and a part merges into
	an identical bare stack already in that container. Nothing is written unless every
	milli-unit found a place; otherwise CAPACITY_EXCEEDED, with the stores unchanged.
	"""
	var item_id: int = _resolve(item_key)
	if item_id < 0:
		return false
	if quantity_milli <= 0:
		return _refuse(InventoryScript.REFUSE_INVALID_QUANTITY)
	if _store_count == 0:
		return _refuse(REFUSE_STORES_NOT_OPEN)
	var route: Vector2i = _route_of(item_id)
	if route.x == route.y:
		return _refuse(REFUSE_NO_ELIGIBLE_STORE)
	var before: int = _inventory.total_live_milli(item_id)
	if not _commit_deposit(route, item_id, quantity_milli):
		return false
	_publish(item_key, before, _inventory.total_live_milli(item_id))
	return true


func _commit_deposit(route: Vector2i, item_id: int, quantity_milli: int) -> bool:
	"""Place the whole quantity across `route`'s stores inside ONE transaction, or none of it.

	A transaction a caller already holds on `inventory()` refuses NESTED_TRANSACTION here rather
	than being joined: this operation's own commit or abort must never close someone else's.
	"""
	var opened: InventoryScript.OpResult = _inventory.begin()
	if not opened.ok:
		return _refuse(opened.error)
	var remaining: int = quantity_milli
	var code: StringName = REFUSE_NONE
	for index: int in range(route.x, route.y):
		if remaining == 0 or code != REFUSE_NONE:
			break
		var container: Vector2i = _store(index)
		var part: int = _fitting_milli(container, item_id, remaining)
		if part > 0:
			code = _deposit_part(container, item_id, part)
			remaining -= part
	if code == REFUSE_NONE and remaining > 0:
		code = InventoryScript.REFUSE_CAPACITY_EXCEEDED
	if code != REFUSE_NONE:
		_inventory.abort()
		return _refuse(code)
	var commit: InventoryScript.OpResult = _inventory.commit()
	if not commit.ok:
		return _refuse(commit.error)
	return true


func _deposit_part(container: Vector2i, item_id: int, quantity_milli: int) -> StringName:
	"""Create one bare lot in `container` and merge it into an identical stack when one exists."""
	var target: Vector2i = _find_stack(container, item_id)
	var created: InventoryScript.OpResult = _inventory.create_lot(
		container, item_id, quantity_milli, UNSET_QUALITY, UNSET_PROVENANCE, NO_RECIPE,
		FRESH_AGE_MILLI_HOURS, FRESH_AGE_REMAINDER)
	if not created.ok:
		return created.error
	if target == InventoryScript.NULL_REF:
		return REFUSE_NONE
	return _inventory.merge_lots(target, created.ref).error


func _fitting_milli(container: Vector2i, item_id: int, remaining: int) -> int:
	"""The most of `remaining` one new lot can carry into `container`.

	A lot charges `ceil(q*m/1000)` grams, which fits `free` exactly when `q*m <= free*1000`, so
	the largest quantity is `floor(free*1000/m)` -- the same split `ground_piles.gd` uses. A merge
	never charges more than the two lots did apart, because the ceiling of a sum is at most the
	sum of the ceilings. A full or over-claimed store answers 0 or less, and the caller skips it.
	"""
	var free_g: int = _inventory.container_max_mass_g(container) \
		- _inventory.container_used_mass_g(container) \
		- _inventory.container_reserved_mass_g(container)
	var mass_g: int = _inventory.item_mass_g(item_id)
	if mass_g <= 0:
		return remaining
	@warning_ignore("integer_division")
	var fits: int = free_g * InventoryScript.MILLI_PER_UNIT / mass_g
	return mini(remaining, fits)


func withdraw(item_key: StringName, quantity_milli: int) -> bool:
	"""Consume unreserved quantity of a catalog item. All-or-nothing; false on refusal.

	Draws from the pantry first and then the stockpiles in ascending container order.
	"""
	var item_id: int = _resolve(item_key)
	if item_id < 0:
		return false
	if quantity_milli <= 0:
		return _refuse(InventoryScript.REFUSE_INVALID_QUANTITY)
	if _store_count == 0:
		return _refuse(REFUSE_STORES_NOT_OPEN)
	var before: int = _inventory.total_live_milli(item_id)
	if available_milli(item_key) < quantity_milli:
		return _refuse(InventoryScript.REFUSE_INSUFFICIENT_UNRESERVED)
	var opened: InventoryScript.OpResult = _inventory.begin()
	if not opened.ok:
		return _refuse(opened.error)
	var remaining: int = quantity_milli
	for index: int in _store_count:
		remaining = _sink_from(_store(index), item_id, remaining)
	if remaining > 0:
		_inventory.abort()
		return _refuse(InventoryScript.REFUSE_INSUFFICIENT_UNRESERVED)
	var commit: InventoryScript.OpResult = _inventory.commit()
	if not commit.ok:
		return _refuse(commit.error)
	_publish(item_key, before, _inventory.total_live_milli(item_id))
	return true


func _sink_from(container: Vector2i, item_id: int, remaining: int) -> int:
	"""Consume up to `remaining` milli of one item from a container. Returns what is still owed.

	Each lot's successor is read before the lot is drained, because emptying a lot retires its
	row and unlinks it from the container.
	"""
	var lot: Vector2i = _inventory.container_first_lot(container)
	while lot != InventoryScript.NULL_REF and remaining > 0:
		var next: Vector2i = _inventory.container_next_lot(lot)
		if _inventory.lot_item_id(lot) == item_id:
			var take: int = mini(_inventory.lot_available_milli(lot), remaining)
			if take > 0 and _inventory.sink_lot_quantity(lot, take).ok:
				remaining -= take
		lot = next
	return remaining


func stock_milli(item_key: StringName) -> int:
	"""Total live milli-units of an item across every store, reserved quantity included."""
	var item_id: int = _definitions.compiled_id(item_key)
	if item_id < 0:
		return 0
	return _inventory.total_live_milli(item_id)


func stock_units(item_key: StringName) -> int:
	"""Whole catalog units of an item in store, rounded down (BAL-NUM-001 discounts down)."""
	@warning_ignore("integer_division") return stock_milli(item_key) / InventoryScript.MILLI_PER_UNIT


func available_milli(item_key: StringName) -> int:
	"""Unreserved milli-units of an item across every store."""
	var item_id: int = _definitions.compiled_id(item_key)
	if item_id < 0:
		return 0
	var total: int = 0
	for index: int in _store_count:
		total += _available_in(_store(index), item_id)
	return total


func _available_in(container: Vector2i, item_id: int) -> int:
	"""Sum of unreserved quantity for one item in one container."""
	var total: int = 0
	var lot: Vector2i = _inventory.container_first_lot(container)
	while lot != InventoryScript.NULL_REF:
		if _inventory.lot_item_id(lot) == item_id:
			total += _inventory.lot_available_milli(lot)
		lot = _inventory.container_next_lot(lot)
	return total


func ready_nutrition_points() -> int:
	"""Nutrition points of food that is edible right now (GDD §5.8's food-days NUMERATOR).

	This is NOT food-days on its own. Bind a residents store with bind_residents() and read
	food_days_centi() for the complete §5.8 figure; without one, the divisor is refused rather
	than invented.
	"""
	return _ready_nutrition_points


func bind_residents(resident_store: ResidentsScript) -> void:
	"""Adopt the residents store that supplies GDD §5.8's daily-demand divisor.

	Binding null unbinds, which returns food-days to explicitly unpopulated. The store is read,
	never mutated: this system owns stock, not population.
	"""
	_residents = resident_store


func residents() -> ResidentsScript:
	"""The bound residents store, or null while none supplies the food-days divisor."""
	return _residents


func has_residents() -> bool:
	"""True when a residents store is bound and has not been freed out from under us."""
	return _residents != null and is_instance_valid(_residents)


func daily_demand_np() -> IntMath.IntResult:
	"""GDD §5.8's food-days DENOMINATOR: today's total daily nutrition demand across residents.

	Refuses with NO_RESIDENT_STORE when nothing supplies a population, and passes through the
	residents store's own refusal when the settlement holds no living resident.
	"""
	if not has_residents():
		var out: IntMath.IntResult = IntMath.IntResult.new()
		out.refuse(String(REFUSE_NO_RESIDENT_STORE))
		return out
	return _residents.daily_demand_np()


func food_days_centi() -> IntMath.IntResult:
	"""GDD §5.8 food-days in hundredths: floor(100 * ready_unreserved_NP / daily_demand_NP).

	The whole formula in integers, with the x100 applied BEFORE the divide so the two displayed
	decimals are exact rather than a rounded float. Refuses whenever the denominator is refused;
	it never falls back to a placeholder value.
	"""
	_food_days_timer.start()
	var out: IntMath.IntResult = IntMath.IntResult.new()
	_food_days_centi_into(out)
	_food_days_timer.stop()
	return out


func _food_days_centi_into(out: IntMath.IntResult) -> bool:
	"""Non-allocating food_days_centi(): write the hundredths into `out` and return out.ok."""
	var demand: IntMath.IntResult = daily_demand_np()
	if not demand.ok:
		return out.refuse(demand.error)
	if not IntMath.checked_mul_into(FOOD_DAYS_SCALE, _ready_nutrition_points, out):
		return false
	return IntMath.floor_div_into(out.value, demand.value, out)


func food_days_text() -> String:
	"""Food-days rendered as GDD §5.8's two-decimal display, or the unpopulated marker.

	Never returns a number the formula could not produce: a refused divisor renders as "--".
	"""
	var centi: IntMath.IntResult = food_days_centi()
	if not centi.ok:
		return UNPOPULATED_TEXT
	# UI-C3-R01 §2 requires the unit on the figure. It belongs here and not in hud.gd, which
	# renders byte for byte by contract: a renderer that appends a unit is deriving a value it
	# was given. The refused case keeps the bare marker -- "-- days" would read as a measured
	# zero rather than an absent divisor.
	@warning_ignore("integer_division") return "%d.%02d days" % [centi.value / FOOD_DAYS_SCALE, centi.value % FOOD_DAYS_SCALE]


func fuel_days_text() -> String:
	"""Fuel-days is not computable in this milestone and always renders as unpopulated.

	See fuel_days_missing_input() for the exact input that is absent. GDD §5.8's own zero-demand
	rule ("display 'No current heat demand', not infinite days") cannot even be evaluated,
	because nothing can tell heating demand zero from heating demand unknown.
	"""
	return UNPOPULATED_TEXT


func fuel_days_missing_input() -> String:
	"""The single missing input that keeps fuel-days unpopulated, named for the UI and reports."""
	return FUEL_DAYS_MISSING_INPUT


func get_last_food_days_usec() -> int:
	"""Duration of the most recent food-days computation, in microseconds."""
	return _food_days_timer.get_last_usec()


func recompute_summary() -> void:
	"""Recompute the derived stock summary (REQ-SET-119, committed-change half)."""
	_recompute_summary()


func _recompute_summary() -> void:
	"""Walk every lot once and re-derive ready nutrition points, timed against the budget."""
	_timer.start()
	var total: int = 0
	for index: int in _store_count:
		total += _ready_nutrition_in(_store(index))
	_ready_nutrition_points = total
	_timer.stop()


func _ready_nutrition_in(container: Vector2i) -> int:
	"""Sum ready nutrition points over one container's lots."""
	var total: int = 0
	var lot: Vector2i = _inventory.container_first_lot(container)
	while lot != InventoryScript.NULL_REF:
		total += _lot_nutrition_points(lot)
		lot = _inventory.container_next_lot(lot)
	return total


func _lot_nutrition_points(lot: Vector2i) -> int:
	"""Ready nutrition points contributed by one lot, or 0 when it is not ready food.

	GDD §5.8: seeds, raw inedible ingredients, expired food and reserved quantity are all
	excluded. Rounding is down, per the BAL-NUM-001 nutrition rule.
	"""
	var item_id: int = _inventory.lot_item_id(lot)
	if _definitions.is_seed(item_id) or not _definitions.is_raw_edible(item_id):
		return 0
	var per_unit: int = _definitions.nutrition_per_u(item_id)
	if per_unit <= 0 or _is_expired(lot, item_id):
		return 0
	@warning_ignore("integer_division") return _inventory.lot_available_milli(lot) * per_unit / InventoryScript.MILLI_PER_UNIT


func _is_expired(lot: Vector2i, item_id: int) -> bool:
	"""True once a lot's effective age has reached shelf_hours x 1000 (GDD §5.8).

	Always false today: nothing advances lot age, because the store and temperature factors
	that drive aging belong to systems this milestone does not build.
	"""
	var shelf_hours: int = _definitions.shelf_hours(item_id)
	if shelf_hours <= 0:
		return false
	return _inventory.lot_age_milli_hours(lot) >= shelf_hours * 1000


func store_used_mass_g(container: Vector2i) -> int:
	"""Grams currently occupied in one store."""
	return _inventory.container_used_mass_g(container)


func pantry() -> Vector2i:
	"""Ref of the hall-owned food store (GDD §5.9 pantry), or the null ref while closed."""
	return _store(PANTRY_STORE) if _store_count != 0 else InventoryScript.NULL_REF


func stockpile(index: int) -> Vector2i:
	"""Ref of material store `index` (0..3, plan order), or the null ref while closed."""
	if _store_count == 0 or index < 0 or index >= STOCKPILE_COUNT:
		return InventoryScript.NULL_REF
	return _store(FIRST_STOCKPILE_STORE + index)


func stores_open() -> bool:
	"""True once `open_starter_stores()` has bound the pantry and the four stockpiles."""
	return _store_count != 0


func material_used_mass_g() -> int:
	"""Grams occupied across the four stockpiles, 0 while closed."""
	var total: int = 0
	for index: int in range(FIRST_STOCKPILE_STORE, _store_count):
		total += _inventory.container_used_mass_g(_store(index))
	return total


func _store(index: int) -> Vector2i:
	"""Store column `index` as a ref. Callers bound `index` by `_store_count`."""
	return Vector2i(_store_slot[index], _store_generation[index])


func inventory() -> InventoryScript:
	"""The authoritative lot store, for systems that need lot-level operations."""
	return _inventory


func definitions() -> ItemDefinitionsScript:
	"""The compiled ItemDefinition catalog backing these stores."""
	return _definitions


func is_known_item(item_key: StringName) -> bool:
	"""True when the key names one of the loaded catalog items."""
	return _definitions.compiled_id(item_key) >= 0


func item_count() -> int:
	"""Number of catalog items registered into the stores."""
	return _definitions.item_count()


func catalog_error() -> String:
	"""Why the catalog failed to load, or empty when the stores are open."""
	return _catalog_error


func last_refusal() -> StringName:
	"""Refusal code of the most recent refused operation, or empty after a successful one."""
	return _last_refusal


func get_last_summary_usec() -> int:
	"""Duration of the most recent summary recompute, in microseconds."""
	return _timer.get_last_usec()


func _resolve(item_key: StringName) -> int:
	"""Compiled id for an item key, or -1 after recording the refusal."""
	if _catalog_error != "":
		_refuse(REFUSE_CATALOG_UNAVAILABLE)
		return -1
	var item_id: int = _definitions.compiled_id(item_key)
	if item_id < 0:
		_refuse(InventoryScript.REFUSE_UNKNOWN_ITEM)
		return -1
	return item_id


func _route_of(item_id: int) -> Vector2i:
	"""The half-open store index range whose filter admits this item; empty when none does."""
	var category: int = _inventory.item_category(item_id)
	if category < 0:
		return Vector2i.ZERO
	if (_pantry_filters >> category) & 1 == 1:
		return Vector2i(PANTRY_STORE, FIRST_STOCKPILE_STORE)
	if (_material_filters >> category) & 1 == 1:
		return Vector2i(FIRST_STOCKPILE_STORE, STORE_COUNT)
	return Vector2i.ZERO


func _find_stack(container: Vector2i, item_id: int) -> Vector2i:
	"""First lot in a container a bare deposit of this item may merge into, or NULL_REF."""
	var lot: Vector2i = _inventory.container_first_lot(container)
	while lot != InventoryScript.NULL_REF:
		if _inventory.lot_item_id(lot) == item_id and _is_bare_lot(lot):
			return lot
		lot = _inventory.container_next_lot(lot)
	return InventoryScript.NULL_REF


func _is_bare_lot(lot: Vector2i) -> bool:
	"""True when a lot carries the deposit defaults, so a merge cannot be refused on attributes."""
	if _inventory.lot_quality(lot) != UNSET_QUALITY:
		return false
	if _inventory.lot_provenance(lot) != UNSET_PROVENANCE or _inventory.lot_recipe_id(lot) != NO_RECIPE:
		return false
	return _inventory.lot_age_milli_hours(lot) == FRESH_AGE_MILLI_HOURS


func _publish(item_key: StringName, before_milli: int, after_milli: int) -> void:
	"""Re-derive the summary and notify the UI after one committed change."""
	_last_refusal = REFUSE_NONE
	_recompute_summary()
	stocks_changed.emit()
	if after_milli <= 0 and before_milli > 0:
		stock_depleted.emit(item_key)


func _refuse(code: StringName) -> bool:
	"""Record a refusal code and return false, so callers can `return _refuse(...)`."""
	_last_refusal = code
	return false
