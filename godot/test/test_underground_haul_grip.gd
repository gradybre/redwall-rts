extends "res://test/framework/test_case.gd"
## ADR1198 steps 6 and 8: the certified curved haul grip and the Delivery station seam, on the real published
## content-5 bank and the production work area. The worker is a real adult mole with no tool equipped.

const WorkArea := preload("res://test/test_underground_entry_work_area.gd")
const Prefix := preload("res://test/test_underground_first_prefix.gd")
const WorkAreaSource := preload("res://scripts/core/underground_entry_work_area.gd")
const Grip := preload("res://data/underground/mole-worker/qualified-haul-v6/grip_certificate.gd")
const Delivery := preload("res://scripts/core/underground_connector_delivery.gd")
const Planner := preload("res://scripts/core/haul_planner.gd")
const StorePolicy := preload("res://scripts/core/store_policy.gd")
const Clock := preload("res://scripts/core/sim_clock.gd")
const Work := preload("res://scripts/core/work.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Jobs := Prefix.Jobs
const Profiles := Prefix.Profiles
const Routes := Prefix.Routes
const NULL_REF: Vector2i = Vector2i(-1, 0)
const ROWS_PATH: String = "res://data/underground/mole-worker/haul-handling-v1/evidence/haul-rows-v1/rows.json"
const EXPIRY: int = 100000

var _probe: WorkArea.Probe = null
var _delivery: Delivery = null
var _planner: Planner = null
var _clock: Clock = null
var _project: Vector2i = NULL_REF


func after_each() -> void:
	"""No Delivery packet escapes; the original work-area fixture audits stock and claims."""
	if _delivery != null: assert_false(_delivery._busy, "no escaped delivery packet")
	_delivery = null; _planner = null; _clock = null
	if _probe != null:
		_probe.after_each()
		assert_true(_probe.failures.is_empty(), "actual work-area fixture: %s" % _probe.failures)
	_probe = null


func test_certificate_constants_are_the_rows_json_witnesses() -> void:
	"""R-S, both hand-contact cells and every yaw-0 box are copied from the step-2 derivation, never authored here."""
	var rows: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROWS_PATH))
	var station: Dictionary = rows["station"]
	var r_minus_s: Array = station["R_minus_S_u"]
	assert_equal(Grip.R_MINUS_S, Vector3i(int(r_minus_s[0]), int(r_minus_s[1]), int(r_minus_s[2])), "R-S")
	for contact: int in 2:
		var cell: Array = station["grip_contacts"][contact]["C_minus_S_cell_u"]
		for axis: int in 6:
			assert_equal(Grip.CONTACT_CELLS[6 * contact + axis], int(cell[axis]), "contact %d cell word %d" % [contact, axis])
	var expected: Array = [Grip.BOXES_CARRY, Grip.BOXES_LOAD, Grip.BOXES_UNLOAD]
	for index: int in 3:
		var boxes: Array = rows["rows"][index]["boxes"]
		assert_equal(boxes.size() * 7, (expected[index] as Array).size(), "row %d box count" % index)
		for ordinal: int in boxes.size():
			for field: int in 6:
				assert_equal((expected[index] as Array)[7 * ordinal + field], int(boxes[ordinal]["bounds_u"][field]), "box word")
			assert_equal((expected[index] as Array)[7 * ordinal + 6], int(boxes[ordinal]["role_id"]), "box role")


func test_certificate_admits_only_the_exact_station_transform() -> void:
	"""The real bank passes; any other heading, offset or row refuses the grip station."""
	_probe = WorkArea.Probe.new()
	_probe.before_each()
	var profiles: Profiles = _probe._world._profiles
	assert_true(Grip.uses(profiles), "real content 5 carries all five certified rows")
	var stock: Vector3i = WorkAreaSource.point(Prefix.ORIGIN, 1)
	var root: Vector3i = WorkAreaSource.point(Prefix.ORIGIN, WorkAreaSource.STAND_M)
	assert_equal(Grip.station_refusal(profiles, 34, root, 16384, stock), &"", "load grip at M's stand")
	assert_equal(Grip.station_refusal(profiles, 36, root, 16384, stock), &"", "unload grip at M's stand")
	assert_equal(Grip.station_refusal(profiles, 33, root, 0, stock), Grip.REFUSE_STATION, "yaw-0 row needs S ahead on -Z")
	assert_equal(Grip.station_refusal(profiles, 34, root, 0, stock), Grip.REFUSE_STATION, "heading must match the row")
	assert_equal(Grip.station_refusal(profiles, 34, root + Vector3i(1, 0, 0), 16384, stock), Grip.REFUSE_STATION, "one unit off")
	assert_equal(Grip.station_refusal(profiles, 32, root, 16384, stock), Grip.REFUSE_PROFILE, "CARRY is not a grip")
	assert_equal(Grip.station_refusal(profiles, 29, root, 16384, stock), Grip.REFUSE_PROFILE, "assembly palm is not a grip")


