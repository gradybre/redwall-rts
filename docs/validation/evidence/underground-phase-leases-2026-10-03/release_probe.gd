extends Node
## Isolated exact cleanup regression on the real macOS release template, not a playable dig.

const Bindings := preload("res://scripts/core/underground_world_bindings.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
var _checks: int = 0
var _failures: int = 0
var _assert_ran: bool = false


func _ready() -> void:
	"""Demonstrate compiled-out assertions and actual release/reacquisition of the production arena."""
	assert(_assert_side_effect())
	_check(not OS.is_debug_build(), "real release binary")
	_check(not _assert_ran, "assert expression compiled out")
	var budget: Budget = Budget.new()
	var provider: Bindings = Bindings.new()
	provider._budget = budget
	var token: int = budget.acquire(Budget.COLD_BYTES)
	provider._phase_token = token
	_check(token > 0, "actual complete arena acquired")
	provider.end_cold_operation(token + 1)
	_check(budget.covers(token, Budget.COLD_BYTES), "foreign token cannot release")
	provider.end_cold_operation(token)
	_check(budget.is_quiescent(), "real cleanup releases with assertions disabled")
	var next_token: int = budget.acquire(Budget.COLD_BYTES)
	_check(next_token > token, "next dig operation can acquire")
	provider.end_cold_operation(token)
	_check(budget.covers(next_token, Budget.COLD_BYTES), "old cleanup preserves next operation")
	if next_token > 0:
		budget.release(next_token)
	_check(budget.is_quiescent(), "final arena quiescent")
	print("PHASE-LEASE-RELEASE checks=", _checks, " failures=", _failures, " assert_ran=", _assert_ran)
	get_tree().quit(0 if _failures == 0 else 1)


func _assert_side_effect() -> bool:
	"""The probe deliberately needs this expression to be absent in the release template."""
	_assert_ran = true
	return true


func _check(passed: bool, label: String) -> void:
	"""The fixture checks never depend on assert, which this export specifically removes."""
	_checks += 1
	if not passed:
		_failures += 1
		print("PHASE-LEASE-FAIL ", label)
