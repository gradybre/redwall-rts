extends RefCounted
## Task 06.4 slice H2 (decision 1023): haul payload sizing, haul demand, destination selection
## and the destination reservation that REQ-SET-030 takes when a haul is accepted.
##
## WHAT IS SPECIFIED, AND WHERE IT COMES FROM
##   * Payload (REQ-SET-111, BAL-WORK-003): "limit carried mass by the resident's species
##     capacity and split quantity exactly". A lot is charged `ceil(q*m/1000)` grams (BAL-NUM-001),
##     so the largest payload of one lot is `floor((carry_g - other_cargo_g)*1000/m)` milli-units.
##     Trips for a whole quantity are BAL-WORK-003's `ceil_div(ceil_div(Q*M,1000), carry_g -
##     other_cargo_g)` -- a PLANNING figure: "each actual departure records exact payload", and the
##     per-lot ceiling can make the real departures one more than the formula (test-pinned).
##   * Handling work (BAL-CAT-010): 2000 milli-WU to load plus 2000 to unload; REQ-SET-134's 10%
##     cut for a pantry connection within 8 m applies to that handling, never to movement
##     (BAL-WORK-004). Travel ticks are BAL-WORK-003's lower bound `ceil_div(D*30, v)`.
##   * Leases (REQ-SET-032): a travelling owner renews every 30 ticks; a lease expires 300 ticks
##     after its last renewal. Published here for the job layer (H4); nothing here ticks.
##
## BRENDAN'S RULINGS OF 2026-10-02 THAT THIS FILE IMPLEMENTS
##   * Loads are sized AT ASSIGNMENT (REQ-SET-030), re-proved at load (`haul_carry.gd`), with ONE
##     ITEM LOT PER JOB at first.
##   * Destination: the LOWEST-SLOT eligible store -- off the source's footprint, owned by a
##     different ACTIVE building, reachable, its filters admitting the item, with free mass for the
##     whole payload: decision 0534's R1 rule, reused for hauling. With none, ground piles from the
##     source building's refund seeds (R2), which reserves nothing.
##   * New numbered ReservationPurpose values HAUL_SOURCE and HAUL_DESTINATION (`reservations.gd`).
##
## R1 IS RESTATED, NOT CALLED. Its only implementation is `settlement_system.gd`'s private
## `_is_output_store()`, a file this slice may not touch while `feat/demolition-d6` changes it.
## The predicate below is the same seven clauses in the same order; folding the two into one
## shared reader is recorded as follow-up work in decision 1023.
##
## THE RECORD. REQ-SET-030 reserves "output capacity" at acceptance, and Inventory's
## `reserved_mass_g` is one anonymous total per container (decision 0534), so the haul must
## remember which container holds its grams. One row per Job slot (the reservation pool's job key,
## 0..8191): the job's generation, the destination container, the tile a hauler unloads at, and
## the grams reserved. Saving it is CONSTRUCTION/HAUL-SAVED-BINDINGS work (slice H8); the
## persistence registry classifies it UNRESOLVED with its question, as decision 0534 did for the
## demolition record.

