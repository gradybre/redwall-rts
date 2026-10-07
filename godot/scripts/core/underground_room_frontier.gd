extends RefCounted
## Derived ordinary Room frontier observation. No paid state, contact permission, or publication ledger.
## Both caller packets and private query die before the original cold lease is released or a phase starts.

const Provider := preload("res://scripts/core/underground_room_world_bindings.gd")
const Face := preload("res://scripts/core/underground_work_face.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Itinerary := preload("res://scripts/core/underground_room_itinerary.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const CONTROL_BYTES: int = 2048
const COLD_BYTES: int = Face.COLD_BYTES + CONTROL_BYTES
const REFUSE_BINDING: StringName = &"ROOM_FRONTIER_BINDING"
const REFUSE_LEASE: StringName = &"ROOM_FRONTIER_COLD_LEASE"
const REFUSE_CAPACITY: StringName = &"ROOM_FRONTIER_OPERATION_CAPACITY"
const REFUSE_SCOPE: StringName = &"ROOM_FRONTIER_SCOPE"
const REFUSE_STALE: StringName = &"ROOM_FRONTIER_SOURCE_CHANGED"
const REFUSE_PHASE: StringName = &"ROOM_FRONTIER_PHASE"
const REFUSE_ACTIVE: StringName = &"ROOM_FRONTIER_EXISTING_PROJECT"
const REFUSE_END: StringName = &"ROOM_FRONTIER_SCAN_END"
const REFUSE_CONTACT: StringName = &"ROOM_FRONTIER_EXISTING_CONTACT_REQUIRED"
const REFUSE_AMBIGUOUS: StringName = &"ROOM_FRONTIER_AMBIGUOUS_CONTACT"


class Candidate extends RefCounted:
	## Caller-owned identity observation only; a Project/pause remains authoritative in its original owner.
	var room: Vector2i = NULL_REF
	var site: Vector2i = NULL_REF
	var project: Vector2i = NULL_REF
	var key: int = -1
	var operation: int = -1
	var physical_phase: int = -1
	var project_phase: int = -1
	var earned_mwu: int = 0
	var room_revision: int = 0
	var geometry_revision: int = 0
	var qualification_revision: int = 0
	var cold_token: int = 0
	var installed: bool = false
	var ever_cut: bool = false
	var paused: bool = false


class Query extends RefCounted:
	## Allocated only after the complete cold admission; never exposed to an observation authority.
	var provider: Provider = null
	var config: WorldRoutes.Configuration = null
	var actual_routes: WorldRoutes = null
	var face: Face = null
	var sites: Sites = null
	var budget: Budget = null
	var original: Candidate = null
	var candidate: Candidate = Candidate.new()
	var request: Face.Request = Face.Request.new()
	var origin: Vector3i = Vector3i.ZERO
	var access: Vector2i = NULL_REF
	var retreat: Vector2i = NULL_REF
	var approach: int = -1
	var approach_revision: int = 0
	var retreat_profile: int = -1
	var retreat_revision: int = 0
	var access_payload: int = 0
	var retreat_payload: int = 0
	var work_payload: int = 0
	var remaining: int = 0
	var remaining_out: PackedInt32Array = PackedInt32Array()


static func next_site_into(actual: Provider, room: Vector2i, after_key: int, cold: int,
		max_checks: int, out: Candidate) -> StringName:
	"""Find one canonical incomplete full Site; no observer, allocation, or output write precedes all refusal checks."""
	var code: StringName = _guard(actual, cold, CONTROL_BYTES, max_checks)
	if code != &"": return code
	if out == null or out.get_script() != Candidate or after_key < -1: return REFUSE_SCOPE
	var sites: Sites = actual._ordinary_original_sites()
	var remaining: int = max_checks - _scope_checks(actual)
	var revision: int = _room_revision(actual, room)
	if revision <= 0 or actual._ordinary_entry_room(room): return REFUSE_SCOPE
	var index: int = _after(sites, after_key)
	while index < sites._count:
		if remaining < 32: return REFUSE_CAPACITY
		remaining -= 32
		var row: int = sites._ordered_row[index]
		if row < 0 or row >= sites._count or sites._present[row] != 1 \
				or sites._site_key[row] != sites._ordered_key[index]: return REFUSE_STALE
		index += 1
		if Vector2i(sites._room_slot[row], sites._room_generation[row]) != room: continue
		if sites._phase[row] == Sites.SUPPORTED_VOID and sites._project_slot[row] == -1: continue
		var operation: int = _operation(sites, row)
		if operation < 0: return REFUSE_PHASE
		var project_row: int = _project_row(sites, row, operation)
		if project_row == -2: return REFUSE_SCOPE
		_capture(actual, sites, row, project_row, operation, room, revision, cold, out)
		return &""
	return REFUSE_END


static func _guard(actual: Provider, cold: int, required: int, checks: int) -> StringName:
	"""Close the concrete once-bound implementation and original arena before reading or allocating query state."""
	if actual == null or actual.get_script() != Provider or actual._ordinary_binding_leaf() != &"": return REFUSE_BINDING
	var config: WorldRoutes.Configuration = actual._ordinary_config
	if config.budget == null or config.budget.get_script() != Budget or cold <= 0 \
			or config.budget._token != cold or config.budget._used < required: return REFUSE_LEASE
	if checks < _scope_checks(actual) or checks > Space.MAX_CHECKS: return REFUSE_CAPACITY
	var face: Face = actual._ordinary_face.get_ref() as Face
	var world_routes: WorldRoutes = actual._ordinary_routes.get_ref() as WorldRoutes
	if actual._phase_token != 0 or config.owner._stage_token != 0 or config.locations._token != 0 \
			or config.routes._token != 0 or config.routes._searching or config.routes._advancing \
			or face._reading or world_routes._reading or actual.qualification_revision() <= 0: return REFUSE_STALE
	return &""


static func _scope_checks(actual: Provider) -> int:
	"""Precharge the full registered source and Placement scans plus direct binding/key/identity reads."""
	return 256 + actual._ordinary_config.owner._source_capacity + actual._ordinary_placements.get_ref()._capacity


static func _room_revision(actual: Provider, room: Vector2i) -> int:
	"""The registered Room source and actual mirrored Buildings row must agree, without public source readers."""
	var config: WorldRoutes.Configuration = actual._ordinary_config
	var buildings: Buildings = config.sources._buildings
	if Face.FinishCheck._room_scope(buildings, room) != &"": return 0
	var row: int = Face.FinishCheck._typed_row(config.sources._directory, room, Directory.KIND_ROOM)
	var source: int = config.owner._find_source(room, false)
	if source < 0 or config.owner._o_kind[source] != Directory.KIND_ROOM \
			or config.owner._o_a[source] != buildings._r_type[row] or config.owner._o_b[source] != 0 \
			or config.owner._o_c[source] != 0 or config.owner._o_d[source] != Buildings.ROOM_SPACE_UNDERGROUND \
			or config.owner._o_parent_slot[source] != buildings._r_building_slot[row] \
			or config.owner._o_parent_generation[source] != buildings._r_building_generation[row]: return 0
	return config.owner._o_revision[source]


static func _after(sites: Sites, key: int) -> int:
	"""A bounded binary upper bound uses the original canonical index; the256-check entry charge includes it."""
	var low: int = 0
	var high: int = sites._count
	while low < high:
		@warning_ignore("integer_division") var middle: int = low + (high - low) / 2
		if sites._ordered_key[middle] <= key: low = middle + 1
		else: high = middle
	return low


static func _operation(sites: Sites, row: int) -> int:
	"""Derive only adopted forward operations; paid history and cancellation progress stay in Sites."""
	var phase: int = sites._phase[row]
	if sites._installed[row] == 0 and (phase == Sites.SOLID or phase == Sites.BACKFILLED or phase == Sites.BRACING):
		return Contract.OP_BRACE
	if sites._installed[row] == 1 and (phase == Sites.BRACED or phase == Sites.CUTTING): return Contract.OP_CUT
	if sites._installed[row] == 1 and sites._ever_cut[row] == 1 \
			and (phase == Sites.OPEN_UNFINISHED or phase == Sites.FINISHING): return Contract.OP_FINISH
	return -1


static func _project_row(sites: Sites, row: int, operation: int) -> int:
	"""A live exact purpose5 Project is reported, never hidden by a stale generation or mistaken for a new phase."""
	var project: Vector2i = Vector2i(sites._project_slot[row], sites._project_generation[row])
	if project == NULL_REF: return -1 if sites._operation[row] == -1 else -2
	var construction: Construction = sites._construction
	var index: int = Face.FinishCheck._typed_row(construction._directory, project, Directory.KIND_CONSTRUCTION)
	if index < 0 or construction._present[index] != 1 or construction._ref_slot[index] != project.x \
			or construction._ref_generation[index] != project.y or construction._purpose[index] != Construction.PURPOSE_EXCAVATION \
			or construction._subject_slot[index] != row or construction._subject_generation[index] != Sites.SITE_GENERATION \
			or construction._type_id[index] != operation or sites._operation[row] != operation: return -2
	return index


static func _capture(actual: Provider, sites: Sites, row: int, project_row: int, operation: int,
		room: Vector2i, room_revision: int, cold: int, out: Candidate) -> void:
	"""Publish the complete derived observation only after all scope checks; this is not phase permission."""
	out.room = room; out.site = Vector2i(row, Sites.SITE_GENERATION)
	out.project = Vector2i(sites._project_slot[row], sites._project_generation[row])
	out.key = sites._site_key[row]; out.operation = operation; out.physical_phase = sites._phase[row]
	out.project_phase = sites._construction._phase[project_row] if project_row >= 0 else -1
	out.paused = sites._construction._paused[project_row] == 1 if project_row >= 0 else false
	out.earned_mwu = sites._earned_mwu[row * Contract.OP_COUNT + operation]
	out.installed = sites._installed[row] == 1; out.ever_cut = sites._ever_cut[row] == 1
	out.room_revision = room_revision; out.geometry_revision = actual._ordinary_config.owner._header[17]
	out.qualification_revision = actual.qualification_revision(); out.cold_token = cold


static func contact_into(actual: Provider, candidate: Candidate, access: Vector2i, approach: int,
		approach_revision: int, cold: int, max_checks: int, out: Face.Request) -> StringName:
	"""Fresh full motion and two directed certificates observe an existing endpoint; every refusal preserves out."""
	var code: StringName = _guard(actual, cold, COLD_BYTES, max_checks)
	if code != &"": return code
	if candidate == null or candidate.get_script() != Candidate or out == null or out.get_script() != Face.Request:
		return REFUSE_SCOPE
	code = _candidate_leaf(actual, candidate, cold)
	if code != &"": return code
	if candidate.project != NULL_REF: return REFUSE_ACTIVE
	var query: Query = Query.new()
	_hold(query, actual, candidate, access, approach, approach_revision, max_checks)
	code = _observe(query)
	if code == &"": _copy_request(query.request, out)
	return code


static func _candidate_leaf(actual: Provider, candidate: Candidate, cold: int) -> StringName:
	"""The original full Site/key/source/history is rederived before contact; caller values confer no authority."""
	var sites: Sites = actual._ordinary_original_sites()
	var row: int = candidate.site.x
	if cold != candidate.cold_token or row < 0 or row >= sites._count or candidate.site.y != Sites.SITE_GENERATION \
			or sites._present[row] != 1 or sites._site_key[row] != candidate.key \
			or Vector2i(sites._room_slot[row], sites._room_generation[row]) != candidate.room \
			or Vector2i(sites._project_slot[row], sites._project_generation[row]) != candidate.project \
			or candidate.operation < Contract.OP_BRACE or candidate.operation > Contract.OP_FINISH \
			or _operation(sites, row) != candidate.operation or sites._phase[row] != candidate.physical_phase \
			or (sites._installed[row] == 1) != candidate.installed or (sites._ever_cut[row] == 1) != candidate.ever_cut \
			or sites._earned_mwu[row * Contract.OP_COUNT + candidate.operation] != candidate.earned_mwu: return REFUSE_STALE
	var project_row: int = _project_row(sites, row, candidate.operation)
	if project_row == -2 or (project_row < 0 and (candidate.project_phase != -1 or candidate.paused)) \
			or (project_row >= 0 and (sites._construction._phase[project_row] != candidate.project_phase \
			or (sites._construction._paused[project_row] == 1) != candidate.paused)): return REFUSE_STALE
	return &"" if candidate.room_revision > 0 and _room_revision(actual, candidate.room) == candidate.room_revision \
		and candidate.geometry_revision == actual._ordinary_config.owner._header[17] \
		and candidate.qualification_revision == actual.qualification_revision() \
		and not actual._ordinary_entry_room(candidate.room) else REFUSE_STALE


static func _copy_candidate(source: Candidate, out: Candidate) -> void:
	"""One private scalar copy detects mutation of the caller packet across observers; there is no copied bank."""
	out.room = source.room; out.site = source.site; out.project = source.project; out.key = source.key
	out.operation = source.operation; out.physical_phase = source.physical_phase; out.project_phase = source.project_phase
	out.earned_mwu = source.earned_mwu; out.room_revision = source.room_revision
	out.geometry_revision = source.geometry_revision; out.qualification_revision = source.qualification_revision
	out.cold_token = source.cold_token; out.installed = source.installed; out.ever_cut = source.ever_cut; out.paused = source.paused


static func _same_candidate(first: Candidate, second: Candidate) -> bool:
	"""Every original caller field remains exact after full WorkFace observations."""
	return first.room == second.room and first.site == second.site and first.project == second.project \
		and first.key == second.key and first.operation == second.operation and first.physical_phase == second.physical_phase \
		and first.project_phase == second.project_phase and first.earned_mwu == second.earned_mwu \
		and first.room_revision == second.room_revision and first.geometry_revision == second.geometry_revision \
		and first.qualification_revision == second.qualification_revision and first.cold_token == second.cold_token \
		and first.installed == second.installed and first.ever_cut == second.ever_cut and first.paused == second.paused


static func _hold(query: Query, actual: Provider, candidate: Candidate, access: Vector2i,
		approach: int, approach_revision: int, checks: int) -> void:
	"""Retain the admitted original owners and one private immutable observation before external callbacks."""
	query.provider = actual; query.config = actual._ordinary_config; query.original = candidate
	query.actual_routes = actual._ordinary_routes.get_ref() as WorldRoutes
	query.face = actual._ordinary_face.get_ref() as Face; query.sites = actual._ordinary_original_sites()
	query.budget = query.config.budget; query.access = access; query.retreat = actual._ordinary_retreat
	query.approach = approach; query.approach_revision = approach_revision
	query.retreat_profile = actual._ordinary_travel; query.retreat_revision = actual._ordinary_travel_revision
	query.remaining = checks - _scope_checks(actual); query.remaining_out.resize(1)
	_copy_candidate(candidate, query.candidate)
	query.origin = _origin(query.sites, candidate.key)


static func _origin(sites: Sites, key: int) -> Vector3i:
	"""Decode the actual immutable canonical key without invoking a Site observer or rounding geometry."""
	var x: int = key % sites._domain.size_quanta.x
	@warning_ignore("integer_division") var rest: int = key / sites._domain.size_quanta.x
	var z: int = rest % sites._domain.size_quanta.z
	@warning_ignore("integer_division") var y: int = rest / sites._domain.size_quanta.z
	var result: Vector3i = Vector3i(x, y, z)
	for axis: int in 3:
		var value: int = int(sites._domain.datum_u[axis]) \
			+ (int(result[axis]) + int(sites._domain.minimum_quantum[axis])) * Contract.QUANTUM_SIDE_U
		if not Space.int32(value): return Vector3i.ZERO
		result[axis] = value
	return result


static func _observe(query: Query) -> StringName:
	"""At most one full WorkFace proof runs, followed by real forward/backward path checks and a pure final closure."""
	if Face.FinishCheck._key_at(query.sites._domain, query.origin) != query.candidate.key: return REFUSE_SCOPE
	var code: StringName = _select(query)
	if code != &"": return code
	query.access_payload = _endpoint(query, query.access)
	query.retreat_payload = _endpoint(query, query.retreat)
	if query.access_payload <= 0 or query.retreat_payload <= 0: return REFUSE_CONTACT
	if query.candidate.operation == Contract.OP_FINISH:
		code = query.face.finish_face_refusal(query.config, query.request, query.sites, query.candidate.site,
			query.candidate.room, NULL_REF, Contract.STAGE_ADMIT, query.candidate.cold_token)
	else: code = query.face.solid_face_refusal(query.config, query.request, query.candidate.cold_token)
	if code == &"": code = _query_leaf(query)
	if code == &"": code = _path(query, query.access, query.request.location, query.approach, query.approach_revision)
	if code == &"": code = _retreat_path(query)
	return _query_leaf(query) if code == &"" else code


static func _retreat_path(query: Query) -> StringName:
	"""ADR1213: a contact of another heading retreats on the bound row's backward sibling at the contact's yaw."""
	var profiles: Profiles = query.config.profiles
	var row: int = query.retreat_profile
	var revision: int = query.retreat_revision
	if _field(query, row, Profiles.F_YAW_KIND) == Profiles.YAW_EXACT and _field(query, row, Profiles.F_YAW) != query.request.yaw:
		row = Itinerary.family_row(profiles, row, query.request.yaw, Profiles.POLICY_READY_BACKWARD)
		revision = profiles._live.quantities[row] if row >= 0 else 0
	return _path(query, query.request.location, query.retreat, row, revision)


static func _spend(query: Query, amount: int) -> bool:
	"""Enumeration and the two static searches share one monotone counter; refusal never resets failed work."""
	if amount <= 0 or query.remaining < amount: query.remaining = -1; return false
	query.remaining -= amount
	return true


static func _field(query: Query, profile: int, column: int) -> int:
	"""Borrow the provider's exact concrete immutable Profile bank; no descriptor copy or observer."""
	return query.config.profiles._live.fields[column * query.config.profiles._profile_capacity + profile]


static func _work_profile(query: Query, profile: int) -> bool:
	"""Only complete exact BUILD contact sources participate; flags alone do not establish physical permission."""
	return query.config.profiles._live.flags[profile] == Profiles.CERT_REQUIRED \
		and _field(query, profile, Profiles.F_MODE) == Profiles.MODE_WORK \
		and _field(query, profile, Profiles.F_WORK_KIND) == Jobs.JOB_KIND_BUILD \
		and _field(query, profile, Profiles.F_YAW_KIND) == Profiles.YAW_EXACT \
		and _field(query, profile, Profiles.F_CONTACT_KIND) == Profiles.CONTACT_ANCHOR_AND_PATCH


static func _select(query: Query) -> StringName:
	"""Conservatively refuse distinct declared contacts instead of choosing an arbitrary first successful source."""
	var locations: Locations = query.config.locations
	for row: int in locations._capacity:
		if not _spend(query, 8): return REFUSE_CAPACITY
		if locations._live.present[row] != 1 or locations._get32(locations._live, Locations.ROLE, row) != Locations.ROLE_WORK: continue
		var location: Vector2i = Vector2i(row, locations._get32(locations._live, Locations.GENERATION, row))
		for profile: int in query.config.profiles._live.header[1]:
			if not _spend(query, 32): return REFUSE_CAPACITY
			if not _work_profile(query, profile): continue
			var side: int = _face(query, profile, location)
			if query.remaining < 0: return REFUSE_CAPACITY
			if side < 0: continue
			if query.request.location != NULL_REF: return REFUSE_AMBIGUOUS
			_capture_request(query, location, profile, side)
	if query.request.location == NULL_REF: return REFUSE_CONTACT
	query.work_payload = _endpoint(query, query.request.location)
	return &"" if query.work_payload > 0 else REFUSE_CONTACT


static func _face(query: Query, profile: int, location: Vector2i) -> int:
	"""An exact source anchor must lie on exactly one face; the full WorkFace later validates its patch and body."""
	var result: int = -1
	var profiles: Profiles = query.config.profiles
	for index: int in _field(query, profile, Profiles.F_BOX_COUNT):
		if not _spend(query, 24): return -1
		var box: int = _field(query, profile, Profiles.F_FIRST_BOX) + index
		if profiles._live.boxes[6 * profiles._box_capacity + box] != Profiles.CONTACT_POINT: continue
		if result >= 0: return -1
		for axis: int in 3:
			var value: int = int(profiles._live.boxes[axis * profiles._box_capacity + box]) \
				+ query.config.locations._get32(query.config.locations._live, Locations.X + axis, location.x)
			if value < query.origin[axis] or value > int(query.origin[axis]) + Contract.QUANTUM_SIDE_U: return -1
			if value == query.origin[axis] or value == int(query.origin[axis]) + Contract.QUANTUM_SIDE_U:
				if result >= 0: return -1
				result = axis * 2 + int(value != query.origin[axis])
	return result


static func _capture_request(query: Query, location: Vector2i, profile: int, side: int) -> void:
	"""Private request is source-derived; no caller-selected point or AABB is substituted for the loaded primitive."""
	query.request.location = location; query.request.target_origin = query.origin; query.request.face = side
	query.request.profile_id = profile; query.request.profile_revision = query.config.profiles._live.quantities[profile]
	query.request.content_revision = query.config.profiles._live.header[0]
	query.request.geometry_revision = query.config.owner._header[17]; query.request.yaw = _field(query, profile, Profiles.F_YAW)


static func _endpoint(query: Query, ref: Vector2i) -> int:
	"""Require full live generation and original current geometry; zero is never an implicit payload receipt."""
	var locations: Locations = query.config.locations
	if not locations._live_ref(locations._live, ref) \
			or locations._get64(locations._live, Locations.GEOMETRY_REVISION, ref.x) != query.candidate.geometry_revision: return 0
	return locations._get64(locations._live, Locations.PAYLOAD_REVISION, ref.x)


static func _path(query: Query, first: Vector2i, last: Vector2i, profile: int, revision: int) -> StringName:
	"""Static route eligibility is observed on the actual committed masks, never equated with movement or work."""
	var code: StringName
	if Profiles.selection_policy_leaf(query.config.profiles, profile, revision,
			query.request.content_revision) == Profiles.POLICY_AUTOMATIC:
		code = WorldRoutes.profile_reachability_refusal(query.actual_routes, first, last, profile,
			revision, query.request.content_revision, query.remaining, query.remaining_out)
	else:
		code = Itinerary.reachability_refusal(query.actual_routes, first, last, profile,
			revision, query.request.content_revision, query.remaining, query.remaining_out)
	if code == &"": query.remaining = query.remaining_out[0]
	return code


static func _query_leaf(query: Query) -> StringName:
	"""No observers follow this original-owner/caller/history/source/full-endpoint closure before output copying."""
	var code: StringName = _guard(query.provider, query.candidate.cold_token, COLD_BYTES, query.remaining)
	if code == &"" and not _spend(query, _scope_checks(query.provider)): code = REFUSE_CAPACITY
	if code != &"": return code
	if not _same_candidate(query.original, query.candidate) or query.provider._ordinary_config != query.config \
			or query.config.budget != query.budget or query.provider._ordinary_routes.get_ref() != query.actual_routes \
			or query.provider._ordinary_face.get_ref() != query.face or query.provider._ordinary_original_sites() != query.sites \
			or query.provider._ordinary_retreat != query.retreat or query.provider._ordinary_travel != query.retreat_profile \
			or query.provider._ordinary_travel_revision != query.retreat_revision: return REFUSE_STALE
	code = _candidate_leaf(query.provider, query.candidate, query.candidate.cold_token)
	if code != &"": return code
	if _endpoint(query, query.access) != query.access_payload or _endpoint(query, query.retreat) != query.retreat_payload \
			or _endpoint(query, query.request.location) != query.work_payload \
			or not _work_profile(query, query.request.profile_id) \
			or query.request.profile_revision != query.config.profiles._live.quantities[query.request.profile_id] \
			or query.request.yaw != _field(query, query.request.profile_id, Profiles.F_YAW) \
			or _face(query, query.request.profile_id, query.request.location) != query.request.face: return REFUSE_STALE
	return REFUSE_CAPACITY if query.remaining < 0 else &""


static func _copy_request(source: Face.Request, out: Face.Request) -> void:
	"""Only the fully completed observation may replace caller output; it remains no later phase permission."""
	out.location = source.location; out.target_origin = source.target_origin; out.face = source.face
	out.profile_id = source.profile_id; out.profile_revision = source.profile_revision
	out.content_revision = source.content_revision; out.geometry_revision = source.geometry_revision; out.yaw = source.yaw
