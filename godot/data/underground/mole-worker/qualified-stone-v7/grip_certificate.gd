extends RefCounted
## ADR1198/1206: certificate for the curved two-hand haul grips of content 6. It covers two cargo families, each a
## CARRY row plus four HAUL grip rows (load and unload, at yaw 0 and the quarter turn):
##   family 0, wood  (item 60): rows 32-36, source 2 (native haul image v8), haul-rows-v1/rows.json;
##   family 1, stone (item 53): rows 37-41, source 3 (native stone image v9), stone-rows-v1/rows.json.
## As in content 5's certificate (qualified-haul-v6/grip_certificate.gd, row 29's assembly-palm precedent),
## every published descriptor word, box and the source image digest must match exactly, because each offline
## contact proof holds only for its own mesh and the one stock transform S = R + (0,0,-576) at yaw 0. At runtime
## the certificate proves that transform and that each witnessed contact lies in both the hand's body volume and
## the stock's volume. It supplies source identity and station geometry only, never a Job, payment, route or World
## permission.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-stone-v7/catalog_source.gd")
const CONTENT_REVISION: int = 6
const FIRST: int = 32
const LAST: int = 41
const FAMILY_ROWS: int = 5
const QUANTITY_MILLI: int = 1000 # ADR1144/1198: whole-unit trips; CARRY and unload rows are 1000..1000.
const QUARTER: int = 16384
## Both families share R - S at yaw 0 (stone grip v1 kept wood's station; ADR 1206).
const R_MINUS_S: Vector3i = Vector3i(0, 0, 576)
## Per family: the two exact hand contacts as closed 1-u cells relative to S (rows.json station).
const CONTACT_CELLS: Array[int] = [
	-345, 101, -1, -344, 102, 0, 354, 92, 28, 355, 93, 29,
	-155, 112, 37, -154, 113, 38, 122, 171, 30, 123, 172, 31]
## Per family: descriptor words (Profiles F_* order) of the CARRY, yaw-0 load and yaw-0 unload rows; the
## quarter-turn rows equal their yaw-0 row with yaw 16384 and the next nine boxes.
const WORDS: Array[int] = [
	2, 6, 0, 6, 2, 0, -1, -1, 60, -1, 1, 0, 0, 453, 291, 7, -1, 0,
	2, 6, 0, 6, 3, 0, -1, -1, -1, -1, 0, 0, 0, 329, 298, 9, 0, 4,
	2, 6, 0, 6, 3, 0, -1, -1, 60, -1, 0, 0, 0, 329, 316, 9, 0, 4,
	3, 6, 0, 6, 2, 0, -1, -1, 53, -1, 1, 0, 0, 453, 334, 7, -1, 0,
	3, 6, 0, 6, 3, 0, -1, -1, -1, -1, 0, 0, 0, 329, 341, 9, 0, 4,
	3, 6, 0, 6, 3, 0, -1, -1, 53, -1, 0, 0, 0, 329, 359, 9, 0, 4]
## Per family, yaw-0 boxes (low xyz, high xyz, role) copied from rows.json as published: CARRY (7), load (9),
## unload (9). Stored family by family at offsets 0 / 175.
const BOXES: Array[int] = [
	-679, 0, -679, 679, 932, 679, 0, -286, -1, -286, 286, 0, 286, 0, -714, 447, -714, 714, 704, 714, 0,
	-375, -1, -375, 375, 0, 375, 1, -679, 0, -679, 679, 932, 679, 2, -286, -1, -286, 286, 0, 286, 2,
	-714, 447, -714, 714, 704, 714, 2,
	-430, 0, -589, 433, 849, 234, 0, -197, -1, -80, 171, 0, 61, 0, -276, -1, -169, 299, 0, 175, 1,
	-430, 0, -589, 433, 849, 234, 2, -197, -1, -80, 171, 0, 61, 2, -430, 0, -589, 433, 849, 234, 3,
	-197, -1, -80, 171, 0, 61, 3, -412, 0, -628, 412, 550, -332, 4, -412, -1, -579, 412, 0, -573, 4,
	-430, 0, -589, 433, 849, 234, 0, -197, -1, -80, 171, 0, 61, 0, -276, -1, -169, 299, 0, 175, 1,
	-430, 0, -589, 433, 849, 234, 2, -197, -1, -80, 171, 0, 61, 2, -423, 0, -436, 433, 849, 234, 3,
	-134, -1, -8, 171, 0, 60, 3, -412, 0, -628, 412, 550, -332, 4, -412, -1, -579, 412, 0, -573, 4,
	-556, 0, -556, 556, 937, 556, 0, -286, -1, -286, 286, 0, 286, 0, -598, 447, -598, 598, 821, 598, 0,
	-375, -1, -375, 375, 0, 375, 1, -556, 0, -556, 556, 937, 556, 2, -286, -1, -286, 286, 0, 286, 2,
	-598, 447, -598, 598, 821, 598, 2,
	-349, 0, -637, 346, 860, 234, 0, -197, -1, -80, 171, 0, 61, 0, -276, -1, -169, 299, 0, 175, 1,
	-349, 0, -637, 346, 860, 234, 2, -197, -1, -80, 171, 0, 61, 2, -349, 0, -637, 346, 860, 234, 3,
	-197, -1, -80, 171, 0, 61, 3, -174, 0, -779, 154, 704, -229, 4, 57, -1, -514, 60, 0, -504, 4,
	-349, 0, -637, 346, 860, 234, 0, -197, -1, -80, 171, 0, 61, 0, -276, -1, -169, 299, 0, 175, 1,
	-349, 0, -637, 346, 860, 234, 2, -197, -1, -80, 171, 0, 61, 2, -317, 0, -539, 317, 860, 234, 3,
	-134, -1, -8, 171, 0, 60, 3, -174, 0, -779, 154, 704, -229, 4, 57, -1, -514, 60, 0, -504, 4]
