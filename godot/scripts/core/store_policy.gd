extends RefCounted
## BuildingItemAllow and BuildingItemMinimum: the per-item store filters and minimum reserves of
## REQ-SET-117, as `systems_architecture.md` §3 budgets them (decision 1031).
##
## REQ-SET-117: "The system shall allow pantry/store filters and minimum reserves per item, with
## emergency meal access overriding ordinary production minimums but never seed classification."
## ARCH-STATE-004 fixes the storage: "BuildingItemMinimum/BuildingItemAllow apply only to the 1024
## exterior main stores ... The original 64-bit filters field is a category mask; an optional
## per-item allow byte further restricts it." §3 budgets both at 262144 rows -- 1024 Building rows
## times the 256-key ItemDefinition envelope -- and this module allocates exactly that:
##
##   | Column                 | Type | Rows   | Bytes   | Budget                               |
##   |------------------------|------|--------|---------|--------------------------------------|
##   | `_allowed`             | B8   | 262144 |  262144 | §3 BuildingItemAllow.allowed         |
##   | `_minimum_milli`       | I64  | 262144 | 2097152 | §3 BuildingItemMinimum.minimum_milli |
##   | `_bound_persistent_id` | I32  |   1024 |    4096 | NEW, decision 1031 (see below)       |
##
## A cell is `building_row * ITEM_CAPACITY + item_id`, where `building_row` is the Building's
## typed row in the shared directory. The arena is owner-major with a fixed stride, so no index,
## heap or free list is needed and none is allocated.
##
## ---------------------------------------------------------------------------------------------
## THE ALLOW BYTE ONLY RESTRICTS. `store_admits()` is the inventory's own category test AND the
## per-item byte. Setting an item allowed cannot admit an item whose category the container's mask
## excludes: ARCH-STATE-004 says the byte "further restricts" the mask, not that it overrides it.
## The mask is a creation-time property of the container (`inventory.create_container()`); no
## command edits it, and this store never writes to `inventory.gd`.
##
## THE MINIMUM IS A WITHDRAWAL FLOOR FOR ORDINARY PRODUCTION, AND NOTHING ELSE. REQ-SET-117 names
## exactly one override -- emergency meal access -- so `ordinary_withdrawable_milli()` is the
## quantity an ORDINARY consumer may take, and an emergency meal consumer simply does not ask it.
## The minimum is NOT seed protection: REQ-SET-117's "never seed classification" is BAL-SAFE-009's
## rule that no meal counts a seed item as food, which the meal selector owns. A minimum of zero on
## a seed item therefore leaves the seed exactly as protected as before, and no minimum here can be
## the thing standing between a hungry resident and the sowing reserve.
##
## ---------------------------------------------------------------------------------------------
## A REUSED BUILDING ROW CANNOT INHERIT A DEMOLISHED BUILDING'S POLICY. Building rows are reused,
## and this store is not told when one is demolished (the composer owns that call). So each row is
## STAMPED with the never-reused persistent ID of the building that wrote it -- the directory's
## ARCH-ID-002 identity, the same guard `transforms.gd` and the route cursor use, and for the same
## reason: a per-slot generation repeats across slots, a persistent ID never does.
##   * A read whose stamp does not name the live building answers the DEFAULTS: allowed, minimum 0.
##   * The first write to a row with a stale stamp RESETS all 256 cells to the defaults before it
##     stamps the row, so a stale row's leftover bytes can never surface.
## The stamp is the one column §3 did not budget; it is 4096 bytes (decision 1031).
##
## THE STAMP IS UNIQUE WITHIN ONE WORLD, NOT ACROSS WORLDS. `entity_directory.clear()` restarts
## persistent IDs at 1, and a load rewinds the cursor to the save's value, so a building of a NEW
## world can carry the same persistent ID at the same row as one of the old world. Every path that
## clears or replaces the directory MUST therefore `clear()` this store too, as it clears every
## other store over that directory (decision 0094: the caller declares what its reset clears).
## `test_store_policy.gd` pins both halves: the inheritance without the reset, and its absence
## with it. A load additionally needs a codec, which does not exist yet (decision 1031's P4).
##
## A BUILDING WITH TWO STORES AT ITS ORIGIN applies its policy to both. #3a gives one main store
## per building; this store does not police that count (an owner scan per read would cost a
## selector a bounded scan of 101376 rows), and `settlement_system.gd::_main_store_of()` refuses
## the ambiguous building instead. Decision 1031 records the disagreement and its resolution: the
## composer should ask this store rather than keep a second #3a test.
##
## WHAT A MAIN STORE IS. DEMO-CONTAIN-R01 #3a: a building's main store is the container it OWNS
## that is ANCHORED AT ITS ORIGIN TILE. `store_admits()` applies the per-item byte only to such a
## container; any other container -- a satchel, a ground pile, a WIP or project store -- answers
## its category mask alone, because ARCH-STATE-004 says those "inherit their owning job's permitted
## contents" and allocate no editable per-item policy.
##
## ALLOCATION. Every column is sized once in `_init()`. Writers return a StringName refusal code
## (the empty name on success) rather than an OpResult, and every read returns a plain value, so no
## call here allocates: `store_admits()` and `ordinary_withdrawable_milli()` are safe on a
## selector's path. There is no scratch object.

