extends "res://test/framework/test_case.gd"
## Real generational stores and immutable endpoint geometry, with explicitly synthetic
## World/contact/profile certificates. No production movement qualification is asserted.

const Routes := preload("res://scripts/core/underground_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Carry := preload("res://scripts/core/haul_carry.gd")
const Work := preload("res://scripts/core/work.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Priorities := preload("res://scripts/core/priorities.gd")
const Schedule := preload("res://scripts/core/schedule.gd")
const Pool := preload("res://scripts/core/reservations.gd")
const Piles := preload("res://scripts/core/ground_piles.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const FILE_PATH: String = "user://test-underground-routes-profiles.bin"
const COLD_BYTES: int = 1048576
const NODES: int = 8
const EDGES: int = 16
const VERTICES: int = 64
const LINKS: int = 64


class CountedSources extends Owner.CoreSources:
	## Preserve real source semantics while counting full owner reads in observation-only loops.
	var reads: int = 0

	func read_into(ref: Vector2i, out: Owner.Facts) -> StringName:
		"""The counter never supplies a synthetic source fact or skips a real owner check."""
		reads += 1
		return super.read_into(ref, out)


class SyntheticWorld extends Routes.Bindings:
	var routes: Routes = null
	var locations: Locations = null
	var owner: Owner = null
	var cold: Budget = null
	var refusal: StringName = &""
	var mutate: bool = false
	var mutate_containment: bool = false
	var reenter_token: int = 0
	var transforms: Transforms = null
	var actor_mutation: int = 0
	var closed_edge: Vector2i = Vector2i(-1, 0)
	var motion_blocked: bool = false
	var synthetic_pace: int = 1024
	var alternate_paces: PackedInt32Array = PackedInt32Array()
	var motion_closed_edge: Vector2i = Vector2i(-1, 0)
	var actual_occupancy: bool = false

	func exact_binding(candidate: RefCounted, endpoints: Locations, space: Owner, arena: Budget) -> bool:
		"""Numeric identity coincidence in a foreign owner is never accepted."""
		return candidate == routes and endpoints == locations and space == owner and arena == cold

	func edge_refusal(edge: Routes.Edge, _route_token: int, _space_token: int, _location_token: int) -> StringName:
		"""Synthetic certificate only: actual production sweep/content belongs to WorldBindings."""
		if mutate:
			edge.points[0] += 1
		if mutate_containment:
			edge.level += 1
		if reenter_token != 0:
			routes.abort(reenter_token)
		return refusal

	func actor_admission_refusal(location: Vector2i, selection: Profiles.Selection) -> StringName:
		"""This fixture does not claim native body/source qualification."""
		if actor_mutation == 1:
			selection.y += 1
		elif actor_mutation == 2:
			transforms.place(selection.worker, selection.x, selection.y + 1, selection.z, selection.yaw)
		elif actor_mutation == 3:
			routes.admit_actor(selection.worker, selection.job, location, selection.mode, selection.posture, -1)
		return refusal

	func publication_refusal(_route_token: int, _space_token: int, _location_token: int) -> StringName:
		"""Explicitly synthetic callback, never a replacement for actual paid publication."""
		return refusal

	func travel_refusal(edge: Vector2i, _selection: Profiles.Selection) -> StringName:
		"""Synthetic complete-span proof can explicitly reject one candidate for this actual actor."""
		return &"SYNTHETIC_SPAN_TOO_SMALL" if edge == closed_edge else refusal

	func transit_region_into(section: Vector2i, _segment: int, _point: Vector3i, out: Owner.Region) -> StringName:
		"""Synthetic support permission; actual containment identity comes from the real section owner."""
		return owner.region_into_reused(section, out)

	func motion_refusal(_worker: Vector2i, _edge: Vector2i, _segment: int, _from: Vector3i,
			_to: Vector3i, _selection: Profiles.Selection) -> StringName:
		"""Explicit test-only dynamic clearance, never production body or connector qualification."""
		if actor_mutation == 4 and _segment == 1:
			routes.cancel_route(_worker)
		if actual_occupancy:
			var bounds: PackedInt32Array = PackedInt32Array([mini(_from.x, _to.x) - 128,
				mini(_from.y, _to.y) - 20, mini(_from.z, _to.z) - 128,
				maxi(_from.x, _to.x) + 128, maxi(_from.y, _to.y) + 900, maxi(_from.z, _to.z) + 128])
			return routes.occupancy_refusal(bounds, _worker)
		return &"SYNTHETIC_DYNAMIC_OBSTACLE" if motion_blocked or _edge == motion_closed_edge else refusal

	func pace_into(_selection: Profiles.Selection, _family: int, _variant: int, out: Routes.IntMath.IntResult) -> StringName:
		"""This fixture value tests integer integration only and is not adopted production pace."""
		out.value = alternate_paces[_variant] if _variant >= 0 and _variant < alternate_paces.size() else synthetic_pace
		return &""


var _residents: Residents = null
var _transforms: Transforms = null
var _buildings: Buildings = null
var _construction: Construction = null
var _inventory: Inventory = null
var _items: Items = null
var _gear: Gear = null
var _carry: Carry = null
var _work: Work = null
var _jobs: Jobs = null
var _priorities: Priorities = null
var _schedule: Schedule = null
var _pool: Pool = null
var _piles: Piles = null
var _profiles: Profiles = null
var _owner: Owner = null
var _sources: Owner.CoreSources = null
var _locations: Locations = null
var _budget: Budget = null
var _routes: Routes = null
var _binding: SyntheticWorld = null
var _world: Vector2i = NULL_REF
var _worker: Vector2i = NULL_REF
var _floor: Vector2i = NULL_REF
var _identity: PackedInt32Array = PackedInt32Array([0, 0, 0])


func before_each() -> void:
	"""Compose actual stores without borrowing any demo flat-tile or guessed underground identity."""
	_residents = Residents.new()
	_world = _residents.directory().create(Directory.KIND_WORLD)
	_worker = _residents.ref_of(_residents.spawn(&"mouse").value)
	assert_true(_residents.spatial_profile_identity_into(_worker, _identity), "actual Resident key")
	_transforms = Transforms.new(_residents.directory())
	assert_true(_transforms.place(_worker, -512, 0, 512, 0), "actual integer pose")
	_buildings = Buildings.new(_residents.directory())
	_construction = Construction.new(_buildings)
	_inventory = Inventory.new(16, 32)
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "real item definitions")
	_make_profiles()
	_make_space()
	_bind_routes(NODES, EDGES, VERTICES, LINKS)


func _bind_routes(nodes: int, edges: int, vertices: int, links: int) -> void:
	"""Bind the actual selected finite graph to the fixture's explicit synthetic provider."""
	_binding = SyntheticWorld.new()
	_binding.routes = _routes
	_binding.locations = _locations
	_binding.owner = _owner
	_binding.cold = _budget
	_binding.transforms = _transforms
	assert_equal(_routes.configure(_locations, _owner, _sources, _buildings, _budget, _binding,
		nodes, edges, vertices, links, Routes.ARENA_BYTES), &"", "admitted actual graph")
	assert_equal(_routes.bind_profiles(_profiles, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual profile collaborators")


func _make_profiles() -> void:
	"""Real dynamic readers select only explicitly labelled synthetic body/profile content."""
	_pool = Pool.new(64, Pool.JOB_CAPACITY, 32)
	_piles = Piles.new()
	assert_true(_piles.bind_stores(_inventory, _buildings, StockAge.new(_inventory)), "actual pile owner")
	assert_true(_piles.bind_world(_world), "actual World")
	_carry = Carry.new()
	assert_true(_carry.bind(_inventory, _pool, _residents, _piles), "actual carry")
	_gear = Gear.new(16)
	assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual Gear")
	_priorities = Priorities.new()
	_schedule = Schedule.new(_residents.needs())
	_jobs = Jobs.new(_residents, _priorities, _schedule)
	_work = Work.new(_jobs)
	assert_true(_work.bind_gear(_gear).ok, "actual Work")
	_profiles = Profiles.new()
	assert_equal(_profiles.configure(32, 256, 8, Profiles.ARENA_BYTES), &"", "finite profile pack")
	assert_equal(_profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), &"", "real readers")
	assert_equal(_load(_image([_row()], _boxes())), &"", "synthetic source certificate")


func _make_space(nodes: int = NODES, regions: int = 64, sources: int = 16, surveys: int = 64) -> void:
	"""The real sparse owner and CoreSources retain this exact movement/containment reader."""
	_routes = Routes.new(_residents, _transforms)
	_sources = CountedSources.new(_residents.directory(), _buildings, _construction, _routes)
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(_world, Vector3i.ZERO, Vector3i(-8, -8, -8),
		Vector3i(16, 16, 16), 64, surveys, Space.MAX_CHECKS), &"", "explicit test domain")
	_owner = Owner.new(_sources)
	assert_equal(_owner.configure(domain, regions, sources), &"", "real sparse owner")
	var token: int = _owner.begin_stage(_owner.revision()).token
	_floor = _region(token, [-4096, 0, -4096, 4096, 1, 4096], Space.FLOOR_DATUM)
	_region(token, [-4096, 0, -4096, 4096, 2048, 4096], Space.SUPPORTED_VOID)
	_region(token, [-4096, -256, -4096, 4096, 0, 4096], Space.SUPPORT)
	assert_equal(_owner.seal(token), &"", "initial geometry")
	_owner.publish(token)
	_budget = Budget.new()
	_locations = Locations.new()
	assert_equal(_locations.configure(_residents.directory(), _buildings, _transforms, _inventory,
		_owner, _sources, _budget, nodes, 228 * nodes + 256), &"", "actual endpoints")


func after_each() -> void:
	"""Weak graph wiring does not form a CoreSources/Routes/Locations cycle."""
	assert_true(_budget.is_quiescent(), "shared cold arena returned")
	_binding = null
	_locations = null
	_owner = null
	_sources = null
	_routes = null
	_profiles = null
	_work = null
	_jobs = null
	_schedule = null
	_priorities = null
	_carry = null
	_gear = null
	_piles = null
	_pool = null
	_inventory = null
	_items = null
	_transforms = null
	_construction = null
	_buildings = null
	_residents = null
	_budget = null
	if FileAccess.file_exists(FILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE_PATH))


func _region(token: int, box: Array[int], role: int) -> Vector2i:
	"""Fixture dimensions are explicit synthetic world geometry, not an authored production catalog."""
	var record: Owner.Region = Owner.Region.new()
	record.box = PackedInt32Array(box)
	record.owner = _world
	record.role = role
	record.level = 0
	var added: Owner.Result = _owner.stage_add(token, record)
	assert_equal(added.error, &"", "actual region")
	return added.handle


func _location(point: Vector3i) -> Vector2i:
	"""Publish a supported exact endpoint through the real immutable location owner."""
	var record: Locations.Record = Locations.Record.new()
	record.point = point
	record.section = _floor
	record.level = 0
	record.role = Locations.ROLE_TRANSIT
	record.envelope = PackedInt32Array([point.x - 128, point.y, point.z - 128, point.x + 128, point.y + 1024, point.z + 128])
	record.support = PackedInt32Array([point.x - 128, point.y - 128, point.z - 128, point.x + 128, point.y, point.z + 128])
	var cold: int = _budget.acquire(COLD_BYTES)
	var token: int = _locations.begin_prepare(cold).token
	var added: Locations.Result = _locations.stage_add(token, record)
	assert_equal(added.error, &"", "actual endpoint coverage")
	assert_equal(_locations.seal(token), &"", "endpoint sealed")
	assert_true(_locations.publish(token), "endpoint published")
	_budget.release(cold)
	return added.location


func _edge(first: Vector2i, last: Vector2i, points: Array[Vector3i]) -> Routes.Edge:
	"""An authored directed span contains every actual XYZ vertex, including negative coordinates."""
	var edge: Routes.Edge = Routes.Edge.new()
	edge.from_location = first
	edge.to_location = last
	edge.section = _floor
	edge.level = 0
	edge.variant = 0
	edge.mode = Profiles.MODE_WALK
	edge.posture = Profiles.POSTURE_UPRIGHT
	edge.content_revision = _profiles.content_revision()
	edge.geometry_revision = _owner.revision()
	edge.point_count = points.size()
	for index: int in points.size():
		edge.points.append_array([points[index].x, points[index].y, points[index].z])
		if index > 0:
			edge.length_u += Routes._segment_length(points[index - 1], points[index])
	return edge


func _publish_edges(edges: Array[Routes.Edge]) -> Array[Vector2i]:
	"""Only this explicitly synthetic World callback authorizes the component graph publication."""
	var refs: Array[Vector2i] = []
	var cold: int = _budget.acquire(COLD_BYTES)
	var prepared: Routes.Result = _routes.begin_prepare(cold)
	assert_equal(prepared.error, &"", "graph preparation")
	for edge: Routes.Edge in edges:
		var added: Routes.Result = _routes.stage_add(prepared.token, edge)
		assert_equal(added.error, &"", "exact span: %s" % added.error)
		refs.append(added.ref)
	assert_equal(_routes.seal(prepared.token), &"", "sealed graph")
	assert_equal(_routes.publish(prepared.token), &"", "actual graph publication")
	_budget.release(cold)
	return refs


func _row(mode: int = Profiles.MODE_WALK) -> Dictionary:
	"""Explicit synthetic geometry/certificate; actual species/stage/rig remains owner-derived."""
	var fields: PackedInt32Array = PackedInt32Array([0, _identity[0], _identity[1], _identity[2],
		mode, Profiles.POSTURE_UPRIGHT, -1, -1, -1, -1, Profiles.YAW_ALL, 0, 31, 511, 0, 3, -1, 0])
	return {"fields": fields, "longs": PackedInt64Array([1, 0, 0]), "flags": PackedByteArray([15, 0])}


func _boxes() -> Array[PackedInt32Array]:
	"""Body retains actual below-root space; explicit test-only floor contact and turn volume."""
	return [PackedInt32Array([-100, -20, -80, 100, 900, 80, 0]),
		PackedInt32Array([-40, -20, -40, 40, 0, 40, 1]),
		PackedInt32Array([-128, -20, -128, 128, 900, 128, 2])]


func _image(rows: Array[Dictionary], boxes: Array[PackedInt32Array], revision: int = 1) -> PackedByteArray:
	"""Independent row-wire writer; loader owns column indexing, count validation and atomicity."""
	var bytes: PackedByteArray = "UGPROF01".to_ascii_buffer()
	bytes.resize(32)
	bytes.encode_u32(8, 1)
	bytes.encode_s64(12, revision)
	bytes.encode_u32(20, rows.size())
	bytes.encode_u32(24, boxes.size())
	bytes.encode_u32(28, 1)
	for index: int in 32:
		bytes.append(7) # Synthetic digest, never a production source.
	for row: Dictionary in rows:
		var base: int = bytes.size()
		bytes.resize(base + 98)
		var fields: PackedInt32Array = row.fields
		var longs: PackedInt64Array = row.longs
		for index: int in 18:
			bytes.encode_s32(base + 4 * index, fields[index])
		for index: int in 3:
			bytes.encode_s64(base + 72 + 8 * index, longs[index])
		bytes[base + 96] = row.flags[0]
		bytes[base + 97] = row.flags[1]
	for box: PackedInt32Array in boxes:
		var base: int = bytes.size()
		bytes.resize(base + 28)
		for index: int in 7:
			bytes.encode_s32(base + 4 * index, box[index])
	bytes.append_array("UGPEND01".to_ascii_buffer())
	return bytes


func _load(bytes: PackedByteArray, revision: int = 1, hash_override: String = "") -> StringName:
	"""The trusted expected digest is external to the file being decoded."""
	var file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var digest_context: HashingContext = HashingContext.new()
	digest_context.start(HashingContext.HASH_SHA256)
	digest_context.update(bytes)
	var actual: String = digest_context.finish().hex_encode()
	return _profiles.load_file(FILE_PATH, actual if hash_override == "" else hash_override, revision)



func test_directed_integer_paths_do_not_infer_reverse_or_vertical_connections() -> void:
	"""Matching coordinates and nearby sections do not replace an authored full directed edge."""
	var a: Vector3i = Vector3i(-512, 0, 512)
	var b: Vector3i = Vector3i(512, 0, 512)
	var first: Vector2i = _location(a)
	var last: Vector2i = _location(b)
	var refs: Array[Vector2i] = _publish_edges([_edge(first, last, [a, b])])
	var out: PackedInt32Array = PackedInt32Array([99, 99, 99, 99])
	var found: Routes.Result = _routes.candidate_path_into(first, last, Profiles.MODE_WALK, 0, out)
	assert_equal(found.error, &"", "authored connection")
	assert_equal(found.count, 1, "one span")
	assert_equal(Vector2i(out[0], out[1]), refs[0], "full directed edge")
	var previous: PackedInt32Array = out.duplicate()
	assert_equal(_routes.candidate_path_into(last, first, Profiles.MODE_WALK, 0, out).error,
		&"ROUTE_NOT_CONNECTED", "no invented reverse edge")
	assert_equal(out, previous, "refused query preserves caller output")
	assert_equal(_routes.candidate_path_into(first, last, Profiles.MODE_CLIMB, 0, out).error,
		&"ROUTE_NOT_CONNECTED", "walk span is not an authored climbing span")


func test_graph_retains_actual_locations_until_exact_live_edge_retirement() -> void:
	"""A prepared graph removal alone cannot authorize a premature endpoint removal."""
	var a: Vector3i = Vector3i(-512, 0, 512)
	var b: Vector3i = Vector3i(512, 0, 512)
	var first: Vector2i = _location(a)
	var last: Vector2i = _location(b)
	var edge: Vector2i = _publish_edges([_edge(first, last, [a, b])])[0]
	var cold: int = _budget.acquire(COLD_BYTES)
	var endpoint_token: int = _locations.begin_prepare(cold).token
	assert_equal(_locations.stage_remove(endpoint_token, first), &"LOCATION_ROUTE_RETAINED", "live graph retains exact generation")
	_locations.abort(endpoint_token)
	var token: int = _routes.begin_prepare(cold).token
	assert_equal(_routes.stage_remove(token, edge), &"", "empty span may be retired")
	assert_true(_routes.retains_location(first), "staged removal is not live")
	assert_equal(_routes.seal(token), &"", "sealed graph removal")
	assert_equal(_routes.publish(token), &"", "actual graph removal")
	endpoint_token = _locations.begin_prepare(cold).token
	assert_equal(_locations.stage_remove(endpoint_token, first), &"", "no live graph reference remains")
	_locations.abort(endpoint_token)
	_budget.release(cold)


func test_refused_and_mutated_callbacks_never_publish_a_partial_graph() -> void:
	"""A failed candidate consumes no live edge generation or topology revision."""
	var a: Vector3i = Vector3i(-512, 0, 512)
	var b: Vector3i = Vector3i(512, 0, 512)
	var first: Vector2i = _location(a)
	var last: Vector2i = _location(b)
	var revision: int = _routes.revision()
	var cold: int = _budget.acquire(COLD_BYTES)
	var token: int = _routes.begin_prepare(cold).token
	_binding.mutate = true
	assert_equal(_routes.stage_add(token, _edge(first, last, [a, b])).error,
		&"ROUTE_CALLBACK_CHANGED_PACKET", "callback is not an input author")
	assert_false(_routes.is_live_edge(Vector2i(0, 1)), "no partial live edge")
	assert_true(_routes.seal(token) != &"", "poisoned candidate refuses")
	assert_true(_routes.abort(token), "normal caller abort")
	_binding.mutate = false
	assert_equal(_routes.revision(), revision, "live revision retained")
	_budget.release(cold)
	var edge: Vector2i = _publish_edges([_edge(first, last, [a, b])])[0]
	assert_equal(edge, Vector2i(0, 1), "failed stage did not consume live identity")


func test_actor_admission_reads_exact_containment_and_retains_real_endpoint() -> void:
	"""Actual identity/pose stays distinct from the fixture's synthetic qualification certificate."""
	var location: Vector2i = _location(Vector3i(-512, 0, 512))
	assert_equal(_routes.admit_actor(_worker, NULL_REF, location, Profiles.MODE_WALK, 0, -1), &"", "actual actor registered")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "committed actual observation")
	assert_equal(actor.worker, _worker, "full Resident generation")
	assert_equal(actor.point, Vector3i(-512, 0, 512), "integer world position")
	assert_equal(actor.section, _floor, "actual full floor handle")
	assert_equal(actor.room, NULL_REF, "surface section is explicitly roomless")
	assert_equal(actor.level, 0, "actual section level")
	assert_equal(actor.phase, Routes.PHASE_IDLE, "no route was invented")
	var facts: Owner.Facts = Owner.Facts.new()
	assert_equal(_routes.read_into(_worker, facts), &"", "CoreSources reads same committed truth")
	assert_equal(Vector3i(facts.a, facts.b, facts.c), actor.point, "exact source coordinates")
	var cold: int = _budget.acquire(COLD_BYTES)
	var token: int = _locations.begin_prepare(cold).token
	assert_equal(_locations.stage_remove(token, location), &"LOCATION_ROUTE_RETAINED", "idle actor retains endpoint")
	_locations.abort(token)
	_budget.release(cold)


