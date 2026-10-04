extends RefCounted
## View-only D11 search. Existing completed endpoints and actual source contacts are never manufactured.
## No witness, lease, prepared candidate or authoritative owner is retained between search steps.

const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const PAIRS_PER_STEP: int = 32
const REFUSE_BINDING: StringName = &"ACCESS_ACTUAL_BINDING"
const REFUSE_CHANGED: StringName = &"ACCESS_SOURCE_CHANGED"
const REFUSE_MISSING: StringName = &"ACCESS_NO_REACHABLE_WORK_FACE"
const REFUSE_BOUNDARY: StringName = &"ACCESS_DRAWN_BOUNDARY"
const REFUSE_SEARCHING: StringName = &"ACCESS_SEARCHING"
const REFUSE_BUSY: StringName = &"ACCESS_VIEW_BUSY"

class Choice extends RefCounted:
	## Private immutable presentation copy. Public readers duplicate arrays and never return this instance.
	var request: Approach.Request = null
	var roles: PackedInt32Array = PackedInt32Array()
	var route_lines: PackedInt32Array = PackedInt32Array()
	var patch: PackedInt32Array = PackedInt32Array()
	var root: Vector3i = Vector3i.ZERO
	var access_root: Vector3i = Vector3i.ZERO
	var graph_revision: int = 0
	var graph_receipt: int = 0
	var location_receipt: int = 0
	var catalog_revision: int = 0

class Attempt extends RefCounted:
	var error: StringName = &""
	var choice: Choice = null

var revision: int = 0
var last_step_usec: int = 0
var max_step_usec: int = 0
var proof_attempts: int = 0
var _provider: WeakRef = null
var _anchor: Vector2i = NULL_REF
var _owners: Array[WeakRef] = []
var _plan: Orders.RoomPlan = null
var _drawing_revision: int = -1
var _choice: Choice = null
var _candidate: Approach.Request = null
var _pins: PackedInt64Array = PackedInt64Array()
var _datum: Vector3i = Vector3i.ZERO
var _picked: Vector2i = Vector2i.ZERO
var _has_pick: bool = false
var _slot: int = 0
var _profile: int = 0
var _travel: int = 0
var _recheck: bool = false
var _searching: bool = false
var _reading: bool = false
var _locked: bool = false
var _error: StringName = REFUSE_MISSING
var _reentered: bool = false
var _last_candidate_error: StringName = &""
var _scan_record: Locations.Record = null
var _scan_ref: PackedInt32Array = PackedInt32Array([0, 0])
var _loaded_slot: int = -1
var _plan_bounds: PackedInt64Array = PackedInt64Array()


func configure(provider: WorldRoutes, access_anchor: Vector2i) -> StringName:
	"""Only a real host-selected completed anchor starts a search; no nearest-point or zero-route fallback."""
	if _guarded(): return REFUSE_BUSY
	_reading = true
	_reentered = false
	var code: StringName = _configure_actual(provider, access_anchor)
	_reading = false
	return REFUSE_BUSY if _reentered else code


func _configure_actual(provider: WorldRoutes, access_anchor: Vector2i) -> StringName:
	"""Hold all original actual collaborators during the sole synchronous configuration observation."""
	if _provider != null or provider == null or provider.get_script() != WorldRoutes \
			or not Space.valid_ref(access_anchor): return REFUSE_BINDING
	var config: WorldRoutes.Configuration = _configuration(provider)
	if config.locations == null or config.profiles == null or config.owner == null or config.budget == null \
			or config.routes == null or config.catalog == null or config.world == null: return REFUSE_BINDING
	var endpoint: Locations.Record = _record()
	var code: StringName = provider.binding_refusal()
	if code == &"": code = config.locations.read_location_into(access_anchor, endpoint)
	if code != &"" or _reentered or not Approach.Witness.exact_configuration(provider, config): return REFUSE_BINDING
	var domain: Space.Domain = config.owner.domain_copy()
	if domain == null or endpoint.world != domain.descriptor().world_ref: return REFUSE_BINDING
	if _reentered or not Approach.Witness.exact_configuration(provider, config): return REFUSE_BINDING
	_provider = weakref(provider)
	_anchor = access_anchor
	_datum = domain.descriptor().datum_u
	for owner: RefCounted in _owner_list(config): _owners.append(weakref(owner))
	return &""


