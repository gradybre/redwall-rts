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
const Layout := preload("res://scripts/core/room_layout.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_BINDING: StringName = &"UNDERGROUND_ROOM_OWNER_UNBOUND"
const REFUSE_FURNITURE: StringName = &"UNDERGROUND_PENDING_FURNITURE_REQUIRED"
const REFUSE_TRANSITION: StringName = &"UNDERGROUND_ROOM_TRANSITION_NOT_PREPARED"
const REFUSE_PLAN: StringName = &"UNDERGROUND_ROOM_PLAN_INVALID"
## Local RoomOrders stage only; never passed as a ModularContract operation/action ordinal.
const ROOM_ADMISSION_STAGE: int = 100
const LAYOUT_OPERATION_STAGE: int = 101
const FURNITURE_BATCH_STAGE: int = 102
const LAYOUT_BATCH_CONTROL_BYTES: int = 138 # 120 coordinator/packet +16 Directory +1 receipt +1 guard.

class FurnitureBatch extends RefCounted:

	## Caller-admitted synchronous scratch, not retained Furniture/Project state.
	var count: int = 0
	var original: Layout.Batch = null
	var canonical: Layout.Batch = Layout.Batch.new()
	var submitted: Layout.Batch = Layout.Batch.new()
	var candidates: Directory.CreateBatch = null
	var slots: PackedInt32Array = PackedInt32Array()
	var generations: PackedInt32Array = PackedInt32Array()
	var kinds: PackedInt32Array = PackedInt32Array()
	var typed_rows: PackedInt32Array = PackedInt32Array()
	var persistent_ids: PackedInt32Array = PackedInt32Array()
	var receipt: Layout.Submission = Layout.Submission.new()

	func copy_request(request: Layout.Batch) -> void:
		"""Keep original and two distinct input copies; providers never receive the canonical one."""
		original = request
		copy_batch(request, canonical)
		copy_batch(request, submitted)
		@warning_ignore("integer_division") count = request.entries.size() / Layout.ENTRY_STRIDE
		receipt.project_refs.resize(count * 2)

	static func copy_batch(source: Layout.Batch, target: Layout.Batch) -> void:
		"""Called only after the actual shared scope admits both16N entry buffers and their headers."""
		target.room_ref = source.room_ref
		target.room_type = source.room_type
		target.level = source.level
		target.pitch_units = source.pitch_units
		target.expected_revision = source.expected_revision
		target.entries = source.entries.duplicate()

	func observe(directory: Directory) -> StringName:
		"""Drop the8N kind request before constructing the40N separately pinned identity columns."""
		candidates = Directory.CreateBatch.new(count * 2)
		var requested: PackedInt32Array = PackedInt32Array()
		requested.resize(count * 2)
		for index: int in count:
			requested[index * 2] = Directory.KIND_FURNITURE
			requested[index * 2 + 1] = Directory.KIND_CONSTRUCTION
		var code: StringName = directory.peek_create_batch_into(requested, candidates)
		requested.clear()
		if code != &"":
			return code
		slots = candidates.slots.duplicate()
		generations = candidates.generations.duplicate()
		kinds = candidates.kinds.duplicate()
		typed_rows = candidates.typed_rows.duplicate()
		persistent_ids = candidates.persistent_ids.duplicate()
		return &""

	static func same_batch(first: Layout.Batch, second: Layout.Batch) -> bool:
		"""All player coordinates, purpose, level, pitch and observed revision are immutable during callbacks."""
		return first != null and second != null and first.room_ref == second.room_ref \
			and first.room_type == second.room_type and first.level == second.level \
			and first.pitch_units == second.pitch_units and first.expected_revision == second.expected_revision \
			and first.entries == second.entries

	func unchanged() -> bool:
		"""Private copies cover all five mutable tuple columns and both exposed request objects."""
		return same_batch(original, canonical) and same_batch(submitted, canonical) \
			and candidates != null and candidates.storage_refusal() == &"" and candidates.count == count * 2 \
			and candidates.slots == slots and candidates.generations == generations and candidates.kinds == kinds \
			and candidates.typed_rows == typed_rows and candidates.persistent_ids == persistent_ids

	func write_receipt() -> void:
		"""Pin every actual accepted Project before a final publication callback can discard observations."""
		for index: int in count:
			receipt.project_refs[index * 2] = candidates.slots[index * 2 + 1]
			receipt.project_refs[index * 2 + 1] = candidates.generations[index * 2 + 1]

	func drop_inputs() -> void:
		"""Drop all copied input/identity buffers before releasing the still-borrowed shared scope."""
		original = null
		canonical = null
		submitted = null
		candidates = null
		slots.clear()
		generations.clear()
		kinds.clear()
		typed_rows.clear()
		persistent_ids.clear()

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

	func phase_section_into(_site: Vector2i, _room: Vector2i, _cold_token: int,
			_out: SpaceOwner.Region) -> StringName:
		"""Observe the exact claimed section under the actual phase lease; metadata grants no usable floor."""
		return REFUSE_BINDING

	func finish_mask_into(_site: Vector2i, _room: Vector2i, _cold_token: int,
			_row_limit: int, _out: PackedInt32Array) -> StringName:
		"""Return disjoint six-int claim intersections; the physical authority still proves and publishes them."""
		return REFUSE_BINDING

	func exact_binding(_buildings: Buildings, _space: SpaceOwner, _construction: Construction,
			_world: Vector2i) -> bool:
		"""Prove actual World owners and the admitted joint live/cold budget; base grants nothing."""
		return false

	func layout_budget_owner() -> Budget:
		"""Return the same actual World arena used by every physical companion; base has no arena."""
		return null

	func begin_layout_cold(_room: Vector2i, _planner_bytes: int, _geometry_limit: int,
			_placement_limit: int, _batch_bytes: int) -> int:
		"""Admit the complete shared planner/provider/batch/bridge/native peak before any input copy."""
		return 0

	func layout_cold_refusal() -> StringName:
		"""An unbound provider has neither a real budget lease nor a valid empty snapshot."""
		return REFUSE_BINDING

	func layout_scope_refusal(_token: int, _room: Vector2i, _planner_bytes: int,
			_batch_bytes: int) -> StringName:
		"""Check the exact actual World's current token and entire retained peak without allocation."""
		return REFUSE_BINDING

	func layout_snapshot(_token: int, _room: Vector2i, _geometry_limit: int,
			_placement_limit: int) -> Layout.Snapshot:
		"""Return real completed floor, protected circulation, contacts/profiles and current accepted claims."""
		return null

	func layout_plan_refusal(_token: int, _request: Layout.Batch, _candidates: Directory.CreateBatch,
			_space_token: int) -> StringName:
		"""Stage only exact pending geometry and its companions under the already acquired common lease."""
		return REFUSE_BINDING

	func layout_prepared_refusal(_token: int, _request: Layout.Batch, _candidates: Directory.CreateBatch,
			_space_token: int) -> StringName:
		"""Revalidate the actual snapshot revision, profiles, contacts and sealed companions before allocation."""
		return REFUSE_BINDING

	func publish_layout(_token: int, _request: Layout.Batch, _candidates: Directory.CreateBatch,
			_space_token: int) -> void:
		"""Only already-prepared companions publish; this cannot release the original planner lease."""
		assert(false, "Unbound layout bindings cannot publish a companion")

	func discard_layout(_token: int, _room: Vector2i, _space_token: int) -> void:
		"""Drop only this unpublished companion, keeping the caller's original exact scope alive."""
		pass

	func end_layout_cold(_token: int, _room: Vector2i) -> StringName:
		"""Release only after planner views, provider images and all batch/bridge companions have dropped."""
		return REFUSE_BINDING

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
var _layout_token: int = 0
var _layout_planner_bytes: int = 0
var _layout_geometry_limit: int = 0
var _layout_placement_limit: int = 0
var _layout_bindings: Bindings = null
var _layout_budget: Budget = null
var _layout_snapshot: Layout.Snapshot = null
var _layout_batch: FurnitureBatch = null
var _layout_receipt: Layout.Submission = null
var _layout_error: StringName = &""
var _layout_callback: bool = false


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


static func layout_batch_cold_bytes(placement_limit: int) -> int:
	"""Additional simultaneous packet/bridge payload; actual providers separately admit native/growth/images."""
	if placement_limit < 1 or placement_limit > Layout.PLACEMENT_CAPACITY:
		return 0
	var bridge_bytes: int = SpaceOwner.furniture_admission_cold_bytes(placement_limit)
	return 120 * placement_limit + 76 + LAYOUT_BATCH_CONTROL_BYTES + bridge_bytes if bridge_bytes > 0 else 0


func layout_binding_refusal() -> StringName:
	"""Typed Sources can check exact local composition without calling a physical provider outside a guard."""
	return _identity_binding_refusal()


func begin_layout_operation(room: Vector2i, planner_bytes: int, geometry_limit: int,
		placement_limit: int) -> int:
	"""Take exclusivity before the first physical callback, then admit every synchronous cold lifetime."""
	if _stage_action != -1:
		_layout_error = REFUSE_TRANSITION
		return 0
	_stage_action = LAYOUT_OPERATION_STAGE
	_stage_room = room
	_layout_error = _layout_limits_refusal(planner_bytes, geometry_limit, placement_limit)
	if _layout_error == &"":
		_layout_bindings = _actual_bindings()
		if _layout_bindings == null:
			_layout_error = REFUSE_BINDING
	if _layout_error == &"":
		_layout_error = _acquire_layout_scope(room, planner_bytes, geometry_limit, placement_limit)
	if _layout_error != &"" or _layout_token <= 0:
		_clear_layout_scope()
		return 0
	_cold_held = true
	return _layout_token


func _acquire_layout_scope(room: Vector2i, planner_bytes: int, geometry_limit: int,
		placement_limit: int) -> StringName:
	"""Pin the actual arena before acquisition; a provider token cannot stand in for Budget ownership."""
	_layout_planner_bytes = planner_bytes
	_layout_geometry_limit = geometry_limit
	_layout_placement_limit = placement_limit
	_layout_budget = _layout_bindings.layout_budget_owner()
	if _layout_budget == null:
		return REFUSE_BINDING
	_layout_token = _layout_bindings.begin_layout_cold(room, planner_bytes, geometry_limit,
		placement_limit, layout_batch_cold_bytes(placement_limit))
	if _layout_token <= 0:
		return _layout_bindings.layout_cold_refusal()
	if _layout_budget != _layout_bindings.layout_budget_owner() or not _layout_budget_covers():
		_layout_bindings.end_layout_cold(_layout_token, room)
		return Layout.REFUSE_SCOPE
	return &""


func _layout_budget_covers() -> bool:
	"""Pure actual-token proof allows copying and sealed source callbacks without another provider invocation."""
	return _layout_budget != null and _layout_budget.covers(_layout_token,
		_layout_planner_bytes + layout_batch_cold_bytes(_layout_placement_limit))


func _layout_limits_refusal(planner_bytes: int, geometry_limit: int, placement_limit: int) -> StringName:
	"""Bound input arithmetic before callbacks/copies; retired Room handles remain valid for UI cleanup."""
	if _identity_binding_refusal() != &"":
		return REFUSE_BINDING
	if _stage_room.x < 0 or _stage_room.y <= 0 or geometry_limit < 1 \
			or geometry_limit > Layout.MAX_OPERATION_CELLS or layout_batch_cold_bytes(placement_limit) == 0:
		return Layout.REFUSE_SCOPE
	return &"" if planner_bytes == Layout.cold_packed_bytes(geometry_limit, placement_limit) else Layout.REFUSE_SCOPE


func layout_cold_refusal() -> StringName:
	"""Report the actual acquisition refusal instead of granting a dummy positive lease token."""
	return _layout_error if _layout_error != &"" else Layout.REFUSE_SCOPE


func layout_scope_refusal(token: int, room: Vector2i, planner_bytes: int) -> StringName:
	"""Check local exact scope first, then the original physical provider's actual same-World lease."""
	if _layout_callback or not _same_layout_scope(token, room) or planner_bytes != _layout_planner_bytes \
			or _identity_binding_refusal() != &"" or _bindings.get_ref() != _layout_bindings:
		return Layout.REFUSE_SCOPE
	_layout_callback = true
	var code: StringName = _layout_bindings.layout_scope_refusal(token, room, planner_bytes,
		layout_batch_cold_bytes(_layout_placement_limit))
	_layout_callback = false
	return code if code != &"" else (&"" if _layout_budget_covers() else Layout.REFUSE_SCOPE)


func _same_layout_scope(token: int, room: Vector2i) -> bool:
	"""Pure exact token/Room/stage comparison; no callback may borrow a foreign ongoing operation."""
	return _layout_scope_identity(token, room) and _layout_budget_covers()


func _layout_scope_identity(token: int, room: Vector2i) -> bool:
	"""Cleanup can discard its own scratch after lease refusal, without releasing a foreign token."""
	return token > 0 and token == _layout_token and room == _stage_room and _cold_held \
		and _layout_bindings != null \
		and (_stage_action == LAYOUT_OPERATION_STAGE or _stage_action == FURNITURE_BATCH_STAGE)


func layout_snapshot(room: Vector2i, token: int) -> Layout.Snapshot:
	"""Borrow one provider image inside the admitted scope; actual Room identity/type remain owner facts."""
	if _stage_action != LAYOUT_OPERATION_STAGE or layout_scope_refusal(token, room, _layout_planner_bytes) != &"" \
			or not _buildings.is_live_room(room):
		return null
	if _layout_snapshot != null:
		return _layout_snapshot
	_layout_callback = true
	var snapshot: Layout.Snapshot = _layout_bindings.layout_snapshot(token, room,
		_layout_geometry_limit, _layout_placement_limit)
	_layout_callback = false
	if layout_scope_refusal(token, room, _layout_planner_bytes) != &"" or snapshot == null:
		return null
	var kind: Buildings.OpResult = _buildings.spatial_kind_of_room(room)
	var type_id: Buildings.OpResult = _buildings.type_of_room(room)
	if kind.ok and kind.value == Buildings.ROOM_SPACE_UNDERGROUND and type_id.ok \
		and snapshot.room_ref == room and snapshot.room_type == type_id.value \
		and snapshot.allowed_types_mask == _catalog.allowed_types_mask(type_id.value):
		_layout_snapshot = snapshot
	return _layout_snapshot


func layout_identity_live(domain: int, ref: Vector2i, token: int) -> bool:
	"""Real full-generation owner readers replace caller booleans and same-number identities."""
	if layout_scope_refusal(token, _stage_room, _layout_planner_bytes) != &"":
		return false
	match domain:
		Layout.DOMAIN_ROOM:
			return _buildings.is_live_room(ref)
		Layout.DOMAIN_FURNITURE:
			return _buildings.is_live_furniture(ref)
		Layout.DOMAIN_PROJECT:
			return _construction.is_live_project(ref)
	return false


func can_submit_layout(token: int) -> bool:
	"""Only the actual once-bound Furniture purpose owner and original active scope can accept a batch."""
	if _stage_action != LAYOUT_OPERATION_STAGE or _layout_receipt != null \
			or layout_scope_refusal(token, _stage_room, _layout_planner_bytes) != &"":
		return false
	_layout_callback = true
	var owner: Contract.Owner = _actual_owner()
	_layout_callback = false
	return owner != null


func accept_layout(request: Layout.Batch, token: int) -> Layout.Submission:
	"""Prepare the whole exact furniture request under the existing input lease, then use one actual Router commit."""
	if _layout_callback or _stage_action != LAYOUT_OPERATION_STAGE or _layout_receipt != null \
			or not _same_layout_scope(token, _stage_room):
		return _layout_refused(REFUSE_TRANSITION)
	_stage_action = FURNITURE_BATCH_STAGE
	var code: StringName = _layout_request_shape_refusal(request)
	if code == &"":
		_layout_batch = FurnitureBatch.new()
		_layout_batch.copy_request(request)
		code = _layout_batch.observe(_construction.directory())
	if code == &"":
		code = _layout_request_refusal(token)
	if code == &"":
		code = _prepare_layout_geometry()
	if code == &"":
		code = _open_layout_pairs()
	if code != &"":
		_discard_layout_candidate()
		return _layout_refused(code)
	var receipt: Layout.Submission = _layout_receipt
	_drop_layout_inputs()
	return receipt


func _layout_request_shape_refusal(request: Layout.Batch) -> StringName:
	"""Check scalar bounds without callbacks before copying within the actual already-held Budget lease."""
	if request == null or request.room_ref != _stage_room or _identity_binding_refusal() != &"":
		return REFUSE_PLAN
	if request.entries.is_empty() or request.entries.size() % Layout.ENTRY_STRIDE != 0 \
			or request.entries.size() > _layout_placement_limit * Layout.ENTRY_STRIDE \
			or request.pitch_units < 1 or request.pitch_units > Layout.CATALOG_TILE_UNITS \
			or Layout.CATALOG_TILE_UNITS % request.pitch_units != 0 or request.level < 0 \
			or request.level > RoomSpace.I32_MAX or request.expected_revision < 0:
		return REFUSE_PLAN
	return &""


func _layout_request_refusal(token: int) -> StringName:
	"""All inputs are pinned before provider callbacks; functional service validity is not shell completion."""
	var code: StringName = layout_scope_refusal(token, _stage_room, _layout_planner_bytes)
	if code != &"":
		return code
	var request: Layout.Batch = _layout_batch.canonical
	var kind: Buildings.OpResult = _buildings.spatial_kind_of_room(request.room_ref)
	var type_id: Buildings.OpResult = _buildings.type_of_room(request.room_ref)
	if not kind.ok or kind.value != Buildings.ROOM_SPACE_UNDERGROUND \
			or not type_id.ok or request.room_type != type_id.value or _actual_owner() == null:
		return REFUSE_FURNITURE
	for offset: int in range(0, request.entries.size(), Layout.ENTRY_STRIDE):
		code = _catalog.compatibility_error(type_id.value, request.entries[offset])
		if code != &"" or request.entries[offset + 3] < 0 or request.entries[offset + 3] >= 4:
			return code if code != &"" else REFUSE_PLAN
	code = layout_scope_refusal(token, _stage_room, _layout_planner_bytes)
	return code if code != &"" else (&"" if _layout_batch.unchanged() else REFUSE_PLAN)


func _prepare_layout_geometry() -> StringName:
	"""Stage exact future Furniture sources and mandatory physical companions before the paired allocation."""
	if not _layout_batch.unchanged():
		return REFUSE_PLAN
	var begun: SpaceOwner.Result = _space.begin_stage(_space.revision())
	if begun.error != &"":
		return begun.error
	_stage_token = begun.token
	var code: StringName = _space.stage_furniture_admissions(_stage_token, _layout_batch.candidates,
		_stage_room, _layout_batch.submitted.entries, self)
	if code == &"":
		_layout_callback = true
		code = _layout_bindings.layout_plan_refusal(_layout_token, _layout_batch.submitted,
			_layout_batch.candidates, _stage_token)
		_layout_callback = false
	if code == &"" and not _layout_batch.unchanged():
		code = REFUSE_PLAN
	if code == &"":
		code = _space.seal(_stage_token)
	return code


func _open_layout_pairs() -> StringName:
	"""The actual Router alone spends the observed free identities and invokes prepared owner publication."""
	var owner: Contract.Owner = _actual_owner()
	var router: Router = _actual_router() as Router
	if owner == null or router == null:
		return REFUSE_BINDING
	var result: Construction.OpResult = router.open_furniture_batch(owner, _stage_room,
		_layout_batch.candidates, _layout_batch.submitted.entries)
	return &"" if result.ok else result.error


func furniture_candidates_refusal(room: Vector2i, candidates: Directory.CreateBatch,
		entries: PackedInt32Array) -> StringName:
	"""Pure retained-packet proof for Buildings/Space callbacks; never recurse into physical prepared validation."""
	return &"" if _identity_binding_refusal() == &"" and _stage_action == FURNITURE_BATCH_STAGE \
		and _same_layout_scope(_layout_token, room) and _layout_batch != null \
		and candidates != null and candidates == _layout_batch.candidates \
		and candidates.directory_owner() == _construction.directory() and _layout_batch.unchanged() \
		and entries == _layout_batch.canonical.entries else REFUSE_PLAN


func furniture_batch_refusal(room: Vector2i, candidates: Directory.CreateBatch,
		entries: PackedInt32Array) -> StringName:
	"""Finish all fallible proof before Directory commits; the last callback can never alter pinned input unnoticed."""
	if _layout_callback:
		return REFUSE_TRANSITION
	var code: StringName = furniture_candidates_refusal(room, candidates, entries)
	if code == &"":
		_layout_callback = true
		code = _layout_bindings.layout_prepared_refusal(_layout_token, _layout_batch.submitted,
			candidates, _stage_token)
		_layout_callback = false
	if code == &"":
		code = layout_scope_refusal(_layout_token, room, _layout_planner_bytes)
	if code == &"":
		code = _space.prepared_refusal(_stage_token)
	return furniture_candidates_refusal(room, candidates, entries) if code == &"" else code


func is_publishing_furniture_admissions(room: Vector2i, candidates: Directory.CreateBatch) -> bool:
	"""No physical provider callback occurs after identities commit; compare the real Router's exact same-stack permit."""
	if _layout_batch == null or _layout_batch.submitted == null \
			or furniture_candidates_refusal(room, candidates, _layout_batch.submitted.entries) != &"":
		return false
	var owner: Contract.Owner = _furniture_owner.get_ref() as Contract.Owner if _furniture_owner != null else null
	return _actual_router().is_publishing_furniture_admissions(room, candidates, owner)


func publish_furniture_batch(room: Vector2i, candidates: Directory.CreateBatch,
		entries: PackedInt32Array) -> void:
	"""Pin the complete preallocated receipt before sealed geometry/companion publication and cleanup."""
	if not is_publishing_furniture_admissions(room, candidates) \
			or entries != _layout_batch.canonical.entries:
		return
	_publishing = true
	_layout_batch.write_receipt()
	var code: StringName = _space.publish_furniture_admissions(_stage_token, candidates, room, entries, self)
	assert(code == &"", "preflighted actual pending Furniture geometry must publish after paired identities")
	_layout_bindings.publish_layout(_layout_token, _layout_batch.submitted, candidates, _stage_token)
	_layout_batch.receipt.ok = true
	_layout_batch.receipt.error = &""
	_layout_receipt = _layout_batch.receipt
	_publishing = false


func _discard_layout_candidate() -> void:
	"""Drop prepared physical companions and Space scratch before any private copied batch is discarded."""
	if _stage_action != FURNITURE_BATCH_STAGE:
		return
	if _layout_bindings != null:
		_layout_bindings.discard_layout(_layout_token, _stage_room, _stage_token)
	if _stage_token > 0:
		_space.abort(_stage_token)
	_drop_layout_inputs()


func _drop_layout_inputs() -> void:
	"""Retain only the receipt until the planner consumes it; all other packet buffers end in this call."""
	if _layout_batch != null:
		_layout_batch.drop_inputs()
	_layout_batch = null
	_stage_token = 0
	_stage_action = LAYOUT_OPERATION_STAGE


func _layout_refused(code: StringName) -> Layout.Submission:
	"""An ordinary refused submission leaves every world owner unchanged and grants no project receipt."""
	var result: Layout.Submission = Layout.Submission.new()
	result.error = code
	return result


func has_layout_scope() -> bool:
	"""A typed Sources adapter retains its actual coordinator until the original scope has ended."""
	return _layout_token > 0


func end_layout_operation(token: int, room: Vector2i) -> StringName:
	"""Clear accepted receipt/provider scratch before releasing the exact original shared lease."""
	if _layout_callback or not _layout_scope_identity(token, room) or _stage_action != LAYOUT_OPERATION_STAGE:
		return Layout.REFUSE_SCOPE
	if _layout_receipt != null:
		_layout_receipt.project_refs.clear()
	_layout_receipt = null
	_layout_snapshot = null
	_layout_callback = true
	var code: StringName = _layout_bindings.end_layout_cold(token, room)
	_layout_callback = false
	if code == &"":
		_clear_layout_scope()
	return code


func _clear_layout_scope() -> void:
	"""Clear only transient numerical/reference wiring, never accepted Furniture/project state."""
	_layout_token = 0
	_layout_planner_bytes = 0
	_layout_geometry_limit = 0
	_layout_placement_limit = 0
	_layout_bindings = null
	_layout_budget = null
	_clear_stage()


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
	var section: SpaceOwner.Result = _stage_room_section(descriptor.bounds_u)
	return section.error if section.error != &"" else _stage_room_runs(descriptor.bounds_u, section.handle)


func _stage_room_section(bounds: PackedInt32Array) -> SpaceOwner.Result:
	"""One metadata envelope identifies this authored section; it grants no occupied or usable floor."""
	var box: PackedInt32Array = _room_section_box()
	if not RoomSpace.contains_box(bounds, box):
		return SpaceOwner.Result.new(REFUSE_PLAN)
	var region: SpaceOwner.Region = SpaceOwner.Region.new()
	region.owner = _stage_room
	region.level = _room_plan.level
	region.role = RoomSpace.FLOOR_DATUM
	region.box = box
	region.box[4] = region.box[1] + 1
	return _space.stage_add(_stage_token, region)


func _room_section_box() -> PackedInt32Array:
	"""Canonical row ordering gives Z endpoints; scan only X extrema without copying or filling holes."""
	var left: int = _room_plan.cells[0]
	var right: int = left
	for index: int in range(2, _room_plan.cells.size(), 2):
		left = mini(left, _room_plan.cells[index])
		right = maxi(right, _room_plan.cells[index])
	return _room_cell_box(left, _room_plan.cells[1], right + 1, _room_plan.cells[-1] + 1)


func _stage_room_runs(bounds: PackedInt32Array, section: Vector2i) -> StringName:
	"""Claim contiguous canonical X runs; absent cells remain absent even inside the outer bounds."""
	var start: int = 0
	while start < _room_plan.cells.size():
		var end: int = start + 2
		while end < _room_plan.cells.size() and _room_plan.cells[end + 1] == _room_plan.cells[start + 1] \
				and _room_plan.cells[end] == _room_plan.cells[end - 2] + 1:
			end += 2
		var code: StringName = _stage_room_run(start, end, bounds, section)
		if code != &"":
			return code
		start = end
	return &""


func _room_cell_box(left: int, near: int, right: int, far: int) -> PackedInt32Array:
	"""Use int64 transforms and refuse int32 overflow before packing; never round a painted edge."""
	var low_x: int = int(_room_plan.origin_u.x) + left * _room_plan.cell_size_u
	var low_z: int = int(_room_plan.origin_u.z) + near * _room_plan.cell_size_u
	var high_x: int = int(_room_plan.origin_u.x) + right * _room_plan.cell_size_u
	var high_z: int = int(_room_plan.origin_u.z) + far * _room_plan.cell_size_u
	if not RoomSpace.int32(low_x) or not RoomSpace.int32(low_z) \
			or not RoomSpace.int32(high_x) or not RoomSpace.int32(high_z):
		return PackedInt32Array()
	return PackedInt32Array([low_x, _room_plan.origin_u.y, low_z, high_x,
		int(_room_plan.origin_u.y) + _room_plan.height_u, high_z])


func _stage_room_run(start: int, end: int, bounds: PackedInt32Array, section: Vector2i) -> StringName:
	"""Link each exact blocking Room claim to shared metadata without inflating its physical footprint."""
	var box: PackedInt32Array = _room_cell_box(_room_plan.cells[start], _room_plan.cells[start + 1],
		_room_plan.cells[end - 2] + 1, _room_plan.cells[start + 1] + 1)
	if not RoomSpace.contains_box(bounds, box):
		return REFUSE_PLAN
	var region: SpaceOwner.Region = SpaceOwner.Region.new()
	region.owner = _stage_room
	region.level = _room_plan.level
	region.role = RoomSpace.OBSTACLE
	region.box = box
	region.section = section
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
	if _stage_action >= ROOM_ADMISSION_STAGE or project != _stage_project or action != _stage_action or _publishing:
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
