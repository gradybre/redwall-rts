extends "res://test/framework/test_case.gd"
## Actual finite owners and paid accounting. Physical frontier/certificates below are explicit component fixtures.

const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const WorldFixture := preload("res://test/test_underground_world_routes.gd")
const GroupFixture := preload("res://test/test_underground_connector_assemblies.gd")
const BuildingFixture := preload("res://test/test_buildings_spatial.gd")
const ModularFixture := preload("res://test/test_modular_projects.gd")
const PhysicalFixture := preload("res://test/test_excavation_physical.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Groups := preload("res://scripts/core/underground_connector_assemblies.gd")
const Recipes := preload("res://scripts/core/underground_connector_recipes.gd")
const ConnectorCatalog := preload("res://scripts/core/underground_connector_catalog.gd")
const CatalogContent := preload("res://test/test_underground_connector_catalog.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Work := preload("res://scripts/core/work.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const BuildingCatalog := preload("res://scripts/core/catalog.gd")
const SAVE: String = "user://test-connector-placement.bin"
const NULL_REF: Vector2i = Vector2i(-1, 0)

class ObservedSources extends Owner.CoreSources:
	## Negative-only observation probe; every returned fact still comes from the real leaf owner.
	var when: Callable = Callable()
	var probe: Callable = Callable()
	var observed: int = 0

	func read_into(ref: Vector2i, out: Owner.Facts) -> StringName:
		"""Revoke the original lease only at the requested actual source-observation boundary."""
		var code: StringName = super.read_into(ref, out)
		if probe.is_valid() and when.is_valid() and when.call():
			var current: Callable = probe
			probe = Callable()
			when = Callable()
			observed += 1
			current.call()
		return code

class CountedLocationBank extends Locations.Bank:
	var copies: int = 0

	func copy_from(other: Locations.Bank) -> void:
		"""Count the real bank-copy boundary, retaining the actual reserved destination and copy logic."""
		copies += 1
		super.copy_from(other)

class CountedEdgeBank extends Routes.EdgeBank:
	var copies: int = 0

	func copy_from(other: Routes.EdgeBank) -> void:
		"""Count actual graph-bank copying rather than a higher-level entry point that may refuse early."""
		copies += 1
		super.copy_from(other)

class ActualFixture extends WorldFixture:
	## Reuse real complete terrain/store wiring; these metadata/support rows are explicitly synthetic.
	var room_permit: BuildingFixture.Authority = null
	var corridor: Vector2i = NULL_REF
	var corridor_floor: Vector2i = NULL_REF
	var watched_building: Vector2i = NULL_REF
	var other_corridor: Vector2i = NULL_REF
	var other_floor: Vector2i = NULL_REF

	func _actual_space(obstruction: int) -> void:
		"""Create the real Room before endpoint publication, so no stale surface anchor is smuggled through."""
		_space_with_source_probe(obstruction)
		room_permit = BuildingFixture.Authority.new()
		room_permit.owner = weakref(_buildings)
		assert_true(_buildings.bind_spatial_authority(room_permit).ok, "actual Room authority")
		room_permit.allow(Buildings.SPATIAL_ROOM_CREATE, NULL_REF, NULL_REF, Buildings.ROOM_TYPE_CORRIDOR)
		var created: Buildings.OpResult = _buildings.designate_spatial_room(Buildings.ROOM_TYPE_CORRIDOR)
		assert_true(created.ok, "actual permanent Corridor identity")
		corridor = created.ref
		var token: int = _owner.begin_stage(_owner.revision()).token
		assert_equal(_owner.stage_source(token, corridor), &"", "actual Room source registration")
		var building: Buildings.OpResult = _buildings.place_building(int(BuildingCatalog.BUILDING_DEFINITION["well"]), 5 * 128 + 5, 0, 31)
		assert_true(building.ok, "actual distant Building source")
		watched_building = building.ref
		assert_equal(_owner.stage_source(token, watched_building), &"", "actual retained Building source")
		var row: Owner.Region = Owner.Region.new()
		row.owner = corridor
		row.level = 0
		row.role = Space.FLOOR_DATUM
		row.box = PackedInt32Array([X + 4096, 512, Z, X + 8192, 513, Z + 4096])
		var added: Owner.Result = _owner.stage_add(token, row)
		assert_equal(added.error, &"", "actual Room metadata source")
		corridor_floor = added.handle
		_add_other_corridor(token)
		assert_equal(_owner.seal(token), &"", "metadata only")
		_owner.publish(token)

	func _add_other_corridor(token: int) -> void:
		"""A second actual Room lets completion distinguish its own source bump from unrelated stale state."""
		room_permit.allow(Buildings.SPATIAL_ROOM_CREATE, NULL_REF, NULL_REF, Buildings.ROOM_TYPE_CORRIDOR)
		var created: Buildings.OpResult = _buildings.designate_spatial_room(Buildings.ROOM_TYPE_CORRIDOR)
		assert_true(created.ok, "actual second permanent Corridor")
		other_corridor = created.ref
		assert_equal(_owner.stage_source(token, other_corridor), &"", "actual second Room source")
		var row: Owner.Region = Owner.Region.new()
		row.owner = other_corridor
		row.role = Space.FLOOR_DATUM
		row.level = 0
		row.box = PackedInt32Array([X + 8192, 512, Z, X + 12288, 513, Z + 4096])
		var added: Owner.Result = _owner.stage_add(token, row)
		assert_equal(added.error, &"", "actual second Room section")
		other_floor = added.handle

	func _space_with_source_probe(obstruction: int) -> void:
		"""Retain the shared fixture's real stores and geometry, replacing only its negative observation hook."""
		_routes = Routes.new(_residents, _transforms)
		_sources = ObservedSources.new(_residents.directory(), _buildings, _construction, _routes)
		var domain: Space.Domain = Space.Domain.new()
		assert_equal(domain.configure(_world_ref, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
			Vector3i(256, 48, 256), 8192, 6144, Space.MAX_CHECKS), &"", "finite production Domain")
		_owner = Owner.new(_sources)
		assert_equal(_owner.configure(domain, Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY), &"", "actual sparse owner")
		var token: int = _owner.begin_stage(_owner.revision()).token
		_floor = _region(token, PackedInt32Array([X, 512, Z, X + 2048, 513, Z + 2048]), Space.FLOOR_DATUM)
		_fixture_void(token, obstruction)
		_region(token, PackedInt32Array([X, 256, Z, X + 2048, 512, Z + 2048]), Space.SUPPORT)
		assert_equal(_owner.seal(token), &"", "synthetic extents sealed by actual owner")
		_owner.publish(token)
		_locations = RefusingLocations.new()
		assert_equal(_locations.configure(_residents.directory(), _buildings, _transforms, _inventory,
			_owner, _sources, _budget, 8, 228 * 8 + 256), &"", "actual endpoints")
		_terrain = ReenteringTerrain.new()
		assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "actual local exclusions")
		_actual_catalog(domain)

	func after_each() -> void:
		"""Release the actual weakly borrowed authority before the underlying store owners."""
		room_permit = null
		super.after_each()

class TestAuthority extends Placements.Authority:
	## Permission here is labeled synthetic; actual geometry/leases/owners still perform every validation.
	var fixture: WeakRef = null
	var placement_owner: WeakRef = null
	var probe: Callable = Callable()
	var allow_cleanup: bool = false
	var allow_restore: bool = false
	var changed_level: Vector2i = NULL_REF

	func exact_binding(p: RefCounted, space: Owner, locations: Locations, routes: Routes, budget: Budget) -> bool:
		"""Require the exact actual borrowed tuple even in this component fixture."""
		var f: ActualFixture = fixture.get_ref() as ActualFixture
		return p == placement_owner.get_ref() and space == f._owner and locations == f._locations and routes == f._routes and budget == f._budget

	func admission_refusal(_placement: Vector2i, _request: Placements.Request, _token: int) -> StringName:
		"""Only the test harness supplies prospective physical permission; fire a single adversarial observer if armed."""
		if probe.is_valid():
			var current: Callable = probe
			probe = Callable()
			current.call()
		return &""

	func installation_cold_bytes(_placement: Vector2i, _assembly: int) -> int:
		"""The real shared companion implementations require the whole original bounded arena."""
		return Budget.COLD_BYTES

	func stage_installation(_placement: Vector2i, _project: Vector2i, _assembly: int, token: int, _cold: int) -> StringName:
		"""A real sealed new Room-owned support fact exercises source revisions; this is not an authored stair."""
		var f: ActualFixture = fixture.get_ref() as ActualFixture
		var row: Owner.Region = Owner.Region.new()
		row.owner = f.corridor
		row.section = f.corridor_floor
		row.level = 0
		row.role = Space.SUPPORT
		row.box = PackedInt32Array([WorldFixture.X + 4096, 256, WorldFixture.Z, WorldFixture.X + 5120, 512, WorldFixture.Z + 1024])
		if changed_level != NULL_REF:
			f._owner._s_r_level[changed_level.x] += 1 # Hostile candidate mutation; never accepted physical authoring.
		return f._owner.stage_add(token, row).error

	func stage_locations(_placement: Vector2i, _project: Vector2i, _assembly: int, token: int, _cold: int) -> StringName:
		"""Existing complete surface endpoints must freshly qualify against the exact sealed candidate."""
		var f: ActualFixture = fixture.get_ref() as ActualFixture
		var code: StringName = f._locations.stage_refresh(token, f._first)
		return f._locations.stage_refresh(token, f._last) if code == &"" else code

	func stage_routes(_placement: Vector2i, _project: Vector2i, _assembly: int, token: int, _cold: int) -> StringName:
		"""A real concrete ground certificate, with explicitly synthetic loaded profiles, accompanies the install."""
		var f: ActualFixture = fixture.get_ref() as ActualFixture
		var edge: Routes.Edge = f._edge()
		edge.geometry_revision = f._owner._s_header[17]
		return f._routes.stage_add(token, edge).error

	func completion_refusal(_placement: Vector2i, _project: Vector2i, _assembly: int, _cold: int) -> StringName:
		"""A late fault must still occur before real Funding settlement."""
		if probe.is_valid():
			var current: Callable = probe
			probe = Callable()
			current.call()
		return &""

	func retirement_refusal(_placement: Vector2i, _cold: int) -> StringName:
		"""Explicit test cleanup permission does not entitle real production demolition or salvage."""
		return &"" if allow_cleanup else &"TEST_CLEANUP_CLOSED"

	func restoration_refusal(_cold: int) -> StringName:
		"""A coordinated physical restore is mandatory, and this fixture enables it only per test."""
		return &"" if allow_restore else &"TEST_RESTORE_CLOSED"

class TestPublisher extends Placements.Publisher:
	var owner: WeakRef = null

	func exact_binding(candidate: RefCounted, world: Vector2i, construction: Construction) -> bool:
		"""Return true only for the expected actual paid owner composition."""
		var paid: PaidOwner = owner.get_ref() as PaidOwner
		return paid.placements == candidate and paid.world == world and paid.construction == construction

	func publication_refusal(placement: Vector2i, project: Vector2i, assembly: int, action: int) -> StringName:
		"""Observe intent prepayment; actual private Router leaves still guard irreversible publication."""
		var paid: PaidOwner = owner.get_ref() as PaidOwner
		return &"" if paid.subject == placement and paid.project == project and paid.operation == assembly and action == Contract.COMMIT else &"TEST_PUBLISH_SCOPE"

class PaidOwner extends ModularFixture.SyntheticOwner:
	## Real purpose8 Router ownership; accounting facts are read from the actual immutable Recipe.
	var placements: Placements = null
	var assembly_source: Groups = null
	var recipe_source: Recipes = null
	var cold: Budget = null
	var assembly_row: Groups.AssemblyRecord = Groups.AssemblyRecord.new()
	var token: int = 0
	var completion_code: StringName = &""
	var before_publish: Callable = Callable()

	func publish_open(candidate: Vector2i) -> void:
		"""The actual Router's ADMIT tuple is required by both this owner and Placements."""
		super.publish_open(candidate)
		completion_code = placements.attach_order(subject, candidate, operation)

	func prepared_order_into(candidate: Vector2i, kind: int, out: Contract.Quote) -> StringName:
		"""The source grouping chooses the bill anchor; project operation remains the assembly ordinal."""
		if not prepared or candidate != subject or kind != operation:
			return &"TEST_ORDER_SCOPE"
		var code: StringName = placements.candidate_order_refusal(candidate, kind)
		if code == &"":
			code = _actual_bill(out)
		return placements.candidate_order_refusal(candidate, kind) if code == &"" else code

	func project_facts_into(candidate: Vector2i, out: Contract.Quote) -> StringName:
		"""Reuse actual immutable price facts and current Construction work, without a second WU ledger."""
		if candidate != project or placements.order_refusal(subject, candidate, operation) != &"":
			return &"TEST_PROJECT_SCOPE"
		var code: StringName = _actual_bill(out)
		if code == &"":
			construction.remaining_mwu_into(candidate, math)
			out.remaining_mwu = math.value
		return code

	func _actual_bill(out: Contract.Quote) -> StringName:
		"""The complete single synthetic group is quoted through both real immutable readers."""
		var code: StringName = assembly_source.assembly_into(0, 1, GroupFixture.GROUP_REVISION, operation, assembly_row)
		if code == &"":
			code = recipe_source.recipe_into(0, 1, assembly_row.recipe_anchor, GroupFixture.RECIPE_REVISION, out)
		if code == &"":
			out.subject = subject
			out.operation = operation
		return code

	func transition_refusal(candidate: Vector2i, action: int) -> StringName:
		"""The real completed Project prepares all actual companions under one original shared lease."""
		var code: StringName = super.transition_refusal(candidate, action)
		if code == &"" and action == Contract.CANCEL:
			return placements.cancellation_refusal(subject, candidate, operation)
		if code != &"" or action != Contract.COMMIT:
			return code
		var bytes: int = placements.installation_cold_bytes(subject, operation)
		token = cold.acquire(bytes)
		return placements.prepare_completion(subject, candidate, token)

	func final_funding_refusal(candidate: Vector2i, action: int) -> StringName:
		"""All physical observers and pure original pins precede actual Funding's irreversible commit."""
		var code: StringName = super.final_funding_refusal(candidate, action)
		if code != &"":
			return code
		if action == Contract.ACTION_OUTPUT:
			code = placements.completion_refusal(subject, candidate, operation, token)
			return placements.prepared_installation_leaf_refusal(subject, candidate, operation, token) if code == &"" else code
		if action == Contract.ACTION_REFUND:
			return placements.cancellation_refusal(subject, candidate, operation)
		return placements.order_refusal(subject, candidate, operation)

	func publish_completion(candidate: Vector2i) -> void:
		"""No observer follows Funding; the actual Router COMMIT bracket authorizes the complete static tail."""
		completion_saw_paid_clear = not funding.is_funded(candidate)
		if before_publish.is_valid():
			before_publish.call()
		completion_code = placements.publish_completion(subject, candidate, operation, token)
		if completion_code == &"":
			completed += 1
			discard_transition(candidate, Contract.COMMIT)
			project = NULL_REF

	func publish_cancellation(candidate: Vector2i) -> void:
		"""Real refund closes only the current Project; installed prefix and spatial owners remain."""
		completion_code = placements.publish_cancellation(subject, candidate, operation)
		if completion_code == &"":
			super.publish_cancellation(candidate)

	func discard_transition(candidate: Vector2i, action: int) -> void:
		"""Drop only our original candidate before releasing its original lease; replacement leases survive."""
		if action == Contract.COMMIT and candidate == project and token > 0:
			placements.discard_completion(subject, candidate, token)
			if cold.covers(token, 1):
				var code: StringName = cold.release(token)
				assert(code == &"", "original test operation releases after candidates")
			token = 0
		super.discard_transition(candidate, action)

var _f: ActualFixture = null
var _group: GroupFixture = null
var _placements: Placements = null
var _authority: TestAuthority = null
var _publisher: TestPublisher = null
var _paid: PaidOwner = null
var _router: Router = null
var _physical: PhysicalFixture.SpatialFixture = null
var _sites: Sites = null
var _request: Placements.Request = null
var _lease: int = 0
var _store: Vector2i = NULL_REF


func before_each() -> void:
	"""Bind every real source/store before a test may create a Placement; no staged geometry is injected into banks."""
	_f = ActualFixture.new()
	_f._actual_fixture()
	_group = GroupFixture.new()
	_group._catalog = _f._catalog
	_group._items = _f._items
	_group._inventory = _f._inventory
	_group._bind_source(_group._group_wire(1, 1), PackedInt32Array([0]), false, 4)
	assert_equal(_group._load_source(), &"", "actual complete group")
	_placements = Placements.new()
	assert_equal(_placements.configure(4, 8, Placements.required_bytes(4, 8)), &"", "finite admitted two-bank owner")
	assert_equal(_placements.bind_actual(_f._owner, _f._locations, _f._routes, _f._budget,
		_f._catalog, _group._reader, _group._recipes, _f._construction), &"", "complete actual binding")
	_authority = TestAuthority.new()
	_authority.fixture = weakref(_f)
	_authority.placement_owner = weakref(_placements)
	assert_equal(_placements.bind_authority(_authority), &"", "explicit fixture frontier permission")
	_bind_paid()
	_request = _make_request()
	assert_equal(_placements._section_refusal(_request.corridor, _request.section, 0, true), &"", "fixture retained Corridor section")
	assert_true(_f._locations._live_ref(_f._locations._live, _request.anchor), "fixture complete anchor full ref")
	assert_equal(_placements._request_refusal(_request), &"", "fixture actual request identity")
	assert_equal(_f.failures.size(), 0, "inherited actual fixture setup propagates failures: %s" % _f.failures)
	assert_equal(_group.failures.size(), 0, "actual grouping setup propagates failures: %s" % _group.failures)


func _bind_paid() -> void:
	"""Use actual Sites/Funding/Router identity; only physical contact permission is a labeled fixture."""
	_physical = PhysicalFixture.SpatialFixture.new()
	_physical.world = _f._world_ref
	_sites = Sites.new(_f._construction, _f._inventory, _f._pool, _f._items, _f._jobs, _f._work, _physical, 64, 8)
	assert_equal(_sites.initialization_refusal(), &"", "actual Sites owns shared Funding")
	_router = Router.new(_f._construction, _f._inventory, _f._pool, _f._items, _f._jobs, _f._work, _sites)
	assert_equal(_router.initialization_refusal(), &"", "actual Router")
	_paid = PaidOwner.new()
	_paid.construction = _f._construction
	_paid.world = _f._world_ref
	_paid.route = weakref(_router)
	_paid.funding = _sites.funding_owner(_f._construction, _f._inventory, _f._pool, _f._items, _f._jobs, _f._work)
	_paid.purpose_tag = Construction.PURPOSE_CONNECTOR_INSTALL
	_paid.operation = 0
	_paid.placements = _placements
	_paid.assembly_source = _group._reader
	_paid.recipe_source = _group._recipes
	_paid.cold = _f._budget
	_publisher = TestPublisher.new()
	_publisher.owner = weakref(_paid)
	assert_equal(_placements.publisher_binding_refusal(_publisher, _router, _paid), &"", "all observers precede links")
	assert_true(_router.bind_owner(_paid).ok, "actual purpose8 owner")
	assert_equal(_placements.bind_publisher(_publisher, _router, _paid), &"", "pure reciprocal binding tail")


func _make_request() -> Placements.Request:
	"""Exact full refs name real retained metadata and completed approach, never a future Room flag."""
	var request: Placements.Request = Placements.Request.new()
	request.corridor = _f.corridor
	request.section = _f.corridor_floor
	request.anchor = _f._first
	request.origin = Vector3i(WorldFixture.X + 4096, 512, WorldFixture.Z)
	request.level = 0
	for ordinal: int in _placements._opening_count():
		request.targets.append_array(PackedInt32Array([_f.corridor.x, _f.corridor.y, _f.corridor_floor.x, _f.corridor_floor.y]))
	return request


func after_each() -> void:
	"""Drop all observers and their exact weak contexts; the test never leaves a retained shared lease."""
	(_f._sources as ObservedSources).probe = Callable()
	(_f._sources as ObservedSources).when = Callable()
	if _lease > 0 and _f._budget.covers(_lease, 1):
		assert_equal(_f._budget.release(_lease), &"", "exact test lease returned")
	_lease = 0
	if _paid != null and _paid.token > 0:
		_paid.discard_transition(_paid.project, Contract.COMMIT)
	assert_true(_f._inventory.audit().ok, "actual Inventory audit")
	assert_true(_f._pool.audit(_f._inventory).ok, "actual claim audit")
	_request = null
	_publisher = null
	_paid = null
	_router = null
	_sites = null
	_physical = null
	_authority = null
	_placements = null
	_group._reader = null
	_group._recipes = null
	_group._catalog = null
	_group._items = null
	_group._inventory = null
	_group = null
	_f.after_each()
	_f = null
	for path: String in [SAVE, GroupFixture.GROUP_PATH, GroupFixture.RECIPE_PATH, GroupFixture.CATALOG_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _paid_order() -> Vector2i:
	"""Real shared Router allocates purpose8 and Placement attaches only in its actual ADMIT bracket."""
	return _open_registered(_register())


func _open_registered(ref: Vector2i) -> Vector2i:
	"""Open the exact previously admitted Placement through the actual shared purpose8 owner."""
	_paid.subject = ref
	_paid.prepared = true
	var opened: Construction.OpResult = _router.open_order(_paid, _paid.subject, _paid.operation)
	assert_true(opened.ok, "actual purpose8 order: %s" % opened.error)
	assert_equal(_paid.completion_code, &"", "actual Placement attached")
	assert_equal(_placements.order_refusal(_paid.subject, opened.ref, 0), &"", "exact live Project scope")
	return opened.ref


func _paid_worker(project: Vector2i) -> Vector2i:
	"""The existing real resident receives a real Job, schedule, priorities and equipped tool claim."""
	var row: int = _f._residents.directory().get_typed_row(_f._worker)
	assert_true(_f._jobs.priorities().spawn(row).ok, "actual priorities")
	assert_true(_f._jobs.schedule().spawn(row, _f._jobs.schedule().default_template_id().value).ok, "actual schedule")
	assert_true(_f._jobs.schedule().resolve(row, 8, false).ok, "actual work hour")
	assert_true(_f._jobs.spawn_agent(row).ok, "actual worker agent")
	for need: int in Needs.NEED_COUNT:
		var value: int = _f._residents.needs().need_of(row, need).value
		assert_true(_f._residents.needs().apply_need_event(row, need, 5000 - value).ok, "actual base mood")
	_store = _f._inventory.create_container(_f._world_ref, 100000, -1, 0, true).ref
	var tool: Vector2i = _stock(&"tool", 1000)
	assert_true(_f._gear.create_gear(_f._inventory, _f._items, tool, Gear.MANUFACTURE_BASIC).ok, "actual basic tool")
	assert_true(_f._gear.equip(tool, _f._worker).ok, "actual equipment")
	var quote: Contract.Quote = Contract.Quote.new()
	assert_equal(_router.project_facts_into(project, quote), &"", "real recipe supplies exact work")
	var job: Jobs.OpResult = _f._jobs.create_job(quote.job_kind, 1, 0, quote.remaining_mwu, 0)
	assert_true(job.ok, "real Job")
	assert_true(_f._jobs.set_requester(job.value, project).ok, "exact requester")
	assert_true(_f._jobs.set_tool_gate(job.value, Jobs.GATE_SATISFIED).ok, "tool gate")
	assert_true(_router.bind_job(project, job.ref).ok, "actual primary Job")
	assert_true(_f._jobs.assign_worker(row, job.value).ok, "actual assignment")
	assert_true(_f._work.claim_tool_for_work(row, tool).ok, "actual Work tool claim")
	return job.ref


func _stock(key: StringName, quantity: int) -> Vector2i:
	"""Catalogued test stock goes through actual Inventory, never synthetic receipt bytes."""
	var made: Inventory.OpResult = _f._inventory.create_lot(_store, _f._items.compiled_id(key), quantity,
		1, BuildingCatalog.PROVENANCE_ORDINARY, -1, 0, 0)
	assert_true(made.ok, "actual stock")
	return made.ref


func _pay_and_work(project: Vector2i, job: Vector2i) -> void:
	"""Fund exact recipe inputs then finish actual Work ticks; no direct Project work/phase writes."""
	var quote: Contract.Quote = Contract.Quote.new()
	assert_equal(_router.project_facts_into(project, quote), &"", "exact one-group bill")
	assert_true(_router.bind_material_container(project, _store).ok, "actual input contact")
	var lot: Vector2i = _stock(quote.input_keys[0], quote.input_milli[0])
	var claims: PackedInt64Array = PackedInt64Array([lot.x, lot.y, Reservations.PURPOSE_MODULAR_INPUT, quote.input_milli[0], 1000])
	assert_true(_f._pool.claim_batch(job, claims, 1, _f._inventory).ok, "actual reserved bill")
	assert_true(_router.record_deliveries(project).ok, "real credits")
	var started: Construction.OpResult = _router.start_work(project, 100)
	assert_true(started.ok, "real paid start: %s" % started.error)
	for tick: int in 1000:
		_f._construction.remaining_mwu_into(project, _paid.math)
		if _paid.math.value == 0:
			return
		var result: Work.TickResult = _f._work.tick_solo(_f._residents.directory().get_typed_row(job))
		assert_true(result.ok, "real productive tick: %s" % result.error)
		if not result.ok:
			return
	fail("real work did not complete within bounded test duration")


func _register() -> Vector2i:
	"""Every test admission runs the actual finite owner path with the real original Budget token."""
	_lease = _f._budget.acquire(Budget.COLD_BYTES)
	var result: Placements.Result = _placements.register(_request, _lease)
	assert_equal(result.error, &"", "actual Placement registration: %s" % result.error)
	assert_equal(_f._budget.release(_lease), &"", "registration scratch drops")
	_lease = 0
	return result.placement


func test_actual_source_registration_copies_full_identity_without_building_geometry() -> void:
	"""Identity registration creates no cut, support, route or free installed prefix."""
	var before: PackedByteArray = _f._owner.state_bytes()
	var ref: Vector2i = _register()
	var out: Placements.OrderRecord = Placements.OrderRecord.new()
	assert_equal(_placements.placement_into(ref, out), &"", "actual current record")
	assert_equal(out.corridor, _f.corridor, "full permanent Room")
	assert_equal(out.installed_count, 0, "no free assembly")
	assert_equal(out.project, NULL_REF, "no fabricated Project")
	assert_equal(_f._owner.state_bytes(), before, "registration has no physical side effect")
	assert_equal(_placements.audit(), &"", "complete row/opening/source audit")


func test_frame_reader_copies_exact_existing_tuple_without_observers_or_aliases() -> void:
	"""A caller gets transform identity only; the uninstalled source still grants no assembly contact."""
	var ref: Vector2i = _register()
	var out: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
	var expected: PackedInt32Array = PackedInt32Array([_request.origin.x, _request.origin.y, _request.origin.z,
		_request.rotation, _request.level, _request.section.x, _request.section.y, _request.anchor.x, _request.anchor.y])
	var source: ObservedSources = _f._sources as ObservedSources
	var observed: int = source.observed
	source.when = func() -> bool: return true
	source.probe = func() -> void: _f._binding._catalog = null
	assert_equal(_placements.placement_frame_into(ref, out), &"", "exact current frame")
	assert_equal(out, expected, "all nine scalar fields")
	assert_equal(source.observed, observed, "no Source observation")
	out[0] += 1
	assert_equal(_placements.placement_frame_into(ref, out), &"", "caller edit cannot change source")
	assert_equal(out, expected, "no bank alias escaped")
	assert_equal(_placements._get32(_placements._live, Placements.INSTALLED, ref.x), 0, "no free prefix")
	source.probe = Callable()
	source.when = Callable()


func test_frame_reader_preserves_output_for_shape_generation_and_actual_source_drift() -> void:
	"""Same numerical catalog revision or local slot cannot substitute for the bound actual source identity."""
	var ref: Vector2i = _register()
	var out: PackedInt32Array = PackedInt32Array([81, 82, 83, 84, 85, 86, 87, 88, 89])
	var before: PackedInt32Array = out.duplicate()
	var short: PackedInt32Array = PackedInt32Array([7, 8])
	assert_equal(_placements.placement_frame_into(ref, short), &"PLACEMENT_OUTPUT_SHAPE", "fixed output only")
	assert_equal(short, PackedInt32Array([7, 8]), "shape refusal preserves caller scratch")
	assert_equal(_placements.placement_frame_into(Vector2i(ref.x, ref.y + 1), out), Placements.REFUSE_STALE, "full generation")
	assert_equal(out, before, "stale generation preserves all fields")
	var other: ConnectorCatalog = _second_catalog()
	_f._binding._catalog = other
	assert_equal(_placements.placement_frame_into(ref, out), Placements.REFUSE_STALE, "actual source tuple")
	assert_equal(out, before, "no partially copied transform")
	_f._binding._catalog = _f._catalog
	var row: int = _f._residents.directory().get_typed_row(_f.corridor)
	_f._buildings._r_type[row] = Buildings.ROOM_TYPE_KITCHEN
	assert_equal(_placements.placement_frame_into(ref, out), Placements.REFUSE_STALE, "actual Room purpose drift")
	assert_equal(out, before, "source drift preserves output")
	_f._buildings._r_type[row] = Buildings.ROOM_TYPE_CORRIDOR
	assert_equal(_placements.placement_frame_into(ref, out), &"", "exact binding can retry")


func test_stream_capture_restore_is_bounded_and_authority_is_mandatory() -> void:
	"""The wire roundtrip uses one window and existing inactive bank; refusal preserves live hash."""
	_register()
	_lease = _f._budget.acquire(Budget.COLD_BYTES)
	var before: String = _placements.state_hash(_lease)
	assert_equal(_placements.capture_file(SAVE, _lease), &"", "stream exact canonical file")
	assert_equal(_placements.captured_hash(), before, "hash and capture same canonical order")
	assert_equal(FileAccess.open(SAVE, FileAccess.READ).get_length(), _placements.wire_bytes(), "exact fixed wire size")
	assert_equal(_placements.restore_file(SAVE, before, _lease), &"TEST_RESTORE_CLOSED", "restore requires physical owner")
	assert_equal(_placements.state_hash(_lease), before, "refused restore is byte equivalent")
	_authority.allow_restore = true
	assert_equal(_placements.restore_file(SAVE, before, _lease), &"", "coordinated exact image restore")
	assert_equal(_placements.state_hash(_lease), before, "same canonical bytes")
	assert_true(_placements._stream.size() <= Placements.STREAM_BYTES, "no full wire retention")


func test_registration_replaced_lease_preserves_new_lease_and_empty_state() -> void:
	"""An equal-size replacement cannot authorize the allocation that the original caller requested."""
	_lease = _f._budget.acquire(Budget.COLD_BYTES)
	var original: int = _lease
	_authority.probe = func() -> void:
		assert_equal(_f._budget.release(original), &"", "observer revokes original")
		_lease = _f._budget.acquire(Budget.COLD_BYTES)
	var result: Placements.Result = _placements.register(_request, original)
	assert_true(result.error != &"", "exact original lease refuses")
	assert_true(_f._budget.covers(_lease, Budget.COLD_BYTES), "replacement is preserved")
	assert_equal(_placements._live.header[Placements.H_COUNT], 0, "no partial identity")


func test_retirement_requires_cleanup_and_reuses_full_generation() -> void:
	"""Paid prefixes are never refunded or demolished by local allocator reuse."""
	var first: Vector2i = _register()
	_lease = _f._budget.acquire(Budget.COLD_BYTES)
	assert_equal(_placements.retire(first, _lease), &"TEST_CLEANUP_CLOSED", "actual cleanup mandatory")
	_authority.allow_cleanup = true
	assert_equal(_placements.retire(first, _lease), &"", "explicit fixture cleanup")
	var next: Placements.Result = _placements.register(_request, _lease)
	assert_equal(next.error, &"", "same finite slot reused")
	assert_equal(next.placement.x, first.x, "deterministic free row")
	assert_true(next.placement.y > first.y, "new full generation")
	var out: Placements.OrderRecord = Placements.OrderRecord.new()
	out.installed_count = 123
	assert_true(_placements.placement_into(first, out) != &"", "old handle cannot alias")
	assert_equal(out.installed_count, 123, "refused output unchanged")


func test_actual_paid_completion_commits_all_companions_once_without_postpayment_observers() -> void:
	"""Real Funding/Work and callback-free Space/Locations/Routes publication advance one billed assembly."""
	var project: Vector2i = _paid_order()
	var job: Vector2i = _paid_worker(project)
	_pay_and_work(project, job)
	var revision: int = _f._owner.revision()
	var done: Construction.OpResult = _router.complete_order(project)
	assert_true(done.ok, "actual completion: %s / %s" % [done.error, _paid.completion_code])
	assert_equal(_paid.completion_code, &"", "static paid publication")
	assert_true(_paid.completion_saw_paid_clear, "receipt settled before physical publication")
	assert_equal(_f._owner.revision(), revision + 1, "one actual geometry publication")
	assert_true(_f._budget.is_quiescent(), "all prepared scratch and original lease returned")
	var out: Placements.OrderRecord = Placements.OrderRecord.new()
	assert_equal(_placements.placement_into(_paid.subject, out), &"", "current exact placed assembly")
	assert_equal(out.installed_count, 1, "one billed group, not its individual prisms")
	assert_equal(out.project, NULL_REF, "project cleared only after companion publication")
	assert_false(_f._construction.is_live_project(project), "actual Router retires paid Project")
	assert_true(_f._binding.static_profile_edge_refusal(Vector2i(0, 1), 0, 1, 1) == &"", "actual committed profile certificate")
	assert_false(_router.complete_order(project).ok, "no duplicate charge or prefix")


func _finished_order() -> Vector2i:
	"""Complete actual materials/labor but leave Funding's output and all physical publication pending."""
	var project: Vector2i = _paid_order()
	var job: Vector2i = _paid_worker(project)
	_pay_and_work(project, job)
	return project


func _assert_uninstalled(project: Vector2i, geometry: PackedByteArray, inventory: PackedByteArray) -> void:
	"""A refused final observer cannot spend WIP, publish support or advance the paid prefix."""
	assert_equal(_f._owner.state_bytes(), geometry, "authoritative geometry unchanged")
	assert_equal(_f._inventory.state_bytes(), inventory, "actual paid Inventory unchanged")
	assert_true(_paid.funding.is_funded(project), "original WIP remains paid and retryable")
	var out: Placements.OrderRecord = Placements.OrderRecord.new()
	assert_equal(_placements.placement_into(_paid.subject, out), &"", "actual current placement")
	assert_equal(out.installed_count, 0, "no installed prefix")
	assert_equal(out.project, project, "retained exact paid Project")


func test_final_observer_replaced_budget_refuses_before_funding_and_preserves_replacement() -> void:
	"""Same-sized foreign lease cannot inherit prepared Space/Locations/Routes or a paid prefix."""
	var project: Vector2i = _finished_order()
	var geometry: PackedByteArray = _f._owner.state_bytes()
	var inventory: PackedByteArray = _f._inventory.state_bytes()
	_authority.probe = func() -> void:
		assert_equal(_f._budget.release(_paid.token), &"", "revoke original actual lease")
		_lease = _f._budget.acquire(Budget.COLD_BYTES)
	assert_false(_router.complete_order(project).ok, "final original-token proof refuses")
	_assert_uninstalled(project, geometry, inventory)
	assert_true(_f._budget.covers(_lease, Budget.COLD_BYTES), "replacement is not released by failed caller")
	assert_equal(_f._budget.release(_lease), &"", "test-owned replacement cleanup")
	_lease = 0
	assert_true(_router.complete_order(project).ok, "fresh explicit retry succeeds")


func test_final_actual_building_drift_refuses_without_spending_then_retries() -> void:
	"""An actual retained source can change without a geometry revision; static leaf facts close that hole."""
	var project: Vector2i = _finished_order()
	var geometry: PackedByteArray = _f._owner.state_bytes()
	var inventory: PackedByteArray = _f._inventory.state_bytes()
	var interior: int = _f._buildings.interior_id_of_building(_f.watched_building).value
	_authority.probe = func() -> void:
		assert_true(_f._buildings.set_building_interior_id(_f.watched_building, interior + 1).ok, "actual late source mutation")
	assert_false(_router.complete_order(project).ok, "actual source drift refuses")
	_assert_uninstalled(project, geometry, inventory)
	assert_true(_f._buildings.set_building_interior_id(_f.watched_building, interior).ok, "restore actual prior facts for retry")
	assert_true(_router.complete_order(project).ok, "new whole proof after source repair")


func test_prepaid_observer_cannot_use_generic_or_static_paid_publication() -> void:
	"""Possessing the actual prepared token is insufficient before the actual Router COMMIT window."""
	var project: Vector2i = _finished_order()
	var revision: int = _f._owner.revision()
	_authority.probe = func() -> void:
		var ctx: Locations.InstallationContext = _placements._context
		_f._owner.publish(ctx.space_token)
		assert_equal(_f._owner.revision(), revision, "generic entry refuses installation token")
		assert_false(Owner.commit_preflighted(_f._owner, ctx.space_token, ctx.base_revision, ctx.target_revision), "static entry requires actual paid window")
		assert_false(Locations.publish_installation(_f._locations, ctx), "endpoints require actual paid window")
		assert_false(WorldRoutes.publish_installation(_f._binding, ctx), "graph cannot publish prepayment")
		assert_true(_f._binding.publish(ctx.route_token) != &"", "ordinary certificate publisher refuses paid context")
		assert_true(_f._routes.publish(ctx.route_token) != &"", "ordinary graph publisher refuses paid context")
	assert_true(_router.complete_order(project).ok, "real later same-stack paid publication succeeds")
	assert_equal(_f._owner.revision(), revision + 1, "exactly one actual publication")


func test_postpayment_tail_uses_no_source_endpoint_or_binding_observers() -> void:
	"""Negative-only observers armed after Funding cannot run anywhere in the paid static tail."""
	var project: Vector2i = _finished_order()
	_paid.before_publish = func() -> void:
		_f._locations.refuse_live_read = true
		_f._terrain.binding_countdown = 1
		_f._terrain.binding_probe = func() -> void: fail("postpayment Terrain observer must not run")
	assert_true(_router.complete_order(project).ok, "static tail succeeds without ordinary observations")
	assert_equal(_paid.completion_code, &"", "all static companions published")
	assert_equal(_f._terrain.binding_probe_count, 0, "no source callback after Funding")
	_f._terrain.binding_probe = Callable()
	_f._terrain.binding_countdown = 0
	_f._locations.refuse_live_read = false
	_paid.before_publish = Callable()


func test_final_reentry_poison_preserves_payment_and_permits_new_retry() -> void:
	"""Nested actual completion cannot clear the outer original candidates or overwrite its request."""
	var project: Vector2i = _finished_order()
	var geometry: PackedByteArray = _f._owner.state_bytes()
	var inventory: PackedByteArray = _f._inventory.state_bytes()
	_authority.probe = func() -> void:
		assert_equal(_placements.prepare_completion(_paid.subject, project, _paid.token), Placements.REFUSE_BUSY, "nested preparation refuses")
	assert_false(_router.complete_order(project).ok, "poisoned outer operation refuses before payment")
	_assert_uninstalled(project, geometry, inventory)
	assert_true(_router.complete_order(project).ok, "independent new attempt remains available")


func test_constructor_and_opening_exhaustion_refuse_without_growing_any_bank() -> void:
	"""Actual configured technical arenas, rather than a room policy cap, bound registration atomically."""
	var rejected: Placements = Placements.new()
	assert_equal(rejected.configure(256, 512, Placements.required_bytes(256, 512) - 1), Placements.REFUSE_CAPACITY, "all simultaneous bytes admitted first")
	assert_equal(rejected._live.i32.size(), 0, "refusal before any row allocation")
	assert_equal(Placements.required_bytes(257, 512), 0, "finite ceiling")
	for ordinal: int in 4:
		var ref: Vector2i = _register()
		assert_equal(ref.x, ordinal, "ascending actual free slots")
	_lease = _f._budget.acquire(Budget.COLD_BYTES)
	var before: String = _placements.state_hash(_lease)
	assert_equal(_placements.register(_request, _lease).error, Placements.REFUSE_CAPACITY, "entire request refused at exact capacity")
	assert_equal(_placements.state_hash(_lease), before, "no truncated opening set or changed generations")
	assert_equal(_placements._live.free_rows.size(), 4, "configured bank never grows")
	assert_equal(_placements.audit(), &"", "complete pool audit")


func test_streamed_hostile_transform_and_generation_preserve_live_state() -> void:
	"""A correct file digest does not make hostile canonical fields valid or resize the inactive bank."""
	_register()
	_lease = _f._budget.acquire(Budget.COLD_BYTES)
	var before: String = _placements.state_hash(_lease)
	assert_equal(_placements.capture_file(SAVE, _lease), &"", "baseline canonical image")
	var file: FileAccess = FileAccess.open(SAVE, FileAccess.READ)
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	_authority.allow_restore = true
	bytes.encode_s32(Placements.BANK_HEADER_BYTES + 4 * Placements.ROTATION * 4, 4)
	var digest: String = _write_corrupt_image(bytes)
	assert_equal(_placements.restore_file(SAVE, digest, _lease), &"PLACEMENT_STATE_TRANSFORM", "unadmitted rotation refuses")
	assert_equal(_placements.state_hash(_lease), before, "rotation refusal preserves exact live bytes")
	bytes.encode_s32(Placements.BANK_HEADER_BYTES + 4 * Placements.ROTATION * 4, 0)
	bytes.encode_s32(Placements.BANK_HEADER_BYTES, 0)
	digest = _write_corrupt_image(bytes)
	assert_true(_placements.restore_file(SAVE, digest, _lease) != &"", "live generation zero refuses")
	assert_equal(_placements.state_hash(_lease), before, "generation refusal preserves exact live bytes")
	assert_equal(_placements._stage.i32.size(), Placements.I32_FIELDS * 4, "no wire-derived capacity growth")


func _write_corrupt_image(bytes: PackedByteArray) -> String:
	"""Only this test-owned path is replaced; a valid digest isolates canonical validation from hash refusal."""
	var file: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	return digest.finish().hex_encode()


func test_refund_clears_only_project_and_never_installs_or_erases_geometry() -> void:
	"""Actual paid cancellation follows the shared refund rule and allows a new full Project generation."""
	var project: Vector2i = _finished_order()
	var geometry: PackedByteArray = _f._owner.state_bytes()
	var result: Construction.OpResult = _router.cancel_order(project, _store)
	assert_true(result.ok, "actual shared cancellation: %s" % result.error)
	assert_equal(_paid.completion_code, &"", "actual cancel publication")
	var out: Placements.OrderRecord = Placements.OrderRecord.new()
	assert_equal(_placements.placement_into(_paid.subject, out), &"", "current uninstalled placement")
	assert_equal(out.installed_count, 0, "cancellation installs nothing")
	assert_equal(out.project, NULL_REF, "only project cleared")
	assert_equal(_f._owner.state_bytes(), geometry, "no demolition or free support")
	assert_false(_f._construction.is_live_project(project), "actual refunded Project retired")
	assert_equal(_placements.candidate_order_refusal(_paid.subject, 0), &"", "same next assembly remains available")


func test_mutated_installation_packet_cannot_substitute_original_project_or_token() -> void:
	"""Private original scalar pins prevent observers from rewriting the shared companion context."""
	var project: Vector2i = _finished_order()
	var geometry: PackedByteArray = _f._owner.state_bytes()
	var inventory: PackedByteArray = _f._inventory.state_bytes()
	_authority.probe = func() -> void:
		_placements._context.project += Vector2i(0, 1)
	assert_false(_router.complete_order(project).ok, "mutable packet mismatch refuses before settlement")
	_assert_uninstalled(project, geometry, inventory)
	assert_true(_router.complete_order(project).ok, "fresh original context retries")


func test_replaced_location_candidate_survives_failed_original_publication() -> void:
	"""An aborted endpoint token cannot be replaced at the same target revision to inherit the prepared proof."""
	var project: Vector2i = _finished_order()
	var inventory: PackedByteArray = _f._inventory.state_bytes()
	var replacement: PackedInt32Array = PackedInt32Array([0])
	_authority.probe = func() -> void:
		var ctx: Locations.InstallationContext = _placements._context
		assert_true(_f._locations.abort(ctx.location_token), "abort original actual endpoint candidate")
		var made: Locations.Result = _f._locations.begin_installation_prepare(ctx)
		assert_equal(made.error, &"", "same Space and original lease permit separate new candidate")
		replacement[0] = made.token
	assert_false(_router.complete_order(project).ok, "old proof cannot publish replacement")
	assert_equal(_f._locations._token, replacement[0], "foreign new candidate remains caller-owned")
	assert_equal(_f._inventory.state_bytes(), inventory, "Funding preserved")
	assert_true(_f._locations.abort(replacement[0]), "test discards its own candidate")
	assert_true(_router.complete_order(project).ok, "new full proof can retry")


func _arm_copy_lease_replacement(endpoint: bool) -> void:
	"""Select the ordinary actual source callback immediately before the chosen companion bank copy."""
	var sources: ObservedSources = _f._sources as ObservedSources
	sources.when = func() -> bool:
		return _f._locations._in_retention and _f._locations._token == 0 if endpoint \
			else _f._routes._in_callback and _f._routes._token == 0
	sources.probe = func() -> void:
		assert_equal(_f._budget.release(_paid.token), &"", "source observer revokes original")
		_lease = _f._budget.acquire(Budget.COLD_BYTES)


func test_source_lease_replacement_precedes_location_bank_copy() -> void:
	"""No endpoint bank copy can occur under a same-size replacement discovered in actual source preflight."""
	var project: Vector2i = _finished_order()
	var geometry: PackedByteArray = _f._owner.state_bytes()
	var inventory: PackedByteArray = _f._inventory.state_bytes()
	var counted: CountedLocationBank = CountedLocationBank.new()
	counted.allocate(_f._locations._capacity)
	_f._locations._stage = counted
	_arm_copy_lease_replacement(true)
	assert_false(_router.complete_order(project).ok, "original endpoint lease refuses")
	assert_equal((_f._sources as ObservedSources).observed, 1, "actual source callback ran")
	assert_equal(counted.copies, 0, "refusal before endpoint bank copy")
	_assert_uninstalled(project, geometry, inventory)
	assert_true(_f._budget.covers(_lease, Budget.COLD_BYTES), "new lease remains owned by test")
	assert_equal(_f._budget.release(_lease), &"", "test releases only its replacement")
	_lease = 0
	assert_true(_router.complete_order(project).ok, "fresh exact lease retries")
	assert_equal(counted.copies, 1, "successful retry copies exactly once")


func test_source_lease_replacement_precedes_route_bank_copy() -> void:
	"""Already-sealed endpoints do not authorize graph copying after its original lease is revoked."""
	var project: Vector2i = _finished_order()
	var geometry: PackedByteArray = _f._owner.state_bytes()
	var inventory: PackedByteArray = _f._inventory.state_bytes()
	var counted: CountedEdgeBank = CountedEdgeBank.new()
	counted.allocate(_f._routes._edge_capacity, _f._routes._vertex_capacity)
	_f._routes._stage = counted
	_arm_copy_lease_replacement(false)
	assert_false(_router.complete_order(project).ok, "original graph lease refuses")
	assert_equal((_f._sources as ObservedSources).observed, 1, "actual source callback ran")
	assert_equal(counted.copies, 0, "refusal before graph bank copy")
	_assert_uninstalled(project, geometry, inventory)
	assert_true(_f._budget.covers(_lease, Budget.COLD_BYTES), "replacement survives exact cleanup")
	assert_equal(_f._budget.release(_lease), &"", "test releases only its replacement")
	_lease = 0
	assert_true(_router.complete_order(project).ok, "new complete proof retries")
	assert_equal(counted.copies, 1, "one actual graph copy")


func test_final_leaf_precharges_capacity_scans_before_reading_sources() -> void:
	"""An unaffordable source/companion census refuses before the first scratch fact is rewritten."""
	var project: Vector2i = _finished_order()
	_authority.probe = func() -> void:
		var checks: int = _f._owner._domain._checks
		_f._owner._domain._checks = 1
		_f._owner._facts.a = 98765
		assert_equal(_placements.prepared_installation_leaf_refusal(_paid.subject, project, 0, _paid.token),
			&"PLACEMENT_SOURCE_CHECK_CAPACITY", "census precharged before source reads")
		assert_equal(_f._owner._facts.a, 98765, "no leaf source wrote reused facts")
		_f._owner._domain._checks = checks
	assert_true(_router.complete_order(project).ok, "properly admitted enclosing operation still succeeds")


func _capture_bytes() -> PackedByteArray:
	"""Test-owned canonical bytes isolate hostile state validation from digest corruption."""
	assert_equal(_placements.capture_file(SAVE, _lease), &"", "capture actual current fields")
	var file: FileAccess = FileAccess.open(SAVE, FileAccess.READ)
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return bytes


func _load_revision(revision: int) -> void:
	"""Exercise the real canonical decoder and inactive-bank validation for an admitted near-exhaustion state."""
	_lease = _f._budget.acquire(Budget.COLD_BYTES)
	var bytes: PackedByteArray = _capture_bytes()
	bytes.encode_s64(8 * Placements.H_REVISION, revision)
	_authority.allow_restore = true
	assert_equal(_placements.restore_file(SAVE, _write_corrupt_image(bytes), _lease), &"", "valid revision image")
	assert_equal(_f._budget.release(_lease), &"", "restore original lease released")
	_lease = 0


func test_admit_requires_revision_for_both_identity_attach_and_terminal_transition() -> void:
	"""A valid idle near-exhausted wire cannot create an actual Project that can never complete or refund."""
	var ref: Vector2i = _register()
	_load_revision(9223372036854775806)
	_paid.subject = ref
	_paid.prepared = true
	var directory: PackedByteArray = _f._residents.directory().state_bytes()
	var inventory: PackedByteArray = _f._inventory.state_bytes()
	assert_equal(_placements.candidate_order_refusal(ref, 0), Placements.REFUSE_CAPACITY, "terminal headroom required")
	var opened: Construction.OpResult = _router.open_order(_paid, ref, 0)
	assert_false(opened.ok, "real Router refuses before Project identity")
	assert_equal(opened.error, Placements.REFUSE_CAPACITY, "pure capacity refusal propagates")
	assert_equal(_f._residents.directory().state_bytes(), directory, "no Directory/PID mutation")
	assert_equal(_f._inventory.state_bytes(), inventory, "no payment or claim mutation")
	assert_equal(_placements._live.header[Placements.H_ACTIVE_ORDERS], 0, "no orphan project count")


func test_all_mutations_preserve_active_order_terminal_revision_reservation() -> void:
	"""Registration/retirement cannot consume the last increment reserved for a real active paid Project."""
	var first: Vector2i = _register()
	var other: Vector2i = _register()
	_load_revision(9223372036854775805)
	var project: Vector2i = _open_registered(first)
	assert_equal(_placements._live.header[Placements.H_ACTIVE_ORDERS], 1, "one actual Project reserve")
	_lease = _f._budget.acquire(Budget.COLD_BYTES)
	_authority.allow_cleanup = true
	assert_equal(_placements.register(_request, _lease).error, Placements.REFUSE_CAPACITY, "registration preserves terminal reserve")
	assert_equal(_placements.retire(other, _lease), Placements.REFUSE_CAPACITY, "retirement preserves terminal reserve")
	assert_equal(_placements.candidate_order_refusal(other, 0), Placements.REFUSE_CAPACITY, "another order cannot borrow reserve")
	assert_equal(_f._budget.release(_lease), &"", "test scratch returned")
	_lease = 0
	var job: Vector2i = _paid_worker(project)
	_pay_and_work(project, job)
	assert_true(_router.complete_order(project).ok, "reserved terminal increment permits actual paid completion")
	assert_equal(_placements._live.header[Placements.H_REVISION], 9223372036854775807, "last exact increment")
	assert_equal(_placements._live.header[Placements.H_ACTIVE_ORDERS], 0, "no unpaid future obligation")
	assert_equal(_placements.audit(), &"", "completed exhausted state is canonical")


func test_streamed_active_exhaustion_and_false_active_count_preserve_live_project() -> void:
	"""Loader rederives the complete linked Project census and refuses impossible terminal capacity."""
	var project: Vector2i = _paid_order()
	_lease = _f._budget.acquire(Budget.COLD_BYTES)
	var before: String = _placements.state_hash(_lease)
	var bytes: PackedByteArray = _capture_bytes()
	var revision: int = _placements._live.header[Placements.H_REVISION]
	_authority.allow_restore = true
	bytes.encode_s64(8 * Placements.H_REVISION, 9223372036854775807)
	assert_equal(_placements.restore_file(SAVE, _write_corrupt_image(bytes), _lease), &"PLACEMENT_STATE_REVISION", "active-at-MAX refuses")
	assert_equal(_placements.state_hash(_lease), before, "live Project preserved")
	bytes.encode_s64(8 * Placements.H_REVISION, revision)
	bytes.encode_s64(8 * Placements.H_ACTIVE_ORDERS, 0)
	assert_equal(_placements.restore_file(SAVE, _write_corrupt_image(bytes), _lease), &"PLACEMENT_STATE_COUNT", "header must match actual Project list")
	assert_equal(_placements.state_hash(_lease), before, "false census refuses atomically")
	assert_equal(_placements.order_refusal(_paid.subject, project, 0), &"", "real old Project still valid")


func test_refund_preflight_refuses_exhaustion_before_actual_inventory_settlement() -> void:
	"""A late invalid capacity observation cannot refund and retire while leaving a stale Placement link."""
	var project: Vector2i = _finished_order()
	var before: PackedByteArray = _f._inventory.state_bytes()
	var revision: int = _placements._live.header[Placements.H_REVISION]
	_placements._live.header[Placements.H_REVISION] = 9223372036854775807
	assert_equal(_placements.cancellation_refusal(_paid.subject, project, 0), Placements.REFUSE_CAPACITY, "pure cancellation capacity guard")
	assert_false(_router.cancel_order(project, _store).ok, "real refund refuses before settlement")
	assert_equal(_f._inventory.state_bytes(), before, "actual WIP and lot bytes unchanged")
	assert_true(_f._construction.is_live_project(project), "live identity not retired")
	assert_true(_paid.funding.is_funded(project), "funded receipt survives")
	_placements._live.header[Placements.H_REVISION] = revision
	assert_true(_router.cancel_order(project, _store).ok, "restored valid original count can refund")
	assert_equal(_placements._live.header[Placements.H_ACTIVE_ORDERS], 0, "terminal reservation released exactly once")


func _second_catalog() -> ConnectorCatalog:
	"""Load a distinct genuine geometry bank at coincident revisions over the same actual profile/level stores."""
	var other: ConnectorCatalog = ConnectorCatalog.new()
	assert_equal(other.configure(ConnectorCatalog.RESERVED_BYTES), &"", "second actual source allocation")
	assert_equal(other.bind_actual(_f._profiles, _f._levels, _f._movement, _f._residents,
		_f._transforms, _f._owner._domain), &"", "same real profile and World owners")
	var bytes: PackedByteArray = GroupFixture._catalog_wire(2)
	assert_equal(other.load_file(GroupFixture.CATALOG_PATH, CatalogContent._write(GroupFixture.CATALOG_PATH, bytes), 1),
		&"", "different complete geometry, equal revision")
	assert_true(other._live.digests != _f._catalog._live.digests, "different actual geometry digest")
	return other


func test_foreign_actual_catalog_group_recipe_cannot_bind_existing_route_provider() -> void:
	"""A complete second immutable tuple is not the catalog used by actual installed route certificates."""
	var other: ConnectorCatalog = _second_catalog()
	var group: GroupFixture = GroupFixture.new()
	group._catalog = other
	group._items = _f._items
	group._inventory = _f._inventory
	group._bind_source(group._group_wire(1, 2), PackedInt32Array([0]), false, 4)
	assert_equal(group._load_source(), &"", "actual alternate grouping/recipe tuple")
	assert_equal(group.failures.size(), 0, "fixture failures propagated")
	var rejected: Placements = Placements.new()
	assert_equal(rejected.configure(4, 8, Placements.required_bytes(4, 8)), &"", "fresh admitted owner")
	assert_equal(rejected.bind_actual(_f._owner, _f._locations, _f._routes, _f._budget,
		other, group._reader, group._recipes, _f._construction), Placements.REFUSE_SOURCE, "exact route Catalog identity required")
	assert_false(rejected._ready, "no partial binding")
	assert_equal(rejected._live.header[Placements.H_REVISION], 0, "immutable pins were not published")
	assert_equal(rejected.bind_actual(_f._owner, _f._locations, _f._routes, _f._budget,
		_f._catalog, _group._reader, _group._recipes, _f._construction), &"", "valid actual tuple retries")


func test_late_route_catalog_rewire_refuses_before_payment_and_geometry() -> void:
	"""Even a real same-revision replacement cannot split billed source from prepared route content."""
	var project: Vector2i = _finished_order()
	var geometry: PackedByteArray = _f._owner.state_bytes()
	var inventory: PackedByteArray = _f._inventory.state_bytes()
	var other: ConnectorCatalog = _second_catalog()
	_authority.probe = func() -> void: _f._binding._catalog = other
	assert_false(_router.complete_order(project).ok, "late actual provider rewire refuses")
	_f._binding._catalog = _f._catalog
	_assert_uninstalled(project, geometry, inventory)
	assert_true(_router.complete_order(project).ok, "restored exact original composition retries")


func _register_other_corridor(opening_only: bool) -> Vector2i:
	"""Register a real unrelated Corridor target while preserving the active paid Placement request."""
	var request: Placements.Request = _make_request()
	if not opening_only:
		request.corridor = _f.other_corridor
		request.section = _f.other_floor
		request.origin.x += 4096
	for ordinal: int in _placements._opening_count():
		request.targets[4 * ordinal] = _f.other_corridor.x
		request.targets[4 * ordinal + 1] = _f.other_corridor.y
		request.targets[4 * ordinal + 2] = _f.other_floor.x
		request.targets[4 * ordinal + 3] = _f.other_floor.y
	_lease = _f._budget.acquire(Budget.COLD_BYTES)
	var added: Placements.Result = _placements.register(request, _lease)
	assert_equal(added.error, &"", "actual retained other target")
	assert_equal(_f._budget.release(_lease), &"", "test registration lease released")
	_lease = 0
	return added.placement


func _change_other_corridor_source() -> void:
	"""Publish a genuine unrelated Room-owned fact, making only its retained Placement pins stale."""
	var token: int = _f._owner.begin_stage(_f._owner.revision()).token
	var row: Owner.Region = Owner.Region.new()
	row.owner = _f.other_corridor
	row.section = _f.other_floor
	row.level = 0
	row.role = Space.SUPPORT
	row.box = PackedInt32Array([WorldFixture.X + 8192, 256, WorldFixture.Z,
		WorldFixture.X + 9216, 512, WorldFixture.Z + 1024])
	assert_equal(_f._owner.stage_add(token, row).error, &"", "actual unrelated physical fact")
	assert_equal(_f._owner.seal(token), &"", "actual unrelated source revision")
	_f._owner.publish(token)


func test_completion_never_normalizes_an_unrelated_stale_placement_source() -> void:
	"""All-row refresh may propagate this transaction's source bump, but cannot launder prior drift."""
	var project: Vector2i = _finished_order()
	var other: Vector2i = _register_other_corridor(false)
	var old_pin: int = _placements._get64(_placements._live, Placements.ROOM_REVISION, other.x)
	_change_other_corridor_source()
	assert_equal(_placements.order_refusal(_paid.subject, project, 0), &"", "active Placement remains current")
	assert_true(_f._owner._r_owner_revision[_f.other_floor.x] > old_pin, "unrelated real source advanced")
	var geometry: PackedByteArray = _f._owner.state_bytes()
	var inventory: PackedByteArray = _f._inventory.state_bytes()
	var done: Construction.OpResult = _router.complete_order(project)
	assert_false(done.ok, "unrelated stale retained Placement blocks physical completion")
	assert_equal(done.error, Placements.REFUSE_STALE, "original retained source refusal")
	_assert_uninstalled(project, geometry, inventory)
	assert_equal(_placements._get64(_placements._live, Placements.ROOM_REVISION, other.x), old_pin, "old pin never normalized")


func test_completion_never_normalizes_an_unrelated_stale_opening_source() -> void:
	"""A current Placement with an independently stale target also refuses before payment."""
	var project: Vector2i = _finished_order()
	var other: Vector2i = _register_other_corridor(true)
	var opening: int = _placements._get32(_placements._live, Placements.OPENING_HEAD, other.x)
	var old_pin: int = _placements._live.opening_revision[opening]
	_change_other_corridor_source()
	assert_equal(_placements._placement_leaf(_placements._live, other.x), &"", "other Placement's own section remains current")
	assert_true(_f._owner._r_owner_revision[_f.other_floor.x] > old_pin, "actual opening source advanced")
	var geometry: PackedByteArray = _f._owner.state_bytes()
	var inventory: PackedByteArray = _f._inventory.state_bytes()
	var done: Construction.OpResult = _router.complete_order(project)
	assert_false(done.ok, "stale retained opening blocks completion")
	assert_equal(done.error, Placements.REFUSE_STALE, "old exact opening pin required")
	_assert_uninstalled(project, geometry, inventory)
	assert_equal(_placements._live.opening_revision[opening], old_pin, "opening pin never normalized")


func test_completion_preserves_retained_section_level_before_payment() -> void:
	"""A prepared metadata level mutation cannot silently move an unrelated retained opening."""
	var project: Vector2i = _finished_order()
	_register_other_corridor(true)
	_authority.changed_level = _f.other_floor
	var geometry: PackedByteArray = _f._owner.state_bytes()
	var inventory: PackedByteArray = _f._inventory.state_bytes()
	var done: Construction.OpResult = _router.complete_order(project)
	assert_false(done.ok, "prepared level drift refuses")
	assert_equal(done.error, Placements.REFUSE_STALE, "exact old section level required")
	_assert_uninstalled(project, geometry, inventory)
	_authority.changed_level = NULL_REF
	assert_true(_router.complete_order(project).ok, "unchanged original level retries")