func begin(plan: Orders.RoomPlan, drawing_revision: int, resuggest: bool = false,
		picked_cell: Vector2i = Vector2i.ZERO, has_pick: bool = false) -> StringName:
	"""Restart cursor work while preserving the chosen marker; bracket every observer with the original input."""
	if _guarded(): return REFUSE_BUSY
	if not _plan_valid(plan) or drawing_revision < 0: return _stop(REFUSE_BOUNDARY)
	_reading = true
	_reentered = false
	var copied: Orders.RoomPlan = Orders.RoomPlan.new()
	copied.copy_from(plan)
	var provider: WorldRoutes = _actual()
	var config: WorldRoutes.Configuration = _configuration(provider) if provider != null else null
	var code: StringName = _owner_refusal(provider, config)
	var pins: PackedInt64Array = _current_pins(config) if code == &"" else PackedInt64Array()
	if code == &"" and (not Approach.Witness.same_plan(plan, copied) or _reentered): code = REFUSE_CHANGED
	if code == &"": code = _owner_refusal(provider, config)
	if code == &"" and not _epochs_match(config, pins, copied.space_revision): code = REFUSE_CHANGED
	if code == &"": _start(copied, drawing_revision, resuggest, picked_cell, has_pick, pins)
	_reading = false
	return &"" if code == &"" else _stop(code)


func _start(plan: Orders.RoomPlan, drawing_revision: int, resuggest: bool,
		picked_cell: Vector2i, has_pick: bool, pins: PackedInt64Array) -> void:
	"""Publish one isolated presentation search only after its entire original observation succeeds."""
	_plan = plan
	_plan_bounds = _bounds_of(plan)
	_drawing_revision = drawing_revision
	_pins = pins
	_slot = 0
	_profile = 0
	_travel = 0
	_has_pick = has_pick
	_picked = picked_cell
	_recheck = _choice != null and not resuggest
	_candidate = copy_request(_choice.request, _plan) if _recheck else null
	_searching = true
	_error = REFUSE_SEARCHING
	_last_candidate_error = &""
	revision += 1


static func _current_pins(config: WorldRoutes.Configuration) -> PackedInt64Array:
	"""Six actual revision/receipt scalars distinguish reload, restore and equal-version companion changes."""
	return PackedInt64Array([config.owner.revision(), config.routes.revision(), config.profiles.content_revision(),
		config.catalog.content_revision(), config.routes.last_published_token(), config.locations.last_published_token()])


static func _plan_valid(plan: Orders.RoomPlan) -> bool:
	"""Reject malformed, noncanonical or overflowing view input before snapshots, loops or product arithmetic."""
	return plan != null and not plan.cells.is_empty() and plan.cells.size() <= 2 * Footprint.MAX_OPERATION_CELLS \
		and plan.cells.size() % 2 == 0 and plan.cell_size_u >= 1 and plan.cell_size_u <= 2048 \
		and 2048 % plan.cell_size_u == 0 and plan.height_u >= 1 and plan.height_u <= Space.I32_MAX \
		and Space.int32(int(plan.origin_u.y) + plan.height_u) and _bounds_of(plan).size() == 4


func step() -> StringName:
	"""Spend at most32 cheap pairs and one full proof; no engine time value decides candidate validity."""
	if _guarded(): return REFUSE_BUSY
	if not _searching: return _error
	_reading = true
	_reentered = false
	_loaded_slot = -1
	var started: int = Time.get_ticks_usec()
	var provider: WorldRoutes = _actual()
	var config: WorldRoutes.Configuration = _configuration(provider) if provider != null else null
	var code: StringName = _source_refusal(provider, config)
	if code == &"": code = _step_candidates(provider, config)
	if _reentered: code = REFUSE_BUSY
	if code != &"" and code != REFUSE_SEARCHING: _stop(code)
	last_step_usec = Time.get_ticks_usec() - started
	max_step_usec = maxi(max_step_usec, last_step_usec)
	_reading = false
	return _error


