extends "res://scripts/core/underground_entry_world_bindings.gd"
## Actual ordinary Room phases share the World composer and original phase context with Entry.
## Current contact/source observations are synchronous; no per-Site work, goods or permission ledger.

const RoomRoutes := preload("res://scripts/core/underground_routes.gd")
const RoomWorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const RoomLocations := preload("res://scripts/core/underground_locations.gd")
const RoomFace := preload("res://scripts/core/underground_work_face.gd")
const RoomFinal := preload("res://scripts/core/underground_final_facts.gd")
const RoomInventory := preload("res://scripts/core/inventory.gd")
const RoomGear := preload("res://scripts/core/gear.gd")
const RoomResidents := preload("res://scripts/core/residents.gd")
const RoomTransforms := preload("res://scripts/core/transforms.gd")
const ROOM_CONTROL_BYTES: int = 1024
const ROOM_HELPER_BYTES: int = 512
const ROOM_NATIVE_ALLOWANCE: int = 256
const ROOM_REFUSE_BINDING: StringName = &"ROOM_PHASE_ACTUAL_BINDING"
const ROOM_REFUSE_SCOPE: StringName = &"ROOM_PHASE_SCOPE"
const ROOM_REFUSE_SOURCE: StringName = &"ROOM_PHASE_SOURCE"
const ROOM_REFUSE_CONTACT: StringName = &"ROOM_PHASE_CONTACT"
const ROOM_REFUSE_WORKER: StringName = &"ROOM_PHASE_WORKER"
const ROOM_REFUSE_STORAGE: StringName = &"ROOM_PHASE_STORAGE"
const ROOM_REFUSE_CAPACITY: StringName = &"ROOM_PHASE_OPERATION_CAPACITY"

var _ordinary_routes: WeakRef = null
var _ordinary_placements: WeakRef = null
var _ordinary_face: WeakRef = null
var _ordinary_config: RoomWorldRoutes.Configuration = null
var _ordinary_query: RoomFace.Request = null
var _ordinary_retreat: Vector2i = NULL_REF
var _ordinary_travel: int = -1
var _ordinary_travel_revision: int = 0
var _ordinary_companion: int = 0
var _ordinary_space: int = 0
var _ordinary_worker: Vector2i = NULL_REF
var _ordinary_job: Vector2i = NULL_REF
var _ordinary_tool: Vector2i = NULL_REF
var _ordinary_satchel: Vector2i = NULL_REF
var _ordinary_cargo: Vector2i = NULL_REF
var _ordinary_quantity: int = 0
var _ordinary_material: Vector2i = NULL_REF
var _ordinary_output: Vector2i = NULL_REF
var _ordinary_material_location: Vector2i = NULL_REF
var _ordinary_output_location: Vector2i = NULL_REF
var _ordinary_material_revision: int = 0
var _ordinary_output_revision: int = 0
var _ordinary_retreat_revision: int = 0
var _ordinary_checks: PackedInt32Array = PackedInt32Array()
var _ordinary_mode: bool = false
var _ordinary_valid: bool = false


func bind_room_phase_contacts(actual: RoomWorldRoutes, face: RoomFace, placements: EntryPlacements,
		retreat: Vector2i, travel: int, travel_revision: int, controls: int) -> StringName:
	"""Admit one reusable packet after all initial observations; nested bind attempts cannot allocate or publish links."""
	if _ordinary_routes != null or _phase_token != 0 or controls < ROOM_CONTROL_BYTES: return ROOM_REFUSE_BINDING
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	var code: StringName = _ordinary_bind_refusal(actual, face, placements, retreat, travel, travel_revision)
	if code == &"": code = actual.binding_refusal()
	if code == &"": code = _ordinary_bind_refusal(actual, face, placements, retreat, travel, travel_revision)
	if _entry_poisoned: code = ENTRY_REFUSE_BUSY
	if code == &"": code = placements.bind_phase_authority(_ordinary_original_sites()._space.get_ref())
	if code == &"":
		_ordinary_routes = weakref(actual)
		_ordinary_placements = weakref(placements)
		_ordinary_face = weakref(face)
		_ordinary_retreat = retreat
		_ordinary_travel = travel
		_ordinary_travel_revision = travel_revision
		_ordinary_allocate(actual)
	return _entry_leave(code)


func _ordinary_bind_refusal(actual: RoomWorldRoutes, face: RoomFace, placements: EntryPlacements,
		retreat: Vector2i, travel: int, travel_revision: int) -> StringName:
	"""Closed original owner identities precede and follow ordinary initialization observations."""
	var sites: Sites = _ordinary_original_sites()
	if actual == null or face == null or placements == null or sites == null or _budget == null or _domain == null \
			or not _budget.is_quiescent() or actual._routes_ref == null or actual._owner_ref == null \
			or actual._sources_ref == null or actual._owner_ref.get_ref() != _owner.get_ref() \
			or actual._sources_ref.get_ref() != _source_reader.get_ref() or actual._terrain != _terrain \
			or actual._world != _world or actual._budget != _budget or placements._space != _owner.get_ref() \
			or placements._world_routes != actual or placements._construction != sites._construction: return ROOM_REFUSE_BINDING
	var graph: RoomRoutes = actual._routes_ref.get_ref() as RoomRoutes
	if not _ordinary_implementations(graph) or face.get_script() != RoomFace: return ROOM_REFUSE_BINDING
	if _ordinary_initial_graph_refusal(actual, placements, graph) != &"": return ROOM_REFUSE_BINDING
	if not graph._locations._live_ref(graph._locations._live, retreat) \
			or not _ordinary_travel_row(graph._profiles, travel, travel_revision): return ROOM_REFUSE_SOURCE
	var authority: Authority = sites._space.get_ref() as Authority if sites._space != null else null
	return &"" if authority != null and authority._sites != null and authority._sites.get_ref() == sites \
		and authority._bindings == self and authority._owner == graph._owner \
		and authority._construction == placements._construction else ROOM_REFUSE_BINDING


func _ordinary_initial_graph_refusal(actual: RoomWorldRoutes, placements: EntryPlacements,
		graph: RoomRoutes) -> StringName:
	"""Every adopted configuration reference remains reciprocal before publishing the shared authority link."""
	var source_owner: Owner.CoreSources = _source_reader.get_ref() as Owner.CoreSources
	if source_owner == null or actual._locations_ref == null or actual._locations_ref.get_ref() != graph._locations \
			or actual._profiles != graph._profiles or actual._residents != graph._residents \
			or actual._transforms != graph._transforms or graph._bindings != actual \
			or graph._owner != _owner.get_ref() or graph._sources != source_owner or graph._cold != _budget \
			or graph._world != _domain._world or graph._ids != source_owner._directory \
			or graph._buildings != source_owner._buildings or source_owner._locations != graph \
			or placements._sources != source_owner or placements._routes != graph \
			or placements._locations != graph._locations or placements._profiles != graph._profiles \
			or placements._residents != graph._residents or placements._transforms != graph._transforms \
			or placements._budget != _budget or placements._world != _domain._world \
			or graph._locations._owner != graph._owner or graph._locations._sources != source_owner \
			or graph._locations._ids != graph._ids or graph._locations._cold != _budget \
			or graph._locations._world != _domain._world or _terrain._space == null or _terrain._sources == null \
			or _terrain._space.get_ref() != graph._owner or _terrain._sources.get_ref() != source_owner \
			or _terrain._world != _world: return ROOM_REFUSE_BINDING
	return _ordinary_initial_catalog_refusal(actual, placements, graph)


static func _ordinary_initial_catalog_refusal(actual: RoomWorldRoutes, placements: EntryPlacements,
		graph: RoomRoutes) -> StringName:
	"""Original configured source identities cannot be replaced after the earlier observed binding check."""
	var catalog: RoomWorldRoutes.Catalog = placements._catalog
	if catalog == null or actual._catalog != catalog or actual._profiles == null \
			or actual._levels == null or actual._movement == null or actual._residents == null \
			or actual._transforms == null or actual._catalog_identity != catalog.get_instance_id() \
			or actual._profile_identity != actual._profiles.get_instance_id() \
			or actual._levels_identity != actual._levels.get_instance_id() \
			or actual._levels != catalog._levels or actual._movement != catalog._movement \
			or catalog._profiles != graph._profiles or catalog._residents != graph._residents \
			or catalog._transforms != graph._transforms or graph._profiles._residents != graph._residents \
			or graph._profiles._transforms != graph._transforms: return ROOM_REFUSE_BINDING
	return &"" if RoomFinal._same_domain(actual._domain, graph._owner._domain) \
		and RoomFinal._same_domain(graph._domain, graph._owner._domain) \
		and RoomFinal._same_domain(graph._locations._domain, graph._owner._domain) else ROOM_REFUSE_BINDING


func _ordinary_original_sites() -> Sites:
	"""Missing original weak bindings refuse before dereference; no observed provider getter runs in a final leaf."""
	if _owner == null or _owner.get_ref() == null or _source_reader == null: return null
	var reader: Owner.CoreSources = _source_reader.get_ref() as Owner.CoreSources
	if reader == null or reader._construction == null or reader._construction._excavation_authority == null: return null
	var sites: Sites = reader._construction._excavation_authority.get_ref() as Sites
	return sites if sites != null and sites._construction == reader._construction else null


static func _ordinary_implementations(graph: RoomRoutes) -> bool:
	"""Private helper reuse is closed by concrete script identity, not by a caller declaration of purity."""
	return graph != null and graph.get_script() == RoomRoutes and graph._profiles != null \
		and graph._profiles.get_script() == EntryProfiles and graph._locations != null \
		and graph._locations.get_script() == RoomLocations and graph._owner != null \
		and graph._owner.get_script() == Owner and graph._ids != null and graph._ids.get_script() == Directory