const BuildingsScript := preload("res://scripts/core/buildings.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")

## ARCH-STATE-004: "the 1024 exterior main stores" and "at most 256 keys".
const BUILDING_CAPACITY: int = BuildingsScript.BUILDING_CAPACITY
const ITEM_CAPACITY: int = InventoryScript.ITEM_CAPACITY
## §3's BuildingItemAllow / BuildingItemMinimum row count: 1024 * 256 = 262144.
const POLICY_CELLS: int = BUILDING_CAPACITY * ITEM_CAPACITY

## The two values of the allow byte. ALLOWED is the default: an unconfigured store restricts
## nothing beyond its category mask.
const DISALLOWED: int = 0
const ALLOWED: int = 1

## The default minimum: no reserve held back from ordinary production.
const NO_MINIMUM: int = 0

## A stamp naming no building. The directory issues persistent IDs from 1, so 0 is never live.
const UNBOUND: int = 0

## Internal absence of a policy cell. Never returned by a public function.
const NO_CELL: int = -1

const REFUSE_NONE: StringName = &""
const REFUSE_STALE_BUILDING: StringName = &"STORE_POLICY_STALE_BUILDING"
const REFUSE_UNKNOWN_ITEM: StringName = &"STORE_POLICY_UNKNOWN_ITEM"
const REFUSE_ALLOWED_DOMAIN: StringName = &"STORE_POLICY_ALLOWED_DOMAIN"
const REFUSE_NEGATIVE_MINIMUM: StringName = &"STORE_POLICY_NEGATIVE_MINIMUM"

var _buildings: BuildingsScript = null
var _inventory: InventoryScript = null
var _directory: EntityDirectory = null

## BuildingItemAllow.allowed, one byte per (building row, item).
var _allowed: PackedByteArray = PackedByteArray()
## BuildingItemMinimum.minimum_milli, one int64 per (building row, item).
var _minimum_milli: PackedInt64Array = PackedInt64Array()
## The persistent ID of the building whose policy each row holds; UNBOUND when none.
var _bound_persistent_id: PackedInt32Array = PackedInt32Array()


func _init(p_buildings: BuildingsScript, p_inventory: InventoryScript) -> void:
	"""Bind the Building store (and through it the shared directory) and the inventory.

	Both are required: the policy is keyed by a Building row, and a store's admission is asked of a
	container. The columns are sized once and then filled with the defaults.
	"""
	assert(p_buildings != null and p_inventory != null,
		"store policy needs the Building store and the inventory")
	_buildings = p_buildings
	_inventory = p_inventory
	_directory = p_buildings.directory()
	_allowed.resize(POLICY_CELLS)
	_minimum_milli.resize(POLICY_CELLS)
	_bound_persistent_id.resize(BUILDING_CAPACITY)
	clear()


func clear() -> void:
	"""Return every row to the defaults and unbind it, without reallocating a column."""
	_allowed.fill(ALLOWED)
	_minimum_milli.fill(NO_MINIMUM)
	_bound_persistent_id.fill(UNBOUND)


func directory() -> EntityDirectory:
	"""The one directory every Building reference here is validated against."""
	return _directory


# --- validation: every check a writer makes, with no write ----------------------------------------

func item_refusal(item_id: int) -> StringName:
	"""REFUSE_NONE for an item id inside the 256-key envelope that the inventory has registered.

	`is_item_registered()` refuses an id outside `0..ITEM_CAPACITY-1` itself, and both modules
	read the one `InventoryScript.ITEM_CAPACITY`, so no second range test is written here.
	"""
	if not _inventory.is_item_registered(item_id):
		return REFUSE_UNKNOWN_ITEM
	return REFUSE_NONE


