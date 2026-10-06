extends "res://test/framework/test_case.gd"
## Original source-bound work area. No paid-state injection or demo dispatch is claimed here.

const Previous := preload("res://test/test_underground_entry_source_phases.gd")
const Prefix := preload("res://test/test_underground_first_prefix.gd")
const Foreman := preload("res://scripts/core/underground_entry_foreman.gd")
const WorkAreaSource := preload("res://scripts/core/underground_entry_work_area.gd")
const Bundle := preload("res://data/underground/first-entry-prefix-v1/qualified-handling-v1/catalog_source.gd")
const WA_PROFILE_SHA: String = Bundle.PROFILE_SHA
const WA_CATALOG_SHA: String = Bundle.CATALOG_SHA
const WA_GROUP_SHA: String = Bundle.GROUPING_SHA
const WA_RECIPE_SHA: String = Bundle.RECIPE_SHA
const WA_FRONTIER_SHA: String = Bundle.FRONTIER_SHA

class WorkAreaImages extends RefCounted:
	static func source(name: String) -> String:
		"""ADR1190: the fixed published bundle, never a validation-evidence copy."""
		return Bundle.FRONTIER_PATH.get_base_dir().path_join(name)

	static func frontier() -> String:
		"""The work-area Frontier is the bundle's revision-2 successor."""
		return Bundle.FRONTIER_PATH


