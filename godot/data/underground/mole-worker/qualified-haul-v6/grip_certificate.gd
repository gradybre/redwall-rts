extends RefCounted
## ADR1198: certificate for the curved two-hand haul grip of content-5 rows 33-36, and the CARRY row 32 Delivery
## reaches over. It follows row 29's assembly-palm precedent (qualified-assembly-v1/source_program.gd): every
## published descriptor word, box and the haul image digest must match exactly, because the offline contact proof
## (haul-handling-v1/evidence/haul-rows-v1/rows.json, both hand vertices exactly on wood-mesh edges) holds only for
## that geometry and the one stock transform S = R + (0,0,-576) at yaw 0. At runtime the certificate proves that
## transform and that each witnessed contact lies in both the hand's body volume and the stock's volume.
## It supplies source identity and station geometry only, never a Job, payment, route or World permission.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-haul-v6/catalog_source.gd")
const CONTENT_REVISION: int = 5
const SOURCE: int = 2
const CARRY: int = 32
const LOAD_YAW_0: int = 33
const UNLOAD_YAW_0: int = 35
const FIRST: int = 32
const LAST: int = 36
const QUANTITY_MILLI: int = 1000 # ADR1144/1198: whole-unit trips; rows 32/35/36 quantity 1000..1000.
const QUARTER: int = 16384
## rows.json station: R - S at yaw 0, and the two exact hand contacts as closed 1-u cells relative to S.
const R_MINUS_S: Vector3i = Vector3i(0, 0, 576)
const CONTACT_CELLS: Array[int] = [-345, 101, -1, -344, 102, 0, 354, 92, 28, 355, 93, 29]
## Descriptor words (Profiles F_* order) of rows 32, 33 and 35; rows 34/36 equal 33/35 with yaw 16384 and the
## next nine boxes.
const WORDS_CARRY: Array[int] = [2, 6, 0, 6, 2, 0, -1, -1, 60, -1, 1, 0, 0, 453, 291, 7, -1, 0]
const WORDS_LOAD: Array[int] = [2, 6, 0, 6, 3, 0, -1, -1, -1, -1, 0, 0, 0, 329, 298, 9, 0, 4]
const WORDS_UNLOAD: Array[int] = [2, 6, 0, 6, 3, 0, -1, -1, 60, -1, 0, 0, 0, 329, 316, 9, 0, 4]
## Yaw-0 boxes (low xyz, high xyz, role), copied from rows.json as published; the 16384 rows are their quarter turn.
const BOXES_CARRY: Array[int] = [
	-679, 0, -679, 679, 932, 679, 0, -286, -1, -286, 286, 0, 286, 0, -714, 447, -714, 714, 704, 714, 0,
	-375, -1, -375, 375, 0, 375, 1, -679, 0, -679, 679, 932, 679, 2, -286, -1, -286, 286, 0, 286, 2,
	-714, 447, -714, 714, 704, 714, 2]
const BOXES_LOAD: Array[int] = [
	-430, 0, -589, 433, 849, 234, 0, -197, -1, -80, 171, 0, 61, 0, -276, -1, -169, 299, 0, 175, 1,
	-430, 0, -589, 433, 849, 234, 2, -197, -1, -80, 171, 0, 61, 2, -430, 0, -589, 433, 849, 234, 3,
	-197, -1, -80, 171, 0, 61, 3, -412, 0, -628, 412, 550, -332, 4, -412, -1, -579, 412, 0, -573, 4]
const BOXES_UNLOAD: Array[int] = [
	-430, 0, -589, 433, 849, 234, 0, -197, -1, -80, 171, 0, 61, 0, -276, -1, -169, 299, 0, 175, 1,
	-430, 0, -589, 433, 849, 234, 2, -197, -1, -80, 171, 0, 61, 2, -423, 0, -436, 433, 849, 234, 3,
	-134, -1, -8, 171, 0, 60, 3, -412, 0, -628, 412, 550, -332, 4, -412, -1, -579, 412, 0, -573, 4]
const REFUSE_PROFILE: StringName = &"HAUL_GRIP_PROFILE"
const REFUSE_STATION: StringName = &"HAUL_GRIP_STATION"


static func uses(actual: Profiles) -> bool:
	"""Content 5 with all five certified rows: hauling in this content is grip hauling at a stand."""
	if actual == null or actual._live == null or actual._loading or actual._live.header.size() != 4: return false
	for row: int in range(FIRST, LAST + 1):
		if profile_refusal(actual, row) != &"": return false
	return true


static func is_grip(row: int) -> bool:
	"""Rows 33-36 are the HAUL grip rows; 32 is the loaded gait."""
	return row > CARRY and row <= LAST


static func is_load(row: int) -> bool:
	"""Rows 33/34 lift the stock off the floor at S; 35/36 set it down there."""
	return row == LOAD_YAW_0 or row == LOAD_YAW_0 + 1


static func yaw_of(row: int) -> int:
	"""Each grip row is exact at yaw 0 (33, 35) or a quarter turn (34, 36)."""
	return QUARTER if row == LOAD_YAW_0 + 1 or row == UNLOAD_YAW_0 + 1 else 0