static func _ordinary_travel_row(profiles: EntryProfiles, row: int, revision: int) -> bool:
	"""One explicit current full source profile must cover travel; no walk row is inferred from work contact."""
	return profiles != null and not profiles._loading and row >= 0 and row < profiles._live.header[1] \
		and profiles._live.quantities[row] == revision and profiles._live.flags[row] == EntryProfiles.CERT_REQUIRED \
		and profiles._live.fields[EntryProfiles.F_MODE * profiles._profile_capacity + row] != EntryProfiles.MODE_WORK


func _ordinary_allocate(actual: RoomWorldRoutes) -> void:
	"""Only once-bound controls grow here, after complete admission; inherited Entry scratch is reused sequentially."""
	_ordinary_config = RoomWorldRoutes.Configuration.new()
	_ordinary_config.routes = actual._routes_ref.get_ref() as RoomRoutes
	_ordinary_config.owner = actual._owner_ref.get_ref() as Owner
	_ordinary_config.sources = actual._sources_ref.get_ref() as Owner.CoreSources
	_ordinary_config.locations = actual._locations_ref.get_ref() as RoomLocations
	_ordinary_config.profiles = actual._profiles
	_ordinary_config.catalog = actual._catalog
	_ordinary_config.levels = actual._levels
	_ordinary_config.movement = actual._movement
	_ordinary_config.residents = actual._residents
	_ordinary_config.transforms = actual._transforms
	_ordinary_config.world = _world
	_ordinary_config.terrain = _terrain
	_ordinary_config.budget = _budget
	_ordinary_query = RoomFace.Request.new()
	_ordinary_checks.resize(1)
	if _entry_box.is_empty(): _entry_box.resize(6)
	if _entry_air.is_empty(): _entry_air.resize(6)
	if _entry_reach.is_empty(): _entry_reach.resize(6)


func _ordinary_binding_leaf() -> StringName:
	"""Recheck original concrete identities after every observation; missing weak links are named refusals."""
	var config: RoomWorldRoutes.Configuration = _ordinary_config
	var actual: RoomWorldRoutes = _ordinary_routes.get_ref() as RoomWorldRoutes if _ordinary_routes != null else null
	var placements: EntryPlacements = _ordinary_placements.get_ref() as EntryPlacements if _ordinary_placements != null else null
	if config == null or actual == null or placements == null or _ordinary_face == null or _domain == null \
			or _ordinary_face.get_ref() == null or _ordinary_face.get_ref().get_script() != RoomFace \
			or not _ordinary_implementations(config.routes) or actual._routes_ref == null or actual._locations_ref == null \
			or actual._owner_ref == null or actual._sources_ref == null or actual._routes_ref.get_ref() != config.routes \
			or actual._locations_ref.get_ref() != config.locations or actual._owner_ref.get_ref() != config.owner \
			or actual._sources_ref.get_ref() != config.sources or actual._profiles != config.profiles \
			or actual._catalog != config.catalog or actual._levels != config.levels or actual._movement != config.movement \
			or actual._residents != config.residents or actual._transforms != config.transforms \
			or _world != config.world or _terrain != config.terrain or _budget != config.budget \
			or actual._world != _world or actual._terrain != _terrain or actual._budget != _budget: return ROOM_REFUSE_BINDING
	return _ordinary_original_binding_leaf(config, actual, placements)


func _ordinary_original_binding_leaf(config: RoomWorldRoutes.Configuration, actual: RoomWorldRoutes,
		placements: EntryPlacements) -> StringName:
	"""The captured graph, shared issuer and actual Sites authority remain reciprocal on every final read."""
	var sites: Sites = _ordinary_original_sites()
	if sites == null or config.sources == null or config.sources._construction != sites._construction \
			or _terrain._space == null or _terrain._sources == null or _terrain._world != _world \
			or _terrain._space.get_ref() != config.owner or _terrain._sources.get_ref() != config.sources \
			or config.owner != _owner.get_ref() or config.sources != _source_reader.get_ref() \
			or placements._construction != sites._construction or placements._space != config.owner \
			or placements._sources != config.sources or placements._routes != config.routes \
			or placements._locations != config.locations or placements._profiles != config.profiles \
			or placements._catalog != config.catalog or placements._budget != _budget \
			or placements._world != _domain._world or placements._world_routes != actual \
			or config.routes._owner != config.owner or config.routes._sources != config.sources \
			or config.routes._locations != config.locations or config.routes._profiles != config.profiles \
			or config.routes._bindings != actual or config.routes._cold != _budget \
			or config.routes._ids != config.sources._directory or config.routes._buildings != config.sources._buildings:
		return ROOM_REFUSE_BINDING
	var authority: Authority = sites._space.get_ref() as Authority if sites._space != null else null
	if authority == null or authority._sites == null or authority._sites.get_ref() != sites \
			or authority._bindings != self or authority._owner != config.owner or authority._sources != config.sources \
			or authority._construction != placements._construction: return ROOM_REFUSE_BINDING
	return &"" if sites._domain != null and sites._domain.world_ref == _domain._world \
		and sites._domain.datum_u == _domain._datum and sites._domain.minimum_quantum == _domain._min_quantum \
		and sites._domain.size_quanta == _domain._size_quanta else ROOM_REFUSE_BINDING


func qualification_revision() -> int:
	"""Restored Location epochs cannot reuse a cached proof: only original non-restored publication tokens qualify."""
	if _ordinary_routes == null: return super.qualification_revision()
	if _ordinary_binding_leaf() != &"": return 0
	return _ordinary_revision_for(_ordinary_config.locations._last_published_token, _ordinary_config.routes._last_published_token)


func _ordinary_revision_for(location_token: int, route_token: int) -> int:
	"""Every included source is monotone on these exact owners; restore clears the required Location receipt."""
	if location_token <= 0 or route_token < 0: return 0
	var config: RoomWorldRoutes.Configuration = _ordinary_config
	var total: int = _ordinary_revision_add(config.profiles._live.header[0], config.catalog._live.header[0])
	total = _ordinary_revision_add(total, config.levels._revision)
	total = _ordinary_revision_add(total, location_token)
	if route_token > 0: total = _ordinary_revision_add(total, route_token)
	var entry: PhaseContacts = _entry_actual()
	if entry == null: return total if _entry_contacts == null else 0
	if _entry_binding_leaf(entry) != &"": return 0
	return _ordinary_revision_add(total, entry._frontier._header[0])


static func _ordinary_revision_add(total: int, value: int) -> int:
	"""Checked addition refuses before any cache or candidate mutation; zero propagates unavailable qualification."""
	return total + value if total > 0 and value > 0 and total <= 9223372036854775807 - value else 0


func _ordinary_entry_room(room: Vector2i) -> bool:
	"""Only a real full Room owner in a live Placement selects the inherited Entry path."""
	var actual: EntryPlacements = _ordinary_placements.get_ref() as EntryPlacements if _ordinary_placements != null else null
	if actual == null: return true
	for row: int in actual._capacity:
		if actual._live.present[row] == 1 and actual._pair(actual._live, EntryPlacements.ROOM_SLOT, row) == room:
			return true
	return false


func _ordinary_pin(site: Vector2i, operation: int, stage: int, room: Vector2i) -> StringName:
	"""Capture full current Site facts before callbacks; prepared calls cannot replace this original packet."""
	if _ordinary_binding_leaf() != &"" or _ordinary_config.owner._stage_token != 0 \
			or operation < Contract.OP_BRACE or operation > Contract.OP_FINISH \
			or stage < PhaseContacts.PHASE_CONTACT_ONLY or stage > Contract.STAGE_WORK: return ROOM_REFUSE_SCOPE
	var sites: Sites = _ordinary_config.sources._construction._excavation_authority.get_ref() as Sites
	if sites == null or site.x < 0 or site.x >= sites._count or site.y != Sites.SITE_GENERATION \
			or sites._present[site.x] != 1 or Vector2i(sites._room_slot[site.x], sites._room_generation[site.x]) != room:
		return ROOM_REFUSE_SCOPE
	_ordinary_mode = true
	_ordinary_valid = false
	_entry_placement = NULL_REF
	_entry_site = site
	_entry_room = room
	_entry_project = Vector2i(sites._project_slot[site.x], sites._project_generation[site.x])
	_ordinary_job = Vector2i(sites._job_slot[site.x], sites._job_generation[site.x])
	_ordinary_worker = _ordinary_assigned_worker()
	_entry_operation = operation
	_entry_stage = stage
	_entry_revision = qualification_revision()
	_entry_cold_token = _phase_token
	_entry_origin = sites.origin_of(site)
	_entry_remaining = _domain._checks
	_ordinary_companion = 0
	_ordinary_space = 0
	_ordinary_material = NULL_REF
	_ordinary_output = NULL_REF
	return _ordinary_scope_leaf()


func _ordinary_scope_leaf() -> StringName:
	"""Scope and source checks use original full refs and the original lease, never a copied success flag."""
	if not _ordinary_mode or _entry_poisoned or _ordinary_binding_leaf() != &"" \
			or _entry_revision < 1 or _entry_revision != qualification_revision(): return ROOM_REFUSE_SOURCE
	var sites: Sites = _ordinary_config.sources._construction._excavation_authority.get_ref() as Sites
	if not _entry_site_leaf(sites) or Vector2i(sites._room_slot[_entry_site.x], sites._room_generation[_entry_site.x]) != _entry_room \
			or Vector2i(sites._project_slot[_entry_site.x], sites._project_generation[_entry_site.x]) != _entry_project:
		return ROOM_REFUSE_SCOPE
	if _entry_cold_token != 0 and (_phase_token != _entry_cold_token or _phase_site != _entry_site \
			or _phase_room != _entry_room or _phase_project != _entry_project or _phase_operation != _entry_operation \
			or _phase_stage != _entry_stage or _budget._token != _entry_cold_token or _budget._used < Budget.COLD_BYTES):
		return REFUSE_BUDGET
	return RoomFace.FinishCheck._room_scope(_ordinary_config.sources._buildings, _entry_room)


