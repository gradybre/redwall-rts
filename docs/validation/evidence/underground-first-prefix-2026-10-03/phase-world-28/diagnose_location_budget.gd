extends "res://test/test_underground_first_prefix.gd"
## Actual first-prefix owner graph, finite stock and real Contacts. Source motion certificates remain synthetic.

const EntryWorld := preload("res://scripts/core/underground_entry_world_bindings.gd")
const EntryStructure := preload("res://scripts/core/underground_entry_structure.gd")
const StructureScope := preload("res://scripts/core/underground_world_structure_scope.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Work := preload("res://scripts/core/work.gd")
const Transforms := preload("res://scripts/core/transforms.gd")

class UnsupportedBodyWorld extends ActualWorld:
	func _profile_image(identity: PackedInt32Array) -> PackedByteArray:
		"""Load an explicit synthetic BODY with two negative units while its actual STANCE covers only one."""
		var bytes: PackedByteArray = super._profile_image(identity)
		var start: int = 64 + 6 * Profiles.PROFILE_WIRE_BYTES
		for rotation: int in 4:
			bytes.encode_s32(start + (3 + 7 * rotation + Profiles.BODY_HELD_LOAD) * 28 + 4, -2)
		return bytes

class ObservedContacts extends Contacts:
	var move_on_final: bool = false
	var pause_on_final: bool = false
	var observe_probe: Callable = Callable()
	var prepared_probe: Callable = Callable()

	func phase_observe_refusal(placement: Vector2i, site: Vector2i, episode: int, operation: int,
			stage: int, cold_token: int = 0, space_token: int = 0) -> StringName:
		"""Observe with real stores first; then expose one adversarial successful outer callback boundary."""
		var code: StringName = super.phase_observe_refusal(placement, site, episode, operation, stage, cold_token, space_token)
		if code == &"" and observe_probe.is_valid():
			var callback: Callable = observe_probe
			observe_probe = Callable()
			callback.call()
		return code

	func phase_final_observation_refusal(placement: Vector2i, site: Vector2i, operation: int, stage: int) -> StringName:
		"""A successful real observation may be followed by actual pose or lifecycle mutation before its caller's final leaf."""
		var code: StringName = super.phase_final_observation_refusal(placement, site, operation, stage)
		if code == &"" and move_on_final:
			move_on_final = false
			var worker: Vector2i = _placements._jobs.worker_of(_job_row(_primary_job))
			_placements._transforms.place(worker, _location.point.x + 1, _location.point.y, _location.point.z, _world_yaw())
		if code == &"" and pause_on_final:
			pause_on_final = false
			_placements._construction.set_paused(_project, true)
		if code == &"" and _phase_companion_token > 0 and prepared_probe.is_valid():
			var callback: Callable = prepared_probe
			prepared_probe = Callable()
			callback.call()
		return code

var _unsupported_body: bool = false
var _bind_during_cold: bool = false
var _entry_structure: EntryStructure = null
var _entry_structure_scope: StructureScope = null
var _accepted_work_mwu: int = 0


func before_each() -> void:
	"""The test-only sum observes actual accepted Work results; it is never a production progress or payment source."""
	_accepted_work_mwu = 0
	super.before_each()


func _make_world() -> ActualWorld:
	"""The rejection case changes only source-authored synthetic geometry before any real owner is bound."""
	return CountedWorld.new()


func _make_phase_provider() -> WorldBindings:
	"""Use the actual subclass before Authority/Sites initialization; no live owner is replaced afterward."""
	return EntryWorld.new()


func _make_contacts() -> Contacts:
	"""All ordinary source, geometry and worker decisions remain the actual Contacts implementation."""
	return ObservedContacts.new()


func _bind_frontier() -> void:
	"""Six extra explicitly authored L0 transit contacts cover only the unchanged synthetic362u ground profile."""
	_source = Frontier.new()
	var capacities: PackedInt32Array = PackedInt32Array([2, 8, 2, 10, 17, 6])
	assert_equal(_source.configure(capacities, Frontier.required_bytes(capacities)), &"", "finite fixture frontier bank")
	assert_equal(_source.bind_actual(_world._catalog, _groups._reader, _groups._recipes, _world._profiles), &"", "actual source chain")
	var bytes: PackedByteArray = _frontier_image(capacities)
	assert_equal(_source.load_file(SOURCE_PATH, CatalogTests._write(SOURCE_PATH, bytes), SOURCE_REVISION), &"", "actual frontier decoder")


func _frontier_endpoints(bytes: PackedByteArray) -> void:
	"""Only actual whole paid L0 can publish these exact source selectors; they imply no path or production profile."""
	super._frontier_endpoints(bytes)
	for depth: int in [-181, -512, -843, -1174, -1505, -1536]:
		_append_endpoint(bytes, Frontier.INSTALLED_CONTACT, 0, 1, Locations.ROLE_TRANSIT, Vector3i(0, 0, depth))


func _natural_surface() -> void:
	"""The formerly missing192u strip is independently proved untouched earth; its half-open support never enters a paid key."""
	super._natural_surface()
	var envelope: PackedInt32Array = Source.world_box(PackedInt32Array([-1792, 0, 0, 1792, 1157, 192]))
	var support: PackedInt32Array = Source.world_box(PackedInt32Array([-1792, -128, 0, 1792, 0, 192]))
	var added: Anchor.Result = _anchor.create_in_section(ORIGIN + Vector3i(0, 0, 96), envelope, support,
		_section, Locations.ROLE_TRANSIT)
	assert_equal(added.error, &"", "actual never-cut near-side earth strip")
	assert_equal(added.section, _section, "same actual World metadata section")


func _bind_entry_and_installation() -> void:
	"""The actual modular installer and excavation composer borrow exactly one once-configured contact packet."""
	super._bind_entry_and_installation()
	assert_equal(_world._locations.bind_sites(_sites), &"", "same actual paid Site namespace for phase companions")
	if _bind_during_cold:
		var token: int = _world._budget.acquire(16)
		assert_true(token > 0, "another actual synchronous operation owns the arena")
		assert_equal((_provider as EntryWorld).bind_phase_contacts(_contacts, EntryWorld.ENTRY_CONTROL_BYTES),
			EntryWorld.ENTRY_REFUSE_BINDING, "first binding cannot cross another original lease")
		assert_equal((_provider as EntryWorld)._entry_box.size(), 0, "refused configuration allocates no packet")
		assert_true(_world._budget.covers(token, 16), "original owner remains charged")
		assert_equal(_world._budget.release(token), &"", "original operation releases its own lease")
	assert_equal((_provider as EntryWorld).bind_phase_contacts(_contacts, EntryWorld.ENTRY_CONTROL_BYTES), &"",
		"same actual phase/install contact packet")
	_entry_structure_scope = StructureScope.new()
	assert_equal(_entry_structure_scope.configure(_provider, _world._levels, _world._budget), &"", "original actual phase Scope")
	_entry_structure = EntryStructure.new()
	assert_equal(_entry_structure.configure(_entry_structure_scope, _world._owner, _world._terrain,
		_world._levels, _sites, _world._budget), &"", "actual entry structural provider")
	assert_equal(_entry_structure.bind_entry_sources(_placements, _source, EntryStructure.ENTRY_CONTROL_BYTES), &"",
		"exact immutable entry bearings")
	assert_equal(_provider.bind_phase_structure(_entry_structure, _world._levels), &"", "actual original World structure dispatch")


func after_each() -> void:
	"""The original phase Scope lives throughout the synchronous actual fixture and is released before its owner graph."""
	_entry_structure = null
	_entry_structure_scope = null
	super.after_each()


func test_initial_binding_requires_actual_quiescence_before_packet_allocation() -> void:
	"""A failed late initialization keeps both original lease and unbound provider available for exact retry."""
	after_each()
	_bind_during_cold = true
	before_each()
	_bind_during_cold = false
	assert_equal((_provider as EntryWorld)._entry_actual(), _contacts, "quiescent retry binds the same actual packet")
	assert_true(_world._budget.is_quiescent(), "no initialization lease is retained")


func test_actual_phase_binding_is_once_only_and_source_revision_is_not_geometry_permission() -> void:
	"""No second packet, equal-looking composer or immutable source replacement may retain qualification."""
	var provider: EntryWorld = _provider as EntryWorld
	assert_equal(provider._entry_actual(), _contacts, "same actual Contacts object")
	assert_equal(provider.qualification_revision(), SOURCE_REVISION, "exact immutable source revision")
	assert_equal(provider.bind_phase_contacts(_contacts, EntryWorld.ENTRY_CONTROL_BYTES), EntryWorld.ENTRY_REFUSE_BINDING,
		"cannot bind twice")
	var replacement: EntryWorld = EntryWorld.new()
	assert_equal(replacement.configure(_world._world, _world._terrain, _world._owner, _world._sources,
		_world._budget), &"", "same-store alternate composer metadata")
	assert_equal(replacement.bind_phase_contacts(_contacts, EntryWorld.ENTRY_CONTROL_BYTES), EntryWorld.ENTRY_REFUSE_BINDING,
		"actual Authority still belongs to the original composer")
	assert_equal(replacement._entry_box.size(), 0, "refused bind allocates no phase packet")
	_replace_actual_profiles()
	assert_equal(provider.qualification_revision(), 0, "actual Profile source drift invalidates cached qualification")


func _replace_actual_profiles() -> void:
	"""The real loader consumes a newly versioned wire image while retaining identical source geometry and profile IDs."""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(WorldTests.PROFILE_TEMP)
	bytes.encode_s64(12, 3)
	assert_equal(_world._profiles.load_file(WorldTests.PROFILE_TEMP, _world._write(WorldTests.PROFILE_TEMP, bytes), 3), &"",
		"actual monotonic Profiles replacement")


func test_unknown_or_foreign_site_refuses_before_plan_allocation() -> void:
	"""Neither a coincident local slot nor an arbitrary cold token creates a phase source association."""
	var provider: EntryWorld = _provider as EntryWorld
	var out: Space.Plan = Space.Plan.new()
	var before: PackedByteArray = _sites.state_bytes()
	assert_equal(provider.phase_plan_into(Vector2i(0, 2), Contract.OP_BRACE, Contract.STAGE_ADMIT,
		NULL_REF, 16, out), EntryWorld.ENTRY_REFUSE_SCOPE, "foreign Site generation")
	assert_equal(out.volumes.role.size(), 0, "no copied source rows")
	assert_equal(out.contacts.profile_id.size(), 0, "no caller contact allocation")
	assert_true(_sites.state_bytes() == before, "no new claim, history or paid identity")
	assert_true(_world._budget.is_quiescent(), "no unrequested shared lease")


func _confirm_prefix() -> Vector2i:
	"""Use the genuine fine first-prefix claim and actual atomic Room/Placement/Sites admission path."""
	var admitted: Buildings.OpResult = _orders.confirm_entry(_entry_plan())
	assert_true(admitted.ok, "actual first-prefix admission: %s" % admitted.error)
	return admitted.ref


func test_first_real_phase_plan_preserves_all_source_motion_and_exact_face_contact() -> void:
	"""Body residual and tool stroke remain in the actual survey; support never becomes an obstruction exception."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var provider: EntryWorld = _provider as EntryWorld
	var token: int = provider.begin_cold_operation(_world._owner, site, Contract.OP_BRACE, Contract.STAGE_ADMIT)
	assert_true(token > 0, "actual original World cold lease")
	var plan: Space.Plan = Space.Plan.new()
	var code: StringName = provider.phase_plan_into(site, Contract.OP_BRACE, Contract.STAGE_ADMIT,
		room, provider.phase_plan_row_limit(_world._owner, token), plan)
	assert_equal(code, &"", "actual complete phase plan")
	if code == &"":
		assert_equal(plan.volumes.role.size(), 5, "all body, stance, recovery, approach and stroke boxes")
		assert_equal(plan.contacts.profile_id.size(), 3, "actual body/approach/recovery air rows")
		assert_true(plan.volumes.lo_y[0] < plan.contacts.approach.lo_y[0], "negative body residual is retained separately")
		assert_equal(plan.owner_ref, room, "full actual Room")
		assert_equal(plan.contacts.work_xyz[1], ORIGIN.y, "exact target top face")
	plan = null
	provider.end_cold_operation(token)
	assert_true(_world._budget.is_quiescent(), "all caller plans dropped before release")


func test_actual_phase_admission_uses_full_motion_and_creates_only_one_real_project() -> void:
	"""Exact fine claims use real phase admission and qualification; no whole-cube enlargement authorizes the paid tail."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var opened: Construction.OpResult = _sites.open_phase(site, Contract.OP_BRACE)
	assert_true(opened.ok, "actual phase ADMIT: %s" % opened.error)
	assert_equal(_world._construction.live_project_count(), 1, "one actual purpose5 Project")
	assert_true(_world._budget.is_quiescent(), "ADMIT drops all phase plan/survey scratch")
	assert_equal(_world._inventory.lot_quantity_milli(_wood), 6500, "admission consumes no wood")
	assert_equal(_sites.virgin_sourced_milli(), 0, "admission creates no spoil")


func test_copied_phase_plan_cannot_drop_negative_body_or_add_unobserved_rows() -> void:
	"""The provider rederives exact immutable source rows after observations, preserving all caller arrays on refusal."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var provider: EntryWorld = _provider as EntryWorld
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var token: int = provider.begin_cold_operation(_world._owner, site, Contract.OP_BRACE, Contract.STAGE_ADMIT)
	var plan: Space.Plan = Space.Plan.new()
	assert_equal(provider.phase_plan_into(site, Contract.OP_BRACE, Contract.STAGE_ADMIT, room,
		provider.phase_plan_row_limit(_world._owner, token), plan), &"", "complete source plan")
	if not failures.is_empty():
		provider.end_cold_operation(token); return
	assert_equal(provider._entry_plan_matches(_contacts, plan), &"", "exact source-derived packet")
	var low: int = plan.volumes.lo_y[0]
	plan.volumes.lo_y[0] += 1
	assert_equal(provider._entry_plan_matches(_contacts, plan), EntryWorld.ENTRY_REFUSE_PLAN, "negative body cannot be clipped")
	assert_equal(plan.volumes.lo_y[0], low + 1, "refusal preserves caller packet")
	plan.volumes.lo_y[0] = low
	plan.contacts.profile_revision[0] += 1
	assert_equal(provider._entry_plan_matches(_contacts, plan), EntryWorld.ENTRY_REFUSE_PLAN, "profile revision cannot drift")
	plan = null
	provider.end_cold_operation(token)


func test_phase_plan_refuses_malformed_empty_output_before_copy() -> void:
	"""A zero role count does not hide an extra packed column or caller contact tail."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var provider: EntryWorld = _provider as EntryWorld
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var token: int = provider.begin_cold_operation(_world._owner, site, Contract.OP_BRACE, Contract.STAGE_ADMIT)
	var plan: Space.Plan = Space.Plan.new()
	plan.volumes.lo_x.append(47)
	assert_equal(provider.phase_plan_into(site, Contract.OP_BRACE, Contract.STAGE_ADMIT, room, 64, plan),
		EntryWorld.ENTRY_REFUSE_PLAN, "mismatched caller column refuses")
	assert_equal(plan.volumes.lo_x, PackedInt32Array([47]), "caller shape is unchanged")
	assert_equal(plan.volumes.role.size(), 0, "no source row was copied")
	plan = null
	provider.end_cold_operation(token)


func test_actual_source_body_inside_support_cannot_be_clipped_into_permission() -> void:
	"""Full BODY geometry outside its exact STANCE fails even though all positive-height approach air exists."""
	after_each()
	_unsupported_body = true
	before_each()
	_unsupported_body = false
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var state: PackedByteArray = _sites.state_bytes()
	var geometry: PackedByteArray = _world._owner.state_bytes()
	var opened: Construction.OpResult = _sites.open_phase(site, Contract.OP_BRACE)
	assert_equal(opened.error, Contacts.REFUSE_GEOMETRY, "actual source BODY intersects real support outside STANCE")
	assert_equal(_world._construction.live_project_count(), 0, "no Project follows clipped permission")
	assert_true(_sites.state_bytes() == state and _world._owner.state_bytes() == geometry, "all authoritative rows remain")
	assert_true(_world._budget.is_quiescent(), "refused complete source frees its original cold lease")


func test_new_provider_uses_one_fixed_packet_and_existing_contacts() -> void:
	"""Runtime reflection counts only the subclass's source-owned numeric payload, not inherited owner reserves."""
	var provider: EntryWorld = _provider as EntryWorld
	var bytes: int = 0
	for field: Dictionary in provider.get_property_list():
		var name: String = field["name"]
		if not name.begins_with("_entry_"): continue
		var value: Variant = provider.get(name)
		match typeof(value):
			TYPE_BOOL: bytes += 1
			TYPE_INT: bytes += 8
			TYPE_VECTOR2I: bytes += 8
			TYPE_VECTOR3I: bytes += 12
			TYPE_PACKED_INT32_ARRAY: bytes += value.size() * 4
	assert_equal(bytes, 202, "fixed three boxes, exact phase and contact refs and scalar controls")
	assert_equal(provider._entry_actual(), _paid._contacts.get_ref(), "one actual shared Contacts packet")
	assert_true(bytes + 1024 <= EntryWorld.ENTRY_CONTROL_BYTES, "fixed plus explicit helper reservation")


func _open_real_phase_job(site: Vector2i, operation: int, ordinal: int) -> int:
	"""A real purpose5 Project, BUILD Job and equipped resident use explicit initial test arrival, not an automatic route."""
	var opened: Construction.OpResult = _sites.open_phase(site, operation)
	assert_true(opened.ok, "actual finite phase admission: %s" % opened.error)
	if not opened.ok: return -1
	var amount: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_world._construction.remaining_mwu_into(opened.ref, amount), "actual quoted remaining work")
	var job: int = _world._jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, amount.value, 0).value
	assert_true(_world._jobs.set_requester(job, opened.ref).ok, "actual Project generation")
	assert_true(_world._jobs.set_tool_gate(job, Jobs.GATE_SATISFIED).ok, "actual equipped tool is required")
	assert_true(_sites.bind_job(site, _world._jobs.ref_of(job)).ok, "single exact phase Job")
	assert_true(_sites.bind_material_container(site, _storage).ok, "source-selected actual storage")
	if operation == Contract.OP_CUT: assert_true(_sites.bind_output(site, _output).ok, "finite actual spoil destination")
	var worker: int = _world._residents.directory().get_typed_row(_world._worker)
	assert_true(_world._jobs.assign_worker(worker, job).ok, "actual single worker assignment")
	assert_true(_world._work.claim_tool_for_work(worker, _tool).ok, "real equipped Gear claim")
	_select_phase_actor(job, ordinal)
	return job