func building_refusal(building_ref: Vector2i) -> StringName:
	"""REFUSE_NONE when `building_ref` names a live Building of the shared directory."""
	if not _buildings.is_live_building(building_ref):
		return REFUSE_STALE_BUILDING
	return REFUSE_NONE


func allowed_refusal(building_ref: Vector2i, item_id: int, allowed: int) -> StringName:
	"""The code `set_allowed()` would refuse with, or REFUSE_NONE. Writes nothing."""
	var code: StringName = building_refusal(building_ref)
	if code == REFUSE_NONE:
		code = item_refusal(item_id)
	if code == REFUSE_NONE and allowed != ALLOWED and allowed != DISALLOWED:
		code = REFUSE_ALLOWED_DOMAIN
	return code


func minimum_refusal(building_ref: Vector2i, item_id: int, minimum_milli: int) -> StringName:
	"""The code `set_minimum()` would refuse with, or REFUSE_NONE. Writes nothing.

	No upper bound is imposed because no document states one: a minimum above anything the store
	could hold only means ordinary production never draws that item from it. A nonnegative int64
	minimum subtracted from a nonnegative int64 quantity cannot overflow.
	"""
	var code: StringName = building_refusal(building_ref)
	if code == REFUSE_NONE:
		code = item_refusal(item_id)
	if code == REFUSE_NONE and minimum_milli < 0:
		code = REFUSE_NEGATIVE_MINIMUM
	return code


# --- writers --------------------------------------------------------------------------------------

func set_allowed(building_ref: Vector2i, item_id: int, allowed: int) -> StringName:
	"""Set one store's per-item allow byte. REFUSE_NONE on success; refuses before any write."""
	var code: StringName = allowed_refusal(building_ref, item_id, allowed)
	if code != REFUSE_NONE:
		return code
	_allowed[_bind_cell(building_ref, item_id)] = allowed
	return REFUSE_NONE


func set_minimum(building_ref: Vector2i, item_id: int, minimum_milli: int) -> StringName:
	"""Set one store's per-item ordinary-production minimum. REFUSE_NONE on success."""
	var code: StringName = minimum_refusal(building_ref, item_id, minimum_milli)
	if code != REFUSE_NONE:
		return code
	_minimum_milli[_bind_cell(building_ref, item_id)] = minimum_milli
	return REFUSE_NONE


func _bind_cell(building_ref: Vector2i, item_id: int) -> int:
	"""The cell a validated write lands in, resetting the row first if another building left it.

	The reset is what makes reuse safe: a row stamped by a demolished building is returned to the
	defaults in full before the new building's first value is written into it.
	"""
	var row: int = _directory.get_typed_row(building_ref)
	var persistent_id: int = _directory.get_persistent_id(building_ref)
	if _bound_persistent_id[row] != persistent_id:
		_reset_row(row)
		_bound_persistent_id[row] = persistent_id
	return row * ITEM_CAPACITY + item_id


func _reset_row(row: int) -> void:
	"""Write the defaults into every one of one Building row's 256 cells."""
	var base: int = row * ITEM_CAPACITY
	for item_id: int in ITEM_CAPACITY:
		_allowed[base + item_id] = ALLOWED
		_minimum_milli[base + item_id] = NO_MINIMUM


# --- per-building reads (what a store panel shows) ------------------------------------------------

func is_allowed(building_ref: Vector2i, item_id: int) -> bool:
	"""The building's own per-item allow byte. The default (true) for a building never configured.

	This is the BYTE, not admission: `store_admits()` also applies the container's category mask.
	An unknown item or a stale building answers false, because neither has a policy to show.
	"""
	var cell: int = _building_cell(building_ref, item_id)
	if cell == NO_CELL:
		return item_refusal(item_id) == REFUSE_NONE \
			and building_refusal(building_ref) == REFUSE_NONE
	return _allowed[cell] == ALLOWED


func minimum_milli_of(building_ref: Vector2i, item_id: int) -> int:
	"""The building's ordinary-production minimum for one item, or 0 when none is set."""
	var cell: int = _building_cell(building_ref, item_id)
	return NO_MINIMUM if cell == NO_CELL else _minimum_milli[cell]