func _ordinary_field(profile: int, column: int) -> int:
	"""Read exact immutable source columns without a descriptor allocation or overridable getter."""
	return _ordinary_config.profiles._live.fields[column * _ordinary_config.profiles._profile_capacity + profile]


func _ordinary_location(location: Vector2i, column: int) -> int:
	"""The exact concrete Location implementation owns this admitted packed row."""
	return _ordinary_config.locations._get32(_ordinary_config.locations._live, column, location.x)


func _ordinary_profile(profile: int) -> bool:
	"""Every role belongs to an exact current certified BUILD contact, never merely a numeric profile ID."""
	var profiles: EntryProfiles = _ordinary_config.profiles
	return not profiles._loading and profile >= 0 and profile < profiles._live.header[1] \
		and profiles._live.flags[profile] == EntryProfiles.CERT_REQUIRED \
		and _ordinary_field(profile, EntryProfiles.F_MODE) == EntryProfiles.MODE_WORK \
		and _ordinary_field(profile, EntryProfiles.F_WORK_KIND) == Jobs.JOB_KIND_BUILD \
		and _ordinary_field(profile, EntryProfiles.F_YAW_KIND) == EntryProfiles.YAW_EXACT \
		and _ordinary_field(profile, EntryProfiles.F_CONTACT_KIND) == EntryProfiles.CONTACT_ANCHOR_AND_PATCH


func _ordinary_box(profile: int, ordinal: int, location: Vector2i) -> int:
	"""Translate the whole authored oriented primitive in int64 before narrowing to one inherited fixed box."""
	var profiles: EntryProfiles = _ordinary_config.profiles
	if ordinal < 0 or ordinal >= _ordinary_field(profile, EntryProfiles.F_BOX_COUNT) or not _entry_spend(24): return -1
	var row: int = _ordinary_field(profile, EntryProfiles.F_FIRST_BOX) + ordinal
	if row < 0 or row >= profiles._live.header[2]: return -1
	for axis: int in 6:
		var value: int = profiles._live.boxes[axis * profiles._box_capacity + row] \
			+ _ordinary_location(location, RoomLocations.X + axis % 3)
		if not Space.int32(value): return -1
		_entry_box[axis] = value
	return profiles._live.boxes[6 * profiles._box_capacity + row]


func _ordinary_contact_face(profile: int, location: Vector2i) -> int:
	"""The exact source anchor identifies one cube face; the subsequent WorkFace proof checks the whole patch."""
	var result: int = -1
	for ordinal: int in _ordinary_field(profile, EntryProfiles.F_BOX_COUNT):
		var role: int = _ordinary_box(profile, ordinal, location)
		if role < 0: return -1
		if role != EntryProfiles.CONTACT_POINT: continue
		for axis: int in 3:
			if _entry_box[axis] < _entry_origin[axis] or _entry_box[axis] > int(_entry_origin[axis]) + 1024: return -1
			if _entry_box[axis] == _entry_origin[axis] or _entry_box[axis] == int(_entry_origin[axis]) + 1024:
				if result >= 0: return -1
				result = axis * 2 + int(_entry_box[axis] != _entry_origin[axis])
	return result


func _ordinary_select() -> StringName:
	"""Assigned START/WORK uses its committed actor; worker-free admission and settlement require one contact."""
	var code: StringName = _ordinary_committed_contact() if _ordinary_needs_worker() \
		or (_entry_stage == PhaseContacts.PHASE_CONTACT_ONLY and _ordinary_worker != NULL_REF) else _ordinary_unique_contact()
	return _ordinary_scope_leaf() if code == &"" else code


func _ordinary_committed_contact() -> StringName:
	"""A second valid source contact cannot make an actual assigned worker's exact current selection ambiguous."""
	var graph: RoomRoutes = _ordinary_config.routes
	var row: int = RoomFace.FinishCheck._typed_row(graph._ids, _ordinary_worker, Directory.KIND_RESIDENT)
	if row < 0 or graph._resident_ref(row) != _ordinary_worker or graph._resident_pair(RoomRoutes.R_JOB_SLOT, row) != _ordinary_job \
			or graph._resident_pair(RoomRoutes.R_EDGE_SLOT, row) != NULL_REF \
			or RoomRoutes.actor_phase_in(graph, _ordinary_worker) != RoomRoutes.PHASE_IDLE:
		return ROOM_REFUSE_WORKER
	var location: Vector2i = graph._resident_pair(RoomRoutes.R_LOCATION_SLOT, row)
	var profile: int = graph._motion.resident[RoomRoutes.R_PROFILE * RoomRoutes.RESIDENT_CAPACITY + row]
	if not _ordinary_profile(profile) or not graph._locations._live_ref(graph._locations._live, location) \
			or _ordinary_location(location, RoomLocations.ROLE) != RoomLocations.ROLE_WORK \
			or graph._motion.resident_long[RoomRoutes.R_PROFILE_REVISION * RoomRoutes.RESIDENT_CAPACITY + row] != graph._profiles._live.quantities[profile] \
			or graph._motion.resident_long[RoomRoutes.R_CONTENT_REVISION * RoomRoutes.RESIDENT_CAPACITY + row] != graph._profiles._live.header[0]:
		return ROOM_REFUSE_WORKER
	var face: int = _ordinary_contact_face(profile, location)
	return _ordinary_capture_contact(location, profile, face) if face >= 0 else ROOM_REFUSE_CONTACT


func _ordinary_unique_contact() -> StringName:
	"""Only worker-free selection scans alternatives; every candidate spends from the same finite observation budget."""
	var locations: RoomLocations = _ordinary_config.locations
	var selected: Vector2i = NULL_REF
	var profile: int = -1
	var face: int = -1
	for row: int in locations._capacity:
		if not _entry_spend(8): return ROOM_REFUSE_CAPACITY
		if locations._live.present[row] != 1 or locations._get32(locations._live, RoomLocations.ROLE, row) != RoomLocations.ROLE_WORK: continue
		var location: Vector2i = Vector2i(row, locations._get32(locations._live, RoomLocations.GENERATION, row))
		for candidate: int in _ordinary_config.profiles._live.header[1]:
			if not _entry_spend(32): return ROOM_REFUSE_CAPACITY
			if not _ordinary_profile(candidate): continue
			var side: int = _ordinary_contact_face(candidate, location)
			if side < 0: continue
			if selected != NULL_REF: return ROOM_REFUSE_CONTACT
			selected = location
			profile = candidate
			face = side
	return _ordinary_capture_contact(selected, profile, face) if selected != NULL_REF else ROOM_REFUSE_CONTACT


func _ordinary_capture_contact(location: Vector2i, profile: int, face: int) -> StringName:
	"""Capture only source selection; callers still prove scope, whole motion, assignment and actual final payment."""
	_ordinary_query.location = location
	_ordinary_query.target_origin = _entry_origin
	_ordinary_query.profile_id = profile
	_ordinary_query.profile_revision = _ordinary_config.profiles._live.quantities[profile]
	_ordinary_query.content_revision = _ordinary_config.profiles._live.header[0]
	_ordinary_query.geometry_revision = _ordinary_config.owner._header[17]
	_ordinary_query.yaw = _ordinary_field(profile, EntryProfiles.F_YAW)
	_ordinary_query.face = face
	_entry_payload = _ordinary_config.locations._get64(_ordinary_config.locations._live, RoomLocations.PAYLOAD_REVISION, location.x)
	return &""


func _ordinary_endpoint_leaf(location: Vector2i, revision: int, role: int = -1) -> StringName:
	"""Exact full live endpoint payloads survive only within the original geometry or its guarded refresh candidate."""
	var locations: RoomLocations = _ordinary_config.locations
	if not locations._live_ref(locations._live, location) or revision <= 0 \
			or locations._get64(locations._live, RoomLocations.PAYLOAD_REVISION, location.x) != revision \
			or locations._get64(locations._live, RoomLocations.GEOMETRY_REVISION, location.x) != _ordinary_query.geometry_revision \
			or (role >= 0 and _ordinary_location(location, RoomLocations.ROLE) != role): return ROOM_REFUSE_CONTACT
	return &""


func _ordinary_selected_leaf() -> StringName:
	"""A later equal source number, changed face or replaced full endpoint cannot reuse a proved motion."""
	var query: RoomFace.Request = _ordinary_query
	var profiles: EntryProfiles = _ordinary_config.profiles
	if query == null or query.target_origin != _entry_origin or query.content_revision != profiles._live.header[0] \
			or query.geometry_revision != _ordinary_config.owner._header[17] or not _ordinary_profile(query.profile_id) \
			or query.profile_revision != profiles._live.quantities[query.profile_id] \
			or query.yaw != _ordinary_field(query.profile_id, EntryProfiles.F_YAW): return ROOM_REFUSE_SOURCE
	var code: StringName = _ordinary_endpoint_leaf(query.location, _entry_payload, RoomLocations.ROLE_WORK)
	if code == &"" and _ordinary_contact_face(query.profile_id, query.location) != query.face: code = ROOM_REFUSE_CONTACT
	return code


func _ordinary_path(destination: Vector2i) -> StringName:
	"""A current certified directed graph path is required; neither contact nor a retained phase creates an edge."""
	var actual: RoomWorldRoutes = _ordinary_routes.get_ref() as RoomWorldRoutes
	var code: StringName = RoomWorldRoutes.profile_reachability_refusal(actual, _ordinary_query.location,
		destination, _ordinary_travel, _ordinary_travel_revision, _ordinary_query.content_revision,
		_entry_remaining, _ordinary_checks)
	if code == &"": _entry_remaining = _ordinary_checks[0]
	return code