const FAMILY_BOX_WORDS: int = 175
const REFUSE_PROFILE: StringName = &"HAUL_GRIP_PROFILE"
const REFUSE_STATION: StringName = &"HAUL_GRIP_STATION"


static func uses(actual: Profiles) -> bool:
	"""Content 6 with all ten certified rows: hauling in this content is grip hauling at a stand."""
	if actual == null or actual._live == null or actual._loading or actual._live.header.size() != 4: return false
	for row: int in range(FIRST, LAST + 1):
		if profile_refusal(actual, row) != &"": return false
	return true


static func family_of(row: int) -> int:
	"""0 wood (rows 32-36), 1 stone (rows 37-41), -1 any other row."""
	if row < FIRST or row > LAST: return -1
	@warning_ignore("integer_division") var family: int = (row - FIRST) / FAMILY_ROWS
	return family


static func carry_of(family: int) -> int:
	"""The family's loaded-gait CARRY row."""
	return FIRST + FAMILY_ROWS * family


static func item_of(row: int) -> int:
	"""The compiled item a certified row hauls (its CARRY row's cargo word), or -1."""
	var family: int = family_of(row)
	return WORDS[family * 54 + Profiles.F_CARGO] if family >= 0 else -1


static func carry_row_for(item: int) -> int:
	"""The CARRY row certified for one compiled item, or -1: only wood and stone are certified."""
	for family: int in 2:
		if WORDS[family * 54 + Profiles.F_CARGO] == item: return carry_of(family)
	return -1


static func is_grip(row: int) -> bool:
	"""The four HAUL grip rows after each family's CARRY row."""
	return family_of(row) >= 0 and row != carry_of(family_of(row))


static func is_load(row: int) -> bool:
	"""The first two grip rows of a family lift the stock off the floor at S; the last two set it down."""
	var family: int = family_of(row)
	return family >= 0 and (row == carry_of(family) + 1 or row == carry_of(family) + 2)


static func yaw_of(row: int) -> int:
	"""Each grip row is exact at yaw 0 or a quarter turn (the even offsets within a family)."""
	var family: int = family_of(row)
	return QUARTER if family >= 0 and row != carry_of(family) and (row - carry_of(family)) % 2 == 0 else 0


static func turn(at: Vector3i, yaw: int) -> Vector3i:
	"""The adopted quarter turn (x,y,z) -> (z,y,-x) for yaw 16384; yaw 0 is the identity."""
	return Vector3i(at.z, at.y, -at.x) if yaw == QUARTER else at


static func stock_offset(yaw: int) -> Vector3i:
	"""S - R at a certified yaw: (0,0,-576) at yaw 0, (-576,0,0) at yaw 16384."""
	return turn(-R_MINUS_S, yaw)


static func profile_refusal(actual: Profiles, row: int) -> StringName:
	"""Exact descriptor words, revision, quantity, policy, boxes and the source image digest of one certified row."""
	var family: int = family_of(row)
	if actual == null or actual._live == null or actual._loading or actual._live.header.size() != 4 \
			or actual._live.header[0] != CONTENT_REVISION or family < 0 \
			or row >= actual._live.header[1] or actual._live.header[3] <= 2 + family: return REFUSE_PROFILE
	var capacity: int = actual._profile_capacity
	var quantity: int = QUANTITY_MILLI if row == carry_of(family) or not is_load(row) else 0
	if actual._live.flags[row] != Profiles.CERT_REQUIRED \
			or actual._live.flags[capacity + row] != Profiles.POLICY_AUTOMATIC \
			or actual._live.quantities[Profiles.L_REVISION * capacity + row] != 1 \
			or actual._live.quantities[Profiles.L_QUANTITY_MIN * capacity + row] != quantity \
			or actual._live.quantities[Profiles.L_QUANTITY_MAX * capacity + row] != quantity: return REFUSE_PROFILE
	for field: int in Profiles.I32_FIELDS:
		if actual._live.fields[field * capacity + row] != word(row, field): return REFUSE_PROFILE
	return &"" if _boxes_match(actual, row) and _digest_matches(actual, family) else REFUSE_PROFILE


