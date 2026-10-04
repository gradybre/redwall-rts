extends RefCounted
## Stateless protocol5 equations for the unchanged fourteen-clip supplied source.
## Routes owns the clock. This module allocates no actor, palette, profile or per-worker state.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const ACTOR_SHA: String = "adc617642313ac004c050d4877ef0b9f4024bb9c88e3ea92ce9a924471bd5ab9"
const PROGRAM_SHA: String = "5caaec976eb3f8995784dc5f8d98cdb6c233020372d87964620b0da1c4e41c6e"
const VERSION: int = 5
const TAG: int = 0x11560000
const ONE: int = 65536
const READY_TIME: int = 524288
const FADE_TIME: int = 491520
const WALK_DURATION: int = 2097153
const TRANSITION_DURATION: int = 1966080
const READY: int = 0
const WALK: int = 2
const FADE_READY: int = 3
const FADE_WALK: int = 4
const ENTRY: int = 5
const WORK: int = 6
const RECOVERY: int = 7
const ENTRY_RETRACE: int = 8
const RECOVERY_WAIT: int = 10


static func profile_refusal(actual: Profiles, profile: int, revision: int, content: int) -> StringName:
	"""Bind this finite protocol to exact immutable row identities and the full original actor-image digest."""
	var policy: int = Profiles.selection_policy_leaf(actual, profile, revision, content)
	if policy < Profiles.POLICY_READY_FORWARD or profile < 2 or profile >= 26:
		return &"ROUTE_SOURCE_PROFILE"
	var wanted: int = Profiles.POLICY_SOURCE_WORK if profile >= 10 else (1 if profile < 6 else 2)
	@warning_ignore("integer_division") var yaw: int = ((profile - 10) / 4) * 16384 if profile >= 10 else ((profile - 2) % 4) * 16384
	var stride: int = actual._profile_capacity
	if policy != wanted or actual._live.flags[profile] != Profiles.CERT_REQUIRED \
			or actual._live.fields[Profiles.F_MODE * stride + profile] != (Profiles.MODE_WORK if profile >= 10 else Profiles.MODE_WALK) \
			or actual._live.fields[Profiles.F_YAW_KIND * stride + profile] != Profiles.YAW_EXACT \
			or actual._live.fields[Profiles.F_YAW * stride + profile] != yaw:
		return &"ROUTE_SOURCE_PROFILE"
	var source: int = actual._live.fields[Profiles.F_SOURCE * stride + profile]
	if source < 0 or source >= actual._live.header[3]:
		return &"ROUTE_SOURCE_PROFILE"
	for byte: int in 32:
		var high: int = ACTOR_SHA.unicode_at(byte * 2)
		var low: int = ACTOR_SHA.unicode_at(byte * 2 + 1)
		high -= 48 if high <= 57 else 87
		low -= 48 if low <= 57 else 87
		if actual._live.sources[source * 32 + byte] != high * 16 + low:
			return &"ROUTE_SOURCE_PROFILE"
	return &""


static func clock_refusal(source_word: int, source_clock: int, profile: int) -> StringName:
	"""Reserved tags/bits and every impossible subphase/time combination refuse before state or output writes."""
	if (source_word & ~63) != TAG or source_clock < 0 or (source_clock & 2147483648) != 0:
		return &"ROUTE_SOURCE_CLOCK"
	var phase: int = (source_word >> 2) & 15
	var time: int = source_clock & 2147483647
	var old: int = source_clock >> 32
	if phase == READY:
		return &"" if time == 0 and old == 0 else &"ROUTE_SOURCE_CLOCK"
	if profile < 10:
		if profile < 2 or old >= WALK_DURATION:
			return &"ROUTE_SOURCE_CLOCK"
		if phase == WALK:
			return &"" if time < WALK_DURATION and old == 0 else &"ROUTE_SOURCE_CLOCK"
		if phase == FADE_WALK or phase == FADE_READY:
			return &"" if time < FADE_TIME and (phase == FADE_READY or old == 0) else &"ROUTE_SOURCE_CLOCK"
	elif profile < 26 and old == 0:
		if phase == WORK or phase == RECOVERY_WAIT:
			return &"" if time < work_duration(profile) else &"ROUTE_SOURCE_CLOCK"
		if phase == ENTRY or phase == RECOVERY or phase == ENTRY_RETRACE:
			return &"" if time < TRANSITION_DURATION else &"ROUTE_SOURCE_CLOCK"
	return &"ROUTE_SOURCE_CLOCK"


static func word(route_phase: int, source_phase: int) -> int:
	"""Both meanings remain explicitly tagged in the existing I32; public route phases are decoded separately."""
	return TAG | (source_phase << 2) | route_phase


static func clock(time: int, old: int) -> int:
	"""Two validated positive31-bit Q16 lanes occupy the existing I64 request-tick union."""
	return (old << 32) | time


static func work_duration(profile: int) -> int:
	"""Exact immutable loop durations; these are source phases, never economic work or root speeds."""
	match (profile - 10) % 4:
		0, 2: return 2359296
		1: return 1703936
		3: return 2097152
	return 0


static func clip(profile: int, phase: int) -> int:
	"""The supplied work/entry/recovery triples and shared ready remain the only legal source families."""
	if profile < 10:
		return 1 if phase == WALK or phase == FADE_WALK else 0
	var work: int = 2 + ((profile - 10) % 4) * 3
	return work + 1 if phase == ENTRY or phase == ENTRY_RETRACE else (work + 2 if phase == RECOVERY else work)


static func walk_time(profile: int, time: int) -> int:
	"""Reverse source time, including the one-Q16-unit final loop interval; do not reverse uniform frame indices."""
	return (WALK_DURATION - time) % WALK_DURATION if profile >= 6 and profile < 10 else time


static func advance(phase: int, time: int, old: int, profile: int) -> Vector3i:
	"""One accepted30Hz tick; a finite transition endpoint holds for the remaining fraction of that tick."""
	if phase == READY:
		return Vector3i(READY, 0, 0)
	if phase == WALK:
		return Vector3i(WALK, (time + ONE) % WALK_DURATION, 0)
	if phase == WORK:
		return Vector3i(WORK, (time + ONE) % work_duration(profile), 0)
	if phase == ENTRY_RETRACE:
		return Vector3i(READY, 0, 0) if time <= ONE else Vector3i(phase, time - ONE, 0)
	var end: int = FADE_TIME if phase == FADE_WALK or phase == FADE_READY else TRANSITION_DURATION
	if phase == RECOVERY_WAIT:
		end = work_duration(profile)
	if time + ONE < end:
		return Vector3i(phase, time + ONE, old)
	if phase == FADE_WALK:
		return Vector3i(WALK, 0, 0)
	if phase == ENTRY:
		return Vector3i(WORK, 0, 0)
	if phase == RECOVERY_WAIT:
		return Vector3i(RECOVERY, 0, 0)
	return Vector3i(READY, 0, 0)
