extends RefCounted
## Test fixture for task 06.4's haul slices (decisions 1022, 1023): the real stores a haul touches,
## composed the way the settlement composes them, sharing ONE directory.
##
## Buildings (owning the directory) with a live World row; Inventory at a reduced capacity;
## StockAge; the ground-pile composer bound as Inventory's site authority; the reservation pool;
## Residents on the same directory; and the two haul composers. Nothing here is a production
## path: it exists so every refusal a suite asserts is the one production would return.

const InventoryScript := preload("res://scripts/core/inventory.gd")
const ReservationsScript := preload("res://scripts/core/reservations.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const GroundPilesScript := preload("res://scripts/core/ground_piles.gd")
const HaulCarryScript := preload("res://scripts/core/haul_carry.gd")
const HaulPlannerScript := preload("res://scripts/core/haul_planner.gd")
const StorePolicyScript := preload("res://scripts/core/store_policy.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")

## Synthetic registered items: id, mass in grams per unit, category bit.
const ITEM_STONE: int = 3
const STONE_MASS_G: int = 1000
const ITEM_GRAIN: int = 6
const GRAIN_MASS_G: int = 1
const ITEM_ODD: int = 7
const ODD_MASS_G: int = 7
const CATEGORY_MATERIAL: int = 0
const CATEGORY_FOOD: int = 1
const START_MASK: int = 1
const LEASE: int = 300

var buildings: BuildingsScript = null
var directory: EntityDirectory = null
var world: Vector2i = EntityDirectory.NULL_REF
var inventory: InventoryScript = null
var stock_age: StockAgeScript = null
var piles: GroundPilesScript = null
var pool: ReservationsScript = null
var residents: ResidentsScript = null
var carry: HaulCarryScript = null
var planner: HaulPlannerScript = null
var store_policy: StorePolicyScript = null


func _init(container_capacity: int = 64, lot_capacity: int = 64, row_capacity: int = 256) -> void:
	"""Compose every store at the given reduced capacities and bind both haul composers."""
	buildings = BuildingsScript.new()
	directory = buildings.directory()
	world = directory.create(EntityDirectory.KIND_WORLD)
	inventory = InventoryScript.new(container_capacity, lot_capacity)
	inventory.register_item(ITEM_STONE, STONE_MASS_G, CATEGORY_MATERIAL)
	inventory.register_item(ITEM_GRAIN, GRAIN_MASS_G, CATEGORY_FOOD)
	inventory.register_item(ITEM_ODD, ODD_MASS_G, CATEGORY_MATERIAL)
	stock_age = StockAgeScript.new(inventory, null)
	piles = GroundPilesScript.new()
	piles.bind_stores(inventory, buildings, stock_age)
	piles.bind_world(world)
	pool = ReservationsScript.new(row_capacity, ReservationsScript.JOB_CAPACITY, lot_capacity)
	residents = ResidentsScript.new(directory, null)
	carry = HaulCarryScript.new()
	carry.bind(inventory, pool, residents, piles)
	store_policy = StorePolicyScript.new(buildings, inventory)
	planner = HaulPlannerScript.new()
	planner.bind(inventory, pool, residents, buildings, piles, store_policy)


static func tile(x: int, z: int) -> int:
	"""GDD §5.1's `z*128+x`."""
	return z * 128 + x


func spawn(species: StringName) -> int:
	"""One adult of `species`; its resident typed row."""
	return residents.spawn(species).value


func place_active(key: String, x: int, z: int, rotation: int = 0) -> Vector2i:
	"""Place one building and make it ACTIVE; its directory ref, or the null ref on a refusal."""
	var made: BuildingsScript.OpResult = buildings.place_building(
		int(Catalog.BUILDING_DEFINITION[key]), tile(x, z), rotation, START_MASK)
	if not made.ok:
		return EntityDirectory.NULL_REF
	buildings.set_building_state(made.ref, Catalog.BUILDING_STATE["ACTIVE"])
	return made.ref


func store(owner: Vector2i, max_mass_g: int, anchor_tile: int,
		filters: int = InventoryScript.FILTERS_ACCEPT_ALL, reachable: bool = true) -> Vector2i:
	"""One ordinary store container owned by `owner`, anchored on `anchor_tile`."""
	return inventory.create_container(owner, max_mass_g, filters, InventoryScript.UNSET_POLICY,
		reachable, anchor_tile).ref


func lot(container: Vector2i, item: int, quantity_milli: int) -> Vector2i:
	"""One plain lot of `quantity_milli` of `item` in `container`."""
	return inventory.create_lot(container, item, quantity_milli, 0, 0, 0, 0, 0).ref


func claim(job: Vector2i, lot_ref: Vector2i, purpose: int, quantity_milli: int,
		expiry: int = LEASE) -> bool:
	"""One single-row claim through the pool's own batch door."""
	var batch: PackedInt64Array = PackedInt64Array([lot_ref.x, lot_ref.y, purpose,
		quantity_milli, expiry])
	return pool.claim_batch(job, batch, 1, inventory).ok


func state() -> PackedByteArray:
	"""Inventory, pool and resident-equipment images concatenated, for byte-identity checks."""
	var out: PackedByteArray = inventory.state_bytes()
	out.append_array(pool.state_bytes())
	out.append_array(residents.equipment_state_bytes())
	return out


func audits_pass() -> bool:
	"""Inventory's conservation/placement audit and the pool's reserved-total audit both pass."""
	return inventory.audit().ok and pool.audit(inventory).ok
