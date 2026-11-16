extends RefCounted
## Decision 1936, P-1933-1 (a) and P-1936-6 (a): a room builder's walk in to its parking and, P-1936-3 (a), back out
## to where it came from, as ADR1219's arrival: a timed walk of BAL-WORK-003's straight-leg lower bound
## ceil_div(D × 30, v) ticks, D the exact integer straight distance rounded up and v the resident's size class ground
## speed. No path is modelled: the Transform stays put until arrival places it. No new constant.

const EntryRuntime := preload("res://scripts/core/underground_entry_runtime.gd")
const HaulPlanner := preload("res://scripts/core/haul_planner.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const REFUSE_WALK: StringName = &"ROOM_BUILDER_WALK"

var ticks_left: int = 0
var leaving: bool = false # Walking out (true) or in (false).
var origin: Vector3i = Vector3i.ZERO # Where the resident stood before it walked in: the walk out's destination.
var _math: IntMath.IntResult = IntMath.IntResult.new()


func begin(residents: RefCounted, row: int, from: Vector3i, to: Vector3i, out: bool) -> StringName:
	"""Start one walk from `from` to `to` at the resident's own ground speed."""
	var size: IntMath.IntResult = residents.size_class_of(row)
	var speed: IntMath.IntResult = residents.size_movement_u_per_s(size.value) if size.ok else size
	if not speed.ok or not HaulPlanner.travel_ticks_into(EntryRuntime.ceil_length(to - from), speed.value, _math):
		return REFUSE_WALK
	ticks_left = _math.value
	leaving = out
	return &""


func step() -> bool:
	"""One tick of the walk; true on the tick it arrives."""
	if ticks_left <= 0: return false
	ticks_left -= 1
	return ticks_left == 0


func walking() -> bool:
	"""A walk is under way."""
	return ticks_left > 0
