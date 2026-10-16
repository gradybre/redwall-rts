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
## Decision 1972 (P-1972-1 (a)): on content 12 the program also owns decision 1981's rooted rows 71-84 on the stair
## carry images (source 6 wood, source 7 stone): the empty walk-off and back-up, and per item the approach, descent,
## ascent, half-turn, retreat and back-up. Their clips also begin and end on one hub (the hold, or the closed-paw
## stand), so the same two phases, tick rule and key rule hold. Their tables are the stair-carry motion bank's.
## Decision 1972 (P-1972-6, "Keep 90 ticks"): a stair pace is in milli-u/s, so the 169 u retreat takes 90 ticks.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Step := preload("res://data/underground/mole-worker/work-step-v1/source_program.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/claw_program.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-stair-carry-v13/catalog_source.gd")
const CONTENT: int = 10
const SOURCE: int = 4
const FIRST: int = Pins.CLAW_STEP_BACK_ROW
const LAST: int = Pins.CLAW_TURN_ROW
const ONE: int = 65536
const READY: int = Step.Parent.READY
const WALK: int = Step.Parent.WALK
const I32_MAX: int = 2147483647
## Decision 1981: the rooted rows (content 12) and their sources.
const ROOTED_FIRST: int = 71
const ROOTED_LAST: int = 84
const WOOD_SOURCE: int = 6
const STONE_SOURCE: int = 7
## Content 12's ground carry rows whose cargo words each loaded rooted row repeats (wood 32, stone 37).
const WOOD_CARRY_ROW: int = 32
const STONE_CARRY_ROW: int = 37
## The longest clip (the half-turns, 271 keys): no presented key reaches it.
const MAX_KEY: int = 270
## The step_back and step_forward clips of the claw v2 image have 5 keys (native-claw-stairs-v1/claw plan.json).
const STEP_CLIP_INTERVALS: int = 4
## Ticks per second times milli-u per u: a pace of p milli-u/s crosses L u in ceil(L * 30,000 / p) ticks.
const MILLI_TICKS: int = 30000


static func owns(actual: Profiles, profile: int) -> bool:
	"""Rows 51-55 of a content whose source 4 is the claw v2 image, or rows 71-84 of a content whose sources 6 and 7
	are the stair carry images (decision 1972)."""
	if actual == null or actual._live == null or actual._loading or actual._live.header.size() != 4 \
			or not in_block(profile) or profile >= actual._live.header[1] \
			or actual._live.header[3] <= source_of(profile):
		return false
	if actual._live.fields[Profiles.F_SOURCE * actual._profile_capacity + profile] != source_of(profile): return false
	if not is_carry_row(profile): return Claw._digest_matches(actual)
	return _source_matches(actual, WOOD_SOURCE, Pins.STAIR_CARRY_WOOD_SOURCE_SHA) \
		and _source_matches(actual, STONE_SOURCE, Pins.STAIR_CARRY_STONE_SOURCE_SHA)


static func in_block(profile: int) -> bool:
	"""Rows 51-55 (content 10 onward) and 71-84 (content 12)."""
	return (profile >= FIRST and profile <= LAST) or is_carry_row(profile)


static func is_carry_row(profile: int) -> bool:
	"""Decision 1981's rooted rows 71-84: the stair's empty floor end and the stair carry."""
	return profile >= ROOTED_FIRST and profile <= ROOTED_LAST


static func source_of(profile: int) -> int:
	"""Source 4 for the claw rows; 6 for the empty pair and the wood carry; 7 for the stone carry."""
	if not is_carry_row(profile): return SOURCE
	return STONE_SOURCE if profile >= Pins.STAIR_CARRY_STONE_ROWS[0] else WOOD_SOURCE


static func _source_matches(actual: Profiles, source: int, sha: String) -> bool:
	"""One source image digest, compared byte by byte without decoding a buffer."""
	if actual._live.sources.size() < 32 * (source + 1): return false
	for byte: int in 32:
		var high: int = sha.unicode_at(byte * 2)
		var low: int = sha.unicode_at(byte * 2 + 1)
		var value: int = (high - (48 if high <= 57 else 87)) * 16 + low - (48 if low <= 57 else 87)
		if actual._live.sources[source * 32 + byte] != value: return false
	return true


static func is_rooted(profile: int) -> bool:
	"""The stair gaits, the half-turn and every rooted row follow an authored root track; the short steps are
	straight."""
	return (profile >= Pins.CLAW_DESCENT_ROW and profile <= LAST) or is_carry_row(profile)


static func _carry_name(profile: int) -> int:
	"""A loaded row's place in its item's six (approach, descent, ascent, turn, retreat, back-up), or -1."""
	if profile < Pins.STAIR_CARRY_WOOD_ROWS[0] or profile > ROOTED_LAST: return -1
	return (profile - Pins.STAIR_CARRY_WOOD_ROWS[0]) % 6


