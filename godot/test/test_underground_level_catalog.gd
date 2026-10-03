extends "res://test/framework/test_case.gd"
## The real finite engineering pack plus adversarial synthetic corruptions; no world-space permission.

const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const PACK: String = "res://data/underground/initial_level_pack.uglvl"
const HASH: String = "c5deb094b335bf6e5db018eeed591a115086b79bd909f829ed6e34166db81f94"
const TEMP: String = "user://test-underground-level-catalog.bin"
var _levels: Levels = null
var _ids: Directory = null
var _world: Vector2i = Vector2i(-1, 0)
var _domain: Space.Domain = null


func before_each() -> void:
	"""Actual Directory lifetime with the root's finite estuary domain and explicit capacity identity."""
	_ids = Directory.new()
	_world = _ids.create(Directory.KIND_WORLD)
	_domain = _make_domain(_world)
	_levels = Levels.new()


func after_each() -> void:
	"""Only this test's temporary file and owned acyclic references are released."""
	_levels = null
	_domain = null
	_ids = null
	if FileAccess.file_exists(TEMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))


func _make_domain(world: Vector2i, minimum_y: int = -32, cells: int = 8192) -> Space.Domain:
	"""No implicit infinite depth or hardcoded four-level world."""
	var value: Space.Domain = Space.Domain.new()
	assert_equal(value.configure(world, Vector3i(0, 512, 0), Vector3i(0, minimum_y, 0),
		Vector3i(256, 48, 256), cells, 6144, Space.MAX_CHECKS), &"", "finite actual Domain")
	return value


func _load_and_bind() -> void:
	"""Source content and actual immutable domain are separate required steps."""
	assert_equal(_levels.load_file(PACK, HASH, 1), &"", "authored engineering pack")
	assert_equal(_levels.bind_domain(_domain, _ids, _domain.descriptor(), Space.VERSION), &"", "exact World tuple")


func _image() -> PackedByteArray:
	"""Copy test corruption input from the actual tiny authored image."""
	return FileAccess.get_file_as_bytes(PACK)


