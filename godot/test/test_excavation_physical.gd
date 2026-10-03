extends "res://test/framework/test_case.gd"
## Concrete ECON-001–006 owner composition; only spatial qualification is explicitly synthetic.

const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
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
const Directory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const ROOM: Vector2i = Vector2i(70000, 1)
const OTHER_ROOM: Vector2i = Vector2i(70001, 1)
const ORIGIN: Vector3i = Vector3i(0, -4096, 0)

class SpatialFixture extends Contract.SpatialAuthority:
	## This fixture is never bound into production. Real UG08/09 must supply all these proofs.
	var world: Vector2i = NULL_REF
	var retained_descriptor: Contract.Domain = null
	var block_operation: StringName = &""
	var block_worker: StringName = &""
	var block_output: StringName = &""
	var publications: int = 0
	var pending_stage: int = -1
	var discard_count: int = 0
	var work_checks: int = 0
	var size: Vector3i = Vector3i(16, 1, 1)
	var publication_probe: WeakRef = null
	var accepted_publications: PackedByteArray = PackedByteArray()
	var false_publications: PackedByteArray = PackedByteArray()
	var premature_publications: PackedByteArray = PackedByteArray()

	func domain_into(out: Contract.Domain) -> bool:
		"""Describe a small exact world domain while retaining the output to test defensive copying."""
		out.world_ref = world
		out.datum_u = ORIGIN
		out.minimum_quantum = Vector3i.ZERO
		out.size_quanta = size
		retained_descriptor = out
		return true

	func room_refusal(room: Vector2i) -> StringName:
		"""Accept only the explicit synthetic room generations."""
		return &"" if room.x >= ROOM.x and room.x < ROOM.x + 64 and room.y == 1 else &"SYNTHETIC_ROOM_STALE"

	func retirement_refusal(room: Vector2i) -> StringName:
		"""No actual room or route is erased by this isolated economy fixture."""
		return room_refusal(room)

	func operation_refusal(origin: Vector3i, operation: int, stage: int, room: Vector2i) -> StringName:
		"""Inject a geometry refusal; successful results are synthetic accounting inputs only."""
		if publication_probe != null:
			var owner: Sites = publication_probe.get_ref() as Sites
			premature_publications.append(int(owner.is_publishing_spatial_transition(origin, operation, stage, room, self)))
		if stage == Contract.STAGE_WORK:
			work_checks += 1
		elif stage != Contract.STAGE_ADMIT:
			pending_stage = stage
		return block_operation if block_operation != &"" else room_refusal(room)

	func material_refusal(_origin: Vector3i, room: Vector2i, _container: Vector2i, _job: Vector2i) -> StringName:
		"""Real Inventory/Reservations still prove all material quantities and identities."""
		return room_refusal(room)

	func output_refusal(_origin: Vector3i, _operation: int, room: Vector2i,
			_container: Vector2i, _job: Vector2i, _tile: int) -> StringName:
		"""Inject actual output-contact blockage without changing real capacity rules."""
		return block_output if block_output != &"" else room_refusal(room)

	func worker_refusal(_origin: Vector3i, _operation: int, room: Vector2i,
			_job: Vector2i, _worker: Vector2i) -> StringName:
		"""Real Jobs/Work/Gear prove the worker; this isolated contact remains synthetic."""
		return block_worker if block_worker != &"" else room_refusal(room)

	func publish_transition(origin: Vector3i, operation: int, stage: int, room: Vector2i) -> void:
		"""Count publication, without making any actual map cell navigable."""
		if publication_probe != null:
			_probe_publication(origin, operation, stage, room)
		publications += 1
		pending_stage = -1

	func _probe_publication(origin: Vector3i, operation: int, stage: int, room: Vector2i) -> void:
		"""Adversarial callback observations; this test-only probe never changes actual owner state."""
		var owner: Sites = publication_probe.get_ref() as Sites
		accepted_publications.append(int(owner.is_publishing_spatial_transition(origin, operation, stage, room, self)))
		false_publications.append(int(owner.is_publishing_spatial_transition(origin + Vector3i(1, 0, 0), operation, stage, room, self)))
		false_publications.append(int(owner.is_publishing_spatial_transition(origin, operation + 1, stage, room, self)))
		false_publications.append(int(owner.is_publishing_spatial_transition(origin, operation, stage + 1, room, self)))
		false_publications.append(int(owner.is_publishing_spatial_transition(origin, operation, stage, Vector2i(room.x, room.y + 1), self)))
		false_publications.append(int(owner.is_publishing_spatial_transition(origin, operation, stage, OTHER_ROOM, self)))
		false_publications.append(int(owner.is_publishing_spatial_transition(origin, operation, stage, room, null)))
		false_publications.append(int(owner.is_publishing_spatial_transition(origin, operation, stage, room, SpatialFixture.new())))

	func discard_transition(_origin: Vector3i, _operation: int, _stage: int, _room: Vector2i) -> void:
		"""Discard only a staged synthetic candidate; real material/output ownership stays untouched."""
		discard_count += 1
		pending_stage = -1

	func ground_pile_tile_refusal(tile: int) -> StringName:
		"""The explicit synthetic output contact may host a real pile; no world terrain is changed."""
		return block_output if tile == 30 else &"SYNTHETIC_PILE_CONTACT"

	func ground_pile_owner_ref() -> Vector2i:
		"""Use the actual shared World generation as the real Inventory owner."""
		return world

class ProfiledWork extends Work:
	## Test-only attribution; all three stages execute the actual production owner methods.
	var preflight_usec: int = 0
	var publication_usec: int = 0
	var commit_usec: int = 0

	func _excavation_refusal(job_slot: int) -> StringName:
		"""Measure the actual physical owner's preflight, without skipping any check."""
		var began: int = Time.get_ticks_usec()
		var code: StringName = super._excavation_refusal(job_slot)
		preflight_usec += Time.get_ticks_usec() - began
		return code

	func _notify_excavation(job_slot: int) -> void:
		"""Measure real post-Work paid progress publication."""
		var began: int = Time.get_ticks_usec()
		super._notify_excavation(job_slot)
		publication_usec += Time.get_ticks_usec() - began

	func _commit_into(job_slot: int, out: Work.TickResult) -> bool:
		"""Measure the existing accepted work/XP/wear transaction unchanged."""
		var began: int = Time.get_ticks_usec()
		var committed: bool = super._commit_into(job_slot, out)
		commit_usec += Time.get_ticks_usec() - began
		return committed

