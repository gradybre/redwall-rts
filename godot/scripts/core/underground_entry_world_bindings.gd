extends "res://scripts/core/underground_world_bindings.gd"
## Actual immutable entry episodes composed with the existing World survey and one shared Contacts packet.
## No Site-to-Placement map, paid ledger, source certificate or companion permission is invented here.

const PhaseContacts := preload("res://scripts/core/underground_connector_contacts.gd")
const EntrySource := preload("res://scripts/core/underground_entry_frontier.gd")
const EntryPlacements := preload("res://scripts/core/underground_connector_placements.gd")
const EntryProfiles := preload("res://scripts/core/underground_profiles.gd")
const ENTRY_CONTROL_BYTES: int = 2048
const ENTRY_REFUSE_BINDING: StringName = &"ENTRY_PHASE_BINDING"
const ENTRY_REFUSE_SCOPE: StringName = &"ENTRY_PHASE_SCOPE"
const ENTRY_REFUSE_SOURCE: StringName = &"ENTRY_PHASE_SOURCE"
const ENTRY_REFUSE_CAPACITY: StringName = &"ENTRY_PHASE_CAPACITY"
const ENTRY_REFUSE_PLAN: StringName = &"ENTRY_PHASE_PLAN"
const ENTRY_REFUSE_BUSY: StringName = &"ENTRY_PHASE_REENTRY"
const ENTRY_REFUSE_COMPANION: StringName = &"ENTRY_PHASE_COMPANION_UNBOUND"

var _entry_contacts: WeakRef = null
var _entry_reading: bool = false
var _entry_poisoned: bool = false
var _entry_placement: Vector2i = NULL_REF
var _entry_site: Vector2i = NULL_REF
var _entry_room: Vector2i = NULL_REF
var _entry_project: Vector2i = NULL_REF
var _entry_contact_ref: Vector2i = NULL_REF
var _entry_contact_revision: int = 0
var _entry_operation: int = -1
var _entry_stage: int = -1
var _entry_episode: int = -1
var _entry_revision: int = 0
var _entry_payload: int = 0
var _entry_cold_token: int = 0
var _entry_remaining: int = 0
var _entry_origin: Vector3i = Vector3i.ZERO
var _entry_point: Vector3i = Vector3i.ZERO
var _entry_box: PackedInt32Array = PackedInt32Array()
var _entry_air: PackedInt32Array = PackedInt32Array()
var _entry_reach: PackedInt32Array = PackedInt32Array()


func bind_phase_contacts(actual: PhaseContacts, controls: int) -> StringName:
	"""Once-bound exact owners share the admitted Contacts packet; no new per-worker or per-Site storage exists."""
	if _entry_contacts != null or _entry_reading or controls != ENTRY_CONTROL_BYTES:
		return ENTRY_REFUSE_BINDING
	if _entry_binding_leaf(actual) != &"" or _budget._token != 0 or _budget._used != 0 \
			or _phase_token != 0 or actual._placements._space._stage_token != 0 \
			or actual._placements._locations._token != 0 or actual._placements._routes._token != 0:
		return ENTRY_REFUSE_BINDING
	var authority: Authority = actual._sites._spatial() as Authority
	var code: StringName = actual._placements.bind_phase_authority(authority)
	if code != &"": return code
	_entry_box.resize(6)
	_entry_air.resize(6)
	_entry_reach.resize(6)
	_entry_contacts = weakref(actual)
	return &""


func _entry_actual() -> PhaseContacts:
	"""Borrow strongly only for the current synchronous call; no owner reference cycle is retained."""
	return _entry_contacts.get_ref() as PhaseContacts if _entry_contacts != null else null


func _entry_binding_leaf(actual: PhaseContacts) -> StringName:
	"""Read exact configured owners directly after all observers, including the reciprocal real phase authority."""
	if actual == null or not actual._configured or actual._binding_leaf() != &"" or _domain == null \
			or _owner == null or _source_reader == null or _budget == null:
		return ENTRY_REFUSE_BINDING
	var placements: EntryPlacements = actual._placements
	var authority: Authority = actual._sites._spatial() as Authority
	if placements._space != _owner.get_ref() or placements._sources != _source_reader.get_ref() \
			or placements._budget != _budget or placements._world != _domain._world \
			or actual._terrain != _terrain or _terrain._world != _world \
			or authority == null or authority._bindings != self or authority._owner != placements._space \
			or authority._construction != placements._construction or authority._physical() != actual._sites:
		return ENTRY_REFUSE_BINDING
	var domain: Space.Domain = placements._space._domain
	return &"" if domain._world == _domain._world and domain._bounds == _domain._bounds \
		and domain._datum == _domain._datum and domain._min_quantum == _domain._min_quantum \
		and domain._size_quanta == _domain._size_quanta else ENTRY_REFUSE_BINDING


func qualification_revision() -> int:
	"""The exact immutable tuple is checked afresh; same geometry with a replaced source cannot retain permission."""
	var actual: PhaseContacts = _entry_actual()
	return actual._frontier._header[0] if _entry_binding_leaf(actual) == &"" else 0