func test_actor_admission_never_teleports_or_accepts_an_unqualified_location() -> void:
	"""A valid local handle does not prove arrival or complete physical clearance."""
	var wrong: Vector2i = _location(Vector3i(512, 0, 512))
	var right: Vector2i = _location(Vector3i(-512, 0, 512))
	assert_equal(_routes.admit_actor(_worker, NULL_REF, wrong, Profiles.MODE_WALK, 0, -1),
		&"ROUTE_ACTOR_POSITION_DRIFT", "no teleport to a matching-purpose endpoint")
	_binding.refusal = &"SYNTHETIC_BODY_DOES_NOT_FIT"
	assert_equal(_routes.admit_actor(_worker, NULL_REF, right, Profiles.MODE_WALK, 0, -1),
		_binding.refusal, "actual provider refusal is mandatory")
	var actor: Routes.Actor = Routes.Actor.new()
	actor.point = Vector3i(77, 88, 99)
	assert_equal(_routes.read_actor_into(_worker, actor), &"ROUTE_ACTOR_NOT_REGISTERED", "no partial actor publication")
	assert_equal(actor.point, Vector3i(77, 88, 99), "refused output preserved")
	_binding.refusal = &""
	assert_equal(_routes.admit_actor(_worker, NULL_REF, right, Profiles.MODE_WALK, 0, -1), &"", "retry uses original actual pose")