var _residents: Residents = null
var _priorities: Priorities = null
var _schedule: Schedule = null
var _jobs: Jobs = null
var _work: Work = null
var _gear: Gear = null
var _inventory: Inventory = null
var _pool: Reservations = null
var _items: Items = null
var _construction: Construction = null
var _space: SpatialFixture = null
var _sites: Sites = null
var _world: Vector2i = NULL_REF
var _site: Vector2i = NULL_REF
var _store: Vector2i = NULL_REF
var _output: Vector2i = NULL_REF
var _resident: int = -1
var _tools: Array[Vector2i] = []
var _math: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Use actual shared identity, Job, worker, Gear, Construction and material owners."""
	_residents = Residents.new()
	_world = _residents.directory().create(Directory.KIND_WORLD)
	_priorities = Priorities.new()
	_schedule = Schedule.new(_residents.needs())
	_jobs = Jobs.new(_residents, _priorities, _schedule)
	_work = Work.new(_jobs)
	_inventory = Inventory.new(16, 512)
	_pool = Reservations.new()
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "actual authored item catalog loads")
	_gear = Gear.new(256)
	assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual Gear binds")
	assert_true(_work.bind_gear(_gear).ok, "actual Work binds Gear")
	_store = _inventory.create_container(_world, 100000, -1, 0, true).ref
	_output = _inventory.create_container(_world, 100000, -1, 0, true).ref
	_construction = Construction.new(Buildings.new(_residents.directory()))
	_space = SpatialFixture.new()
	_space.world = _world
	_sites = Sites.new(_construction, _inventory, _pool, _items, _jobs, _work, _space, 512, 8)
	assert_equal(_sites.initialization_refusal(), &"", "actual physical owners bind")
	_site = _sites.claim_quantum(ORIGIN, ROOM).ref
	_resident = _worker()


func after_each() -> void:
	"""Drop the composed world and all explicitly synthetic geometry state between tests."""
	_sites = null
	_space = null
	_construction = null
	_gear = null
	_work = null
	_jobs = null
	_schedule = null
	_priorities = null
	_residents = null
	_pool = null
	_items = null
	_inventory = null
	_tools.clear()


func _worker(stage: int = Residents.LIFE_STAGE_ADULT) -> int:
	"""Create an eligible base-rate resident and equip an actual durable general tool."""
	var resident: int = _residents.spawn_with_stage(&"mouse", stage).value
	assert_true(_priorities.spawn(resident).ok, "worker priorities spawn")
	assert_true(_schedule.spawn(resident, _schedule.default_template_id().value).ok, "schedule spawns")
	assert_true(_schedule.resolve(resident, 8, false).ok, "real work-hour eligibility resolves")
	assert_true(_jobs.spawn_agent(resident).ok, "actual JobAgent spawns")
	for need: int in Needs.NEED_COUNT:
		var present: int = _residents.needs().need_of(resident, need).value
		assert_true(_residents.needs().apply_need_event(resident, need, 5000 - present).ok, "base-rate mood")
	var tool: Vector2i = _lot(&"tool", Gear.GEAR_LOT_QUANTITY_MILLI)
	assert_true(_gear.create_gear(_inventory, _items, tool, Gear.MANUFACTURE_BASIC).ok, "actual tool creates")
	assert_true(_gear.equip(tool, _residents.ref_of(resident)).ok, "actual tool equips")
	_tools.append(tool)
	return resident


func _lot(key: StringName, quantity: int) -> Vector2i:
	"""Create fixture starting materials; cut earth is only ever produced by actual Sites."""
	var made: Inventory.OpResult = _inventory.create_lot(_store, _items.compiled_id(key),
		quantity, 1, Catalog.PROVENANCE_ORDINARY, -1, 0, 0)
	assert_true(made.ok, "actual material lot creates: %s" % made.error)
	return made.ref


func _open(operation: int, site: Vector2i = Vector2i(-1, 0), worker: int = -1) -> int:
	"""Open a real paid phase and Job, bind actual worker/tool, but do not begin productive work."""
	if site == NULL_REF:
		site = _site
	if worker == -1:
		worker = _resident
	var opened: Construction.OpResult = _sites.open_phase(site, operation)
	assert_true(opened.ok, "physical phase opens: %s" % opened.error)
	_construction.remaining_mwu_into(opened.ref, _math)
	var job: int = _jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, _math.value, 0).value
	assert_true(_jobs.set_requester(job, opened.ref).ok, "Job names actual Construction generation")
	assert_true(_jobs.set_tool_gate(job, Jobs.GATE_SATISFIED).ok, "equipment requirement is explicit")
	assert_true(_sites.bind_job(site, _jobs.ref_of(job)).ok, "phase binds actual Job")
	assert_true(_sites.bind_material_container(site, _store).ok, "delivered location binds")
	if operation == Contract.OP_CUT or operation == Contract.OP_BACKFILL_CLOSE \
			or operation == Contract.OP_UNOPENED_SUPPORT_CLOSE:
		assert_true(_sites.bind_output(site, _output).ok, "actual finite output binds")
	assert_true(_jobs.assign_worker(worker, job).ok, "actual worker assigns")
	assert_true(_work.claim_tool_for_work(worker, _tools[worker]).ok, "actual equipped tool claims")
	return job


func _deliver(operation: int, job: int, site: Vector2i = Vector2i(-1, 0)) -> void:
	"""Use real material claims; earth input is physically moved from prior actual cut output."""
	if site == NULL_REF:
		site = _site
	for line: int in Contract.input_count(operation):
		var key: StringName = Contract.input_key(operation, line)
		var quantity: int = Contract.input_milli(operation, line)
		var lot: Vector2i = _find_lot(_output, key) if key == &"excavated_earth" else _lot(key, quantity)
		if key == &"excavated_earth":
			assert_true(_inventory.move_lot(lot, _store).ok, "actual previously cut earth hauled to input")
		var batch: PackedInt64Array = PackedInt64Array([lot.x, lot.y,
			Reservations.PURPOSE_EXCAVATION_INPUT, quantity, 100000])
		assert_true(_pool.claim_batch(_jobs.ref_of(job), batch, 1, _inventory).ok, "real Job claims input")
	if Contract.input_count(operation) > 0:
		var recorded: Construction.OpResult = _sites.record_deliveries(site)
		assert_true(recorded.ok, "Construction delivery derives from actual claims: %s" % recorded.error)


func _find_lot(container: Vector2i, key: StringName) -> Vector2i:
	"""Read actual loose stock without creating a substitute earth source."""
	var lot: Vector2i = _inventory.container_first_lot(container)
	while lot != NULL_REF and _inventory.lot_item_id(lot) != _items.compiled_id(key):
		lot = _inventory.container_next_lot(lot)
	return lot


func _start(operation: int, site: Vector2i = Vector2i(-1, 0), worker: int = -1) -> int:
	"""Fund a phase using real claims and bind its worker before the first actual Work tick."""
	if site == NULL_REF:
		site = _site
	var job: int = _open(operation, site, worker)
	_deliver(operation, job, site)
	assert_true(_sites.bind_worker(site).ok, "physical face binds actual worker")
	var started: Construction.OpResult = _sites.begin_phase_work(site, 0)
	assert_true(started.ok, "real paid work begins: %s" % started.error)
	return job


func _finish_work(job: int) -> int:
	"""Drive actual integer Work ticks; there is no fabricated progress or timer completion."""
	var ticks: int = 0
	while _jobs.remaining_mwu_into(job, _math) and _math.value > 0 and ticks < 1000:
		var worked: Work.TickResult = _work.tick_solo(job)
		assert_true(worked.ok, "actual Work contribution: %s" % worked.error)
		if not worked.ok:
			break
		ticks += 1
	return ticks


func _complete(operation: int) -> int:
	"""Commit actual physical output only after real worker contributions finish the phase."""
	var job: int = _start(operation)
	var ticks: int = _finish_work(job)
	var settled: Construction.OpResult = _sites.settle_phase(_site)
	assert_true(settled.ok, "physical output/support commits: %s" % settled.error)
	assert_true(_inventory.audit().ok, "actual Inventory audit passes")
	assert_true(_pool.audit(_inventory).ok, "actual claim audit passes")
	assert_equal(_sites.earth_conservation_refusal(), &"", "actual earth physical ledger balances")
	assert_equal(_sites.support_conservation_refusal(), &"", "actual wood/stone WIP-support-salvage-loss accounts balance")
	return ticks


func _phase() -> int:
	"""Read physical phase through the public owner API."""
	assert_true(_sites.phase_into(_site, _math), "physical phase reads")
	return _math.value


func test_real_worker_brace_cut_finish_matches_adopted_arithmetic_and_wear() -> void:
	"""One 1m3 quantum costs 9WU, wood250/stone250, outputs earth2000, and takes 113 base ticks."""
	assert_equal(_complete(Contract.OP_BRACE), 25, "brace is exactly 25 base ticks")
	assert_equal(_phase(), Sites.BRACED, "installed support precedes every cut")
	assert_equal(_complete(Contract.OP_CUT), 50, "cut is exactly 50 base ticks")
	assert_equal(_phase(), Sites.OPEN_UNFINISHED, "open unfinished differs from supported usable void")
	assert_equal(_complete(Contract.OP_FINISH), 38, "finish caps its last accepted tick")
	assert_equal(_phase(), Sites.SUPPORTED_VOID, "finished empty shell is supported")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 2000, "actual earth exists")
	assert_equal(_sites.virgin_sourced_milli(), 2000, "one geological source event")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"wood")), 0, "brace wood consumed")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"stone")), 0, "brace stone consumed")
	assert_equal(_work.wear_remainder_of(_resident).value, 9000, "actual contributor retains wear across phases")
	assert_false(_sites.open_phase(_site, Contract.OP_CUT).ok, "finished quantum cannot cut twice")
	assert_equal(_sites.legacy_save_refusal(), &"EXCAVATION_VERSIONED_CODEC_REQUIRED", "retired projects retain required physical history")


func test_backfill_and_recut_withdraw_embedded_earth_without_new_virgin_source() -> void:
	"""Coupled closure publishes salvage once; a fresh phase later reclaims exactly that stock."""
	_complete(Contract.OP_BRACE)
	_complete(Contract.OP_CUT)
	_complete(Contract.OP_FINISH)
	assert_equal(_complete(Contract.OP_BACKFILL_CLOSE), 54, "4.25WU closure needs 54 actual base ticks")
	assert_equal(_phase(), Sites.BACKFILLED, "closure leaves solid paid backfill")
	assert_equal(_sites.embedded_earth_milli(_site), 2000, "actual consumed input now embedded")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 0, "no loose duplicate earth")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"wood")), 125, "half brace wood salvaged only at closure")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"stone")), 125, "half brace stone salvaged only at closure")
	assert_true(_sites.release_room_claim(_site).ok, "safely backfilled old room can retire")
	assert_equal(_sites.claim_quantum(ORIGIN, OTHER_ROOM).ref, _site, "new room inherits same physical key")
	_complete(Contract.OP_BRACE)
	_complete(Contract.OP_CUT)
	assert_equal(_sites.embedded_earth_milli(_site), 0, "recut withdraws embedded earth")
	assert_equal(_sites.virgin_sourced_milli(), 2000, "new project/type does not create fresh geology")
	var earth: Vector2i = _find_lot(_output, &"excavated_earth")
	assert_equal(_inventory.lot_provenance(earth), Catalog.PROVENANCE_BACKFILL_RECLAIM, "actual output is reclaimed")


func test_immutable_datum_overlap_and_stale_site_identity_refuse_without_mutation() -> void:
	"""Picked world coordinates map exactly; an adapter cannot slide an existing economic key."""
	_space.retained_descriptor.datum_u += Vector3i(1024, 1024, 1024)
	assert_equal(_sites.origin_of(_site), ORIGIN, "bound owner copied the immutable world datum")
	var before: PackedByteArray = _sites.state_bytes()
	assert_equal(_sites.claim_quantum(ORIGIN, OTHER_ROOM).error, Sites.REFUSE_OVERLAP, "overlap cannot reprice the same earth")
	assert_equal(_sites.claim_quantum(ORIGIN + Vector3i(1, 0, 0), ROOM).error, Sites.REFUSE_DOMAIN, "partial quantum never rounded")
	assert_false(_sites.open_phase(Vector2i(_site.x, 2), Contract.OP_BRACE).ok, "stale physical generation refuses")
	assert_equal(_sites.state_bytes(), before, "invalid candidates preserve all physical history")


func test_direct_construction_cannot_bypass_real_paid_owner() -> void:
	"""Numeric delivery/work counters and passing the authority object cannot fake settlement."""
	var job: int = _open(Contract.OP_BRACE)
	var project: Vector2i = _jobs.requester_of(job)
	var before: PackedByteArray = _construction.state_bytes()
	assert_equal(_construction.deliver_material(project, 0, 250).error, Construction.REFUSE_COORDINATOR_ONLY, "fake delivery denied")
	assert_equal(_construction.begin_work(project).error, Construction.REFUSE_COORDINATOR_ONLY, "free start denied")
	assert_equal(_construction.add_work_mwu(project, 2000).error, Construction.REFUSE_COORDINATOR_ONLY, "fake progress denied")
	assert_equal(_construction.begin_refund(project).error, Construction.REFUSE_COORDINATOR_ONLY, "external refund denied")
	assert_equal(_construction.retire_excavation_phase(project, _sites).error,
		Construction.REFUSE_COORDINATOR_ONLY, "mere authority identity is not committed output")
	assert_equal(_construction.state_bytes(), before, "all generic bypasses preserve actual project")


func test_direct_construction_pause_stops_work_without_wu_xp_wear_or_inventory_mutation() -> void:
	"""A revision pause reaches actual Work even before the coordinator releases worker leases."""
	var job: int = _start(Contract.OP_BRACE)
	assert_true(_work.tick_solo(job).ok, "one real productive tick precedes pause")
	assert_true(_construction.set_paused(_jobs.requester_of(job), true).ok, "actual Construction pauses")
	var work_before: PackedByteArray = _work.state_bytes()
	var jobs_before: PackedByteArray = _jobs.state_bytes()
	var gear_before: PackedByteArray = _gear.state_bytes()
	var inventory_before: PackedByteArray = _inventory.state_bytes()
	assert_equal(_work.tick_solo(job).error, Construction.REFUSE_PAUSED, "direct Work obeys owner pause")
	assert_equal(_work.state_bytes(), work_before, "no WU/XP/remainder mutation")
	assert_equal(_jobs.state_bytes(), jobs_before, "no Job work mutation")
	assert_equal(_gear.state_bytes(), gear_before, "no tool wear mutation")
	assert_equal(_inventory.state_bytes(), inventory_before, "no material mutation")
	assert_true(_sites.set_paused(_site, true).ok, "owner pause releases actual worker")
	assert_equal(_jobs.worker_of(job), NULL_REF, "actual Job worker released")
	assert_equal(_gear.claim_job_of(_tools[_resident]), NULL_REF, "actual Gear claim released")
	assert_equal(_work.wear_remainder_of(_resident).value, 80, "contributor wear carry survives pause")


func test_started_brace_cancel_returns_80_percent_and_requires_full_new_input() -> void:
	"""Cancellation retains performed work, but no installed support or free refunded funding."""
	var job: int = _start(Contract.OP_BRACE)
	for tick: int in 5:
		assert_true(_work.tick_solo(job).ok, "actual partial bracing")
	assert_true(_sites.cancel_phase(_site, _store).ok, "real refund commits")
	assert_equal(_phase(), Sites.BRACING, "partial physical work persists")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"wood")), 200, "actual wood refund")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"stone")), 200, "actual stone refund")
	var resumed: int = _open(Contract.OP_BRACE)
	assert_equal(_jobs.remaining_mwu_of(resumed).value, 1600, "new phase reads physical earned work")
	assert_true(_sites.bind_worker(_site).ok, "actual worker rebinds")
	assert_false(_sites.begin_phase_work(_site, 1).ok, "retained work alone is not funding")
	_deliver(Contract.OP_BRACE, resumed)
	assert_true(_sites.begin_phase_work(_site, 1).ok, "full new phase bill funds resumed work")
	assert_equal(_finish_work(resumed), 20, "only remaining WU is performed")
	assert_true(_sites.settle_phase(_site).ok, "funded remaining work installs support")
	assert_equal(_work.wear_remainder_of(_resident).value, 2000, "cancellation never resets contributor wear")


func test_unopened_support_close_has_salvage_but_no_earth_input_or_output() -> void:
	"""The adopted never-opened solid exception removes support after exactly 1.25WU."""
	_complete(Contract.OP_BRACE)
	assert_equal(_complete(Contract.OP_UNOPENED_SUPPORT_CLOSE), 16, "actual 1.25WU costs 16 base ticks")
	assert_equal(_phase(), Sites.SOLID, "never-opened terrain remains solid")
	assert_equal(_sites.virgin_sourced_milli(), 0, "support removal creates no geological source")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"wood")), 125, "actual half wood salvage")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"stone")), 125, "actual half stone salvage")
	assert_false(_sites.open_phase(_site, Contract.OP_UNOPENED_SUPPORT_CLOSE).ok, "cannot salvage the same support twice")


func test_late_requester_job_blocks_refund_without_orphaning_its_claims() -> void:
	"""Late binding cannot evade the physical owner's safe settlement scan."""
	var job: int = _start(Contract.OP_BRACE)
	var late: int = _jobs.create_job(Jobs.JOB_KIND_HAUL, 0, 0, 100, 0).value
	assert_true(_jobs.set_requester(late, _jobs.requester_of(job)).ok, "late hauling requester binds")
	var before: PackedByteArray = _sites.state_bytes()
	assert_equal(_sites.cancel_phase(_site, _store).error, Sites.REFUSE_JOB, "late owner blocks retirement")
	assert_equal(_sites.state_bytes(), before, "late-owner refusal preserves WIP/physical state")
	assert_true(_jobs.destroy_job(late).ok, "external owner safely retires its own unused job")
	assert_true(_sites.cancel_phase(_site, _store).ok, "cancellation succeeds after real owner release")


