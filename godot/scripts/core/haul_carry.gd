extends RefCounted
## Task 06.4 slice H1 (decision 1022): the haul's physical carry -- load, unload, and the drop.
##
## Brendan's rulings of 2026-10-02 fix the shape this file composes:
##   * A SATCHEL IS MADE PER HAUL (option b). The load creates it, sized to the hauler's species
##     carry limit (GDD §5.2: 12000/16000/24000 g by size class), unplaced and owned by the
##     resident; whatever empties it destroys it. `residents.gd`'s `Equipment.satchel` pair mirrors
##     it while it lives -- that pair had no caller until now.
##   * WORK covers the load at the source contact; HAUL_OUTPUT covers the carry and the unload.
##     This file is the two instantaneous state changes at either end; WHEN they happen (after
##     2000 milli-WU each, BAL-CAT-010) is the job layer's, slice H4.
##   * A hauler that dies or departs while carrying drops the satchel's contents as a ground pile
##     at its tile under DEC-043 #9's rules, and the satchel is destroyed.
##   * A haul cancelled mid-carry keeps its goods in the satchel; the fresh haul posted for them
##     names the satchel as its source, and its "load" re-keys the claim where it stands.
##
## THE GOODS NEVER TELEPORT AND ARE NEVER CLONED (INV-GOODS-R01, BAL-SAFE-002, REQ-SET-111). Every
## move is Inventory's own `move_lot()`/`transfer()`, so a lot in transit is in exactly one
## container -- the source, then the satchel, then the destination -- and `audit()`'s conservation
## identity is untouched by a haul: nothing is sourced or sunk. The CLAIM moves with the goods in
## the same transaction (`reservations.gd`'s carry doors): HAUL_SOURCE on the source lot until the
## load, HAUL_DESTINATION on the satchel lot until the unload.
##
## THE TWO PILE PATHS ARE TWO TRANSACTIONS, AND SAY SO. The pool cannot join an inventory
## transaction (its rows are not journaled there), so an unload onto ground piles and a drop
## release the claim through the pool and then move the goods through `ground_piles.gd`. Both
## first run that mover's preflight with the claims still standing (it asks as if every claim
## were released). The drop releases every claim on the satchel, so its move sees exactly what
## the preflight saw. The unload releases only ITS job's claim: if another job also claims the
## carried lot (a second haul admitted against the same satchel goods), the move refuses the
## still-claimed source and the unload re-claims what it released -- restoring the pool's
## canonical image exactly (`test_a_second_claim_on_the_satchel_lot_rolls_the_unload_back`).
##
## CALLERS UNLOAD THROUGH THE PLANNER. `haul_planner.complete_unload()` is the door the job layer
## uses: it passes this file the recorded destination and grams and retires the record with the
## delivery. Calling the two unloads below directly and then `haul_planner.cancel()` would release
## the destination grams twice (decision 1023, review H1).
##
## NO STATE OF ITS OWN. Every authoritative fact lives in Inventory, the reservation pool and the
## resident store, all of which already save; the columns below are cold-path scratch.