func test_actor_callback_mutation_reentry_and_pose_drift_are_atomic() -> void:
	"""A side-effecting callback cannot change the pinned packet or publish a stale source observation."""
	var location: Vector2i = _location(Vector3i(-512, 0, 512))
	var errors: Array[StringName] = [&"ROUTE_CALLBACK_CHANGED_PACKET", &"ROUTE_ACTOR_PROFILE_DRIFT", &"ROUTE_CALLBACK_REENTRY"]
	for mode: int in 3:
		_binding.actor_mutation = mode + 1
		assert_equal(_routes.admit_actor(_worker, NULL_REF, location, Profiles.MODE_WALK, 0, -1), errors[mode], "callback cannot publish")
		assert_false(_routes.retains_location(location), "no partially committed actor")
		assert_true(_transforms.place(_worker, -512, 0, 512, 0), "restore actual fixture pose")
	_binding.actor_mutation = 0
	assert_equal(_routes.admit_actor(_worker, NULL_REF, location, Profiles.MODE_WALK, 0, -1), &"", "clean retry after refused callback")


func test_readable_actor_is_separate_from_changed_profile_permission() -> void:
	"""A changed content pack keeps actual containment readable but needs explicit profile requalification."""
	var location: Vector2i = _location(Vector3i(-512, 0, 512))
	assert_equal(_routes.admit_actor(_worker, NULL_REF, location, Profiles.MODE_WALK, 0, -1), &"", "initial profile")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_load(_image([_row()], _boxes(), 2), 2), &"", "real immutable replacement")
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "identity read does not recurse through entry proof")
	assert_equal(actor.content_revision, 1, "prior committed qualification is not silently promoted")
	assert_equal(_routes.refresh_actor(_worker, NULL_REF, Profiles.MODE_WALK, 0, -1), &"ROUTE_PROFILE_EXTENT_STALE", "global occupancy extent needs cold refresh")
	assert_equal(_routes.refresh_profile_extent(), &"", "exact new catalog extent")
	assert_equal(_routes.refresh_actor(_worker, NULL_REF, Profiles.MODE_WALK, 0, -1), &"", "explicit current physical proof")
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "refreshed actor readable")
	assert_equal(actor.content_revision, 2, "new proof committed only after qualification")