func _step_candidates(provider: WorldRoutes, config: WorldRoutes.Configuration) -> StringName:
	"""Source prefilters precede the expensive real path/face observation; one candidate is never permission."""
	if _recheck: return _attempt(provider, config, _candidate)
	for ignored: int in PAIRS_PER_STEP:
		if _candidate != null:
			var travel: Profiles.Descriptor = Profiles.Descriptor.new()
			if _travel >= config.profiles.profile_count(_pins[2]):
				_candidate = null
				continue
			var work: Profiles.Descriptor = Profiles.Descriptor.new()
			var code: StringName = config.profiles.descriptor_into(_candidate.work_profile, _pins[2], work)
			if code == &"": code = config.profiles.descriptor_into(_travel, _pins[2], travel)
			_travel += 1
			if code != &"": return code
			if not _travel_matches(travel, work): continue
			_candidate.travel_profile = travel.profile_id
			_candidate.travel_revision = travel.profile_revision
			return _attempt(provider, config, _candidate)
		var candidate_code: StringName = _next_candidate(provider, config)
		if candidate_code != &"": return candidate_code
	return REFUSE_SEARCHING


func _next_candidate(provider: WorldRoutes, config: WorldRoutes.Configuration) -> StringName:
	"""Enumerate full live identities through the public reader, never through private endpoint columns."""
	if _slot >= config.locations.location_capacity(): return _no_candidate()
	if _profile >= config.profiles.profile_count(_pins[2]):
		_slot += 1
		_profile = 0
		return &""
	var code: StringName = &""
	if _loaded_slot != _slot:
		_scan_record = _record()
		code = config.locations.live_location_at_into(_slot, _pins[0], _scan_ref, _scan_record)
		_loaded_slot = _slot
	if _source_refusal(provider, config) != &"": return REFUSE_CHANGED
	if code == &"LOCATION_ABSENT":
		_slot += 1
		_profile = 0
		return &""
	if code != &"": return code
	var descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
	code = config.profiles.descriptor_into(_profile, _pins[2], descriptor)
	_profile += 1
	if code != &"": return code
	if _scan_record.role == Locations.ROLE_STORAGE or _scan_record.world != _plan.world \
			or not _work_matches(descriptor): return &""
	_candidate = _derive(config.profiles, _scan_record, Vector2i(_scan_ref[0], _scan_ref[1]), descriptor)
	_travel = 0
	return _source_refusal(provider, config)


func _derive(profiles: Profiles, endpoint: Locations.Record, handle: Vector2i,
		descriptor: Profiles.Descriptor) -> Approach.Request:
	"""An authored full patch determines its exact face/cube; no sampled tip or rounded contact is substituted."""
	var patch: Profiles.Box = Profiles.Box.new()
	for ordinal: int in descriptor.box_count:
		if profiles.box_into(descriptor.profile_id, descriptor.profile_revision, _pins[2], ordinal, patch) != &"": return null
		if patch.role != Profiles.CONTACT_PATCH: continue
		var absolute: PackedInt32Array = translated(patch, endpoint.point)
		if absolute.size() != 6 or not _near_drawing(absolute): return null
		var cube: PackedInt32Array = target_for_patch(absolute, endpoint.point, _datum)
		if cube.size() != 4 or not _boundary_contains(_plan, absolute, int(cube[3]), _picked, _has_pick): return null
		var request: Approach.Request = copy_request(null, _plan)
		request.access = _anchor
		request.work_location = handle
		request.work_profile = descriptor.profile_id
		request.work_revision = descriptor.profile_revision
		request.content_revision = descriptor.content_revision
		request.target_origin = Vector3i(cube[0], cube[1], cube[2])
		request.face = cube[3]
		request.yaw = descriptor.yaw
		return request
	return null


func _attempt(provider: WorldRoutes, config: WorldRoutes.Configuration, request: Approach.Request) -> StringName:
	"""The helper's entire witness frame ends before this original lease is released, even on refusal."""
	var code: StringName = _source_refusal(provider, config)
	if code != &"": return code
	if _recheck and not _choice_epoch_matches(config): return REFUSE_CHANGED
	var token: int = config.budget.acquire(Budget.COLD_BYTES)
	if token == 0: return Budget.REFUSE_BUSY
	proof_attempts += 1
	var result: Attempt = _observe(provider, request, token)
	code = config.budget.release(token)
	if code != &"" or _source_refusal(provider, config) != &"": return REFUSE_CHANGED
	if result.error != &"":
		_last_candidate_error = result.error
		return result.error if _recheck else REFUSE_SEARCHING
	_choice = result.choice
	_searching = false
	_error = &""
	_candidate = null
	revision += 1
	return &""