static func policy_of(profile: int) -> int:
	"""The published policy of each row."""
	if profile == Pins.CLAW_STEP_BACK_ROW: return Profiles.POLICY_SHORT_BACKWARD
	if profile == Pins.CLAW_STEP_FORWARD_ROW: return Profiles.POLICY_SHORT_FORWARD
	if not is_carry_row(profile): return Profiles.POLICY_STAIR_TURN if profile == LAST else Profiles.POLICY_STAIR
	if profile == Pins.STAIR_EMPTY_FLOOR_ROWS[0]: return Profiles.POLICY_ROOTED_TRAVEL
	if profile == Pins.STAIR_EMPTY_FLOOR_ROWS[1]: return Profiles.POLICY_ROOTED_BACKWARD
	return [Profiles.POLICY_ROOTED_TRAVEL, Profiles.POLICY_ROOTED_STAIR, Profiles.POLICY_ROOTED_STAIR,
		Profiles.POLICY_ROOTED_TURN, Profiles.POLICY_ROOTED_TRAVEL, Profiles.POLICY_ROOTED_BACKWARD][_carry_name(profile)]


static func yaw_of(profile: int) -> int:
	"""Every row starts facing down the stair (yaw 0) except the ascents and retreats, which face up (32768)."""
	if profile == Pins.CLAW_ASCENT_ROW: return 32768
	var name: int = _carry_name(profile)
	return 32768 if name == 2 or name == 4 else 0


static func mode_of(profile: int) -> int:
	"""WALK, except the loaded rooted rows, which CARRY one unit."""
	return Profiles.MODE_CARRY if _carry_name(profile) >= 0 else Profiles.MODE_WALK


static func family_mask_of(profile: int) -> int:
	"""The steps are ground rows; the stair and rooted rows serve EARTH_TIMBER connector edges (family bit 0)."""
	return 1 if is_rooted(profile) else 0


static func profile_refusal(actual: Profiles, profile: int, revision: int, content: int) -> StringName:
	"""Exact policy, certificate, mode, exact heading, family, tool-free identity, the cargo words and the image
	digests."""
	if not owns(actual, profile) or revision != 1 or not Claw.serves(content) \
			or (is_carry_row(profile) and content != Claw.SUCCESSOR_CONTENT):
		return &"ROUTE_SOURCE_PROFILE"
	var stride: int = actual._profile_capacity
	if Profiles.selection_policy_leaf(actual, profile, revision, content) != policy_of(profile) \
			or actual._live.flags[profile] != Profiles.CERT_REQUIRED \
			or actual._live.fields[Profiles.F_MODE * stride + profile] != mode_of(profile) \
			or actual._live.fields[Profiles.F_YAW_KIND * stride + profile] != Profiles.YAW_EXACT \
			or actual._live.fields[Profiles.F_YAW * stride + profile] != yaw_of(profile) \
			or actual._live.fields[Profiles.F_FAMILIES * stride + profile] != family_mask_of(profile) \
			or actual._live.fields[Profiles.F_TOOL * stride + profile] != -1 \
			or actual._live.fields[Profiles.F_TOOL_VARIANT * stride + profile] != -1:
		return &"ROUTE_SOURCE_PROFILE"
	return &"" if _cargo_matches(actual, profile) else &"ROUTE_SOURCE_PROFILE"


static func _cargo_matches(actual: Profiles, profile: int) -> bool:
	"""An empty row carries nothing; a loaded row carries exactly its item's ground carry words (row 32 or 37)."""
	var stride: int = actual._profile_capacity
	var template: int = -1
	if _carry_name(profile) >= 0:
		template = STONE_CARRY_ROW if source_of(profile) == STONE_SOURCE else WOOD_CARRY_ROW
	for field: int in [Profiles.F_CARGO, Profiles.F_CARGO_VARIANT]:
		var expected: int = -1 if template < 0 else actual._live.fields[field * stride + template]
		if actual._live.fields[field * stride + profile] != expected: return false
	return template < 0 or actual._live.fields[Profiles.F_CARGO * stride + profile] >= 0


static func word(route_phase: int, source_phase: int) -> int:
	"""Protocol 6's phase encoding in the existing I32 column."""
	return Step.word(route_phase, source_phase)


static func clock(key: int) -> int:
	"""The presented key in the time lane; the second lane is unused."""
	return key * ONE


static func clock_refusal(source_word: int, source_clock: int, profile: int) -> StringName:
	"""READY holds key 0; WALK holds a whole key short of the clip's end; nothing else is a stair state."""
	if (source_word & ~63) != Step.TAG or source_clock < 0 or (source_clock >> 32) != 0 \
			or not in_block(profile):
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
	"""Whole ticks to cross an edge of `length` u at `pace` milli-u/s: ceil(length * 30,000 / pace), or -1.
	Decision 1972 (P-1972-6): the connector catalog reports every stair timing in milli-u/s, so the 169 u retreat
	takes exactly 90 ticks; the earlier u/s rows report x 1,000 and keep their ticks."""
	if length < 1 or pace < 1: return -1
	@warning_ignore("integer_division") var ticks: int = (length * MILLI_TICKS + pace - 1) / pace
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