func test_reused_resident_generation_cannot_inherit_old_actor_record() -> void:
	"""Even the same typed row/endpoint does not make the old full Resident identity live."""
	var location: Vector2i = _location(Vector3i(-512, 0, 512))
	assert_equal(_routes.admit_actor(_worker, NULL_REF, location, Profiles.MODE_WALK, 0, -1), &"", "old actual actor")
	assert_true(_residents.despawn(_worker).ok, "actual old Resident retired")
	var next: Vector2i = _residents.ref_of(_residents.spawn(&"mouse").value)
	assert_true(_transforms.place(next, -512, 0, 512, 0), "new actual pose")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.read_actor_into(_worker, actor), &"ROUTE_ACTOR_STALE", "retired generation rejected")
	assert_equal(_routes.read_actor_into(next, actor), &"ROUTE_ACTOR_NOT_REGISTERED", "typed row is not identity")
	assert_equal(_routes.admit_actor(next, NULL_REF, location, Profiles.MODE_WALK, 0, -1),
		&"ROUTE_ACTOR_STALE", "stale retained record prevents a complete occupancy refresh")
	assert_true(_routes.retains_location(location), "failed external retirement never silently releases geometry")


func test_real_actor_queues_exact_generations_and_cancel_releases_only_future_edges() -> void:
	"""The pooled route is authoritative retention, even before the first movement tick."""
	var a: Vector3i = Vector3i(-512, 0, 512)
	var b: Vector3i = Vector3i(512, 0, 512)
	var first: Vector2i = _location(a)
	var last: Vector2i = _location(b)
	var edge: Vector2i = _publish_edges([_edge(first, last, [a, b])])[0]
	assert_equal(_routes.admit_actor(_worker, NULL_REF, first, Profiles.MODE_WALK, 0, -1), &"", "real actor admitted")
	assert_equal(_routes.request_route(_worker, last, 10), &"", "actual actor-qualified path")
	var path: PackedInt32Array = PackedInt32Array([91, 92])
	assert_equal(_routes.queued_path_into(_worker, path).count, 1, "one pooled full edge")
	assert_equal(Vector2i(path[0], path[1]), edge, "exact edge generation retained")
	var cold: int = _budget.acquire(COLD_BYTES)
	var token: int = _routes.begin_prepare(cold).token
	assert_equal(_routes.stage_remove(token, edge), &"ROUTE_EDGE_RETAINED", "queued actor retains path")
	_routes.abort(token)
	_budget.release(cold)
	assert_equal(_routes.cancel_route(_worker), &"", "future route cancelled")
	assert_equal(_routes.queued_path_into(_worker, path).count, 0, "pool returned")
	cold = _budget.acquire(COLD_BYTES)
	token = _routes.begin_prepare(cold).token
	assert_equal(_routes.stage_remove(token, edge), &"", "no queued reference remains")
	_routes.abort(token)
	_budget.release(cold)
	assert_true(_routes.retains_location(first), "idle actor still retains its actual endpoint")


func test_actor_search_uses_fitting_alternative_and_preserves_prior_route_on_refusal() -> void:
	"""An unusable span is excluded during real search; a later failed request never destroys the prior queue."""
	var a: Vector3i = Vector3i(-512, 0, 512)
	var b: Vector3i = Vector3i(512, 0, 512)
	var c: Vector3i = Vector3i(1536, 0, 512)
	var first: Vector2i = _location(a)
	var middle: Vector2i = _location(b)
	var last: Vector2i = _location(c)
	var edges: Array[Vector2i] = _publish_edges([_edge(first, middle, [a, b]), _edge(middle, last, [b, c]), _edge(first, last, [a, c])])
	assert_equal(_routes.admit_actor(_worker, NULL_REF, first, Profiles.MODE_WALK, 0, -1), &"", "actual actor")
	assert_equal(_routes.request_route(_worker, last, 20), &"", "equal-cost stable route")
	var path: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	assert_equal(_routes.queued_path_into(_worker, path).count, 2, "lower final edge resolves tie")
	assert_equal(Vector2i(path[0], path[1]), edges[0], "first contiguous span")
	_binding.closed_edge = edges[0]
	assert_equal(_routes.request_route(_worker, last, 21), &"", "fitting alternative")
	assert_equal(_routes.queued_path_into(_worker, path).count, 1, "direct authored span")
	assert_equal(Vector2i(path[0], path[1]), edges[2], "rejected span not chosen")
	var previous: PackedInt32Array = path.duplicate()
	_binding.refusal = &"SYNTHETIC_NO_FITTING_SPAN"
	assert_equal(_routes.request_route(_worker, last, 22), &"ROUTE_NOT_CONNECTED", "no unqualified fallback")
	assert_equal(_routes.queued_path_into(_worker, path).count, 1, "old queue remains")
	assert_equal(path, previous, "previous full path retained byte-for-byte")


func _moving_actor() -> Array[Vector2i]:
	"""Actual actor, profile reader and retained span with synthetic World clearance/pace only."""
	var a: Vector3i = Vector3i(-512, 0, 512)
	var b: Vector3i = Vector3i(512, 0, 512)
	var first: Vector2i = _location(a)
	var last: Vector2i = _location(b)
	var edge: Vector2i = _publish_edges([_edge(first, last, [a, b])])[0]
	assert_equal(_routes.admit_actor(_worker, NULL_REF, first, Profiles.MODE_WALK, 0, -1), &"", "actual actor at entry")
	assert_equal(_routes.request_route(_worker, last, 0), &"", "pooled actual request")
	return [first, last, edge]