func _select_phase_actor(job: int, ordinal: int) -> void:
	"""Only initial fixture arrival is placed directly; later phases requalify the same actor at its existing station."""
	var worker: int = _world._residents.directory().get_typed_row(_world._worker)
	var profile: int = 2 if ordinal % 2 == 0 else 4
	if _world._routes._resident_ref(worker) != NULL_REF:
		_move_existing_actor(job, _endpoints[3 + ordinal], 49152 if ordinal % 2 == 0 else 16384)
		if not failures.is_empty(): return
		assert_equal(_world._routes.refresh_work_actor(_world._worker, _world._jobs.ref_of(job),
			profile, 1, 2, 0, -1, _tool), &"", "same actual idle actor changes only its exact current WORK Job")
		return
	var point: Vector3i = ORIGIN + Source.side_root(ordinal)
	assert_true(_world._transforms.place(_world._worker, point.x, point.y, point.z,
		49152 if ordinal % 2 == 0 else 16384), "explicit test arrival at authored station")
	assert_equal(_world._routes.admit_work_actor(_world._worker, _world._jobs.ref_of(job), _endpoints[3 + ordinal],
		profile, 1, 2, 0, -1, _tool), &"", "actual qualified idle WORK actor")


func _reserve_real_phase_inputs(site: Vector2i, operation: int, job: int) -> void:
	"""Reserve existing finite stock; neither delivery nor the fixture creates replacement inputs."""
	for line: int in Contract.input_count(operation):
		var lot: Vector2i = _wood if Contract.input_key(operation, line) == &"wood" else _stone
		var batch: PackedInt64Array = PackedInt64Array([lot.x, lot.y, Reservations.PURPOSE_EXCAVATION_INPUT,
			Contract.input_milli(operation, line), 100000])
		assert_true(_world._pool.claim_batch(_world._jobs.ref_of(job), batch, 1, _world._inventory).ok,
			"real exact input claim")
	if Contract.input_count(operation) > 0:
		var delivered: Construction.OpResult = _sites.record_deliveries(site)
		assert_true(delivered.ok, "delivered totals derive only from real claims: %s" % delivered.error)