func _ordinary_observe_face() -> StringName:
	"""All large exact-union geometry is observed under the original lease and destroyed before companions."""
	var code: StringName = _ordinary_select()
	if code != &"": return code
	if _entry_cold_token <= 0: return REFUSE_BUDGET
	var face: RoomFace = _ordinary_face.get_ref() as RoomFace
	if _entry_operation == Contract.OP_FINISH:
		var sites: Sites = _ordinary_config.sources._construction._excavation_authority.get_ref() as Sites
		code = face.finish_face_refusal(_ordinary_config, _ordinary_query, sites, _entry_site,
			_entry_room, _entry_project, _entry_stage, _entry_cold_token)
	else:
		code = face.solid_face_refusal(_ordinary_config, _ordinary_query, _entry_cold_token)
	if code == &"": code = _ordinary_scope_leaf()
	if code == &"": code = _ordinary_selected_leaf()
	if code == &"": code = _ordinary_path(_ordinary_retreat)
	if code == &"":
		_ordinary_retreat_revision = _ordinary_config.locations._get64(_ordinary_config.locations._live,
			RoomLocations.PAYLOAD_REVISION, _ordinary_retreat.x)
	return code


func phase_plan_into(site: Vector2i, operation: int, stage: int, room: Vector2i,
		volume_rows_limit: int, out: Space.Plan) -> StringName:
	"""Ordinary Rooms derive complete current source plans; actual Entry retains its immutable EPISODE provider."""
	if _ordinary_entry_room(room):
		_ordinary_mode = false
		return super.phase_plan_into(site, operation, stage, room, volume_rows_limit, out)
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	var code: StringName = _ordinary_pin(site, operation, stage, room)
	if code == &"": code = _ordinary_observe_face()
	if code == &"": code = structural_refusal(site, operation, stage, room)
	if code == &"": code = _ordinary_resources()
	if code == &"" and _ordinary_needs_worker(): code = _ordinary_worker_leaf(true)
	if code == &"": code = _ordinary_plan_shape(out, volume_rows_limit, true)
	if code == &"": code = _ordinary_plan(out, true)
	if code == &"": code = _ordinary_scope_leaf()
	_ordinary_valid = code == &""
	return _entry_leave(code)


func _ordinary_plan_shape(plan: Space.Plan, limit: int, empty: bool) -> StringName:
	"""Capacity precedes all row growth; no extra cut, endpoint or Catalog instruction hides in the phase plan."""
	if plan == null or plan.contacts == null or plan.volumes == null or not _entry_plan_extras_empty(plan):
		return ENTRY_REFUSE_PLAN
	var count: int = _ordinary_field(_ordinary_query.profile_id, EntryProfiles.F_BOX_COUNT)
	if limit < 3 * count or limit > PHASE_ROW_LIMIT: return ROOM_REFUSE_CAPACITY
	if empty:
		return &"" if _entry_table_shape(plan.volumes, 0) and _entry_table_shape(plan.contacts.approach, 0) \
			and _entry_table_shape(plan.contacts.reach, 0) and plan.contacts.profile_id.is_empty() \
			and plan.contacts.profile_revision.is_empty() and plan.contacts.work_xyz.is_empty() \
			and plan.expected_revision == 0 and plan.owner_ref == NULL_REF and plan.owner_revision == 0 else ENTRY_REFUSE_PLAN
	var contacts: int = plan.contacts.profile_id.size()
	return &"" if _entry_table_shape(plan.volumes, plan.volumes.role.size()) \
		and _entry_table_shape(plan.contacts.approach, contacts) and _entry_table_shape(plan.contacts.reach, contacts) \
		and plan.contacts.profile_revision.size() == contacts and plan.contacts.work_xyz.size() == 3 * contacts else ENTRY_REFUSE_PLAN


func _ordinary_plan_owner() -> StringName:
	"""Room ownership never excuses another resident; an assigned actual actor may own only its own approach."""
	var ids: Directory = _ordinary_config.sources._directory
	var buildings: Buildings = _ordinary_config.sources._buildings
	var row: int = RoomFace.FinishCheck._typed_row(ids, _entry_room, Directory.KIND_ROOM)
	if row < 0 or buildings._r_present[row] != 1: return ROOM_REFUSE_SCOPE
	_entry_contact_ref = _entry_room
	_entry_contact_revision = _ordinary_room_revision()
	if _entry_contact_revision <= 0: return ROOM_REFUSE_SCOPE
	if not _ordinary_needs_worker(): return &""
	var worker: Vector2i = _ordinary_assigned_worker()
	var owner: Owner = _ordinary_config.owner
	if not _entry_spend(owner._source_capacity): return ROOM_REFUSE_CAPACITY
	var source: int = owner._find_source(worker, false)
	if source >= 0:
		_entry_contact_ref = worker
		_entry_contact_revision = owner._o_revision[source]
	return &""


func _ordinary_plan(plan: Space.Plan, write: bool) -> StringName:
	"""Write or compare every source primitive and contact; role partition never removes a negative residual."""
	var code: StringName = _ordinary_plan_owner()
	if code != &"": return code
	var revision: int = _ordinary_room_revision()
	if revision <= 0: return ROOM_REFUSE_SCOPE
	if write:
		plan.expected_revision = _ordinary_query.geometry_revision
		plan.owner_ref = _entry_room
		plan.owner_revision = revision
	elif plan.expected_revision != _ordinary_query.geometry_revision or plan.owner_ref != _entry_room or plan.owner_revision != revision:
		return ENTRY_REFUSE_PLAN
	code = _ordinary_read_anchor()
	if code != &"": return code
	var rows: int = 0
	var contacts: int = 0
	for ordinal: int in _ordinary_field(_ordinary_query.profile_id, EntryProfiles.F_BOX_COUNT):
		var role: int = _ordinary_box(_ordinary_query.profile_id, ordinal, _ordinary_query.location)
		if role < 0: return ROOM_REFUSE_CAPACITY
		if role == EntryProfiles.CONTACT_POINT or role == EntryProfiles.CONTACT_PATCH: continue
		code = _ordinary_plan_row(plan, write, rows, contacts, role, revision)
		if code != &"": return code
		rows += 1
		if _ordinary_has_air_contact(role): contacts += 1
	return &"" if rows == plan.volumes.role.size() and contacts == plan.contacts.profile_id.size() else ENTRY_REFUSE_PLAN


func _ordinary_read_anchor() -> StringName:
	"""Retain the exact immutable anchor solely for constructing a complete conservative face reach."""
	var found: int = 0
	for ordinal: int in _ordinary_field(_ordinary_query.profile_id, EntryProfiles.F_BOX_COUNT):
		var role: int = _ordinary_box(_ordinary_query.profile_id, ordinal, _ordinary_query.location)
		if role < 0: return ROOM_REFUSE_CAPACITY
		if role == EntryProfiles.CONTACT_POINT:
			found += 1
			_entry_point = Vector3i(_entry_box[0], _entry_box[1], _entry_box[2])
	return &"" if found == 1 else ROOM_REFUSE_CONTACT


func _ordinary_plan_row(plan: Space.Plan, write: bool, row: int, contact: int, role: int, revision: int) -> StringName:
	"""Full volumes retain the source; the separate supported approach is the proven above-plane body portion."""
	var level: int = _ordinary_location(_ordinary_query.location, RoomLocations.LEVEL)
	var volume_role: int = Space.SUPPORT_REQUIRED if role == EntryProfiles.STANCE_SUPPORT else Space.ENVELOPE
	if write: _entry_append_row(plan.volumes, _entry_box, volume_role, level, _entry_room, revision)
	elif not _entry_row_matches(plan.volumes, row, _entry_box, volume_role, level, _entry_room, revision): return ENTRY_REFUSE_PLAN
	if not _ordinary_has_air_contact(role): return &""
	for axis: int in 3:
		_entry_air[axis] = maxi(_entry_box[axis], _ordinary_location(_ordinary_query.location, RoomLocations.ENVELOPE + axis))
		_entry_air[axis + 3] = mini(_entry_box[axis + 3], _ordinary_location(_ordinary_query.location, RoomLocations.ENVELOPE + axis + 3))
		if _entry_air[axis] >= _entry_air[axis + 3]: return ENTRY_REFUSE_PLAN
		_entry_reach[axis] = mini(_entry_air[axis], _entry_point[axis])
		_entry_reach[axis + 3] = maxi(_entry_air[axis + 3], int(_entry_point[axis]) + 1)
	if write:
		_entry_append_row(plan.contacts.approach, _entry_air, Space.ENVELOPE, level, _entry_contact_ref, _entry_contact_revision)
		_entry_append_row(plan.contacts.reach, _entry_reach, Space.ENVELOPE, level, _entry_contact_ref, _entry_contact_revision)
		plan.contacts.profile_id.append(_ordinary_query.profile_id)
		plan.contacts.profile_revision.append(_ordinary_query.profile_revision)
		plan.contacts.work_xyz.append(_entry_point.x); plan.contacts.work_xyz.append(_entry_point.y); plan.contacts.work_xyz.append(_entry_point.z)
		return &""
	return &"" if _entry_row_matches(plan.contacts.approach, contact, _entry_air, Space.ENVELOPE, level, _entry_contact_ref, _entry_contact_revision) \
		and _entry_row_matches(plan.contacts.reach, contact, _entry_reach, Space.ENVELOPE, level, _entry_contact_ref, _entry_contact_revision) \
		and plan.contacts.profile_id[contact] == _ordinary_query.profile_id \
		and plan.contacts.profile_revision[contact] == _ordinary_query.profile_revision \
		and Vector3i(plan.contacts.work_xyz[3 * contact], plan.contacts.work_xyz[3 * contact + 1], plan.contacts.work_xyz[3 * contact + 2]) == _entry_point else ENTRY_REFUSE_PLAN