func test_integer_motion_arrives_after_exact_thirty_ticks_and_never_advances_twice() -> void:
	"""The synthetic1024u/s rate integrates to exactly1024u with one Transform advance per fixed tick."""
	var refs: Array[Vector2i] = _moving_actor()
	var actor: Routes.Actor = Routes.Actor.new()
	for tick: int in range(1, 31):
		assert_equal(_routes.advance_tick(tick), 1, "one real actor advances")
		assert_equal(_routes.read_actor_into(_worker, actor), &"", "actual interior/arrival remains readable")
		@warning_ignore("integer_division") var distance: int = 1024 * tick / 30
		assert_equal(actor.point, Vector3i(-512 + distance, 0, 512), "exact integer rate and carried remainder")
		assert_equal(_routes.advance_tick(tick), 0, "same tick cannot roll previous pose again")
	assert_equal(actor.location, refs[1], "actual far endpoint committed")
	assert_equal(actor.edge, NULL_REF, "occupied span released only at arrival")
	assert_equal(actor.phase, Routes.PHASE_IDLE, "no remaining route")
	assert_equal(actor.yaw, 49152, "+X uses adopted quarter-turn convention")
	assert_equal(_routes.advance_tick(31), 0, "idle actor does not move again")


func test_blocked_motion_preserves_pose_progress_and_retry() -> void:
	"""A fresh obstacle pauses the actual retained path without earning distance or losing fractional progress."""
	_moving_actor()
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.advance_tick(1), 1, "first stride")
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "current actor")
	var point: Vector3i = actor.point
	_binding.motion_blocked = true
	assert_equal(_routes.advance_tick(2), 0, "actual motion proof refuses")
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "held identity remains readable")
	assert_equal(actor.point, point, "no movement earned on refused tick")
	assert_equal(actor.phase, Routes.PHASE_HELD, "blocked state explicit")
	_binding.motion_blocked = false
	assert_equal(_routes.advance_tick(3), 1, "retry on same retained span")
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "resumed actor")
	assert_equal(actor.point, Vector3i(-444, 0, 512), "only two strides, including exact prior remainder")


func test_cancel_in_transit_retains_current_edge_and_finishes_at_safe_endpoint() -> void:
	"""Cancellation may remove future intent, never the support occupied by a moving actor."""
	var refs: Array[Vector2i] = _moving_actor()
	assert_equal(_routes.advance_tick(1), 1, "entered actual span")
	assert_equal(_routes.cancel_route(_worker), &"", "cancel future queue")
	var cold: int = _budget.acquire(COLD_BYTES)
	var token: int = _routes.begin_prepare(cold).token
	assert_equal(_routes.stage_remove(token, refs[2]), &"ROUTE_EDGE_RETAINED", "occupied span remains retained")
	_routes.abort(token)
	_budget.release(cold)
	for tick: int in range(2, 31):
		assert_equal(_routes.advance_tick(tick), 1, "finish current supported span")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "safe actual arrival")
	assert_equal(actor.location, refs[1], "no teleport or mid-air abandonment")
	assert_equal(actor.phase, Routes.PHASE_IDLE, "cancelled intent is not restored")


func test_authored_polyline_controls_height_and_integer_heading() -> void:
	"""A synthetic elevated span proves XYZ integration only; no floor-height inference supplies its shape."""
	var a: Vector3i = Vector3i(-512, 0, 512)
	var raised: Vector3i = Vector3i(0, 768, 512)
	var b: Vector3i = Vector3i(512, 0, 512)
	var first: Vector2i = _location(a)
	var last: Vector2i = _location(b)
	_publish_edges([_edge(first, last, [a, raised, b])])
	assert_equal(_routes.admit_actor(_worker, NULL_REF, first, Profiles.MODE_WALK, 0, -1), &"", "actual start")
	assert_equal(_routes.request_route(_worker, last, 0), &"", "explicit connected polyline")
	_binding.synthetic_pace = 924 * 30
	assert_equal(_routes.advance_tick(1), 1, "one authored segment")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "exact current segment boundary")
	assert_equal(actor.point, raised, "actual Y comes from polyline")
	assert_equal(_routes.advance_tick(2), 1, "complete descent")
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "far endpoint")
	assert_equal(actor.point, b, "explicit final point")
	for direction: Vector3i in [Vector3i.FORWARD, Vector3i.LEFT, Vector3i.BACK, Vector3i.RIGHT]:
		assert_equal(Routes.heading_for_delta(-direction, 0), posmod(Routes.heading_for_delta(direction, 0) + 32768, 65536), "opposite heading is exact half turn")
	assert_equal(Routes.heading_for_delta(Vector3i(-1, 0, -1), 0), 8192, "exact diagonal tie")
	assert_equal(Routes.heading_for_delta(Vector3i(0, 10, 0), 1234), 1234, "vertical motion retains actual yaw")


func test_subunit_motion_requires_fresh_dynamic_clearance_before_fractional_progress() -> void:
	"""A sub-unit displacement still occupies space and cannot accumulate progress through a refusal."""
	_moving_actor()
	_binding.synthetic_pace = 1
	_binding.motion_blocked = true
	assert_equal(_routes.advance_tick(1), 0, "same-point dynamic proof refuses")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "identity still readable")
	assert_equal(actor.point, Vector3i(-512, 0, 512), "refused pose unchanged")
	_binding.motion_blocked = false
	for tick: int in range(2, 31):
		assert_equal(_routes.advance_tick(tick), 1, "accepted fractional step")
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "29 admitted fractions")
	assert_equal(actor.point.x, -512, "blocked tick earned no fraction")
	assert_equal(_routes.advance_tick(31), 1, "thirtieth admitted fraction")
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "one exact unit")
	assert_equal(actor.point.x, -511, "integer motion begins only after all30 accepted fractions")


func test_edge_callback_cannot_change_derived_room_or_level_packet() -> void:
	"""Section-derived containment must remain exact across the otherwise read-only geometry callback."""
	var a: Vector3i = Vector3i(-512, 0, 512)
	var b: Vector3i = Vector3i(512, 0, 512)
	var first: Vector2i = _location(a)
	var last: Vector2i = _location(b)
	var cold: int = _budget.acquire(COLD_BYTES)
	var token: int = _routes.begin_prepare(cold).token
	_binding.mutate_containment = true
	var added: Routes.Result = _routes.stage_add(token, _edge(first, last, [a, b]))
	assert_equal(added.error, &"ROUTE_CALLBACK_CHANGED_PACKET", "derived packet mutation poisons candidate")
	assert_false(_routes.is_live_edge(added.ref), "nothing published")
	assert_true(_routes.abort(token), "poisoned candidate remains abortable")
	assert_equal(_budget.release(cold), &"", "actual cold lease released")


func _full_technical_pack() -> void:
	"""Recompose the approved real arena sizes; no array maximum is silently reduced for testing."""
	_binding = null
	_make_space(Budget.LOCATION_CAPACITY, Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY, Budget.PHASE_VOLUME_CAPACITY)
	_bind_routes(Routes.MAX_LOCATIONS, Routes.MAX_EDGES, Routes.MAX_VERTICES, Routes.MAX_LINKS)
	assert_equal(_routes.packed_memory_bytes() + _locations.packed_memory_bytes()
		+ Routes.HEADER_RESERVE - Routes.FIXED_PACKED_BYTES, 1041728, "complete retained/load/query technical pack")


func test_full_admitted_arenas_seal_refresh_and_preserve_full_edge_generation() -> void:
	"""The real1072 capacities admit an ordinary operation under the unchanged bounded work ceiling."""
	_full_technical_pack()
	var refs: Array[Vector2i] = _moving_actor()
	var cold: int = _budget.acquire(COLD_BYTES)
	var token: int = _routes.begin_prepare(cold).token
	assert_equal(_routes.stage_refresh(token, refs[2]), &"", "actual full-pack retained span refresh")
	assert_equal(_routes.seal(token), &"", "finite full-pack seal")
	assert_equal(_routes.publish(token), &"", "same full span publishes")
	assert_equal(_budget.release(cold), &"", "real shared lease released")
	assert_true(_routes.is_live_edge(refs[2]), "refresh never reuses generation")
	assert_equal(_routes.advance_tick(1), 1, "retained exact queued route still works")