func _observe(provider: WorldRoutes, request: Approach.Request, token: int) -> Attempt:
	"""Existing complete geometric proof supplies the only successful preview; no Room candidate is allocated."""
	var out: Attempt = Attempt.new()
	var copied: Orders.RoomPlan = Orders.RoomPlan.new()
	copied.copy_from(_plan)
	var result: Approach.Result = Approach.begin(provider, request, copied, token)
	out.error = result.error
	if out.error != &"": return out
	var patch: PackedInt32Array = _patch_from_witness(result.witness)
	if not _boundary_contains(_plan, patch, request.face, _picked, _has_pick):
		out.error = REFUSE_BOUNDARY
		return out
	out.choice = _capture_choice(result.witness, patch)
	if result.witness.path_count > 0 and out.choice.route_lines.is_empty():
		out.choice = null
		out.error = REFUSE_CHANGED
		return out
	out.error = result.witness.source_refusal()
	if out.error != &"": out.choice = null
	return out


func _capture_choice(witness: Approach.Witness, patch: PackedInt32Array) -> Choice:
	"""Copy only bounded presentation values; the large proof/witness/owners stay in this synchronous call."""
	var choice: Choice = Choice.new()
	choice.request = copy_request(witness.original, _plan)
	choice.root = witness.face.endpoint.point
	choice.access_root = witness.access.point
	choice.patch = patch
	choice.roles = witness.boxes.duplicate()
	choice.graph_revision = _pins[1]
	choice.catalog_revision = _pins[3]
	choice.graph_receipt = _pins[4]
	choice.location_receipt = _pins[5]
	choice.route_lines = _route_lines(witness)
	return choice


static func _patch_from_witness(witness: Approach.Witness) -> PackedInt32Array:
	"""The selected source patch already has its exact yaw; translate only once by the observed work root."""
	var box: Profiles.Box = Profiles.Box.new()
	for ordinal: int in witness.work.box_count:
		if witness.config.profiles.box_into(witness.work.profile_id, witness.work.profile_revision,
				witness.work.content_revision, ordinal, box) != &"": return PackedInt32Array()
		if box.role == Profiles.CONTACT_PATCH: return translated(box, witness.face.endpoint.point)
	return PackedInt32Array()


static func _route_lines(witness: Approach.Witness) -> PackedInt32Array:
	"""Draw actual existing polylines; an empty route is never replaced by a fabricated straight passage."""
	var lines: PackedInt32Array = PackedInt32Array()
	var edge: Routes.Edge = Routes.Edge.new()
	var first: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var last: PackedInt32Array = PackedInt32Array([0, 0, 0])
	for at: int in witness.path_count:
		var ref: Vector2i = Vector2i(witness.path[at * 2], witness.path[at * 2 + 1])
		if witness.config.routes.edge_metadata_into(ref, edge) != &"": return PackedInt32Array()
		for ordinal: int in range(1, edge.point_count):
			if lines.size() > 6 * Routes.MAX_VERTICES - 6: return PackedInt32Array()
			if witness.config.routes.edge_point_into(ref, ordinal - 1, first) != &"" \
					or witness.config.routes.edge_point_into(ref, ordinal, last) != &"": return PackedInt32Array()
			lines.append_array(first)
			lines.append_array(last)
	return lines


func selection_refusal(plan: Orders.RoomPlan, drawing_revision: int, stamp: int) -> StringName:
	"""Bracket synchronous source observations; RoomOrders still repeats the complete physical proof."""
	if _reading:
		_reentered = true
		return REFUSE_BUSY
	_reading = true
	_reentered = false
	var code: StringName = _selection_refusal(plan, drawing_revision, stamp)
	_reading = false
	return REFUSE_BUSY if _reentered else code


func _selection_refusal(plan: Orders.RoomPlan, drawing_revision: int, stamp: int) -> StringName:
	"""The original drawing and selection must survive both sides of every actual source observation."""
	if _searching: return REFUSE_SEARCHING
	if _error != &"": return _error
	if not _selection_matches(plan, drawing_revision, stamp): return REFUSE_CHANGED
	var provider: WorldRoutes = _actual()
	var config: WorldRoutes.Configuration = _configuration(provider) if provider != null else null
	var code: StringName = _source_refusal(provider, config)
	if code == &"" and not _choice_epoch_matches(config): code = REFUSE_CHANGED
	if code == &"" and not _selection_matches(plan, drawing_revision, stamp): code = REFUSE_CHANGED
	return code


