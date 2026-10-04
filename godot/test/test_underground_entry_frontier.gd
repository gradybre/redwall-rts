extends "res://test/framework/test_case.gd"
## Actual immutable source owners; tiny synthetic geometry/profile flags grant no physical entry permission.

const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const GroupFixture := preload("res://test/test_underground_connector_assemblies.gd")
const CatalogFixture := preload("res://test/test_underground_connector_catalog.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const PATH: String = "user://test-entry-frontier.bin"
const REVISION: int = 23
var _fixture: GroupFixture = null
var _reader: Frontier = null
var _caps: PackedInt32Array = PackedInt32Array([2, 1, 1, 1, 2, 1])


func before_each() -> void:
	"""Load real Catalog/Grouping/Recipe/Profile decoders in one actual live World namespace."""
	_fixture = GroupFixture.new()
	_fixture.before_each()
	assert_equal(_fixture._fixture._load_profiles(_work_profiles(), 2), &"", "actual WORK profile source")
	var catalog: PackedByteArray = GroupFixture._catalog_wire(4, 2)
	catalog.encode_s64(48, 2)
	assert_equal(_fixture._load_catalog(catalog, 2), &"", "actual Catalog after profile reload")
	_fixture._bind_source(_fixture._group_wire(), PackedInt32Array([0, 2]))
	assert_equal(_fixture._load_source(), &"", "actual group partition")
	assert_true(_fixture.failures.is_empty(), "fixture setup fully passed")
	_new_reader()


func after_each() -> void:
	"""Drop source readers before their borrowed test owners and delete only this suite's input file."""
	_reader = null
	_fixture.after_each()
	_fixture = null
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _new_reader(capacities: PackedInt32Array = PackedInt32Array()) -> void:
	"""Admit exactly the configured immutable bank and logical reader peak before binding sources."""
	if capacities.is_empty(): capacities = _caps
	_reader = Frontier.new()
	assert_equal(_reader.configure(capacities, Frontier.required_bytes(capacities)), &"", "bounded frontier")
	assert_equal(_reader.bind_actual(_fixture._catalog, _fixture._reader, _fixture._recipes,
		_fixture._fixture._profiles), &"", "same actual sources")


func _work_profiles() -> PackedByteArray:
	"""Insert four explicit synthetic exact-yaw WORK rows between WALK and CLIMB, with complete rotated boxes."""
	var source: PackedByteArray = CatalogFixture.synthetic_profile_image(_fixture._fixture._identity, 2)
	var bytes: PackedByteArray = source.slice(0, 64 + Profiles.PROFILE_WIRE_BYTES)
	bytes.encode_u32(20, 6)
	bytes.encode_u32(24, 34)
	for rotation: int in 4:
		_append_work_row(bytes, rotation)
	var climb: PackedByteArray = source.slice(64 + Profiles.PROFILE_WIRE_BYTES, 64 + 2 * Profiles.PROFILE_WIRE_BYTES)
	climb.encode_s32(Profiles.F_FIRST_BOX * 4, 31)
	bytes.append_array(climb)
	var boxes: int = 64 + 2 * Profiles.PROFILE_WIRE_BYTES
	bytes.append_array(source.slice(boxes, boxes + 3 * 28))
	for rotation: int in 4:
		for role: int in 7:
			var box: PackedInt32Array = _rotate_work_box(_work_box(role), rotation)
			box.append(role)
			CatalogFixture._append_row(bytes, box)
	bytes.append_array(source.slice(boxes + 3 * 28, source.size() - 8))
	bytes.append_array("UGPEND01".to_ascii_buffer())
	return bytes


func _append_work_row(bytes: PackedByteArray, rotation: int) -> void:
	"""Explicit source-qualified rows cover all four Catalog-admitted orientations; no runtime search chooses one."""
	var identity: PackedInt32Array = _fixture._fixture._identity
	CatalogFixture._append_row(bytes, PackedInt32Array([0, identity[0], identity[1], identity[2],
		Profiles.MODE_WORK, 0, -1, -1, -1, -1, Profiles.YAW_EXACT, ((4 - rotation) * 16384) % 65536,
		31, 511, 3 + rotation * 7, 7, Jobs.JOB_KIND_BUILD, Profiles.CONTACT_ANCHOR_AND_PATCH]), 1)
	bytes.resize(bytes.size() + 18)
	bytes[bytes.size() - 2] = Profiles.CERT_REQUIRED


static func _rotate_work_box(source: PackedInt32Array, rotation: int) -> PackedInt32Array:
	"""Exact source quarter turns preserve contact-point/patch dimensions and match RoomConnectors geometry."""
	var result: PackedInt32Array = source.duplicate()
	for step: int in rotation:
		var min_x: int = result[0]; var max_x: int = result[3]
		result[0] = -result[5]; result[3] = -result[2]
		result[2] = min_x; result[5] = max_x
	return result


static func _work_box(role: int) -> PackedInt32Array:
	"""Source qualification is synthetic; complete positive body/support/stroke and planar patch semantics are real."""
	match role:
		Profiles.STANCE_SUPPORT: return PackedInt32Array([-128, -1, -128, 128, 0, 128])
		Profiles.WORK_STROKE: return PackedInt32Array([-16, 500, -800, 16, 600, -128])
		Profiles.CONTACT_POINT: return PackedInt32Array([0, 550, -768, 0, 550, -768])
		Profiles.CONTACT_PATCH: return PackedInt32Array([-1, 549, -768, 1, 551, -768])
	return PackedInt32Array([-128, 0, -128, 128, 900, 128])


func _wire() -> PackedByteArray:
	"""Independent row-major wire describes two groups sharing an existing natural work/storage approach."""
	var bytes: PackedByteArray = "UGFRNT01".to_ascii_buffer()
	bytes.resize(Frontier.WIRE_HEADER_BYTES)
	bytes.encode_u32(8, 1)
	var revisions: PackedInt64Array = PackedInt64Array([REVISION, 2, 1,
		GroupFixture.GROUP_REVISION, GroupFixture.RECIPE_REVISION, 2])
	for index: int in revisions.size():
		bytes.encode_s64(12 + index * 8, revisions[index])
	for table: int in Frontier.TABLE_COUNT:
		bytes.encode_u32(68 + table * 4, _caps[table])
	_write_source_digests(bytes)
	for ordinal: int in 2:
		CatalogFixture._append_row(bytes, PackedInt32Array([ordinal, 0, 0, 0, 1, 0, 1, 1, 0]))
	CatalogFixture._append_row(bytes, PackedInt32Array([0, 0, 0, 0, 0, 1, 0, 4, Jobs.JOB_KIND_BUILD]), 1)
	for rotation: int in range(1, 4):
		CatalogFixture._append_row(bytes, PackedInt32Array([rotation + 1]), 1)
	CatalogFixture._append_row(bytes, PackedInt32Array([0, -1024, -1024, 1024, 0, 0, Sites.SUPPORTED_VOID]))
	CatalogFixture._append_row(bytes, PackedInt32Array([Frontier.NATURAL, -1, -1, 0, -1024, -1024, 1024, 0, 0]))
	CatalogFixture._append_row(bytes, PackedInt32Array([Frontier.SURFACE_ANCHOR, -1, 0, 2, 0, 0, 0, 0]), 1)
	CatalogFixture._append_row(bytes, PackedInt32Array([Frontier.SURFACE_CONTACT, -1, 0, 1, 512, 0, 0, 0]), 1)
	CatalogFixture._append_row(bytes, PackedInt32Array([0, -1024, -1024, 1024, 0, 0, 7, 0,
		0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 4]))
	bytes.append_array("UGFEND01".to_ascii_buffer())
	return bytes


func _write_source_digests(bytes: PackedByteArray) -> void:
	"""Wire pins actual successfully loaded source digests, not their filenames or a caller boolean."""
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(32)
	assert_true(_fixture._catalog.content_hash_into(2, digest), "Catalog pin")
	var values: Array[PackedByteArray] = [digest, _fixture._group_hash.hex_decode(),
		_fixture._recipe_hash.hex_decode(), PackedByteArray()]
	values[3].resize(32)
	assert_true(_fixture._fixture._profiles.source_hash_into(0, 2, values[3]), "actual program source")
	for source: int in 4:
		for index: int in 32:
			bytes[92 + source * 32 + index] = values[source][index]


static func _write(bytes: PackedByteArray) -> String:
	"""Use the valid digest even for deliberately malformed source; schema refusal must do the work."""
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var digest_value: HashingContext = HashingContext.new()
	digest_value.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): digest_value.update(bytes)
	return digest_value.finish().hex_encode()


