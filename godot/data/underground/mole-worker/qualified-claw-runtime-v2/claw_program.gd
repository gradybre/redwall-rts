extends RefCounted
## ADR 1229 increment 3: the claw work program of source 4 on content 10 (`qualified-claw-stairs-v11`), the successor
## of `qualified-claw-runtime-v1/claw_program.gd` (content 9). Content 10 inserts the stair and step WALK rows 51-55
## before source 4's WORK rows, so the dig/tap rows move to 56-63 and the tread fitting tap is row 64 (DEC-058). This
## program owns the travel rows 42-50 and the work rows 56-64; the stair program (`stair_program.gd`) owns 51-55.
## Every equation is v1's: protocol 6's phase encoding, the claw image's clock domain (stand key 8, walk 45 keys,
## entry/recovery 31 keys, stroke and work 33; the tread tap's clips have the tap's lengths) and Brendan's fade rule
## (ADR 1217 step 4d). The image is the claw v2 image (content 10 source 4). Stateless: Routes owns the clock.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Step := preload("res://data/underground/mole-worker/work-step-v1/source_program.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-claw-stairs-v11/catalog_source.gd")
const CONTENT: int = 10
const SOURCE: int = 4
const FIRST: int = 42
const LAST: int = 64
const ONE: int = 65536
const READY_TIME: int = Pins.CLAW_READY_KEY * ONE
const FADE_TIME: int = Step.Parent.FADE_TIME
const WALK_DURATION: int = (Pins.CLAW_WALK_KEYS - 1) * ONE
const TRANSITION_DURATION: int = 30 * ONE
const WORK_DURATION: int = 32 * ONE
const READY: int = Step.Parent.READY
const WALK: int = Step.Parent.WALK
const FADE_READY: int = Step.Parent.FADE_READY
const FADE_WALK: int = Step.Parent.FADE_WALK
const ENTRY: int = Step.Parent.ENTRY
const WORK: int = Step.Parent.WORK
const RECOVERY: int = Step.Parent.RECOVERY
const ENTRY_RETRACE: int = Step.Parent.ENTRY_RETRACE
const RECOVERY_WAIT: int = Step.Parent.RECOVERY_WAIT
## Claw v2 image clip ordinals (claw-work-v1 native-claw-stairs-v1/claw plan.json).
const CLIP_STAND: int = 0
const CLIP_WALK: int = 1
const CLIP_DIG_ENTRY: int = 2
const CLIP_TAP_ENTRY: int = 5
const CLIP_TREAD_TAP_ENTRY: int = 8
const I32_MAX: int = 2147483647


static func owns(actual: Profiles, profile: int) -> bool:
	"""The row is a claw-image row: its source word is 4 and source 4 is the published claw image."""
	if actual == null or actual._live == null or actual._loading or actual._live.header.size() != 4 \
			or not in_block(profile) or profile >= actual._live.header[1] \
			or actual._live.header[3] <= SOURCE:
		return false
	return actual._live.fields[Profiles.F_SOURCE * actual._profile_capacity + profile] == SOURCE \
		and _digest_matches(actual)


static func in_block(profile: int) -> bool:
	"""Rows 42-50 and 56-64; the stair and step rows 51-55 between them are the stair program's."""
	return profile >= FIRST and profile <= LAST and (profile < Pins.CLAW_STEP_BACK_ROW or profile > Pins.CLAW_TURN_ROW)


static func is_travel(profile: int) -> bool:
	"""Canonical-ground WALK 42 and the narrow approach and retreat 43-50."""
	return profile >= FIRST and profile <= Pins.CLAW_RETREAT_ROWS[3]


static func is_backward(profile: int) -> bool:
	"""The narrow retreat rows play the approach poses in reverse."""
	return profile >= Pins.CLAW_RETREAT_ROWS[0] and profile <= Pins.CLAW_RETREAT_ROWS[3]


static func is_tap(profile: int) -> bool:
	"""Seating tap rows 57/59/61/63 and the tread fitting tap 64; the dig rows are 56/58/60/62."""
	if profile == Pins.CLAW_TREAD_TAP_ROW: return true
	return profile >= Pins.CLAW_DIG_ROWS[0] and profile <= Pins.CLAW_TAP_ROWS[3] and (profile - Pins.CLAW_DIG_ROWS[0]) % 2 == 1


