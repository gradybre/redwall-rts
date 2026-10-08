extends "res://test/framework/test_case.gd"
## Original source-bound work area. No paid-state injection or demo dispatch is claimed here.

const Previous := preload("res://test/test_underground_entry_source_phases.gd")
const Prefix := preload("res://test/test_underground_first_prefix.gd")
const Foreman := preload("res://scripts/core/underground_entry_foreman.gd")
const WorkAreaSource := preload("res://scripts/core/underground_entry_work_area.gd")
## ADR1217 step 5: the production work area is the claw bundle's (stations at +/-1430, H's claw air). ADR1229: the
## mounted bundle is the T1-T6 one (content 10), which keeps the claw bundle's L0/T0 rows on content 10's row ids.
const Bundle := preload("res://data/underground/first-entry-prefix-v1/qualified-stairs-v8/catalog_source.gd")
const MoleCatalog := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const ClawPins := preload("res://data/underground/mole-worker/qualified-claw-stairs-v11/catalog_source.gd")
const WA_PROFILE_SHA: String = Bundle.PROFILE_SHA
const WA_CATALOG_SHA: String = Bundle.CATALOG_SHA
const WA_GROUP_SHA: String = Bundle.GROUPING_SHA
const WA_RECIPE_SHA: String = Bundle.RECIPE_SHA
const WA_FRONTIER_SHA: String = Bundle.FRONTIER_SHA
const ROWS_PATH: String = "res://data/underground/mole-worker/haul-handling-v1/evidence/haul-rows-v1/rows.json"