func test_sparse_history_budget_refuses_before_payment_and_never_recycles_retired_keys() -> void:
	"""Untouched world cells need no dense record; finite history pressure never erases paid identity."""
	for index: int in [7, 2, 1, 6, 3, 5, 4]:
		var origin: Vector3i = ORIGIN + Vector3i(index * 1024, 0, 0)
		var site: Vector2i = _sites.claim_quantum(origin, ROOM).ref
		assert_true(_sites.is_live_site(site), "sparse key inserted in arbitrary draw order")
		assert_equal(_sites.origin_of(site), origin, "derived sorted index preserves physical key")
	var before: PackedByteArray = _sites.state_bytes()
	assert_equal(_sites.claim_quantum(ORIGIN + Vector3i(8192, 0, 0), ROOM).error,
		Sites.REFUSE_SITE_CAPACITY, "in-domain ninth record exhausts explicit eight-record engineering budget")
	assert_equal(_sites.state_bytes(), before, "budget refusal changes no owner state")
	assert_true(_sites.release_room_claim(_site).ok, "unbuilt room claim may retire")
	assert_equal(_sites.claim_quantum(ORIGIN, OTHER_ROOM).ref, _site, "retirement rebinds original record")
	assert_equal(_sites.claim_quantum(ORIGIN + Vector3i(8192, 0, 0), ROOM).error,
		Sites.REFUSE_SITE_CAPACITY, "retirement never frees a physical key to reset geology")