func _economic_image() -> Array[PackedByteArray]:
	"""Independent owner images expose payment, reservation, labor, skill or durability changes on refusal."""
	return [_world._inventory.state_bytes(), _world._pool.state_bytes(), _router._funding.state_bytes(),
		_world._construction.state_bytes(), _world._jobs.state_bytes(), _world._work.state_bytes(),
		_world._gear.state_bytes(), _world._residents.state_bytes()]


func _assert_economic_image(before: Array[PackedByteArray]) -> void:
	"""No single unchanged total can hide mutation in another actual economic owner."""
	var after: Array[PackedByteArray] = _economic_image()
	for index: int in before.size():
		assert_true(after[index] == before[index], "economic owner %d unchanged" % index)


func test_phase_material_contact_cannot_substitute_another_real_storage() -> void:
	"""A reachable real output storage has valid geometry but is not the immutable material selector."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var job: int = _open_real_phase_job(site, Contract.OP_BRACE, 0)
	if job < 0 or not failures.is_empty(): return
	var before: Array[PackedByteArray] = _economic_image()
	var state: PackedByteArray = _sites.state_bytes()
	assert_false(_sites.bind_material_container(site, _output).ok, "foreign actual STORAGE refuses before rebinding")
	_assert_economic_image(before)
	assert_true(_sites.state_bytes() == state, "original full Site and selected contact remain")
	assert_true(_sites.bind_material_container(site, _storage).ok, "exact selected storage remains usable")


func test_missing_stone_prevents_payment_work_skill_and_tool_wear() -> void:
	"""A real partial wood delivery never fabricates the adopted stone line or a READY phase."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var job: int = _open_real_phase_job(site, Contract.OP_BRACE, 0)
	if job < 0 or not failures.is_empty(): return
	var claim: PackedInt64Array = PackedInt64Array([_wood.x, _wood.y, Reservations.PURPOSE_EXCAVATION_INPUT, 250, 100000])
	assert_true(_world._pool.claim_batch(_world._jobs.ref_of(job), claim, 1, _world._inventory).ok, "only real wood reserved")
	assert_true(_sites.record_deliveries(site).ok, "partial actual delivery is recorded")
	var before: Array[PackedByteArray] = _economic_image()
	var geometry: PackedByteArray = _world._owner.state_bytes()
	assert_equal(_sites.begin_phase_work(site, 0).error, Construction.REFUSE_WRONG_PHASE, "incomplete bill never starts")
	assert_false(_world._work.tick_solo(job).ok, "actual dispatcher cannot earn unfunded phase work")
	_assert_economic_image(before)
	assert_true(_world._owner.state_bytes() == geometry and _world._budget.is_quiescent(), "no candidate or escaped cold lease")
	assert_equal(_world._inventory.lot_quantity_milli(_wood), 6500, "delivered reservation is not input consumption")


func _walk_existing_ground(job: int, destination: Vector2i) -> Routes.Actor:
	"""Move through the actual committed ground graph; bounded ticks never fabricate arrival or a work-facing turn."""
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_world._routes.refresh_actor(_world._worker, _world._jobs.ref_of(job), Profiles.MODE_WALK,
		Profiles.POSTURE_UPRIGHT, -1, _tool), &"", "actual source-qualified idle WALK selection")
	assert_equal(_world._routes.request_route(_world._worker, destination, 0), &"", "explicit actual route request")
	if not failures.is_empty(): return actor
	for tick: int in 600:
		_world._routes.advance_tick(tick)
		assert_equal(_world._routes.read_actor_into(_world._worker, actor), &"", "actual moving actor")
		if actor.phase == Routes.PHASE_IDLE: break
		if actor.phase == Routes.PHASE_HELD:
			assert_true(false, "actual route held before destination")
			break
	return actor


func _move_existing_actor(job: int, destination: Vector2i, yaw: int) -> void:
	"""Real existing routes carry position; the explicitly synthetic stationary-turn fixture changes yaw only."""
	var row: int = _world._residents.directory().get_typed_row(_world._worker)
	if _world._routes._resident_pair(Routes.R_LOCATION_SLOT, row) != destination:
		var actor: Routes.Actor = _walk_existing_ground(job, destination)
		assert_equal(actor.location, destination, "actual full endpoint reached before orientation fixture")
		if not failures.is_empty(): return
	var pose: Transforms.Pose = Transforms.Pose.new()
	assert_true(_world._transforms.read_into(_world._worker, pose), "actual current stationary pose")
	if pose.yaw != yaw:
		assert_true(_world._transforms.place(_world._worker, pose.x, pose.y, pose.z, yaw),
			"SYNTHETIC stationary-turn boundary: unchanged XYZ, no production turn or source qualification")


