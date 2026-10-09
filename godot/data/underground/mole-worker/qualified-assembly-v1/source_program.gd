extends RefCounted
## Exact stationary handling certificate. This supplies source identity, never paid or World permission.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Clock := preload("res://data/underground/mole-worker/qualified-assembly-v1/handling_clock.gd")
const Parent := preload("res://data/underground/mole-worker/work-approach-v1/source_program.gd")
const ACTOR_SHA: String = "b94d676e999c87dd399a4dc110674620a4fbc66f0ca07e494b8bedadac683b66"
const VERSION: int = 7
const TAG: int = 0x11780000
const PROFILE_COUNT: int = 30
const BOX_COUNT: int = 281
const SOURCE_COUNT: int = 2
const PROFILE: int = 29
const SOURCE: int = 1
const FIRST_BOX: int = 271
const ROLE_COUNT: int = 10
const BODY_LOW: Vector3i = Vector3i(-409, 0, -521)
const BODY_HIGH: Vector3i = Vector3i(476, 840, 234)
const FOOT_LOW: Vector3i = Vector3i(-274, -1, -169)
const FOOT_HIGH: Vector3i = Vector3i(299, 0, 174)
const TOOL_LOW: Vector3i = Vector3i(185, 379, -732)
const TOOL_HIGH: Vector3i = Vector3i(660, 810, -249)


static func uses(actual: Profiles) -> bool:
	"""A successor count is accepted only with its exact appended source/descriptor/geometry closure."""
	return actual != null and actual._live != null and actual._live.header.size() == 4 \
		and profile_refusal(actual, PROFILE, 1, actual._live.header[0]) == &""


static func profile_refusal(actual: Profiles, profile: int, revision: int, content: int) -> StringName:
	"""All published handling words and both complete image digests must match before parsing the new clock.
	ADR1200: a successor content may append rows/boxes/sources after row 29 (per-source sorted blocks never
	renumber it); row 29's words, boxes 271-280 and sources 0-1 are still compared exactly below."""
	if actual == null or actual._live == null or actual._loading or actual._live.header.size() != 4 \
			or profile != PROFILE or revision != 1 or content <= 0 or actual._live.header[0] != content \
			or actual._live.header[1] < PROFILE_COUNT or actual._live.header[2] < BOX_COUNT \
			or actual._live.header[3] < SOURCE_COUNT or actual._profile_capacity < PROFILE_COUNT \
			or actual._box_capacity < BOX_COUNT or actual._source_capacity < SOURCE_COUNT:
		return &"ASSEMBLY_SOURCE_PROFILE"
	if Profiles.selection_policy_leaf(actual, profile, revision, content) != Profiles.POLICY_ASSEMBLY_HANDLING \
			or actual._live.flags[profile] != Profiles.CERT_REQUIRED \
			or actual._live.quantities[Profiles.L_QUANTITY_MIN * actual._profile_capacity + profile] != 0 \
			or actual._live.quantities[Profiles.L_QUANTITY_MAX * actual._profile_capacity + profile] != 0:
		return &"ASSEMBLY_SOURCE_PROFILE"
	if not _fields_match(actual) or not _boxes_match(actual) or not _digests_match(actual):
		return &"ASSEMBLY_SOURCE_PROFILE"
	return &""


static func _fields_match(actual: Profiles) -> bool:
	"""Check every descriptor word in a separate frame; no retained success flag survives this call."""
	for field: int in Profiles.I32_FIELDS:
		if actual._live.fields[field * actual._profile_capacity + PROFILE] != _field(field): return false
	return true


static func _boxes_match(actual: Profiles) -> bool:
	"""All seventy complete role/box words remain mandatory, with unchanged ordinal and half-open geometry."""
	for ordinal: int in ROLE_COUNT:
		for field: int in 7:
			if actual._live.boxes[field * actual._box_capacity + FIRST_BOX + ordinal] != box_word(ordinal, field):
				return false
	return true


static func _digests_match(actual: Profiles) -> bool:
	"""Both complete immutable image identities are checked after the descriptor and geometry frames return."""
	for byte: int in 32:
		if actual._live.sources[byte] != _digest_byte(Parent.ACTOR_SHA, byte) \
				or actual._live.sources[32 + byte] != _digest_byte(ACTOR_SHA, byte):
			return false
	return true