func _load_bytes(bytes: PackedByteArray, expected: String = "") -> StringName:
	"""Each malformed fixture has its own matching digest so semantic validation is exercised."""
	var file: FileAccess = FileAccess.open(TEMP, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var hash_context: HashingContext = HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	var digest: String = hash_context.finish().hex_encode()
	return _levels.load_file(TEMP, digest if expected == "" else expected, 1)


func test_actual_pack_derives_six_levels_with_complete_local_bands() -> void:
	"""All accepted floors fit the real32m depth; definitions do not create completed void or support."""
	_load_and_bind()
	assert_equal(_levels.level_count(), 6, "derived from depth, spacing and complete footing")
	var record: Levels.Record = Levels.Record.new()
	for level_id: int in range(1, 7):
		assert_equal(_levels.level_into(level_id, 0, record), &"", "finite authored level")
		var floor_y: int = 512 - level_id * 5120
		assert_equal(record.world_ref, _world, "actual full World ref")
		assert_equal(record.content_revision, 1, "actual pack version")
		assert_equal(record.floor_y_u, floor_y, "exact datum-relative floor")
		assert_equal(record.clear_roof_y_u, floor_y + 4096, "4m finished clear shell")
		assert_equal(record.clear_height_u, 4096, "integer clear height")
		assert_true(record.has_roof, "local roof obligation")
		assert_equal(record.protected_above_low_u, floor_y + 4096, "band starts above roof")
		assert_equal(record.protected_above_high_u, floor_y + 5120, "band ends at next base floor")
		assert_equal(record.required_footing_low_u, floor_y - 1024, "complete local footing")
		assert_equal(record.required_footing_high_u, floor_y, "footing ends at actual floor")
	assert_equal(record.floor_y_u, -30208, "deepest base floor")
	assert_equal(_levels.level_into(7, 0, record), &"LEVEL_CATALOG_SECTION", "no invented seventh level")
	assert_equal(record.floor_y_u, -30208, "refusal preserves output")


func test_surface_entry_has_no_invented_roof_or_completed_floor() -> void:
	"""Surface ID0 records the actual datum; construction still needs actual reachable terrain/contact."""
	_load_and_bind()
	var record: Levels.Record = Levels.Record.new()
	assert_equal(_levels.level_into(0, 0, record), &"", "surface entry datum")
	assert_equal(record.floor_y_u, 512, "terrain datum, not demo Y0")
	assert_false(record.has_roof, "no invented surface ceiling")
	assert_equal(record.protected_above_low_u, record.protected_above_high_u, "no whole-map roof volume")
	assert_equal(_levels.level_into(0, 1024, record), &"LEVEL_CATALOG_SECTION", "room section menu cannot raise terrain")
	assert_equal(record.floor_y_u, 512, "refused surface edit leaves metadata intact")


func test_sections_keep_roof_fixed_and_require_matching_authored_short_rise() -> void:
	"""Raised floors reduce headroom; sunken floors require their actual deeper footing."""
	_load_and_bind()
	assert_equal(_levels.section_offset_count(), 3, "finite engineering menu")
	var record: Levels.Record = Levels.Record.new()
	for index: int in 3:
		var offset: int = _levels.section_offset_at(index)
		assert_equal(offset, (index - 1) * 1024, "exact whole-cube offset")
		assert_equal(_levels.level_into(1, offset, record), &"", "local section")
		assert_equal(record.floor_y_u, -4608 + offset, "section floor only")
		assert_equal(record.clear_roof_y_u, -512, "roof never moves with the floor")
		assert_equal(record.clear_height_u, 4096 - offset, "real remaining headroom")
		assert_equal(record.required_footing_low_u, -5632 + offset, "footing follows actual floor")
		assert_equal(record.protected_above_high_u, 512, "upper structure remains protected")
	assert_true(_levels.has_short_rise(0, 1024), "1m fixed short variant")
	assert_true(_levels.has_short_rise(1024, -1024), "2m fixed short variant")
	assert_false(_levels.has_short_rise(0, 512), "never silently rounds a half-cube choice")
	assert_false(_levels.has_short_rise(0, 0), "not a vertical connector")
	assert_equal(_levels.section_offset_at(3), -2147483648, "invalid menu index")


func test_stale_world_or_foreign_domain_cannot_keep_valid_looking_heights() -> void:
	"""Full generation, exact domain shape/capacity/version and Directory instance are bound."""
	_load_and_bind()
	assert_true(_levels.binding_matches(_make_domain(_world), _ids, Space.VERSION), "equal immutable domain copy")
	assert_false(_levels.binding_matches(_make_domain(_world, -32, 4096), _ids, Space.VERSION), "capacity identity differs")
	assert_false(_levels.binding_matches(_domain, _ids, Space.VERSION + 1), "format version differs")
	var foreign: Directory = Directory.new()
	assert_equal(foreign.create(Directory.KIND_WORLD), _world, "deliberate ref-number collision")
	assert_false(_levels.binding_matches(_domain, foreign, Space.VERSION), "different actual owner refused")
	var record: Levels.Record = Levels.Record.new()
	record.floor_y_u = 777
	assert_true(_ids.destroy(_world), "actual World retired")
	var replacement: Vector2i = _ids.create(Directory.KIND_WORLD)
	assert_equal(replacement.x, _world.x, "same slot deliberately reused")
	assert_equal(_levels.level_count(), 0, "old generation cannot expose a catalog")
	assert_equal(_levels.level_into(1, 0, record), &"LEVEL_CATALOG_WORLD_STALE", "exact World lifetime")
	assert_equal(record.floor_y_u, 777, "refused output untouched")


func test_failed_binding_does_not_partially_publish_identity() -> void:
	"""A stale expected descriptor cannot turn a refused binding into a usable level menu."""
	assert_equal(_levels.load_file(PACK, HASH, 1), &"", "authored pack")
	var expected: Dictionary = _domain.descriptor()
	expected.max_cells = 4096
	assert_equal(_levels.bind_domain(_domain, _ids, expected, Space.VERSION), &"LEVEL_CATALOG_DOMAIN", "capacity drift")
	assert_equal(_levels.level_count(), 0, "no partial binding")
	assert_equal(_levels.bind_domain(_domain, _ids, _domain.descriptor(), 0), &"LEVEL_CATALOG_DOMAIN", "unversioned domain")
	var changed: Space.Domain = _make_domain(_world, -31)
	assert_equal(_levels.bind_domain(changed, _ids, changed.descriptor(), Space.VERSION), &"LEVEL_CATALOG_DOMAIN", "pack shape mismatch")
	assert_equal(_levels.bind_domain(_domain, _ids, _domain.descriptor(), Space.VERSION), &"", "exact retry")
	assert_equal(_levels.bind_domain(_domain, _ids, _domain.descriptor(), Space.VERSION), &"LEVEL_CATALOG_ALREADY_BOUND", "no migration")


func test_unbound_or_extreme_lookup_never_narrows_before_refusal() -> void:
	"""Membership and finite level bounds precede every arithmetic operation on caller input."""
	var record: Levels.Record = Levels.Record.new()
	record.floor_y_u = 123
	assert_equal(_levels.level_into(1, 0, record), &"LEVEL_CATALOG_WORLD_STALE", "no source or World")
	_load_and_bind()
	for level_id: int in [-1, 7, 9223372036854775807]:
		assert_equal(_levels.level_into(level_id, 0, record), &"LEVEL_CATALOG_SECTION", "level checked before multiplication")
		assert_equal(record.floor_y_u, 123, "no output write")
	assert_equal(_levels.level_into(1, -9223372036854775807, record), &"LEVEL_CATALOG_SECTION", "offset membership before sum")
	assert_false(_levels.has_short_rise(-9223372036854775807, 9223372036854775807), "membership before overflowing subtraction")
	assert_equal(_levels.level_into(1, 0, null), &"LEVEL_CATALOG_WORLD_STALE", "null scratch")


func test_offset_footing_outside_a_shallower_domain_is_not_silently_clipped() -> void:
	"""A base floor may fit while its optional sunken section cannot retain complete support."""
	var bytes: PackedByteArray = _image()
	bytes.encode_s32(36, -31)
	assert_equal(_load_bytes(bytes), &"", "synthetic shallower authored pack")
	_domain = _make_domain(_world, -31)
	assert_equal(_levels.bind_domain(_domain, _ids, _domain.descriptor(), Space.VERSION), &"", "matching actual shallower World")
	var record: Levels.Record = Levels.Record.new()
	assert_equal(_levels.level_into(6, 0, record), &"", "base sixth level fits")
	var previous: int = record.floor_y_u
	assert_equal(_levels.level_into(6, -1024, record), &"LEVEL_CATALOG_SECTION_OUTSIDE_DOMAIN", "complete deeper footing cannot fit")
	assert_equal(record.floor_y_u, previous, "no clipped or rounded replacement")


func test_hash_schema_truncation_and_capacity_refuse_before_publication() -> void:
	"""Digest binds the bytes actually decoded; neither extra data nor omitted offsets can count as content."""
	assert_equal(_load_bytes(_image(), "0".repeat(64)), &"LEVEL_CATALOG_SOURCE", "wrong digest")
	assert_equal(_levels.content_revision(), 0, "no partial content")
	var bytes: PackedByteArray = _image()
	bytes.encode_u32(8, 999)
	assert_equal(_load_bytes(bytes), &"LEVEL_CATALOG_SCHEMA", "unknown schema")
	bytes = _image()
	bytes.encode_u32(72, 2147483647)
	assert_equal(_load_bytes(bytes), &"LEVEL_CATALOG_CAPACITY", "offset count before allocation")
	bytes = _image()
	bytes.append(0)
	assert_equal(_load_bytes(bytes), &"LEVEL_CATALOG_CAPACITY", "trailing data")
	assert_equal(_load_bytes(_image().slice(0, 100)), &"LEVEL_CATALOG_CAPACITY", "truncated record")
	assert_equal(_levels.content_revision(), 0, "all failed candidates remained absent")
	assert_equal(_levels.load_file(PACK, HASH, 1), &"", "valid retry")
	assert_equal(_levels.load_file(PACK, HASH, 1), &"LEVEL_CATALOG_ALREADY_LOADED", "immutable content")


func test_nonquantized_spacing_or_overflowing_domain_never_creates_implicit_levels() -> void:
	"""Malformed engineering content has no source authority and is never rounded or repaired."""
	var bytes: PackedByteArray = _image()
	bytes.encode_s32(56, 5121)
	assert_equal(_load_bytes(bytes), &"LEVEL_CATALOG_QUANTUM", "no silent cut rounding")
	bytes = _image()
	bytes.encode_s32(24, 2147483647)
	assert_equal(_load_bytes(bytes), &"LEVEL_CATALOG_DOMAIN", "check datum sum before narrowing")
	bytes = _image()
	bytes.encode_s32(64, 2048)
	assert_equal(_load_bytes(bytes), &"LEVEL_CATALOG_PROTECTED_BAND", "cannot change structure without spacing")
	assert_equal(_levels.content_revision(), 0, "failed source has no authority")


func test_content_hash_uses_exact_scratch_and_does_not_alias_storage() -> void:
	"""The owning World can pin source bytes without receiving a mutable internal digest alias."""
	assert_equal(_levels.load_file(PACK, HASH, 1), &"", "actual content")
	var bytes: PackedByteArray = PackedByteArray([7])
	assert_false(_levels.content_hash_into(bytes), "wrong shape")
	assert_equal(bytes[0], 7, "refusal leaves scratch untouched")
	bytes.resize(32)
	assert_true(_levels.content_hash_into(bytes), "copy actual content fingerprint")
	assert_equal(bytes.hex_encode(), HASH, "exact digest")
	bytes.fill(0)
	assert_true(_levels.content_hash_into(bytes), "caller mutation was not catalog mutation")
	assert_equal(bytes.hex_encode(), HASH, "immutable source storage")