func _load(bytes: PackedByteArray) -> StringName:
	"""Invoke only the public streamed immutable loader with exact source identity."""
	return _reader.load_file(PATH, _write(bytes), REVISION)


static func _base(table: int) -> int:
	"""Independent fixture layout offsets, including the separate int64 station revision."""
	const STARTS: PackedInt32Array = [220, 292, 372, 400, 436, 516]
	return STARTS[table]


func test_exact_tables_fill_caller_outputs_without_publishing_physical_permission() -> void:
	"""Every public reader returns its fixed metadata and actual revisions; caller edits do not alter source."""
	var source: PackedByteArray = _wire()
	var digest: String = _write(source)
	assert_equal(_reader.load_file(PATH, digest, REVISION), &"", "load exact source")
	assert_equal(_reader.content_revision(), REVISION, "positive immutable revision")
	assert_true(_reader.binding_matches(_fixture._catalog, _fixture._reader, _fixture._recipes,
		_fixture._fixture._profiles), "exact sources")
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(9)
	assert_equal(_reader.installation_into(1, out), &"", "second group")
	assert_equal(out, PackedInt32Array([1, 0, 0, 0, 1, 0, 1, 1, 0]), "one immutable installation row")
	out[0] = 999
	assert_equal(_reader.installation_into(1, out), &"", "no alias to source")
	assert_equal(out[0], 1, "source unchanged")
	var revision: IntMath.IntResult = IntMath.IntResult.new()
	assert_equal(_reader.station_into(0, out, revision), &"", "station")
	assert_equal(revision.value, 1, "full profile revision")
	assert_equal(_reader.bearing_into(0, out), &"", "bearing target")
	out.resize(7)
	assert_equal(_reader.cut_into(0, out), &"", "exact physical dependency")
	assert_equal(out[6], Sites.SUPPORTED_VOID, "exact stable phase")
	assert_equal(_reader.endpoint_into(1, out), &"", "separate actual-surface storage selector")
	out.resize(19)
	assert_equal(_reader.episode_into(0, out), &"", "all paid phases remain explicit")
	_check_source_identity(digest)


