extends Node
## Settlement stockpiles and the fixed-rate economy tick.
##
## Amounts are floats so fractional per-second rates accumulate without drift.
## The tick is driven off an accumulator rather than a Timer node so its cost is
## measurable against the <2ms budget in CLAUDE.md.

const PerfTimerScript := preload("res://scripts/utils/perf_timer.gd")

const ECONOMY_TICK_RATE: float = 1.0
const DEFAULT_STORAGE_CAP: float = 500.0
const SPEND_TOLERANCE: float = 0.0001
const MAX_TICKS_PER_FRAME: int = 8

const RESOURCE_FOOD: StringName = &"food"
const RESOURCE_WOOD: StringName = &"wood"
const RESOURCE_STONE: StringName = &"stone"
const RESOURCE_HERBS: StringName = &"herbs"

signal resource_changed(resource_type: StringName, amount: float)
signal resource_depleted(resource_type: StringName)

var _types: Array[StringName] = [RESOURCE_FOOD, RESOURCE_WOOD, RESOURCE_STONE, RESOURCE_HERBS]
var _amounts: Dictionary = {}
var _rates: Dictionary = {}
var _caps: Dictionary = {}
var _tick_accumulator: float = 0.0
var _timer: PerfTimerScript = PerfTimerScript.new()


func _init() -> void:
	"""Seed every tracked resource so autoload and test instances start identical."""
	reset()


func _ready() -> void:
	"""Report readiness at boot."""
	print("[EconomySystem] ready")


func _process(delta: float) -> void:
	"""Advance the accumulator and run whole economy ticks at a fixed rate.

	Godot does not clamp _process delta after a long stall, so the catch-up is
	capped and the remainder dropped rather than run as a single huge burst.
	"""
	_tick_accumulator += delta
	var ticks: int = 0
	while _tick_accumulator >= ECONOMY_TICK_RATE and ticks < MAX_TICKS_PER_FRAME:
		_tick_accumulator -= ECONOMY_TICK_RATE
		ticks += 1
		tick(ECONOMY_TICK_RATE)
	if _tick_accumulator >= ECONOMY_TICK_RATE:
		_tick_accumulator = 0.0


func tick(seconds: float) -> void:
	"""Apply net production rates for one tick of the given length."""
	_timer.start()
	for resource_type: StringName in _types:
		var rate: float = _rates[resource_type]
		if rate == 0.0:
			continue
		_apply_delta(resource_type, rate * seconds)
	_timer.stop()


func get_resource_types() -> Array[StringName]:
	"""Every tracked resource key, in display order."""
	return _types.duplicate()


func is_tracked(resource_type: StringName) -> bool:
	"""True when the key names a resource this system tracks."""
	return _amounts.has(resource_type)


func add_resource(resource_type: StringName, amount: float) -> void:
	"""Add to a stockpile, clamped at its storage cap. Negative amounts are ignored."""
	if not _validate(resource_type) or amount <= 0.0:
		return
	_apply_delta(resource_type, amount)


func try_consume(resource_type: StringName, amount: float) -> bool:
	"""Spend from a stockpile. Returns false and spends nothing when short.

	The comparison carries a tolerance because stockpiles are built by repeated
	float addition: 10 x 0.1 lands just under 1.0 and must still buy a 1.0 cost.
	"""
	if not _validate(resource_type) or amount <= 0.0:
		return false
	if _amounts[resource_type] - amount < -SPEND_TOLERANCE:
		return false
	_apply_delta(resource_type, -amount)
	return true


func get_amount(resource_type: StringName) -> float:
	"""Current stockpile for a resource, or 0.0 when untracked."""
	return _amounts.get(resource_type, 0.0)


func get_all_amounts() -> Dictionary:
	"""Copy of every stockpile, for pushing a full refresh into the HUD."""
	return _amounts.duplicate()


func set_rate(resource_type: StringName, rate: float) -> void:
	"""Set the net per-second production rate applied on each tick."""
	if not _validate(resource_type):
		return
	_rates[resource_type] = rate


func get_rate(resource_type: StringName) -> float:
	"""Net per-second production rate for a resource."""
	return _rates.get(resource_type, 0.0)


func set_cap(resource_type: StringName, cap: float) -> void:
	"""Set a storage cap and trim the current stockpile into it.

	Trimming is not a drain, so it never raises resource_depleted.
	"""
	if not _validate(resource_type) or cap < 0.0:
		return
	_caps[resource_type] = cap
	if _amounts[resource_type] <= cap:
		return
	_amounts[resource_type] = cap
	resource_changed.emit(resource_type, cap)


func get_cap(resource_type: StringName) -> float:
	"""Storage cap for a resource."""
	return _caps.get(resource_type, 0.0)


func get_last_tick_usec() -> int:
	"""Duration of the most recent economy tick, in microseconds."""
	return _timer.get_last_usec()


func reset() -> void:
	"""Return every stockpile, rate and cap to its starting value."""
	_tick_accumulator = 0.0
	for resource_type: StringName in _types:
		_amounts[resource_type] = 0.0
		_rates[resource_type] = 0.0
		_caps[resource_type] = DEFAULT_STORAGE_CAP


func _apply_delta(resource_type: StringName, delta_amount: float) -> void:
	"""Clamp a stockpile change into [0, cap] and notify UI listeners.

	The no-change check is an exact comparison on purpose: an approximate one
	discards small deltas outright rather than deferring them, so slow
	production rates would stall permanently as a stockpile grows.
	"""
	var previous: float = _amounts[resource_type]
	var updated: float = clampf(previous + delta_amount, 0.0, _caps[resource_type])
	if updated == previous:
		return
	_amounts[resource_type] = updated
	resource_changed.emit(resource_type, updated)
	if updated <= 0.0 and previous > 0.0:
		resource_depleted.emit(resource_type)


func _validate(resource_type: StringName) -> bool:
	"""True when the resource is tracked; reports the bad key otherwise."""
	if _amounts.has(resource_type):
		return true
	push_error("EconomySystem: unknown resource type '%s'." % resource_type)
	return false