func test_material_free_cancel_and_resume_retains_actual_cut_work_without_refund_storage() -> void:
	"""A partial cut refunds nothing and preserves its geological source until one successful commit."""
	_complete(Contract.OP_BRACE)
	var job: int = _start(Contract.OP_CUT)
	for tick: int in 10:
		assert_true(_work.tick_solo(job).ok, "real partial cutting")
	assert_true(_sites.cancel_phase(_site, NULL_REF).ok, "material-free cancellation needs no returned-lot capacity")
	assert_equal(_phase(), Sites.CUTTING, "partial physical cutting remains")
	assert_equal(_sites.virgin_sourced_milli(), 0, "partial cut has not published earth")
	assert_equal(_inventory.container_reserved_mass_g(_output), 0, "actual pending output claim releases")
	var resumed: int = _start(Contract.OP_CUT)
	assert_equal(_jobs.remaining_mwu_of(resumed).value, 3200, "full retained physical work survives rebinding")
	assert_equal(_finish_work(resumed), 40, "only unpaid remaining labor advances")
	assert_true(_sites.settle_phase(_site).ok, "one actual cut output commits")
	assert_equal(_sites.virgin_sourced_milli(), 2000, "one geological source after resumption")
	assert_equal(_sites.earth_conservation_refusal(), &"", "cancellation/rebind conservation holds")


func test_paused_paid_phase_resumes_with_same_wip_after_real_worker_rebind() -> void:
	"""Reassigning after pause preserves input payment and accepted WU rather than restarting them."""
	var job: int = _start(Contract.OP_BRACE)
	assert_true(_work.tick_solo(job).ok, "one productive tick")
	assert_true(_sites.set_paused(_site, true).ok, "pause releases real leases")
	var inventory_before: PackedByteArray = _inventory.state_bytes()
	assert_true(_sites.set_paused(_site, false).ok, "hold releases")
	assert_true(_jobs.assign_worker(_resident, job).ok, "actual resident reassigns")
	assert_true(_work.claim_tool_for_work(_resident, _tools[_resident]).ok, "actual Gear reclaims")
	assert_true(_sites.bind_worker(_site).ok, "face registers actual rebind")
	assert_true(_sites.resume_phase_work(_site).ok, "paid phase resumes without another delivery")
	assert_equal(_inventory.state_bytes(), inventory_before, "resuming consumes no second input")
	assert_equal(_finish_work(job), 24, "remaining 1920mWU only")
	assert_true(_sites.settle_phase(_site).ok, "same paid brace completes")
	assert_equal(_work.wear_remainder_of(_resident).value, 2000, "actual wear combines both intervals")


func test_required_tool_gate_never_allows_unclaimed_bare_hands_work() -> void:
	"""Even a generic caller cannot turn the required-equipment declaration into free productivity."""
	var job: int = _jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, 2000, 0).value
	assert_true(_jobs.set_tool_gate(job, Jobs.GATE_SATISFIED).ok, "job explicitly requires equipment")
	assert_true(_jobs.assign_worker(_resident, job).ok, "actual eligible worker assigns")
	assert_true(_jobs.set_state(job, Jobs.JOB_STATE_WORK).ok, "generic job requests productivity")
	var work_before: PackedByteArray = _work.state_bytes()
	var jobs_before: PackedByteArray = _jobs.state_bytes()
	var gear_before: PackedByteArray = _gear.state_bytes()
	assert_equal(_work.tick_solo(job).error, Work.REFUSE_TOOL_NOT_CLAIMED, "equipped but unclaimed tool is not productive")
	assert_equal(_work.state_bytes(), work_before, "no work/XP carry credited")
	assert_equal(_jobs.state_bytes(), jobs_before, "no Job work consumed")
	assert_equal(_gear.state_bytes(), gear_before, "no uncontrolled equipment side effect")
	assert_true(_work.claim_tool_for_work(_resident, _tools[_resident]).ok, "actual ownership resolves blocker")
	assert_true(_work.tick_solo(job).ok, "real claimed equipment enables work")
	assert_true(_jobs.set_tool_gate(job, Jobs.GATE_BLOCKED).ok, "equipment qualification changes")
	assert_equal(_work.tick_solo(job).error, Work.REFUSE_TOOL_GATE_BLOCKED, "bound tool cannot bypass blocked gate")


func test_four_builders_per_room_project_and_one_actual_worker_per_face() -> void:
	"""Independent work faces share the authored project cap, while a separate room has its own cap."""
	for index: int in 6:
		var worker: int = _resident if index == 0 else _worker()
		var room: Vector2i = OTHER_ROOM if index == 5 else ROOM
		var site: Vector2i = _sites.claim_quantum(ORIGIN + Vector3i(index * 1024, 0, 0), room).ref
		var job: int = _open(Contract.OP_BRACE, site, worker)
		var bound: Construction.OpResult = _sites.bind_worker(site)
		if index == 4:
			assert_equal(bound.error, Sites.REFUSE_BUILDER_CAP, "fifth worker on one room project refuses")
		else:
			assert_true(bound.ok, "first four and another room admit real workers")
		assert_equal(_jobs.worker_of(job), _residents.ref_of(worker), "single face has one actual worker")
	var extra: int = _worker()
	var first_job: int = _jobs.directory().get_typed_row(_jobs.job_of(_resident))
	assert_false(_jobs.assign_worker(extra, first_job).ok, "a second resident cannot own the occupied face")


func test_blocked_output_commit_preserves_ready_work_and_retry_charges_no_additional_wear() -> void:
	"""A completed cut waits for actual contact without returning to productive work or minting output."""
	_complete(Contract.OP_BRACE)
	var job: int = _start(Contract.OP_CUT)
	assert_equal(_finish_work(job), 50, "actual cut labor completes")
	var work_before: PackedByteArray = _work.state_bytes()
	var inventory_before: PackedByteArray = _inventory.state_bytes()
	var sites_before: PackedByteArray = _sites.state_bytes()
	_space.block_output = &"SYNTHETIC_OUTPUT_BLOCKED"
	assert_equal(_sites.settle_phase(_site).error, _space.block_output, "real output-contact blocker shown")
	assert_equal(_work.state_bytes(), work_before, "refused commit spends no WU/XP/wear")
	assert_equal(_inventory.state_bytes(), inventory_before, "no premature earth or lost reservation")
	assert_equal(_sites.state_bytes(), sites_before, "ready work/WIP/physical source retained")
	assert_false(_work.tick_solo(job).ok, "work-ready phase cannot spend extra productive ticks")
	_space.block_output = &""
	assert_true(_sites.settle_phase(_site).ok, "same work-ready phase retries")
	assert_equal(_work.wear_remainder_of(_resident).value, 6000, "exact paid brace+cut contributor wear")
	assert_equal(_sites.virgin_sourced_milli(), 2000, "retry publishes one actual source event")
	assert_false(_sites.settle_phase(_site).ok, "retired phase cannot commit twice")


func test_backfill_cancellation_preserves_void_support_and_books_exact_earth_loss() -> void:
	"""Uncommitted closure never embeds its refunded earth or publishes salvage."""
	_complete(Contract.OP_BRACE)
	_complete(Contract.OP_CUT)
	_complete(Contract.OP_FINISH)
	var job: int = _start(Contract.OP_BACKFILL_CLOSE)
	assert_true(_work.tick_solo(job).ok, "real closure begins")
	assert_true(_sites.cancel_phase(_site, _store).ok, "backfill cancellation returns actual current phase inputs")
	assert_equal(_phase(), Sites.CLOSING, "partial closure state remains explicit until geometry revalidation")
	assert_equal(_sites.embedded_earth_milli(_site), 0, "uncommitted input never becomes embedded")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 1600, "actual 80 percent earth returned")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"wood")), 0, "no early support salvage")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"stone")), 0, "installed support remains")
	assert_equal(_sites.earth_conservation_refusal(), &"", "remaining 400 earth recorded as cancellation loss")
	assert_false(_sites.release_room_claim(_site).ok, "partly closed installed void cannot silently retire")


func test_support_contact_and_stale_world_refusals_precede_all_productive_state() -> void:
	"""Missing real geometry proof and recycled World identity never become permissive defaults."""
	_space.block_operation = &"SYNTHETIC_SUPPORT_REQUIRED"
	var before: PackedByteArray = _sites.state_bytes()
	assert_equal(_sites.open_phase(_site, Contract.OP_BRACE).error, _space.block_operation, "missing support refuses")
	assert_equal(_sites.state_bytes(), before, "admission refusal changes no physical ledger")
	_space.block_operation = &""
	var job: int = _open(Contract.OP_BRACE)
	_deliver(Contract.OP_BRACE, job)
	assert_true(_sites.bind_worker(_site).ok, "actual worker exists before contact changes")
	_space.block_worker = &"SYNTHETIC_WORK_CONTACT_BLOCKED"
	var inventory_before: PackedByteArray = _inventory.state_bytes()
	assert_equal(_sites.begin_phase_work(_site, 0).error, _space.block_worker, "contact refusal precedes consumption")
	assert_equal(_inventory.state_bytes(), inventory_before, "actual delivered goods remain")
	assert_true(_residents.directory().destroy(_world), "fixture retires World owner")
	assert_false(_sites.begin_phase_work(_site, 0).ok, "stale World cannot advance its old physical ledger")
	assert_equal(_inventory.state_bytes(), inventory_before, "stale identity changes no goods")