func _entry_enter() -> bool:
	"""Nested observations poison the outer operation without replacing its original scope or cold lease."""
	if _entry_reading:
		_entry_poisoned = true
		return false
	_entry_reading = true
	_entry_poisoned = false
	return true


func _entry_leave(code: StringName) -> StringName:
	"""No reentrant observer may turn a failed original operation into successful phase permission."""
	_entry_reading = false
	return ENTRY_REFUSE_BUSY if _entry_poisoned else code


func _entry_spend(amount: int) -> bool:
	"""Each candidate Placement, episode and source primitive spends from one finite operation allowance."""
	if amount < 0 or amount > _entry_remaining:
		return false
	_entry_remaining -= amount
	return true


func _entry_pin(actual: PhaseContacts, site: Vector2i, operation: int, stage: int, cold: int) -> StringName:
	"""Pin full original live Site and immutable source before any public source or endpoint observer."""
	if _entry_binding_leaf(actual) != &"" or operation < Contract.OP_BRACE or operation > Contract.OP_FINISH \
			or stage < PhaseContacts.PHASE_CONTACT_ONLY or stage > Contract.STAGE_WORK:
		return ENTRY_REFUSE_SCOPE
	var sites: Sites = actual._sites
	if not sites.is_live_site(site): return ENTRY_REFUSE_SCOPE
	if _phase_token != 0 and (cold != _phase_token or site != _phase_site \
			or operation != _phase_operation or stage != _phase_stage): return ENTRY_REFUSE_SCOPE
	_entry_site = site
	_entry_room = Vector2i(sites._room_slot[site.x], sites._room_generation[site.x])
	_entry_project = Vector2i(sites._project_slot[site.x], sites._project_generation[site.x])
	_entry_operation = operation
	_entry_stage = stage
	_entry_revision = actual._frontier._header[0]
	_entry_cold_token = cold
	_entry_origin = sites.origin_of(site)
	_entry_remaining = _domain._checks
	_entry_placement = NULL_REF
	_entry_episode = -1
	var code: StringName = _entry_find(actual)
	if code == &"":
		_entry_payload = actual._placements._get64(actual._placements._live, EntryPlacements.PAYLOAD_REVISION, _entry_placement.x)
	return _entry_leaf(actual) if code == &"" else code


func _entry_find(actual: PhaseContacts) -> StringName:
	"""Select exactly one real Placement/episode; duplicate applicability and finite-work exhaustion both refuse."""
	var placements: EntryPlacements = actual._placements
	var source: EntrySource = actual._frontier
	for row: int in placements._capacity:
		if not _entry_spend(16): return ENTRY_REFUSE_CAPACITY
		if placements._live.present[row] != 1 or placements._pair(placements._live, EntryPlacements.ROOM_SLOT, row) != _entry_room:
			continue
		if placements._pair(placements._live, EntryPlacements.PROJECT_SLOT, row) != NULL_REF:
			continue
		for episode: int in source._header[8 + EntrySource.EPISODE]:
			if not _entry_spend(64): return ENTRY_REFUSE_CAPACITY
			if not _entry_episode_matches(actual, row, episode): continue
			if _entry_placement != NULL_REF: return ENTRY_REFUSE_SCOPE
			_entry_placement = Vector2i(row, placements._get32(placements._live, EntryPlacements.GENERATION, row))
			_entry_episode = episode
	return &"" if _entry_placement != NULL_REF else ENTRY_REFUSE_SCOPE


func _entry_episode_matches(actual: PhaseContacts, row: int, episode: int) -> bool:
	"""Invert the exact Placement quarter turn without snapping or converting full cubes to point samples."""
	var placements: EntryPlacements = actual._placements
	var source: EntrySource = actual._frontier
	if (source._field(EntrySource.EPISODE, episode, 6) & (1 << (_entry_operation - 1))) == 0 \
			or source._field(EntrySource.EPISODE, episode, 7) != placements._get32(placements._live, EntryPlacements.INSTALLED, row):
		return false
	var x: int = int(_entry_origin.x) - placements._get32(placements._live, EntryPlacements.X, row)
	var y: int = int(_entry_origin.y) - placements._get32(placements._live, EntryPlacements.X + 1, row)
	var z: int = int(_entry_origin.z) - placements._get32(placements._live, EntryPlacements.X + 2, row)
	var rotation: int = placements._get32(placements._live, EntryPlacements.ROTATION, row)
	var local_x: int = x if rotation == 0 else z if rotation == 1 else -x - 1024 if rotation == 2 else -z - 1024
	var local_z: int = z if rotation == 0 else -x - 1024 if rotation == 1 else -z - 1024 if rotation == 2 else x
	return rotation >= 0 and rotation <= 3 and local_x >= source._field(EntrySource.EPISODE, episode, 0) \
		and y >= source._field(EntrySource.EPISODE, episode, 1) and local_z >= source._field(EntrySource.EPISODE, episode, 2) \
		and local_x + 1024 <= source._field(EntrySource.EPISODE, episode, 3) \
		and y + 1024 <= source._field(EntrySource.EPISODE, episode, 4) \
		and local_z + 1024 <= source._field(EntrySource.EPISODE, episode, 5)


