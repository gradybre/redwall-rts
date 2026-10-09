extends RefCounted
## ADR1211: the presentation program of the content-6 tool-free rows (30-41, haul and stone images).
## A row's program is read from its own immutable Descriptor (mode, cargo) and its source image; the clips and their
## order are the derived rows' own clip lists (haul-rows-v1 / stone-rows-v1 rows.json) plus the native-replayed joins
## (stand@8 -> enter_haul -> approach, recovery -> leave_haul -> stand@8). Presentation only: it never advances a
## simulation clock and grants no work, contact or movement.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const ONE: int = 65536
const SOURCE_HAUL: int = 2
const SOURCE_STONE: int = 3
const MAX_STEPS: int = 4
# Clip ordinals shared by both images (plan order 0-7).
const APPROACH: int = 0
const LIFT: int = 1
const PLACE: int = 2
const RECOVERY: int = 3
const HOLD: int = 4
const ENTER: int = 5
const CARRY: int = 6
const EXIT: int = 7
# Haul image v8 only.
const HAUL_STAND: int = 8
const HAUL_WALK: int = 9
const HAUL_ENTER_HAUL: int = 10
const HAUL_LEAVE_HAUL: int = 11
# Stone image v9 only (its stand/walk stay in v8; v9 enter_haul_stone@0 == v8 stand@8).
const STONE_ENTER_HAUL: int = 8
const STONE_LEAVE_HAUL: int = 9
const KIND_NONE: int = -1
const KIND_STAND: int = 0
const KIND_WALK: int = 1
const KIND_CARRY_TRAVEL: int = 2
const KIND_CARRY_ARRIVED: int = 3
const KIND_LOAD: int = 4
const KIND_UNLOAD: int = 5


static func kind_of(descriptor: Profiles.Descriptor, travelling: bool) -> int:
	"""The program kind of one tool-free row from its own mode and cargo; anything else is not a haul program."""
	if descriptor == null or descriptor.tool_item != -1:
		return KIND_NONE
	match descriptor.mode:
		Profiles.MODE_STAND:
			return KIND_STAND if descriptor.cargo_item == -1 else KIND_NONE
		Profiles.MODE_WALK:
			return KIND_WALK if descriptor.cargo_item == -1 else KIND_NONE
		Profiles.MODE_CARRY:
			if descriptor.cargo_item == -1:
				return KIND_NONE
			return KIND_CARRY_TRAVEL if travelling else KIND_CARRY_ARRIVED
		Profiles.MODE_WORK:
			return KIND_LOAD if descriptor.cargo_item == -1 else KIND_UNLOAD
	return KIND_NONE


static func program_into(source: int, kind: int, out: PackedInt32Array) -> int:
	"""Write the clip sequence into fixed caller scratch; returns its length, or 0 when the source has no such program."""
	if out.size() != MAX_STEPS or (source != SOURCE_HAUL and source != SOURCE_STONE):
		return 0
	var enter_haul: int = HAUL_ENTER_HAUL if source == SOURCE_HAUL else STONE_ENTER_HAUL
	var leave_haul: int = HAUL_LEAVE_HAUL if source == SOURCE_HAUL else STONE_LEAVE_HAUL
	match kind:
		KIND_STAND, KIND_WALK:
			if source != SOURCE_HAUL:
				return 0
			out[0] = HAUL_STAND if kind == KIND_STAND else HAUL_WALK
			return 1
		KIND_CARRY_TRAVEL:
			return _write(out, HOLD, ENTER, CARRY, -1)
		KIND_CARRY_ARRIVED:
			return _write(out, EXIT, HOLD, -1, -1)
		KIND_LOAD:
			return _write(out, enter_haul, APPROACH, LIFT, -1)
		KIND_UNLOAD:
			return _write(out, HOLD, PLACE, RECOVERY, leave_haul)
	return 0


static func _write(out: PackedInt32Array, a: int, b: int, c: int, d: int) -> int:
	"""Fill a sequence of up to four clips; -1 ends it."""
	var count: int = 0
	for clip: int in [a, b, c, d]:
		if clip < 0:
			break
		out[count] = clip
		count += 1
	return count


static func locate_into(content: Content, program: PackedInt32Array, count: int, elapsed_q16: int,
		timing: PackedInt32Array, out: PackedInt32Array) -> StringName:
	"""Resolve elapsed program time to (clip, clip time): each clip plays once, the last one loops or clamps."""
	if content == null or count < 1 or count > program.size() or elapsed_q16 < 0 or out.size() != 2 or timing.size() != 2:
		return &"MOLE_HAUL_PROGRAM_INPUT"
	var remaining: int = elapsed_q16
	for step: int in count:
		if not content.clip_timing_into(program[step], timing):
			return &"MOLE_HAUL_PROGRAM_CLIP"
		if step == count - 1 or remaining < timing[0]:
			out[0] = program[step]
			out[1] = remaining if timing[1] != 0 else mini(remaining, timing[0])
			return &""
		remaining -= timing[0]
	return &"MOLE_HAUL_PROGRAM_INPUT"
