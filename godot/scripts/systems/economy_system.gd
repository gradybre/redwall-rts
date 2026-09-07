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

const InventoryScript := preload("res://scripts/core/inventory.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const PerfTimerScript := preload("res://scripts/utils/perf_timer.gd")

## GDD §5.9 starter fixture: "Four pantry shelves supply 200000g storage" and "Four stockpiles
## provide 1600000g material storage; starting food fits the pantry."
const PANTRY_MAX_MASS_G: int = 200000
const MATERIAL_STORE_MAX_MASS_G: int = 1600000

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

## UI-only notifications. Game logic calls the accessors below directly instead.
signal stocks_changed()
signal stock_depleted(item_key: StringName)

var _inventory: InventoryScript = InventoryScript.new()
var _definitions: ItemDefinitionsScript = ItemDefinitionsScript.new()
var _pantry: Vector2i = InventoryScript.NULL_REF
var _material_store: Vector2i = InventoryScript.NULL_REF
var _pantry_filters: int = 0
var _material_filters: int = 0
var _ready_nutrition_points: int = 0
var _catalog_error: String = ""
var _last_refusal: StringName = REFUSE_NONE
var _timer: PerfTimerScript = PerfTimerScript.new()


func _init() -> void:
	"""Load the catalog and open the starting stores so autoload and test instances match."""
	reset()


func _ready() -> void:
	"""Report readiness, or the catalog failure that left the stores closed."""
	if _catalog_error != "":
		push_error("EconomySystem: catalog unavailable: %s" % _catalog_error)
	print("[EconomySystem] ready")


func reset() -> void:
	"""Empty every store, reload the catalog, and reopen the starting containers."""
	_inventory.clear()
	_definitions = ItemDefinitionsScript.new()
	_pantry = InventoryScript.NULL_REF
	_material_store = InventoryScript.NULL_REF
	_last_refusal = REFUSE_NONE
	var load_result: ItemDefinitionsScript.LoadResult = _definitions.load_default(_inventory)
	_catalog_error = load_result.error
	if load_result.ok:
		_open_stores()
	_recompute_summary()


func _open_stores() -> void:
	"""Create the pantry and material store with their GDD §5.9 masses and category filters."""
	_pantry_filters = _filters_for(PANTRY_CATEGORIES)
	_material_filters = _filters_for(MATERIAL_CATEGORIES)
	if _pantry_filters == 0 or _material_filters == 0:
		_catalog_error = "category domain missing a routed category"
		return
	var pantry: InventoryScript.OpResult = _inventory.create_container(
		InventoryScript.NULL_REF, PANTRY_MAX_MASS_G, _pantry_filters, InventoryScript.UNSET_POLICY, true)
	var store: InventoryScript.OpResult = _inventory.create_container(
		InventoryScript.NULL_REF, MATERIAL_STORE_MAX_MASS_G, _material_filters, InventoryScript.UNSET_POLICY, true)
	if not pantry.ok or not store.ok:
		_catalog_error = "store creation refused"
		return
	_pantry = pantry.ref
	_material_store = store.ref


func _filters_for(category_names: Array[StringName]) -> int:
	"""Compose a 64-bit container filter from compiled category ids. 0 when any is unknown."""
	var mask: int = 0
	for name: StringName in category_names:
		var category: int = _definitions.category_compiled_id(name)
		if category < 0:
			return 0
		mask |= _inventory.category_mask(category)
	return mask


func deposit(item_key: StringName, quantity_milli: int) -> bool:
	"""Introduce quantity of a catalog item into its store. All-or-nothing; false on refusal.

	Merges into an existing identical stack when one is present, so repeated deposits do not
	consume a lot row each time.
	"""
	var item_id: int = _resolve(item_key)
	if item_id < 0:
		return false
	if quantity_milli <= 0:
		return _refuse(InventoryScript.REFUSE_INVALID_QUANTITY)
	var container: Vector2i = _store_for(item_id)
	if container == InventoryScript.NULL_REF:
		return _refuse(REFUSE_NO_ELIGIBLE_STORE)
	var before: int = _inventory.total_live_milli(item_id)
	if not _commit_deposit(container, item_id, quantity_milli):
		return false
	_publish(item_key, before, _inventory.total_live_milli(item_id))
	return true


func _commit_deposit(container: Vector2i, item_id: int, quantity_milli: int) -> bool:
	"""Run one deposit inside a transaction so a refused merge rolls the new lot back too."""
	var target: Vector2i = _find_stack(container, item_id)
	_inventory.begin()
	var created: InventoryScript.OpResult = _inventory.create_lot(
		container, item_id, quantity_milli, UNSET_QUALITY, UNSET_PROVENANCE, NO_RECIPE,
		FRESH_AGE_MILLI_HOURS, FRESH_AGE_REMAINDER)
	if created.ok and target != InventoryScript.NULL_REF:
		_inventory.merge_lots(target, created.ref)
	var commit: InventoryScript.OpResult = _inventory.commit()
	if not commit.ok:
		return _refuse(commit.error)
	return true


func withdraw(item_key: StringName, quantity_milli: int) -> bool:
	"""Consume unreserved quantity of a catalog item. All-or-nothing; false on refusal."""
	var item_id: int = _resolve(item_key)
	if item_id < 0:
		return false
	if quantity_milli <= 0:
		return _refuse(InventoryScript.REFUSE_INVALID_QUANTITY)
	var before: int = _inventory.total_live_milli(item_id)
	if available_milli(item_key) < quantity_milli:
		return _refuse(InventoryScript.REFUSE_INSUFFICIENT_UNRESERVED)
	_inventory.begin()
	var remaining: int = _sink_from(_pantry, item_id, quantity_milli)
	remaining = _sink_from(_material_store, item_id, remaining)
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
	return stock_milli(item_key) / InventoryScript.MILLI_PER_UNIT


func available_milli(item_key: StringName) -> int:
	"""Unreserved milli-units of an item across every store."""
	var item_id: int = _definitions.compiled_id(item_key)
	if item_id < 0:
		return 0
	return _available_in(_pantry, item_id) + _available_in(_material_store, item_id)


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

	This is NOT food-days. Food-days additionally divides by daily demand from each living
	resident's size and today's season multiplier, and no resident, need or season data exists
	yet, so the divisor cannot be computed and is not invented.
	"""
	return _ready_nutrition_points


func recompute_summary() -> void:
	"""Recompute the derived stock summary (REQ-SET-119, committed-change half)."""
	_recompute_summary()


func _recompute_summary() -> void:
	"""Walk every lot once and re-derive ready nutrition points, timed against the budget."""
	_timer.start()
	var total: int = 0
	total += _ready_nutrition_in(_pantry)
	total += _ready_nutrition_in(_material_store)
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
	return _inventory.lot_available_milli(lot) * per_unit / InventoryScript.MILLI_PER_UNIT


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
	"""Ref of the food store (GDD §5.9 pantry)."""
	return _pantry


func material_store() -> Vector2i:
	"""Ref of the material store (GDD §5.9 stockpiles)."""
	return _material_store


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


func _store_for(item_id: int) -> Vector2i:
	"""The container whose filter admits this item, or NULL_REF when neither does."""
	var category: int = _inventory.item_category(item_id)
	if category < 0:
		return InventoryScript.NULL_REF
	if (_pantry_filters >> category) & 1 == 1:
		return _pantry
	if (_material_filters >> category) & 1 == 1:
		return _material_store
	return InventoryScript.NULL_REF


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