static func profile_refusal(actual: Profiles, profile: int, revision: int, content: int) -> StringName:
	"""Exact policy, certificate, mode, heading, tool-free identity and the claw image digest of one claw row."""
	if not owns(actual, profile): return &"ROUTE_SOURCE_PROFILE"
	var policy: int = Profiles.selection_policy_leaf(actual, profile, revision, content)
	var stride: int = actual._profile_capacity
	if policy != _policy(profile) or revision != 1 or actual._live.flags[profile] != Profiles.CERT_REQUIRED \
			or actual._live.fields[Profiles.F_MODE * stride + profile] != (Profiles.MODE_WALK if is_travel(profile) else Profiles.MODE_WORK) \
			or actual._live.fields[Profiles.F_YAW_KIND * stride + profile] != (Profiles.YAW_ALL if profile == FIRST else Profiles.YAW_EXACT) \
			or actual._live.fields[Profiles.F_YAW * stride + profile] != yaw_of(profile):
		return &"ROUTE_SOURCE_PROFILE"
	for field: int in [Profiles.F_TOOL, Profiles.F_TOOL_VARIANT, Profiles.F_CARGO, Profiles.F_CARGO_VARIANT]:
		if actual._live.fields[field * stride + profile] != -1: return &"ROUTE_SOURCE_PROFILE"
	return &""


static func _policy(profile: int) -> int:
	"""Canonical ground, READY_FORWARD, READY_BACKWARD or SOURCE_WORK, by the published block layout."""
	if profile == FIRST: return Profiles.POLICY_CANONICAL_GROUND
	if profile < Pins.CLAW_RETREAT_ROWS[0]: return Profiles.POLICY_READY_FORWARD
	return Profiles.POLICY_READY_BACKWARD if is_backward(profile) else Profiles.POLICY_SOURCE_WORK


static func yaw_of(profile: int) -> int:
	"""Each block runs yaw 0, 16384, 32768, 49152; WALK 42 admits every heading (word 0)."""
	if profile == FIRST: return 0
	if is_travel(profile): return ((profile - Pins.CLAW_APPROACH_ROWS[0]) % 4) * 16384
	if profile == Pins.CLAW_TREAD_TAP_ROW: return 0
	@warning_ignore("integer_division") var heading: int = (profile - Pins.CLAW_DIG_ROWS[0]) / 2
	return heading * 16384


static func _digest_matches(actual: Profiles) -> bool:
	"""Source 4 is the complete claw image, compared byte by byte without decoding a buffer."""
	for byte: int in 32:
		var high: int = Pins.CLAW_SOURCE_SHA.unicode_at(byte * 2)
		var low: int = Pins.CLAW_SOURCE_SHA.unicode_at(byte * 2 + 1)
		var value: int = (high - (48 if high <= 57 else 87)) * 16 + low - (48 if low <= 57 else 87)
		if actual._live.sources[SOURCE * 32 + byte] != value: return false
	return true


static func word(route_phase: int, source_phase: int) -> int:
	"""Protocol 6's phase encoding in the existing I32 column."""
	return Step.word(route_phase, source_phase)


static func clock(time: int, old: int) -> int:
	"""Two positive 31-bit Q16 lanes in the existing I64 request-tick union."""
	return (old << 32) | time


static func clock_refusal(source_word: int, source_clock: int, profile: int) -> StringName:
	"""Every impossible phase/time combination of this program's clock domain refuses before any write."""
	if (source_word & ~63) != Step.TAG or source_clock < 0 or (source_clock & 2147483648) != 0 \
			or not in_block(profile):
		return &"ROUTE_SOURCE_CLOCK"
	var phase: int = (source_word >> 2) & 15
	var time: int = source_clock & I32_MAX
	var old: int = source_clock >> 32
	if phase == READY: return &"" if time == 0 and old == 0 else &"ROUTE_SOURCE_CLOCK"
	if is_travel(profile): return _travel_clock_refusal(phase, time, old, profile)
	if old != 0: return &"ROUTE_SOURCE_CLOCK"
	if phase == WORK or phase == RECOVERY_WAIT:
		return &"" if time < WORK_DURATION else &"ROUTE_SOURCE_CLOCK"
	if phase == ENTRY or phase == RECOVERY:
		return &"" if time < TRANSITION_DURATION else &"ROUTE_SOURCE_CLOCK"
	return &"" if phase == ENTRY_RETRACE and time < TRANSITION_DURATION else &"ROUTE_SOURCE_CLOCK"


