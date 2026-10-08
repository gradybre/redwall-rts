extends RefCounted
## ADR 1217 step 5: the haul-grip certificate of content 9. Content 7 swapped sources 2 and 3 to the haul images wood
## v10 and stone v10 (the corrected stand, walk and joins of ADR 1217 step 1c) and kept every descriptor word and box
## of the grip rows 32-41; so the certificate is content 6's (`qualified-stone-v7/grip_certificate.gd`) with the
## content revision and the two image digests renewed. Every row table, contact cell and station equation is that
## certificate's own. It supplies source identity and station geometry only, never a Job, payment, route or World
## permission.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Parent := preload("res://data/underground/mole-worker/qualified-stone-v7/grip_certificate.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-claw-approach-v10/catalog_source.gd")
const CONTENT_REVISION: int = 9
const FIRST: int = Parent.FIRST
const LAST: int = Parent.LAST
const QUANTITY_MILLI: int = Parent.QUANTITY_MILLI
const QUARTER: int = Parent.QUARTER
const REFUSE_PROFILE: StringName = Parent.REFUSE_PROFILE
const REFUSE_STATION: StringName = Parent.REFUSE_STATION


static func uses(actual: Profiles) -> bool:
	"""Content 9 with all ten certified rows: hauling in this content is grip hauling at a stand."""
	if actual == null or actual._live == null or actual._loading or actual._live.header.size() != 4: return false
	for row: int in range(FIRST, LAST + 1):
		if profile_refusal(actual, row) != &"": return false
	return true


static func family_of(row: int) -> int:
	"""0 wood (rows 32-36), 1 stone (rows 37-41), -1 any other row."""
	return Parent.family_of(row)


static func carry_of(family: int) -> int:
	"""The family's loaded-gait CARRY row."""
	return Parent.carry_of(family)


static func item_of(row: int) -> int:
	"""The compiled item a certified row hauls, or -1."""
	return Parent.item_of(row)


static func carry_row_for(item: int) -> int:
	"""The CARRY row certified for one compiled item, or -1: only wood and stone are certified."""
	return Parent.carry_row_for(item)


static func is_grip(row: int) -> bool:
	"""The four HAUL grip rows after each family's CARRY row."""
	return Parent.is_grip(row)


static func is_load(row: int) -> bool:
	"""The first two grip rows of a family lift the stock; the last two set it down."""
	return Parent.is_load(row)


static func yaw_of(row: int) -> int:
	"""Each grip row is exact at yaw 0 or a quarter turn."""
	return Parent.yaw_of(row)


static func turn(at: Vector3i, yaw: int) -> Vector3i:
	"""The adopted quarter turn (x,y,z) -> (z,y,-x) for yaw 16384; yaw 0 is the identity."""
	return Parent.turn(at, yaw)


static func stock_offset(yaw: int) -> Vector3i:
	"""S - R at a certified yaw: (0,0,-576) at yaw 0, (-576,0,0) at yaw 16384."""
	return Parent.stock_offset(yaw)


static func profile_refusal(actual: Profiles, row: int) -> StringName:
	"""Exact descriptor words, revision, quantity, policy, boxes and the v10 source image digest of one row."""
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
		if actual._live.fields[field * capacity + row] != Parent.word(row, field): return REFUSE_PROFILE
	return &"" if Parent._boxes_match(actual, row) and _digest_matches(actual, family) else REFUSE_PROFILE


static func _digest_matches(actual: Profiles, family: int) -> bool:
	"""Each family's source is its v10 haul image (wood v10 at source 2, stone v10 at source 3)."""
	var expected: String = Pins.HAUL_SOURCE_SHA if family == 0 else Pins.STONE_SOURCE_SHA
	var source: int = 2 + family
	for byte: int in 32:
		var high: int = expected.unicode_at(byte * 2)
		var low: int = expected.unicode_at(byte * 2 + 1)
		var value: int = (high - (48 if high <= 57 else 87)) * 16 + low - (48 if low <= 57 else 87)
		if actual._live.sources[source * 32 + byte] != value: return false
	return true


static func station_refusal(actual: Profiles, row: int, root: Vector3i, yaw: int, stock: Vector3i) -> StringName:
	"""The worker root, heading and stock point S form the certified transform, and both witnessed hand contacts lie
	in the row's hand and stock volumes there (content 6's equations, unchanged)."""
	if not is_grip(row) or profile_refusal(actual, row) != &"": return REFUSE_PROFILE
	if yaw != yaw_of(row) or stock - root != stock_offset(yaw): return REFUSE_STATION
	var cells: int = family_of(row) * 12
	for contact: int in 2:
		var at: int = cells + 6 * contact
		var low: Vector3i = stock + turn(Vector3i(Parent.CONTACT_CELLS[at], Parent.CONTACT_CELLS[at + 1],
			Parent.CONTACT_CELLS[at + 2]), yaw)
		var high: Vector3i = stock + turn(Vector3i(Parent.CONTACT_CELLS[at + 3], Parent.CONTACT_CELLS[at + 4],
			Parent.CONTACT_CELLS[at + 5]), yaw)
		if not Parent._in_role(row, Profiles.BODY_HELD_LOAD, root, low, high) \
				or not Parent._in_role(row, Profiles.WORK_STROKE, root, low, high): return REFUSE_STATION
	return &"" if Parent._in_role(row, Profiles.WORK_STROKE, root, stock, stock) else REFUSE_STATION
