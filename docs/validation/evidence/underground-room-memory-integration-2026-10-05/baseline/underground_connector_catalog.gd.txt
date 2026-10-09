extends RefCounted
## Immutable fixed geometry and exact authored pace. No route, excavation, grip or load permission.
## Two streamed banks live inside the existing bindings arena; never the Profiles arena. Decision1080.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Movement := preload("res://scripts/core/movement.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Connectors := preload("res://scripts/core/room_connectors.gd")
const Geometry := preload("res://scripts/core/connector_geometry.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const MAX_VARIANTS: int = 16
const MAX_POINTS: int = 512
const MAX_REGIONS: int = 1024
const MAX_PARTS: int = 256
const MAX_VERTICES: int = 2048
const MAX_MATERIALS: int = 16
const MAX_PACES: int = 256
const MAX_OPENINGS_PER_VARIANT: int = 16 # Finite exact target list, not an implicit placement permission.
const VARIANT_FIELDS: int = 26
const PART_FIELDS: int = 9
const PACE_FIELDS: int = 7
const BANK_BYTES: int = 86008
const FIXED_RESERVE: int = 2048
const NATIVE_RESERVE: int = 16384 # Explicit reservation, not a measured native allocation claim.
const RESERVED_BYTES: int = 2 * BANK_BYTES + FIXED_RESERVE + NATIVE_RESERVE
const RATE_GROUND_CAP: int = 0
const RATE_AUTHORED: int = 1
const V_FAMILY: int = 0
const V_VARIANT: int = 1
const V_ROTATIONS: int = 2
const V_START: int = 3
const V_END: int = 6
const V_START_LEVEL: int = 9
const V_END_LEVEL: int = 10
const V_START_YAW: int = 11
const V_END_YAW: int = 12
const V_PATH_START: int = 13
const V_PATH_COUNT: int = 14
const V_REGION_START: int = 15
const V_REGION_COUNT: int = 16
const V_PART_START: int = 17
const V_PART_COUNT: int = 18
const V_VERTEX_START: int = 19
const V_VERTEX_COUNT: int = 20
const V_SPIRAL_X: int = 21
const V_SPIRAL_Z: int = 22
const V_MODE: int = 23
const V_POSTURE: int = 24
const V_OPENING_COUNT: int = 25
const P_PROFILE: int = 0
const P_FAMILY: int = 1
const P_VARIANT: int = 2
const P_MOVEMENT: int = 3
const P_MOVEMENT_REVISION: int = 4
const P_RATE: int = 5
const P_KIND: int = 6


class Record extends RefCounted:

	## Caller-owned scalar metadata. Every refused query leaves it unchanged.
	var catalog_id: int = -1
	var revision: int = 0
	var content_revision: int = 0
	var family: int = -1
	var variant: int = -1
	var allowed_rotations: int = 0
	var start: Vector3i = Vector3i.ZERO
	var end: Vector3i = Vector3i.ZERO
	var start_level_offset: int = 0
	var end_level_offset: int = 0
	var start_yaw: int = 0
	var end_yaw: int = 0
	var mode: int = -1
	var posture: int = -1
	var point_count: int = 0
	var region_count: int = 0
	var part_count: int = 0
	var vertex_count: int = 0
	var opening_count: int = 0
	var spiral_centre_xz: Vector2i = Vector2i.ZERO


class Bank extends RefCounted:

	## Headers: revision, seven live counts, profile content revision, level revision, profile source id.
	var header: PackedInt64Array = PackedInt64Array()
	var variants: PackedInt32Array = PackedInt32Array()
	var variant_revisions: PackedInt64Array = PackedInt64Array()
	var points: PackedInt32Array = PackedInt32Array()
	var regions: PackedInt32Array = PackedInt32Array()
	var parts: PackedInt32Array = PackedInt32Array()
	var vertices: PackedInt32Array = PackedInt32Array()
	var materials: PackedInt32Array = PackedInt32Array()
	var paces: PackedInt32Array = PackedInt32Array()
	var pace_revisions: PackedInt64Array = PackedInt64Array()
	var digests: PackedByteArray = PackedByteArray() # actual catalog, expected profile source, expected levels.

	func allocate() -> void:
		"""All fixed arrays allocate only after the complete two-bank peak is admitted."""
		header.resize(11)
		variants.resize(VARIANT_FIELDS * MAX_VARIANTS)
		variant_revisions.resize(MAX_VARIANTS)
		points.resize(4 * MAX_POINTS)
		regions.resize(8 * MAX_REGIONS)
		parts.resize(PART_FIELDS * MAX_PARTS)
		vertices.resize(3 * MAX_VERTICES)
		materials.resize(MAX_MATERIALS)
		paces.resize(PACE_FIELDS * MAX_PACES)
		pace_revisions.resize(MAX_PACES)
		digests.resize(96)


var _live: Bank = Bank.new()
var _stage: Bank = Bank.new()
var _configured: bool = false
var _loading: bool = false
var _profiles: Profiles = null
var _levels: Levels = null
var _movement: Movement = null
var _residents: Residents = null
var _transforms: Transforms = null
var _descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
var _number: IntMath.IntResult = IntMath.IntResult.new()
var _hash: PackedByteArray = PackedByteArray()


func configure(arena_bytes: int) -> StringName:
	"""Admit both immutable images and fixed decode/query/native lifetime before any packed growth."""
	if _configured:
		return &"CONNECTOR_CATALOG_ALREADY_CONFIGURED"
	if arena_bytes != RESERVED_BYTES:
		return &"CONNECTOR_CATALOG_CAPACITY"
	_live.allocate()
	_stage.allocate()
	_hash.resize(32)
	_configured = true
	return &""


func bind_actual(profiles: Profiles, levels: Levels, movement: Movement, residents: Residents,
		transforms: Transforms, domain: Space.Domain) -> StringName:
	"""One exact composition; a numeric profile/species/world coincidence cannot bind a foreign owner."""
	if _profiles != null:
		return &"CONNECTOR_CATALOG_ALREADY_BOUND"
	if not _configured or profiles == null or levels == null or movement == null or residents == null \
			or transforms == null or domain == null:
		return &"CONNECTOR_CATALOG_UNBOUND"
	if not movement.is_bound_owners(residents.directory(), residents, transforms) \
			or not levels.binding_matches(domain, residents.directory(), Space.VERSION):
		return &"CONNECTOR_CATALOG_OWNER_MISMATCH"
	_profiles = profiles
	_levels = levels
	_movement = movement
	_residents = residents
	_transforms = transforms
	return &""


func binding_matches(profiles: Profiles, levels: Levels, movement: Movement, residents: Residents,
		transforms: Transforms, domain: Space.Domain) -> bool:
	"""The World must share the exact finite domain, live World and all actual pace/content instances."""
	return _configured and _profiles != null and _profiles == profiles and _levels == levels \
		and _movement == movement and _residents == residents and _transforms == transforms \
		and movement.is_bound_owners(residents.directory(), residents, transforms) \
		and levels.binding_matches(domain, residents.directory(), Space.VERSION)


func content_revision() -> int:
	"""A rejected/absent image never publishes a positive content revision."""
	return _live.header[0] if _configured else 0


func packed_memory_bytes() -> int:
	"""The extra32-byte reusable digest scratch belongs to the fixed2048-byte reservation."""
	return 2 * BANK_BYTES + 32 if _configured else 0


func content_hash_into(revision: int, out: PackedByteArray) -> bool:
	"""Copy a validated content digest; never expose a mutable bank array to World/save composition."""
	if revision < 1 or revision != content_revision() or out.size() != 32:
		return false
	for index: int in 32:
		out[index] = _live.digests[index]
	return true


func load_file(path: String, expected_sha256: String, revision: int) -> StringName:
	"""Decode and hash the same bounded stream; refusal preserves the previous immutable live image."""
	if not _configured or _loading or _profiles == null or revision <= content_revision() \
			or expected_sha256.length() != 64 or not expected_sha256.is_valid_hex_number(false):
		return &"CONNECTOR_CATALOG_SOURCE"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return &"CONNECTOR_CATALOG_SOURCE"
	_loading = true
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var code: StringName = _decode(file, digest, revision)
	var actual: PackedByteArray = digest.finish()
	file.close()
	if code == &"" and actual.hex_encode() != expected_sha256.to_lower():
		code = &"CONNECTOR_CATALOG_SOURCE_HASH"
	if code == &"":
		code = _validate_stage()
	if code == &"":
		for index: int in 32:
			_stage.digests[index] = actual[index]
		var old: Bank = _live
		_live = _stage
		_stage = old
	_loading = false
	return code


static func _read(file: FileAccess, digest: HashingContext, count: int) -> PackedByteArray:
	"""At most one bounded record is resident beside the preallocated banks and fixed query scratch."""
	var bytes: PackedByteArray = file.get_buffer(count)
	digest.update(bytes)
	return bytes


func _decode(file: FileAccess, digest: HashingContext, revision: int) -> StringName:
	"""Validate counts and the exact file size before any payload loop or multiplication."""
	var bytes: PackedByteArray = _read(file, digest, 72)
	if bytes.size() != 72 or bytes.slice(0, 8).get_string_from_ascii() != "UGCONN01" \
			or bytes.decode_u32(8) != 1 or bytes.decode_s64(12) != revision:
		return &"CONNECTOR_CATALOG_FORMAT"
	_stage.header[0] = revision
	const MAX_COUNTS: Array[int] = [MAX_VARIANTS, MAX_POINTS, MAX_REGIONS, MAX_PARTS, MAX_VERTICES, MAX_MATERIALS, MAX_PACES]
	const ROW_BYTES: Array[int] = [112, 16, 32, 36, 12, 4, 36]
	var expected: int = 144
	for at: int in 7:
		var count: int = bytes.decode_u32(20 + at * 4)
		if count < 1 or count > MAX_COUNTS[at]:
			return &"CONNECTOR_CATALOG_CAPACITY"
		_stage.header[at + 1] = count
		expected += count * ROW_BYTES[at]
	if file.get_length() != expected:
		return &"CONNECTOR_CATALOG_FORMAT"
	for at: int in 3:
		_stage.header[8 + at] = bytes.decode_s64(48 + at * 8)
	bytes = _read(file, digest, 64)
	if bytes.size() != 64:
		return &"CONNECTOR_CATALOG_FORMAT"
	for at: int in 64:
		_stage.digests[32 + at] = bytes[at]
	return _decode_payload(file, digest)


func _decode_payload(file: FileAccess, digest: HashingContext) -> StringName:
	"""Field-major destination columns never retain a row packet or a third complete source image."""
	var code: StringName = _decode_table(file, digest, _stage.variants, MAX_VARIANTS, 26, _stage.header[1], _stage.variant_revisions)
	if code == &"":
		code = _decode_table(file, digest, _stage.points, MAX_POINTS, 4, _stage.header[2])
	if code == &"":
		code = _decode_table(file, digest, _stage.regions, MAX_REGIONS, 8, _stage.header[3])
	if code == &"":
		code = _decode_table(file, digest, _stage.parts, MAX_PARTS, 9, _stage.header[4])
	if code == &"":
		code = _decode_table(file, digest, _stage.vertices, MAX_VERTICES, 3, _stage.header[5])
	if code == &"":
		code = _decode_table(file, digest, _stage.materials, MAX_MATERIALS, 1, _stage.header[6])
	if code == &"":
		code = _decode_table(file, digest, _stage.paces, MAX_PACES, 7, _stage.header[7], _stage.pace_revisions)
	if code != &"":
		return code
	var end: PackedByteArray = _read(file, digest, 8)
	return &"" if end.get_string_from_ascii() == "UGCEND01" else &"CONNECTOR_CATALOG_FORMAT"


static func _decode_table(file: FileAccess, digest: HashingContext, target: PackedInt32Array,
		capacity: int, fields: int, count: int, revisions: PackedInt64Array = PackedInt64Array()) -> StringName:
	"""A short read still refuses if the external file changes after its initial exact length check."""
	for row: int in count:
		var length: int = fields * 4 + (8 if not revisions.is_empty() else 0)
		var bytes: PackedByteArray = _read(file, digest, length)
		if bytes.size() != length:
			return &"CONNECTOR_CATALOG_FORMAT"
		for field: int in fields:
			target[field * capacity + row] = bytes.decode_s32(field * 4)
		if not revisions.is_empty():
			revisions[row] = bytes.decode_s64(fields * 4)
	return &""


static func _v(bank: Bank, row: int, field: int) -> int:
	"""A previously validated dense catalog row has no per-variant heap object."""
	return bank.variants[field * MAX_VARIANTS + row]


static func _p(bank: Bank, row: int, field: int) -> int:
	"""Pace rows carry exact profile and family identities; no wildcard or neighbouring-species fallback."""
	return bank.paces[field * MAX_PACES + row]


func _validate_stage() -> StringName:
	"""Validate source bindings, complete prefix census and every fixed integer table before swapping."""
	var code: StringName = _content_binding_refusal(_stage)
	if code != &"":
		return code
	var point_next: int = 0
	var region_next: int = 0
	var part_next: int = 0
	var vertex_next: int = 0
	for row: int in _stage.header[1]:
		if _v(_stage, row, V_PATH_START) != point_next or _v(_stage, row, V_REGION_START) != region_next \
				or _v(_stage, row, V_PART_START) != part_next or _v(_stage, row, V_VERTEX_START) != vertex_next:
			return &"CONNECTOR_CATALOG_CENSUS"
		code = _variant_refusal(row)
		if code != &"":
			return code
		point_next += _v(_stage, row, V_PATH_COUNT)
		region_next += _v(_stage, row, V_REGION_COUNT)
		part_next += _v(_stage, row, V_PART_COUNT)
		vertex_next += _v(_stage, row, V_VERTEX_COUNT)
	if point_next != _stage.header[2] or region_next != _stage.header[3] \
			or part_next != _stage.header[4] or vertex_next != _stage.header[5]:
		return &"CONNECTOR_CATALOG_CENSUS"
	for row: int in _stage.header[6]:
		if _stage.materials[row] < 1 or _stage.materials[row] > Geometry.MAX_LOCAL_U:
			return &"CONNECTOR_MATERIAL_SCALE"
	return _validate_paces()


func _content_binding_refusal(bank: Bank) -> StringName:
	"""Catalog replacement cannot silently inherit another physical source, level pack or retired World."""
	if _profiles == null or _levels == null or _movement == null or _residents == null \
			or not _movement.is_bound_owners(_residents.directory(), _residents, _transforms) or _levels.level_count() < 1:
		return &"CONNECTOR_CATALOG_UNBOUND"
	if bank.header[8] < 1 or bank.header[8] != _profiles.content_revision() \
			or bank.header[9] != _levels.content_revision() \
			or not _profiles.source_hash_into(bank.header[10], bank.header[8], _hash):
		return &"CONNECTOR_CATALOG_CONTENT_STALE"
	for at: int in 32:
		if _hash[at] != bank.digests[32 + at]:
			return &"CONNECTOR_CATALOG_CONTENT_STALE"
	if not _levels.content_hash_into(_hash):
		return &"CONNECTOR_CATALOG_CONTENT_STALE"
	for at: int in 32:
		if _hash[at] != bank.digests[64 + at]:
			return &"CONNECTOR_CATALOG_CONTENT_STALE"
	return &""


func _variant_refusal(row: int) -> StringName:
	"""Known family, exact authored rotation/mode and finite disjoint table spans precede all indexing."""
	var family: int = _v(_stage, row, V_FAMILY)
	var variant: int = _v(_stage, row, V_VARIANT)
	if family < 0 or family >= Connectors.FAMILY_COUNT or variant < 0 or _stage.variant_revisions[row] < 1 \
			or _v(_stage, row, V_ROTATIONS) < 1 or _v(_stage, row, V_ROTATIONS) > 15 \
			or _v(_stage, row, V_OPENING_COUNT) < 1 or _v(_stage, row, V_OPENING_COUNT) > MAX_OPENINGS_PER_VARIANT:
		return &"CONNECTOR_CATALOG_VARIANT"
	if row > 0 and (_v(_stage, row - 1, V_FAMILY) > family \
			or (_v(_stage, row - 1, V_FAMILY) == family and _v(_stage, row - 1, V_VARIANT) >= variant)):
		return &"CONNECTOR_CATALOG_ORDER"
	var mode: int = _v(_stage, row, V_MODE)
	if mode not in [Profiles.MODE_WALK, Profiles.MODE_CARRY, Profiles.MODE_CLIMB] \
			or (family == Connectors.LADDER_HATCH) != (mode == Profiles.MODE_CLIMB) \
			or _v(_stage, row, V_POSTURE) < 0 or _v(_stage, row, V_POSTURE) > Profiles.POSTURE_STOOPED:
		return &"CONNECTOR_CATALOG_MODE"
	var code: StringName = _variant_ranges_refusal(row)
	if code == &"":
		code = _path_refusal(row)
	if code == &"":
		code = _regions_refusal(row)
	return _parts_refusal(row) if code == &"" else code


func _variant_ranges_refusal(row: int) -> StringName:
	"""All relative coordinates fit the existing exact integer compiler; no later narrowing repairs input."""
	for field: int in range(V_START, V_END + 3):
		if absi(_v(_stage, row, field)) > Geometry.MAX_LOCAL_U:
			return &"CONNECTOR_GEOMETRY_OVERFLOW"
	if _v(_stage, row, V_START + 1) == _v(_stage, row, V_END + 1):
		return &"CONNECTOR_GEOMETRY_ENDPOINT"
	for field: int in [V_START_YAW, V_END_YAW]:
		if _v(_stage, row, field) < 0 or _v(_stage, row, field) >= 65536:
			return &"CONNECTOR_CATALOG_ORIENTATION"
	for field: int in [V_START_LEVEL, V_END_LEVEL]:
		if absi(_v(_stage, row, field)) > Levels.MAX_LEVELS:
			return &"CONNECTOR_GEOMETRY_ENDPOINT"
	for field: int in [V_SPIRAL_X, V_SPIRAL_Z]:
		if absi(_v(_stage, row, field)) > Geometry.MAX_LOCAL_U:
			return &"CONNECTOR_GEOMETRY_OVERFLOW"
	const SPANS: Array[int] = [V_PATH_START, V_REGION_START, V_PART_START, V_VERTEX_START]
	for index: int in 4:
		var first: int = _v(_stage, row, SPANS[index])
		var count: int = _v(_stage, row, SPANS[index] + 1)
		if first < 0 or count < (2 if index == 0 else 1) or first + count > _stage.header[index + 2]:
			return &"CONNECTOR_CATALOG_CENSUS"
	return &""


func _path_refusal(row: int) -> StringName:
	"""Explicit relative XYZ/yaw points describe every bend; matching floor levels cannot invent a path."""
	var begin: int = _v(_stage, row, V_PATH_START)
	var count: int = _v(_stage, row, V_PATH_COUNT)
	for ordinal: int in count:
		var point: int = begin + ordinal
		for axis: int in 3:
			var value: int = _stage.points[axis * MAX_POINTS + point]
			if absi(value) > Geometry.MAX_LOCAL_U:
				return &"CONNECTOR_GEOMETRY_OVERFLOW"
			if ordinal == 0 and value != _v(_stage, row, V_START + axis):
				return &"CONNECTOR_GEOMETRY_ENDPOINT"
			if ordinal == count - 1 and value != _v(_stage, row, V_END + axis):
				return &"CONNECTOR_GEOMETRY_ENDPOINT"
		var yaw: int = _stage.points[3 * MAX_POINTS + point]
		if yaw < 0 or yaw >= 65536:
			return &"CONNECTOR_CATALOG_ORIENTATION"
		if (ordinal == 0 and yaw != _v(_stage, row, V_START_YAW)) \
				or (ordinal == count - 1 and yaw != _v(_stage, row, V_END_YAW)):
			return &"CONNECTOR_CATALOG_ORIENTATION"
		if ordinal > 0 and _same_point(_stage.points, MAX_POINTS, point, point - 1):
			return &"CONNECTOR_GEOMETRY_ENDPOINT"
	return &""


static func _same_point(points: PackedInt32Array, capacity: int, first: int, second: int) -> bool:
	"""Full three-dimensional equality never aliases a vertical segment with a flat endpoint."""
	return points[first] == points[second] and points[capacity + first] == points[capacity + second] \
		and points[capacity * 2 + first] == points[capacity * 2 + second]


func _regions_refusal(row: int) -> StringName:
	"""Every variant explicitly includes its full clearance, landings, support and upper/lower openings."""
	var begin: int = _v(_stage, row, V_REGION_START)
	var count: int = _v(_stage, row, V_REGION_COUNT)
	var mask: int = 0
	var landings: int = 0
	var openings: int = 0
	for ordinal: int in count:
		var at: int = begin + ordinal
		var role: int = _stage.regions[6 * MAX_REGIONS + at]
		if role < Space.ENVELOPE or role > Space.SOLID \
				or absi(_stage.regions[7 * MAX_REGIONS + at]) > Levels.MAX_LEVELS:
			return &"CONNECTOR_CATALOG_REGION"
		mask |= 1 << (role - Space.ENVELOPE)
		openings += int(role == Space.OPENING)
		for axis: int in 3:
			var low: int = _stage.regions[axis * MAX_REGIONS + at]
			var high: int = _stage.regions[(axis + 3) * MAX_REGIONS + at]
			if low >= high or absi(low) > Geometry.MAX_LOCAL_U or absi(high) > Geometry.MAX_LOCAL_U:
				return &"CONNECTOR_CATALOG_REGION"
		if role == Space.LANDING:
			landings |= _landing_mask(row, at)
	return &"" if (mask & 15) == 15 and landings == 3 and openings == _v(_stage, row, V_OPENING_COUNT) \
		else &"CONNECTOR_FOOTPRINT_MISSING"


func _landing_mask(row: int, region: int) -> int:
	"""Both exact endpoint/root contacts must occupy authored landing boxes on their relative levels."""
	var result: int = 0
	for side: int in 2:
		var field: int = V_START if side == 0 else V_END
		var level_field: int = V_START_LEVEL if side == 0 else V_END_LEVEL
		if _stage.regions[7 * MAX_REGIONS + region] != _v(_stage, row, level_field):
			continue
		var inside: bool = true
		for axis: int in 3:
			var value: int = _v(_stage, row, field + axis)
			inside = inside and _stage.regions[axis * MAX_REGIONS + region] <= value \
				and value < _stage.regions[(axis + 3) * MAX_REGIONS + region]
		if inside:
			result |= 1 << side
	return result


func _parts_refusal(row: int) -> StringName:
	"""Bound primitive row/vertex/material metadata before any later explicitly cold render compilation."""
	var next: int = _v(_stage, row, V_VERTEX_START)
	var end: int = next + _v(_stage, row, V_VERTEX_COUNT)
	for ordinal: int in _v(_stage, row, V_PART_COUNT):
		var at: int = _v(_stage, row, V_PART_START) + ordinal
		var kind: int = _stage.parts[at]
		var depth: int = _stage.parts[MAX_PARTS + at]
		var first: int = _stage.parts[7 * MAX_PARTS + at]
		var count: int = _stage.parts[8 * MAX_PARTS + at]
		if kind < 0 or kind >= Geometry.PART_KIND_COUNT or depth < 1 or depth > Geometry.MAX_LOCAL_U \
				or absi(_stage.parts[2 * MAX_PARTS + at]) > Levels.MAX_LEVELS \
				or first != next or count < 3 or count > Geometry.MAX_PART_POINTS or first + count > end:
			return &"CONNECTOR_PART_FORMAT"
		var hinge: int = _stage.parts[3 * MAX_PARTS + at]
		if (kind == Geometry.HATCH and (hinge < 0 or hinge >= count)) or (kind != Geometry.HATCH and hinge != -1):
			return &"CONNECTOR_HINGE_FORMAT"
		for field: int in range(4, 7):
			if _stage.parts[field * MAX_PARTS + at] < 0 or _stage.parts[field * MAX_PARTS + at] >= _stage.header[6]:
				return &"CONNECTOR_MATERIAL_MISSING"
		for vertex: int in range(first, first + count):
			for axis: int in 3:
				var value: int = _stage.vertices[axis * MAX_VERTICES + vertex]
				if absi(value) > Geometry.MAX_LOCAL_U or (axis == 1 and absi(value - depth) > Geometry.MAX_LOCAL_U):
					return &"CONNECTOR_GEOMETRY_OVERFLOW"
		next += count
	return &"" if next == end else &"CONNECTOR_CATALOG_CENSUS"


func _validate_paces() -> StringName:
	"""Sorted exact rows have no duplicate permission; actual Movement and immutable geometry sources must match."""
	for row: int in _stage.header[7]:
		if row > 0 and _compare_pace(_stage, row - 1, row) >= 0:
			return &"CONNECTOR_PACE_ORDER"
		var code: StringName = _pace_row_refusal(_stage, row)
		if code != &"":
			return code
	return &""


static func _compare_pace(bank: Bank, first: int, second: int) -> int:
	"""Stable lexicographic profile/family/variant order supports exact bounded binary lookup."""
	for field: int in 3:
		var a: int = _p(bank, first, field)
		var b: int = _p(bank, second, field)
		if a != b:
			return -1 if a < b else 1
	return 0


func _pace_row_refusal(bank: Bank, row: int) -> StringName:
	"""A certified physical descriptor supplies identity; authored timing cannot add a missing movement species."""
	var code: StringName = _profiles.descriptor_into(_p(bank, row, P_PROFILE), bank.header[8], _descriptor)
	if code != &"" or _descriptor.profile_revision != bank.pace_revisions[row] \
			or _descriptor.source_id != bank.header[10] or (_descriptor.mode != Profiles.MODE_WALK \
			and _descriptor.mode != Profiles.MODE_CARRY and _descriptor.mode != Profiles.MODE_CLIMB):
		return &"CONNECTOR_PACE_PROFILE"
	var family: int = _p(bank, row, P_FAMILY)
	var variant: int = _p(bank, row, P_VARIANT)
	if family == -1:
		if variant != 0 or _p(bank, row, P_KIND) != RATE_GROUND_CAP or _p(bank, row, P_RATE) != 0 \
				or _descriptor.mode == Profiles.MODE_CLIMB:
			return &"CONNECTOR_PACE_GROUND"
	else:
		var geometry: int = _variant_row(bank, family, variant)
		if geometry < 0 or _p(bank, row, P_KIND) != RATE_AUTHORED or _p(bank, row, P_RATE) < 1 \
				or (_descriptor.family_mask & (1 << family)) == 0 \
				or _descriptor.mode != _v(bank, geometry, V_MODE) or _descriptor.posture != _v(bank, geometry, V_POSTURE):
			return &"CONNECTOR_PACE_UNAUTHORED"
	return _movement_pace_refusal(bank, row)


func _movement_pace_refusal(bank: Bank, row: int) -> StringName:
	"""Read all timing from this actual current profile; neighboring sizes and stale revisions never qualify."""
	var profile: int = _p(bank, row, P_MOVEMENT)
	if _movement.profile_revision_of(profile) != _p(bank, row, P_MOVEMENT_REVISION) \
			or _p(bank, row, P_MOVEMENT_REVISION) < 1:
		return &"CONNECTOR_PACE_MOVEMENT_STALE"
	if not _movement.profile_species_id_into(profile, _number) or _number.value != _descriptor.species \
			or not _movement.profile_life_stage_into(profile, _number) or _number.value != _descriptor.life_stage:
		return &"CONNECTOR_PACE_SPECIES_STAGE"
	if not _movement.profile_speed_into(profile, _number) or _number.value < 1:
		return &"CONNECTOR_PACE_UNAUTHORED"
	if _p(bank, row, P_KIND) == RATE_AUTHORED and _p(bank, row, P_RATE) > _number.value:
		return &"CONNECTOR_PACE_EXCEEDS_CAP"
	return &""


static func _variant_row(bank: Bank, family: int, variant: int) -> int:
	"""At most16 authored variants; absent fixed geometry never becomes a scaled neighboring entry."""
	if family < 0 or family >= Connectors.FAMILY_COUNT or variant < 0:
		return -1
	var row: int = 0
	while row < bank.header[1]:
		if _v(bank, row, V_FAMILY) == family and _v(bank, row, V_VARIANT) == variant:
			return row
		row += 1
	return -1


func variant_into(family: int, variant: int, revision: int, out: Record) -> StringName:
	"""Copy complete fixed geometry metadata only; no world placement, profile or support permission."""
	var code: StringName = _live_refusal(revision)
	if code != &"":
		return code
	var row: int = _variant_row(_live, family, variant)
	if row < 0 or out == null:
		return &"CONNECTOR_CATALOG_VARIANT"
	_write_record(row, out)
	return &""


func _write_record(row: int, out: Record) -> void:
	"""No mutable source array escapes through this scalar-only descriptor."""
	out.catalog_id = row
	out.revision = _live.variant_revisions[row]
	out.content_revision = content_revision()
	out.family = _v(_live, row, V_FAMILY)
	out.variant = _v(_live, row, V_VARIANT)
	out.allowed_rotations = _v(_live, row, V_ROTATIONS)
	out.start = Vector3i(_v(_live, row, V_START), _v(_live, row, V_START + 1), _v(_live, row, V_START + 2))
	out.end = Vector3i(_v(_live, row, V_END), _v(_live, row, V_END + 1), _v(_live, row, V_END + 2))
	out.start_level_offset = _v(_live, row, V_START_LEVEL)
	out.end_level_offset = _v(_live, row, V_END_LEVEL)
	out.start_yaw = _v(_live, row, V_START_YAW)
	out.end_yaw = _v(_live, row, V_END_YAW)
	out.mode = _v(_live, row, V_MODE)
	out.posture = _v(_live, row, V_POSTURE)
	out.point_count = _v(_live, row, V_PATH_COUNT)
	out.region_count = _v(_live, row, V_REGION_COUNT)
	out.part_count = _v(_live, row, V_PART_COUNT)
	out.vertex_count = _v(_live, row, V_VERTEX_COUNT)
	out.opening_count = _v(_live, row, V_OPENING_COUNT)
	out.spiral_centre_xz = Vector2i(_v(_live, row, V_SPIRAL_X), _v(_live, row, V_SPIRAL_Z))


func _live_refusal(revision: int) -> StringName:
	"""Both immutable source images and the bound actual World must still match before any successful read."""
	if revision < 1 or revision != content_revision():
		return &"CONNECTOR_CATALOG_STALE"
	return _content_binding_refusal(_live)


func _row_refusal(row: int, variant_revision: int, revision: int) -> StringName:
	"""An old dense row cannot read a same-number replacement variant after catalog refresh."""
	var code: StringName = _live_refusal(revision)
	if code != &"":
		return code
	return &"" if row >= 0 and row < _live.header[1] and _live.variant_revisions[row] == variant_revision \
		else &"CONNECTOR_CATALOG_VARIANT_STALE"


func path_point_into(row: int, variant_revision: int, revision: int, ordinal: int,
		out: PackedInt32Array) -> StringName:
	"""Write exact [x,y,z,yaw] relative content into four caller integers, with no implicit rotation."""
	var code: StringName = _row_refusal(row, variant_revision, revision)
	if code != &"":
		return code
	if out.size() != 4 or ordinal < 0 or ordinal >= _v(_live, row, V_PATH_COUNT):
		return &"CONNECTOR_CATALOG_OUTPUT"
	var at: int = _v(_live, row, V_PATH_START) + ordinal
	for field: int in 4:
		out[field] = _live.points[field * MAX_POINTS + at]
	return &""


func region_into(row: int, variant_revision: int, revision: int, ordinal: int,
		out: PackedInt32Array) -> StringName:
	"""Write [loXYZ,hiXYZ,Space role,relative level]; physical proof must use every required authored box."""
	var code: StringName = _row_refusal(row, variant_revision, revision)
	if code != &"":
		return code
	if out.size() != 8 or ordinal < 0 or ordinal >= _v(_live, row, V_REGION_COUNT):
		return &"CONNECTOR_CATALOG_OUTPUT"
	var at: int = _v(_live, row, V_REGION_START) + ordinal
	for field: int in 8:
		out[field] = _live.regions[field * MAX_REGIONS + at]
	return &""


func part_into(row: int, variant_revision: int, revision: int, ordinal: int,
		out: PackedInt32Array) -> StringName:
	"""Nine integers: kind,depth,level,hinge,top/bottom/side materials,variant-relative vertex start,count."""
	var code: StringName = _row_refusal(row, variant_revision, revision)
	if code != &"":
		return code
	if out.size() != 9 or ordinal < 0 or ordinal >= _v(_live, row, V_PART_COUNT):
		return &"CONNECTOR_CATALOG_OUTPUT"
	var at: int = _v(_live, row, V_PART_START) + ordinal
	for field: int in 9:
		out[field] = _live.parts[field * MAX_PARTS + at]
	out[7] -= _v(_live, row, V_VERTEX_START)
	return &""


func vertex_into(row: int, variant_revision: int, revision: int, ordinal: int,
		out: PackedInt32Array) -> StringName:
	"""Read exact local primitive XYZ; fixed authored geometry cannot stretch to a requested stairwell."""
	var code: StringName = _row_refusal(row, variant_revision, revision)
	if code != &"":
		return code
	if out.size() != 3 or ordinal < 0 or ordinal >= _v(_live, row, V_VERTEX_COUNT):
		return &"CONNECTOR_CATALOG_OUTPUT"
	var at: int = _v(_live, row, V_VERTEX_START) + ordinal
	for field: int in 3:
		out[field] = _live.vertices[field * MAX_VERTICES + at]
	return &""


func material_period_into(material: int, revision: int, out: IntMath.IntResult) -> StringName:
	"""World-unit UV periods fill clipped surfaces without stretching a texture to each new footprint."""
	var code: StringName = _live_refusal(revision)
	if code != &"":
		return code
	if material < 0 or material >= _live.header[6] or out == null:
		return &"CONNECTOR_MATERIAL_MISSING"
	out.succeed(_live.materials[material])
	return &""


func pace_into(profile_id: int, profile_revision: int, profile_content_revision: int, family: int,
		variant: int, catalog_revision: int, out: IntMath.IntResult) -> StringName:
	"""Geometry/timing lookup only; the caller separately proves real actor Gear/Haul/route eligibility."""
	var code: StringName = _live_refusal(catalog_revision)
	if code != &"":
		return code
	if out == null or profile_content_revision != _live.header[8] or profile_id < 0 \
			or family < -1 or family >= Connectors.FAMILY_COUNT or variant < 0 or (family == -1 and variant != 0):
		return &"CONNECTOR_PACE_UNAUTHORED"
	var row: int = _pace_row(profile_id, family, variant)
	if row < 0 or profile_revision != _live.pace_revisions[row]:
		return &"CONNECTOR_PACE_UNAUTHORED"
	code = _pace_row_refusal(_live, row)
	if code != &"":
		return code
	out.succeed(_number.value if family == -1 else _p(_live, row, P_RATE))
	return &""


func _pace_row(profile_id: int, family: int, variant: int) -> int:
	"""At most nine exact comparisons over 256 rows; the hot reader allocates no temporary Array."""
	var low: int = 0
	var high: int = _live.header[7]
	while low < high:
		@warning_ignore("integer_division") var middle: int = (low + high) / 2
		var a: int = _p(_live, middle, P_PROFILE)
		var b: int = _p(_live, middle, P_FAMILY)
		var c: int = _p(_live, middle, P_VARIANT)
		if a == profile_id and b == family and c == variant:
			return middle
		if a < profile_id or (a == profile_id and (b < family or (b == family and c < variant))):
			low = middle + 1
		else:
			high = middle
	return -1
