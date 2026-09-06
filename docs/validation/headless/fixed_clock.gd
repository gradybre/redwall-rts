extends RefCounted
## Integer host-debt scheduler kernel; no scene physics or Engine.time_scale changes.

const PLAYER: int = 1
const MENU: int = 2
const CRITICAL: int = 4
const VICTORY: int = 8
const LOAD: int = 16
const TICK_COST: int = 1000000
const MAX_TICKS_PER_FRAME: int = 8
const MAX_I64: int = 9223372036854775807
var completed_tick: int = 0
var debt: int = 0
var requested_speed: int = 1
var pause_mask: int = PLAYER
var fallback_count: int = 0
var acknowledged_catchup_resets: int = 0


func set_speed(value: int) -> bool:
	## Invalid 3x requests leave state untouched; speed changes do not clear pause reasons.
	if value != 1 and value != 2 and value != 4:
		return false
	requested_speed = value
	return true


func set_pause(reason: int, enabled: bool) -> void:
	## Independent reasons prevent closing one menu from resuming a different pause.
	assert(reason == PLAYER or reason == MENU or reason == CRITICAL or reason == VICTORY or reason == LOAD)
	if enabled:
		pause_mask |= reason
		if reason == PLAYER and debt < TICK_COST:
			debt = 0
	else:
		pause_mask &= ~reason


func effective_speed() -> int:
	## Paused host time contributes no new simulation debt.
	return requested_speed if pause_mask == 0 else 0


func advance(elapsed_microseconds: int, step: Callable = Callable()) -> int:
	## Advance bounded complete ticks; overload retains every remaining owed tick.
	assert(elapsed_microseconds >= 0)
	var speed: int = effective_speed()
	if speed == 0:
		return 0
	assert(elapsed_microseconds <= (MAX_I64 - debt) / (30 * speed))
	debt += elapsed_microseconds * 30 * speed
	var count: int = 0
	while debt >= TICK_COST and count < MAX_TICKS_PER_FRAME and pause_mask == 0:
		debt -= TICK_COST
		if step.is_valid():
			step.call()
		completed_tick += 1
		count += 1
	if pause_mask == 0 and debt > 30 * speed * TICK_COST / 4:
		apply_overload()
	return count


func apply_overload() -> void:
	## Follow 4 to 2 to 1 to diagnostic pause once per host frame.
	fallback_count += 1
	if requested_speed == 4:
		requested_speed = 2
	elif requested_speed == 2:
		requested_speed = 1
	else:
		pause_mask |= CRITICAL


func acknowledge_without_catchup() -> void:
	## Explicit recovery may clear host debt only; gameplay tick never rewinds or advances.
	debt = 0
	acknowledged_catchup_resets += 1
	pause_mask &= ~CRITICAL


func calendar() -> PackedInt32Array:
	## Return absolute day, year, season, season day, hour; initial hour is 6.
	var time: int = completed_tick + 4500
	var day_zero: int = time / 18000
	return PackedInt32Array([day_zero + 1, day_zero / 48 + 1, (day_zero % 48) / 12, day_zero % 12 + 1, (time / 750) % 24])
