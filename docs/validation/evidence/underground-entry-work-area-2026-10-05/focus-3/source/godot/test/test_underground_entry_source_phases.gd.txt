extends "res://test/framework/test_case.gd"
## Actual source/terrain/paid-phase integration. Initial worker arrival is an explicit test setup.
## No synthetic certificates, injected paid state, automatic crew dispatch or playable Kitchen claim.

const Prefix := preload("res://test/test_underground_first_prefix.gd")
const PhaseFixture := preload("res://test/test_underground_entry_world_bindings.gd")
const Structural := preload("res://test/test_underground_entry_structure_source.gd")
const FrontierSource := preload("res://test/test_underground_entry_frontier_source.gd")
const PROFILE_PATH: String = "res://data/underground/mole-worker/qualified-step-v4/mole-worker.ugprof"
const PROFILE_SHA: String = "830ee531a432f9cef8a24a85f1c017be21253301bc46bf55e0a6b97807a4ec4e"

class SourceWorld extends Prefix.ActualWorld:
	var negative_case: int = 0

	func _actual_profiles() -> void:
		"""Retain the original concrete store graph and read only the complete published v4 source."""
		_pool = Pool.new(64, Pool.JOB_CAPACITY, 64)
		_piles = Piles.new()
		assert_true(_piles.bind_stores(_inventory, _buildings, StockAge.new(_inventory)), "actual piles")
		assert_true(_piles.bind_world(_world_ref), "actual pile World")
		_carry = Carry.new()
		assert_true(_carry.bind(_inventory, _pool, _residents, _piles), "actual cargo")
		_gear = Gear.new(16)
		assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual Gear")
		_work = Work.new(_jobs)
		assert_true(_work.bind_gear(_gear).ok, "actual Work")
		_profiles = Profiles.new()
		assert_equal(_profiles.configure(29, 271, 1, Profiles.ARENA_BYTES), &"", "unchanged full source arena")
		assert_equal(_profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual readers")
		_load_source()

	func _load_source() -> void:
		"""Positive runs read exact v4; negative runs explicitly corrupt one full BODY residual in a separate test wire."""
		if negative_case == 0:
			assert_equal(_profiles.load_file(PROFILE_PATH, PROFILE_SHA, 3), &"", "published v4 source")
			return
		var raw: PackedByteArray = FileAccess.get_file_as_bytes(PROFILE_PATH)
		var ordinal: int = 227 if negative_case == 1 else 226
		raw.encode_s32(64 + 29 * 98 + ordinal * 28 + 4, -2)
		var path: String = "user://entry-source-invalid-residual.bin"
		assert_equal(_profiles.load_file(path, _write(path, raw), 3), &"", "explicit malformed physical source candidate")

	func after_each() -> void:
		"""Remove the test's malformed source after releasing every original owner."""
		super.after_each()
		var path: String = "user://entry-source-invalid-residual.bin"
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

	func _load_catalog(revision: int) -> StringName:
		"""Choose real structural content before the first WorldRoutes binding."""
		return _catalog.load_file(Structural.CATALOG_PATH, Structural.CATALOG_SHA, revision)

	func _actual_binding() -> void:
		"""Use the production root-cell query bound; the earlier tiny synthetic fixture bound cannot hold this full source."""
		_binding = Prefix.WorldRoutes.new()
		var config: Prefix.WorldRoutes.Configuration = Prefix.WorldRoutes.Configuration.new()
		config.routes = _routes; config.owner = _owner; config.sources = _sources; config.locations = _locations
		config.profiles = _profiles; config.catalog = _catalog; config.levels = _levels; config.movement = _movement
		config.residents = _residents; config.transforms = _transforms; config.world = _world
		config.terrain = _terrain; config.budget = _budget
		assert_equal(_binding.configure(config), &"", "actual complete route provider")
		assert_equal(_routes.configure(_locations, _owner, _sources, _buildings, _budget, _binding,
			1024, 32, 128, 128, Routes.ARENA_BYTES), &"", "existing production cell query bound")
		assert_equal(_routes.bind_profiles(_profiles, _inventory, _gear, _carry, _work, _pool, _piles), &"", "original worker owners")

class Probe extends PhaseFixture:
	var _tick: int = 0
	var negative_case: int = 0
	var completed_cube: bool = false
	var completed_l0: bool = false

	func before_each() -> void:
		"""The old helper supplies actual economic owners only; every immutable content bank comes from source."""
		_spec = Source.read_fixture()
		_world = _make_world()
		(_world as SourceWorld).negative_case = negative_case
		_world.spec = _spec
		_world.location_capacity = 32
		_world._turn_source_case = 3
		_world._actual_fixture()
		_groups = PricedGroups.new()
		_groups._catalog = _world._catalog; _groups._items = _world._items; _groups._inventory = _world._inventory
		_load_real_bills()
		_bind_frontier()
		_natural_surface()
		_remaining_surface_contacts()
		_surface_routes()
		_finite_stock_and_worker()
		_bind_paid_owners()
		assert_true(_world.failures.is_empty(), "actual World setup: %s" % _world.failures)

	func _make_world() -> Prefix.ActualWorld:
		"""A successor diagnostic may select its exact immutable source before constructing any original owner."""
		return SourceWorld.new()

	func _content_revision() -> int:
		"""All original v4 selectors share their exact content revision; no caller may bypass actual reader checks."""
		return 3

	func _load_real_bills() -> void:
		"""All bills and complete assembly partitions retain the independently accepted actual bytes."""
		_groups._recipes = Recipes.new()
		assert_equal(_groups._recipes.configure(Recipes.MAX_PARTS, Recipes.required_bytes(Recipes.MAX_PARTS)), &"", "recipe arena")
		assert_equal(_groups._recipes.bind_actual(_world._catalog, _world._items, _world._inventory), &"", "recipe owners")
		assert_equal(_groups._recipes.load_file(Structural.RECIPE_PATH, Structural.RECIPE_SHA, 1, Structural.GROUP_SHA, 1), &"", "real recipe")
		_groups._reader = Assemblies.new()
		assert_equal(_groups._reader.configure(Assemblies.MAX_GROUPS, Assemblies.required_bytes(Assemblies.MAX_GROUPS)), &"", "group arena")
		assert_equal(_groups._reader.bind_actual(_world._catalog, _groups._recipes, _world._items, _world._inventory), &"", "group owners")
		assert_equal(_groups._reader.load_file(Structural.GROUP_PATH, Structural.GROUP_SHA, 1, Structural.RECIPE_SHA, 1), &"", "real partition")

	func _bind_frontier() -> void:
		"""Immutable source names actual downward programs and full all-yaw perimeter routes."""
		_source = Frontier.new()
		var capacities: PackedInt32Array = PackedInt32Array([2, 8, 2, 10, 10, 6])
		assert_equal(_source.configure(capacities, 4032), &"", "source bank")
		assert_equal(_source.bind_actual(_world._catalog, _groups._reader, _groups._recipes, _world._profiles), &"", "source chain")
		assert_equal(_source.load_file(FrontierSource.FRONTIER_PATH, FrontierSource.FRONTIER_SHA, 1), &"", "actual Frontier")

	func _entry_plan() -> EntryPlan.Request:
		"""Keep exact original claims; bind only the new immutable revisions and actual original digests."""
		var plan: EntryPlan.Request = super._entry_plan()
		plan.grouping_revision = 1; plan.recipe_revision = 1; plan.frontier_revision = 1
		return plan

	func _natural_surface() -> void:
		"""Observe complete actual air and untouched footing; broad metadata cannot create either."""
		_anchor = Anchor.new()
		assert_equal(_anchor.configure(_world._world, _world._terrain, _world._owner, _world._sources,
			_world._locations, _world._budget, Anchor.RESERVED_BYTES), &"", "actual Anchor")
		_endpoints.resize(9)
		var envelope: PackedInt32Array = Source.world_box(PackedInt32Array([-3072, 0, -4608, 3072, 2048, 2048]))
		var support: PackedInt32Array = Source.world_box(PackedInt32Array([-2304, -128, 0, 2304, 0, 1024]))
		var metadata: PackedInt32Array = Source.world_box(PackedInt32Array([-3072, 0, -4608, 3072, 1, 2048]))
		var created: Anchor.Result = _anchor.create(_surface_point(0), envelope, support, Locations.ROLE_WORK, metadata)
		assert_equal(created.error, &"", "actual full near-side ground survey")
		_section = created.section
		_endpoints[0] = created.location

	func _remaining_surface_contacts() -> void:
		"""Real endpoint publication proves each entire footing strip without reserving any future cut."""
		var envelope: PackedInt32Array = Source.world_box(PackedInt32Array([-3072, 0, -4608, 3072, 2048, 2048]))
		for index: int in range(1, 9):
			var role: int = Locations.ROLE_STORAGE if index < 3 else Locations.ROLE_WORK
			var foot: PackedInt32Array = PackedInt32Array([-2304, -128, 0, 2304, 0, 1024])
			if index >= 3:
				foot = PackedInt32Array([-2304, -128, -4096, -1024, 0, 1024]) if index % 2 == 1 else \
					PackedInt32Array([1024, -128, -4096, 2304, 0, 1024])
			var added: Anchor.Result = _anchor.create_in_section(_surface_point(index), envelope, Source.world_box(foot), _section, role)
			assert_equal(added.error, &"", "actual full endpoint %d" % index)
			_endpoints[index] = added.location

	func _surface_point(index: int) -> Vector3i:
		"""Exact runtime points equal the corrected source selectors, including unchanged finite storage endpoints."""
		if index < 3: return super._surface_point(index)
		@warning_ignore("integer_division")
		return ORIGIN + Vector3i(-1536 if index % 2 == 1 else 1536, 0, -512 - ((index - 3) / 2) * 1024)

	func _surface_routes() -> void:
		"""Publish actual explicit perimeter polylines; a future excavated pocket is never crossed diagonally."""
		var lease: int = _world._budget.acquire(Budget.COLD_BYTES)
		var begun: Routes.Result = _world._binding.begin_prepare(lease)
		assert_equal(begun.error, &"", "actual ground preparation")
		for endpoint: int in [1, 2]:
			for work: int in [0, 3, 4, 5, 6, 7, 8]:
				assert_equal(_world._routes.stage_add(begun.token, _surface_edge(endpoint, work)).error, &"", "actual outward path")
				assert_equal(_world._routes.stage_add(begun.token, _surface_edge(work, endpoint)).error, &"", "actual return path")
		assert_equal(_world._binding.seal(begun.token), &"", "actual complete ground certificate")
		assert_equal(_world._binding.publish(begun.token), &"", "actual graph publication")
		_world._binding.abort(begun.token)
		assert_equal(_world._budget.release(lease), &"", "original graph lease released")

	func _surface_edge(first: int, last: int) -> Routes.Edge:
		"""Each source12 sweep uses the same outside gateway checked in the immutable source review."""
		var edge: Routes.Edge = Routes.Edge.new()
		var from: Vector3i = _surface_point(first)
		var to: Vector3i = _surface_point(last)
		edge.from_location = _endpoints[first]; edge.to_location = _endpoints[last]
		edge.section = _section; edge.level = 0; edge.family = -1; edge.variant = 0
		edge.mode = Profiles.MODE_WALK; edge.posture = Profiles.POSTURE_UPRIGHT
		edge.content_revision = _content_revision(); edge.geometry_revision = _world._owner.revision()
		edge.points = PackedInt32Array([from.x, from.y, from.z])
		if first >= 3 or last >= 3:
			var work: int = first if first >= 3 else last
			var bend: Vector3i = Vector3i(_surface_point(work).x, ORIGIN.y, ORIGIN.z + 512)
			edge.points.append_array(PackedInt32Array([bend.x, bend.y, bend.z]))
		edge.points.append_array(PackedInt32Array([to.x, to.y, to.z]))
		@warning_ignore("integer_division")
		edge.point_count = edge.points.size() / 3
		edge.length_u = absi(to.x - from.x) + absi(to.z - from.z)
		return edge

	func _select_phase_actor(job: int, ordinal: int) -> void:
		"""The first phase starts at an explicitly placed station; successors retain the same real actor and pose."""
		var profile: int = 25 if ordinal % 2 == 0 else 17
		var worker: int = _world._residents.directory().get_typed_row(_world._worker)
		if _world._routes._resident_ref(worker) != NULL_REF:
			_move_to_source_station(job, ordinal)
			if not failures.is_empty(): return
			assert_equal(_world._routes.refresh_work_actor(_world._worker, _world._jobs.ref_of(job), profile, 1, _content_revision(), 0, -1, _tool), &"", "same real actor")
			return
		var point: Vector3i = _surface_point(3 + ordinal)
		assert_true(_world._transforms.place(_world._worker, point.x, point.y, point.z, 49152 if ordinal % 2 == 0 else 16384), "explicit initial test arrival")
		assert_equal(_world._routes.admit_work_actor(_world._worker, _world._jobs.ref_of(job), _endpoints[3 + ordinal], profile, 1, _content_revision(), 0, -1, _tool), &"", "actual source actor")

	func _move_to_source_station(job: int, ordinal: int) -> void:
		"""Successor stations require actual perimeter travel, source recovery and a physically certified turn."""
		var worker: int = _world._residents.directory().get_typed_row(_world._worker)
		if _world._routes._resident_pair(Routes.R_LOCATION_SLOT, worker) == _endpoints[3 + ordinal]: return
		assert_equal(_world._routes.refresh_travel_actor(_world._worker, _world._jobs.ref_of(job), 12, 1, _content_revision(), 0, -1, _tool), &"", "actual source WALK handoff")
		assert_equal(_world._routes.request_route(_world._worker, _endpoints[3 + ordinal], _tick), &"", "actual perimeter itinerary")
		if not failures.is_empty(): return
		var actor: Routes.Actor = Routes.Actor.new()
		for step: int in 600:
			_world._routes.advance_tick(_tick); _tick += 1
			assert_equal(_world._routes.read_actor_into(_world._worker, actor), &"", "actual moving actor")
			if actor.phase == Routes.PHASE_HELD:
				assert_true(false, "actual perimeter route held")
				return
			if actor.location == _endpoints[3 + ordinal] and \
				Routes.source_ready_leaf_refusal(_world._routes, _world._worker, _world._jobs.ref_of(job), 12, 1, _content_revision()) == &"": break
		assert_equal(actor.location, _endpoints[3 + ordinal], "actual endpoint reached")
		assert_equal(WorldRoutes.turn_actor(_world._binding, _world._worker, _world._jobs.ref_of(job),
			49152 if ordinal % 2 == 0 else 16384, Space.MAX_CHECKS), &"", "actual full-envelope work-facing turn")

	func _begin_actual_phase(site: Vector2i, operation: int, ordinal: int) -> int:
		"""Canonical source entry must finish through actual Routes before any paid productive START."""
		var job: int = _open_real_phase_job(site, operation, ordinal)
		if job < 0 or not failures.is_empty(): return -1
		var profile: int = 25 if ordinal % 2 == 0 else 17
		for step: int in 240:
			if Routes.source_work_leaf_refusal(_world._routes, _world._worker, _world._jobs.ref_of(job), profile, 1, _content_revision()) == &"": break
			_world._routes.advance_tick(_tick); _tick += 1
		assert_equal(Routes.source_work_leaf_refusal(_world._routes, _world._worker, _world._jobs.ref_of(job), profile, 1, _content_revision()), &"", "actual source WORK reached")
		if not failures.is_empty(): return -1
		_reserve_real_phase_inputs(site, operation, job)
		var bound: Construction.OpResult = _sites.bind_worker(site)
		assert_true(bound.ok, "actual phase worker: %s" % bound.error)
		if not bound.ok: return -1
		var started: Construction.OpResult = _sites.begin_phase_work(site, _tick)
		assert_true(started.ok, "actual source phase START: %s" % started.error)
		return job if started.ok else -1

	func _earn_actual_phase(job: int) -> void:
		"""Every fixed productive tick advances the actual source clock and the actual existing Work dispatcher."""
		var remaining: IntMath.IntResult = IntMath.IntResult.new()
		var ticks: int = 0
		while _world._jobs.remaining_mwu_into(job, remaining) and remaining.value > 0 and ticks < 1000:
			_world._routes.advance_tick(_tick); _tick += 1
			var worked: Work.TickResult = _world._work.tick_solo(job)
			assert_true(worked.ok, "actual source productive tick: %s" % worked.error)
			if not worked.ok: return
			_accepted_work_mwu += worked.accepted_mwu
			ticks += 1
		assert_true(_world._jobs.remaining_mwu_into(job, remaining) and remaining.value == 0, "actual work completed")

	func _complete_actual_phase(site: Vector2i, operation: int, ordinal: int) -> bool:
		"""The exact source returns to READY before the completed phase releases its real Job and tool claim."""
		var job: int = _begin_actual_phase(site, operation, ordinal)
		if job < 0: return false
		_earn_actual_phase(job)
		if not failures.is_empty(): return false
		assert_equal(_world._routes.request_source_ready(_world._worker, _world._jobs.ref_of(job)), &"", "real source recovery")
		var profile: int = 25 if ordinal % 2 == 0 else 17
		for step: int in 240:
			if Routes.source_ready_leaf_refusal(_world._routes, _world._worker, _world._jobs.ref_of(job), profile, 1, _content_revision()) == &"": break
			_world._routes.advance_tick(_tick); _tick += 1
		assert_equal(Routes.source_ready_leaf_refusal(_world._routes, _world._worker, _world._jobs.ref_of(job), profile, 1, _content_revision()), &"", "actual full recovery")
		if not failures.is_empty(): return false
		var settled: Construction.OpResult = _sites.settle_phase(site)
		assert_true(settled.ok, "actual paid phase settles: %s" % settled.error)
		assert_true(_world._budget.is_quiescent(), "original phase lease released")
		return settled.ok

	func reject_invalid_residual() -> void:
		"""Wholly negative or mixed positive/negative BODY must retain complete original physical refusal."""
		if not failures.is_empty(): return
		var room: Vector2i = _confirm_prefix()
		if room == NULL_REF: return
		var inventory: PackedByteArray = _world._inventory.state_bytes()
		var geometry: PackedByteArray = _world._owner.state_bytes()
		var sites: PackedByteArray = _sites.state_bytes()
		var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
		assert_equal(_sites.open_phase(site, Contract.OP_BRACE).error, Contacts.REFUSE_GEOMETRY, "full invalid BODY cannot borrow support")
		assert_equal(_world._inventory.state_bytes(), inventory, "no input spend")
		assert_equal(_world._owner.state_bytes(), geometry, "no geometry publication")
		assert_equal(_sites.state_bytes(), sites, "no phase WIP")
		assert_equal(_world._construction.live_project_count(), 0, "no invalid project")

	func execute_first_cube() -> void:
		"""Complete three real phases with finite input/output accounting, retaining no invented source progress."""
		if not failures.is_empty(): return
		var room: Vector2i = _confirm_prefix()
		if room == NULL_REF: return
		var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
		for operation: int in [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]:
			if not _complete_actual_phase(site, operation, 0): return
		assert_equal(_world._inventory.lot_quantity_milli(_wood), 6250, "real one-cube wood consumption")
		assert_equal(_world._inventory.lot_quantity_milli(_stone), 1250, "real one-cube stone consumption")
		assert_equal(_sites.virgin_sourced_milli(), 2000, "one real CUT emits exactly once")
		assert_equal(_sites.support_conservation_refusal(), &"", "support conservation")
		assert_equal(_sites.earth_conservation_refusal(), &"", "spoil conservation")
		assert_equal(_world._routes._live.edge_count, 28, "only explicit actual surface graph")
		completed_cube = failures.is_empty()

	func execute_l0_cubes() -> void:
		"""Four real cubes precede any timber; moving between them never earns work or changes their bills."""
		if not failures.is_empty(): return
		var room: Vector2i = _confirm_prefix()
		if room == NULL_REF: return
		for ordinal: int in 4:
			var box: PackedInt32Array = Source.cube(ordinal)
			var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(box[0], box[1], box[2]))
			for operation: int in [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]:
				if not _complete_actual_phase(site, operation, ordinal): return
		assert_equal(_world._inventory.lot_quantity_milli(_wood), 5500, "four real brace wood bills")
		assert_equal(_world._inventory.lot_quantity_milli(_stone), 500, "four real brace stone bills")
		assert_equal(_sites.virgin_sourced_milli(), 8000, "four whole CUT outputs")
		assert_equal(_sites.support_conservation_refusal(), &"", "four support ledgers balance")
		assert_equal(_sites.earth_conservation_refusal(), &"", "all local spoil conserved")
		assert_equal(_world._construction.live_project_count(), 0, "all twelve phases retired")
		completed_l0 = failures.is_empty()

