extends "capture_underground_profiles.gd"
## Offline sampled evidence of existing demo transitions. No row authorizes gameplay clearance.
## Inherits exact imported skin/palette measurement; it never forces the brain or held item during sampling.

const Brain := preload("res://demo/cast/resident_brain.gd")
const Clock := preload("res://demo/demo_clock.gd")
const Graph := preload("res://demo/tunnel/underground_graph.gd")
const Router := preload("res://demo/tunnel/tunnel_router.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Definitions := preload("res://scripts/core/item_definitions.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Carry := preload("res://scripts/core/haul_carry.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Piles := preload("res://scripts/core/ground_piles.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const MODES: PackedStringArray = ["walk_turn", "carry_turn", "swing_return", "tunnel_reversal", "tunnel_retreat"]
const FIXTURE_CAPACITY: int = 32 # Offline arena bound, not a world capacity or gameplay recipe.

var _clock: Clock = Clock.new()
var _identity: IdentityFixture = null
var _mode: String = ""
var _phase_steps: int = 0
var _bore: int = -1
var _bore_mid: float = 0.0
var _event_done: bool = false
var _last_yaw: float = 0.0
var _initial_root: Vector3 = Vector3.ZERO


class IdentityFixture extends RefCounted:
	## Real stores, synthetic initial lots/jobs. Identity observations do not bind a physical mesh.
	var buildings: Buildings = Buildings.new()
	var residents: Residents = null
	var inventory: Inventory = Inventory.new(FIXTURE_CAPACITY, FIXTURE_CAPACITY)
	var definitions: Definitions = Definitions.new()
	var gear: Gear = Gear.new(FIXTURE_CAPACITY)
	var pool: Reservations = Reservations.new(FIXTURE_CAPACITY, Reservations.JOB_CAPACITY, FIXTURE_CAPACITY)
	var carry: Carry = Carry.new()
	var piles: Piles = Piles.new()
	var age: StockAge = null
	var jobs: Jobs = null
	var person: Vector2i = Directory.NULL_REF
	var tool: Vector2i = Directory.NULL_REF
	var cargo: Vector2i = Directory.NULL_REF
	var store: Vector2i = Directory.NULL_REF
	var job: Vector2i = Directory.NULL_REF

	func setup(species_key: StringName) -> bool:
		"""Compose real shared owners and one adult, with only fixture initialization sourcing goods."""
		residents = Residents.new(buildings.directory(), null)
		jobs = Jobs.new(residents)
		if not definitions.load_default(inventory).ok:
			return false
		var spawned: Residents.OpResult = residents.spawn(species_key)
		if not spawned.ok:
			return false
		person = spawned.ref
		age = StockAge.new(inventory, null)
		if not piles.bind_stores(inventory, buildings, age):
			return false
		var world: Vector2i = buildings.directory().create(Directory.KIND_WORLD)
		if not piles.bind_world(world) or not carry.bind(inventory, pool, residents, piles):
			return false
		if not gear.bind_equipment(inventory, buildings.directory(), residents).ok:
			return false
		return _stock_and_equip(world)

	func _stock_and_equip(world: Vector2i) -> bool:
		"""Use the real item definitions and gear quantity; no fixture quantity becomes a recipe."""
		store = inventory.create_container(world, 1000000, Inventory.FILTERS_ACCEPT_ALL,
			Inventory.UNSET_POLICY, true).ref
		if store == Directory.NULL_REF:
			return false
		tool = inventory.create_lot(store, definitions.compiled_id(&"tool"),
			Gear.GEAR_LOT_QUANTITY_MILLI, 0, 0, 0, 0, 0).ref
		if not gear.create_gear(inventory, definitions, tool, Gear.MANUFACTURE_BASIC).ok:
			return false
		if not gear.equip(tool, person).ok:
			return false
		return inventory.audit().ok

	func load_cargo() -> bool:
		"""Exercise actual claim and haul transfer; this fixture does not pretend to execute paid Work."""
		var made: Jobs.OpResult = jobs.create_job(Catalog.JOB_KIND["HAUL"], 0, 0, 0, 0)
		if not made.ok:
			return false
		job = made.ref
		var lot: Vector2i = inventory.create_lot(store, definitions.compiled_id(&"wood"),
			Gear.GEAR_LOT_QUANTITY_MILLI, 0, 0, 0, 0, 0).ref
		var claim: PackedInt64Array = PackedInt64Array([lot.x, lot.y, Reservations.PURPOSE_HAUL_SOURCE,
			inventory.lot_quantity_milli(lot), 2147483647])
		if not pool.claim_batch(job, claim, 1, inventory).ok:
			return false
		var loaded: Inventory.OpResult = carry.load_payload(job, residents.slot_of_ref(person).value, lot)
		cargo = loaded.ref
		return loaded.ok and inventory.audit().ok and pool.audit(inventory).ok

	func observe(ref: Vector2i, gear_ref: Vector2i, cargo_ref: Vector2i) -> Dictionary:
		"""Read exact live owner identities; stale or mismatched data cannot silently become an empty profile."""
		var row: IntMath.IntResult = residents.slot_of_ref(ref)
		if not row.ok:
			return {"error": "TRANSITION_RESIDENT_STALE"}
		var species_id: int = residents.species_of(row.value).value
		var stage: int = residents.life_stage_of_ref(ref).value
		var rig: Residents.OpResult = residents.rig_binding_by_species_id(species_id, stage)
		if not rig.ok:
			return {"error": "TRANSITION_STAGE_ASSET_UNBOUND"}
		var result: Dictionary = {"error": "", "resident_ref": [ref.x, ref.y], "species_id": species_id,
			"species": String(residents.species_key(species_id)), "life_stage": String(residents.life_stage_key(stage)),
			"logical_rig": String(residents.rig_key_of(rig.value)), "gear": {}, "cargo": {},
			"physical_variant_binding": "UNBOUND", "production_qualified": false}
		var code: String = _gear_into(ref, row.value, gear_ref, result)
		if code == "":
			code = _cargo_into(ref, row.value, cargo_ref, result)
		result.error = code
		return result

	func _gear_into(ref: Vector2i, slot: int, gear_ref: Vector2i, result: Dictionary) -> String:
		"""Require Inventory, Gear and resident equipment to agree, including generation and durability."""
		if not inventory.is_lot_valid(gear_ref) or not gear.is_equipped_record(gear_ref) \
				or gear.owner_of(gear_ref) != ref or not residents.has_equipped_tool(slot):
			return "TRANSITION_GEAR_IDENTITY"
		var item: IntMath.IntResult = IntMath.IntResult.new()
		var durability: IntMath.IntResult = IntMath.IntResult.new()
		var mirror: IntMath.IntResult = IntMath.IntResult.new()
		if not gear.item_id_into(gear_ref, item) or not gear.durability_into(gear_ref, durability):
			return "TRANSITION_GEAR_IDENTITY"
		if not residents.equipped_tool_item_id_into(slot, mirror) or mirror.value != item.value:
			return "TRANSITION_GEAR_MIRROR"
		if not residents.equipped_tool_durability_into(slot, mirror) or mirror.value != durability.value:
			return "TRANSITION_GEAR_MIRROR"
		result.gear = {"lot_ref": [gear_ref.x, gear_ref.y], "item_id": item.value,
			"quantity_milli": inventory.lot_quantity_milli(gear_ref), "durability": durability.value,
			"physical_variant_binding": "UNBOUND"}
		return ""

	func _cargo_into(ref: Vector2i, slot: int, cargo_ref: Vector2i, result: Dictionary) -> String:
		"""Reject a missing expected load or changed lot; quantities remain actual Inventory values."""
		var actual: Vector2i = carry.carried_lot(slot)
		var satchel: Vector2i = carry.satchel_of(slot)
		if actual != cargo_ref:
			return "TRANSITION_CARGO_IDENTITY"
		if cargo_ref == Directory.NULL_REF:
			return "" if residents.satchel_of(slot) == Directory.NULL_REF else "TRANSITION_CARGO_IDENTITY"
		if not inventory.is_lot_valid(cargo_ref) or satchel == Directory.NULL_REF \
				or inventory.container_owner(satchel) != ref or inventory.lot_container(cargo_ref) != satchel \
				or inventory.container_next_lot(cargo_ref) != Directory.NULL_REF:
			return "TRANSITION_CARGO_IDENTITY"
		result.cargo = {"lot_ref": [cargo_ref.x, cargo_ref.y], "satchel_ref": [satchel.x, satchel.y],
			"item_id": inventory.lot_item_id(cargo_ref), "quantity_milli": inventory.lot_quantity_milli(cargo_ref),
			"physical_variant_binding": "UNBOUND"}
		return ""

	func close() -> void:
		"""Break equipment's collaborator links through the real unequip door before releasing fixture stores."""
		if gear.is_equipped(tool):
			gear.unequip(tool, store, false)


func _implementation_error(pins: Dictionary) -> String:
	"""Require this driver, its inherited evaluator, transitive readers and catalog bytes explicitly."""
	var refusal: String = super._implementation_error(pins)
	if refusal != "":
		return refusal
	var base_path: String = get_script().resource_path.get_base_dir().path_join("capture_underground_profiles.gd")
	if not pins.has(base_path):
		return "TRANSITION_INHERITED_IMPLEMENTATION_UNPINNED"
	var pending: Array[String] = [get_script().resource_path]
	var seen: Dictionary = {}
	var references: RegEx = RegEx.create_from_string("(?:preload|load)\\(\\s*\"(res://[^\"]+\\.gd)\"\\s*\\)")
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if seen.has(path):
			continue
		if seen.size() >= MAX_SOURCES or not pins.has(path):
			return "TRANSITION_IMPLEMENTATION_UNPINNED"
		seen[path] = true
		for match_result: RegExMatch in references.search_all(FileAccess.get_file_as_string(path)):
			var dependency: String = match_result.get_string(1)
			if not seen.has(dependency) and not pending.has(dependency):
				pending.append(dependency)
	for path: String in [Definitions.DEFAULT_JSON_PATH, "res://data/catalog_ids.json"]:
		if not pins.has(path):
			return "TRANSITION_CATALOG_UNPINNED"
	return ""


func _case_error(request: Variant, pins: Dictionary, ids: Dictionary) -> String:
	"""Keep each species/state requirement explicit; unsupported modes do not fall back to a plain clip."""
	var refusal: String = super._case_error(request, pins, ids)
	if refusal != "":
		return refusal
	if not MODES.has(str(request.get("transition", ""))) or request.attachments.size() > 1:
		return "TRANSITION_CASE_FORMAT"
	var clips: Dictionary = _manifest.cast[request.cast].clips
	for key: String in ["idle", "walk", request.clip]:
		if not clips.has(key):
			return "TRANSITION_REQUIRED_CLIP_MISSING"
	if request.transition == "carry_turn" and request.clip != String(Brain.CLIP_CARRY):
		return "TRANSITION_REQUIRED_CLIP_MISSING"
	if request.transition == "swing_return" and request.clip != String(Actor.CLIP_SWING):
		return "TRANSITION_REQUIRED_CLIP_MISSING"
	return ""


func _configure_case() -> void:
	"""Validate every clip that may enter a fade, then prepare the inherited exact skin cache."""
	if _skeleton == null or _player == null:
		super._configure_case()
		return
	for clip: String in ["idle", "walk", str(_cases[_case_index].clip)]:
		_error = _animation_error(StringName("cast/" + clip))
		if _error != "":
			_finish()
			return
	super._configure_case()


func _begin_case(request: Dictionary) -> void:
	"""Warm a real idle pose, then begin observed transitions without warm-up consuming source motion."""
	super._begin_case(request)
	_mode = request.transition
	_identity = IdentityFixture.new()
	if not _identity.setup(StringName(request.species)):
		_error = "TRANSITION_IDENTITY_FIXTURE"
		_finish()
		return
	if _mode == "carry_turn" and not _identity.load_cargo():
		_error = "TRANSITION_HAUL_FIXTURE"
		_finish()
		return
	_phase_steps = ceili(maxf(_player.get_animation(StringName("cast/" + request.clip)).length,
		PI / Brain.SPOT_TURN_RATE) * SAMPLE_HZ) + ceili(Actor.CROSSFADE_S * SAMPLE_HZ)
	_steps = 3 * _phase_steps + 1
	if _steps > MAX_STEPS:
		_error = "TRANSITION_TIMELINE_CAPACITY"
		_finish()
		return
	_actor.brain.call("_enter_hold")
	_actor.place(Vector2.ZERO, 0.0, -1, -1)
	_actor.brain.call("_enter_hold")
	_restart_clip(_player, &"cast/idle")
	_prepare_transition_row()
	_prepare_held_item()
	_event_done = false
	if _mode.begins_with("tunnel_"):
		_prepare_tunnel()


func _prepare_transition_row() -> void:
	"""Retain the measurement contract and per-frame facts separately from production profile permission."""
	_row["transition"] = _mode
	_row["events"] = []
	_row["motion"] = []
	_row["identity_initial"] = _identity.observe(_identity.person, _identity.tool, _identity.cargo)
	_row["phase_steps"] = _phase_steps
	_row.expected_sample_count = _steps
	_row.sample_boundary = "idle warm-up, actual demo methods at sample zero; all transitions sampled only"
	_row.root_motion = "actual demo root updates in synthetic route fixture; no core movement authority"
	_row["max_observed_yaw_step_rad"] = 0.0
	_row["max_observed_root_step_m"] = 0.0
	_row["synthetic_fixture"] = true
	_row["physical_variant_binding"] = "UNBOUND"
	_report["measurement_scope"] = "actual demo transition samples plus isolated real identity readers"
	_report.missing_bindings = ["CONTINUOUS_RUNTIME_RESIDUAL", "COMPLETE_TRANSITION_AND_RECOVERY_COVERAGE",
		"LOGICAL_RIG_TO_IMPORTED_ASSET", "GEAR_AND_CARGO_PHYSICAL_VARIANTS", "AUTHORITATIVE_STATE_COST_BINDING",
		"ACTUAL_ROOT_SUPPORT_CONTACT", "ACCEPTED_PROFILE_REVISION"]


func _prepare_held_item() -> void:
	"""Attach one existing prop once, retaining its actual visibility behavior throughout the transition."""
	for item: Dictionary in _items:
		item["visible_samples"] = 0
		item["hidden_samples"] = 0
		if item.key == "mole_pick":
			_actor.set_work_tool(item.mesh, item.fit)
		elif item.key != "log":
			_actor.hold(item.mesh, item.fit)


func _prepare_tunnel() -> void:
	"""Make an explicit synthetic completed demo route using its existing sizes and dig clock."""
	var graph: Graph = _actor.brain.space().tunnels
	var half: int = Tunnel.RAMP_RUN_U + Tunnel.MIN_LENGTH_U
	var flat: PackedInt32Array = PackedInt32Array([0, -half, 0, half])
	var ref: PackedInt32Array = PackedInt32Array([-1, 0, -1])
	if not graph.add_into(flat, 2, _actor.brain.index, ref):
		_error = "TRANSITION_ROUTE_FIXTURE"
		return
	var chain: PackedInt32Array = PackedInt32Array()
	graph.piece_segments_into(ref[2], chain)
	if chain.size() != 3:
		_error = "TRANSITION_ROUTE_FIXTURE"
		return
	for slot: int in chain:
		graph.start_dig(slot, graph.generation[slot], _actor.brain.index)
		graph.set_bore(slot, Tunnel.BORE_WIDE)
		@warning_ignore("integer_division") var usec: int = (graph.total_ticks(slot) * Tunnel.USEC_PER_SECOND + Tunnel.TICKS_PER_SECOND - 1) / Tunnel.TICKS_PER_SECOND
		graph.advance(slot, graph.generation[slot], usec)
		if graph.phase[slot] != Graph.PHASE_OPEN:
			_error = "TRANSITION_ROUTE_NOT_FINISHED"
	_bore = chain[1]
	_bore_mid = graph.length_m(_bore) * 0.25 # Fixture starts nearer the entry, so nearest-exit actually retreats.
	_steps = MAX_STEPS # Bounded exit observation window, not a movement timeout or policy.
	_row.expected_sample_count = _steps
	_row["route_fixture"] = {"points_u": Array(flat), "segments": Array(chain),
		"bore": _bore, "bore_class": Tunnel.BORE_WIDE, "production_permission": false}


func _step_pose() -> void:
	"""Advance the real demo clock/brain/draw chain; inherited callbacks read final skeleton output."""
	if _error != "":
		_finish()
		return
	if _step < 0:
		_clock.advance(1.0 / SAMPLE_HZ)
		_actor.draw(_clock)
	else:
		_transition_events()
		_clock.advance(0.0 if _step == 0 else 1.0 / SAMPLE_HZ)
		_actor.advance(_clock)
	_player.advance(0.0 if _step == 0 else 1.0 / SAMPLE_HZ)
	_pending = true
	_skeleton.advance(1.0 / SAMPLE_HZ)


func _transition_events() -> void:
	"""Issue bounded fixture orders; every observed movement still runs through its existing method."""
	if _mode.begins_with("tunnel_"):
		_tunnel_events()
		return
	if _step == 0 or _step == _phase_steps:
		if _mode == "swing_return":
			_actor.brain.task_play(Actor.CLIP_SWING if _step == 0 else Brain.CLIP_WALK)
			if _step != 0:
				_actor.clear_work_tool()
			_event("swing" if _step == 0 else "return_to_walk")
		else:
			var span: float = _actor.brain.walk_speed * float(_phase_steps * 2) / SAMPLE_HZ
			var goal: Vector2 = _actor.brain.position + Vector2(0.0, -span if _step == 0 else span)
			if _mode == "carry_turn":
				_actor.brain.order_carry(goal)
			else:
				_actor.brain.order_move(goal)
			_event("turn_and_walk" if _step == 0 else "reverse_order")
	if _step == 2 * _phase_steps:
		_actor.brain.call("_enter_hold")
		_event("hold_and_fade_idle")


func _tunnel_events() -> void:
	"""Start at real bore progress, then invoke the existing reversal or nearest-exit method without resetting it."""
	var brain: Brain = _actor.brain
	var graph: Graph = brain.space().tunnels
	if _step == 0:
		brain.path = PackedVector2Array([graph.node_m(graph.node_b[_bore])])
		brain.path_tunnel = PackedInt32Array([Router.leg_code(_bore, false)])
		brain.path_index = 0
		brain.call("_start_travel", _bore, _bore_mid, graph.length_m(_bore))
		_event("begin_at_committed_bore_progress")
	elif not _event_done and brain.is_in_bore(_bore) and brain.bore_along_m() > _bore_mid:
		var before: float = brain.bore_along_m()
		if _mode == "tunnel_reversal":
			brain.turn_back(_bore, 0.0)
		else:
			brain.call("_walk_out")
		_event("turn_back" if _mode == "tunnel_reversal" else "walk_out")
		_row.events[-1]["progress_before_m"] = before
		_row.events[-1]["progress_after_m"] = brain.bore_along_m()
		_event_done = true
	elif _event_done and not brain.underground and _row.events.size() == 2:
		brain.call("_enter_hold")
		_event("reached_surface_exit")
		_steps = mini(MAX_STEPS, _step + _phase_steps + 1)
		_row.expected_sample_count = _steps


func _event(name: String) -> void:
	"""Keep the exact order boundary and source clip visible to the outer evidence verifier."""
	_row.events.append({"name": name, "step": _step, "state": _actor.brain.state,
		"clip": String(_actor.brain.clip), "position_m": _vector(_actor.position)})


func _capture_pose() -> void:
	"""Measure skin/attachments, then retain actual state and live identities for this same sample."""
	super._capture_pose()
	var brain: Brain = _actor.brain
	var facts: Dictionary = _identity.observe(_identity.person, _identity.tool, _identity.cargo)
	if facts.error != "":
		_error = facts.error
	var root_step: float = _actor.position.distance_to(_initial_root) if _step > 0 else 0.0
	var yaw_step: float = absf(angle_difference(_last_yaw, brain.yaw)) if _step > 0 else 0.0
	_row.max_observed_root_step_m = maxf(_row.max_observed_root_step_m, root_step)
	_row.max_observed_yaw_step_rad = maxf(_row.max_observed_yaw_step_rad, yaw_step)
	var clip: Animation = _player.get_animation(_player.assigned_animation)
	_row.motion.append({"animation_name": String(_player.assigned_animation),
		"animation_length_s": clip.length, "animation_loop_mode": clip.loop_mode, "step": _step, "state": brain.state, "clip": String(brain.clip),
		"played_clip": String(_actor.played_clip()), "clip_position_s": _player.current_animation_position,
		"clip_rate": _player.speed_scale, "brain_clip_time_s": brain.clip_time(),
		"root_m": _vector(_actor.position), "yaw_rad": brain.yaw, "pitch_rad": brain.pitch,
		"underground": brain.underground, "bore_progress_m": brain.bore_along_m(),
		"carrying": brain.carrying, "identity": facts, "stoop_m": _actor.stoop_now_m()})
	_last_yaw = brain.yaw
	_initial_root = _actor.position


static func _vector(value: Vector3) -> Array:
	"""Plain numeric diagnostic coordinates only; this never packs authoritative positions."""
	return [value.x, value.y, value.z]


func _capture_items() -> void:
	"""Measure only geometry the demo actually shows; retain hidden samples instead of fabricating a grip."""
	for item: Dictionary in _items:
		var name: String = "_work_tool" if item.key == "mole_pick" else ("_load" if item.key == "log" else "_held")
		var instance: MeshInstance3D = _actor.get(name) as MeshInstance3D
		if instance == null or instance.mesh != item.mesh:
			_error = "TRANSITION_ATTACHMENT_IDENTITY"
			return
		if not instance.visible:
			item.hidden_samples += 1
			continue
		item.visible_samples += 1
		for points: PackedVector3Array in item.surfaces:
			for point: Vector3 in points:
				if not _include(item.bounds, instance.global_transform * point):
					_error = "CAPTURE_NONFINITE_ATTACHMENT"


func _end_case() -> void:
	"""Keep actual visibility and final identities; refuse a transition that never reached its required event."""
	var last: String = "reached_surface_exit" if _mode.begins_with("tunnel_") else "hold_and_fade_idle"
	if _row.events.is_empty() or _row.events[-1].name != last:
		_error = "TRANSITION_EVENT_INCOMPLETE"
	for item: Dictionary in _items:
		if item.bounds.is_empty():
			_error = "TRANSITION_ATTACHMENT_NEVER_VISIBLE"
	if _error != "":
		_finish()
		return
	_row["attachment_visibility"] = []
	for item: Dictionary in _items:
		_row.attachment_visibility.append({"key": item.key, "visible_samples": item.visible_samples,
			"hidden_samples": item.hidden_samples, "physical_variant_binding": "UNBOUND"})
	_row["identity_final"] = _identity.observe(_identity.person, _identity.tool, _identity.cargo)
	_identity.close()
	_identity = null
	super._end_case()


func _finish() -> void:
	"""Release owned fixtures even after a bounded refusal; never mutate other worktrees or live sessions."""
	if _identity != null:
		_identity.close()
		_identity = null
	super._finish()


func _self_checks() -> Dictionary:
	"""Actual small core stores exercise stale generations and physical-binding gaps; no fake catalog masses."""
	var checks: Dictionary = {}
	var fixture: IdentityFixture = IdentityFixture.new()
	checks["actual_fixture"] = fixture.setup(&"mouse")
	if not checks.actual_fixture:
		fixture.close()
		return {"synthetic_fixture": true, "checks": checks, "status": "SELF_TEST_ONLY"}
	checks["actual_gear_reader"] = fixture.observe(fixture.person, fixture.tool, fixture.cargo).error == ""
	checks["stale_resident"] = fixture.observe(Vector2i(fixture.person.x, fixture.person.y + 1), fixture.tool, fixture.cargo).error == "TRANSITION_RESIDENT_STALE"
	checks["stale_gear"] = fixture.observe(fixture.person, Vector2i(fixture.tool.x, fixture.tool.y + 1), fixture.cargo).error == "TRANSITION_GEAR_IDENTITY"
	checks["actual_haul_transfer"] = fixture.load_cargo()
	checks["actual_cargo_reader"] = fixture.observe(fixture.person, fixture.tool, fixture.cargo).error == ""
	checks["omitted_cargo"] = fixture.observe(fixture.person, fixture.tool, Directory.NULL_REF).error == "TRANSITION_CARGO_IDENTITY"
	checks["stale_cargo"] = fixture.observe(fixture.person, fixture.tool, Vector2i(fixture.cargo.x, fixture.cargo.y + 1)).error == "TRANSITION_CARGO_IDENTITY"
	checks["no_physical_permission"] = fixture.observe(fixture.person, fixture.tool, fixture.cargo).physical_variant_binding == "UNBOUND"
	checks.merge(_identity_extra_checks(fixture))
	checks["conservation"] = fixture.inventory.audit().ok and fixture.pool.audit(fixture.inventory).ok
	fixture.close()
	return {"synthetic_fixture": true, "checks": checks, "status": "SELF_TEST_ONLY"}


func _identity_extra_checks(fixture: IdentityFixture) -> Dictionary:
	"""Adversarial real owner/stage and mirror changes remain separate from source asset permissions."""
	var checks: Dictionary = {}
	var other: Residents.OpResult = fixture.residents.spawn(&"mouse")
	checks["foreign_gear_owner"] = fixture.observe(other.ref, fixture.tool, fixture.cargo).error == "TRANSITION_GEAR_IDENTITY"
	var child: Residents.OpResult = fixture.residents.spawn_with_stage(&"mouse", Residents.LIFE_STAGE_CHILD)
	checks["child_does_not_inherit_adult_asset"] = fixture.observe(child.ref, fixture.tool, Directory.NULL_REF).error == "TRANSITION_STAGE_ASSET_UNBOUND"
	var slot: int = fixture.residents.slot_of_ref(fixture.person).value
	var durability: IntMath.IntResult = IntMath.IntResult.new()
	fixture.gear.durability_into(fixture.tool, durability)
	fixture.residents.set_equipped_tool_durability(slot, durability.value - 1)
	checks["changed_equipment_mirror"] = fixture.observe(fixture.person, fixture.tool, fixture.cargo).error == "TRANSITION_GEAR_MIRROR"
	fixture.residents.set_equipped_tool_durability(slot, durability.value)
	var satchel: Vector2i = fixture.residents.satchel_of(slot)
	fixture.residents.set_satchel(slot, Vector2i(satchel.x, satchel.y + 1))
	checks["stale_satchel"] = fixture.observe(fixture.person, fixture.tool, fixture.cargo).error == "TRANSITION_CARGO_IDENTITY"
	fixture.residents.set_satchel(slot, satchel)
	return checks