func test_manual_job_counter_and_callback_cannot_impersonate_real_work_transaction() -> void:
	"""Only Work's synchronous post-commit proof may publish physical earned WU."""
	var job: int = _start(Contract.OP_BRACE)
	var project: Vector2i = _jobs.requester_of(job)
	assert_false(_work.is_publishing_excavation_tick(_jobs.ref_of(job)), "no saved or external publication permit")
	assert_true(_jobs.set_remaining_mwu(job, 0).ok, "unowned writer corrupts only generic Job counter")
	var before: PackedByteArray = _sites.state_bytes()
	_sites.accept_work_tick(_jobs.ref_of(job))
	assert_equal(_sites.state_bytes(), before, "direct callback grants no physical progress")
	_construction.remaining_mwu_into(project, _math)
	assert_equal(_math.value, 2000, "real paid work remains entirely outstanding")
	assert_equal(_sites.work_tick_refusal(_jobs.ref_of(job)), Sites.REFUSE_JOB, "owner disagreement is diagnosed")
	assert_false(_sites.settle_phase(_site).ok, "corrupted Job cannot commit installed support")


func test_work_ready_cancel_requires_full_refunding_but_no_additional_productive_tick() -> void:
	"""Work done before output publication survives cancellation without enabling unfunded completion."""
	var job: int = _start(Contract.OP_BRACE)
	assert_equal(_finish_work(job), 25, "actual full 2000mWU earned")
	assert_true(_sites.cancel_phase(_site, _store).ok, "unpublished support inputs refund once")
	assert_equal(_sites.support_conservation_refusal(), &"", "refund/loss/remaining work accounts balance")
	var resumed: int = _open(Contract.OP_BRACE)
	assert_equal(_jobs.remaining_mwu_of(resumed).value, 0, "work-ready labor survives project retirement")
	assert_true(_sites.bind_worker(_site).ok, "actual worker still validates the completion contact")
	assert_false(_sites.begin_phase_work(_site, 1).ok, "zero remaining work is not a free bill")
	_deliver(Contract.OP_BRACE, resumed)
	assert_true(_sites.begin_phase_work(_site, 1).ok, "full new inputs fund retained ready work")
	assert_equal(_finish_work(resumed), 0, "retained work spends no second WU or wear tick")
	assert_true(_sites.settle_phase(_site).ok, "paid supported phase commits once")
	assert_equal(_work.wear_remainder_of(_resident).value, 2000, "contributor retains only actual earned work")
	assert_equal(_sites.support_conservation_refusal(), &"", "new support/refund/loss balance remains exact")


func test_real_inventory_lot_exhaustion_keeps_cut_ready_after_worker_release() -> void:
	"""Output allocation can fail after labor completes; retry consumes no new work or source."""
	_complete(Contract.OP_BRACE)
	var job: int = _start(Contract.OP_CUT)
	_finish_work(job)
	var project: Vector2i = _jobs.requester_of(job)
	var removable: Vector2i = NULL_REF
	while _inventory.live_lot_count() < 512:
		removable = _lot(&"wood", 1)
	var inventory_before: PackedByteArray = _inventory.state_bytes()
	assert_equal(_sites.settle_phase(_site).error, Inventory.REFUSE_CAPACITY_INVENTORY_LOT, "actual lot budget blocks output")
	assert_equal(_inventory.state_bytes(), inventory_before, "all output writes and capacity release roll back")
	assert_equal(_jobs.worker_of(job), NULL_REF, "completed worker was safely released")
	assert_true(_construction.phase_into(project, _math), "paid phase still exists")
	assert_equal(_math.value, Construction.PHASE_WORK_DONE, "labor remains ready")
	assert_equal(_sites.virgin_sourced_milli(), 0, "blocked transaction creates no geological source")
	assert_true(_inventory.sink_lot_quantity(removable, 1).ok, "other owner frees one real lot row")
	assert_true(_sites.settle_phase(_site).ok, "worker-free ready phase retries publication")
	assert_equal(_work.wear_remainder_of(_resident).value, 6000, "no retry WU/XP/wear")
	assert_equal(_sites.virgin_sourced_milli(), 2000, "one source event finally commits")


func test_cancelled_partial_cut_can_safely_remove_unopened_support_without_earth() -> void:
	"""A quantum still physically solid uses the explicit never-opened closure after partial work."""
	_complete(Contract.OP_BRACE)
	var job: int = _start(Contract.OP_CUT)
	assert_true(_work.tick_solo(job).ok, "partial cut performs actual work")
	assert_true(_sites.cancel_phase(_site, NULL_REF).ok, "cancelled material-free cut retains history")
	assert_equal(_complete(Contract.OP_UNOPENED_SUPPORT_CLOSE), 16, "never-opened support closes safely")
	assert_equal(_phase(), Sites.SOLID, "terrain never became a void")
	assert_equal(_sites.virgin_sourced_milli(), 0, "no invented excavation output")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 0, "no earth debit or credit")
	assert_equal(_sites.support_conservation_refusal(), &"", "actual installed support becomes exact salvage and loss")


func test_concrete_first_cut_uses_finite_staging_then_actual_ground_pile() -> void:
	"""The concrete worker/physical owner completes the same staged output transaction as B2."""
	assert_true(_inventory.set_ground_pile_authority(_space).ok, "actual pile owner interface binds")
	_complete(Contract.OP_BRACE)
	var job: int = _open(Contract.OP_CUT)
	var staging: Vector2i = _inventory.create_container(_world,
		Inventory.GROUND_PILE_MAX_MASS_G, -1, 0, true, 30).ref
	assert_true(_sites.bind_output(_site, staging, 30).ok, "site proves finite pending output contact")
	assert_true(_sites.bind_worker(_site).ok, "actual worker binds")
	assert_true(_sites.begin_phase_work(_site, 0).ok, "cut reserves real pending capacity")
	assert_equal(_inventory.container_reserved_mass_g(staging), 2000, "real mass reserved before first tick")
	assert_equal(_inventory.ground_pile_at_tile(30), NULL_REF, "empty staging is not a forbidden lotless pile")
	assert_equal(_finish_work(job), 50, "actual productive cut work")
	assert_true(_sites.settle_phase(_site).ok, "one physical transaction publishes output/pile/source")
	assert_equal(_inventory.ground_pile_at_tile(30), staging, "same nonempty row becomes actual pile")
	assert_equal(_inventory.container_reserved_mass_g(staging), 0, "owned reservation settled once")
	assert_equal(_inventory.lot_quantity_milli(_inventory.container_first_lot(staging)), 2000, "actual earth occupies pile")
	assert_equal(_sites.earth_conservation_refusal(), &"", "physical virgin ledger matches output")


func test_unbound_spatial_contract_never_supplies_production_permission() -> void:
	"""The shipped abstract adapter cannot admit or pay for one quantum."""
	var construction: Construction = Construction.new(Buildings.new(_residents.directory()))
	var work: Work = Work.new(_jobs)
	assert_true(work.bind_gear(_gear).ok, "ordinary actual owner composition is valid")
	var unbound: Contract.SpatialAuthority = Contract.SpatialAuthority.new()
	var sites: Sites = Sites.new(construction, _inventory, _pool, _items, _jobs, work, unbound, 8, 8)
	assert_equal(sites.initialization_refusal(), Sites.REFUSE_DOMAIN, "missing real domain refuses")
	var before: PackedByteArray = _inventory.state_bytes()
	assert_false(sites.claim_quantum(ORIGIN, ROOM).ok, "no trusted true geometry fallback")
	assert_false(sites.open_phase(Vector2i(0, 1), Contract.OP_BRACE).ok, "no fake paid phase")
	assert_equal(_inventory.state_bytes(), before, "unbound world changes no material state")


func test_external_worker_detach_is_diagnosed_before_replacement_or_retirement() -> void:
	"""Unowned Job writes cannot erase a full-generation work-face binding or leave duplicate workers."""
	var job: int = _start(Contract.OP_BRACE)
	assert_true(_jobs.release_worker(_resident).ok, "external writer detaches generic Job only")
	assert_equal(_sites.release_worker(_site).error, Sites.REFUSE_WORKER, "orphaned registered face is explicit")
	var replacement: int = _worker()
	assert_true(_jobs.assign_worker(replacement, job).ok, "generic Job now has a different worker")
	assert_true(_work.claim_tool_for_work(replacement, _tools[replacement]).ok, "replacement claims its own actual tool")
	assert_equal(_sites.bind_worker(_site).error, Sites.REFUSE_WORKER, "old registered identity prevents silent face overwrite")
	assert_false(_sites.resume_phase_work(_site).ok, "unreconciled owner state cannot become productive")