static func _travel_clock_refusal(phase: int, time: int, old: int, profile: int) -> StringName:
	"""Walk and fades on whole source keys; a READY fade never holds a blocked walk key (ADR 1217 step 4d)."""
	if old >= WALK_DURATION or old % ONE != 0 or time % ONE != 0: return &"ROUTE_SOURCE_CLOCK"
	if phase == WALK: return &"" if time < WALK_DURATION and old == 0 else &"ROUTE_SOURCE_CLOCK"
	if phase == FADE_WALK: return &"" if time < FADE_TIME and old == 0 else &"ROUTE_SOURCE_CLOCK"
	if phase == FADE_READY:
		return &"" if time < FADE_TIME and not fade_blocked(profile, old) else &"ROUTE_SOURCE_CLOCK"
	return &"ROUTE_SOURCE_CLOCK"


static func walk_time(profile: int, time: int) -> int:
	"""The presented walk key: the retreat plays source time in reverse."""
	return (WALK_DURATION - time) % WALK_DURATION if is_backward(profile) else time


static func fade_blocked(profile: int, time: int) -> bool:
	"""Brendan (ADR 1217 step 4d): no READY fade from the presented walk keys 28-37 (whole intervals 28-37)."""
	var shown: int = walk_time(profile, time)
	return shown >= Pins.CLAW_FADE_BLOCKED_FIRST * ONE and shown < Pins.CLAW_FADE_RESUME_KEY * ONE


static func arrive(time: int, profile: int) -> Vector3i:
	"""The tick a route ends: the walk advances one key, then fades to READY, or walks on in place while blocked."""
	var next: int = (time + ONE) % WALK_DURATION
	return Vector3i(WALK, next, 0) if fade_blocked(profile, next) else Vector3i(FADE_READY, 0, next)


static func stationary(phase: int, time: int, old: int, profile: int, queued: bool) -> Vector3i:
	"""One headless tick at an endpoint: a queued READY fades to WALK; an unqueued WALK fades to READY once its key
	is clear and otherwise walks on in place (at most ten keys); every other phase advances its own clock."""
	if phase == READY and queued: return advance(FADE_WALK, time, old)
	if phase == WALK and not queued:
		if fade_blocked(profile, time): return Vector3i(WALK, (time + ONE) % WALK_DURATION, 0)
		return advance(FADE_READY, 0, time)
	return advance(phase, time, old)


static func ready_request(phase: int, time: int, old: int, profile: int) -> Vector3i:
	"""Stop source motion at its exact boundary: entry retraces, work finishes its loop, a clear walk fades; a walk on
	a blocked key is left to walk on (the stationary tick fades it)."""
	if phase == ENTRY: return Vector3i(ENTRY_RETRACE, time, old)
	if phase == WORK: return Vector3i(RECOVERY if time == 0 else RECOVERY_WAIT, time, old)
	if phase == WALK and not fade_blocked(profile, time): return Vector3i(FADE_READY, 0, time)
	return Vector3i(phase, time, old)


static func advance(phase: int, time: int, old: int) -> Vector3i:
	"""One accepted 30 Hz tick; a finite transition endpoint holds for the rest of that tick."""
	if phase == READY: return Vector3i(READY, 0, 0)
	if phase == WALK: return Vector3i(WALK, (time + ONE) % WALK_DURATION, 0)
	if phase == WORK: return Vector3i(WORK, (time + ONE) % WORK_DURATION, 0)
	if phase == ENTRY_RETRACE: return Vector3i(READY, 0, 0) if time <= ONE else Vector3i(phase, time - ONE, 0)
	var end: int = FADE_TIME if phase == FADE_WALK or phase == FADE_READY else TRANSITION_DURATION
	if phase == RECOVERY_WAIT: end = WORK_DURATION
	if time + ONE < end: return Vector3i(phase, time + ONE, old)
	if phase == FADE_WALK: return Vector3i(WALK, 0, 0)
	if phase == ENTRY: return Vector3i(WORK, 0, 0)
	if phase == RECOVERY_WAIT: return Vector3i(RECOVERY, 0, 0)
	return Vector3i(READY, 0, 0)


static func clip(profile: int, phase: int) -> int:
	"""Claw image clip of a phase: stand and walk for travel; entry, stroke or work, recovery for dig and tap."""
	if is_travel(profile): return CLIP_WALK if phase == WALK or phase == FADE_WALK else CLIP_STAND
	var entry: int = CLIP_DIG_ENTRY
	if is_tap(profile): entry = CLIP_TREAD_TAP_ENTRY if profile == Pins.CLAW_TREAD_TAP_ROW else CLIP_TAP_ENTRY
	if phase == ENTRY or phase == ENTRY_RETRACE: return entry
	if phase == RECOVERY: return entry + 2
	return entry + 1 if phase == WORK or phase == RECOVERY_WAIT else CLIP_STAND
