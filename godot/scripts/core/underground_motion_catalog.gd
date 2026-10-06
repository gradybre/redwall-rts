extends RefCounted
## Immutable source geometry only. This catalog never authorizes travel, support or a gameplay rate.
## Two admitted banks preserve complete gait/handoff columns; no wire or JSON image is retained.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const MoleCatalog := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-handling-v5/catalog_source.gd")
const BANK_BYTES: int = 70860
const WIRE_BYTES: int = 70936
const I32_COUNT: int = 17421
const I64_COUNT: int = 67
const BYTE_COUNT: int = 640
const DECODE_BYTES: int = 4096
const CALLER_BYTES: int = 176
const CONTROL_BYTES: int = 4096
const NATIVE_RESERVE: int = 32768 # Provisional ceiling, not measured allocator usage.
const ONE: int = 65536
const PROGRAMS: int = 5
const SOURCES: int = 3
const HANDOFF: int = 4798
const PROGRAM: int = 16903
const PRIMITIVES: int = 17003
const JOINS: int = 17399
const DOMAIN: int = 17415
const PROGRAM_LONG: int = 32
const ACTOR_BYTES: int = 544
const REVISION: int = 4 # ADR1194: rebound to the content-4 profile wire; tables unchanged.
const SOURCE_WIRE_SHA: String = "16c3c6b030c21fa9185a706493815b87441cfbfe8ceed2fdaa5733c0c4693fcc"
const LEVEL_SHA: String = "c5deb094b335bf6e5db018eeed591a115086b79bd909f829ed6e34166db81f94"
const GAIT_BASE: Array[int] = [0, 24, 570, 1290, 3378, 4354, 4534]
const GAIT_ROWS: Array[int] = [2, 182, 180, 348, 122, 180, 44]
const HANDOFF_BASE: Array[int] = [0, 24, 2289, 4989, 9075, 11523, 11973]
const HANDOFF_ROWS: Array[int] = [3, 453, 450, 681, 306, 450, 22]
const HEADER: Array[int] = [1, REVISION, REVISION, 1, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 5, 3, 66, 4, 0, 0]
const BOUNDS: Array[int] = [0, -32256, 0, 262144, 16896, 262144]
const ACTOR_HASHES: Array[String] = [
	"3a9e2459edba1bf4eaa50f91b5accb53f53317e5fc67bfa75b4a4b4cb8ac6988",
	"16b83eea13565018294c648e75b73e59f1083112a00da1e16b86907a0e392bff",
	"c0d74030fc7e0a56a24d08315af197b82530aae682067f94e2bcd2faedd543af",
]


class Bank extends RefCounted:
	var ints: PackedInt32Array = PackedInt32Array()
	var longs: PackedInt64Array = PackedInt64Array()
	var bytes: PackedByteArray = PackedByteArray()

	func allocate() -> void:
		"""Only configure may call this after the complete joint peak is admitted."""
		ints.resize(I32_COUNT)
		longs.resize(I64_COUNT)
		bytes.resize(BYTE_COUNT)


var _live: Bank = Bank.new()
var _stage: Bank = Bank.new()
var _profiles: Profiles = null
var _profile_bank: Profiles.Bank = null
var _levels: Levels = null
var _directory: Directory = null
var _level_identity: PackedInt32Array = PackedInt32Array()
var _level_config: PackedInt32Array = PackedInt32Array()
var _level_digest: PackedByteArray = PackedByteArray()
var _digest: PackedByteArray = PackedByteArray()
var _world: Vector2i = Vector2i(-1, 0)
var _world_pid: int = 0
var _profile_revision: int = 0
var _level_revision: int = 0
var _admitted_bytes: int = 0
var _revision: int = 0
var _busy: bool = false
var _poisoned: bool = false


func configure(profiles: Profiles, levels: Levels, arena_bytes: int) -> StringName:
	"""Refuse independent maximum composition before the first numeric bank allocation."""
	if _busy:
		_poisoned = true
		return &"MOTION_BUSY"
	if _admitted_bytes != 0:
		return &"MOTION_ALREADY_CONFIGURED"
	var required: int = _joint_bytes(profiles)
	if required < 0 or arena_bytes > Budget.PROFILE_BYTES or arena_bytes < required:
		return &"MOTION_JOINT_CAPACITY"
	_busy = true
	_poisoned = false
	var code: StringName = _cold_owners(profiles, levels)
	if code == &"" and not _poisoned:
		_pin_owners(profiles, levels)
		code = _owner_leaf()
	if code == &"" and not _poisoned:
		_allocate_banks(required)
	_busy = false
	return &"MOTION_BUSY" if _poisoned else code