func test_actual_existing_ground_route_moves_between_outside_stations_without_work_credit() -> void:
	"""The next excavation station is reachable only through real retained earth spans, never a test teleport or new edge."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var job: int = _open_real_phase_job(site, Contract.OP_BRACE, 0)
	if job < 0 or not failures.is_empty(): return
	var before: Array[PackedByteArray] = _economic_image()
	var actor: Routes.Actor = _walk_existing_ground(job, _endpoints[7])
	assert_equal(actor.phase, Routes.PHASE_IDLE, "bounded actual traversal finishes")
	assert_equal(actor.location, _endpoints[7], "exact existing destination generation")
	assert_equal(actor.point, ORIGIN + Source.side_root(4), "actual integer arrival at the outside retained strip")
	assert_equal(actor.mode, Profiles.MODE_WALK, "arrival has not invented a work-facing contact")
	assert_equal(_world._routes._live.edge_count, 16, "no implicit route was created")
	_assert_economic_image(before)
	assert_false(_world._construction.has_work_begun(_sites.project_of(site)), "travel earns no funded work")


func test_actual_ready_worker_uses_prospective_contact_and_departure_refuses_without_credit() -> void:
	"""Actual READY registration proves contact before the Site row exists; payment still needs its registered START worker."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var job: int = _open_real_phase_job(site, Contract.OP_BRACE, 0)
	if job < 0 or not failures.is_empty(): return
	_reserve_real_phase_inputs(site, Contract.OP_BRACE, job)
	var bound: Construction.OpResult = _sites.bind_worker(site)
	assert_true(bound.ok, "actual READY worker binds before payment: %s" % bound.error)
	assert_false(_world._construction.has_work_begun(_sites.project_of(site)), "registration creates no WIP")
	var point: Vector3i = ORIGIN + Source.side_root(0)
	assert_true(_world._transforms.place(_world._worker, point.x + 1, point.y, point.z, 49152), "actual pose changed")
	assert_false(_sites.bind_worker(site).ok, "departed actual worker cannot retain contact permission")
	assert_equal(_world._inventory.lot_quantity_milli(_wood), 6500, "no input consumed by contact checks")
	assert_equal(_world._construction._remaining_mwu[_world._construction._row_of(_sites.project_of(site))],
		Contract.work_mwu(Contract.OP_BRACE), "no work credit from registration or refusal")


func test_prospective_worker_late_pose_change_refuses_and_exact_retry_registers() -> void:
	"""The callback's copied successful observation cannot outlive actual worker arrival at the selected station."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var job: int = _open_real_phase_job(site, Contract.OP_BRACE, 0)
	if job < 0 or not failures.is_empty(): return
	_reserve_real_phase_inputs(site, Contract.OP_BRACE, job)
	var before: PackedByteArray = _sites.state_bytes()
	var inventory: PackedByteArray = _world._inventory.state_bytes()
	(_contacts as ObservedContacts).move_on_final = true
	assert_false(_sites.bind_worker(site).ok, "late actual displacement refuses registration")
	assert_true(_sites.state_bytes() == before and _world._inventory.state_bytes() == inventory, "no registration or payment")
	assert_false(_world._construction.has_work_begun(_sites.project_of(site)), "no WIP escaped")
	var point: Vector3i = ORIGIN + Source.side_root(0)
	assert_true(_world._transforms.place(_world._worker, point.x, point.y, point.z, 49152), "actual return")
	assert_true(_sites.bind_worker(site).ok, "same exact actual worker can retry")


func test_prospective_worker_late_pause_cannot_borrow_contact_only_lifecycle() -> void:
	"""Contact-only selection is restricted to the same original unpaused READY state after the last observer."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var job: int = _open_real_phase_job(site, Contract.OP_BRACE, 0)
	if job < 0 or not failures.is_empty(): return
	_reserve_real_phase_inputs(site, Contract.OP_BRACE, job)
	var before: PackedByteArray = _sites.state_bytes()
	(_contacts as ObservedContacts).pause_on_final = true
	assert_false(_sites.bind_worker(site).ok, "late actual pause refuses registration")
	assert_true(_sites.state_bytes() == before, "no worker or phase state was published")
	assert_true(_world._construction.is_paused(_sites.project_of(site)), "real observer mutation is not rolled back")
	assert_equal(_world._inventory.lot_quantity_milli(_wood), 6500, "all material remains actual finite stock")
	assert_false(_world._construction.has_work_begun(_sites.project_of(site)), "no WIP or labor")
	assert_true(_sites.set_paused(site, false).ok, "explicit resume")
	assert_true(_sites.bind_worker(site).ok, "actual resumed READY worker registers")


func _begin_actual_phase(site: Vector2i, operation: int, ordinal: int) -> int:
	"""Use the real phase authority and prepared companions; missing production bindings remain a visible failing gate."""
	var job: int = _open_real_phase_job(site, operation, ordinal)
	if job < 0 or not failures.is_empty(): return -1
	_reserve_real_phase_inputs(site, operation, job)
	var bound: Construction.OpResult = _sites.bind_worker(site)
	assert_true(bound.ok, "actual phase worker: %s" % bound.error)
	if not bound.ok: return -1
	var inventory: PackedByteArray = _world._inventory.state_bytes()
	var funding: PackedByteArray = _router._funding.state_bytes()
	var geometry: PackedByteArray = _world._owner.state_bytes()
	var started: Construction.OpResult = _sites.begin_phase_work(site, 0)
	if not started.ok:
		assert_true(_world._inventory.state_bytes() == inventory and _router._funding.state_bytes() == funding,
			"missing actual phase permission cannot consume finite stock or publish WIP")
		assert_true(_world._owner.state_bytes() == geometry, "no partial physical publication")
	assert_true(started.ok, "actual prepared phase START: %s" % started.error)
	return job if started.ok else -1


func _earn_actual_phase(job: int) -> void:
	"""Drive bounded real Work ticks; integer work, skill and tool wear stay owned by the existing dispatcher."""
	var remaining: IntMath.IntResult = IntMath.IntResult.new()
	var ticks: int = 0
	while _world._jobs.remaining_mwu_into(job, remaining) and remaining.value > 0 and ticks < 1000:
		var worked: Work.TickResult = _world._work.tick_solo(job)
		assert_true(worked.ok, "actual productive phase tick: %s" % worked.error)
		if not worked.ok: return
		_accepted_work_mwu += worked.accepted_mwu
		ticks += 1
	assert_true(_world._jobs.remaining_mwu_into(job, remaining) and remaining.value == 0, "actual finite work completes")
	assert_true(ticks > 0, "no fabricated work credit")


func test_first_real_brace_requires_actual_start_work_settlement_and_conservation() -> void:
	"""Actual non-flat support and sealed companions publish only after finite paid work completes."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var job: int = _begin_actual_phase(site, Contract.OP_BRACE, 0)
	if job < 0: return
	assert_equal(_world._inventory.lot_quantity_milli(_wood), 6250, "one adopted brace wood input")
	assert_equal(_world._inventory.lot_quantity_milli(_stone), 1250, "one adopted brace stone input")
	assert_false(_sites.installed_support(site), "paid WIP is not yet installed support")
	_earn_actual_phase(job)
	if not failures.is_empty(): return
	var settled: Construction.OpResult = _sites.settle_phase(site)
	assert_true(settled.ok, "actual paid brace settles once: %s" % settled.error)
	if not settled.ok: return
	assert_true(_sites.installed_support(site), "only completed paid work installs the brace")
	assert_equal(_sites.support_conservation_refusal(), &"", "actual input/WIP/support account balances")
	assert_equal(_sites.earth_conservation_refusal(), &"", "brace creates no earth")
	assert_equal(_sites.virgin_sourced_milli(), 0, "no CUT output yet")
	assert_false(_sites.settle_phase(site).ok, "paid phase cannot settle twice")
	assert_true(_world._budget.is_quiescent(), "all original phase scratch is released")


func _complete_actual_phase(site: Vector2i, operation: int, ordinal: int) -> bool:
	"""One real phase finishes through its exact START, productive and worker-free settlement boundaries."""
	var job: int = _begin_actual_phase(site, operation, ordinal)
	if job < 0: return false
	_earn_actual_phase(job)
	if not failures.is_empty(): return false
	var settled: Construction.OpResult = _sites.settle_phase(site)
	assert_true(settled.ok, "actual operation %d settlement: %s" % [operation, settled.error])
	assert_true(_world._budget.is_quiescent(), "completed or refused phase releases only its own arena")
	return settled.ok


func test_first_cube_real_brace_cut_finish_preserves_spoil_and_finite_inputs() -> void:
	"""All three paid phases share one actual actor and full Site; CUT emits spoil once and FINISH creates exact room air."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	for operation: int in [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]:
		if not _complete_actual_phase(site, operation, 0): return
	assert_equal(_world._inventory.lot_quantity_milli(_wood), 6250, "one adopted brace wood bill")
	assert_equal(_world._inventory.lot_quantity_milli(_stone), 1250, "one adopted brace stone bill")
	assert_equal(_sites.virgin_sourced_milli(), 2000, "one real whole-cube CUT output")
	assert_equal(_sites.support_conservation_refusal(), &"", "actual support ledger balances")
	assert_equal(_sites.earth_conservation_refusal(), &"", "actual spoil ledger balances")
	assert_equal(_world._construction.live_project_count(), 0, "all three completed Projects retired")
	assert_equal(_world._routes._live.edge_count, 16, "phase publication adds no route")


