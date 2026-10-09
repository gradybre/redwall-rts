extends RefCounted
## ADR 1229 increment 3: the stair source program of content 10's source-proved travel rows on source 4: step back 51,
## step forward 52, descent 53, ascent 54 and the half-turn 55. Every one of their clips begins and ends on the claw
## READY hub (ADR 1217 §6.1), so the program has two source phases only: READY at a Location, and WALK while it
## crosses one edge. A crossing takes a fixed number of ticks, ceil(length * 30 / pace), from the edge's pace row:
## DEC-050's authored connector paces give 30 ticks per tread and 45 per half-turn; the short steps keep ADR 1164's
## adopted ground cap (two movement ticks over 141 u). The pose at tick t is the program's key t * (intervals / ticks),
## a whole key, so the handoff root equation's ceil of the rational interpolation is the key's own integer root.
## Phase words keep protocol 6's encoding; the clock's time lane holds the presented key (Q16), and Routes' progress
## column holds the elapsed ticks. Stateless: Routes owns the clock.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Step := preload("res://data/underground/mole-worker/work-step-v1/source_program.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/claw_program.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-claw-stairs-v11/catalog_source.gd")
const CONTENT: int = 10
const SOURCE: int = 4
const FIRST: int = Pins.CLAW_STEP_BACK_ROW
const LAST: int = Pins.CLAW_TURN_ROW
const ONE: int = 65536
const READY: int = Step.Parent.READY
const WALK: int = Step.Parent.WALK
const I32_MAX: int = 2147483647
## The longest clip of the five (the half-turn, 271 keys): no presented key reaches it.
const MAX_KEY: int = 270
## The step_back and step_forward clips of the claw v2 image have 5 keys (native-claw-stairs-v1/claw plan.json).
const STEP_CLIP_INTERVALS: int = 4


static func owns(actual: Profiles, profile: int) -> bool:
	"""Rows 51-55 of a content whose source 4 is the claw v2 image."""
	if actual == null or actual._live == null or actual._loading or actual._live.header.size() != 4 \
			or profile < FIRST or profile > LAST or profile >= actual._live.header[1] \
			or actual._live.header[3] <= SOURCE:
		return false
	return actual._live.fields[Profiles.F_SOURCE * actual._profile_capacity + profile] == SOURCE \
		and Claw._digest_matches(actual)


static func is_rooted(profile: int) -> bool:
	"""The stair gaits and the half-turn follow an authored root track; the short steps are straight."""
	return profile >= Pins.CLAW_DESCENT_ROW and profile <= LAST


static func policy_of(profile: int) -> int:
	"""The published policy of each row."""
	if profile == Pins.CLAW_STEP_BACK_ROW: return Profiles.POLICY_SHORT_BACKWARD
	if profile == Pins.CLAW_STEP_FORWARD_ROW: return Profiles.POLICY_SHORT_FORWARD
	return Profiles.POLICY_STAIR_TURN if profile == LAST else Profiles.POLICY_STAIR


static func yaw_of(profile: int) -> int:
	"""Every row starts facing down the stair (yaw 0) except the ascent, which faces up (32768)."""
	return 32768 if profile == Pins.CLAW_ASCENT_ROW else 0


static func family_mask_of(profile: int) -> int:
	"""The steps are ground rows; the stair rows serve EARTH_TIMBER connector edges (family bit 0)."""
	return 1 if is_rooted(profile) else 0


static func profile_refusal(actual: Profiles, profile: int, revision: int, content: int) -> StringName:
	"""Exact policy, certificate, WALK mode, exact heading, family, tool-free identity and the claw image digest."""
	if not owns(actual, profile) or revision != 1 or content != CONTENT: return &"ROUTE_SOURCE_PROFILE"
	var stride: int = actual._profile_capacity
	if Profiles.selection_policy_leaf(actual, profile, revision, content) != policy_of(profile) \
			or actual._live.flags[profile] != Profiles.CERT_REQUIRED \
			or actual._live.fields[Profiles.F_MODE * stride + profile] != Profiles.MODE_WALK \
			or actual._live.fields[Profiles.F_YAW_KIND * stride + profile] != Profiles.YAW_EXACT \
			or actual._live.fields[Profiles.F_YAW * stride + profile] != yaw_of(profile) \
			or actual._live.fields[Profiles.F_FAMILIES * stride + profile] != family_mask_of(profile):
		return &"ROUTE_SOURCE_PROFILE"
	for field: int in [Profiles.F_TOOL, Profiles.F_TOOL_VARIANT, Profiles.F_CARGO, Profiles.F_CARGO_VARIANT]:
		if actual._live.fields[field * stride + profile] != -1: return &"ROUTE_SOURCE_PROFILE"
	return &""


static func word(route_phase: int, source_phase: int) -> int:
	"""Protocol 6's phase encoding in the existing I32 column."""
	return Step.word(route_phase, source_phase)


static func clock(key: int) -> int:
	"""The presented key in the time lane; the second lane is unused."""
	return key * ONE


static func clock_refusal(source_word: int, source_clock: int, profile: int) -> StringName:
	"""READY holds key 0; WALK holds a whole key short of the clip's end; nothing else is a stair state."""
	if (source_word & ~63) != Step.TAG or source_clock < 0 or (source_clock >> 32) != 0 \
			or profile < FIRST or profile > LAST:
		return &"ROUTE_SOURCE_CLOCK"
	var phase: int = (source_word >> 2) & 15
	if phase == READY: return &"" if source_clock == 0 else &"ROUTE_SOURCE_CLOCK"
	if phase != WALK or source_clock % ONE != 0 or source_clock >= MAX_KEY * ONE: return &"ROUTE_SOURCE_CLOCK"
	return &""


static func progress_refusal(source_word: int, source_clock: int, progress: int, remainder: int,
		occupied: bool) -> StringName:
	"""Elapsed ticks live in the progress column: zero at READY, positive with a presented key while crossing."""
	var phase: int = (source_word >> 2) & 15
	if remainder != 0 or progress < 0 or progress > MAX_KEY: return &"ROUTE_SOURCE_STEP_PROGRESS"
	if phase == READY: return &"" if progress == 0 and not occupied else &"ROUTE_SOURCE_STEP_PROGRESS"
	return &"" if (progress > 0) == occupied and (progress > 0) == (source_clock > 0) else &"ROUTE_SOURCE_STEP_PROGRESS"


static func ticks_for(length: int, pace: int) -> int:
	"""Whole ticks to cross an edge of `length` at `pace` u/s: ceil(length * 30 / pace), or -1."""
	if length < 1 or pace < 1: return -1
	@warning_ignore("integer_division") var ticks: int = (length * 30 + pace - 1) / pace
	return ticks


static func key_step(intervals: int, ticks: int) -> int:
	"""Keys per tick; the crossing must land on whole keys (90 / 30, 270 / 45, 4 / 2), else -1."""
	if ticks < 1 or intervals < ticks or intervals % ticks != 0: return -1
	@warning_ignore("integer_division") var step: int = intervals / ticks
	return step


static func stationary(phase: int, time: int, queued: bool) -> Vector3i:
	"""A queued READY starts the crossing at once (the clip leaves the READY hub); nothing else moves in place."""
	if phase == READY and queued: return Vector3i(WALK, 0, 0)
	return Vector3i(phase, time, 0)


static func ready_request(phase: int, time: int) -> Vector3i:
	"""A crossing is never cut short: it ends on the next READY hub, where the actor is already ready."""
	return Vector3i(phase, time, 0)