static func _kind(row: int) -> int:
	"""0 CARRY, 1 load, 2 unload: the row's index into its family's WORDS and BOXES tables."""
	return 0 if row == carry_of(family_of(row)) else (1 if is_load(row) else 2)


static func word(row: int, field: int) -> int:
	"""Published descriptor word; the quarter-turn rows differ only in yaw and their first box."""
	var at: int = (family_of(row) * 3 + _kind(row)) * 18
	if field == Profiles.F_YAW: return yaw_of(row)
	if field == Profiles.F_FIRST_BOX:
		return WORDS[at + field] + (WORDS[at + Profiles.F_BOX_COUNT] if yaw_of(row) == QUARTER else 0)
	return WORDS[at + field]


static func box_word(row: int, ordinal: int, field: int) -> int:
	"""One published box word: yaw-0 words verbatim, quarter-turn rows as (z0, y0, -x1, z1, y1, -x0)."""
	var kind: int = _kind(row)
	var at: int = family_of(row) * FAMILY_BOX_WORDS + (0 if kind == 0 else 49 + 63 * (kind - 1)) + ordinal * 7
	if yaw_of(row) != QUARTER or field == 1 or field == 4 or field == 6: return BOXES[at + field]
	match field:
		0: return BOXES[at + 2]
		2: return -BOXES[at + 3]
		3: return BOXES[at + 5]
	return -BOXES[at]


static func _boxes_match(actual: Profiles, row: int) -> bool:
	"""Every published role/box word is mandatory; nothing is widened, clipped or reordered."""
	var first: int = word(row, Profiles.F_FIRST_BOX)
	if first + word(row, Profiles.F_BOX_COUNT) > actual._live.header[2]: return false
	for ordinal: int in word(row, Profiles.F_BOX_COUNT):
		for field: int in 7:
			if actual._live.boxes[field * actual._box_capacity + first + ordinal] != box_word(row, ordinal, field):
				return false
	return true


static func _digest_matches(actual: Profiles, family: int) -> bool:
	"""Each family's source image is the native program its poses and offline witnesses were taken from."""
	var expected: String = Pins.HAUL_SOURCE_SHA if family == 0 else Pins.STONE_SOURCE_SHA
	var source: int = 2 + family
	for byte: int in 32:
		var high: int = expected.unicode_at(byte * 2)
		var low: int = expected.unicode_at(byte * 2 + 1)
		var value: int = (high - (48 if high <= 57 else 87)) * 16 + low - (48 if low <= 57 else 87)
		if actual._live.sources[source * 32 + byte] != value: return false
	return true


static func station_refusal(actual: Profiles, row: int, root: Vector3i, yaw: int, stock: Vector3i) -> StringName:
	"""The worker root, its heading and the stock point S form the exact certified transform, and both witnessed
	hand contacts of the row's family lie inside the row's hand (body) volume and its stock volume there."""
	if not is_grip(row) or profile_refusal(actual, row) != &"": return REFUSE_PROFILE
	if yaw != yaw_of(row) or stock - root != stock_offset(yaw): return REFUSE_STATION
	var cells: int = family_of(row) * 12
	for contact: int in 2:
		var at: int = cells + 6 * contact
		var low: Vector3i = stock + turn(Vector3i(CONTACT_CELLS[at], CONTACT_CELLS[at + 1], CONTACT_CELLS[at + 2]), yaw)
		var high: Vector3i = stock + turn(Vector3i(CONTACT_CELLS[at + 3], CONTACT_CELLS[at + 4], CONTACT_CELLS[at + 5]), yaw)
		if not _in_role(row, Profiles.BODY_HELD_LOAD, root, low, high) \
				or not _in_role(row, Profiles.WORK_STROKE, root, low, high): return REFUSE_STATION
	return &"" if _in_role(row, Profiles.WORK_STROKE, root, stock, stock) else REFUSE_STATION


static func _in_role(row: int, role: int, root: Vector3i, first: Vector3i, second: Vector3i) -> bool:
	"""Some published box of the role, at the root, closes over the cell spanned by two turned corners."""
	for ordinal: int in word(row, Profiles.F_BOX_COUNT):
		if box_word(row, ordinal, 6) != role: continue
		var inside: bool = true
		for axis: int in 3:
			var low: int = mini(first[axis], second[axis])
			var high: int = maxi(first[axis], second[axis])
			if low < box_word(row, ordinal, axis) + root[axis] or high > box_word(row, ordinal, axis + 3) + root[axis]:
				inside = false
		if inside: return true
	return false
