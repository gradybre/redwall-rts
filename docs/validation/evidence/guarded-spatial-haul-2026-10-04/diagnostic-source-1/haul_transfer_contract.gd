extends RefCounted
## ADR1141: one final observation over an original, pool-issued Inventory transaction.
## This protocol imports no economic/spatial owner. Its base grants no transfer permission.

const ADMIT: int = 0
const LOAD: int = 1
const REPOST: int = 2
const UNLOAD: int = 3
const CANCEL: int = 4
const NULL_REF: Vector2i = Vector2i(-1, 0)
const TRANSFER_BYTES: int = 216
const REFUSE_UNBOUND: StringName = &"HAUL_TRANSFER_UNBOUND"
const REFUSE_SCOPE: StringName = &"HAUL_TRANSFER_SCOPE_STALE"
const REFUSE_REENTRY: StringName = &"HAUL_TRANSFER_REENTRY"
const REFUSE_PACKET: StringName = &"HAUL_TRANSFER_PACKET_CHANGED"
const REFUSE_CLAIM: StringName = &"HAUL_TRANSFER_CLAIM_CHANGED"

class Transfer extends RefCounted:
	var job: Vector2i = NULL_REF
	var worker: Vector2i = NULL_REF
	var source_lot: Vector2i = NULL_REF
	var source_container: Vector2i = NULL_REF
	var destination: Vector2i = NULL_REF
	var original_satchel: Vector2i = NULL_REF
	var arrived_lot: Vector2i = NULL_REF
	var staged_satchel: Vector2i = NULL_REF
	var action: int = -1
	var claim_row: int = -1
	var claim_count: int = 0
	var from_purpose: int = 0
	var to_purpose: int = 0
	var quantity_milli: int = 0
	var expiry_tick: int = 0
	var reserved_mass_g: int = 0
	var carry_limit_g: int = 0
	var item_id: int = -1
	var item_mass_g: int = 0
	var quality: int = 0
	var age_milli_hours: int = 0
	var age_remainder: int = 0
	var provenance: int = 0
	var recipe_id: int = 0
	var source_quantity_milli: int = 0
	var source_reserved_milli: int = 0
	var destination_reserved_g: int = 0


func final_transfer_refusal(_transfer: Transfer, _inventory: RefCounted,
		_pool: RefCounted) -> StringName:
	"""The last external observation; concrete Delivery finishes its direct leaves before returning."""
	return REFUSE_UNBOUND


static func copy_into(source: Transfer, out: Transfer) -> void:
	"""Copy a fixed packet, without arrays, reflection or a new object."""
	out.job = source.job
	out.worker = source.worker
	out.source_lot = source.source_lot
	out.source_container = source.source_container
	out.destination = source.destination
	out.original_satchel = source.original_satchel
	out.arrived_lot = source.arrived_lot
	out.staged_satchel = source.staged_satchel
	_copy_scalars(source, out)


static func _copy_scalars(source: Transfer, out: Transfer) -> void:
	"""The nineteen integer values are source/accounting facts, never a second ledger."""
	out.action = source.action
	out.claim_row = source.claim_row
	out.claim_count = source.claim_count
	out.from_purpose = source.from_purpose
	out.to_purpose = source.to_purpose
	out.quantity_milli = source.quantity_milli
	out.expiry_tick = source.expiry_tick
	out.reserved_mass_g = source.reserved_mass_g
	out.carry_limit_g = source.carry_limit_g
	out.item_id = source.item_id
	out.item_mass_g = source.item_mass_g
	out.quality = source.quality
	out.age_milli_hours = source.age_milli_hours
	out.age_remainder = source.age_remainder
	out.provenance = source.provenance
	out.recipe_id = source.recipe_id
	out.source_quantity_milli = source.source_quantity_milli
	out.source_reserved_milli = source.source_reserved_milli
	out.destination_reserved_g = source.destination_reserved_g


static func matches(first: Transfer, other: Transfer) -> bool:
	"""All caller-visible fields must still match the original private packet."""
	return first != null and other != null and first.job == other.job and first.worker == other.worker \
		and first.source_lot == other.source_lot and first.source_container == other.source_container \
		and first.destination == other.destination and first.original_satchel == other.original_satchel \
		and first.arrived_lot == other.arrived_lot and first.staged_satchel == other.staged_satchel \
		and _scalars_match(first, other)