func _check_source_identity(digest: String) -> void:
	"""Every table count and self digest name the immutable accepted source exactly."""
	for table: int in Frontier.TABLE_COUNT:
		assert_equal(_reader.row_count(table, REVISION), _caps[table], "exact census")
	var digest_value: PackedByteArray = PackedByteArray(); digest_value.resize(32)
	assert_true(_reader.content_hash_into(REVISION, digest_value), "source identity")
	assert_equal(digest_value.hex_encode(), digest, "digest_value of decoded bytes")


func test_capacity_is_admitted_before_allocation_and_cannot_grow() -> void:
	"""The source's explicit subreserve includes all tables and fixed readers; no maximum is silently allocated."""
	var empty: Frontier = Frontier.new()
	assert_equal(empty.configure(_caps, Frontier.required_bytes(_caps) - 1), Frontier.REFUSE_CAPACITY, "underfunded")
	assert_equal(empty.packed_memory_bytes(), 0, "no allocated payload on refusal")
	assert_equal(Frontier.required_bytes(PackedInt32Array([2, 2048, 2048, 2048, 2048, 2048])), 0, "whole envelope bounded")
	assert_equal(Frontier.required_bytes(PackedInt32Array([2, 1, 1, 1, -1, 1])), 0, "negative capacity")
	assert_equal(Frontier.required_bytes(PackedInt32Array([2, 1])), 0, "complete table census")
	assert_equal(_reader.packed_memory_bytes(), 668, "allocated field-major payload, not reservation")
	assert_equal(_reader.configure(_caps, Frontier.required_bytes(_caps)), Frontier.REFUSE_CAPACITY, "once configured")