func _ordinary_has_air_contact(role: int) -> bool:
	"""Whole below-floor residuals remain full survey rows and WorkFace obligations; only positive air is approach."""
	return _entry_is_approach(role) and _entry_box[4] > _ordinary_location(_ordinary_query.location, RoomLocations.Y)


func phase_qualification_refusal(domain: Space.Domain, snapshot: Space.Snapshot, plan: Space.Plan,
		site: Vector2i, operation: int, stage: int) -> StringName:
	"""A copied plan qualifies only the original unique contact/source tuple and exact World geometry."""
	if not _ordinary_mode: return super.phase_qualification_refusal(domain, snapshot, plan, site, operation, stage)
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	var code: StringName = _ordinary_context(site, operation, stage)
	if code == &"" and (not _entry_same_domain(domain) or snapshot == null \
		or snapshot.world_ref != _domain._world or snapshot.revision != _ordinary_query.geometry_revision): code = ENTRY_REFUSE_PLAN
	if code == &"": code = _ordinary_plan_shape(plan, PHASE_ROW_LIMIT, false)
	if code == &"": code = _ordinary_plan(plan, false)
	if code == &"": code = _ordinary_live_leaf(false)
	return _entry_leave(code)


func _ordinary_context(site: Vector2i, operation: int, stage: int) -> StringName:
	"""A successful observation never transfers to another full Site, stage, Project or original cold operation."""
	if not _ordinary_valid or site != _entry_site or operation != _entry_operation or stage != _entry_stage:
		return ROOM_REFUSE_SCOPE
	return _ordinary_scope_leaf()


func _ordinary_needs_worker() -> bool:
	"""Worker-free admission and terminal retry keep complete contact geometry without productive entitlement."""
	return _entry_stage == Contract.STAGE_START or _entry_stage == Contract.STAGE_WORK


func _ordinary_assigned_worker() -> Vector2i:
	"""Full actual Job and Resident assignment is read from canonical columns without retaining a second mapping."""
	var sites: Sites = _ordinary_config.sources._construction._excavation_authority.get_ref() as Sites
	var job: Vector2i = Vector2i(sites._job_slot[_entry_site.x], sites._job_generation[_entry_site.x])
	var row: int = RoomFace.FinishCheck._typed_row(_ordinary_config.sources._directory, job, Directory.KIND_JOB)
	var jobs: Jobs = _ordinary_config.profiles._work._jobs
	if row < 0 or jobs._job_present[row] != 1 or jobs._job_ref_slot[row] != job.x \
			or jobs._job_ref_generation[row] != job.y: return NULL_REF
	return Vector2i(jobs._worker_slot[row], jobs._worker_generation[row])


func _ordinary_room_revision() -> int:
	"""Read the actual retained full Room source revision; Buildings has no invented geometry counter."""
	var owner: Owner = _ordinary_config.owner
	if not _entry_spend(owner._source_capacity): return 0
	var row: int = owner._find_source(_entry_room, false)
	return owner._o_revision[row] if row >= 0 and owner._o_kind[row] == Directory.KIND_ROOM else 0


func _ordinary_project_row() -> int:
	"""Construction purpose, subject and operation must name this actual Site through their full row mirror."""
	var construction: Construction = _ordinary_config.sources._construction
	var row: int = RoomFace.FinishCheck._typed_row(construction._directory, _entry_project, Directory.KIND_CONSTRUCTION)
	return row if row >= 0 and construction._present[row] == 1 and construction._ref_slot[row] == _entry_project.x \
		and construction._ref_generation[row] == _entry_project.y and construction._purpose[row] == Construction.PURPOSE_EXCAVATION \
		and construction._type_id[row] == _entry_operation and construction._subject_slot[row] == _entry_site.x \
		and construction._subject_generation[row] == _entry_site.y else -1


func _ordinary_lifecycle_leaf() -> StringName:
	"""Current action-specific paid truth is required; cancellation can freeze a paused or unfinished phase."""
	var sites: Sites = _ordinary_config.sources._construction._excavation_authority.get_ref() as Sites
	var phase: int = sites._phase[_entry_site.x]
	var installed: int = sites._installed[_entry_site.x]
	if _entry_operation == Contract.OP_BRACE and (installed != 0 or (phase != Sites.SOLID and phase != Sites.BACKFILLED and phase != Sites.BRACING)):
		return ROOM_REFUSE_SCOPE
	if _entry_operation == Contract.OP_CUT and (installed != 1 or (phase != Sites.BRACED and phase != Sites.CUTTING)): return ROOM_REFUSE_SCOPE
	if _entry_operation == Contract.OP_FINISH and (installed != 1 or sites._ever_cut[_entry_site.x] != 1 \
		or (phase != Sites.OPEN_UNFINISHED and phase != Sites.FINISHING)): return ROOM_REFUSE_SCOPE
	if _entry_stage == Contract.STAGE_ADMIT:
		return &"" if _entry_project == NULL_REF and sites._operation[_entry_site.x] == -1 else ROOM_REFUSE_SCOPE
	var row: int = _ordinary_project_row()
	if row < 0 or sites._operation[_entry_site.x] != _entry_operation: return ROOM_REFUSE_SCOPE
	if _entry_stage == Contract.STAGE_CANCEL or _entry_stage == PhaseContacts.PHASE_CONTACT_ONLY: return &""
	var construction: Construction = _ordinary_config.sources._construction
	if construction._paused[row] != 0: return Construction.REFUSE_PAUSED
	if _entry_stage == Contract.STAGE_START:
		return &"" if construction._phase[row] == Construction.PHASE_READY and construction._work_begun[row] == 0 else Construction.REFUSE_WRONG_PHASE
	if construction._work_begun[row] != 1 or sites._funding._project_slot[row] != _entry_project.x \
		or sites._funding._project_generation[row] != _entry_project.y: return Construction.REFUSE_WRONG_PHASE
	if _entry_stage == Contract.STAGE_COMMIT:
		return &"" if construction._phase[row] == Construction.PHASE_WORK_DONE and construction._remaining_mwu[row] == 0 else Construction.REFUSE_WRONG_PHASE
	return &"" if _entry_stage == Contract.STAGE_WORK and construction._phase[row] == Construction.PHASE_WORKING \
		and construction._remaining_mwu[row] > 0 else Construction.REFUSE_WRONG_PHASE


func _ordinary_worker_leaf(capture: bool = false) -> StringName:
	"""Current actual Transform, complete body selection, assigned BUILD Job and equipped claim close together."""
	var code: StringName = _ordinary_productive_phase_leaf()
	if code != &"": return code
	var graph: RoomRoutes = _ordinary_config.routes
	var worker: Vector2i = _ordinary_assigned_worker()
	var row: int = RoomFace.FinishCheck._typed_row(graph._ids, worker, Directory.KIND_RESIDENT)
	if row < 0 or graph._resident_ref(row) != worker or graph._resident_pair(RoomRoutes.R_LOCATION_SLOT, row) != _ordinary_query.location \
			or graph._resident_pair(RoomRoutes.R_EDGE_SLOT, row) != NULL_REF \
			or RoomRoutes.actor_phase_in(graph, worker) != RoomRoutes.PHASE_IDLE:
		return ROOM_REFUSE_WORKER
	if not _entry_spend(512): return ROOM_REFUSE_CAPACITY
	code = RoomRoutes.physical_selection_into(graph, row, graph._checked_selection)
	if code != &"": return code
	var selected: EntryProfiles.Selection = graph._checked_selection
	if selected.profile_id != _ordinary_query.profile_id or selected.profile_revision != _ordinary_query.profile_revision \
			or selected.content_revision != _ordinary_query.content_revision or selected.yaw != _ordinary_query.yaw \
			or selected.mode != EntryProfiles.MODE_WORK or selected.x != _ordinary_location(_ordinary_query.location, RoomLocations.X) \
			or selected.y != _ordinary_location(_ordinary_query.location, RoomLocations.Y) \
			or selected.z != _ordinary_location(_ordinary_query.location, RoomLocations.Z): return ROOM_REFUSE_WORKER
	code = _ordinary_job_leaf(worker, selected.job, row)
	if code == &"": code = _ordinary_tool_leaf(worker, selected.job, selected.tool, row)
	if code == &"": code = RoomRoutes.source_work_leaf_refusal(graph, worker, _ordinary_job,
		_ordinary_query.profile_id, _ordinary_query.profile_revision, _ordinary_query.content_revision)
	if code == &"": code = _ordinary_worker_payload(selected, capture)
	if code == &"": code = _ordinary_travel_payload()
	return code


func _ordinary_productive_phase_leaf() -> StringName:
	"""Prospective worker binding is READY only; paused cancellation never becomes an unpaid work entitlement."""
	if _entry_stage != PhaseContacts.PHASE_CONTACT_ONLY: return _ordinary_lifecycle_leaf()
	var row: int = _ordinary_project_row()
	if row < 0: return ROOM_REFUSE_SCOPE
	var construction: Construction = _ordinary_config.sources._construction
	if construction._paused[row] != 0: return Construction.REFUSE_PAUSED
	return &"" if construction._phase[row] == Construction.PHASE_READY and construction._work_begun[row] == 0 \
		else Construction.REFUSE_WRONG_PHASE


