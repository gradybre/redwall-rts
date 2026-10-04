extends "res://test/framework/test_case.gd"
## Actual paid lifecycle. Diagnostic1134 source/adapter dependencies and synthetic motion remain explicit.

const PieceTests := preload("res://test/test_underground_connector_workpieces.gd")
const PrefixTests := preload("res://test/test_underground_first_prefix.gd")
const ActualBuildings := preload("res://scripts/core/buildings.gd")
const ActualConstruction := preload("res://scripts/core/construction.gd")
const Workpieces := preload("res://scripts/core/underground_connector_workpieces.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const ActualTransforms := preload("res://scripts/core/transforms.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Modular := preload("res://scripts/core/modular_project_contract.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class ObservedBuildings extends ActualBuildings:
	var final_probe: Callable = Callable()
	var final_calls: int = 0
	var probe_boundary: StringName = &"_final_workpiece_leaf"

	func room_identity_into(room: Vector2i, out: PackedInt32Array) -> StringName:
		"""A real successful public read may mutate other actual owners after copying the original Room facts."""
		var code: StringName = super.room_identity_into(room, out)
		if code != &"" or not final_probe.is_valid(): return code
		for frame: Dictionary in get_stack():
			if frame.get("function") == probe_boundary:
				var callback: Callable = final_probe
				final_probe = Callable()
				final_calls += 1
				callback.call()
				break
		return code

class ProbeWorld extends PieceTests.HandlingWorld:
	func _actual_profiles() -> void:
		"""Install the observing actual Building store before any spatial, paid or profile binding exists."""
		_buildings = ObservedBuildings.new(_residents.directory())
		_construction = ActualConstruction.new(_buildings)
		super._actual_profiles()

class ProbeFixture extends PieceTests.Fixture:
	func _make_world() -> PrefixTests.ActualWorld:
		"""All inherited phase and paid proofs use the actual shared store tuple from initialization."""
		return ProbeWorld.new()

var _builder: PieceTests = null
var _fixture: ProbeFixture = null
var _pieces: Workpieces = null
var _original_pose: Vector3i = Vector3i.ZERO
var _original_yaw: int = 0


func before_each() -> void:
	"""Reuse the reviewed actual first-prefix assembly fixture without copying its paid lifecycle implementation."""
	_fixture = ProbeFixture.new()
	_fixture.before_each()
	assert_true(_fixture.failures.is_empty(), "actual setup: %s" % _fixture.failures)
	_pieces = Workpieces.new()
	assert_equal(_pieces.configure(4, 2, Workpieces.required_bytes(4, 2)), &"", "actual finite workpiece rows")
	assert_equal(_pieces.bind_actual(_fixture._placements, _fixture._router, _fixture._paid), &"", "actual source binding")
	_builder = PieceTests.new()
	_builder._fixture = _fixture
	_builder._pieces = _pieces


func after_each() -> void:
	"""Propagate every inner fixture failure and release any armed callback before dropping actual owners."""
	var observed: ObservedBuildings = _fixture._world._buildings as ObservedBuildings
	observed.final_probe = Callable()
	_builder.after_each()
	assert_true(_builder.failures.is_empty(), "inner lifecycle failures: %s" % _builder.failures)
	_builder = null
	_pieces = null
	_fixture = null


func _ready_and_delivered() -> Vector2i:
	"""Genuine paid phase transitions precede the next assembly; input ownership stays in Inventory/Pool."""
	var project: Vector2i = _builder._ready_l0()
	if project == NULL_REF or not _builder.failures.is_empty(): return NULL_REF
	var job: int = _fixture._installation_job(project, _fixture._endpoints[0])
	if job < 0 or not _fixture.failures.is_empty(): return NULL_REF
	var quote: Modular.Quote = Modular.Quote.new()
	assert_equal(_fixture._router.project_facts_into(project, quote), &"", "actual full bill")
	assert_true(_fixture._router.bind_material_container(project, _fixture._storage).ok, "actual delivered endpoint")
	var batch: PackedInt64Array = PackedInt64Array([_fixture._wood.x, _fixture._wood.y,
		Reservations.PURPOSE_MODULAR_INPUT, quote.input_milli[0], 100000])
	assert_true(_fixture._world._pool.claim_batch(_fixture._world._jobs.ref_of(job), batch, 1,
		_fixture._world._inventory).ok, "real loose wood reservation")
	assert_true(_fixture._router.record_deliveries(project).ok, "real arrived quantities")
	return project


func _move_after_room_copy() -> void:
	"""The successful last public source read changes actual pose inside the prepared obstacle, with no geometry receipt."""
	var world: PrefixTests.ActualWorld = _fixture._world
	var row: int = ActualTransforms.POSITIONED_BASE[Directory.KIND_RESIDENT] + world._residents.directory().get_typed_row(world._worker)
	_original_pose = Vector3i(world._transforms._x[row], world._transforms._y[row], world._transforms._z[row])
	_original_yaw = world._transforms._yaw[row]
	assert_true(world._transforms.place(world._worker, _pieces._bounds[0] + 1,
		_pieces._bounds[1], _pieces._bounds[2] + 1, _original_yaw), "actual late pose mutation")


func test_last_public_room_reader_is_absent_after_final_occupancy_proof() -> void:
	"""The retained rejected witness is now armed at the same exact boundary, which dispatches no public store read."""
	var project: Vector2i = _ready_and_delivered()
	if project == NULL_REF: return
	var observed: ObservedBuildings = _fixture._world._buildings as ObservedBuildings
	observed.final_probe = _move_after_room_copy
	var started: ActualConstruction.OpResult = _fixture._router.start_work(project, 0)
	assert_true(started.ok, "valid actual START: %s" % started.error)
	assert_equal(observed.final_calls, 0, "no public Room reader remains after occupancy")
	assert_true(_fixture._router._funding.is_funded(project), "sole actual WIP receipt")
	assert_equal(_pieces._live.present.count(1), 1, "one physical row")


func test_observing_room_copy_move_refuses_payment_and_allows_valid_retry() -> void:
	"""Normal source observations remain active, and their mutations must precede the final body proof."""
	var project: Vector2i = _ready_and_delivered()
	if project == NULL_REF: return
	var inventory: PackedByteArray = _fixture._world._inventory.state_bytes()
	var geometry: PackedByteArray = _fixture._world._owner.state_bytes()
	var observed: ObservedBuildings = _fixture._world._buildings as ObservedBuildings
	observed.probe_boundary = &"workpiece_refusal"
	observed.final_probe = _move_after_room_copy
	var started: ActualConstruction.OpResult = _fixture._router.start_work(project, 0)
	assert_false(started.ok, "the actual moved body prevents START")
	assert_equal(observed.final_calls, 1, "normal successful public Room observation still runs")
	assert_true(_fixture._world._inventory.state_bytes() == inventory, "no payment after source observation moves worker")
	assert_true(_fixture._world._owner.state_bytes() == geometry, "no obstacle through current body")
	assert_false(_fixture._router._funding.is_funded(project), "no failed WIP receipt")
	assert_equal(_pieces._live.present.count(1), 0, "no failed physical row")
	assert_true(_fixture._world._transforms.place(_fixture._world._worker, _original_pose.x,
		_original_pose.y, _original_pose.z, _original_yaw), "actual return to original station")
	started = _fixture._router.start_work(project, 0)
	assert_true(started.ok, "unchanged original source permits actual retry: %s" % started.error)
	assert_equal(_pieces._live.present.count(1), 1, "retry publishes once")


func test_physical_source_survives_released_job_without_granting_work_or_turn() -> void:
	"""A complete retained body remains physical after assignment ends; current tool/pose still select its exact source."""
	var project: Vector2i = _ready_and_delivered()
	if project == NULL_REF: return
	var world: PrefixTests.ActualWorld = _fixture._world
	var row: int = world._residents.directory().get_typed_row(world._worker)
	assert_equal(Routes.physical_selection_into(world._routes, row, world._routes._occupant_selection), &"", "bound full body")
	assert_true(world._jobs.release_worker(row).ok, "actual released BUILD assignment")
	assert_true(Routes.turn_selection_into(world._routes, row, world._routes._occupant_selection) != &"", "turn still requires assignment")
	assert_equal(Routes.physical_selection_into(world._routes, row, world._routes._occupant_selection), &"", "physical source needs no productive claim")
	var gear_row: int = world._gear._resolve_row(_fixture._tool)
	var manufacture: int = world._gear._manufacture_recipe[gear_row]
	world._gear._manufacture_recipe[gear_row] += 1
	assert_true(Routes.physical_selection_into(world._routes, row, world._routes._occupant_selection) != &"", "different actual held tool cannot borrow old body")
	world._gear._manufacture_recipe[gear_row] = manufacture
	assert_equal(Routes.physical_selection_into(world._routes, row, world._routes._occupant_selection), &"", "exact equipment retry")


func test_paid_paused_cancellation_removes_only_exact_piece_after_refund() -> void:
	"""The real Router releases assignment before its guarded refund; spatial occupancy remains worker-free."""
	var project: Vector2i = _ready_and_delivered()
	if project == NULL_REF: return
	var started: ActualConstruction.OpResult = _fixture._router.start_work(project, 0)
	assert_true(started.ok, "actual START: %s" % started.error)
	if not started.ok: return
	var placement: Vector2i = _fixture._world._construction.subject_ref_of(project)
	var region: Vector2i = _pieces.workpiece_region(placement, project)
	assert_true(_fixture._world._construction.set_paused(project, true).ok, "actual player pause")
	var cancelled: ActualConstruction.OpResult = _fixture._router.cancel_order(project, _fixture._storage)
	assert_true(cancelled.ok, "worker-free actual refund: %s" % cancelled.error)
	if not cancelled.ok: return
	assert_equal(Workpieces._removed_leaf(_pieces, project, region), &"", "exact full obstacle/source retired")
	assert_equal(_pieces._live.present.count(1), 0, "no paid physical row after refund")
	assert_false(_fixture._world._construction._directory.is_valid(project), "Project retired after geometry")