func _entry_leaf(actual: PhaseContacts) -> StringName:
	"""Original full refs, prefix, source and exact lease are reattested without any public observation callback."""
	if _entry_binding_leaf(actual) != &"" or _entry_poisoned or _entry_revision != actual._frontier._header[0]:
		return ENTRY_REFUSE_SOURCE
	var sites: Sites = actual._sites
	var placements: EntryPlacements = actual._placements
	if not _entry_site_leaf(sites) or not placements._is_live(placements._live, _entry_placement) \
			or not actual._frontier._valid_row(EntrySource.EPISODE, _entry_episode) \
			or placements._get64(placements._live, EntryPlacements.PAYLOAD_REVISION, _entry_placement.x) != _entry_payload \
			or placements._pair(placements._live, EntryPlacements.ROOM_SLOT, _entry_placement.x) != _entry_room \
			or placements._pair(placements._live, EntryPlacements.PROJECT_SLOT, _entry_placement.x) != NULL_REF \
			or Vector2i(sites._room_slot[_entry_site.x], sites._room_generation[_entry_site.x]) != _entry_room \
			or Vector2i(sites._project_slot[_entry_site.x], sites._project_generation[_entry_site.x]) != _entry_project \
			or not _entry_episode_matches(actual, _entry_placement.x, _entry_episode):
		return ENTRY_REFUSE_SCOPE
	if _entry_cold_token != 0 and (_entry_cold_token != _phase_token or _entry_site != _phase_site \
			or _entry_operation != _phase_operation or _entry_stage != _phase_stage or _entry_room != _phase_room \
			or _entry_project != _phase_project or not _budget.covers(_entry_cold_token, Budget.COLD_BYTES)):
		return REFUSE_BUDGET
	return placements._placement_leaf(placements._live, _entry_placement.x)


func _entry_site_leaf(sites: Sites) -> bool:
	"""Decode the actual retained key directly; no public Site observation follows the final source attestation."""
	if _entry_site.y != Sites.SITE_GENERATION or _entry_site.x < 0 or _entry_site.x >= sites._count \
			or sites._present[_entry_site.x] != 1:
		return false
	var key: int = sites._site_key[_entry_site.x]
	if key < 0: return false
	var x: int = key % sites._domain.size_quanta.x
	@warning_ignore("integer_division") var rest: int = key / sites._domain.size_quanta.x
	var z: int = rest % sites._domain.size_quanta.z
	@warning_ignore("integer_division") var y: int = rest / sites._domain.size_quanta.z
	return int(sites._domain.datum_u.x) + (x + int(sites._domain.minimum_quantum.x)) * 1024 == _entry_origin.x \
		and int(sites._domain.datum_u.y) + (y + int(sites._domain.minimum_quantum.y)) * 1024 == _entry_origin.y \
		and int(sites._domain.datum_u.z) + (z + int(sites._domain.minimum_quantum.z)) * 1024 == _entry_origin.z


func phase_plan_into(site: Vector2i, operation: int, stage: int, room: Vector2i,
		volume_rows_limit: int, out: Space.Plan) -> StringName:
	"""Observe actual whole source motion under the original lease before allocating caller-owned plan rows."""
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	var actual: PhaseContacts = _entry_actual()
	var code: StringName = _entry_pin(actual, site, operation, stage, _phase_token)
	if code == &"" and (room != _entry_room or _phase_token <= 0 or out == null): code = ENTRY_REFUSE_SCOPE
	if code == &"":
		code = actual.phase_observe_refusal(_entry_placement, site, _entry_episode, operation, stage, _phase_token)
	if code == &"": code = _entry_leaf(actual)
	if code == &"": code = actual.phase_final_leaf_refusal(_entry_placement, site, operation, stage)
	if code == &"": code = _entry_plan_refusal(actual, volume_rows_limit, out)
	if code == &"": code = _entry_write_plan(actual, out)
	return _entry_leave(code)


func _entry_plan_refusal(actual: PhaseContacts, limit: int, out: Space.Plan) -> StringName:
	"""Capacity and exact empty output precede every copied row; all semantic residuals were proved by Contacts."""
	if out.contacts == null or not _entry_table_shape(out.volumes, 0) \
			or not _entry_table_shape(out.contacts.approach, 0) or not _entry_table_shape(out.contacts.reach, 0) \
			or not out.contacts.profile_id.is_empty() or not out.contacts.profile_revision.is_empty() \
			or not out.contacts.work_xyz.is_empty() or not _entry_plan_extras_empty(out) \
			or out.expected_revision != 0 or out.owner_ref != NULL_REF or out.owner_revision != 0:
		return ENTRY_REFUSE_PLAN
	var code: StringName = _entry_read_point(actual)
	if code != &"": return code
	code = _entry_select_contact_owner(actual)
	if code != &"": return code
	var rows: int = 0
	var approaches: int = 0
	for ordinal: int in actual._descriptor.box_count:
		if not actual._read_profile_box(ordinal, actual._box): return ENTRY_REFUSE_CAPACITY
		var role: int = actual._box.role
		if role == EntryProfiles.CONTACT_POINT or role == EntryProfiles.CONTACT_PATCH: continue
		rows += 1
		code = actual._profile_bounds(actual._box, _entry_box)
		if code != &"": return code
		if _entry_has_air_contact(actual, role):
			approaches += 1
			if not _entry_contact_bounds(actual): return ENTRY_REFUSE_PLAN
	if approaches < 1 or rows + 2 * approaches > limit or limit > PHASE_ROW_LIMIT \
			or actual._fragments.remaining < actual._descriptor.box_count:
		return ENTRY_REFUSE_CAPACITY
	return _entry_leaf(actual)


