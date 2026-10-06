extends "res://test/framework/test_case.gd"
## ADR1200/1206: the published tool-free haul rows (content 6: wood 30-36, stone 37-41) with actual
## Resident/Inventory/Carry/Jobs owners.
## Selection identity only; no World support, route, station seam, grip certificate or presentation is granted.

const Catalog := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-stone-v7/catalog_source.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Fixture := preload("res://test/test_underground_profiles.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Pool := preload("res://scripts/core/reservations.gd")
# The immutable consumer contract must already be in the host's actual script cache.
const WorkFace := preload("res://scripts/core/underground_work_face.gd")
const Contacts := preload("res://scripts/core/underground_connector_contacts.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Driver := preload("res://data/underground/mole-worker/mole_profile_driver.gd")
const ACTOR_PATH: String = "res://data/underground/mole-worker/evidence/contact-qualification/install-program-compile-v3/result/mole-worker.ugactor"
const PRESENTATION_RESERVE: int = 7141920
const NULL_REF: Vector2i = Vector2i(-1, 0)
const STAND: int = 30
const WALK: int = 31
const CARRY: int = 32
const LOAD: int = 33 # yaw 0; 34 is yaw 16384
const UNLOAD: int = 35 # yaw 0; 36 is yaw 16384
const STONE_CARRY: int = 37
const STONE_LOAD: int = 38 # yaw 0; 39 is yaw 16384
const STONE_UNLOAD: int = 40 # yaw 0; 41 is yaw 16384
var _fixture: Fixture = null
var _content: Content = null
var _domain: Space.Domain = null


func before_each() -> void:
	"""A tool-free actual mole and the same published content the Session loads."""
	_fixture = Fixture.new()
	_fixture.before_each()
	_fixture._slot = _fixture._residents.spawn(&"mole").value
	_fixture._worker = _fixture._residents.ref_of(_fixture._slot)
	assert_true(_fixture._residents.spatial_profile_identity_into(_fixture._worker, _fixture._identity), "actual mole rig")
	assert_true(_fixture._transforms.place(_fixture._worker, 4096, 512, 4096, 12345), "actual noncardinal root")
	_content = Content.new()
	assert_equal(_content.load_file(ACTOR_PATH, Pins.ACTOR_SHA, PRESENTATION_RESERVE), &"", "same-file source image")
	_domain = Space.Domain.new()
	assert_equal(_domain.configure(Vector2i(0, 1), Vector3i(0, 512, 0), Vector3i(0, -32, 0), Vector3i(256, 48, 256),
		8192, 6144, Space.MAX_CHECKS), &"", "finite initial world")
	_fixture._profiles = Profiles.new()
	assert_equal(_fixture._profiles.configure(Catalog.PROFILE_COUNT, Catalog.BOX_COUNT, Catalog.SOURCE_COUNT,
		Catalog.PAIRED_BANK_BYTES + Catalog.CONTROL_RESERVE), &"", "complete peak admission")
	assert_equal(_fixture._bind(_fixture._profiles), &"", "actual same-owner profile identity")
	assert_equal(Catalog.load_into(_fixture._profiles, _content, _domain), &"", "published content 6")
	assert_true(_fixture.failures.is_empty(), "actual fixture assertions propagated")


func after_each() -> void:
	"""Release only this suite's scratch; the fixture clears its own owners."""
	_content = null
	_domain = null
	if _fixture != null:
		assert_true(_fixture.failures.is_empty(), "fixture failure propagation")
		_fixture.after_each()
	_fixture = null


func _wood_lot(quantity: int, job: Vector2i, item: StringName = &"wood") -> Vector2i:
	"""Load one actual lot of `item` (wood unless named) of exactly `quantity` milli into the worker's real satchel."""
	var wood: int = _fixture._items.compiled_id(item)
	var source: Vector2i = _fixture._inventory.create_lot(_fixture._store, wood, 5000, 0, 0, -1, 0, 0).ref
	var batch: PackedInt64Array = PackedInt64Array([source.x, source.y, Pool.PURPOSE_HAUL_SOURCE, quantity, 300])
	assert_true(_fixture._pool.claim_batch(job, batch, 1, _fixture._inventory).ok, "actual source claim")
	assert_true(_fixture._carry.load_payload(job, _fixture._slot, source).ok, "actual carried lot")
	return _fixture._carry.carried_lot(_fixture._slot)


func _haul_job() -> Vector2i:
	"""An actual HAUL Job assigned to the actual worker through Jobs' own owners."""
	assert_true(_fixture._priorities.spawn(_fixture._slot).ok, "actual priorities")
	assert_true(_fixture._schedule.spawn(_fixture._slot, _fixture._schedule.default_template_id().value).ok, "actual schedule")
	assert_true(_fixture._schedule.resolve(_fixture._slot, 8, false).ok, "work hour")
	assert_true(_fixture._jobs.spawn_agent(_fixture._slot).ok, "actual JobAgent")
	var job: Jobs.OpResult = _fixture._jobs.create_job(Jobs.JOB_KIND_HAUL, 0, 0, 1000, 0)
	assert_true(job.ok, "actual HAUL Job")
	assert_true(_fixture._jobs.assign_worker(_fixture._slot, job.value).ok, "actual assignment")
	return job.ref


func test_published_content_5_keeps_content_4_and_appends_the_haul_source_block() -> void:
	"""Rows 30-36 are the tool-free source-2 block; the full live wire still hashes to the published pin."""
	var profiles: Profiles = _fixture._profiles
	assert_equal(Catalog.catalog_refusal(profiles), &"", "complete live wire matches the published digest")
	assert_equal(profiles.profile_count(Catalog.CONTENT_REVISION), 42, "content 4, seven haul rows, five stone rows")
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(32)
	assert_true(profiles.source_hash_into(2, Catalog.CONTENT_REVISION, digest), "third source exists")
	assert_equal(digest.hex_encode(), Pins.HAUL_SOURCE_SHA, "native haul image v8")
	var row: Profiles.Descriptor = Profiles.Descriptor.new()
	var wood: int = _fixture._items.compiled_id(&"wood")
	for profile: int in range(STAND, 37):
		assert_equal(profiles.descriptor_into(profile, Catalog.CONTENT_REVISION, row), &"", "published row")
		assert_equal(row.source_id, 2, "own source block")
		assert_equal(row.tool_item, -1, "tool-free")
		assert_equal(profiles.selection_policy_of(profile, 1, Catalog.CONTENT_REVISION), Profiles.POLICY_AUTOMATIC, "automatic")
		var loaded: bool = profile == CARRY or profile >= UNLOAD
		assert_equal(row.cargo_item, wood if loaded else -1, "actual compiled wood id")
		assert_equal(row.quantity_min_milli, 1000 if loaded else 0, "exact whole-unit trip")
		assert_equal(row.quantity_max_milli, 1000 if loaded else 0, "no partial range")
		if profile >= LOAD:
			assert_equal(row.work_kind, Jobs.JOB_KIND_HAUL, "HAUL Job kind")
			assert_equal(row.contact_kind, Profiles.CONTACT_HAUL_GRIP, "curved grip, no planar contact")
			assert_equal(row.yaw, 0 if profile == LOAD or profile == UNLOAD else 16384, "two exact headings")
	assert_equal(profiles.descriptor_into(29, Catalog.CONTENT_REVISION, row), &"", "row 29 unchanged")
	assert_equal(row.source_id, 1, "assembly-handling source keeps its id")


func test_tool_free_worker_selects_stand_walk_and_carry_automatically() -> void:
	"""A worker with no tool selects A/A' empty, and B only while carrying exactly 1000 milli wood."""
	var out: Profiles.Selection = Profiles.Selection.new()
	var profiles: Profiles = _fixture._profiles
	assert_equal(profiles.query_into(_fixture._worker, NULL_REF, Profiles.MODE_STAND, 0, -1, NULL_REF, out), &"", "stand")
	assert_equal(out.profile_id, STAND, "tool-free stand")
	assert_equal(profiles.query_into(_fixture._worker, NULL_REF, Profiles.MODE_WALK, 0, -1, NULL_REF, out), &"", "walk")
	assert_equal(out.profile_id, WALK, "tool-free walk, not the pick walk")
	assert_equal(out.yaw, 12345, "all-yaw row keeps the actual heading")
	assert_equal(profiles.query_into(_fixture._worker, NULL_REF, Profiles.MODE_CARRY, 0, -1, NULL_REF, out),
		&"PROFILE_VARIANT_UNAUTHORED", "no empty carry")
	var lot: Vector2i = _wood_lot(1000, Vector2i(500, 1))
	assert_equal(profiles.query_into(_fixture._worker, NULL_REF, Profiles.MODE_CARRY, 0, -1, NULL_REF, out), &"", "carry")
	assert_equal(out.profile_id, CARRY, "tool-free loaded gait")
	assert_equal(out.cargo, lot, "actual carried lot")
	assert_equal(out.cargo_quantity_milli, 1000, "exact quantity")
	assert_equal(out.source_id, 2, "haul source")
	assert_equal(profiles.query_into(_fixture._worker, NULL_REF, Profiles.MODE_WALK, 0, -1, NULL_REF, out),
		&"PROFILE_VARIANT_UNAUTHORED", "held wood cannot use the empty walk")


func test_carry_refuses_any_quantity_other_than_one_whole_unit() -> void:
	"""ADR1198: whole-unit trips only; 2000 milli has no authored loaded gait."""
	var out: Profiles.Selection = Profiles.Selection.new()
	_wood_lot(2000, Vector2i(500, 1))
	assert_equal(_fixture._profiles.query_into(_fixture._worker, NULL_REF, Profiles.MODE_CARRY, 0, -1, NULL_REF, out),
		&"PROFILE_VARIANT_UNAUTHORED", "no rounding to the authored range")


func test_haul_work_rows_follow_actual_cargo_and_exact_heading() -> void:
	"""Load (no cargo) and unload (1000 wood) select by the actual HAUL Job, carried lot and cardinal yaw."""
	var out: Profiles.Selection = Profiles.Selection.new()
	var profiles: Profiles = _fixture._profiles
	var job: Vector2i = _haul_job()
	for heading: int in [0, 16384]:
		assert_true(_fixture._transforms.place(_fixture._worker, 4096, 512, 4096, heading), "station heading")
		# ADR1206: an empty lift cannot tell wood from stone, so content 6 refuses to guess; Delivery names the row.
		assert_equal(profiles.query_into(_fixture._worker, job, Profiles.MODE_WORK, 0, -1, NULL_REF, out),
			&"PROFILE_SELECTION_AMBIGUOUS", "empty lift is not selected by file order")
		for row: int in [LOAD, STONE_LOAD]:
			var exact: int = row + (1 if heading != 0 else 0)
			assert_equal(profiles.query_work_profile_into(_fixture._worker, job, exact, 1, Catalog.CONTENT_REVISION, 0, -1,
				NULL_REF, out), &"", "explicit empty grip %d" % exact)
			assert_equal(out.profile_id, exact, "named row at this heading")
	assert_true(_fixture._transforms.place(_fixture._worker, 4096, 512, 4096, 32768), "unauthored heading")
	assert_equal(profiles.query_into(_fixture._worker, job, Profiles.MODE_WORK, 0, -1, NULL_REF, out),
		&"PROFILE_VARIANT_UNAUTHORED", "no rotation is inferred")
	_wood_lot(1000, job)
	for heading: int in [0, 16384]:
		assert_true(_fixture._transforms.place(_fixture._worker, 4096, 512, 4096, heading), "station heading")
		assert_equal(profiles.query_into(_fixture._worker, job, Profiles.MODE_WORK, 0, -1, NULL_REF, out), &"", "unload")
		assert_equal(out.profile_id, UNLOAD + (1 if heading != 0 else 0), "loaded grip at this heading")
		assert_equal(out.cargo_quantity_milli, 1000, "exact carried quantity")


func test_quarter_turn_rows_are_the_exact_integer_rotation() -> void:
	"""Every yaw-16384 box is (z0, y0, -x1, z1, y1, -x0) of its yaw-0 box, as rows 13 and 17 are."""
	var a: Profiles.Box = Profiles.Box.new()
	var b: Profiles.Box = Profiles.Box.new()
	for pair: Array in [[13, 17], [LOAD, LOAD + 1], [UNLOAD, UNLOAD + 1]]:
		var row: Profiles.Descriptor = Profiles.Descriptor.new()
		assert_equal(_fixture._profiles.descriptor_into(pair[0], Catalog.CONTENT_REVISION, row), &"", "source row")
		for ordinal: int in row.box_count:
			assert_equal(_fixture._profiles.box_into(pair[0], 1, Catalog.CONTENT_REVISION, ordinal, a), &"", "yaw 0 box")
			assert_equal(_fixture._profiles.box_into(pair[1], 1, Catalog.CONTENT_REVISION, ordinal, b), &"", "yaw 16384 box")
			assert_equal(b.low, Vector3i(a.low.z, a.low.y, -a.high.x), "low corner")
			assert_equal(b.high, Vector3i(a.high.z, a.high.y, -a.low.x), "high corner")
			assert_equal(b.role, a.role, "same role")


func test_stone_rows_are_their_own_source_block_and_select_by_actual_cargo() -> void:
	"""ADR1206: rows 37-41 are source 3 (native stone image v9), stone item 53, whole-unit trips."""
	var profiles: Profiles = _fixture._profiles
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(32)
	assert_true(profiles.source_hash_into(3, Catalog.CONTENT_REVISION, digest), "fourth source exists")
	assert_equal(digest.hex_encode(), Pins.STONE_SOURCE_SHA, "native stone image v9")
	var stone: int = _fixture._items.compiled_id(&"stone")
	assert_equal(stone, 53, "stone's compiled id")
	var row: Profiles.Descriptor = Profiles.Descriptor.new()
	for profile: int in range(STONE_CARRY, 42):
		assert_equal(profiles.descriptor_into(profile, Catalog.CONTENT_REVISION, row), &"", "published row")
		assert_equal(row.source_id, 3, "own source block")
		assert_equal(row.tool_item, -1, "tool-free")
		var loaded: bool = profile == STONE_CARRY or profile >= STONE_UNLOAD
		assert_equal(row.cargo_item, stone if loaded else -1, "stone cargo")
		assert_equal(row.quantity_min_milli, 1000 if loaded else 0, "exact whole-unit trip")
	var out: Profiles.Selection = Profiles.Selection.new()
	var job: Vector2i = _haul_job()
	var lot: Vector2i = _wood_lot(1000, job, &"stone")
	assert_equal(profiles.query_into(_fixture._worker, NULL_REF, Profiles.MODE_CARRY, 0, -1, NULL_REF, out), &"", "carry")
	assert_equal(out.profile_id, STONE_CARRY, "stone loaded gait, not wood's")
	assert_equal(out.cargo, lot, "actual carried stone lot")
	for heading: int in [0, 16384]:
		assert_true(_fixture._transforms.place(_fixture._worker, 4096, 512, 4096, heading), "station heading")
		assert_equal(profiles.query_into(_fixture._worker, job, Profiles.MODE_WORK, 0, -1, NULL_REF, out), &"", "unload")
		assert_equal(out.profile_id, STONE_UNLOAD + (1 if heading != 0 else 0), "stone set-down at this heading")
	var a: Profiles.Box = Profiles.Box.new()
	var b: Profiles.Box = Profiles.Box.new()
	for pair: Array in [[STONE_LOAD, STONE_LOAD + 1], [STONE_UNLOAD, STONE_UNLOAD + 1]]:
		assert_equal(profiles.descriptor_into(pair[0], Catalog.CONTENT_REVISION, row), &"", "source row")
		for ordinal: int in row.box_count:
			assert_equal(profiles.box_into(pair[0], 1, Catalog.CONTENT_REVISION, ordinal, a), &"", "yaw 0 box")
			assert_equal(profiles.box_into(pair[1], 1, Catalog.CONTENT_REVISION, ordinal, b), &"", "yaw 16384 box")
			assert_equal(b.low, Vector3i(a.low.z, a.low.y, -a.high.x), "quarter turn")
