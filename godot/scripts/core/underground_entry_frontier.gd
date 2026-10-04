extends RefCounted
## Immutable authored work dependencies, never Site progress, installed parts or contact permission.
## One streamed bank; exact current sources and complete fixed outputs. Decision1109.

const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Assemblies := preload("res://scripts/core/underground_connector_assemblies.gd")
const Recipes := preload("res://scripts/core/underground_connector_recipes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const SourceFacts := preload("res://scripts/core/underground_connector_source_facts.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const TABLE_COUNT: int = 6
const INSTALL: int = 0
const STATION: int = 1
const CUT: int = 2
const BEARING: int = 3
const ENDPOINT: int = 4
const EPISODE: int = 5
const NATURAL: int = 0
const INSTALLED_PART: int = 1
const SURFACE_ANCHOR: int = 0
const INSTALLED_CONTACT: int = 1
const SURFACE_CONTACT: int = 2
const MAX_ROWS: int = 2048
const MAX_BYTES: int = 28597 # 36789 remaining, less separate4096 Contacts and4096 EntryBindings.
const FIXED_BYTES: int = 2048 # Exact header, capacities, streamed row and logical helper allowance.
const WIRE_HEADER_BYTES: int = 220
const HEADER_FIELDS: int = 14
# Self, Catalog, Grouping, Recipe, actual profile-program source.
const DIGEST_BYTES: int = 160
const REFUSE_CAPACITY: StringName = &"ENTRY_FRONTIER_CAPACITY"
const REFUSE_BINDING: StringName = &"ENTRY_FRONTIER_BINDING"
const REFUSE_SOURCE: StringName = &"ENTRY_FRONTIER_SOURCE"
const REFUSE_FORMAT: StringName = &"ENTRY_FRONTIER_FORMAT"
const REFUSE_REFERENCE: StringName = &"ENTRY_FRONTIER_REFERENCE"
const REFUSE_FUTURE: StringName = &"ENTRY_FRONTIER_FUTURE_SUPPORT"
const REFUSE_PROFILE: StringName = &"ENTRY_FRONTIER_PROFILE"
const REFUSE_DUPLICATE: StringName = &"ENTRY_FRONTIER_DUPLICATE_OPERATION"
const REFUSE_OUTPUT: StringName = &"ENTRY_FRONTIER_OUTPUT"

var _capacities: PackedInt32Array = PackedInt32Array()
var _header: PackedInt64Array = PackedInt64Array() # six revisions; Catalog row/source id; six counts.
var _digests: PackedByteArray = PackedByteArray()
var _install: PackedInt32Array = PackedInt32Array()
var _station: PackedInt32Array = PackedInt32Array()
var _profile_revision: PackedInt64Array = PackedInt64Array()
var _rotation_profile: PackedInt32Array = PackedInt32Array()
var _cut: PackedInt32Array = PackedInt32Array()
var _bearing: PackedInt32Array = PackedInt32Array()
var _endpoint: PackedInt32Array = PackedInt32Array()
var _travel_profile: PackedInt32Array = PackedInt32Array()
var _travel_revision: PackedInt64Array = PackedInt64Array()
var _episode: PackedInt32Array = PackedInt32Array()
var _catalog: Catalog = null
var _assemblies: Assemblies = null
var _recipes: Recipes = null
var _profiles: Profiles = null
var _configured: bool = false
var _loaded: bool = false
var _busy: bool = false


static func row_fields(table: int) -> int:
	"""The wire and field-major bank use one fixed explicit numeric schema per table."""
	match table:
		INSTALL, STATION, BEARING:
			return 9
		CUT, ENDPOINT:
			return 7
		EPISODE:
			return 19
	return 0


static func required_bytes(capacities: PackedInt32Array) -> int:
	"""Reject the complete simultaneous envelope before allocating any bank or copied capacities."""
	if capacities.size() != TABLE_COUNT:
		return 0
	var total: int = FIXED_BYTES
	for table: int in TABLE_COUNT:
		if capacities[table] < 1 or capacities[table] > (Catalog.MAX_PARTS if table == INSTALL else MAX_ROWS):
			return 0
		total += capacities[table] * wire_row_bytes(table)
	return total if total <= MAX_BYTES else 0


static func wire_row_bytes(table: int) -> int:
	"""Endpoints explicitly add transit profile/revision; no WALK profile is inferred from a WORK station."""
	return row_fields(table) * 4 + (44 if table == STATION else (12 if table == ENDPOINT else 0))


func configure(capacities: PackedInt32Array, arena_bytes: int) -> StringName:
	"""This reader consumes only the explicitly admitted subreserve; tables never grow at runtime."""
	if _configured or required_bytes(capacities) == 0 or arena_bytes != required_bytes(capacities):
		return REFUSE_CAPACITY
	_capacities.resize(TABLE_COUNT)
	for table: int in TABLE_COUNT:
		_capacities[table] = capacities[table]
	_header.resize(HEADER_FIELDS)
	_digests.resize(DIGEST_BYTES)
	_install.resize(9 * _capacities[INSTALL])
	_station.resize(9 * _capacities[STATION])
	_profile_revision.resize(4 * _capacities[STATION])
	_rotation_profile.resize(3 * _capacities[STATION])
	_cut.resize(7 * _capacities[CUT])
	_bearing.resize(9 * _capacities[BEARING])
	_endpoint.resize(7 * _capacities[ENDPOINT])
	_travel_profile.resize(_capacities[ENDPOINT])
	_travel_revision.resize(_capacities[ENDPOINT])
	_episode.resize(19 * _capacities[EPISODE])
	_configured = true
	_clear_bank()
	return &""


func bind_actual(catalog: Catalog, assemblies: Assemblies, recipes: Recipes, profiles: Profiles) -> StringName:
	"""Bind exact current source owners once; matching row numbers from another World are insufficient."""
	if not _configured or _busy or _catalog != null or catalog == null or assemblies == null \
			or recipes == null or profiles == null or catalog._profiles != profiles \
			or assemblies._catalog != catalog or assemblies._recipes != recipes or recipes._catalog != catalog \
			or not assemblies._loaded or not recipes._loaded:
		return REFUSE_BINDING
	_catalog = catalog
	_assemblies = assemblies
	_recipes = recipes
	_profiles = profiles
	return &""


func load_file(path: String, expected_sha256: String, revision: int) -> StringName:
	"""Hash the bytes actually decoded; no second whole-file image, source replacement or partial live load."""
	if _busy or _loaded or _catalog == null or revision < 1 or expected_sha256.length() != 64 \
			or not expected_sha256.is_valid_hex_number(false):
		return REFUSE_SOURCE
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return REFUSE_SOURCE
	_busy = true
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var code: StringName = _decode(file, digest, revision)
	var actual: PackedByteArray = digest.finish()
	file.close()
	if code == &"" and actual.hex_encode() != expected_sha256.to_lower():
		code = REFUSE_SOURCE
	if code == &"":
		code = _semantic_refusal()
	if code == &"":
		for index: int in 32:
			_digests[index] = actual[index]
		_loaded = true
	else:
		_clear_bank()
	_busy = false
	return code


static func _read(file: FileAccess, digest: HashingContext, size: int) -> PackedByteArray:
	"""Each bounded read is hashed once; empty corrupt input produces an ordinary refusal, not diagnostics."""
	var bytes: PackedByteArray = file.get_buffer(size)
	if not bytes.is_empty():
		digest.update(bytes)
	return bytes


func _decode(file: FileAccess, digest: HashingContext, revision: int) -> StringName:
	"""Validate the complete finite wire length before any row; table decoding writes only unpublished columns."""
	var code: StringName = _decode_header(_read(file, digest, WIRE_HEADER_BYTES), revision, file.get_length())
	if code != &"":
		return code
	for table: int in TABLE_COUNT:
		code = _decode_table(file, digest, table)
		if code != &"":
			return code
	return &"" if _read(file, digest, 8).get_string_from_ascii() == "UGFEND01" else REFUSE_FORMAT


func _decode_header(bytes: PackedByteArray, revision: int, file_bytes: int) -> StringName:
	"""Positive exact revisions and row counts bind Catalog/group/recipe/profile sources without callbacks."""
	if bytes.size() != WIRE_HEADER_BYTES or bytes.slice(0, 8).get_string_from_ascii() != "UGFRNT01" \
			or bytes.decode_u32(8) != 1 or bytes.decode_s64(12) != revision:
		return REFUSE_FORMAT
	for field: int in 6:
		_header[field] = bytes.decode_s64(12 + field * 8)
		if _header[field] < 1:
			return REFUSE_SOURCE
	_header[6] = bytes.decode_s32(60)
	_header[7] = bytes.decode_s32(64)
	var expected: int = WIRE_HEADER_BYTES + 8
	for table: int in TABLE_COUNT:
		var count: int = bytes.decode_u32(68 + table * 4)
		if count < 1 or count > _capacities[table]:
			return REFUSE_CAPACITY
		_header[8 + table] = count
		expected += count * wire_row_bytes(table)
	for index: int in 128:
		_digests[32 + index] = bytes[92 + index]
	return _sources_refusal(self) if expected == file_bytes else REFUSE_FORMAT


func _decode_table(file: FileAccess, digest: HashingContext, table: int) -> StringName:
	"""A single small row is live while writing explicit field-major columns, including full int64 revisions."""
	var fields: int = row_fields(table)
	var size: int = wire_row_bytes(table)
	for row: int in _header[8 + table]:
		var bytes: PackedByteArray = _read(file, digest, size)
		if bytes.size() != size:
			return REFUSE_FORMAT
		for field: int in fields:
			_store_field(table, field * _capacities[table] + row, bytes.decode_s32(field * 4))
		if table == STATION:
			_profile_revision[row] = bytes.decode_s64(36)
			for rotation: int in range(1, 4):
				_rotation_profile[(rotation - 1) * _capacities[STATION] + row] = bytes.decode_s32(44 + (rotation - 1) * 12)
				_profile_revision[rotation * _capacities[STATION] + row] = bytes.decode_s64(48 + (rotation - 1) * 12)
		elif table == ENDPOINT:
			_travel_profile[row] = bytes.decode_s32(28)
			_travel_revision[row] = bytes.decode_s64(32)
	return &""


func _store_field(table: int, at: int, value: int) -> void:
	"""Write actual packed fields, never a resized copy-on-write loop alias."""
	match table:
		INSTALL: _install[at] = value
		STATION: _station[at] = value
		CUT: _cut[at] = value
		BEARING: _bearing[at] = value
		ENDPOINT: _endpoint[at] = value
		EPISODE: _episode[at] = value


func _field(table: int, row: int, field: int) -> int:
	"""Internal callers bound row/field first; no bank or slice escapes into caller-owned state."""
	var at: int = field * _capacities[table] + row
	match table:
		INSTALL: return _install[at]
		STATION: return _station[at]
		CUT: return _cut[at]
		BEARING: return _bearing[at]
		ENDPOINT: return _endpoint[at]
		EPISODE: return _episode[at]
	return -1


static func _sources_refusal(actual: RefCounted) -> StringName:
	"""Read concrete source banks and original World wiring; no overridable hash/metadata observer runs."""
	if actual._catalog == null or actual._assemblies == null or actual._recipes == null or actual._profiles == null \
			or actual._catalog._profiles != actual._profiles or actual._assemblies._catalog != actual._catalog \
			or actual._assemblies._recipes != actual._recipes or actual._recipes._catalog != actual._catalog \
			or not actual._assemblies._loaded or actual._assemblies._busy or not actual._recipes._loaded or actual._recipes._busy \
			or actual._assemblies._header.size() != 7 or actual._assemblies._digests.size() != 96 \
			or actual._recipes._header.size() != 4 or actual._recipes._digests.size() != 96:
		return REFUSE_SOURCE
	if SourceFacts.refusal(actual._catalog, actual._header[6], actual._header[2], actual._header[1], actual._digests, 32) != &"" \
			or actual._assemblies._header[0] != actual._header[3] or actual._assemblies._header[1] != actual._header[1] \
			or actual._assemblies._header[2] != actual._header[4] or actual._assemblies._header[3] != actual._header[6] \
			or actual._assemblies._header[4] != actual._header[2] or actual._assemblies._header[5] != actual._header[8] \
			or actual._recipes._header[0] != actual._header[4] or actual._recipes._header[1] != actual._header[1] \
			or actual._recipes._header[2] != actual._header[3] or actual._recipes._header[3] != actual._header[8] \
			or actual._recipes._catalog_row != actual._header[6] or actual._recipes._variant_revision != actual._header[2]:
		return REFUSE_SOURCE
	return _source_digest_refusal(actual)


static func _source_digest_refusal(actual: RefCounted) -> StringName:
	"""The same exact Items/Inventory registration and monotonic Profiles revision remain in force."""
	if actual._assemblies._items != actual._recipes._items or actual._assemblies._inventory != actual._recipes._inventory \
			or actual._recipes._items == null or not actual._recipes._items._loaded \
			or actual._recipes._items._registered_inventory == null \
			or actual._recipes._items._registered_inventory.get_ref() != actual._recipes._inventory \
			or actual._profiles._loading or actual._profiles._live.header[0] != actual._header[5] \
			or actual._header[7] < 0 or actual._header[7] >= actual._profiles._live.header[3] \
			or actual._header[7] != actual._catalog._live.header[10] or actual._header[5] != actual._catalog._live.header[8]:
		return REFUSE_SOURCE
	for index: int in 32:
		if actual._assemblies._digests[index] != actual._digests[64 + index] \
				or actual._recipes._digests[index] != actual._digests[96 + index] \
				or actual._assemblies._digests[32 + index] != actual._digests[32 + index] \
				or actual._recipes._digests[32 + index] != actual._digests[32 + index] \
				or actual._assemblies._digests[64 + index] != actual._digests[96 + index] \
				or actual._recipes._digests[64 + index] != actual._digests[64 + index] \
				or actual._profiles._live.sources[actual._header[7] * 32 + index] != actual._digests[128 + index]:
			return REFUSE_SOURCE
	return &""


func _semantic_refusal() -> StringName:
	"""Validate every row, including unused source entries; no malformed hidden row inherits a good digest."""
	for table: int in TABLE_COUNT:
		for row: int in _header[8 + table]:
			var code: StringName = _row_refusal(table, row)
			if code != &"":
				return code
	return _sources_refusal(self)


func _row_refusal(table: int, row: int) -> StringName:
	"""Dispatch exact per-table semantics without allocating records or dictionaries."""
	match table:
		INSTALL: return _installation_refusal(row)
		STATION: return _station_refusal(row)
		CUT: return _cut_refusal(row)
		BEARING: return _bearing_refusal(row)
		ENDPOINT: return _endpoint_refusal(row)
		EPISODE: return _episode_refusal(row)
	return REFUSE_FORMAT


func _valid_row(table: int, row: int) -> bool:
	"""Indices name live authored rows, not spare allocated capacity."""
	return row >= 0 and row < _header[8 + table]


func _range(table: int, first: int, count: int, empty_allowed: bool = false) -> bool:
	"""Subtraction avoids overflow; empty ranges have exactly start zero when explicitly permitted."""
	if count == 0:
		return empty_allowed and first == 0
	return first >= 0 and count > 0 and first <= _header[8 + table] - count


func _box_refusal(table: int, row: int, first: int, lattice: bool) -> StringName:
	"""Half-open relative volumes are positive; paid cut unions use whole canonical1024-unit cubes."""
	for axis: int in 3:
		var low: int = _field(table, row, first + axis)
		var high: int = _field(table, row, first + axis + 3)
		if low >= high or (lattice and (low % 1024 != 0 or high % 1024 != 0)):
			return REFUSE_FORMAT
	return &""


func _installation_refusal(row: int) -> StringName:
	"""Each Grouping ordinal appears exactly once; all support, approach and retreat precede its installation."""
	if _field(INSTALL, row, 0) != row or not _valid_row(STATION, _field(INSTALL, row, 1)) \
			or not _valid_row(BEARING, _field(INSTALL, row, 2)) \
			or not _range(CUT, _field(INSTALL, row, 3), _field(INSTALL, row, 4)) \
			or not _range(BEARING, _field(INSTALL, row, 5), _field(INSTALL, row, 6)):
		return REFUSE_REFERENCE
	var code: StringName = _prior_station(_field(INSTALL, row, 1), row)
	if code == &"": code = _prior_bearing(_field(INSTALL, row, 2), row)
	if code == &"": code = _prior_endpoint(_field(INSTALL, row, 7), row)
	if code == &"": code = _prior_endpoint(_field(INSTALL, row, 8), row)
	if code != &"": return code
	for target: int in range(_field(INSTALL, row, 5), _field(INSTALL, row, 5) + _field(INSTALL, row, 6)):
		code = _prior_bearing(target, row)
		if code != &"": return code
	return &""


func _station_refusal(row: int) -> StringName:
	"""Source-local root/yaw/face remain explicit; every allowed rotation chooses an authored WORK row."""
	var endpoint: int = _field(STATION, row, 0)
	if not _valid_row(ENDPOINT, endpoint) or _field(STATION, row, 7) < 0 or _field(STATION, row, 7) > 5:
		return REFUSE_REFERENCE
	for axis: int in 3:
		if _field(STATION, row, 1 + axis) != _field(ENDPOINT, endpoint, 4 + axis):
			return REFUSE_REFERENCE
	if _field(ENDPOINT, endpoint, 3) != Locations.ROLE_WORK or _field(STATION, row, 4) < 0 \
			or _field(STATION, row, 4) >= 65536 or _field(STATION, row, 8) != Jobs.JOB_KIND_BUILD:
		return REFUSE_PROFILE
	for rotation: int in 4:
		var code: StringName = _station_profile_refusal(row, rotation)
		if code != &"": return code
	return &""


func _station_profile(row: int, rotation: int) -> int:
	"""Quarter-turn selection never searches for or substitutes an unqualified physical profile."""
	return _field(STATION, row, 5) if rotation == 0 else _rotation_profile[(rotation - 1) * _capacities[STATION] + row]


func _catalog_field(field: int) -> int:
	"""The exact current immutable variant owns allowed rotations and relative region bounds."""
	return _catalog._live.variants[field * Catalog.MAX_VARIANTS + _header[6]]


func _station_profile_refusal(row: int, rotation: int) -> StringName:
	"""Actual exact-yaw work rows explicitly qualify each admitted placement orientation."""
	var profile: int = _station_profile(row, rotation)
	var revision: int = _profile_revision[rotation * _capacities[STATION] + row]
	if (_catalog_field(Catalog.V_ROTATIONS) & (1 << rotation)) == 0:
		return &"" if profile == -1 and revision == 0 else REFUSE_PROFILE
	if profile < 0 or profile >= _profiles._live.header[1] or revision <= 0:
		return REFUSE_PROFILE
	if _profile_field(profile, Profiles.F_SOURCE) != _header[7] \
			or _profile_field(profile, Profiles.F_MODE) != Profiles.MODE_WORK \
			or _profile_field(profile, Profiles.F_YAW_KIND) != Profiles.YAW_EXACT \
			or _profile_field(profile, Profiles.F_YAW) != (_field(STATION, row, 4) + (4 - rotation) * 16384) % 65536 \
			or _profile_field(profile, Profiles.F_POSTURE) != _field(STATION, row, 6) \
			or _profile_field(profile, Profiles.F_WORK_KIND) != _field(STATION, row, 8) \
			or _profile_field(profile, Profiles.F_CONTACT_KIND) != Profiles.CONTACT_ANCHOR_AND_PATCH \
			or _profiles._live.flags[profile] != Profiles.CERT_REQUIRED \
			or _profiles._live.quantities[profile] != revision:
		return REFUSE_PROFILE
	return &""


func _profile_field(profile: int, field: int) -> int:
	"""Only exact actual loaded Profiles columns are read; immutable geometry is not live worker permission."""
	return _profiles._live.fields[field * _profiles._profile_capacity + profile]


func _cut_refusal(row: int) -> StringName:
	"""Dependency phases are exact stable tags; their ASCII enum numbers are never progress thresholds."""
	if _field(CUT, row, 6) not in [Sites.SOLID, Sites.BRACED, Sites.OPEN_UNFINISHED, Sites.SUPPORTED_VOID, Sites.BACKFILLED]:
		return REFUSE_FORMAT
	return _box_refusal(CUT, row, 0, true)


func _bearing_refusal(row: int) -> StringName:
	"""An installed target names a part of its actual billable group; natural targets carry no fabricated part."""
	var kind: int = _field(BEARING, row, 0)
	var assembly: int = _field(BEARING, row, 1)
	var part: int = _field(BEARING, row, 2)
	if kind == NATURAL:
		if assembly != -1 or part != -1: return REFUSE_REFERENCE
	elif kind == INSTALLED_PART:
		if not _valid_row(INSTALL, assembly): return REFUSE_REFERENCE
		if part < _assemblies._first_part[assembly] \
				or part >= _assemblies._first_part[assembly] + _assemblies._part_count[assembly]:
			return REFUSE_REFERENCE
	else:
		return REFUSE_FORMAT
	return _box_refusal(BEARING, row, 3, false)


func _endpoint_refusal(row: int) -> StringName:
	"""Immutable selectors contain no runtime handles and never make a Location exist."""
	var kind: int = _field(ENDPOINT, row, 0)
	var assembly: int = _field(ENDPOINT, row, 1)
	if kind == SURFACE_ANCHOR or kind == SURFACE_CONTACT:
		if assembly != -1 or _field(ENDPOINT, row, 2) != 0: return REFUSE_REFERENCE
	elif kind == INSTALLED_CONTACT:
		if not _valid_row(INSTALL, assembly) or _installed_datum_refusal(row) != &"": return REFUSE_REFERENCE
	else:
		return REFUSE_FORMAT
	var role: int = _field(ENDPOINT, row, 3)
	if role < Locations.ROLE_TRANSIT or role > Locations.ROLE_WORK: return REFUSE_FORMAT
	return _travel_refusal(row)


func _installed_datum_refusal(row: int) -> StringName:
	"""An installed selector names an exact authored LANDING floor; the actual FLOOR_DATUM is proved later."""
	var ordinal: int = _field(ENDPOINT, row, 2)
	if ordinal < 0 or ordinal >= _catalog_field(Catalog.V_REGION_COUNT): return REFUSE_REFERENCE
	var at: int = _catalog_field(Catalog.V_REGION_START) + ordinal
	if _catalog._live.regions[6 * Catalog.MAX_REGIONS + at] != Space.LANDING:
		return REFUSE_REFERENCE
	for axis: int in 3:
		var point: int = _field(ENDPOINT, row, 4 + axis)
		var low: int = _catalog._live.regions[axis * Catalog.MAX_REGIONS + at]
		var high: int = _catalog._live.regions[(axis + 3) * Catalog.MAX_REGIONS + at]
		if (axis == 1 and point != low) or (axis != 1 and (point < low or point >= high)):
			return REFUSE_REFERENCE
	return &""


func _travel_refusal(row: int) -> StringName:
	"""Explicit actual transit selectors bind the same qualified source and full profile revision."""
	var profile: int = _travel_profile[row]
	if profile < 0 or profile >= _profiles._live.header[1] or _travel_revision[row] <= 0:
		return REFUSE_PROFILE
	var mode: int = _profile_field(profile, Profiles.F_MODE)
	if (mode != Profiles.MODE_WALK and mode != Profiles.MODE_CARRY and mode != Profiles.MODE_CLIMB) \
			or _profile_field(profile, Profiles.F_SOURCE) != _header[7] \
			or _profiles._live.flags[profile] != Profiles.CERT_REQUIRED \
			or _profiles._live.quantities[profile] != _travel_revision[row]:
		return REFUSE_PROFILE
	return &""


func _prior_station(station: int, prefix: int) -> StringName:
	"""The station's actual completed endpoint must predate the current operation."""
	return _prior_endpoint(_field(STATION, station, 0), prefix)


func _prior_endpoint(endpoint: int, prefix: int) -> StringName:
	"""A pending assembly can supply neither its own worker floor nor its material/retreat endpoint."""
	if not _valid_row(ENDPOINT, endpoint): return REFUSE_REFERENCE
	return REFUSE_FUTURE if _field(ENDPOINT, endpoint, 0) == INSTALLED_CONTACT \
		and _field(ENDPOINT, endpoint, 1) >= prefix else &""


func _prior_bearing(target: int, prefix: int) -> StringName:
	"""Source support is prior-only; actual retained earth/solid-part intersections still require physical proof."""
	return REFUSE_FUTURE if _field(BEARING, target, 0) == INSTALLED_PART \
		and _field(BEARING, target, 1) >= prefix else &""


func _episode_refusal(row: int) -> StringName:
	"""One exact cut union can share authored phase inputs; every physical cube still has its own actual Site."""
	var code: StringName = _box_refusal(EPISODE, row, 0, true)
	var mask: int = _field(EPISODE, row, 6)
	var prefix: int = _field(EPISODE, row, 7)
	if code != &"" or mask < 1 or mask > 7 or prefix < 0 or prefix > _header[8] \
			or _field(EPISODE, row, 18) < 0 or _field(EPISODE, row, 18) > 5:
		return REFUSE_FORMAT
	if not _range(CUT, _field(EPISODE, row, 11), _field(EPISODE, row, 12), true) \
			or not _range(BEARING, _field(EPISODE, row, 13), _field(EPISODE, row, 14)):
		return REFUSE_REFERENCE
	code = _episode_selectors_refusal(row, mask, prefix)
	if code != &"": return code
	for previous: int in row:
		if (_field(EPISODE, previous, 6) & mask) != 0 and _episodes_overlap(previous, row):
			return REFUSE_DUPLICATE
	return &""


func _episode_selectors_refusal(row: int, mask: int, prefix: int) -> StringName:
	"""Every enabled phase has an explicit source-qualified station, with material/output and retreat selectors."""
	for phase: int in 3:
		var station: int = _field(EPISODE, row, 8 + phase)
		if (mask & (1 << phase)) == 0:
			if station != -1: return REFUSE_REFERENCE
			continue
		if not _valid_row(STATION, station): return REFUSE_REFERENCE
		var code: StringName = _prior_station(station, prefix)
		if code != &"": return code
	for field: int in range(15, 18):
		var code: StringName = _prior_endpoint(_field(EPISODE, row, field), prefix)
		if code != &"": return code
	for target: int in range(_field(EPISODE, row, 13), _field(EPISODE, row, 13) + _field(EPISODE, row, 14)):
		var code: StringName = _prior_bearing(target, prefix)
		if code != &"": return code
	return &""


func _episodes_overlap(first: int, second: int) -> bool:
	"""Half-open integer intersection rejects duplicate phase ownership across differently grouped ranges."""
	for axis: int in 3:
		if _field(EPISODE, first, axis) >= _field(EPISODE, second, axis + 3) \
				or _field(EPISODE, second, axis) >= _field(EPISODE, first, axis + 3):
			return false
	return true


static func source_leaf_refusal(actual: RefCounted) -> StringName:
	"""No source observer, allocation or publication occurs in this final immutable-owner check."""
	return _sources_refusal(actual) if actual != null and actual._loaded and not actual._busy else REFUSE_SOURCE


func binding_matches(catalog: Catalog, assemblies: Assemblies, recipes: Recipes, profiles: Profiles) -> bool:
	"""Borrow only the once-bound concrete owners; equal bytes in foreign namespaces confer no permission."""
	return catalog == _catalog and assemblies == _assemblies and recipes == _recipes and profiles == _profiles \
		and source_leaf_refusal(self) == &""


func _copy_row(table: int, row: int, out: PackedInt32Array) -> StringName:
	"""All source/index/output checks finish before the first caller write; no partial refused output escapes."""
	var code: StringName = source_leaf_refusal(self)
	if code != &"": return code
	if not _valid_row(table, row) or out.size() != row_fields(table): return REFUSE_OUTPUT
	for field: int in row_fields(table):
		out[field] = _field(table, row, field)
	return &""


func installation_into(ordinal: int, out: PackedInt32Array) -> StringName:
	"""Read the exact nine-field INSTALL row; no bill, progress or actual contact is inferred."""
	return _copy_row(INSTALL, ordinal, out)


func station_into(index: int, out: PackedInt32Array, revision: IntMath.IntResult, rotation: int = 0) -> StringName:
	"""Return local coordinates/yaw/face plus the exact chosen world-yaw profile; callers transform the local frame."""
	if revision == null or rotation < 0 or rotation > 3: return REFUSE_OUTPUT
	var source_code: StringName = source_leaf_refusal(self)
	if source_code != &"": return source_code
	if (_catalog_field(Catalog.V_ROTATIONS) & (1 << rotation)) == 0: return REFUSE_PROFILE
	var code: StringName = _copy_row(STATION, index, out)
	if code == &"":
		out[5] = _station_profile(index, rotation)
		revision.value = _profile_revision[rotation * _capacities[STATION] + index]
	return code


func cut_into(index: int, out: PackedInt32Array) -> StringName:
	"""Read one exact cube-union dependency and physical phase tag."""
	return _copy_row(CUT, index, out)


func bearing_into(index: int, out: PackedInt32Array) -> StringName:
	"""Read a retained natural or prior-part target; source bounds alone prove no bearing."""
	return _copy_row(BEARING, index, out)


func endpoint_into(index: int, out: PackedInt32Array) -> StringName:
	"""Read an immutable selector, never a runtime Location or material-container handle."""
	return _copy_row(ENDPOINT, index, out)


func endpoint_travel_into(index: int, profile: IntMath.IntResult, revision: IntMath.IntResult) -> StringName:
	"""Read the explicit transit pair atomically; alias, row, source and output refusals preserve both values."""
	var code: StringName = source_leaf_refusal(self)
	if code != &"": return code
	if not _valid_row(ENDPOINT, index) or profile == null or revision == null or profile == revision:
		return REFUSE_OUTPUT
	profile.value = _travel_profile[index]
	revision.value = _travel_revision[index]
	return &""


func episode_into(index: int, out: PackedInt32Array) -> StringName:
	"""Read the19-field exact cut union and BRACE/CUT/FINISH stations; actual Sites owns every paid phase."""
	return _copy_row(EPISODE, index, out)


func row_count(table: int, revision: int) -> int:
	"""Zero is a stale/invalid-source refusal, never permission to treat an unauthored table as complete."""
	return _header[8 + table] if table >= 0 and table < TABLE_COUNT and revision > 0 \
		and _loaded and _header[0] == revision and source_leaf_refusal(self) == &"" else 0


func content_revision() -> int:
	"""Expose immutable source identity only; this number cannot establish physical constructibility."""
	return _header[0] if _loaded and not _busy else 0


func content_hash_into(revision: int, out: PackedByteArray) -> bool:
	"""The successful whole-source digest is copied only to a complete exact caller buffer."""
	if not _loaded or _busy or revision != _header[0] or out.size() != 32 or source_leaf_refusal(self) != &"":
		return false
	for index: int in 32:
		out[index] = _digests[index]
	return true


func packed_memory_bytes() -> int:
	"""Count actual allocated packed payload; fixed logical/native helper reservation is stated separately."""
	return required_bytes(_capacities) - FIXED_BYTES + 24 + HEADER_FIELDS * 8 + DIGEST_BYTES if _configured else 0


func _clear_bank() -> void:
	"""A refused first load retains only admitted capacity, with no published rows, revisions or hashes."""
	_header.fill(0)
	_digests.fill(0)
	_install.fill(0)
	_station.fill(0)
	_profile_revision.fill(0)
	_rotation_profile.fill(-1)
	_cut.fill(0)
	_bearing.fill(0)
	_endpoint.fill(0)
	_travel_profile.fill(0)
	_travel_revision.fill(0)
	_episode.fill(0)
	_loaded = false
