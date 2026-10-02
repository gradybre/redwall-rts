extends RefCounted
## The fishers' gear locker at the fisher shelter (GDD §5.9: "Fisher shelter | ... | Gear locker; bank access"), holding
## REAL gear: every hand net, trap, ice kit and tier-2 outfit is an InventoryLot of `data/item_definitions.json`'s item
## in a real `scripts/core/inventory.gd` container, with a real `scripts/core/gear.gd` GearInstance row. Decision 0435.
## This closes fishing_driver.gd's named blocker "GEAR DURABILITY AND WEAR": the store's own rules apply, unforked --
##   * durability 0-1000 and §5.4's wear per cycle (net 20, trap 10, ice kit 20; gear.gd `cycle_wear_for_item_into`);
##   * "A cycle cannot start with durability below wear" -- `claim_for_job` refuses INSUFFICIENT_DURABILITY, so gear
##     NEVER breaks in use (review ECO-020's "no surprise breakage"): a worn net is refused BEFORE the trip, with its
##     durability shown and Mend offered;
##   * the claim belongs to the cycle's Job (decision 0017): completion applies the wear exactly once, cancellation
##     applies none, a second completion refuses;
##   * repair is gear.gd's: "wood 1 + rope 0.25 and 30 WU per 200 restored durability", clamped at the cap;
##   * a tier-2 outfit is gear with no durability (gear.gd: "no clothing degradation mechanic").
## The locker's MATERIALS -- rope and iron for making and mending gear -- are real lots of `rope` and `iron` here too.
##
## THE OPENING STOCK (DEMO, decision 0435): the demo has no flax, ropewalk, iron or cloth chain (rope is §5.7 flax, iron
## has no producer, outfits are cloth), so the locker starts with what the village came with: one hand net, one trap,
## two tier-2 outfits, 4 U of rope and 2 U of iron. Making more gear spends them (and the stores' wood).
##
## THE GEAR'S RECIPES (GDD §5.4 cost column; balance §3.3 `craft_net` 30000 mWU, `craft_trap` 40000, `craft_ice_kit`
## 40000; §5.9: "Gear crafting at a workbench"): a net wood 2 + rope 1, a trap wood 4 + rope 2, an ice kit wood 2 +
## iron 1. Outfits are not made here (§5.7 `outfit`: cloth 2 at the Workshop -- the demo has neither).

const InventoryScript := preload("res://scripts/core/inventory.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const GearScript := preload("res://scripts/core/gear.gd")
const CoreCatalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const KIND_NET: int = 0
const KIND_TRAP: int = 1
const KIND_ICE_KIT: int = 2
const KIND_OUTFIT: int = 3
const KIND_COUNT: int = 4
const KIND_KEYS: Array[StringName] = [&"net", &"trap", &"ice_kit", &"outfit_tier2"]
const KIND_NAMES: Array[String] = ["hand net", "trap", "ice kit", "winter outfit"]
const MAT_ROPE: int = 0
const MAT_IRON: int = 1
const MAT_KEYS: Array[StringName] = [&"rope", &"iron"]
const MAT_NAMES: Array[String] = ["rope", "iron"]

## The opening stock (see THE OPENING STOCK; DEMO).
const OPENING_GEAR: Array[int] = [1, 1, 0, 2]
const OPENING_MATERIAL_MILLI: Array[int] = [4000, 2000]
## The recipes (see THE GEAR'S RECIPES), by kind; the outfit's row is unused (not made here).
const MAKE_WOOD_MILLI: Array[int] = [2000, 4000, 2000, 0]
const MAKE_MATERIAL: Array[int] = [MAT_ROPE, MAT_ROPE, MAT_IRON, MAT_ROPE]
const MAKE_MATERIAL_MILLI: Array[int] = [1000, 2000, 1000, 0]
const MAKE_MWU: Array[int] = [30000, 40000, 40000, 0]
## gear.gd's repair: 200 points per 30 WU, wood 1 + rope 0.25.
const MEND_POINTS: int = 200
const MEND_MWU: int = 30000
const MEND_WOOD_MILLI: int = 1000
const MEND_ROPE_MILLI: int = 250
## A gear lot is one indivisible unit (gear.gd GEAR_LOT_QUANTITY_MILLI).
const LOT_MILLI: int = GearScript.GEAR_LOT_QUANTITY_MILLI
## The locker's capacity (§5.9: "the fisher and boathouse gear lockers hold 200000 g").
const LOCKER_G: int = 200000
## The locker's owner. `inventory.gd` refuses an ownerless container since decision 0533 (DEMO-CONTAIN-R01 #7), but
## the demo's fisher shelter is a presentation building with no directory row (D3 deliberately does not wire the
## demo's buildings to the settlement). The locker owns this private inventory (decision 0435) and nothing reads its
## owner -- no gate, save or directory -- so the shelter is named by this fixed, well-formed placeholder ref, slot 0
## generation 1, recorded in decision 0533. It has the shape of a real directory's first row: if this inventory is
## ever merged into the settlement's, it must become the shelter's real Building ref first, or it names that row.
const DEMO_FISHER_SHELTER_OWNER: Vector2i = Vector2i(0, 1)
const MAX_GEAR: int = 24
const NONE: int = -1

var ok: bool = false
var error: String = ""
## Bumped on every change a panel should redraw for.
var revision: int = 0

var _inventory: InventoryScript = null
var _defs: ItemDefinitionsScript = null
var _gear: GearScript = null
var _container: Vector2i = Vector2i(-1, 0)
## Each piece of gear: its lot, its kind and who has it set aside (0: nobody; else the trip's serial).
var _lots: Array[Vector2i] = []
var _kind: PackedInt32Array = PackedInt32Array()
var _earmark: PackedInt32Array = PackedInt32Array()
var _material_lot: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(-1, 0)]
var _read: IntMath.IntResult = IntMath.IntResult.new()