func is_policy_bound(building_ref: Vector2i) -> bool:
	"""True when this live building has written a policy row of its own."""
	if building_refusal(building_ref) != REFUSE_NONE:
		return false
	var row: int = _directory.get_typed_row(building_ref)
	return _bound_persistent_id[row] == _directory.get_persistent_id(building_ref)


func _building_cell(building_ref: Vector2i, item_id: int) -> int:
	"""The cell holding this live building's own value for `item_id`, or NO_CELL if it has none."""
	if item_refusal(item_id) != REFUSE_NONE or not is_policy_bound(building_ref):
		return NO_CELL
	return _directory.get_typed_row(building_ref) * ITEM_CAPACITY + item_id


# --- container reads: the published queries -------------------------------------------------------

func store_admits(container_ref: Vector2i, item_id: int) -> bool:
	"""True when this container's filters admit `item_id`: "filters admit", for destinations.

	Admission is the container's 64-bit category mask (the same test `inventory.gd` enforces on
	placement) AND, for a building's main store, that building's per-item allow byte. A dead
	container or an unknown item admits nothing. This answers FILTERS ONLY: capacity
	(`container_free_mass_g()`), reachability and the minimum are separate questions, asked
	separately. Read-only and allocation-free.

	A dead container needs no test of its own: `container_filters()` answers 0 for one, so the mask
	test refuses it. The item is checked first because an unknown item has no category bit to test.
	"""
	if item_refusal(item_id) != REFUSE_NONE:
		return false
	var category: int = _inventory.item_category(item_id)
	if ((_inventory.container_filters(container_ref) >> category) & 1) != 1:
		return false
	var cell: int = _main_store_cell(container_ref, item_id)
	return cell == NO_CELL or _allowed[cell] == ALLOWED


func store_minimum_milli(container_ref: Vector2i, item_id: int) -> int:
	"""The ordinary-production minimum this container holds back for `item_id`, or 0.

	Only a building's main store carries a minimum (ARCH-STATE-004); every other container, and a
	main store whose building never set one, answers 0. A dead container or an unknown item has
	no cell, so it answers 0 too.
	"""
	var cell: int = _main_store_cell(container_ref, item_id)
	return NO_MINIMUM if cell == NO_CELL else _minimum_milli[cell]


func ordinary_withdrawable_milli(container_ref: Vector2i, item_id: int) -> int:
	"""How much of `item_id` ORDINARY production may still take from this container.

	The container's unreserved stock of that item, less its minimum, never below 0. Emergency meal
	access is REQ-SET-117's one override and does not ask this; seed protection is not a minimum
	and is not decided here (see the header). Walks the container's own lot list; allocates nothing.
	"""
	var available: int = 0
	var lot: Vector2i = _inventory.container_first_lot(container_ref)
	while lot != InventoryScript.NULL_REF:
		if _inventory.lot_item_id(lot) == item_id:
			available += _inventory.lot_available_milli(lot)
		lot = _inventory.container_next_lot(lot)
	return maxi(0, available - store_minimum_milli(container_ref, item_id))


func _main_store_cell(container_ref: Vector2i, item_id: int) -> int:
	"""The policy cell governing this container, or NO_CELL when no per-item policy applies.

	A policy applies only to a live building's MAIN STORE -- owned by it and anchored at its origin
	tile (DEMO-CONTAIN-R01 #3a) -- and only once that building has written a row of its own.

	The ORDER is the guard. `_building_cell()` first: it answers NO_CELL unless the owner is a
	live, bound Building and the item is known -- and a dead container's owner reads as the null
	ref, so a dead container never gets past it. Only then is the anchor read, and by then the
	container is proved live, which is why the plain `container_anchor_tile()` reader is safe here:
	the stale-ref-reads-as-unplaced hazard its header warns about cannot reach this line.
	"""
	var owner: Vector2i = _inventory.container_owner(container_ref)
	var cell: int = _building_cell(owner, item_id)
	if cell == NO_CELL:
		return NO_CELL
	if _inventory.container_anchor_tile(container_ref) != _buildings.origin_tile_or_none(owner):
		return NO_CELL
	return cell


# --- the memory ledger ----------------------------------------------------------------------------

func ledger_bytes() -> int:
	"""Bytes this store allocates: §3's two budgeted rows plus decision 1031's binding stamp."""
	return _allowed.size() + _minimum_milli.size() * 8 + _bound_persistent_id.size() * 4
