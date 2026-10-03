extends "res://scripts/core/modular_project_contract.gd".Owner
## Actual pending Furniture purpose owner. Shared Funding, Jobs, Work and Gear own paid progress.
## It borrows the sole RoomOrders authority; no per-furniture receipt, quote or geometry is created.

const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const RoomOrders := preload("res://scripts/core/underground_room_orders.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_BINDING: StringName = &"UNDERGROUND_FURNITURE_OWNER_UNBOUND"
const REFUSE_ORDER: StringName = &"UNDERGROUND_FURNITURE_ORDER_NOT_PREPARED"

var _construction: Construction = null
var _router: WeakRef = null
var _rooms: WeakRef = null
var _world: Vector2i = NULL_REF
var _ready_error: StringName = REFUSE_BINDING
var _pending_furniture: Vector2i = NULL_REF
var _pending_type: int = -1
var _math: IntMath.IntResult = IntMath.IntResult.new()


func configure(router: Router, rooms: RoomOrders) -> StringName:
	"""Preflight both once-bound links so a refused composition cannot strand either actual owner."""
	if _construction != null or router == null or rooms == null or rooms.binding_refusal() != &"" \
			or router.construction_owner() != rooms.construction_owner() or router.world_ref() != rooms.world_ref():
		return REFUSE_BINDING
	_construction = rooms.construction_owner()
	_router = weakref(router)
	_rooms = weakref(rooms)
	_world = rooms.world_ref()
	var code: StringName = router.owner_binding_refusal(self)
	if code == &"":
		code = rooms.furniture_owner_binding_refusal(self)
	if code != &"":
		_clear_wiring()
		return code
	var bound: StringName = rooms.bind_furniture_owner(self)
	assert(bound == &"", "preflighted exact Room purpose binding")
	var result: Construction.OpResult = router.bind_owner(self)
	assert(result.ok, "preflighted exact Router purpose binding")
	_ready_error = &""
	return &""


func _clear_wiring() -> void:
	"""Drop only unpublished setup links on refusal; no authoritative store was changed."""
	_construction = null
	_router = null
	_rooms = null
	_world = NULL_REF


func construction_owner() -> RefCounted:
	"""The Router compares the actual accounting owner during exact composition preflight."""
	return _construction


func world_ref() -> Vector2i:
	"""Furniture and Room identities belong to this actual Directory's immutable World generation."""
	return _world


func purpose() -> int:
	"""Actual Furniture uses the existing separate purpose, never a physical excavation operation."""
	return Construction.PURPOSE_SPATIAL_FURNITURE


func _actual_rooms() -> RoomOrders:
	"""Resolve weak ownership without preserving an expired replacement coordinator."""
	return _rooms.get_ref() as RoomOrders if _rooms != null else null


func _actual_router() -> Contract:
	"""A live reference alone is insufficient after actual accounting-owner rewiring."""
	var target: Contract = _router.get_ref() as Contract if _router != null else null
	return target if target != null and _construction != null \
		and _construction.modular_authority() == target else null


func binding_refusal() -> StringName:
	"""Exact current Room/Router composition is checked without hot Quote or Buildings result allocation."""
	var rooms: RoomOrders = _actual_rooms()
	return &"" if _ready_error == &"" and rooms != null and _actual_router() != null \
		and rooms.is_bound_furniture_owner(self) else REFUSE_BINDING


func prepare_installation(furniture: Vector2i) -> StringName:
	"""Prepare one actual compatible pending subject; no caller specifies work, recipe or completion."""
	if binding_refusal() != &"":
		return REFUSE_BINDING
	discard_transition(NULL_REF, Contract.ADMIT)
	var code: StringName = _actual_rooms().furniture_admission_refusal(furniture)
	if code != &"":
		return code
	var type_id: Buildings.OpResult = _construction.buildings().type_id_of_furniture(furniture)
	if not type_id.ok:
		return type_id.error
	_pending_furniture = furniture
	_pending_type = type_id.value
	return &""


func prepared_subject() -> Vector2i:
	"""Read the full existing subject for Router.open_order; an absent pending selection stays null."""
	return _pending_furniture if binding_refusal() == &"" else NULL_REF


func prepared_operation() -> int:
	"""The actual protected FurnitureDefinition is the operation; no display alias adds a price."""
	return _pending_type if binding_refusal() == &"" else -1


func prepared_order_into(subject: Vector2i, operation: int, out: Contract.Quote) -> StringName:
	"""Read the real catalog bill and stage qualified existing geometry before Construction allocation."""
	if binding_refusal() != &"" or subject != _pending_furniture or operation != _pending_type:
		return REFUSE_ORDER
	var code: StringName = _actual_rooms().prepare_admission(subject, operation)
	return _fill_quote(subject, operation, out) if code == &"" else code


func project_facts_into(project: Vector2i, out: Contract.Quote) -> StringName:
	"""Read actual pending identity, immutable catalog price and Construction-owned remaining labor."""
	var code: StringName = _project_refusal(project)
	if code != &"":
		return code
	_construction.type_id_into(project, _math)
	code = _fill_quote(_construction.subject_ref_of(project), _math.value, out)
	if code != &"":
		return code
	if not _construction.remaining_mwu_into(project, _math):
		return Contract.REFUSE_QUOTE
	out.remaining_mwu = _math.value
	return out.refusal()


func _fill_quote(furniture: Vector2i, type_id: int, out: Contract.Quote) -> StringName:
	"""Copy the protected current catalog into caller-owned scratch, never keep a per-project Quote."""
	if out == null or not _construction.declared_work_mwu_into(purpose(), type_id, _math):
		return Contract.REFUSE_QUOTE
	out.reset()
	out.subject = furniture
	out.operation = type_id
	out.total_mwu = _math.value
	out.remaining_mwu = _math.value
	out.job_kind = int(Catalog.JOB_KIND["BUILD"])
	out.max_workers = Construction.MAX_BUILDERS
	if not _construction.bill_size_into(purpose(), type_id, _math):
		return Contract.REFUSE_QUOTE
	out.input_count = _math.value
	if out.input_count > Contract.INPUT_CAPACITY:
		return Contract.REFUSE_QUOTE
	for line: int in out.input_count:
		out.input_keys[line] = _construction.material_key_at(purpose(), type_id, line)
		if not _construction.required_milli_into(purpose(), type_id, line, _math):
			return Contract.REFUSE_QUOTE
		out.input_milli[line] = _math.value
	return out.refusal()


func _project_refusal(project: Vector2i) -> StringName:
	"""Productive proof avoids cold source scans, copied bills and allocating Buildings readers."""
	return _actual_rooms().project_refusal(project) if binding_refusal() == &"" else REFUSE_BINDING


func transition_refusal(project: Vector2i, action: int) -> StringName:
	"""The Room owner prepares real source/service changes before actual accounting commits."""
	return _actual_rooms().transition_refusal(project, action) if binding_refusal() == &"" else REFUSE_BINDING


func material_refusal(project: Vector2i, container: Vector2i, job: Vector2i) -> StringName:
	"""Keep actual delivered materials and refunds at the accepted operation's supported contact."""
	return _actual_rooms().material_refusal(project, container, job) if binding_refusal() == &"" else REFUSE_BINDING


func output_refusal(_project: Vector2i, _container: Vector2i, _job: Vector2i,
		_promotion_tile: int) -> StringName:
	"""Installation has no physical output bill; refunds use the real material-contact reader."""
	return Contract.REFUSE_QUOTE


func worker_refusal(project: Vector2i, job: Vector2i, worker: Vector2i) -> StringName:
	"""Actual worker/contact identity supplements the shared mandatory Job/Gear paid-work checks."""
	return _actual_rooms().worker_refusal(project, job, worker) if binding_refusal() == &"" else REFUSE_BINDING


func discard_transition(project: Vector2i, action: int) -> void:
	"""Only the exact stage is discarded; accepted identity and progress remain in their owners."""
	var rooms: RoomOrders = _actual_rooms()
	if rooms != null:
		rooms.discard_transition(project, action)
	if project == NULL_REF and action == Contract.ADMIT:
		_pending_furniture = NULL_REF
		_pending_type = -1


func publish_open(project: Vector2i) -> void:
	"""Accept the actual project only during the shared router's exact ADMIT call stack."""
	if not _publication_allowed(project, Contract.ADMIT) \
			or _construction.subject_ref_of(project) != _pending_furniture:
		return
	_actual_rooms().publish_transition(project, Contract.ADMIT)
	_pending_furniture = NULL_REF
	_pending_type = -1


func publish_work(project: Vector2i) -> void:
	"""Construction already holds accepted work; only the exact prepared contact companion publishes."""
	if _publication_allowed(project, Contract.PRODUCTIVE):
		_actual_rooms().publish_transition(project, Contract.PRODUCTIVE)


func publish_completion(project: Vector2i) -> void:
	"""The actual shared receipt commit precedes installed presence and sealed geometry publication."""
	if _publication_allowed(project, Contract.COMMIT):
		_actual_rooms().publish_transition(project, Contract.COMMIT)


func publish_cancellation(project: Vector2i) -> void:
	"""Actual material settlement precedes release of only the canceled pending Furniture identity."""
	if _publication_allowed(project, Contract.CANCEL):
		_actual_rooms().publish_transition(project, Contract.CANCEL)


func _publication_allowed(project: Vector2i, action: int) -> bool:
	"""Direct, foreign and expired callbacks cannot manufacture any paid physical publication."""
	return binding_refusal() == &"" and _actual_router().is_publishing(project, action, self)


func embedded_earth_milli() -> int:
	"""Furniture owns no embedded earth stock; invalid composition remains explicitly unavailable."""
	return 0 if binding_refusal() == &"" else -1