func _ready_actual_phase(site: Vector2i, operation: int, ordinal: int) -> int:
	"""Prepare a real funded-input candidate without consuming any material or creating WIP."""
	var job: int = _open_real_phase_job(site, operation, ordinal)
	if job < 0 or not failures.is_empty(): return -1
	_reserve_real_phase_inputs(site, operation, job)
	var bound: Construction.OpResult = _sites.bind_worker(site)
	assert_true(bound.ok, "actual ready worker: %s" % bound.error)
	return job if bound.ok else -1


func _probe_prepared_mismatches(site: Vector2i, observed: PackedInt64Array) -> void:
	"""Independent wrong tuples must preserve the actual original packet while an unchanged retry still proves it."""
	var placement: Vector2i = _contacts._placement
	var cold: int = _contacts._phase_cold_token
	var space: int = _contacts._phase_space_token
	var companion: int = _contacts._phase_companion_token
	observed[0] = companion
	assert_true(_placements.phase_context(companion) != null, "actual typed sealed context exists")
	for field: int in 6:
		var code: StringName = _contacts.bind_prepared_phase(placement, site if field != 0 else Vector2i(site.x, site.y + 1),
			Contract.OP_BRACE if field != 1 else Contract.OP_CUT, Contract.STAGE_START if field != 2 else Contract.STAGE_COMMIT,
			cold if field != 3 else cold + 1, space if field != 4 else space + 1, companion if field != 5 else companion + 1)
		assert_true(code != &"", "wrong retained tuple field %d refuses" % field)
	assert_equal(_contacts._phase_companion_token, companion, "failed attempts cannot replace original companion")
	assert_equal(_contacts._phase_space_token, space, "failed attempts cannot replace original Space token")
	assert_equal(_contacts.bind_prepared_phase(placement, site, Contract.OP_BRACE, Contract.STAGE_START,
		cold, space, companion), &"", "unchanged original scope remains valid")


func test_prepared_phase_rejects_wrong_full_tuple_and_old_token_without_reobservation() -> void:
	"""A sealed numeric token is not permission; exact original refs and both original owner leases remain necessary."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	if _ready_actual_phase(site, Contract.OP_BRACE, 0) < 0: return
	var observed: PackedInt64Array = PackedInt64Array([0])
	(_contacts as ObservedContacts).prepared_probe = func() -> void: _probe_prepared_mismatches(site, observed)
	var started: Construction.OpResult = _sites.begin_phase_work(site, 0)
	assert_true(started.ok, "actual unchanged START after refused foreign tuples: %s" % started.error)
	assert_true(observed[0] > 0, "probe ran only after actual companion preparation")
	assert_equal(_contacts._phase_companion_token, 0, "original cold cleanup drops prepared scope")
	assert_true(_contacts.bind_prepared_phase(_contacts._placement, site, Contract.OP_BRACE,
		Contract.STAGE_START, 1, 1, observed[0]) != &"", "retired token cannot revive old observation")
	assert_true(_world._budget.is_quiescent(), "no companion observation owns another arena")


func test_prepared_start_late_pose_change_preserves_payment_and_retry() -> void:
	"""Current worker facts are rechecked after the last successful prepared observation inside Inventory's barrier."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	if _ready_actual_phase(site, Contract.OP_BRACE, 0) < 0: return
	var before: Array[PackedByteArray] = _economic_image()
	var geometry: PackedByteArray = _world._owner.state_bytes()
	var point: Vector3i = ORIGIN + Source.side_root(0)
	(_contacts as ObservedContacts).prepared_probe = func() -> void:
		assert_true(_world._transforms.place(_world._worker, point.x + 1, point.y, point.z, 49152), "actual late displacement")
	assert_false(_sites.begin_phase_work(site, 0).ok, "departed prepared worker cannot spend input")
	_assert_economic_image(before)
	assert_true(_world._owner.state_bytes() == geometry, "no geometry follows rejected payment")
	assert_false(_world._construction.has_work_begun(_sites.project_of(site)), "no WIP escaped")
	assert_true(_world._budget.is_quiescent(), "exact rejected context was discarded")
	assert_true(_world._transforms.place(_world._worker, point.x, point.y, point.z, 49152), "actual return to existing contact")
	assert_true(_sites.begin_phase_work(site, 0).ok, "same actual Project retries without replacement input")


func test_prepared_start_replaced_cold_lease_preserves_foreign_owner_and_payment() -> void:
	"""Cleanup uses the retained original token even after the last observer replaces the real shared arena owner."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	if _ready_actual_phase(site, Contract.OP_BRACE, 0) < 0: return
	var before: Array[PackedByteArray] = _economic_image()
	var geometry: PackedByteArray = _world._owner.state_bytes()
	var replacement: PackedInt64Array = PackedInt64Array([0])
	(_contacts as ObservedContacts).prepared_probe = func() -> void:
		assert_equal(_world._budget.release(_contacts._phase_cold_token), &"", "actual original lease released by observer")
		replacement[0] = _world._budget.acquire(Budget.COLD_BYTES)
	assert_false(_sites.begin_phase_work(site, 0).ok, "equal-capacity foreign scope cannot fund original START")
	_assert_economic_image(before)
	assert_true(_world._owner.state_bytes() == geometry, "no swap escaped foreign token")
	assert_true(_world._budget.covers(replacement[0], Budget.COLD_BYTES), "cleanup preserved the replacement scope")
	assert_equal(_world._budget.release(replacement[0]), &"", "only replacement caller releases its scope")
	assert_true(_sites.begin_phase_work(site, 0).ok, "original paid Project retries under a fresh exact phase")


func test_real_paid_cancel_releases_worker_and_preserves_refund_geometry() -> void:
	"""Terminal refund does not require the released worker to remain an assigned productive actor."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var job: int = _begin_actual_phase(site, Contract.OP_BRACE, 0)
	if job < 0: return
	assert_true(_world._work.tick_solo(job).ok, "actual partial paid brace work")
	assert_true(_sites.set_paused(site, true).ok, "paused cancellation remains legal")
	var cancelled: Construction.OpResult = _sites.cancel_phase(site, _storage)
	assert_true(cancelled.ok, "actual paid worker-free cancellation: %s" % cancelled.error)
	if not cancelled.ok: return
	assert_false(_sites.installed_support(site), "partial WIP cannot publish paid support")
	assert_equal(_sites.support_conservation_refusal(), &"", "real returned inputs and declared losses balance")
	assert_equal(_sites.virgin_sourced_milli(), 0, "cancelled brace produces no earth")
	assert_true(_world._budget.is_quiescent(), "refund drops exact prepared context")