const IntMath := preload("res://scripts/core/int_math.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ReservationsScript := preload("res://scripts/core/reservations.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const GroundPilesScript := preload("res://scripts/core/ground_piles.gd")
const HaulCarryScript := preload("res://scripts/core/haul_carry.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")

const NULL_REF: Vector2i = InventoryScript.NULL_REF
const NO_TILE: int = -1
## The reservation pool's Job key range; one record row per key.
const JOB_CAPACITY: int = ReservationsScript.JOB_CAPACITY

## BAL-CAT-010: "handling a haul payload 2000 milli-WU to load plus 2000 to unload".
const HAUL_LOAD_MILLI_WU: int = 2000
const HAUL_UNLOAD_MILLI_WU: int = 2000
## REQ-SET-134 / BAL-WORK-004: the hauling-work reduction for a pantry connection, as 9/10.
const PANTRY_HANDLING_NUMERATOR: int = 9
const PANTRY_HANDLING_DENOMINATOR: int = 10
## REQ-SET-134's "within 8 m walking distance", in 1/1024 m units.
const PANTRY_CONNECTION_MAX_U: int = 8 * 1024
## BAL-WORK-003's tick rate and REQ-SET-032's lease cadence.
const TICKS_PER_SECOND: int = 30
const LEASE_RENEW_TICKS: int = 30
const LEASE_EXPIRY_TICKS: int = 300
## BAL-NUM-001: milli-units per catalog unit.
const MILLI_PER_UNIT: int = InventoryScript.MILLI_PER_UNIT

const DESTINATION_NONE: int = 0
const DESTINATION_STORE: int = 1
const DESTINATION_GROUND: int = 2

const REFUSE_NONE: StringName = &""
const REFUSE_NOT_BOUND: StringName = &"HAUL_PLANNER_NOT_BOUND"
const REFUSE_INVALID_ARGUMENT: StringName = &"HAUL_INVALID_ARGUMENT"
const REFUSE_OVERFLOW: StringName = &"HAUL_ARITHMETIC_OVERFLOW"
const REFUSE_JOB_RANGE: StringName = &"HAUL_JOB_OUT_OF_RANGE"
const REFUSE_JOB_ADMITTED: StringName = &"HAUL_JOB_ALREADY_ADMITTED"
const REFUSE_JOB_NOT_ADMITTED: StringName = &"HAUL_JOB_NOT_ADMITTED"
const REFUSE_SOURCE_LOT: StringName = &"HAUL_SOURCE_LOT_INVALID"
const REFUSE_NOTHING_TO_HAUL: StringName = &"HAUL_NOTHING_TO_HAUL"
const REFUSE_HAULER_ABSENT: StringName = &"HAUL_HAULER_NOT_PRESENT"
const REFUSE_CARRY_LIMIT: StringName = &"HAUL_CARRY_LIMIT_UNAVAILABLE"
## A satchel's goods are hauled on only by the resident carrying them.
const REFUSE_NOT_HAULERS_SATCHEL: StringName = &"HAUL_SATCHEL_NOT_THE_HAULERS"
## REQ-SET-031's blocking cause: no store takes the payload and no pile fallback applies.
const REFUSE_NO_DESTINATION: StringName = &"HAUL_NO_DESTINATION"
const REFUSE_TRANSACTION_OPEN: StringName = &"HAUL_INVENTORY_TRANSACTION_OPEN"
## `audit()`: a record names a dead store, or the records hold more grams than a store reserves.
const REFUSE_AUDIT_STORE: StringName = &"HAUL_AUDIT_DESTINATION_DEAD"
const REFUSE_AUDIT_GRAMS: StringName = &"HAUL_AUDIT_GRAMS_EXCEED_STORE"


class Destination:
	"""Caller-owned outcome of a destination choice. `kind` is DESTINATION_* and is read first."""
	var kind: int = DESTINATION_NONE
	## The store, for DESTINATION_STORE; the null ref otherwise.
	var container: Vector2i = Vector2i(-1, 0)
	## The store's anchor tile, or the first eligible pile seed for DESTINATION_GROUND.
	var tile: int = NO_TILE
	## The payload's charge in grams: what a store reserves; 0 is reserved for piles.
	var charge_g: int = 0

	func clear() -> void:
		"""Reset to "no destination"."""
		kind = DESTINATION_NONE
		container = Vector2i(-1, 0)
		tile = NO_TILE
		charge_g = 0


var _inventory: InventoryScript = null
var _reservations: ReservationsScript = null
var _residents: ResidentsScript = null
var _buildings: BuildingsScript = null
var _piles: GroundPilesScript = null

# --- the record: one row per Job key (registry: UNRESOLVED, decision 1023) -------------------
## The admitted job's generation; 0 means the row holds no admission.
var _job_generation: PackedInt32Array = PackedInt32Array()
## The destination store (an INVENTORY container ref), null for a ground-pile destination.
var _dest_slot: PackedInt32Array = PackedInt32Array()
var _dest_generation: PackedInt32Array = PackedInt32Array()
## The tile the hauler unloads at: the store's anchor, or the pile walk's first eligible seed.
var _dest_tile: PackedInt32Array = PackedInt32Array()
## Grams reserved in the destination store at admission; 0 for a ground-pile destination.
var _reserved_g: PackedInt64Array = PackedInt64Array()

# --- cold-path scratch (ARCH §2.3 row, decision 1023) ----------------------------------------
var _footprint: PackedByteArray = PackedByteArray()
var _outside: PackedByteArray = PackedByteArray()
var _seeds: PackedInt32Array = PackedInt32Array()
## How many of `_seeds` the last footprint read wrote; 0 for a source with no Building owner.
var _seed_count: int = 0
var _spec: PackedInt64Array = PackedInt64Array()
var _claim: PackedInt64Array = PackedInt64Array()
## The recorded unload tile as a one-cell seed buffer for a ground destination's unload.
var _one_seed: PackedInt32Array = PackedInt32Array()
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _place: GroundPilesScript.PlaceResult = GroundPilesScript.PlaceResult.new()
var _chosen: Destination = Destination.new()


func _init() -> void:
	"""Allocate the record and the scratch once (ARCH-MEM-001)."""
	_job_generation.resize(JOB_CAPACITY)
	_dest_slot.resize(JOB_CAPACITY)
	_dest_generation.resize(JOB_CAPACITY)
	_dest_tile.resize(JOB_CAPACITY)
	_reserved_g.resize(JOB_CAPACITY)
	_footprint.resize(InventoryScript.ANCHOR_TILE_COUNT)
	_outside.resize(InventoryScript.ANCHOR_TILE_COUNT)
	_footprint.fill(0)
	_outside.fill(1)
	_seeds.resize(GroundPilesScript.REFUND_SEED_CAPACITY)
	_spec.resize(GroundPilesScript.SPEC_STRIDE)
	_claim.resize(ReservationsScript.CLAIM_STRIDE)
	_one_seed.resize(1)
	clear()


func clear() -> void:
	"""Forget every admission.

	Releases nothing: the stores holding the claims and grams are cleared by their own owners on
	the same reset, exactly like `demolition_admissions.gd`'s record.
	"""
	_job_generation.fill(0)
	_dest_slot.fill(InventoryScript.NULL_SLOT)
	_dest_generation.fill(InventoryScript.NULL_GENERATION)
	_dest_tile.fill(NO_TILE)
	_reserved_g.fill(0)


func bind(inventory: InventoryScript, reservations: ReservationsScript,
		residents: ResidentsScript, buildings: BuildingsScript, piles: GroundPilesScript) -> bool:
	"""Borrow the five stores a haul admission reads and writes. False, binding nothing, on a null."""
	if inventory == null or reservations == null or residents == null or buildings == null \
			or piles == null:
		return false
	_inventory = inventory
	_reservations = reservations
	_residents = residents
	_buildings = buildings
	_piles = piles
	return true


# --- sizing (static, allocation-free) -------------------------------------------------------

static func payload_milli_into(available_milli: int, mass_g: int, carry_g: int,
		other_cargo_g: int, out: IntMath.IntResult) -> bool:
	"""REQ-SET-111's payload: the most of `available_milli` one departure may carry.

	`ceil(q*m/1000) <= room` exactly when `q*m <= room*1000`, so it is
	`min(available, floor(room*1000/m))` with `room = carry_g - other_cargo_g`; a massless item
	goes whole. Refuses negative inputs and arithmetic that would overflow. 0 is a real answer.
	"""
	if available_milli < 0 or mass_g < 0 or carry_g < 0 or other_cargo_g < 0:
		return out.refuse(String(REFUSE_INVALID_ARGUMENT))
	var room: int = carry_g - other_cargo_g
	if room <= 0 or available_milli == 0:
		return out.succeed(0)
	if mass_g == 0:
		# Defensive: `inventory.register_item()` refuses a massless item today.
		return out.succeed(available_milli)
	if not IntMath.checked_mul_into(room, MILLI_PER_UNIT, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	@warning_ignore("integer_division") var fits: int = out.value / mass_g
	return out.succeed(mini(available_milli, fits))


static func trips_into(quantity_milli: int, mass_g: int, carry_g: int, other_cargo_g: int,
		out: IntMath.IntResult) -> bool:
	"""BAL-WORK-003's planning trips: `ceil_div(ceil_div(Q*M,1000), carry_g - other_cargo_g)`.

	A planning figure for forecasts and job sizing. The departures actually made are each sized
	by `payload_milli_into()`, whose per-lot ceiling can need one more trip than this returns.
	Refuses a carry that leaves no room, negative inputs and overflow.
	"""
	if quantity_milli < 0 or mass_g < 0 or other_cargo_g < 0 or carry_g - other_cargo_g <= 0:
		return out.refuse(String(REFUSE_INVALID_ARGUMENT))
	if not IntMath.inventory_capacity_debit_g_into(quantity_milli, mass_g, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return IntMath.ceil_div_into(out.value, carry_g - other_cargo_g, out)


static func travel_ticks_into(distance_u: int, speed_u_per_s: int,
		out: IntMath.IntResult) -> bool:
	"""BAL-WORK-003's lower bound for one straight leg from rest: `ceil_div(D*30, v)` ticks."""
	if distance_u < 0 or speed_u_per_s <= 0:
		return out.refuse(String(REFUSE_INVALID_ARGUMENT))
	if not IntMath.checked_mul_into(distance_u, TICKS_PER_SECOND, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return IntMath.ceil_div_into(out.value, speed_u_per_s, out)


static func handling_milli_wu(load_side: bool, pantry_connection: bool) -> int:
	"""BAL-CAT-010's load or unload work, cut to 9/10 on a REQ-SET-134 pantry connection.

	2000 * 9 / 10 is exactly 1800, so no rounding rule is needed for the values in force.
	"""
	var base: int = HAUL_LOAD_MILLI_WU if load_side else HAUL_UNLOAD_MILLI_WU
	if not pantry_connection:
		return base
	@warning_ignore("integer_division") return base * PANTRY_HANDLING_NUMERATOR / PANTRY_HANDLING_DENOMINATOR


# --- demand ---------------------------------------------------------------------------------

func next_haul_lot(source: Vector2i, after_lot: Vector2i = NULL_REF) -> Vector2i:
	"""The next lot in `source` -- in its list order, after `after_lot` -- with unclaimed quantity.

	One item lot per job: a demand producer posts one haul per lot this returns. Claimed
	quantity is already some job's; a lot claimed whole is skipped. The null ref ends the walk.
	"""
	if _inventory == null or not _inventory.is_container_valid(source):
		return NULL_REF
	var lot: Vector2i = _inventory.container_first_lot(source) if after_lot == NULL_REF \
		else _inventory.container_next_lot(after_lot)
	while lot != NULL_REF and _inventory.lot_available_milli(lot) <= 0:
		lot = _inventory.container_next_lot(lot)
	return lot


func is_standing_haul_source(container: Vector2i) -> bool:
	"""Whether goods here are owed a haul by default, before any player or intent asks.

	REQ-SET-110's ground pile is "visible temporary" storage, and a satchel left holding
	unclaimed goods is a cancelled haul's cargo awaiting its fresh haul -- either only while it
	holds quantity no haul has claimed yet. A building's store is a
	source only when something names it (D6's evacuation intent, a production output policy), so
	it answers false here.
	"""
	if _inventory == null or not _inventory.is_container_valid(container):
		return false
	if not _inventory.is_ground_pile(container) and not _inventory.is_satchel(container):
		return false
	return next_haul_lot(container) != NULL_REF


# --- destination ----------------------------------------------------------------------------

func select_destination_into(source_lot: Vector2i, payload_milli: int, out: Destination) -> bool:
	"""Choose where `payload_milli` of `source_lot` goes, writing nothing to any store.

	R1: the lowest-slot eligible store. R2: else ground piles from the source building's refund
	seeds, proved placeable by a rolled-back placement. A source with no live Building owner (a
	ground pile, a satchel) has no R2 fallback and refuses HAUL_NO_DESTINATION -- REQ-SET-031's
	blocking cause. On success `out` names the destination; on refusal `out` is cleared.
	"""
	out.clear()
	var ready: StringName = _destination_input_refusal(source_lot, payload_milli)
	if ready != REFUSE_NONE:
		return _refuse_into(out, ready)
	var source: Vector2i = _inventory.lot_container(source_lot)
	var owner: Vector2i = _inventory.container_owner(source)
	var built: bool = _is_live_building(owner)
	if not _mark_source_footprint(owner, built):
		return _refuse_into(out, StringName(_math.error))
	out.charge_g = _math.value
	var store: Vector2i = _lowest_destination_store(owner, source_lot, out.charge_g)
	if built:
		_set_footprint_rect(owner, 0)
	if store != NULL_REF:
		out.kind = DESTINATION_STORE
		out.container = store
		out.tile = _inventory.container_anchor_tile(store)
		return true
	# With no Building owner `_seed_count` is 0, so R2 refuses HAUL_NO_DESTINATION.
	return _ground_fallback_into(source_lot, payload_milli, out)


func _destination_input_refusal(source_lot: Vector2i, payload_milli: int) -> StringName:
	"""Bound, a live loose lot, a positive payload it holds, and its charge in `_math.value`."""
	if _inventory == null:
		return REFUSE_NOT_BOUND
	if not _inventory.is_lot_valid(source_lot) or _inventory.is_lot_equipped(source_lot):
		return REFUSE_SOURCE_LOT
	if payload_milli <= 0 or payload_milli > _inventory.lot_quantity_milli(source_lot):
		return REFUSE_INVALID_ARGUMENT
	if not IntMath.inventory_capacity_debit_g_into(payload_milli,
			_inventory.item_mass_g(_inventory.lot_item_id(source_lot)), _math):
		return REFUSE_OVERFLOW
	return REFUSE_NONE


func _mark_source_footprint(owner: Vector2i, built: bool) -> bool:
	"""Read a Building owner's refund seeds, and clear its footprint out of `_outside`.

	BETWEEN CALLS `_outside` IS ALL ONES AND `_footprint` ALL ZEROS, so only the footprint's own
	rectangle is written here and restored after the scan (`_set_footprint_rect(owner, 0)`): a
	destination choice costs its footprint, not 16384 tiles. Keeps the payload charge in
	`_math.value`. With no Building owner nothing is excluded and `_seed_count` is 0.
	"""
	var charge: int = _math.value
	_seed_count = 0
	if built:
		if not _piles.refund_seeds_into(owner, _footprint, _seeds, _math):
			return false
		_seed_count = _math.value
		_set_footprint_rect(owner, 1)
	return _math.succeed(charge)


func _set_footprint_rect(owner: Vector2i, marked: int) -> void:
	"""Write `marked` into `_footprint` and its complement into `_outside` over one footprint."""
	var type_id: int = _buildings.type_id_of_building(owner).value
	var origin: int = _buildings.origin_tile_of_building(owner).value
	var rotation: int = _buildings.rotation_of_building(owner).value
	var size_x: int = _buildings.definitions().footprint_x_of(type_id)
	var size_z: int = _buildings.definitions().footprint_z_of(type_id)
	for dz: int in _buildings.extent_z_of(size_x, size_z, rotation):
		for dx: int in _buildings.extent_x_of(size_x, size_z, rotation):
			var tile: int = origin + dz * GroundPilesScript.MAP_TILES_X + dx
			_footprint[tile] = marked
			_outside[tile] = 1 - marked


func _lowest_destination_store(owner: Vector2i, lot: Vector2i, charge_g: int) -> Vector2i:
	"""Walk placed containers off the footprint in ascending slot order; the first eligible one."""
	var candidate: Vector2i = _inventory.next_container_anchored_in(-1, _outside)
	while candidate != NULL_REF:
		if _is_destination_store(candidate, owner, lot, charge_g):
			return candidate
		candidate = _inventory.next_container_anchored_in(candidate.x, _outside)
	return NULL_REF


func _is_destination_store(candidate: Vector2i, source_owner: Vector2i, lot: Vector2i,
		charge_g: int) -> bool:
	"""Decision 0534's R1 clauses for one candidate, applied to a haul's payload.

	The source itself never qualifies: a building's store is on its own footprint (masked out)
	and shares its owner; a pile or satchel source is refused as a pile or a satchel.
	"""
	if _inventory.is_ground_pile(candidate) or _inventory.is_satchel(candidate):
		return false
	var owner: Vector2i = _inventory.container_owner(candidate)
	if owner == source_owner or not _is_live_building(owner):
		return false
	if _buildings.state_of_building(owner).value != Catalog.BUILDING_STATE["ACTIVE"]:
		return false
	if not _inventory.container_reachable(candidate):
		return false
	var category: int = _inventory.item_category(_inventory.lot_item_id(lot))
	if (_inventory.container_filters(candidate) >> category) & 1 != 1:
		return false
	return _inventory.container_free_mass_g(candidate) >= charge_g


func _is_live_building(owner: Vector2i) -> bool:
	"""Whether a container owner is a live Building in the settlement directory."""
	return _buildings.directory().is_valid_of_kind(owner, EntityDirectory.KIND_BUILDING)


func _ground_fallback_into(source_lot: Vector2i, payload_milli: int, out: Destination) -> bool:
	"""R2: prove the payload fits ground piles from the source building's seeds; reserve nothing."""
	_write_spec(source_lot, payload_milli)
	if _seed_count <= 0 or not _piles.preflight_lots_from_seeds(_seeds, _seed_count,
			PackedByteArray(), _spec, _place):
		return _refuse_into(out, REFUSE_NO_DESTINATION)
	for index: int in _seed_count:
		if _piles.ground_pile_tile_refusal(_seeds[index]) == GroundPilesScript.REFUSE_NONE:
			out.kind = DESTINATION_GROUND
			out.tile = _seeds[index]
			out.charge_g = 0
			return true
	return _refuse_into(out, REFUSE_NO_DESTINATION)


func _write_spec(source_lot: Vector2i, payload_milli: int) -> void:
	"""One placement row carrying the source lot's own attributes and the payload quantity."""
	_spec[GroundPilesScript.SPEC_ITEM] = _inventory.lot_item_id(source_lot)
	_spec[GroundPilesScript.SPEC_QUANTITY] = payload_milli
	_spec[GroundPilesScript.SPEC_QUALITY] = _inventory.lot_quality(source_lot)
	_spec[GroundPilesScript.SPEC_PROVENANCE] = _inventory.lot_provenance(source_lot)
	_spec[GroundPilesScript.SPEC_RECIPE] = _inventory.lot_recipe_id(source_lot)
	_spec[GroundPilesScript.SPEC_AGE] = _inventory.lot_age_milli_hours(source_lot)
	_spec[GroundPilesScript.SPEC_AGE_REMAINDER] = _inventory.lot_age_remainder(source_lot)


func _refuse_into(out: Destination, code: StringName) -> bool:
	"""Clear `out`, leave `code` in `_math.error` for the caller, and answer false."""
	out.clear()
	_math.refuse(String(code))
	return false


func last_refusal() -> StringName:
	"""The code behind the last false `select_destination_into()` or sizing read."""
	return StringName(_math.error)


# --- admission: REQ-SET-030's all-or-nothing reservation -------------------------------------

func admit(job_ref: Vector2i, hauler_slot: int, source_lot: Vector2i, requested_milli: int,
		expiry_tick: int) -> InventoryScript.OpResult:
	"""Accept one haul: size its payload, choose its destination and reserve both, or nothing.

	The payload is the most of `requested_milli` the lot can spare that the hauler's species
	carry limit takes (REQ-SET-111). A store destination's grams are reserved first, then the
	HAUL_SOURCE claim; a refused claim releases the grams again, so a refusal leaves Inventory and
	the pool exactly as they were and REQ-SET-031's cause is the refusal code. `expiry_tick` is
	the claim's lease (REQ-SET-032). `.ref` is the source lot, `.value` the payload.
	"""
	var ready: StringName = _admission_refusal(job_ref, hauler_slot, source_lot, requested_milli)
	if ready != REFUSE_NONE:
		return _refuse(ready)
	var payload: int = _math.value
	if not select_destination_into(source_lot, payload, _chosen):
		return _refuse(last_refusal())
	if _chosen.kind == DESTINATION_STORE:
		var held: InventoryScript.OpResult = _inventory.reserve_container_mass(_chosen.container,
			_chosen.charge_g)
		if not held.ok:
			return held
	var claimed: InventoryScript.OpResult = _claim_source(job_ref, source_lot, payload, expiry_tick)
	if not claimed.ok:
		_unreserve_chosen()
		return claimed
	_write_record(job_ref)
	return InventoryScript.OpResult.new(true, REFUSE_NONE, source_lot, payload)


func _admission_refusal(job_ref: Vector2i, hauler_slot: int, source_lot: Vector2i,
		requested_milli: int) -> StringName:
	"""Every admission precondition; leaves the sized payload in `_math.value` on REFUSE_NONE."""
	if _inventory == null:
		return REFUSE_NOT_BOUND
	if _inventory.is_transaction_open():
		return REFUSE_TRANSACTION_OPEN
	var job: StringName = _job_key_refusal(job_ref)
	if job != REFUSE_NONE:
		return job
	if _job_generation[job_ref.x] != 0:
		return REFUSE_JOB_ADMITTED
	if not _inventory.is_lot_valid(source_lot) or _inventory.is_lot_equipped(source_lot):
		return REFUSE_SOURCE_LOT
	if requested_milli <= 0:
		return REFUSE_INVALID_ARGUMENT
	var hauler: StringName = _hauler_refusal(hauler_slot, source_lot)
	if hauler != REFUSE_NONE:
		return hauler
	return _size_refusal(hauler_slot, source_lot, requested_milli)


func _hauler_refusal(hauler_slot: int, source_lot: Vector2i) -> StringName:
	"""A present hauler, who must own the satchel when the source is one."""
	if not _residents.is_present(hauler_slot):
		return REFUSE_HAULER_ABSENT
	var source: Vector2i = _inventory.lot_container(source_lot)
	if _inventory.is_satchel(source) \
			and _inventory.container_owner(source) != _residents.ref_of(hauler_slot):
		return REFUSE_NOT_HAULERS_SATCHEL
	return REFUSE_NONE


func _size_refusal(hauler_slot: int, source_lot: Vector2i, requested_milli: int) -> StringName:
	"""Size the payload into `_math.value`: REQ-SET-111 against the hauler's carry limit."""
	var size: IntMath.IntResult = _residents.size_class_of(hauler_slot)
	var carry: IntMath.IntResult = _residents.size_carry_g(size.value) if size.ok else size
	if not carry.ok or carry.value <= 0:
		return REFUSE_CARRY_LIMIT
	var available: int = mini(requested_milli, _inventory.lot_available_milli(source_lot))
	var mass: int = _inventory.item_mass_g(_inventory.lot_item_id(source_lot))
	if not payload_milli_into(available, mass, carry.value, 0, _math):
		return StringName(_math.error)
	return REFUSE_NOTHING_TO_HAUL if _math.value <= 0 else REFUSE_NONE


func _claim_source(job_ref: Vector2i, source_lot: Vector2i, payload: int,
		expiry_tick: int) -> InventoryScript.OpResult:
	"""The HAUL_SOURCE claim on the payload, through the pool's own all-or-nothing batch."""
	_claim[ReservationsScript.CLAIM_LOT_SLOT] = source_lot.x
	_claim[ReservationsScript.CLAIM_LOT_GENERATION] = source_lot.y
	_claim[ReservationsScript.CLAIM_PURPOSE] = ReservationsScript.PURPOSE_HAUL_SOURCE
	_claim[ReservationsScript.CLAIM_QUANTITY_MILLI] = payload
	_claim[ReservationsScript.CLAIM_EXPIRY] = expiry_tick
	return _reservations.claim_batch(job_ref, _claim, 1, _inventory)


func _unreserve_chosen() -> void:
	"""Give back the grams `admit()` reserved before its claim refused. Restores them exactly."""
	if _chosen.kind == DESTINATION_STORE:
		_inventory.release_container_mass(_chosen.container, _chosen.charge_g)


func _write_record(job_ref: Vector2i) -> void:
	"""Record the admitted destination on the job's row."""
	var row: int = job_ref.x
	_job_generation[row] = job_ref.y
	_dest_slot[row] = _chosen.container.x
	_dest_generation[row] = _chosen.container.y
	_dest_tile[row] = _chosen.tile
	_reserved_g[row] = _chosen.charge_g


# --- after admission ------------------------------------------------------------------------

func is_admitted(job_ref: Vector2i) -> bool:
	"""Whether this exact job (slot and generation) holds an admission record."""
	return _job_key_refusal(job_ref) == REFUSE_NONE and _job_generation[job_ref.x] == job_ref.y


func destination_kind_of(job_ref: Vector2i) -> int:
	"""DESTINATION_STORE, DESTINATION_GROUND, or DESTINATION_NONE for no admission."""
	if not is_admitted(job_ref):
		return DESTINATION_NONE
	return DESTINATION_STORE if _dest_slot[job_ref.x] != InventoryScript.NULL_SLOT \
		else DESTINATION_GROUND


func destination_of(job_ref: Vector2i) -> Vector2i:
	"""The admitted destination store, or the null ref (no admission, or ground piles)."""
	if not is_admitted(job_ref):
		return NULL_REF
	return Vector2i(_dest_slot[job_ref.x], _dest_generation[job_ref.x])


func destination_tile_of(job_ref: Vector2i) -> int:
	"""The tile the hauler unloads at, or NO_TILE without an admission."""
	return _dest_tile[job_ref.x] if is_admitted(job_ref) else NO_TILE


func reserved_g_of(job_ref: Vector2i) -> int:
	"""Grams the admission holds in its destination store; 0 for piles or no admission."""
	return _reserved_g[job_ref.x] if is_admitted(job_ref) else 0


func complete_unload(job_ref: Vector2i, hauler_slot: int,
		carry: HaulCarryScript) -> InventoryScript.OpResult:
	"""The haul's unload, done through its OWN record, which it then retires.

	A store destination unloads into the recorded store, releasing exactly the recorded grams in
	the same transaction; a ground destination unloads breadth-first from the recorded tile. The
	record is cleared only after the unload succeeded, so no later `cancel()` can release grams the
	delivery already gave back (the record is the one authority on which grams are this job's).
	A store that can no longer take the goods refuses; the caller cancels and re-admits.
	"""
	if not is_admitted(job_ref):
		return _refuse(REFUSE_JOB_NOT_ADMITTED)
	var row: int = job_ref.x
	var unloaded: InventoryScript.OpResult = null
	if destination_kind_of(job_ref) == DESTINATION_STORE:
		unloaded = carry.unload_into_store(job_ref, hauler_slot, destination_of(job_ref),
			_reserved_g[row])
	else:
		_one_seed[0] = _dest_tile[row]
		unloaded = carry.unload_into_piles(job_ref, hauler_slot, _one_seed, 1, PackedByteArray())
	if unloaded.ok:
		_clear_row(row)
	return unloaded


func cancel(job_ref: Vector2i) -> InventoryScript.OpResult:
	"""Release an admitted haul: its destination grams, every claim the job holds, its record.

	Before the load this returns the source claim; after it, the HAUL_DESTINATION claim on the
	satchel lot goes and the goods stay in the satchel, unclaimed, for the fresh haul the ruling
	posts. Proved first, written after: the grams must still be held, and the pool's own release
	is all-or-nothing. `.value` is the claim rows released. After `complete_unload()` the record
	is gone, so a late cancel refuses instead of releasing grams the delivery already returned.
	Every path that ends a haul early -- cancellation, the hauler's death or departure (cancel,
	then `haul_carry.drop_satchel()`), and a lease the pool expired -- must come through here, or
	the record's grams stay reserved in the store.
	"""
	var ready: StringName = _cancel_refusal(job_ref)
	if ready != REFUSE_NONE:
		return _refuse(ready)
	var released: InventoryScript.OpResult = _reservations.release_job_claims(job_ref, _inventory)
	if not released.ok:
		return released
	var row: int = job_ref.x
	if _reserved_g[row] > 0:
		# Cannot refuse: `_cancel_refusal()` proved the store live and holding the grams.
		_inventory.release_container_mass(destination_of(job_ref), _reserved_g[row])
	_clear_row(row)
	return released


func _cancel_refusal(job_ref: Vector2i) -> StringName:
	"""An admitted job whose recorded grams its store still holds, with no transaction open."""
	if _inventory == null:
		return REFUSE_NOT_BOUND
	if not is_admitted(job_ref):
		return REFUSE_JOB_NOT_ADMITTED
	if _inventory.is_transaction_open():
		return REFUSE_TRANSACTION_OPEN
	var grams: int = _reserved_g[job_ref.x]
	if grams <= 0:
		return REFUSE_NONE
	var store: Vector2i = destination_of(job_ref)
	if not _inventory.is_container_valid(store) \
			or _inventory.container_reserved_mass_g(store) < grams:
		return InventoryScript.REFUSE_INSUFFICIENT_RESERVED_MASS
	return REFUSE_NONE


func audit() -> StringName:
	"""NOT A PRODUCTION CALL: every store a record names is live and holds the records' grams.

	Inventory's `reserved_mass_g` is anonymous, so this is the one check that the record and the
	stores agree: for each store, the sum of the grams every admitted record holds there must not
	exceed what the store has reserved. A record whose grams went back without the record being
	cleared, or a release that took another job's grams, shows up here. O(rows x stores); tests
	and save checks only.
	"""
	for row: int in JOB_CAPACITY:
		if _job_generation[row] == 0 or _reserved_g[row] <= 0:
			continue
		var store: Vector2i = Vector2i(_dest_slot[row], _dest_generation[row])
		if not _inventory.is_container_valid(store):
			return REFUSE_AUDIT_STORE
		if _first_row_holding(store) == row \
				and _grams_recorded_on(store) > _inventory.container_reserved_mass_g(store):
			return REFUSE_AUDIT_GRAMS
	return REFUSE_NONE


func _first_row_holding(store: Vector2i) -> int:
	"""The lowest record row holding grams in `store`."""
	for row: int in JOB_CAPACITY:
		if _job_generation[row] != 0 and _reserved_g[row] > 0 and _dest_slot[row] == store.x \
				and _dest_generation[row] == store.y:
			return row
	return -1


func _grams_recorded_on(store: Vector2i) -> int:
	"""The sum of every admitted record's grams in `store`."""
	var total: int = 0
	for row: int in JOB_CAPACITY:
		if _job_generation[row] != 0 and _dest_slot[row] == store.x \
				and _dest_generation[row] == store.y:
			total += _reserved_g[row]
	return total


func _clear_row(row: int) -> void:
	"""Return one record row to "no admission"."""
	_job_generation[row] = 0
	_dest_slot[row] = InventoryScript.NULL_SLOT
	_dest_generation[row] = InventoryScript.NULL_GENERATION
	_dest_tile[row] = NO_TILE
	_reserved_g[row] = 0


func _job_key_refusal(job_ref: Vector2i) -> StringName:
	"""The pool's own Job key shape: slot in range, a positive generation."""
	if job_ref.x < 0 or job_ref.x >= JOB_CAPACITY or job_ref.y <= 0:
		return REFUSE_JOB_RANGE
	return REFUSE_NONE


func _refuse(code: StringName) -> InventoryScript.OpResult:
	"""An explicit refusal in Inventory's result shape, carrying no ref and no value."""
	return InventoryScript.OpResult.new(false, code, NULL_REF, 0)


func record_bytes() -> int:
	"""Bytes the record's five columns hold: the §3 row decision 1023 adds."""
	return _job_generation.size() * 4 + _dest_slot.size() * 4 + _dest_generation.size() * 4 \
		+ _dest_tile.size() * 4 + _reserved_g.size() * 8


func scratch_bytes() -> int:
	"""Bytes of cold-path scratch: the §2.3 row decision 1023 adds."""
	return _footprint.size() + _outside.size() + _seeds.size() * 4 + _spec.size() * 8 \
		+ _claim.size() * 8 + _one_seed.size() * 4