func _ordinary_job_leaf(worker: Vector2i, job: Vector2i, resident: int) -> StringName:
	"""Both full Job and resident-agent links remain exact after every source/contact observation."""
	var graph: RoomRoutes = _ordinary_config.routes
	var sites: Sites = graph._sources._construction._excavation_authority.get_ref() as Sites
	var jobs: Jobs = graph._jobs
	var row: int = RoomFace.FinishCheck._typed_row(graph._ids, job, Directory.KIND_JOB)
	if row < 0 or jobs._job_present[row] != 1 or jobs._job_ref_slot[row] != job.x or jobs._job_ref_generation[row] != job.y \
			or jobs._kind[row] != Jobs.JOB_KIND_BUILD or jobs._is_coordinator[row] != 0 or jobs._coordinator_slot[row] != -1 \
			or jobs._worker_slot[row] != worker.x or jobs._worker_generation[row] != worker.y \
			or jobs._requester_slot[row] != _entry_project.x or jobs._requester_generation[row] != _entry_project.y \
			or jobs._tool_gate[row] != Jobs.GATE_SATISFIED or jobs._agent_present[resident] != 1 \
			or jobs._agent_persistent_id[resident] != graph._ids._persistent_id[worker.x] \
			or jobs._agent_job_slot[resident] != job.x or jobs._agent_job_generation[resident] != job.y \
			or sites._job_slot[_entry_site.x] != job.x or sites._job_generation[_entry_site.x] != job.y \
			or sites._job_site[row] != _entry_site.x: return ROOM_REFUSE_WORKER
	var project: int = _ordinary_project_row()
	if project < 0 or jobs._remaining_mwu[row] != sites._construction._remaining_mwu[project]: return ROOM_REFUSE_WORKER
	if _ordinary_needs_worker() and (sites._worker_site[resident] != _entry_site.x or sites._worker_generation[resident] != worker.y):
		return ROOM_REFUSE_WORKER
	return &""


func _ordinary_tool_leaf(worker: Vector2i, job: Vector2i, tool: Vector2i, resident: int) -> StringName:
	"""Physical equipped geometry is not a productive claim; actual Work/Gear assignment and durability also hold."""
	var profiles: EntryProfiles = _ordinary_config.profiles
	var work: RefCounted = profiles._work
	var gear: RoomGear = profiles._gear
	if tool.x < 0 or tool.x >= RoomGear.LOT_CAPACITY or tool.y <= 0 \
			or work._tool_lot_slot[resident] != tool.x or work._tool_lot_generation[resident] != tool.y \
			or work._tool_job_slot[resident] != job.x or work._tool_job_generation[resident] != job.y: return ROOM_REFUSE_WORKER
	var row: int = gear._lot_row[tool.x]
	return &"" if row >= 0 and row < gear._row_capacity and gear._occupied[row] == 1 \
		and gear._lot_slot[row] == tool.x and gear._lot_generation[row] == tool.y and gear._equipped[row] == 1 \
		and gear._owner_slot[row] == worker.x and gear._owner_generation[row] == worker.y and gear._durability[row] > 0 \
		and gear._claim_job_slot[row] == job.x and gear._claim_job_generation[row] == job.y else ROOM_REFUSE_WORKER


func _ordinary_worker_payload(selected: EntryProfiles.Selection, capture: bool) -> StringName:
	"""Only initial live observation captures the actual worker/load; final calls compare the same original tuple."""
	if _ordinary_worker != selected.worker or _ordinary_job != selected.job: return ROOM_REFUSE_WORKER
	if capture:
		_ordinary_tool = selected.tool
		_ordinary_satchel = selected.satchel
		_ordinary_cargo = selected.cargo
		_ordinary_quantity = selected.cargo_quantity_milli
		return &""
	return &"" if _ordinary_worker == selected.worker and _ordinary_job == selected.job \
		and _ordinary_tool == selected.tool and _ordinary_satchel == selected.satchel and _ordinary_cargo == selected.cargo \
		and _ordinary_quantity == selected.cargo_quantity_milli else ROOM_REFUSE_WORKER


func _ordinary_travel_payload() -> StringName:
	"""The explicit retreat profile must fit this same current body, equipped tool and complete carried quantity."""
	var profiles: EntryProfiles = _ordinary_config.profiles
	if not _ordinary_travel_row(profiles, _ordinary_travel, _ordinary_travel_revision): return ROOM_REFUSE_SOURCE
	for index: int in 3:
		if _ordinary_field(_ordinary_travel, EntryProfiles.F_SPECIES + index) != profiles._identity[index]: return ROOM_REFUSE_WORKER
	for index: int in 4:
		if _ordinary_field(_ordinary_travel, EntryProfiles.F_TOOL + index) != profiles._query_values[index]: return ROOM_REFUSE_WORKER
	var quantity: int = profiles._candidate.cargo_quantity_milli
	return &"" if quantity >= profiles._live.quantities[EntryProfiles.L_QUANTITY_MIN * profiles._profile_capacity + _ordinary_travel] \
		and quantity <= profiles._live.quantities[EntryProfiles.L_QUANTITY_MAX * profiles._profile_capacity + _ordinary_travel] else ROOM_REFUSE_WORKER


func _ordinary_storage_row(container: Vector2i) -> int:
	"""Resolve actual Inventory spatial columns directly; an Inventory observation adapter cannot alter this leaf."""
	var inventory: RoomInventory = _ordinary_config.profiles._inventory
	if container.x < 0 or container.x >= inventory._c_capacity or container.y <= 0 \
			or inventory._c_live[container.x] != 1 or inventory._c_generation[container.x] != container.y \
			or inventory._c_anchor_tile[container.x] > -2 or inventory._c_reachable[container.x] != 1:
		return -1
	var row: int = -2 - inventory._c_anchor_tile[container.x]
	if row < 0 or row >= inventory._spatial_container_slot.size() \
			or inventory._spatial_container_slot[row] != container.x or inventory._spatial_container_generation[row] != container.y \
			or inventory._spatial_world != _domain._world or inventory._c_owner_slot[container.x] != _domain._world.x \
			or inventory._c_owner_generation[container.x] != _domain._world.y \
			or inventory._c_max_mass_g[container.x] != RoomInventory.GROUND_PILE_MAX_MASS_G \
			or inventory._c_filters[container.x] != RoomInventory.FILTERS_ACCEPT_ALL \
			or (inventory._c_policy[container.x] != RoomInventory.UNSET_POLICY and inventory._c_policy[container.x] != RoomInventory.POLICY_GROUND_PILE): return -1
	var adapter: RoomLocations.InventoryLocations = inventory._spatial_authority.get_ref() as RoomLocations.InventoryLocations \
		if inventory._spatial_authority != null else null
	return row if adapter != null and adapter._locations != null and adapter._locations.get_ref() == _ordinary_config.locations else -1


func _ordinary_storage_leaf(container: Vector2i, endpoint: Vector2i, revision: int) -> StringName:
	"""The actual finite container, full STORAGE endpoint and its original payload all agree before payment."""
	var row: int = _ordinary_storage_row(container)
	var inventory: RoomInventory = _ordinary_config.profiles._inventory
	if row < 0 or Vector2i(inventory._spatial_location_slot[row], inventory._spatial_location_generation[row]) != endpoint \
			or inventory._spatial_location_revision[row] != revision: return ROOM_REFUSE_STORAGE
	return _ordinary_endpoint_leaf(endpoint, revision, RoomLocations.ROLE_STORAGE)


func _ordinary_observe_storage(container: Vector2i, output: bool) -> StringName:
	"""Pin one actual selected input/refund or output store and a current certified path; no distance is invented."""
	var row: int = _ordinary_storage_row(container)
	if row < 0: return ROOM_REFUSE_STORAGE
	var inventory: RoomInventory = _ordinary_config.profiles._inventory
	var endpoint: Vector2i = Vector2i(inventory._spatial_location_slot[row], inventory._spatial_location_generation[row])
	var revision: int = inventory._spatial_location_revision[row]
	var code: StringName = _ordinary_storage_leaf(container, endpoint, revision)
	if code == &"": code = _ordinary_path(endpoint)
	if code != &"": return code
	if output:
		_ordinary_output = container
		_ordinary_output_location = endpoint
		_ordinary_output_revision = revision
	else:
		_ordinary_material = container
		_ordinary_material_location = endpoint
		_ordinary_material_revision = revision
	return _ordinary_storage_leaf(container, endpoint, revision)


func _ordinary_resources() -> StringName:
	"""Before preparing banks, capture the canonical current material and spoil bindings, without a quantity ledger."""
	if _entry_project == NULL_REF: return &""
	var row: int = _ordinary_project_row()
	if row < 0: return ROOM_REFUSE_SCOPE
	var construction: Construction = _ordinary_config.sources._construction
	var material: Vector2i = Vector2i(construction._material_container_slot[row], construction._material_container_generation[row])
	var code: StringName = &""
	if material != NULL_REF: code = _ordinary_observe_storage(material, false)
	var sites: Sites = construction._excavation_authority.get_ref() as Sites
	var output: Vector2i = Vector2i(sites._output_slot[_entry_site.x], sites._output_generation[_entry_site.x])
	if code == &"" and output != NULL_REF:
		if sites._promotion_tile[_entry_site.x] != -1: return ROOM_REFUSE_STORAGE
		code = _ordinary_observe_storage(output, true)
	return code


func _ordinary_observers(worker: bool) -> StringName:
	"""Terrain and actual dynamic profile readers finish before every direct final physical and worker leaf."""
	var code: StringName = _ordinary_scope_leaf()
	if code == &"" and _terrain._checked_geometry_revision != _ordinary_query.geometry_revision:
		code = _terrain.binding_refusal()
	if code == &"": code = _ordinary_scope_leaf()
	if code == &"" and worker:
		var profiles: EntryProfiles = _ordinary_config.profiles
		code = profiles.query_work_profile_into(_ordinary_worker, _ordinary_job, _ordinary_query.profile_id,
			_ordinary_query.profile_revision, _ordinary_query.content_revision,
			_ordinary_field(_ordinary_query.profile_id, EntryProfiles.F_POSTURE), -1, _ordinary_tool,
			_ordinary_config.routes._checked_selection)
		if code == &"": code = _ordinary_config.routes.source_work_observation_refusal(_ordinary_worker,
			_ordinary_job, _ordinary_query.profile_id, _ordinary_query.profile_revision, _ordinary_query.content_revision)
	return _ordinary_scope_leaf() if code == &"" else code