func _expand_fixture_domain_for_population() -> void:
	"""Replace only the empty test composition before any paid operation, with explicit budgets."""
	_sites = null
	_construction = Construction.new(Buildings.new(_residents.directory()))
	_work = ProfiledWork.new(_jobs)
	assert_true(_work.bind_gear(_gear).ok, "fresh fixture Work binds actual Gear")
	_space.size = Vector3i(256, 1, 1)
	_sites = Sites.new(_construction, _inventory, _pool, _items, _jobs, _work, _space, 512, 256)
	assert_equal(_sites.initialization_refusal(), &"", "explicit 256-record sparse history budget binds")
	_site = _sites.claim_quantum(ORIGIN, ROOM).ref


func _populate_256_work_faces() -> PackedInt32Array:
	"""Exactly the living population cap, split over 64 four-worker room projects."""
	_expand_fixture_domain_for_population()
	var jobs: PackedInt32Array = PackedInt32Array()
	for index: int in 256:
		var worker: int = _resident if index == 0 else _worker()
		@warning_ignore("integer_division") var room: Vector2i = Vector2i(ROOM.x + index / 4, 1)
		var site: Vector2i = _sites.claim_quantum(ORIGIN + Vector3i(index * 1024, 0, 0), room).ref
		jobs.append(_start(Contract.OP_BRACE, site, worker))
	return jobs


func test_256_resident_work_and_full_job_table_transition_microbenchmark() -> void:
	"""Measure actual paid Work plus event-driven safety checks; no unmeasured frame-budget claim."""
	var jobs: PackedInt32Array = _populate_256_work_faces()
	var tick_result: Work.TickResult = Work.TickResult.new(false, &"")
	var total_usec: int = 0
	var maximum_usec: int = 0
	var refused_ticks: int = 0
	for tick: int in 10:
		var began: int = Time.get_ticks_usec()
		for job: int in jobs:
			if not _work.tick_solo_into(job, tick_result):
				refused_ticks += 1
		var elapsed: int = Time.get_ticks_usec() - began
		total_usec += elapsed
		maximum_usec = maxi(maximum_usec, elapsed)
	assert_equal(refused_ticks, 0, "all 2560 actual contributions succeeded; assertion is outside measured work")
	@warning_ignore("integer_division") var mean_usec: int = total_usec / 10
	print("UG06_WORK_256 mean_usec=%d max_usec=%d sparse_owner_image_bytes=%d" %
		[mean_usec, maximum_usec, _sites.state_bytes().size()])
	_report_work_profile()
	_assert_measured_packed_storage()
	for job: int in jobs:
		assert_equal(_jobs.remaining_mwu_of(job).value, 1200, "exact 800mWU accepted per actual worker")
	assert_equal(_sites.support_conservation_refusal(), &"", "all 512 consumed input receipts remain conserved")
	_benchmark_phase_gates()
	_benchmark_full_job_table_cancel_refusal()


func _benchmark_full_job_table_cancel_refusal() -> void:
	"""Use the real cancel API with a geometry refusal after its complete late-job scan."""
	while _jobs.job_count() < Jobs.JOB_CAPACITY:
		assert_true(_jobs.create_job(Jobs.JOB_KIND_HAUL, 0, 0, 1, 0).ok, "actual Job table fills")
	_space.block_operation = &"SYNTHETIC_PROTECTED_ROUTE"
	var maximum_usec: int = 0
	var total_usec: int = 0
	for attempt: int in 10:
		var began: int = Time.get_ticks_usec()
		var refused: Construction.OpResult = _sites.cancel_phase(_site, _store)
		var elapsed: int = Time.get_ticks_usec() - began
		assert_equal(refused.error, _space.block_operation, "event-driven refusal occurs after all owner checks")
		maximum_usec = maxi(maximum_usec, elapsed)
		total_usec += elapsed
	@warning_ignore("integer_division") var mean_usec: int = total_usec / 10
	print("UG06_CANCEL_8192 mean_usec=%d max_usec=%d" % [mean_usec, maximum_usec])


func _benchmark_phase_gates() -> void:
	"""Attribute the added hot-path cost; synthetic spatial callbacks contain no scans."""
	_benchmark_owner_gate(&"BOUND", _probe_bound_gate)
	_benchmark_owner_gate(&"SPACE", _probe_space_gate)
	_benchmark_owner_gate(&"OUTPUT", _probe_output_gate)
	_benchmark_owner_gate(&"WORKER", _probe_worker_gate)
	_benchmark_owner_gate(&"PRODUCTIVE", _probe_productive_gate)


func _report_work_profile() -> void:
	"""Report stages separately; measured methods preserve all real Work and Sites mutations."""
	var profiled: ProfiledWork = _work as ProfiledWork
	@warning_ignore("integer_division") var preflight: int = profiled.preflight_usec / 10
	@warning_ignore("integer_division") var publication: int = profiled.publication_usec / 10
	@warning_ignore("integer_division") var committed: int = profiled.commit_usec / 10
	print("UG06_STAGES_256 preflight_usec=%d publication_usec=%d commit_usec=%d" %
		[preflight, publication, committed])


func _benchmark_owner_gate(label: StringName, probe: Callable) -> void:
	"""Run repeated read-only 256-row checks with assertions and reporting outside the interval."""
	var total_usec: int = 0
	var maximum_usec: int = 0
	var refusals: int = 0
	for attempt: int in 10:
		var began: int = Time.get_ticks_usec()
		for row: int in 256:
			if probe.call(row) != &"":
				refusals += 1
		var elapsed: int = Time.get_ticks_usec() - began
		total_usec += elapsed
		maximum_usec = maxi(maximum_usec, elapsed)
	assert_equal(refusals, 0, "all profiled owner checks pass without productive mutations")
	@warning_ignore("integer_division") var mean_usec: int = total_usec / 10
	print("UG06_GATE_%s_256 mean_usec=%d max_usec=%d" % [label, mean_usec, maximum_usec])


func _probe_bound_gate(row: int) -> StringName:
	"""Measure actual world/room/project/Job identity qualification."""
	return _sites._bound_refusal(Vector2i(row, 1))


func _probe_space_gate(row: int) -> StringName:
	"""Measure exact-origin computation and the synthetic constant-time spatial callback."""
	return _sites._space_refusal(row, Contract.OP_BRACE, Contract.STAGE_WORK)


func _probe_output_gate(row: int) -> StringName:
	"""Measure the actual zero-output brace branch rather than an invented output scan."""
	return _sites._output_refusal(row)


func _probe_worker_gate(row: int) -> StringName:
	"""Measure actual resident/Job/Work/Gear generations, equipment and contact qualification."""
	return _sites._worker_refusal(row, true)


func _probe_productive_gate(row: int) -> StringName:
	"""Measure the complete productive funding/pause/progress/space/output preflight."""
	return _sites._productive_refusal(row)


func test_child_excavation_is_forbidden_even_when_generic_job_and_fixture_contact_accept() -> void:
	"""HAZ-001 is unconditional; a synthetic or future profile adapter cannot grant child excavation."""
	var child: int = _worker(Residents.LIFE_STAGE_CHILD)
	var job: int = _open(Contract.OP_BRACE, _site, child)
	_deliver(Contract.OP_BRACE, job)
	var before: PackedByteArray = _inventory.state_bytes()
	assert_equal(_sites.bind_worker(_site).error, Sites.REFUSE_CHILD, "actual resident stage forbids excavation")
	assert_equal(_sites.begin_phase_work(_site, 0).error, Sites.REFUSE_CHILD, "direct phase start cannot bypass stage rule")
	assert_equal(_inventory.state_bytes(), before, "child exclusion precedes material consumption")


func test_productive_ticks_do_not_prepare_geometry_and_failed_transitions_discard_candidates() -> void:
	"""Only start/commit/cancel prepare publication; failure cleans scratch before a later retry."""
	var job: int = _start(Contract.OP_BRACE)
	assert_equal(_space.pending_stage, -1, "successful start installed its prepared candidate")
	assert_true(_work.tick_solo(job).ok, "actual productive tick validates current space")
	assert_equal(_space.pending_stage, -1, "per-tick proof stages no new geometry")
	assert_equal(_space.work_checks, 1, "dedicated productive proof stage used")
	var tiny: Vector2i = _inventory.create_container(_world, 1, -1, 0, true).ref
	assert_equal(_sites.cancel_phase(_site, tiny).error, Inventory.REFUSE_CAPACITY_EXCEEDED, "real refund capacity blocks cancellation")
	assert_equal(_space.pending_stage, -1, "failed refund leaves no stale prepared geometry")
	assert_equal(_space.discard_count, 1, "one failed transition explicitly discarded")
	assert_true(_sites.cancel_phase(_site, _store).ok, "retry revalidates and prepares a fresh candidate")
	assert_equal(_space.pending_stage, -1, "successful retry installed only its current candidate")


