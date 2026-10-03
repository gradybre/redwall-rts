extends "res://scripts/core/buildings.gd".SpatialAuthority
## Sole actual Buildings spatial coordinator. Paid fitting is one action of this room owner.
## Physical shell, profile, service and contact qualification is mandatory; the base refuses.

const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const SpaceOwner := preload("res://scripts/core/underground_space_owner.gd")
const RoomSpace := preload("res://scripts/core/room_space.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_BINDING: StringName = &"UNDERGROUND_ROOM_OWNER_UNBOUND"
const REFUSE_FURNITURE: StringName = &"UNDERGROUND_PENDING_FURNITURE_REQUIRED"
const REFUSE_TRANSITION: StringName = &"UNDERGROUND_ROOM_TRANSITION_NOT_PREPARED"
const REFUSE_PLAN: StringName = &"UNDERGROUND_ROOM_PLAN_INVALID"
## Local RoomOrders stage only; never passed as a ModularContract operation/action ordinal.
const ROOM_ADMISSION_STAGE: int = 100

class RoomPlan extends RefCounted:

	## Caller data describes the exact painted shape, not physical cuts or qualification.
	## Cells remain canonical [x,z] indices with an explicit world transform. A finer painted
	## outline is never snapped to the separate ECON-001 physical cut lattice.
	var world: Vector2i = NULL_REF
	var space_revision: int = 0
	var room_type: int = -1
	var level: int = -1
	var origin_u: Vector3i = Vector3i.ZERO
	var cell_size_u: int = 0
	var height_u: int = 0
	var cells: PackedInt32Array = PackedInt32Array()

	func copy_from(source: RoomPlan) -> void:
		"""Snapshot caller cells only after the exact shared cold peak is acquired."""
		world = source.world
		space_revision = source.space_revision
		room_type = source.room_type
		level = source.level
		origin_u = source.origin_u
		cell_size_u = source.cell_size_u
		height_u = source.height_u
		cells = source.cells.duplicate()

	func reset() -> void:
		"""Drop the operation's copied cells before releasing the shared cold lease."""
		world = NULL_REF
		space_revision = 0
		room_type = -1
		level = -1
		origin_u = Vector3i.ZERO
		cell_size_u = 0
		height_u = 0
		cells.clear()

class Bindings extends RefCounted:

	func exact_binding(_buildings: Buildings, _space: SpaceOwner, _construction: Construction,
			_world: Vector2i) -> bool:
		"""Prove actual World owners and the admitted joint live/cold budget; base grants nothing."""
		return false

	func begin_room_cold(_plan: RoomPlan) -> StringName:
		"""Acquire plan-copy, Footprint dictionary/native and spatial/companion peak before any copies."""
		return REFUSE_BINDING

	func room_plan_refusal(_plan: RoomPlan, _room: Vector2i, _space_token: int) -> StringName:
		"""Prove current actual terrain/level/support/profile and separate whole paid-cut coverage; stage companions."""
		return REFUSE_BINDING

	func room_prepared_refusal(_plan: RoomPlan, _room: Vector2i, _space_token: int) -> StringName:
		"""Recheck actual source/contact revisions and every prepared companion before identity publication."""
		return REFUSE_BINDING

	func discard_room_plan(_room: Vector2i, _space_token: int) -> void:
		"""Drop only this exact room companion; accepted claims from other Rooms remain live."""
		assert(false, "Unbound room bindings cannot retain a plan")

	func publish_room_plan(_room: Vector2i, _space_token: int) -> void:
		"""Publish only in the exact room-admission callback after identity and sealed marker geometry commit."""
		assert(false, "Unbound room bindings cannot publish a plan")

	func end_room_cold() -> void:
		"""Release the exact current room lease only after all copied plan/companion/Space scratch drops."""
		assert(false, "Unbound room bindings cannot own the shared cold lease")

	func admission_refusal(_room: Vector2i, _furniture: Vector2i, _type_id: int) -> StringName:
		"""Prepare completed shell, actual fitted geometry, room-purpose access and source qualification."""
		return REFUSE_BINDING

	func transition_refusal(_room: Vector2i, _furniture: Vector2i, _project: Vector2i,
			_action: int, _space_token: int) -> StringName:
		"""Stage contact/services before payment; productive proof must be allocation-free and current."""
		return REFUSE_BINDING

	func begin_cold(_room: Vector2i, _furniture: Vector2i, _project: Vector2i, _action: int) -> StringName:
		"""Acquire the exact shared finite cold peak before any candidate/domain/handle copy; refusal holds none."""
		return REFUSE_BINDING

	func end_cold(_room: Vector2i, _furniture: Vector2i, _project: Vector2i, _action: int) -> void:
		"""Release only this exact lease after companion and spatial scratch have been published/discarded."""
		assert(false, "Unbound room bindings cannot hold shared cold memory")

	func prepared_refusal(_room: Vector2i, _furniture: Vector2i, _project: Vector2i,
			_action: int, _space_token: int) -> StringName:
		"""Revalidate the exact sealed companion revision before the shared material transaction."""
		return REFUSE_BINDING

	func material_refusal(_room: Vector2i, _furniture: Vector2i, _project: Vector2i,
			_container: Vector2i, _job: Vector2i) -> StringName:
		"""Inputs and positive refunds need a real reachable finite physical contact."""
		return REFUSE_BINDING

	func worker_refusal(_room: Vector2i, _furniture: Vector2i, _project: Vector2i,
			_job: Vector2i, _worker: Vector2i) -> StringName:
		"""Prove actual worker arrival/load/posture and installed-geometry access at this operation."""
		return REFUSE_BINDING

	func discard_transition(_room: Vector2i, _furniture: Vector2i, _project: Vector2i,
			_action: int, _space_token: int) -> void:
		"""Discard only the exact companion candidate; never release accepted live footprint claims."""
		assert(false, "Unbound room bindings cannot own prepared state")

	func publish_transition(_room: Vector2i, _furniture: Vector2i, _project: Vector2i,
			_action: int, _space_token: int) -> void:
		"""Publish in the exact window and drop companion scratch before returning to release its cold lease."""
		assert(false, "Unbound room bindings cannot publish geometry or services")

	func area_of_room(_room: Vector2i) -> Buildings.OpResult:
		"""Read exact supported Room floor area, never surface TileLinks or an assumed rectangle."""
		return Buildings.OpResult.new(false, REFUSE_BINDING, 0, NULL_REF)

	func service_refusal(_room: Vector2i) -> StringName:
		"""Fresh whole-room/service-owner gates are separate from installed furniture presence."""
		return REFUSE_BINDING

var _construction: Construction = null
var _buildings: Buildings = null
var _space: SpaceOwner = null
var _sources: SpaceOwner.CoreSources = null
var _catalog: RoomCatalog = null
var _router: WeakRef = null
var _bindings: WeakRef = null
var _furniture_owner: WeakRef = null
var _world: Vector2i = NULL_REF
var _ready_error: StringName = REFUSE_BINDING
var _stage_project: Vector2i = NULL_REF
var _stage_furniture: Vector2i = NULL_REF
var _stage_room: Vector2i = NULL_REF
var _stage_action: int = -1
var _stage_token: int = 0
var _cold_held: bool = false
var _publishing: bool = false
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _room_plan: RoomPlan = RoomPlan.new()
var _room_candidate: Directory.CreateCandidate = Directory.CreateCandidate.new()


func configure(router: Router, space: SpaceOwner, sources: SpaceOwner.CoreSources,
		catalog: RoomCatalog, bindings: Bindings) -> StringName:
	"""Preflight exact composition before the single once-bound Buildings write."""
	if _construction != null or router == null or space == null or sources == null or catalog == null or bindings == null:
		return REFUSE_BINDING
	var construction: Construction = router.construction_owner() as Construction
	if construction == null or sources.construction_owner() != construction \
			or sources.directory() != construction.directory() or not space.is_bound_sources(sources):
		return REFUSE_BINDING
	var domain: RoomSpace.Domain = space.domain_copy()
	if domain == null or domain.descriptor().world_ref != router.world_ref() \
			or not bindings.exact_binding(construction.buildings(), space, construction, router.world_ref()):
		return REFUSE_BINDING
	_set_wiring(router, space, sources, catalog, bindings)
	var bound: Buildings.OpResult = _buildings.bind_spatial_authority(self)
	if not bound.ok:
		_clear_wiring()
		return bound.error
	_ready_error = &""
	return &""


func _set_wiring(router: Router, space: SpaceOwner, sources: SpaceOwner.CoreSources,
		catalog: RoomCatalog, bindings: Bindings) -> void:
	"""Stage borrowed immutable owner links; no source geometry or entity is allocated."""
	_construction = router.construction_owner() as Construction
	_buildings = _construction.buildings()
	_space = space
	_sources = sources
	_catalog = catalog
	_router = weakref(router)
	_bindings = weakref(bindings)
	_world = router.world_ref()


func _clear_wiring() -> void:
	"""Failed unpublished setup can retry without leaving a second owner partially bound."""
	_construction = null
	_buildings = null
	_space = null
	_sources = null
	_catalog = null
	_router = null
	_bindings = null
	_world = NULL_REF


func buildings_owner() -> RefCounted:
	"""Buildings compares the actual store during binding and every later spatial action."""
	return _buildings


func construction_owner() -> Construction:
	"""Return only this successfully configured accounting owner for exact composition."""
	return _construction if _ready_error == &"" else null


func world_ref() -> Vector2i:
	"""The immutable actual Directory World never comes from the UI's level number."""
	return _world if _ready_error == &"" else NULL_REF


func _actual_router() -> Contract:
	"""Weak expiration or accounting rewiring never qualifies a numerically similar router."""
	var target: Contract = _router.get_ref() as Contract if _router != null else null
	return target if target != null and _construction != null \
		and _construction.modular_authority() == target else null


func _actual_bindings() -> Bindings:
	"""Physical owner wiring is checked in O(1); hot paths do not construct spatial snapshots."""
	var target: Bindings = _bindings.get_ref() as Bindings if _bindings != null else null
	return target if target != null and target.exact_binding(_buildings, _space, _construction, _world) else null


func binding_refusal() -> StringName:
	"""Late World retirement, foreign wiring or expired owners fail before any productive mutation."""
	var code: StringName = _identity_binding_refusal()
	return code if code != &"" else (&"" if _actual_bindings() != null else REFUSE_BINDING)


func _identity_binding_refusal() -> StringName:
	"""Read actual local owner identity without invoking a provider callback inside publication attestation."""
	if _ready_error != &"" or _construction == null or _buildings.spatial_authority() != self \
			or _construction.buildings() != _buildings or not _space.is_bound_sources(_sources) \
			or not _construction.directory().is_valid_of_kind(_world, Directory.KIND_WORLD):
		return REFUSE_BINDING
	return &"" if _actual_router() != null and _bindings != null \
		and _bindings.get_ref() is Bindings else REFUSE_BINDING


func confirm_room(plan: RoomPlan) -> Buildings.OpResult:
	"""Confirm one exact painted plan as a real reserved Room; no excavation or services are completed."""
	if _stage_action != -1:
		return Buildings.OpResult.new(false, REFUSE_TRANSITION, 0, NULL_REF)
	_stage_action = ROOM_ADMISSION_STAGE
	var code: StringName = _room_input_refusal(plan)
	var bindings: Bindings = _actual_bindings() if code == &"" else null
	if code != &"" or bindings == null:
		_clear_stage()
		return Buildings.OpResult.new(false, code if code != &"" else REFUSE_BINDING, 0, NULL_REF)
	code = bindings.begin_room_cold(plan)
	if code != &"":
		_clear_stage()
		return Buildings.OpResult.new(false, code, 0, NULL_REF)
	_cold_held = true
	code = _room_input_refusal(plan)
	if code == &"":
		_room_plan.copy_from(plan)
		code = _prepare_room(bindings)
	if code == &"" and not _same_room_plan(plan):
		code = REFUSE_PLAN
	if code != &"":
		_discard_room(bindings)
		return Buildings.OpResult.new(false, code, 0, NULL_REF)
	return _publish_room(bindings)


func _room_input_refusal(plan: RoomPlan) -> StringName:
	"""Bound input shape/scalars before cold admission; finer cells and exact height remain authored data."""
	if binding_refusal() != &"":
		return REFUSE_BINDING
	if plan == null or plan.world != _world or plan.space_revision != _space.revision() \
			or plan.room_type < 0 or plan.room_type >= Buildings.ROOM_TYPE_COUNT \
			or plan.level < 0 or plan.level > RoomSpace.I32_MAX \
			or plan.cell_size_u < 1 or plan.cell_size_u > RoomSpace.I32_MAX \
			or plan.height_u < 1 or plan.height_u > RoomSpace.I32_MAX \
			or int(plan.origin_u.y) + plan.height_u > RoomSpace.I32_MAX \
			or plan.cells.size() < 2 or plan.cells.size() % 2 != 0 \
			or plan.cells.size() > Footprint.MAX_OPERATION_CELLS * 2:
		return REFUSE_PLAN
	return &""


func _same_room_plan(plan: RoomPlan) -> bool:
	"""A synchronous caller/binding cannot change the confirmed request after its owned snapshot."""
	return plan != null and plan.world == _room_plan.world and plan.space_revision == _room_plan.space_revision \
		and plan.room_type == _room_plan.room_type and plan.level == _room_plan.level \
		and plan.origin_u == _room_plan.origin_u and plan.cell_size_u == _room_plan.cell_size_u \
		and plan.height_u == _room_plan.height_u and plan.cells == _room_plan.cells


func _prepare_room(bindings: Bindings) -> StringName:
	"""Pin future identity, exact marker geometry and mandatory actual-world proofs before any live write."""
	var code: StringName = _construction.directory().peek_create_into(Directory.KIND_ROOM, _room_candidate)
	if code != &"":
		return code
	_stage_room = _room_candidate.ref
	code = _prepare_room_geometry()
	if code == &"":
		code = bindings.room_plan_refusal(_room_plan, _stage_room, _stage_token)
	if code == &"":
		code = _space.seal(_stage_token)
	if code == &"":
		code = bindings.room_prepared_refusal(_room_plan, _stage_room, _stage_token)
	if code == &"":
		code = binding_refusal()
	if code == &"":
		code = _space.prepared_refusal(_stage_token)
	if code == &"":
		code = _buildings.spatial_room_candidate_refusal(_room_plan.room_type, _room_candidate)
	return code


func _prepare_room_geometry() -> StringName:
	"""Preserve finer painted cells and holes; actual cut coverage is a separate mandatory provider proof."""
	var domain: RoomSpace.Domain = _space.domain_copy()
	if domain == null:
		return REFUSE_BINDING
	var descriptor: Dictionary = domain.descriptor()
	if descriptor.world_ref != _world:
		return REFUSE_BINDING
	var code: StringName = Footprint.validation_error(_room_plan.cells, descriptor.max_cells, true)
	if code != &"":
		return code
	var begun: SpaceOwner.Result = _space.begin_stage(_room_plan.space_revision)
	if begun.error != &"":
		return begun.error
	_stage_token = begun.token
	code = _space.stage_room_admission(_stage_token, _room_candidate, _room_plan.room_type, self)
	if code != &"":
		return code
	return _stage_room_runs(descriptor.bounds_u)


func _stage_room_runs(bounds: PackedInt32Array) -> StringName:
	"""Claim contiguous canonical X runs; absent cells remain absent even inside the outer bounds."""
	var start: int = 0
	while start < _room_plan.cells.size():
		var end: int = start + 2
		while end < _room_plan.cells.size() and _room_plan.cells[end + 1] == _room_plan.cells[start + 1] \
				and _room_plan.cells[end] == _room_plan.cells[end - 2] + 1:
			end += 2
		var code: StringName = _stage_room_run(start, end, bounds)
		if code != &"":
			return code
		start = end
	return &""


func _room_run_box(start: int, end: int) -> PackedInt32Array:
	"""Use int64 transforms and refuse int32 overflow before packing; never round a painted edge."""
	var low_x: int = int(_room_plan.origin_u.x) + int(_room_plan.cells[start]) * _room_plan.cell_size_u
	var low_z: int = int(_room_plan.origin_u.z) + int(_room_plan.cells[start + 1]) * _room_plan.cell_size_u
	var high_x: int = int(_room_plan.origin_u.x) + (int(_room_plan.cells[end - 2]) + 1) * _room_plan.cell_size_u
	var high_z: int = low_z + _room_plan.cell_size_u
	if not RoomSpace.int32(low_x) or not RoomSpace.int32(low_z) \
			or not RoomSpace.int32(high_x) or not RoomSpace.int32(high_z):
		return PackedInt32Array()
	return PackedInt32Array([low_x, _room_plan.origin_u.y, low_z, high_x,
		int(_room_plan.origin_u.y) + _room_plan.height_u, high_z])


func _stage_room_run(start: int, end: int, bounds: PackedInt32Array) -> StringName:
	"""Add floor metadata and its exact Room marker; neither is supported void or an unpaid physical cut."""
	var box: PackedInt32Array = _room_run_box(start, end)
	if not RoomSpace.contains_box(bounds, box):
		return REFUSE_PLAN
	var region: SpaceOwner.Region = SpaceOwner.Region.new()
	region.owner = _stage_room
	region.level = _room_plan.level
	region.role = RoomSpace.FLOOR_DATUM
	region.box = box.duplicate()
	region.box[4] = region.box[1] + 1
	var floor_result: SpaceOwner.Result = _space.stage_add(_stage_token, region)
	if floor_result.error != &"":
		return floor_result.error
	region.role = RoomSpace.OBSTACLE
	region.box = box
	region.section = floor_result.handle
	region.claim_kind = SpaceOwner.CLAIM_ROOM
	region.claim_ref = _stage_room
	return _space.stage_add(_stage_token, region).error


func room_candidate_refusal(candidate: Directory.CreateCandidate, room_type: int) -> StringName:
	"""Attest retained identity without provider/Space callbacks; fresh physical proof precedes publication."""
	if _identity_binding_refusal() != &"" or _stage_action != ROOM_ADMISSION_STAGE or not _cold_held \
			or candidate == null or candidate != _room_candidate or candidate.ref != _stage_room \
			or room_type != _room_plan.room_type or _room_plan.world != _world:
		return REFUSE_TRANSITION
	return &""


func is_publishing_room_admission(room: Vector2i, room_type: int) -> bool:
	"""Preparation/direct calls cannot borrow the exact synchronous Room identity/marker publication."""
	return _publishing and room == _stage_room and room_candidate_refusal(_room_candidate, room_type) == &""


func _publish_room(bindings: Bindings) -> Buildings.OpResult:
	"""Publish actual Room then its sealed exact future source, without fallible reconstruction afterward."""
	_publishing = true
	var made: Buildings.OpResult = _buildings.designate_spatial_room_candidate(_room_plan.room_type, _room_candidate)
	if not made.ok:
		_publishing = false
		_discard_room(bindings)
		return made
	var code: StringName = _space.publish_room_admission(_stage_token, _room_candidate, _room_plan.room_type, self)
	assert(code == &"", "preflighted exact future Room geometry must publish after identity")
	bindings.publish_room_plan(_stage_room, _stage_token)
	_publishing = false
	_finish_room_cold(bindings)
	return made


func _discard_room(bindings: Bindings) -> void:
	"""Abort only this candidate; every Room/Directory/geometry refusal leaves the live owners unchanged."""
	bindings.discard_room_plan(_stage_room, _stage_token)
	if _stage_token > 0:
		_space.abort(_stage_token)
	_finish_room_cold(bindings)


func _finish_room_cold(bindings: Bindings) -> void:
	"""Drop owned copied cells and candidate observations before releasing the exact shared peak."""
	_room_plan.reset()
	_room_candidate.reset()
	if _cold_held:
		bindings.end_room_cold()
	_clear_stage()


func furniture_owner_binding_refusal(owner: Contract.Owner) -> StringName:
	"""Preflight the furniture purpose without replacing an existing or expired weak owner."""
	if binding_refusal() != &"" or owner == null or _furniture_owner != null:
		return REFUSE_BINDING
	return &"" if owner.construction_owner() == _construction and owner.world_ref() == _world \
		and owner.purpose() == Construction.PURPOSE_SPATIAL_FURNITURE else REFUSE_BINDING


func bind_furniture_owner(owner: Contract.Owner) -> StringName:
	"""Publish one preflighted weak purpose link; actual Router binding remains separately exact."""
	var code: StringName = furniture_owner_binding_refusal(owner)
	if code == &"":
		_furniture_owner = weakref(owner)
	return code


func is_bound_furniture_owner(owner: Contract.Owner) -> bool:
	"""A stale or foreign purpose instance cannot reuse full refs from another composition."""
	return owner != null and binding_refusal() == &"" and _furniture_owner != null \
		and _furniture_owner.get_ref() == owner and _actual_router().is_bound_owner(owner)


func _actual_owner() -> Contract.Owner:
	"""Resolve the current exact shared-router purpose; no strong back-reference cycle exists."""
	var target: Contract.Owner = _furniture_owner.get_ref() as Contract.Owner if _furniture_owner != null else null
	return target if is_bound_furniture_owner(target) else null


func furniture_admission_refusal(furniture: Vector2i) -> StringName:
	"""Cold admission proves actual pending identity, permanent purpose and registered source facts."""
	var code: StringName = _pending_refusal(furniture)
	if code != &"":
		return code
	var room: Vector2i = _buildings.room_ref_of_furniture(furniture)
	var kind: Buildings.OpResult = _buildings.spatial_kind_of_room(room)
	var type_id: Buildings.OpResult = _buildings.type_id_of_furniture(furniture)
	if not kind.ok or kind.value != Buildings.ROOM_SPACE_UNDERGROUND or not type_id.ok:
		return REFUSE_FURNITURE
	code = _catalog.compatibility_error(_buildings.type_of_room(room).value, type_id.value)
	if code == &"":
		code = _space.source_refusal(room)
	if code == &"":
		code = _space.source_refusal(furniture)
	return code


func _pending_refusal(furniture: Vector2i) -> StringName:
	"""Hot identity validation uses only exact live rows and immutable membership, without allocations."""
	if binding_refusal() != &"" or _actual_owner() == null:
		return REFUSE_BINDING
	return &"" if _buildings.is_live_furniture(furniture) and not _buildings.is_furniture_installed(furniture) \
		and _buildings.is_live_room(_buildings.room_ref_of_furniture(furniture)) else REFUSE_FURNITURE


func prepare_admission(furniture: Vector2i, type_id: int) -> StringName:
	"""Prepare existing physical admission before actual Construction allocates its full identity."""
	var code: StringName = furniture_admission_refusal(furniture)
	if code != &"" or _stage_action != -1:
		return code if code != &"" else REFUSE_TRANSITION
	if _buildings.type_id_of_furniture(furniture).value != type_id:
		return REFUSE_FURNITURE
	_set_stage(NULL_REF, furniture, Contract.ADMIT)
	return _actual_bindings().admission_refusal(_stage_room, furniture, type_id)


func project_refusal(project: Vector2i) -> StringName:
	"""O(1) exact accounting/member checks precede every productive/contact operation."""
	if binding_refusal() != &"" or not _construction.purpose_into(project, _math) \
			or _math.value != Construction.PURPOSE_SPATIAL_FURNITURE:
		return REFUSE_BINDING
	return _pending_refusal(_construction.subject_ref_of(project))


func transition_refusal(project: Vector2i, action: int) -> StringName:
	"""Stage the exact cold physical change; START/PRODUCTIVE make no geometry-bank copy."""
	var code: StringName = project_refusal(project)
	if code != &"" or _stage_action != -1:
		return code if code != &"" else REFUSE_TRANSITION
	if action != Contract.START and action != Contract.PRODUCTIVE and action != Contract.COMMIT and action != Contract.CANCEL:
		return REFUSE_TRANSITION
	_set_stage(project, _construction.subject_ref_of(project), action)
	if action == Contract.COMMIT or action == Contract.CANCEL:
		code = _begin_cold_geometry(action)
	if code == &"":
		code = _actual_bindings().transition_refusal(_stage_room, _stage_furniture, project, action, _stage_token)
	if code == &"" and _stage_token > 0:
		code = _space.seal(_stage_token)
	if code == &"":
		code = _actual_bindings().prepared_refusal(_stage_room, _stage_furniture, project, action, _stage_token)
	if code == &"" and _stage_token > 0:
		code = _space.prepared_refusal(_stage_token)
	return code


func _set_stage(project: Vector2i, furniture: Vector2i, action: int) -> void:
	"""Retain only one synchronous stage; authoritative project progress remains in Construction."""
	_stage_project = project
	_stage_furniture = furniture
	_stage_room = _buildings.room_ref_of_furniture(furniture)
	_stage_action = action
	_stage_token = 0


func _begin_cold_geometry(action: int) -> StringName:
	"""Retain shared peak admission before the first cold bank copy, including failed geometry attempts."""
	var code: StringName = _actual_bindings().begin_cold(_stage_room, _stage_furniture, _stage_project, action)
	if code != &"":
		return code
	_cold_held = true
	return _prepare_geometry(action)


func _prepare_geometry(action: int) -> StringName:
	"""Keep installed source facts or exact removal in the existing sparse owner's staged bank."""
	if action == Contract.COMMIT and (not _construction.phase_into(_stage_project, _math) \
			or _math.value != Construction.PHASE_WORK_DONE \
			or not _construction.remaining_mwu_into(_stage_project, _math) or _math.value != 0):
		return Construction.REFUSE_WRONG_PHASE
	var begun: SpaceOwner.Result = _space.begin_stage(_space.revision())
	if begun.error != &"":
		return begun.error
	_stage_token = begun.token
	if action == Contract.COMMIT:
		return _space.stage_furniture_install(_stage_token, _stage_project, _actual_router(), _actual_owner())
	return _remove_owned_geometry()


func _remove_owned_geometry() -> StringName:
	"""Cold cancellation removes exact full-owner handles; stage_forget refuses omitted dependents."""
	var bounds: PackedInt32Array = _space.domain_copy().descriptor().bounds_u
	var handles: PackedInt32Array = PackedInt32Array()
	var code: StringName = _space.overlapping_regions_into(bounds, handles)
	if code != &"":
		return code
	var region: SpaceOwner.Region = SpaceOwner.Region.new()
	for index: int in range(0, handles.size(), 2):
		var handle: Vector2i = Vector2i(handles[index], handles[index + 1])
		code = _space.region_into(handle, region)
		if code != &"":
			return code
		if region.owner == _stage_furniture:
			code = _space.stage_remove(_stage_token, handle)
			if code != &"":
				return code
	return _space.stage_forget_source(_stage_token, _stage_furniture)


func material_refusal(project: Vector2i, container: Vector2i, job: Vector2i) -> StringName:
	"""Actual delivered inputs and refunds use this furniture's own physical contact."""
	var code: StringName = project_refusal(project)
	var furniture: Vector2i = _construction.subject_ref_of(project) if code == &"" else NULL_REF
	return _actual_bindings().material_refusal(_buildings.room_ref_of_furniture(furniture), furniture,
		project, container, job) if code == &"" else code


func worker_refusal(project: Vector2i, job: Vector2i, worker: Vector2i) -> StringName:
	"""Current physical qualification supplements the shared actual Job/tool/worker proofs."""
	var code: StringName = project_refusal(project)
	var furniture: Vector2i = _construction.subject_ref_of(project) if code == &"" else NULL_REF
	return _actual_bindings().worker_refusal(_buildings.room_ref_of_furniture(furniture), furniture,
		project, job, worker) if code == &"" else code


func discard_transition(project: Vector2i, action: int) -> void:
	"""A wrong action/project cannot erase another prepared candidate or any accepted footprint."""
	if _stage_action == ROOM_ADMISSION_STAGE or project != _stage_project or action != _stage_action or _publishing:
		return
	var target: Bindings = _bindings.get_ref() as Bindings if _bindings != null else null
	if target != null:
		target.discard_transition(_stage_room, _stage_furniture, project, action, _stage_token)
	if _stage_token > 0:
		_space.abort(_stage_token)
	if _cold_held and target != null:
		target.end_cold(_stage_room, _stage_furniture, project, action)
	_clear_stage()


func is_publishing(project: Vector2i, action: int, furniture: Vector2i, room: Vector2i) -> bool:
	"""Only the exact real router's synchronous physical callback permits companion publication."""
	var owner: Contract.Owner = _actual_owner()
	return _publishing and owner != null and project == _stage_project and action == _stage_action \
		and furniture == _stage_furniture and room == _stage_room \
		and _actual_router().is_publishing(project, action, owner)


func publish_transition(project: Vector2i, action: int) -> void:
	"""Publish only preflighted physical state after shared Funding/Work has actually committed."""
	var owner: Contract.Owner = _actual_owner()
	if owner == null or not _actual_router().is_publishing(project, action, owner) or action != _stage_action:
		return
	if action == Contract.ADMIT and _stage_project == NULL_REF \
			and _construction.subject_ref_of(project) == _stage_furniture:
		_stage_project = project
	if project != _stage_project or _publishing:
		return
	_publishing = true
	if action == Contract.COMMIT:
		_publish_install()
	elif action == Contract.CANCEL:
		_publish_removal()
	_actual_bindings().publish_transition(_stage_room, _stage_furniture, project, action, _stage_token)
	if _cold_held:
		_actual_bindings().end_cold(_stage_room, _stage_furniture, project, action)
	_publishing = false
	_clear_stage()


func _publish_install() -> void:
	"""Future source facts were sealed while pending; actual installation occurs only after payment."""
	var installed: Buildings.OpResult = _buildings.install_spatial_furniture(_stage_furniture)
	assert(installed.ok, "preflighted paid pending installation cannot fail")
	var code: StringName = _space.publish_furniture_install(_stage_token, _stage_project, _actual_router(), _actual_owner())
	assert(code == &"", "sealed actual installed source must publish without reconstruction")


func _publish_removal() -> void:
	"""Retire pending identity only after the sealed source-free candidate and actual refund commit."""
	_space.publish(_stage_token)
	var removed: Buildings.OpResult = _buildings.remove_furniture(_stage_furniture)
	assert(removed.ok, "preflighted pending cancellation cannot fail after actual refund")


func mutation_refusal(action: int, subject: Vector2i, related: Vector2i,
		value: int, rotation: int) -> StringName:
	"""No legacy setter, direct install or wrong Room can borrow the paid publication window."""
	if not is_publishing(_stage_project, _stage_action, subject, _stage_room) \
			or related != NULL_REF or value != 0 or rotation != 0:
		return Buildings.REFUSE_SPATIAL_COMMAND
	return &"" if action == Buildings.SPATIAL_FURNITURE_INSTALL and _stage_action == Contract.COMMIT \
		or action == Buildings.SPATIAL_FURNITURE_REMOVE and _stage_action == Contract.CANCEL \
		else Buildings.REFUSE_SPATIAL_COMMAND


func area_of_room(room: Vector2i) -> Buildings.OpResult:
	"""Read exact real floor area through the bound owner; an unknown Room never means zero area."""
	if binding_refusal() != &"" or not _buildings.is_live_room(room):
		return Buildings.OpResult.new(false, REFUSE_BINDING, 0, NULL_REF)
	var result: Buildings.OpResult = _actual_bindings().area_of_room(room)
	return result if result.ok and result.ref == room and result.value > 0 \
		else Buildings.OpResult.new(false, Buildings.REFUSE_SPATIAL_AREA, 0, NULL_REF)


func service_refusal(room: Vector2i) -> StringName:
	"""Installed flags only describe presence; actual connected whole-room service proof remains required."""
	if binding_refusal() != &"" or not _buildings.is_live_room(room):
		return REFUSE_BINDING
	return _actual_bindings().service_refusal(room)


func _clear_stage() -> void:
	"""Erase only transient callback identity; never reset actual progress or geometry history."""
	_stage_project = NULL_REF
	_stage_furniture = NULL_REF
	_stage_room = NULL_REF
	_stage_action = -1
	_stage_token = 0
	_cold_held = false