func _ordinary_terrain_leaf() -> StringName:
	"""Source-complete motion and target exclusions are fresh after observers; no cache is promoted by assignment."""
	for axis: int in 3:
		_entry_box[axis] = _entry_origin[axis]
		_entry_box[axis + 3] = int(_entry_origin[axis]) + 1024
	var code: StringName = _ordinary_local_leaf(Terrain.DIG)
	if code != &"": return code
	for ordinal: int in _ordinary_field(_ordinary_query.profile_id, EntryProfiles.F_BOX_COUNT):
		var role: int = _ordinary_box(_ordinary_query.profile_id, ordinal, _ordinary_query.location)
		if role < 0: return ROOM_REFUSE_CAPACITY
		if role == EntryProfiles.CONTACT_POINT or role == EntryProfiles.CONTACT_PATCH: continue
		code = _ordinary_local_leaf(Terrain.EXCLUSIONS)
		if code != &"": return code
	return &""


func _ordinary_local_leaf(purpose: int) -> StringName:
	"""Use the accepted direct prepared Terrain reader or its exact direct live columns; neither invokes observers."""
	if not _entry_spend(Terrain.LOCAL_QUERY_CHECKS): return ROOM_REFUSE_CAPACITY
	if _ordinary_space > 0:
		return Terrain.prepared_local_leaf_refusal(_terrain, _entry_box, purpose, _ordinary_query.geometry_revision,
			_ordinary_space, _entry_cold_token)
	if _ordinary_config.owner._stage_token != 0 or _terrain._checked_geometry_revision != _ordinary_query.geometry_revision \
			or not Terrain._final_owners_match(_terrain, _ordinary_config.sources) \
			or _terrain._space.get_ref() != _ordinary_config.owner or _terrain._sources.get_ref() != _ordinary_config.sources \
			or _terrain._world_ref != _domain._world or _terrain._domain_bounds != _domain._bounds \
			or not Space.valid_box(_entry_box) or not Space.contains_box(_domain._bounds, _entry_box): return ROOM_REFUSE_SOURCE
	return Terrain._final_local_tiles(_terrain, _entry_box, purpose)


func _ordinary_occupants_leaf(except_worker: Vector2i) -> StringName:
	"""Every living actual resident needs a current full physical selection, including released terminal workers."""
	var graph: RoomRoutes = _ordinary_config.routes
	var residents: RoomResidents = graph._residents
	for row: int in RoomRoutes.RESIDENT_CAPACITY:
		if not _entry_spend(8): return ROOM_REFUSE_CAPACITY
		if residents._present[row] != 1 or residents._needs._present[row] != 1 or residents._needs._health[row] <= 0: continue
		var worker: Vector2i = Vector2i(residents._ref_slot[row], residents._ref_generation[row])
		if RoomFace.FinishCheck._typed_row(graph._ids, worker, Directory.KIND_RESIDENT) != row \
			or graph._resident_ref(row) != worker: return ROOM_REFUSE_WORKER
		if worker == except_worker: continue
		if not _entry_spend(256): return ROOM_REFUSE_CAPACITY
		var code: StringName = RoomRoutes.physical_selection_into(graph, row, graph._occupant_selection)
		if code == &"": code = _ordinary_occupant_boxes(graph._occupant_selection)
		if code != &"": return code
	return &""


func _ordinary_occupant_boxes(actor: EntryProfiles.Selection) -> StringName:
	"""Whole current body/recovery volumes oppose every non-support source motion primitive; no point test grants space."""
	var profiles: EntryProfiles = _ordinary_config.profiles
	for ordinal: int in actor.box_count:
		var at: int = _ordinary_field(actor.profile_id, EntryProfiles.F_FIRST_BOX) + ordinal
		var role: int = profiles._live.boxes[6 * profiles._box_capacity + at]
		if role != EntryProfiles.BODY_HELD_LOAD and role != EntryProfiles.TURN_RECOVERY: continue
		for axis: int in 6:
			var root: int = actor.x if axis % 3 == 0 else actor.y if axis % 3 == 1 else actor.z
			var value: int = root + profiles._live.boxes[axis * profiles._box_capacity + at]
			if not Space.int32(value): return ROOM_REFUSE_WORKER
			_entry_air[axis] = value
		for work_box: int in _ordinary_field(_ordinary_query.profile_id, EntryProfiles.F_BOX_COUNT):
			var work_role: int = _ordinary_box(_ordinary_query.profile_id, work_box, _ordinary_query.location)
			if work_role < 0: return ROOM_REFUSE_CAPACITY
			if work_role == EntryProfiles.STANCE_SUPPORT or work_role == EntryProfiles.CONTACT_POINT \
				or work_role == EntryProfiles.CONTACT_PATCH: continue
			if Space.overlaps(_entry_air, _entry_box): return &"ROUTE_OCCUPIED"
	return &""


func _ordinary_resource_leaf() -> StringName:
	"""Prepared or live payment keeps exactly the canonical material/output containers observed beforehand."""
	var code: StringName = _ordinary_endpoint_leaf(_ordinary_retreat, _ordinary_retreat_revision)
	if code == &"" and _ordinary_material != NULL_REF:
		code = _ordinary_storage_leaf(_ordinary_material, _ordinary_material_location, _ordinary_material_revision)
	if code == &"" and _ordinary_output != NULL_REF:
		code = _ordinary_storage_leaf(_ordinary_output, _ordinary_output_location, _ordinary_output_revision)
	if code != &"" or _entry_project == NULL_REF: return code
	var row: int = _ordinary_project_row()
	if row < 0: return ROOM_REFUSE_SCOPE
	var construction: Construction = _ordinary_config.sources._construction
	var sites: Sites = construction._excavation_authority.get_ref() as Sites
	if _ordinary_material != NULL_REF and _entry_stage != PhaseContacts.PHASE_CONTACT_ONLY \
		and Vector2i(construction._material_container_slot[row], construction._material_container_generation[row]) != _ordinary_material:
		return ROOM_REFUSE_STORAGE
	if _ordinary_output != NULL_REF and _entry_stage != PhaseContacts.PHASE_CONTACT_ONLY \
		and (Vector2i(sites._output_slot[_entry_site.x], sites._output_generation[_entry_site.x]) != _ordinary_output \
		or sites._promotion_tile[_entry_site.x] != -1): return ROOM_REFUSE_STORAGE
	return &""


func _ordinary_live_leaf(worker: bool) -> StringName:
	"""Complete actual current facts close geometry/contact observation without allocating another snapshot."""
	var code: StringName = _ordinary_scope_leaf()
	if code == &"": code = _ordinary_lifecycle_leaf()
	if code == &"": code = _ordinary_selected_leaf()
	if code == &"": code = _ordinary_resource_leaf()
	if code == &"": code = _ordinary_terrain_leaf()
	if code == &"" and worker: code = _ordinary_worker_leaf()
	if code == &"" and worker: code = _ordinary_occupants_leaf(_ordinary_worker)
	if code == &"" and _ordinary_space == 0:
		code = RoomFinal.snapshot_refusal(_ordinary_config.owner, _ordinary_config.routes, _ordinary_config.locations,
			_ordinary_query.geometry_revision, _entry_remaining)
	if code == &"": code = _ordinary_scope_leaf()
	return code


func _ordinary_live_contact(origin: Vector3i, operation: int, room: Vector2i, stage: int) -> StringName:
	"""Small live material/worker observations cannot replace an already sealed phase packet."""
	if _ordinary_binding_leaf() != &"": return ROOM_REFUSE_BINDING
	var sites: Sites = _ordinary_config.sources._construction._excavation_authority.get_ref() as Sites
	var site: Vector2i = sites.site_at(origin)
	if _phase_token > 0:
		if site != _phase_site or operation != _phase_operation or room != _phase_room: return ROOM_REFUSE_SCOPE
		stage = _phase_stage
		if _ordinary_config.owner._stage_token == 0:
			return _ordinary_context(site, operation, stage)
	if _ordinary_config.owner._stage_token != 0:
		return _ordinary_final_context(site, operation, stage, _entry_cold_token, _ordinary_space, _ordinary_companion)
	var code: StringName = _ordinary_pin(site, operation, stage, room)
	if code == &"": code = _ordinary_select()
	if code == &"": code = _ordinary_resources()
	if code == &"": code = _ordinary_path(_ordinary_retreat)
	if code == &"":
		_ordinary_retreat_revision = _ordinary_config.locations._get64(_ordinary_config.locations._live,
			RoomLocations.PAYLOAD_REVISION, _ordinary_retreat.x)
	_ordinary_valid = code == &""
	return code


func material_refusal(origin: Vector3i, room: Vector2i, container: Vector2i, job: Vector2i) -> StringName:
	"""Only the actual selected spatial stockpile may deliver or receive the current phase refund."""
	if _ordinary_entry_room(room): return super.material_refusal(origin, room, container, job)
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	if _ordinary_binding_leaf() != &"": return _entry_leave(ROOM_REFUSE_BINDING)
	var sites: Sites = _ordinary_config.sources._construction._excavation_authority.get_ref() as Sites
	var site: Vector2i = sites.site_at(origin)
	var code: StringName = ROOM_REFUSE_SCOPE
	if sites.is_live_site(site): code = _ordinary_live_contact(origin, sites._operation[site.x], room, PhaseContacts.PHASE_CONTACT_ONLY)
	if code == &"" and job != Vector2i(sites._job_slot[site.x], sites._job_generation[site.x]): code = ROOM_REFUSE_SCOPE
	if code == &"" and _entry_cold_token == 0: code = _ordinary_observe_storage(container, false)
	elif code == &"" and container != _ordinary_material: code = ROOM_REFUSE_STORAGE
	if code == &"": code = _ordinary_observers(false)
	if code == &"": code = _ordinary_live_leaf(false)
	return _entry_leave(code)