func test_sites_huge_budget_refuses_without_variable_allocation_or_owner_binding() -> void:
	"""The 8MiB technical envelope is checked against the original request, never silently clamped."""
	assert_equal(Sites.MAX_SITE_CAPACITY, 73909, "exact floor((8388608-36880)/113) history rows")
	assert_equal(Sites.FIXED_PACKED_BYTES + Sites.SITE_RECORD_BYTES * Sites.MAX_SITE_CAPACITY,
		8388597, "maximum packed Sites arena includes fixed indexes and scratch")
	assert_true(Sites.FIXED_PACKED_BYTES + Sites.SITE_RECORD_BYTES * (Sites.MAX_SITE_CAPACITY + 1)
		> Sites.MAX_SITE_ARENA_BYTES, "one extra history row exceeds the declared 8MiB engineering ceiling")
	for requested: int in [-1, 0, Sites.MAX_SITE_CAPACITY + 1, 9223372036854775807]:
		var construction: Construction = Construction.new(Buildings.new(_residents.directory()))
		var work: Work = Work.new(_jobs)
		var refused: Sites = Sites.new(construction, _inventory, _pool, _items,
			_jobs, work, _space, 8, requested)
		assert_equal(refused.initialization_refusal(), Sites.REFUSE_SITE_CAPACITY, "invalid capacity explicitly refuses")
		assert_equal(refused.state_bytes().size(), 160, "only fixed scalar image; no history, index, worker or Funding arrays")
		assert_true(construction.excavation_authority() == null, "failed capacity does not bind Construction")
		assert_equal(work.excavation_binding_refusal(Contract.new()), &"", "failed capacity does not bind Work")


func test_sites_preflights_both_owner_bindings_without_partial_initialization() -> void:
	"""A refused Work or Construction binding never strands the other owner behind a dead ledger."""
	for bind_work_first: bool in [true, false]:
		var construction: Construction = Construction.new(Buildings.new(_residents.directory()))
		var work: Work = Work.new(_jobs)
		assert_true(work.bind_gear(_gear).ok, "both binding orders use valid Gear composition")
		var held: Contract = Contract.new()
		if bind_work_first:
			assert_true(work.bind_excavation_authority(held).ok, "another physical owner already holds Work")
		else:
			assert_true(construction.bind_excavation_authority(held).ok, "another physical owner already holds Construction")
		var refused: Sites = Sites.new(construction, _inventory, _pool, _items,
			_jobs, work, _space, 8, 8)
		assert_equal(refused.initialization_refusal(), Contract.REFUSE_AUTHORITY, "conflicting binding explicitly refuses")
		assert_equal(refused.state_bytes().size(), 160, "binding conflict precedes all packed allocation")
		if bind_work_first:
			assert_true(construction.bind_excavation_authority(held).ok, "Construction remains unbound and usable")
		else:
			assert_true(work.bind_excavation_authority(held).ok, "Work remains unbound and usable")


func test_refused_null_owner_public_methods_fail_safely() -> void:
	"""A configuration refusal cannot be followed by a null dereference in a public owner door."""
	var refused: Sites = Sites.new(null, null, null, null, null, null, null, 1, 1)
	assert_equal(refused.initialization_refusal(), Contract.REFUSE_AUTHORITY, "null wiring refuses")
	assert_equal(refused.open_phase(Vector2i(0, 1), Contract.OP_BRACE).error, Contract.REFUSE_AUTHORITY,
		"opening on a refused initializer reports the owner error")
	assert_equal(refused.work_tick_refusal(Vector2i(0, 1)), Contract.REFUSE_AUTHORITY, "work gate refuses safely")
	refused.accept_work_tick(Vector2i(0, 1))
	assert_equal(refused.earth_conservation_refusal(), Contract.REFUSE_AUTHORITY, "earth read refuses safely")
	assert_equal(refused.support_conservation_refusal(), Contract.REFUSE_AUTHORITY, "support read refuses safely")
	assert_true(refused.construction_owner() == null, "refused initialization exposes no bound owner")
	assert_true(refused.bound_spatial_authority() == null, "refused initialization exposes no typed spatial target")
	assert_false(refused.is_bound_spatial(_space), "refused initialization exposes no spatial binding")


func test_owner_identity_readers_refuse_numeric_aliases_null_and_expired_space() -> void:
	"""UG21 can compare actual owner objects without mistaking coincident EntityRefs for one world."""
	var other_directory: Directory = Directory.new()
	var other_world: Vector2i = other_directory.create(Directory.KIND_WORLD)
	var other_construction: Construction = Construction.new(Buildings.new(other_directory))
	var other_space: SpatialFixture = SpatialFixture.new()
	other_space.world = other_world
	assert_equal(other_world, _world, "foreign World identity deliberately aliases both numeric fields")
	assert_true(_sites.construction_owner() == _construction, "reader preserves actual Construction identity")
	assert_false(_sites.construction_owner() == other_construction, "numeric alias cannot replace actual owner")
	assert_true(_sites.bound_spatial_authority() == _space, "typed reader returns the actual weak target")
	assert_false(_sites.bound_spatial_authority() == other_space, "typed target never aliases a foreign object")
	assert_true(_sites.is_bound_spatial(_space), "actual spatial owner is bound")
	assert_false(_sites.is_bound_spatial(other_space), "equal world descriptor is not equal authority")
	assert_false(_sites.is_bound_spatial(null), "null never proves an authority")
	_space = null
	assert_true(_sites.bound_spatial_authority() == null, "expired weak target reads null")
	assert_false(_sites.is_bound_spatial(other_space), "expired owner never falls back to a matching descriptor")
	assert_false(_sites.is_bound_spatial(null), "expired weak reference and null are not a binding")
	assert_false(_sites.is_publishing_spatial_transition(ORIGIN, Contract.OP_BRACE,
		Contract.STAGE_START, ROOM, null), "expired spatial owner cannot attest a callback")


func test_spatial_publication_attests_only_the_exact_committed_callback() -> void:
	"""A real paid transition opens one callback window; direct calls and preparation do not."""
	_space.publication_probe = weakref(_sites)
	_space.publish_transition(ORIGIN, Contract.OP_BRACE, Contract.STAGE_START, ROOM)
	assert_equal(_space.accepted_publications, PackedByteArray([0]), "a direct public callback has no proof")
	_space.accepted_publications.clear()
	_complete(Contract.OP_BRACE)
	var job: int = _start(Contract.OP_CUT)
	assert_true(_sites.set_paused(_site, true).ok, "actual worker and phase are held before cancellation")
	assert_true(_sites.cancel_phase(_site, NULL_REF).ok, "material-free cut cancels through its actual owner")
	assert_equal(_space.accepted_publications, PackedByteArray([1, 1, 1, 1]),
		"brace start/commit and cut start/cancel each open their exact window")
	assert_equal(_space.false_publications.count(1), 0, "wrong datum, operation, stage, Room generation or authority refuses")
	assert_equal(_space.premature_publications.count(1), 0, "operation preparation is never publication permission")
	assert_false(_sites.is_publishing_spatial_transition(ORIGIN, Contract.OP_CUT,
		Contract.STAGE_CANCEL, ROOM, _space), "the completed callback's permission has ended")
	assert_equal(_jobs.ref_of(job), NULL_REF, "cancellation completed the actual phase lifecycle")


func test_256_resident_existing_work_baseline_microbenchmark_without_excavation() -> void:
	"""Measure the same real Job/Gear/Work path with no excavation authority or timed assertions."""
	var baseline: Work = Work.new(_jobs)
	assert_true(baseline.bind_gear(_gear).ok, "baseline uses the same real Gear owner")
	var jobs: PackedInt32Array = PackedInt32Array()
	for index: int in 256:
		var worker: int = _resident if index == 0 else _worker()
		var job: int = _jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, 2000, 0).value
		assert_true(_jobs.set_tool_gate(job, Jobs.GATE_SATISFIED).ok, "baseline also requires tools")
		assert_true(_jobs.assign_worker(worker, job).ok, "actual baseline worker binds")
		assert_true(baseline.claim_tool_for_work(worker, _tools[worker]).ok, "actual baseline tool claims")
		assert_true(_jobs.set_state(job, Jobs.JOB_STATE_WORK).ok, "ordinary baseline Work begins")
		jobs.append(job)
	_measure_existing_work_baseline(baseline, jobs)


func _measure_existing_work_baseline(baseline: Work, jobs: PackedInt32Array) -> void:
	"""Keep assertion/reporting overhead outside both compared productive loops."""
	var tick_result: Work.TickResult = Work.TickResult.new(false, &"")
	var total_usec: int = 0
	var maximum_usec: int = 0
	var refused_ticks: int = 0
	for tick: int in 10:
		var began: int = Time.get_ticks_usec()
		for job: int in jobs:
			if not baseline.tick_solo_into(job, tick_result):
				refused_ticks += 1
		var elapsed: int = Time.get_ticks_usec() - began
		total_usec += elapsed
		maximum_usec = maxi(maximum_usec, elapsed)
	assert_equal(refused_ticks, 0, "all actual baseline contributions succeed")
	for job: int in jobs:
		assert_equal(_jobs.remaining_mwu_of(job).value, 1200, "same actual 800mWU per baseline resident")
	@warning_ignore("integer_division") var mean_usec: int = total_usec / 10
	print("UG06_BASELINE_WORK_256 mean_usec=%d max_usec=%d" % [mean_usec, maximum_usec])