static func turn(at: Vector3i, yaw: int) -> Vector3i:
	"""The adopted quarter turn (x,y,z) -> (z,y,-x) for yaw 16384; yaw 0 is the identity."""
	return Vector3i(at.z, at.y, -at.x) if yaw == QUARTER else at


static func stock_offset(yaw: int) -> Vector3i:
	"""S - R at a certified yaw: (0,0,-576) at yaw 0, (-576,0,0) at yaw 16384."""
	return turn(-R_MINUS_S, yaw)


static func profile_refusal(actual: Profiles, row: int) -> StringName:
	"""Exact descriptor words, revision, quantity, policy, boxes and the haul image digest of one certified row."""
	if actual == null or actual._live == null or actual._loading or actual._live.header.size() != 4 \
			or actual._live.header[0] != CONTENT_REVISION or row < FIRST or row > LAST \
			or row >= actual._live.header[1] or actual._live.header[3] <= SOURCE: return REFUSE_PROFILE
	var capacity: int = actual._profile_capacity
	var quantity: int = QUANTITY_MILLI if row == CARRY or row > LOAD_YAW_0 + 1 else 0
	if actual._live.flags[row] != Profiles.CERT_REQUIRED \
			or actual._live.flags[capacity + row] != Profiles.POLICY_AUTOMATIC \
			or actual._live.quantities[Profiles.L_REVISION * capacity + row] != 1 \
			or actual._live.quantities[Profiles.L_QUANTITY_MIN * capacity + row] != quantity \
			or actual._live.quantities[Profiles.L_QUANTITY_MAX * capacity + row] != quantity: return REFUSE_PROFILE
	for field: int in Profiles.I32_FIELDS:
		if actual._live.fields[field * capacity + row] != word(row, field): return REFUSE_PROFILE
	return &"" if _boxes_match(actual, row) and _digest_matches(actual) else REFUSE_PROFILE


static func word(row: int, field: int) -> int:
	"""Published descriptor word; the quarter-turn rows differ only in yaw and their first box."""
	var words: Array[int] = WORDS_CARRY if row == CARRY else (WORDS_LOAD if is_load(row) else WORDS_UNLOAD)
	if field == Profiles.F_YAW: return yaw_of(row)
	if field == Profiles.F_FIRST_BOX: return words[field] + (words[Profiles.F_BOX_COUNT] if yaw_of(row) == QUARTER else 0)
	return words[field]


static func box_word(row: int, ordinal: int, field: int) -> int:
	"""One published box word: yaw-0 words verbatim, quarter-turn rows as (z0, y0, -x1, z1, y1, -x0)."""
	var boxes: Array[int] = BOXES_CARRY if row == CARRY else (BOXES_LOAD if is_load(row) else BOXES_UNLOAD)
	var at: int = ordinal * 7
	if yaw_of(row) != QUARTER or field == 1 or field == 4 or field == 6: return boxes[at + field]
	match field:
		0: return boxes[at + 2]
		2: return -boxes[at + 3]
		3: return boxes[at + 5]
	return -boxes[at]


static func _boxes_match(actual: Profiles, row: int) -> bool:
	"""Every published role/box word is mandatory; nothing is widened, clipped or reordered."""
	var first: int = word(row, Profiles.F_FIRST_BOX)
	if first + word(row, Profiles.F_BOX_COUNT) > actual._live.header[2]: return false
	for ordinal: int in word(row, Profiles.F_BOX_COUNT):
		for field: int in 7:
			if actual._live.boxes[field * actual._box_capacity + first + ordinal] != box_word(row, ordinal, field):
				return false
	return true


static func _digest_matches(actual: Profiles) -> bool:
	"""The haul image (source 2) is the native program v8 whose poses the offline witnesses were taken from."""
	for byte: int in 32:
		var high: int = Pins.HAUL_SOURCE_SHA.unicode_at(byte * 2)
		var low: int = Pins.HAUL_SOURCE_SHA.unicode_at(byte * 2 + 1)
		var value: int = (high - (48 if high <= 57 else 87)) * 16 + low - (48 if low <= 57 else 87)
		if actual._live.sources[SOURCE * 32 + byte] != value: return false
	return true


static func station_refusal(actual: Profiles, row: int, root: Vector3i, yaw: int, stock: Vector3i) -> StringName:
	"""The worker root, its heading and the stock point S form the exact certified transform, and both witnessed
	hand contacts lie inside the row's hand (body) volume and its stock volume at that transform."""
	if not is_grip(row) or profile_refusal(actual, row) != &"": return REFUSE_PROFILE
	if yaw != yaw_of(row) or stock - root != stock_offset(yaw): return REFUSE_STATION
	for contact: int in 2:
		var low: Vector3i = stock + turn(Vector3i(CONTACT_CELLS[6 * contact], CONTACT_CELLS[6 * contact + 1],
			CONTACT_CELLS[6 * contact + 2]), yaw)
		var high: Vector3i = stock + turn(Vector3i(CONTACT_CELLS[6 * contact + 3], CONTACT_CELLS[6 * contact + 4],
			CONTACT_CELLS[6 * contact + 5]), yaw)
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