func test_wrong_sha_truncated_extra_and_empty_sources_refuse_without_live_rows() -> void:
	"""A failed first load is retryable with clean unpublished storage; a good load is immutable."""
	var bytes: PackedByteArray = _wire()
	_write(bytes)
	assert_equal(_reader.load_file(PATH, "0".repeat(64), REVISION), Frontier.REFUSE_SOURCE, "wrong digest")
	for bad: PackedByteArray in [PackedByteArray(), bytes.slice(0, 100), bytes.slice(0, bytes.size() - 1), bytes + PackedByteArray([0])]:
		assert_equal(_load(bad), Frontier.REFUSE_FORMAT, "exact byte census")
		assert_equal(_reader.content_revision(), 0, "nothing published")
	assert_equal(_load(bytes), &"", "valid retry")
	assert_equal(_load(bytes), Frontier.REFUSE_SOURCE, "source cannot be replaced")


func test_source_revisions_counts_and_digests_are_exact() -> void:
	"""Even a correctly hashed input must match actual source counts and every independent source pin."""
	for offset: int in [20, 28, 36, 44, 52, 60, 64, 92, 124, 156, 188]:
		var bytes: PackedByteArray = _wire()
		bytes[offset] += 1
		assert_equal(_load(bytes), Frontier.REFUSE_SOURCE, "source tuple field" + str(offset))
		assert_equal(_reader.content_revision(), 0, "no partial source")
	var grown: PackedByteArray = _wire()
	grown.encode_u32(72, 2)
	assert_equal(_load(grown), Frontier.REFUSE_CAPACITY, "count above admitted station capacity")


func test_installation_ordinals_ranges_and_full_group_partition_are_required() -> void:
	"""A wrong grouping ordinal or range cannot alias another billable assembly or spare table capacity."""
	for edit: Vector2i in [Vector2i(0, 1), Vector2i(4, 1), Vector2i(8, -1), Vector2i(12, 1),
		Vector2i(16, 0), Vector2i(20, 1), Vector2i(24, 0), Vector2i(28, 2), Vector2i(32, -1)]:
		var bytes: PackedByteArray = _wire()
		bytes.encode_s32(_base(Frontier.INSTALL) + edit.x, edit.y)
		assert_equal(_load(bytes), Frontier.REFUSE_REFERENCE, "bad installation selector")


func test_pending_assembly_cannot_supply_its_own_floor_or_bearing() -> void:
	"""Prior-only source constraints reject future support before any runtime phase/contact observation."""
	var endpoint: PackedByteArray = _wire()
	endpoint.encode_s32(_base(Frontier.ENDPOINT), Frontier.INSTALLED_CONTACT)
	endpoint.encode_s32(_base(Frontier.ENDPOINT) + 4, 0)
	assert_equal(_load(endpoint), Frontier.REFUSE_FUTURE, "L0 cannot stand on itself")
	var bearing: PackedByteArray = _wire()
	bearing.encode_s32(_base(Frontier.BEARING), Frontier.INSTALLED_PART)
	bearing.encode_s32(_base(Frontier.BEARING) + 4, 0)
	bearing.encode_s32(_base(Frontier.BEARING) + 8, 0)
	assert_equal(_load(bearing), Frontier.REFUSE_FUTURE, "L0 cannot bear itself")