func _packed_payload_bytes(owner: Object) -> int:
	"""Cold independent reflection measures every actual packed array, including transaction scratch."""
	var bytes: int = 0
	for property: Dictionary in owner.get_property_list():
		var value: Variant = owner.get(property["name"])
		if value is PackedByteArray:
			bytes += value.size()
		elif value is PackedInt32Array:
			bytes += value.size() * 4
		elif value is PackedInt64Array:
			bytes += value.size() * 8
	return bytes


func _assert_measured_packed_storage() -> void:
	"""Pin actual backing storage separately from diagnostic image scalar headers and object overhead."""
	var site_bytes: int = _packed_payload_bytes(_sites)
	var funding_bytes: int = _packed_payload_bytes(_sites.get("_funding"))
	assert_equal(site_bytes, 36880 + 113 * 256, "all sparse Sites columns and fixed scratch measured")
	assert_equal(funding_bytes, 2330624 + 88 * 512, "all actual Funding live and scratch arrays measured")
	print("UG06_PACKED S=256 R=512 sites_bytes=%d funding_bytes=%d total_bytes=%d" %
		[site_bytes, funding_bytes, site_bytes + funding_bytes])


func _assert_refused_foreign_composition(inventory: Inventory, pool: Reservations, items: Items) -> void:
	"""Refusal precedes all Construction/Work bindings and all paid-state allocation."""
	var construction: Construction = Construction.new(Buildings.new(_residents.directory()))
	var work: Work = Work.new(_jobs)
	assert_true(work.bind_gear(_gear).ok, "real original Gear binds")
	var refused: Sites = Sites.new(construction, inventory, pool, items, _jobs, work, _space, 8, 8)
	assert_equal(refused.initialization_refusal(), Contract.REFUSE_AUTHORITY, "foreign composition refuses")
	assert_equal(refused.state_bytes().size(), 160, "foreign owner rejection precedes packed allocation")
	assert_true(construction.excavation_authority() == null, "Construction remains unbound")
	assert_equal(work.excavation_binding_refusal(Contract.new()), &"", "Work remains unbound")


func test_sites_reject_foreign_inventory_catalog_and_claim_pool_with_matching_numeric_refs() -> void:
	"""No typed numeric alias may pair this worker/equipment world with foreign material ownership."""
	var other: Inventory = Inventory.new(16, 512)
	var definitions: Items = Items.new()
	assert_true(definitions.load_default(other).ok, "foreign catalog has identical authored IDs")
	var store: Vector2i = other.create_container(_world, 100000, -1, 0, true).ref
	var lot: Vector2i = other.create_lot(store, definitions.compiled_id(&"wood"), 1000, 1, 0, -1, 0, 0).ref
	assert_equal(lot, _tools[0], "foreign material lot aliases local equipped tool numerically")
	var pool: Reservations = Reservations.new()
	var claims: PackedInt64Array = PackedInt64Array([lot.x, lot.y, Reservations.PURPOSE_EXCAVATION_INPUT, 250, 100])
	assert_true(pool.claim_batch(Vector2i(1, 1), claims, 1, other).ok, "foreign pool binds its actual Inventory")
	_assert_refused_foreign_composition(other, _pool, _items)
	_assert_refused_foreign_composition(_inventory, pool, _items)
	_assert_refused_foreign_composition(_inventory, _pool, definitions)
	var columns: Reservations.ReservationColumns = Reservations.ReservationColumns.new()
	assert_true(pool.copy_reservation_columns_into(columns), "legacy foreign claims capture")
	var unbound: Reservations = Reservations.new()
	assert_true(unbound.restore_reservation_columns(columns), "pure-column import remains supported")
	_assert_refused_foreign_composition(_inventory, unbound, _items)


func test_spatial_adapter_reads_exact_current_site_room_project_operation_and_job() -> void:
	"""Adapter reads cannot allocate geometry or reuse stale phase generations after retirement."""
	assert_equal(_sites.site_at(ORIGIN), _site, "exact claimed quantum resolves")
	assert_equal(_sites.site_at(ORIGIN + Vector3i(1, 0, 0)), NULL_REF, "fractional origin never rounds")
	assert_equal(_sites.site_at(ORIGIN + Vector3i(1024, 0, 0)), NULL_REF, "unclaimed exact quantum remains absent")
	assert_equal(_sites.room_of(_site), ROOM, "actual current room identity reads")
	assert_equal(_sites.project_of(_site), NULL_REF, "no invented project before opening")
	assert_false(_sites.operation_into(_site, _math), "inactive operation explicitly refuses")
	var job: int = _start(Contract.OP_BRACE)
	var project: Vector2i = _construction.project_of_excavation_site(_site)
	assert_equal(_sites.project_of(_site), project, "full Construction identity reads")
	assert_equal(_sites.job_of(_site), _jobs.ref_of(job), "actual bound Job identity reads")
	assert_true(_sites.operation_into(_site, _math), "active operation reads")
	assert_equal(_math.value, Contract.OP_BRACE, "reads the actual adopted operation")
	assert_equal(_sites.room_of(Vector2i(_site.x, 2)), NULL_REF, "stale site generation has no room")
	assert_equal(_sites.job_of(Vector2i(_site.x, 2)), NULL_REF, "stale site generation has no Job")
	assert_equal(_finish_work(job), 25, "real work completes before phase retirement")
	assert_true(_sites.settle_phase(_site).ok, "actual phase commits")
	assert_equal(_sites.project_of(_site), NULL_REF, "retired Construction cannot be reused")
	assert_equal(_sites.job_of(_site), NULL_REF, "retired Job cannot be reused")
	assert_equal(_sites.site_at(ORIGIN), _site, "paid quantum history survives phase retirement")


func _assert_late_wiring_stops_paid_work(job: int) -> void:
	"""All relevant public paths reject before worker, material, carry or equipment mutation."""
	var work_before: PackedByteArray = _work.state_bytes()
	var jobs_before: PackedByteArray = _jobs.state_bytes()
	var material_before: PackedByteArray = _inventory.state_bytes()
	var gear_before: PackedByteArray = _work.gear().state_bytes()
	assert_equal(_sites.bind_worker(_site).error, Contract.REFUSE_AUTHORITY, "worker bind rechecks actual world wiring")
	assert_equal(_sites.begin_phase_work(_site, 0).error, Contract.REFUSE_AUTHORITY, "phase start rechecks actual world wiring")
	assert_equal(_sites.resume_phase_work(_site).error, Contract.REFUSE_AUTHORITY, "resume rechecks actual world wiring")
	assert_equal(_work.tick_solo(job).error, Contract.REFUSE_AUTHORITY, "productive tick rechecks actual world wiring")
	assert_equal(_work.state_bytes(), work_before, "no WU, XP or wear carry mutation")
	assert_equal(_jobs.state_bytes(), jobs_before, "no accepted Job work")
	assert_equal(_inventory.state_bytes(), material_before, "no material consumption or publication")
	assert_equal(_work.gear().state_bytes(), gear_before, "no foreign equipment wear")


func test_late_catalog_rebinding_stops_actual_paid_worker_without_state_changes() -> void:
	"""A successful catalog registration into another world cannot silently change an active phase."""
	var job: int = _start(Contract.OP_BRACE)
	var other: Inventory = Inventory.new(16, 512)
	assert_true(_items.load_default(other).ok, "existing public catalog API explicitly changes its target")
	_assert_late_wiring_stops_paid_work(job)


func test_late_work_gear_rebinding_stops_funded_phase_without_state_changes() -> void:
	"""Releasing claims permits generic Work rewiring, but never licenses a foreign excavation world."""
	var job: int = _start(Contract.OP_BRACE)
	assert_true(_sites.set_paused(_site, true).ok, "actual pause releases Work/Gear claim")
	assert_true(_sites.set_paused(_site, false).ok, "player pause clears before foreign rebind")
	var other: Inventory = Inventory.new(16, 512)
	var definitions: Items = Items.new()
	assert_true(definitions.load_default(other).ok, "foreign authored catalog registers")
	var foreign_gear: Gear = Gear.new(256)
	assert_true(foreign_gear.bind_equipment(other, _residents.directory(), _residents).ok,
		"foreign Gear uses same numeric resident namespace but different actual Inventory")
	assert_true(_work.bind_gear(foreign_gear).ok, "generic Work allows replacement after claims release")
	_assert_late_wiring_stops_paid_work(job)