var _probe: Probe = null


func after_each() -> void:
	"""Dispose only this test's original owner graph and report helper assertions without rewriting framework totals."""
	if _probe != null:
		_probe.after_each()
		assert_true(_probe.failures.is_empty(), "actual source fixture: %s" % _probe.failures)
	_probe = null


func test_real_source_first_cube_earns_paid_brace_cut_and_finish() -> void:
	"""A real full-size worker must pass terrain, source clock and economic gates through all three operations."""
	_probe = Probe.new()
	_probe.before_each()
	_probe.execute_first_cube()
	assert_true(_probe.failures.is_empty(), "real-source execution: %s" % _probe.failures)
	assert_true(_probe.completed_cube, "all three actual source phases completed")
	assert_equal(_probe._accepted_work_mwu, 9000, "exact adopted productive work; recovery earns none")
	assert_true(_probe.assertions > 50, "actual nested owner checks executed; not added to the suite assertion counter")


func test_wholly_negative_body_residual_cannot_be_omitted() -> void:
	"""Air-contact filtering cannot erase one unsupported unit of the full below-plane source body."""
	_probe = Probe.new()
	_probe.negative_case = 1
	_probe.before_each()
	_probe.reject_invalid_residual()
	assert_true(_probe.failures.is_empty(), "whole negative residual: %s" % _probe.failures)


func test_four_landing_cubes_require_real_source_travel_and_paid_phases() -> void:
	"""One worker reaches all four initial landing cuts over retained ground and completes twelve paid phases."""
	_probe = Probe.new()
	_probe.before_each()
	_probe.execute_l0_cubes()
	assert_true(_probe.failures.is_empty(), "four source cubes: %s" % _probe.failures)
	assert_true(_probe.completed_l0, "all four whole cubes dug and finished")
	assert_equal(_probe._accepted_work_mwu, 36000, "actual phase work only; travel and turns earn none")


func test_mixed_body_residual_cannot_be_clipped_to_air() -> void:
	"""A primitive spanning both air and unsupported matter remains a complete physical refusal."""
	_probe = Probe.new()
	_probe.negative_case = 2
	_probe.before_each()
	_probe.reject_invalid_residual()
	assert_true(_probe.failures.is_empty(), "mixed body residual: %s" % _probe.failures)
