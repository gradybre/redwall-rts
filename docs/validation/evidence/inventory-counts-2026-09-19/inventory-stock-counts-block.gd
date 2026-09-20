## INIT-COUNT-R01v2 (decision 0159): a cold, read-only whole-inventory stock count.
##
## `StockCounts` is a caller-owned record of four independent ITEM_CAPACITY-length
## PackedInt64Array buffers. `copy_stock_counts_into()` stages a fresh set of these buffers,
## validates and checked-accumulates a single ascending pass over live lot rows, and on
## success ADOPTS the staging buffers into the caller's target by field reassignment --
## never by copying elements into a target that may already be aliased. Nothing here calls
## `_attests`, `_audit_lot_placement`, `audit()` or any collaborator; nothing here writes an
## owner field, including the existing `_math`/`_plan`/`_out_ref`/`_out_value` scratch, any
## diagnostic, a transaction flag, or `_attesting`. This is a cold presentation read, not a
## per-tick or per-resident simulation operation; see the contract's evidence obligations for
## the aliasing, ordering and byte-identical-source requirements this method must satisfy.
const REFUSE_STOCK_COUNTS_SHAPE: StringName = &"INV_STOCK_COUNTS_SHAPE"
const REFUSE_STOCK_COUNTS_BUSY: StringName = &"INV_STOCK_COUNTS_BUSY"
const REFUSE_STOCK_COUNTS_STATE: StringName = &"INV_STOCK_COUNTS_STATE"
const REFUSE_STOCK_COUNTS_OVERFLOW: StringName = &"INV_STOCK_COUNTS_OVERFLOW"


class StockCounts:
	"""Caller-owned read-only stock snapshot: four independent ITEM_CAPACITY int64 buffers.

	Each of `live_milli`, `loose_milli`, `equipped_milli` and `unreserved_loose_milli` is a
	separate zeroed PackedInt64Array of length ITEM_CAPACITY, allocated once here and never
	resized. This constructs no Inventory, lot, container, catalog or resident; it is a plain
	data record a presentation layer may hold and refresh via copy_stock_counts_into().
	"""
	var live_milli: PackedInt64Array = PackedInt64Array()
	var loose_milli: PackedInt64Array = PackedInt64Array()
	var equipped_milli: PackedInt64Array = PackedInt64Array()
	var unreserved_loose_milli: PackedInt64Array = PackedInt64Array()

	func _init() -> void:
		"""Allocate and zero-fill the four independent ITEM_CAPACITY buffers, once."""
		live_milli.resize(ITEM_CAPACITY)
		loose_milli.resize(ITEM_CAPACITY)
		equipped_milli.resize(ITEM_CAPACITY)
		unreserved_loose_milli.resize(ITEM_CAPACITY)
		live_milli.fill(0)
		loose_milli.fill(0)
		equipped_milli.fill(0)
		unreserved_loose_milli.fill(0)


func copy_stock_counts_into(target: StockCounts, out: IntMath.IntResult) -> bool:
	"""Publish a fresh whole-inventory stock count into `target`. Returns `out.ok`.

	On success `out.value` is the number of live rows counted and `target`'s four array
	fields are REPLACED with four independent staging buffers built by this call; an older
	held reference to a prior field is an older snapshot and is not kept current. On any
	refusal `target` and every owner field are left completely unchanged, and `out` carries
	the refusal code with a zeroed value channel.

	Precedence, checked in order: a null `target` or any field whose length is not
	ITEM_CAPACITY refuses SHAPE before anything else is inspected. An open or poisoned
	transaction, a non-empty undo journal, or an in-progress attestation refuses BUSY. An
	out-of-range high-water mark refuses STATE. Then exactly ONE ascending pass over
	`0.._l_slot_high_water` validates each row's local structural invariants (STATE) and
	folds it into the local staging buffers with checked arithmetic (OVERFLOW); an overflow
	found at an earlier row therefore refuses before a malformed later row is ever reached.

	This certifies only the structural invariants named in INIT-COUNT-R01v2: item
	registration, positive lot generation, quantity and reservation bounds, and a null or
	valid container placement. It does not call the equipment attestation authority and does
	not certify the Gear/Directory equipped biconditual, intrusive-list membership, cached
	mass or full-world conservation -- those remain `audit()`'s obligations.
	"""
	var shape: StringName = _stock_counts_shape_refusal(target)
	if shape != REFUSE_NONE:
		return out.refuse(String(shape))
	if _tx_open or _tx_poisoned or _j_count != 0 or _attesting:
		return out.refuse(String(REFUSE_STOCK_COUNTS_BUSY))
	if _l_slot_high_water < 0 or _l_slot_high_water > _l_capacity:
		return out.refuse(String(REFUSE_STOCK_COUNTS_STATE))
	var staging: StockCounts = StockCounts.new()
	var scratch: IntMath.IntResult = IntMath.IntResult.new()
	var live_rows: int = 0
	for slot: int in range(_l_slot_high_water):
		var occupancy: int = _l_live[slot]
		if occupancy == 0:
			continue
		if occupancy != 1:
			return out.refuse(String(REFUSE_STOCK_COUNTS_STATE))
		var row: StringName = _stock_counts_row_into(slot, staging, scratch)
		if row != REFUSE_NONE:
			return out.refuse(String(row))
		live_rows += 1
	target.live_milli = staging.live_milli
	target.loose_milli = staging.loose_milli
	target.equipped_milli = staging.equipped_milli
	target.unreserved_loose_milli = staging.unreserved_loose_milli
	return out.succeed(live_rows)