func _selection_matches(plan: Orders.RoomPlan, drawing_revision: int, stamp: int) -> bool:
	"""This final comparison has no external observers and cannot reinterpret a different current marker."""
	return _choice != null and stamp == revision and drawing_revision == _drawing_revision \
		and Approach.Witness.same_plan(plan, _plan)


func selected_request(plan: Orders.RoomPlan, drawing_revision: int, stamp: int) -> Approach.Request:
	"""A fresh caller copy never exposes the retained selection or aliases its footprint."""
	if selection_refusal(plan, drawing_revision, stamp) != &"": return null
	var out: Approach.Request = copy_request(_choice.request, plan)
	out.cells = plan.cells.duplicate()
	return out


func lock_selection(plan: Orders.RoomPlan, drawing_revision: int, stamp: int) -> StringName:
	"""Reject selection edits during the synchronous command; this lock grants no owner permission."""
	if _guarded(): return REFUSE_BUSY
	var code: StringName = selection_refusal(plan, drawing_revision, stamp)
	if code == &"": _locked = true
	return code


func unlock_selection() -> void:
	"""The command adapter releases only its presentation guard after the actual owner returns."""
	if _reading:
		_reentered = true
		return
	_locked = false


func searching() -> bool:
	"""Searching is a visible view state, independent of route planning or productive work."""
	return _searching


func refusal() -> StringName:
	"""Return current preview validity without running an observer or acquiring a cold lease."""
	return _error


func preview() -> Dictionary:
	"""Return copied finite rendering data; no returned array can alter the selected command."""
	if _choice == null: return {"selected": false, "error": _error, "revision": revision}
	return {"selected": true, "error": _error, "revision": revision, "root": _choice.root,
		"access_root": _choice.access_root, "target": _choice.request.target_origin, "face": _choice.request.face,
		"patch": _choice.patch.duplicate(), "roles": _choice.roles.duplicate(), "route": _choice.route_lines.duplicate()}


func clear() -> StringName:
	"""Explicit discard drops view data only; it cannot retire a Room, endpoint or paid project."""
	if _guarded(): return REFUSE_BUSY
	_plan = null
	_choice = null
	_candidate = null
	_drawing_revision = -1
	return _stop(REFUSE_MISSING)


func _source_refusal(provider: WorldRoutes, config: WorldRoutes.Configuration) -> StringName:
	"""Every resumed step uses the original actual owner set and exact content/geometry/graph epochs."""
	if _reentered: return REFUSE_BUSY
	var code: StringName = _owner_refusal(provider, config)
	if code != &"": return code
	if _plan == null or not _epochs_match(config, _pins, _plan.space_revision) \
			or not config.locations.is_live_location(_anchor): return REFUSE_CHANGED
	if _reentered: return REFUSE_BUSY
	if not _epochs_match(config, _pins, _plan.space_revision): return REFUSE_CHANGED
	return _owner_refusal(provider, config)


static func _epochs_match(config: WorldRoutes.Configuration, pins: PackedInt64Array, geometry: int) -> bool:
	"""Final epoch comparison has no overridable getters after the actual endpoint observation."""
	return pins.size() == 6 and geometry == pins[0] and config.owner._ready_error == &"" \
		and config.owner._header[17] == pins[0] and config.owner._stage_token == 0 \
		and config.routes._live.revision == pins[1] and not config.profiles._loading \
		and config.profiles._live.header[0] == pins[2] and not config.catalog._loading \
		and config.catalog._live.header[0] == pins[3] and config.routes._last_published_token == pins[4] \
		and config.locations._last_published_token == pins[5]


func _owner_refusal(provider: WorldRoutes, config: WorldRoutes.Configuration) -> StringName:
	"""Weak identity pins cannot retain a discarded World or accept a replacement composition with equal numbers."""
	if provider == null or config == null or not Approach.Witness.exact_configuration(provider, config): return REFUSE_BINDING
	var actual: Array[RefCounted] = _owner_list(config)
	if _owners.size() != actual.size(): return REFUSE_BINDING
	for index: int in actual.size():
		if _owners[index].get_ref() != actual[index]: return REFUSE_CHANGED
	return &""


