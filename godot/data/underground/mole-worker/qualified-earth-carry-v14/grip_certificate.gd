extends RefCounted
## Decision 2042 (P-2042-2/3 (a), ruled 2026-10-16): the haul-grip certificate of content 13, the successor of
## `qualified-claw-runtime-v1/grip_certificate.gd` (contents 9/10) with a third cargo family:
##   family 0, wood  (item 60): rows 32-36, source 2, 1,000 milli-U a trip (unchanged);
##   family 1, stone (item 53): rows 37-41, source 3, 1,000 milli-U a trip (unchanged);
##   family 2, earth (item 11): rows 85-89, source 8, 5,000 milli-U a trip (P-2042-2 (a): the same 5,000 g).
## Earth is carried as the stone lump (P-2042-1 (a) "Stone lump, earth colour"), so the earth rows are the stone rows
## with source, cargo and quantity changed: their boxes, stands, contact cells and the transform S = R + (0,0,-576)
## are the stone family's own, and source 8 is the stone haul image v10 itself. A bank of any other content is
## handed to `qualified-claw-runtime-v1/grip_certificate.gd` (contents 6, 9 and 10), as that certificate hands
## content 6 to its own parent: the certificate follows the loaded content. Data only, not active: nothing preloads
## this until phase 2b mounts content 13. It supplies source identity and station geometry only, never a Job,
## payment, route or World permission.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Parent := preload("res://data/underground/mole-worker/qualified-stone-v7/grip_certificate.gd")
const Previous := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/grip_certificate.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-earth-carry-v14/catalog_source.gd")
const CONTENT_REVISION: int = 13
const FAMILIES: int = 3
const FAMILY_ROWS: int = Parent.FAMILY_ROWS
const EARTH_FAMILY: int = 2
const EARTH_FIRST: int = 85
const STONE_FIRST: int = 37
const QUARTER: int = Parent.QUARTER
## Wood's and stone's trip, as every earlier certificate names it; earth's is `quantity_of`.
const QUANTITY_MILLI: int = Parent.QUANTITY_MILLI
## Per family: the trip quantity of its CARRY and unload rows (load rows are 0..0).
const FAMILY_QUANTITY_MILLI: Array[int] = [Parent.QUANTITY_MILLI, Parent.QUANTITY_MILLI, Pins.EARTH_QUANTITY_MILLI]
## Per family: the source holding its rows.
const SOURCES: Array[int] = [2, 3, Pins.EARTH_LEVEL_SOURCE]
## The earth family's first box at yaw 0 for its CARRY, load and unload rows, as content 13 publishes them.
const EARTH_FIRST_BOX: Array[int] = [637, 644, 662]
const REFUSE_PROFILE: StringName = Parent.REFUSE_PROFILE
const REFUSE_STATION: StringName = Parent.REFUSE_STATION


static func uses(actual: Profiles) -> bool:
	"""Content 13 with all fifteen certified rows; any other content is its own certificate's question."""
	if actual == null or actual._live == null or actual._loading or actual._live.header.size() != 4: return false
	if actual._live.header[0] != CONTENT_REVISION: return Previous.uses(actual)
	for family: int in FAMILIES:
		for offset: int in FAMILY_ROWS:
			if profile_refusal(actual, carry_of(family) + offset) != &"": return false
	return true


static func family_of(row: int) -> int:
	"""0 wood (32-36), 1 stone (37-41), 2 earth (85-89), -1 any other row."""
	if row >= EARTH_FIRST and row < EARTH_FIRST + FAMILY_ROWS: return EARTH_FAMILY
	return Parent.family_of(row)


static func carry_of(family: int) -> int:
	"""The family's loaded-gait CARRY row, or -1."""
	if family == EARTH_FAMILY: return EARTH_FIRST
	return Parent.carry_of(family) if family == 0 or family == 1 else -1


static func template_of(row: int) -> int:
	"""The content-6 row whose words and boxes a certified row repeats: itself, or the stone row for earth."""
	return row - EARTH_FIRST + STONE_FIRST if family_of(row) == EARTH_FAMILY else row


static func item_of(row: int) -> int:
	"""The compiled item a certified row hauls (its family's CARRY cargo word), or -1."""
	if family_of(row) == EARTH_FAMILY: return Pins.EARTH_ITEM
	return Parent.item_of(row)


static func carry_row_for(item: int) -> int:
	"""The CARRY row certified for one compiled item, or -1: wood, stone and earth."""
	if item == Pins.EARTH_ITEM: return EARTH_FIRST
	return Parent.carry_row_for(item)


static func quantity_of(item: int) -> int:
	"""One trip's quantity for a certified item, or -1: 5,000 milli-U of earth, 1,000 of wood or stone."""
	var row: int = carry_row_for(item)
	return FAMILY_QUANTITY_MILLI[family_of(row)] if row >= 0 else -1


static func is_grip(row: int) -> bool:
	"""The four HAUL grip rows after each family's CARRY row."""
	return family_of(row) >= 0 and row != carry_of(family_of(row))


static func is_load(row: int) -> bool:
	"""The first two grip rows of a family lift the stock; the last two set it down (any other row: false)."""
	return Parent.is_load(template_of(row))


static func yaw_of(row: int) -> int:
	"""Each grip row is exact at yaw 0 or a quarter turn, as its template."""
	return Parent.yaw_of(template_of(row)) if family_of(row) >= 0 else 0


static func turn(at: Vector3i, yaw: int) -> Vector3i:
	"""The adopted quarter turn (x,y,z) -> (z,y,-x) for yaw 16384; yaw 0 is the identity."""
	return Parent.turn(at, yaw)


