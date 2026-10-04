extends "res://scripts/core/modular_project_contract.gd".Owner
## Actual purpose8 installation through one immutable assembly bill and the shared paid owners.
## Contacts grant no default permission. Placement alone owns installed prefixes and physical companions.

const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const Assemblies := preload("res://scripts/core/underground_connector_assemblies.gd")
const Recipes := preload("res://scripts/core/underground_connector_recipes.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_BINDING: StringName = &"CONNECTOR_WORK_UNBOUND"
const REFUSE_ORDER: StringName = &"CONNECTOR_WORK_ORDER"
const REFUSE_STAGE: StringName = &"CONNECTOR_WORK_STAGE"
const REFUSE_REENTRY: StringName = &"CONNECTOR_WORK_REENTRY"

class Contacts extends RefCounted:

	func exact_binding(_placements: Placements, _router: Router, _world: Vector2i) -> bool:
		"""Require the actual physical/contact composition, never a numeric World or profile coincidence."""
		return false

	func admission_refusal(_placement: Vector2i, _assembly: int) -> StringName:
		"""Prove the real next assembly's installation frontier before a Project identity is spent."""
		return REFUSE_BINDING

	func transition_refusal(_placement: Vector2i, _project: Vector2i, _assembly: int, _action: int) -> StringName:
		"""Observe current contact/support/retreat for START, PRODUCTIVE, COMMIT or CANCEL, without owning geometry."""
		return REFUSE_BINDING

	func material_refusal(_placement: Vector2i, _project: Vector2i, _assembly: int,
			_container: Vector2i, _job: Vector2i) -> StringName:
		"""Attest actual delivered or refunded goods at the full current supported material endpoint."""
		return REFUSE_BINDING

	func worker_refusal(_placement: Vector2i, _project: Vector2i, _assembly: int,
			_job: Vector2i, _worker: Vector2i) -> StringName:
		"""Require real worker/tool/load/pose and selected installation contact; no cold copy in a work tick."""
		return REFUSE_BINDING

	func final_observation_refusal(_placement: Vector2i, _project: Vector2i, _assembly: int, _action: int) -> StringName:
		"""Finish every contact observer before irreversible payment; temporary copied scratch must return here."""
		return REFUSE_BINDING

	func final_leaf_refusal(_placement: Vector2i, _project: Vector2i, _assembly: int, _action: int) -> StringName:
		"""Actual implementation must read pinned leaf owners without callbacks, allocation or publication."""
		return REFUSE_BINDING

	func discard_transition(_placement: Vector2i, _project: Vector2i, _assembly: int, _action: int) -> void:
		"""Release only refused observation controls; contacts retain no copied operation scratch or geometry."""
		pass

class Publication extends Placements.Publisher:
	var owner: WeakRef = null

	func exact_binding(placements: RefCounted, world: Vector2i, construction: Construction) -> bool:
		"""Initialization preflight may precede reciprocal binding; no ready permission is granted here."""
		var actual: RefCounted = owner.get_ref() if owner != null else null
		return actual != null and actual._placements == placements and actual._world == world \
			and actual._construction == construction and actual._composition_leaf(false) == &""

	func project_refusal(placement: Vector2i, project: Vector2i, assembly: int) -> StringName:
		"""Placement's observer checks full purpose/subject/operation without recursively reading a bill."""
		var actual: RefCounted = owner.get_ref() if owner != null else null
		return actual._exact_project_refusal(placement, project, assembly) if actual != null else REFUSE_BINDING

	func publication_refusal(placement: Vector2i, project: Vector2i, assembly: int, action: int) -> StringName:
		"""This is prepayment intent; only actual Router private tuples authorize the later pure publication."""
		var actual: RefCounted = owner.get_ref() if owner != null else null
		return actual._stage_refusal(placement, project, assembly, action) if actual != null else REFUSE_BINDING

var _placements: Placements = null
var _construction: Construction = null
var _assemblies: Assemblies = null
var _recipes: Recipes = null
var _router: WeakRef = null
var _contacts: WeakRef = null
var _publication: Publication = null
var _world: Vector2i = NULL_REF
var _ready: bool = false
var _busy: bool = false
var _poisoned: bool = false
var _order: Placements.OrderRecord = Placements.OrderRecord.new()
var _assembly: Assemblies.AssemblyRecord = Assemblies.AssemblyRecord.new()
var _stage_placement: Vector2i = NULL_REF
var _stage_project: Vector2i = NULL_REF
var _stage_assembly: int = -1
var _stage_action: int = -1
var _stage_contacts: Contacts = null
var _cold_budget: Budget = null
var _cold_token: int = 0


func configure(placements: Placements, router: Router, contacts: Contacts) -> StringName:
	"""Initialize once; a failed reciprocal bind leaves an unactivated whole composition to discard."""
	if _placements != null or placements == null or router == null or contacts == null or not _enter():
		return REFUSE_BINDING
	_placements = placements
	_construction = placements.construction_owner()
	_assemblies = placements.assemblies_owner()
	_recipes = placements.recipes_owner()
	_world = placements.world_ref()
	_router = weakref(router)
	_contacts = weakref(contacts)
	_publication = Publication.new()
	_publication.owner = weakref(self)
	var code: StringName = _composition_leaf(false)
	if code == &"" and not contacts.exact_binding(placements, router, _world):
		code = REFUSE_BINDING
	if code == &"":
		code = placements.publisher_binding_refusal(_publication, router, self)
	if code == &"":
		code = router.owner_binding_refusal(self)
	if code == &"" and not _poisoned:
		code = router.bind_owner(self).error
	if code == &"" and not _poisoned:
		code = placements.bind_publisher(_publication, router, self)
	_ready = code == &"" and not _poisoned and _composition_leaf(false) == &""
	return _leave(code if _ready else REFUSE_BINDING)


func construction_owner() -> RefCounted:
	"""The actual immutable store is exposed for initialization; readiness is checked by every operation."""
	return _construction


func world_ref() -> Vector2i:
	"""The local Placement namespace belongs only to this exact Directory World generation."""
	return _world


func purpose() -> int:
	"""Purpose8 names connector assemblies, never unrelated Furniture or excavation BRACE operations."""
	return Construction.PURPOSE_CONNECTOR_INSTALL


func is_quiescent() -> bool:
	"""Composed capture/frame boundaries require no escaped synchronous installation or contact preparation."""
	return not _busy and _stage_action == -1 and _stage_project == NULL_REF and _stage_placement == NULL_REF \
		and _stage_contacts == null and _cold_token == 0 and _cold_budget == null


func _actual_router() -> Router:
	"""Borrow the exact live weak Router without an observer or owner-bill recursion."""
	return _router.get_ref() as Router if _router != null else null


func _composition_leaf(require_ready: bool = true) -> StringName:
	"""Direct real owner identities close observer rewiring without another callback loop."""
	var router: Router = _actual_router()
	if require_ready and not _ready or router == null or _placements == null or _construction == null \
			or _assemblies == null or _recipes == null or _publication == null or _contacts == null \
			or _contacts.get_ref() == null or router._ready_error != &"" or router._construction != _construction \
			or router._world != _world or router._items != _recipes._items or router._inventory != _recipes._inventory \
			or _construction._modular_authority == null or _construction._modular_authority.get_ref() != router \
			or _placements._construction != _construction or _placements._world != _world \
			or _placements._assemblies != _assemblies or _placements._recipes != _recipes \
			or not _construction.directory().is_valid_of_kind(_world, Directory.KIND_WORLD):
		return REFUSE_BINDING
	if require_ready and (router._connector_owner == null or router._connector_owner.get_ref() != self \
			or _placements._publisher == null or _placements._publisher.get_ref() != _publication \
			or _placements._paid_owner == null or _placements._paid_owner.get_ref() != self):
		return REFUSE_BINDING
	return &""


func _enter() -> bool:
	"""Nested owner calls cannot overwrite shared quote/transition observations or bless the outer call."""
	if _busy:
		_poisoned = true
		return false
	_busy = true
	_poisoned = false
	return true


func _leave(code: StringName) -> StringName:
	"""Reentry poisons only this attempt; a later fresh Router operation may retry without losing paid work."""
	_busy = false
	return REFUSE_REENTRY if _poisoned else code


func _contact_owner() -> Contacts:
	"""Retain the exact observation owner strongly for the duration of one callback and recheck afterward."""
	var contacts: Contacts = _contacts.get_ref() as Contacts if _contacts != null else null
	return contacts if contacts != null and contacts.exact_binding(_placements, _actual_router(), _world) else null


func prepared_order_into(placement: Vector2i, assembly: int, out: Contract.Quote) -> StringName:
	"""One actual installed-prefix ordinal selects one immutable billable group, never a visual part bill."""
	if not _enter():
		return REFUSE_REENTRY
	var code: StringName = _composition_leaf()
	if code == &"" and _stage_action != -1:
		code = REFUSE_STAGE
	if code == &"":
		code = _placements.candidate_order_refusal(placement, assembly)
	var contacts: Contacts = _contact_owner() if code == &"" else null
	if code == &"" and contacts == null:
		code = REFUSE_BINDING
	if code == &"":
		_set_stage(placement, NULL_REF, assembly, Contract.ADMIT, contacts)
		code = contacts.admission_refusal(placement, assembly)
	if code == &"":
		code = _bill_into(placement, assembly, out)
	if code == &"":
		code = contacts.final_leaf_refusal(placement, NULL_REF, assembly, Contract.ADMIT)
	if code == &"":
		code = _placements.candidate_order_refusal(placement, assembly)
	return _leave(code if code != &"" else _composition_leaf())


func _bill_into(placement: Vector2i, assembly: int, out: Contract.Quote) -> StringName:
	"""Exactly128 reused logical bytes resolve the actual source tuple into the caller's existing Quote."""
	var code: StringName = _placements.placement_into(placement, _order)
	if code != &"" or _order.installed_count != assembly or assembly >= _order.assembly_count:
		return code if code != &"" else REFUSE_ORDER
	code = _assemblies.assembly_into(_order.catalog_row, _order.variant_revision, _order.grouping_revision, assembly, _assembly)
	if code == &"":
		code = _recipes.recipe_into(_order.catalog_row, _order.variant_revision, _assembly.recipe_anchor, _order.recipe_revision, out)
	if code == &"":
		out.subject = placement
		out.operation = assembly
	return code


func _project_row(project: Vector2i) -> int:
	"""Full mirrored generation and actual purpose precede every hot subject or operation read."""
	if _composition_leaf() != &"" or not _construction.directory().is_valid_of_kind(project, Directory.KIND_CONSTRUCTION):
		return -1
	var row: int = _construction.directory().get_typed_row(project)
	if row < 0 or row >= Construction.CONSTRUCTION_CAPACITY or _construction._present[row] != 1 \
			or _construction._ref_slot[row] != project.x or _construction._ref_generation[row] != project.y \
			or _construction._purpose[row] != Construction.PURPOSE_CONNECTOR_INSTALL:
		return -1
	return row


func _exact_project_refusal(placement: Vector2i, project: Vector2i, assembly: int) -> StringName:
	"""This leaf performs no Recipe, contact or Publisher observation; Placement owns the sole active link."""
	var row: int = _project_row(project)
	if row < 0 or _construction.subject_ref_of(project) != placement or _construction._type_id[row] != assembly:
		return REFUSE_ORDER
	return _placements.order_refusal(placement, project, assembly)


func project_facts_into(project: Vector2i, out: Contract.Quote) -> StringName:
	"""Cold funding reads immutable prices and real current Construction work; no copied work ledger exists."""
	if not _enter():
		return REFUSE_REENTRY
	var row: int = _project_row(project)
	var code: StringName = REFUSE_ORDER
	if row >= 0:
		var placement: Vector2i = _construction.subject_ref_of(project)
		var assembly: int = _construction._type_id[row]
		code = _exact_project_refusal(placement, project, assembly)
		if code == &"":
			code = _bill_into(placement, assembly, out)
		if code == &"":
			code = _exact_project_refusal(placement, project, assembly)
		if code == &"":
			out.remaining_mwu = _construction._remaining_mwu[row]
	return _leave(code)


func _set_stage(placement: Vector2i, project: Vector2i, assembly: int, action: int, contacts: Contacts) -> void:
	"""One synchronous operation retains only scope/control facts; no per-placement arena is added."""
	_stage_placement = placement
	_stage_project = project
	_stage_assembly = assembly
	_stage_action = action
	_stage_contacts = contacts


func _stage_refusal(placement: Vector2i, project: Vector2i, assembly: int, action: int) -> StringName:
	"""Publisher preflight proves exact intent without confusing it with a postpayment Router window."""
	if placement != _stage_placement or project != _stage_project or assembly != _stage_assembly \
			or action != _stage_action or _stage_contacts == null or _contacts.get_ref() != _stage_contacts:
		return REFUSE_STAGE
	var code: StringName = _exact_project_refusal(placement, project, assembly)
	return _action_state_refusal(project, action) if code == &"" else code


func _action_state_refusal(project: Vector2i, action: int) -> StringName:
	"""Late successful observers cannot preserve identity while changing the paid phase or pausing work."""
	var row: int = _project_row(project)
	if row < 0 or _construction._remaining_mwu[row] < 0:
		return REFUSE_ORDER
	var phase: int = _construction._phase[row]
	if action == Contract.CANCEL:
		return &"" if phase >= 0 and phase < Construction.PHASE_COUNT else Construction.REFUSE_WRONG_PHASE
	if _construction._paused[row] != 0:
		return Construction.REFUSE_PAUSED
	var funded: bool = _actual_router()._funding.is_funded(project)
	if action == Contract.START and phase == Construction.PHASE_READY \
			and _construction._work_begun[row] == 0 and not funded:
		return &""
	if not funded or _construction._work_begun[row] != 1:
		return Construction.REFUSE_WRONG_PHASE
	if action == Contract.COMMIT:
		return &"" if phase == Construction.PHASE_WORK_DONE and _construction._remaining_mwu[row] == 0 \
			else Construction.REFUSE_WRONG_PHASE
	return &"" if (action == Contract.START or action == Contract.PRODUCTIVE) \
		and phase == Construction.PHASE_WORKING and _construction._remaining_mwu[row] > 0 else Construction.REFUSE_WRONG_PHASE


func _funding_state_refusal(project: Vector2i, action: int) -> StringName:
	"""START settlement is not a funded resume; cancellation settlement is already frozen and may be paused."""
	var row: int = _project_row(project)
	if row < 0:
		return REFUSE_ORDER
	if action == Contract.ACTION_WIP and (_construction._phase[row] != Construction.PHASE_READY \
			or _construction._work_begun[row] != 0 or _actual_router()._funding.is_funded(project)):
		return Construction.REFUSE_WRONG_PHASE
	if action == Contract.ACTION_REFUND and _construction._phase[row] != Construction.PHASE_REFUNDING:
		return Construction.REFUSE_WRONG_PHASE
	return &""


func transition_refusal(project: Vector2i, action: int) -> StringName:
	"""All contact and physical preparation happens before actual input, work, output or refund settlement."""
	if not _enter():
		return REFUSE_REENTRY
	var row: int = _project_row(project)
	var code: StringName = REFUSE_STAGE
	if row >= 0 and _stage_action == -1 and (action == Contract.START or action == Contract.PRODUCTIVE \
			or action == Contract.COMMIT or action == Contract.CANCEL):
		var contacts: Contacts = _contact_owner()
		if contacts != null:
			_set_stage(_construction.subject_ref_of(project), project, _construction._type_id[row], action, contacts)
			code = _stage_refusal(_stage_placement, project, _stage_assembly, action)
			if code == &"":
				code = contacts.transition_refusal(_stage_placement, project, _stage_assembly, action)
			if code == &"" and action == Contract.COMMIT:
				code = _prepare_completion()
			if code == &"" and action == Contract.CANCEL:
				code = _placements.cancellation_refusal(_stage_placement, project, _stage_assembly)
			if code == &"":
				code = _stage_refusal(_stage_placement, project, _stage_assembly, action)
	return _leave(code)


func _prepare_completion() -> StringName:
	"""Retain the actual original arena before observers; never re-fetch a possibly invalidated owner to clean up."""
	_cold_budget = _placements.cold_budget_owner()
	var bytes: int = _placements.installation_cold_bytes(_stage_placement, _stage_assembly)
	if _cold_budget == null or bytes < 1 or _placements.cold_budget_owner() != _cold_budget:
		return REFUSE_BINDING
	_cold_token = _cold_budget.acquire(bytes)
	if _cold_token <= 0:
		return Budget.REFUSE_BUSY
	return _placements.prepare_completion(_stage_placement, _stage_project, _cold_token)


func material_refusal(project: Vector2i, container: Vector2i, job: Vector2i) -> StringName:
	"""Actual Funding retains lot/claim ownership; this provider proves the spatial material contact."""
	if not _enter():
		return REFUSE_REENTRY
	var row: int = _project_row(project)
	var contacts: Contacts = _contact_owner() if row >= 0 else null
	var code: StringName = REFUSE_BINDING
	if contacts != null:
		var placement: Vector2i = _construction.subject_ref_of(project)
		var assembly: int = _construction._type_id[row]
		code = _exact_project_refusal(placement, project, assembly)
		if code == &"":
			code = contacts.material_refusal(placement, project, assembly, container, job)
		if code == &"":
			code = _exact_project_refusal(placement, project, assembly)
	return _leave(code)


func worker_refusal(project: Vector2i, job: Vector2i, worker: Vector2i) -> StringName:
	"""Hot proof uses no record, Quote, source-array copy or virtual Recipe read."""
	if not _enter():
		return REFUSE_REENTRY
	var row: int = _project_row(project)
	var contacts: Contacts = _contact_owner() if row >= 0 else null
	var code: StringName = REFUSE_BINDING
	if contacts != null:
		var placement: Vector2i = _construction.subject_ref_of(project)
		var assembly: int = _construction._type_id[row]
		code = _exact_project_refusal(placement, project, assembly)
		if code == &"":
			code = contacts.worker_refusal(placement, project, assembly, job, worker)
		if code == &"":
			code = _exact_project_refusal(placement, project, assembly)
	return _leave(code)


func output_refusal(project: Vector2i, container: Vector2i, _job: Vector2i, promotion_tile: int) -> StringName:
	"""Installed wood produces no carried output; no surface or spatial pile capacity can be borrowed."""
	return &"" if _project_row(project) >= 0 and container == NULL_REF and promotion_tile == -1 else REFUSE_ORDER


func final_funding_refusal(project: Vector2i, action: int) -> StringName:
	"""Finish observers after Inventory staging, then pure contact/source/lease facts before commit."""
	if not _enter():
		return REFUSE_REENTRY
	var stage: int = Contract.START if action == Contract.ACTION_WIP else Contract.COMMIT \
		if action == Contract.ACTION_OUTPUT else Contract.CANCEL if action == Contract.ACTION_REFUND else -1
	var code: StringName = _stage_refusal(_stage_placement, project, _stage_assembly, stage)
	if code == &"":
		code = _stage_contacts.final_observation_refusal(_stage_placement, project, _stage_assembly, stage)
	if code == &"" and stage == Contract.COMMIT:
		code = _placements.completion_refusal(_stage_placement, project, _stage_assembly, _cold_token)
	if code == &"":
		code = _stage_contacts.final_leaf_refusal(_stage_placement, project, _stage_assembly, stage)
	if code == &"":
		code = _stage_refusal(_stage_placement, project, _stage_assembly, stage)
	if code == &"" and stage == Contract.COMMIT:
		code = _placements.prepared_installation_leaf_refusal(_stage_placement, project, _stage_assembly, _cold_token)
	if code == &"" and stage == Contract.CANCEL:
		code = _placements.cancellation_refusal(_stage_placement, project, _stage_assembly)
	if code == &"":
		code = _funding_state_refusal(project, action)
	return _leave(code)


func _publication_allowed(project: Vector2i, action: int) -> bool:
	"""Read the real synchronous Router tuple directly; no observer is permitted after payment."""
	var router: Router = _actual_router()
	return not _busy and not _poisoned and _composition_leaf() == &"" and router._busy \
		and router._publishing_project == project and router._publishing_action == action and router._publishing_owner == self


func publish_open(project: Vector2i) -> void:
	"""Only the original one-group admission attaches the newly allocated real Project."""
	if _stage_action != Contract.ADMIT or not _publication_allowed(project, Contract.ADMIT):
		return
	var code: StringName = _placements.attach_order(_stage_placement, project, _stage_assembly)
	assert(code == &"", "exact preflighted next assembly must attach once")
	_clear_stage()


func publish_work(project: Vector2i) -> void:
	"""Actual Work already applied integer WU/XP/wear; there is no duplicate installation progress."""
	if project == _stage_project and _stage_action == Contract.PRODUCTIVE and _publication_allowed(project, Contract.PRODUCTIVE):
		_clear_stage()


func publish_completion(project: Vector2i) -> void:
	"""Only static prepared companions publish after Funding; no bill/contact/source observer follows."""
	if project != _stage_project or _stage_action != Contract.COMMIT or not _publication_allowed(project, Contract.COMMIT):
		return
	var code: StringName = _placements.publish_completion(_stage_placement, project, _stage_assembly, _cold_token)
	assert(code == &"", "prepayment exact leaf permits the pure installation tail")
	_release_cold()
	_clear_stage()


func publish_cancellation(project: Vector2i) -> void:
	"""Actual refund settles first; cancellation clears only the active Project and preserves the installed prefix."""
	if project != _stage_project or _stage_action != Contract.CANCEL or not _publication_allowed(project, Contract.CANCEL):
		return
	var code: StringName = _placements.publish_cancellation(_stage_placement, project, _stage_assembly)
	assert(code == &"", "preflighted actual cancellation must retain the settled prefix")
	_clear_stage()


func discard_transition(project: Vector2i, action: int) -> void:
	"""Refusal drops only this exact operation; replacement leases, other Projects, earned work and WIP survive."""
	if project != _stage_project or action != _stage_action:
		return
	if not _enter():
		return
	if action == Contract.COMMIT and _cold_token > 0:
		_placements.discard_completion(_stage_placement, project, _cold_token)
	if _stage_contacts != null:
		_stage_contacts.discard_transition(_stage_placement, project, _stage_assembly, action)
	_release_cold()
	_clear_stage()
	_leave(&"")


func _release_cold() -> void:
	"""All copied provider/companion state has dropped before returning only the original acquired lease."""
	if _cold_budget != null and _cold_token > 0 and _cold_budget.covers(_cold_token, 1):
		var code: StringName = _cold_budget.release(_cold_token)
		assert(code == &"", "exact retained original arena releases without a source observer")
	_cold_budget = null
	_cold_token = 0


func _clear_stage() -> void:
	"""Only synchronous controls are cleared; every durable truth stays with its actual owner."""
	_stage_placement = NULL_REF
	_stage_project = NULL_REF
	_stage_assembly = -1
	_stage_action = -1
	_stage_contacts = null