func _allocate_banks(required: int) -> void:
	"""Called only after the complete joint source and capacity check, with no provider callback."""
	_live.allocate()
	_stage.allocate()
	_digest.resize(32)
	_admitted_bytes = required


static func _joint_bytes(profiles: Profiles) -> int:
	"""The actual configured Profile capacity, not its smaller loaded census, owns both banks."""
	if profiles == null or profiles.get_script() != Profiles:
		return -1
	var p: int = profiles._profile_capacity
	var b: int = profiles._box_capacity
	var s: int = profiles._source_capacity
	if p < 1 or p > Profiles.MAX_PROFILES or b < 1 or b > Profiles.MAX_BOXES or s < 1 or s > Profiles.MAX_SOURCES:
		return -1
	return 2 * (98 * p + 28 * b + 32 * s + 32) + Profiles.CONTROL_RESERVE + Levels.RESERVED_BYTES \
		+ 2 * BANK_BYTES + DECODE_BYTES + CALLER_BYTES + CONTROL_BYTES + NATIVE_RESERVE


static func _cold_owners(profiles: Profiles, levels: Levels) -> StringName:
	"""Current published geometry and cached production consumers remain independently exact."""
	if profiles == null or profiles.get_script() != Profiles or levels == null or levels.get_script() != Levels \
			or levels._revision < 1 or levels._identity.size() != 21 or levels._config.size() != 13 \
			or levels._digest.size() != 32 or levels._directory == null:
		return &"MOTION_SOURCE_OWNER"
	if levels._digest.hex_encode() != LEVEL_SHA:
		return &"MOTION_LEVEL_SOURCE"
	for axis: int in 6:
		if levels._identity[11 + axis] != BOUNDS[axis]:
			return &"MOTION_DOMAIN"
	var code: StringName = MoleCatalog.runtime_sources_refusal()
	if code == &"":
		code = MoleCatalog.catalog_refusal(profiles)
	return code


func _pin_owners(profiles: Profiles, levels: Levels) -> void:
	"""Only bounded fixed controls are copied; canonical source banks stay with their owners."""
	_profiles = profiles
	_profile_bank = profiles._live
	_levels = levels
	_directory = levels._directory
	_profile_revision = profiles._live.header[0]
	_level_revision = levels._revision
	_level_identity.resize(21)
	_level_config.resize(13)
	_level_digest.resize(32)
	for index: int in 21:
		_level_identity[index] = levels._identity[index]
	for index: int in 13:
		_level_config[index] = levels._config[index]
	for index: int in 32:
		_level_digest[index] = levels._digest[index]
	_world = Vector2i(_level_identity[0], _level_identity[1])
	_world_pid = _directory._persistent_id[_world.x] if _world.x >= 0 and _world.x < Directory.DIRECTORY_CAPACITY else 0


func _owner_leaf() -> StringName:
	"""Direct current source and full World facts; no observing provider or profile query."""
	if _profiles == null or _profiles.get_script() != Profiles or _profiles._live != _profile_bank \
			or _profile_bank.header[0] != _profile_revision or _levels == null or _levels.get_script() != Levels \
			or _levels._revision != _level_revision or _levels._directory != _directory \
			or _levels._identity != _level_identity or _levels._config != _level_config or _levels._digest != _level_digest:
		return &"MOTION_SOURCE_STALE"
	if _world.x < 0 or _world.x >= Directory.DIRECTORY_CAPACITY or _world.y < 1 or _directory == null \
			or _directory._active[_world.x] != 1 or _directory._kind[_world.x] != Directory.KIND_WORLD \
			or _directory._generation[_world.x] != _world.y or _world_pid < 1 \
			or _directory._persistent_id[_world.x] != _world_pid or _directory._typed_row[_world.x] != 0 			or _directory._typed_owner_slot[_directory._kind_base[Directory.KIND_WORLD]] != _world.x:
		return &"MOTION_WORLD_STALE"
	return &""


