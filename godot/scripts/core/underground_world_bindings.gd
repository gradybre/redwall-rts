extends "res://scripts/core/underground_space_authority.gd".Bindings
## Actual World composition. A survey is observation, never excavation or traversal permission.
## Base matter is exactly subtracted around retained physical state; claims remain blockers.

const World := preload("res://scripts/core/world_init.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Authority := preload("res://scripts/core/underground_space_authority.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const RoomOrders := preload("res://scripts/core/underground_room_orders.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const NATURAL_ROW_LIMIT: int = 512
const COMPOSED_ROW_LIMIT: int = Budget.PHASE_VOLUME_CAPACITY
const FRAGMENT_LIMIT: int = 4096
const CONTROL_BYTES: int = 640
const SNAPSHOT_BYTES: int = 48 * Budget.REGION_CAPACITY + 16 * Budget.SOURCE_CAPACITY
const OUTPUT_BYTES: int = 48 * COMPOSED_ROW_LIMIT + 16 * Budget.SOURCE_CAPACITY
const SNAPSHOT_SCAN_CHECKS: int = 3 * (Budget.REGION_CAPACITY + Budget.SOURCE_CAPACITY)
const WORLD_LOOKUP_CHECKS: int = 10 * Budget.SOURCE_CAPACITY
const COMPOSITION_BYTES: int = SNAPSHOT_BYTES + 48 * NATURAL_ROW_LIMIT + OUTPUT_BYTES \
	+ 48 * FRAGMENT_LIMIT + CONTROL_BYTES
const PHASE_CONTROL_BYTES: int = 512
const PHASE_ROW_BYTES: int = 72 # 48 per volume plus conservatively charged contact metadata.
@warning_ignore("integer_division")
const PHASE_ROW_LIMIT: int = (Budget.COLD_BYTES - COMPOSITION_BYTES - PHASE_CONTROL_BYTES) / PHASE_ROW_BYTES
const REFUSE_BINDING: StringName = &"WORLD_COMPOSITION_BINDING"
const REFUSE_BOUNDS: StringName = &"WORLD_COMPOSITION_BOUNDS"
const REFUSE_CAPACITY: StringName = &"WORLD_COMPOSITION_CAPACITY"
const REFUSE_BUDGET: StringName = &"WORLD_COMPOSITION_COLD_LEASE"
const REFUSE_BUSY: StringName = &"WORLD_COMPOSITION_BUSY"

var _world: World = null
var _terrain: Terrain = null
var _owner: WeakRef = null
var _source_reader: WeakRef = null
var _budget: Budget = null
var _domain: Space.Domain = null
var _composing: bool = false
var _remaining: int = 0
var _retained_rows: int = 0
var _fragments: Array[PackedInt32Array] = []
var _next_fragments: Array[PackedInt32Array] = []
var _clip: PackedInt32Array = PackedInt32Array()
var _intersection: PackedInt32Array = PackedInt32Array()
var _cold_opening: bool = false
var _phase_token: int = 0
var _phase_site: Vector2i = NULL_REF
var _phase_room: Vector2i = NULL_REF
var _phase_project: Vector2i = NULL_REF
var _phase_geometry_revision: int = 0
var _phase_operation: int = -1
var _phase_stage: int = -1
var _room_bindings: WeakRef = null
var _room_region: Owner.Region = null
var _room_reading: bool = false
var _room_identity: PackedInt32Array = PackedInt32Array()
var _identity_reading: bool = false
var _worker_reading: bool = false


func configure(world: World, terrain: Terrain, owner: Owner, reader: Owner.CoreSources,
		budget: Budget) -> StringName:
	"""Bind actual collaborators and the complete finite observation pack before any survey allocation."""
	if _owner != null:
		return &"WORLD_COMPOSITION_ALREADY_BOUND"
	if world == null or terrain == null or owner == null or reader == null or budget == null \
			or not owner.is_bound_sources(reader) or not terrain.is_bound_world(world, owner, reader) \
			or not terrain.is_bound_budget(budget) or terrain.binding_refusal() != &"":
		return REFUSE_BINDING
	if not owner.allocation_within(Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY) \
			or COMPOSITION_BYTES > Budget.COLD_BYTES:
		return REFUSE_CAPACITY
	_domain = owner.domain_copy()
	if _domain == null:
		return REFUSE_BINDING
	_world = world
	_terrain = terrain
	_owner = weakref(owner)
	_source_reader = weakref(reader)
	_budget = budget
	_clip.resize(6)
	_intersection.resize(6)
	_room_identity.resize(Buildings.ROOM_IDENTITY_FIELDS)
	return &""


func sources() -> Owner.CoreSources:
	"""Borrow the actual reader without making a Construction-to-Bindings reference cycle."""
	return _source_reader.get_ref() as Owner.CoreSources if _source_reader != null else null


func space_owner() -> Owner:
	"""Borrow configured identity only; callers still require the exact live cold-site proof."""
	return _actual_owner()


func terrain_owner() -> Terrain:
	"""Borrow configured identity only; callers must still prove actual World, Budget and current exclusions."""
	return _terrain


func room_refusal(room: Vector2i) -> StringName:
	"""Require actual registered underground identity and unchanged permanent purpose, without granting service."""
	if _identity_reading:
		return REFUSE_BUSY
	_identity_reading = true
	var code: StringName = _room_identity_refusal(room)
	_identity_reading = false
	return code


func _room_identity_refusal(room: Vector2i) -> StringName:
	"""This path never calls Sites.room_of, which itself asks the physical authority to validate this Room."""
	var code: StringName = binding_refusal()
	if code != &"":
		return code
	var reader: Owner.CoreSources = sources()
	var construction: Construction = reader.construction_owner() if reader != null else null
	if construction == null or construction.directory() != reader.directory():
		return REFUSE_BINDING
	code = construction.buildings().room_identity_into(room, _room_identity)
	if code != &"":
		return code
	if _room_identity[0] != Buildings.ROOM_SPACE_UNDERGROUND:
		return &"SPACE_UNDERGROUND_ROOM_REQUIRED"
	code = _actual_owner().source_refusal(room)
	return binding_refusal() if code == &"" else code


func assigned_worker(site: Vector2i, job: Vector2i) -> Vector2i:
	"""Read only an actual reciprocal living Job assignment; contact, gear and work permission remain separate."""
	if _worker_reading:
		return NULL_REF
	_worker_reading = true
	var worker: Vector2i = _assigned_worker(site, job)
	_worker_reading = false
	return worker


func _assigned_worker(site: Vector2i, job: Vector2i) -> Vector2i:
	"""Use the actual Sites Jobs owner, full Directory kinds/generations and both row mirrors."""
	if binding_refusal() != &"":
		return NULL_REF
	var sites: Sites = _actual_sites()
	if sites == null or not sites.is_live_site(site) or sites.job_of(site) != job or job == NULL_REF:
		return NULL_REF
	var room: Vector2i = sites.room_of(site)
	if room_refusal(room) != &"":
		return NULL_REF
	var jobs: Jobs = sites.jobs_owner()
	var ids: Directory = sources().directory()
	if jobs == null or jobs.directory() != ids or not ids.is_valid_of_kind(job, Directory.KIND_JOB):
		return NULL_REF
	var row: int = ids.get_typed_row(job)
	if jobs.ref_of(row) != job:
		return NULL_REF
	var worker: Vector2i = jobs.worker_of(row)
	if not ids.is_valid_of_kind(worker, Directory.KIND_RESIDENT):
		return NULL_REF
	var resident: int = ids.get_typed_row(worker)
	if jobs.residents().ref_of(resident) != worker or not jobs.residents().is_alive(resident) \
			or not jobs.is_agent_present(resident) or jobs.job_of(resident) != job:
		return NULL_REF
	return worker if sites.job_of(site) == job and binding_refusal() == &"" else NULL_REF


func bind_room_bindings(reader: RoomOrders.Bindings) -> StringName:
	"""Wire one actual room provider at quiescence without a concrete-provider preload or reference cycle."""
	if _room_reading or _composing or _cold_opening or _phase_token != 0 or _room_bindings != null \
			or (_budget != null and not _budget.is_quiescent()):
		return REFUSE_BUSY
	_room_reading = true
	var code: StringName = _room_binding_refusal(reader)
	if code == &"" and not _budget.is_quiescent():
		code = REFUSE_BUSY
	if code == &"":
		_room_bindings = weakref(reader)
		_room_region = Owner.Region.new()
		_room_region.box.resize(6)
	_room_reading = false
	return code


func _room_binding_refusal(reader: RoomOrders.Bindings) -> StringName:
	"""Equal numeric references never substitute for the actual Buildings, Construction, Space and arena."""
	if reader == null or binding_refusal() != &"":
		return REFUSE_BINDING
	var actual: Owner.CoreSources = sources()
	var owner: Owner = _actual_owner()
	var construction: Construction = actual.construction_owner() if actual != null else null
	if construction == null or owner == null \
			or not reader.exact_binding(construction.buildings(), owner, construction, world_ref()) \
			or reader.layout_budget_owner() != _budget or reader.phase_world_owner() != self:
		return REFUSE_BINDING
	return binding_refusal()


func _actual_room_bindings() -> RoomOrders.Bindings:
	"""Keep a strong borrow only for a synchronous observation; expired wiring cannot recreate authority."""
	return _room_bindings.get_ref() as RoomOrders.Bindings if _room_bindings != null else null


func _room_phase_refusal(reader: RoomOrders.Bindings, site: Vector2i, room: Vector2i,
		token: int) -> StringName:
	"""Recheck exact phase scope after binding callbacks and after the actual provider fills its result."""
	var code: StringName = cold_site_refusal(token, site, room)
	if code == &"":
		code = _room_binding_refusal(reader)
	return cold_site_refusal(token, site, room) if code == &"" else code


func floor_section(site: Vector2i, room: Vector2i) -> Vector2i:
	"""Delegate exact Room-owned metadata under the retained actual Site lease; never infer floor from cut Y."""
	if _room_reading or _composing or _cold_opening:
		return NULL_REF
	_room_reading = true
	var token: int = _phase_token
	var reader: RoomOrders.Bindings = _actual_room_bindings()
	var code: StringName = _room_phase_refusal(reader, site, room, token)
	if code == &"" and _room_region != null:
		code = reader.phase_section_into(site, room, token, _room_region)
	elif code == &"":
		code = REFUSE_BINDING
	if code == &"":
		code = _room_phase_refusal(reader, site, room, token)
	var result: Vector2i = _room_region.section if code == &"" else NULL_REF
	_room_reading = false
	return result


func finish_mask_into(site: Vector2i, room: Vector2i, cold_token: int,
		row_limit: int, out: PackedInt32Array) -> StringName:
	"""Borrow exact fine claims; the physical Authority independently proves and publishes the returned mask."""
	if _room_reading or _composing or _cold_opening:
		return REFUSE_BUSY
	_room_reading = true
	out.clear()
	var reader: RoomOrders.Bindings = _actual_room_bindings()
	var code: StringName = _room_phase_refusal(reader, site, room, cold_token)
	if code == &"":
		code = reader.finish_mask_into(site, room, cold_token, row_limit, out)
	if code == &"":
		code = _room_phase_refusal(reader, site, room, cold_token)
	if code != &"":
		out.clear()
	_room_reading = false
	return code


func world_ref() -> Vector2i:
	"""Read the immutable configured World generation without allocating a Domain descriptor."""
	return _domain._world if _domain != null else NULL_REF


func binding_refusal() -> StringName:
	"""Reject expired or rewired actual owners; static numeric references are insufficient."""
	var owner: Owner = _actual_owner()
	var reader: Owner.CoreSources = sources()
	if owner == null or reader == null or _terrain == null or _domain == null \
			or not owner.is_bound_sources(reader) or not _terrain.is_bound_world(_world, owner, reader) \
			or not _terrain.is_bound_budget(_budget):
		return REFUSE_BINDING
	return _terrain.binding_refusal()


func allocation_refusal(owner: Owner, proof_rows: int, cache_bytes: int) -> StringName:
	"""Attest actual bounded cache/owner identity; this supplies no physical qualification revision."""
	if binding_refusal() != &"" or owner != _actual_owner():
		return REFUSE_BINDING
	return &"" if proof_rows > 0 and proof_rows <= Budget.PROOF_CAPACITY \
		and cache_bytes == 69 * proof_rows + 60 and cache_bytes <= Budget.PROOF_BYTES \
		else REFUSE_CAPACITY


func is_bound_budget(candidate: Budget) -> bool:
	"""Only the configured World-owned cold arena can fund this provider's output lifetime."""
	return _budget != null and candidate == _budget


func begin_cold_operation(owner: Owner, site: Vector2i, operation: int, stage: int) -> int:
	"""Acquire this actual world's complete synchronous phase peak; the lease grants no work permission."""
	if _cold_opening or _composing or _room_reading or _phase_token != 0:
		return 0
	_cold_opening = true
	var valid: bool = owner == _actual_owner() and owner != null and binding_refusal() == &"" \
		and Contract.valid_operation(operation) and stage >= Contract.STAGE_ADMIT and stage <= Contract.STAGE_WORK
	var sites: Sites = _actual_sites() if valid else null
	if sites != null and sites.is_live_site(site) and sites.room_of(site) != NULL_REF:
		_phase_site = site
		_phase_room = sites.room_of(site)
		_phase_project = sites.project_of(site)
		_phase_geometry_revision = owner.revision()
		_phase_operation = operation
		_phase_stage = stage
		_phase_token = _budget.acquire(Budget.COLD_BYTES)
	var token: int = _phase_token
	_cold_opening = false
	if token == 0:
		_clear_phase_lease()
	return token


func cold_operation_refusal(token: int) -> StringName:
	"""Attest the exact retained lease and unchanged actual site scope before any allocating boundary."""
	if _cold_opening or token <= 0 or token != _phase_token or _budget == null \
			or not _budget.covers(token, Budget.COLD_BYTES):
		return REFUSE_BUDGET
	var code: StringName = binding_refusal()
	if code != &"":
		return code
	var sites: Sites = _actual_sites()
	if sites == null or not sites.is_live_site(_phase_site) or sites.room_of(_phase_site) != _phase_room \
			or sites.project_of(_phase_site) != _phase_project \
			or _actual_owner().revision() != _phase_geometry_revision:
		return &"WORLD_COMPOSITION_COLD_CONTEXT"
	return &"" if _budget.covers(token, Budget.COLD_BYTES) else REFUSE_BUDGET


func cold_site_refusal(token: int, site: Vector2i, room: Vector2i) -> StringName:
	"""A caller cannot borrow another site's current lease, even within the same Room."""
	if site == NULL_REF or room == NULL_REF or site != _phase_site or room != _phase_room:
		return &"WORLD_COMPOSITION_COLD_CONTEXT"
	return cold_operation_refusal(token)


func cold_phase_refusal(token: int, site: Vector2i, operation: int, stage: int,
		room: Vector2i) -> StringName:
	"""An actual structural companion may borrow only this exact observed operation and phase boundary."""
	if operation != _phase_operation or stage != _phase_stage:
		return &"WORLD_COMPOSITION_COLD_CONTEXT"
	return cold_site_refusal(token, site, room)


func end_cold_operation(token: int) -> void:
	"""Drop only our exact lease after caller scratch/companions; cleanup cannot release a replacement lease."""
	if _cold_opening or _composing or token <= 0 or token != _phase_token:
		return
	if _budget.covers(token, Budget.COLD_BYTES):
		var released: StringName = _budget.release(token)
		assert(released == &"", "Exact completed phase lease releases once")
	_clear_phase_lease()


func _clear_phase_lease() -> void:
	"""Transient site pins are not gameplay state and do not outlive an operation's allocated scratch."""
	_phase_token = 0
	_phase_site = NULL_REF
	_phase_room = NULL_REF
	_phase_project = NULL_REF
	_phase_geometry_revision = 0
	_phase_operation = -1
	_phase_stage = -1


func _actual_sites() -> Sites:
	"""Borrow the actual once-bound physical store; numeric site references cannot select another world."""
	var reader: Owner.CoreSources = sources()
	if reader == null or reader.construction_owner() == null:
		return null
	var sites: Sites = reader.construction_owner().excavation_authority() as Sites
	return sites if sites != null and sites.construction_owner() == reader.construction_owner() else null


func composition_peak_bytes() -> int:
	"""Expose the full simultaneous packed peak; callers add their own retained plans and companions."""
	return COMPOSITION_BYTES if _owner != null else 0


func composed_snapshot_into(bounds: PackedInt32Array, out: Space.Snapshot, token: int) -> StringName:
	"""Compose under a retained lease; admitted failures clear output and reentry preserves the active output."""
	return _snapshot_query(bounds, out, token, null, NULL_REF)


func composed_snapshot_for_site_into(bounds: PackedInt32Array, out: Space.Snapshot,
		token: int, sites: Sites, site: Vector2i) -> StringName:
	"""Only actual Sites may omit their own typed Room/project markers; all physical blockers remain."""
	if sites == null or site == NULL_REF:
		var code: StringName = _begin_query(out)
		return code if code != &"" else _finish_query(out, &"WORLD_COMPOSITION_SITE_SCOPE")
	return _snapshot_query(bounds, out, token, sites, site)


func _begin_query(out: Space.Snapshot) -> StringName:
	"""Establish exclusivity before any provider callback; a refused nested call cannot clear active output."""
	if _composing or _room_reading:
		return REFUSE_BUSY
	if out == null:
		return &"WORLD_COMPOSITION_OUTPUT"
	if out.volumes == null:
		_clear_snapshot(out)
		return &"WORLD_COMPOSITION_OUTPUT"
	_composing = true
	_clear_snapshot(out)
	return &""


func _finish_query(out: Space.Snapshot, code: StringName) -> StringName:
	"""Drop every fragment before returning the caller-owned observation under its existing lease."""
	_fragments.clear()
	_next_fragments.clear()
	if code != &"":
		_clear_snapshot(out)
	_composing = false
	return code


func _snapshot_query(bounds: PackedInt32Array, out: Space.Snapshot, token: int,
		sites: Sites, site: Vector2i) -> StringName:
	"""Use a single actual retained image for both generic and exact site-scoped composition."""
	var code: StringName = _begin_query(out)
	if code != &"":
		return code
	code = _query_refusal(bounds, token)
	if code == &"" and ((sites == null) != (site == NULL_REF)):
		code = &"WORLD_COMPOSITION_SITE_SCOPE"
	if code == &"":
		code = _compose(bounds, out, token, sites, site)
	return _finish_query(out, code)


func phase_plan_row_limit(owner: Owner, token: int) -> int:
	"""Reserve the entire simultaneous contact-plan and composed-survey peak before creating a plan."""
	return mini(PHASE_ROW_LIMIT, _domain._regions) if owner == _actual_owner() \
		and binding_refusal() == &"" and _budget.covers(token, Budget.COLD_BYTES) else 0


func phase_snapshot_into(owner: Owner, sites: Sites, site: Vector2i, operation: int,
		stage: int, room: Vector2i, plan: Space.Plan, out: Space.Snapshot, token: int) -> StringName:
	"""Survey the full actual cube and checked contact extents without retaining immutable base dirt."""
	var code: StringName = _begin_query(out)
	if code != &"":
		return code
	var limit: int = phase_plan_row_limit(owner, token)
	if limit < 1:
		return _finish_query(out, REFUSE_BUDGET)
	code = _phase_scope_refusal(sites, site, operation, stage, room, plan)
	if code == &"":
		code = Authority.phase_plan_bounds_refusal(_domain, plan, limit)
	if code == &"" and not _budget.covers(token, Budget.COLD_BYTES):
		code = REFUSE_BUDGET
	if code == &"":
		var bounds: PackedInt32Array = _phase_bounds(sites, site, plan)
		code = _query_refusal(bounds, token)
		if code == &"" and not _spend(2 * limit):
			code = REFUSE_CAPACITY
		if code == &"":
			code = _compose(bounds, out, token, sites, site)
	if code == &"" and not _budget.covers(token, Budget.COLD_BYTES):
		code = REFUSE_BUDGET
	return _finish_query(out, code)


func _phase_scope_refusal(sites: Sites, site: Vector2i, operation: int, stage: int,
		room: Vector2i, plan: Space.Plan) -> StringName:
	"""Caller Room/revision/operation cannot enlarge the actual physical owner's claim exemption."""
	if sites == null or not sites.is_live_site(site) or sites.room_of(site) != room \
			or sources().construction_owner() != sites.construction_owner() \
			or sites.construction_owner().excavation_authority() != sites \
			or not Contract.valid_operation(operation) or stage < Contract.STAGE_ADMIT \
			or stage > Contract.STAGE_WORK or plan == null or plan.owner_ref != room \
			or plan.expected_revision != _actual_owner().revision() \
			or plan.owner_revision < 1 or plan.owner_revision != _actual_owner().source_revision(room):
		return &"WORLD_COMPOSITION_SITE_SCOPE"
	return &""


func _phase_bounds(sites: Sites, site: Vector2i, plan: Space.Plan) -> PackedInt32Array:
	"""Union target, support, body approach and productive reach bounds after complete table validation."""
	var bounds: PackedInt32Array = Space.quantum_box(_domain, sites.origin_of(site))
	if bounds.is_empty():
		return bounds
	for rows: Space.Volumes in [plan.volumes, plan.contacts.approach, plan.contacts.reach]:
		for row: int in rows.role.size():
			var box: PackedInt32Array = rows.box_at(row)
			for axis: int in 3:
				bounds[axis] = mini(bounds[axis], box[axis])
				bounds[axis + 3] = maxi(bounds[axis + 3], box[axis + 3])
	return bounds


func _query_refusal(bounds: PackedInt32Array, token: int) -> StringName:
	"""Prove the exact borrowed lease before the first owner snapshot or transient fragment copy."""
	var code: StringName = binding_refusal()
	if code != &"":
		return code
	if not Space.valid_box(bounds) or not Space.contains_box(_domain._bounds, bounds):
		return REFUSE_BOUNDS
	if not _budget.covers(token, COMPOSITION_BYTES):
		return REFUSE_BUDGET
	_remaining = _domain._checks
	_retained_rows = 0
	return &"" if _spend(SNAPSHOT_SCAN_CHECKS + WORLD_LOOKUP_CHECKS
		+ Terrain.natural_survey_checks(bounds)) else REFUSE_CAPACITY


func _compose(bounds: PackedInt32Array, out: Space.Snapshot, token: int,
		sites: Sites = null, site: Vector2i = NULL_REF) -> StringName:
	"""Keep one real source image, one finite natural image and the output; no hidden third snapshot."""
	var retained: Space.Snapshot = Space.Snapshot.new()
	var natural: Space.Volumes = Space.Volumes.new()
	var room: Vector2i = sites.room_of(site) if sites != null else NULL_REF
	var project: Vector2i = sites.project_of(site) if sites != null else NULL_REF
	var code: StringName = _actual_owner().snapshot_into(retained) if sites == null \
		else _actual_owner().snapshot_for_site_into(retained, sites, site)
	if code == &"" and not _budget.covers(token, COMPOSITION_BYTES):
		return REFUSE_BUDGET
	if code == &"":
		code = _terrain.natural_survey_into(bounds, NATURAL_ROW_LIMIT, natural, token)
	if code == &"" and not _budget.covers(token, COMPOSITION_BYTES):
		return REFUSE_BUDGET
	if code == &"":
		code = _copy_retained(bounds, retained, out)
	if code == &"":
		code = _append_natural(natural, out.volumes)
	if code == &"":
		code = _current_sources_refusal(retained)
	if code == &"" and sites != null:
		code = _site_still_current(sites, site, room, project)
	if code == &"" and not _budget.covers(token, COMPOSITION_BYTES):
		return REFUSE_BUDGET
	if code == &"":
		out.version = retained.version
		out.world_ref = retained.world_ref
		out.revision = retained.revision
		out.live_refs = retained.live_refs.duplicate()
		out.live_revisions = retained.live_revisions.duplicate()
	return code


func _site_still_current(sites: Sites, site: Vector2i, room: Vector2i, project: Vector2i) -> StringName:
	"""Site retirement, Room ownership or project replacement cannot reuse an earlier marker exemption."""
	return &"" if sites.construction_owner() == sources().construction_owner() \
		and sites.construction_owner().excavation_authority() == sites and sites.is_live_site(site) \
		and sites.room_of(site) == room and sites.project_of(site) == project \
		else &"WORLD_COMPOSITION_SITE_CHANGED"


func _copy_retained(bounds: PackedInt32Array, retained: Space.Snapshot, out: Space.Snapshot) -> StringName:
	"""All actual clipped claims and blockers survive with their original full source identity."""
	if retained.volumes.role.size() > Budget.REGION_CAPACITY \
			or retained.live_revisions.size() > Budget.SOURCE_CAPACITY:
		return REFUSE_CAPACITY
	for row: int in retained.volumes.role.size():
		if not _spend():
			return REFUSE_CAPACITY
		if _clip_box(retained.volumes.box_at(row), bounds, _clip):
			var code: StringName = _append_row(out.volumes, _clip, retained.volumes, row)
			if code != &"":
				return code
	_retained_rows = out.volumes.role.size()
	return &""


func _append_natural(natural: Space.Volumes, out: Space.Volumes) -> StringName:
	"""Never let original substrate fill a retained void or erase its owner/unfinished state."""
	for row: int in natural.role.size():
		_fragments.clear()
		if not _append_fragment(_fragments, natural.box_at(row)):
			return REFUSE_CAPACITY
		for other: int in _retained_rows:
			if not _spend():
				return REFUSE_CAPACITY
			if not _suppresses_natural(natural.role[row], out.role[other]):
				continue
			var code: StringName = _subtract_retained(out.box_at(other))
			if code != &"":
				return code
			if _fragments.is_empty():
				break
		for box: PackedInt32Array in _fragments:
			var code: StringName = _append_row(out, box, natural, row)
			if code != &"":
				return code
	return &""


func _subtract_retained(cover: PackedInt32Array) -> StringName:
	"""Alternate two finite work lists, releasing the old fragments before reusing their list."""
	_next_fragments.clear()
	for box: PackedInt32Array in _fragments:
		if not _spend() or not _subtract_box(box, cover, _next_fragments):
			return REFUSE_CAPACITY
	_fragments.clear()
	var previous: Array[PackedInt32Array] = _fragments
	_fragments = _next_fragments
	_next_fragments = previous
	return &""


func _subtract_box(box: PackedInt32Array, cover: PackedInt32Array,
		out: Array[PackedInt32Array]) -> bool:
	"""Partition into at most six disjoint half-open slabs; never fill holes with a bounding box."""
	if not _clip_box(box, cover, _intersection):
		return _append_fragment(out, box)
	var center: PackedInt32Array = box.duplicate()
	for axis: int in 3:
		if center[axis] < _intersection[axis]:
			var lower: PackedInt32Array = center.duplicate()
			lower[axis + 3] = _intersection[axis]
			if not _append_fragment(out, lower):
				return false
			center[axis] = _intersection[axis]
		if center[axis + 3] > _intersection[axis + 3]:
			var upper: PackedInt32Array = center.duplicate()
			upper[axis] = _intersection[axis + 3]
			if not _append_fragment(out, upper):
				return false
			center[axis + 3] = _intersection[axis + 3]
	return true


func _append_fragment(out: Array[PackedInt32Array], box: PackedInt32Array) -> bool:
	"""Bound both packed fragment payload and work before any new retained copy."""
	if not _spend() or out.size() >= FRAGMENT_LIMIT:
		return false
	out.append(box.duplicate())
	return true


func _append_row(out: Space.Volumes, box: PackedInt32Array, source: Space.Volumes, row: int) -> StringName:
	"""Preserve source role/level/full generation/revision, refusing before capacity growth."""
	if not _spend() or out.role.size() >= mini(COMPOSED_ROW_LIMIT, _domain._regions):
		return REFUSE_CAPACITY
	return &"" if out.append(box, source.role[row], source.level[row], source.ref_at(row),
		source.owner_revision[row]) else REFUSE_CAPACITY


func _current_sources_refusal(snapshot: Space.Snapshot) -> StringName:
	"""Recheck actual source/claim truth in one finite owner scan, with no second snapshot or pair lookup."""
	var code: StringName = binding_refusal()
	if code != &"":
		return code
	return _actual_owner().snapshot_revision_refusal(snapshot.revision)


func _actual_owner() -> Owner:
	"""A weak back-reference cannot extend an old World after its actual composition is gone."""
	return _owner.get_ref() as Owner if _owner != null else null


func _spend(amount: int = 1) -> bool:
	"""Keep clipping/subtraction/source observations inside the domain's unchanged cold-work ceiling."""
	if amount < 0 or _remaining < amount:
		return false
	_remaining -= amount
	return true


static func _suppresses_natural(natural_role: int, retained_role: int) -> bool:
	"""Actual material history wins; reservations/supports/occupants alone never claim a free excavation."""
	return retained_role == Space.DRY_SOLID or retained_role == Space.SUPPORTED_VOID \
		or retained_role == Space.UNFINISHED or retained_role == Space.WATER \
		or retained_role == Space.OPENABLE_SHELL \
		or (natural_role == Space.FLOOR_DATUM and retained_role == Space.FLOOR_DATUM)


static func _clip_box(first: PackedInt32Array, second: PackedInt32Array, out: PackedInt32Array) -> bool:
	"""Write exact integer intersection into caller scratch; zero-width face contact is not overlap."""
	for axis: int in 3:
		out[axis] = maxi(first[axis], second[axis])
		out[axis + 3] = mini(first[axis + 3], second[axis + 3])
		if out[axis] >= out[axis + 3]:
			return false
	return true


static func _clear_snapshot(out: Space.Snapshot) -> void:
	"""A refused or consumed observation has no world/revision or remaining packed output prefix."""
	out.version = Space.VERSION
	out.world_ref = NULL_REF
	out.revision = 0
	out.live_refs.clear()
	out.live_revisions.clear()
	if out.volumes == null:
		return
	out.volumes.lo_x.clear()
	out.volumes.lo_y.clear()
	out.volumes.lo_z.clear()
	out.volumes.hi_x.clear()
	out.volumes.hi_y.clear()
	out.volumes.hi_z.clear()
	out.volumes.role.clear()
	out.volumes.level.clear()
	out.volumes.owner_slot.clear()
	out.volumes.owner_generation.clear()
	out.volumes.owner_revision.clear()
