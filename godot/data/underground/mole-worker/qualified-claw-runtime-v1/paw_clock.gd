extends RefCounted
## ADR 1217 step 5: the paw-handling clock of row 59 (source 5). Its phases and 30-tick transitions are the pick
## handling clock's (`qualified-assembly-v1/handling_clock.gd`), so the state equations are that clock's own; only the
## presented source differs: the paw image's seat entry and seat recovery clips have 31 keys (30 intervals), where the
## pick image's had 55. Pure equations; the paid owner authorizes every canonical write.

const Parent := preload("res://data/underground/mole-worker/qualified-assembly-v1/handling_clock.gd")
const ONE: int = Parent.ONE
const TRANSITION_TICKS: int = Parent.TRANSITION_TICKS
const DURATION: int = Parent.DURATION
const SOURCE_INTERVALS: int = 30
const READY: int = Parent.READY
const ENTRY: int = Parent.ENTRY
const RECOVERY: int = Parent.RECOVERY
const ENTRY_RETRACE: int = Parent.ENTRY_RETRACE
const HANDLED_READY: int = Parent.HANDLED_READY
## Paw image clip ordinals (native-claw-split-v1/paw plan.json): seat entry, seat work (hold), seat recovery.
const CLIP_ENTRY: int = 0
const CLIP_RECOVERY: int = 2


static func state_valid(phase: int, time: int) -> bool:
	"""The pick handling clock's states; no renderer state or reserved tag can create completion."""
	return Parent.state_valid(phase, time)


static func advance(phase: int, time: int) -> Vector2i:
	"""One accepted 30 Hz tick, as the pick handling clock."""
	return Parent.advance(phase, time)


static func interrupt(phase: int, time: int) -> Vector2i:
	"""Retrace an incomplete entry; a seated worker finishes the recovery, as the pick handling clock."""
	return Parent.interrupt(phase, time)


static func source_into(phase: int, time: int, out: PackedInt32Array) -> StringName:
	"""Write the paw image's exact clip and Q16 source time into two caller scalars; refusals keep the output."""
	if out.size() != 2 or not state_valid(phase, time): return &"ASSEMBLY_SOURCE_CLOCK"
	var clip: int = CLIP_ENTRY
	var source_time: int = 0
	if phase == HANDLED_READY:
		clip = CLIP_RECOVERY
		source_time = SOURCE_INTERVALS * ONE
	elif phase != READY:
		clip = CLIP_RECOVERY if phase == RECOVERY else CLIP_ENTRY
		@warning_ignore("integer_division")
		source_time = time * SOURCE_INTERVALS / TRANSITION_TICKS
	out[0] = clip
	out[1] = source_time
	return &""