func test_256_actual_residents_use_finite_route_and_motion_columns() -> void:
	"""Synthetic clearance isolates finite owner/profile/Transform work; this is not crowd-flow qualification."""
	_full_technical_pack()
	var refs: Array[Vector2i] = _moving_actor()
	var workers: Array[Vector2i] = [_worker]
	for index: int in 255:
		var worker: Vector2i = _residents.ref_of(_residents.spawn(&"mouse").value)
		assert_true(_transforms.place(worker, -512, 0, 512, 0), "actual pose for live resident")
		assert_equal(_routes.admit_actor(worker, NULL_REF, refs[0], Profiles.MODE_WALK, 0, -1), &"", "actual profile/endpoint record")
		assert_equal(_routes.request_route(worker, refs[1], 0), &"", "fixed pool accepts exact route")
		workers.append(worker)
	var started: int = Time.get_ticks_usec()
	for tick: int in range(1, 31):
		assert_equal(_routes.advance_tick(tick), 256, "all actual living rows advance exactly once")
	var elapsed: int = Time.get_ticks_usec() - started
	print("ROUTES-COMPONENT-PERF actors=256 ticks=30 elapsed_us=%d synthetic_clearance=true" % elapsed)
	var actor: Routes.Actor = Routes.Actor.new()
	for worker: Vector2i in workers:
		assert_equal(_routes.read_actor_into(worker, actor), &"", "actual final record")
		assert_equal(actor.location, refs[1], "exact endpoint")
		assert_equal(actor.point, Vector3i(512, 0, 512), "integer30-tick arrival")
		assert_equal(actor.phase, Routes.PHASE_IDLE, "route links released")


func test_segment_lengths_remain_exact_at_negative_and_int64_product_boundaries() -> void:
	"""The fast single-axis path and Newton integer path share the same outward geometry contract."""
	assert_equal(Routes._segment_length(Vector3i.ZERO, Vector3i.ZERO), 0, "zero segment later refuses")
	assert_equal(Routes._segment_length(Vector3i(-100, 0, 0), Vector3i(200, 0, 0)), 300, "negative coordinate single axis")
	assert_equal(Routes._segment_length(Vector3i.ZERO, Vector3i(3, 4, 12)), 13, "exact three-dimensional square")
	assert_equal(Routes._segment_length(Vector3i.ZERO, Vector3i(1, 1, 1)), 2, "outward irrational length")
	assert_equal(Routes._segment_length(Vector3i.ZERO, Vector3i(1753413056, 1753413056, 1753413056)), 3037000500, "int64-safe three-axis maximum")
	assert_equal(Routes._segment_length(Vector3i.ZERO, Vector3i(1753413057, 0, 0)), -1, "unchanged representability limit")
	for value: int in range(1, 1024):
		assert_equal(Routes._ceil_root(value * value), value, "exact square")
		assert_equal(Routes._ceil_root(value * value + 1), value + 1, "just over square")


func test_actual_occupancy_expands_negative_root_cells_and_validates_exact_exception() -> void:
	"""A complete actor can overlap a query in the neighbouring hash cell, including below its root."""
	var location: Vector2i = _location(Vector3i(-512, 0, 512))
	assert_equal(_routes.admit_actor(_worker, NULL_REF, location, Profiles.MODE_WALK, 0, -1), &"", "actual registered root")
	var query: PackedInt32Array = PackedInt32Array([-641, -10, 500, -639, 10, 524])
	assert_equal(_routes.occupancy_refusal(query), &"ROUTE_OCCUPIED", "turn/recovery reaches beyond the body")
	assert_equal(_routes.occupancy_refusal(query, _worker), &"", "exact caller exception only")
	assert_equal(_routes.occupancy_refusal(query, Vector2i(_worker.x, _worker.y + 1)), &"ROUTE_ACTOR_STALE", "wrong generation cannot exempt")
	query[3] = -640
	assert_equal(_routes.occupancy_refusal(query), &"", "half-open touching boundary is clear")
	assert_equal(Routes._floor_cell(-1), -1, "negative one-unit floor")
	assert_equal(Routes._floor_cell(-1024), -1, "negative exact cell")
	assert_equal(Routes._floor_cell(-1025), -2, "next negative cell")


func test_foreign_transform_writes_refuse_cached_occupancy_until_exact_refresh() -> void:
	"""Global pose freshness prevents an unobserved foreign move from becoming a broadphase false negative."""
	var location: Vector2i = _location(Vector3i(-512, 0, 512))
	assert_equal(_routes.admit_actor(_worker, NULL_REF, location, Profiles.MODE_WALK, 0, -1), &"", "actual root")
	var query: PackedInt32Array = PackedInt32Array([2048, 0, 2048, 2304, 256, 2304])
	var outsider: Vector2i = _residents.ref_of(_residents.spawn(&"mouse").value)
	assert_true(_transforms.place(outsider, 6000, 0, 6000, 0), "foreign surface pose write")
	assert_equal(_routes.occupancy_refusal(query), &"ROUTE_OCCUPANCY_STALE", "cached empty answer refuses")
	assert_equal(_routes.refresh_occupancy(), &"", "once-only actual registered-root audit")
	assert_equal(_routes.occupancy_refusal(query), &"", "unregistered surface actor remains other provider responsibility")
	assert_true(_transforms.place(_worker, 2176, 0, 2176, 0), "adversarial registered actor teleport")
	assert_equal(_routes.occupancy_refusal(query), &"ROUTE_OCCUPANCY_STALE", "moved actor cannot hide in old bucket")
	assert_equal(_routes.refresh_occupancy(), &"ROUTE_ACTOR_POSITION_DRIFT", "handoff/location truth must be repaired explicitly")
	assert_equal(_routes.occupancy_refusal(query), &"ROUTE_OCCUPANCY_STALE", "failed refresh cannot qualify partial hash")


func test_changed_profile_never_omits_an_unqualified_nearby_occupant() -> void:
	"""A new source catalog must be acknowledged and actual nearby profile lookup remains mandatory."""
	var location: Vector2i = _location(Vector3i(-512, 0, 512))
	assert_equal(_routes.admit_actor(_worker, NULL_REF, location, Profiles.MODE_WALK, 0, -1), &"", "old actual body")
	assert_equal(_load(_image([_row(Profiles.MODE_STAND)], _boxes(), 2), 2), &"", "replacement lacks current travel body")
	var query: PackedInt32Array = PackedInt32Array([-600, 0, 450, -500, 300, 550])
	assert_equal(_routes.occupancy_refusal(query), &"ROUTE_OCCUPANCY_STALE", "old content extent cannot be reused")
	assert_equal(_routes.refresh_profile_extent(), &"", "actual new global extent")
	assert_equal(_routes.occupancy_refusal(query), &"ROUTE_OCCUPANT_PROFILE_STALE", "missing current variant is occupied uncertainty")