func _entry_read_point(actual: PhaseContacts) -> StringName:
	"""Translate the unique exact authored anchor using wide integers before narrowing to world coordinates."""
	var found: int = 0
	for ordinal: int in actual._descriptor.box_count:
		if not actual._read_profile_box(ordinal, actual._box): return ENTRY_REFUSE_CAPACITY
		if actual._box.role != EntryProfiles.CONTACT_POINT: continue
		found += 1
		for axis: int in 3:
			var point: int = int(actual._location.point[axis]) + int(actual._box.low[axis])
			if point < _domain._bounds[axis] or point >= _domain._bounds[axis + 3]: return ENTRY_REFUSE_PLAN
			_entry_point[axis] = point
	return &"" if found == 1 else ENTRY_REFUSE_PLAN


static func _entry_table_shape(rows: Space.Volumes, count: int) -> bool:
	"""Validate every packed column without creating a temporary row, column list or copy."""
	return rows != null and rows.role.size() == count and rows.level.size() == count \
		and rows.lo_x.size() == count and rows.lo_y.size() == count and rows.lo_z.size() == count \
		and rows.hi_x.size() == count and rows.hi_y.size() == count and rows.hi_z.size() == count \
		and rows.owner_slot.size() == count and rows.owner_generation.size() == count and rows.owner_revision.size() == count


static func _entry_plan_extras_empty(plan: Space.Plan) -> bool:
	"""Excavation episode plans never carry connector endpoints, extra cut keys or a substituted Catalog selection."""
	return plan.cuts_xyz.is_empty() and plan.cut_contacts.is_empty() and plan.endpoints_xyz.is_empty() \
		and plan.endpoint_levels.is_empty() and plan.endpoint_refs.is_empty() and plan.endpoint_revisions.is_empty() \
		and plan.catalog_key == &"" and plan.catalog_revision == 0


static func _entry_is_approach(role: int) -> bool:
	"""Productive tool motion is surveyed independently; it is never relabelled an already-clear body approach."""
	return role == EntryProfiles.BODY_HELD_LOAD or role == EntryProfiles.WORK_APPROACH or role == EntryProfiles.TURN_RECOVERY


func _entry_has_air_contact(actual: PhaseContacts, role: int) -> bool:
	"""Contacts already proves complete stance residuals; only above-plane primitives additionally describe air approach."""
	return _entry_is_approach(role) and _entry_box[4] > actual._location.point.y


func _entry_select_contact_owner(actual: PhaseContacts) -> StringName:
	"""Only a verified assigned worker already registered in actual Space may own its occupied approach."""
	var owner: Owner = actual._placements._space
	_entry_contact_ref = _entry_room
	_entry_contact_revision = owner._r_owner_revision[actual._frame[5]]
	if not actual._phase_needs_worker(): return &""
	var job: int = actual._job_row(actual._primary_job)
	if job < 0: return ENTRY_REFUSE_SCOPE
	var worker: Vector2i = Vector2i(actual._placements._jobs._worker_slot[job], actual._placements._jobs._worker_generation[job])
	if not _entry_spend(owner._source_capacity): return ENTRY_REFUSE_CAPACITY
	var row: int = owner._find_source(worker, false)
	if row >= 0:
		_entry_contact_ref = worker
		_entry_contact_revision = owner._o_revision[row]
	return &""


func _entry_write_plan(actual: PhaseContacts, out: Space.Plan) -> StringName:
	"""Preserve each complete source primitive before deriving its independently qualified air intersection."""
	var owner: Owner = actual._placements._space
	out.expected_revision = owner._header[17]
	out.owner_ref = _entry_room
	out.owner_revision = owner._r_owner_revision[actual._frame[5]]
	for ordinal: int in actual._descriptor.box_count:
		if not actual._read_profile_box(ordinal, actual._box): return ENTRY_REFUSE_CAPACITY
		if actual._box.role == EntryProfiles.CONTACT_POINT or actual._box.role == EntryProfiles.CONTACT_PATCH: continue
		var code: StringName = actual._profile_bounds(actual._box, _entry_box)
		if code != &"": return code
		var role: int = Space.SUPPORT_REQUIRED if actual._box.role == EntryProfiles.STANCE_SUPPORT else Space.ENVELOPE
		_entry_append_row(out.volumes, _entry_box, role, actual._location.level, _entry_room, out.owner_revision)
		if _entry_has_air_contact(actual, actual._box.role): _entry_append_contact(actual, out)
	return &""