func test_delivery_refuses_a_part_unit_haul_trip() -> void:
	"""Whole-unit trips only: 999 milli is never admitted, and nothing is claimed."""
	if not _ready(): return
	var lot: Vector2i = _stage(999)
	var job: Jobs.OpResult = _haul_job()
	var result: Prefix.Inventory.OpResult = _delivery.admit(job.ref, lot, 999, EXPIRY)
	assert_false(result.ok, "part unit refused")
	assert_equal(result.error, Delivery.REFUSE_TRANSFER, "exact refusal")
	assert_equal(_probe._world._inventory.lot_reserved_milli(lot), 0, "no claim")


func test_grip_facing_away_from_the_stock_refuses_loading() -> void:
	"""At R's stand the yaw-0 row would grip a point 576 u ahead on -Z, not R's stock: the final leaf refuses."""
	if not _ready(): return
	var lot: Vector2i = _stage(1000)
	var job: Jobs.OpResult = _haul_job()
	assert_true(_delivery.admit(job.ref, lot, 1000, EXPIRY).ok, "admitted")
	assert_true(_probe._world._jobs.set_state(job.value, Jobs.JOB_STATE_TRAVEL).ok, "source travel")
	if not _travel(job, WorkAreaSource.STAND_R, Profiles.MODE_WALK): return
	var world: RefCounted = _probe._world
	assert_equal(Prefix.WorldRoutes.turn_actor(world._binding, world._worker, job.ref, 0, Prefix.Space.MAX_CHECKS), &"", "turn to yaw 0")
	assert_equal(world._routes.refresh_work_actor(world._worker, job.ref, 33, 1, Grip.CONTENT_REVISION, 0, -1, NULL_REF),
		&"", "the yaw-0 grip row is selectable here")
	assert_equal(_delivery.begin_load(job.ref), Delivery.REFUSE_ARRIVAL, "S is not at the certified offset")
	assert_equal(world._jobs._state[job.value], Jobs.JOB_STATE_TRAVEL, "no WORK entered")


func _ready() -> bool:
	"""Real entry, an open BRACE phase whose Site holds M's container, Delivery composed, and the tool unequipped."""
	_probe = WorkArea.Probe.new()
	_probe.before_each()
	if _probe._confirm_prefix() == NULL_REF:
		assert_true(false, "actual entry confirmation: %s" % _probe.failures)
		return false
	var world: RefCounted = _probe._world
	var cube: PackedInt32Array = Prefix.Source.cube(0)
	var site: Vector2i = _probe._sites.site_at(Prefix.ORIGIN + Vector3i(cube[0], cube[1], cube[2]))
	var opened: RefCounted = _probe._sites.open_phase(site, Prefix.Contract.OP_BRACE)
	assert_true(opened.ok, "real BRACE phase Project: %s" % opened.error)
	if not opened.ok: return false
	_project = opened.ref
	var amount: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(world._construction.remaining_mwu_into(_project, amount), "quoted phase work")
	var build: Jobs.OpResult = world._jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, amount.value, 0)
	assert_true(world._jobs.set_requester(build.value, _project).ok, "BUILD names the phase Project")
	assert_true(world._jobs.set_tool_gate(build.value, Jobs.GATE_SATISFIED).ok, "tool gate")
	assert_true(_probe._sites.bind_job(site, build.ref).ok, "Site job")
	assert_true(_probe._sites.bind_material_container(site, _probe._storage).ok, "Site validates M's container")
	assert_true(world._gear.unequip(_probe._tool, _probe._storage, false).ok, "the mole holds no tool")
	_compose_delivery()
	return failures.is_empty() and _probe.failures.is_empty()