func test_cuts_use_whole_datum_cubes_and_exact_stable_phase_tags() -> void:
	"""A half-cube or transient phase does not acquire an installed-space prerequisite."""
	for edit: Vector2i in [Vector2i(0, 1), Vector2i(12, 0), Vector2i(24, Sites.CUTTING), Vector2i(24, 99)]:
		var bytes: PackedByteArray = _wire()
		bytes.encode_s32(_base(Frontier.CUT) + edit.x, edit.y)
		assert_equal(_load(bytes), Frontier.REFUSE_FORMAT, "whole stable dependency")


func test_station_requires_actual_source_work_patch_posture_and_revision() -> void:
	"""A transit profile or coincident profile number never becomes the authored working contact."""
	for edit: Vector2i in [Vector2i(16, 1), Vector2i(20, 0), Vector2i(24, 1), Vector2i(32, Jobs.JOB_KIND_HAUL)]:
		var bytes: PackedByteArray = _wire()
		bytes.encode_s32(_base(Frontier.STATION) + edit.x, edit.y)
		assert_equal(_load(bytes), Frontier.REFUSE_PROFILE, "wrong actual work selection")
	var revision: PackedByteArray = _wire()
	revision.encode_s64(_base(Frontier.STATION) + 36, 2)
	assert_equal(_load(revision), Frontier.REFUSE_PROFILE, "exact full revision")
	var root: PackedByteArray = _wire(); root.encode_s32(_base(Frontier.STATION) + 4, 1)
	assert_equal(_load(root), Frontier.REFUSE_REFERENCE, "root is actual endpoint selector point")


func test_episode_masks_stations_and_ranges_do_not_invent_paid_phases() -> void:
	"""Every enabled operation has an authored station; no unauthored future contact is inferred."""
	for edit: Vector2i in [Vector2i(24, 0), Vector2i(24, 8), Vector2i(28, 3), Vector2i(72, 6)]:
		var bytes: PackedByteArray = _wire(); bytes.encode_s32(_base(Frontier.EPISODE) + edit.x, edit.y)
		assert_equal(_load(bytes), Frontier.REFUSE_FORMAT, "invalid operation domain")
	for edit: Vector2i in [Vector2i(32, -1), Vector2i(44, 1), Vector2i(56, 0), Vector2i(60, 2)]:
		var bytes: PackedByteArray = _wire(); bytes.encode_s32(_base(Frontier.EPISODE) + edit.x, edit.y)
		assert_equal(_load(bytes), Frontier.REFUSE_REFERENCE, "incomplete authored phase selectors")


func test_duplicate_cube_operation_refuses_even_when_ranges_are_grouped_differently() -> void:
	"""Two ranges cannot silently nominate the same paid physical phase twice."""
	var capacity: PackedInt32Array = _caps.duplicate(); capacity[Frontier.EPISODE] = 2
	_new_reader(capacity)
	var bytes: PackedByteArray = _wire()
	bytes.encode_u32(68 + Frontier.EPISODE * 4, 2)
	var second: PackedByteArray = bytes.slice(_base(Frontier.EPISODE), bytes.size() - 8)
	second.encode_s32(0, -1024)
	bytes.resize(bytes.size() - 8); bytes.append_array(second); bytes.append_array("UGFEND01".to_ascii_buffer())
	assert_equal(_load(bytes), Frontier.REFUSE_DUPLICATE, "overlapping operation union")
	second.encode_s32(0, -2048); second.encode_s32(12, -1024)
	bytes.resize(_base(Frontier.EPISODE) + 76); bytes.append_array(second); bytes.append_array("UGFEND01".to_ascii_buffer())
	assert_equal(_load(bytes), &"", "disjoint whole-cube ranges")


func test_actual_profile_reload_rejects_existing_frontier() -> void:
	"""Loaded source identity cannot survive actual monotonic source replacement or World generation reuse."""
	assert_equal(_load(_wire()), &"", "loaded source")
	var out: PackedInt32Array = PackedInt32Array(); out.resize(9); out.fill(123)
	var bytes: PackedByteArray = _work_profiles(); bytes.encode_s64(12, 3)
	assert_equal(_fixture._fixture._load_profiles(bytes, 3), &"", "actual later profile content")
	assert_equal(_reader.installation_into(0, out), Frontier.REFUSE_SOURCE, "old source refuses")
	assert_equal(out, PackedInt32Array([123, 123, 123, 123, 123, 123, 123, 123, 123]), "refused output unchanged")