func _entry_contact_bounds(actual: PhaseContacts) -> bool:
	"""Only actual qualified endpoint air is approach; a disjoint or zero-volume primitive cannot become a contact."""
	for axis: int in 3:
		_entry_air[axis] = maxi(_entry_box[axis], actual._location.envelope[axis])
		_entry_air[axis + 3] = mini(_entry_box[axis + 3], actual._location.envelope[axis + 3])
		if _entry_air[axis] >= _entry_air[axis + 3]: return false
		_entry_reach[axis] = mini(_entry_air[axis], _entry_point[axis])
		_entry_reach[axis + 3] = maxi(_entry_air[axis + 3], int(_entry_point[axis]) + 1)
	return true


func _entry_append_contact(actual: PhaseContacts, out: Space.Plan) -> void:
	"""Write only preflighted positive extents; the full negative residual remains in the preceding volume row."""
	var valid: bool = _entry_contact_bounds(actual)
	assert(valid, "Exact preflighted contact geometry cannot change without an observer")
	_entry_append_row(out.contacts.approach, _entry_air, Space.ENVELOPE, actual._location.level, _entry_contact_ref, _entry_contact_revision)
	_entry_append_row(out.contacts.reach, _entry_reach, Space.ENVELOPE, actual._location.level, _entry_contact_ref, _entry_contact_revision)
	out.contacts.profile_id.append(actual._station[5])
	out.contacts.profile_revision.append(actual._profile_revision)
	out.contacts.work_xyz.append(_entry_point.x)
	out.contacts.work_xyz.append(_entry_point.y)
	out.contacts.work_xyz.append(_entry_point.z)


static func _entry_append_row(rows: Space.Volumes, box: PackedInt32Array, role: int,
		level: int, owner: Vector2i, revision: int) -> void:
	"""A direct concrete packed write introduces no caller-overridable append after source preflight."""
	rows.lo_x.append(box[0]); rows.lo_y.append(box[1]); rows.lo_z.append(box[2])
	rows.hi_x.append(box[3]); rows.hi_y.append(box[4]); rows.hi_z.append(box[5])
	rows.role.append(role); rows.level.append(level)
	rows.owner_slot.append(owner.x); rows.owner_generation.append(owner.y); rows.owner_revision.append(revision)


func phase_qualification_refusal(domain: Space.Domain, snapshot: Space.Snapshot,
		plan: Space.Plan, site: Vector2i, operation: int, stage: int) -> StringName:
	"""A copied plan cannot substitute another source; final actual full motion and lifetime remain mandatory."""
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	var actual: PhaseContacts = _entry_actual()
	var code: StringName = _entry_context(site, operation, stage)
	if code == &"" and (domain != _domain and not _entry_same_domain(domain)): code = ENTRY_REFUSE_SCOPE
	if code == &"" and (snapshot == null or snapshot.revision != _phase_geometry_revision \
		or snapshot.world_ref != _domain._world or plan == null or plan.owner_ref != _entry_room \
		or plan.expected_revision != snapshot.revision): code = ENTRY_REFUSE_PLAN
	if code == &"": code = actual.phase_final_observation_refusal(_entry_placement, site, operation, stage)
	if code == &"": code = _entry_leaf(actual)
	if code == &"": code = actual.phase_final_leaf_refusal(_entry_placement, site, operation, stage)
	if code == &"": code = _entry_plan_matches(actual, plan)
	return _entry_leave(code)


func _entry_plan_matches(actual: PhaseContacts, plan: Space.Plan) -> StringName:
	"""Compare every copied geometry row to immutable source without allocating another plan or hiding residuals."""
	if not _entry_plan_shape_matches(actual, plan): return ENTRY_REFUSE_PLAN
	var code: StringName = _entry_read_point(actual)
	if code != &"": return code
	code = _entry_select_contact_owner(actual)
	if code != &"": return code
	var row: int = 0
	var contact: int = 0
	for ordinal: int in actual._descriptor.box_count:
		if not actual._read_profile_box(ordinal, actual._box): return ENTRY_REFUSE_CAPACITY
		if actual._box.role == EntryProfiles.CONTACT_POINT or actual._box.role == EntryProfiles.CONTACT_PATCH: continue
		code = actual._profile_bounds(actual._box, _entry_box)
		if code != &"": return code
		var role: int = Space.SUPPORT_REQUIRED if actual._box.role == EntryProfiles.STANCE_SUPPORT else Space.ENVELOPE
		if not _entry_row_matches(plan.volumes, row, _entry_box, role, actual._location.level, _entry_room, plan.owner_revision):
			return ENTRY_REFUSE_PLAN
		row += 1
		if _entry_has_air_contact(actual, actual._box.role):
			if not _entry_contact_matches(actual, plan, contact): return ENTRY_REFUSE_PLAN
			contact += 1
	return &"" if row == plan.volumes.role.size() and contact == plan.contacts.profile_id.size() else ENTRY_REFUSE_PLAN