func _choice_epoch_matches(config: WorldRoutes.Configuration) -> bool:
	"""A source reload or restored graph requires an explicit new selection even when old coordinates still fit."""
	return _choice != null and _choice.request.space_revision == config.owner._header[17] \
		and _choice.request.content_revision == config.profiles._live.header[0] \
		and _choice.graph_revision == config.routes._live.revision and _choice.catalog_revision == config.catalog._live.header[0] \
		and _choice.graph_receipt == config.routes._last_published_token \
		and _choice.location_receipt == config.locations._last_published_token


func _no_candidate() -> StringName:
	"""Keep a meaningful last physical refusal when an exact requested boundary could not be reached."""
	return _last_candidate_error if _last_candidate_error != &"" else REFUSE_MISSING


func _near_drawing(patch: PackedInt32Array) -> bool:
	"""Cheap whole-drawing rejection precedes exact exposed-face coverage; it never grants boundary fit."""
	return _plan_bounds.size() == 4 and patch[0] >= _plan_bounds[0] and patch[3] <= _plan_bounds[2] \
		and patch[2] >= _plan_bounds[1] and patch[5] <= _plan_bounds[3]


static func _bounds_of(plan: Orders.RoomPlan) -> PackedInt64Array:
	"""One finite scan per drawing records only a rejection broadphase, never filled concave geometry."""
	var out: PackedInt64Array = PackedInt64Array([Space.I32_MAX, Space.I32_MAX, -2147483648, -2147483648])
	for at: int in range(0, plan.cells.size(), 2):
		if plan.cells[at] == Space.I32_MAX or plan.cells[at + 1] == Space.I32_MAX: return PackedInt64Array()
		if at > 0 and (plan.cells[at + 1] < plan.cells[at - 1] or (plan.cells[at + 1] == plan.cells[at - 1] \
				and plan.cells[at] <= plan.cells[at - 2])): return PackedInt64Array()
		var x: int = int(plan.origin_u.x) + int(plan.cells[at]) * plan.cell_size_u
		var z: int = int(plan.origin_u.z) + int(plan.cells[at + 1]) * plan.cell_size_u
		if not Space.int32(x) or not Space.int32(z) or not Space.int32(x + plan.cell_size_u) \
				or not Space.int32(z + plan.cell_size_u): return PackedInt64Array()
		out[0] = mini(out[0], x)
		out[1] = mini(out[1], z)
		out[2] = maxi(out[2], x + plan.cell_size_u)
		out[3] = maxi(out[3], z + plan.cell_size_u)
	return out


func _stop(code: StringName) -> StringName:
	"""Refused searches retain their last selected marker for explicit player revision."""
	_searching = false
	_candidate = null
	_error = code
	revision += 1
	return code


func _actual() -> WorldRoutes:
	"""Expiry never creates or borrows another WorldRoutes instance."""
	return _provider.get_ref() as WorldRoutes if _provider != null else null


func _guarded() -> bool:
	"""Attempted recursive view mutation poisons the active observation without changing its original input."""
	if _reading: _reentered = true
	return _reading or _locked


static func _configuration(provider: WorldRoutes) -> WorldRoutes.Configuration:
	"""Use the existing exact composition copier; this strong packet dies at the current call boundary."""
	var config: WorldRoutes.Configuration = WorldRoutes.Configuration.new()
	Approach.Witness.capture_configuration(provider, config)
	return config


static func _owner_list(config: WorldRoutes.Configuration) -> Array[RefCounted]:
	"""Thirteen finite weak identity pins are presentation bookkeeping, never a second authoritative store."""
	return [config.routes, config.owner, config.sources, config.locations, config.profiles, config.catalog,
		config.levels, config.movement, config.residents, config.transforms, config.world, config.terrain, config.budget]


static func _record() -> Locations.Record:
	"""The public Location reader writes only into caller-sized six-integer buffers."""
	var record: Locations.Record = Locations.Record.new()
	record.envelope.resize(6)
	record.support.resize(6)
	return record


static func _work_matches(descriptor: Profiles.Descriptor) -> bool:
	"""Only complete authored BUILD contacts can be prospective construction choices."""
	return descriptor.mode == Profiles.MODE_WORK and descriptor.work_kind == Jobs.JOB_KIND_BUILD \
		and descriptor.contact_kind == Profiles.CONTACT_ANCHOR_AND_PATCH and descriptor.yaw_kind == Profiles.YAW_EXACT \
		and descriptor.certificate_flags == Profiles.CERT_REQUIRED


