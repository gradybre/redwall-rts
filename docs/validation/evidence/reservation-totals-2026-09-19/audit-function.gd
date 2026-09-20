# RES-TOTAL-R01 v2 -- replacement `_audit_lot_totals`.
#
# REPLACES, verbatim and in place, the existing `func _audit_lot_totals(inventory: Inventory)`
# in `godot/scripts/core/reservations.gd`. It is the last internal caller of the deleted
# `_sum_list`, so this replacement and the query-block replacement must land together.
#
# Declares no `extends`, no `preload` and no member the owner file already defines. `_math` is
# the owner's EXISTING scratch field, reused here deliberately: audit is diagnostic and already
# owns that buffer, so no per-lot allocation is added.

func _audit_lot_totals(inventory: Inventory) -> StringName:
	"""Decision 0019's invariant, per lot the pool holds rows for, with a CHECKED sum.

	Fixed order, per lot:
	  1. the existing `is_lot_valid` gate, whose REFUSE_AUDIT_RESERVED_TOTAL precedence over
	     every arithmetic outcome is preserved -- an invalid lot is still reported as such even
	     when its rows would also overflow;
	  2. the checked sum, returning the ALREADY EXISTING REFUSE_OVERFLOW before any comparison,
	     so audit can never compare a wrapped total against a real reserved figure and call a
	     broken world healthy;
	  3. equality against `inventory.reserved_milli`;
	  4. the quantity bound.

	`_math.value` is copied into `total` IMMEDIATELY, before the two further Inventory queries,
	because `_math` is shared scratch and any later checked call would overwrite it.

	This closes one blind spot only. Lots the pool holds no rows for -- including Inventory lots
	reserved by a caller going around this pool -- are still invisible here; that reconciliation
	remains the coordinator's separately documented task, and this change does not claim to fix
	all audit coverage.
	"""
	for slot: int in range(_lot_capacity):
		var head: int = _lot_head[slot]
		if head == NULL_ROW:
			continue
		var lot_ref: Vector2i = Vector2i(slot, _r_lot_generation[head])
		if not inventory.is_lot_valid(lot_ref):
			return REFUSE_AUDIT_RESERVED_TOTAL
		if not _sum_list_into(head, false, _math):
			return REFUSE_OVERFLOW
		var total: int = _math.value
		if total != inventory.lot_reserved_milli(lot_ref):
			return REFUSE_AUDIT_RESERVED_TOTAL
		if total > inventory.lot_quantity_milli(lot_ref):
			return REFUSE_AUDIT_RESERVED_EXCEEDS
	return REFUSE_NONE