func load_file(path: String, expected_sha: String, revision: int) -> StringName:
	"""Stream one exact source-once candidate; failure keeps the published bank untouched."""
	if _busy:
		_poisoned = true
		return &"MOTION_BUSY"
	if _admitted_bytes == 0 or _revision != 0 or revision != REVISION or path.length() > 1024 \
			or expected_sha != SOURCE_WIRE_SHA:
		return &"MOTION_LOAD_UNAVAILABLE"
	_busy = true
	_poisoned = false
	var code: StringName = _owner_leaf()
	if code == &"":
		code = _cold_owners(_profiles, _levels)
	if code == &"":
		code = _load_stream(path, expected_sha)
	if code == &"":
		code = _validate_stage()
	if code == &"":
		code = _owner_leaf()
	if code == &"" and not _poisoned:
		_publish_source(expected_sha)
	_busy = false
	return &"MOTION_BUSY" if _poisoned else code


func _load_stream(path: String, expected_sha: String) -> StringName:
	"""The same bounded file stream supplies decoding and the complete wire digest."""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return &"MOTION_SOURCE_MISSING"
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	var code: StringName = &"MOTION_WIRE_SIZE" if file.get_length() != WIRE_BYTES else _decode_stream(file, hashing)
	file.close()
	if code == &"" and hashing.finish().hex_encode() != expected_sha.to_lower():
		code = &"MOTION_SOURCE_HASH"
	return code


func _decode_stream(file: FileAccess, hashing: HashingContext) -> StringName:
	"""Fixed counts refuse before any length product or write; all destination arrays already exist."""
	var bytes: PackedByteArray = _read(file, hashing, 32)
	if bytes.size() != 32 or bytes.slice(0, 8).get_string_from_ascii() != "UGMOTN01" \
			or bytes.decode_u32(8) != 1 or bytes.decode_u32(12) != BANK_BYTES or bytes.decode_s64(16) != REVISION \
			or bytes.decode_u32(24) != 3 or bytes.decode_u32(28) != 0:
		return &"MOTION_WIRE_HEADER"
	for column: int in 3:
		var code: StringName = _decode_column(file, hashing, column)
		if code != &"":
			return code
	bytes = _read(file, hashing, 8)
	return &"" if bytes.get_string_from_ascii() == "UGMEND01" and file.get_position() == file.get_length() else &"MOTION_WIRE_FOOTER"


func _decode_column(file: FileAccess, hashing: HashingContext, column: int) -> StringName:
	"""A single at-most4KiB payload window coexists with fixed headers, never a second wire image."""
	var count: int = I32_COUNT if column == 0 else (I64_COUNT if column == 1 else BYTE_COUNT)
	var width: int = 4 if column == 0 else (8 if column == 1 else 1)
	var tag: String = "I032" if column == 0 else ("I064" if column == 1 else "BYTE")
	var header: PackedByteArray = _read(file, hashing, 12)
	if header.size() != 12 or header.slice(0, 4).get_string_from_ascii() != tag \
			or header.decode_u32(4) != width or header.decode_u32(8) != count:
		return &"MOTION_WIRE_COLUMN"
	var at: int = 0
	while at < count:
		@warning_ignore("integer_division") var span: int = mini(DECODE_BYTES / width, count - at)
		var code: StringName = _decode_payload(file, hashing, column, at, span, width)
		if code != &"":
			return code
		at += span
	return &""


func _decode_payload(file: FileAccess, hashing: HashingContext, column: int, at: int, span: int, width: int) -> StringName:
	"""This frame owns every payload alias and dies before the next chunk allocation."""
	var bytes: PackedByteArray = _read(file, hashing, span * width)
	if bytes.size() != span * width:
		return &"MOTION_WIRE_TRUNCATED"
	for index: int in span:
		if column == 0:
			_stage.ints[at + index] = bytes.decode_s32(index * width)
		elif column == 1:
			_stage.longs[at + index] = bytes.decode_s64(index * width)
		else:
			_stage.bytes[at + index] = bytes[index]
	return &""


static func _read(file: FileAccess, hashing: HashingContext, count: int) -> PackedByteArray:
	"""Only fixed-size headers or the admitted4KiB window may be requested."""
	var bytes: PackedByteArray = file.get_buffer(count)
	hashing.update(bytes)
	return bytes