func test_actual_world_generation_reuse_rejects_existing_frontier() -> void:
	"""World reuse alone invalidates immutable wiring without a preceding profile reload refusal."""
	assert_equal(_load(_wire()), &"", "loaded source")
	assert_equal(Frontier.source_leaf_refusal(_reader), &"", "live original World")
	var ids: Directory = _fixture._fixture._residents.directory()
	assert_true(ids.destroy(_fixture._fixture._world), "destroy actual World")
	var replacement: Vector2i = ids.create(Directory.KIND_WORLD)
	assert_true(replacement != _fixture._fixture._world, "new full World generation")
	assert_equal(Frontier.source_leaf_refusal(_reader), Frontier.REFUSE_SOURCE, "stale full World")


func test_refused_queries_preserve_all_caller_outputs() -> void:
	"""Bad row/shape/revision/binding never clears a caller's retained valid observation."""
	assert_equal(_load(_wire()), &"", "loaded source")
	var out: PackedInt32Array = PackedInt32Array([41, 42, 43])
	var revision: IntMath.IntResult = IntMath.IntResult.new(); revision.value = 81
	assert_equal(_reader.station_into(0, out, revision), Frontier.REFUSE_OUTPUT, "wrong output size")
	assert_equal(out, PackedInt32Array([41, 42, 43]), "unchanged row")
	assert_equal(revision.value, 81, "unchanged paired revision")
	out.resize(9); out.fill(52)
	assert_equal(_reader.station_into(-1, out, revision), Frontier.REFUSE_OUTPUT, "invalid row")
	assert_equal(out[0], 52, "still unchanged")
	assert_equal(_reader.row_count(0, REVISION + 1), 0, "wrong source revision")
	assert_equal(_reader.row_count(-1, REVISION), 0, "wrong table")
	var digest_value: PackedByteArray = PackedByteArray([1, 2, 3])
	assert_false(_reader.content_hash_into(REVISION, digest_value), "wrong digest_value output")
	assert_equal(digest_value, PackedByteArray([1, 2, 3]), "digest_value preserved")
	assert_false(_reader.binding_matches(null, _fixture._reader, _fixture._recipes, _fixture._fixture._profiles), "foreign source")


func test_endpoint_travel_is_explicit_and_refusal_preserves_paired_outputs() -> void:
	"""No WORK, absent or wrong-generation travel profile is inferred into a route permission."""
	for invalid: int in [-1, 1, 6]:
		var bytes: PackedByteArray = _wire(); bytes.encode_s32(_base(Frontier.ENDPOINT) + 28, invalid)
		assert_equal(_load(bytes), Frontier.REFUSE_PROFILE, "non-transit selector")
	var stale: PackedByteArray = _wire(); stale.encode_s64(_base(Frontier.ENDPOINT) + 32, 2)
	assert_equal(_load(stale), Frontier.REFUSE_PROFILE, "exact transit revision")
	assert_equal(_load(_wire()), &"", "explicit actual WALK source")
	var profile: IntMath.IntResult = IntMath.IntResult.new(); profile.value = 71
	var revision: IntMath.IntResult = IntMath.IntResult.new(); revision.value = 72
	assert_equal(_reader.endpoint_travel_into(-1, profile, revision), Frontier.REFUSE_OUTPUT, "invalid row")
	assert_equal(profile.value, 71, "refused profile unchanged")
	assert_equal(revision.value, 72, "refused revision unchanged")
	assert_equal(_reader.endpoint_travel_into(0, profile, profile), Frontier.REFUSE_OUTPUT, "no output alias")
	assert_equal(profile.value, 71, "aliased output unchanged")
	assert_equal(_reader.endpoint_travel_into(0, profile, revision), &"", "explicit pair")
	assert_equal(profile.value, 0, "WALK selector")
	assert_equal(revision.value, 1, "exact profile revision")