func _entry_plan_shape_matches(actual: PhaseContacts, plan: Space.Plan) -> bool:
	"""The complete exact copied packet has no unobserved table tail, owner revision or extra instruction."""
	if plan == null or plan.contacts == null or plan.volumes == null or not _entry_plan_extras_empty(plan) \
			or plan.owner_ref != _entry_room or plan.expected_revision != actual._placements._space._header[17] \
			or plan.owner_revision != actual._placements._space._r_owner_revision[actual._frame[5]]: return false
	var count: int = plan.contacts.profile_id.size()
	return _entry_table_shape(plan.volumes, plan.volumes.role.size()) \
		and _entry_table_shape(plan.contacts.approach, count) and _entry_table_shape(plan.contacts.reach, count) \
		and plan.contacts.profile_revision.size() == count and plan.contacts.work_xyz.size() == 3 * count


func _entry_row_matches(rows: Space.Volumes, row: int, box: PackedInt32Array, role: int,
		level: int, owner: Vector2i, revision: int) -> bool:
	"""Exact source row equality includes the full owner generation and every integer bound."""
	return row < rows.role.size() and rows.role[row] == role and rows.level[row] == level \
		and rows.lo_x[row] == box[0] and rows.lo_y[row] == box[1] and rows.lo_z[row] == box[2] \
		and rows.hi_x[row] == box[3] and rows.hi_y[row] == box[4] and rows.hi_z[row] == box[5] \
		and rows.owner_slot[row] == owner.x and rows.owner_generation[row] == owner.y \
		and rows.owner_revision[row] == revision


func _entry_contact_matches(actual: PhaseContacts, plan: Space.Plan, row: int) -> bool:
	"""Both semantic air and conservative face reach must equal the original source-selected work contact."""
	if row >= plan.contacts.profile_id.size() or not _entry_contact_bounds(actual): return false
	return _entry_row_matches(plan.contacts.approach, row, _entry_air, Space.ENVELOPE, actual._location.level, _entry_contact_ref, _entry_contact_revision) \
		and _entry_row_matches(plan.contacts.reach, row, _entry_reach, Space.ENVELOPE, actual._location.level, _entry_contact_ref, _entry_contact_revision) \
		and plan.contacts.profile_id[row] == actual._station[5] and plan.contacts.profile_revision[row] == actual._profile_revision \
		and plan.contacts.work_xyz[3 * row] == _entry_point.x and plan.contacts.work_xyz[3 * row + 1] == _entry_point.y \
		and plan.contacts.work_xyz[3 * row + 2] == _entry_point.z


func _entry_same_domain(other: Space.Domain) -> bool:
	"""Only the exact original integer World namespace can qualify a copied phase input."""
	return other != null and other._world == _domain._world and other._bounds == _domain._bounds \
		and other._datum == _domain._datum and other._min_quantum == _domain._min_quantum \
		and other._size_quanta == _domain._size_quanta and other._checks == _domain._checks


func _entry_context(site: Vector2i, operation: int, stage: int) -> StringName:
	"""A final callback consumes only the retained exact operation, never a new matching numeric token."""
	return &"" if site == _entry_site and operation == _entry_operation and stage == _entry_stage \
		and _entry_actual() != null else ENTRY_REFUSE_SCOPE


func _entry_contact_observation(actual: PhaseContacts, origin: Vector3i, operation: int,
		room: Vector2i, stage: int) -> StringName:
	"""Live queries derive source scope; post-seal output/refund checks consume only the original complete observation."""
	if _entry_binding_leaf(actual) != &"": return ENTRY_REFUSE_BINDING
	var site: Vector2i = actual._sites.site_at(origin)
	if _phase_token != 0:
		if site != _phase_site or operation != _phase_operation or room != _phase_room: return ENTRY_REFUSE_SCOPE
		stage = _phase_stage
	if actual._placements._space._stage_token != 0:
		return _entry_prepared_contact(actual, site, operation, room, stage)
	var code: StringName = _entry_pin(actual, site, operation, stage, _phase_token)
	if code == &"" and room != _entry_room: code = ENTRY_REFUSE_SCOPE
	if code == &"": code = actual.phase_observe_refusal(_entry_placement, site, _entry_episode, operation, stage, _phase_token)
	return _entry_leaf(actual) if code == &"" else code


func _entry_prepared_contact(actual: PhaseContacts, site: Vector2i, operation: int,
		room: Vector2i, stage: int) -> StringName:
	"""No prepared call may replace source selectors, endpoint payloads, Project identity or the original lease."""
	if room != _entry_room or not actual._valid or not actual._phase_mode: return ENTRY_REFUSE_SCOPE
	var code: StringName = _entry_final_context(site, operation, stage, _phase_token,
		actual._phase_space_token, actual._phase_companion_token)
	if code == &"": code = actual._retained_phase_scope(_entry_placement, site, operation, stage)
	return _entry_leaf(actual) if code == &"" else code


