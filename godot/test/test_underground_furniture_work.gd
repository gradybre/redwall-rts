extends "res://test/framework/test_case.gd"
## Actual paid furniture/geometry owners. Room admission, profiles and contacts are SYNTHETIC.
## This fixture does not activate live room drawing, service availability or production geometry.

const FurnitureWork := preload("res://scripts/core/underground_furniture_work.gd")
const RoomOrders := preload("res://scripts/core/underground_room_orders.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const SpaceOwner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Priorities := preload("res://scripts/core/priorities.gd")
const Schedule := preload("res://scripts/core/schedule.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Work := preload("res://scripts/core/work.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Funding := preload("res://scripts/core/excavation_inventory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const PhysicalFixture := preload("res://test/test_excavation_physical.gd")
const ModularFixture := preload("res://test/test_modular_projects.gd")
const TestCase := preload("res://test/framework/test_case.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class ExactPhysicalDomain extends PhysicalFixture.SpatialFixture:
	## SYNTHETIC permissions retain the exact actual fixture Space key namespace.
	func domain_into(out: Sites.Domain) -> bool:
		"""Room and physical owners must agree even in a geometry-permission fixture."""
		out.world_ref = world
		out.datum_u = Vector3i(0, -8192, 0)
		out.minimum_quantum = Vector3i.ZERO
		out.size_quanta = Vector3i(16, 16, 16)
		retained_descriptor = out
		return true

class SyntheticRegistration extends RoomOrders:
	## Only initial registration uses a synthetic scoped permit; paid installation uses production super.
	var permit_action: int = -1
	var permit_related: Vector2i = NULL_REF
	var permit_value: int = 0
	var permit_rotation: int = 0

	func mutation_refusal(action: int, subject: Vector2i, related: Vector2i,
			value: int, rotation: int) -> StringName:
		"""No unscoped fixture success; exact registration arguments are discarded before paid work."""
		if action == permit_action and subject == NULL_REF and related == permit_related \
				and value == permit_value and rotation == permit_rotation:
			return &""
		return super.mutation_refusal(action, subject, related, value, rotation)

class WatchedSpace extends SpaceOwner:
	## Actual owner implementation; only counters observe the pre-allocation budget call order.
	var stage_calls: int = 0
	var domain_calls: int = 0

	func begin_stage(expected_revision: int) -> SpaceOwner.Result:
		"""Count entry before the actual sparse bank copies; denied admission must never reach this."""
		stage_calls += 1
		return super.begin_stage(expected_revision)

	func domain_copy() -> Space.Domain:
		"""Observe the real cold copy boundary without changing its immutable-domain implementation."""
		domain_calls += 1
		return super.domain_copy()

class SyntheticBindings extends RoomOrders.Bindings:
	## These permissions are explicitly synthetic; accounting, source facts and publication are real.
	var construction: Construction = null
	var space: SpaceOwner = null
	var world: Vector2i = NULL_REF
	var inventory: Inventory = null
	var orders: WeakRef = null
	var wired: bool = true
	var shell_complete: bool = true
	var services_available: bool = false
	var block_action: int = -1
	var block_material: bool = false
	var block_worker: bool = false
	var stage_action: int = -1
	var stage_project: Vector2i = NULL_REF
	var stage_furniture: Vector2i = NULL_REF
	var stage_room: Vector2i = NULL_REF
	var stage_token: int = 0
	var publications: PackedInt32Array = PackedInt32Array()
	var exact_windows: PackedByteArray = PackedByteArray()
	var false_windows: PackedByteArray = PackedByteArray()
	var discarded: int = 0
	var cold_allowed: bool = true
	var cold_project: Vector2i = NULL_REF
	var cold_action: int = -1
	var cold_begins: int = 0
	var cold_ends: int = 0
	var cold_foreign_stage: bool = false

	func exact_binding(buildings: Buildings, candidate: SpaceOwner, actual: Construction,
			world_ref: Vector2i) -> bool:
		"""Even synthetic spatial permission compares the exact real stores and actual World."""
		return wired and actual == construction and buildings == construction.buildings() \
			and candidate == space and world_ref == world

	func admission_refusal(room: Vector2i, furniture: Vector2i, _type_id: int) -> StringName:
		"""Record explicit synthetic complete-shell/fit proof, separate from source/paid-owner validity."""
		_record(room, furniture, NULL_REF, Contract.ADMIT, 0)
		return &"" if shell_complete else &"SYNTHETIC_SHELL_INCOMPLETE"

	func transition_refusal(room: Vector2i, furniture: Vector2i, project: Vector2i,
			action: int, token: int) -> StringName:
		"""Simulate a current contact/service candidate, including controlled refusal before payment."""
		_record(room, furniture, project, action, token)
		return &"SYNTHETIC_CONTACT_BLOCKED" if action == block_action else &""

	func begin_cold(_room: Vector2i, _furniture: Vector2i, project: Vector2i, action: int) -> StringName:
		"""Explicit synthetic joint-arena admission refuses before any real sparse-owner bank copy."""
		if not cold_allowed:
			return &"SYNTHETIC_COLD_BUDGET"
		if cold_project != NULL_REF:
			return &"SYNTHETIC_COLD_BUSY"
		cold_project = project
		cold_action = action
		cold_foreign_stage = space.has_prepared()
		cold_begins += 1
		return &""

	func end_cold(_room: Vector2i, _furniture: Vector2i, project: Vector2i, action: int) -> void:
		"""Only the exact leased operation may release; all actual geometry scratch must be dropped first."""
		assert(project == cold_project and action == cold_action, "exact shared cold owner")
		assert(not space.has_prepared() or cold_foreign_stage, "own sparse candidate dropped before cold release")
		assert(stage_action == -1, "companion scratch dropped before cold release")
		cold_project = NULL_REF
		cold_action = -1
		cold_ends += 1

	func _record(room: Vector2i, furniture: Vector2i, project: Vector2i, action: int, token: int) -> void:
		"""Keep one fixture stage so wrong-project discards cannot hide a composition defect."""
		stage_room = room
		stage_furniture = furniture
		stage_project = project
		stage_action = action
		stage_token = token

	func prepared_refusal(room: Vector2i, furniture: Vector2i, project: Vector2i,
			action: int, token: int) -> StringName:
		"""Require all exact prepared fields, rather than granting a blanket synthetic true reply."""
		return &"" if room == stage_room and furniture == stage_furniture and project == stage_project \
			and action == stage_action and token == stage_token else &"SYNTHETIC_STAGE_MISMATCH"

	func material_refusal(_room: Vector2i, _furniture: Vector2i, _project: Vector2i,
			container: Vector2i, _job: Vector2i) -> StringName:
		"""Actual containers remain finite/reachable; only their physical contact qualification is synthetic."""
		return &"" if not block_material and inventory.container_reachable(container) else &"SYNTHETIC_MATERIAL_CONTACT"

	func worker_refusal(_room: Vector2i, _furniture: Vector2i, _project: Vector2i,
			_job: Vector2i, worker: Vector2i) -> StringName:
		"""The shared Router still proves assignment/tools; no fake resident reference is accepted here."""
		return &"" if not block_worker and construction.directory().is_valid_of_kind(worker, Directory.KIND_RESIDENT) \
			else &"SYNTHETIC_WORKER_CONTACT"

	func discard_transition(room: Vector2i, furniture: Vector2i, project: Vector2i,
			action: int, token: int) -> void:
		"""Only the matching prepared candidate is cleared; this fixture owns no live geometric state."""
		if prepared_refusal(room, furniture, project, action, token) == &"":
			stage_action = -1
			discarded += 1

	func publish_transition(room: Vector2i, furniture: Vector2i, project: Vector2i,
			action: int, token: int) -> void:
		"""Probe real synchronous publication; record presence without inventing usable room services."""
		var actual: RoomOrders = orders.get_ref() as RoomOrders
		exact_windows.append(int(actual.is_publishing(project, action, furniture, room)))
		false_windows.append(int(actual.is_publishing(project, action + 1, furniture, room)))
		false_windows.append(int(actual.is_publishing(Vector2i(project.x, project.y + 1), action, furniture, room)))
		false_windows.append(int(actual.is_publishing(project, action, Vector2i(furniture.x, furniture.y + 1), room)))
		false_windows.append(int(actual.is_publishing(project, action, furniture, Vector2i(room.x, room.y + 1))))
		assert(token == stage_token, "same staged geometry token")
		assert(action != Contract.COMMIT and action != Contract.CANCEL \
			or cold_project == project and cold_action == action, "cold lease retained through publication")
		publications.append(action)
		stage_action = -1

	func area_of_room(room: Vector2i) -> Buildings.OpResult:
		"""Explicit synthetic 8m by 8m floor area; it does not qualify real authored shell geometry."""
		return Buildings.OpResult.new(construction.buildings().is_live_room(room), &"", 8192 * 8192, room)

	func service_refusal(_room: Vector2i) -> StringName:
		"""Actual installation never silently turns this deliberately unavailable service proof on."""
		return &"" if services_available else &"SYNTHETIC_WHOLE_ROOM_SERVICE_UNQUALIFIED"

class Fixture extends RefCounted:
	## Shared setup object belongs only to tests; production uses packed stores, never per-item fixtures.
	var check_owner: WeakRef = null
	var residents: Residents = Residents.new()
	var priorities: Priorities = Priorities.new()
	var schedule: Schedule = null
	var jobs: Jobs = null
	var work: ModularFixture.FaultWork = null
	var inventory: Inventory = Inventory.new(32, 256)
	var pool: Reservations = Reservations.new()
	var items: Items = Items.new()
	var gear: Gear = Gear.new(8)
	var buildings: Buildings = null
	var construction: Construction = null
	var physical: PhysicalFixture.SpatialFixture = ExactPhysicalDomain.new()
	var sites: Sites = null
	var funding: Funding = null
	var router: Router = null
	var sources: SpaceOwner.CoreSources = null
	var space: WatchedSpace = null
	var catalog: RoomCatalog = RoomCatalog.new()
	var bindings: SyntheticBindings = SyntheticBindings.new()
	var orders: SyntheticRegistration = SyntheticRegistration.new()
	var owner: FurnitureWork = FurnitureWork.new()
	var world: Vector2i = NULL_REF
	var stock: Vector2i = NULL_REF
	var room: Vector2i = NULL_REF
	var floor_ref: Vector2i = NULL_REF
	var worker: int = -1
	var tool: Vector2i = NULL_REF
	var math: IntMath.IntResult = IntMath.IntResult.new()

	func _init(test_case: TestCase, bind_furniture: bool = true, room_bindings: SyntheticBindings = null) -> void:
		"""Build real accounting, physical history, catalog, labor and sparse geometry ownership."""
		if room_bindings != null:
			bindings = room_bindings
		check_owner = weakref(test_case)
		world = residents.directory().create(Directory.KIND_WORLD)
		schedule = Schedule.new(residents.needs())
		jobs = Jobs.new(residents, priorities, schedule)
		work = ModularFixture.FaultWork.new(jobs)
		check(items.load_default(inventory).ok, "actual catalog")
		check(gear.bind_equipment(inventory, residents.directory(), residents).ok, "actual Gear")
		check(work.bind_gear(gear).ok, "actual Work equipment")
		stock = inventory.create_container(world, 1000000, -1, 0, true).ref
		buildings = Buildings.new(residents.directory())
		construction = Construction.new(buildings)
		physical.world = world
		sites = Sites.new(construction, inventory, pool, items, jobs, work, physical, 64, 64)
		check(sites.initialization_refusal() == &"", "actual Sites shared Funding")
		funding = sites.funding_owner(construction, inventory, pool, items, jobs, work)
		router = Router.new(construction, inventory, pool, items, jobs, work, sites)
		check(router.initialization_refusal() == &"", "actual Router")
		_configure_space()
		check(orders.configure(router, space, sources, catalog, bindings) == &"", "sole actual Room authority")
		if bind_furniture:
			check(owner.configure(router, orders) == &"", "actual Furniture purpose")
		worker = _spawn_worker()

	func check(condition: bool, label: String) -> void:
		"""Report through the actual test framework rather than treating engine exit zero as evidence."""
		(check_owner.get_ref() as TestCase).assert_true(condition, label)

	func _configure_space() -> void:
		"""Keep real source generations and finite sparse regions; profiles remain synthetic."""
		sources = SpaceOwner.CoreSources.new(buildings.directory(), buildings, construction)
		space = WatchedSpace.new(sources)
		var domain: Space.Domain = Space.Domain.new()
		check(domain.configure(world, Vector3i(0, -8192, 0), Vector3i.ZERO, Vector3i(16, 16, 16), 64, 64, 100000) == &"", "explicit fixture domain")
		check(space.configure(domain, 64, 32) == &"", "actual sparse geometry")
		bindings.construction = construction
		bindings.space = space
		bindings.world = world
		bindings.inventory = inventory
		bindings.orders = weakref(orders)

	func _spawn_worker() -> int:
		"""Initialize an actual eligible adult with real skill/mood and equipped job-scoped tool."""
		var resident: int = residents.spawn_with_stage(&"mouse", Residents.LIFE_STAGE_ADULT).value
		check(priorities.spawn(resident).ok, "worker priorities")
		check(schedule.spawn(resident, schedule.default_template_id().value).ok, "worker schedule")
		check(schedule.resolve(resident, 8, false).ok, "work-hour eligibility")
		check(jobs.spawn_agent(resident).ok, "actual JobAgent")
		for need: int in Needs.NEED_COUNT:
			check(residents.needs().apply_need_event(resident, need, 5000 - residents.needs().need_of(resident, need).value).ok, "base mood")
		tool = lot(&"tool", Gear.GEAR_LOT_QUANTITY_MILLI)
		check(gear.create_gear(inventory, items, tool, Gear.MANUFACTURE_BASIC).ok, "actual tool")
		check(gear.equip(tool, residents.ref_of(resident)).ok, "actual equipped tool")
		return resident

	func lot(key: StringName, quantity: int) -> Vector2i:
		"""Create actual finite catalog stock for delivery/refund conservation tests."""
		var made: Inventory.OpResult = inventory.create_lot(stock, items.compiled_id(key), quantity,
			1, Catalog.PROVENANCE_ORDINARY, -1, 0, 0)
		check(made.ok, "actual material lot")
		return made.ref

	func make_room(kind: int = Buildings.ROOM_TYPE_KITCHEN) -> Vector2i:
		"""Synthetic initial admission uses the SAME authority; real identity and region storage follow."""
		orders.permit_action = Buildings.SPATIAL_ROOM_CREATE
		orders.permit_value = kind
		var result: Buildings.OpResult = buildings.designate_spatial_room(kind)
		orders.permit_action = -1
		check(result.ok, "actual permanent Room")
		room = result.ref
		var stage: SpaceOwner.Result = space.begin_stage(space.revision())
		check(stage.error == &"", "Room source stage")
		check(space.stage_source(stage.token, room) == &"", "actual Room source")
		var region: SpaceOwner.Region = SpaceOwner.Region.new()
		region.owner = room
		region.role = Space.FLOOR_DATUM
		region.level = 0
		region.box = PackedInt32Array([0, -4097, 0, 8192, -4096, 8192])
		var floor_result: SpaceOwner.Result = space.stage_add(stage.token, region)
		check(floor_result.error == &"", "actual floor section")
		floor_ref = floor_result.handle
		region.role = Space.PROTECTED_ACCESS
		region.section = floor_ref
		region.box = PackedInt32Array([0, -4096, 0, 512, -3072, 8192])
		check(space.stage_add(stage.token, region).error == &"", "actual protected room route")
		check(space.seal(stage.token) == &"", "exact Room geometry candidate")
		space.publish(stage.token)
		return room

	func pending(key: String = "kitchen_bench", x: int = 1024, rotation: int = 0) -> Vector2i:
		"""Register real pending piece and its actual region; this fixture alone supplies initial fit."""
		var type_id: int = int(Catalog.FURNITURE_DEFINITION[key])
		orders.permit_action = Buildings.SPATIAL_FURNITURE_CREATE
		orders.permit_related = room
		orders.permit_value = type_id
		orders.permit_rotation = rotation
		var made: Buildings.OpResult = buildings.stage_spatial_furniture(room, type_id, rotation)
		orders.permit_action = -1
		check(made.ok, "actual pending Furniture identity")
		var stage: SpaceOwner.Result = space.begin_stage(space.revision())
		check(stage.error == &"", "Furniture geometry stage")
		check(space.stage_source(stage.token, made.ref) == &"", "actual pending Furniture source")
		var region: SpaceOwner.Region = SpaceOwner.Region.new()
		region.owner = made.ref
		region.section = floor_ref
		region.role = Space.OBSTACLE
		region.level = 0
		region.box = PackedInt32Array([x, -4096, 1024, x + 512, -3072, 1536])
		check(space.stage_add(stage.token, region).error == &"", "actual pending footprint")
		check(space.seal(stage.token) == &"", "exact pending geometry candidate")
		space.publish(stage.token)
		return made.ref

	func open(furniture: Vector2i) -> Vector2i:
		"""The actual purpose owner derives protected recipes; the caller gives no quantity or work."""
		check(owner.prepare_installation(furniture) == &"", "actual installation preparation")
		var result: Construction.OpResult = router.open_order(owner, owner.prepared_subject(), owner.prepared_operation())
		check(result.ok, "actual paid project admission: %s" % result.error)
		return result.ref

	func bind_job(project: Vector2i) -> Vector2i:
		"""Give actual immutable project work to a required-tool Job and eligible assigned resident."""
		var quote: Contract.Quote = Contract.Quote.new()
		check(router.project_facts_into(project, quote) == &"", "actual project quote")
		var result: Jobs.OpResult = jobs.create_job(quote.job_kind, 1, 0, quote.remaining_mwu, 0)
		check(result.ok, "actual BUILD Job")
		check(jobs.set_requester(result.value, project).ok, "actual requester")
		check(jobs.set_tool_gate(result.value, Jobs.GATE_SATISFIED).ok, "mandatory required tool")
		check(router.bind_job(project, result.ref).ok, "accepted actual project Job")
		assign(result.ref)
		return result.ref

	func assign(job: Vector2i) -> void:
		"""Actual assignment and Gear claim, including resume after safe pause/release."""
		check(jobs.assign_worker(worker, jobs.directory().get_typed_row(job)).ok, "actual worker")
		check(work.claim_tool_for_work(worker, tool).ok, "actual required tool claim")

	func deliver(project: Vector2i) -> void:
		"""Fund the exact bill through actual lots, reservations and derived Construction credits."""
		var quote: Contract.Quote = Contract.Quote.new()
		check(router.project_facts_into(project, quote) == &"", "exact actual catalog bill")
		check(router.bind_material_container(project, stock).ok, "actual physical input binding")
		var claims: PackedInt64Array = PackedInt64Array()
		for line: int in quote.input_count:
			var material: Vector2i = lot(quote.input_keys[line], quote.input_milli[line])
			claims.append_array(PackedInt64Array([material.x, material.y, Reservations.PURPOSE_MODULAR_INPUT, quote.input_milli[line], 1000]))
		check(pool.claim_batch(router.job_of(project), claims, quote.input_count, inventory).ok, "actual input claims")
		check(router.record_deliveries(project).ok, "actual claims become delivery credits")

	func start(project: Vector2i) -> void:
		"""Payment happens through shared Funding before actual productive Work may begin."""
		deliver(project)
		var begun: Construction.OpResult = router.start_work(project, 100)
		check(begun.ok, "actual paid start: %s" % begun.error)
		check(funding.is_funded(project), "actual shared WIP")

	func finish(project: Vector2i, job: Vector2i) -> void:
		"""Only real Work supplies capped labor, XP and wear; no fake timer or direct accepted-WU input."""
		for tick: int in 2000:
			construction.remaining_mwu_into(project, math)
			if math.value == 0:
				return
			var result: Work.TickResult = work.tick_solo(jobs.directory().get_typed_row(job))
			check(result.ok, "actual productive tick: %s" % result.error)
			if not result.ok:
				return
		check(false, "fixture work bound exhausted")

	func image() -> PackedByteArray:
		"""Actual physical, material and worker state for unchanged-on-refusal comparisons."""
		var bytes: PackedByteArray = inventory.state_bytes()
		bytes.append_array(pool.state_bytes())
		bytes.append_array(funding.state_bytes())
		bytes.append_array(construction.state_bytes())
		bytes.append_array(router.state_bytes())
		bytes.append_array(jobs.state_bytes())
		bytes.append_array(work.state_bytes())
		bytes.append_array(gear.state_bytes())
		bytes.append_array(residents.state_bytes())
		bytes.append_array(buildings.spatial_state_bytes())
		bytes.append_array(space.state_bytes())
		return bytes

	func audit() -> void:
		"""Every test audits real material and claims; synthetic geometry permission cannot hide leakage."""
		check(inventory.audit().ok, "actual Inventory conservation audit")
		check(pool.audit(inventory).ok, "actual Reservation audit")
		check(not space.has_prepared(), "no leaked geometry transaction")
		check(bindings.cold_project == NULL_REF and bindings.cold_begins == bindings.cold_ends, "balanced shared cold release")

var _f: Fixture = null


func before_each() -> void:
	"""Real owners with explicitly synthetic initial shell/fit/contact qualification."""
	_f = Fixture.new(self)
	_f.make_room()


func after_each() -> void:
	"""All production reverse links are weak; no worker or scene object leaks remain."""
	_f.audit()
	_f = null


func test_real_paid_work_installs_presence_and_matching_geometry_exactly_once() -> void:
	"""A bench remains pending through actual payment/work; install and source facts publish together."""
	var furniture: Vector2i = _f.pending()
	var project: Vector2i = _f.open(furniture)
	var job: Vector2i = _f.bind_job(project)
	assert_false(_f.buildings.is_furniture_installed(furniture), "accepted identity supplies no installation")
	assert_equal(_f.buildings.furniture_mask_of(_f.room).value, 0, "pending bench grants zero presence")
	_f.start(project)
	assert_false(_f.buildings.is_furniture_installed(furniture), "payment alone grants no presence")
	_f.finish(project, job)
	assert_false(_f.buildings.is_furniture_installed(furniture), "earned work waits for atomic geometry commit")
	var old_revision: int = _f.space.source_revision(furniture)
	assert_true(_f.router.complete_order(project).ok, "actual completion publishes")
	assert_true(_f.buildings.is_furniture_installed(furniture), "actual installed Furniture")
	assert_equal(_f.space.source_refusal(furniture), &"", "source facts reflect actual installed flag")
	assert_true(_f.space.source_revision(furniture) > old_revision, "source revision advances once")
	assert_true(_f.buildings.furniture_mask_of(_f.room).value > 0, "installed presence only")
	assert_false(_f.buildings.room_is_valid(_f.room), "missing whole-room services do not become valid")
	assert_false(_f.construction.is_live_project(project), "actual Construction retires after commit")
	assert_false(_f.jobs.directory().is_valid(job), "actual Job safely retires")
	assert_false(_f.funding.is_funded(project), "receipt arena settles once")
	var after: PackedByteArray = _f.image()
	assert_false(_f.router.complete_order(project).ok, "duplicate completion refuses")
	assert_true(_f.image() == after, "duplicate cannot publish or debit twice")
	assert_false(_f.bindings.exact_windows.has(0), "every companion used exact synchronous bracket")
	assert_false(_f.bindings.false_windows.has(1), "mismatched action/generation never qualifies")


func test_direct_installation_retirement_and_fake_callbacks_never_supply_paid_completion() -> void:
	"""Having a live Furniture ref or retained stage arguments cannot bypass payment and real Work."""
	var furniture: Vector2i = _f.pending()
	var project: Vector2i = _f.open(furniture)
	var before: PackedByteArray = _f.image()
	assert_false(_f.buildings.install_spatial_furniture(furniture).ok, "direct installation denied")
	assert_false(_f.buildings.remove_furniture(furniture).ok, "direct removal denied")
	assert_false(_f.buildings.set_room_valid(_f.room, true).ok, "caller cannot grant Room service validity")
	_f.owner.publish_completion(project)
	_f.owner.publish_cancellation(project)
	_f.orders.publish_transition(project, Contract.COMMIT)
	assert_false(_f.router.complete_order(project).ok, "unpaid order cannot complete")
	assert_true(_f.image() == before, "every owner remains unchanged")
	assert_false(_f.orders.is_publishing(project, Contract.COMMIT, furniture, _f.room), "no retained permit")


func test_room_purpose_and_complete_shell_both_gate_admission() -> void:
	"""A cleared Kitchen stays a Kitchen; initial synthetic placement never relaxes production purpose rules."""
	var wrong: Vector2i = _f.pending("bed")
	var before: PackedByteArray = _f.image()
	assert_equal(_f.owner.prepare_installation(wrong), RoomCatalog.REFUSE_PURPOSE, "ordinary bed refuses Kitchen")
	assert_true(_f.image() == before, "purpose refusal changes no paid or identity state")
	var bench: Vector2i = _f.pending("kitchen_bench", 2048)
	_f.bindings.shell_complete = false
	assert_equal(_f.owner.prepare_installation(bench), &"", "selection is not a physical admission")
	before = _f.image()
	assert_false(_f.router.open_order(_f.owner, bench, _f.owner.prepared_operation()).ok, "unfinished shell cannot admit furnishing work")
	assert_true(_f.image() == before, "refused shell allocates no Construction identity")
	assert_equal(_f.owner.prepared_subject(), NULL_REF, "refused admission discards only UI selection")
	assert_equal(_f.buildings.type_of_room(_f.room).value, Buildings.ROOM_TYPE_KITCHEN, "permanent type retained")


func test_unstarted_cancellation_removes_only_its_actual_furniture_source() -> void:
	"""Room floor, protected access and another pending item survive a canceled full-generation subject."""
	var furniture: Vector2i = _f.pending()
	var other: Vector2i = _f.pending("shelf", 2048)
	var project: Vector2i = _f.open(furniture)
	var inventory_before: PackedByteArray = _f.inventory.state_bytes()
	var room_revision: int = _f.space.source_revision(_f.room)
	var other_revision: int = _f.space.source_revision(other)
	assert_true(_f.router.cancel_order(project).ok, "unstarted real cancellation needs no refund capacity")
	assert_false(_f.buildings.is_live_furniture(furniture), "pending actual identity retired")
	assert_equal(_f.space.source_revision(furniture), 0, "only canceled geometry source removed")
	assert_true(_f.space.is_live_region(_f.floor_ref), "floor section still live")
	assert_equal(_f.space.source_revision(_f.room), room_revision, "whole Room source remains owned")
	assert_equal(_f.space.source_revision(other), other_revision, "foreign Furniture source unchanged")
	assert_true(_f.buildings.is_live_furniture(other), "foreign pending item retained")
	assert_true(_f.inventory.state_bytes() == inventory_before, "no material invented or removed")
	assert_false(_f.router.cancel_order(project).ok, "retired project cannot cancel twice")


func test_started_blocked_refund_retains_physical_source_then_settles_exact_real_refund() -> void:
	"""Safe worker release may occur; no physical cancellation or WIP loss happens before actual settlement."""
	var furniture: Vector2i = _f.pending()
	var project: Vector2i = _f.open(furniture)
	var job: Vector2i = _f.bind_job(project)
	_f.start(project)
	assert_true(_f.work.tick_solo(_f.jobs.directory().get_typed_row(job)).ok, "real partial work")
	var quote: Contract.Quote = Contract.Quote.new()
	assert_equal(_f.router.project_facts_into(project, quote), &"", "adopted real bill")
	var expected: PackedInt64Array = PackedInt64Array()
	for line: int in quote.input_count:
		assert_true(_f.construction.cancellation_refund_milli_into(project, line, _f.math), "actual exact refund rule")
		expected.append(_f.math.value)
	var tiny: Vector2i = _f.inventory.create_container(_f.world, 1, -1, 0, true).ref
	var geometry_before: PackedByteArray = _f.space.state_bytes()
	assert_false(_f.router.cancel_order(project, tiny).ok, "insufficient real refund capacity blocks")
	assert_true(_f.funding.is_funded(project), "paid receipt retained")
	assert_true(_f.buildings.is_live_furniture(furniture), "pending identity still owned")
	assert_true(_f.space.state_bytes() == geometry_before, "physical source/regions untouched on blocked refund")
	assert_false(_f.space.has_prepared(), "candidate discarded for retry")
	assert_true(_f.router.cancel_order(project, _f.stock).ok, "actual refund retries successfully")
	for line: int in quote.input_count:
		assert_equal(_f.inventory.total_live_milli(_f.items.compiled_id(quote.input_keys[line])), expected[line], "exact adopted refund material")
	assert_false(_f.buildings.is_live_furniture(furniture), "identity retires only after real refund")
	assert_false(_f.funding.is_funded(project), "shared WIP clears only once")


func test_current_contact_refusal_stops_work_before_material_xp_wear_or_progress_changes() -> void:
	"""Paid WIP does not turn a stale or blocked worker contact into ongoing productive authority."""
	var project: Vector2i = _f.open(_f.pending())
	var job: Vector2i = _f.bind_job(project)
	_f.start(project)
	_f.bindings.block_worker = true
	var before: PackedByteArray = _f.image()
	assert_false(_f.work.tick_solo(_f.jobs.directory().get_typed_row(job)).ok, "actual contact blocks worker")
	assert_true(_f.image() == before, "all actual worker/material/progress owners unchanged")
	_f.bindings.block_worker = false
	_f.bindings.block_action = Contract.PRODUCTIVE
	assert_false(_f.work.tick_solo(_f.jobs.directory().get_typed_row(job)).ok, "post-crew physical preparation blocks")
	assert_true(_f.image() == before, "refused preparation cannot earn labor")
	assert_equal(_f.bindings.stage_action, -1, "exact refused productive candidate discarded")
	_f.bindings.block_action = -1
	assert_true(_f.work.tick_solo(_f.jobs.directory().get_typed_row(job)).ok, "next valid actual tick succeeds")


func test_completion_contact_refusal_preserves_earned_work_wip_and_pending_geometry_for_retry() -> void:
	"""Fully earned labor cannot publish installed presence through a stale service/contact candidate."""
	var furniture: Vector2i = _f.pending()
	var project: Vector2i = _f.open(furniture)
	var job: Vector2i = _f.bind_job(project)
	_f.start(project)
	_f.finish(project, job)
	_f.bindings.block_action = Contract.COMMIT
	var before: PackedByteArray = _f.image()
	assert_false(_f.router.complete_order(project).ok, "current geometry/contact publication refuses")
	assert_true(_f.image() == before, "paid WIP/work and every live owner unchanged")
	assert_false(_f.buildings.is_furniture_installed(furniture), "no early installed presence")
	assert_equal(_f.space.source_refusal(furniture), &"", "pending actual source still matches")
	_f.bindings.block_action = -1
	assert_true(_f.router.complete_order(project).ok, "successful sealed retry uses existing paid work")
	assert_true(_f.buildings.is_furniture_installed(furniture), "retry installs once")


func test_late_foreign_binding_and_expired_coordinator_do_not_reuse_numeric_refs() -> void:
	"""Live wiring is checked after configuration; same numeric identities do not grant foreign permission."""
	var project: Vector2i = _f.open(_f.pending())
	var job: Vector2i = _f.bind_job(project)
	_f.start(project)
	_f.bindings.wired = false
	var before: PackedByteArray = _f.image()
	assert_false(_f.work.tick_solo(_f.jobs.directory().get_typed_row(job)).ok, "late foreign binding refuses")
	assert_false(_f.router.complete_order(project).ok, "foreign binding cannot complete")
	assert_true(_f.image() == before, "no late binding debit or work")
	_f.bindings.wired = true
	_f.orders = null
	assert_false(_f.work.tick_solo(_f.jobs.directory().get_typed_row(job)).ok, "expired weak Room owner refuses")
	assert_equal(_f.owner.binding_refusal(), FurnitureWork.REFUSE_BINDING, "expired owner stays unavailable")
	assert_false(_f.buildings.bind_spatial_authority(RoomOrders.new()).ok, "retained expired owner cannot be replaced")
	assert_true(_f.image() == before, "expiration cannot silently publish or clear retained accounting")


func test_stale_furniture_generation_never_retargets_a_live_project() -> void:
	"""The actual subject must remain live; replacing a slot cannot transfer paid authority."""
	var furniture: Vector2i = _f.pending()
	var project: Vector2i = _f.open(furniture)
	assert_equal(_f.owner.prepare_installation(Vector2i(furniture.x, furniture.y + 1)), RoomOrders.REFUSE_FURNITURE, "stale selected generation")
	var before: PackedByteArray = _f.image()
	var quote: Contract.Quote = Contract.Quote.new()
	assert_true(_f.router.project_facts_into(Vector2i(project.x, project.y + 1), quote) != &"", "stale project cannot supply a recipe")
	assert_false(_f.orders.is_publishing(project, Contract.COMMIT, Vector2i(furniture.x, furniture.y + 1), _f.room), "wrong generation never qualifies")
	assert_true(_f.image() == before, "stale refs never mutate live subjects")


func test_pause_keeps_pending_room_geometry_and_real_paid_work_until_resume() -> void:
	"""Pausing releases actual worker/tool use while retaining the existing subject, receipts and shape."""
	var furniture: Vector2i = _f.pending()
	var project: Vector2i = _f.open(furniture)
	var job: Vector2i = _f.bind_job(project)
	_f.start(project)
	assert_true(_f.work.tick_solo(_f.jobs.directory().get_typed_row(job)).ok, "real first contribution")
	_f.construction.remaining_mwu_into(project, _f.math)
	var remaining: int = _f.math.value
	var geometry: PackedByteArray = _f.space.state_bytes()
	assert_true(_f.router.set_paused(project, true).ok, "actual pause")
	assert_true(_f.funding.is_funded(project), "paid material retained")
	assert_true(_f.space.state_bytes() == geometry, "paused footprint stays owned")
	assert_false(_f.work.tick_solo(_f.jobs.directory().get_typed_row(job)).ok, "released paused worker cannot produce")
	assert_true(_f.router.set_paused(project, false).ok, "actual resume hold release")
	_f.assign(job)
	assert_true(_f.router.resume_work(project).ok, "actual resumed contact/tool proof")
	_f.construction.remaining_mwu_into(project, _f.math)
	assert_equal(_f.math.value, remaining, "pause/resume did not buy or lose work")
	_f.finish(project, job)
	assert_true(_f.router.complete_order(project).ok, "actual retained project installs")


func test_wrong_project_discard_and_direct_prepared_publish_leave_other_candidate_owned() -> void:
	"""Prepared geometry is not a completion permit and an unrelated caller cannot erase its stage."""
	var furniture: Vector2i = _f.pending()
	var project: Vector2i = _f.open(furniture)
	var job: Vector2i = _f.bind_job(project)
	_f.start(project)
	_f.finish(project, job)
	assert_equal(_f.orders.transition_refusal(project, Contract.COMMIT), &"", "actual cold candidate prepares")
	assert_true(_f.space.has_prepared(), "exact sparse candidate retained")
	_f.orders.discard_transition(Vector2i(project.x, project.y + 1), Contract.COMMIT)
	_f.orders.discard_transition(project, Contract.CANCEL)
	assert_true(_f.space.has_prepared(), "foreign/stale discard cannot erase candidate")
	_f.orders.publish_transition(project, Contract.COMMIT)
	_f.owner.publish_completion(project)
	assert_false(_f.buildings.is_furniture_installed(furniture), "outside-router publish grants nothing")
	assert_true(_f.funding.is_funded(project), "direct callback cannot clear shared receipt")
	_f.orders.discard_transition(project, Contract.COMMIT)
	assert_false(_f.space.has_prepared(), "exact owner can discard cold scratch")
	assert_true(_f.router.complete_order(project).ok, "actual router can now settle and publish")


func test_zero_accepted_and_post_gate_work_failure_discard_the_actual_room_candidate() -> void:
	"""A prepared Room contact must not survive real Work refusing after its initial paid-owner gate."""
	var project: Vector2i = _f.open(_f.pending())
	var job: Vector2i = _f.bind_job(project)
	_f.start(project)
	var before: PackedByteArray = _f.image()
	_f.work.fail_after_gate = true
	assert_false(_f.work.tick_solo(_f.jobs.directory().get_typed_row(job)).ok, "actual post-gate refusal")
	assert_equal(_f.bindings.stage_action, -1, "Room candidate cleared after later Work refusal")
	assert_true(_f.image() == before, "refused real Work mutates no accounting, XP or wear")
	_f.work.fail_after_gate = false
	_f.work.zero_potential = true
	var tick: Work.TickResult = _f.work.tick_solo(_f.jobs.directory().get_typed_row(job))
	assert_true(tick.ok, "zero accepted actual contribution is valid")
	assert_equal(tick.accepted_mwu, 0, "no invented work")
	assert_equal(_f.bindings.stage_action, -1, "zero accepted candidate cleared")
	assert_true(_f.image() == before, "zero contribution leaves physical and paid state unchanged")
	_f.work.zero_potential = false
	assert_true(_f.work.tick_solo(_f.jobs.directory().get_typed_row(job)).ok, "next real contribution is not stranded")


func test_rebuilt_furniture_has_a_fresh_identity_and_requires_its_full_real_recipe_again() -> void:
	"""Explicit cancellation retires that item; a new item cannot inherit an old paid completion permit."""
	var removed: Vector2i = _f.pending()
	var old_project: Vector2i = _f.open(removed)
	var job: Vector2i = _f.bind_job(old_project)
	_f.start(old_project)
	assert_true(_f.work.tick_solo(_f.jobs.directory().get_typed_row(job)).ok, "real partial first fitting labor")
	assert_true(_f.router.cancel_order(old_project, _f.stock).ok, "actual cancellation and refund")
	var replacement: Vector2i = _f.pending()
	assert_true(replacement != removed, "fresh full-generation identity")
	var next_project: Vector2i = _f.open(replacement)
	var quote: Contract.Quote = Contract.Quote.new()
	assert_equal(_f.router.project_facts_into(next_project, quote), &"", "actual new catalog work")
	assert_equal(quote.remaining_mwu, quote.total_mwu, "new item has its own full installation labor")
	assert_false(_f.router.complete_order(next_project).ok, "new unpaid item cannot borrow old receipt")
	_f.owner.publish_completion(old_project)
	assert_false(_f.buildings.is_furniture_installed(replacement), "retired callback cannot install replacement")
	assert_equal(_f.space.source_refusal(replacement), &"", "new pending geometry has exact new source facts")


func test_shared_cold_refusal_precedes_all_candidate_domain_and_handle_copies() -> void:
	"""Both actual COMMIT and CANCEL need admitted shared peak memory before any sparse preparation."""
	var furniture: Vector2i = _f.pending()
	var project: Vector2i = _f.open(furniture)
	var job: Vector2i = _f.bind_job(project)
	_f.start(project)
	_f.finish(project, job)
	assert_equal(_f.bindings.cold_begins, 0, "START and PRODUCTIVE never acquire cold storage")
	_f.bindings.cold_allowed = false
	var before: PackedByteArray = _f.image()
	var stages: int = _f.space.stage_calls
	var domains: int = _f.space.domain_calls
	assert_equal(_f.router.complete_order(project).error, &"SYNTHETIC_COLD_BUDGET", "cold complete admission denied")
	assert_equal(_f.router.cancel_order(project, _f.stock).error, &"SYNTHETIC_COLD_BUDGET", "cold cancel admission denied")
	assert_equal(_f.space.stage_calls, stages, "no real staged bank copy before budget admission")
	assert_equal(_f.space.domain_calls, domains, "no cold domain/survey allocation before admission")
	assert_equal(_f.bindings.cold_begins, 0, "no partial lease on refusal")
	assert_equal(_f.bindings.cold_ends, 0, "refused operation cannot release another lease")
	assert_true(_f.image() == before, "budget refusal preserves all actual live owners")
	_f.bindings.cold_allowed = true
	assert_true(_f.router.complete_order(project).ok, "admitted retry settles and publishes")
	assert_equal(_f.bindings.cold_begins, 1, "one exact acquired lease")
	assert_equal(_f.bindings.cold_ends, 1, "lease released only after publication and scratch cleanup")


func test_nested_shared_cold_owner_is_preserved_and_geometry_busy_attempt_releases_its_own_lease() -> void:
	"""A second operation cannot borrow or clear another arena lease, including failure before a token exists."""
	var furniture: Vector2i = _f.pending()
	var project: Vector2i = _f.open(furniture)
	var other: Vector2i = Vector2i(project.x, project.y + 1)
	assert_equal(_f.bindings.begin_cold(_f.room, furniture, other, Contract.CANCEL), &"", "explicit other synthetic cold holder")
	var stages: int = _f.space.stage_calls
	assert_equal(_f.router.cancel_order(project).error, &"SYNTHETIC_COLD_BUSY", "nested actual operation refuses")
	assert_equal(_f.bindings.cold_project, other, "other arena owner retained")
	assert_equal(_f.space.stage_calls, stages, "nested cold denial allocates no sparse bank")
	_f.bindings.end_cold(_f.room, furniture, other, Contract.CANCEL)
	var busy: SpaceOwner.Result = _f.space.begin_stage(_f.space.revision())
	assert_equal(busy.error, &"", "actual other geometry transaction")
	assert_equal(_f.router.cancel_order(project).error, &"SPACE_TRANSACTION_BUSY", "lease acquired then geometry refuses")
	assert_equal(_f.bindings.cold_project, NULL_REF, "failed pre-token operation releases only its own lease")
	assert_true(_f.space.has_prepared(), "unrelated existing sparse candidate remains owned")
	assert_true(_f.space.abort(busy.token), "other geometry owner releases its own token")
	assert_true(_f.router.cancel_order(project).ok, "retry succeeds after both real dependencies clear")
	assert_equal(_f.bindings.cold_begins, _f.bindings.cold_ends, "every successful acquisition is released exactly once")