func _publish_source(expected_sha: String) -> void:
	"""One source-only swap after complete validation; no gameplay or geometry owner is mutated."""
	var previous: Bank = _live
	_live = _stage
	_stage = previous
	var bytes: PackedByteArray = expected_sha.hex_decode()
	for index: int in 32:
		_digest[index] = bytes[index]
	_revision = REVISION


func packed_memory_bytes() -> int:
	"""All actual retained motion columns, excluding separately censused controls."""
	return 2 * BANK_BYTES if _admitted_bytes > 0 else 0


func admitted_bytes() -> int:
	"""Joint logical reservation, never a native allocator measurement."""
	return _admitted_bytes


func content_revision() -> int:
	"""A source revision is not movement permission."""
	return _revision


func activation_refusal() -> StringName:
	"""Future actual support, source Profile, renderer, save and pace qualification are absent."""
	return &"MOTION_SOURCE_ONLY"


static func _g(bank: Bank, table: int, row: int, field: int) -> int:
	"""Fixed field-major gait segment; callers validate the exact table and row first."""
	return bank.ints[GAIT_BASE[table] + field * GAIT_ROWS[table] + row]


static func _h(bank: Bank, table: int, row: int, field: int) -> int:
	"""Handoff columns retain their fixed-frame roots and explicit moving heading."""
	return bank.ints[HANDOFF + HANDOFF_BASE[table] + field * HANDOFF_ROWS[table] + row]


static func _p(bank: Bank, program: int, field: int) -> int:
	"""Metadata does not replace a qualifying actual Profile or Catalog owner."""
	return bank.ints[PROGRAM + field * PROGRAMS + program]


func _validate_stage() -> StringName:
	"""Complete fixed-column checks precede source publication, even for this pinned-only wire."""
	for index: int in 20:
		if _stage.longs[index] != HEADER[index]:
			return &"MOTION_METADATA"
	for axis: int in 6:
		if _stage.ints[DOMAIN + axis] != BOUNDS[axis] or _level_identity[11 + axis] != BOUNDS[axis]:
			return &"MOTION_DOMAIN"
	var code: StringName = _stage_sources()
	if code == &"":
		code = _stage_programs()
	if code == &"":
		code = _stage_geometry()
	if code == &"":
		code = _stage_supports()
	return code


func _stage_sources() -> StringName:
	"""Actual profile/level digests and all three exact images are distinct from permission bits."""
	var profile_digest: PackedByteArray = Pins.WIRE_SHA.hex_decode()
	for index: int in 32:
		if _stage.bytes[160 + index] != profile_digest[index] or _stage.bytes[192 + index] != _level_digest[index]:
			return &"MOTION_SOURCE_BINDING"
	for source: int in SOURCES:
		var expected: PackedByteArray = ACTOR_HASHES[source].hex_decode()
		for index: int in 32:
			if _stage.bytes[ACTOR_BYTES + source * 32 + index] != expected[index]:
				return &"MOTION_ACTOR_SOURCE"
		if _stage.longs[20 + source] < 1 or _stage.longs[23 + source] != (2 if source == 0 else (1 if source == 1 else 3)) \
				or _stage.longs[26 + source] != 0 or _stage.longs[29 + source] != 0:
			return &"MOTION_ACTOR_SOURCE"
	return &""


func _stage_programs() -> StringName:
	"""All five nonlooping mappings retain terminal phases and explicitly unbound runtime roles."""
	for program: int in PROGRAMS:
		var component: int = int(program >= 2)
		var local: int = program if component == 0 else program - 2
		var last: int = 270 if program == 3 else 90
		if _p(_stage, program, 0) != component or _p(_stage, program, 1) != local \
				or _p(_stage, program, 2) != mini(program, 2) or _p(_stage, program, 3) != (0 if component == 0 else local) \
				or _p(_stage, program, 4) != component or _p(_stage, program, 9) != -1 or _p(_stage, program, 10) != -1 \
				or _p(_stage, program, 11) != 0 or _p(_stage, program, 12) != 2 or _p(_stage, program, 15) != 0 \
				or _p(_stage, program, 16) != last or _p(_stage, program, 19) != 0:
			return &"MOTION_PROGRAM"
		for field: int in 7:
			var expected: int = (1 if field == 2 else last * ONE) if field == 2 or field == 3 else 0
			if _stage.longs[PROGRAM_LONG + field * PROGRAMS + program] != expected:
				return &"MOTION_PROGRAM"
	return &""


