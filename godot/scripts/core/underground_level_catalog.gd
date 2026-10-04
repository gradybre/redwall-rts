extends RefCounted
## Immutable engineering heights; no terrain, void, support, paid cut or route is created here.
## Exact source content and full live World/Domain identity precede every section lookup.

const Space := preload("res://scripts/core/room_space.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const VERSION: int = 1
const CONFIG_FIELDS: int = 13
const IDENTITY_FIELDS: int = 21
const MAX_OFFSETS: int = 9
const MAX_SHORT_RISES: int = 8
const MAX_LEVELS: int = 256 # Finite content loop bound, unrelated to population policy.
const MAX_FILE_BYTES: int = 156
const MAX_RETAINED_BYTES: int = 244 # Five packed columns plus one int64 revision.
const CONTROL_RESERVE: int = 2048 # Includes cold wire/decode/native peak; not measured.
const RESERVED_BYTES: int = MAX_RETAINED_BYTES + CONTROL_RESERVE


class Record extends RefCounted:
	## Local Y obligations only; the caller must intersect its actual room/section XZ footprint.
	var world_ref: Vector2i = Vector2i(-1, 0)
	var content_revision: int = 0
	var level_id: int = -1
	var section_offset_u: int = 0
	var floor_y_u: int = 0
	var clear_roof_y_u: int = 0
	var clear_height_u: int = 0
	var has_roof: bool = false
	var protected_above_low_u: int = 0
	var protected_above_high_u: int = 0
	var required_footing_low_u: int = 0
	var required_footing_high_u: int = 0


var _config: PackedInt32Array = PackedInt32Array()
var _offsets: PackedInt32Array = PackedInt32Array()
var _short_rises: PackedInt32Array = PackedInt32Array()
var _identity: PackedInt32Array = PackedInt32Array()
var _digest: PackedByteArray = PackedByteArray()
var _revision: int = 0
var _directory: Directory = null


func load_file(path: String, expected_sha256: String, revision: int) -> StringName:
	"""One admitted tiny binary image; JSON numbers never participate in authoritative height arithmetic."""
	if _revision != 0:
		return &"LEVEL_CATALOG_ALREADY_LOADED"
	if expected_sha256.length() != 64 or revision < 1:
		return &"LEVEL_CATALOG_SOURCE"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return &"LEVEL_CATALOG_SOURCE"
	var length: int = file.get_length()
	if length < 96 or length > MAX_FILE_BYTES:
		file.close()
		return &"LEVEL_CATALOG_CAPACITY"
	var bytes: PackedByteArray = file.get_buffer(length)
	file.close()
	var digest_context: HashingContext = HashingContext.new()
	digest_context.start(HashingContext.HASH_SHA256)
	digest_context.update(bytes)
	var digest: PackedByteArray = digest_context.finish()
	if bytes.size() != length or digest.hex_encode() != expected_sha256:
		return &"LEVEL_CATALOG_SOURCE"
	return _decode(bytes, digest, revision)


func _decode(bytes: PackedByteArray, digest: PackedByteArray, revision: int) -> StringName:
	"""Publish only after the entire exact-length candidate validates; refused loads remain empty."""
	if bytes.slice(0, 8).get_string_from_ascii() != "UGLEVEL1" or bytes.decode_u32(8) != VERSION \
			or bytes.decode_s64(12) != revision:
		return &"LEVEL_CATALOG_SCHEMA"
	var config: PackedInt32Array = _integers(bytes, 20, CONFIG_FIELDS)
	var offsets_count: int = bytes.decode_u32(72)
	if offsets_count < 1 or offsets_count > MAX_OFFSETS or 88 + offsets_count * 4 > bytes.size():
		return &"LEVEL_CATALOG_CAPACITY"
	var offsets: PackedInt32Array = _integers(bytes, 76, offsets_count)
	var rises_count: int = bytes.decode_u32(76 + offsets_count * 4)
	if rises_count < 1 or rises_count > MAX_SHORT_RISES or bytes.size() != 88 + 4 * (offsets_count + rises_count):
		return &"LEVEL_CATALOG_CAPACITY"
	var rises: PackedInt32Array = _integers(bytes, 80 + offsets_count * 4, rises_count)
	if bytes.slice(bytes.size() - 8).get_string_from_ascii() != "UGLEND01":
		return &"LEVEL_CATALOG_SCHEMA"
	var code: StringName = _content_refusal(config, offsets, rises)
	if code != &"":
		return code
	_publish_content(config, offsets, rises, digest, revision)
	return &""


func _publish_content(config: PackedInt32Array, offsets: PackedInt32Array, rises: PackedInt32Array,
		digest: PackedByteArray, revision: int) -> void:
	"""Copy the fully validated finite candidate into independently owned immutable columns."""
	_config.resize(CONFIG_FIELDS)
	_offsets.resize(offsets.size())
	_short_rises.resize(rises.size())
	_digest.resize(32)
	for index: int in CONFIG_FIELDS:
		_config[index] = config[index]
	for index: int in offsets.size():
		_offsets[index] = offsets[index]
	for index: int in rises.size():
		_short_rises[index] = rises[index]
	for index: int in 32:
		_digest[index] = digest[index]
	_revision = revision


static func _integers(bytes: PackedByteArray, start: int, count: int) -> PackedInt32Array:
	"""The caller has already bounded each wire range before decoding signed exact integers."""
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(count)
	for index: int in count:
		out[index] = bytes.decode_s32(start + index * 4)
	return out


static func _content_refusal(config: PackedInt32Array, offsets: PackedInt32Array,
		rises: PackedInt32Array) -> StringName:
	"""Whole-cube engineering values and finite extents never round a paid datum or stretch a stair."""
	for axis: int in 3:
		var low: int = int(config[axis]) + int(config[axis + 3]) * Space.QUANTUM_U
		var high: int = low + int(config[axis + 6]) * Space.QUANTUM_U
		if config[axis + 6] < 1 or not Space.int32(low) or not Space.int32(high):
			return &"LEVEL_CATALOG_DOMAIN"
	if config[4] >= 0 or int(config[4]) + int(config[7]) <= 0:
		return &"LEVEL_CATALOG_DOMAIN"
	for field: int in range(9, CONFIG_FIELDS):
		if config[field] < Space.QUANTUM_U or config[field] % Space.QUANTUM_U != 0:
			return &"LEVEL_CATALOG_QUANTUM"
	if int(config[9]) != int(config[10]) + int(config[11]):
		return &"LEVEL_CATALOG_PROTECTED_BAND"
	var count: int = _count_levels(config)
	if count < 1 or count > MAX_LEVELS or not offsets.has(0):
		return &"LEVEL_CATALOG_LEVEL_COUNT"
	if not _ordered_offsets(offsets, config[10]) or not _ordered_offsets(rises, config[9], true):
		return &"LEVEL_CATALOG_OFFSETS"
	return &""


static func _ordered_offsets(values: PackedInt32Array, limit: int, positive: bool = false) -> bool:
	"""Sorted exact heights are engineering choices; they imply no climbing or load permission."""
	var previous: int = -2147483649
	for value: int in values:
		if value <= previous or value % Space.QUANTUM_U != 0 or absi(value) >= limit \
				or (positive and value <= 0):
			return false
		previous = value
	return true


static func _count_levels(config: PackedInt32Array) -> int:
	"""Derive the deepest base level that retains its complete required footing inside the actual domain."""
	@warning_ignore("integer_division") var count: int = (-int(config[4]) * Space.QUANTUM_U - config[12]) / config[9]
	return count


func bind_domain(domain: Space.Domain, directory: Directory, expected: Dictionary,
		expected_space_version: int) -> StringName:
	"""Pin the complete actual World/domain/capacity tuple; binding creates no physical region."""
	if not _identity.is_empty():
		return &"LEVEL_CATALOG_ALREADY_BOUND"
	if _revision == 0 or domain == null or directory == null or expected_space_version != Space.VERSION:
		return &"LEVEL_CATALOG_DOMAIN"
	var actual: Dictionary = domain.descriptor()
	if actual != expected or not _descriptor_valid(actual):
		return &"LEVEL_CATALOG_DOMAIN"
	var world: Vector2i = actual.world_ref
	if not directory.is_valid_of_kind(world, Directory.KIND_WORLD):
		return &"LEVEL_CATALOG_WORLD_STALE"
	if actual.datum_u != Vector3i(_config[0], _config[1], _config[2]) \
			or actual.min_quantum != Vector3i(_config[3], _config[4], _config[5]) \
			or actual.size_quanta != Vector3i(_config[6], _config[7], _config[8]):
		return &"LEVEL_CATALOG_DOMAIN"
	var identity: PackedInt32Array = _identity_of(actual, expected_space_version)
	_identity.resize(IDENTITY_FIELDS)
	for index: int in IDENTITY_FIELDS:
		_identity[index] = identity[index]
	_directory = directory
	return &""


static func _descriptor_valid(value: Dictionary) -> bool:
	"""Reject incomplete or differently typed metadata before any typed copy or narrowing."""
	if value.size() != 8 or not value.get("world_ref") is Vector2i \
			or not value.get("datum_u") is Vector3i or not value.get("min_quantum") is Vector3i \
			or not value.get("size_quanta") is Vector3i or not value.get("bounds_u") is PackedInt32Array:
		return false
	if value.bounds_u.size() != 6 or not Space.valid_box(value.bounds_u):
		return false
	for key: String in ["max_cells", "max_regions", "max_checks"]:
		if not value.get(key) is int or value[key] < 1 or not Space.int32(value[key]):
			return false
	return true


static func _identity_of(value: Dictionary, version: int) -> PackedInt32Array:
	"""One small cold identity copy includes every domain descriptor field and its format version."""
	var world: Vector2i = value.world_ref
	var datum: Vector3i = value.datum_u
	var minimum: Vector3i = value.min_quantum
	var size: Vector3i = value.size_quanta
	var out: PackedInt32Array = PackedInt32Array([world.x, world.y, datum.x, datum.y, datum.z,
		minimum.x, minimum.y, minimum.z, size.x, size.y, size.z])
	out.append_array(value.bounds_u)
	out.append_array(PackedInt32Array([value.max_cells, value.max_regions, value.max_checks, version]))
	return out


func binding_matches(domain: Space.Domain, directory: Directory, version: int) -> bool:
	"""Cold cross-owner check permits an exact domain copy, never another Directory or capacity tuple."""
	if not _world_live() or domain == null or directory != _directory or version != Space.VERSION:
		return false
	var actual: Dictionary = domain.descriptor()
	return _descriptor_valid(actual) and _identity_of(actual, version) == _identity


func _world_live() -> bool:
	"""A retired World cannot keep serving valid-looking heights after its slot is reused."""
	return _identity.size() == IDENTITY_FIELDS and _directory != null \
		and _directory.is_valid_of_kind(Vector2i(_identity[0], _identity[1]), Directory.KIND_WORLD)


func content_revision() -> int:
	"""Zero denotes absent source content, including every rejected load."""
	return _revision


func content_hash_into(out: PackedByteArray) -> bool:
	"""World/save composition pins this digest; the catalog never hands out mutable source storage."""
	if _revision == 0 or out.size() != 32:
		return false
	for index: int in 32:
		out[index] = _digest[index]
	return true


func level_count() -> int:
	"""Number of underground base levels; surface ID0 is additional and creates no floor/void."""
	return _count_levels(_config) if _world_live() else 0


func section_offset_count() -> int:
	"""Only the authored finite menu is exposed; actual geometry may refuse a listed choice."""
	return _offsets.size() if _world_live() else 0


func section_offset_at(index: int) -> int:
	"""INT32_MIN is a refusal sentinel, outside every admitted engineering offset."""
	return _offsets[index] if _world_live() and index >= 0 and index < _offsets.size() else -2147483648


func has_short_rise(from_u: int, to_u: int) -> bool:
	"""A matching fixed height exists in authored content; this does not qualify any physical connector."""
	if not _world_live() or not _offsets.has(from_u) or not _offsets.has(to_u) or from_u == to_u:
		return false
	return _short_rises.has(absi(to_u - from_u))


func level_into(level_id: int, section_offset_u: int, out: Record) -> StringName:
	"""Translate exact local obligations only; the real room footprint and supporting facts remain external."""
	if out == null or not _world_live():
		return &"LEVEL_CATALOG_WORLD_STALE"
	if level_id < 0 or level_id > level_count() or not _offsets.has(section_offset_u) \
			or (level_id == 0 and section_offset_u != 0):
		return &"LEVEL_CATALOG_SECTION"
	var base: int = int(_config[1]) - int(level_id) * int(_config[9])
	var floor_y: int = base + section_offset_u
	var roof_y: int = base + _config[10] if level_id > 0 else _identity[15]
	var protected_high: int = base + _config[9] if level_id > 0 else roof_y
	var footing_low: int = floor_y - _config[12]
	if footing_low < _identity[12] or protected_high > _identity[15] or floor_y >= roof_y \
			or not Space.int32(footing_low) or not Space.int32(protected_high) \
			or not Space.int32(roof_y - floor_y):
		return &"LEVEL_CATALOG_SECTION_OUTSIDE_DOMAIN"
	_write_record(out, level_id, section_offset_u, floor_y, roof_y, protected_high, footing_low)
	return &""


func _write_record(out: Record, level_id: int, section_offset_u: int, floor_y: int,
		roof_y: int, protected_high: int, footing_low: int) -> void:
	"""Copy only an already-admitted complete record; every refusal precedes these writes."""
	out.world_ref = Vector2i(_identity[0], _identity[1])
	out.content_revision = _revision
	out.level_id = level_id
	out.section_offset_u = section_offset_u
	out.floor_y_u = floor_y
	out.clear_roof_y_u = roof_y
	out.clear_height_u = roof_y - floor_y
	out.has_roof = level_id > 0
	out.protected_above_low_u = roof_y
	out.protected_above_high_u = protected_high
	out.required_footing_low_u = footing_low
	out.required_footing_high_u = floor_y