func material_refusal(origin: Vector3i, room: Vector2i, container: Vector2i, job: Vector2i) -> StringName:
	"""The selected existing storage and actual primary Job are mandatory for delivery and refund."""
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	var actual: PhaseContacts = _entry_actual()
	var site: Vector2i = actual._sites.site_at(origin) if actual != null else NULL_REF
	var operation: int = actual._sites._operation[site.x] if actual != null and actual._sites.is_live_site(site) else -1
	var code: StringName = _entry_contact_observation(actual, origin, operation, room, PhaseContacts.PHASE_CONTACT_ONLY)
	if code == &"": code = actual.phase_material_refusal(_entry_placement, site, operation, container, job)
	return _entry_leave(code)


func output_refusal(origin: Vector3i, operation: int, room: Vector2i, container: Vector2i,
		job: Vector2i, promotion_tile: int) -> StringName:
	"""Finite actual output capacity/claims remain Funding-owned; this proves the exact source-selected spatial contact."""
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	var actual: PhaseContacts = _entry_actual()
	var code: StringName = _entry_contact_observation(actual, origin, operation, room, PhaseContacts.PHASE_CONTACT_ONLY)
	if code == &"": code = actual.phase_output_refusal(_entry_placement, _entry_site, operation, container, job, promotion_tile)
	return _entry_leave(code)


func worker_refusal(origin: Vector3i, operation: int, room: Vector2i, job: Vector2i,
		worker: Vector2i, geometry_revision: int, source_revision: int) -> StringName:
	"""Fresh full worker/tool/load/occupancy facts are conjunctive with the original actual qualified Site scope."""
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	var actual: PhaseContacts = _entry_actual()
	var stage: int = _phase_stage if _phase_token > 0 else _entry_live_worker_stage(actual, origin, worker)
	var code: StringName = ENTRY_REFUSE_SOURCE
	if source_revision == qualification_revision() and actual != null and geometry_revision == actual._placements._space._header[17]:
		code = _entry_contact_observation(actual, origin, operation, room, stage)
	if code == &"": code = actual.phase_final_observation_refusal(_entry_placement, _entry_site, operation, stage)
	if code == &"": code = _entry_leaf(actual)
	if code == &"" and _phase_token == 0 and stage != _entry_live_worker_stage(actual, origin, worker):
		code = ENTRY_REFUSE_SCOPE
	if code == &"": code = actual.phase_worker_refusal(_entry_placement, _entry_site, operation, job, worker)
	if code == &"": code = actual.phase_final_leaf_refusal(_entry_placement, _entry_site, operation, stage)
	return _entry_leave(code)


func _entry_live_worker_stage(actual: PhaseContacts, origin: Vector3i, worker: Vector2i) -> int:
	"""Only an unfunded READY worker may prove contact before Sites registers it; paid work keeps its exact stage."""
	if _entry_binding_leaf(actual) != &"": return -2
	var site: Vector2i = actual._sites.site_at(origin)
	if not actual._sites.is_live_site(site): return -2
	var project: Vector2i = Vector2i(actual._sites._project_slot[site.x], actual._sites._project_generation[site.x])
	var row: int = actual._placements._construction._row_of(project)
	if row < 0: return -2
	if _entry_unregistered_ready_worker(actual, row, worker) or _entry_rebinding_worker(actual, site, row, worker):
		return PhaseContacts.PHASE_CONTACT_ONLY
	return Contract.STAGE_WORK if actual._placements._construction._work_begun[row] == 1 else Contract.STAGE_START


func _entry_unregistered_ready_worker(actual: PhaseContacts, row: int, worker: Vector2i) -> bool:
	"""No pending payment, paid receipt, pause or existing Site registration can borrow prospective contact scope."""
	var sites: Sites = actual._sites
	var construction: Construction = actual._placements._construction
	var resident: int = actual._placements._ids.get_typed_row(worker)
	return resident >= 0 and resident < sites._worker_site.size() and sites._worker_site[resident] == -1 \
		and sites._worker_generation[resident] == 0 and not sites._starting and sites._candidate_row == -1 \
		and sites._permit_project == NULL_REF and construction._phase[row] == Construction.PHASE_READY \
		and construction._paused[row] == 0 and construction._work_begun[row] == 0 \
		and (sites._funding._project_slot[row] != construction._ref_slot[row] \
			or sites._funding._project_generation[row] != construction._ref_generation[row])


func _entry_rebinding_worker(actual: PhaseContacts, site: Vector2i, row: int, worker: Vector2i) -> bool:
	"""ADR1225: a replacement for a crew that died or left proves contact prospectively, as an unfunded READY
	worker does, but only on an unpaused paid phase whose face has no registered worker at all; its productive
	ticks still require Sites' registration and the full paid stage."""
	var sites: Sites = actual._sites
	var construction: Construction = actual._placements._construction
	var resident: int = actual._placements._ids.get_typed_row(worker)
	return resident >= 0 and resident < sites._worker_site.size() and sites._worker_site[resident] == -1 \
		and sites._worker_generation[resident] == 0 and not sites._starting and sites._candidate_row == -1 \
		and sites._permit_project == NULL_REF and construction._work_begun[row] == 1 and construction._paused[row] == 0 \
		and sites._registered_worker_row(site.x) == Sites.NO_ROW