func _stage_geometry() -> StringName:
	"""Every complete box and original solid is present with positive finite integer extents."""
	for component: int in 2:
		for table: int in [3, 6]:
			var count: int = GAIT_ROWS[table] if component == 0 else HANDOFF_ROWS[table]
			for row: int in count:
				for axis: int in 3:
					var low: int = _g(_stage, table, row, axis) if component == 0 else _h(_stage, table, row, axis)
					var high: int = _g(_stage, table, row, axis + 3) if component == 0 else _h(_stage, table, row, axis + 3)
					if low >= high or absi(low) > 8192 or absi(high) > 8192:
						return &"MOTION_BOX"
	for row: int in 66:
		var component: int = _stage.ints[PRIMITIVES + row]
		var solid: int = _stage.ints[PRIMITIVES + 66 + row]
		if component != int(row >= 44) or solid != (row if row < 44 else row - 44) \
				or _stage.ints[PRIMITIVES + 132 + row] != row % 22:
			return &"MOTION_PRIMITIVE_MAP"
	return &""


func _stage_supports() -> StringName:
	"""Complete interval references cannot drop stationary phases or address another source image."""
	for interval: int in 180:
		if _g(_stage, 2, interval, 0) < 0 or _g(_stage, 2, interval, 0) >= 348 \
				or _g(_stage, 2, interval, 1) < 0 or _g(_stage, 2, interval, 1) >= 348 \
				or not _support_span(0, _g(_stage, 2, interval, 2), _g(_stage, 2, interval, 3)):
			return &"MOTION_INTERVAL"
	for interval: int in 450:
		if _h(_stage, 2, interval, 2) < 0 or _h(_stage, 2, interval, 2) >= 681 \
				or _h(_stage, 2, interval, 3) < 0 or _h(_stage, 2, interval, 3) >= 681 \
				or not _support_span(1, _h(_stage, 2, interval, 4), _h(_stage, 2, interval, 5)):
			return &"MOTION_INTERVAL"
	return &""


func _support_span(component: int, first: int, count: int) -> bool:
	"""Reference ranges and every full-foot source row stay inside the complete fixed tables."""
	var refs: int = 180 if component == 0 else 450
	var rows: int = 122 if component == 0 else 306
	if first < 0 or count < 1 or count > 2 or first + count > refs:
		return false
	for index: int in count:
		var row: int = _g(_stage, 5, first + index, 0) if component == 0 else _h(_stage, 5, first + index, 0)
		if row < 0 or row >= rows:
			return false
		var foot: int = _g(_stage, 4, row, 0) if component == 0 else _h(_stage, 4, row, 0)
		var solid: int = _g(_stage, 4, row, 1) if component == 0 else _h(_stage, 4, row, 1)
		if foot < 0 or foot > 1 or solid < 0 or solid >= (44 if component == 0 else 22):
			return false
	return true


func _read_leaf(program: int, revision: int) -> StringName:
	"""An unchanged original actual source tuple is required even for source-only geometry."""
	if _busy or _revision == 0 or revision != _revision or program < 0 or program >= PROGRAMS:
		return &"MOTION_QUERY"
	return _owner_leaf()


func program_into(program: int, revision: int, out: PackedInt32Array, longs: PackedInt64Array) -> StringName:
	"""Copy20I32+7I64; null future profile/variant/rate values are intentional refusals of activation."""
	if out.size() != 20 or longs.size() != 7:
		return &"MOTION_OUTPUT_SIZE"
	var code: StringName = _read_leaf(program, revision)
	if code != &"":
		return code
	for field: int in 20:
		out[field] = _p(_live, program, field)
	for field: int in 7:
		longs[field] = _live.longs[PROGRAM_LONG + field * PROGRAMS + program]
	return &""


func identity_into(revision: int, out: PackedInt64Array) -> StringName:
	"""The exact twenty-field header exposes missing actual-world and qualification bindings as zero."""
	if out.size() != 20:
		return &"MOTION_OUTPUT_SIZE"
	var code: StringName = _read_leaf(0, revision)
	if code != &"":
		return code
	for field: int in 20:
		out[field] = _live.longs[field]
	return &""


func digest_into(selector: int, revision: int, out: PackedByteArray) -> StringName:
	"""Twelve explicit source/proof identities; zero digests are unresolved, never wildcard matches."""
	if out.size() != 32 or selector < 0 or selector >= 12:
		return &"MOTION_OUTPUT_SIZE"
	var code: StringName = _read_leaf(0, revision)
	if code != &"":
		return code
	for index: int in 32:
		out[index] = _live.bytes[160 + selector * 32 + index]
	return &""


