extends RefCounted
## ADR 1229 increment 4: the paw handling programs of content 10 on the paw v2 image (source 5): row 65, content 9's
## row 59 moved (the L0/T0 bearers), and row 66, the tread handling seat (T1-T5 and the T6 sill, DEC-060). Both keep
## runtime-v1's handling word, roles, clock and state machine (`paw_clock.gd`); only the boxes, the first box and the
## presented clips differ: row 65 plays the seat clips 0-2 of the paw v2 image, row 66 the tread seat clips 3-5. It
## supplies source identity only, never paid or World permission. Stateless.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Clock := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/paw_clock.gd")
const Parent := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/claw_program.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-claw-stairs-v11/catalog_source.gd")
const TAG: int = Parent.TAG
const CONTENT: int = 10
const PROFILE_COUNT: int = 67
const BOX_COUNT: int = 547
const SOURCE_COUNT: int = 6
const SOURCE: int = 5
const ROLE_COUNT: int = 7
const STATES: int = 457
const PART_COUNT: int = 2
## Each row's first box in content 10 (rows 0-50 keep content 9's 517 boxes' order; 15 stair boxes and 8 tread-fit
## boxes precede them).
const L0_T0_FIRST_BOX: int = 533
const TREAD_FIRST_BOX: int = 540
## The paw v2 image's clip ordinals (native-claw-stairs-v1/paw plan.json): seat entry/work/recovery, then the tread's.
const L0_T0_ENTRY_CLIP: int = 0
const TREAD_ENTRY_CLIP: int = 3
## Row 65's seven published role boxes (content 9's row 59, unchanged) and row 66's (stair-rows-v1 tread_seat), in
## published order: low xyz, high xyz, role.
const L0_T0_BOXES: Array[int] = [
	-293, 0, -524, 327, 666, 219, 0,
	-197, -1, -80, 171, 0, -1, 0,
	-276, -1, -169, 299, 0, 175, 1,
	-478, 0, -578, 443, 840, 234, 2,
	-197, -1, -80, 171, 0, 61, 2,
	-478, 0, -329, 415, 840, 234, 3,
	-134, -1, 44, -126, 0, 60, 3]
const TREAD_BOXES: Array[int] = [
	-359, 0, -376, 376, 738, 223, 0,
	-197, -1, -80, 171, 0, -2, 0,
	-276, -1, -169, 299, 0, 175, 1,
	-478, 0, -410, 445, 840, 234, 2,
	-197, -1, -80, 171, 0, 61, 2,
	-478, 0, -329, 415, 840, 234, 3,
	-134, -1, 44, -126, 0, 60, 3]


static func owns(profile: int) -> bool:
	"""Rows 65 and 66 of content 10."""
	return profile == Pins.PAW_HANDLING_ROW or profile == Pins.PAW_TREAD_HANDLING_ROW


static func is_tread(profile: int) -> bool:
	"""Row 66 seats a tread bearer (T1-T6) from the tread above."""
	return profile == Pins.PAW_TREAD_HANDLING_ROW


static func uses(actual: Profiles) -> bool:
	"""Content 10 with both handling rows exact."""
	return actual != null and actual._live != null and actual._live.header.size() == 4 \
		and profile_refusal(actual, Pins.PAW_HANDLING_ROW, 1, actual._live.header[0]) == &"" \
		and profile_refusal(actual, Pins.PAW_TREAD_HANDLING_ROW, 1, actual._live.header[0]) == &""


static func profile_refusal(actual: Profiles, profile: int, revision: int, content: int) -> StringName:
	"""Every published handling word, box and both v2 image digests must match before the clock is parsed."""
	if actual == null or actual._live == null or actual._loading or actual._live.header.size() != 4 \
			or not owns(profile) or revision != 1 or content != CONTENT or actual._live.header[0] != content \
			or actual._live.header[1] != PROFILE_COUNT or actual._live.header[2] != BOX_COUNT \
			or actual._live.header[3] != SOURCE_COUNT:
		return &"ASSEMBLY_SOURCE_PROFILE"
	if Profiles.selection_policy_leaf(actual, profile, revision, content) != Profiles.POLICY_ASSEMBLY_HANDLING \
			or actual._live.flags[profile] != Profiles.CERT_REQUIRED \
			or actual._live.quantities[Profiles.L_QUANTITY_MIN * actual._profile_capacity + profile] != 0 \
			or actual._live.quantities[Profiles.L_QUANTITY_MAX * actual._profile_capacity + profile] != 0:
		return &"ASSEMBLY_SOURCE_PROFILE"
	if not _fields_match(actual, profile) or not _boxes_match(actual, profile) or not _digests_match(actual):
		return &"ASSEMBLY_SOURCE_PROFILE"
	return &""