func open() -> bool:
	"""Make the real stores, the locker container and the opening stock. False (with `error`) when the item catalog
	does not load -- the fishery then offers no gear rather than inventing any."""
	_inventory = InventoryScript.new(4, 64)
	_defs = ItemDefinitionsScript.new()
	var loaded: ItemDefinitionsScript.LoadResult = _defs.load_from_file(ItemDefinitionsScript.DEFAULT_JSON_PATH, _inventory)
	if not loaded.ok:
		error = "ITEM_DEFINITIONS: %s" % loaded.error
		return false
	_gear = GearScript.new(MAX_GEAR)
	var made: InventoryScript.OpResult = _inventory.create_container(DEMO_FISHER_SHELTER_OWNER, LOCKER_G, -1, 0, true)
	if not made.ok:
		error = String(made.error)
		return false
	_container = made.ref
	ok = _stock_opening()
	return ok


func _stock_opening() -> bool:
	"""The opening gear and materials (see THE OPENING STOCK)."""
	for kind: int in KIND_COUNT:
		for n: int in OPENING_GEAR[kind]:
			if add_gear(kind) == NONE:
				return false
	for mat: int in MAT_KEYS.size():
		if not add_material(mat, OPENING_MATERIAL_MILLI[mat]):
			error = "MATERIAL"
			return false
	return true


func add_gear(kind: int) -> int:
	"""A new piece of `kind` at full durability (a made net, the opening stock): its index, or NONE when the store
	refused (the reason in `error`)."""
	var lot: InventoryScript.OpResult = _inventory.create_lot(_container, _defs.compiled_id(KIND_KEYS[kind]), LOT_MILLI, 0,
		CoreCatalog.PROVENANCE_ORDINARY, -1, 0, 0)
	if not lot.ok:
		error = String(lot.error)
		return NONE
	var made: InventoryScript.OpResult = _gear.create_gear(_inventory, _defs, lot.ref, GearScript.MANUFACTURE_BASIC)
	if not made.ok:
		_inventory.sink_lot_quantity(lot.ref, LOT_MILLI)
		error = String(made.error)
		return NONE
	_lots.append(lot.ref)
	_kind.append(kind)
	_earmark.append(0)
	revision += 1
	return _lots.size() - 1


func add_material(mat: int, milli: int) -> bool:
	"""Put `milli` of a material in the locker (merged into its one lot)."""
	if _inventory.is_lot_valid(_material_lot[mat]):
		var extra: InventoryScript.OpResult = _inventory.create_lot(_container, _defs.compiled_id(MAT_KEYS[mat]), milli, 0,
			CoreCatalog.PROVENANCE_ORDINARY, -1, 0, 0)
		if not extra.ok:
			return false
		var merged: InventoryScript.OpResult = _inventory.merge_lots(_material_lot[mat], extra.ref)
		revision += 1
		return merged.ok
	var lot: InventoryScript.OpResult = _inventory.create_lot(_container, _defs.compiled_id(MAT_KEYS[mat]), milli, 0,
		CoreCatalog.PROVENANCE_ORDINARY, -1, 0, 0)
	if lot.ok:
		_material_lot[mat] = lot.ref
		revision += 1
	return lot.ok


func material_milli(mat: int) -> int:
	"""How much of a material the locker holds, milli-U."""
	return _inventory.lot_quantity_milli(_material_lot[mat]) if _inventory.is_lot_valid(_material_lot[mat]) else 0