func test_cut_output_and_late_terminal_context_refusals_keep_completed_work_for_worker_free_retry() -> void:
	"""Actual output failures cannot mint spoil; released terminal workers are not a new productive permission gate."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	if not _complete_actual_phase(site, Contract.OP_BRACE, 0): return
	var job: int = _begin_actual_phase(site, Contract.OP_CUT, 0)
	if job < 0: return
	_earn_actual_phase(job)
	if not failures.is_empty(): return
	assert_true(_world._inventory.set_container_reachable(_output, false).ok, "actual spoil destination becomes unavailable")
	assert_false(_sites.settle_phase(site).ok, "unavailable actual output refuses")
	assert_equal(_sites.virgin_sourced_milli(), 0, "no output escaped failed reachability")
	assert_true(_world._inventory.set_container_reachable(_output, true).ok, "actual output restored")
	_assert_terminal_context_retry(site, job)


func _assert_terminal_context_retry(site: Vector2i, job: int) -> void:
	"""A last-observer context mutation refuses payment while retaining finished WIP and its original real Project."""
	var inventory: PackedByteArray = _world._inventory.state_bytes()
	var funding: PackedByteArray = _router._funding.state_bytes()
	var geometry: PackedByteArray = _world._owner.state_bytes()
	(_contacts as ObservedContacts).prepared_probe = func() -> void:
		_placements._phase_context.project.y += 1
	assert_false(_sites.settle_phase(site).ok, "wrong final full Project refuses terminal publication")
	assert_true(_world._inventory.state_bytes() == inventory and _router._funding.state_bytes() == funding,
		"no partial output or lost WIP receipt")
	assert_true(_world._owner.state_bytes() == geometry, "no partially published cut")
	assert_equal(_world._jobs.worker_of(job), NULL_REF, "real worker was released before terminal observer")
	var work: PackedByteArray = _world._work.state_bytes()
	var resident: PackedByteArray = _world._residents.state_bytes()
	var gear: PackedByteArray = _world._gear.state_bytes()
	var retried: Construction.OpResult = _sites.settle_phase(site)
	assert_true(retried.ok, "same completed WIP retries without a new worker: %s" % retried.error)
	assert_equal(_sites.virgin_sourced_milli(), 2000, "one actual CUT output on successful retry")
	assert_true(_world._work.state_bytes() == work and _world._residents.state_bytes() == resident \
		and _world._gear.state_bytes() == gear, "retry earns no work, skill or wear")


func _complete_l0_cubes() -> bool:
	"""Four exact keys finish through real phases and existing surface paths; no terrain or Site state is seeded."""
	for ordinal: int in 4:
		var cube: PackedInt32Array = Source.cube(ordinal)
		var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(cube[0], cube[1], cube[2]))
		for operation: int in [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]:
			if not _complete_actual_phase(site, operation, ordinal): return false
	return true


func _open_installation(ordinal: int) -> Vector2i:
	"""Only the real paid adapter may attach the next complete seven-part assembly to this permanent Corridor."""
	var placement: Vector2i = Vector2i(0, _placements._get32(_placements._live, Placements.GENERATION, 0))
	var opened: Construction.OpResult = _router.open_order(_paid, placement, ordinal)
	assert_true(opened.ok, "actual group %d installation admission: %s" % [ordinal, opened.error])
	return opened.ref if opened.ok else NULL_REF


func _installation_job(project: Vector2i, endpoint: Vector2i) -> int:
	"""The same existing worker/tool reaches the real fastening station before selecting the immutable installation profile."""
	var quote: Modular.Quote = Modular.Quote.new()
	assert_equal(_router.project_facts_into(project, quote), &"", "actual grouped wood/work bill")
	var created: Jobs.OpResult = _world._jobs.create_job(quote.job_kind, 0, 0, quote.remaining_mwu, 0)
	assert_true(created.ok, "actual installation BUILD Job")
	if not created.ok: return -1
	assert_true(_world._jobs.set_requester(created.value, project).ok, "exact purpose8 requester")
	assert_true(_world._jobs.set_tool_gate(created.value, Jobs.GATE_SATISFIED).ok, "actual durable basic tool")
	assert_true(_router.bind_job(project, created.ref).ok, "actual sole primary Job")
	var worker: int = _world._residents.directory().get_typed_row(_world._worker)
	assert_true(_world._jobs.assign_worker(worker, created.value).ok, "same real worker")
	assert_true(_world._work.claim_tool_for_work(worker, _tool).ok, "same equipped tool claimed for installation")
	_move_existing_actor(created.value, endpoint, 0)
	if not failures.is_empty(): return -1
	assert_equal(_world._routes.refresh_work_actor(_world._worker, created.ref, 1, 1, 2, 0, -1, _tool),
		&"", "actual installation WORK profile/body/contact selection")
	return created.value


func _pay_installation(project: Vector2i, job: int) -> bool:
	"""One immutable wood-only bill consumes the original finite lot, with no bearer surcharge or excavation recipe reuse."""
	var quote: Modular.Quote = Modular.Quote.new()
	assert_equal(_router.project_facts_into(project, quote), &"", "source-pinned one-assembly quote")
	assert_equal(quote.input_count, 1, "wood only")
	assert_equal(quote.input_keys[0], &"wood", "actual approved material")
	assert_true(_router.bind_material_container(project, _storage).ok, "exact existing material endpoint")
	var batch: PackedInt64Array = PackedInt64Array([_wood.x, _wood.y, Reservations.PURPOSE_MODULAR_INPUT,
		quote.input_milli[0], 100000])
	assert_true(_world._pool.claim_batch(_world._jobs.ref_of(job), batch, 1, _world._inventory).ok,
		"existing finite wood claimed once for complete assembly")
	assert_true(_router.record_deliveries(project).ok, "actual input claims supply delivery")
	var started: Construction.OpResult = _router.start_work(project, 0)
	assert_true(started.ok, "actual paid installation START: %s" % started.error)
	return started.ok


func _complete_l0_installation() -> bool:
	"""Complete the genuine first priced group after all four dependency cubes have finished."""
	var project: Vector2i = _open_installation(0)
	if project == NULL_REF: return false
	var job: int = _installation_job(project, _endpoints[0])
	if job < 0 or not _pay_installation(project, job): return false
	_earn_actual_phase(job)
	if not failures.is_empty(): return false
	var completed: Construction.OpResult = _router.complete_order(project)
	if not completed.ok:
		print("L0-INSTALL point=", _bindings._entry_contact.point - ORIGIN,
			" role=", _bindings._entry_contact.role, " envelope=", _bindings._entry_contact.envelope,
			" support=", _bindings._entry_contact.support, " remaining=", _bindings._entry_checks)
	assert_true(completed.ok, "actual L0 paid parts/contact publication: %s" % completed.error)
	return completed.ok


func test_four_real_l0_cubes_then_paid_l0_installation_conserve_all_adopted_goods() -> void:
	"""Geometry/economy/companions are actual; only source certificates and same-position stationary turns are synthetic."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF or not _complete_l0_cubes(): return
	assert_equal(_sites.virgin_sourced_milli(), 8000, "four independently paid CUT outputs")
	assert_equal(_world._inventory.lot_quantity_milli(_wood), 5500, "four brace wood bills only")
	assert_equal(_world._inventory.lot_quantity_milli(_stone), 500, "four brace stone bills only")
	if not _complete_l0_installation(): return
	assert_equal(_placements._get32(_placements._live, Placements.INSTALLED, 0), 1, "one complete L0 prefix")
	assert_equal(_world._inventory.lot_quantity_milli(_wood), 1500, "4000 wood charged once for seven included parts")
	assert_equal(_sites.earth_conservation_refusal(), &"", "actual earth account")
	assert_equal(_sites.support_conservation_refusal(), &"", "actual paid brace account")
	assert_equal(_accepted_work_mwu, 68000, "four9000 phase bills plus32000 landing through real Work")
	_assert_timber_prisms(7)
	assert_equal(_world._routes._live.edge_count, 16, "no ground connection to installed L0 or stair edge invented")


func _installed_l0_contact() -> Vector2i:
	"""Resolve the exact WORK contact, independently of the separately authored transit selectors at that same paid deck."""
	var found: Vector2i = NULL_REF
	var record: Locations.Record = Locations.Record.new()
	record.envelope.resize(6); record.support.resize(6)
	for row: int in _world._locations._capacity:
		if _world._locations._live.present[row] != 1 \
			or _world._locations._ref_at(_world._locations._live, Locations.ROOM_SLOT, row) == NULL_REF: continue
		var ref: Vector2i = Vector2i(row, _world._locations._live.i32[row])
		assert_equal(_world._locations.read_location_into(ref, record), &"", "actual installed contact proof")
		if record.role != Locations.ROLE_WORK or record.point != ORIGIN + Vector3i(0, 0, -1536): continue
		assert_equal(found, NULL_REF, "one actual L0 contact")
		found = ref
	assert_true(found != NULL_REF, "real installed L0 contact published")
	return found


func _assert_l0_contact_current(location: Vector2i, expected_prefix: int = 1) -> void:
	"""Every later paid phase must refresh the existing full installed witness instead of bypassing it or recreating it."""
	var record: Locations.Record = Locations.Record.new()
	record.envelope.resize(6); record.support.resize(6)
	assert_equal(_world._locations.read_location_into(location, record), &"", "current complete installed prism/lower-Site witness")
	assert_equal(record.point, ORIGIN + Vector3i(0, 0, -1536), "unchanged exact fastening station")
	assert_equal(record.geometry_revision, _world._owner.revision(), "companion revision matches actual current Space")
	assert_equal(_placements._get32(_placements._live, Placements.INSTALLED, 0), expected_prefix, "only whole assembly completion advances prefix")