class SourceWorld extends Previous.SourceWorld:
	func _actual_profiles() -> void:
		"""Admit the exact complete two-source bank before binding any actual route owner."""
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
		assert_equal(_profiles.configure(30, 281, 2, Profiles.ARENA_BYTES), &"", "full source arena")
		assert_equal(_profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual readers")
		_load_source()

	func _load_source() -> void:
		"""The diagnostic source adds handling; no existing full body or held-pick extent changes."""
		assert_equal(_profiles.load_file(WorkAreaImages.source("mole-worker.ugprof"), WA_PROFILE_SHA, 4), &"", "complete diagnostic source")

	func _load_catalog(revision: int) -> StringName:
		"""Select the same unchanged real structural parts before WorldRoutes is bound."""
		return _catalog.load_file(WorkAreaImages.source("structure.ugconn"), WA_CATALOG_SHA, revision)


class Probe extends Previous.Probe:
	var _published: WorkAreaSource.Published = null

	func _make_world() -> Prefix.ActualWorld:
		"""Select the immutable two-source bank at initial construction only."""
		return SourceWorld.new()

	func _content_revision() -> int:
		"""All actual route, worker and clock readers name the same complete diagnostic bank."""
		return 4

	func _entry_plan() -> EntryPlan.Request:
		"""The new selector revision is explicit in the original Room confirmation request."""
		var plan: EntryPlan.Request = super._entry_plan()
		plan.frontier_revision = 2
		return plan

	func _load_real_bills() -> void:
		"""No work amount or material quantity changes when the travel selectors change."""
		_groups._recipes = Recipes.new()
		assert_equal(_groups._recipes.configure(Recipes.MAX_PARTS, Recipes.required_bytes(Recipes.MAX_PARTS)), &"", "recipe arena")
		assert_equal(_groups._recipes.bind_actual(_world._catalog, _world._items, _world._inventory), &"", "recipe owners")
		assert_equal(_groups._recipes.load_file(WorkAreaImages.source("recipes.ugrecp"), WA_RECIPE_SHA, 1, WA_GROUP_SHA, 1), &"", "real recipe")
		_groups._reader = Assemblies.new()
		assert_equal(_groups._reader.configure(Assemblies.MAX_GROUPS, Assemblies.required_bytes(Assemblies.MAX_GROUPS)), &"", "group arena")
		assert_equal(_groups._reader.bind_actual(_world._catalog, _groups._recipes, _world._items, _world._inventory), &"", "group owners")
		assert_equal(_groups._reader.load_file(WorkAreaImages.source("assemblies.ugasmb"), WA_GROUP_SHA, 1, WA_RECIPE_SHA, 1), &"", "real partition")

	func _bind_frontier() -> void:
		"""Distinct source selectors resolve to the same actual immutable M/R Location handles."""
		_source = Frontier.new()
		assert_equal(_source.configure(PackedInt32Array([2, 8, 2, 10, 12, 6]), 4112), &"", "exact successor arena")
		assert_equal(_source.bind_actual(_world._catalog, _groups._reader, _groups._recipes, _world._profiles), &"", "original source chain")
		assert_equal(_source.load_file(WorkAreaImages.frontier(), WA_FRONTIER_SHA, 2), &"", "immutable work-area Frontier")

	func _natural_surface() -> void:
		"""ADR1197 G1: the production publisher creates all nine endpoints from the accepted geometry."""
		_anchor = Anchor.new()
		assert_equal(_anchor.configure(_world._world, _world._terrain, _world._owner, _world._sources,
			_world._locations, _world._budget, Anchor.RESERVED_BYTES), &"", "actual Anchor")
		_published = WorkAreaSource.Published.new()
		assert_equal(WorkAreaSource.publish_locations(_anchor, ORIGIN, _published), &"", "production work-area endpoints")
		_section = _published.section
		_endpoints.resize(9)
		for index: int in _published.endpoints.size(): _endpoints[index] = _published.endpoints[index]

	func _remaining_surface_contacts() -> void:
		"""All nine endpoints were published together by the production module."""
		pass

	func _surface_routes() -> void:
		"""ADR1197 G1: the production publisher seals and publishes all 28 directed paths once."""
		assert_equal(WorkAreaSource.publish_paths(_world._binding, _world._routes, _world._budget, _world._owner,
			ORIGIN, _published, _content_revision()), &"", "production work-area paths")

	func _surface_point(index: int) -> Vector3i:
		"""The same authored points the production publisher uses."""
		return WorkAreaSource.point(ORIGIN, index)


var _probe: Probe = null


func after_each() -> void:
	"""Report every nested actual-owner assertion and release this test's own original World."""
	if _probe != null:
		_probe.after_each()
		assert_true(_probe.failures.is_empty(), "actual work-area fixture: %s" % _probe.failures)
	_probe = null


func test_actual_work_area_preserves_all_four_paid_cuts() -> void:
	"""The complete original graph and distinct storage selectors must execute all twelve real phases."""
	_probe = Probe.new()
	_probe.before_each()
	_probe.execute_l0_cubes()
	assert_true(_probe.completed_l0, "actual L0 excavation completes in the original work area")


func test_actual_material_aliases_do_not_create_extra_locations() -> void:
	"""Only nine initial actual endpoints exist although twelve immutable selectors describe this source."""
	_probe = Probe.new()
	_probe.before_each()
	assert_equal(_probe._world._locations._live.count, 9, "unchanged original Location count")
	assert_equal(_probe._world._routes._live.edge_count, 28, "all exact original directed paths")
	assert_equal(_probe._source.row_count(4, 2), 12, "explicit extra travel selectors only")


func test_entry_foreman_drives_all_twelve_l0_phases_from_the_frontier() -> void:
	"""ADR1196: only Foreman.advance(tick) runs the four cubes; ledgers match the hand-driven fixture exactly."""
	_probe = Probe.new()
	_probe.before_each()
	var room: Vector2i = _probe._confirm_prefix()
	if room == Vector2i(-1, 0): return
	var first: Vector3i = _probe._surface_point(3)
	assert_true(_probe._world._transforms.place(_probe._world._worker, first.x, first.y, first.z, 49152),
		"worker physically stands at the first authored station")
	var foreman: Foreman = Foreman.new()
	var placement: Vector2i = Vector2i(0, _probe._placements._get32(_probe._placements._live, Prefix.Placements.GENERATION, 0))
	assert_equal(foreman.configure(foreman_owners(_probe), foreman_crew(_probe), placement), &"", "plan from Frontier and Placement")
	assert_equal(foreman.task_count(), 12, "four cubes x BRACE/CUT/FINISH")
	var tick: int = _probe._tick
	while not foreman.is_done() and foreman.error() == &"" and tick < _probe._tick + 30000:
		foreman.advance(tick)
		tick += 1
	assert_equal(foreman.error(), &"", "no refusal")
	assert_true(foreman.is_done(), "all twelve phases settled")
	_assert_l0_ledgers()


static func foreman_owners(_probe: RefCounted) -> Foreman.Owners:
	"""The probe's actual composed owners, unchanged; shared with the paid suite."""
	var o: Foreman.Owners = Foreman.Owners.new()
	var w: RefCounted = _probe._world
	o.sites = _probe._sites; o.jobs = w._jobs; o.work = w._work; o.routes = w._routes; o.binding = w._binding
	o.residents = w._residents; o.pool = w._pool; o.construction = w._construction; o.inventory = w._inventory
	o.profiles = w._profiles; o.frontier = _probe._source; o.placements = _probe._placements; o.locations = w._locations
	return o


static func foreman_crew(_probe: RefCounted) -> Foreman.Crew:
	"""One worker, its tool, the source storage/output containers and the finite wood/stone lots."""
	var c: Foreman.Crew = Foreman.Crew.new()
	c.worker = _probe._world._worker; c.tool = _probe._tool
	c.storage = _probe._storage; c.output = _probe._output
	c.lot_keys = [&"wood", &"stone"]; c.lots = [_probe._wood, _probe._stone]
	return c


func _assert_l0_ledgers() -> void:
	"""The same exact quantities the hand-driven execute_l0_cubes asserts."""
	assert_equal(_probe._world._inventory.lot_quantity_milli(_probe._wood), 5500, "four real brace wood bills")
	assert_equal(_probe._world._inventory.lot_quantity_milli(_probe._stone), 500, "four real brace stone bills")
	assert_equal(_probe._sites.virgin_sourced_milli(), 8000, "four whole CUT outputs")
	assert_equal(_probe._sites.support_conservation_refusal(), &"", "support ledgers balance")
	assert_equal(_probe._sites.earth_conservation_refusal(), &"", "spoil conserved")
	assert_equal(_probe._world._construction.live_project_count(), 0, "all twelve phases retired")