func take_material(mat: int, milli: int) -> bool:
	"""Spend `milli` of a material, all or nothing."""
	if milli <= 0:
		return true
	if material_milli(mat) < milli:
		return false
	var taken: bool = _inventory.sink_lot_quantity(_material_lot[mat], milli).ok
	revision += 1
	return taken


# --- the gear -------------------------------------------------------------------------------------

func count() -> int:
	"""How many pieces of gear the locker holds."""
	return _lots.size()


func kind_of(index: int) -> int:
	"""A piece's KIND_*."""
	return _kind[index]


func count_of(kind: int) -> int:
	"""How many pieces of `kind` the locker holds."""
	return _kind.count(kind)


func durability_of(index: int) -> int:
	"""A piece's durability (0..1000; 0 for an outfit, which has none)."""
	return _read.value if _gear.durability_into(_lots[index], _read) else 0


func wear_of_kind(kind: int) -> int:
	"""§5.4's wear a cycle takes from `kind` (0 for an outfit)."""
	if kind == KIND_OUTFIT:
		return 0
	return _read.value if _gear.cycle_wear_for_item_into(_defs, _defs.compiled_id(KIND_KEYS[kind]), _read) else 0


func cycles_left(index: int) -> int:
	"""Whole cycles a piece has left before it must be mended (§5.4: none may start below its wear)."""
	var wear: int = wear_of_kind(_kind[index])
	@warning_ignore("integer_division") return durability_of(index) / wear if wear > 0 else 0


func is_free(index: int) -> bool:
	"""Whether a piece is neither set aside for a trip nor claimed by a cycle."""
	return _earmark[index] == 0


func is_claimed(index: int) -> bool:
	"""Whether a piece holds a cycle's durability claim (gear.gd: REQ-SET-044) -- released at completion or cancel."""
	return _gear.is_claimed(_lots[index])


func pick_into(kind: int, out: IntMath.IntResult) -> bool:
	"""The free piece of `kind` that can still make a cycle, the most durable first (the lowest index on a tie), into
	`out`. Refuses NO_GEAR (none in the locker), GEAR_IN_USE (every one out) or GEAR_WORN (every free one below its
	wear: mend it)."""
	if count_of(kind) == 0:
		return out.refuse("NO_GEAR")
	var best: int = NONE
	var any_free: bool = false
	for k: int in _lots.size():
		if _kind[k] != kind or not is_free(k):
			continue
		any_free = true
		if durability_of(k) >= wear_of_kind(kind) and (best == NONE or durability_of(k) > durability_of(best)):
			best = k
	if best != NONE:
		return out.succeed(best)
	return out.refuse("GEAR_WORN" if any_free else "GEAR_IN_USE")


func earmark(index: int, trip: int) -> void:
	"""Set a free piece aside for trip `trip` (> 0)."""
	_earmark[index] = trip
	revision += 1


func release(index: int, trip: int) -> void:
	"""Trip `trip` gives back a piece it set aside (another trip's mark is left alone)."""
	if index >= 0 and index < _earmark.size() and _earmark[index] == trip:
		_earmark[index] = 0
		revision += 1


func claim(index: int, job: Vector2i) -> String:
	"""REQ-SET-044's durability reservation for a cycle's Job: "" when claimed, else gear.gd's refusal."""
	var claimed: InventoryScript.OpResult = _gear.claim_for_job(_lots[index], job)
	return "" if claimed.ok else String(claimed.error)


func complete(index: int, job: Vector2i) -> int:
	"""REQ-SET-045's wear, applied once for a completed cycle: the wear taken (-1 when there was no such claim)."""
	var done: InventoryScript.OpResult = _gear.complete_cycle(_lots[index], job)
	revision += 1
	return done.value if done.ok else -1


func cancel(index: int, job: Vector2i) -> bool:
	"""A cycle given up: its claim released, no wear (false when there was no such claim)."""
	return _gear.cancel_claim(_lots[index], job).ok


func mend(index: int) -> int:
	"""Restore MEND_POINTS (clamped at the cap): the new durability, or -1 when gear.gd refused (claimed, an outfit)."""
	var mended: InventoryScript.OpResult = _gear.repair(_lots[index], MEND_POINTS)
	revision += 1
	return mended.value if mended.ok else -1


func most_worn_into(out: IntMath.IntResult) -> bool:
	"""The free piece with the most durability missing (the lowest index on a tie), into `out`; refuses NOTHING_WORN."""
	var best: int = NONE
	for k: int in _lots.size():
		if _kind[k] == KIND_OUTFIT or not is_free(k) or durability_of(k) >= GearScript.CAP_FISHING:
			continue
		if best == NONE or durability_of(k) < durability_of(best):
			best = k
	if best == NONE:
		return out.refuse("NOTHING_WORN")
	return out.succeed(best)


func gear_store() -> GearScript:
	"""The real gear store (tests read it)."""
	return _gear
