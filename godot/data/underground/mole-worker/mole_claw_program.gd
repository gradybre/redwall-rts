extends RefCounted
## ADR1217 step 5 (ADR1211 entry worker view): the presented frame of a claw row (source 4, rows 42-58) from the
## simulation's own source clock, as `mole_profile_driver.gd` presents the pick rows: READY holds the claw stand at
## key 8, WALK plays the walk (reversed on the narrow retreat), the READY and WALK fades blend the two at the fade
## weight, and dig/tap phases play their entry, stroke or work, and recovery clips. Presentation only: it reads the
## clock Routes owns and never advances it.

const Content := preload("res://demo/cast/underground_actor_content.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/claw_program.gd")
## ADR1229: content 10's claw rows (42-50, 56-64) on the v2 claw image; the same clock, its own row-to-clip map.
const Claw10 := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/claw_program.gd")
const ONE: int = 65536


static func frames_into(content: Content, profile: int, state: PackedInt64Array, pose: PackedInt32Array,
		out: PackedInt32Array, content_revision: int = Claw.CONTENT) -> StringName:
	"""Write the frame pair and blend weight of one source state (phase, time, old) into `out`."""
	var program: GDScript = Claw10 if content_revision == Claw10.CONTENT else Claw
	if content == null or state.size() < 3 or pose.size() != 3 or out.size() != 7 \
			or profile < program.FIRST or profile > program.LAST \
			or (program == Claw10 and not Claw10.in_block(profile)):
		return &"MOLE_CLAW_PROGRAM_INPUT"
	var phase: int = state[0]
	var code: StringName = content.clip_into(_first_clip(program, profile, phase),
		_first_time(program, profile, phase, state[1]), pose)
	if code != &"": return code
	for index: int in 3:
		out[index] = pose[index]
		out[index + 3] = pose[index]
	out[6] = ONE
	if phase != Claw.FADE_READY and phase != Claw.FADE_WALK: return &""
	code = content.clip_into(program.CLIP_WALK, program.walk_time(profile, state[2]), pose) if phase == Claw.FADE_READY \
		else content.clip_into(program.CLIP_STAND, program.READY_TIME, pose)
	if code != &"": return code
	for index: int in 3:
		out[index + 3] = pose[index]
	@warning_ignore("integer_division") out[6] = state[1] * ONE / Claw.FADE_TIME
	return &""


static func _first_clip(program: GDScript, profile: int, phase: int) -> int:
	"""READY and the READY fade start from the stand; every other phase from its own clip."""
	return program.CLIP_STAND if phase == Claw.READY or phase == Claw.FADE_READY else program.clip(profile, phase)


static func _first_time(program: GDScript, profile: int, phase: int, time: int) -> int:
	"""The stand's ready key, the walk's first key for the WALK fade, the presented walk key, or the phase time."""
	if phase == Claw.READY or phase == Claw.FADE_READY: return program.READY_TIME
	if phase == Claw.FADE_WALK: return 0
	return program.walk_time(profile, time) if phase == Claw.WALK else time