func _complete_first_prefix_cuts() -> Vector2i:
	"""All six paid keys and real L0 installation precede any T0 assembly; retained installed witnesses stay current."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF or not _complete_l0_cubes() or not _complete_l0_installation(): return NULL_REF
	var location: Vector2i = _installed_l0_contact()
	if location == NULL_REF: return NULL_REF
	for ordinal: int in range(4, 6):
		var cube: PackedInt32Array = Source.cube(ordinal)
		var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(cube[0], cube[1], cube[2]))
		for operation: int in [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]:
			if not _complete_actual_phase(site, operation, ordinal): return NULL_REF
			_assert_l0_contact_current(location)
	return location


func test_t0_real_phase_sequence_preserves_installed_l0_and_leaves_unclaimed_tail_unfinished() -> void:
	"""Real prepared phase banks retain paid L0 through later cuts; a published contact still grants no new graph edge."""
	var location: Vector2i = _complete_first_prefix_cuts()
	if location == NULL_REF: return
	assert_equal(_sites.virgin_sourced_milli(), 12000, "six real whole-cube yields exactly once")
	assert_equal(_world._inventory.lot_quantity_milli(_wood), 1000, "only approved T0 assembly wood remains")
	assert_equal(_world._inventory.lot_quantity_milli(_stone), 0, "six exact brace stone bills")
	assert_equal(_sites.earth_conservation_refusal(), &"", "six-cube earth account")
	assert_equal(_sites.support_conservation_refusal(), &"", "six paid braces retained")
	assert_true(_world._inventory.audit().ok and _world._pool.audit(_world._inventory).ok, "actual inventories and reservations audit")
	_assert_unfinished_tail(_placements._pair(_placements._live, Placements.ROOM_SLOT, 0))
	var remaining: PackedInt32Array = PackedInt32Array([0])
	assert_true(WorldRoutes.profile_reachability_refusal(_world._binding, _endpoints[1], location,
		0, 1, 2, _world._owner._domain._checks, remaining) != &"", "new contact cannot invent surface-to-L0 ground connection")


func _l0_ground_connection(location: Vector2i) -> bool:
	"""Two explicitly authored fixture ground edges qualify actual body/support; no stair or free geometry is published."""
	var cold: int = _world._budget.acquire(Budget.COLD_BYTES)
	var begun: Routes.Result = _world._binding.begin_prepare(cold)
	assert_equal(begun.error, &"", "actual existing geometry route preparation")
	for reverse: bool in [false, true]:
		var edge: Routes.Edge = _l0_ground_edge(location, reverse)
		var added: Routes.Result = _world._routes.stage_add(begun.token, edge)
		if added.error != &"": _report_l0_ground_refusal(edge)
		assert_equal(added.error, &"", "explicit supported L0 ground path: %s" % added.error)
		if added.error != &"": break
	if failures.is_empty():
		assert_equal(_world._binding.seal(begun.token), &"", "real complete support/body profile masks")
		if failures.is_empty(): assert_equal(_world._binding.publish(begun.token), &"", "actual edge/mask publication")
	_world._binding.abort(begun.token)
	assert_equal(_world._budget.release(cold), &"", "no retained path survey")
	return failures.is_empty()


func _report_l0_ground_refusal(edge: Routes.Edge) -> void:
	"""Diagnostic evidence reports actual source roles and exact retained coverage, without changing admission."""
	var actual: WorldRoutes = _world._binding
	print("L0-PATH profile0=", actual._profile_edge_refusal(0, edge))
	for segment: int in edge.point_count - 1:
		var first: Vector3i = WorldRoutes._point(edge, segment)
		var last: Vector3i = WorldRoutes._point(edge, segment + 1)
		print("L0-PATH segment=", segment, " first=", first - ORIGIN, " last=", last - ORIGIN,
			" stance=", actual._stance_sweeps_refusal(first, last), " full=", actual._profile_segment_refusal(first, last))
		for ordinal: int in actual._descriptor.box_count:
			if actual._profile_box_into(ordinal, actual._body) != &"": continue
			actual._sweep_into(actual._body, first, last, actual._bounds)
			var local: PackedInt32Array = actual._bounds.duplicate()
			for axis: int in 6: local[axis] -= ORIGIN[axis % 3]
			print("L0-PATH role=", actual._body.role, " bounds=", local,
				" support=", actual._proof.covered(actual._bounds, Space.SUPPORT),
				" air=", actual._proof.covered(actual._bounds, Space.SUPPORTED_VOID),
				" blocked=", actual._proof.blocked(actual._bounds, true))


func _l0_ground_edge(location: Vector2i, reverse: bool) -> Routes.Edge:
	"""Source-local same-height path stays within the exact common World section; each swept volume must still qualify."""
	var edge: Routes.Edge = Routes.Edge.new()
	var points: Array[Vector3i] = [Vector3i(-832, 0, 512), Vector3i(0, 0, 512), Vector3i(0, 0, -1536)]
	if reverse: points.reverse()
	edge.from_location = location if reverse else _endpoints[0]
	edge.to_location = _endpoints[0] if reverse else location
	edge.section = _section; edge.level = 0; edge.family = -1; edge.variant = 0
	edge.mode = Profiles.MODE_WALK; edge.posture = Profiles.POSTURE_UPRIGHT
	edge.content_revision = 2; edge.geometry_revision = _world._owner.revision()
	for local: Vector3i in points:
		var point: Vector3i = ORIGIN + local
		edge.points.append_array(PackedInt32Array([point.x, point.y, point.z]))
	edge.point_count = 3; edge.length_u = 2880
	return edge


func test_complete_paid_l0_t0_prefix_requires_explicit_ground_path_and_preserves_exact_ledgers() -> void:
	"""This is real first-prefix economy/geometry evidence with synthetic source/turn fixtures, never playable qualification."""
	var l0: Vector2i = _complete_first_prefix_cuts()
	if l0 == NULL_REF: return
	var placement: Vector2i = Vector2i(0, _placements._get32(_placements._live, Placements.GENERATION, 0))
	var wood: int = _world._inventory.lot_quantity_milli(_wood)
	assert_false(_router.open_order(_paid, placement, 1).ok, "T0 cannot borrow an unconnected new L0 contact")
	assert_equal(_world._inventory.lot_quantity_milli(_wood), wood, "missing path creates no bill or payment")
	if not _l0_ground_connection(l0): return
	var project: Vector2i = _open_installation(1)
	if project == NULL_REF: return
	var job: int = _installation_job(project, l0)
	if job < 0 or not _pay_installation(project, job): return
	_earn_actual_phase(job)
	if not failures.is_empty(): return
	var completed: Construction.OpResult = _router.complete_order(project)
	assert_true(completed.ok, "actual T0 whole group/contact publication: %s" % completed.error)
	if not completed.ok: return
	_assert_l0_contact_current(l0, 2)
	_assert_complete_prefix_ledger()


func _assert_complete_prefix_ledger() -> void:
	"""Independent quantities and conserved physical roles account for all six phases and both one-time assembly bills."""
	assert_equal(_placements._get32(_placements._live, Placements.INSTALLED, 0), 2, "two whole paid groups exactly once")
	assert_equal(_world._inventory.lot_quantity_milli(_wood), 0, "all6500 adopted wood spent, no bearer surcharge")
	assert_equal(_world._inventory.lot_quantity_milli(_stone), 0, "all1500 adopted brace stone spent")
	assert_equal(_sites.virgin_sourced_milli(), 12000, "six2000 spoil outputs, never an assembly output")
	assert_equal(_accepted_work_mwu, 98000, "six9000 phase bills plus32000 landing and12000 tread are earned through real Work")
	assert_equal(_sites.earth_conservation_refusal(), &"", "complete spoil conservation")
	assert_equal(_sites.support_conservation_refusal(), &"", "complete brace conservation")
	assert_true(_world._inventory.audit().ok and _world._pool.audit(_world._inventory).ok, "real conservation audits")
	assert_equal(_world._construction.live_project_count(), 0, "no duplicate active work/progress owner")
	assert_equal(_world._routes._live.edge_count, 18, "only two authored ground links; no T0 stair edge")
	_assert_timber_prisms(14)
	_assert_fractional_t0_contact()
	_assert_unfinished_tail(_placements._pair(_placements._live, Placements.ROOM_SLOT, 0))


func _assert_fractional_t0_contact() -> void:
	"""The128u lower installed datum must retain its real full prism, lower paid Site and source witness."""
	var found: Vector2i = NULL_REF
	var record: Locations.Record = Locations.Record.new()
	record.envelope.resize(6); record.support.resize(6)
	for row: int in _world._locations._capacity:
		if _world._locations._live.present[row] != 1 \
			or _world._locations._ref_at(_world._locations._live, Locations.ROOM_SLOT, row) == NULL_REF: continue
		var ref: Vector2i = Vector2i(row, _world._locations._live.i32[row])
		assert_equal(_world._locations.read_location_into(ref, record), &"", "actual final installed endpoint qualification")
		if record.role != Locations.ROLE_WORK or record.point != ORIGIN + Vector3i(0, -128, -2304): continue
		assert_equal(found, NULL_REF, "one exact fractional T0 WORK contact")
		found = ref
		assert_equal(record.geometry_revision, _world._owner.revision(), "fractional contact matches actual current Space")
		assert_equal(record.support[4], ORIGIN.y - 128, "actual deck top, no above-deck Site or fake plane")
	assert_true(found != NULL_REF, "whole paid T0 publishes its actual installed contact")


func _assert_timber_prisms(count: int) -> void:
	"""Every paid included part exists once at its exact full positive bounds; no outline or bearer-only completion suffices."""
	var room: Vector2i = _placements._pair(_placements._live, Placements.ROOM_SLOT, 0)
	for part: int in count:
		var bounds: PackedInt32Array = Source.world_box(PackedInt32Array(_spec["parts"][part]["bounds_u"]))
		var found: int = 0
		for row: int in _world._owner._region_capacity:
			if _world._owner._r_present[row] != 1 or _world._owner._r_claim_kind[row] != Owner.CLAIM_NONE \
				or Vector2i(_world._owner._r_owner_slot[row], _world._owner._r_owner_generation[row]) != room: continue
			var actual: PackedInt32Array = PackedInt32Array([_world._owner._r_lo_x[row], _world._owner._r_lo_y[row],
				_world._owner._r_lo_z[row], _world._owner._r_hi_x[row], _world._owner._r_hi_y[row], _world._owner._r_hi_z[row]])
			if actual != bounds: continue
			assert_equal(_world._owner._r_role[row], Space.SUPPORT, "actual paid deck/bearer/post role")
			found += 1
		assert_equal(found, 1, "full included part %d exists exactly once" % part)


func _assert_unfinished_tail(room: Vector2i) -> void:
	"""Exact retained physical roles cover the paid half-cube remainder without turning it into usable Room air."""
	var tail: PackedInt32Array = Source.world_box(PackedInt32Array([-1024, -1024, -3072, 1024, 0, -2560]))
	var volume: int = 0
	for row: int in _world._owner._region_capacity:
		if _world._owner._r_present[row] != 1 or _world._owner._r_claim_kind[row] != Owner.CLAIM_NONE \
			or Vector2i(_world._owner._r_owner_slot[row], _world._owner._r_owner_generation[row]) != room: continue
		var box: PackedInt32Array = PackedInt32Array([_world._owner._r_lo_x[row], _world._owner._r_lo_y[row],
			_world._owner._r_lo_z[row], _world._owner._r_hi_x[row], _world._owner._r_hi_y[row], _world._owner._r_hi_z[row]])
		if not Space.overlaps(box, tail): continue
		assert_equal(_world._owner._r_role[row], Space.UNFINISHED, "paid excess cannot become outside usable void or timber")
		volume += (mini(box[3], tail[3]) - maxi(box[0], tail[0])) \
			* (mini(box[4], tail[4]) - maxi(box[1], tail[1])) * (mini(box[5], tail[5]) - maxi(box[2], tail[2]))
	assert_equal(volume, 2048 * 1024 * 512, "whole paid tail remains exactly nontraversable")


func test_observer_replaces_original_lease_before_any_plan_copy() -> void:
	"""A valid foreign lease with the same capacity never pays for the original operation's copied source rows."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var provider: EntryWorld = _provider as EntryWorld
	var token: int = provider.begin_cold_operation(_world._owner, site, Contract.OP_BRACE, Contract.STAGE_ADMIT)
	var limit: int = provider.phase_plan_row_limit(_world._owner, token)
	var replacement: PackedInt64Array = PackedInt64Array([0])
	(_contacts as ObservedContacts).observe_probe = func() -> void:
		assert_equal(_world._budget.release(token), &"", "observer releases its actual scope")
		replacement[0] = _world._budget.acquire(Budget.COLD_BYTES)
	var out: Space.Plan = Space.Plan.new()
	assert_equal(provider.phase_plan_into(site, Contract.OP_BRACE, Contract.STAGE_ADMIT, room, limit, out),
		WorldBindings.REFUSE_BUDGET, "same-size replacement cannot authorize original copy")
	assert_true(out.volumes.role.is_empty() and out.contacts.profile_id.is_empty(), "no private/caller plan rows escaped")
	out = null
	provider.end_cold_operation(token)
	assert_true(_world._budget.covers(replacement[0], Budget.COLD_BYTES), "cleanup preserves the foreign original owner")
	assert_equal(_world._budget.release(replacement[0]), &"", "replacement remains releasable by its caller")