static func _travel_matches(travel: Profiles.Descriptor, work: Profiles.Descriptor) -> bool:
	"""Keep every tool/load/source requirement; no neighboring cast or unqualified movement row is substituted."""
	return (travel.mode == Profiles.MODE_WALK or travel.mode == Profiles.MODE_CARRY) \
		and travel.certificate_flags == Profiles.CERT_REQUIRED and Approach.Witness.same_actor(travel, work) \
		and (travel.yaw_kind == Profiles.YAW_ALL or travel.yaw == work.yaw)


static func copy_request(source: Approach.Request, plan: Orders.RoomPlan) -> Approach.Request:
	"""Command scalars are exact; internal copies borrow only this view's already isolated footprint."""
	var out: Approach.Request = Approach.Request.new()
	out.world = plan.world
	out.space_revision = plan.space_revision
	out.room_type = plan.room_type
	out.level = plan.level
	out.origin_u = plan.origin_u
	out.cell_size_u = plan.cell_size_u
	out.height_u = plan.height_u
	out.cells = plan.cells
	if source == null: return out
	out.access = source.access
	out.work_location = source.work_location
	out.travel_profile = source.travel_profile
	out.travel_revision = source.travel_revision
	out.work_profile = source.work_profile
	out.work_revision = source.work_revision
	out.content_revision = source.content_revision
	out.target_origin = source.target_origin
	out.face = source.face
	out.yaw = source.yaw
	return out


static func translated(box: Profiles.Box, root: Vector3i) -> PackedInt32Array:
	"""Use wide scalar addition before narrowing, preserving even the source's negative contact residual."""
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(6)
	for axis: int in 3:
		var low: int = int(root[axis]) + int(box.low[axis])
		var high: int = int(root[axis]) + int(box.high[axis])
		if not Space.int32(low) or not Space.int32(high): return PackedInt32Array()
		out[axis] = low
		out[axis + 3] = high
	return out


static func target_for_patch(patch: PackedInt32Array, root: Vector3i, datum: Vector3i) -> PackedInt32Array:
	"""A positive planar patch fits exactly one paid face; reject seams, nonplanes and overflowing extents."""
	if patch.size() != 6: return PackedInt32Array()
	var out: PackedInt32Array = PackedInt32Array([0, 0, 0, -1])
	for axis: int in 3:
		var low: int = patch[axis]
		var high: int = patch[axis + 3]
		if high < low: return PackedInt32Array()
		var origin: int = int(datum[axis]) + _floor_div(low - int(datum[axis]), Space.QUANTUM_U) * Space.QUANTUM_U
		if high == low:
			if out[3] != -1 or origin != low: return PackedInt32Array()
			var side: int = 0 if root[axis] < low else 1
			out[3] = axis * 2 + side
			origin -= Space.QUANTUM_U * side
		elif high > origin + Space.QUANTUM_U: return PackedInt32Array()
		if not Space.int32(origin) or not Space.int32(origin + Space.QUANTUM_U): return PackedInt32Array()
		out[axis] = origin
	return out if out[3] >= 0 else PackedInt32Array()


static func boundary_contains(plan: Orders.RoomPlan, patch: PackedInt32Array, face: int,
		picked: Vector2i = Vector2i.ZERO, has_pick: bool = false) -> bool:
	"""Public input is checked once; internal search already owns an isolated validated canonical drawing."""
	return _plan_valid(plan) and _boundary_contains(plan, patch, face, picked, has_pick)


static func _boundary_contains(plan: Orders.RoomPlan, patch: PackedInt32Array, face: int,
		picked: Vector2i, has_pick: bool) -> bool:
	"""Measure the full patch on exact occupied fine cells, with no scan of unrelated painted rows."""
	if not _patch_valid(patch, face): return false
	@warning_ignore("integer_division") var axis: int = face / 2
	if axis != 1 and (patch[1] < plan.origin_u.y or patch[4] > int(plan.origin_u.y) + plan.height_u): return false
	if axis == 1 and patch[1] != int(plan.origin_u.y) + (plan.height_u if face == 3 else 0): return false
	var bounds: PackedInt64Array = _patch_cells(plan, patch, face)
	if bounds.is_empty(): return false
	var expected: int = (int(patch[3]) - patch[0]) * (int(patch[5]) - patch[2]) if axis == 1 \
		else int(patch[5 if axis == 0 else 3]) - patch[2 if axis == 0 else 0]
	var covered: int = 0
	var picked_match: bool = not has_pick
	if 2 * (bounds[2] - bounds[0] + 1) * (bounds[3] - bounds[1] + 1) > plan.cells.size():
		return _scan_boundary(plan, patch, face, picked, has_pick, expected)
	for z: int in range(bounds[1], bounds[3] + 1):
		for x: int in range(bounds[0], bounds[2] + 1):
			if not Footprint.contains_cell(plan.cells, x, z): continue
			var amount: int = _boundary_overlap(plan, Vector2i(x, z), patch, face)
			covered += amount
			if amount > 0 and Vector2i(x, z) == picked: picked_match = true
	return covered == expected and picked_match