static func _scalars_match(first: Transfer, other: Transfer) -> bool:
	"""Every numeric pin participates, including quantity, lease and destination grams."""
	return first.action == other.action and first.claim_row == other.claim_row \
		and first.claim_count == other.claim_count and first.from_purpose == other.from_purpose \
		and first.to_purpose == other.to_purpose and first.quantity_milli == other.quantity_milli \
		and first.expiry_tick == other.expiry_tick and first.reserved_mass_g == other.reserved_mass_g \
		and first.carry_limit_g == other.carry_limit_g and first.item_id == other.item_id \
		and first.item_mass_g == other.item_mass_g and first.quality == other.quality \
		and first.age_milli_hours == other.age_milli_hours and first.age_remainder == other.age_remainder \
		and first.provenance == other.provenance and first.recipe_id == other.recipe_id \
		and first.source_quantity_milli == other.source_quantity_milli \
		and first.source_reserved_milli == other.source_reserved_milli \
		and first.destination_reserved_g == other.destination_reserved_g


static func scope_refusal(inventory: RefCounted, pool: RefCounted,
		guard: RefCounted, packet: Transfer) -> StringName:
	"""Internal concrete pool scope, checked after the last observer; no provider method dispatch."""
	if inventory == null or pool == null or guard == null or packet == null:
		return REFUSE_UNBOUND
	if not pool._haul_active or pool._haul_inventory != inventory or pool._haul_guard != guard \
		or pool._haul_view != packet or pool._bound_inventory == null \
		or pool._bound_inventory.get_ref() != inventory or not inventory._tx_open:
		return REFUSE_SCOPE
	if pool._haul_error != &"":
		return pool._haul_error
	if not matches(pool._haul_original, packet):
		return REFUSE_PACKET
	return &""


static func claim_refusal(pool: RefCounted, packet: Transfer) -> StringName:
	"""The original claim remains in the Pool until Inventory succeeds; ADMIT still has no row."""
	if packet.job.x < 0 or packet.job.x >= pool._job_capacity or packet.job.y <= 0:
		return REFUSE_CLAIM
	if packet.action == ADMIT:
		return &"" if pool._job_head[packet.job.x] == -1 and pool._free_count > 0 \
			and pool._free_heap[0] == packet.claim_row else REFUSE_CLAIM
	if pool._job_head[packet.job.x] != packet.claim_row:
		return REFUSE_CLAIM
	if packet.action == CANCEL:
		return _cancel_claims_refusal(pool, packet)
	var row: int = packet.claim_row
	if row < 0 or row >= pool._row_capacity or pool._occupied[row] != 1:
		return REFUSE_CLAIM
	return &"" if Vector2i(pool._r_job_slot[row], pool._r_job_generation[row]) == packet.job \
		and Vector2i(pool._r_lot_slot[row], pool._r_lot_generation[row]) == packet.source_lot \
		and pool._r_purpose[row] == packet.from_purpose and pool._r_quantity_milli[row] == packet.quantity_milli \
		and pool._r_expiry[row] == packet.expiry_tick and pool._job_next[row] == -1 else REFUSE_CLAIM


static func _cancel_claims_refusal(pool: RefCounted, packet: Transfer) -> StringName:
	"""Cancellation reads the bounded original chain, without allocating a second claim image."""
	var row: int = packet.claim_row
	var count: int = 0
	while row != -1:
		if row < 0 or row >= pool._row_capacity or count >= pool._row_capacity \
			or pool._occupied[row] != 1 or pool._r_quantity_milli[row] <= 0 \
			or Vector2i(pool._r_job_slot[row], pool._r_job_generation[row]) != packet.job:
			return REFUSE_CLAIM
		count += 1
		row = pool._job_next[row]
	return &"" if count == packet.claim_count else REFUSE_CLAIM


static func lot_live(inventory: RefCounted, ref: Vector2i) -> bool:
	"""Exact actual Inventory lot columns, with no public observer dispatch."""
	return ref.x >= 0 and ref.x < inventory._l_capacity and ref.y > 0 \
		and inventory._l_live[ref.x] == 1 and inventory._l_generation[ref.x] == ref.y


static func container_live(inventory: RefCounted, ref: Vector2i) -> bool:
	"""Exact actual Inventory container columns, with no public observer dispatch."""
	return ref.x >= 0 and ref.x < inventory._c_capacity and ref.y > 0 \
		and inventory._c_live[ref.x] == 1 and inventory._c_generation[ref.x] == ref.y


static func satchel_matches(inventory: RefCounted, ref: Vector2i, worker: Vector2i) -> bool:
	"""Only the real worker-owned unplaced satchel can be the staged load container."""
	return container_live(inventory, ref) and inventory._c_policy[ref.x] == inventory.POLICY_SATCHEL \
		and inventory._c_anchor_tile[ref.x] == inventory.UNPLACED_TILE \
		and Vector2i(inventory._c_owner_slot[ref.x], inventory._c_owner_generation[ref.x]) == worker