func phase_final_observation_refusal(site: Vector2i, operation: int, stage: int,
		cold_token: int, space_token: int, companion_token: int) -> StringName:
	"""Observers run only in the retained original phase; unknown prepared companion contexts never grant permission."""
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	var actual: PhaseContacts = _entry_actual()
	var code: StringName = _entry_final_context(site, operation, stage, cold_token, space_token, companion_token)
	if code == &"": code = actual.phase_final_observation_refusal(_entry_placement, site, operation, stage)
	if code == &"": code = _entry_leaf(actual)
	return _entry_leave(code)


func phase_final_leaf_refusal(site: Vector2i, operation: int, stage: int,
		cold_token: int, space_token: int, companion_token: int) -> StringName:
	"""Direct actual worker/source/lease facts are the final boundary; no observer follows them here."""
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	var actual: PhaseContacts = _entry_actual()
	var code: StringName = _entry_final_context(site, operation, stage, cold_token, space_token, companion_token)
	if code == &"": code = _entry_leaf(actual)
	if code == &"": code = actual.phase_final_leaf_refusal(_entry_placement, site, operation, stage)
	return _entry_leave(code)


func _entry_final_context(site: Vector2i, operation: int, stage: int,
		cold_token: int, space_token: int, companion_token: int) -> StringName:
	"""Compare original observed phase against the exact sealed companion context without another observation pass."""
	var code: StringName = _entry_context(site, operation, stage)
	if code != &"" or cold_token <= 0 or cold_token != _entry_cold_token or cold_token != _phase_token:
		return ENTRY_REFUSE_SCOPE
	var actual: PhaseContacts = _entry_actual()
	if space_token <= 0 or companion_token <= 0 or actual._phase_space_token != space_token \
			or actual._phase_companion_token != companion_token:
		return ENTRY_REFUSE_COMPANION
	return actual._prepared_phase_leaf(space_token, companion_token)


func prepare_companions(owner_token: int, site: Vector2i, operation: int,
		stage: int, room: Vector2i, _plan: Space.Plan) -> int:
	"""Refresh real existing companions after Space seal, retaining the single live Contacts observation."""
	if not _entry_enter(): return 0
	var actual: PhaseContacts = _entry_actual()
	var code: StringName = _entry_context(site, operation, stage)
	if code == &"" and room != _entry_room: code = ENTRY_REFUSE_SCOPE
	if code == &"": code = _entry_leaf(actual)
	var token: int = 0
	if code == &"":
		token = actual._placements.prepare_phase_refresh(actual._sites._spatial(), _entry_placement,
			site, operation, stage, room, owner_token, _phase_token)
		if token <= 0: code = ENTRY_REFUSE_COMPANION
	if code == &"":
		code = actual.bind_prepared_phase(_entry_placement, site, operation, stage, _phase_token, owner_token, token)
	if code == &"": code = _entry_leaf(actual)
	code = _entry_leave(code)
	if code != &"" and token > 0: actual._placements.discard_phase_refresh(token)
	return token if code == &"" else 0


func prepared_refusal(token: int) -> StringName:
	"""Complete all actual companion observers before the final original context/source proof."""
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	var actual: PhaseContacts = _entry_actual()
	var code: StringName = _entry_leaf(actual)
	if code == &"": code = actual._placements.phase_refresh_refusal(token)
	if code == &"": code = _entry_final_context(_entry_site, _entry_operation, _entry_stage,
		_entry_cold_token, actual._phase_space_token, token)
	return _entry_leave(code)


func revision_after(token: int) -> int:
	"""Only the same original sealed candidate supplies the source revision used by the actual proof cache."""
	var actual: PhaseContacts = _entry_actual()
	if _entry_leaf(actual) != &"" or token != actual._phase_companion_token: return 0
	return actual._placements.phase_revision_after(token)


func discard_companions(token: int) -> void:
	"""Discard only the retained companion tuple; Authority separately releases its original Space and arena."""
	if _entry_reading:
		_entry_poisoned = true
		return
	var actual: PhaseContacts = _entry_actual()
	if actual != null and token > 0 and token == actual._phase_companion_token:
		actual._placements.discard_phase_refresh(token)


func publish_companions(_token: int) -> void:
	"""Actual Authority publishes through its concrete static Sites window; no observer runs after payment."""
	assert(false, "The concrete phase publication kernel owns these prepared companions")


func end_cold_operation(token: int) -> void:
	"""Drop our exact Contacts scope before the base releases the original arena; nested cleanup poisons without release."""
	if _entry_reading:
		_entry_poisoned = true
		return
	if token <= 0 or token != _phase_token: return
	var actual: PhaseContacts = _entry_actual()
	if actual != null: actual.discard_phase(_entry_placement, _entry_site, _entry_operation, _entry_stage)
	_entry_cold_token = 0
	_entry_placement = NULL_REF
	_entry_site = NULL_REF
	_entry_episode = -1
	super.end_cold_operation(token)