func join_into(ordinal: int, revision: int, out: PackedInt32Array) -> StringName:
	"""One exact source-to-source join; it does not create a live Location or graph edge."""
	if out.size() != 4 or ordinal < 0 or ordinal >= 4:
		return &"MOTION_OUTPUT_SIZE"
	var code: StringName = _read_leaf(0, revision)
	if code != &"":
		return code
	for field: int in 4:
		out[field] = _live.ints[JOINS + field * 4 + ordinal]
	return &""


func clip_metadata_into(program: int, revision: int, out: PackedInt32Array) -> StringName:
	"""Exact first/count/nonloop/duration of the selected actual image clip, with no tick-rate adoption."""
	if out.size() != 4:
		return &"MOTION_OUTPUT_SIZE"
	var code: StringName = _read_leaf(program, revision)
	if code != &"":
		return code
	out[0] = _h(_live, 0, program - 2, 0) if program >= 2 else 0
	out[1] = _p(_live, program, 16) + 1
	out[2] = 0
	out[3] = _live.longs[PROGRAM_LONG + 3 * PROGRAMS + program]
	return &""


func source_into(source: int, revision: int, out: PackedInt64Array, digest: PackedByteArray) -> StringName:
	"""Exact source revision/clip count and absent certificate bits;32-byte image identity is copied."""
	if out.size() != 4 or digest.size() != 32 or source < 0 or source >= SOURCES:
		return &"MOTION_OUTPUT_SIZE"
	var code: StringName = _read_leaf(0, revision)
	if code != &"":
		return code
	for field: int in 4:
		out[field] = _live.longs[20 + field * SOURCES + source]
	for index: int in 32:
		digest[index] = _live.bytes[ACTOR_BYTES + source * 32 + index]
	return &""


func phase_into(program: int, revision: int, phase: int, out: PackedInt32Array) -> StringName:
	"""NineI32: fixed-fixture XYZ/yaw, source, clip, absolute first/second frame, Q16 share."""
	if out.size() != 9:
		return &"MOTION_OUTPUT_SIZE"
	var code: StringName = _read_leaf(program, revision)
	if code != &"":
		return code
	var last: int = _p(_live, program, 16)
	if phase < 0 or phase > last * ONE:
		return &"MOTION_PHASE"
	@warning_ignore("integer_division") var frame: int = phase / ONE
	var share: int = phase % ONE
	var second: int = mini(frame + 1, last)
	for axis: int in 3:
		var value: int = _ceil_lerp(_key(program, frame, axis), _key(program, second, axis), share)
		if _p(_live, program, 5) == 2 and axis != 1:
			value = -value
		out[axis] = value + _p(_live, program, 6 + axis)
	out[3] = _p(_live, program, 17) if program < 2 else _ceil_lerp(_key(program, frame, 3), _key(program, second, 3), share)
	out[4] = _p(_live, program, 2)
	out[5] = _p(_live, program, 3)
	out[6] = frame + (_h(_live, 0, program - 2, 0) if program >= 2 else 0)
	out[7] = second + (_h(_live, 0, program - 2, 0) if program >= 2 else 0)
	out[8] = share
	return &""


func _key(program: int, frame: int, field: int) -> int:
	"""Only already-validated program and phase rows reach the immutable source keys."""
	if program < 2:
		return _g(_live, 1, program * 91 + frame, field)
	return _h(_live, 1, _h(_live, 0, program - 2, 0) + frame, field)


static func _ceil_lerp(first: int, second: int, share: int) -> int:
	"""Signed local ceil is applied before fixed orientation, never to transformed endpoints."""
	var numerator: int = first * (ONE - share) + second * share
	@warning_ignore("integer_division") var value: int = (numerator + ONE - 1) / ONE if numerator >= 0 else -((-numerator) / ONE)
	return value


func _interval_leaf(program: int, revision: int, interval: int) -> StringName:
	"""A terminal pose has no next interval; callers must name a real complete source interval."""
	var code: StringName = _read_leaf(program, revision)
	if code != &"":
		return code
	return &"" if interval >= 0 and interval < _p(_live, program, 16) else &"MOTION_INTERVAL"