class WorkAreaImages extends RefCounted:
	static func source(name: String) -> String:
		"""ADR1190: the fixed published bundle, never a validation-evidence copy."""
		return Bundle.FRONTIER_PATH.get_base_dir().path_join(name)

	static func frontier() -> String:
		"""The work-area Frontier is the bundle's current successor (ADR 1202 split landing: revision 4)."""
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
		assert_equal(_profiles.configure(MoleCatalog.PROFILE_COUNT, MoleCatalog.BOX_COUNT, MoleCatalog.SOURCE_COUNT, Profiles.ARENA_BYTES), &"", "full source arena")
		assert_equal(_profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual readers")
		_load_source()

	func _load_source() -> void:
		"""The diagnostic source adds handling; no existing full body or held-pick extent changes."""
		assert_equal(_profiles.load_file(WorkAreaImages.source("mole-worker.ugprof"), WA_PROFILE_SHA, Bundle.CONTENT_REVISION), &"", "complete published source")

	func _load_catalog(revision: int) -> StringName:
		"""Select the same unchanged real structural parts before WorldRoutes is bound."""
		return _catalog.load_file(WorkAreaImages.source("structure.ugconn"), WA_CATALOG_SHA, revision)


class Probe extends Previous.Probe:
	var _published: WorkAreaSource.Published = null

	func _make_world() -> Prefix.ActualWorld:
		"""Select the immutable two-source bank at initial construction only."""
		return SourceWorld.new()

	func _content_revision() -> int:
		"""All actual route, worker and clock readers name the same complete published bank."""
		return Bundle.CONTENT_REVISION

	func _entry_plan() -> EntryPlan.Request:
		"""The new selector revision is explicit in the original Room confirmation request."""
		var plan: EntryPlan.Request = super._entry_plan()
		plan.frontier_revision = Bundle.FRONTIER_REVISION
		# ADR1229: the claims are the bundle's CUT rows, as Site.entry_plan derives them (seven cube rows).
		plan.claims = PackedInt32Array()
		var cut: PackedInt32Array = PackedInt32Array()
		cut.resize(Frontier.row_fields(Frontier.CUT))
		for row: int in _source.row_count(Frontier.CUT, Bundle.FRONTIER_REVISION):
			assert_equal(_source.cut_into(row, cut), &"", "authored CUT row")
			plan.claims.append_array(Prefix.Source.world_box(cut.slice(0, 6)))
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
		var capacities: PackedInt32Array = PackedInt32Array([Bundle.INSTALL_COUNT, Bundle.STATION_COUNT, Bundle.CUT_COUNT,
			Bundle.BEARING_COUNT, Bundle.ENDPOINT_COUNT, Bundle.EPISODE_COUNT])
		assert_equal(_source.configure(capacities, Frontier.required_bytes(capacities)), &"", "exact successor arena")
		assert_equal(_source.bind_actual(_world._catalog, _groups._reader, _groups._recipes, _world._profiles), &"", "original source chain")
		assert_equal(_source.load_file(WorkAreaImages.frontier(), WA_FRONTIER_SHA, Bundle.FRONTIER_REVISION), &"", "immutable work-area Frontier")

	func _natural_surface() -> void:
		"""ADR1197 G1: the production publisher creates all nine endpoints from the accepted geometry."""
		_anchor = Anchor.new()
		assert_equal(_anchor.configure(_world._world, _world._terrain, _world._owner, _world._sources,
			_world._locations, _world._budget, Anchor.RESERVED_BYTES), &"", "actual Anchor")
		_published = WorkAreaSource.Published.new()
		assert_equal(WorkAreaSource.publish_locations(_anchor, ORIGIN, _published), &"", "production work-area endpoints")
		_section = _published.section
		_endpoints.resize(WorkAreaSource.ENDPOINTS)
		for index: int in _published.endpoints.size(): _endpoints[index] = _published.endpoints[index]

	func _remaining_surface_contacts() -> void:
		"""All nineteen endpoints were published together by the production module."""
		pass

	func _surface_routes() -> void:
		"""ADR1197 G1: the production publisher seals and publishes all 36 directed paths once."""
		assert_equal(WorkAreaSource.publish_paths(_world._binding, _world._routes, _world._budget, _world._owner,
			ORIGIN, _published, _content_revision()), &"", "production work-area paths")

	func _surface_point(index: int) -> Vector3i:
		"""The same authored points the production publisher uses."""
		return WorkAreaSource.point(ORIGIN, index)

	func _equips_tool() -> bool:
		"""DEC-052: the claw crew digs and fits with no tool."""
		return false

	func _dig_profile(ordinal: int) -> int:
		"""The claw dig rows of the bundle's left (49152) and right (16384) cut stations."""
		return ClawPins.CLAW_DIG_ROWS[3] if ordinal % 2 == 0 else ClawPins.CLAW_DIG_ROWS[1]

	func _ground_profile() -> int:
		"""The claw canonical-ground WALK."""
		return ClawPins.CLAW_WALK_ROW


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
	"""Nine original endpoints, two haul stands and (ADR1229) the descent's eight cut stations exist although twelve
	immutable selectors describe this source; the descent stations' paths wait until they are worked."""
	_probe = Probe.new()
	_probe.before_each()
	assert_equal(_probe._world._locations._live.count, 19, "original nine, two haul stands, eight descent stations")
	assert_equal(_probe._world._routes._live.edge_count, 36, "original 28 directed paths plus eight haul edges")
	assert_equal(_probe._source.row_count(4, Bundle.FRONTIER_REVISION), 44,
		"explicit extra travel selectors, the installed arrival selectors and the stair stops")


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


static func foreman_owners(probe: RefCounted) -> Foreman.Owners:
	"""The probe's actual composed owners, unchanged; shared with the paid suite."""
	var o: Foreman.Owners = Foreman.Owners.new()
	var w: RefCounted = probe._world
	o.sites = probe._sites; o.jobs = w._jobs; o.work = w._work; o.routes = w._routes; o.binding = w._binding
	o.residents = w._residents; o.pool = w._pool; o.construction = w._construction; o.inventory = w._inventory
	o.profiles = w._profiles; o.frontier = probe._source; o.placements = probe._placements; o.locations = w._locations
	o.items = w._items
	return o


static func foreman_crew(probe: RefCounted) -> Foreman.Crew:
	"""One worker, its tool and the source storage/output containers; inputs come from the storage's own stock."""
	var c: Foreman.Crew = Foreman.Crew.new()
	c.worker = probe._world._worker; c.tool = probe._tool
	c.storage = probe._storage; c.output = probe._output
	return c


func _assert_l0_ledgers() -> void:
	"""The same exact quantities the hand-driven execute_l0_cubes asserts."""
	assert_equal(_probe._world._inventory.lot_quantity_milli(_probe._wood), 5500, "four real brace wood bills")
	assert_equal(_probe._world._inventory.lot_quantity_milli(_probe._stone), 500, "four real brace stone bills")
	assert_equal(_probe._sites.virgin_sourced_milli(), 8000, "four whole CUT outputs")
	assert_equal(_probe._sites.support_conservation_refusal(), &"", "support ledgers balance")
	assert_equal(_probe._sites.earth_conservation_refusal(), &"", "spoil conserved")
	assert_equal(_probe._world._construction.live_project_count(), 0, "all twelve phases retired")


func test_haul_stands_derive_from_the_content5_grip_rows_and_qualify_walk_and_carry() -> void:
	"""ADR1198 step 5: each stand is its stock point plus R-S at yaw 16384 and carries every row's floor, S included."""
	_probe = Probe.new()
	_probe.before_each()
	var rows: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROWS_PATH))
	var r_minus_s: Array = rows["station"]["R_minus_S_u"]
	assert_equal(WorkAreaSource.STAND_OFFSET, Vector3i(int(r_minus_s[2]), int(r_minus_s[1]), -int(r_minus_s[0])),
		"stand offset is the certified R-S turned a quarter (x,y,z) -> (z,y,-x)")
	for stand: int in [WorkAreaSource.STAND_M, WorkAreaSource.STAND_R]:
		assert_equal(WorkAreaSource.point(Prefix.ORIGIN, stand) - WorkAreaSource.point(Prefix.ORIGIN, WorkAreaSource.stock_of(stand)),
			WorkAreaSource.STAND_OFFSET, "stand beside its own storage endpoint")
	assert_equal(_floor_union(_probe._world._profiles), WorkAreaSource.STAND_FOOT, "stand footing is the exact floor union")
	var binding: RefCounted = _probe._world._binding
	assert_true(_edge_admits(binding, _probe._endpoints[2], _probe._endpoints[WorkAreaSource.STAND_R], 31), "tool-free WALK to R's stand")
	assert_true(_edge_admits(binding, _probe._endpoints[WorkAreaSource.STAND_R], _probe._endpoints[WorkAreaSource.STAND_M], 32), "CARRY between stands")
	assert_true(_edge_admits(binding, _probe._endpoints[WorkAreaSource.STAND_M], _probe._endpoints[1], 31), "tool-free WALK back to M")
	var stand_m: Vector2i = _probe._endpoints[WorkAreaSource.STAND_M]
	var stand_r: Vector2i = _probe._endpoints[WorkAreaSource.STAND_R]
	assert_true(_edge_admits(binding, stand_r, _probe._endpoints[2], 31), "ADR1205: WALK R's stand back to R")
	assert_true(_edge_admits(binding, _probe._endpoints[1], stand_m, 31), "ADR1205: WALK M to M's stand")
	assert_true(_edge_admits(binding, stand_m, stand_r, 32), "ADR1205: CARRY M's stand to R's stand")
	assert_true(_edge_admits(binding, stand_m, stand_r, 31), "ADR1205: empty return walk between the stands")
	assert_true(_edge_admits(binding, stand_r, stand_m, 31), "ADR1205: empty walk R's stand to M's stand")