const IntMath := preload("res://scripts/core/int_math.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ReservationsScript := preload("res://scripts/core/reservations.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const GroundPilesScript := preload("res://scripts/core/ground_piles.gd")

const NULL_REF: Vector2i = InventoryScript.NULL_REF
const HAUL_SOURCE: int = ReservationsScript.PURPOSE_HAUL_SOURCE
const HAUL_DESTINATION: int = ReservationsScript.PURPOSE_HAUL_DESTINATION

const REFUSE_NONE: StringName = &""
const REFUSE_NOT_BOUND: StringName = &"HAUL_CARRY_NOT_BOUND"
const REFUSE_HAULER_ABSENT: StringName = &"HAUL_HAULER_NOT_PRESENT"
## BAL-SAFE-002's "one container in transit": a hauler already carrying a satchel loads nothing
## new into a second one.
const REFUSE_ALREADY_CARRYING: StringName = &"HAUL_HAULER_ALREADY_CARRYING"
const REFUSE_NOT_CARRYING: StringName = &"HAUL_HAULER_NOT_CARRYING"
## The resident's satchel pair names no live satchel this resident owns.
const REFUSE_SATCHEL_STALE: StringName = &"HAUL_SATCHEL_STALE"
## The claimed lot sits in another resident's satchel: only its owner carries it.
const REFUSE_NOT_HAULERS_SATCHEL: StringName = &"HAUL_SATCHEL_NOT_THE_HAULERS"
const REFUSE_NO_CLAIM: StringName = &"HAUL_NO_SUCH_CLAIM"
## REQ-SET-111, re-proved at load: the claimed payload's per-lot ceiling mass exceeds the
## hauler's species carry limit.
const REFUSE_OVER_CARRY: StringName = &"HAUL_PAYLOAD_EXCEEDS_CARRY"
const REFUSE_CARRY_LIMIT: StringName = &"HAUL_CARRY_LIMIT_UNAVAILABLE"
const REFUSE_OVERFLOW: StringName = &"HAUL_ARITHMETIC_OVERFLOW"
const REFUSE_TRANSACTION_OPEN: StringName = &"HAUL_INVENTORY_TRANSACTION_OPEN"

var _inventory: InventoryScript = null
var _reservations: ReservationsScript = null
var _residents: ResidentsScript = null
var _piles: GroundPilesScript = null

## Cold-path scratch: checked arithmetic, a claim's lease, and the pile mover's outcome.
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _expiry: IntMath.IntResult = IntMath.IntResult.new()
var _place: GroundPilesScript.PlaceResult = GroundPilesScript.PlaceResult.new()
## One re-claim record for the unreachable pile-unload rollback (ReservationsScript.CLAIM_STRIDE).
var _reclaim: PackedInt64Array = PackedInt64Array()


func _init() -> void:
	"""Allocate the scratch once."""
	_reclaim.resize(ReservationsScript.CLAIM_STRIDE)


func bind(inventory: InventoryScript, reservations: ReservationsScript,
		residents: ResidentsScript, piles: GroundPilesScript) -> bool:
	"""Borrow the four stores a haul's carry touches. False, binding nothing, when one is null."""
	if inventory == null or reservations == null or residents == null or piles == null:
		return false
	_inventory = inventory
	_reservations = reservations
	_residents = residents
	_piles = piles
	return true


# --- reads ----------------------------------------------------------------------------------

func carry_limit_g_into(hauler_slot: int, out: IntMath.IntResult) -> bool:
	"""The hauler's species carry limit in grams (GDD §5.2 by size class), read from Residents."""
	if _residents == null:
		return out.refuse(String(REFUSE_NOT_BOUND))
	if not _residents.is_present(hauler_slot):
		return out.refuse(String(REFUSE_HAULER_ABSENT))
	var size: IntMath.IntResult = _residents.size_class_of(hauler_slot)
	var carry: IntMath.IntResult = _residents.size_carry_g(size.value) if size.ok else size
	if not carry.ok or carry.value <= 0:
		return out.refuse(String(REFUSE_CARRY_LIMIT))
	return out.succeed(carry.value)


func satchel_of(hauler_slot: int) -> Vector2i:
	"""The live satchel the hauler carries, or the null ref (none, or a stale pair)."""
	if _residents == null or _inventory == null:
		return NULL_REF
	var satchel: Vector2i = _residents.satchel_of(hauler_slot)
	return satchel if _owns_live_satchel(hauler_slot, satchel) else NULL_REF


func carried_lot(hauler_slot: int) -> Vector2i:
	"""The first lot in the hauler's satchel -- one item lot per haul (H2) -- or the null ref."""
	var satchel: Vector2i = satchel_of(hauler_slot)
	return NULL_REF if satchel == NULL_REF else _inventory.container_first_lot(satchel)


func _owns_live_satchel(hauler_slot: int, satchel: Vector2i) -> bool:
	"""Whether `satchel` is a live satchel row owned by this present resident."""
	return satchel != NULL_REF and _inventory.is_satchel(satchel) \
		and _inventory.container_owner(satchel) == _residents.ref_of(hauler_slot)


# --- load -----------------------------------------------------------------------------------

func load_payload(job_ref: Vector2i, hauler_slot: int,
		source_lot: Vector2i) -> InventoryScript.OpResult:
	"""The load that ends WORK at the source: the job's HAUL_SOURCE claim goes into a new satchel.

	Re-proves REQ-SET-111 against the hauler's carry limit, then mints the satchel and moves the
	claimed quantity into it in ONE inventory transaction (`load_claim_into_new_satchel()`), the
	claim arriving as HAUL_DESTINATION; only then does the resident's satchel pair name it. When
	the claimed lot already sits in this hauler's own satchel -- a re-posted haul -- nothing
	moves and the claim is re-keyed. `.ref` is the carried lot, `.value` its quantity.
	"""
	var refusal: StringName = _load_refusal(job_ref, hauler_slot, source_lot)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	var carry_g: int = _math.value
	if satchel_of(hauler_slot) != NULL_REF:
		return _reservations.repurpose_claim(job_ref, source_lot, HAUL_SOURCE, HAUL_DESTINATION)
	var loaded: InventoryScript.OpResult = _reservations.load_claim_into_new_satchel(job_ref,
		source_lot, HAUL_SOURCE, _residents.ref_of(hauler_slot), carry_g, HAUL_DESTINATION,
		_inventory)
	if not loaded.ok:
		return loaded
	# Cannot refuse: the resident was proved present and the satchel ref is freshly minted.
	_residents.set_satchel(hauler_slot, _inventory.lot_container(loaded.ref))
	return loaded


func _load_refusal(job_ref: Vector2i, hauler_slot: int, source_lot: Vector2i) -> StringName:
	"""Every load precondition; leaves the carry limit in `_math.value` on REFUSE_NONE."""
	var ready: StringName = _hauler_refusal(hauler_slot)
	if ready != REFUSE_NONE:
		return ready
	var quantity: int = _reservations.claim_quantity_milli(job_ref, source_lot, HAUL_SOURCE)
	if quantity <= 0 or not _inventory.is_lot_valid(source_lot):
		return REFUSE_NO_CLAIM
	var ready_satchel: StringName = _load_satchel_refusal(hauler_slot, source_lot)
	if ready_satchel != REFUSE_NONE:
		return ready_satchel
	if not IntMath.inventory_capacity_debit_g_into(quantity,
			_inventory.item_mass_g(_inventory.lot_item_id(source_lot)), _math):
		return REFUSE_OVERFLOW
	var debit: int = _math.value
	if not carry_limit_g_into(hauler_slot, _math):
		return StringName(_math.error)
	return REFUSE_OVER_CARRY if debit > _math.value else REFUSE_NONE


func _load_satchel_refusal(hauler_slot: int, source_lot: Vector2i) -> StringName:
	"""A hauler loads into a NEW satchel, or re-keys goods already in its own one -- nothing else."""
	var held: Vector2i = _residents.satchel_of(hauler_slot)
	var container: Vector2i = _inventory.lot_container(source_lot)
	if held == NULL_REF:
		return REFUSE_NOT_HAULERS_SATCHEL if _inventory.is_satchel(container) else REFUSE_NONE
	if not _owns_live_satchel(hauler_slot, held):
		return REFUSE_SATCHEL_STALE
	return REFUSE_NONE if container == held else REFUSE_ALREADY_CARRYING


func _hauler_refusal(hauler_slot: int) -> StringName:
	"""Bound, no caller transaction open, and a present hauler."""
	if _inventory == null:
		return REFUSE_NOT_BOUND
	if _inventory.is_transaction_open():
		return REFUSE_TRANSACTION_OPEN
	if not _residents.is_present(hauler_slot):
		return REFUSE_HAULER_ABSENT
	return REFUSE_NONE


# --- unload ---------------------------------------------------------------------------------

func unload_into_store(job_ref: Vector2i, hauler_slot: int, destination: Vector2i,
		reserved_g: int) -> InventoryScript.OpResult:
	"""The unload that ends HAUL_OUTPUT at a store: deliver the carried lot, free the satchel.

	`reserved_g` is the destination headroom H2 reserved for this payload; it is released in the
	same transaction as the move, and the emptied satchel is destroyed in it too
	(`deliver_claim()`). The resident's satchel pair is cleared once the satchel is gone. `.ref`
	is the delivered lot, `.value` its quantity.
	"""
	var refusal: StringName = _carrying_refusal(job_ref, hauler_slot)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	var satchel: Vector2i = satchel_of(hauler_slot)
	var delivered: InventoryScript.OpResult = _reservations.deliver_claim(job_ref,
		carried_lot(hauler_slot), HAUL_DESTINATION, destination, reserved_g, _inventory)
	if delivered.ok:
		_clear_if_retired(hauler_slot, satchel)
	return delivered


func unload_into_piles(job_ref: Vector2i, hauler_slot: int, seeds: PackedInt32Array,
		seed_count: int, excluded_mask: PackedByteArray) -> InventoryScript.OpResult:
	"""The unload onto ground piles: R2's fallback when no store could take the payload.

	The pile walk is proved with the claim still standing, the claim is released, the goods move
	breadth-first from `seeds` (DEC-043 #9), and the emptied satchel is destroyed. Every lot in
	the satchel moves (one item lot per haul, R-H6). `.value` is the job's claimed quantity; `.ref`
	the null ref, because the goods may now span several piles.
	"""
	var refusal: StringName = _carrying_refusal(job_ref, hauler_slot)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	var satchel: Vector2i = satchel_of(hauler_slot)
	var lot: Vector2i = carried_lot(hauler_slot)
	if not _piles.preflight_container_into_piles(satchel, seeds, seed_count, excluded_mask, _place):
		return _refuse(_place.error)
	var quantity: int = _reservations.claim_quantity_milli(job_ref, lot, HAUL_DESTINATION)
	_reservations.claim_expiry_into(job_ref, lot, HAUL_DESTINATION, _expiry)
	var released: InventoryScript.OpResult = _reservations.release_claim(job_ref, lot,
		HAUL_DESTINATION, _inventory)
	if not released.ok:
		return released
	if not _piles.move_container_into_piles(satchel, seeds, seed_count, excluded_mask, _place):
		_reclaim_after_refused_move(job_ref, lot, released.value)
		return _refuse(_place.error)
	return _retire_satchel(hauler_slot, satchel, quantity)


func _carrying_refusal(job_ref: Vector2i, hauler_slot: int) -> StringName:
	"""A present hauler carrying a live satchel whose lot this job claims for its destination."""
	var ready: StringName = _hauler_refusal(hauler_slot)
	if ready != REFUSE_NONE:
		return ready
	var held: Vector2i = _residents.satchel_of(hauler_slot)
	if held == NULL_REF:
		return REFUSE_NOT_CARRYING
	if not _owns_live_satchel(hauler_slot, held):
		return REFUSE_SATCHEL_STALE
	var lot: Vector2i = _inventory.container_first_lot(held)
	if lot == NULL_REF or not _reservations.has_claim(job_ref, lot, HAUL_DESTINATION):
		return REFUSE_NO_CLAIM
	return REFUSE_NONE


func _reclaim_after_refused_move(job_ref: Vector2i, lot: Vector2i, quantity: int) -> void:
	"""Unreachable guard: put back the claim a refused pile move left released."""
	_reclaim[ReservationsScript.CLAIM_LOT_SLOT] = lot.x
	_reclaim[ReservationsScript.CLAIM_LOT_GENERATION] = lot.y
	_reclaim[ReservationsScript.CLAIM_PURPOSE] = HAUL_DESTINATION
	_reclaim[ReservationsScript.CLAIM_QUANTITY_MILLI] = quantity
	_reclaim[ReservationsScript.CLAIM_EXPIRY] = _expiry.value if _expiry.ok else 0
	_reservations.claim_batch(job_ref, _reclaim, 1, _inventory)


# --- the drop: death or departure -----------------------------------------------------------

func drop_satchel(hauler_slot: int, seeds: PackedInt32Array,
		seed_count: int) -> InventoryScript.OpResult:
	"""Empty a dying or departing hauler's satchel onto ground piles and destroy it.

	Call it BEFORE the resident's row is despawned: the row's satchel pair is how the satchel is
	found, and a despawned row must not leave an owned container behind. `seeds` come from
	`ground_piles.drop_seeds_into()` for the resident's tile. Every claim on the satchel's lots is
	released -- they belonged to a haul the death cancels -- after the pile walk is proved. The
	caller cancels the haul through `haul_planner.cancel()` first, so its destination grams go
	back too. A hauler carrying nothing answers ok with `.value` 0; otherwise `.value` counts
	the lots or lot parts that arrived on piles.
	"""
	var ready: StringName = _hauler_refusal(hauler_slot)
	if ready != REFUSE_NONE:
		return _refuse(ready)
	var held: Vector2i = _residents.satchel_of(hauler_slot)
	if held == NULL_REF:
		return InventoryScript.OpResult.new(true, REFUSE_NONE, NULL_REF, 0)
	if not _owns_live_satchel(hauler_slot, held):
		return _refuse(REFUSE_SATCHEL_STALE)
	if _inventory.container_lot_count(held) == 0:
		return _retire_satchel(hauler_slot, held, 0)
	if not _piles.preflight_container_into_piles(held, seeds, seed_count, PackedByteArray(), _place):
		return _refuse(_place.error)
	var released: StringName = _release_satchel_claims(held)
	if released != REFUSE_NONE:
		return _refuse(released)
	if not _piles.move_container_into_piles(held, seeds, seed_count, PackedByteArray(), _place):
		return _refuse(_place.error)
	return _retire_satchel(hauler_slot, held, _place.lots_created)


func _release_satchel_claims(satchel: Vector2i) -> StringName:
	"""Release every claim on every lot in the satchel, lot by lot, in list order."""
	var lot: Vector2i = _inventory.container_first_lot(satchel)
	while lot != NULL_REF:
		var released: InventoryScript.OpResult = _reservations.release_lot_claims(lot, _inventory)
		if not released.ok:
			return released.error
		lot = _inventory.container_next_lot(lot)
	return REFUSE_NONE


# --- shared ---------------------------------------------------------------------------------

func _retire_satchel(hauler_slot: int, satchel: Vector2i,
		value: int) -> InventoryScript.OpResult:
	"""Destroy the emptied satchel and clear the resident's pair; `value` is reported back."""
	var destroyed: InventoryScript.OpResult = _inventory.destroy_satchel(satchel)
	if not destroyed.ok:
		return destroyed
	_residents.set_satchel(hauler_slot, NULL_REF)
	return InventoryScript.OpResult.new(true, REFUSE_NONE, NULL_REF, value)


func _clear_if_retired(hauler_slot: int, satchel: Vector2i) -> void:
	"""Clear the resident's satchel pair once the satchel row it names is gone."""
	if not _inventory.is_container_valid(satchel):
		_residents.set_satchel(hauler_slot, NULL_REF)


func _refuse(code: StringName) -> InventoryScript.OpResult:
	"""An explicit refusal in Inventory's result shape, carrying no ref and no value."""
	return InventoryScript.OpResult.new(false, code, NULL_REF, 0)