func interval_box_into(program: int, revision: int, interval: int, role: int, out: PackedInt32Array) -> StringName:
	"""Complete body or held-tool box in fixed fixture space; source root is already included."""
	if out.size() != 6 or role < 0 or role > 1:
		return &"MOTION_OUTPUT_SIZE"
	var code: StringName = _interval_leaf(program, revision, interval)
	if code != &"":
		return code
	var row: int = _interval(program, interval)
	var box: int = _g(_live, 2, row, role) if program < 2 else _h(_live, 2, row, role + 2)
	_box_into(program, 3, box, out)
	return &""


func _interval(program: int, interval: int) -> int:
	"""One global row per original source interval, including stationary-root intervals."""
	return program * 90 + interval if program < 2 else _h(_live, 0, program - 2, 2) + interval


func _box_into(program: int, table: int, row: int, out: PackedInt32Array) -> void:
	"""A fixed half-turn reverses the horizontal bounds; handoff boxes are already fixed-frame."""
	for field: int in 6:
		var axis: int = field % 3
		var source_field: int = (field + 3) % 6 if program == 0 and axis != 1 else field
		var value: int = _g(_live, table, row, source_field) if program < 2 else _h(_live, table, row, source_field)
		if program == 0 and axis != 1:
			value = -value
		out[field] = value + _p(_live, program, 6 + axis)


func interval_support_count(program: int, revision: int, interval: int) -> int:
	"""Negative means refusal; a planted mask alone never creates a full-foot support row."""
	if _interval_leaf(program, revision, interval) != &"":
		return -1
	var row: int = _interval(program, interval)
	return _g(_live, 2, row, 3) if program < 2 else _h(_live, 2, row, 5)


func interval_support_into(program: int, revision: int, interval: int, ordinal: int, out: PackedInt32Array) -> StringName:
	"""Foot/canonical-solid/plane/full XZ enclosure/witness vertex; no actual-world support is inferred."""
	if out.size() != 8:
		return &"MOTION_OUTPUT_SIZE"
	var count: int = interval_support_count(program, revision, interval)
	if count < 0 or ordinal < 0 or ordinal >= count:
		return &"MOTION_SUPPORT"
	var row: int = _interval(program, interval)
	var first: int = _g(_live, 2, row, 2) if program < 2 else _h(_live, 2, row, 4)
	var support: int = _g(_live, 5, first + ordinal, 0) if program < 2 else _h(_live, 5, first + ordinal, 0)
	for field: int in 8:
		out[field] = _g(_live, 4, support, field) if program < 2 else _h(_live, 4, support, field)
	_support_fixture(program, out)
	return &""


func _support_fixture(program: int, out: PackedInt32Array) -> void:
	"""Map immutable source primitive IDs and exact foot enclosure into the fixed canonical fixture."""
	out[1] %= 22
	out[2] += _p(_live, program, 7)
	if program == 0:
		var x: int = out[3]
		var z: int = out[4]
		out[3] = -out[5]
		out[4] = -out[6]
		out[5] = -x
		out[6] = -z
	out[3] += _p(_live, program, 6)
	out[5] += _p(_live, program, 6)
	out[4] += _p(_live, program, 8)
	out[6] += _p(_live, program, 8)


func primitive_into(program: int, revision: int, ordinal: int, out: PackedInt32Array) -> StringName:
	"""All22 exact fixture solids remain; caller must later resolve real paid/natural full identities."""
	if out.size() != 6 or ordinal < 0 or ordinal >= 22:
		return &"MOTION_OUTPUT_SIZE"
	var code: StringName = _read_leaf(program, revision)
	if code != &"":
		return code
	_box_into(program, 6, program * 22 + ordinal if program < 2 else ordinal, out)
	return &""


func primitive_mapping_into(program: int, revision: int, ordinal: int, out: PackedInt32Array) -> StringName:
	"""Copy the source/canonical/kind/authored-part/assembly mapping, never a live Region handle."""
	if out.size() != 6 or ordinal < 0 or ordinal >= 22:
		return &"MOTION_OUTPUT_SIZE"
	var code: StringName = _read_leaf(program, revision)
	if code != &"":
		return code
	var row: int = mini(program, 2) * 22 + ordinal
	for field: int in 6:
		out[field] = _live.ints[PRIMITIVES + field * 66 + row]
	return &""
