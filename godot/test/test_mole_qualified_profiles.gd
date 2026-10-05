extends "res://test/framework/test_case.gd"
## Actual source artifact + real Resident/Job/Work/Gear identity. No World, paid target, support or WIP is fabricated.

const Catalog := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-step-v4/catalog_source.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Fixture := preload("res://test/test_underground_profiles.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Space := preload("res://scripts/core/room_space.gd")
# The immutable consumer contract must already be in the host's actual script cache.
const WorkFace := preload("res://scripts/core/underground_work_face.gd")
const Contacts := preload("res://scripts/core/underground_connector_contacts.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Driver := preload("res://data/underground/mole-worker/mole_profile_driver.gd")
const Step := preload("res://data/underground/mole-worker/work-step-v1/source_program.gd")
const ACTOR_PATH: String = "res://data/underground/mole-worker/evidence/contact-qualification/install-program-compile-v3/result/mole-worker.ugactor"
const PRESENTATION_RESERVE: int = 7141920
const NULL_REF: Vector2i = Vector2i(-1, 0)
var _fixture: Fixture = null
var _content: Content = null
var _domain: Space.Domain = null
var _tool: Vector2i = NULL_REF
var _job: Vector2i = NULL_REF


func before_each() -> void:
	"""Actual owner keys/claims plus the same source image used by the independently reviewed native proof."""
	_fixture = Fixture.new()
	_fixture.before_each()
	_fixture._slot = _fixture._residents.spawn(&"mole").value
	_fixture._worker = _fixture._residents.ref_of(_fixture._slot)
	assert_true(_fixture._residents.spatial_profile_identity_into(_fixture._worker, _fixture._identity), "actual mole rig")
	assert_true(_fixture._transforms.place(_fixture._worker, 4096, 512, 4096, 0), "actual integer source root")
	_tool = _fixture._equip()
	_job = _fixture._actual_work_job().ref
	assert_true(_fixture._work.claim_tool_for_work(_fixture._slot, _tool).ok, "actual BASIC tool claim")
	_content = Content.new()
	assert_equal(_content.load_file(ACTOR_PATH, Pins.ACTOR_SHA, PRESENTATION_RESERVE), &"", "same-file source image")
	_domain = _make_domain(Vector3i(0, 512, 0))
	_fixture._profiles = _empty_catalog()
	assert_equal(_fixture._bind(_fixture._profiles), &"", "actual same-owner profile identity")
	assert_equal(Catalog.load_into(_fixture._profiles, _content, _domain), &"", "qualified source geometry only")
	assert_true(_fixture.failures.is_empty(), "actual fixture assertions propagated")


func after_each() -> void:
	"""Release only owned source/fixture scratch; no production owner is cleared by the content component."""
	_content = null
	_domain = null
	if _fixture != null:
		assert_true(_fixture.failures.is_empty(), "fixture failure propagation")
		_fixture.after_each()
	_fixture = null


func _empty_catalog() -> Profiles:
	"""Exactly two minimal banks; the stated native/control reservation is not a measured allocation result."""
	var profiles: Profiles = Profiles.new()
	assert_equal(profiles.configure(29, 271, 1, Catalog.PAIRED_BANK_BYTES + Catalog.CONTROL_RESERVE), &"", "complete peak admission")
	assert_equal(profiles.packed_memory_bytes(), 20988, "paired source-derived payload")
	return profiles


func _make_domain(datum: Vector3i) -> Space.Domain:
	"""Only domain identity/extents are supplied; this creates no supported underground space."""
	var result: Space.Domain = Space.Domain.new()
	assert_equal(result.configure(Vector2i(0, 1), datum, Vector3i(0, -32, 0), Vector3i(256, 48, 256),
		8192, 6144, Space.MAX_CHECKS), &"", "finite initial world")
	return result


func test_actual_source_rows_and_headings_keep_every_contact_distinct() -> void:
	"""Four real-source contacts at each of four headings still require an actual claimed BUILD Job."""
	var out: Profiles.Selection = Profiles.Selection.new()
	for heading: int in 4:
		var yaw: int = heading * 16384
		assert_true(_fixture._transforms.place(_fixture._worker, 4096, 512, 4096, yaw), "actual heading")
		for role: int in range(2, 6):
			var profile: int = Catalog.profile_id(role, yaw)
			assert_equal(_fixture._profiles.query_work_profile_into(_fixture._worker, _job, profile, 1, 3,
				0, -1, _tool, out), &"", "exact qualified source contact")
			assert_equal(out.profile_id, profile, "no first-match contact substitution")
			assert_equal(out.yaw, yaw, "no cardinal rounding")
			assert_equal(out.tool, _tool, "actual equipped/claimed BASIC source")
			assert_equal(out.job, _job, "actual assigned job")
	assert_equal(_fixture._profiles.query_into(_fixture._worker, _job, Profiles.MODE_WORK, 0, -1, _tool, out),
		&"PROFILE_VARIANT_UNAUTHORED", "source-clock WORK requires an explicit authored contact")


func test_all_yaw_ground_profile_preserves_full_tool_and_ground_stance() -> void:
	"""The complete ground union is available at intermediate angles, never a512u tread clearance claim."""
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_true(_fixture._transforms.place(_fixture._worker, 4096, 512, 4096, 12345), "noncardinal ground pose")
	assert_equal(_fixture._profiles.query_into(_fixture._worker, NULL_REF, Profiles.MODE_WALK, 0, -1, _tool, out), &"", "all native headings")
	assert_equal(out.profile_id, 1, "unique exact ground source")
	assert_equal(out.yaw, 12345, "actual yaw retained")
	var support: Profiles.Box = Profiles.Box.new()
	assert_equal(_fixture._profiles.box_into(1, 1, 3, 3, support), &"", "full stance row")
	assert_equal(support.role, Profiles.STANCE_SUPPORT, "source support role")
	assert_equal(support.high.x - support.low.x, 812, "wider than a512u tread")
	assert_equal(support.high.z - support.low.z, 812, "no implicit varying-height foot proof")
	assert_equal(Catalog.profile_id(2, 12345), -1, "intermediate productive yaw unauthored")
	assert_equal(_fixture._profiles.query_work_profile_into(_fixture._worker, _job, 13, 1, 3, 0, -1, _tool, out),
		&"PROFILE_VARIANT_UNAUTHORED", "real pose cannot borrow cardinal contact")


func test_directed_approach_mapping_preserves_body_heading_and_explicit_policy() -> void:
	"""Forward and backward share a body heading but remain distinct complete travel sources."""
	var selected: Profiles.Selection = Profiles.Selection.new()
	for heading: int in 4:
		var yaw: int = heading * 16384
		assert_true(_fixture._transforms.place(_fixture._worker, 4096, 512, 4096, yaw), "actual cardinal body heading")
		for backward: bool in [false, true]:
			var profile: int = Catalog.approach_profile_id(yaw, backward)
			assert_equal(profile, (6 if backward else 2) + heading, "explicit direction has its own row")
			assert_equal(_fixture._profiles.query_travel_profile_into(_fixture._worker, _job,
				profile, 1, 3, 0, -1, _tool, selected), &"", "actual actor/tool/Job selection")
			assert_equal(selected.yaw, yaw, "backward path does not reverse body heading")
			assert_equal(_fixture._profiles.selection_policy_of(profile, 1, 3), 2 if backward else 1, "versioned policy")
	for yaw: int in [-1, 1, 12345, 65536]:
		assert_equal(Catalog.approach_profile_id(yaw), -1, "no implicit heading rounding")
		assert_equal(Catalog.approach_profile_id(yaw, true), -1, "invalid backward heading refuses")


func test_canonical_ground_and_finite_step_are_explicit_current_source_selections() -> void:
	"""The published finite step is an exact selected policy, never a replacement for ordinary WALK."""
	var selected: Profiles.Selection = Profiles.Selection.new()
	assert_equal(Catalog.canonical_ground_profile_id(), 12, "canonical all-yaw source identity")
	assert_true(_fixture._transforms.place(_fixture._worker, 4096, 512, 4096, 49152), "authored positive-X heading")
	for profile: int in [Catalog.short_step_profile_id(49152), Catalog.short_step_profile_id(49152, true),
			Catalog.canonical_ground_profile_id()]:
		assert_equal(_fixture._profiles.query_travel_profile_into(_fixture._worker, _job,
			profile, 1, 3, 0, -1, _tool, selected), &"", "real current tool/cargo/Job selection")
		assert_equal(Step.profile_refusal(_fixture._profiles, profile, 1, 3), &"", "actual immutable protocol-six descriptor")
		assert_equal(selected.yaw, 49152, "backward path leaves body orientation unchanged")
	assert_equal(_fixture._profiles.query_into(_fixture._worker, NULL_REF, Profiles.MODE_WALK, 0, -1, _tool, selected),
		&"", "ordinary policy remains available explicitly")
	assert_equal(selected.profile_id, 1, "no silent canonical enrollment")
	for yaw: int in [-1, 0, 16384, 32768, 49151, 65536]:
		assert_equal(Catalog.short_step_profile_id(yaw), -1, "no rotated short-step source was authored")
		assert_equal(Catalog.short_step_profile_id(yaw, true), -1, "same restriction for the reverse source")
	assert_equal(Step.profile_refusal(_fixture._profiles, 10, 1, 2), &"ROUTE_SOURCE_PROFILE", "old content tuple refuses")
	assert_equal(Catalog.profile_id(4, 49152), 27, "FRONT moves with the complete work block")
	assert_equal(Catalog.profile_id(3, 49152), 26, "HIGH cannot alias the finite step row")


func test_tenth_cached_source_and_old_publication_remain_distinct() -> void:
	"""Current geometry cannot borrow a legacy full hash or an unobserved canonical source program."""
	assert_equal(Pins.PATHS.size(), 10, "complete current source closure")
	var script: Script = Step
	assert_equal(Pins.PATHS[9], script.resource_path, "exact tenth actual Script")
	var original: String = script.source_code
	script.source_code = original + "\n# negative cached canonical source drift\n"
	var code: StringName = Catalog.runtime_sources_refusal()
	script.source_code = original
	assert_equal(code, &"MOLE_CATALOG_SOURCE_DRIFT", "cached new clock must match independently")
	assert_equal(Catalog.runtime_sources_refusal(), &"", "original source restored")
	var old: Profiles = _empty_catalog()
	assert_equal(old.load_file("res://data/underground/mole-worker/profile-publication-v3-frontier/mole-worker.ugprof",
		"a581f90aa0db07187a1dfc1f0836bd7f3de39d401ff944db07a3958649b1c204", 2), &"", "unchanged historical source still readable")
	assert_equal(Catalog.catalog_refusal(old), &"MOLE_CATALOG_OWNER", "historical rows cannot claim current production identity")


func test_stale_claim_or_job_preserves_previous_selected_source() -> void:
	"""Source geometry does not restore a released economic claim or an old assignment."""
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_equal(_fixture._profiles.query_work_profile_into(_fixture._worker, _job, 13, 1, 3, 0, -1, _tool, out), &"", "real source selected")
	assert_true(_fixture._work.release_tool_claim(_fixture._slot).ok, "actual claim release")
	assert_equal(_fixture._profiles.query_work_profile_into(_fixture._worker, _job, 16, 1, 3, 0, -1, _tool, out),
		&"PROFILE_TOOL_CLAIM", "no source flag recreates ownership")
	assert_equal(out.profile_id, 13, "refused source output unchanged")
	assert_true(_fixture._work.claim_tool_for_work(_fixture._slot, _tool).ok, "actual claim reacquired")
	assert_true(_fixture._jobs.release_worker(_fixture._slot).ok, "actual assignment removed")
	assert_equal(_fixture._profiles.query_work_profile_into(_fixture._worker, _job, 16, 1, 3, 0, -1, _tool, out),
		&"PROFILE_JOB_STALE", "source is not labor permission")
	assert_equal(out.profile_id, 13, "prior exact source remains intact")


func test_wrong_domain_content_and_renderer_refuse_before_profile_publication() -> void:
	"""A successful source reader cannot migrate its numerical proof or impersonate an active backend."""
	var empty: Profiles = _empty_catalog()
	assert_equal(Catalog.load_into(empty, _content, _make_domain(Vector3i(0, 513, 0))), &"MOLE_CATALOG_DOMAIN", "one-unit datum drift")
	assert_equal(empty.content_revision(), 0, "no candidate rows published")
	assert_equal(Catalog.load_into(empty, Content.new(), _domain), &"MOLE_CATALOG_CONTENT", "absent source")
	assert_equal(empty.content_revision(), 0, "failed source still unpublished")
	assert_equal(Catalog.presentation_refusal(_content, null, _domain), &"MOLE_CATALOG_RENDERER", "no fake headless renderer")
	assert_equal(Catalog.load_into(_fixture._profiles, _content, _domain), &"MOLE_CATALOG_OWNER", "immutable initial publication only")


func test_cold_descriptor_does_not_create_actual_worker_permission() -> void:
	"""A prospective work face may read source geometry before any Job, without inventing authority."""
	var cold: Profiles = _empty_catalog()
	assert_equal(Catalog.load_into(cold, _content, _domain), &"", "unbound immutable source")
	var descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
	assert_equal(cold.descriptor_into(16, 3, descriptor), &"", "authored INSTALL source")
	assert_equal(descriptor.contact_kind, Profiles.CONTACT_ANCHOR_AND_PATCH, "actual source patch")
	assert_equal(descriptor.certificate_flags, 15, "four reviewed source gates")
	assert_equal(cold.query_work_profile_into(_fixture._worker, _job, 16, 1, 3, 0, -1, _tool, Profiles.Selection.new()),
		&"PROFILE_OWNER_UNBOUND", "no allocated World support or worker binding")


func test_exact_wire_identity_cannot_be_replaced_by_same_actor_revision_with_larger_box() -> void:
	"""A structurally valid synthetic alteration is refused by the source catalog's complete live wire hash."""
	var pins: PackedInt64Array = PackedInt64Array()
	pins.resize(87)
	assert_equal(Catalog.pins_into(_fixture._profiles, pins), &"", "all exact authored tuples")
	var before: PackedInt64Array = pins.duplicate()
	var changed: Profiles = _changed_geometry()
	assert_equal(Catalog.pins_into(changed, pins), &"MOLE_CATALOG_GEOMETRY_DRIFT", "equal source/revision is not equal geometry")
	assert_equal(pins, before, "refused output fully unchanged")
	assert_equal(Catalog.pins_into(_fixture._profiles, PackedInt64Array([55])), &"MOLE_CATALOG_PINS_SIZE", "exact caller scratch")


func _changed_geometry() -> Profiles:
	"""Only this negative fixture mutates source bytes; the real artifact and its digest remain untouched."""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(Catalog.WIRE_PATH)
	var first_box: int = 32 + 32 + 29 * 98
	bytes.encode_s32(first_box + 12, bytes.decode_s32(first_box + 12) + 1)
	var path: String = "user://mole-qualified-mutant-%d.bin" % get_instance_id()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var changed: Profiles = _empty_catalog()
	assert_equal(changed.load_file(path, FileAccess.get_sha256(path), 3), &"", "explicit negative-fixture certificate")
	assert_equal(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "owned fixture deleted")
	return changed


func test_actual_cached_source_hashes_and_bounded_unicode_chunks() -> void:
	"""The loader checks already loaded code and refuses missing/changed source, including stripped exports."""
	assert_equal(Catalog.runtime_sources_refusal(), &"", "all ten actual cached sources")
	var source: String = "é🦡一".repeat(1500)
	assert_equal(Catalog._source_refusal(source, source.sha256_text()), &"", "UTF-8 chunk boundaries preserve exact text")
	assert_equal(Catalog._source_refusal(source, "0".repeat(64)), &"MOLE_CATALOG_SOURCE_DRIFT", "changed executed source refuses")
	assert_equal(Catalog._source_refusal("", "0".repeat(64)), &"MOLE_CATALOG_SOURCE_CAPACITY", "stripped source refuses")
	assert_equal(Catalog._source_refusal("x".repeat(Catalog.SOURCE_CHARS + 1), "0".repeat(64)), &"MOLE_CATALOG_SOURCE_CAPACITY", "finite source work")


func test_driver_uses_the_published_source_tuple_without_work_credit() -> void:
	"""Real driver observes actual owners and the qualified artifact; ready/pose change does not pay or credit Work."""
	var pins: PackedInt64Array = PackedInt64Array()
	pins.resize(54)
	assert_equal(Catalog.driver_pins_into(_fixture._profiles, pins), &"", "exact source map without another driver bank")
	var driver: Driver = Driver.new()
	assert_equal(driver.configure(_content, _fixture._profiles, _fixture._residents, _fixture._worker, _tool,
		pins, Pins.ACTOR_SHA, Driver.PROGRAM_SHORT_STEP), &"", "same actual source driver")
	var frame: Driver.Frame = Driver.Frame.new()
	assert_equal(driver.step_profile_into(16, _job, 32768, false, frame),
		&"MOLE_DRIVER_CANONICAL_ROUTES_REQUIRED", "render calls cannot advance source-clock WORK")
	assert_false(frame.ready, "presentation cannot manufacture readiness")
	assert_equal(_fixture._work.tool_job_of(_fixture._slot), _job, "Work claim remains authoritative")
	driver.retire()


func test_driver_subset_pins_preserve_output_on_geometry_or_shape_refusal() -> void:
	"""The fixed driver packet excludes travel rows and cannot silently accept a different source image."""
	var pins: PackedInt64Array = PackedInt64Array()
	pins.resize(54)
	assert_equal(Catalog.driver_pins_into(_fixture._profiles, pins), &"", "all eighteen source roles")
	for index: int in 18:
		assert_equal(pins[index * 3], index if index < 2 else index + 11, "only exact legacy geometry roles")
		assert_equal(pins[index * 3 + 1], 1, "unchanged source row revision")
		assert_equal(pins[index * 3 + 2], 3, "current complete content image")
	var before: PackedInt64Array = pins.duplicate()
	assert_equal(Catalog.driver_pins_into(_changed_geometry(), pins), &"MOLE_CATALOG_GEOMETRY_DRIFT", "whole source still checked")
	assert_equal(pins, before, "failed geometry emits no partial pin tuple")
	assert_equal(Catalog.driver_pins_into(_fixture._profiles, PackedInt64Array([55])),
		&"MOLE_CATALOG_PINS_SIZE", "caller packet remains exactly fifty-four scalars")