static func _scan_boundary(plan: Orders.RoomPlan, patch: PackedInt32Array, face: int,
		picked: Vector2i, has_pick: bool, expected: int) -> bool:
	"""For tiny pitch, scanning the actual finite paint costs less than iterating a large absent patch grid."""
	var covered: int = 0
	var picked_match: bool = not has_pick
	for at: int in range(0, plan.cells.size(), 2):
		var cell: Vector2i = Vector2i(plan.cells[at], plan.cells[at + 1])
		var amount: int = _boundary_overlap(plan, cell, patch, face)
		covered += amount
		if amount > 0 and cell == picked: picked_match = true
	return covered == expected and picked_match


static func _patch_cells(plan: Orders.RoomPlan, patch: PackedInt32Array, face: int) -> PackedInt64Array:
	"""Signed floor selects every intersected cell; exact normal planes select only the approached boundary side."""
	var out: PackedInt64Array = PackedInt64Array()
	out.resize(4)
	for index: int in 2:
		var axis: int = index * 2
		var low: int = int(patch[axis]) - plan.origin_u[axis]
		var high: int = int(patch[axis + 3]) - plan.origin_u[axis]
		if high == low:
			if low % plan.cell_size_u != 0: return PackedInt64Array()
			out[index] = _floor_div(low, plan.cell_size_u) - (1 if face % 2 == 1 else 0)
			out[index + 2] = out[index]
		else:
			out[index] = _floor_div(low, plan.cell_size_u)
			out[index + 2] = _floor_div(high - 1, plan.cell_size_u)
		if not Space.int32(out[index]) or not Space.int32(out[index + 2]): return PackedInt64Array()
	return out


static func _patch_valid(patch: PackedInt32Array, face: int) -> bool:
	"""Each contact is a complete one-cube planar patch; bound area products before multiplying."""
	if patch.size() != 6 or face < 0 or face > 5: return false
	@warning_ignore("integer_division") var normal: int = face / 2
	for axis: int in 3:
		var span: int = int(patch[axis + 3]) - patch[axis]
		if axis == normal:
			if span != 0: return false
		elif span < 1 or span > Space.QUANTUM_U: return false
	return true


static func _boundary_overlap(plan: Orders.RoomPlan, cell: Vector2i, patch: PackedInt32Array, face: int) -> int:
	"""Only exposed fine-grid faces contribute; adjacent paint never becomes an opening through an interior wall."""
	var x: int = int(plan.origin_u.x) + int(cell.x) * plan.cell_size_u
	var z: int = int(plan.origin_u.z) + int(cell.y) * plan.cell_size_u
	var dx: int = maxi(0, mini(x + plan.cell_size_u, patch[3]) - maxi(x, patch[0]))
	var dz: int = maxi(0, mini(z + plan.cell_size_u, patch[5]) - maxi(z, patch[2]))
	if face == 2 or face == 3: return dx * dz
	var neighbor: Vector2i = cell
	if face == 0 or face == 1:
		if patch[0] != x + (plan.cell_size_u if face == 1 else 0): return 0
		neighbor.x += -1 if face == 0 else 1
	else:
		if patch[2] != z + (plan.cell_size_u if face == 5 else 0): return 0
		neighbor.y += -1 if face == 4 else 1
	if Footprint.contains_cell(plan.cells, neighbor.x, neighbor.y): return 0
	return dz if face < 2 else dx


static func _floor_div(value: int, divisor: int) -> int:
	"""Signed integer floor preserves negative datum-relative world coordinates without floating point."""
	@warning_ignore("integer_division") var quotient: int = value / divisor
	return quotient - 1 if value < 0 and value % divisor != 0 else quotient
