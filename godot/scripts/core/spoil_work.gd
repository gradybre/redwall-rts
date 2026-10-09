extends "res://scripts/core/modular_project_contract.gd".Owner
## Actual tip-operation owner for the single shared modular accounting router.
## Physical siting/contacts are mandatory typed bindings, never UI permission or caller prices.

const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const Tips := preload("res://scripts/core/spoil_tips.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_BINDING: StringName = &"SPOIL_WORK_OWNER_UNBOUND"
const REFUSE_ORDER: StringName = &"SPOIL_ORDER_NOT_PREPARED"
const REFUSE_TRANSITION: StringName = &"SPOIL_TRANSITION_NOT_PREPARED"

class Contacts extends RefCounted:
	## Implemented by the actual World/terrain/movement composition; base denies all permission.
	func exact_binding(_tips: Tips, _construction: Construction, _world: Vector2i) -> bool:
		"""Prove actual live owners rather than coincident numbers in a different World."""
		return false

	func admission_refusal(_tip: Vector2i, _tile: int, _operation: int, _quantity: int) -> StringName:
		"""Stage dry exterior footprint/contact/route ownership before Construction allocation."""
		return REFUSE_BINDING

	func transition_refusal(_tip: Vector2i, _tile: int, _project: Vector2i,
			_operation: int, _action: int) -> StringName:
		"""Prepare all fallible geometry before START, productive work, cancellation or source commit."""
		return REFUSE_BINDING

	func material_refusal(_tip: Vector2i, _project: Vector2i, _container: Vector2i,
			_job: Vector2i) -> StringName:
		"""Prove the real adjacent delivered-input contact and its approved route."""
		return REFUSE_BINDING

	func output_refusal(_tip: Vector2i, _project: Vector2i, _container: Vector2i,
			_job: Vector2i, _promotion_tile: int) -> StringName:
		"""Prove the actual adjacent output and any first ground-pile publication lease."""
		return REFUSE_BINDING

	func worker_refusal(_tip: Vector2i, _project: Vector2i, _job: Vector2i,
			_worker: Vector2i) -> StringName:
		"""Check the real worker, current load/posture, occupancy and operation contact."""
		return REFUSE_BINDING

	func discard_transition(_tip: Vector2i, _tile: int, _project: Vector2i,
			_operation: int, _action: int) -> void:
		"""Discard only staged proof; accepted footprint and physical source remain owned."""
		assert(false, "Unbound spoil contacts cannot own transition scratch")

	func publish_transition(_tip: Vector2i, _tile: int, _project: Vector2i,
			_operation: int, _action: int) -> void:
		"""Publish prepared geometry synchronously after payment, using captured pre-retirement facts."""
		assert(false, "Unbound spoil contacts cannot publish physical space")

class Publication extends Tips.Publisher:
	## One component bridge; weak owner/router links prevent a reference cycle.
	var owner: WeakRef = null
	var router: WeakRef = null
	var tips: Tips = null
	var construction: Construction = null
	var pending: bool = false
	var subject: Vector2i = NULL_REF
	var tile: int = -1
	var operation: int = -1
	var quantity: int = 0
	var math: IntMath.IntResult = IntMath.IntResult.new()

	func actual_owner() -> Contract.Owner:
		"""Resolve the live exact purpose owner without holding it strongly."""
		return owner.get_ref() as Contract.Owner if owner != null else null

	func actual_router() -> Contract:
		"""Resolve only the router still bound to the actual Construction object."""
		var target: Contract = router.get_ref() as Contract if router != null else null
		return target if construction != null and construction.modular_authority() == target else null

	func exact_binding(candidate: RefCounted, world: Vector2i, actual: Construction) -> bool:
		"""Allow composition preflight before the actual router publishes its purpose binding."""
		var target: Contract.Owner = actual_owner()
		return target != null and candidate == tips and actual == construction \
			and target.construction_owner() == actual and target.world_ref() == world \
			and actual_router() != null

	func project_refusal(tip: Vector2i, project: Vector2i, op: int, q: int) -> StringName:
		"""Use actual immutable accounting and ledger facts; never recurse through a project bill."""
		var route: Contract = actual_router()
		var target: Contract.Owner = actual_owner()
		if route == null or target == null or not route.is_bound_owner(target):
			return REFUSE_BINDING
		if not construction.purpose_into(project, math) or math.value != Construction.PURPOSE_SPOIL_TIP:
			return REFUSE_ORDER
		if construction.subject_ref_of(project) != tip \
				or not construction.type_id_into(project, math) or math.value != op:
			return REFUSE_ORDER
		if pending and subject == tip and operation == op and quantity == q \
				and route.is_publishing(project, Contract.ADMIT, target):
			return &""
		return &"" if tips.is_live_tip(tip) and tips.project_of(tip) == project \
			and tips.operation_of(tip) == op and tips.quantity_milli(tip) == q else REFUSE_ORDER

	func publication_refusal(tip: Vector2i, project: Vector2i, op: int, q: int,
			action: int) -> StringName:
		"""The exact actual router window, full project and purpose owner must all agree."""
		var code: StringName = project_refusal(tip, project, op, q)
		if code != &"":
			return code
		return &"" if actual_router().is_publishing(project, action, actual_owner()) else REFUSE_TRANSITION

	func clear_pending() -> void:
		"""Erase only cold unaccepted order scratch; physical history stays in Tips."""
		pending = false
		subject = NULL_REF
		tile = -1
		operation = -1
		quantity = 0

var _tips: Tips = null
var _construction: Construction = null
var _items: Items = null
var _router: WeakRef = null
var _contacts: WeakRef = null
var _publication: Publication = null
var _ready_error: StringName = REFUSE_BINDING
var _stage_project: Vector2i = NULL_REF
var _stage_tip: Vector2i = NULL_REF
var _stage_tile: int = -1
var _stage_operation: int = -1
var _stage_action: int = -1


func configure(tips: Tips, router: Router, contacts: Contacts) -> StringName:
	"""Preflight both once-bound owners before publishing either composition link."""
	if _tips != null or tips == null or router == null or contacts == null:
		return REFUSE_BINDING
	var construction: Construction = tips.construction_owner()
	if tips.initialization_refusal() != &"" or construction == null \
			or router.construction_owner() != construction or router.world_ref() != tips.world_ref() \
			or construction.modular_authority() != router \
			or router.item_definitions_owner() == null \
			or not contacts.exact_binding(tips, construction, tips.world_ref()):
		return REFUSE_BINDING
	_set_wiring(tips, router, contacts)
	var code: StringName = router.owner_binding_refusal(self)
	if code == &"":
		code = tips.publisher_binding_refusal(_publication)
	if code != &"":
		_clear_wiring()
		return code
	var published: StringName = tips.bind_publisher(_publication)
	assert(published == &"", "preflighted exact tip publisher")
	if published != &"":
		_clear_wiring()
		return published
	var bound: Construction.OpResult = router.bind_owner(self)
	assert(bound.ok, "preflighted exact purpose owner")
	if not bound.ok:
		return bound.error
	_ready_error = &""
	return &""


func _set_wiring(tips: Tips, router: Router, contacts: Contacts) -> void:
	"""Prepare component references only; no authoritative store is changed."""
	_tips = tips
	_construction = tips.construction_owner()
	_items = router.item_definitions_owner()
	_router = weakref(router)
	_contacts = weakref(contacts)
	_publication = Publication.new()
	_publication.owner = weakref(self)
	_publication.router = _router
	_publication.tips = tips
	_publication.construction = _construction


func _clear_wiring() -> void:
	"""Rollback unpublished component setup after preflight refusal."""
	_publication = null
	_tips = null
	_construction = null
	_items = null
	_router = null
	_contacts = null


func _actual_contacts() -> Contacts:
	"""Expired, foreign or invalidated physical composition cannot grant permission."""
	var target: Contacts = _contacts.get_ref() as Contacts if _contacts != null else null
	return target if target != null and target.exact_binding(_tips, _construction, world_ref()) else null


func _binding_refusal() -> StringName:
	"""Every external operation checks the actual live World/router/contact composition."""
	if _ready_error != &"" or _publication == null or _items == null or _actual_contacts() == null:
		return REFUSE_BINDING
	var route: Contract = _publication.actual_router()
	return &"" if route != null and route.is_bound_owner(self) \
		and route.item_definitions_owner() == _items else REFUSE_BINDING


func construction_owner() -> RefCounted:
	"""Return the real accounting object for typed composition, never a surrogate Building."""
	return _construction


func world_ref() -> Vector2i:
	"""The local tip namespace belongs to this exact immutable World generation."""
	return _tips.world_ref() if _tips != null else NULL_REF


func purpose() -> int:
	"""Tip operation IDs never share the physical excavation-purpose namespace."""
	return Construction.PURPOSE_SPOIL_TIP


func prepare_tip_order(tile: int) -> StringName:
	"""Stage a candidate exterior tile; the router performs the actual atomic admission."""
	var code: StringName = _binding_refusal()
	if code != &"":
		return code
	_discard_admission()
	code = _tips.candidate_prepare_refusal(tile)
	if code == &"":
		_set_pending(_tips.candidate_tip_ref(), tile, Tips.PREPARE, 0)
	return code


func prepare_operation(tip: Vector2i, operation: int, quantity: int = 0) -> StringName:
	"""Stage only a physically legal exact-q order; no progress, inventory or claim changes."""
	var code: StringName = _binding_refusal()
	if code != &"":
		return code
	_discard_admission()
	code = _tips.candidate_order_refusal(tip, operation, quantity)
	if code == &"":
		_set_pending(tip, _tips.tile_of(tip), operation, quantity)
	return code


func _set_pending(tip: Vector2i, tile: int, operation: int, quantity: int) -> void:
	"""Retain one synchronous caller request, with no per-project quote or receipt allocation."""
	_publication.pending = true
	_publication.subject = tip
	_publication.tile = tile
	_publication.operation = operation
	_publication.quantity = quantity


func prepared_subject() -> Vector2i:
	"""Read the staged exact local handle for Router.open_order; absent remains explicitly null."""
	return _publication.subject if _publication != null and _publication.pending else NULL_REF


func prepared_order_into(subject: Vector2i, operation: int, out: Contract.Quote) -> StringName:
	"""Revalidate physical/source facts and stage geometry before allocating the real project."""
	var code: StringName = _binding_refusal()
	if code != &"":
		return code
	if not _publication.pending or subject != _publication.subject or operation != _publication.operation:
		return REFUSE_ORDER
	if _tips.is_live_tip(subject):
		code = _tips.candidate_order_refusal(subject, operation, _publication.quantity)
	elif operation == Tips.PREPARE and subject == _tips.candidate_tip_ref():
		code = _tips.candidate_prepare_refusal(_publication.tile)
	else:
		code = REFUSE_ORDER
	if code == &"":
		code = _fill_quote(subject, operation, _publication.quantity, out)
	if code == &"":
		code = _actual_contacts().admission_refusal(subject, _publication.tile, operation, _publication.quantity)
	return code


func project_facts_into(project: Vector2i, out: Contract.Quote) -> StringName:
	"""Read immutable active operation/q and actual retained work without another project table."""
	var code: StringName = _project_refusal(project)
	if code != &"":
		return code
	var tip: Vector2i = _construction.subject_ref_of(project)
	return _fill_quote(tip, _tips.operation_of(tip), _tips.quantity_milli(tip), out)


func _fill_quote(tip: Vector2i, operation: int, quantity: int, out: Contract.Quote) -> StringName:
	"""Use only the adopted Work rational prices and actual compiled earth item definition."""
	if out == null:
		return Contract.REFUSE_QUOTE
	out.reset()
	var total: int = Tips.total_work_mwu(operation, quantity)
	var retained: int = _tips.retained_work_mwu(tip, operation, quantity) if _tips.is_live_tip(tip) else 0
	if total <= 0 or retained < 0 or retained > total:
		return Contract.REFUSE_QUOTE
	out.subject = tip
	out.operation = operation
	out.quantity_milli = quantity
	out.total_mwu = total
	out.remaining_mwu = total - retained
	out.job_kind = int(Catalog.JOB_KIND["KEEP" if operation == Tips.COMPACT else "BUILD"])
	out.max_workers = Construction.MAX_BUILDERS
	if operation == Tips.COMPACT:
		out.input_count = 1
		out.input_keys[0] = Catalog.EXCAVATED_EARTH_ITEM_KEY
		out.input_milli[0] = quantity
	elif operation == Tips.RECLAIM:
		_fill_reclaim_output(quantity, out)
	return out.refusal()


func _fill_reclaim_output(quantity: int, out: Contract.Quote) -> void:
	"""Normalize only the adopted earth source output; no generic metadata laundering path."""
	out.output_count = 1
	out.output_item[0] = _items.compiled_id(Catalog.EXCAVATED_EARTH_ITEM_KEY)
	out.output_milli[0] = quantity
	out.output_quality[0] = int(Catalog.QUALITY["PLAIN"])
	out.output_provenance[0] = Catalog.PROVENANCE_SPOIL_RECLAIM
	out.output_recipe[0] = -1
	out.output_age[0] = 0
	out.output_remainder[0] = 0


func _project_refusal(project: Vector2i) -> StringName:
	"""No stale project, subject, World or purpose can address a live tip by numeric coincidence."""
	var code: StringName = _binding_refusal()
	if code != &"":
		return code
	var tip: Vector2i = _construction.subject_ref_of(project)
	if not _tips.is_live_tip(tip):
		return REFUSE_ORDER
	return _publication.project_refusal(tip, project, _tips.operation_of(tip), _tips.quantity_milli(tip))


func transition_refusal(project: Vector2i, action: int) -> StringName:
	"""Stage physical proof before irreversible work or Inventory; START changes no tip ledger."""
	var code: StringName = _project_refusal(project)
	if code != &"":
		return code
	if _stage_action != -1:
		return REFUSE_TRANSITION
	var tip: Vector2i = _construction.subject_ref_of(project)
	if action == Contract.COMMIT:
		code = _tips.completion_refusal(tip, project)
	elif action == Contract.CANCEL:
		code = _tips.cancellation_refusal(tip, project)
	elif action == Contract.PRODUCTIVE:
		code = _tips.work_refusal(tip, project)
	elif action != Contract.START:
		return REFUSE_TRANSITION
	if code != &"":
		return code
	_set_stage(project, tip, action)
	return _actual_contacts().transition_refusal(tip, _stage_tile, project, _stage_operation, action)


func _set_stage(project: Vector2i, tip: Vector2i, action: int) -> void:
	"""Keep the exact proposed proof identity so even a refused contact stage can be discarded."""
	_stage_project = project
	_stage_tip = tip
	_stage_tile = _tips.tile_of(tip)
	_stage_operation = _tips.operation_of(tip)
	_stage_action = action


func material_refusal(project: Vector2i, container: Vector2i, job: Vector2i) -> StringName:
	"""Funding's actual input reservation must reach this exact physical operation."""
	var code: StringName = _project_refusal(project)
	return _actual_contacts().material_refusal(_construction.subject_ref_of(project), project, container, job) \
		if code == &"" else code


func output_refusal(project: Vector2i, container: Vector2i, job: Vector2i,
		promotion_tile: int) -> StringName:
	"""Reclamation may publish only into actual adjacent reserved output capacity."""
	var code: StringName = _project_refusal(project)
	return _actual_contacts().output_refusal(_construction.subject_ref_of(project), project, container, job, promotion_tile) \
		if code == &"" else code


func worker_refusal(project: Vector2i, job: Vector2i, worker: Vector2i) -> StringName:
	"""A productive worker needs its real current load/posture and operation contact."""
	var code: StringName = _project_refusal(project)
	return _actual_contacts().worker_refusal(_construction.subject_ref_of(project), project, job, worker) \
		if code == &"" else code


func publish_open(project: Vector2i) -> void:
	"""Publish the exact prepared tip and footprint in the router's ADMIT call stack."""
	if _binding_refusal() != &"" or not _publication.pending:
		return
	var tip: Vector2i = _publication.subject
	var tile: int = _publication.tile
	var operation: int = _publication.operation
	if _publication.publication_refusal(tip, project, operation, _publication.quantity, Contract.ADMIT) != &"":
		return
	var code: StringName = _tips.publish_order(tip, project, operation, _publication.quantity) \
		if _tips.is_live_tip(tip) else _tips.publish_prepare_order(tile, project)
	assert(code == &"", "physical tip admission was fully preflighted")
	if code != &"":
		return
	_actual_contacts().publish_transition(tip, tile, project, operation, Contract.ADMIT)
	_publication.clear_pending()


func publish_work(project: Vector2i) -> void:
	"""Retain only the progress the real Work/Construction transaction just accepted."""
	_publish_transition(project, Contract.PRODUCTIVE)


func publish_completion(project: Vector2i) -> void:
	"""Actual output/WIP commits precede this no-fail physical source transition."""
	_publish_transition(project, Contract.COMMIT)


func publish_cancellation(project: Vector2i) -> void:
	"""Actual refund/loss settlement precedes release of source and incoming claims."""
	_publish_transition(project, Contract.CANCEL)


func _publish_transition(project: Vector2i, action: int) -> void:
	"""Use captured geometry facts because successful closure retires the tip handle."""
	if _binding_refusal() != &"" or project != _stage_project or action != _stage_action \
			or not _publication.actual_router().is_publishing(project, action, self):
		return
	var code: StringName = REFUSE_TRANSITION
	if action == Contract.PRODUCTIVE:
		code = _tips.publish_work(_stage_tip, project)
	elif action == Contract.COMMIT:
		code = _tips.publish_completion(_stage_tip, project)
	elif action == Contract.CANCEL:
		code = _tips.publish_cancellation(_stage_tip, project)
	assert(code == &"", "source publication was fully preflighted")
	if code != &"":
		return
	_actual_contacts().publish_transition(_stage_tip, _stage_tile, project, _stage_operation, action)
	_clear_stage()


func discard_transition(project: Vector2i, action: int) -> void:
	"""Release only this transaction's staged proof after failure or a successful START check."""
	if action == Contract.ADMIT:
		_discard_admission()
	elif project == _stage_project and action == _stage_action:
		var contacts: Contacts = _actual_contacts()
		if contacts != null:
			contacts.discard_transition(_stage_tip, _stage_tile, project, _stage_operation, action)
		_clear_stage()


func _discard_admission() -> void:
	"""A replacement or refused pending request cannot retain a cold footprint-stage lease."""
	if _publication == null or not _publication.pending:
		return
	var contacts: Contacts = _actual_contacts()
	if contacts != null:
		contacts.discard_transition(_publication.subject, _publication.tile, NULL_REF, _publication.operation, Contract.ADMIT)
	_publication.clear_pending()


func _clear_stage() -> void:
	"""Erase synchronous publication scratch; no physical state or retained work is erased."""
	_stage_project = NULL_REF
	_stage_tip = NULL_REF
	_stage_tile = -1
	_stage_operation = -1
	_stage_action = -1


func embedded_earth_milli() -> int:
	"""Whole-world conservation reads actual embedded stock, and refuses unavailable ownership."""
	return _tips.total_embedded_milli() if _binding_refusal() == &"" else -1