func output_refusal(origin: Vector3i, operation: int, room: Vector2i, container: Vector2i,
		job: Vector2i, promotion_tile: int) -> StringName:
	"""Current actual spatial output is required; an unproved surface promotion cannot stand in for a Room endpoint."""
	if _ordinary_entry_room(room): return super.output_refusal(origin, operation, room, container, job, promotion_tile)
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	if _ordinary_binding_leaf() != &"": return _entry_leave(ROOM_REFUSE_BINDING)
	var code: StringName = _ordinary_live_contact(origin, operation, room, PhaseContacts.PHASE_CONTACT_ONLY)
	var sites: Sites = _ordinary_config.sources._construction._excavation_authority.get_ref() as Sites
	if code == &"" and (operation != Contract.OP_CUT or promotion_tile != -1 \
		or job != Vector2i(sites._job_slot[_entry_site.x], sites._job_generation[_entry_site.x])): code = ROOM_REFUSE_STORAGE
	if code == &"" and _entry_cold_token == 0: code = _ordinary_observe_storage(container, true)
	elif code == &"" and container != _ordinary_output: code = ROOM_REFUSE_STORAGE
	if code == &"": code = _ordinary_observers(false)
	if code == &"": code = _ordinary_live_leaf(false)
	return _entry_leave(code)


func worker_refusal(origin: Vector3i, operation: int, room: Vector2i, job: Vector2i,
		worker: Vector2i, geometry_revision: int, source_revision: int) -> StringName:
	"""Productive Work always reattests the actual worker, full motion, tool/cargo, current routes and local facts."""
	if _ordinary_entry_room(room): return super.worker_refusal(origin, operation, room, job, worker, geometry_revision, source_revision)
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	if _ordinary_binding_leaf() != &"": return _entry_leave(ROOM_REFUSE_BINDING)
	var code: StringName = ROOM_REFUSE_SOURCE
	if geometry_revision == _ordinary_config.owner._header[17] and source_revision == qualification_revision():
		code = _ordinary_live_contact(origin, operation, room, _ordinary_worker_stage(origin))
	if code == &"" and (worker != _ordinary_worker or job != _ordinary_job): code = ROOM_REFUSE_WORKER
	if code == &"": code = _ordinary_worker_leaf(_entry_cold_token == 0)
	if code == &"": code = _ordinary_observers(true)
	if code == &"": code = _ordinary_live_leaf(true)
	return _entry_leave(code)


func _ordinary_worker_stage(origin: Vector3i) -> int:
	"""Unfunded worker binding is prospective; paid work must retain the actual current WORKING action."""
	var sites: Sites = _ordinary_config.sources._construction._excavation_authority.get_ref() as Sites
	var site: Vector2i = sites.site_at(origin)
	if not sites.is_live_site(site): return -2
	var project: Vector2i = Vector2i(sites._project_slot[site.x], sites._project_generation[site.x])
	var row: int = RoomFace.FinishCheck._typed_row(_ordinary_config.sources._directory, project, Directory.KIND_CONSTRUCTION)
	if row < 0: return -2
	return Contract.STAGE_WORK if sites._construction._work_begun[row] == 1 else PhaseContacts.PHASE_CONTACT_ONLY


func prepare_companions(owner_token: int, site: Vector2i, operation: int,
		stage: int, room: Vector2i, plan: Space.Plan) -> int:
	"""The actual shared issuer creates a refresh-only ordinary candidate; no fictitious Placement is passed."""
	if not _ordinary_mode: return super.prepare_companions(owner_token, site, operation, stage, room, plan)
	if not _entry_enter(): return 0
	var code: StringName = _ordinary_context(site, operation, stage)
	if code == &"" and room != _entry_room: code = ROOM_REFUSE_SCOPE
	var placements: EntryPlacements = _ordinary_placements.get_ref() as EntryPlacements
	var authority: Authority = _ordinary_authority()
	var token: int = 0
	if code == &"":
		token = placements.prepare_room_phase_refresh(authority, site, operation, stage, room, owner_token, _entry_cold_token)
		if token <= 0: code = ENTRY_REFUSE_COMPANION
	if code == &"":
		_ordinary_space = owner_token
		_ordinary_companion = token
		code = _ordinary_final_context(site, operation, stage, _entry_cold_token, owner_token, token)
	code = _entry_leave(code)
	if code != &"" and token > 0: authority.discard_room_phase_refresh(token)
	return token if code == &"" else 0


func _ordinary_authority() -> Authority:
	"""Borrow the once-bound actual Sites authority; no numeric candidate token authorizes another issuer."""
	var sites: Sites = _ordinary_original_sites()
	return sites._space.get_ref() as Authority if sites != null and sites._space != null else null


func _ordinary_final_context(site: Vector2i, operation: int, stage: int,
		cold: int, space: int, companion: int) -> StringName:
	"""Compare every original phase ref and token against the shared typed context; NULL Placement means ordinary only."""
	var code: StringName = _ordinary_context(site, operation, stage)
	if code != &"": return code
	if cold <= 0 or cold != _entry_cold_token or space <= 0 or space != _ordinary_space \
		or companion <= 0 or companion != _ordinary_companion: return ENTRY_REFUSE_COMPANION
	var authority: Authority = _ordinary_authority()
	var context: RoomLocations.PhaseContext = authority.room_phase_context(companion) if authority != null else null
	if context == null or context.placement != NULL_REF or context.site != site or context.room != _entry_room \
			or context.project != _entry_project or context.operation != operation or context.stage != stage \
			or context.cold_token != cold or context.space_token != space or context.location_token != companion \
			or context.issuer.get_ref() != _ordinary_placements.get_ref() or context.authority.get_ref() != authority \
			or context.budget != _budget or context.base_revision != _ordinary_query.geometry_revision \
			or context.profile_revision != _ordinary_query.content_revision: return ENTRY_REFUSE_COMPANION
	return &""


func prepared_refusal(token: int) -> StringName:
	"""Finish complete actual companion observations without replacing the original source/contact packet."""
	if not _ordinary_mode: return super.prepared_refusal(token)
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	var code: StringName = _ordinary_final_context(_entry_site, _entry_operation, _entry_stage,
		_entry_cold_token, _ordinary_space, token)
	if code == &"": code = _ordinary_authority().room_phase_observation_refusal(token)
	if code == &"": code = _ordinary_final_context(_entry_site, _entry_operation, _entry_stage,
		_entry_cold_token, _ordinary_space, token)
	return _entry_leave(code)


func phase_final_observation_refusal(site: Vector2i, operation: int, stage: int,
		cold_token: int, space_token: int, companion_token: int) -> StringName:
	"""All source/worker observers finish inside the original prepared Inventory window before final direct leaves."""
	if not _ordinary_mode: return super.phase_final_observation_refusal(site, operation, stage, cold_token, space_token, companion_token)
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	var code: StringName = _ordinary_final_context(site, operation, stage, cold_token, space_token, companion_token)
	if code == &"": code = _ordinary_observers(_ordinary_needs_worker())
	if code == &"": code = _ordinary_final_context(site, operation, stage, cold_token, space_token, companion_token)
	return _entry_leave(code)


func phase_final_leaf_refusal(site: Vector2i, operation: int, stage: int,
		cold_token: int, space_token: int, companion_token: int) -> StringName:
	"""No observer follows full original phase/contact/worker proof; actual Authority publishes all banks after payment."""
	if not _ordinary_mode: return super.phase_final_leaf_refusal(site, operation, stage, cold_token, space_token, companion_token)
	if not _entry_enter(): return ENTRY_REFUSE_BUSY
	var code: StringName = _ordinary_final_context(site, operation, stage, cold_token, space_token, companion_token)
	if code == &"": code = _ordinary_live_leaf(_ordinary_needs_worker())
	if code == &"": code = Authority.room_phase_leaf_refusal(_ordinary_authority(), companion_token)
	return _entry_leave(code)


func revision_after(token: int) -> int:
	"""Use exactly the candidate's future non-restored Location and graph receipts, not their rewindable bank epochs."""
	var placements: EntryPlacements = _ordinary_placements.get_ref() as EntryPlacements if _ordinary_placements != null else null
	if placements == null: return super.revision_after(token)
	if not _ordinary_mode:
		if super.revision_after(token) <= 0: return 0
	elif _ordinary_final_context(_entry_site, _entry_operation, _entry_stage,
		_entry_cold_token, _ordinary_space, token) != &"": return 0
	var context: RoomLocations.PhaseContext = placements.phase_context(token)
	return _ordinary_revision_for(context.location_token, context.route_token) if context != null else 0


func discard_companions(token: int) -> void:
	"""Discard only the exact ordinary context; nested callbacks cannot end someone else's cold operation."""
	if not _ordinary_mode:
		super.discard_companions(token)
		return
	if _entry_reading:
		_entry_poisoned = true
		return
	var authority: Authority = _ordinary_authority()
	if authority != null and token > 0 and token == _ordinary_companion: authority.discard_room_phase_refresh(token)


func end_cold_operation(token: int) -> void:
	"""The existing owner releases the original lease after all companions; no binding is reset for reuse."""
	if _entry_reading:
		_entry_poisoned = true
		return
	if token <= 0 or token != _phase_token: return
	_ordinary_valid = false
	_ordinary_space = 0
	_ordinary_companion = 0
	super.end_cold_operation(token)
	_ordinary_mode = false