func _stock_counts_shape_refusal(target: StockCounts) -> StringName:
	"""REFUSE_STOCK_COUNTS_SHAPE for a null target or any field not sized ITEM_CAPACITY.

	Short-circuits on `target == null` before any field is read.
	"""
	if target == null:
		return REFUSE_STOCK_COUNTS_SHAPE
	if target.live_milli.size() != ITEM_CAPACITY or target.loose_milli.size() != ITEM_CAPACITY \
			or target.equipped_milli.size() != ITEM_CAPACITY \
			or target.unreserved_loose_milli.size() != ITEM_CAPACITY:
		return REFUSE_STOCK_COUNTS_SHAPE
	return REFUSE_NONE


func _stock_counts_row_into(slot: int, staging: StockCounts,
		scratch: IntMath.IntResult) -> StringName:
	"""Validate one live row's local structural invariants, then fold it into `staging`.

	A null container classifies as equipped and requires null container generation, null
	next/previous links and zero reservation. A non-null container must be a complete valid
	ref per the existing pure is_container_valid() predicate. Everything else refuses STATE.
	"""
	var item_id: int = _l_item_id[slot]
	if item_id < 0 or item_id >= ITEM_CAPACITY or _item_registered[item_id] != 1:
		return REFUSE_STOCK_COUNTS_STATE
	if _l_generation[slot] <= 0:
		return REFUSE_STOCK_COUNTS_STATE
	var quantity: int = _l_quantity_milli[slot]
	if quantity <= 0:
		return REFUSE_STOCK_COUNTS_STATE
	var reserved: int = _l_reserved_milli[slot]
	if reserved < 0 or reserved > quantity:
		return REFUSE_STOCK_COUNTS_STATE
	var container_slot: int = _l_container_slot[slot]
	var equipped: bool
	if container_slot == NULL_SLOT:
		if _l_container_generation[slot] != NULL_GENERATION or _l_next[slot] != NULL_SLOT \
				or _l_prev[slot] != NULL_SLOT or reserved != 0:
			return REFUSE_STOCK_COUNTS_STATE
		equipped = true
	else:
		if not is_container_valid(Vector2i(container_slot, _l_container_generation[slot])):
			return REFUSE_STOCK_COUNTS_STATE
		equipped = false
	return _fold_stock_counts_row(staging, scratch, item_id, quantity, reserved, equipped)


func _fold_stock_counts_row(staging: StockCounts, scratch: IntMath.IntResult, item_id: int,
		quantity: int, reserved: int, equipped: bool) -> StringName:
	"""Checked accumulation of one row's quantity into live/loose/equipped/unreserved_loose.

	`scratch` is the caller's own local IntResult, distinct from the owner's private `_math`.
	Every sum is checked; there is no wrap, saturation or float conversion anywhere here.
	"""
	if not IntMath.checked_add_into(staging.live_milli[item_id], quantity, scratch):
		return REFUSE_STOCK_COUNTS_OVERFLOW
	staging.live_milli[item_id] = scratch.value
	if equipped:
		if not IntMath.checked_add_into(staging.equipped_milli[item_id], quantity, scratch):
			return REFUSE_STOCK_COUNTS_OVERFLOW
		staging.equipped_milli[item_id] = scratch.value
		return REFUSE_NONE
	if not IntMath.checked_add_into(staging.loose_milli[item_id], quantity, scratch):
		return REFUSE_STOCK_COUNTS_OVERFLOW
	staging.loose_milli[item_id] = scratch.value
	var unreserved: int = quantity - reserved
	if not IntMath.checked_add_into(staging.unreserved_loose_milli[item_id], unreserved, scratch):
		return REFUSE_STOCK_COUNTS_OVERFLOW
	staging.unreserved_loose_milli[item_id] = scratch.value
	return REFUSE_NONE