static func _floor_union(profiles: RefCounted) -> Array[int]:
	"""Union of every floor (y <= 0) box of the tool-free ground rows 30-32 and the yaw-16384 grip rows 34/36."""
	var out: Array[int] = [0, 0, 0, 0, 0, 0]
	var box: Prefix.Profiles.Box = Prefix.Profiles.Box.new()
	for row: int in [30, 31, 32, 34, 36]:
		for ordinal: int in profiles._field(profiles._live, row, Prefix.Profiles.F_BOX_COUNT):
			if profiles.box_into(row, 1, Bundle.CONTENT_REVISION, ordinal, box) != &"" or box.high.y > 0: continue
			for axis: int in 3:
				out[axis] = mini(out[axis], box.low[axis])
				out[axis + 3] = maxi(out[axis + 3], box.high[axis])
	return out


static func _edge_admits(binding: RefCounted, first: Vector2i, last: Vector2i, profile: int) -> bool:
	"""Some published edge between two endpoints carries the profile's certificate bit (the stands have two)."""
	var routes: RefCounted = binding._routes_ref.get_ref()
	var capacity: int = routes._edge_capacity
	for row: int in capacity:
		if routes._live.present[row] != 1: continue
		var fields: PackedInt32Array = routes._live.fields
		if Vector2i(fields[Prefix.Routes.E_FROM_SLOT * capacity + row], fields[Prefix.Routes.E_FROM_GENERATION * capacity + row]) != first \
				or Vector2i(fields[Prefix.Routes.E_TO_SLOT * capacity + row], fields[Prefix.Routes.E_TO_GENERATION * capacity + row]) != last:
			continue
		@warning_ignore("integer_division")
		if (binding._live.masks[row * Prefix.WorldRoutes.MASK_BYTES + profile / 8] & (1 << (profile % 8))) != 0:
			return true
	return false



func test_entry_confirmation_carries_every_work_area_path() -> void:
	"""ADR1205: the Room's only geometry change is floor metadata, so all 36 paths carry and the proof stays small."""
	_probe = Probe.new()
	_probe.before_each()
	var room: Vector2i = _probe._confirm_prefix()
	if room == Vector2i(-1, 0): return
	var binding: RefCounted = _probe._world._binding
	assert_equal(binding._carried_edges, 36, "every published path carried")
	assert_true(binding._proof_checks * 2 < Prefix.Space.MAX_CHECKS, "entry confirmation well inside the check budget: %d" % binding._proof_checks)