func _compose_delivery() -> void:
	"""The real Planner and one Delivery over the probe's original owners."""
	var world: RefCounted = _probe._world
	_planner = Planner.new()
	assert_true(_planner.bind(world._inventory, world._pool, world._residents, world._buildings, world._piles,
		StorePolicy.new(world._buildings, world._inventory)), "actual Planner")
	_clock = Clock.new()
	_delivery = Delivery.new()
	assert_equal(_delivery.configure(_probe._placements, _probe._source, _planner, world._binding, world._work,
		_clock, Delivery.RESERVED_BYTES), &"", "one bounded Delivery")


func _stage(quantity: int) -> Vector2i:
	"""Surface stock staged at R: R's container is real create_spatial_ground_staging storage (ADR1197 G4)."""
	var made: Prefix.Inventory.OpResult = _probe._world._inventory.create_lot(_probe._output,
		_probe._world._items.compiled_id(&"wood"), quantity, 1, Prefix.Provenance.PROVENANCE_ORDINARY, -1, 0, 0)
	assert_true(made.ok, "staged surface wood: %s" % made.error)
	return made.ref


func _haul_job() -> Jobs.OpResult:
	"""A solo HAUL sourced by the phase Project; the idle tool-free mole is admitted on R by ordinary WALK selection."""
	var world: RefCounted = _probe._world
	var made: Jobs.OpResult = world._jobs.create_job(Jobs.JOB_KIND_HAUL, 0, 0, Planner.HAUL_LOAD_MILLI_WU, 0)
	assert_true(world._jobs.set_requester(made.value, _project).ok and world._jobs.set_source(made.value, _project).ok, "HAUL source")
	assert_true(world._jobs.assign_worker(world._residents.directory().get_typed_row(world._worker), made.value).ok, "solo assignment")
	var at: Vector3i = WorkAreaSource.point(Prefix.ORIGIN, 2)
	assert_true(world._transforms.place(world._worker, at.x, at.y, at.z, 0), "the mole stands on R")
	assert_equal(world._routes.admit_actor(world._worker, made.ref, _probe._endpoints[2], Profiles.MODE_WALK, 0, -1), &"", "tool-free walk")
	return made


func _travel(job: Jobs.OpResult, stand: int, mode: int) -> bool:
	"""Ordinary selection and route travel to a stand; position changes only over certified spans."""
	var world: RefCounted = _probe._world
	assert_equal(world._routes.refresh_actor(world._worker, job.ref, mode, 0, -1, NULL_REF), &"", "travel selection")
	assert_equal(world._routes.request_route(world._worker, _probe._endpoints[stand], 0), &"", "route request")
	var actor: Routes.Actor = Routes.Actor.new()
	for tick: int in 2000:
		world._routes.advance_tick(tick)
		assert_equal(world._routes.read_actor_into(world._worker, actor), &"", "actual actor")
		if actor.phase == Routes.PHASE_IDLE or actor.phase == Routes.PHASE_HELD: break
	assert_equal(actor.location, _probe._endpoints[stand], "arrived on the stand")
	return failures.is_empty()


func _grip(job: Jobs.OpResult, row: int) -> bool:
	"""Turn in place to the row's certified heading, then select the exact grip row."""
	var world: RefCounted = _probe._world
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(world._routes.read_actor_into(world._worker, actor), &"", "actual actor")
	if Grip.is_load(row):
		assert_equal(Prefix.WorldRoutes.turn_actor(world._binding, world._worker, job.ref, Grip.yaw_of(row),
			Prefix.Space.MAX_CHECKS), &"", "empty-handed supported turn to face the stock")
	else:
		assert_equal(actor.yaw, Grip.yaw_of(row), "the CARRY edge arrives on the grip heading; no loaded turn exists")
	assert_equal(world._routes.refresh_work_actor(world._worker, job.ref, row, 1, Grip.CONTENT_REVISION, 0, -1, NULL_REF),
		&"", "certified grip row %d" % row)
	return failures.is_empty()


func _work(job: int) -> bool:
	"""Fixed Work ticks until the handling phase has no remaining work; each tick runs the final grip leaf."""
	for tick: int in 2000:
		var result: Work.TickResult = _probe._world._work.tick_solo(job)
		assert_true(result.ok, "handling Work: %s" % result.error)
		if not result.ok or result.remaining_mwu == 0: break
	return failures.is_empty()