func test_each_allowed_rotation_selects_its_exact_source_profile_without_rotating_output_coordinates() -> void:
	"""Quarter-turn1 means +X geometry but yaw49152 under the existing underground heading convention."""
	assert_equal(_load(_wire()), &"", "four exact source-qualified WORK rows")
	var out: PackedInt32Array = PackedInt32Array(); out.resize(9)
	var revision: IntMath.IntResult = IntMath.IntResult.new()
	for rotation: int in 4:
		assert_equal(_reader.station_into(0, out, revision, rotation), &"", "explicit rotation")
		assert_equal(out[4], 0, "yaw stays local; owner transforms it")
		assert_equal(out[5], rotation + 1, "exact rotated profile, no inferred selector")
		assert_equal(revision.value, 1, "full selected revision")
		assert_equal(_fixture._fixture._profiles._live.fields[Profiles.F_YAW * 8 + out[5]],
			PackedInt32Array([0, 49152, 32768, 16384])[rotation], "actual world cardinal heading")
	out.fill(81); revision.value = 82
	assert_equal(_reader.station_into(0, out, revision, 4), Frontier.REFUSE_OUTPUT, "invalid rotation")
	assert_equal(out[5], 81, "refused caller row unchanged")
	assert_equal(revision.value, 82, "refused revision unchanged")


func test_rotated_work_source_cannot_be_missing_wrong_yaw_or_stale() -> void:
	"""All Catalog-admitted orientations require their own exact profile and revision before source activation."""
	for profile: int in [-1, 0, 1, 5, 6]:
		var bytes: PackedByteArray = _wire()
		bytes.encode_s32(_base(Frontier.STATION) + 44, profile)
		assert_equal(_load(bytes), Frontier.REFUSE_PROFILE, "no missing or wrong-yaw quarter-turn")
	var stale: PackedByteArray = _wire(); stale.encode_s64(_base(Frontier.STATION) + 48, 2)
	assert_equal(_load(stale), Frontier.REFUSE_PROFILE, "exact rotated revision")


func _with_installed_endpoint(datum: int, x: int = 0, y: int = 0) -> PackedByteArray:
	"""The second installation may depend on a prior assembly's explicitly authored landing floor."""
	var bytes: PackedByteArray = _wire()
	bytes.encode_u32(68 + Frontier.ENDPOINT * 4, 3)
	bytes.encode_s32(_base(Frontier.INSTALL) + 36 + 28, 2)
	var episode: PackedByteArray = bytes.slice(_base(Frontier.EPISODE))
	bytes.resize(_base(Frontier.EPISODE))
	CatalogFixture._append_row(bytes, PackedInt32Array([Frontier.INSTALLED_CONTACT, 0, datum, 1, x, y, 0, 0]), 1)
	bytes.append_array(episode)
	return bytes


func test_installed_endpoint_names_actual_catalog_landing_floor_with_exact_half_open_point() -> void:
	"""An arbitrary positive datum cannot masquerade as a published installed FLOOR_DATUM."""
	var capacity: PackedInt32Array = _caps.duplicate(); capacity[Frontier.ENDPOINT] = 3
	_new_reader(capacity)
	for datum: int in [-1, 0, 3, 6]:
		assert_equal(_load(_with_installed_endpoint(datum)), Frontier.REFUSE_REFERENCE, "not actual variant LANDING")
	assert_equal(_load(_with_installed_endpoint(1, 512)), Frontier.REFUSE_REFERENCE, "outside half-open landing X")
	assert_equal(_load(_with_installed_endpoint(1, 0, 1)), Frontier.REFUSE_REFERENCE, "above actual authored floor")
	assert_equal(_load(_with_installed_endpoint(1)), &"", "prior exact authored landing floor")
