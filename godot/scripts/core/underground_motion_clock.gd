extends RefCounted
## DEC-050 timing for three exact source programs; no retained clock or movement permission.

const Motion := preload("res://scripts/core/underground_motion_catalog.gd")
const SOURCE_WIRE_SHA: String = "2f44037e5e4eed0b4e2966cd1ac1881bdf4481dd083a26b11d8eea0c5ca0f986"
const TREAD_TICKS: int = 30
const HALF_TURN_TICKS: int = 45


static func sample_into(motion: Motion, revision: Variant, program: Variant,
		from_tick: Variant, to_tick: Variant, pose_out: PackedInt32Array,
		intervals_out: PackedInt32Array) -> StringName:
	"""Sample exact elapsed ticks and every crossed source interval; leave both caller outputs on refusal."""
	if pose_out.size() != 9 or intervals_out.size() != 2:
		return &"MOTION_CLOCK_OUTPUT_SIZE"
	if motion == null or motion.get_script() != Motion or Motion.SOURCE_WIRE_SHA != SOURCE_WIRE_SHA:
		return &"MOTION_CLOCK_SOURCE"
	if typeof(revision) != TYPE_INT or typeof(program) != TYPE_INT \
			or typeof(from_tick) != TYPE_INT or typeof(to_tick) != TYPE_INT:
		return &"MOTION_CLOCK_INTEGER"
	var ticks: int = _duration(int(program))
	if ticks == 0:
		return &"MOTION_CLOCK_TIMING"
	if from_tick < 0 or from_tick > to_tick or to_tick > ticks:
		return &"MOTION_CLOCK_TICK_RANGE"
	var step: int = 6 if int(program) == 3 else 3
	var phase: int = int(to_tick) * step * Motion.ONE
	var code: StringName = motion.phase_into(int(program), int(revision), phase, pose_out)
	if code != &"":
		return code
	intervals_out[0] = int(from_tick) * step
	intervals_out[1] = int(to_tick) * step
	return &""


static func _duration(program: int) -> int:
	"""Only ascent, descent and the supported half-turn have adopted timing; approach/retreat stay absent."""
	if program == 0 or program == 1:
		return TREAD_TICKS
	return HALF_TURN_TICKS if program == 3 else 0