func test_actual_second_actor_blocks_motion_without_clobbering_current_selection() -> void:
	"""The actual shared index can be queried inside a read-only motion callback without aliasing its pinned actor."""
	var refs: Array[Vector2i] = _moving_actor()
	var other: Vector2i = _residents.ref_of(_residents.spawn(&"mouse").value)
	assert_true(_transforms.place(other, 512, 0, 512, 0), "actual stationary actor")
	assert_equal(_routes.admit_actor(other, NULL_REF, refs[1], Profiles.MODE_WALK, 0, -1), &"", "actual second profile")
	_binding.actual_occupancy = true
	assert_equal(_routes.advance_tick(1), 1, "clear initial motion survives nested occupancy read")
	for tick: int in range(2, 31):
		_routes.advance_tick(tick)
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "actual held actor")
	assert_equal(actor.phase, Routes.PHASE_HELD, "fresh second body blocks progress")
	assert_true(actor.point.x + 128 <= 384, "complete bodies never overlap")
	assert_equal(_routes.read_actor_into(other, actor), &"", "stationary actual actor")
	assert_equal(actor.point, Vector3i(512, 0, 512), "other actor was never overwritten")


func test_graph_publication_token_and_point_observations_pin_exact_actual_span() -> void:
	"""Prepared companion identity survives only the actual successful bank swap, never an aborted future row."""
	var refs: Array[Vector2i] = _moving_actor()
	var published: int = _routes.last_published_token()
	assert_true(published > 0, "actual graph has a completed token")
	var point: PackedInt32Array = PackedInt32Array([7, 8, 9])
	assert_equal(_routes.edge_point_into(refs[2], 1, point), &"", "single exact vertex")
	assert_equal(point, PackedInt32Array([512, 0, 512]), "exact authored point")
	assert_equal(_routes.edge_point_into(refs[2], 2, point), &"ROUTE_OUTPUT_SHAPE", "outside actual polyline")
	assert_equal(point, PackedInt32Array([512, 0, 512]), "refused reader preserves prior result")
	var cold: int = _budget.acquire(COLD_BYTES)
	var token: int = _routes.begin_prepare(cold).token
	assert_equal(_routes.stage_refresh(token, refs[2]), &"", "exact retained candidate")
	assert_equal(_routes.seal(token), &"", "sealed metadata")
	var edge: Routes.Edge = Routes.Edge.new()
	assert_equal(_routes.prepared_edge_metadata_into(token, refs[2], edge), &"", "bounded companion metadata")
	assert_equal(edge.ref, refs[2], "full staged identity is explicit")
	assert_true(_routes.abort(token), "prepared candidate discarded")
	assert_equal(_routes.last_published_token(), published, "abort cannot bless staged certificates")
	assert_equal(_budget.release(cold), &"", "actual cold lease released")


func _chain_actor(lengths: Array[int], variants: Array[int] = []) -> Array[Vector2i]:
	"""Build exact connected component-test spans; native clearance and pace authoring remain separate."""
	_binding = null
	_make_space(128)
	_bind_routes(128, 128, 256, 128)
	var point: Vector3i = Vector3i(-512, 0, 512)
	var first: Vector2i = _location(point)
	var previous: Vector2i = first
	var edges: Array[Routes.Edge] = []
	for index: int in lengths.size():
		var next_point: Vector3i = point + Vector3i(lengths[index], 0, 0)
		var endpoint: Vector2i = _location(next_point)
		var edge: Routes.Edge = _edge(previous, endpoint, [point, next_point])
		edge.variant = variants[index] if not variants.is_empty() else 0
		edges.append(edge)
		point = next_point
		previous = endpoint
	var refs: Array[Vector2i] = _publish_edges(edges)
	assert_equal(_routes.admit_actor(_worker, NULL_REF, first, Profiles.MODE_WALK, 0, -1), &"", "actual actor start")
	assert_equal(_routes.request_route(_worker, previous, 0), &"", "all spans in exact route")
	return refs


func test_motion_is_invariant_to_many_short_connected_span_boundaries() -> void:
	"""A32-span path integrates exactly like the single1024u span, including boundary-crossing ticks."""
	var lengths: Array[int] = []
	for index: int in 32:
		lengths.append(32)
	_chain_actor(lengths)
	var actor: Routes.Actor = Routes.Actor.new()
	for tick: int in range(1, 31):
		assert_equal(_routes.advance_tick(tick), 1, "one actual Transform update per tick")
		assert_equal(_routes.read_actor_into(_worker, actor), &"", "exact contained actor")
		@warning_ignore("integer_division") var distance: int = 1024 * tick / 30
		assert_equal(actor.point.x, -512 + distance, "same every-tick position as one long edge")
	assert_equal(actor.phase, Routes.PHASE_IDLE, "same30-tick exact arrival")
	assert_equal(_routes._motion.free_count, 128, "every consumed pooled link returned")


func test_one_unit_spans_can_cross_many_edges_in_a_single_fixed_tick() -> void:
	"""Fine graph metadata does not impose a hidden stop or one-edge-per-tick movement policy."""
	var lengths: Array[int] = []
	for index: int in 64:
		lengths.append(1)
	_chain_actor(lengths)
	_binding.synthetic_pace = 1920
	assert_equal(_routes.advance_tick(1), 1, "64 exact entry/sweep transitions fit one finite tick")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "actual arrival")
	assert_equal(actor.point.x, -448, "all64 units accepted")
	assert_equal(actor.phase, Routes.PHASE_IDLE, "all boundaries consumed at authored pace")


func test_within_tick_pace_changes_preserve_exact_time_and_fractional_distance() -> void:
	"""Two different connector rates use exact spent time, without applying one span's pace to the next."""
	_chain_actor([7, 7, 1010], [0, 1, 2])
	_binding.alternate_paces = PackedInt32Array([300, 600, 900])
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.advance_tick(1), 1, "7/300 seconds plus6/600 seconds is exactly one tick")
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "first mixed rate")
	assert_equal(actor.point.x, -499, "13 exact units in first tick")
	assert_equal(_routes.advance_tick(2), 1, "remaining1/600 then28.5 units at900")
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "second mixed rate")
	assert_equal(actor.point.x, -470, "42 whole units and one-half retained")
	var row: int = _residents.directory().get_typed_row(_worker)
	assert_equal(_routes._motion.resident_long[Routes.R_REMAINDER * Residents.RESIDENT_CAPACITY + row],
		Routes._encode_fraction(1, 2), "exact reduced fractional distance")
	assert_equal(_routes.advance_tick(3), 1, "another exact30 units")
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "fraction survives later ticks")
	assert_equal(actor.point.x, -440, "72.5 total units without rounding the pace ratio")


func test_blocked_next_span_commits_clear_prefix_without_banking_wait_time() -> void:
	"""A resident reaches the safe endpoint, keeps the blocked link and earns no distance while waiting."""
	var refs: Array[Vector2i] = _chain_actor([10, 1014])
	_binding.closed_edge = refs[1]
	assert_equal(_routes.advance_tick(1), 1, "first clear prefix reaches its actual endpoint")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "safe waiting endpoint")
	assert_equal(actor.point.x, -502, "only first10 units")
	assert_equal(actor.edge, NULL_REF, "blocked next span was not entered")
	assert_equal(_routes.advance_tick(2), 0, "closed next span earns nothing")
	assert_equal(_routes.advance_tick(3), 0, "another wait earns nothing")
	_binding.closed_edge = NULL_REF
	assert_equal(_routes.advance_tick(4), 1, "resume at current authored pace")
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "fresh connected entry")
	assert_equal(actor.point.x, -468, "exactly one34-unit resumed tick, no banked blocked time")


func test_next_span_dynamic_turn_refusal_keeps_the_actual_safe_endpoint() -> void:
	"""A static span certificate never bypasses fresh entry turn/body/occupancy proof."""
	var refs: Array[Vector2i] = _chain_actor([10, 1014])
	_binding.motion_closed_edge = refs[1]
	assert_equal(_routes.advance_tick(1), 1, "clear prefix accepted before new dynamic entry refusal")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "safe actual endpoint")
	assert_equal(actor.point.x, -502, "stopped before unqualified next span")
	assert_equal(actor.edge, NULL_REF, "closed entry not retained as occupied")
	_binding.motion_closed_edge = NULL_REF
	assert_equal(_routes.advance_tick(2), 1, "fresh body proof now allows entry")
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "actual continued actor")
	assert_equal(actor.point.x, -468, "no banked remainder from blocked next span")


