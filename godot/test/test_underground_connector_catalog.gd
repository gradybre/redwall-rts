extends "res://test/framework/test_case.gd"
## Synthetic finite geometry/certificates test this loader and ACTUAL Movement identity readers.
## These inputs are never authored connector installation, body clearance or climbing permission.

const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Movement := preload("res://scripts/core/movement.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Connectors := preload("res://scripts/core/room_connectors.gd")
const Geometry := preload("res://scripts/core/connector_geometry.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const LEVEL_PATH: String = "res://data/underground/initial_level_pack.uglvl"
const LEVEL_HASH: String = "c5deb094b335bf6e5db018eeed591a115086b79bd909f829ed6e34166db81f94"
const TEMP: String = "user://test-underground-connectors.bin"
const PROFILE_TEMP: String = "user://test-underground-connector-profiles.bin"
const VARIANT_BASE: int = 136
const PATH_BASE: int = VARIANT_BASE + 5 * 112
const REGION_BASE: int = PATH_BASE + 10 * 16
const PART_BASE: int = REGION_BASE + 30 * 32
const VERTEX_BASE: int = PART_BASE + 5 * 36
const MATERIAL_BASE: int = VERTEX_BASE + 20 * 12
const PACE_BASE: int = MATERIAL_BASE + 4
var _catalog: Catalog = null
var _profiles: Profiles = null
var _levels: Levels = null
var _movement: Movement = null
var _residents: Residents = null
var _transforms: Transforms = null
var _domain: Space.Domain = null
var _world: Vector2i = Vector2i(-1, 0)
var _identity: PackedInt32Array = PackedInt32Array([0, 0, 0])


func before_each() -> void:
	"""One actual Directory, adult species profile and finite estuary domain; geometry remains synthetic."""
	_residents = Residents.new()
	_world = _residents.directory().create(Directory.KIND_WORLD)
	var worker: Vector2i = _residents.ref_of(_residents.spawn(&"mouse").value)
	assert_true(_residents.spatial_profile_identity_into(worker, _identity), "actual species/stage/rig")
	_transforms = Transforms.new(_residents.directory())
	_movement = Movement.new(_residents.directory(), null, null, _transforms, _residents)
	_domain = Space.Domain.new()
	assert_equal(_domain.configure(_world, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
		Vector3i(256, 48, 256), 8192, 6144, Space.MAX_CHECKS), &"", "actual finite Domain")
	_levels = Levels.new()
	assert_equal(_levels.load_file(LEVEL_PATH, LEVEL_HASH, 1), &"", "authored level geometry")
	assert_equal(_levels.bind_domain(_domain, _residents.directory(), _domain.descriptor(), Space.VERSION), &"", "World identity")
	_profiles = Profiles.new()
	assert_equal(_profiles.configure(8, 64, 2, Profiles.ARENA_BYTES), &"", "finite synthetic certificate arena")
	assert_equal(_load_profiles(synthetic_profile_image(_identity)), &"", "synthetic immutable source")
	_catalog = Catalog.new()
	assert_equal(_catalog.configure(Catalog.RESERVED_BYTES), &"", "admit full two-bank peak")
	assert_equal(_catalog.bind_actual(_profiles, _levels, _movement, _residents, _transforms, _domain), &"", "exact owners")


func after_each() -> void:
	"""Release this suite's acyclic owners and remove only its own temporary files."""
	_catalog = null
	_profiles = null
	_levels = null
	_movement = null
	_transforms = null
	_residents = null
	_domain = null
	for path: String in [TEMP, PROFILE_TEMP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _append_row(bytes: PackedByteArray, fields: PackedInt32Array, revision: int = -1) -> void:
	"""Independent row-wire encoder, not the loader's field-major memory indexing."""
	var start: int = bytes.size()
	bytes.resize(start + fields.size() * 4 + (8 if revision >= 0 else 0))
	for index: int in fields.size():
		bytes.encode_s32(start + index * 4, fields[index])
	if revision >= 0:
		bytes.encode_s64(start + fields.size() * 4, revision)


static func synthetic_profile_image(identity: PackedInt32Array, revision: int = 1) -> PackedByteArray:
	"""Reusable test-only trusted wire: two synthetic adult walking/climbing certificates, never production proof."""
	var bytes: PackedByteArray = "UGPROF01".to_ascii_buffer()
	bytes.resize(32)
	bytes.encode_u32(8, 1)
	bytes.encode_s64(12, revision)
	bytes.encode_u32(20, 2)
	bytes.encode_u32(24, 6)
	bytes.encode_u32(28, 1)
	for index: int in 32:
		bytes.append(7)
	for index: int in 2:
		_append_row(bytes, PackedInt32Array([0, identity[0], identity[1], identity[2],
			Profiles.MODE_WALK if index == 0 else Profiles.MODE_CLIMB, 0, -1, -1, -1, -1,
			Profiles.YAW_ALL, 0, 31, 511, index * 3, 3, -1, 0]), 1)
		bytes.resize(bytes.size() + 18) # Two zero I64 quantities and two certificate bytes.
		bytes[bytes.size() - 2] = Profiles.CERT_REQUIRED
	for index: int in 2:
		_append_row(bytes, PackedInt32Array([-128, -1, -128, 128, 900, 128, Profiles.BODY_HELD_LOAD]))
		_append_row(bytes, PackedInt32Array([-181, -1, -181, 181, 0, 181, Profiles.STANCE_SUPPORT]))
		_append_row(bytes, PackedInt32Array([-181, -1, -181, 181, 900, 181, Profiles.TURN_RECOVERY]))
	bytes.append_array("UGPEND01".to_ascii_buffer())
	return bytes


static func synthetic_image(revision: int = 1, profile_revision: int = 1) -> PackedByteArray:
	"""Reusable test-only connector wire; each family's typed rows are intentionally not a qualified built stair."""
	var bytes: PackedByteArray = "UGCONN01".to_ascii_buffer()
	bytes.resize(72)
	bytes.encode_u32(8, 1)
	bytes.encode_s64(12, revision)
	var counts: PackedInt32Array = PackedInt32Array([5, 10, 30, 5, 20, 1, 6])
	for index: int in 7:
		bytes.encode_u32(20 + index * 4, counts[index])
	bytes.encode_s64(48, profile_revision)
	bytes.encode_s64(56, 1)
	bytes.encode_s64(64, 0)
	for index: int in 32:
		bytes.append(7)
	bytes.append_array(LEVEL_HASH.hex_decode())
	for family: int in 5:
		_append_row(bytes, PackedInt32Array([family, 0, 15, 0, 0, 0, 0, 1024, -2048,
			0, 1, 0, 0, family * 2, 2, family * 6, 6, family, 1, family * 4, 4, 0, 0,
			Profiles.MODE_CLIMB if family == 4 else Profiles.MODE_WALK, 0, 1]), 1)
	for family: int in 5:
		_append_row(bytes, PackedInt32Array([0, 0, 0, 0]))
		_append_row(bytes, PackedInt32Array([0, 1024, -2048, 0]))
	_append_geometry(bytes)
	_append_row(bytes, PackedInt32Array([1024]))
	_append_row(bytes, PackedInt32Array([0, -1, 0, 0, 1, 0, Catalog.RATE_GROUND_CAP]), 1)
	for family: int in 5:
		_append_row(bytes, PackedInt32Array([1 if family == 4 else 0, family, 0, 0, 1, 512, Catalog.RATE_AUTHORED]), 1)
	bytes.append_array("UGCEND01".to_ascii_buffer())
	return bytes


static func _append_geometry(bytes: PackedByteArray) -> void:
	"""Finite typed region/primitive fixture; actual five-family construction and contacts qualify elsewhere."""
	for family: int in 5:
		_append_row(bytes, PackedInt32Array([-1024, -256, -3072, 1024, 4096, 1024, Space.ENVELOPE, 0]))
		_append_row(bytes, PackedInt32Array([-512, 0, -512, 512, 1024, 512, Space.LANDING, 0]))
		_append_row(bytes, PackedInt32Array([-512, 1024, -2560, 512, 2048, -1536, Space.LANDING, 1]))
		_append_row(bytes, PackedInt32Array([-512, -128, -2560, 512, 0, 512, Space.SUPPORT_REQUIRED, 0]))
		_append_row(bytes, PackedInt32Array([-512, 1024, -2560, 512, 2048, -1536, Space.OPENING, 1]))
		_append_row(bytes, PackedInt32Array([-256, -128, -1024, 256, 0, 0, Space.SOLID, 0]))
	for family: int in 5:
		_append_row(bytes, PackedInt32Array([Geometry.TREAD, 128, 0, -1, 0, 0, 0, family * 4, 4]))
	for family: int in 5:
		for point: Vector3i in [Vector3i(-256, 0, -1024), Vector3i(256, 0, -1024),
				Vector3i(256, 0, 0), Vector3i(-256, 0, 0)]:
			_append_row(bytes, PackedInt32Array([point.x, point.y, point.z]))


static func _write(path: String, bytes: PackedByteArray) -> String:
	"""Hash exactly the independent candidate written to this test's unique temporary file."""
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _load(bytes: PackedByteArray, revision: int = 1, expected_hash: String = "") -> StringName:
	"""Digest-correct corruptions exercise semantics rather than merely failing provenance."""
	var digest: String = _write(TEMP, bytes)
	return _catalog.load_file(TEMP, digest if expected_hash == "" else expected_hash, revision)


func _load_profiles(bytes: PackedByteArray, revision: int = 1) -> StringName:
	"""Use the actual immutable Profiles loader, without pretending a synthetic certificate is a real asset."""
	return _profiles.load_file(PROFILE_TEMP, _write(PROFILE_TEMP, bytes), revision)


func test_exact_actual_pace_uses_movement_source_and_explicit_family_rows() -> void:
	"""Synthetic family timing cannot override the unchanged actual adult mouse cap or publish clearance."""
	assert_equal(_load(synthetic_image()), &"", "finite synthetic catalog")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_equal(_catalog.pace_into(0, 1, 1, -1, 0, 1, out), &"", "exact ground convention")
	assert_equal(out.value, 3277, "actual Movement cap, not a copied catalog number")
	for family: int in 5:
		assert_equal(_catalog.pace_into(1 if family == 4 else 0, 1, 1, family, 0, 1, out), &"", "exact authored fixture rate")
		assert_equal(out.value, 512, "explicit synthetic pace")
	assert_false(_movement.profile_clearance_class_into(0, out), "catalog did not grant legacy clearance")
	assert_false(_movement.profile_permits_mode(0, Movement.MODE_CLIMB), "catalog did not add climbing ability")


func test_all_family_metadata_and_exact_output_shapes_are_copied_without_aliases() -> void:
	"""Every fixed row is observed as exact authored integer data, never stretched or given world identity."""
	assert_equal(_load(synthetic_image()), &"", "fixture")
	var record: Catalog.Record = Catalog.Record.new()
	var point: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var region: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	var part: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
	var vertex: PackedInt32Array = PackedInt32Array([0, 0, 0])
	for family: int in 5:
		assert_equal(_catalog.variant_into(family, 0, 1, record), &"", "family metadata")
		assert_equal(record.family, family, "exact family")
		assert_equal(record.opening_count, 1, "exact required target count")
		assert_equal(record.end, Vector3i(0, 1024, -2048), "fixed rise and run")
		assert_equal(_catalog.path_point_into(family, 1, 1, 1, point), &"", "endpoint")
		assert_equal(point, PackedInt32Array([0, 1024, -2048, 0]), "no rounding or implicit rotation")
		assert_equal(_catalog.region_into(family, 1, 1, 4, region), &"", "exact opening row")
		assert_equal(region[6], Space.OPENING, "role preserved")
		assert_equal(_catalog.part_into(family, 1, 1, 0, part), &"", "part metadata")
		assert_equal(part[7], 0, "variant-relative vertex index")
		assert_equal(_catalog.vertex_into(family, 1, 1, 0, vertex), &"", "exact source vertex")
	point.fill(99)
	assert_equal(_catalog.path_point_into(0, 1, 1, 0, point), &"", "reader is copied")
	assert_equal(point, PackedInt32Array([0, 0, 0, 0]), "caller never changed stored content")


func test_arena_admission_precedes_all_packed_allocation() -> void:
	"""Both replacement banks and native/decode controls must be budgeted, with no third image."""
	var catalog: Catalog = Catalog.new()
	assert_equal(catalog.packed_memory_bytes(), 0, "unconfigured packed arena")
	assert_equal(Catalog.RESERVED_BYTES, 190448, "approved bindings reservation")
	assert_equal(catalog.configure(Catalog.RESERVED_BYTES - 1), &"CONNECTOR_CATALOG_CAPACITY", "full admission required")
	assert_equal(catalog.packed_memory_bytes(), 0, "refused before allocation")
	assert_equal(catalog.configure(Catalog.RESERVED_BYTES), &"", "complete peak admitted")
	assert_equal(catalog.packed_memory_bytes(), 172048, "two source-derived banks plus fixed digest scratch")
	assert_equal(catalog.configure(Catalog.RESERVED_BYTES), &"CONNECTOR_CATALOG_ALREADY_CONFIGURED", "no hidden reallocation")


func test_foreign_actual_owners_and_rebinding_refuse() -> void:
	"""Numeric Directory/profile coincidences cannot substitute another actual world composition."""
	var other: Residents = Residents.new()
	var foreign: Movement = Movement.new(other.directory(), null, null, Transforms.new(other.directory()), other)
	var catalog: Catalog = Catalog.new()
	assert_equal(catalog.configure(Catalog.RESERVED_BYTES), &"", "arena")
	assert_equal(catalog.bind_actual(_profiles, _levels, foreign, _residents, _transforms, _domain),
		&"CONNECTOR_CATALOG_OWNER_MISMATCH", "foreign pace owner")
	assert_true(_catalog.binding_matches(_profiles, _levels, _movement, _residents, _transforms, _domain), "actual composition")
	assert_false(_catalog.binding_matches(_profiles, _levels, foreign, _residents, _transforms, _domain), "exact owner identity")
	assert_equal(_catalog.bind_actual(_profiles, _levels, _movement, _residents, _transforms, _domain),
		&"CONNECTOR_CATALOG_ALREADY_BOUND", "no silent migration")


func test_every_stale_refusal_preserves_all_output_fields() -> void:
	"""Refused readers cannot clobber a prior accepted answer, including IntResult status/error."""
	assert_equal(_load(synthetic_image()), &"", "fixture")
	var record: Catalog.Record = Catalog.Record.new()
	record.family = 99
	assert_equal(_catalog.variant_into(0, 0, 2, record), &"CONNECTOR_CATALOG_STALE", "content revision")
	assert_equal(record.family, 99, "metadata preserved")
	var point: PackedInt32Array = PackedInt32Array([7, 8, 9, 10])
	assert_equal(_catalog.path_point_into(0, 2, 1, 0, point), &"CONNECTOR_CATALOG_VARIANT_STALE", "variant revision")
	assert_equal(_catalog.path_point_into(0, 1, 1, 2, point), &"CONNECTOR_CATALOG_OUTPUT", "ordinal")
	assert_equal(point, PackedInt32Array([7, 8, 9, 10]), "point preserved")
	var out: IntMath.IntResult = IntMath.IntResult.new(false, 777, "prior")
	assert_equal(_catalog.pace_into(0, 9, 1, -1, 0, 1, out), &"CONNECTOR_PACE_UNAUTHORED", "profile revision")
	assert_equal(_catalog.pace_into(0, 1, 1, -1, 1, 1, out), &"CONNECTOR_PACE_UNAUTHORED", "ground variant not guessed")
	assert_equal(_catalog.pace_into(0, 1, 1, 4, 0, 1, out), &"CONNECTOR_PACE_UNAUTHORED", "climb profile not borrowed")
	assert_equal(out.value, 777, "scalar preserved")
	assert_false(out.ok, "prior status preserved")
	assert_equal(out.error, "prior", "prior error preserved")


func test_atomic_failed_replacement_preserves_live_hash_and_queries() -> void:
	"""Malformed replacement content cannot evict accepted geometry or expose half-decoded rows."""
	var original: PackedByteArray = synthetic_image()
	assert_equal(_load(original), &"", "first image")
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(32)
	assert_true(_catalog.content_hash_into(1, digest), "first digest")
	var expected: String = digest.hex_encode()
	var invalid: PackedByteArray = synthetic_image(2)
	invalid.encode_s32(VARIANT_BASE + 2 * 4, 16)
	assert_equal(_load(invalid, 2), &"CONNECTOR_CATALOG_VARIANT", "invalid rotation mask")
	assert_equal(_catalog.content_revision(), 1, "old image retained")
	assert_true(_catalog.content_hash_into(1, digest), "old digest remains")
	assert_equal(digest.hex_encode(), expected, "byte-identical content identity")
	assert_equal(_load(synthetic_image(2), 2), &"", "valid replacement")
	assert_false(_catalog.content_hash_into(1, digest), "old content handle invalidated")
	assert_equal(digest.hex_encode(), expected, "refused digest copy unchanged")


func test_truncation_trailing_bytes_hash_and_oversized_counts_refuse() -> void:
	"""Wire limits precede loops and decode; a correct candidate hash cannot excuse malformed structure."""
	assert_equal(_load(synthetic_image(), 1, "0".repeat(64)), &"CONNECTOR_CATALOG_SOURCE_HASH", "wrong source hash")
	var bytes: PackedByteArray = synthetic_image()
	bytes.resize(bytes.size() - 1)
	assert_equal(_load(bytes), &"CONNECTOR_CATALOG_FORMAT", "truncated trailer")
	bytes = synthetic_image()
	bytes.append(0)
	assert_equal(_load(bytes), &"CONNECTOR_CATALOG_FORMAT", "trailing bytes")
	bytes = synthetic_image()
	bytes.encode_u32(28, Catalog.MAX_REGIONS + 1)
	assert_equal(_load(bytes), &"CONNECTOR_CATALOG_CAPACITY", "region bound before payload")
	bytes = synthetic_image()
	bytes[136] = 99
	assert_equal(_load(bytes), &"CONNECTOR_CATALOG_VARIANT", "unknown family")
	assert_equal(_catalog.content_revision(), 0, "nothing partially accepted")


func test_short_record_decode_refuses_without_overwriting_destination() -> void:
	"""A file truncated after size admission still cannot feed out-of-bounds record decoders."""
	_write(TEMP, PackedByteArray([1, 2, 3]))
	var file: FileAccess = FileAccess.open(TEMP, FileAccess.READ)
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var target: PackedInt32Array = PackedInt32Array([55])
	assert_equal(Catalog._decode_table(file, digest, target, 1, 1, 1), &"CONNECTOR_CATALOG_FORMAT", "short row")
	file.close()
	assert_equal(target[0], 55, "no invalid decode or partial row write")


func test_complete_prefix_census_endpoint_and_opening_targets_are_required() -> void:
	"""Missing, duplicated or silently shifted rows cannot masquerade as complete authored content."""
	var bytes: PackedByteArray = synthetic_image()
	bytes.encode_s32(VARIANT_BASE + 13 * 4, 1)
	assert_equal(_load(bytes), &"CONNECTOR_CATALOG_CENSUS", "missing first path point")
	bytes = synthetic_image()
	bytes.encode_s32(PATH_BASE, 1)
	assert_equal(_load(bytes), &"CONNECTOR_GEOMETRY_ENDPOINT", "metadata/path mismatch")
	bytes = synthetic_image()
	bytes.encode_s32(VARIANT_BASE + 25 * 4, 2)
	assert_equal(_load(bytes), &"CONNECTOR_FOOTPRINT_MISSING", "one unbound opening target")
	bytes = synthetic_image()
	bytes.encode_s32(REGION_BASE + 2 * 32 + 7 * 4, 0)
	assert_equal(_load(bytes), &"CONNECTOR_FOOTPRINT_MISSING", "upper landing on wrong level")
	bytes = synthetic_image()
	bytes.encode_s32(VARIANT_BASE + 25 * 4, Catalog.MAX_OPENINGS_PER_VARIANT + 1)
	assert_equal(_load(bytes), &"CONNECTOR_CATALOG_VARIANT", "finite target list")


func test_extreme_coordinates_primitive_ranges_and_material_scale_refuse() -> void:
	"""Integer bounds are tested before later render/placement transforms; malformed content is not repaired."""
	var bytes: PackedByteArray = synthetic_image()
	bytes.encode_s32(PATH_BASE, -2147483648)
	assert_equal(_load(bytes), &"CONNECTOR_GEOMETRY_OVERFLOW", "INT32_MIN cannot negate into a plausible point")
	bytes = synthetic_image()
	bytes.encode_s32(REGION_BASE + 7 * 4, 2147483647)
	assert_equal(_load(bytes), &"CONNECTOR_CATALOG_REGION", "relative level bounded")
	bytes = synthetic_image()
	bytes.encode_s32(PART_BASE + 7 * 4, 1)
	assert_equal(_load(bytes), &"CONNECTOR_PART_FORMAT", "vertex prefix gap")
	bytes = synthetic_image()
	bytes.encode_s32(PART_BASE + 3 * 4, 0)
	assert_equal(_load(bytes), &"CONNECTOR_HINGE_FORMAT", "non-hatch cannot carry a hinge")
	bytes = synthetic_image()
	bytes.encode_s32(MATERIAL_BASE, 0)
	assert_equal(_load(bytes), &"CONNECTOR_MATERIAL_SCALE", "zero metre scale")


func test_pace_identity_never_borrows_species_stage_or_unprofiled_badger() -> void:
	"""Every authored pace has the exact actual Movement profile and immutable body revision."""
	var bytes: PackedByteArray = synthetic_image()
	bytes.encode_s32(PACE_BASE + 3 * 4, 1)
	assert_equal(_load(bytes), &"CONNECTOR_PACE_SPECIES_STAGE", "mole pace cannot stand in for mouse")
	bytes = synthetic_image()
	bytes.encode_s32(PACE_BASE + 3 * 4, Movement.PROFILE_COUNT)
	assert_equal(_load(bytes), &"CONNECTOR_PACE_MOVEMENT_STALE", "missing badger profile has no default")
	bytes = synthetic_image()
	bytes.encode_s64(PACE_BASE + 7 * 4, 2)
	assert_equal(_load(bytes), &"CONNECTOR_PACE_PROFILE", "profile revision mismatch")
	bytes = synthetic_image()
	bytes.encode_s32(PACE_BASE + 36 + 5 * 4, 3278)
	assert_equal(_load(bytes), &"CONNECTOR_PACE_EXCEEDS_CAP", "authored rate exceeds actual species cap")
	bytes = synthetic_image()
	bytes.encode_s32(PACE_BASE + 36 + 5 * 4, 0)
	assert_equal(_load(bytes), &"CONNECTOR_PACE_UNAUTHORED", "no automatic stair pace")


func test_changed_movement_profile_and_replaced_physical_content_refuse_live_queries() -> void:
	"""Accepted timing never outlives its exact mutable Movement revision or immutable body content."""
	assert_equal(_load(synthetic_image()), &"", "fixture")
	var out: IntMath.IntResult = IntMath.IntResult.new(false, 777, "prior")
	assert_true(_movement.revise_profile(0), "actual pace source changed")
	assert_equal(_catalog.pace_into(0, 1, 1, -1, 0, 1, out), &"CONNECTOR_PACE_MOVEMENT_STALE", "fresh source revision")
	assert_equal(out.value, 777, "refused pace unchanged")
	assert_equal(_load_profiles(synthetic_profile_image(_identity, 2), 2), &"", "replace actual physical catalog")
	var record: Catalog.Record = Catalog.Record.new()
	record.family = 99
	assert_equal(_catalog.variant_into(0, 0, 1, record), &"CONNECTOR_CATALOG_CONTENT_STALE", "geometry source pin stale")
	assert_equal(record.family, 99, "record unchanged")


func test_retired_world_and_changed_source_digest_cannot_publish_content() -> void:
	"""Matching numbers from a replaced World or source manifest do not keep old geometry authoritative."""
	var bytes: PackedByteArray = synthetic_image()
	bytes[72] = 8
	assert_equal(_load(bytes), &"CONNECTOR_CATALOG_CONTENT_STALE", "exact profile source hash")
	bytes = synthetic_image()
	bytes[104] = 8
	assert_equal(_load(bytes), &"CONNECTOR_CATALOG_CONTENT_STALE", "exact level source hash")
	assert_equal(_load(synthetic_image()), &"", "valid retry")
	assert_true(_residents.directory().destroy(_world), "retire actual World")
	var record: Catalog.Record = Catalog.Record.new()
	assert_equal(_catalog.variant_into(0, 0, 1, record), &"CONNECTOR_CATALOG_UNBOUND", "dead World generation")
	assert_false(_catalog.binding_matches(_profiles, _levels, _movement, _residents, _transforms, _domain), "binding dead")


func test_material_scale_and_refused_shapes_preserve_caller_scratch() -> void:
	"""World/render adapters can use exact periods without mutable catalog arrays or implicit resizing."""
	assert_equal(_load(synthetic_image()), &"", "fixture")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_equal(_catalog.material_period_into(0, 1, out), &"", "one metre period")
	assert_equal(out.value, 1024, "authored integer texture repeat")
	assert_equal(_catalog.material_period_into(1, 1, out), &"CONNECTOR_MATERIAL_MISSING", "missing material")
	assert_equal(out.value, 1024, "period retained")
	var short: PackedInt32Array = PackedInt32Array([7])
	assert_equal(_catalog.region_into(0, 1, 1, 0, short), &"CONNECTOR_CATALOG_OUTPUT", "region needs eight")
	assert_equal(_catalog.part_into(0, 1, 1, 0, short), &"CONNECTOR_CATALOG_OUTPUT", "part needs nine")
	assert_equal(_catalog.vertex_into(0, 1, 1, 0, short), &"CONNECTOR_CATALOG_OUTPUT", "vertex needs three")
	assert_equal(short, PackedInt32Array([7]), "no implicit resizing or partial output")
