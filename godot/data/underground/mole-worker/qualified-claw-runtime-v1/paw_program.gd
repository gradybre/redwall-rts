extends RefCounted
## ADR 1217 step 5: exact stationary paw-handling certificate of row 59 (source 5, content 9). The tool-free successor of
## `qualified-assembly-v1/source_program.gd` (row 29, source 1): both paws rest on the delivered bearer, no tool is held.
## It supplies source identity only, never paid or World permission. The handling word keeps the pick handling
## program's encoding, because the clock's phases and 30-tick transitions are the same (paw_clock.gd); the row and its
## source select which image is presented. The L0/T0 part transforms and bearer prisms are the pick certificate's.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Clock := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/paw_clock.gd")
const Parent := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/claw_program.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-claw-approach-v10/catalog_source.gd")
const TAG: int = Parent.TAG
const CONTENT: int = 9
const PROFILE_COUNT: int = 60
const BOX_COUNT: int = 517
const SOURCE_COUNT: int = 6
const PROFILE: int = Pins.PAW_HANDLING_ROW
const SOURCE: int = 5
const FIRST_BOX: int = 510
const ROLE_COUNT: int = 7
const STATES: int = 457
## The two physical volumes the handling station must hold: every BODY/TURN/APPROACH body word of row 59, and its
## authored stance (which contains both below-floor foot residuals).
const PART_COUNT: int = 2
const BODY_LOW: Vector3i = Vector3i(-478, 0, -578)
const BODY_HIGH: Vector3i = Vector3i(443, 840, 234)
const FOOT_LOW: Vector3i = Vector3i(-276, -1, -169)
const FOOT_HIGH: Vector3i = Vector3i(299, 0, 175)
## Row 59's seven published role boxes (low xyz, high xyz, role), in order.
const BOXES: Array[int] = [
	-293, 0, -524, 327, 666, 219, 0,
	-197, -1, -80, 171, 0, -1, 0,
	-276, -1, -169, 299, 0, 175, 1,
	-478, 0, -578, 443, 840, 234, 2,
	-197, -1, -80, 171, 0, 61, 2,
	-478, 0, -329, 415, 840, 234, 3,
	-134, -1, 44, -126, 0, 60, 3]


static func uses(actual: Profiles) -> bool:
	"""Content 9 or an exact successor that keeps row 59, its boxes and sources 4-5."""
	return actual != null and actual._live != null and actual._live.header.size() == 4 \
		and profile_refusal(actual, PROFILE, 1, actual._live.header[0]) == &""


static func profile_refusal(actual: Profiles, profile: int, revision: int, content: int) -> StringName:
	"""Every published handling word, box and both split image digests must match before the clock is parsed."""
	if actual == null or actual._live == null or actual._loading or actual._live.header.size() != 4 \
			or profile != PROFILE or revision != 1 or content < CONTENT or actual._live.header[0] != content \
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
	"""Every descriptor word, in a frame of its own."""
	for field: int in Profiles.I32_FIELDS:
		if actual._live.fields[field * actual._profile_capacity + PROFILE] != _field(field): return false
	return true


static func _boxes_match(actual: Profiles) -> bool:
	"""All seven complete role/box words, with unchanged ordinal and half-open geometry."""
	for ordinal: int in ROLE_COUNT:
		for field: int in 7:
			if actual._live.boxes[field * actual._box_capacity + FIRST_BOX + ordinal] != box_word(ordinal, field):
				return false
	return true


static func _digests_match(actual: Profiles) -> bool:
	"""Source 5 is the paw-handling image and source 4 the claw image whose stand key 8 its ready joins equal."""
	for byte: int in 32:
		if actual._live.sources[Claw.SOURCE * 32 + byte] != Parent._digest_byte(Pins.CLAW_SOURCE_SHA, byte) \
				or actual._live.sources[SOURCE * 32 + byte] != Parent._digest_byte(Pins.PAW_SOURCE_SHA, byte):
			return false
	return true


static func _field(field: int) -> int:
	"""The adult Mole, tool-free, empty-handed BUILD tuple of row 59."""
	match field:
		Profiles.F_SOURCE: return SOURCE
		Profiles.F_SPECIES, Profiles.F_RIG: return 6
		Profiles.F_MODE: return Profiles.MODE_WORK
		Profiles.F_TOOL, Profiles.F_TOOL_VARIANT, Profiles.F_CARGO, Profiles.F_CARGO_VARIANT: return -1
		Profiles.F_STATES: return STATES
		Profiles.F_FIRST_BOX: return FIRST_BOX
		Profiles.F_BOX_COUNT: return ROLE_COUNT
		Profiles.F_WORK_KIND: return Profiles.Work.JobsScript.JOB_KIND_BUILD
		Profiles.F_CONTACT_KIND: return Profiles.CONTACT_ASSEMBLY_PALM
	return 0


static func box_word(ordinal: int, field: int) -> int:
	"""One published box word of row 59."""
	if ordinal < 0 or ordinal >= ROLE_COUNT or field < 0 or field > 6: return -2147483648
	return BOXES[ordinal * 7 + field]


static func volume_word(part: int, field: int) -> int:
	"""The station's physical volumes: part 0 the union of every body word, part 1 the stance (all footing)."""
	if part < 0 or part >= PART_COUNT or field < 0 or field > 5: return -2147483648
	if field < 3: return BODY_LOW[field] if part == 0 else FOOT_LOW[field]
	return BODY_HIGH[field - 3] if part == 0 else FOOT_HIGH[field - 3]


static func part_refusal(assembly: int, part: int, turn: int, translation: Vector3i) -> StringName:
	"""The included L0/T0 bearer transforms are the pick certificate's."""
	return Parent.part_refusal(assembly, part, turn, translation)


static func bearer_refusal(assembly: int, point: Vector3i, bounds: PackedInt32Array) -> StringName:
	"""The full relative bearer prisms and stationary roots are the pick certificate's."""
	return Parent.bearer_refusal(assembly, point, bounds)


static func word(route_phase: int, source_phase: int) -> int:
	"""The handling encoding in the existing phase column; callers own every canonical write."""
	return TAG | (source_phase << 2) | route_phase


static func clock_refusal(source_word: int, source_clock: int, profile: int) -> StringName:
	"""Stationary integer ticks allow IDLE or physical HELD only; no queue or spare clock lane."""
	if (source_word & ~63) != TAG or profile != PROFILE or ((source_word & 3) != 0 and (source_word & 3) != 3) \
			or source_clock < 0 or source_clock >= Clock.DURATION or source_clock % Clock.ONE != 0:
		return &"ASSEMBLY_SOURCE_CLOCK"
	return &"" if Clock.state_valid((source_word >> 2) & 15, source_clock) else &"ASSEMBLY_SOURCE_CLOCK"