static func _field(field: int) -> int:
	"""The reviewed adult Mole/BASIC/empty BUILD tuple is finite content, not a wildcard profile."""
	match field:
		Profiles.F_SOURCE: return SOURCE
		Profiles.F_SPECIES, Profiles.F_RIG: return 6
		Profiles.F_MODE: return Profiles.MODE_WORK
		Profiles.F_TOOL: return 54
		Profiles.F_CARGO, Profiles.F_CARGO_VARIANT: return -1
		Profiles.F_STATES: return 457
		Profiles.F_FIRST_BOX: return FIRST_BOX
		Profiles.F_BOX_COUNT: return ROLE_COUNT
		Profiles.F_WORK_KIND: return Profiles.Work.JobsScript.JOB_KIND_BUILD
		Profiles.F_CONTACT_KIND: return Profiles.CONTACT_ASSEMBLY_PALM
	return 0


static func box_word(ordinal: int, field: int) -> int:
	"""Retain every body point: full positive body, all below-plane foot residual, and complete held pick."""
	if ordinal < 0 or ordinal >= ROLE_COUNT or field < 0 or field > 6: return -2147483648
	if field == 6:
		return Profiles.STANCE_SUPPORT if ordinal == 9 else Profiles.BODY_HELD_LOAD if ordinal < 3 \
			else Profiles.TURN_RECOVERY if ordinal < 6 else Profiles.WORK_APPROACH
	var part: int = ordinal % 3 if ordinal < 9 else 1
	if field < 3:
		return BODY_LOW[field] if part == 0 else FOOT_LOW[field] if part == 1 else TOOL_LOW[field]
	return BODY_HIGH[field - 3] if part == 0 else FOOT_HIGH[field - 3] if part == 1 else TOOL_HIGH[field - 3]


static func _digest_byte(digest: String, byte: int) -> int:
	"""Read existing immutable characters without allocating a second hash or palette bank."""
	var high: int = digest.unicode_at(byte * 2)
	var low: int = digest.unicode_at(byte * 2 + 1)
	return (high - (48 if high <= 57 else 87)) * 16 + low - (48 if low <= 57 else 87)


static func part_refusal(assembly: int, part: int, turn: int, translation: Vector3i) -> StringName:
	"""Only the exact included L0/T0 bearer transforms have this complete continuous triangle certificate."""
	if turn != 3: return &"ASSEMBLY_SOURCE_PART"
	if assembly == 0:
		return &"" if part == 1 and translation == Vector3i(1024, 192, -768) else &"ASSEMBLY_SOURCE_PART"
	return &"" if assembly == 1 and part == 8 and translation == Vector3i(2304, 320, -2816) \
		else &"ASSEMBLY_SOURCE_PART"


static func bearer_refusal(assembly: int, point: Vector3i, bounds: PackedInt32Array) -> StringName:
	"""Full relative prism, unchanged stationary root and heading zero; equal partial contact is insufficient."""
	if bounds.size() != 6 or assembly < 0 or assembly > 1: return &"ASSEMBLY_SOURCE_BEARER"
	return &"" if int(bounds[0]) - point.x == (-192 if assembly == 0 else -256) \
		and int(bounds[3]) - point.x == (1856 if assembly == 0 else 256) \
		and int(bounds[1]) - point.y == 0 and int(bounds[4]) - point.y == 128 \
		and int(bounds[2]) - point.z == -512 and int(bounds[5]) - point.z == -384 else &"ASSEMBLY_SOURCE_BEARER"


static func word(route_phase: int, source_phase: int) -> int:
	"""Versioned meaning in the existing phase column; callers still own every canonical state write."""
	return TAG | (source_phase << 2) | route_phase


static func clock_refusal(source_word: int, source_clock: int, profile: int) -> StringName:
	"""Stationary integer ticks allow IDLE or physical HELD, never a route queue or spare high clock lane."""
	if (source_word & ~63) != TAG or profile != PROFILE or ((source_word & 3) != 0 and (source_word & 3) != 3) \
			or source_clock < 0 or source_clock >= Clock.DURATION or source_clock % Clock.ONE != 0:
		return &"ASSEMBLY_SOURCE_CLOCK"
	return &"" if Clock.state_valid((source_word >> 2) & 15, source_clock) else &"ASSEMBLY_SOURCE_CLOCK"