static func stock_offset(yaw: int) -> Vector3i:
	"""S - R at a certified yaw, shared by all three families."""
	return Parent.stock_offset(yaw)


static func word(row: int, field: int) -> int:
	"""Published descriptor word: the template's, with the earth family's source, cargo and first box."""
	if family_of(row) != EARTH_FAMILY: return Parent.word(row, field)
	var stone: int = template_of(row)
	if field == Profiles.F_SOURCE: return SOURCES[EARTH_FAMILY]
	if field == Profiles.F_CARGO and Parent.word(stone, field) != -1: return Pins.EARTH_ITEM
	if field == Profiles.F_FIRST_BOX:
		var kind: int = 0 if stone == STONE_FIRST else (1 if Parent.is_load(stone) else 2)
		return EARTH_FIRST_BOX[kind] + (Parent.word(stone, Profiles.F_BOX_COUNT) if yaw_of(row) == QUARTER else 0)
	return Parent.word(stone, field)


static func profile_refusal(actual: Profiles, row: int) -> StringName:
	"""Exact descriptor words, revision, quantity, policy, boxes and source image digest of one certified row; a bank
	of another content is the previous certificate's."""
	var family: int = family_of(row)
	if actual != null and actual._live != null and actual._live.header.size() == 4 \
			and actual._live.header[0] != CONTENT_REVISION:
		return Previous.profile_refusal(actual, row) # Rows 85-89 are no family there: refused.
	if actual == null or actual._live == null or actual._loading or actual._live.header.size() != 4 \
			or family < 0 \
			or row >= actual._live.header[1] or actual._live.header[3] <= SOURCES[family]: return REFUSE_PROFILE
	var capacity: int = actual._profile_capacity
	var quantity: int = FAMILY_QUANTITY_MILLI[family] if row == carry_of(family) or not is_load(row) else 0
	if actual._live.flags[row] != Profiles.CERT_REQUIRED \
			or actual._live.flags[capacity + row] != Profiles.POLICY_AUTOMATIC \
			or actual._live.quantities[Profiles.L_REVISION * capacity + row] != 1 \
			or actual._live.quantities[Profiles.L_QUANTITY_MIN * capacity + row] != quantity \
			or actual._live.quantities[Profiles.L_QUANTITY_MAX * capacity + row] != quantity: return REFUSE_PROFILE
	for field: int in Profiles.I32_FIELDS:
		if actual._live.fields[field * capacity + row] != word(row, field): return REFUSE_PROFILE
	return &"" if _boxes_match(actual, row) and _digest_matches(actual, family) else REFUSE_PROFILE


static func _boxes_match(actual: Profiles, row: int) -> bool:
	"""Every box word is the template's, at the row's own first box."""
	var first: int = word(row, Profiles.F_FIRST_BOX)
	var count: int = word(row, Profiles.F_BOX_COUNT)
	if first + count > actual._live.header[2]: return false
	for ordinal: int in count:
		for field: int in 7:
			if actual._live.boxes[field * actual._box_capacity + first + ordinal] \
					!= Parent.box_word(template_of(row), ordinal, field): return false
	return true


static func _digest_matches(actual: Profiles, family: int) -> bool:
	"""Wood's source is the wood haul image v10; stone's and earth's are the stone haul image v10."""
	var expected: String = Pins.HAUL_SOURCE_SHA if family == 0 else Pins.STONE_SOURCE_SHA
	var source: int = SOURCES[family]
	for byte: int in 32:
		if actual._live.sources[source * 32 + byte] != _hex(expected, byte * 2) * 16 + _hex(expected, byte * 2 + 1):
			return false
	return true


static func _hex(text: String, at: int) -> int:
	"""One lower-case hex digit's value, read without allocating (the predecessors' arithmetic)."""
	var code: int = text.unicode_at(at)
	return code - (48 if code <= 57 else 87)


static func station_refusal(actual: Profiles, row: int, root: Vector3i, yaw: int, stock: Vector3i) -> StringName:
	"""The template's transform and both witnessed hand contacts (content 6's equations), on this row's own check; a
	bank of another content is the previous certificate's."""
	if actual != null and actual._live != null and actual._live.header.size() == 4 \
			and actual._live.header[0] != CONTENT_REVISION:
		return Previous.station_refusal(actual, row, root, yaw, stock) # Rows 85-89: refused there.
	if not is_grip(row) or profile_refusal(actual, row) != &"": return REFUSE_PROFILE
	if yaw != yaw_of(row) or stock - root != Parent.stock_offset(yaw): return REFUSE_STATION
	var template: int = template_of(row)
	var cells: int = Parent.family_of(template) * 12
	for contact: int in 2:
		var at: int = cells + 6 * contact
		var low: Vector3i = stock + Parent.turn(Vector3i(Parent.CONTACT_CELLS[at], Parent.CONTACT_CELLS[at + 1],
			Parent.CONTACT_CELLS[at + 2]), yaw)
		var high: Vector3i = stock + Parent.turn(Vector3i(Parent.CONTACT_CELLS[at + 3], Parent.CONTACT_CELLS[at + 4],
			Parent.CONTACT_CELLS[at + 5]), yaw)
		if not Parent._in_role(template, Profiles.BODY_HELD_LOAD, root, low, high) \
				or not Parent._in_role(template, Profiles.WORK_STROKE, root, low, high): return REFUSE_STATION
	return &"" if Parent._in_role(template, Profiles.WORK_STROKE, root, stock, stock) else REFUSE_STATION