func test_nested_phase_query_poison_refuses_before_plan_allocation() -> void:
	"""A nested same-input observer cannot replace the original Site/source/lease scratch or escape caller rows."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var provider: EntryWorld = _provider as EntryWorld
	var token: int = provider.begin_cold_operation(_world._owner, site, Contract.OP_BRACE, Contract.STAGE_ADMIT)
	var limit: int = provider.phase_plan_row_limit(_world._owner, token)
	var nested: Space.Plan = Space.Plan.new()
	(_contacts as ObservedContacts).observe_probe = func() -> void:
		assert_equal(provider.phase_plan_into(site, Contract.OP_BRACE, Contract.STAGE_ADMIT, room, limit, nested),
			EntryWorld.ENTRY_REFUSE_BUSY, "nested query is excluded before any observer")
	var out: Space.Plan = Space.Plan.new()
	assert_equal(provider.phase_plan_into(site, Contract.OP_BRACE, Contract.STAGE_ADMIT, room, limit, out),
		EntryWorld.ENTRY_REFUSE_BUSY, "outer query remembers reentry")
	assert_true(out.volumes.role.is_empty() and nested.volumes.role.is_empty(), "both caller images remain empty")
	out = null; nested = null
	provider.end_cold_operation(token)
	assert_true(_world._budget.is_quiescent(), "original operation cleans only its own scope")


func test_late_actual_profile_reload_cannot_escape_a_copied_phase_plan() -> void:
	"""A successful actual contact observation cannot preserve permission after its immutable program source reloads."""
	var room: Vector2i = _confirm_prefix()
	if room == NULL_REF: return
	var site: Vector2i = _sites.site_at(ORIGIN + Vector3i(-1024, -1024, -1024))
	var provider: EntryWorld = _provider as EntryWorld
	var token: int = provider.begin_cold_operation(_world._owner, site, Contract.OP_BRACE, Contract.STAGE_ADMIT)
	var limit: int = provider.phase_plan_row_limit(_world._owner, token)
	var inventory: PackedByteArray = _world._inventory.state_bytes()
	var geometry: PackedByteArray = _world._owner.state_bytes()
	(_contacts as ObservedContacts).observe_probe = func() -> void:
		_replace_actual_profiles()
	var out: Space.Plan = Space.Plan.new()
	assert_equal(provider.phase_plan_into(site, Contract.OP_BRACE, Contract.STAGE_ADMIT, room, limit, out),
		EntryWorld.ENTRY_REFUSE_SOURCE, "same numeric Frontier and geometry cannot preserve stale motion permission")
	assert_true(out.volumes.role.is_empty() and out.contacts.profile_id.is_empty(), "no caller source image is copied")
	assert_equal(provider.qualification_revision(), 0, "cached phase qualification becomes unavailable")
	assert_true(_world._inventory.state_bytes() == inventory and _world._owner.state_bytes() == geometry,
		"source reload creates no payment or physical publication")
	out = null
	provider.end_cold_operation(token)
	assert_true(_world._budget.is_quiescent(), "stale source cannot prevent original-scope cleanup")


class CountedLocations extends GroundTests.WatchedLocations:

	var by_caller: Dictionary = {}
	var first_failure: Dictionary = {}

	func _spend(checks: int = 1) -> bool:
		"""Record exact existing charges; never replace a refusal or reset the shared counter."""
		var before: int = _remaining
		var result: bool = super._spend(checks)
		if not _installation_active(): return result
		var stack: Array = get_stack()
		var caller: String = str(stack[1]["function"]) if stack.size() > 1 else "unknown"
		var tally: Vector2i = by_caller.get(caller, Vector2i.ZERO)
		by_caller[caller] = tally + Vector2i(1, checks)
		if not result and first_failure.is_empty():
			first_failure = {"available": before, "requested": checks, "stage_count": _stage.count,
				"live_count": _live.count, "point": _record.point, "section": _record.section,
				"stack": stack, "charges": by_caller.duplicate()}
		return result

class CountedWorld extends ActualWorld:

	func _actual_space(_obstruction: int) -> void:
		"""Initialize the same actual empty owner graph, substituting only a forwarding accounting observer."""
		_routes = Routes.new(_residents, _transforms)
		_sources = Owner.CoreSources.new(_residents.directory(), _buildings, _construction, _routes)
		var domain: Space.Domain = Space.Domain.new()
		assert_equal(domain.configure(_world_ref, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
			Vector3i(256, 48, 256), 8192, 6144, check_budget), &"", "unchanged actual finite Domain")
		_owner = Owner.new(_sources)
		assert_equal(_owner.configure(domain, Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY), &"", "same empty owner")
		_locations = CountedLocations.new()
		assert_equal(_locations.configure(_residents.directory(), _buildings, _transforms, _inventory,
			_owner, _sources, _budget, location_capacity, 228 * location_capacity + 256), &"", "same actual endpoint capacity")
		_terrain = GroundTests.CountedTerrain.new()
		assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "same actual Terrain")
		_actual_catalog(domain)



func run_probe() -> Dictionary:
	"""Run one genuine L0 attempt and retain the exhausted helper before ordinary cleanup."""
	before_each()
	test_four_real_l0_cubes_then_paid_l0_installation_conserve_all_adopted_goods()
	var locations: CountedLocations = _world._locations as CountedLocations
	var result: Dictionary = locations.first_failure.duplicate()
	result["fixture_failures"] = failures.duplicate()
	after_each()
	return result
