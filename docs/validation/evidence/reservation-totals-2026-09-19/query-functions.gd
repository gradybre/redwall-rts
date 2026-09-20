# RES-TOTAL-R01 v2 -- replacement reservation total query block.
#
# REPLACES, verbatim and in place, the existing block in `godot/scripts/core/reservations.gd`
# that currently runs from `func job_reserved_total_milli(...)` through the end of
# `func _sum_list(...)`. The unchecked `_sum_list` is DELETED, not kept alongside: a second
# unchecked helper is exactly the thing this repair exists to remove, and any missed internal
# caller must fail parsing rather than silently keep wrapping.
#
# Declares no `extends`, no `preload` and no member the owner file already defines. `IntMath`
# and `NULL_ROW` are the owner's existing names; `_math` and `_pending_new_rows` are NOT touched
# by anything below.

func job_reserved_total_milli(job_ref: Vector2i) -> IntMath.IntResult:
	"""Total milli-units claimed by one Job across every lot, as an explicit checked result.

	COLD PATH: allocates exactly one IntResult and delegates to the `_into` form, so the two
	surfaces can never disagree. `.ok` MUST be inspected before `.value`; a job whose claims sum
	past int64 yields an explicit refusal, never a wrapped negative total.

	Each call returns an INDEPENDENT result object holding no reference to owner scratch.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	job_reserved_total_milli_into(job_ref, out)
	return out


func lot_reserved_total_milli(lot_ref: Vector2i) -> IntMath.IntResult:
	"""Total milli-units claimed against one lot, re-derived from the rows, as a checked result.

	This is the right-hand side of decision 0019's invariant. COLD PATH: allocates exactly one
	IntResult and delegates to the `_into` form.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	lot_reserved_total_milli_into(lot_ref, out)
	return out


func job_reserved_total_milli_into(job_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating job_reserved_total_milli(): sum into caller-owned `out`, return out.ok.

	`out` is caller-owned and is ALSO this call's arithmetic scratch, so it must not be a result
	the caller still needs. A null `out` is refused before this touches a head column or any row,
	and no owner field -- canonical, derived, pending or `_math` -- is written on any path.

	A job with no list at all, including an out-of-range or generation-mismatched reference, is a
	total of zero rather than a refusal: `_list_head()` answers NULL_ROW and the traversal ends
	immediately in `out.succeed(0)`, clearing whatever failure `out` carried before.
	"""
	if out == null:
		return false
	return _sum_list_into(_list_head(job_ref, true), true, out)


func lot_reserved_total_milli_into(lot_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating lot_reserved_total_milli(): sum into caller-owned `out`, return out.ok.

	Same contract as the job form, against the lot list: `out` doubles as scratch, a null `out`
	is refused before any list access, a missing lot list succeeds at zero, and nothing in this
	pool or in any Inventory is mutated.
	"""
	if out == null:
		return false
	return _sum_list_into(_list_head(lot_ref, false), false, out)


func _sum_list_into(head: int, by_job: bool, out: IntMath.IntResult) -> bool:
	"""Checked sum of the claimed quantities along one intrusive list, written into `out`.

	The ONLY summation helper in this module. Traversal order is the list's existing canonical
	order, unchanged; what changes is that every quantity goes through `IntMath.checked_add_into`
	instead of `+=`. Because `out` is the scratch for each step, the running value is copied into
	a local BEFORE the next call, which is the convention every checked caller here already uses.

	Overflow returns false with `out.ok == false`, `out.value == 0` and a non-empty IntMath error,
	so no partial total is ever exposed as a success. An empty list -- head == NULL_ROW -- reaches
	the final `out.succeed(0)` and is an explicit success, not a refusal.
	"""
	if out == null:
		return false
	var total: int = 0
	var row: int = head
	while row != NULL_ROW:
		if not IntMath.checked_add_into(total, _r_quantity_milli[row], out):
			return false
		total = out.value
		row = _job_next[row] if by_job else _lot_next[row]
	return out.succeed(total)
