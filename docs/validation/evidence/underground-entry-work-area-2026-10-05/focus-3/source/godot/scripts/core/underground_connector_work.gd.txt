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
const Workpieces := preload("res://scripts/core/underground_connector_workpieces.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_BINDING: StringName = &"CONNECTOR_WORK_UNBOUND"
const REFUSE_ORDER: StringName = &"CONNECTOR_WORK_ORDER"
const REFUSE_STAGE: StringName = &"CONNECTOR_WORK_STAGE"
const REFUSE_REENTRY: StringName = &"CONNECTOR_WORK_REENTRY"
const HANDLING: int = 5 # Private synchronous promotion only; not a Router/Funding action.
const HANDLING_PUBLISH: int = 6 # Entered only after the last concrete proof; no observer runs in this state.
const PAUSING: int = 7
const PAUSE_PUBLISH: int = 8

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

	func prepare_workpiece_start(_placement: Vector2i, _project: Vector2i, _assembly: int) -> StringName:
		"""Pin live endpoints and materials before spatial preparation, without granting target permission."""
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

	func handling_observation_refusal(_placement: Vector2i, _project: Vector2i,
			_worker: Vector2i, _job: Vector2i) -> StringName:
		"""Observe the complete actual stationary source; no base or caller success grants handled state."""
		return REFUSE_BINDING

	func release_observation_refusal(_placement: Vector2i, _project: Vector2i,
			_worker: Vector2i, _job: Vector2i) -> StringName:
		"""Observe actual READY positioning for departure, without granting productive or unpaused work."""
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
var _workpieces: Workpieces = null


func configure(placements: Placements, router: Router, contacts: Contacts) -> StringName:
	"""Initialize once; a failed reciprocal bind leaves an unactivated whole composition to discard."""
	if _world != NULL_REF or _placements != null or placements == null or router == null or contacts == null or not _enter():
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


static func retirement_refusal_in(actual: RefCounted, original: RefCounted, stopped_constructor: bool = false) -> StringName:
	"""Match the captured original fields and the finite configure prefixes; no foreign owner is reset or observed."""
	if actual == null or original == null or original.connector != actual or original.placements == null \
			or original.router == null or original.contacts == null or actual._publication == null \
			or actual._publication.owner == null or actual._publication.owner.get_ref() != actual \
			or actual._world != original.world_ref or actual._placements != original.placements \
			or actual._construction != original.construction or actual._assemblies != original.placements._assemblies \
			or actual._recipes != original.placements._recipes or actual._router == null \
			or actual._router.get_ref() != original.router or actual._contacts == null \
			or actual._contacts.get_ref() != original.contacts or (not actual._ready and not stopped_constructor):
		return REFUSE_BINDING
	if actual._busy or actual._stage_action != -1 or actual._stage_project != NULL_REF \
			or actual._stage_placement != NULL_REF or actual._stage_contacts != null \
			or actual._cold_token != 0 or actual._cold_budget != null:
		return REFUSE_STAGE
	if actual._workpieces != original.workpieces:
		if not stopped_constructor or actual._workpieces != null or original.workpieces == null \
				or original.placements._workpieces != null: return REFUSE_BINDING
	return _retirement_reciprocals_in(actual, original, stopped_constructor)


static func _retirement_reciprocals_in(actual: RefCounted, original: RefCounted, stopped: bool) -> StringName:
	"""Only absent, Router-only and fully bound configure prefixes can survive an actual stopped constructor."""
	var placements: RefCounted = original.placements
	var router: RefCounted = original.router
	if router._connector_owner == null:
		return &"" if stopped and not actual._ready and placements._publisher == null \
			and placements._router == null and placements._paid_owner == null else REFUSE_BINDING
	if router._connector_owner.get_ref() != actual: return REFUSE_BINDING
	if placements._publisher == null:
		return &"" if stopped and not actual._ready and placements._router == null \
			and placements._paid_owner == null else REFUSE_BINDING
	return &"" if placements._publisher.get_ref() == actual._publication and placements._router != null \
		and placements._router.get_ref() == router and placements._paid_owner != null \
		and placements._paid_owner.get_ref() == actual else REFUSE_BINDING


static func world_retirement_release_preflighted_in(actual: RefCounted, original: RefCounted,
		persistent_id: int, stopped_constructor: bool = false) -> StringName:
	"""Release only own borrows after canonical whole-World clear; the retained World handle permanently closes configure."""
	var code: StringName = retirement_refusal_in(actual, original, stopped_constructor)
	if code != &"": return code
	code = Routes.Buildings.whole_world_retirement_refusal_in(original.directory, original.world_ref, persistent_id, true)
	if code != &"": return code
	if original.world == null or original.world._published: return REFUSE_BINDING
	actual._ready = false
	actual._placements = null
	actual._construction = null
	actual._assemblies = null
	actual._recipes = null
	actual._router = null
	actual._contacts = null
	actual._publication.owner = null
	actual._publication = null
	actual._workpieces = null
	actual._order = null
	actual._assembly = null
	return &""


func construction_owner() -> RefCounted:
	"""The actual immutable store is exposed for initialization; readiness is checked by every operation."""
	return _construction


func bind_workpieces(actual: Workpieces) -> StringName:
	"""Activate one reciprocal static-workpiece composition only at the initialization boundary."""
	if not is_quiescent() or _composition_leaf() != &"" or _workpieces != null or actual == null \
			or not actual.is_quiescent() or not actual.exact_binding(_placements, _actual_router()) \
			or _placements._live.header[Placements.H_ACTIVE_ORDERS] != 0:
		return REFUSE_BINDING
	_workpieces = actual
	var code: StringName = _placements.bind_workpieces(actual)
	if code != &"": _workpieces = null
	return code


func complete_handling(placement: Vector2i, project: Vector2i, worker: Vector2i, job: Vector2i) -> StringName:
	"""Observe first, then promote one original paid row through concrete physical/source/clock leaves only."""
	if not _enter(): return REFUSE_REENTRY
	return _finish_handling_preflighted(self, _complete_handling_observed(placement, project, worker, job))


func _complete_handling_observed(placement: Vector2i, project: Vector2i, worker: Vector2i, job: Vector2i) -> StringName:
	"""The same real promotion may finish inside the exact Router pause window while its original worker is retained."""
	var pieces: Workpieces = _workpieces
	var placements: Placements = _placements
	var router: Router = _actual_router()
	var contacts: Contacts = _contacts.get_ref() as Contacts if _contacts != null else null
	var code: StringName = _composition_leaf()
	if code == &"" and (pieces == null or _stage_action != -1 or contacts == null \
			or router._busy and not _pause_window(self, router, project)):
		code = REFUSE_STAGE
	if code == &"": code = Workpieces.handling_leaf_refusal(pieces, placement, project, worker, job)
	if code != &"": return code
	_set_stage(placement, project, pieces._router._construction._type_id[Workpieces._project_row(pieces,
		placement, project)], HANDLING, contacts)
	placements._routes._remaining = placements._routes._domain._checks
	placements._routes._operation_error = &""
	placements._routes._callback_reentered = false
	code = contacts.handling_observation_refusal(placement, project, worker, job)
	if code == &"": code = _handling_scope_leaf(self, pieces, placements, router, contacts)
	if code == &"": code = _complete_handling_leaf(self, placement, project, worker, job)
	if code == &"":
		_stage_action = HANDLING_PUBLISH
		if not Workpieces.publish_handled_preflighted(pieces, placement, project, worker, job): code = REFUSE_STAGE
	return code


static func _handling_scope_leaf(a: RefCounted, pieces: Workpieces, placements: Placements,
		router: Router, contacts: Contacts) -> StringName:
	"""Close original borrowed owner identities after observers, without adopting coincident foreign replacements."""
	return &"" if a._workpieces == pieces and a._placements == placements and a._router != null \
		and a._router.get_ref() == router and a._construction == router._construction \
		and a._contacts != null and a._contacts.get_ref() == contacts and a._stage_contacts == contacts \
		and pieces._placements == placements and pieces._router == router and pieces._contacts != null \
		and pieces._contacts.get_ref() == contacts \
		and (not router._busy or _pause_window(a, router, a._stage_project)) else REFUSE_BINDING


static func _complete_handling_leaf(a: RefCounted, placement: Vector2i, project: Vector2i,
		worker: Vector2i, job: Vector2i) -> StringName:
	"""No virtual reader follows the last Contacts observer; original synchronous intent survives reentry or replacement."""
	if not a._busy or a._poisoned or a._stage_action != HANDLING or a._stage_placement != placement \
			or a._stage_project != project or a._contacts == null or a._contacts.get_ref() != a._stage_contacts \
			or a._workpieces == null or a._placements == null:
		return REFUSE_REENTRY
	var code: StringName = WorldRoutes.assembly_handling_leaf_refusal(a._placements._world_routes,
		a._workpieces, placement, project, worker, job)
	if code == &"": code = Workpieces.handling_leaf_refusal(a._workpieces, placement, project, worker, job)
	if code != &"": return code
	var row: int = Workpieces._project_row(a._workpieces, placement, project)
	if row < 0 or a._construction._type_id[row] != a._stage_assembly \
			or a._construction._phase[row] != Construction.PHASE_WORKING \
			or a._workpieces._live.present[placement.x] != Workpieces.PENDING_HANDLING:
		return Workpieces.REFUSE_HANDLING
	var profile: int = a._workpieces._parts[Workpieces.PROFILE * a._workpieces._assembly_capacity + a._stage_assembly]
	return Routes.assembly_handled_ready_leaf_refusal(a._placements._routes, worker, job, profile,
		a._workpieces._profile_revisions[a._stage_assembly], a._workpieces._header[Workpieces.H_PROFILES])


static func _finish_handling_preflighted(a: RefCounted, code: StringName) -> StringName:
	"""Direct cleanup cannot dispatch after the sole handled-state write; another staged operation is left untouched."""
	_clear_handling_preflighted(a)
	a._busy = false
	return REFUSE_REENTRY if a._poisoned else code


static func _clear_handling_preflighted(a: RefCounted) -> void:
	"""An enclosing pause keeps its synchronous reentry latch while a completed promotion drops only local intent."""
	if a._stage_action == HANDLING or a._stage_action == HANDLING_PUBLISH \
			or a._stage_action == PAUSING or a._stage_action == PAUSE_PUBLISH:
		a._stage_placement = NULL_REF
		a._stage_project = NULL_REF
		a._stage_assembly = -1
		a._stage_action = -1
		a._stage_contacts = null


static func _pause_window(a: RefCounted, router: Router, project: Vector2i) -> bool:
	"""Only the original synchronous paused purpose8 operation may retain Router busy during positioning recovery."""
	return router != null and router._busy and router._publishing_action == Contract.PAUSE_PREPARE \
		and router._publishing_project == project and router._publishing_owner == a \
		and router._connector_owner != null and router._connector_owner.get_ref() == a


func pause_release(project: Vector2i) -> StringName:
	"""Request real recovery now; keep exact assignments while it runs, then release through one closed static tail."""
	if not _enter(): return REFUSE_REENTRY
	var router: Router = _actual_router()
	var pieces: Workpieces = _workpieces
	var contacts: Contacts = _contacts.get_ref() as Contacts if _contacts != null else null
	var code: StringName = _composition_leaf()
	if code == &"" and (not _pause_window(self, router, project) or _stage_action != -1 \
			or router.get_script() != Router or contacts == null): code = REFUSE_STAGE
	if code == &"": code = Router.pause_release_leaf_refusal(router, project, self)
	if code == &"" and pieces != null: code = _pause_recover_workers(pieces, project)
	if code != &"": return _finish_handling_preflighted(self, code)
	_stage_project = project
	_stage_action = PAUSING
	_stage_contacts = contacts
	if pieces != null:
		var row: int = Workpieces._directory_row(_placements._ids, project, Directory.KIND_CONSTRUCTION)
		if row < 0: return _finish_handling_preflighted(self, Workpieces.REFUSE_PROJECT)
		_stage_placement = Vector2i(_construction._subject_slot[row], _construction._subject_generation[row])
		_stage_assembly = _construction._type_id[row]
		_placements._routes._remaining = _placements._routes._domain._checks
		_placements._routes._operation_error = &""
		_placements._routes._callback_reentered = false
		code = _pause_observe_workers(router, contacts, project)
	if code == &"": code = _pause_final_leaf(self, router, pieces, contacts, project)
	if code == &"":
		_stage_action = PAUSE_PUBLISH
		router._publishing_action = Contract.PAUSE_RELEASE
		code = Router.pause_release_preflighted(router, project, self)
	return _finish_handling_preflighted(self, code)


func _pause_recover_workers(pieces: Workpieces, project: Vector2i) -> StringName:
	"""Recovery owns no elapsed-work credit and can remain pending across paused 30 Hz ticks."""
	var code: StringName = Workpieces._binding_leaf(pieces)
	if code != &"": return code
	var router: Router = pieces._router
	for row: int in Router.JOB_CAPACITY:
		if router._project_slot[row] != project.x or router._project_generation[row] != project.y \
				or router._jobs._worker_slot[row] == -1: continue
		var job: Vector2i = Vector2i(router._job_slot[row], router._job_generation[row])
		var worker: Vector2i = Vector2i(router._jobs._worker_slot[row], router._jobs._worker_generation[row])
		code = _pause_recover_worker(pieces, project, worker, job)
		if code != &"" or _poisoned: return code if code != &"" else REFUSE_REENTRY
	return &""


func _pause_recover_worker(pieces: Workpieces, project: Vector2i, worker: Vector2i, job: Vector2i) -> StringName:
	"""Completed manipulation is promoted before normalization; interrupted entry only retraces its authored prefix."""
	var graph: Routes = _placements._routes
	var resident: int = Workpieces._directory_row(_placements._ids, worker, Directory.KIND_RESIDENT)
	var row: int = Workpieces._directory_row(_placements._ids, project, Directory.KIND_CONSTRUCTION)
	if graph == null or resident < 0 or row < 0: return REFUSE_BINDING
	var profile: int = graph._motion.resident[Routes.R_PROFILE * Routes.RESIDENT_CAPACITY + resident]
	var revision: int = graph._motion.resident_long[Routes.R_PROFILE_REVISION * Routes.RESIDENT_CAPACITY + resident]
	var content: int = graph._motion.resident_long[Routes.R_CONTENT_REVISION * Routes.RESIDENT_CAPACITY + resident]
	var code: StringName = Routes.source_ready_leaf_refusal(graph, worker, job, profile, revision, content)
	if code == &"": return &""
	if profile == Routes.Assembly.PROFILE \
			and Routes.assembly_handled_ready_leaf_refusal(graph, worker, job, profile, revision, content) == &"":
		var placement: Vector2i = Vector2i(_construction._subject_slot[row], _construction._subject_generation[row])
		if pieces._live.present[placement.x] == Workpieces.PENDING_HANDLING:
			code = _complete_handling_observed(placement, project, worker, job)
			_clear_handling_preflighted(self)
			if code != &"": return code
	code = graph.request_source_ready(worker, job)
	return code if code != &"" else Routes.source_ready_leaf_refusal(graph, worker, job, profile, revision, content)


func _pause_observe_workers(router: Router, contacts: Contacts, project: Vector2i) -> StringName:
	"""Every current departure source observes under one original graph budget, before any final physical or release leaf."""
	for row: int in Router.JOB_CAPACITY:
		if router._project_slot[row] != project.x or router._project_generation[row] != project.y \
				or router._jobs._worker_slot[row] == -1: continue
		var code: StringName = contacts.release_observation_refusal(_stage_placement, project,
			Vector2i(router._jobs._worker_slot[row], router._jobs._worker_generation[row]),
			Vector2i(router._job_slot[row], router._job_generation[row]))
		if code != &"" or _poisoned: return code if code != &"" else REFUSE_REENTRY
	return &""


static func _pause_final_leaf(a: RefCounted, router: Router, pieces: Workpieces,
		contacts: Contacts, project: Vector2i) -> StringName:
	"""No observer follows complete physical, source, original owner and actual release-store validation."""
	if not a._busy or a._poisoned or a._stage_action != PAUSING or a._stage_project != project \
			or a._workpieces != pieces or a._router == null or a._router.get_ref() != router \
			or a._contacts == null or a._contacts.get_ref() != contacts or a._stage_contacts != contacts \
			or not _pause_window(a, router, project) or router.get_script() != Router:
		return REFUSE_REENTRY
	var code: StringName = &""
	if pieces != null:
		if pieces._placements != a._placements or pieces._router != router or pieces._contacts == null \
				or pieces._contacts.get_ref() != contacts: return REFUSE_BINDING
		code = Workpieces.source_leaf_refusal(pieces, a._stage_placement, project)
		if code != &"": return code
		for row: int in Router.JOB_CAPACITY:
			if router._project_slot[row] != project.x or router._project_generation[row] != project.y \
					or router._jobs._worker_slot[row] == -1: continue
			code = WorldRoutes.assembly_release_leaf_refusal(a._placements._world_routes, pieces,
				a._stage_placement, project, Vector2i(router._jobs._worker_slot[row], router._jobs._worker_generation[row]),
				Vector2i(router._job_slot[row], router._job_generation[row]))
			if code != &"": return code
		code = Routes.assembly_release_leaf_refusal(a._placements._routes, pieces, project)
	if code == &"": code = Router.pause_release_leaf_refusal(router, project, a)
	return code


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
		if phase < 0 or phase >= Construction.PHASE_COUNT: return Construction.REFUSE_WRONG_PHASE
		return Routes.assembly_release_leaf_refusal(_placements._routes, _workpieces, project) \
			if _workpieces != null else &""
	if _construction._paused[row] != 0:
		return Construction.REFUSE_PAUSED
	var funded: bool = _actual_router()._funding.is_funded(project)
	if action == Contract.START and phase == Construction.PHASE_READY \
			and _construction._work_begun[row] == 0 and not funded:
		return &""
	if not funded or _construction._work_begun[row] != 1:
		return Construction.REFUSE_WRONG_PHASE
	if _workpieces != null and (action == Contract.PRODUCTIVE or action == Contract.COMMIT):
		var handling: StringName = Workpieces.handled_leaf_refusal(_workpieces,
			Vector2i(_construction._subject_slot[row], _construction._subject_generation[row]), project)
		if handling != &"": return handling
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
			if code == &"" and _initial_workpiece_start():
				code = _prepare_workpiece_start()
			if code == &"":
				code = contacts.transition_refusal(_stage_placement, project, _stage_assembly, action)
			if code == &"" and action == Contract.COMMIT:
				code = _prepare_completion()
			if code == &"" and action == Contract.CANCEL:
				code = _prepare_cancellation()
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
	var code: StringName = &""
	if _workpieces != null:
		code = _workpieces.prepare_completion(_stage_placement, _stage_project, _cold_token)
	if code == &"":
		code = _placements.prepare_completion(_stage_placement, _stage_project, _cold_token)
	if code == &"" and _workpieces != null:
		code = _workpieces.bind_prepared_completion(_stage_placement, _stage_project, _cold_token)
	return code


func _initial_workpiece_start() -> bool:
	"""Funded resume uses the existing live obstacle; only the original READY transition prepares a new one."""
	var row: int = _project_row(_stage_project)
	return _workpieces != null and _stage_action == Contract.START and row >= 0 \
		and _construction._phase[row] == Construction.PHASE_READY and _construction._work_begun[row] == 0


func _prepare_workpiece_start() -> StringName:
	"""One live prepass precedes all prepared banks; only the later complete contact proof grants START."""
	var code: StringName = _stage_contacts.prepare_workpiece_start(_stage_placement, _stage_project, _stage_assembly)
	if code == &"":
		code = _acquire_workpiece_cold()
	return _workpieces.prepare_start(_stage_placement, _stage_project, _cold_token) if code == &"" else code


func _prepare_cancellation() -> StringName:
	"""Only a genuinely funded workpiece needs a prepared spatial removal before its actual refund."""
	var code: StringName = _placements.cancellation_refusal(_stage_placement, _stage_project, _stage_assembly)
	if code != &"" or _workpieces == null or not _actual_router()._funding.is_funded(_stage_project):
		return code
	code = _acquire_workpiece_cold()
	return _workpieces.prepare_cancel(_stage_placement, _stage_project, _cold_token) if code == &"" else code


func _acquire_workpiece_cold() -> StringName:
	"""Capture the one original admitted arena; every failure later releases this exact object and token."""
	_cold_budget = _placements.cold_budget_owner()
	if _cold_budget == null or _cold_budget != _workpieces._budget:
		return REFUSE_BINDING
	_cold_token = _cold_budget.acquire(Budget.COLD_BYTES)
	return &"" if _cold_token > 0 else Budget.REFUSE_BUSY


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
	if code == &"" and _workpiece_prepared() and stage != Contract.COMMIT:
		code = _placements.workpiece_refusal(_workpieces._context)
	if code == &"":
		code = _stage_contacts.final_leaf_refusal(_stage_placement, project, _stage_assembly, stage)
	if code == &"":
		code = _stage_refusal(_stage_placement, project, _stage_assembly, stage)
	if code == &"" and stage == Contract.COMMIT:
		code = _placements.prepared_installation_leaf_refusal(_stage_placement, project, _stage_assembly, _cold_token)
	if code == &"" and _workpiece_prepared():
		code = _final_workpiece_leaf()
	if code == &"" and stage == Contract.CANCEL and not _workpiece_prepared():
		code = _placements.cancellation_refusal(_stage_placement, project, _stage_assembly)
	if code == &"":
		code = _funding_state_refusal(project, action)
	if code == &"" and stage == Contract.CANCEL and _workpieces != null:
		code = Routes.assembly_release_leaf_refusal(_placements._routes, _workpieces, project)
	return _leave(code)


func _workpiece_prepared() -> bool:
	"""Only this original captured action may borrow the workpiece's shared preparation packet."""
	return _workpieces != null and _cold_token > 0 and _workpieces._stage_project == _stage_project \
		and _workpieces._stage_placement == _stage_placement and _workpieces._stage_action == _stage_action


func _final_workpiece_leaf() -> StringName:
	"""After all observers, both actual owners attest the same original candidate before Inventory commits."""
	var code: StringName = Workpieces.prepared_leaf_refusal(_workpieces, _stage_placement,
		_stage_project, _stage_action, _cold_token)
	return _placements.prepared_workpiece_leaf_refusal(_workpieces._context) \
		if code == &"" and _stage_action != Contract.COMMIT else code


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


func publish_start(project: Vector2i) -> void:
	"""Payment and Construction already committed; one concrete spatial kernel publishes the prepared row too."""
	if project != _stage_project or _stage_action != Contract.START or not _publication_allowed(project, Contract.START):
		return
	if _workpieces != null:
		var published: bool = Placements.publish_workpiece_preflighted(_placements, _workpieces._context)
		assert(published, "the last prepayment leaf admits one callback-free workpiece publication")
	_release_cold()
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
	if _workpiece_prepared():
		var published: bool = Placements.publish_workpiece_preflighted(_placements, _workpieces._context)
		assert(published, "prepared refund removes exactly one workpiece and active project")
	else:
		var code: StringName = _placements.publish_cancellation(_stage_placement, project, _stage_assembly)
		assert(code == &"", "preflighted actual cancellation must retain the settled prefix")
	_release_cold()
	_clear_stage()


func discard_transition(project: Vector2i, action: int) -> void:
	"""Refusal drops only this exact operation; replacement leases, other Projects, earned work and WIP survive."""
	if project != _stage_project or action != _stage_action:
		return
	if not _enter():
		return
	if _cold_token > 0:
		_placements.discard_completion(_stage_placement, project, _cold_token)
		if _workpieces != null:
			_workpieces.discard(_stage_placement, project, _cold_token)
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