static func _fields_match(actual: Profiles, profile: int) -> bool:
	"""Every descriptor word."""
	for field: int in Profiles.I32_FIELDS:
		if actual._live.fields[field * actual._profile_capacity + profile] != _field(profile, field): return false
	return true


static func _boxes_match(actual: Profiles, profile: int) -> bool:
	"""All seven complete role/box words, in published order."""
	var first: int = first_box(profile)
	for ordinal: int in ROLE_COUNT:
		for field: int in 7:
			if actual._live.boxes[field * actual._box_capacity + first + ordinal] != box_word(profile, ordinal, field):
				return false
	return true


static func _digests_match(actual: Profiles) -> bool:
	"""Source 5 is the paw v2 image and source 4 the claw v2 image whose stand key 8 its ready joins equal."""
	for byte: int in 32:
		if actual._live.sources[Claw.SOURCE * 32 + byte] != Parent._digest_byte(Pins.CLAW_SOURCE_SHA, byte) \
				or actual._live.sources[SOURCE * 32 + byte] != Parent._digest_byte(Pins.PAW_SOURCE_SHA, byte):
			return false
	return true


static func first_box(profile: int) -> int:
	"""The row's first box in content 10."""
	return TREAD_FIRST_BOX if is_tread(profile) else L0_T0_FIRST_BOX


static func _field(profile: int, field: int) -> int:
	"""The adult Mole, tool-free, empty-handed BUILD tuple of both rows."""
	match field:
		Profiles.F_SOURCE: return SOURCE
		Profiles.F_SPECIES, Profiles.F_RIG: return 6
		Profiles.F_MODE: return Profiles.MODE_WORK
		Profiles.F_TOOL, Profiles.F_TOOL_VARIANT, Profiles.F_CARGO, Profiles.F_CARGO_VARIANT: return -1
		Profiles.F_STATES: return STATES
		Profiles.F_FIRST_BOX: return first_box(profile)
		Profiles.F_BOX_COUNT: return ROLE_COUNT
		Profiles.F_WORK_KIND: return Profiles.Work.JobsScript.JOB_KIND_BUILD
		Profiles.F_CONTACT_KIND: return Profiles.CONTACT_ASSEMBLY_PALM
	return 0


static func box_word(profile: int, ordinal: int, field: int) -> int:
	"""One published box word of row 65 or 66."""
	if not owns(profile) or ordinal < 0 or ordinal >= ROLE_COUNT or field < 0 or field > 6: return -2147483648
	return TREAD_BOXES[ordinal * 7 + field] if is_tread(profile) else L0_T0_BOXES[ordinal * 7 + field]


static func volume_word(profile: int, part: int, field: int) -> int:
	"""The station's physical volumes, read from the row's own boxes: part 0 the union of every body word above the
	floor (BODY, TURN, APPROACH), part 1 the authored stance (which contains every below-floor foot residual)."""
	if not owns(profile) or part < 0 or part >= PART_COUNT or field < 0 or field > 5: return -2147483648
	var result: int = 2147483647 if field < 3 else -2147483648
	for ordinal: int in ROLE_COUNT:
		var stance: bool = box_word(profile, ordinal, 6) == Profiles.STANCE_SUPPORT
		if (part == 1) != stance or (part == 0 and box_word(profile, ordinal, 1) < 0): continue
		var value: int = box_word(profile, ordinal, field)
		result = mini(result, value) if field < 3 else maxi(result, value)
	return result


static func clip_of(profile: int, phase: int) -> int:
	"""The paw v2 image clip of a handling phase: entry for entry/retrace, recovery after seating."""
	var entry: int = TREAD_ENTRY_CLIP if is_tread(profile) else L0_T0_ENTRY_CLIP
	return entry + Clock.CLIP_RECOVERY if phase == Clock.RECOVERY or phase == Clock.HANDLED_READY else entry


static func word(route_phase: int, source_phase: int) -> int:
	"""The handling encoding in the existing phase column; callers own every canonical write."""
	return TAG | (source_phase << 2) | route_phase


static func clock_refusal(source_word: int, source_clock: int, profile: int) -> StringName:
	"""Stationary integer ticks allow IDLE or physical HELD only; no queue or spare clock lane."""
	if (source_word & ~63) != TAG or not owns(profile) or ((source_word & 3) != 0 and (source_word & 3) != 3) \
			or source_clock < 0 or source_clock >= Clock.DURATION or source_clock % Clock.ONE != 0:
		return &"ASSEMBLY_SOURCE_CLOCK"
	return &"" if Clock.state_valid((source_word >> 2) & 15, source_clock) else &"ASSEMBLY_SOURCE_CLOCK"