func test_reduced_motion_fraction_refuses_unrepresentable_or_corrupt_state() -> void:
	"""The existingI64 fraction uses exact positive31-bit lanes; overflow never turns into free movement."""
	assert_equal(_routes._tick_distance(-1, 1024), &"ROUTE_FRACTION_FORMAT", "negative/corrupt encoded state")
	assert_equal(_routes._tick_distance(1 << 32, 1024), &"ROUTE_FRACTION_FORMAT", "missing denominator")
	assert_equal(_routes._tick_distance(Routes._encode_fraction(2, 2), 1024), &"ROUTE_FRACTION_FORMAT", "not sub-unit")
	assert_equal(_routes._tick_distance(0, 31), &"", "31/30 exact initial budget")
	_routes._step.numerator = 1
	_routes._step.denominator = 30
	assert_equal(_routes._rescale_distance(37), &"", "unspent1/30 distance at31 becomes37/930")
	assert_equal(_routes._step.numerator, 37, "reduced numerator")
	assert_equal(_routes._step.denominator, 930, "reduced denominator")
	_routes._step.numerator = 9223372036854775807
	_routes._step.denominator = 1
	_routes._step.pace = 1
	assert_equal(_routes._rescale_distance(2147483647), &"ROUTE_FRACTION_CAPACITY", "checked int64 product refuses")


func test_later_segment_callback_reentry_rejects_the_whole_uncommitted_tick() -> void:
	"""An attempted mutation is not a normal obstacle; a previously clear prefix must not swallow the guard."""
	var first: Vector3i = Vector3i(-512, 0, 512)
	var bend: Vector3i = Vector3i(-502, 0, 512)
	var last: Vector3i = Vector3i(512, 0, 512)
	var origin: Vector2i = _location(first)
	var destination: Vector2i = _location(last)
	_publish_edges([_edge(origin, destination, [first, bend, last])])
	assert_equal(_routes.admit_actor(_worker, NULL_REF, origin, Profiles.MODE_WALK, 0, -1), &"", "actual actor")
	assert_equal(_routes.request_route(_worker, destination, 0), &"", "one exact pooled span")
	_binding.actor_mutation = 4
	assert_equal(_routes.advance_tick(1), 0, "later callback reentry refuses the complete tick")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "original actor remains readable")
	assert_equal(actor.point, first, "no prefix published after callback violation")
	assert_equal(_routes._motion.free_count, LINKS - 1, "queued edge was not consumed or cancelled")
	_binding.actor_mutation = 0
	assert_equal(_routes.advance_tick(2), 1, "current complete proof retries")
	assert_equal(_routes.read_actor_into(_worker, actor), &"", "accepted exact retry")
	assert_equal(actor.point.x, -478, "one current34-unit tick, no failed-time bank")


func test_prepared_metadata_batch_reads_constant_rows_between_full_preflights() -> void:
	"""A1536-edge certificate scan cannot secretly repeat the complete source census for each observation."""
	var refs: Array[Vector2i] = _moving_actor()
	var cold: int = _budget.acquire(COLD_BYTES)
	var token: int = _routes.begin_prepare(cold).token
	assert_equal(_routes.seal(token), &"", "exact staged graph")
	assert_equal(_routes.prepared_refusal(token), &"", "one full initial source/claim check")
	var out: Routes.Edge = Routes.Edge.new()
	out.points = PackedInt32Array([4, 5, 6])
	var counted: CountedSources = _sources as CountedSources
	var reads: int = counted.reads
	for index: int in 1536:
		assert_equal(_routes.prepared_edge_metadata_reused_into(token, refs[2], out), &"", "fixed exact metadata")
	assert_equal(counted.reads, reads, "no hidden source scans or provider callbacks")
	assert_equal(out.ref, refs[2], "full span generation retained")
	assert_equal(out.points, PackedInt32Array([4, 5, 6]), "no polyline copy or resize")
	assert_equal(_routes.prepared_refusal(token), &"", "one full final source/claim check")
	assert_true(counted.reads > reads, "full bracket still performs real source validation")
	assert_true(_routes.abort(token), "discard observation candidate")
	assert_equal(_budget.release(cold), &"", "release real lease")


func test_prepared_metadata_observes_sealed_space_without_repeated_source_reads() -> void:
	"""Actual future section observations use the same sealed full handles and never grant future movement."""
	var refs: Array[Vector2i] = _moving_actor()
	var space_token: int = _owner.begin_stage(_owner.revision()).token
	_region(space_token, [3000, 0, 3000, 3100, 128, 3100], Space.OBSTACLE)
	assert_equal(_owner.seal(space_token), &"", "actual sealed changed geometry")
	var cold: int = _budget.acquire(COLD_BYTES)
	var token: int = _routes.begin_prepare(cold, space_token).token
	assert_equal(_routes.stage_refresh(token, refs[2]), &"", "real future geometry revision")
	assert_equal(_routes.seal(token), &"", "graph after exact future section proof")
	assert_equal(_routes.prepared_refusal(token), &"", "full preflight before observation loop")
	var counted: CountedSources = _sources as CountedSources
	var reads: int = counted.reads
	var out: Routes.Edge = Routes.Edge.new()
	for index: int in 1536:
		assert_equal(_routes.prepared_edge_metadata_reused_into(token, refs[2], out), &"", "future metadata")
	assert_equal(counted.reads, reads, "staged section also copies directly")
	assert_equal(out.geometry_revision, _owner.revision() + 1, "future revision remains explicit")
	assert_equal(_routes.prepared_refusal(token), &"", "full final freshness proof")
	assert_true(_owner.abort(space_token), "future geometry disappeared")
	assert_equal(_routes.prepared_edge_metadata_reused_into(token, refs[2], out),
		&"SPACE_TRANSACTION_UNSEALED", "old graph token cannot observe aborted geometry")
	assert_true(_routes.abort(token), "discard dependent graph")
	assert_equal(_budget.release(cold), &"", "no retained operation")


func test_prepared_metadata_observation_requires_current_tokens_lease_and_full_ref() -> void:
	"""A metadata read is cheap but still cannot alias another namespace or outlive its cold operation."""
	var refs: Array[Vector2i] = _moving_actor()
	var cold: int = _budget.acquire(COLD_BYTES)
	var token: int = _routes.begin_prepare(cold).token
	var out: Routes.Edge = Routes.Edge.new()
	out.level = 913
	assert_equal(_routes.prepared_edge_metadata_reused_into(token, refs[2], out), &"ROUTE_TRANSACTION_STALE", "unsealed")
	assert_equal(_routes.seal(token), &"", "sealed exact candidate")
	assert_equal(_routes.prepared_edge_metadata_reused_into(token + 1, refs[2], out), &"ROUTE_TRANSACTION_STALE", "wrong token")
	assert_equal(_routes.prepared_edge_metadata_reused_into(token, Vector2i(refs[2].x, refs[2].y + 1), out),
		&"ROUTE_EDGE_STALE", "full generation")
	assert_equal(out.level, 913, "refused result untouched")
	assert_equal(_budget.release(cold), &"", "operation loses actual lease")
	var replacement: int = _budget.acquire(COLD_BYTES)
	assert_equal(_routes.prepared_edge_metadata_reused_into(token, refs[2], out), &"ROUTE_TRANSACTION_STALE", "replacement lease cannot alias")
	assert_equal(out.level, 913, "stale lease leaves metadata unchanged")
	assert_true(_routes.abort(token), "discard original graph preparation")
	assert_equal(_budget.release(replacement), &"", "release replacement operation")
